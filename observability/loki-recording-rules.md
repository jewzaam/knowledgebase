# Loki Recording Rules

Behavioral facts and constraints discovered when implementing LogQL recording rules in Loki for OTEL-based observability stacks. Sourced from implementation work in [claude-otel-stack](https://github.com/jewzaam/claude-otel-stack).

## Timestamp Fields

### `observed_timestamp` vs `event_sequence`

`event_sequence` resets across session resumes (e.g., sandbox disconnects, `/resume` in Claude Code). It is only reliable within a single uninterrupted session run.

Use `observed_timestamp` for time comparisons in LogQL recording rules. `observed_timestamp` contains nanosecond-epoch timestamps assigned by the OTEL collector at ingestion time and persists reliably across session interruptions.

## Event Filtering

### `hook_registered` vs `hook_execution_complete`

Both event types carry `hook_event` labels (e.g., `hook_event="Stop"`). However:

- `hook_registered` events fire at session startup when hooks are registered. These are metadata declarations, NOT actual hook executions.
- `hook_execution_complete` (and `hook_execution_start`) represent real hook firing events.

Filter to `event_name = "hook_execution_complete"` or `event_name = "hook_execution_start"` for actual hook execution signals.

## LogQL Aggregation Constraints

### `count_over_time` Grouping Limitation

`count_over_time({...} [range])` does NOT support `by()` grouping directly. The expression:

```logql
count_over_time({label="value"} [1h]) by (label1, label2)
```

returns a parse error:

```text
grouping not allowed for count_over_time aggregation
```

Wrap `count_over_time` with an outer aggregation that supports `by()`:

```logql
sum by (label1, label2) (count_over_time({label="value"} [1h]))
```

## Recording Rule Comparison Pattern

To determine whether "event A happened more recently than event B", compare timestamp values extracted via:

```logql
max_over_time({...} | unwrap observed_timestamp [range])
```

This yields nanosecond timestamps that can be compared with `>` or `<`.

Use `or vector(0)` as a fallback for sessions missing one side of the comparison. Example:

```logql
(max_over_time({event_name="hook_execution_complete", hook_event="Start"} | unwrap observed_timestamp [7d]) or vector(0))
>
(max_over_time({event_name="hook_execution_complete", hook_event="Stop"} | unwrap observed_timestamp [7d]) or vector(0))
```

This expression evaluates to `1` if the most recent `Start` hook fired more recently than the most recent `Stop` hook within the 7-day range.

## Loki Ruler Configuration

### `remote_write` Config Format

Loki's ruler `remote_write` configuration uses a **single struct**, NOT a Prometheus-style list of remote write targets. Correct syntax:

```yaml
ruler:
  remote_write:
    enabled: true
    client:
      url: http://prometheus:9090/api/v1/write
```

Using list syntax (`- url: ...`) causes the error:

```text
cannot unmarshal !!seq into ruler.RemoteWriteConfig
```

### Prometheus Remote Write Receiver Requirement

Prometheus must be started with the `--web.enable-remote-write-receiver` flag to accept remote write from Loki ruler. Without this flag, Loki ruler silently fails to write recording rule results to Prometheus.

## Structured Metadata in Recording Rules

Loki structured metadata fields (populated from OTLP attributes) function as first-class filter targets and grouping labels in recording rule expressions.

Fields such as `event_name`, `hook_event`, `session_id`, `host_name`, `project` can be used in:

- Line filter expressions: `{stream_labels} | event_name = "hook_execution_complete"`
- Grouping (`by()`) in outer aggregations wrapping `count_over_time` or other range functions

Example:

```logql
sum by (session_id, hook_event) (count_over_time({job="claude-code-events"} | event_name = "hook_execution_complete" [7d]))
```

This groups hook execution counts by session and hook event type over a 7-day range.

### Cross-Stream Ordering

Loki `direction=backward` orders log entries within each stream but does NOT guarantee ordering across streams.

When structured metadata fields (e.g., `prompt`, `cost_usd`) create unique streams per event (each event has different metadata values, resulting in different stream identity), the result array order is arbitrary across those streams.

Application code must sort by `observed_timestamp` after receiving results that span multiple streams. Example from [claude-dashboard](https://github.com/jewzaam/claude-dashboard) tooltip polling: events with unique `prompt` values form separate streams, requiring client-side timestamp sorting before processing the result array.

## Recording Rule Event Filtering

### Sub-Agent Permission Bleed

Recording rules that track permission state must filter by `query_source` to avoid sub-agent event interference.

The `claude_session_permission` rule (in [claude-otel-stack](https://github.com/jewzaam/claude-otel-stack)) compares `PermissionRequest` timestamp vs latest `tool_result|user_prompt` timestamp. Sub-agent events share the parent session's `session_id`. A background agent's `tool_result` events can have timestamps newer than the main thread's `PermissionRequest`, causing the rule to evaluate FALSE and clear permission state while the main thread is still blocked on a permission prompt.

Fix: filter the clearing side to `query_source = "repl_main_thread"` so only main-thread events can clear permission state.

This issue is specific to permission tracking. The `claude_session_working` and `claude_session_ready` rules do NOT require this filter:

- **`claude_session_working`**: sub-agent events contributing to WORKING state is correct (work is happening in the session)
- **`claude_session_ready`**: correctly blocked by agent activity; auto-wake Stop hook resolves it when agents finish
