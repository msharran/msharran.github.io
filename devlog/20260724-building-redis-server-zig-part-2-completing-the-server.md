---
layout: default
title: "Building a Redis Server in Zig, Part 2: Completing the Server"
date: 2026-07-24
permalink: /devlog/20260724-building-redis-server-zig-part-2-completing-the-server/
---

# Building a Redis Server in Zig, Part 2: Completing the Server

The entire project discussed in this devlog is linked below.

[github.com/msharran/codingchallenges.fyi/redis-server/zig-redis-server](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/redis-server/zig-redis-server/README.md?plain=1#L1-L122)

## Picking Up From RESP

In the [first part](/devlog/20260718-building-redis-server-zig-part-1-resp/), I stopped after turning RESP bytes into a Zig `Message`.

That was the boundary between the client and the protocol parser. This part is about what happens after that:

```text
redis-cli
    |
    | TCP request
    v
Facil.io connection
    |
    v
Resp.deserialise()
    |
    v
Router
    |
    v
Command handler
    |
    v
Dictionary
    |
    v
Resp.serialise()
    |
    v
TCP response
```

The implementation still supports the same small set of commands:

- `PING`
- `ECHO`
- `SET`
- `GET`
- `CONFIG GET`

The interesting part is no longer the number of commands. It is how the pieces fit together.

## Starting The Server

**Source:** [`main.zig` and `redis.zig`](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/redis-server/zig-redis-server/src/redis.zig)

The entry point is deliberately small:

```zig
pub fn main() !void {
    redis.init();
    defer redis.deinit();

    try redis.start();
}
```

`init()` prepares the long-lived server state:

- the global allocator
- the command router
- the in-memory dictionary

`start()` configures Facil.io and listens on port `6377`.

```zig
const args = fio.fio_start_args{
    .threads = 1,
    .workers = 1,
};
```

The final version uses one event-loop thread and one worker. I had initially used a multi-threaded design with locks around the dictionary. For this small server, the simpler single-threaded design performed better because requests could access the shared dictionary without lock contention.

This is also a useful reminder that non-blocking I/O and multiple application threads are separate choices. Facil.io can provide the evented I/O model while the Redis state remains in one thread.

## The Connection Lifecycle

**Source:** [`redis.zig` — connection callbacks](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/redis-server/zig-redis-server/src/redis.zig)

When a client connects, `on_open()` creates a Facil.io protocol object and attaches two callbacks to the connection:

```zig
fio_proto.* = fio.fio_protocol_s{
    .on_data = on_data,
    .on_close = on_close,
};
```

The connection is given a five-second timeout and then waits for data.

When data arrives, `on_data()` handles the complete request-response path. When the connection closes, `on_close()` releases the protocol object that was allocated for that connection.

```text
connection opened -> attach callbacks -> receive data
                                           |
                                           v
                                      handle request
                                           |
                                           v
connection closed -> free protocol object
```

The callback is where the protocol parser from Part 1 becomes part of an actual server.

## Handling One Request

**Source:** [`redis.zig` — `on_data()`](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/redis-server/zig-redis-server/src/redis.zig#L68-L122)

For each callback, I create a fixed buffer backed by a stack array:

```zig
var buf: [4096]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&buf);
const allocator = fba.allocator();
```

The request buffer is allocated from this fixed buffer and passed to Facil.io for reading. The bytes are then handed to `Resp.deserialise()`.

```zig
const msg = if (read == 0)
    Message.err("empty request")
else
    resp.deserialise(read_buffer[0..read]) catch |err| blk: {
        log.err("failed to deserialise: {}", .{err});
        break :blk Message.err("failed to deserialise");
    };
```

At this point, the server has a structured `Message`, but it still does not know whether the request is `GET`, `SET`, or something else. That decision belongs to the router.

After routing, the response is serialised back into RESP and written to the connection using `fio.write2()`.

```text
read bytes
    -> parse RESP
    -> route Message
    -> create response Message
    -> serialise RESP
    -> write bytes
```

There is one important limitation here. The current code reads into a fixed `1024`-byte request buffer and handles the data available to the callback as one request. A more complete server would need buffering for partial TCP reads and pipelined requests, which is separate from parsing the RESP format itself.

## Routing Commands

**Source:** [`Router.zig`](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/redis-server/zig-redis-server/src/Router.zig), [`command.zig`](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/redis-server/zig-redis-server/src/command.zig)

The router uses a compile-time `StaticStringMap`:

```zig
const routes: []const RouterKV = &.{
    .{ "PING", command.ping },
    .{ "ECHO", command.echo },
    .{ "SET", command.set },
    .{ "GET", command.get },
    .{ "CONFIG", command.config },
};
```

The router expects the parsed message to be an array. The first item is the command and the remaining items are arguments.

```text
["SET", "name", "msharran"]
        |
        +-- command: SET
        +-- argument: name
        +-- argument: msharran
```

If the message is not an array, has no items, or contains an unknown command, the router returns a RESP error message. The parser does not need to know about these errors. It only produces the structure that the router expects.

Each command receives a `CommandCtx` containing the request message and an arena allocator for command-specific response data.

## Storing Values

**Source:** [`dictionary.zig`](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/redis-server/zig-redis-server/src/dictionary.zig)

The data store is a `std.StringHashMap` whose values are currently a tagged union containing one variant:

```zig
pub const Value = union(enum) {
    string: []const u8,
};
```

`SET` cannot retain slices pointing into the request buffer because that buffer belongs to the current callback. The dictionary therefore copies both the key and the value before storing them.

```zig
const key_copy = try self.allocator.dupe(u8, key);
const value_copy = try self.allocator.dupe(u8, value);

try self.map.put(key_copy, Value{ .string = value_copy });
```

Updating an existing key follows a slightly different path. The key can stay where it is, but the old value is freed before the new value is installed.

```text
request buffer
    |
    | SET name msharran
    v
dictionary owns copies
    |
    +-- key: name
    +-- value: msharran
```

For `GET`, a missing key becomes a RESP nil value. This is a small example of the command layer translating storage semantics into protocol semantics.

When the server shuts down, the dictionary walks through every entry, frees each key and value, and then deinitialises the hash map.

## A Small CONFIG Compatibility Layer

`redis-benchmark` tries to run `CONFIG GET` before benchmarking. Without that command, the benchmark prints:

```text
WARNING: Could not fetch server CONFIG
```

I added a small compatibility implementation for two parameters:

```text
CONFIG GET save
        -> ["save", "900 1 300 10"]

CONFIG GET appendonly
        -> ["appendonly", "no"]
```

This does not add persistence or append-only logging. It only returns enough of the expected configuration shape for the client tooling to continue. Unknown parameters return an empty array.

I like this kind of compatibility layer because it keeps the core implementation small. The server does not need to implement every Redis feature to behave usefully with an existing client.

## Allocator Choices

**Source:** [`global.zig`](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/redis-server/zig-redis-server/src/global.zig), [`redis.zig`](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/redis-server/zig-redis-server/src/redis.zig)

There are two different memory lifetimes in this server.

The dictionary and connection protocol objects are long-lived, so they use the global allocator. In debug builds, that is normally Zig's `GeneralPurposeAllocator`, which gives me leak detection. In release builds linked with libc, the implementation can use the C allocator instead.

Request parsing and response serialisation are short-lived. Those allocations use the fixed buffer allocator created inside `on_data()` and disappear with the callback's stack buffer.

The `CONFIG GET` response also demonstrates a third lifetime. Its response array is allocated from the `CommandCtx` arena and released when the command context is deinitialised.

```text
server lifetime       -> global allocator
request lifetime      -> fixed buffer allocator
command response data -> CommandCtx arena
```

The shutdown order is explicit:

```zig
fio.fio_stop();
global.deinitDictionary();
global.deinitRouter();
global.deinitAllocator();
```

The main lesson for me is that allocator choice follows ownership and lifetime. It is not just a global performance setting.

## Measuring The Optimisations

The README records three stages of `redis-benchmark` results for `SET` and `GET`:

| Version | SET | GET |
|---|---:|---:|
| Initial implementation | 17,513 req/sec, p50 2.647 ms | 22,868 req/sec, p50 2.007 ms |
| Fixed buffer allocation | 107,527 req/sec, p50 0.239 ms | 90,172 req/sec, p50 0.303 ms |
| Single-threaded design | 140,449 req/sec, p50 0.183 ms | 142,450 req/sec, p50 0.183 ms |

The largest jump came from moving request I/O and RESP work from heap allocation to a fixed buffer allocator. The later move to one thread improved the result further by removing lock overhead from the shared dictionary.

The latest recorded comparison was close to the original Redis server on the same benchmark:

| Server | Command | Requests/sec | Latency (p50) |
|---|---|---:|---:|
| Zig Redis, port 6377 | SET | 140,449.44 | 0.183 ms |
| Original Redis, port 6379 | SET | 146,198.83 | 0.175 ms |
| Zig Redis, port 6377 | GET | 142,450.14 | 0.183 ms |
| Original Redis, port 6379 | GET | 140,646.97 | 0.183 ms |

I do not want to read too much into a single benchmark run. It is still useful as a direction-finder: it showed me that the allocation model and concurrency model mattered more than adding complexity to the command handlers.

## Gist Of The Complete Flow

The complete server path now looks like this:

```text
main()
  |
  +-- redis.init()
  |     +-- allocator
  |     +-- router
  |     +-- dictionary
  |
  +-- redis.start()
        +-- fio_listen(6377)
        +-- on_open()
              +-- attach on_data / on_close
              +-- on_data()
                    +-- read request bytes
                    +-- deserialise RESP
                    +-- route command
                    +-- read or update dictionary
                    +-- serialise response
                    +-- write response bytes
```

The server is small, but the boundaries are similar to a larger network service:

- the transport owns the connection lifecycle
- the protocol layer owns bytes and message structure
- the router owns command selection
- handlers own command semantics
- the dictionary owns stored data
- allocators make those ownership boundaries explicit

## What I Want To Remember

The first part of this project taught me that Redis commands are just structured RESP messages on a TCP stream.

This part made the next boundary visible: a working server is not only a parser and a socket. It also needs a lifecycle, a routing layer, storage ownership, and a clear answer to how long every byte should live.

The implementation became faster when I removed work from the hot path:

```text
heap allocation per request -> fixed buffer allocation
multiple threads + locks     -> one event-loop thread
```

Neither change is universally correct. They work here because the server has a small command set and one shared in-memory dictionary. The important part was measuring the result after each change instead of assuming that a more concurrent design would automatically be faster.

## Key Take Aways

- Facil.io handles the connection lifecycle while the Redis logic stays in Zig callbacks.
- A single-threaded event loop can simplify access to shared state and improve performance for this workload.
- The router can be a small compile-time map from command names to handlers.
- Stored keys and values must be copied because request buffers are temporary.
- `CONFIG GET` is enough to make common Redis tooling work without implementing Redis persistence.
- Fixed buffer allocation removes much of the short-lived allocation work from the request path.
- Allocator choice is really an ownership and lifetime decision.
- Benchmarking helped choose the simpler architecture.
- RESP message boundaries and TCP read boundaries are still different things.

At this point, I have a small Redis-compatible server that accepts real `redis-cli` requests, stores string values, returns RESP responses, and performs close to the original Redis server on the recorded benchmark.

It is nowhere near a complete Redis implementation, but it is enough to make the request path from TCP bytes to a stored value feel concrete.

However, I'm going to stop here.
