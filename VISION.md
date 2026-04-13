# Claude Still Thinking?: Vision

## The Problem

Developers using Claude Code spend hours every day waiting for AI responses. But nobody knows how much time that actually is. There's no metric for it. No dashboard. No way to say "I spent 4 hours waiting for Claude Code this week" with any confidence.

The result is a vague feeling of lost time with no data to back it up.

## The Insight

Three things make this worth building:

**The number itself.** Seeing "you waited 3 hours and 47 minutes for Claude Code today" is visceral. Everyone who uses Claude Code will want to know their number.

**The notification.** A popup that says "You've been waiting for AI for 45 minutes today. Your houseplants miss you." Wellness advice wrapped in humor. The kind of thing people screenshot.

**The shareable card.** A clean stat card you can export and post. "I spent 6.2 hours this week waiting for Claude Code." This is the viral loop. The card IS the marketing.

## How It Works

Claude Still Thinking? is a macOS menu bar app. It installs a hook into Claude Code that fires events when you submit a prompt and when Claude finishes responding. The app watches those events, tracks the time, and shows you the data.

No process monitoring. No accessibility permissions. No heuristics. Just hooks and timestamps. 100% accurate.

## What It Does

- **Menu bar timer**: Shows a live countdown while Claude Code is thinking. Icon only when idle.
- **Dashboard**: Click the menu bar icon to see today's total, a weekly chart, average wait times, longest session, and recent activity.
- **Share cards**: Generate a clean PNG stat card showing your wait time. Share to Twitter, LinkedIn, Bluesky, Threads, or save it.
- **Touch grass notifications**: Configurable reminders when your daily wait time exceeds a threshold. Rotating messages with personality.

## What It Doesn't Do

- Read your terminal content. Ever. Only timestamps.
- Require accessibility permissions or full disk access.
- Run as an Electron app. It's native Swift, ~85MB memory.
- Phone home. All data stays on your Mac in a local SQLite database.

## Architecture

Native Swift menu bar shell. WKWebView for the dashboard (HTML/CSS/JS renders faster and prettier than SwiftUI for charts). SQLite via GRDB for storage. Claude Code hooks for event detection.

The hard part (detection) is native. The pretty part (dashboard, share cards) is web. Best of both.

## Distribution

- GitHub Releases: Signed .dmg, universal binary (ARM + Intel)
- Homebrew: `brew install --cask time-spend`
- Auto-update via Sparkle framework

Not on the Mac App Store. Sandboxing would block hook installation.

## Growth

The share card is the growth engine. When someone posts "I spent 18 hours waiting for Claude Code this week" with a clean stat card, every developer who sees it wants to know their own number.

The touch grass notification is the screenshot moment. "Claude has been thinking for 32 minutes today. Your houseplants miss you." is the kind of notification people post for the joke.

The app doesn't need a marketing budget. The data is inherently shareable because it's surprising, personal, and slightly horrifying.

## Roadmap

**v1 (now):** Claude Code only. macOS only. Core timer, dashboard, share cards, touch grass notifications.

**v1.1:** Milestone celebrations ("New record!"), more share card designs, daily/weekly email digest.

**v1.2:** Multi-AI tracking. Cursor, Copilot, Windsurf. The `ai_tool` column is already in the database.

**v2:** Cross-platform (Tauri). Leaderboards (opt-in). Team dashboards. "Our team spent 847 hours waiting for AI this quarter."

## Principles

1. **Invisible until useful.** No dock icon. No startup splash. Just a timer icon that shows your number when you want it.
2. **Accurate or nothing.** Hooks give exact timestamps. No "approximately" or "estimated." If the number is wrong, the app is worthless.
3. **Fun, not guilt.** The tone is self-aware humor, not productivity shaming. "Go touch grass" not "you're wasting time."
4. **Privacy by default.** Local data only. No accounts. No telemetry. The share card is opt-in, everything else is private.
5. **Lightweight.** If the app that measures your waiting time makes you wait, something has gone wrong.
