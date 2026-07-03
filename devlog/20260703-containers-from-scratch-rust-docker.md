---
layout: default
title: "[WIP] Containers From Scratch: Building a Tiny Docker Runtime in Rust"
date: 2026-07-03
permalink: /devlog/20260703-containers-from-scratch-rust-docker/
description: "A hands-on guide to Linux namespaces, filesystem isolation, and how containers actually work."
---

# [WIP] Containers From Scratch: Building a Tiny Docker Runtime in Rust

The entire project discussed in this demo is linked below.

[github.com/msharran/codingchallenges.fyi/docker/rust-docker](https://github.com/msharran/codingchallenges.fyi/blob/main/docker/rust-docker/README.md)

<!-- Draft goes here. -->

## Setting context

I know basic rust which I learnt out of curiosity. However, I have written some [projects in Zig](https://github.com/msharran/codingchallenges.fyi/tree/main/redis-server/zig-redis-server), so I know a thing or two about systems programming. I also have a background in Infrastructure engineering, so I know a little bit about linux and containers.

> Note: I consider these devlogs as my personal journal of my learnings. So, I will not be writing a full-fledged article here. I will just write down my learnings and thoughts in a concise manner.

## What I have built

### Running some adhoc commands inside the container from host 

**First I'll run them in Host**

```bash
msharran@ubuntu:rust-docker$ hostname
ubuntu

msharran@ubuntu:rust-docker$ uname -a
Linux ubuntu 7.0.11-orbstack-00360-gc9bc4d96ac70 #1 SMP PREEMPT Thu Jun  4 16:40:25 UTC 2026 x86_64 GNU/Linux

msharran@ubuntu:rust-docker$ cat /etc/os-release
PRETTY_NAME="Ubuntu 26.04 LTS"
NAME="Ubuntu"
VERSION_ID="26.04"
VERSION="26.04 LTS (Resolute Raccoon)"
VERSION_CODENAME=resolute
ID=ubuntu
ID_LIKE=debian
HOME_URL="https://www.ubuntu.com/"
SUPPORT_URL="https://help.ubuntu.com/"
BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
UBUNTU_CODENAME=resolute
LOGO=ubuntu-logo
```

**Now inside the Container**

```bash
msharran@ubuntu:rust-docker$ sudo ./target/debug/dkr hostname
container    

msharran@ubuntu:rust-docker$ sudo ./target/debug/dkr uname -a
Linux container 7.0.11-orbstack-00360-gc9bc4d96ac70 #1 SMP PREEMPT Thu Jun  4 16:40:25 UTC 2026 x86_64 Linux

msharran@ubuntu:rust-docker$ sudo ./target/debug/dkr cat /etc/os-release
INFO Running command: ["./target/debug/dkr", "cat", "/etc/os-release"]
INFO Parent PID 6882
Continuing execution in parent process, new child has pid: 6883
INFO I'm a new child process with pid 6883
NAME="Alpine Linux"
ID=alpine
VERSION_ID=3.24.1
PRETTY_NAME="Alpine Linux v3.24"
HOME_URL="https://alpinelinux.org/"
BUG_REPORT_URL="https://gitlab.alpinelinux.org/alpine/aports/-/issues"
INFO Child command has finished its execution!
INFO Container with pid 6883 has been dropped!
Parent execution done
```

### Exec into the container 

```bash
msharran@ubuntu:rust-docker$ sudo ./target/debug/dkr sh
INFO Running command: ["./target/debug/dkr", "sh"]
INFO Parent PID 6898
Continuing execution in parent process, new child has pid: 6899
INFO I'm a new child process with pid 6899
 # uname -a
Linux container 7.0.11-orbstack-00360-gc9bc4d96ac70 #1 SMP PREEMPT Thu Jun  4 16:40:25 UTC 2026 x86_64 Linux
 # cat /etc/os-release
NAME="Alpine Linux"
ID=alpine
VERSION_ID=3.24.1
PRETTY_NAME="Alpine Linux v3.24"
HOME_URL="https://alpinelinux.org/"
BUG_REPORT_URL="https://gitlab.alpinelinux.org/alpine/aports/-/issues"
 #
```

## Features I want to understand by building

- Separate hostname 
- Separate isolated process for the container
- Change root filesystem to point to Alpine linux root filesystem (which is a minimal linux filesystem)

For now this gives me a mental model of how containers work under the hood. So this should be good enough.
