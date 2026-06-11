# Skitarii Chat

Skitarii Chat adds a small Mechanicus-themed chat feature to Warhammer 40,000: Darktide. It can encode only messages sent with `/skc`, encode every normal message, or leave outgoing chat untouched. Incoming decoding can be enabled or disabled separately.

The default **Command only** mode works by typing `/skc` followed by a message:

```text
/skc Praise the Omnissiah
```

Players who have Skitarii Chat installed see the readable message locally, marked with Darktide's Mechanicus glyph. Players without the mod see an opaque, chat-safe encoded string instead.

Normal chat is unchanged, and other commands continue to work normally.

> [!IMPORTANT]
> Skitarii Chat is thematic encoding, not encryption. It does not provide privacy or protect sensitive information.

## Features

- Adds the `/skc <message>` chat command.
- Provides Off, Always, and Command only outgoing encoding modes.
- Allows incoming SKC1 decoding to be switched off independently.
- Lets any player stop outgoing encoding for the current location with a shared safe word.
- Supports a configurable keybind for enabling or disabling the entire mod.
- Encodes outgoing messages into an opaque Base64url packet.
- Decodes valid packets locally for other mod users and for the sender.
- Supports arbitrary UTF-8 text, including non-English text and emoji.
- Splits longer messages into multiple chat-safe packets.
- Reassembles chunks even if they arrive out of order.
- Limits outgoing chunks to reduce accidental chat spam.
- Leaves invalid or unrelated Mechanicus-prefixed messages untouched.
- Includes optional protocol and chunk diagnostics.

## What Players See

When a player enters:

```text
/skc The motive force guides us.
```

A player with the mod sees:

```text
[Mechanicus glyph] The motive force guides us.
```

A player without the mod sees something similar to:

```text
[Mechanicus glyph]<opaque-base64url-packet>
```

The encoded text is randomized because every packet uses a random nonce and every message receives a random 16-bit message ID.

## Installation

Skitarii Chat requires:

- Darktide Mod Loader
- Darktide Mod Framework (DMF)

Install it like a normal DMF mod:

1. Place the included `SkitariiChat` folder in the Darktide `mods` directory.
2. Add `SkitariiChat` to `mod_load_order.txt`.
3. Start Darktide.
4. Open chat and send `/skc Praise the Omnissiah`.

Every player who should see decoded messages needs the mod installed, enabled, and configured to decode incoming messages.

## Usage

### Command only

This is the default mode. Use the command in any chat channel selected by the normal Darktide chat UI:

```text
/skc <message>
```

Examples:

```text
/skc Binary cant transmission authenticated.
/skc Omnissiah, preserve this strike team.
/skc Coordinates received: sector 7.
```

Entering `/skc` without a message displays:

```text
Usage: /skc <message>
```

If the message exceeds the configured chunk limit, no packets are sent and the mod displays:

```text
Skitarii Chat message is too long.
```

### Always

Every normal outgoing chat message is encoded automatically. Slash commands remain commands rather than being encoded as literal text. `/skc` remains available as an explicit encoding command.

### Off

Outgoing messages are never encoded. This does not change the separate incoming decoding setting.

### Toggle keybind

The optional keybind uses DMF's mod toggle. Disabling the mod stops outgoing encoding, incoming decoding, and the `/skc` command. Re-enabling it restores the configured encoding mode. Skitarii Chat echoes its new enabled or disabled state whenever the keybind is used.

Toggling only affects messages processed afterward. Messages already present in chat history are not revisited, encoded again, decoded again, or otherwise changed.

### Safe word

Any player can send the following as a normal chat message:

```text
SKITUSSY
```

Detection is case-insensitive and triggers when `skitussy` appears anywhere in a normal chat message, for example `Hey SKITUSSY stfu!!`. Every Skitarii Chat user who receives it stops encoding outgoing messages for the current mission, hub, or other gameplay instance. In **Always** mode, messages return to ordinary chat; `/skc` is blocked with a local notice. Incoming SKC1 messages can still be decoded.

The phrase is always sent as readable text, including in **Always** mode. Encoding becomes available again when the next gameplay instance begins.

## Settings

| Setting | Default | Description |
| --- | ---: | --- |
| Outgoing encoding mode | Command only | `Off` never encodes outgoing chat, `Always` encodes every normal message, and `Command only` encodes `/skc` messages. |
| Toggle Skitarii Chat | Unbound | Enables or disables the entire mod through DMF. |
| Decode incoming SKC1 messages | On | Converts valid incoming packets into readable text. When off, packets are displayed unchanged, as they appear to players without the mod. |
| Show decoded Mechanicus marker | On | Adds the Mechanicus glyph before locally decoded messages. |
| Maximum outgoing chunks | 3 | Limits one encoded message to between 1 and 10 chat packets. |
| Enable debug logging | Off | Writes SKC1 send, collection, conflict, and expiration details to the mod log. |

Each packet carries up to 120 payload bytes. The default three-chunk limit therefore supports up to 360 UTF-8 bytes, subject to any additional game-side chat restrictions.

The limit is measured in bytes, not displayed characters. Non-ASCII characters usually consume more than one UTF-8 byte.

## Limitations

- This is obfuscation, not secure encryption.
- Players without the mod see the raw encoded packets.
- One long message appears as several raw chat entries to players without the mod.
- Darktide's display hook supplies the rendered sender name rather than a stable participant ID. Reassembly therefore identifies a message by rendered sender, channel, and random message ID.
- Chat delivery, moderation, filtering, and platform restrictions remain controlled by Darktide and its chat service.
- The protocol does not compress messages.

---

## Important Disclaimer

This mod is **not intended for public games**. If a feature affects other players or behaves like a serverside mod, using it in public matchmaking may violate Fatshark's modding rules and can put your account at risk.

Use it in private environments only, and only if you understand the risk.

The policy guidance this repository follows is:

> For those seeking serverside mods such as True Shirtless and Vacuum Capsule, such mods are intentionally restricted due to them being against Fatshark Modding Policy. The primary reason for this is that they affect unmodded players as such mods force an unintended experience unto them.
>
> I know it's not fun, but honestly we have a super sweet deal going on in terms of modding support. The fact that we can just enable any mod without them having to go through an approval process is awesome, and it's best not to cause enough trouble to force Fatshark to stop this.
>
> The more these serverside mods spread, the more it'll become a potential problem, so us modders want to avoid doing that as much as possible, sorry x,x
>
> Q: Will I be banned for using them?
> A: It's possible. If someone reports you or you mess with the servers, you run the risk of having action taken against you, so it's best to avoid them. Mods that interfere with servers are especially high risk, due to the possibility of crashing servers (which you will immediately get banned for in such cases).
>
> Q: May I still use them anyway?
> A: I suppose, but I doubt any of the modders here will share such mods due to the reasons above. We don't want to encourage any of the behavior, so asking about it will be frowned upon. We want to keep the modding community a healthy environment <3
>
> Q: Are clientside mods still okay?
> A: Yep! As long as you don't affect other players, cheat in any way, or crash the servers you'll be fine. Pretty much all the mods on nexus are fine, including the regular shirtless mod for private use.

# Developer Reference

## Repository Layout

```text
SkitariiChat/
  SkitariiChat.mod
  scripts/mods/SkitariiChat/
    SkitariiChat.lua
    SkitariiChat_data.lua
    SkitariiChat_localization.lua
    SkitariiChat_protocol.lua
tests/
  SkitariiChat_protocol_spec.lua
  SkitariiChat_integration_spec.lua
```

The implementation is deliberately split into two main parts:

- `SkitariiChat_protocol.lua` contains the chat-independent SKC1 encoder and decoder.
- `SkitariiChat.lua` integrates the protocol with DMF and Darktide's chat UI.

This keeps packet behavior testable without loading the game or DMF.

## Protocol Overview

The internal protocol is named `SKC1`.

The visible chat message is:

```text
<U+E029><unpadded-base64url-packet>
```

`U+E029` is Darktide's Mechanicus private-use glyph. The text following it uses the URL-safe Base64 alphabet:

```text
A-Z a-z 0-9 - _
```

Padding is omitted. Standard Base64 characters `+`, `/`, and `=` are never emitted.

The visible string intentionally does not expose separators, version text, chunk labels, or a readable message ID. Those fields exist only inside the encoded binary packet.

## Binary Packet Layout

| Byte | Field | Decoded value |
| ---: | --- | --- |
| 1 | Nonce | Random byte stored directly |
| 2 | Magic | `0x53 XOR nonce` |
| 3 | Version | `0x01 XOR nonce` |
| 4 | Flags | `0x00 XOR nonce` |
| 5 | Message ID high | High byte XOR nonce |
| 6 | Message ID low | Low byte XOR nonce |
| 7 | Part | One-based chunk index XOR nonce |
| 8 | Total | Total chunk count XOR nonce |
| 9 | Checksum | Checksum XOR nonce |
| 10..N | Payload | Each raw payload byte XOR nonce |

Current constants:

```lua
PACKET_MAGIC = 0x53
PACKET_VERSION = 0x01
FLAG_NONE = 0x00
HEADER_SIZE = 9
PAYLOAD_BYTES_PER_PACKET = 120
MAX_VISIBLE_PACKET_LENGTH = 190
MAX_PROTOCOL_CHUNKS = 10
```

The nonce changes the visible representation of all packet fields and payload bytes. This prevents the encoded text from having an obvious static header, but it is not cryptographically secure.

## Checksum

SKC1 uses a one-byte additive checksum:

```text
(
  magic
  + version
  + flags
  + message_id_hi
  + message_id_lo
  + part
  + total
  + sum(payload bytes)
) mod 256
```

The checksum detects malformed or accidentally modified packets. It is not intended to resist deliberate tampering.

## Encoding Flow

`Protocol.encode_message(message, max_chunks, random_byte)` performs these steps:

1. Reject an empty or non-string message.
2. Validate that `max_chunks` is between 1 and 10.
3. Treat the Lua string as raw UTF-8 bytes.
4. Calculate the required number of 120-byte chunks.
5. Reject the message if it exceeds the outgoing chunk limit.
6. Generate one random 16-bit message ID.
7. Generate an independent random nonce for every chunk.
8. Build and XOR-obfuscate each packet.
9. Base64url-encode the binary packet without padding.
10. Prefix the result with `U+E029`.

The optional `random_byte` dependency allows tests to supply deterministic values. Runtime code defaults to `math.random(0, 255)`.

Splitting may occur in the middle of a multibyte UTF-8 character. This is safe because chunks remain raw bytes until the complete message is reassembled.

## Decoding and Validation

`Protocol.decode_visible(message)` returns a decoded packet table only when every validation step succeeds:

```lua
{
    message_id = 4660,
    part = 1,
    total = 2,
    payload = "...raw bytes...",
}
```

Validation includes:

- The message begins with `U+E029`.
- The complete visible message is at most 190 bytes.
- The Base64url body has a valid length and alphabet.
- Decoding and re-encoding produces the same canonical Base64url body.
- The packet contains a header and a non-empty payload.
- Magic is `0x53`.
- Version is `0x01`.
- Flags are `0x00`.
- `total` is between 1 and 10.
- `part` is between 1 and `total`.
- The checksum matches.

Failure returns `nil`. The display hook then passes the original message to Darktide unchanged. Merely starting a message with the Mechanicus glyph is never enough to hide it.

## Chunk Reassembly

Incoming chunks are grouped with the effective key:

```text
rendered_sender + channel + message_id
```

The Lua key uses null-byte separators to avoid ambiguous concatenation:

```lua
sender_key .. "\0" .. channel_key .. "\0" .. message_id
```

Pending state contains:

```lua
{
    sender = sender_key,
    channel = channel_key,
    message_id = message_id,
    total = total,
    created_at = Managers.time:time("main"),
    received = 0,
    chunks = {
        [1] = "...raw bytes...",
        [2] = "...raw bytes...",
    },
}
```

Chunks may arrive in any order. Duplicate identical chunks are ignored. A conflicting total or conflicting payload for the same part resets that pending message rather than combining inconsistent data.

When all parts are present, `table.concat(chunks, "", 1, total)` reconstructs the original byte string. UTF-8 interpretation occurs only after this point.

Incomplete messages expire after 10 seconds. Cleanup is checked at most once per second and only runs from `mod.update` while pending messages exist, or opportunistically when a packet arrives.

## Chat Hooks

The integration registers one DMF command and uses three hooks.

### DMF command registration

`mod:command("skc", ...)` registers `/skc` with DMF's command system. This is required because DMF processes slash commands before Darktide's vanilla `_parse_slash_commands` and `_handle_slash_command` methods.

The callback encodes the message and sends each packet to the selected chat channel.

### `ConstantElementChat._handle_active_chat_input`

Captures the selected channel and exact `/skc` message substring before DMF tokenizes and queues the registered command. This preserves repeated, leading, and trailing spaces after the first command separator.

Every input still delegates to the original hook chain.

### `ChatManager.send_channel_message`

Applies the selected outgoing mode at the final chat-send boundary:

- The shared safe word bypasses encoding and disables outgoing encoding for the current gameplay instance.
- `off` passes normal outgoing text through unchanged.
- `command` encodes raw strings beginning with `/skc` as a fallback for callers that bypass the standard chat UI parser.
- `always` encodes normal outgoing text while leaving slash-command strings untouched.

Before applying `always`, the hook validates glyph-prefixed text with `Protocol.decode_visible`. A valid SKC1 packet is passed directly to the original send function. This prevents packets generated by the mod from recursively entering the encoder.

### `ConstantElementChat._add_message`

Checks displayed messages for the Mechanicus glyph and validates them with the protocol decoder.

- The shared safe word is detected before packet decoding and passed through unchanged.
- When incoming decoding is disabled, every message is passed through unchanged.
- Invalid packets are passed through unchanged.
- Valid incomplete chunks are withheld from local history.
- A completed set is reassembled and added once as readable text.
- The optional Mechanicus marker is applied after reassembly.
- The reconstructed text is passed through Darktide's `_scrub` function before display.

This path also processes the local user's echoed chat packets, so the sender sees one decoded message instead of their raw packet sequence.

## Settings Lifecycle

Settings are cached in locals rather than queried for every packet:

```lua
encode_mode
decode_incoming_messages
show_decoded_marker
max_chunks
debug_logging
```

`mod.on_setting_changed` refreshes the cache. Selecting outgoing mode `off` clears any queued command text. Disabling incoming decoding clears partially collected messages so they cannot be completed unexpectedly after decoding is re-enabled.

The safe-word state is separate from user settings. It blocks only outgoing encoding and is reset whenever DMF enters a new `StateGameplay` instance.

The toggle keybind uses DMF's native `mod_toggle` keybind type. DMF disables hooks automatically, while Skitarii Chat explicitly disables and re-enables its registered `/skc` command in the lifecycle callbacks. `mod.on_disabled` clears pending command and chunk state; `mod.on_enabled` reloads the configured mode. Both callbacks echo the new state for non-initial toggles.

`send_encoded_message` also rejects a missing channel handle with a user-facing message. This protects against a chat command that was queued immediately before the mod was disabled.

The chat-input hook also guards against a DMF command-autocomplete GUI becoming stale while Darktide replaces the mission world with the end-of-round world. It catches only the specific `slug_text_extents` GUI-handle error, destroys DMF's cached command GUI, and allows chat processing to recover on the following frame. Unrelated downstream errors are rethrown.

The configured chunk limit is clamped to the protocol range of 1 through 10 before use.

## Performance Notes

The feature avoids work in normal chat paths:

- Messages without the three-byte Mechanicus prefix immediately delegate to Darktide.
- Normal messages receive one short safe-word comparison before packet handling.
- Encoding occurs only at the outgoing send boundary selected by the current mode.
- Decoding occurs only for glyph-prefixed messages.
- Packet sizes and chunk counts are bounded.
- Frequently used Lua functions are cached as locals.
- No UTF-8 traversal is needed; Lua strings are handled as byte sequences.
- Timeout cleanup is inactive when there are no pending messages.
- Reassembly allocates the final message only after every chunk is present.

The Base64url implementation is local to the protocol module so behavior does not depend on permissive game-side Base64 decoding.

## Tests

The tests are plain Lua scripts and do not require Darktide.

From the repository root, using a compatible Lua runtime:

```text
lua tests/SkitariiChat_protocol_spec.lua
lua tests/SkitariiChat_integration_spec.lua
```

The protocol test covers:

- Deterministic packet construction.
- Message ID, part, total, and payload decoding.
- Base64url alphabet and visible length.
- Three-part UTF-8 and emoji reassembly.
- Out-of-order chunks.
- Checksum or packet mutation rejection.
- Invalid glyph-prefixed input.
- Outgoing chunk-limit rejection.

The integration test supplies small DMF and `Managers` stubs and covers:

- DMF command registration.
- Exact `/skc` payload spacing.
- Normal outgoing encoding.
- Command-mode normal-message passthrough.
- Off-mode outgoing passthrough and incoming decoding.
- Incoming decoding passthrough when disabled.
- Always-mode automatic encoding.
- Slash-command preservation in Always mode.
- Prevention of recursive packet encoding.
- Safe-word passthrough, instance encoding disable, continued decoding, and next-instance reset.
- Keybind lifecycle command disabling, re-enabling, and state echoes.
- Missing-channel protection for a command queued during disabling.
- Recovery from DMF's stale slash-command autocomplete GUI during end-of-round transitions.
- Sender-side decoded display.
- Invalid packet passthrough.
- Out-of-order multi-chunk display.
- Direct-send fallback behavior.
- Too-long warnings without sending.
- Partial-message expiration.

## Compatibility and Extension Notes

SKC1 reserves the flags byte and includes an explicit version byte for future protocol changes. A future incompatible format should use a new version and keep V1 decoding available when practical.

When extending the protocol:

- Keep invalid-packet passthrough behavior.
- Keep visible packet length within the verified chat-safe bound.
- Do not repurpose V1 fields without changing the version.
- Preserve byte-oriented handling until all chunks are assembled.
- Add deterministic protocol tests for every new packet variant.
- Avoid placing readable headers or separators in the visible chat string.

Compression, shared keys, and secure encryption are intentionally outside the current protocol.

## License

See [LICENSE](LICENSE).
