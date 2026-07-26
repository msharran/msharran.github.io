---
layout: default
title: "Giving Agents a Browser: My chrome-* Skills Setup"
date: 2026-07-26
permalink: /devlog/20260726-giving-agents-a-browser-chrome-skills-setup/
description: "Two complementary Chrome skills for agent harnesses — DevTools MCP on a dedicated profile, and real work/play sessions via agent-browser."
---

# Giving Agents a Browser: My chrome-* Skills Setup

*How I wired up browser automation for Cursor and Claude Code without permission prompts, and without giving up my real logged-in sessions.*

I keep hitting the same wall with coding agents: the task needs a browser. Check a gated dashboard. Pull a PDF from Drive. Read a Slack thread. Verify a deploy preview. The agent can write code all day, but the moment the work crosses into "open this URL and tell me what you see," things get awkward fast.

So I spent a few sessions wiring up Chrome for my agent harnesses. The result is two skills under a `chrome-*` naming convention, both managed in my dotfiles and stowed to `~/.claude/skills/`:

| Skill | What it does |
|-------|--------------|
| **chrome-devtools-mcp** | DevTools MCP automation on a **dedicated agent Chrome profile** |
| **chrome-agent-browser** | My **real work/play Chrome** sessions via the `agent-browser` CLI |

They sound similar. They are not. One is an isolated sandbox the agent owns. The other is me, authenticated, with cookies that already exist.

## The problem I was solving

Agents need browser access for three broad reasons:

1. **Automation and debugging** — navigate, screenshot, inspect DOM, read network traces, run performance profiles.
2. **Authenticated reads** — dashboards behind Pritunl Zero, email, Slack, Google Drive, internal status pages.
3. **Repeatability across machines** — same setup on personal and work laptops without re-documenting everything every time.

The naive approaches break down quickly:

- **`--autoConnect` to your everyday Chrome** — Chrome 136+ refuses `--remote-debugging-port` on the default user-data-dir. Dead end.
- **Bundled Chromium from `agent-browser`** — looks logged out even when your session is on disk. Chromium decrypts cookies with a different macOS Keychain key than Google Chrome ("Chromium Safe Storage" vs "Google Chrome Safe Storage"). Silent failure. You land on the login gate every time.
- **Starting MCP before Chrome binds port 9222** — race condition. MCP connects, Chrome isn't ready yet, everything fails until you retry manually.

I wanted one setup that handles automation cleanly *and* a separate path for "use my actual cookies when I need them."

## Architecture: two browsers, two skills

```text
┌─────────────────────────────────────────────────────────────┐
│  Agent harness (Cursor, Claude Code, …)                     │
└───────────────┬─────────────────────────┬───────────────────┘
                │                         │
                ▼                         ▼
   chrome-devtools-mcp              chrome-agent-browser
   (MCP server)                     (agent-browser CLI)
                │                         │
                ▼                         ▼
   localhost:9222                   work / play profile
   dedicated agent profile          (read-only snapshot)
   ~/.cache/chrome-devtools-mcp/    real Google Chrome binary
   agent-profile
```

### chrome-devtools-mcp — the agent's own browser

This is the default path for "drive a browser through DevTools."

A dedicated Chrome instance runs at login via a LaunchAgent (`com.msharran.chrome-agent`). It uses its own profile at `~/.cache/chrome-devtools-mcp/agent-profile` — separate from my everyday browsing. Debug port `9222` is bound to localhost only.

The harness connects through [chrome-devtools MCP](https://github.com/ChromeDevTools/chrome-devtools-mcp) with `--browser-url=http://127.0.0.1:9222`. Critically, this is **not** `--autoConnect`. Pre-starting Chrome and pointing MCP at the URL avoids the "Allow remote debugging?" prompt on every connection.

I log into sites once in that agent window. Cookies persist across restarts. They do **not** sync between laptops — each machine gets its own one-time login.

MCP config example (merged into `~/.cursor/mcp.json` or added via `claude mcp add`):

```json
"chrome-devtools-mcp": {
  "command": "npx",
  "args": [
    "-y",
    "chrome-devtools-mcp@latest",
    "--browser-url=http://127.0.0.1:9222"
  ]
}
```

The launcher script `chrome-agent-profile` now polls up to 15 seconds for port 9222 after background start. Small change, but it killed a annoying class of "MCP failed immediately" races.

### chrome-agent-browser — my real sessions

Sometimes the agent profile is the wrong tool. I need **my** cookies — the work profile for `~/root/work/*` projects, the play profile for `~/root/play/*`.

That's what `agent-browser` is for. The skill encodes the non-obvious parts:

1. **Always use the real Google Chrome binary**, not the bundled Chromium:

   ```bash
   --executable-path "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
   ```

2. **Pick the profile from the project path** — work vs play, confirmed via `agent-browser profiles`.

3. **Close the daemon before switching profiles.** `agent-browser` pins profile and executable from its first launch. A stale daemon silently ignores later `--profile` flags. You think you're on work Chrome; you're on whatever launched first.

   ```bash
   agent-browser close
   agent-browser --executable-path "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
     --profile "<work|play label>" open "<URL>"
   ```

4. **Quitting my real Chrome is not required.** `--profile` uses a read-only snapshot of the profile directory. Persistent cookies (Pritunl Zero sessions, etc.) get flushed to disk and show up in the snapshot.

This skill does not prescribe what to do once you're in. The user says "check my email" or "download this PDF from Drive" — the skill just gets the agent to the right authenticated page.

## Why the `chrome-*` rename

I had two older skills with inconsistent names: `chrome-devtools` and `agent-browser-chrome`. Merged to dotfiles `main` on 2026-07-26 ([commit `82a6b1f`](https://github.com/msharran/.dotfiles-private/commit/82a6b1f7c57f8032cb8ac2e2c99d91ae4653728d)):

| Before | After |
|--------|-------|
| `chrome-devtools` | **chrome-devtools-mcp** |
| `agent-browser-chrome` | **chrome-agent-browser** |

The `chrome-*` prefix makes it obvious these are related browser skills, and the suffix tells you *which mechanism* each one uses. Harness-agnostic setup docs moved to `docs/chrome-devtools-setup.md` so I'm not maintaining separate Cursor-only instructions.

## Bootstrap on a new machine

Abbreviated version — full steps live in my dotfiles setup doc.

```bash
cd ~/.dotfiles-private && make install
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.msharran.chrome-agent.plist
# Merge config/chrome-devtools-mcp.json into harness MCP config
chrome-agent-profile   # log in once in the agent Chrome window
```

Verify:

```bash
curl -sf http://127.0.0.1:9222/json/version
```

Then ask the agent to smoke-test DevTools MCP. For authenticated work/play access, test `agent-browser` against a gated URL you know is logged in.

## When to use which

| I need… | Skill |
|---------|-------|
| DOM inspection, network tab, performance traces, screenshots on arbitrary sites | **chrome-devtools-mcp** |
| No permission prompts; isolated agent profile | **chrome-devtools-mcp** |
| My existing work/play login (Slack, email, Pritunl dashboards, Drive) | **chrome-agent-browser** |
| Download a file from an authenticated portal | **chrome-agent-browser** |

If I reach for DevTools MCP when I actually need my real cookies, I waste time logging into things I already have sessions for. If I reach for `agent-browser` when I just need to debug a public page's network waterfall, I'm overcomplicating it.

## Gotchas I actually hit

**Chromium vs Chrome Keychain.** This one took a while. `agent-browser` ships Chromium. Your cookies were sealed with Chrome's Keychain key. Without `--executable-path`, every gated page looks logged out. No error, just a login gate.

**Stale daemon.** Switching work → play without `agent-browser close` means the second command's `--profile` is ignored. You get a warning in stderr if you're paying attention. Usually you're not, and you wonder why Pritunl Zero is asking you to log in again.

**Chrome 136+ and default profile debugging.** `--remote-debugging-port` on the normal user-data-dir is blocked. The dedicated agent profile + `--browser-url` pattern sidesteps this entirely.

**Port 9222 race.** MCP starts, Chrome hasn't bound the port yet, connection fails. Fixed with polling in `chrome-agent-profile`.

**Logins don't travel.** Agent profile cookies are per-machine. Budget five minutes on each laptop to sign into the sites your agents need.

## Security notes (brief)

- Debug port is localhost only. Don't expose 9222 on the network.
- Agent profile is isolated from Default Chrome and work/play profiles.
- MCP clients can read cookies and page content in the attached browser. That's the point, but worth remembering.

For remote viewing (e.g. checking the agent Chrome window from iOS), I use Chrome Remote Desktop — not port forwarding.

## What's next

This setup is stable enough that I'm using it daily. The skills are doing their job: tell the agent *how* to get browser access, not *what* to do once it's there.

I might write a follow-up on specific `agent-browser` recipes — Google Drive downloads, Slack thread reads, gated dashboard verification — but the plumbing is in place.

---

*Canonical setup guide: `~/.dotfiles-private/docs/chrome-devtools-setup.md`. Wiki notes: [Chrome DevTools Agent Browser](https://github.com/msharran/wiki-personal/blob/main/wiki/guides/chrome-devtools-agent-browser.md).*
