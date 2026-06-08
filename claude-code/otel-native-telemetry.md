# Claude Code Native OTEL Telemetry

Claude Code emits native OpenTelemetry telemetry without requiring custom hooks or relay scripts. This document describes the events it emits, their labels, and how to use them for session state detection.

## Configuration

- **Service name**: `claude-code`
- **Scope**: `com.anthropic.claude_code.events`
- **Minimum version**: 2.1.143+
- **Transport**: OTLP/gRPC to configured OTEL collector

## Event Types

All event types below validated from live Loki data (~50k events across multiple sessions).

### Activity Events

**`api_request`** — LLM API call completed

Labels:

- `model` — model name (e.g., `claude-sonnet-4-5@20250929`)
- `cost_usd` — request cost in USD
- `duration_ms` — request duration
- `input_tokens`, `output_tokens`, `cache_creation_tokens`, `cache_read_tokens` — token counts
- `query_source` — activity source (see taxonomy below)
- `effort` — effort level
- `speed` — speed setting

**`tool_decision`** — model decided to use a tool

Labels:

- `tool_name` — tool being invoked
- `decision` — decision outcome
- `source` — decision source

**`tool_result`** — tool execution completed

Labels:

- `tool_name` — tool executed
- `duration_ms` — execution duration
- `success` — boolean success flag
- `decision_type` — type of decision that led to execution
- `decision_source` — source of decision
- `tool_input_size_bytes`, `tool_result_size_bytes` — payload sizes

**`user_prompt`** — user submitted a prompt

Labels:

- `prompt_length` — length of submitted prompt

### Hook Events

**`hook_execution_start`** / **`hook_execution_complete`** — command hook fired

Labels:

- `hook_event` — event type (Stop, PreToolUse, PostToolUse, UserPromptSubmit, PermissionRequest, SessionStart, SubagentStart, SubagentStop, etc.)
- `hook_name` — name of hook
- `num_hooks` — number of hooks executed
- `total_duration_ms` — total execution time

**`hook_registered`** — hook registered at session start

NOT a hook firing event — emitted during session initialization.

Labels:

- `hook_event` — event type hook is registered for
- `hook_source` — source of hook
- `hook_type` — type of hook

### Agent Events

**`skill_activated`** — skill invoked

**`subagent_completed`** — subagent finished execution

### Infrastructure Events

**`plugin_loaded`** — plugin loaded at startup

Labels:

- `plugin_name` — name of plugin
- `plugin_version` — plugin version
- `has_hooks` — boolean flag for hook presence
- `has_mcp` — boolean flag for MCP presence

**`mcp_server_connection`** — MCP server connected

Labels:

- `server_name` — MCP server name
- `transport_type` — transport protocol
- `status` — connection status

**`away_summary`** — session going idle

Reliable idle signal. Also appears as `query_source` value on `api_request` events.

## Common Labels

Present on every event:

- `session_id` — unique session identifier
- `host_name` — hostname (sandboxes: `sandbox-{sandbox-name}`)
- `project` — project directory name
- `event_name` — event type
- `event_sequence` — monotonic sequence number
- `event_timestamp` — event creation time
- `observed_timestamp` — observation time
- `service_name` — always `claude-code`
- `service_version` — Claude Code version
- `scope_name` — always `com.anthropic.claude_code.events`
- `scope_version` — scope version
- `environment` — environment name
- `os_type` — operating system type
- `os_version` — OS version string
- `host_arch` — CPU architecture
- `terminal_type` — terminal emulator type
- `user_id` — user identifier
- `user_name` — username

## query_source Taxonomy

The `query_source` label appears on activity events (api_request, tool_decision, tool_result) and distinguishes main thread from agents:

- `repl_main_thread` — main session thread
- `agent:builtin:general-purpose` — built-in general-purpose subagent
- `agent:builtin:Explore` — Explore agent
- `agent:builtin:Plan` — Plan agent
- `agent:custom` — custom/plugin agent
- `sdk` — MCP/plugin SDK calls
- `away_summary` — session idle detection summary
- `compact` — context compaction
- `generate_session_title` — title generation
- `web_search_tool`, `web_fetch_apply` — web tools
- `rename_generate_name` — rename operation

Note: `query_source` is NOT present on all events — only on activity events.

## Sandbox Hostname Pattern

Sandboxes report `host_name` as `sandbox-{sandbox-name}` (e.g., `sandbox-claude-dashboard-main`). This pattern is deterministic and derivable from sandbox name. No `SANDBOX_NAME` environment variable exists, but hostname encodes the sandbox identifier.

## Loki Storage

OTEL events land in Loki as **structured metadata**, NOT stream labels. Only `service_name` is a stream label.

Query patterns:

- Filter: `{service_name="claude-code"} | field="value"`
- Unwrap: works on numeric structured metadata fields

## Session State Detection

Native events enable session state derivation:

| State | Signals |
|-------|---------|
| WORKING | api_request, tool_decision, tool_result events present |
| READY | hook_event=Stop is most recent significant event |
| PERMISSION_REQUIRED | hook_event=PermissionRequest fired |
| AWAITING_INPUT | inferred from READY + prolonged absence |

Agent activity detectable via `query_source` values starting with `agent:`.

## Long-Running Operations

Sessions running long agent calls (up to 98 minutes observed) emit no main-thread events, but subagent events (query_source=agent:*) continue flowing at ~77 events/min. Treat any event (main or subagent) as proof of session activity.

## Related Documentation

- [hook-state-transitions.md](hook-state-transitions.md) — hook event types and state machines from the hook perspective

## Provenance

- Local repo: <https://github.com/jewzaam/claude-otel-stack>
- Knowledgebase repo: <https://github.com/jewzaam/knowledgebase>
- Standards repo: <https://github.com/jewzaam/standards>

Generated By: Claude Code (Claude Sonnet 4.5)
