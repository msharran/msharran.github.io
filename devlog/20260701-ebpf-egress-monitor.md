---
layout: default
title: "eBPF egress monitor"
date: 2026-07-01
permalink: /devlog/20260701-ebpf-egress-monitor/
---

# eBPF egress monitor

I started this project because I wanted to learn eBPF. So I decided to write a practical tool that runs on a Linux ECS/EKS node and answer one simple question: which process or container is talking to which dependency?

The project lives here: [github.com/msharran/labs/go/ebpf-network-egress-monitor](https://github.com/msharran/labs/tree/main/go/ebpf-network-egress-monitor).

I already knew Go well, so the CLI side felt approachable. The unknown part was C, especially eBPF C. I did not want the LLM to hide that from me. I wanted it to help me branch into C gradually, with a small proof of concept first and then build up.

The final goal is bigger, but the learning path had to be small:

```text
kernel sees connect() -> eBPF program emits event 
-> Go reads event -> terminal prints event
```

## Starting the challenge

Pi session: [019f028a-106f-7938-b0ae-603809ccb443](https://pi.dev/session/#40426232c2d6c9d14795aae61ba8ad3d)

I started inside [`go/ebpf-network-egress-monitor`](https://github.com/msharran/labs/tree/main/go/ebpf-network-egress-monitor) with an initial [`CHALLENGE.md`](https://github.com/msharran/labs/blob/main/go/ebpf-network-egress-monitor/CHALLENGE.md).

My first intent was roughly this:

```text
Build a Go CLI using github.com/cilium/ebpf from the ebpf-go getting started guide.
Run development/testing inside an OrbStack Ubuntu VM.
Eventually SSH into ECS/EKS nodes and run a monitor that shows which pod/task/container/process calls which dependency.
```

This local workflow became important:

```sh
orb make
orb go test ./...
orb go run .
```

My daily machine is macOS, but eBPF depends on Linux kernel features. So the actual build/run/debug loop needed to happen inside Linux.

The LLM created some repository guidance in [`AGENTS.md`](https://github.com/msharran/labs/blob/main/go/ebpf-network-egress-monitor/AGENTS.md): use OrbStack Ubuntu VM, prefix Linux commands with `orb`, use Go and `github.com/cilium/ebpf`, and keep the scope narrow.

It also created the first [`README.md`](https://github.com/msharran/labs/blob/main/go/ebpf-network-egress-monitor/README.md) with a simple description of the tool.

Then I asked it to rename the challenge to `ebpf network egress monitor` if that made more sense. I wanted the name to match the actual use case. Not an abstract dependency map, but a concrete egress monitor.

The challenge became:

```text
Build a Go CLI that you can SSH into an ECS or EKS node and run with sudo to see which pod/task/container and process is making outbound network connections to which DNS name or IP and port.
```

I also asked `@#oracle` to review the challenge. The target was:

> **Note:** `@#oracle` is my Pi subagent for second-opinion reviews. It runs as a separate Pi agent with its own context so I can ask it to critique scope, assumptions, and implementation direction. I use the subagent pattern described in my [`pragmatic-pi-extensions` README](https://github.com/msharran/pragmatic-pi-extensions/blob/main/README.md#2-pi-as-subagentts).

```text
Use inside ECS/EKS node.
SSH into node and run monitor.
See which pod/task/container and its process uses which dependency.
Keep MVP simple:
- container/process
- DNS:port
- protocol
- connection count
- bytes sent/received
```

The review said the direction was right but too broad. The suggested MVP output was simpler:

```text
DNS:port
PROTO
CONNS
BYTES_SENT
BYTES_RECV
```

Things like `AVG_LAT`, `FAILS`, `LAST_SEEN`, filters, and a TUI can come later.

That helped me keep the final product ambitious, while the learning path stayed tiny: first observe `connect()` calls, then read them from Go, then add DNS/container/process enrichment later.

## Making the first stupid POC

Pi session: [019f02a6-d85a-7ebb-aa11-6af9c4e766e7](https://pi.dev/session/#a39312f67308a0999fcc8c21af24083c)

This session is almost the entire implementation I have so far. I went by first principles. I did not worry too much about syntax or programming language constructs. I let the agent take care of those parts, but only after I asked enough questions to understand what was happening. Once I understood the shape of the change, I let the agent code it.

At this point I intentionally asked for a very small implementation:

```text
only add handle enter. remove others. i want to start with simple stupid POC for learning
```

I did not want a production-grade monitor. I wanted only:

- `sys_enter_connect`
- no `sys_exit_connect`
- no inflight map
- no return code tracking
- emit one event immediately when a process calls `connect()`

The C side was reduced to one tracepoint handler in [`egress_bpf.c`](https://github.com/msharran/labs/blob/main/go/ebpf-network-egress-monitor/egress_bpf.c):

```c
SEC("tracepoint/syscalls/sys_enter_connect")
int handle_enter(struct sys_enter_connect_ctx *ctx) {
    ...
}
```

The Go side attached only this tracepoint:

```go
link.Tracepoint("syscalls", "sys_enter_connect", objs.HandleEnter, nil)
```

The terminal output was intentionally boring:

```text
PID COMM DEST
```

That boringness was the point. I wanted the smallest loop to work before learning anything else.

Then I asked:

```text
im new to c, well versed in go. explain this flow of code in c to go
```

The explanation that clicked for me was:

```text
Go process starts
  ↓
Go loads compiled eBPF object
  ↓
Go attaches C eBPF function to kernel tracepoint
  ↓
Kernel calls C function on every connect()
  ↓
C function writes event into eBPF ring buffer map
  ↓
Go reads ring buffer map
  ↓
Go prints event
```

The important realization was that this project does not use cgo. Go does not call the C function. The C is compiled into eBPF bytecode, Go loads that bytecode into the kernel, and the kernel calls it when the tracepoint fires.

Some C/eBPF details I understood during review:

- `SEC("tracepoint/syscalls/sys_enter_connect")` is not a normal userspace C annotation. It puts the function in a special ELF section so the loader knows where it can be attached.
- `struct sys_enter_connect_ctx` has to match the kernel tracepoint format. The useful command is:

  ```bash
  sudo cat /sys/kernel/debug/tracing/events/syscalls/sys_enter_connect/format
  ```

- `bpf_probe_read_user(...)` is needed because the syscall receives a userspace pointer to `sockaddr`. The eBPF program runs in kernel context and must copy from userspace safely.
- The ring buffer is the pipe from kernel eBPF code back to the Go process.
- The C event struct and Go event struct must match in field order, size, and alignment.

I also asked why tutorials often use both `sys_enter_connect` and `sys_exit_connect`.

The short version:

```text
sys_enter_connect gives syscall arguments, like destination sockaddr.
sys_exit_connect gives the return value/result.
```

So if I want destination and result, I need to capture destination at enter, store it in an inflight map keyed by pid/tid, then join it with the result at exit.

For this POC, enter-only was enough. I just wanted to prove that I can see connection attempts.

## Build/debug loop inside Linux

Same Pi session: [019f02a6-d85a-7ebb-aa11-6af9c4e766e7](https://pi.dev/session/#a39312f67308a0999fcc8c21af24083c)

The first `go generate ./...` failed with:

```text
fatal error: 'asm/types.h' file not found
```

The fix was to add the Ubuntu architecture include path to the `bpf2go` clang flags. The directive shape became:

```go
//go:generate go run github.com/cilium/ebpf/cmd/bpf2go -cc clang -cflags "-O2 -g" egress egress_bpf.c -- -I. -I/usr/include/x86_64-linux-gnu
```

My understanding: `bpf2go` invokes clang to compile the C file. Inside Linux, clang still needs the right header include path. This was a C/header problem, not a Go problem.

Then I hit another C compile issue:

```text
variable has incomplete type 'struct sockaddr'
use of undeclared identifier 'AF_INET'
use of undeclared identifier 'AF_INET6'
```

The fix was to avoid relying on userspace libc structs in BPF C and define only the minimal shape I needed inside [`egress_bpf.c`](https://github.com/msharran/labs/blob/main/go/ebpf-network-egress-monitor/egress_bpf.c):

```c
#ifndef AF_INET
#define AF_INET 2
#endif

#ifndef AF_INET6
#define AF_INET6 10
#endif

struct sockaddr_header {
    unsigned short sa_family;
    char sa_data[14];
};
```

This was another good reminder that eBPF C is constrained C. I should not assume normal userspace headers and structs are available or verifier-friendly.

After that, tests passed:

```text
?    egress-monitor [no test files]
```

And this was the first real runtime proof:

```bash
orb bash -lc 'sudo timeout 15s go run ./... events'
```

Example output:

```text
listening for connect() calls; run `curl https://example.com` in another terminal
PID COMM DEST
935321 curl 0.250.250.200:53
935321 curl 172.66.147.243:443
935321 curl 104.20.23.154:443
```

Seeing `curl` show up in the terminal with destination IPs and ports was the unlock. The tracepoint was firing, the ring buffer was working, and Go could print events from the kernel.

## Renaming `events` to `trace`

Later I renamed `events` to `trace` after the first working loop.

The command name `events` felt too generic. At this stage the tool is not the final `top` table view. It is a raw trace stream, so `trace` made more sense.

The [`Makefile`](https://github.com/msharran/labs/blob/main/go/ebpf-network-egress-monitor/Makefile) now builds inside OrbStack and runs with sudo:

```make
APP=egress-monitor
GO=go
ORB=orb

.PHONY: build clean run-%

build:
	$(ORB) $(GO) build -o $(APP) .

run-%: build
	$(ORB) sudo ./$(APP) $*

clean:
	rm -f $(APP)
```

So locally I can run:

```bash
make run-trace
```

The rename was roughly:

```text
events.go -> trace.go
CLI command: events -> trace
runEvents() -> runTrace()
```

In [`main.go`](https://github.com/msharran/labs/blob/main/go/ebpf-network-egress-monitor/main.go), dispatch became:

```go
switch flag.Arg(0) {
case "trace":
    if err := runTrace(); err != nil {
        fmt.Fprintln(os.Stderr, "trace:", err)
        os.Exit(1)
    }
default:
    ...
}
```

Verification after rename:

```sh
orb gofmt -w main.go trace.go
orb go test ./...
```

Output:

```text
?   	egress-monitor	[no test files]
```

## Current code shape

The current implementation is still a learning project, but it already has the main Go/eBPF boundary in place.

[`main.go`](https://github.com/msharran/labs/blob/main/go/ebpf-network-egress-monitor/main.go) is intentionally boring. It just dispatches to `runTrace()`.

[`trace.go`](https://github.com/msharran/labs/blob/main/go/ebpf-network-egress-monitor/trace.go) does the interesting userspace work:

```go
rlimit.RemoveMemlock()
loadEgressObjects(&objs, nil)
link.Tracepoint(...)
ringbuf.NewReader(objs.Events)
reader.Read()
```

My current mental model:

```text
1. Remove memlock limit so eBPF maps/programs can be loaded.
2. Load compiled eBPF object generated by bpf2go.
3. Attach eBPF functions to kernel tracepoints.
4. Open the BPF ring buffer map.
5. Read raw samples forever.
6. Decode bytes into a Go struct matching the C struct.
```

[`trace.go`](https://github.com/msharran/labs/blob/main/go/ebpf-network-egress-monitor/trace.go) has also started to move beyond raw connect events into DNS-aware trace output:

```text
CONNECT
DNS_QUERY
DNS_ANSWER
```

[`egress_bpf.c`](https://github.com/msharran/labs/blob/main/go/ebpf-network-egress-monitor/egress_bpf.c) defines the event contract between C and Go:

```c
struct event {
    __u32 type;
    __u32 pid;
    __u32 tgid;
    __u16 family;
    __u16 dport;
    __u16 data_len;
    __u8 ip_version;
    __u8 pad1;
    char comm[TASK_COMM_LEN];
    __u8 dst[16];
    __u8 data[DNS_PAYLOAD_LEN];
};
```

If I change this shape in C, I must update the Go struct too. Otherwise Go will decode garbage.

Current tracepoints in [`egress_bpf.c`](https://github.com/msharran/labs/blob/main/go/ebpf-network-egress-monitor/egress_bpf.c):

```text
sys_enter_connect
sys_enter_sendto
sys_enter_recvfrom
sys_exit_recvfrom
```

My understanding now:

- `connect` gives destination socket addresses.
- `sendto` / `recvfrom` help observe DNS payloads on port 53.
- `recvfrom` needs enter and exit because enter captures the userspace buffer pointer, while exit tells whether bytes were actually received.

## Commands to remember

Build/test:

```bash
orb go generate ./...
orb gofmt -w main.go trace.go
orb go test ./...
```

Run:

```bash
make run-trace
```

Manual run shape:

```bash
orb sudo ./egress-monitor trace
```

Inspect tracepoint format:

```bash
sudo cat /sys/kernel/debug/tracing/events/syscalls/sys_enter_connect/format
```

Trigger test traffic:

```bash
curl https://example.com
curl https://api.github.com
```

## What I want to remember

This project is not just about building a tool. It is about learning the boundary between Go userspace and eBPF C in the Linux kernel.

The architecture in my head is:

```text
Go CLI
  |
  | loads compiled eBPF object generated by bpf2go
  v
Linux kernel eBPF verifier/loader
  |
  | attaches eBPF programs to tracepoints
  v
sys_enter_connect / DNS syscall tracepoints
  |
  | eBPF C program runs when syscall happens
  v
BPF ring buffer map
  |
  | Go reads raw events
  v
terminal output
```

The biggest conceptual jumps for me:

1. eBPF C is not normal userspace C.
2. Go does not call the C function.
3. The kernel calls the eBPF function when the tracepoint fires.
4. The ring buffer is the kernel-to-userspace event pipe.
5. The C struct and Go struct must match exactly.
6. `sys_enter` gives arguments; `sys_exit` gives return values.
7. Start with an intentionally stupid POC before adding correctness and enrichment.

From here, the project can grow carefully: add syscall exit when I need results, add DNS parsing when I need names, add container metadata when I need ECS/EKS context, and eventually aggregate into the `top` view from the challenge.
