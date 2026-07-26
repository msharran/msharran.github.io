---
layout: default
title: "Giving Agent a Separate Chrome"
date: 2026-07-26
permalink: /devlog/20260726-giving-agent-a-separate-chrome/
description: "How I wired chrome-devtools MCP to a dedicated Chrome on port 9222 so my agent and I share one profile and one window."
---

# Giving Agent a Separate Chrome

> Note: I consider these devlogs my personal journal of what I'm learning, so I won't be writing a full-fledged article here. Just learnings and thoughts concisely.

I keep running into tasks where the agent needs a browser. Not "scrape a public docs page" — actual logged-in stuff. Check a shared household inbox for a monthly statement. See if loyalty points posted. Book a hotel room. The agent can write code fine, but once the work is "open this URL and tell me what you see," everything gets awkward.

So I set up [chrome-devtools MCP](https://github.com/ChromeDevTools/chrome-devtools-mcp) against a dedicated Chrome instance. Not a separate browser abstraction. A separate Chrome window that I also use day to day.

## Why I did this

Most setups give the agent an isolated profile. Clean sandbox, no real logins, agent does its thing while you use normal Chrome separately.

I did not want that.

I wanted the agent operating in a Chrome I actually use. Full visibility into what it is doing. Same sessions, same logins, same tabs. When the agent navigates somewhere, I see it. When I click around, the agent sees that state on the next MCP call. That part is intentional.

## The setup

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

A login-time launcher starts Chrome automatically. Profile lives at `/tmp/foo-chrome/profile` — separate from whatever Chrome I used before, but once I log in there, that becomes my Chrome.

The harness connects through MCP with `--browser-url=http://127.0.0.1:9222`. I pre-start Chrome and point MCP at the URL so I do not get the "Allow remote debugging?" prompt on every connection. The launcher script polls up to 15 seconds for port 9222 after start. That fixed a race where MCP connected before Chrome was ready.

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

Works with Cursor, Claude Code, or anything else with MCP support.

## What I use it for

### Monthly spend report

Log into a shared household inbox. Find the latest monthly statement. Pull spend details from the last bill that was paid. Have the agent calculate a report — category breakdown, totals, anything worth flagging.

Before this, I did the email archaeology myself or copy-pasted into chat. Now the agent opens the inbox in our shared Chrome, finds the statement, reads it, does the math.

### Loyalty points and hotel booking

Log into a hotel loyalty portal. Check if points from a recent stay posted. If they did, book rooms at a preferred property for an upcoming trip.

The agent handles portal navigation. I watch in the same window. If something looks wrong — wrong dates, wrong property — I intervene before it confirms.

### Day-to-day browsing

I've logged into the sites I use regularly in this Chrome instance. It has become my primary browser for personal tasks. The old default Chrome profile is fading out. Eventually I'll stop launching it entirely.

## Moving away from a legacy browser CLI

I used to maintain a second path: a browser-snapshot CLI that read copies of my everyday Chrome profiles. Different tool, different skill, different mental model.

I don't find a use case for it anymore.

The only thing that CLI still does that I occasionally reach for is screenshots. Chrome DevTools MCP can take screenshots too. Once I'm confident in that, I'll drop it entirely and consolidate on `chrome-devtools-mcp`.

| Approach | Status |
|----------|--------|
| chrome-devtools-mcp | Primary — shared Chrome for me and the agent |
| Legacy browser-snapshot CLI | Screenshots only, eventually removed |

## Gotchas

**`--autoConnect` to everyday Chrome.** Chrome 136+ refuses `--remote-debugging-port` on the default user-data-dir. Dead end for me. The dedicated profile + `--browser-url` pattern sidesteps this.

**Port 9222 race.** MCP starts, Chrome hasn't bound the port yet, connection fails. Polling in the launcher script fixed it.

**Logins don't travel between machines.** Agent profile cookies are per-machine. I budget five minutes on each machine to sign into the sites I need.

**Shared state.** If I leave a tab open, the agent sees it. If the agent navigates away, I see that. I had to get used to that — it's what I wanted, but it's still a gotcha when you forget.

**localhost only.** Port 9222 is bound to localhost on my machine. I only use this on my personal laptop, on Wi-Fi I trust. Any local process can reach `127.0.0.1:9222` if it tries. Fine for my setup; probably not what you want on a shared or corporate machine.

## What's next

This setup is stable enough that I'm using it daily. The agent and I share one Chrome, and that works better than I expected.

- Stop launching my old default Chrome entirely
- Drop the legacy browser CLI once screenshots via DevTools MCP cover everything I need
- Maybe write up the hotel booking flow once I've done it a few more times
