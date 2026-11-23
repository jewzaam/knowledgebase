# Headless Sessions with stream-json

Observed with Claude Code 2.1.x on Windows 11 Home, plus official documentation.

## One process, one session, many messages

```bash
claude -p --input-format stream-json --output-format stream-json --verbose
```

keeps ONE process and ONE session across many user messages. Each input line is
one JSON object:

```json
{"type":"user","message":{"role":"user","content":"text"}}
```

- Context survives idle gaps between messages.
- A message sent while a turn is running is folded into that turn: one `result`
  event, not two.
- `system/init` is emitted only after the first user message. It lists
  capabilities (interrupt, ask_user_question, ...).
- Each turn ends with one `result` event carrying `total_cost_usd`, `usage`, and
  `modelUsage.<model>.contextWindow`.

## Context size comes from the last API call

The context occupied in the window is the usage of the LAST top-level API call
(input + cache read + cache creation tokens), not the turn's summed usage. On
one measured turn with 3 tool calls the summed usage was 154,028 tokens (15.4%)
but the last call was 38,705 tokens (3.87%).

## AskUserQuestion needs `--permission-prompt-tool stdio`

In stream-json mode AskUserQuestion appears as a `control_request` only when
launched with `--permission-prompt-tool stdio` (works together with
`--dangerously-skip-permissions`). Answer with a `control_response` carrying
`answers`. In plain `-p` mode terminal-only tools are disabled.

## `--session-id` vs `--resume`

- `--session-id <uuid>` on an already saved session fails with
  `Session ID <uuid> is already in use.`
- `--resume <uuid>` on a session that never ran fails with
  `No conversation found with session ID: <uuid>`.

After a crashed first turn it is unknowable which case applies; retrying once
with the other flag resolves it.

## MCP servers and plugins

A default headless session starts the MCP server of every enabled plugin (a
Discord channel plugin then opens a second gateway connection).
`--strict-mcp-config` prevents that.

## `--channels` is variadic

`claude --channels plugin:x@m plugin list` fails with
`--channels entries must be tagged`, because `plugin` and `list` are consumed as
further entries. The `=` form ends the list:

```bash
claude --channels=plugin:x@m plugin list
```

## Bypass-permissions mode still prompts for some things

- AskUserQuestion.
- Critical-path `rm` / `rmdir` (Bash), unless env
  `CLAUDE_CODE_EVEN_MORE_DANGEROUSLY_SKIP_PERMISSIONS=1`.
- Cross-session messaging safeguards.
- PowerShell commands flagged "could not fully check your permission rules".
  Simple inline PowerShell avoids the flag; complex logic in script files
  avoids it too.

## Usage limits

- Two windows: a 5-hour session window and a weekly window, shared across all
  models.
- Message text: `You've hit your session limit · resets <time>`.
- The status line JSON has `rate_limits.five_hour` and `rate_limits.seven_day`
  with `used_percentage` and `resets_at` (Pro/Max/Ultra only, after the first
  response), plus `context_window.used_percentage` and `context_window_size`.

## Sub-agent model resolution

Order of precedence: per-call `model` parameter, then agent frontmatter, then
`CLAUDE_CODE_SUBAGENT_MODEL`, then the parent's model. A trivial haiku
sub-agent costs about 40K tokens of overhead.
