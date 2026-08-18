---
layout: default
title: "One CLAUDE.md, Many Harnesses"
date: 2026-08-18
permalink: /devlog/20260818-one-claude-md-many-harnesses/
description: "I stopped symlink'ing every agent file to CLAUDE.md. make writes a one-line import instead, so each harness can grow its own extras."
---

# One CLAUDE.md, Many Harnesses

> Note: I consider these devlogs my personal journal of what I'm learning, so I won't be writing a full-fledged article here. Just learnings and thoughts concisely.

I keep user rules in one file: `~/.claude/CLAUDE.md`. Cursor, Codex, Amp, Gemini, Pi, Zed, and the generic Agents tree all want their own instruction file, with a different name in a different directory.

Same day as the [2 → 1 dotfiles merge](/devlog/20260818-two-to-one-dotfiles-cursor-cloud-agents/). `make stow-link` in the private tree now generates those files. It does not symlink them.

## What I used to do

The Makefile pointed every harness file at the same inode:

```bash
ln -sfn ../../.claude/CLAUDE.md .config/zed/AGENTS.md
ln -sfn ../../.claude/CLAUDE.md .config/amp/AGENT.md
ln -sfn ../.claude/CLAUDE.md .codex/AGENTS.md
# …
```

Simple until it was not. A symlink is the same file. Cursor wants YAML frontmatter (`alwaysApply: true`). The next harness will want a line that the others should not see. A symlink cannot do that without forking the source.

`~/.codex` and `~/.cursor` are also real directories on this machine, not Stow packages. Extra home links on top of CLAUDE.md symlinks got messy.

## What `make` writes now

`make install` → `stow-link` → `link-agent-guidance`. One source of truth, many tiny pointers:

```text
~/.claude/CLAUDE.md
        ▲
        │  read @~/.claude/CLAUDE.md for user rules
        │
.config/zed/AGENTS.md
.config/amp/AGENT.md
.pi/agent/AGENTS.md
.codex/AGENTS.md
.gemini/GEMINI.md
.agents/AGENTS.md
.cursor/rules/agents.mdc
```

Each markdown file is one line:

```text
read @~/.claude/CLAUDE.md for user rules
```

Cursor is the extra. `.cursor/rules/agents.mdc` gets frontmatter so the rule always loads, then the same import line. That is the whole point of not symlink'ing: harness-specific bits live in the generated file, shared rules stay in `CLAUDE.md`.

Most of those paths Stow into `$HOME`. Codex and Cursor get an extra `ln -sfn` because those home dirs already exist as real directories.

## Why this is KISS

- One file to edit: `CLAUDE.md`
- `make stow-link` regenerates the pointers, so I do not hand-maintain six copies
- A new harness is another path in the Makefile plus, if needed, a few extra lines in that one `printf`
- No relative-symlink math (`../../.claude/…` vs `../.claude/…`)

I moved off symlinks because this is smaller, and because I can add custom harness-specific instructions when a tool needs them. Cursor already does.
