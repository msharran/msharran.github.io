---
layout: default
title: "How kube-proxy Programs iptables and nftables from Go"
date: 2026-10-31
permalink: /devlog/20261031-kube-proxy-iptables-nftables-from-go/
description: "Following kube-proxy's Go code from in-memory rules to Linux userspace tools and the kernel."
---

# How kube-proxy Programs iptables and nftables from Go

While learning about Linux networking, I had a doubt: **how does kube-proxy, written in Go, program iptables and nftables?**

I knew `iptables` and `nft` as commands I could run in a terminal. But I associated low-level networking with C, Rust, or Zig. Go felt like a higher-level language. Was kube-proxy calling a C library? Making system calls? Implementing the packet-processing logic itself?

Following the source made the boundary much clearer. In the write paths I traced, kube-proxy builds rules in Go and launches an existing userspace binary to apply them.

## The language was the wrong boundary

My initial assumption needed correcting: Go can do systems programming. A garbage collector does not prevent a userspace program from making system calls or using Linux interfaces such as netlink. C, Rust, and Zig are useful for low-level work, but they are not prerequisites for configuring the kernel.

There are also three different things involved here:

- **kube-proxy:** a userspace process that watches Kubernetes Services and EndpointSlices and reconciles networking rules on a node.
- **The userspace tools:** `iptables`, `iptables-restore`, and `nft`, which accept commands and configure kernel state.
- **The kernel:** where Netfilter hooks and the configured rules handle packets.

Strictly speaking, nftables names a kernel subsystem as well as the surrounding tooling; its command-line tool is `nft`. Similarly, calling everything “iptables” can hide the distinction between the CLI and its kernel backend.

In iptables and nftables proxy modes, kube-proxy does not need to process each Service packet in Go. It configures the rules, and the kernel handles the traffic.

The paths I followed look like this:

```text
iptables mode:
  kube-proxy (Go)
    → restore-format text in memory
    → iptables-restore, with the text on stdin
    → kernel rules
    → packets handled in the kernel

nftables mode:
  kube-proxy (Go)
    → knftables transaction
    → nft command text in memory
    → nft -f -, with the text on stdin
    → kernel nftables rules
    → packets handled in the kernel
```

These are two selectable proxy modes. I am comparing their implementations, rather than describing a migration that every cluster has already made.

## Following the iptables path

I started with the iptables proxier's sync code. It assembles a buffer containing sections in the format understood by `iptables-restore`: `*filter`, chain and rule definitions, `COMMIT`, then `*nat` and another `COMMIT`.

The [buffer assembly and restore call][iptables-sync] are close together. This excerpt shows the handoff:

```go
err := proxier.iptables.RestoreAll(
    proxier.iptablesData.Bytes(),
    utiliptables.NoFlushTables,
    utiliptables.RestoreCounters,
)
```

The name `RestoreAll` initially made this look like a Go API that might program the kernel itself. Following it into [the iptables utility wrapper][iptables-wrapper] reveals the next step:

```go
cmd := runner.exec.Command(iptablesRestoreCmd, fullArgs...)
cmd.SetStdin(bytes.NewBuffer(data))
b, err := cmd.CombinedOutput()
```

That is the boundary I was looking for. The rules are bytes in memory. The wrapper starts `iptables-restore` and connects those bytes to the child process's standard input. For IPv6 it selects `ip6tables-restore`.

The command also receives options for waiting on the xtables lock, preserving unrelated table contents with `--noflush`, and restoring counters. The proxier explicitly uses `NoFlushTables` so it does not flush non-Kubernetes chains in the table. This is more precise than imagining kube-proxy replacing the node's entire firewall.

There is one more layer: `runner.exec` is the `k8s.io/utils/exec` interface. Its [real implementation delegates to Go's `os/exec`][go-exec]. The interface also allows callers to substitute a fake executor in tests.

A simplified version of the same process-launching idea would be:

```go
// Illustration only: not kube-proxy's complete implementation.
cmd := exec.CommandContext(ctx, "iptables-restore", "--noflush")
cmd.Stdin = bytes.NewReader(rules)
output, err := cmd.CombinedOutput()
```

There is no shell pipeline in that Go code. `os/exec` starts the executable directly; stdin supplies the rule text. kube-proxy's wrapper captures output and returns an error if the restore fails.

Batching matters here. Starting `iptables` separately for every rule would add process startup overhead. The restore interface lets kube-proxy submit many rules in one invocation. The input contains table-level `COMMIT` boundaries; I would not treat the whole multi-table buffer as a universal all-or-nothing transaction across every iptables backend.

The utility also has [individual command paths][iptables-single] for operations such as ensuring a rule exists. So “uses iptables” includes both individual commands and the bulk restore path.

## Following the nftables path

Next I followed the nftables proxier. This time the Go API is `sigs.k8s.io/knftables`.

kube-proxy [creates an interface][nft-client] for the appropriate IP family and its `kube-proxy` table. During synchronization it [starts a transaction][nft-tx]:

```go
tx := proxier.nftables.NewTransaction()
if doFullSync {
    proxier.setupNFTables(tx)
}
```

It then adds operations on tables, chains, sets, maps, and rules. For example, [ensuring a chain exists][nft-chain] adds a chain object and queues a flush of that chain. These calls describe work to perform; they do not each launch `nft`.

Inside knftables, [transaction methods append operations to a list][tx-operations]. When the transaction is ready, kube-proxy [calls `Run`][nft-run]:

```go
err = proxier.nftables.Run(context.TODO(), tx)
```

The library [serializes the operations][tx-text] into command text. A rule object becomes an `add rule ...` line through its [`writeOperation` method][rule-text].

Finally, [knftables' implementation of `Run`][knftables-run] does this:

```go
nft.buffer.Reset()
tx.populateCommandBuf(nft.buffer)

cmd := exec.CommandContext(ctx, nft.path, "-f", "-")
cmd.Stdin = nft.buffer
_, err := nft.exec.Run(cmd)
return err
```

So the write path still launches a userspace tool.

The command is `nft -f -`: `-f` means read commands from a file, and the filename `-` means standard input. There is no temporary rules file on disk in this path. The “file” comes from an in-memory buffer connected to stdin.

The `nft` tool parses that batch and submits the transaction through the kernel's nftables netlink interface. The changes in the transaction are applied atomically. Go handles constructing and submitting the desired configuration; the userspace tool handles interpreting nft syntax and communicating the update to the kernel.

## What about netlink from Go?

One detail in the newer source stopped me from concluding that kube-proxy *always* uses a CLI for every interaction.

The [nftables interface setup][nft-client] checks the `NFTablesNetlink` feature gate and can pass `knftables.UseNetlink`. The library's [option documentation and initialization][netlink-option] scope that option to the `List*` methods: reading existing state through netlink instead of executing `nft list` and parsing its output.

In the inspected implementation, **writes still use `nft -f -`**. Enabling netlink reads does not change the `Run` implementation shown above.

That also answers my original language question from another direction: Go code can communicate with the kernel through netlink. Using a subprocess for writes is an implementation choice, not a language restriction.

## The comparison I wanted

| Step | iptables proxy mode | nftables proxy mode |
| --- | --- | --- |
| Build desired changes | Restore-format text buffers | knftables transaction objects |
| Submit writes | `iptables-restore` / `ip6tables-restore` | `nft -f -` |
| Pass the batch | Standard input | Standard input |
| Read existing state | Userspace command paths such as `iptables-save` | `nft list`, or netlink with the inspected option |
| Handle packets | Kernel rules | Kernel nftables rules |

There is another naming trap: an `iptables` executable can use the nftables compatibility backend, often called `iptables-nft`. That does not make kube-proxy's **iptables proxy mode** the same as its **native nftables proxy mode**. The interface and rule structure kube-proxy generates still differ.

Both paths need the appropriate binaries and permission to administer networking in the target network namespace, typically involving `CAP_NET_ADMIN`. A high-level language does not remove those operating-system requirements.

## What I learned

The useful question turned out to be: **which interface does this program use to configure the kernel?**

For the iptables write path, I followed a Go buffer through `RestoreAll`, an exec wrapper, and finally `iptables-restore`. For nftables, I followed transaction objects through serialization and finally `nft -f -`.

I had been treating the choice of programming language as the main constraint. Reading the code showed me the actual division of work: Go reconciles Kubernetes state, userspace tools apply rule updates, and the kernel processes packets.

## Source trail

This is a source-reading devlog, not a report of a live cluster experiment. I started with my iptables notes from October 23 and nftables notes from October 27, 2026, and checked the linked implementation paths. The links are pinned so the explanation can be read alongside the same code later.

- **iptables:** Kubernetes commit `dc5eeea813679154dce3bf511ab011221ebd67a1`, plus the explicitly cited Kubernetes utils snapshot.
- **nftables:** Kubernetes commit `b5cf787e5ea33a70fc038150634ead3c6970da93`. Its [dependency declaration][dependency] pins knftables v0.0.22.
- **knftables internals:** commit `0087e9ef619d6c93eccd07dd11af97aa2cc09296`, as recorded in my notes. I also checked that the [vendored `Run` implementation][vendored-run] in the cited Kubernetes snapshot has the same stdin/exec write path.

These are implementation snapshots, not a claim about every Kubernetes release or every proxy mode.

[iptables-sync]: https://github.com/kubernetes/kubernetes/blob/dc5eeea813679154dce3bf511ab011221ebd67a1/pkg/proxy/iptables/proxier.go#L1362-L1384
[iptables-wrapper]: https://github.com/kubernetes/kubernetes/blob/dc5eeea813679154dce3bf511ab011221ebd67a1/pkg/util/iptables/iptables.go#L327-L350
[iptables-single]: https://github.com/kubernetes/kubernetes/blob/dc5eeea813679154dce3bf511ab011221ebd67a1/pkg/util/iptables/iptables.go#L376-L388
[go-exec]: https://github.com/kubernetes/utils/blob/cf1189d6abe3a7522bbd54a1bc1068a0a56011c8/exec/exec.go#L117-L124
[nft-client]: https://github.com/kubernetes/kubernetes/blob/b5cf787e5ea33a70fc038150634ead3c6970da93/pkg/proxy/nftables/supported.go#L34-L58
[nft-tx]: https://github.com/kubernetes/kubernetes/blob/b5cf787e5ea33a70fc038150634ead3c6970da93/pkg/proxy/nftables/proxier.go#L1244-L1247
[nft-chain]: https://github.com/kubernetes/kubernetes/blob/b5cf787e5ea33a70fc038150634ead3c6970da93/pkg/proxy/nftables/proxier.go#L445-L459
[nft-run]: https://github.com/kubernetes/kubernetes/blob/b5cf787e5ea33a70fc038150634ead3c6970da93/pkg/proxy/nftables/proxier.go#L1882-L1893
[tx-operations]: https://github.com/kubernetes-sigs/knftables/blob/0087e9ef619d6c93eccd07dd11af97aa2cc09296/transaction.go#L76-L163
[tx-text]: https://github.com/kubernetes-sigs/knftables/blob/0087e9ef619d6c93eccd07dd11af97aa2cc09296/transaction.go#L53-L57
[rule-text]: https://github.com/kubernetes-sigs/knftables/blob/0087e9ef619d6c93eccd07dd11af97aa2cc09296/objects.go#L305-L325
[knftables-run]: https://github.com/kubernetes-sigs/knftables/blob/0087e9ef619d6c93eccd07dd11af97aa2cc09296/nftables.go#L265-L281
[netlink-option]: https://github.com/kubernetes-sigs/knftables/blob/0087e9ef619d6c93eccd07dd11af97aa2cc09296/nftables.go#L216-L255
[dependency]: https://github.com/kubernetes/kubernetes/blob/b5cf787e5ea33a70fc038150634ead3c6970da93/go.mod
[vendored-run]: https://github.com/kubernetes/kubernetes/blob/b5cf787e5ea33a70fc038150634ead3c6970da93/vendor/sigs.k8s.io/knftables/nftables.go#L265-L281
