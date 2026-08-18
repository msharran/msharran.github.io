---
layout: default
title: "2 → 1 Dotfiles, Done with Cursor Cloud Agents"
date: 2026-08-18
permalink: /devlog/20260818-two-to-one-dotfiles-cursor-cloud-agents/
description: "How I collapsed a public/private GNU Stow split into one private repo — steered from a Cursor cloud VM, because the Mac still had the old tree stowed."
---

# 2 → 1 Dotfiles, Done with Cursor Cloud Agents

> Note: I consider these devlogs my personal journal of what I'm learning, so I won't be writing a full-fledged article here. Just learnings and thoughts concisely.

I had two GNU Stow trees. One public, one private. The split was supposed to keep secrets out of GitHub. In practice it meant two clones, two `make install`s, and a public history of nvim/tmux/kitty that did not need to be public.

I did not do the merge on the Mac. That machine still had `~/.dotfiles` stowed. I used the [pure-cloud path](/devlog/20260726-shelf-mac-cloud-agents-voice-to-devlog/): a Cursor cloud agent with both repos checked out, steered over chat, on 18 Aug 2026.

The public GitHub repo is archived and private now. Everything lives in the private tree.

## The split that existed

| | Public | Private |
|---|---|---|
| Repo | `msharran/.dotfiles` (`master`) | `msharran/.dotfiles-private` (`main`) |
| Home path | `~/.dotfiles` | `~/.dotfiles-private` |
| What lived there | nvim, tmux, kitty, ghostty, k9s, sbin helpers, terminfo | fish, zed, jj, git-crypt secrets, agent tooling |
| Stow | GNU Stow into `$HOME` | GNU Stow into `$HOME` |

Goal of the run: **one private repo**, a sunset of the public one, and a one-shot path for the machine that still has the public clone linked.

```text
~/.dotfiles  (stowed)     ~/.dotfiles-private (stowed)
        │                            │
        └──────── absorb once ───────┘
                         │
                         ▼
              ~/.dotfiles-private only
              ~/.dotfiles parked under /tmp
```

## Copy was cheap. Steering was the real part.

Public `.config/` subtrees did not overlap the private ones, so the first pass was a straight copy: aerospace, bat, ghostty, k9s, kitty, nvim, zsh, `sbin/`, `.tmux.conf`, terminfo. Skipped the public GPL `LICENSE` (do not copyleft the private repo) and local junk like `*.bak`.

The public Makefile became a tombstone. `make install` / `stow-link` / `dryrun` / `ls` now print instructions and exit 1. `make clean` still exists, and only removes `$HOME` symlinks that still point at `~/.dotfiles`, never at the private clone.

## Design that survived contact with the machine

**`make install` is cheap.** Day-to-day refresh should not brew the world.

```bash
make bootstrap   # dirs, brew, npm, terminfo — new Mac only
make install     # git crypt unlock, stow, agent-guidance, SSH perms
```

A review pass also caught a fake brew formula (`glowin` vs `glow`), `brew install a b c || true` (one miss skipped the rest), and `~/projects` (this machine keeps clones under `~/root/`, not `~/projects`).

**Absorb is a skill you run once**, not a hook on every rebase. The first version wired it into [`gsync`](/devlog/gsync/) (an agent skill: stash if needed, `git pull --rebase`, walk conflicts, ask before push), `gpr` (a fish abbreviation for `git pull --rebase`), fish startup, and git hooks. That would have rewritten `gpr` into a wrapper, for a one-time migration. Reverted to invoke-only: I type `/absorb-public-dotfiles`, and the skill calls the script.

```text
/absorb-public-dotfiles
        │
        ▼
~/.dotfiles-private/.claude/skills/absorb-public-dotfiles/absorb-public-dotfiles.sh
```

**Park, don't delete.** Other machines, muscle memory, "what if I still needed a file." Absorb and the public README now `mv ~/.dotfiles /tmp/dotfiles-public-$USER-$timestamp`. A public clone with uncommitted changes is unstowed but not moved. If you are standing inside the clone, the script `cd`s home first.

**Unused tools go to `archive/`** (Stow-ignored), instead of silently remaining as `~/sbin` leftovers. What is still stowed: `sbin/zed-sessioniser` only. Kitty/tmux sessioniser bindings went with the archive.

**Stow must name `$HOME`.** GNU Stow's default target is the parent of the package directory, which is only `$HOME` when the clone lives at `~/.dotfiles-private`. An off-home checkout writes into the parent. Fix: `stow -v -t "$(HOME)"`.

**Private dryrun must not see public links.** Fail-closed dryrun against the live home conflicts with public `.tmux.conf` / `~/sbin` still occupying those paths, so absorb aborted *before* unstow. On the Mac that still had the public clone stowed, that would have blocked the whole migration. Probe an empty `$HOME`, then unstow (including directory-level `sbin` / `.config` symlinks), then stow private.

## I could not test macOS `make install` on this pod

The cloud instance is Ubuntu 24.04, nested KVM, no systemd, no Homebrew, no git-crypt, no Docker at boot. Egress unrestricted. That last point does not matter: this is not a Mac, and Apple will not hand it a recovery image.

I still tried. Docker was not installed; `dockerd` started by hand. `overlay2` cannot mount on this overlay root; `vfs` is fine. A tiny public image runs. Then:

| Attempt | Result |
|---|---|
| `kvm-ok` | KVM acceleration can be used |
| `sickcodes/docker-osx:latest` (Catalina, VNC, 6G RAM) | Apple `osrecovery.apple.com` **HTTP 403**; no `BaseSystem.img`; QEMU exits |
| `sickcodes/docker-osx:auto` / `:big-sur` | Docker Hub **404** (tags gone) |
| `dockurr/macos` Ventura, web UI `:8006` | same Apple **403**, container exit 60 |

dockur's README is also clear: Apple's EULA does not permit installing macOS on non-Apple machines. Even if the 403 lifted, it would not have been a license-compliant guest. [Docker-OSX](https://github.com/sickcodes/Docker-OSX) and [dockur/macos](https://github.com/dockur/macos) were the wrong test for this pod.

## Isolated Linux `$HOME` instead

```text
HOME=/tmp/dotfiles-test-home
clone=$HOME/.dotfiles-private
make dryrun && make install
```

`git crypt unlock || true` no-ops as designed. `make bootstrap` (brew) was not run.

That is how the Stow parent-directory bug showed up: first `stow -v .` from `/tmp/dotfiles-private-test` linked into **`/tmp`**, not `$HOME`. Those stray links were unstowed immediately, then `-t "$(HOME)"` landed.

After that, install passed: `.tmux.conf`, `.config` (nvim/kitty/fish/…), `sbin` → private, LaunchAgents present, `archive/` **not** stowed. The live repo clone stayed clean because the test used a copy.

Absorb got a second fixture: public owned `.tmux.conf` and whole `~/sbin` (with leftover `ktm`). Exit 0. Public parked under `/tmp/dotfiles-public-$USER-…`. `~/sbin` retargeted at private; `ktm` gone; `archive/` still not stowed.

## Then I ran absorb on the Mac

After the cloud PRs, I invoked `/absorb-public-dotfiles` once on the machine that still had `~/.dotfiles` stowed. The skill called the script against live `$HOME`. Exit 0. Public links unstowed, private restowed, clone parked at `/tmp/dotfiles-public-$USER-20260818184055`.

Redacted chat: [Absorb transcript](/devlog/20260818-absorb-public-dotfiles-transcript/).

`make bootstrap` only if this is a new Mac.

The public GitHub repo is archived and private. Git history from the old public clone still exists there; the live tree is private only.

## What's next

- Leave absorb invoke-only. If it is still sitting in a hook next month, the design did not stick
