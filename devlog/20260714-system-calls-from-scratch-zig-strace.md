---
layout: default
title: "System Calls From Scratch: Building a Tiny strace in Zig"
date: 2026-07-14
permalink: /devlog/20260714-system-calls-from-scratch-zig-strace/
---

# System Calls From Scratch: Building a Tiny strace in Zig

The entire project discussed in this demo is linked below.

[github.com/msharran/codingchallenges.fyi/strace/zig-strace](https://github.com/msharran/codingchallenges.fyi/tree/main/strace/zig-strace)

## Setting Some Context

**Source:** [`README.md` — project purpose](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/strace/zig-strace/README.md#L1-L8), [`ptrace.zig` — ptrace wrapper](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/strace/zig-strace/src/ptrace.zig#L49-L93)

I use `strace` whenever I want to understand what a program is doing at the boundary between userspace and the Linux kernel. It shows the system calls made by a process, the arguments passed to them, and the values returned by the kernel.

For example, a simple command such as `ls` eventually has to ask the kernel to open files, map memory, write output, and exit. `strace` lets me see those operations instead of treating the command as a black box.

I wanted to understand how this works, so I built a very small version of `strace` in Zig using [`ptrace(2)`](https://man7.org/linux/man-pages/man2/ptrace.2.html).

> Note: I consider these devlogs my personal journal of what I’m learning, so I will not be writing a full-fledged article here. I will just write down my learnings and thoughts concisely.

## My Local Setup

**Source:** [`README.md` — requirements and build commands](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/strace/zig-strace/README.md#L17-L31), [`build.zig` — executable target](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/strace/zig-strace/build.zig#L41-L61)

- My development environment for this project is an ARM64 Linux VM running inside a MacBook using [OrbStack](https://orbstack.dev/).
- The project uses Zig `0.15.1`.
- The implementation requires Linux `5.3` or later because it uses `PTRACE_GET_SYSCALL_INFO`.
- The current syscall mapping is specific to ARM64/AArch64.

The project is built using:

```sh
zig build -Dtarget=aarch64-linux
```

The generated executable is:

```text
zig-out/bin/zig_strace
```

## Realistic Outcome

**Source:** [`main.zig` — syscall tracing and output](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/strace/zig-strace/src/main.zig#L42-L69), [`README.md` — example output](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/strace/zig-strace/README.md#L33-L72)

The final implementation can run a command as a child process and print every syscall entry and exit until that command finishes.

```sh
./zig-out/bin/zig_strace ls 2>&1 | grep -w syscall
```

The output looks roughly like this:

```text
info(syscall): brk(0, 0, 0, 0, ffff8557fd58, a)
info(syscall): retval=0xaaaacc620000 error=0
info(syscall): mmap(0, 2000, 3, 22, ffffffffffffffff, 0)
info(syscall): retval=0xffff85560000 error=0
info(syscall): openat(ffffffffffffff9c, ffff85563b78, 80000, 0, ffff855825b0, ffffffffffffffff)
info(syscall): retval=0x3 error=0
info(syscall): write(1, aaaacc6032b0, 2d, ffff85572740, 4e128c0908db9974, aaaacc603260)
info(syscall): retval=0x2d error=0
info(syscall): exit_group(0, 0, ffff85572f00, 120, ffff85581a30, 17f)
```

It does not decode pointers, flags, file paths, or error names yet. The arguments and return values are printed as raw hexadecimal values. However, it captures the main behavior I wanted to understand: stop a process at syscall entry and exit, inspect what happened, and then let it continue.

## Building It

**Source:** [`zig-strace` — project directory](https://github.com/msharran/codingchallenges.fyi/tree/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/strace/zig-strace), [`main.zig`](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/strace/zig-strace/src/main.zig), [`ptrace.zig`](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/strace/zig-strace/src/ptrace.zig), [`wait.zig`](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/strace/zig-strace/src/wait.zig)

Full project is available [here](https://github.com/msharran/codingchallenges.fyi/tree/main/strace/zig-strace).

**Project Structure**

The project is small. `main.zig` manages the tracee and tracer processes, `ptrace.zig` wraps the `ptrace` operations, and `wait.zig` interprets the child process status returned by `waitpid()`.

```sh
zig-strace$ tree -L2
.
├── Makefile
├── README.md
├── build.zig
├── build.zig.zon
└── src
    ├── main.zig
    ├── ptrace.zig
    └── wait.zig
```

## Creating The Tracee Process

**Code:** [`main.zig` — argument parsing, fork, and parent/child branches](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/strace/zig-strace/src/main.zig#L72-L97)

The entrypoint reads the command and its arguments, then calls [`fork(2)`](https://man7.org/linux/man-pages/man2/fork.2.html).

```zig
const args = try std.process.argsAlloc(allocator);
defer std.process.argsFree(allocator, args);

if (args.len < 2) {
    log_tracer.err("Usage: {s} <command> [args...]", .{args[0]});
    return;
}

const pid = try posix.fork();

if (pid == 0) {
    return runChildAsTracee(allocator, args);
} else {
    try traceChild(allocator, pid);
}
```

After `fork()`, the same program continues in two processes:

```text
zig_strace
├── child  -> becomes the tracee and runs the requested command
└── parent -> becomes the tracer and observes the child
```

The child gets `pid == 0`, while the parent gets the actual PID of the child. The parent needs this PID for every later `ptrace()` and `waitpid()` call.

## Asking The Parent To Trace The Child

**Code:** [`main.zig` — ptrace import and `traceMe()` call](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/strace/zig-strace/src/main.zig#L8-L15), [`ptrace.zig` — `Tracee` and `traceMe()` implementation](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/strace/zig-strace/src/ptrace.zig#L95-L111)

The child first calls `PTRACE_TRACEME` and then stops itself using `SIGSTOP`.

```zig
pub fn traceMe(_: Self) !void {
    try posix.ptrace(linux.PTRACE.TRACEME, 0, 0, 0);
    try posix.raise(linux.SIG.STOP);
}
```

`PTRACE_TRACEME` tells the kernel that this process expects its parent to trace it.

The `SIGSTOP` is the synchronization point between the two processes. It gives the parent a chance to set its tracing options before the child replaces itself with the requested program.

At this moment, the process state looks roughly like this:

```text
child:  PTRACE_TRACEME -> raise(SIGSTOP) -> stopped
                                         |
parent:                     waitpid() <---'
```

Without this stop, the child could continue into `exec()` before the parent has completed its tracing setup.

## Preparing And Executing The Command

**Code:** [`main.zig` — building `argv` and calling `execvpeZ()`](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/strace/zig-strace/src/main.zig#L13-L40)

The child takes everything after the `zig_strace` executable name and builds a null-terminated argument list.

```zig
const child_cmd = args[1..];
const argv = try allocator.alloc(?[*:0]const u8, child_cmd.len + 1);
defer allocator.free(argv);

for (args[1..], 0..) |arg, i| {
    argv[i] = arg;
}
argv[child_cmd.len] = null;
```

The null terminator is required because `exec` follows the C ABI convention for its argument list.

The child then calls:

```zig
return posix.execvpeZ(args[1], argv_ptr, &envp);
```

The `Z` suffix in Zig means that the strings are null-terminated. If this call succeeds, it does not return. The kernel replaces the child process image with the requested program, while the PID stays the same.

This distinction was important for me:

```text
fork() -> creates another process
exec() -> replaces the program running inside that process
```

So `zig_strace ls` does not create an unrelated `ls` process and then search for it. It creates the child itself, marks it for tracing, and replaces that child with `ls`.

## Setting The ptrace Options

**Code:** [`main.zig` — parent tracing setup](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/strace/zig-strace/src/main.zig#L42-L49), [`ptrace.zig` — option constants and ptrace calls](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/strace/zig-strace/src/ptrace.zig#L7-L8), [`ptrace.zig` — `setOptions()` and `cont()`](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/strace/zig-strace/src/ptrace.zig#L49-L74)

The parent waits for the child's initial `SIGSTOP` and configures two `ptrace` options:

```zig
var res = try wait.sigStop(pid, 0);

try ptracer.setOptions(ptrace.O_TRACESYSGOOD | ptrace.O_TRACEEXEC);
try ptracer.cont(null);
res = try wait.sigStop(pid, 0);
```

The options are:

- `PTRACE_O_TRACESYSGOOD` — marks syscall stops with `SIGTRAP | 0x80`, so they can be distinguished from normal `SIGTRAP` stops.
- `PTRACE_O_TRACEEXEC` — asks the kernel to stop the child when `exec()` replaces its process image.

The parent continues the child once so it can reach `exec()`, then waits again for the exec stop.

The complete setup flow is:

```text
child                              parent
-----                              ------
PTRACE_TRACEME
raise(SIGSTOP) ------------------> waitpid()
                                   PTRACE_SETOPTIONS
              <------------------ PTRACE_CONT
exec(ls) ------------------------> waitpid()
                                   ready to trace syscalls
```

## Stopping At Every System Call

**Code:** [`main.zig` — syscall tracing loop](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/strace/zig-strace/src/main.zig#L50-L69), [`ptrace.zig` — `PTRACE_SYSCALL` and syscall information](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/strace/zig-strace/src/ptrace.zig#L76-L92)

Once the child has executed the requested program, the tracer enters a loop:

```zig
while (true) {
    try ptracer.syscall();
    res = wait.sigSyscallStop(pid, 0) catch |err| switch (err) {
        error.ChildExited => return,
        else => return err,
    };

    const syscall_info = try ptracer.getSyscallInfo(allocator);
    defer allocator.destroy(syscall_info);

    ...
}
```

`PTRACE_SYSCALL` resumes the child just like `PTRACE_CONT`, but asks the kernel to stop it at the next syscall boundary.

Each syscall has two boundaries:

```text
userspace
   |
   | syscall entry  -> syscall number and arguments are available
   v
kernel executes the syscall
   |
   | syscall exit   -> return value and error status are available
   v
userspace continues
```

The tracer repeats `PTRACE_SYSCALL` after every stop. This lets one loop observe entry, exit, the next entry, the next exit, and so on until the child terminates.

## Knowing Whether It Is A Syscall Stop

**Code:** [`wait.zig` — `waitpid()` status and syscall-stop checks](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/strace/zig-strace/src/wait.zig#L6-L22), [`main.zig` — handling child exit from the wait](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/strace/zig-strace/src/main.zig#L50-L55)

The tracer uses `waitpid()` to wait whenever the child is stopped.

```zig
pub fn sigStop(pid: posix.pid_t, flags: u32) !posix.WaitPidResult {
    const res = posix.waitpid(pid, flags);
    if (linux.W.IFEXITED(res.status)) return error.ChildExited;
    if (!linux.W.IFSTOPPED(res.status)) return error.ChildNotStopped;
    return res;
}
```

However, a traced process can stop for reasons other than a syscall. The extra `0x80` bit added by `PTRACE_O_TRACESYSGOOD` is what makes the syscall stop recognizable:

```zig
const stop_signal = linux.W.STOPSIG(res.status);
if (stop_signal == (linux.SIG.TRAP | 0x80)) {
    return res;
} else {
    return error.NotSyscallStopSignal;
}
```

This is one of the parts that made `ptrace` click for me. The tracer does not continuously read the child process while it runs. The kernel stops the child, `waitpid()` reports why it stopped, the tracer inspects it, and then explicitly resumes it.

The loop is really:

```text
resume child -> kernel stops child -> waitpid returns
-> inspect stop -> resume child again
```

## Reading The Syscall Information

**Code:** [`ptrace.zig` — `ptrace_syscall_info` layout](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/strace/zig-strace/src/ptrace.zig#L10-L42), [`ptrace.zig` — `getSyscallInfo()`](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/strace/zig-strace/src/ptrace.zig#L80-L92), [`main.zig` — reading the structure](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/strace/zig-strace/src/main.zig#L57-L58)

At a syscall stop, the tracer calls `PTRACE_GET_SYSCALL_INFO`:

```zig
pub fn getSyscallInfo(
    self: Self,
    allocator: std.mem.Allocator,
) !*ptrace_syscall_info {
    const syscall_info = try allocator.create(ptrace_syscall_info);
    errdefer allocator.destroy(syscall_info);

    try posix.ptrace(
        linux.PTRACE.GET_SYSCALL_INFO,
        self.pid,
        @sizeOf(ptrace_syscall_info),
        @intFromPtr(syscall_info),
    );

    if (syscall_info.op == 0) {
        return error.NotAtSyscallStop;
    }

    return syscall_info;
}
```

The kernel writes into a `ptrace_syscall_info` structure supplied by the tracer. I represented the Linux structure in Zig using an `extern struct` and `extern union` so its memory layout follows the C ABI.

```zig
pub const ptrace_syscall_info = extern struct {
    op: u8,
    arch: u32,
    instruction_pointer: u64,
    stack_pointer: u64,
    data: extern union {
        entry: extern struct {
            nr: u64,
            args: [6]u64,
        },
        exit: extern struct {
            rval: i64,
            is_error: u8,
        },
        ...
    },
};
```

The `op` field tells me which part of the union is valid:

- syscall entry gives the syscall number and six raw argument values.
- syscall exit gives the return value and whether the kernel considers it an error.

This is similar to the C and Go event structs in my eBPF project. Whenever the kernel and userspace exchange a binary structure, the layout must match exactly. Field sizes, ordering, alignment, and padding all matter.

## Mapping A Number To A Syscall Name

**Code:** [`ptrace.zig` — `syscallNameFromNum()`](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/strace/zig-strace/src/ptrace.zig#L44-L47), [`main.zig` — mapping at syscall entry](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/strace/zig-strace/src/main.zig#L60-L62)

The kernel reports a syscall number, not a name such as `openat` or `write`.

Instead of maintaining my own ARM64 lookup table, I use Zig's architecture-specific `linux.SYS` enum:

```zig
pub fn syscallNameFromNum(syscall_num: u64) []const u8 {
    const syscall_enum = std.meta.intToEnum(linux.SYS, syscall_num)
        catch return "unknown";
    return @tagName(syscall_enum);
}
```

The flow is:

```text
kernel syscall number
  |
  v
Zig linux.SYS enum
  |
  v
enum tag name such as openat, mmap, write, or exit_group
```

Syscall numbers are architecture-specific. A number that represents one syscall on ARM64 is not guaranteed to represent the same syscall on x86-64. Using Zig's target-specific enum avoids hardcoding a second table, but the current project is still only tested and intended for ARM64.

## Printing Entry And Exit

**Code:** [`main.zig` — entry and exit logging](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/strace/zig-strace/src/main.zig#L57-L67), [`ptrace.zig` — entry and exit helpers](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/strace/zig-strace/src/ptrace.zig#L35-L47)

The tracer uses `op` to decide whether to print syscall arguments or the result:

```zig
if (syscall_info.isEntry()) {
    const syscall_name = ptrace.syscallNameFromNum(
        syscall_info.data.entry.nr,
    );
    log_syscall.info(
        "{s}({x}, {x}, {x}, {x}, {x}, {x})",
        .{
            syscall_name,
            syscall_info.data.entry.args[0],
            syscall_info.data.entry.args[1],
            syscall_info.data.entry.args[2],
            syscall_info.data.entry.args[3],
            syscall_info.data.entry.args[4],
            syscall_info.data.entry.args[5],
        },
    );
} else if (syscall_info.isExit()) {
    log_syscall.info(
        "retval=0x{x} error={}",
        .{
            syscall_info.data.exit.rval,
            syscall_info.data.exit.is_error,
        },
    );
}
```

At entry, all six argument registers are printed because the tracer does not yet know the signature of each syscall. At exit, it prints the raw return value and the error bit.

A real `strace` knows how to interpret each syscall individually. For `openat`, it reads the pathname from the tracee's memory and decodes flags such as `O_RDONLY`. For `write`, it knows which argument is the file descriptor, which one is a buffer pointer, and which one is the byte count.

My implementation deliberately stops before that layer. I wanted to understand process tracing and syscall stops first. Pretty formatting can come after the core loop works.

## Gist Of The Complete Flow

**Source:** [`main.zig` — complete child and tracer flow](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/strace/zig-strace/src/main.zig#L13-L98), [`ptrace.zig` — tracing operations](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/strace/zig-strace/src/ptrace.zig#L49-L111), [`wait.zig` — process-stop synchronization](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/strace/zig-strace/src/wait.zig#L6-L22)

The complete flow of `zig_strace` is now:

```text
1. Read a command from the CLI.
2. Fork the zig_strace process.
3. Let the child request tracing using PTRACE_TRACEME.
4. Stop the child using SIGSTOP.
5. Let the parent wait for that stop and set ptrace options.
6. Continue the child into exec().
7. Replace the child program with the requested command.
8. Resume it using PTRACE_SYSCALL.
9. Wait at each syscall entry and exit.
10. Read syscall information and print it.
11. Repeat until the child exits.
```

In terms of Linux operations, the important flow is:

```text
fork()
  |
  v
PTRACE_TRACEME + SIGSTOP
  |
  v
waitpid() + PTRACE_SETOPTIONS
  |
  v
PTRACE_CONT + exec()
  |
  v
PTRACE_SYSCALL
  |
  v
waitpid() + PTRACE_GET_SYSCALL_INFO
  |
  `---- repeat until exit
```

That is enough to capture the same basic syscall sequence shown by the real `strace` for a command such as `ls`.

## What I Want To Remember

**Source:** [`main.zig` — tracer control loop](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/strace/zig-strace/src/main.zig#L42-L69), [`wait.zig` — kernel stop reporting through `waitpid()`](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/strace/zig-strace/src/wait.zig#L6-L22)

`strace` is mainly a controlled loop between a tracer, a tracee, and the kernel.

My current mental model is:

```text
tracee process
  |
  | enters or exits a syscall
  v
kernel stops tracee
  |
  | reports status through waitpid()
  v
tracer process
  |
  | reads syscall information using ptrace()
  | prints it
  | resumes the tracee
  `--------------------------------------> repeat
```

The tracer is not passively watching a stream of events. It is actively controlling when the tracee can continue.

This is also the main difference in my head between this project and my eBPF egress monitor. The eBPF program observes kernel events without stopping the process that caused them. `ptrace` stops and controls one particular process so the tracer can inspect it at precise boundaries.

## Key Take Aways

**Source:** [`main.zig` — end-to-end implementation](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/strace/zig-strace/src/main.zig#L13-L98), [`ptrace.zig` — tracing primitives and syscall data](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/strace/zig-strace/src/ptrace.zig#L7-L111), [`README.md` — limitations and future improvements](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/strace/zig-strace/README.md#L122-L134)

1. `fork()` creates the child that will become the traced process.
2. `PTRACE_TRACEME` lets the child ask its parent to trace it.
3. `SIGSTOP` gives the parent time to configure tracing before `exec()`.
4. `exec()` replaces the child program but keeps the same process ID.
5. `PTRACE_SYSCALL` stops the tracee at both syscall entry and exit.
6. `waitpid()` is the synchronization mechanism between the tracer and tracee.
7. `PTRACE_O_TRACESYSGOOD` makes syscall stops distinguishable from other stops.
8. `PTRACE_GET_SYSCALL_INFO` provides syscall arguments at entry and the result at exit.
9. Syscall numbers and their mappings depend on the CPU architecture.
10. A small tracer can show the core behavior of `strace` without decoding every syscall argument.

From here, the project can grow carefully: decode arguments based on each syscall signature, read strings from the tracee's memory, print error names, follow forked child processes, and support more architectures.

However, I'm going to stop here.
