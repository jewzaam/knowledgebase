# OpenShell Sandbox Internals

Verified: 2026-06-01  
Provenance: <https://github.com/jewzaam/openshell-sandbox>

OpenShell is a sandboxing tool that wraps container runtimes (podman, docker) with network and filesystem policies. Used for running untrusted code (e.g., Claude Code auto mode) with L4/L7 network filtering and Landlock filesystem restrictions.

## Proxy Architecture

All sandbox traffic routes through an HTTP/1.1 CONNECT proxy at a host-side veth IP (e.g., `10.200.0.1:3128`). The network namespace forces all traffic through the proxy regardless of environment variables. Setting `no_proxy` has no effect — the namespace-level routing supersedes it.

The proxy is HTTP/1.1 only. gRPC (HTTP/2) cannot traverse it. Attempting to use gRPC endpoints (e.g., OTLP on port 4317) will fail silently or with protocol errors.

### Policy Protocol Field

Omitting the `protocol` field in policy endpoints gives L4-only mode (no HTTP inspection), but traffic still routes through the proxy. This is not a bypass — it only disables application-layer filtering. gRPC still fails because the proxy itself is HTTP/1.1.

**Workaround**: Use HTTP equivalents for gRPC services when possible. Example: OpenTelemetry OTLP supports both gRPC (port 4317) and HTTP (port 4318). Use the HTTP endpoint inside OpenShell sandboxes.

## Host Access from Containers

`host.containers.internal` resolves to `169.254.1.2` inside podman containers. This is the standard hostname for reaching the host machine from a container. Works in OpenShell sandboxes for reaching host-side services (e.g., OTLP collector, local dev servers).

Example:

```bash
# Inside sandbox, send OTLP to host collector
export OTEL_EXPORTER_OTLP_ENDPOINT=http://host.containers.internal:4318
```
