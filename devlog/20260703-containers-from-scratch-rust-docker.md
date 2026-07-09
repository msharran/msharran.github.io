---
layout: default
title: "[WIP] Containers From Scratch: Building a Tiny Docker Runtime in Rust"
date: 2026-07-03
permalink: /devlog/20260703-containers-from-scratch-rust-docker/
---

# [WIP] Containers From Scratch: Building a Tiny Docker Runtime in Rust

The entire project discussed in this demo is linked below.

[github.com/msharran/codingchallenges.fyi/docker/rust-docker](https://github.com/msharran/codingchallenges.fyi/blob/main/docker/rust-docker/README.md)

<!-- Draft goes here. -->

## Setting Some Context

I know basic Rust, which I learned out of curiosity. I have also written some [projects in Zig](https://github.com/msharran/codingchallenges.fyi/tree/main/redis-server/zig-redis-server), so I know a thing or two about systems programming. I have a background in infrastructure engineering, so I know a little bit about Linux and containers.

> Note: I consider these devlogs my personal journal of what I’m learning, so I will not be writing a full-fledged article here. I will just write down my learnings and thoughts concisely.

## My Local Setup

- My development environment for this project is an Ubuntu VM provisioned using [OrbStack](https://orbstack.dev/) and running inside a MacBook.

```sh
~/r/p/c/d/rust-docker> orbctl list
NAME    STATE    DISTRO  VERSION   ARCH   SIZE    IP
----    -----    ------  -------   ----   ----    --
ubuntu  running  ubuntu  resolute  amd64  5.8 GB  192.168.139.104

~/r/p/c/d/rust-docker> orb

msharran@ubuntu:rust-docker$ uname -mno
ubuntu x86_64 GNU/Linux
```

- The `rust-docker` binary is called `dkr`, which I will use throughout the rest of this devlog.
- [Alpine Linux](https://alpinelinux.org/) is used as the container's distribution. I placed it in `/alpine-root` using the following commands:

```sh
msharran@ubuntu:rust-docker$ sudo mkdir /alpine-root
msharran@ubuntu:rust-docker$ sudo docker create --name alpine-temp alpine
msharran@ubuntu:rust-docker$ sudo docker export alpine-temp | sudo tar -xf - -C /alpine-root
msharran@ubuntu:rust-docker$ sudo docker rm alpine-temp
msharran@ubuntu:rust-docker$ ls /alpine-root/
bin  etc   lib    mnt  proc  run   srv  tmp  var
dev  home  media  opt  root  sbin  sys  usr
```

## Realistic Outcome

From the code that I have written, it won't exactly feel like Docker; however, it captures the essence of what Docker does.

**Command**

```
1  msharran@ubuntu$ sudo ./target/debug/dkr sh
2  # uname -mno
3  container x86_64 Linux
4  # cat /etc/os-release
5  NAME="Alpine Linux"
6  ID=alpine
7  VERSION_ID=3.24.1
8  ...
9  #
```

**Line-by-Line Breakdown**

Line 1: 
- `sudo` — is needed because we need `root` access to set up Linux namespaces.
- `./target/debug/dkr` — is the Rust executable built using `cargo build`. (See [Makefile](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/docker/rust-docker/Makefile#L1))
- `sh` — command to run inside the container. Here, it starts a shell.

Line 2: 
- `#` — Shell prompt indicator
- `uname -mno` — Running `uname` command inside the container

Line 3:
- `container x86_64 Linux` — tells us the container's hostname is `container`, the architecture is `x86_64`, and the OS is `Linux`

Line 4: 
- `cat /etc/os-release` — Checking the OS release name and ID

Line 5:
- `NAME="Alpine Linux"` — Container is now running "Alpine Linux"

## Building It

Full project is available [here](https://github.com/msharran/codingchallenges.fyi/tree/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/docker/rust-docker)

**Project Structure**

It is a very minimal Rust project. We will focus on `main.rs` first, then on `container.rs` later.

```sh
msharran@ubuntu:rust-docker$ tree -L2
.
├── Cargo.lock
├── Cargo.toml
├── Makefile
├── README.md
├── src
│   ├── container.rs
│   └── main.rs
```

**Setting Up the CLI Entrypoint**

```rs
const PKG_NAME: &str = env!("CARGO_PKG_NAME");

fn main() -> ExitCode {
    match run() {
        Ok(_) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("{}: {}", PKG_NAME, e);
            ExitCode::from(1)
        }
    }
}
```

We set up a simple entrypoint using `fn main()`, which returns exit code `0` when `fn run()` succeeds and a non-zero exit code on failure.

**Getting the Command to Run as an Argument**

```rs
fn run() -> Result<(), String> {
    let args: Vec<String> = env::args().collect();
    println!("INFO Running command: {:?}", args);
    if args.len() < 2 {
        return Err("ERROR No command given".to_string());
    }
    ...
}
```

This way, we can pass a command like `dkr uname -mno`.

**Running the Command as a Child Process**

```rs
use nix::{self};
use nix::{
    sys::wait::waitpid,
    unistd::{fork, ForkResult},
};
use std::{
    env,
    process::{self, ExitCode},
};

mod io {
    // Unsafe to use `println!` (or `unwrap`) here. See Safety.
    pub fn write_stdout(msg: String) {
        nix::unistd::write(std::io::stdout(), msg.as_bytes()).ok();
    }
}

fn run() -> Result<(), String> {
    ...
    let pid = process::id();
    println!("INFO Parent PID {}", pid);
    
    match unsafe { fork() } {
        Ok(ForkResult::Parent { child, .. }) => {
            println!(
                "Continuing execution in parent process, new child has pid: {}",
                child
            );
            waitpid(child, None).unwrap();
            println!("Parent execution done")
        }
        Ok(ForkResult::Child) => {
            // Only pass the command and arguments that need to run
            // inside the container.
            let args = args[1..].to_vec();
            let run_result = Container::new(args).run();
            if let Err(err) = run_result {
                eprintln!("Container error: {}", err);
            }
        }
        Err(_) => println!("Fork failed"),
    };

    Ok(())
}
```

This function implements the main logic of the program.
It forks the process to create a child that will run in a container.
The parent process waits for the child to complete.
We use the [`fork(2)`](https://man7.org/linux/man-pages/man2/fork.2.html) syscall to create a subprocess, which is an unsafe operation in Rust.
After `fork`, we have two processes running the same code, but the `fork` call returns different values to each process so they can tell which is which.

We use the [`nix`](https://docs.rs/nix/latest/nix/) crate for all Linux operations.

> The `nix` crate provides Rust-friendly bindings to various *nix system functions. Modules are structured according to the C header files they would be defined in.

> Note: We can also use the [`clone(2)`](https://man7.org/linux/man-pages/man2/clone.2.html) syscall. However, I felt [`fork(2)`](https://man7.org/linux/man-pages/man2/fork.2.html) with [`unshare(2)`](https://man7.org/linux/man-pages/man2/unshare.2.html) was easier for setting up Linux containers.

**Waiting for the Child to Exit**

```rs
        Ok(ForkResult::Parent { child, .. }) => {
            println!(
                "Continuing execution in parent process, new child has pid: {}",
                child
            );
            waitpid(child, None).unwrap();
            println!("Parent execution done")
        }
```

The parent calls `waitpid()` on the child. This ensures our `dkr` binary doesn't exit when we spin up an interactive shell using `dkr /bin/sh`.

**Setting Up the Container from the Child Process**

```rs
        Ok(ForkResult::Child) => {
            // Only pass the command and arguments that needs to run
            // inside the container
            let args = args[1..].to_vec();
            let run_result = Container::new(args).run();
            if let Err(err) = run_result {
                eprintln!("Container error: {}", err);
            }
        }
```

We create a new `Container` instance and call its `run()` method. This is where we will set up the container environment and execute the command. More on this in the next section.

> Note: We pass only the command and its arguments to the `Container` instance, excluding the `dkr` binary itself.

**Gist Of Overall Flow**

This is the overall flow of the program. The parent process waits for the child to finish, and the child sets up the container and runs the command.

**Initializing The `Container` Object**

See full [container.rs here](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/docker/rust-docker/src/container.rs)

```rs
use std::process::{self};

pub struct Container {
    pid: String,
    command: Vec<String>,
}

impl Container {
    pub fn new(command: Vec<String>) -> Self {
        Container {
            pid: process::id().to_string(),
            command,
        }
    }
```

It is a simple struct that stores the process ID and command of the Child Process.

**Moving Child To A Namespace**

Inside `Container::run()`, the first important thing we do is move the child process into new Linux namespaces.

```rs
pub fn run(&mut self) -> Result<(), String> {
    write_stdout(format!(
        "INFO I'm a new child process with pid {}\n",
        self.pid
    ));

    // Move the current process into a namespace. We can do this
    // by unsharing its CLONE_* flags.
    nix::sched::unshare(CloneFlags::CLONE_NEWUTS | CloneFlags::CLONE_NEWPID)
        .map_err(|e| format!("ERROR Failed to unshare UTS namespace: {}", e))?;

    // change hostname
    nix::unistd::sethostname("container")
        .map_err(|e| format!("ERROR Failed to set hostname: {}", e))?;
    ...
}
```

A Linux namespace gives a process an isolated view of some system resource. Containers are mostly built by combining a bunch of these namespaces: PID, UTS, mount, network, IPC, user namespaces, and so on.

Here, I am creating two namespaces:

- `CLONE_NEWUTS` — creates a new UTS namespace. This isolates the hostname and domain name.
- `CLONE_NEWPID` — creates a new PID namespace. This isolates the process tree seen by processes inside the container.

The UTS namespace is what makes this line safe:

```rs
nix::unistd::sethostname("container")
```

Without `CLONE_NEWUTS`, changing the hostname would affect the host machine. With the new UTS namespace, only processes inside this container-like environment see the hostname as `container`.

The PID namespace has one subtle behavior that I initially had to pause on: the process that calls `unshare(CLONE_NEWPID)` does not immediately become PID `1` inside the new namespace. Instead, the next child process created after the `unshare()` call becomes PID `1` in that namespace.

That is why this later `spawn()` is important:

```rs
let command = process::Command::new(&self.command[0])
    .args(&self.command[1..])
    .stdin(process::Stdio::inherit())
    .stdout(process::Stdio::inherit())
    .stderr(process::Stdio::inherit())
    .spawn();
```

The `dkr` child process calls `unshare()`, sets up the container environment, and then spawns the actual command. That spawned command is the one that becomes PID `1` inside the new PID namespace.

So the rough process hierarchy looks like this:

```txt
host shell
└── dkr parent process
    └── dkr child process
        └── command running inside new PID namespace as PID 1
```

At this point, the command has an isolated hostname and an isolated process tree. This is one of the core building blocks that makes the process start to feel like it is running inside a container instead of directly on the host.
