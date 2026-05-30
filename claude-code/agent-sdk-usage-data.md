# Extracting Usage/Cost Data from the Claude Agent SDK

> How to recover cost, token, context-window, and rate-limit data from the
> Claude Agent SDK's streaming messages. Written against
> `claude-agent-sdk==0.1.56`; field names come from
> `claude_agent_sdk/types.py`.

## Which messages carry usage data

The SDK streams several message types. Only two carry usage data:

| Message type | Contains |
|---|---|
| `ResultMessage` | cost, tokens, durations, model usage (**emitted once per query/turn**) |
| `RateLimitEvent` | rate-limit bucket, utilization, reset timestamp |

`AssistantMessage`, `UserMessage`, `StreamEvent`, and `SystemMessage` do not
carry cost or token fields.

## `ResultMessage` fields (the primary source)

```python
@dataclass
class ResultMessage:
    subtype: str
    duration_ms: int
    duration_api_ms: int
    is_error: bool
    num_turns: int
    session_id: str
    stop_reason: str | None = None
    total_cost_usd: float | None = None
    usage: dict[str, Any] | None = None
    result: str | None = None
    structured_output: Any = None
    model_usage: dict[str, Any] | None = None
    permission_denials: list[Any] | None = None
    errors: list[str] | None = None
    uuid: str | None = None
```

### `usage` dict shape

Mirrors the Anthropic API response `usage` block:

```python
{
    "input_tokens": int,
    "output_tokens": int,
    "cache_creation_input_tokens": int,
    "cache_read_input_tokens": int,
    # "service_tier", "server_tool_use", ... possible but rare
}
```

### `model_usage` dict shape

Keyed by model id (e.g. `claude-sonnet-4-6-20250929`), values are per-model
usage dicts with `outputTokens`, `inputTokens`, etc. In most runs there is a
single key; with subagents or model switches there can be more. To pick the
"primary" model, choose the key with the highest `outputTokens`.

## Per-query vs. cumulative

**`ResultMessage` fields are per-query, not session-cumulative.** A streaming
session with multiple `query()` calls emits multiple `ResultMessage`s; each
reports the cost and tokens of just that one turn. If you want a session-total
(for a dashboard, a statusline-like view, or billing), accumulate on your side:

```python
class SessionAccumulator:
    total_cost_usd: float = 0.0
    total_input_tokens: int = 0
    total_output_tokens: int = 0
    total_duration_ms: int = 0

    def record_result(
        self,
        *,
        session_id: str,
        total_cost_usd: float | None,
        usage: dict[str, int] | None,
        duration_ms: int,
    ) -> None:
        if total_cost_usd is not None:
            self.total_cost_usd += total_cost_usd
        self.total_duration_ms += duration_ms or 0
        if usage:
            # Lifetime totals mirror the Claude Code CLI's statusline
            # semantics exactly: only `input_tokens` (uncached new input)
            # and `output_tokens` are summed. Cache reads and cache
            # creations are surfaced separately via the per-turn snapshot
            # below — they feed `used_percentage` but never the lifetime
            # totals. This is intentional: the CLI's lifetime field
            # represents new-input pressure, not billable input volume,
            # and downstream aggregators (e.g. AgentPulse) treat the
            # field that way. Summing the cache fields here would
            # desynchronize SDK-sourced data from CLI-sourced data and
            # break cross-source comparisons.
            self.total_input_tokens += usage.get("input_tokens") or 0
            self.total_output_tokens += usage.get("output_tokens") or 0

# Caller extracts fields from ResultMessage and passes them as kwargs:
acc.record_result(
    session_id=msg.session_id,
    total_cost_usd=msg.total_cost_usd,
    usage=msg.usage,
    duration_ms=msg.duration_ms,
)
```

Keyword-only arguments keep the call site self-documenting and allow the
accumulator to evolve (new optional fields) without breaking callers.

For **per-turn context-window snapshots** — what feeds `used_percentage` —
keep the most recent single-call usage separately (`last_input_tokens`,
`last_cache_read_input_tokens`, `last_cache_creation_input_tokens`). These
must *not* be summed across turns: they represent the size of one API call
and cannot exceed the window. `ResultMessage.usage` is aggregated across
every API call in the turn (tool loops produce many) so it's only suitable
for lifetime totals. Capture the snapshot from the last `AssistantMessage.usage`
before the turn ended.

The split is what enables `used_percentage` to reflect "how full is my
context right now" while `total_input_tokens` tracks "how much new input
pressure has this process taken across its lifetime." A common mistake is
to push the snapshot's three-field sum into the lifetime accumulator;
that turns the lifetime field into a roughly-monotonic estimate of
billable input volume, which the CLI does not produce and downstream
consumers do not expect. Verified empirically against the Claude Code CLI:
its `total_input_tokens` ticks by `input_tokens` only — typically a
handful of tokens per turn after the first, even in long sessions where
each request replays hundreds of thousands of tokens via cache_read. Match
that behaviour.

**Do not reset the accumulator on `/clear` or session resume.** The Claude
Code CLI's statusline is process-scoped — `/clear` rotates `session_id` but
cost and token totals keep climbing until the CLI process exits. Mirror
that behaviour: keep one accumulator for the lifetime of your chat
process, let `session_id` update via each new `ResultMessage`, and only
instantiate a fresh accumulator to simulate a full restart. If you reset
on `/clear`, users will see misleading dips in cost every time they clear
a conversation, and downstream aggregators that collapse by process
(e.g. AgentPulse + an InfoTab-style view) will show the "newest session's
cost" as the snapshot — undercounting the real process total.

## Gaps vs. the CLI statusline hook

The Claude Code CLI's statusline hook emits a richer payload than the SDK. In
practice the SDK misses:

| Field | Reason | Workaround |
|---|---|---|
| `cost.total_lines_added` / `total_lines_removed` | Derived by the CLI from Edit/Write tool results | Parse `ToolResultBlock` text from `UserMessage` content, or leave null |
| `context_window.context_window_size` | Not reported anywhere in SDK messages | Maintain a `model_id → size` lookup table (see below) |
| `context_window.used_percentage` | Needs the window size to compute | Compute as `(input + cache_read + cache_creation) / window_size * 100` |

## Model → context window lookup

No SDK field exposes the model's context window. Keep a small, versioned
table in code:

```python
CONTEXT_WINDOW_SIZES = {
    "claude-haiku-4-5": 200_000,
    "claude-sonnet-4-5": 200_000,
    "claude-sonnet-4-6": 200_000,
    "claude-sonnet-4-6[1m]": 1_000_000,
    "claude-opus-4-6": 200_000,
    "claude-opus-4-7": 200_000,
    "claude-opus-4-7[1m]": 1_000_000,
}
DEFAULT_CONTEXT_WINDOW = 200_000
```

Match exact first, then by known-prefix for dated variants
(`claude-opus-4-7-20251231` → `claude-opus-4-7` → 200k). Fall back to 200k
for unknown models and log it so the table can be updated.

## `RateLimitEvent`

```python
@dataclass
class RateLimitInfo:
    status: Literal["allowed", "allowed_warning", "rejected"]
    resets_at: int | None = None               # unix seconds
    rate_limit_type: Literal[
        "five_hour", "seven_day",
        "seven_day_opus", "seven_day_sonnet", "overage",
    ] | None = None
    utilization: float | None = None           # 0.0 – 1.0
    overage_status: RateLimitStatus | None = None
    overage_resets_at: int | None = None
    overage_disabled_reason: str | None = None
    raw: dict[str, Any] | None = None

@dataclass
class RateLimitEvent:
    rate_limit_info: RateLimitInfo
    uuid: str
    session_id: str
```

Rate limit events fire when the limit status changes — not per query. Use
them to surface approaching-limit warnings, not as a frequency sink.

## Writing usage data to an external system

If you're forwarding SDK usage to a service that already ingests the CLI's
statusline hook payload (e.g. AgentPulse's `/statusline/claude`), the
expected JSON shape the CLI emits is:

```json
{
  "session_id": "...",
  "pid": 0,
  "source_system": "hostname",
  "workspace": {"project_dir": "..."},
  "cost": {
    "total_cost_usd": 0.0,
    "total_duration_ms": 0,
    "total_api_duration_ms": 0,
    "total_lines_added": 0,
    "total_lines_removed": 0
  },
  "context_window": {
    "total_input_tokens": 0,
    "total_output_tokens": 0,
    "used_percentage": 0,
    "context_window_size": 200000,
    "current_usage": {
      "cache_read_input_tokens": 0,
      "cache_creation_input_tokens": 0
    }
  },
  "model": {"display_name": "..."}
}
```

Mapping from SDK → this shape:

| Target field | SDK source |
|---|---|
| `session_id` | `ResultMessage.session_id` |
| `pid` | `os.getpid()` (synthesized — the SDK runs in your process) |
| `source_system` | `socket.gethostname()` |
| `workspace.project_dir` | Your configured cwd |
| `cost.total_cost_usd` | Cumulative `ResultMessage.total_cost_usd` |
| `cost.total_duration_ms` | Cumulative `ResultMessage.duration_ms` |
| `cost.total_api_duration_ms` | Cumulative `ResultMessage.duration_api_ms` |
| `cost.total_lines_added` / `_removed` | — (leave null unless parsed from tool results) |
| `context_window.total_input_tokens` | Cumulative `usage["input_tokens"]` only — mirrors CLI semantics; cache reads/creations are *not* added (see accumulator note above) |
| `context_window.total_output_tokens` | Cumulative `usage["output_tokens"]` |
| `context_window.used_percentage` | Computed — see formula above |
| `context_window.context_window_size` | Model lookup table |
| `context_window.current_usage.cache_*_tokens` | Latest `usage["cache_*_input_tokens"]` |
| `model.display_name` | `extract_model_name(ResultMessage.model_usage)` |

## Working reference implementation

`personal-assistant-dashboard/personal_assistant_dashboard/agentpulse_statusline.py`
implements this mapping end-to-end (accumulator, payload builder, HTTP POST,
and model lookup table). Tests are at
`tests/test_agentpulse_statusline.py`.
