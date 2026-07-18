---
layout: default
title: "Building a Redis Server in Zig, Part 1: Parsing RESP"
date: 2026-07-18
permalink: /devlog/20260718-building-redis-server-zig-part-1-resp/
---

# Building a Redis Server in Zig, Part 1: Parsing RESP

The entire project discussed in this devlog is linked below.

[github.com/msharran/codingchallenges.fyi/redis-server/zig-redis-server](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/redis-server/zig-redis-server/README.md?plain=1#L1-L52)

## Setting Some Context

I have mostly used Redis as an in-memory cache without thinking much about what happens after I run a command. I wanted to understand that boundary, so I built a small Redis-compatible server in Zig.

At its simplest, I can think of Redis as a server that stores data against keys:

```text
SET name msharran
GET name
```

Even with this simple mental model, Redis is still a client-server application.

When I run `redis-cli`, the CLI connects to the Redis server over TCP. It converts the command into bytes, sends those bytes to the server, waits for a response, and converts the response back into something readable.

```text
redis-cli
    |
    | TCP request
    v
Redis server
    |
    | TCP response
    v
redis-cli
```

My Zig implementation supports a small subset of Redis:

- `PING`
- `ECHO`
- `SET`
- `GET`
- `CONFIG GET`

It is enough for me to connect using the normal `redis-cli` and understand the important parts of a Redis server without trying to reimplement all of Redis.

I am splitting this project into two devlogs.

This first part is about the boundary between the client and server: parsing and serialising the Redis protocol.

The second part will cover the rest of the server: accepting connections, routing commands, storing values, memory allocation, the single-threaded event loop, and the performance optimisations I made.

> Note: I consider these devlogs my personal journal of what I’m learning, so I will not be writing a full-fledged article here. I will just write down my learnings and thoughts concisely.

## Realistic Outcome

**Source:** [`README.md` — build, run, and `redis-cli` examples](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/redis-server/zig-redis-server/README.md?plain=1#L25-L52)

The server listens on port `6377`.

```sh
./zig-out/bin/redis-server
```

I can then connect to it using the official Redis CLI:

```sh
redis-cli -p 6377 PING
```

The response is:

```text
PONG
```

I can also set and retrieve a value:

```sh
redis-cli -p 6377 SET name msharran
OK

redis-cli -p 6377 GET name
"msharran"
```

What I type into the terminal looks like plain text. However, that is not exactly what gets sent over the TCP connection.

Redis clients and servers communicate using RESP.

## RESP, Not REST

RESP stands for **Redis Serialization Protocol**. It is the wire protocol used by Redis clients to communicate with Redis servers.

It should not be confused with REST, which is commonly associated with HTTP APIs.

RESP is small enough to read directly. A Redis request is normally represented as an array containing the command followed by its arguments. The [official RESP specification](https://redis.io/docs/latest/develop/reference/protocol-spec/) describes the complete protocol.

For example:

```sh
redis-cli -p 6377 ECHO hello
```

is sent approximately as:

```text
*2\r\n$4\r\nECHO\r\n$5\r\nhello\r\n
```

The request can be split into five small parts:

```text
*2\r\n
$4\r\n
ECHO\r\n
$5\r\n
hello\r\n
```

Line by line:

- `*2` means this is an array containing two items.
- `$4` means the next bulk string contains four bytes.
- `ECHO` is the first item.
- `$5` means the next bulk string contains five bytes.
- `hello` is the second item.
- `\r\n` is CRLF, which RESP uses as a terminator.

After parsing, the request becomes:

```text
["ECHO", "hello"]
```

The first item is the command. Everything after it is an argument to that command.

## RESP Data Types

**Source:** [`Resp.zig` — RESP data types](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/redis-server/zig-redis-server/src/Resp.zig#L27-L63)

RESP uses the first byte of a value to identify its type.

The subset supported by my implementation is:

| Prefix | Type | Example |
|---|---|---|
| `+` | Simple string | `+PONG\r\n` |
| `-` | Error | `-ERR unknown command\r\n` |
| `:` | Integer | `:123\r\n` |
| `$` | Bulk string | `$5\r\nhello\r\n` |
| `*` | Array | `*2\r\n...` |
| `_` | Nil | `_\r\n` |

I represent these types using a Zig enum:

```zig
pub const DataType = enum {
    SimpleString,
    Error,
    Integer,
    BulkString,
    Array,
    Nil,
};
```

The first byte is converted into one of these enum values:

```zig
fn fromChar(data_type: u8) !DataType {
    return switch (data_type) {
        '+' => .SimpleString,
        '-' => .Error,
        ':' => .Integer,
        '$' => .BulkString,
        '*' => .Array,
        '_' => .Nil,
        else => return error.InvalidDataType,
    };
}
```

This is the first step in parsing any RESP message.

```text
first byte -> RESP data type -> type-specific parsing
```

## Representing A RESP Message In Zig

**Source:** [`Resp.zig` — `Value` and `Message`](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/redis-server/zig-redis-server/src/Resp.zig#L66-L107)

A RESP value can either contain a byte string or a list of other messages.

I represent that using a tagged union:

```zig
pub const Value = union(ValueTag) {
    list: std.ArrayList(Message),
    single: []const u8,
};
```

A complete message contains its RESP type and value:

```zig
pub const Message = struct {
    type: DataType,
    value: Value,
};
```

For example:

```text
+PONG\r\n
```

becomes roughly:

```zig
Message{
    .type = .SimpleString,
    .value = .{ .single = "PONG" },
}
```

An `ECHO hello` request becomes an array message:

```text
Message(Array)
├── Message(BulkString, "ECHO")
└── Message(BulkString, "hello")
```

This gives the rest of the server one consistent representation. The command router does not need to understand raw RESP bytes. It only receives a `Message`.

## Deserialising Simple Values

**Source:** [`Resp.zig` — `deserialise()`](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/redis-server/zig-redis-server/src/Resp.zig#L109-L157)

The main parsing function is:

```zig
pub fn deserialise(self: *Resp, raw: []const u8) !Message
```

It first reads the data type:

```zig
const data_type = try DataType.fromChar(raw[0]);
```

Simple strings, errors, integers, and nil values have a similar shape. Their value starts after the first byte and ends before the final CRLF:

```zig
.SimpleString, .Error, .Integer, .Nil => {
    const value = raw[1 .. raw.len - CRLF_LEN];
    const last_2_bytes = raw[raw.len - CRLF_LEN ..];

    if (!std.mem.eql(u8, last_2_bytes, CRLF)) {
        return error.InvalidTerminator_ShouldBeCRLF;
    }

    return Message.init(data_type, value);
},
```

For example:

```text
+PONG\r\n
```

is split into:

```text
+        -> SimpleString
PONG     -> value
\r\n     -> terminator
```

## Deserialising Bulk Strings

**Source:** [`Resp.zig` — bulk-string parsing](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/redis-server/zig-redis-server/src/Resp.zig#L124-L142)

Bulk strings are length-prefixed:

```text
$<length>\r\n<content>\r\n
```

For example:

```text
$5\r\nhello\r\n
```

The parser splits the message using CRLF and reads the length after `$`:

```zig
const length_part = parts.first();
const len = try std.fmt.parseInt(usize, length_part[1..], 10);
```

It then reads the content and verifies its length:

```zig
const string_part = parts.next() orelse {
    return error.MissingContent;
};

if (string_part.len != len) {
    return error.ContentLengthMismatch;
}
```

The length prefix tells the parser exactly how many bytes belong to the string, so the content does not need quoting or escaping.

## Deserialising Arrays

**Source:** [`Resp.zig` — array parsing](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/redis-server/zig-redis-server/src/Resp.zig#L143-L209)

Redis commands are normally sent as arrays, so this is the most important part of the request parser.

Given:

```text
*2\r\n$4\r\nECHO\r\n$5\r\nhello\r\n
```

`getArrayItems()` first separates the raw request into two complete RESP messages:

```text
$4\r\nECHO\r\n
$5\r\nhello\r\n
```

The parser then recursively calls `deserialise()` for every item:

```zig
for (raw_msgs) |msg| {
    const m = try self.deserialise(msg);
    try list.append(m);
}
```

The result is returned as an array message:

```zig
return Message.initList(data_type, list);
```

This recursion means an array is not a special command-specific structure. It is simply a RESP value containing other RESP values.

The RESP parser does not need to know what `ECHO`, `GET`, or `SET` means. Its only job is to turn bytes into messages.

Command interpretation happens later.

## Serialising The Response

**Source:** [`Resp.zig` — `serialise()`](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/redis-server/zig-redis-server/src/Resp.zig#L211-L274)

For responses, I do the same work in reverse.

```zig
pub fn serialise(self: *Resp, m: Message) ![]u8
```

For a simple string:

```zig
Message.simpleString("PONG")
```

the serialiser produces:

```text
+PONG\r\n
```

For a bulk string:

```zig
Message.bulkString("hello")
```

it produces:

```text
$5\r\nhello\r\n
```

Arrays are serialised recursively. The serialiser calculates the size of the array header and every nested message, allocates one output buffer, and copies each serialised element into it.

The complete request and response boundary now looks like this:

```text
TCP request bytes
    |
    v
Resp.deserialise()
    |
    v
Message
    |
    v
command handler
    |
    v
Message
    |
    v
Resp.serialise()
    |
    v
TCP response bytes
```

## Request-Scoped Memory

**Source:** [`Resp.zig` — arena allocator](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/redis-server/zig-redis-server/src/Resp.zig#L12-L25), [`redis.zig` — request buffer and parser lifetime](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/redis-server/zig-redis-server/src/redis.zig#L74-L109)

Parsing arrays creates several temporary allocations: the list of raw items, the reconstructed messages, and the final array of parsed messages.

I use an arena allocator inside `Resp`:

```zig
arena: std.heap.ArenaAllocator,
```

The allocations belong to the lifetime of one request. Once the request has been parsed, routed, serialised, and written back, I can release the entire arena together:

```zig
var resp = Resp.init(allocator);
defer resp.deinit();
```

This is simpler than individually tracking every allocation created while recursively parsing an array.

The server currently backs the request work with a fixed buffer allocator created from a stack buffer. I will cover that optimisation and its benchmark impact in the next devlog because it belongs to the overall server architecture.

## One Important Boundary

**Source:** [`redis.zig` — socket read and deserialise boundary](https://github.com/msharran/codingchallenges.fyi/blob/fc15a9fb6b23838df810eb6ca2b6c24d6bbbb220/redis-server/zig-redis-server/src/redis.zig#L74-L103)

The current implementation reads bytes from the connection and passes that buffer directly to `deserialise()`.

That works for the requests I used while building the challenge, but TCP itself does not preserve message boundaries. One read could contain only part of a RESP message, or it could contain several messages sent using pipelining.

A more complete parser would need to retain incomplete bytes between reads and report how many bytes it consumed from the buffer.

I want to remember this distinction:

```text
RESP defines message boundaries.
TCP only provides a stream of bytes.
```

Parsing RESP and reading from a socket are related problems, but they are not the same problem.

## What I Want To Remember

The part that initially looked cryptic:

```text
*2\r\n$4\r\nECHO\r\n$5\r\nhello\r\n
```

is just a typed, length-prefixed representation of:

```text
["ECHO", "hello"]
```

The first byte tells me the type. CRLF separates the metadata. Length prefixes tell me how much content to read. Arrays allow the command and its arguments to be represented using the same protocol as every other value.

Once the request is converted into a `Message`, the rest of the server no longer needs to care how it arrived over the network.

## Key Take Aways

- Redis clients and servers communicate using RESP, not REST.
- RESP is the wire format; Redis commands are the meaning carried inside that format.
- Redis requests are normally arrays containing the command and its arguments.
- The first byte identifies the RESP data type.
- Bulk strings use byte lengths instead of quoting and escaping.
- Arrays can be parsed and serialised recursively.
- The protocol parser should produce a command-independent representation.
- RESP message boundaries and TCP read boundaries are different things.
- Memory allocation is part of protocol-parser performance, not a separate concern.

At this point, I have crossed the first boundary of the Redis server: turning bytes from `redis-cli` into messages and turning the response messages back into bytes.

However, I am going to stop here.

In the next part, I will go through how the complete Redis server fits together: Facil.io, the single-threaded event loop, connection callbacks, command routing, the in-memory dictionary, and the optimisations and their benchmark impact.
