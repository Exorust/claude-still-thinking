#!/bin/bash
# Claude is Thinking? hook script - writes events to JSONL for tracking Claude Code wait time
# Called by Claude Code hooks. Arg 1: event type (prompt_start | response_end)
# Claude Code passes JSON context on stdin including session_id

EVENTS_DIR="$HOME/.timespend"
EVENTS_FILE="$EVENTS_DIR/events.jsonl"
EVENT_TYPE="${1:-unknown}"
PID=$$
TS=$(date +%s)

# Read session_id from stdin JSON (Claude Code passes context via stdin)
if command -v python3 &>/dev/null; then
    STDIN_JSON=$(cat)
    SESSION_ID=$(echo "$STDIN_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null)
fi
SESSION_ID="${SESSION_ID:-$$}"

# Get parent process start time for PID recycling detection (macOS)
PID_START=$(ps -o lstart= -p $PPID 2>/dev/null | xargs -I{} date -j -f "%c" "{}" "+%s" 2>/dev/null || echo "0")

# Ensure directory exists
mkdir -p "$EVENTS_DIR"

# Atomic append: single printf < PIPE_BUF (4096) is atomic on POSIX
printf '{"event":"%s","ts":%s,"session_id":"%s","pid":%s,"pid_start":%s}\n' \
    "$EVENT_TYPE" "$TS" "$SESSION_ID" "$PID" "$PID_START" >> "$EVENTS_FILE"
