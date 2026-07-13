---
layout: default
title: "Containers From Scratch: Building a Tiny Docker Runtime in Rust"
date: 2026-07-03
permalink: /devlog/20260703-containers-from-scratch-rust-docker/
---

{% include sidebar.html %}

# Containers From Scratch: Building a Tiny Docker Runtime in Rust

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

```text
host shell
└── dkr parent process
    └── dkr child process
        └── command running inside new PID namespace as PID 1
```

At this point, the command has an isolated hostname and an isolated process tree. This is one of the core building blocks that makes the process start to feel like it is running inside a container instead of directly on the host.

**Changing The Root Filesystem**

At this point, the command has an isolated hostname and process tree. However, it can still see the host machine's filesystem.

I use [`chroot(2)`](https://man7.org/linux/man-pages/man2/chroot.2.html) to change the root directory seen by the command:

```rs
// change root
nix::unistd::chroot("/alpine-root")
    .map_err(|e| format!("Failed to change root: {}", e))?;
```

After this call, `/alpine-root` becomes `/` for the command running inside the container.

For example, these paths will now point to files inside the Alpine root filesystem:

```text
/bin/sh         -> /alpine-root/bin/sh
/etc/os-release -> /alpine-root/etc/os-release
```

This is why running `cat /etc/os-release` inside the container shows Alpine Linux:

```sh
# cat /etc/os-release
NAME="Alpine Linux"
ID=alpine
VERSION_ID=3.24.1
...
```

It is important to note that we are not running an Alpine kernel. Containers share the host machine's Linux kernel. In this case, Alpine only provides the userspace files and commands inside `/alpine-root`.

> Note: `chroot()` is not a security boundary by itself. This project does not yet create a mount namespace, mount `/proc`, isolate the network, or restrict resources using cgroups. It only changes the filesystem root seen by the command.

One small detail I still need to address is the current working directory. `chroot()` changes the root directory, but it does not automatically move the process into that directory. The safer version would call `chdir("/")` immediately afterward:

```rs
nix::unistd::chdir("/")
    .map_err(|e| format!("Failed to change directory: {}", e))?;
```

This ensures the process starts from `/` inside the new root filesystem.

**Executing The Command**

After setting up the namespaces, hostname, and root filesystem, the container is ready to run the command passed to `dkr`.

```rs
let command = process::Command::new(&self.command[0])
    .args(&self.command[1..])
    .stdin(process::Stdio::inherit())
    .stdout(process::Stdio::inherit())
    .stderr(process::Stdio::inherit())
    .spawn();
```

The first item in `self.command` is the executable, and everything after it is passed as arguments.

For example:

```sh
sudo ./target/debug/dkr uname -mno
```

becomes roughly:

```rs
process::Command::new("uname")
    .args(["-mno"])
```

The command is resolved after `chroot()`, so executables such as `/bin/sh` and `uname` come from the Alpine root filesystem rather than the host filesystem.

As mentioned earlier, this `spawn()` also creates the first child after `CLONE_NEWPID` was set up. Therefore, the spawned command becomes PID `1` inside the new PID namespace.

**Inheriting The Terminal**

The container command inherits standard input, output, and error from `dkr`:

```rs
.stdin(process::Stdio::inherit())
.stdout(process::Stdio::inherit())
.stderr(process::Stdio::inherit())
```

This is why an interactive command such as the following works:

```sh
sudo ./target/debug/dkr /bin/sh
```

The shell reads input from the same terminal and writes its output back to it.

There is no terminal emulator, daemon, socket, or attach mechanism here. The container command is simply connected directly to the terminal that started `dkr`.

**Waiting For The Command To Finish**

After spawning the command, the `dkr` child waits for it to exit:

```rs
match command {
    Ok(mut command) => {
        command.wait().expect("command wasn't running");

        write_stdout(format!(
            "INFO Child command has finished its execution!\n"
        ));
    }
    Err(e) => {
        write_stdout(format!(
            "ERROR Failed to execute Child command: {}\n",
            e
        ));
    }
}
```

This gives us two levels of waiting:

```text
dkr parent
    waits for
dkr child
    waits for
container command
```

The outer parent keeps the main `dkr` process alive. The inner child keeps the container setup process alive until the requested command finishes.

Once the command exits, the `Container` object is dropped.

**Cleaning Up The Container Process**

The `Container` struct implements `Drop`:

```rs
impl Drop for Container {
    fn drop(&mut self) {
        write_stdout(format!(
            "INFO Container with pid {} has been dropped!\n",
            self.pid
        ));
        unsafe { nix::libc::exit(0) };
    }
}
```

There is no persistent container object to delete here. The “container” is only a group of settings applied to a process: namespaces, a hostname, and a changed root filesystem.

When the process exits, the kernel cleans up its namespaces after no processes are using them anymore.

The Alpine files under `/alpine-root` remain on the host because they were created before running `dkr`. This project does not manage container images or remove root filesystems.

**Why `write_stdout()` Is Used In The Child**

The child uses this small helper for some of its output:

```rs
mod io {
    // Unsafe to use `println!` (or `unwrap`) here. See Safety.
    pub fn write_stdout(msg: String) {
        nix::unistd::write(std::io::stdout(), msg.as_bytes()).ok();
    }
}
```

Calling `fork()` from a Rust program requires some care. The child receives a copy of the parent process's memory, including the state of userspace locks. Higher-level output functions may depend on those locks.

The helper calls the lower-level [`write(2)`](https://man7.org/linux/man-pages/man2/write.2.html) operation through the `nix` crate. For this small project, it keeps the output path after `fork()` simple.

This is also one reason a real container runtime generally needs more careful process management than this learning implementation.

**Gist Of The Complete Flow**

The complete flow of `dkr` is now:

```text
1. Read the command from the CLI.
2. Fork the dkr process.
3. Keep the parent waiting for the child.
4. Create new UTS and PID namespaces in the child.
5. Change the hostname to container.
6. Change the root filesystem to /alpine-root.
7. Spawn the requested command.
8. Run that command as PID 1 in the new PID namespace.
9. Connect the command to the current terminal.
10. Wait for it to exit.
```

In code, the important Linux operations are:

```text
fork()
  |
  v
unshare(CLONE_NEWUTS | CLONE_NEWPID)
  |
  v
sethostname("container")
  |
  v
chroot("/alpine-root")
  |
  v
spawn(command)
  |
  v
wait()
```

That is enough to produce the result shown at the beginning of this devlog:

```sh
msharran@ubuntu$ sudo ./target/debug/dkr sh
# uname -mno
container x86_64 Linux
# cat /etc/os-release
NAME="Alpine Linux"
ID=alpine
VERSION_ID=3.24.1
...
```

The hostname comes from the UTS namespace. The isolated process tree comes from the PID namespace. The Alpine commands and files come from `chroot("/alpine-root")`. The Linux kernel still comes from the host.

## What I Want To Remember

A container is not one special Linux feature. It is a normal process with several Linux isolation and resource-control features applied around it.

For this implementation, my mental model is:

```text
normal Linux process
  |
  +-- UTS namespace -> isolated hostname
  |
  +-- PID namespace -> isolated process tree
  |
  +-- chroot         -> different filesystem root
  |
  +-- inherited I/O -> interactive terminal
  |
  `-- Alpine rootfs  -> container userspace
```

Docker and other container runtimes build on the same Linux primitives, but they add the missing namespaces, cgroups, security controls, image management, networking, storage, and lifecycle handling.

## Key Take Aways

1. A container is still a process running on the host's Linux kernel.
2. `fork()` creates the child process used to prepare the container environment.
3. `unshare()` gives that process new namespace views.
4. The UTS namespace allows the container to have its own hostname.
5. The first child created after `CLONE_NEWPID` becomes PID `1` inside the new PID namespace.
6. `chroot()` changes the filesystem root seen by the command.
7. An Alpine root filesystem provides Alpine userspace, not an Alpine kernel.
8. Inheriting standard I/O is enough to make a basic interactive shell work.
9. Namespaces and `chroot()` alone do not make a secure container.
10. A tiny implementation is enough to understand the basic shape of a container runtime.

From here, the project can grow carefully: add a mount namespace and mount `/proc`, add network isolation, restrict resources using cgroups, introduce user namespaces, and handle signals and PID `1` responsibilities properly.

However, I'm going to stop here.
