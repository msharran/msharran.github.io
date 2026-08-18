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

## The target

Copy this into a Makefile next to `.claude/CLAUDE.md`. `make link-agent-guidance` writes the pointers. Hook it from `stow-link` if Stow owns the rest of the tree.

```makefile
AGENT_GUIDANCE_IMPORT := read @~/.claude/CLAUDE.md for user rules
AGENT_GUIDANCE_MD_FILES := \
	.config/zed/AGENTS.md \
	.config/amp/AGENT.md \
	.pi/agent/AGENTS.md \
	.codex/AGENTS.md \
	.gemini/GEMINI.md \
	.agents/AGENTS.md
AGENT_GUIDANCE_HOME_LINKS := \
	$(HOME)/.pi/agent/AGENTS.md \
	$(HOME)/.config/zed/AGENTS.md \
	$(HOME)/.config/amp/AGENT.md \
	$(HOME)/.codex/AGENTS.md \
	$(HOME)/.gemini/GEMINI.md \
	$(HOME)/.agents/AGENTS.md \
	$(HOME)/.cursor/rules/agents.mdc

.PHONY: link-agent-guidance
link-agent-guidance:
	@test -e .claude/CLAUDE.md || { echo "missing .claude/CLAUDE.md"; exit 1; }; \
	mkdir -p .codex .pi/agent .agents .cursor/rules "$(HOME)/.codex"; \
	for f in $(AGENT_GUIDANCE_MD_FILES); do \
		mkdir -p "$$(dirname "$$f")"; \
		rm -f "$$f"; \
		printf '%s\n' "$(AGENT_GUIDANCE_IMPORT)" > "$$f"; \
	done; \
	printf '%s\n' "---" "description: User rules imported from CLAUDE.md" "alwaysApply: true" "---" "" "$(AGENT_GUIDANCE_IMPORT)" > .cursor/rules/agents.mdc; \
	if [ -L "$(HOME)/.cursor/rules" ]; then rm -f "$(HOME)/.cursor/rules"; fi; \
	mkdir -p "$(HOME)/.cursor/rules"; \
	ln -sfn "$(CURDIR)/.codex/AGENTS.md" "$(HOME)/.codex/AGENTS.md"; \
	ln -sfn "$(CURDIR)/.cursor/rules/agents.mdc" "$(HOME)/.cursor/rules/agents.mdc"; \
	rm -f "$(HOME)/.cursor/AGENTS.md"; \
	for t in $(AGENT_GUIDANCE_HOME_LINKS); do \
		echo "LINK: $$t => $$(readlink "$$t" 2>/dev/null || { [ -e "$$t" ] && echo file || echo missing; })"; \
	done
```

Drop a path from `AGENT_GUIDANCE_MD_FILES` if you do not use that harness. Add extra `printf` lines in the recipe when a tool needs more than the import.

## Why this is KISS

- One file to edit: `CLAUDE.md`
- `make stow-link` regenerates the pointers, so I do not hand-maintain six copies
- A new harness is another path in the Makefile plus, if needed, a few extra lines in that one `printf`
- No relative-symlink math (`../../.claude/…` vs `../.claude/…`)

I moved off symlinks because this is smaller, and because I can add custom harness-specific instructions when a tool needs them. Cursor already does.
