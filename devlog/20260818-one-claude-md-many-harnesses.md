---
layout: default
title: "One CLAUDE.md, Many Harnesses"
date: 2026-08-18
permalink: /devlog/20260818-one-claude-md-many-harnesses/
description: "One CLAUDE.md, and a Makefile target that writes a one-line import into each harness instruction file."
---

# One CLAUDE.md, Many Harnesses

> Note: I consider these devlogs my personal journal of what I'm learning, so I won't be writing a full-fledged article here. Just learnings and thoughts concisely.

User rules live in `~/.claude/CLAUDE.md`. Cursor, Codex, Amp, Gemini, Pi, Zed, and the generic Agents tree each want their own instruction file, with a different name in a different directory.

This is how that is set up. `make stow-link` runs `link-agent-guidance`, which writes small import files that point at `CLAUDE.md`.

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

Today the generator is dumb: `rm` + `printf >` replaces those files on every `make link-agent-guidance`. Do not put custom text in them. Shared rules live in `CLAUDE.md`.

The state I want is templatized generation (Jinja, or something like it) so a harness can have extra lines without hand-editing the output. Cursor already needs `alwaysApply: true` frontmatter on `.cursor/rules/agents.mdc`. That is still a second `printf` in the recipe, not a template. Later.

Most of those paths Stow into `$HOME`. Codex and Cursor get an extra `ln -sfn` because those home dirs already exist as real directories.

## The target

Copy this into a Makefile next to `.claude/CLAUDE.md`. Hook it from `stow-link` if Stow owns the rest of the tree. Drop a path from `AGENT_GUIDANCE_MD_FILES` if you do not use that harness.

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
