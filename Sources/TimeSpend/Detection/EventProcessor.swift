import Foundation

final class EventProcessor {
    private let dataStore: DataStore
    private let onSessionUpdate: () -> Void
    private let onSessionEnd: ((Int) -> Void)?

    // File watching
    private var fileHandle: FileHandle?
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var lastReadOffset: UInt64 = 0

    // Open sessions: session_id -> HookEvent (the prompt_start event)
    private var openSessions: [String: HookEvent] = [:]

    // Orphan detection
    private var orphanCheckPaused = false

    // Public: active session tracking for menu bar timer
    var activeSessionStartTime: Date? {
        guard let oldest = openSessions.values.min(by: { $0.ts < $1.ts }) else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(oldest.ts))
    }

    private var eventsFilePath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.timespend/events.jsonl"
    }

    init(dataStore: DataStore, onSessionUpdate: @escaping () -> Void, onSessionEnd: ((Int) -> Void)? = nil) {
        self.dataStore = dataStore
        self.onSessionUpdate = onSessionUpdate
        self.onSessionEnd = onSessionEnd
    }

    deinit {
        stopWatching()
    }

    // MARK: - File Watching

    func startWatching() {
        let path = eventsFilePath

        // Ensure file exists
        if !FileManager.default.fileExists(atPath: path) {
            let dir = (path as NSString).deletingLastPathComponent
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: path, contents: nil)
        }

        guard let handle = FileHandle(forReadingAtPath: path) else {
            print("[TimeSpend] Failed to open events file: \(path)")
            return
        }

        fileHandle = handle

        // Seek to end (only process new events)
        handle.seekToEndOfFile()
        lastReadOffset = handle.offsetInFile

        // Watch for writes using GCD dispatch source
        let fd = handle.fileDescriptor
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend],
            queue: DispatchQueue.global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            self?.readNewEvents()
        }

        source.setCancelHandler { [weak self] in
            self?.fileHandle?.closeFile()
            self?.fileHandle = nil
        }

        dispatchSource = source
        source.resume()
    }

    func stopWatching() {
        dispatchSource?.cancel()
        dispatchSource = nil
    }

    // MARK: - Event Processing

    private func readNewEvents() {
        guard let handle = fileHandle else { return }

        handle.seek(toFileOffset: lastReadOffset)
        let data = handle.readDataToEndOfFile()
        lastReadOffset = handle.offsetInFile

        guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }

        let lines = text.components(separatedBy: "\n")
        let decoder = JSONDecoder()

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            guard let lineData = trimmed.data(using: .utf8),
                  let event = try? decoder.decode(HookEvent.self, from: lineData) else {
                // Malformed line: skip without crashing
                continue
            }

            processEvent(event)
        }
    }

    private func processEvent(_ event: HookEvent) {
        switch event.event {
        case "prompt_start":
            openSessions[event.sessionId] = event
            DispatchQueue.main.async { self.onSessionUpdate() }

        case "response_end":
            guard let startEvent = openSessions.removeValue(forKey: event.sessionId) else {
                // response_end with no matching prompt_start: skip
                return
            }

            let duration = event.ts - startEvent.ts
            guard duration > 0 else { return }

            let session = WaitSession(
                startTime: Date(timeIntervalSince1970: TimeInterval(startEvent.ts)),
                endTime: Date(timeIntervalSince1970: TimeInterval(event.ts)),
                durationSeconds: duration,
                aiTool: "claude_code",
                sessionId: event.sessionId
            )

            dataStore.saveSession(session)
            DispatchQueue.main.async {
                self.onSessionUpdate()
                self.onSessionEnd?(duration)
            }

        default:
            // Unknown event type: skip
            break
        }
    }

    // MARK: - Orphan Detection

    func checkOrphans() {
        guard !orphanCheckPaused else { return }

        let now = Date()
        var closedIds: [String] = []

        for (sessionId, event) in openSessions {
            let age = now.timeIntervalSince1970 - TimeInterval(event.ts)

            // Check if PID is still alive
            let pidAlive = kill(Int32(event.pid), 0) == 0

            if !pidAlive {
                // PID is dead, close the session at current time
                closedIds.append(sessionId)
                closeOrphanSession(event, endTs: Int(now.timeIntervalSince1970))
            } else if age > 900 {
                // PID alive but session > 15 min, check pid_start for recycling
                let currentPidStart = getProcessStartTime(pid: event.pid)
                if currentPidStart != event.pidStart {
                    // PID was recycled
                    closedIds.append(sessionId)
                    closeOrphanSession(event, endTs: Int(now.timeIntervalSince1970))
                } else {
                    // Genuine long session, close as "incomplete"
                    closedIds.append(sessionId)
                    closeOrphanSession(event, endTs: Int(now.timeIntervalSince1970))
                }
            }
        }

        for id in closedIds {
            openSessions.removeValue(forKey: id)
        }

        if !closedIds.isEmpty {
            DispatchQueue.main.async { self.onSessionUpdate() }
        }
    }

    private func closeOrphanSession(_ event: HookEvent, endTs: Int) {
        let duration = endTs - event.ts
        guard duration > 0 else { return }

        let session = WaitSession(
            startTime: Date(timeIntervalSince1970: TimeInterval(event.ts)),
            endTime: Date(timeIntervalSince1970: TimeInterval(endTs)),
            durationSeconds: duration,
            aiTool: "claude_code",
            sessionId: event.sessionId
        )

        dataStore.saveSession(session)
    }

    private func getProcessStartTime(pid: Int) -> Int {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-o", "lstart=", "-p", "\(pid)"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !output.isEmpty else {
                return 0
            }

            let formatter = DateFormatter()
            formatter.dateFormat = "EEE MMM dd HH:mm:ss yyyy"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            if let date = formatter.date(from: output) {
                return Int(date.timeIntervalSince1970)
            }
        } catch {
            // Process not found or other error
        }

        return 0
    }

    func pauseOrphanDetection() {
        orphanCheckPaused = true
    }

    func resumeOrphanDetection() {
        orphanCheckPaused = false
    }

    // MARK: - Events File Maintenance

    func rotateEventsFileIfNeeded() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: eventsFilePath),
              let size = attrs[.size] as? UInt64 else { return }

        // Rotate at 1MB
        if size > 1_000_000 {
            // Stop watching, truncate, restart
            stopWatching()
            try? "".write(toFile: eventsFilePath, atomically: true, encoding: .utf8)
            lastReadOffset = 0
            startWatching()
        }
    }
}
