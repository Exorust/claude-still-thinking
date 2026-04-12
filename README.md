# Claude is Thinking?

**How much time did you waste waiting for Claude Code?**

A macOS menu bar app that tracks how long you spend waiting for Claude Code to respond. See your stats, get reminded to touch grass, and share your numbers.

![menu bar timer](https://img.shields.io/badge/menu_bar-timer-4ade80) ![macOS 13+](https://img.shields.io/badge/macOS-13%2B-333) ![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-F05138) ![License MIT](https://img.shields.io/badge/license-MIT-blue)

## Features

**Live timer** in the menu bar while Claude Code is thinking.

**Dashboard** with today's total, weekly chart, average wait per prompt, longest session, and recent activity. Toggle between daily and weekly views.

**Share cards** as PNG images. Post your wait time to Twitter, LinkedIn, Bluesky, or Threads. The image is copied to your clipboard and the compose window opens automatically.

**Touch grass notifications** when your cumulative daily wait time crosses a threshold. Rotating messages like "Claude has been thinking for 32 minutes today. Your houseplants miss you."

## Install

### Homebrew (coming soon)

```
brew install --cask time-spend
```

### Download

Grab the latest `.dmg` from [Releases](../../releases).

### Build from source

Requires Swift 5.9+ and macOS 13+.

```bash
git clone https://github.com/YOUR_USERNAME/time-spend.git
cd time-spend/TimeSpend
swift build
./scripts/bundle-app.sh
open build/TimeSpend.app
```

## How It Works

Claude is Thinking? uses [Claude Code hooks](https://docs.anthropic.com/en/docs/claude-code/hooks) to track wait time. No process monitoring, no accessibility permissions, no heuristics.

On first launch, click **Enable Tracking** to install two hooks into `~/.claude/settings.json`:

- `UserPromptSubmit` fires when you send a prompt (starts the timer)
- `Stop` fires when Claude finishes responding (stops the timer)

The hooks write timestamped events to `~/Library/Application Support/TimeSpend/events.jsonl`. The app watches this file and pairs start/end events into sessions stored in a local SQLite database.

**Your data never leaves your Mac.** No accounts, no telemetry, no network requests.

## Usage

1. Launch the app. A timer icon (⏲) appears in your menu bar.
2. Click **Enable Tracking** on the first-run screen.
3. Use Claude Code normally. The menu bar shows a live timer while Claude is thinking.
4. Click the menu bar icon to see your dashboard.
5. Click **Share Your Stats** to generate and share a stat card.

### Settings

Click the gear icon in the dashboard to configure:

- **Touch grass threshold**: 15m, 30m, 45m, or 1h (or off)
- **Launch at login**: Start automatically
- **Disable tracking**: Removes hooks from `~/.claude/settings.json`

## Project Structure

```
TimeSpend/
├── Package.swift
├── Sources/TimeSpend/
│   ├── App/
│   │   ├── main.swift              # Entry point
│   │   └── AppDelegate.swift       # Menu bar, popover, lifecycle
│   ├── Detection/
│   │   ├── HookInstaller.swift     # Installs/removes Claude Code hooks
│   │   └── EventProcessor.swift    # Watches events.jsonl, pairs sessions
│   ├── Data/
│   │   ├── DataStore.swift         # SQLite via GRDB, queries, maintenance
│   │   └── Models.swift            # WaitSession, DashboardData, HookEvent
│   ├── Notifications/
│   │   └── GrassNotifier.swift     # Touch grass notifications
│   ├── UI/
│   │   ├── DashboardBridge.swift   # Swift <-> WebView communication
│   │   └── ShareCardRenderer.swift # HTML -> PNG via WKWebView snapshot
│   └── Resources/
│       ├── dashboard.html          # Dashboard UI (HTML/CSS/JS)
│       └── Hook/
│           └── timespend-hook.sh   # Hook script installed into Claude Code
└── scripts/
    └── bundle-app.sh              # Creates .app bundle from SPM build
```

## Tech Stack

- **Swift 5.9+** with Swift Package Manager
- **AppKit** for menu bar and popover
- **WKWebView** for dashboard rendering
- **GRDB.swift** for SQLite (WAL mode, DatabasePool)
- **UNNotificationCenter** for touch grass alerts

## Data Storage

All data is stored locally at `~/Library/Application Support/TimeSpend/`:

| File | Purpose |
|------|---------|
| `data.db` | SQLite database with sessions and settings |
| `events.jsonl` | Raw hook events (rotated at 1MB) |
| `timespend-hook.sh` | Hook script called by Claude Code |

Sessions older than 90 days are automatically pruned on app launch.

## Privacy

- Claude is Thinking? **never** reads your terminal content or Claude Code conversations.
- It only records timestamps: when a prompt was sent and when a response finished.
- All data is stored locally. Nothing is sent anywhere.
- The share card is generated locally. Social sharing opens your browser, the image stays on your clipboard.

## Requirements

- macOS 13 (Ventura) or later
- Claude Code CLI installed
- No special permissions needed

## License

MIT
