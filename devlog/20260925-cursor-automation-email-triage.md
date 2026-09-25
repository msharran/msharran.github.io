---
layout: default
title: "Cursor Automation for Email Triage"
date: 2026-09-25
permalink: /devlog/20260925-cursor-automation-email-triage/
description: "First-draft notes on setting up a Cursor automation to triage my inbox."
---

# Cursor Automation for Email Triage

> Note: I consider these devlogs my personal journal of what I'm learning, so I won't be writing a full-fledged article here. Just learnings and thoughts concisely.

<!-- Draft goes here. Key points only, to expand later. -->

- Goal: use a Cursor automation with Gmail access to triage my inbox instead of doing it manually.
- Inbox is large and mostly unread today, so "triage" here means sorting/labeling, not answering everything.
- I already keep a small GTD-ish label set by hand — things like `@ACTION`, `@WAITING FOR`, and a few `Topic—*` labels — so a first automation pass could plug into that instead of inventing a new taxonomy.
- I haven't nailed down the exact automation yet (trigger, schedule, rules), so treating this as an intent post rather than a how-it-works post.

## Open questions / TODOs

- TODO: decide the trigger — scheduled sweep (e.g. daily) vs. running on new mail.
- TODO: define what "triage" actually does — label only? archive newsletters? flag anything needing a reply?
- TODO: confirm whether it reuses my existing labels (`@ACTION`, `@WAITING FOR`, `Topic—*`) or introduces new ones.
- TODO: decide how much autonomy it gets — can it archive/label without approval, or does it draft a plan first?
- TODO: figure out how to review/undo mistakes (mislabeled threads, missed important mail).

## What's next

- Actually stand up the automation and note the concrete setup (trigger, prompt, scope) once it exists.
- Run it for a bit before writing anything more detailed than this.
