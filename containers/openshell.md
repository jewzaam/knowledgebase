# OpenShell Sandbox Internals

Verified: 2026-06-12  
Provenance: <https://github.com/jewzaam/openshell-sandbox>

OpenShell is a sandboxing tool that wraps container runtimes (podman, docker) with network and filesystem policies. Used for running untrusted code (e.g., Claude Code auto mode) with L4/L7 network filtering and Landlock filesystem restrictions.

## Proxy Architecture

All sandbox traffic routes through an HTTP/1.1 CONNECT proxy at a host-side veth IP (e.g., `10.200.0.1:3128`). The network namespace forces all traffic through the proxy regardless of environment variables. Setting `no_proxy` has no effect — the namespace-level routing supersedes it.

OpenShell injects `ALL_PROXY=http://10.200.0.1:3128` plus lowercase `http_proxy`, `https_proxy`, `no_proxy` into sandbox processes. `ALL_PROXY` takes precedence over user-set `HTTP_PROXY`/`HTTPS_PROXY` in curl and many HTTP clients. To use a custom proxy, must unset `ALL_PROXY`/`all_proxy` and override the lowercase variants.

The proxy is HTTP/1.1 only. gRPC (HTTP/2) cannot traverse it. Attempting to use gRPC endpoints (e.g., OTLP on port 4317) will fail silently or with protocol errors.

### Policy Protocol Field

Omitting the `protocol` field in policy endpoints gives L4-only mode (no HTTP inspection), but traffic still routes through the proxy. This is not a bypass — it only disables application-layer filtering. gRPC still fails because the proxy itself is HTTP/1.1.

**Workaround**: Use HTTP equivalents for gRPC services when possible. Example: OpenTelemetry OTLP supports both gRPC (port 4317) and HTTP (port 4318). Use the HTTP endpoint inside OpenShell sandboxes.

## Network Policy Validation

The `host` field in network policy rejects:

- `"**"` — "host wildcard matches all hosts"
- TLD wildcards like `"*.com"` — "TLD wildcard not allowed; use subdomain wildcards like `*.example.com`"

Only subdomain-scoped wildcards (`*.example.com`) are accepted. No mechanism for open web egress exists in current OpenShell.

`openshell policy set` returns exit 0 immediately. Validation happens asynchronously. A policy can fail L7 validation after the command returns successfully. Check status via `openshell policy list <name>` — look for `Failed`/`Loaded`/`Effective` in the status column. Failed policies do not replace the previous effective policy.

## Exec Session Stability

`sandbox exec` TTY sessions drop during idle periods. `--timeout 0` is the default (no timeout), so it is not an exec-level timeout. The gRPC stream between CLI and gateway/supervisor is suspected of being reaped. No keepalive configuration is exposed. Workaround: background process writing ENQ byte to stdout every 30s.

## Network Policy Discovery

The container-side policy file is at `/etc/openshell/policy.yaml`. The host can inject **additional** policy entries that do not appear in the container's copy — the proxy enforces the union of both. Services may be reachable that are not listed in the container-side file. Verify access empirically rather than trusting the container copy as exhaustive.

Structure: YAML with `network_policies:` mapping named policies to `{endpoints, binaries}` pairs. Each endpoint has `host`, `port`, and optional L7 fields (`protocol`, `enforcement`, `access`, `rules`).

## Host Access from Containers

`host.containers.internal` resolves to `169.254.1.2` inside podman containers. This is the standard hostname for reaching the host machine from a container. However, it is NOT directly reachable from inside the sandbox — all traffic is forced through the L7 proxy at `10.200.0.1:3128`. Connections to `host.containers.internal:<port>` only succeed if the proxy allows them per policy.

Example:

```bash
# Inside sandbox, send OTLP to host collector
# Requires network policy with { host: "host.containers.internal", ports: [4318] }
export OTEL_EXPORTER_OTLP_ENDPOINT=http://host.containers.internal:4318
```

### Accessing the OTEL Stack

When the host runs an OTEL collector + Loki stack (e.g., [claude-otel-stack](https://github.com/jewzaam/claude-otel-stack)):

| Service | Endpoint | Access |
|---------|----------|--------|
| OTEL collector | `host.containers.internal:4318` | HTTP OTLP ingest |
| Loki | `host.containers.internal:3100` | Query API (GET only) |
| Grafana | `host.containers.internal:3000` | Blocked by policy |

**L7 enforcement quirk**: POST to Loki's `/loki/api/v1/query_range` is denied with `"POST /loki/api/v1/query_range not permitted by policy"`. Use GET with `--data-urlencode` parameters instead:

```bash
curl -s -G 'http://host.containers.internal:3100/loki/api/v1/query_range' \
  --data-urlencode 'query={service_name="claude-code"} | event_name="api_request"' \
  --data-urlencode "start=$START_NS" \
  --data-urlencode "end=$NOW_NS" \
  --data-urlencode 'limit=5000'
```

**Query range limit**: Loki enforces a 30-day max range (`query length: ... limit: 30d1h`). Compute start/end as nanosecond-epoch timestamps within that window:

```bash
NOW_NS=$(python3 -c "import time; print(int(time.time() * 1e9))")
START_NS=$(python3 -c "import time; print(int((time.time() - 30*24*3600) * 1e9))")
```

Structured metadata fields (e.g., `event_name`, `session_id`, `cost_usd`, `model`, `query_source`) work as filter targets in LogQL from inside the sandbox, consistent with the [otel-native-telemetry](https://github.com/jewzaam/knowledgebase/blob/main/claude-code/otel-native-telemetry.md) documentation.
