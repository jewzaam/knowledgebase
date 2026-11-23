# Discord Bot REST API Facts

Taken from Discord's official developer documentation and direct tests.

## Sending messages

- `POST /channels/{id}/messages`
- Header `Authorization: Bot <token>`.
- A `User-Agent` of the form `DiscordBot (<url>, <version>)` is required.
- `content` is at most 2000 characters.
- `allowed_mentions` controls which mentions ping.
- 429 responses carry `retry_after`.

## Reactions

`PUT` / `DELETE /channels/{id}/messages/{id}/reactions/{emoji}/@me`, with the
emoji URL-encoded.

## Permission bits

| Permission | Bit |
|---|---|
| ADD_REACTIONS | `1<<6` |
| VIEW_CHANNEL | `1<<10` |
| SEND_MESSAGES | `1<<11` |
| ATTACH_FILES | `1<<15` |
| READ_MESSAGE_HISTORY | `1<<16` |
| CREATE_PUBLIC_THREADS | `1<<35` |
| SEND_MESSAGES_IN_THREADS | `1<<38` |

## Bot invite URL

```text
https://discord.com/oauth2/authorize?client_id=<id>&scope=bot&permissions=<int>
```

## Intents

Reading message text needs the Message Content privileged intent.

## Polls

Up to 10 answers; question up to 300 characters; answer text up to 55
characters; multi-select supported.

## Voice messages

Voice messages arrive as ogg/opus attachments. Converting to 16 kHz mono WAV
with ffmpeg prepares them for whisper.cpp:

```bash
ffmpeg -i voice.ogg -ar 16000 -ac 1 voice.wav
```
