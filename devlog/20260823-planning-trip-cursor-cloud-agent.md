---
layout: default
title: "Planning a Trip from a Cursor Cloud Agent"
date: 2026-08-23
permalink: /devlog/20260823-planning-trip-cursor-cloud-agent/
description: "Wiki as state, Drive as docs, Gmail as the action bus — a family itinerary treated like a small production system."
---

# Planning a Trip from a Cursor Cloud Agent

> Note: I consider these devlogs my personal journal of what I'm learning, so I won't be writing a full-fledged article here. Just learnings and thoughts concisely.

A family trip to Delhi and Agra is not a chat. Rates move. Tickets get misnamed. Hotels want the booking mailbox, not mine. If the agent only remembers in the thread, the next run starts from rumours.

So I ran it the way I run a small system: a Cursor Cloud Agent, a git wiki as the control plane, Drive as the blob store, Gmail as the action bus. I steer from the phone. The Mac only wakes when something needs a logged-in browser.

PII stays out of this post and out of the wiki body. Tickets, IDs, and barcodes live in Drive.

## The shape

```text
Phone (prompt / review)
        │
        ▼
Cursor Cloud Agent
        │
        ├── wiki/                 git  — dated state
        │     entities/           living decision log
        │     analyses/           one research artifact per question
        │     sources/            ingested confirmations
        │
        ├── Drive MCP             PDFs, tickets   (PII stays here)
        ├── Gmail MCP             draft → send → wait
        └── Chrome (shelf Mac)    OTP, loyalty cart, hotel site
```

| Layer | Job | What it is not |
|---|---|---|
| **Wiki** | Control plane. Dated. Linked. Lintable. | A chat summary. |
| **Drive** | Canonical files. Inventory only in git. | Something to paste into markdown. |
| **Gmail** | Side effects. Right mailbox. Draft first. | The system of record. |
| **Chrome** | Live cart / OTP. Hybrid on the [shelf Mac](/devlog/20260726-shelf-mac-cloud-agents-voice-to-devlog/). | A scraper of public rates. |

Same split I already use: **pure cloud** writes the wiki. **Hybrid** touches logged-in portals. The trip just used both in one loop.

## State is a decision log, not an answer

Hotel research does not flatten into "book X". It appends a dated entry and a separate analysis page. Next run reads the entity first, then the latest analysis, then Drive — never the other way around.

```markdown
### 2026-07-20 — remaining-points scenario
- Agra transfer still uncredited. Do not spend the same miles twice.
- Public rate ≠ cart. Next gate is a signed-in, simultaneous 3-room check.
- Airport-side hotel wins on points. Central wins on walking. Record both.
```

Points math is a function, not a vibe. Club-program reward nights are whole nights, not a rupee credit:

```text
reward_nights = floor(points / cost_per_room_night)
cash_nights   = rooms * nights - reward_nights
cash_due      = cash_nights * member_rate   # taxes extra, always
```

The leftover after Agra is a *constraint* on the Delhi cart, not a second transfer. That distinction only survives if you write it down with a date.

## Read the file. Do not trust the filename.

Drive MCP is the source. The wiki stores a category inventory — "2 train PDFs" — not the PDFs.

```text
search_files
  query: title contains 'Agra' and mimeType = 'application/pdf'
```

One PDF was named for train A. The ERS inside was train B, later the same day, different station window. Cab research that followed the filename would have missed the train.

```text
filename:  ...-<daytime-express>-<date>.pdf
ERS:       <night-express>  depart 21:00
checkout:  12:00
gap:       hold bags, wait on property, cab ~19:30–20:00
```

That is a lint finding, not a silent overwrite. Filename stays (Drive is canonical). Wiki flags the contradiction. Open questions keep the toddler-on-the-ticket gap.

## Gmail is the action bus

Hotel mail has to leave the booking mailbox. The agent drafts, I look, then it sends. The wiki files the sent message as a source and marks the reply **waiting**.

```text
create_draft
  from: <booking mailbox>
  to:   reservations@<hotel>
  cc:   <me>
  subject: early check-in + toddler meal — <dates>

  Can kitchen do plain khichdi and milk as a courtesy, not room service?
  Morning arrival; standard check-in is 15:00. Even one room by noon helps.
  Party includes 50+ adults — do not call them senior citizens.
```

No confirmation numbers in the mail unless we have them. No identity docs attached. After send: source page + "reply pending". A later run searches the thread instead of guessing.

## What I actually got out of this

Not a prettier itinerary. A system that does not forget the last cart check.

- **Ingest** a confirmation → source page + entity bump + log line.
- **Query** "what is still open?" → open booking checks, not a new web search.
- **Lint** → filename ≠ ticket, public rate ≠ cart, points already spent.

The agent is disposable. The wiki is not. That is the whole design.
