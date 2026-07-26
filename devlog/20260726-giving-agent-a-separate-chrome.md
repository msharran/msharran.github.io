---
layout: default
title: "Giving Agent a Separate Chrome"
date: 2026-07-26
permalink: /devlog/20260726-giving-agent-a-separate-chrome/
description: "How I use chrome-devtools MCP to give my agent and myself one shared Chrome — same profile, same logins, same window."
---

# Giving Agent a Separate Chrome

*One Chrome instance for me and my agent. Same profile, same logins, same tabs.*

I keep hitting the same wall with coding agents: the task needs a browser. Check email. Read a credit card statement. See if loyalty points transferred. Book a hotel room. The agent can write code all day, but the moment the work crosses into "open this URL and tell me what you see," things get awkward fast.

So I wired up [chrome-devtools MCP](https://github.com/ChromeDevTools/chrome-devtools-mcp) with a dedicated Chrome instance. Not a separate *browser* abstraction — a separate *Chrome*. One window that both I and the agent use.

## The idea

Most setups treat agent browser access as a sandbox. Isolated profile, no real logins, agent does its thing in a vacuum while you use normal Chrome separately.

I went the other way.

I launched Chrome on a debug port, logged into my accounts in that window, and started using it as my primary Chrome. Gmail. Twitter. Club ITC. My wife's email for credit card statements. The agent connects to the same instance via MCP. We see the same Chrome, the same profile, the same sessions.

When the agent navigates somewhere, I see it. When I click around, the agent sees that state on the next MCP call. That's intentional — I want full visibility into what the agent is doing, and I want the agent operating in a Chrome I actually use.

## How it works

```text
Me + Agent (Cursor, Claude Code, …)
        │
        ▼
  chrome-devtools MCP
  (--browser-url=http://127.0.0.1:9222)
        │
        ▼
  localhost:9222
        │
        ▼
  Chrome (agent profile)
  ~/.cache/chrome-devtools-mcp/agent-profile
```

A LaunchAgent (`com.msharran.chrome-agent`) starts Chrome at login. The profile lives at `~/.cache/chrome-devtools-mcp/agent-profile` — separate from whatever Chrome you had before, but once you log in there, that *becomes* your Chrome.

The harness connects through MCP with `--browser-url=http://127.0.0.1:9222`. Pre-starting Chrome and pointing MCP at the URL avoids the "Allow remote debugging?" prompt on every connection. The launcher script `chrome-agent-profile` polls up to 15 seconds for port 9222 after start, which killed an annoying race where MCP connected before Chrome was ready.

MCP config (merged into `~/.cursor/mcp.json` or added via `claude mcp add`):

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

Bootstrap on a new machine:

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

Full setup guide: `~/.dotfiles-private/docs/chrome-devtools-setup.md`.

## What I actually use it for

These are not hypothetical. This is what I've been doing with it.

### Credit card spend report

Log into my wife's Gmail. Find the latest credit card statement email. Pull the spend details from the last bill that was paid. Have the agent calculate a report — category breakdown, totals, anything worth flagging.

Before this setup, that meant me doing the email archaeology manually or copy-pasting into a chat. Now the agent opens Gmail in our shared Chrome, finds the statement, reads it, and does the math.

### Club ITC points and hotel booking

Log into the Club ITC portal. Check if my points have transferred from a recent stay. If they have, book two standard rooms at ITC Maurya or ITC Mughal in Agra for two nights.

The agent handles the portal navigation. I watch it happen in the same window. If something looks wrong — wrong dates, wrong property — I intervene before it confirms.

### Day-to-day browsing

I've logged into Gmail, Twitter, and the other sites I use regularly in this Chrome instance. It's become my primary browser for personal tasks. The old default Chrome profile is fading out. I'll eventually stop launching it entirely and just use the agent's Chrome.

## Moving away from agent-browser

I used to maintain a second path: `agent-browser` with a read-only snapshot of my work/play Chrome profiles. Different tool, different skill, different mental model.

I don't find a use case for it anymore.

The only thing `agent-browser` still does that I occasionally reach for is screenshots. But Chrome DevTools MCP can take screenshots too. Once I'm fully confident in that, I'll drop `agent-browser` entirely and consolidate on `chrome-devtools-mcp`.

The `chrome-*` skill naming in my dotfiles reflects this direction:

| Skill | Status |
|-------|--------|
| **chrome-devtools-mcp** | Primary — shared Chrome for me and the agent |
| **chrome-agent-browser** | Legacy — screenshots only, eventually removed |

## Security posture

I know what you're thinking. Debug port. Agent reading cookies. Agent with full browser control.

Here's my threat model:

- My laptop is under lockdown. I always keep it locked.
- I only use it on personal Wi-Fi, or offline on the laptop itself.
- Port 9222 is bound to localhost. I am not exposing it anywhere outside my machine.

For my setup, that's acceptable. The agent profile has my real logins because I put them there. MCP clients can read cookies and page content in the attached browser — that's the point. I'm not running this on a shared machine or an untrusted network.

Your threat model may differ. Don't copy this blindly if you're on a corporate laptop or a network you don't control.

## Gotchas I hit along the way

**`--autoConnect` to everyday Chrome.** Chrome 136+ refuses `--remote-debugging-port` on the default user-data-dir. Dead end. The dedicated profile + `--browser-url` pattern sidesteps this.

**Port 9222 race.** MCP starts, Chrome hasn't bound the port yet, connection fails. Fixed with polling in `chrome-agent-profile`.

**Logins don't travel between laptops.** Agent profile cookies are per-machine. Budget five minutes on each laptop to sign into the sites you need.

**Shared state is a feature, not a bug.** If you leave a tab open, the agent sees it. If the agent navigates away, you see that. Plan for it.

## What's next

This setup is stable enough that I'm using it daily. The agent and I share one Chrome, and that works better than I expected.

Next steps for me:

- Stop launching my old default Chrome entirely
- Drop the `chrome-agent-browser` skill once screenshots via DevTools MCP cover everything I need
- Maybe write up the Club ITC booking flow as a concrete recipe once I've done it a few more times

---

*Setup guide: `~/.dotfiles-private/docs/chrome-devtools-setup.md`. Skill: `~/.claude/skills/chrome-devtools-mcp/SKILL.md`.*
