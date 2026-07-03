---
layout: default
title: "[WIP] Containers From Scratch: Building A Tiny Docker Runtime In Rust"
date: 2026-07-03
permalink: /devlog/20260703-containers-from-scratch-rust-docker/
---

# [WIP] Containers From Scratch: Building A Tiny Docker Runtime In Rust

The entire project discussed in this demo is linked below.

[github.com/msharran/codingchallenges.fyi/docker/rust-docker](https://github.com/msharran/codingchallenges.fyi/blob/main/docker/rust-docker/README.md)

<!-- Draft goes here. -->

## Setting Some Context

I know basic rust which I learnt out of curiosity. However, I have written some [projects in Zig](https://github.com/msharran/codingchallenges.fyi/tree/main/redis-server/zig-redis-server), so I know a thing or two about systems programming. I also have a background in Infrastructure engineering, so I know a little bit about linux and containers.

> Note: I consider these devlogs as my personal journal of my learnings. So, I will not be writing a full-fledged article here. I will just write down my learnings and thoughts in a concise manner.

## My Local Setup

- My development environment for this project is a Ubuntu VM provisioned using [OrbStack](https://orbstack.dev/) running inside a Macbook.

```sh
~/r/p/c/d/rust-docker> orbctl list
NAME    STATE    DISTRO  VERSION   ARCH   SIZE    IP
----    -----    ------  -------   ----   ----    --
ubuntu  running  ubuntu  resolute  amd64  5.8 GB  192.168.139.104

~/r/p/c/d/rust-docker> orb

msharran@ubuntu:rust-docker$ uname -mno
ubuntu x86_64 GNU/Linux
```

- The `rust-docker` binary name called `dkr`, which I will be using in the rest of this devlog.
- [Alpine Linux](https://alpinelinux.org/) as the container's distribution. Placed it in `/alpine-root` using the following commands,

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

From the code that I have written, it won't exactly feel like docker, however, it is the essence of what docker does.

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

**Line Wise Breakdown**

Line 1: 
- `sudo` — is needed because we need `root` access to provision linux namespaces.
- `./target/debug/dkr` — is the rust executable build using `cargo build`. (See [Makefile](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/docker/rust-docker/Makefile#L1))
- `sh` — Command to run inside the container. Here it is the [Bourne Shell](https://en.wikipedia.org/wiki/Bourne_shell)

Line 2: 
- `#` — Shell prompt indicator
- `uname -mno` — Running `uname` command inside the container

Line 3:
- `container x86_64 Linux` — Tells us the container's hostname is `container`, arch is `x86_64` and OS is `Linux`

Line 4: 
- `cat /etc/os-release` — Checking the OS release name and ID

Line 5:
- `NAME="Alpine Linux"` — Container is now running "Alpine Linux"

## Building It

Full project is available [here](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/docker/rust-docker/README.md)

**Project Structure**

It is a very minimal rust project. We will be focusing on `main.rs` first, then on `container.rs` later.

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

**Setting Up The CLI Entrypoint**

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

We setup a simple entrypoint using `fn main()` which returns exit code `0` on `fn run()`'s success and fail with an exit code on failure.

**Getting The Command To Run As Argument**

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

This way, we can pass command like `dkr uname -mno`

**Running The Command As Child Process**

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
             Only pass the command and arguments that needs to run
             inside the container
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
We use `fork()` which is unsafe as it creates a completely new process.
After `fork()` we have two processes running the same code, but the `fork()` call returns different values to each process so they can tell which is which.

We use the [`nix`](https://docs.rs/nix/latest/nix/) crate for all linux operations. 

> Nix crate is a Rust friendly bindings to the various *nix system functions. Modules are structured according to the C header file that they would be defined in.

**Waiting For The Child To Exit**

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

Parent calls `waitpid()` on Child. This ensures our `dkr` binary doesn't exit when we spin up a Shell interactively using `dkr /bin/sh`
