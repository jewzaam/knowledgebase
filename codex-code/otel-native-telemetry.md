# Codex OTEL Telemetry

These observations are attributed to a local Codex CLI with an OpenTelemetry
deployment.

## Configuration locations

Codex hook and configuration files can exist at these locations:

- `~/.codex/hooks.json`
- `~/.codex/config.toml`
- `<repo>/.codex/hooks.json`
- `<repo>/.codex/config.toml`

Project trust gates project hooks and project configuration. User-level hooks
remain independent of those project trust decisions.

## Hook observations

Observed hook payloads contain `hook_event_name`, session or conversation
identity, `cwd`, and `model` fields. The conversation identity remains stable
when `/cd` changes the working directory; `/cd` changes `cwd` without creating
a new conversation.

The durable join key for native Codex records is `conversation_id`. The hook
observer reports the same value as its `session_id` field, but native
Prometheus metrics do not carry that identity. A dashboard that needs a
conversation selector therefore needs a bounded recording-rule index (for
example, a count grouped by `conversation_id`) while token and accounting
panels should filter the original Loki event records by `conversation_id`.

This also means that the recording rule is not a historical backfill: the
selector series become available as the rule evaluates. Historical event data
can still be queried directly from Loki over its retention window.

Native response-completion records are emitted as
`service_name="codex_cli_rs"`, `event_name="codex.sse_event"`, and
`event_kind="response.completed"`. The useful structured numeric fields are
`input_token_count`, `cached_token_count`, `cache_write_token_count`,
`output_token_count`, and `tool_token_count`; `model`, `project`,
`conversation_id`, and sandbox metadata are available for filtering and
grouping. Exact cost panels should sum these Loki fields and apply explicit
model pricing rather than relying on reset-prone Prometheus counter
increases.

For environment attribution, derive the display label from sandbox metadata:
`sb-<sandbox_profile>` when `sandbox_profile` exists, otherwise `local`.
Group cost by this derived `env` label, not by model. An unlabeled
`vector(0)` fallback can erase the grouping label during LogQL arithmetic;
use a zero-valued fallback that carries the same grouping label instead.

Grafana panels using these Loki metric queries must use the Loki datasource at
both panel and target level. Loki table targets need `format: "table"`,
`instant: true`, and `range: false`; leaving them as range targets can make a
valid query render as no data when Grafana transformations expect table rows.
Long multi-model LogQL expressions may also exceed the local Loki gateway's
GET header limit; split the query into smaller targets or use an allowed POST
path before adding a Grafana join/aggregation transformation.

## Native OTEL metrics

Native Codex OTEL metrics normalize token usage to the
`codex_turn_token_usage_sum` histogram. Its observed `token_type` values are:

- `total`
- `input`
- `cached_input`
- `output`
- `reasoning_output`

Native telemetry also includes `hooks.run`, `thread`, and `conversation`
metrics.

When resource attributes are propagated, native metrics can include `project`,
`host_name`, `sandbox_source`, `sandbox_openshell_name`, and `sandbox_profile`.
The Codex session-state metrics may also include `session_id` and `location`.

## Export behavior

Logs and metrics are configured separately. Native exporters support HTTP and
gRPC transports. A small hook observer can send OTLP HTTP JSON directly to an
OTEL endpoint.

For OTLP/HTTP, use signal-specific collector paths in the Codex config:

```toml
[otel.exporter.otlp-http]
endpoint = "http://collector:4318/v1/logs"
protocol = "binary"

[otel.metrics_exporter.otlp-http]
endpoint = "http://collector:4318/v1/metrics"
protocol = "binary"
```

Using only `http://collector:4318` did not produce native token metrics in a
sandbox; adding `/v1/metrics` produced the expected
`codex_turn_token_usage_{bucket,sum,count}` series. The resulting series had
the sandbox project and resource labels. OTLP/HTTP binary is protobuf and is
compatible with an HTTP/1.1-only proxy; OTLP/gRPC requires HTTP/2 and does not
traverse the OpenShell HTTP/1.1 CONNECT proxy.

Native Codex exporters batch asynchronously and flush on shutdown. Hook
observer logs and Loki-derived session-state metrics therefore prove only the
hook path, not that native token metrics have been exported.

References: [Codex observability configuration](https://learn.chatgpt.com/docs/config-file/config-advanced#observability-and-telemetry),
[OTLP exporter specification](https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/protocol/exporter.md).
