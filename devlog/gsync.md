---
layout: default
title: "gsync"
date: 2026-08-18
permalink: /devlog/gsync/
description: "Agent skill: stash if needed, git pull --rebase, walk conflicts, then ask before push."
---

# gsync

Agent skill. Stash if needed, `git pull --rebase`, walk conflicts, then ask before push.

```text
1. check local changes using git status
2. If there are local changes, stash them, run the following steps, then unstash them back.
3. run git pull --rebase
4. resolve conflicts. if u can't decide based on the context from the current session or current git branch, ask user to resolve it
5. once user acknowledges, run git rebase --continue
6. if user asks to abort, run git rebase --abort and report back to user
7. On continue, repeat steps 4-6 until rebase is complete
8. finally ask me if i should push the local change, if yes, run git push origin <branch> (set upstream branch if unset)
9. after a successful push, report back a clickable browser URL for the pushed branch. Derive it from git remote get-url origin and the current branch, converting SSH GitHub remotes like git@github.com:owner/repo.git to https://github.com/owner/repo/tree/<branch>.
```

Used from [2 → 1 Dotfiles, Done with Cursor Cloud Agents](/devlog/20260818-two-to-one-dotfiles-cursor-cloud-agents/).
