# Hook Event Types and State Transitions

> Source: `~/source/claude-dashboard/docs/state-transitions.md` (authoritative).
> This is a reference copy for discoverability. If details conflict, trust the
> source.

## Available Hook Event Types

Claude Code supports 17+ hook event types. Hooks are configured in
`~/.claude/settings.json` (or project-level `.claude/settings.json`).

| Event | Description |
|-------|-------------|
| `PreToolUse` | Before tool execution. Exit 2 to block |
| `PostToolUse` | After successful tool execution |
| `PostToolUseFailure` | Tool failure |
| `UserPromptSubmit` | User submits a prompt |
| `Stop` | Response complete |
| `Notification` | System notification |
| `PermissionRequest` | Permission prompt |
| `SessionStart` | Session begins |
| `SessionEnd` | Session ends |
| `SubagentStart` | Subagent launched |
| `SubagentStop` | Subagent finished |
| `PreCompact` | Before context compaction |
| `Setup` | During setup/initialization |
| `TeammateIdle` | Teammate is idle |
| `TaskCompleted` | Task finishes |
| `ConfigChange` | Config modified |
| `WorktreeCreate` | Worktree created |
| `WorktreeRemove` | Worktree removed |

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
