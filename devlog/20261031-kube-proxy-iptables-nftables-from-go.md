---
layout: default
title: "How kube-proxy Programs iptables and nftables from Go"
date: 2026-10-31
permalink: /devlog/20261031-kube-proxy-iptables-nftables-from-go/
description: "A quick source dive into how Go hands networking rules to Linux userspace tools."
---

# How kube-proxy Programs iptables and nftables from Go

I knew `iptables` and `nft` as Linux userspace commands. So how did kube-proxy, written in Go, configure them? I expected something closer to C, Rust, or Zig.

The key excerpts (not standalone programs):

**iptables mode:** Go builds rule text and [pipes it to `iptables-restore`][iptables]:

```go
cmd := runner.exec.Command(iptablesRestoreCmd, fullArgs...)
cmd.SetStdin(bytes.NewBuffer(data))
```

That wrapper [delegates to `os/exec`][exec]:

```go
return (*cmdWrapper)(maskErrDotCmd(osexec.Command(cmd, args...)))
```

**nftables mode:** Go builds a `knftables.Transaction`. The library converts it to text and [runs `nft -f -`][nft]:

```go
cmd := exec.CommandContext(ctx, nft.path, "-f", "-")
cmd.Stdin = nft.buffer
```

The batch goes through stdin. No temporary rules file.

Both paths batch updates instead of starting a process for every rule. The userspace tools configure the kernel; **the kernel handles the packets**.

My assumption about Go was too narrow. Go can make system calls and use netlink directly. These subprocesses are an implementation choice, not a language limitation.

One wrinkle: the inspected nftables implementation can [use netlink for reads][netlink]:

```go
// UseNetlink: use the experimental netlink version of the List* methods rather than
// using `nft list`.
```

Writes still go through `nft -f -`.

What clicked for me: ask which Linux interface a program uses, rather than assuming its language determines how close it can get to the kernel.

*Source-reading notes from October 2026; links pin the inspected implementations.*

[iptables]: https://github.com/kubernetes/kubernetes/blob/dc5eeea813679154dce3bf511ab011221ebd67a1/pkg/util/iptables/iptables.go#L327-L350
[exec]: https://github.com/kubernetes/utils/blob/cf1189d6abe3a7522bbd54a1bc1068a0a56011c8/exec/exec.go#L117-L124
[nft]: https://github.com/kubernetes/kubernetes/blob/b5cf787e5ea33a70fc038150634ead3c6970da93/vendor/sigs.k8s.io/knftables/nftables.go#L265-L281
[netlink]: https://github.com/kubernetes/kubernetes/blob/b5cf787e5ea33a70fc038150634ead3c6970da93/vendor/sigs.k8s.io/knftables/nftables.go#L216-L255
