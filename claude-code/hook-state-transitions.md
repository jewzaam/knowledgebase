# Hook Event Types and State Transitions

> Source: `~/source/claude-dashboard/docs/state-transitions.md` (authoritative).
> This is a reference copy for discoverability. If details conflict, trust the
> source.

## Available Hook Event Types

Claude Code accepts 33 hook event types. Hooks are configured in
`~/.claude/settings.json` (or project-level `.claude/settings.json`). Anything outside this list is
rejected with `Unknown hook type "<name>"`.

> Source: the `Im` array in the Claude Code bundle (`bin/claude.exe` is a Bun single-file
> executable; the JS is embedded as plain text and greppable). Verified against 2.1.269. The
> published docs at <https://code.claude.com/docs/en/hooks> lag this list — re-derive from the
> binary on upgrade rather than trusting the count here.

**OTEL gate:** Claude Code only emits an OTEL event for a hook type if at least one hook of that
type is configured. No hook = no telemetry for that event type. To observe all events, register a
no-op hook for every type. See `~/source/my-claude-stuff/claude/settings.json.d/hooks-noop.json`
and `~/source/my-claude-stuff/docs/noop-hooks.md`.

| Event | Description |
|-------|-------------|
| `PreToolUse` | Before tool execution. Exit 2 to block |
| `PostToolUse` | After a successful tool execution. Fires per tool, may run concurrently for parallel calls |
| `PostToolUseFailure` | Tool failure |
| `PostToolBatch` | Once after every tool call in a batch resolves, before the next model request. Carries `tool_calls[]` |
| `Notification` | System notification (`message`, `notification_type`) |
| `UserPromptSubmit` | User submits a prompt. `source`: user, sdk, system, loop_wakeup, schedule_wakeup, poll_event |
| `UserPromptExpansion` | Slash command or MCP prompt expanded (`expansion_type`, `command_name`, `command_args`) |
| `SessionStart` | Session begins. `source`: startup, resume, clear, compact, fork |
| `SessionEnd` | Session ends. `reason`: clear, resume, logout, prompt_input_exit, other |
| `Stop` | Response complete |
| `StopFailure` | Turn ended in error (`error`, `error_details`) |
| `SubagentStart` | Subagent launched (`agent_id`, `agent_type`) |
| `SubagentStop` | Subagent finished. Carries `background_tasks[]` and `session_crons[]` |
| `PreCompact` | Before context compaction (`trigger`: manual/auto) |
| `PostCompact` | After compaction (`compact_summary`) |
| `PreModelSwitch` | Before a model switch. `source`: command, picker, sdk |
| `PostModelSwitch` | After a model switch. Adds `source` values auto, resume |
| `PermissionRequest` | Permission prompt |
| `PermissionDenied` | Permission denied (`tool_name`, `tool_use_id`, `reason`) |
| `Setup` | Setup/initialization (`trigger`: init/maintenance) |
| `TeammateIdle` | Teammate is idle |
| `TaskCreated` | Task created (`task_id`, `task_subject`) |
| `TaskCompleted` | Task finishes |
| `Elicitation` | MCP server requests user input. Hook can auto-respond instead of showing the dialog |
| `ElicitationResult` | User responded to an MCP elicitation. Hook can observe or override before it reaches the server |
| `ConfigChange` | Config modified. `source`: user/project/local/policy settings, skills |
| `WorktreeCreate` | Worktree created |
| `WorktreeRemove` | Worktree removed |
| `InstructionsLoaded` | A memory/instructions file loaded (`memory_type`, `load_reason`, `file_path`) |
| `CwdChanged` | Working directory changed (`old_cwd`, `new_cwd`) |
| `FileChanged` | A watched file changed. Only fires for paths a hook registered via `watchPaths` in its own output |
| `DirectoryAdded` | Directory added. `source`: slash_command (/add-dir) or register_repo_root (SDK) |
| `MessageDisplay` | Each batch of newly completed lines while an assistant message streams. Display-only |

## Server-Side Tools Fire No Hooks

The advisor (`/advisor`, "consult a stronger model at key moments") runs **server-side**. In the
response stream it arrives as a `server_tool_use` block named `advisor` and returns an
`advisor_tool_result` block; no local tool executes. Consequences:

- No `PreToolUse` / `PostToolUse` / `PostToolUseFailure` hook fires for it.
- No `tool_decision` / `tool_result` OTEL event. The whole consultation sits inside one in-flight
  `api_request`, which emits only on completion.
- The only client-side telemetry is Statsig (`tengu_advisor_tool_call`, `tengu_advisor_tool_result`,
  `tengu_advisor_tool_error`) — not the `com.anthropic.claude_code.events` OTEL pipeline.

So an advisor turn is a hook-silent, OTEL-silent gap of arbitrary length in the middle of a turn.
Any session-state rule that infers WORKING from recent activity events (e.g. a
`count_over_time(... [60s])` recording rule) reports the session as not working for the duration.
Edge-based state — WORKING from `UserPromptSubmit` until `Stop`/`StopFailure`, as the state machine
below describes — does not have this failure mode. No hook registration fixes it; there is no
client-side event to register for.

## Hook Input Contract

Hooks receive JSON on stdin with fields including:

| Field | Description |
|-------|-------------|
| `session_id` | Unique session identifier |
| `tool_name` | Name of the tool (Bash, Read, Edit, etc.) |
| `tool_input` | Structured input to the tool |
| `cwd` | Current working directory |
| `transcript_path` | Path to session transcript |
| `agent_id` | Present on subagent events, absent on main process events |
| `agent_type` | Present on agent events. Observed: `"general-purpose"` |

## Hook Output

Exit codes:

- `0` — proceed (allow)
- `2` — block (PreToolUse only)
- Other — allow, but stderr is logged

Optional structured JSON output:
```json
{
  "permissionDecision": "allow|deny|ask",
  "updatedInput": {},
  "additionalContext": "string"
}
```

## Hook Configuration Structure

```json
{
  "hooks": {
    "EventType": [
      {
        "matcher": "ToolName or empty string for wildcard",
        "hooks": [
          {
            "type": "command",
            "command": "path/to/script.py"
          }
        ]
      }
    ]
  }
}
```

- Empty `matcher` (`""`) = wildcard/catch-all for that event type
- Multiple hook entries under one event execute in sequence
- All matching hooks within one entry run in parallel
- Default timeout: 10 minutes per hook

## Main Process State Machine

```text
Unknown → Working (user sends prompt)
Working → Ready (Stop event, no agent_id)
Working → Permission Required (needs approval)
Working → Awaiting Input (asks a question)
Ready → Idle (user clicks row)
Ready → Working (user sends prompt)
Idle → Working (user sends prompt or agent auto-wake)
Permission → Working (approved or denied with feedback)
```

## Agent (Subagent) State Machine

Agents have a simpler lifecycle — they never receive `Stop`, never enter
Ready/Idle.

```text
[First event with agent_id] → Working
Working → Permission Required (needs approval)
Working → Awaiting Input (asks a question)
Permission Required → Working (approved)
Permission Required → Removed (denied)
Awaiting Input → Working (answered)
[SubagentStop] → Removed
```

## Critical Caveats

### SubagentStart is unreliable

Sometimes does not fire for background agents. Register agents on the first
hook event carrying an `agent_id` that is NOT `SubagentStop`.

### Deny without feedback (main process)

Denying a tool on the main process without feedback text fires NO follow-up
hook. No `PostToolUse`, no `Stop`. State remains at Permission Required until
the user sends a new prompt. Known gap, no workaround.

### Deny without feedback (agent)

Agent permission denial fires `SubagentStop` — the agent gives up cleanly. No
stuck state.

### Auto-wake after agent completion

Each `SubagentStop` triggers an automatic `UserPromptSubmit` → `Stop` on the
main session. With N background agents, expect up to N such cycles.

### Agent clearing

All tracked agents for a session are cleared when:

1. `UserPromptSubmit` arrives (no `agent_id`) — new user turn
2. Parent session PID dies

### Session crash

No `SessionEnd` hook fires on crash. Detect via PID polling.

### Resumed sessions

Hooks may fire with the original session ID rather than the new one. Match by
CWD as a fallback.

### Out-of-order completion

Agents can complete in any order regardless of start order. Handle interleaved
`SubagentStop` → auto-wake cycles.

## Effective (Displayed) State

When tracking multiple agents, the displayed state is the highest priority
across the main process and all active agents:

| Priority | State |
|----------|-------|
| 1 (highest) | Permission Required |
| 2 | Awaiting Input |
| 3 | Ready |
| 4 | Working |
| 5 | Idle |
| 6 (lowest) | Unknown |
