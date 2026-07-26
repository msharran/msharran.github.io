---
layout: default
title: "Giving Agent a Separate Chrome"
date: 2026-07-26
permalink: /devlog/20260726-giving-agent-a-separate-chrome/
description: "How I use chrome-devtools MCP to give my agent and myself one shared Chrome — same profile, same logins, same window."
---

# Giving Agent a Separate Chrome

*One Chrome instance for me and my agent. Same profile, same logins, same tabs.*

I keep hitting the same wall with coding agents: the task needs a browser. Check email. Review a monthly statement. See if loyalty points transferred. Book a hotel room. The agent can write code all day, but the moment the work crosses into "open this URL and tell me what you see," things get awkward fast.

So I wired up [chrome-devtools MCP](https://github.com/ChromeDevTools/chrome-devtools-mcp) with a dedicated Chrome instance. Not a separate *browser* abstraction — a separate *Chrome*. One window that both I and the agent use.

## The idea

Most setups treat agent browser access as a sandbox. Isolated profile, no real logins, agent does its thing in a vacuum while you use normal Chrome separately.

I went the other way.

I launched Chrome on a debug port, logged into my accounts in that window, and started using it as my primary Chrome. Email. Social. A hotel loyalty portal. A shared household inbox for monthly statements. The agent connects to the same instance via MCP. We see the same Chrome, the same profile, the same sessions.

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
  /tmp/foo-chrome/profile
```

A login-time launcher starts Chrome automatically. The profile lives at `/tmp/foo-chrome/profile` — separate from whatever Chrome you had before, but once you log in there, that *becomes* your Chrome.

The harness connects through MCP with `--browser-url=http://127.0.0.1:9222`. Pre-starting Chrome and pointing MCP at the URL avoids the "Allow remote debugging?" prompt on every connection. A small launcher script polls up to 15 seconds for port 9222 after start, which killed an annoying race where MCP connected before Chrome was ready.

MCP config (merged into your harness MCP config):

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

Bootstrap on a new machine (macOS example):

```bash
# Install your dotfiles / launcher scripts however you manage them
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.foo.chrome-agent.plist
# Merge the MCP server block above into your harness config
start-agent-chrome   # log in once in the agent Chrome window
```

Verify:

```bash
curl -sf http://127.0.0.1:9222/json/version
```

The pattern is harness-agnostic — Cursor, Claude Code, or anything else with MCP support.

## What I actually use it for

These are not hypothetical. This is what I've been doing with it.

### Monthly spend report

Log into a shared household inbox. Find the latest monthly statement. Pull spend details from the last bill that was paid. Have the agent calculate a report — category breakdown, totals, anything worth flagging.

Before this setup, that meant me doing the email archaeology manually or copy-pasting into a chat. Now the agent opens the inbox in our shared Chrome, finds the statement, reads it, and does the math.

### Loyalty points and hotel booking

Log into a hotel loyalty portal. Check if points from a recent stay have posted. If they have, book rooms at a preferred property for an upcoming trip. I keep program and property names out of this post — the pattern matters more than the brand.

The agent handles the portal navigation. I watch it happen in the same window. If something looks wrong — wrong dates, wrong property — I intervene before it confirms.

### Day-to-day browsing

I've logged into the sites I use regularly in this Chrome instance. It's become my primary browser for personal tasks. The old default Chrome profile is fading out. I'll eventually stop launching it entirely and just use the agent's Chrome.

## Moving away from a legacy browser CLI

I used to maintain a second path: a browser-snapshot CLI that read copies of my everyday Chrome profiles. Different tool, different skill, different mental model.

I don't find a use case for it anymore.

The only thing that CLI still does that I occasionally reach for is screenshots. But Chrome DevTools MCP can take screenshots too. Once I'm fully confident in that, I'll drop it entirely and consolidate on `chrome-devtools-mcp`.

| Approach | Status |
|----------|--------|
| **chrome-devtools-mcp** | Primary — shared Chrome for me and the agent |
| **Legacy browser-snapshot CLI** | Screenshots only, eventually removed |

## Security posture

I know what you're thinking. Debug port. Agent reading cookies. Agent with full browser control.

Here's my threat model:

- My laptop is under lockdown. I always keep it locked.
- I only use it on personal Wi-Fi, or offline on the laptop itself.
- Port 9222 is bound to localhost. I am not exposing it anywhere outside my machine.

For my setup, that's acceptable. The agent profile has my real logins because I put them there. MCP clients can read cookies and page content in the attached browser — that's the point. Assume any local process on the machine can reach `127.0.0.1:9222`. I'm not running this on a shared machine or an untrusted network.

Your threat model may differ. Don't copy this blindly if you're on a corporate laptop or a network you don't control.

## Gotchas I hit along the way

**`--autoConnect` to everyday Chrome.** Chrome 136+ refuses `--remote-debugging-port` on the default user-data-dir. Dead end. The dedicated profile + `--browser-url` pattern sidesteps this.

**Port 9222 race.** MCP starts, Chrome hasn't bound the port yet, connection fails. Fixed with polling in the launcher script.

**Logins don't travel between machines.** Agent profile cookies are per-machine. Budget five minutes on each machine to sign into the sites you need.

**Shared state is a feature, not a bug.** If you leave a tab open, the agent sees it. If the agent navigates away, you see that. Plan for it.

## What's next

This setup is stable enough that I'm using it daily. The agent and I share one Chrome, and that works better than I expected.

Next steps for me:

- Stop launching my old default Chrome entirely
- Drop the legacy browser CLI once screenshots via DevTools MCP cover everything I need
- Maybe write up the hotel booking flow as a concrete recipe once I've done it a few more times
