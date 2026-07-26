---
layout: default
title: "Shelf Mac, Cloud Agents, Voice to Devlog"
date: 2026-07-26
permalink: /devlog/20260726-shelf-mac-cloud-agents-voice-to-devlog/
description: "How I run personal agents two ways — hybrid on a shelf MacBook Air and pure cloud on Cursor — and finally started publishing devlogs by voice."
---

# Shelf Mac, Cloud Agents, Voice to Devlog

> Note: I consider these devlogs my personal journal of what I'm learning, so I won't be writing a full-fledged article here. Just learnings and thoughts concisely.

I have a two-year-old. Side-project time is scarce now. I still had experiments I wanted to write about, but sitting down, drafting from scratch, wiring up a site, and publishing kept losing to everything else. The notes stayed in my head.

I stopped waiting for desk time and started running agents in two modes instead: **hybrid** (agent loop in the cloud, tools on my Mac) and **pure cloud** (the whole loop runs in a VM — no Mac required). I draft devlogs while my kid eats; I merge when I have ninety seconds.

## Two modes

| Mode | When I use it | What runs where |
|------|---------------|-----------------|
| **Hybrid** | Logged-in websites — Gmail, Drive, insurance portals | Agent loop in the cloud; Chrome, files, and tools on my Mac |
| **Pure cloud** | Devlogs, site work — nothing that needs my accounts | Entire agent loop + tools in a Cursor Cloud VM |

Hybrid is for tasks that need my real logins. Pure cloud is for shipping things where the agent does not need to touch my accounts.

## The shelf Mac

I have one personal machine: a MacBook Air. After my kid was born, it spent more than a year on a shelf. I use a company laptop for work; this Air is not my daily driver anymore.

Now it has one job. It sits on a shelf, always on, lid open, locked is fine. Cursor (and Codex before it) has a setting to keep the Mac available for remote agents — I turned that on and treat the Air like a small server. I am an SRE; managing a box that only runs agents is not a big deal. I connect the charger when I walk past the room and the battery is below 50%. Roughly every two days.

The Air runs [the agent Chrome setup I wrote about earlier](/devlog/20260726-giving-agent-a-separate-chrome/) — a dedicated profile on port 9222, same logins I need for real tasks. I do not use this laptop for anything else anymore. It exists so the agent has a browser and a filesystem.

## What I use hybrid for

### Insurance name transfer

I built this on Codex first. The same workflow runs on Cursor today — the harness changed, the shape did not.

I needed to transfer an insurance policy from the previous owner to my wife's name. The provider emailed back and forth. I set up a daily check at 10 a.m.: read the thread, see who replied, nudge with context if nothing moved.

When they asked for documents, the agent had access to my Drive and a skill that explains how I organize folders. It drafted the reply, attached the right files, and sent the email. It followed up every few days until the name transferred.

Then it read the revised policy, found a mistake, replied to the company, got a corrected version, saved the final document to Drive, and stopped the schedule.

The entire loop used my real Chrome — the same setup from [Giving Agent a Separate Chrome](/devlog/20260726-giving-agent-a-separate-chrome/). Not an isolated sandbox. Logged-in Gmail, logged-in Drive, logged-in portal. That is the point of hybrid.

I have similar automations on Cursor now. Nothing as involved yet, but the setup is the same. It works anywhere the agent can reach your tools.

## What I use pure cloud for

### Publishing devlogs by voice

For publishing, the Mac does not need to be on.

I speak what I want on my phone — rough notes, half-formed ideas, "write a devlog about X, match the tone of my first post." Cursor Cloud spins up a VM with a GUI and Chrome, drafts a PR, runs the site locally inside that VM, and attaches screenshots and video of how localhost looks to the conversation transcript. I review the markdown on mobile, suggest edits, iterate.

When it looks right, I merge from the Cursor mobile app in one click. GitHub Actions deploys to GitHub Pages within seconds.

I can see how the post will render before I approve the PR because the VM already recorded localhost in Chrome. Before this, the friction of writing and publishing was enough to keep me from starting. This workflow removed that.

## Why I moved: Amp → Codex → Cursor

I wanted a spending cap of about **$20 per month** (~₹2000). Not a hobby budget that drifts.

| Stop | What happened |
|------|----------------|
| **Amp** | Started with Amp Code. Loaded $20 — API tokens, gone quickly. When Amp moved to subscriptions, it was still token-based unless you linked another provider (e.g. Codex). Still exceeded my cap. **Orbs** — their cloud agent, run anything in the cloud without your laptop — was a nice idea. |
| **Codex** | ~$20/mo, generous for about two months. Limits exhausted often; I used free resets three or four times a month. **Model fatigue:** GPT 5.6 Sol vs Tera vs Luna, each with effort levels (high, xhigh, medium, low) — sometimes all three worked, but I spent energy deciding which to use. I also wanted open-weight models like Kimi K2 and GLM 5.2; no subscription home for that. Codex was good. I was happy. The cap and the choices wore me down. |
| **Cursor** | [SpaceXAI × Cursor Grok 4.5 launch](https://x.com/cursor_ai/status/2074915744999969059) put first-party models — **Composer 2.5** and Grok 4.5 — on Pro with better limits than third-party APIs. Cursor then [doubled quota again](https://x.com/cursor_ai/status/2079615536963485815) for Grok, Composer, and future hosted models. I picked Composer 2.5 (Kimi K2.5 lineage) and skipped Grok — frontier weight class, burns the pool faster. One default model, no daily model choice. Cancelled Codex, subscribed this month. Limits feel generous: ~2% used in two days, more throughput than my Codex peak. Composer 2.5 with fast mode off for now; if I still have quota at month-end, I will flip fast mode on and use the rest. Staying for a few months unless something breaks. |

The timing helped. I was already looking for a $20 home with one model I did not have to babysit. The [Grok 4.5 announcement](https://x.com/cursor_ai/status/2074915744999969059) made it clear Cursor was betting on its own model pool — not just reselling Claude and GPT. The [quota doubling](https://x.com/cursor_ai/status/2079615536963485815) made that pool feel sustainable for how I actually work.

Codex did not fail me. I left for predictable $20, one default model, and cloud agents that publish without waking the Mac.

## How the two modes fit together

```text
Phone (voice / review / merge)
        │
        ├─► Pure cloud ──► VM + Chrome + localhost video ──► PR ──► GitHub Pages
        │
        └─► Hybrid ──► cloud agent loop ──► shelf Mac (Chrome, Drive, Gmail)
```

- **Insurance, email, logged-in portals** → hybrid on the Air.
- **Devlogs, site deploys, anything account-free** → pure cloud from my phone.

Yesterday's post was about giving the agent a browser. This one is about putting that browser on a machine I no longer use — and about the cases where I do not need that machine at all.

## What's next

- Port more Codex-era automations to Cursor as they come up
- See if Composer limits hold through a full month at my actual usage
- Write more devlogs the same way — voice while feeding, merge when I have ninety seconds
