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

## Export behavior

Logs and metrics are configured separately. Native exporters support HTTP and
gRPC transports. A small hook observer can send OTLP HTTP JSON directly to an
OTEL endpoint.
