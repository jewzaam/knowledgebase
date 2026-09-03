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
