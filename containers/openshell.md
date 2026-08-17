# OpenShell Sandbox Internals

Verified: 2026-08-17  
Provenance: <https://github.com/jewzaam/openshell-sandbox>, <https://github.com/NVIDIA/OpenShell>

OpenShell is a sandboxing tool that wraps container runtimes (podman, docker) with network and filesystem policies. Used for running untrusted code (e.g., Claude Code auto mode) with L4/L7 network filtering and Landlock filesystem restrictions.

## Network Topology

A sandbox has exactly one network interface — a veth at `10.200.0.2/24` — and exactly one route, `default via 10.200.0.1`. It cannot reach a podman bridge network (e.g. `172.30.0.0/24`) directly; such an attempt is refused by the host, not by whatever is listening on the far end. The only egress path is OpenShell's proxy on the gateway address (`10.200.0.1`, see Proxy Architecture below). Anything else must be named in policy and reached through that proxy.

Rootless podman puts that gateway address further out of reach for a container started with `--network host` — see [podman-rootless-networking.md](podman-rootless-networking.md#--network-host-cannot-reach-the-rootless-netns-gateway).

## Proxy Architecture

All sandbox traffic routes through an HTTP/1.1 CONNECT proxy at a host-side veth IP (e.g., `10.200.0.1:3128`). The network namespace forces all traffic through the proxy regardless of environment variables. Setting `no_proxy` has no effect — the namespace-level routing supersedes it.

OpenShell injects `ALL_PROXY=http://10.200.0.1:3128` plus lowercase `http_proxy`, `https_proxy`, `no_proxy` into sandbox processes. `ALL_PROXY` takes precedence over user-set `HTTP_PROXY`/`HTTPS_PROXY` in curl and many HTTP clients. To use a custom proxy, must unset `ALL_PROXY`/`all_proxy` and override the lowercase variants.

Pointing `https_proxy` at a dead port causes curl to fail against that port, confirming the override is honoured and that the injected `ALL_PROXY` does not win once unset. Unsetting every proxy variable instead produces `Could not resolve host` — the sandbox has no resolver of its own; DNS is performed by the proxy. An attempt to bypass the proxy by unsetting the variables therefore looks like a hard block when it is actually loss of name resolution.

The proxy is HTTP/1.1 only. gRPC (HTTP/2) cannot traverse it. Attempting to use gRPC endpoints (e.g., OTLP on port 4317) will fail silently or with protocol errors.

### Policy Protocol Field

Omitting the `protocol` field in policy endpoints gives L4-only mode (no HTTP inspection), but traffic still routes through the proxy. This is not a bypass — it only disables application-layer filtering. gRPC still fails because the proxy itself is HTTP/1.1.

**Workaround**: Use HTTP equivalents for gRPC services when possible. Example: OpenTelemetry OTLP supports both gRPC (port 4317) and HTTP (port 4318). Use the HTTP endpoint inside OpenShell sandboxes.

An endpoint declared without `protocol:` permits absolute-URI GET but refuses CONNECT: the same host:port returns `400` from the upstream service for a plain proxy-form GET (visible past L4) and `403` from OpenShell for CONNECT. Adding `protocol: rest` and `enforcement: enforce` makes CONNECT succeed.

CONNECT is not restricted to port 443 — CONNECT to a permitted host on port 80 and on port 4318 both succeeded, so a non-443 port is not itself a reason for a CONNECT rejection.

### Proxy Chaining

Tested from an attempt to obtain broader outbound HTTPS by running an HTTP proxy outside the sandbox and chaining OpenShell's proxy to it — the attempt failed, and the failure modes are informative:

- **Nested CONNECT is categorically blocked.** Given a policy that permits host:port of a second HTTP proxy, a client can establish a CONNECT tunnel to that proxy through OpenShell's proxy. Sending a further `CONNECT <target>:443` inside that tunnel gets the tunnel torn down with no response — for an inner target the policy allows (`api.anthropic.com:443`) exactly as for one it does not (`example.com:443`). This is a categorical limit on nested CONNECT, not policy enforcement on the inner request. Consequence: proxy chaining cannot carry HTTPS out of a sandbox, no matter what the policy says.

- **Absolute-URI GET inside that same tunnel is NOT blocked, and reaches unlisted hosts.** Through a tunnel to a permitted proxy, `GET http://example.com/ HTTP/1.1` returned `200` from a sandbox whose policy never named `example.com`. `GET http://deb.debian.org/debian/` (a permitted host) also returned `200`. OpenShell blocks nested CONNECT but forwards nested absolute-URI requests without applying policy to the inner target — permitting a single endpoint that happens to be an HTTP proxy is therefore a much wider grant than it appears, yielding arbitrary cleartext egress. In practice the exposure is limited by how little of the web is cleartext (one measured research corpus: 18 of 5,423 URLs were `http://`), not by the policy.

- **curl `--preproxy` does not chain HTTP to HTTP.** With `--preproxy http://<openshell-proxy> --proxy http://<second-proxy>`, curl sends `CONNECT <final-target>:443` to the preproxy and never contacts the second proxy at all; a request to a policy-permitted final target succeeded, proving the second proxy was bypassed rather than chained. `--preproxy` is a SOCKS-first mechanism. Chaining two HTTP proxies requires an external relay (for example socat's `PROXY:` address type), which does establish the tunnel correctly — the nested-CONNECT limit above is what defeats it afterwards.

### Denied vs Unreachable Host

A policy-denied host and a policy-allowed-but-dead host fail differently, and the difference is diagnostic. The L7 CONNECT proxy returns `403` immediately when a host is not in the policy. When the host IS in the policy but the upstream service is unreachable, the proxy instead returns `502 Bad Gateway` after a delay, or never answers at all. Observed both from the same endpoint at different times: an allowed collector address whose service was down produced `502` on one attempt and a total stall on another. A health check that maps both `403` and "no response" to a single "blocked" state cannot distinguish a policy problem from an outage, and will misreport a dead service on a permitted host as a policy failure.

`curl --connect-timeout` does not bound a request through the proxy — it only bounds the TCP connect to the proxy itself, which always succeeds immediately. If the proxy then stalls on an unreachable upstream, curl waits indefinitely. Measured: a request with `--connect-timeout 3` and no `--max-time` ran past 90 seconds with no response. Always set `--max-time` for reachability probes.

## Network Policy Validation

The `host` field in network policy rejects:

- `"**"` — "host wildcard matches all hosts"
- TLD wildcards like `"*.com"` — "TLD wildcard not allowed; use subdomain wildcards like `*.example.com`"

Only subdomain-scoped wildcards (`*.example.com`) are accepted. No mechanism for open web egress exists in current OpenShell.

`openshell policy set` returns exit 0 immediately. Validation happens asynchronously. A policy can fail L7 validation after the command returns successfully. Check status via `openshell policy list <name>` — look for `Failed`/`Loaded`/`Effective` in the status column. Failed policies do not replace the previous effective policy.

### Policy Granularity

Network policy operates at host+port level only. No URL path filtering, no HTTP verb filtering. The L7 CONNECT proxy establishes a TLS tunnel; once up, it cannot inspect HTTP methods or paths inside the tunnel. The `access` field values (`read-only`, `full`) are OpenShell's own access tier concept, not HTTP GET vs POST filtering.

Because the CONNECT tunnel is opaque at the TLS layer, client-side TLS fingerprint impersonation (e.g. a Chrome-impersonating HTTP client) survives the tunnel intact — the proxy cannot see or alter the client hello. Practical consequence, observed running [claude-skill-cited-research](https://github.com/jewzaam/claude-skill-cited-research) inside an [openshell-sandbox](https://github.com/jewzaam/openshell-sandbox) container: a search library that impersonates a browser's TLS handshake to avoid anti-bot challenges keeps working through an OpenShell CONNECT proxy that allowlists the target hosts. It cannot be routed instead through the sandbox's host-side fetch service, since that issues plain GETs on the caller's behalf and would substitute its own (non-impersonated) TLS fingerprint, reintroducing the anti-bot challenge.

## Control-Plane Ports Are Blocked Unconditionally

Five ports are refused for every sandbox regardless of policy, `allowed_ips`, address range, or hostname:

```rust
// crates/openshell-supervisor-network/src/proxy.rs
const BLOCKED_CONTROL_PLANE_PORTS: &[u16] = &[
    2379,  // etcd client
    2380,  // etcd peer
    6443,  // Kubernetes API server
    10250, // kubelet API
    10255, // kubelet read-only
];
```

The check runs in all three destination-validation paths — `validate_allowed_ips_for_resolved_addrs`, `validate_declared_endpoint_resolved_addrs`, and `resolve_and_check_trusted_gateway` — so none of these reaches a Kubernetes API server:

- an endpoint naming the IP literal, with or without `allowed_ips`
- an endpoint naming a hostname that resolves to it, including a tailnet name
- `host.containers.internal:6443`, despite that alias otherwise bypassing the SSRF tiers

It arrived in `834f8aa1` (2026-03-23, "security hardening batch 1", SEC-005) as *"defense-in-depth for the allowed_ips feature"* — the stated concern being that a broad CIDR such as `10.0.0.0/8` would unintentionally expose control-plane services. A later commit (`f1fc87e1`, #1560) added a trust tier that does relax RFC1918 for operator-declared hostnames, and deliberately preserved the port block.

There is no configuration knob, and adding one is the wrong shape: OpenShell is deployed with the gateway and sandboxes inside a Kubernetes cluster, where the party authoring the sandbox policy is frequently the party the cluster is being protected from. A policy-level opt-in would be written by exactly the wrong actor. Reachability, not authorization, is the grant being withheld — a sandbox that can reach the API server presents whatever credential it can find, including an in-cluster pod's projected ServiceAccount token, so read-only RBAC on an intended identity does not bound the exposure.

### Consequence for cluster access from a sandbox

`kubectl` against a standard cluster cannot work from inside a sandbox. It fails at the proxy before TLS, so the error is a bare `Unable to connect to the server: Forbidden` with no Kubernetes `Status` body.

A host-side TCP forwarder on an unblocked port defeats the block (the port is checked, the destination is not), but only in the podman-on-a-host deployment where such a host exists — and it is a *wider* hole than it appears, because `host.containers.internal` cannot be port-filtered by policy, so the forwarder becomes reachable from every sandbox on that host regardless of each one's policy.

### Denial envelopes distinguish the two rejections

Both return `403`, and the JSON body says which layer refused:

```json
{"error":"policy_denied","detail":"GET 10.0.0.5:9000/health not permitted by policy"}
{"error":"ssrf_denied","detail":"GET 10.0.0.5:6443 blocked: allowed_ips check failed"}
```

`policy_denied` means no endpoint matched. `ssrf_denied` means an endpoint matched and destination validation refused the address or port. An endpoint whose `host` is an IP literal gets that address implicitly allowlisted (`implicit_allowed_ips_for_ip_host`), which is why a blocked control-plane port on a declared IP reports an `allowed_ips` failure despite no `allowed_ips` appearing in the policy.

## Exec Session Stability

`sandbox exec` TTY sessions drop during idle periods. `--timeout 0` is the default (no timeout), so it is not an exec-level timeout. The gRPC stream between CLI and gateway/supervisor is suspected of being reaped. No keepalive configuration is exposed. Workaround: background process writing ENQ byte to stdout every 30s.

## Network Policy Discovery

No container-side policy file exists in a current sandbox at `/etc/openshell/policy.yaml` — that path does not exist; `/etc/openshell/` contains only `auth/` and `tls/` subdirectories. A session cannot read its own effective policy from inside the container unless something outside places a copy there (e.g., `/sandbox/source/openshell-policy.yaml`, uploaded from the host per the project's own `CLAUDE.md`). The host can still inject **additional** policy entries beyond any uploaded copy — the proxy enforces the union — so an uploaded policy file should not be trusted as exhaustive; verify access empirically.

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

### Tailscale MagicDNS Resolution

A `<name>.<tailnet>.ts.net` host in the network policy resolves and works from inside a sandbox, because name resolution happens host-side at the L7 proxy and the host is on the tailnet — no Tailscale `100.x` address is needed inside the sandbox. Verified against a tailnet-exposed OTLP collector: with the host in policy the endpoint answered `405 Method Not Allowed` to a GET (correct for an OTLP HTTP receiver), and the same tailnet host when absent from the policy answered `403`.

## Container Identification

OpenShell sandbox containers use labels for identification:

- `openshell.ai/sandbox-name` — user-facing sandbox name
- `openshell.ai/sandbox-id` — UUID assigned by OpenShell

Container names follow the pattern `openshell-default--<sandbox-name>-<sandbox-uuid>` but should not be hardcoded. Use label-based lookup via `podman ps -a --format json | jq` filtering on the `openshell.ai/sandbox-name` label.

## Package Installation via apt

`apt-get install` cannot succeed inside a sandbox: there is no `sudo`, `/usr` is `read_only` in the filesystem policy, and `/var` appears in neither the read-only nor read-write lists, so `/var/lib/apt`, `/var/cache`, and `/var/lib/dpkg/status` are all inaccessible.

Discovery and extraction still work, by redirecting all of apt's state directories to a writable path. Verified sequence, given a policy allowing `deb.debian.org` on 80 and 443:

```bash
mkdir -p /tmp/apt/lists/partial /tmp/apt/cache/archives/partial
A="-o Dir::State=/tmp/apt -o Dir::State::Lists=/tmp/apt/lists
   -o Dir::Cache=/tmp/apt/cache -o Dir::State::status=/tmp/apt/status
   -o Debug::NoLocking=1"
apt-get $A update            # fetched ~10 MB
apt-cache $A search '^ripgrep$'
cd /tmp/apt && apt-get $A download ripgrep && dpkg -x ./*.deb /tmp/apt/root
/tmp/apt/root/usr/bin/rg --version   # runs
```

`Dir::State` must be overridden too, not just `Dir::State::Lists` and `Dir::Cache` — without it apt fails on `/var/lib/apt/extended_states`. This makes a read-only Debian mirror grant genuinely useful: a session can identify a package, confirm it is the right one, extract a working binary, and use it directly from the extracted path, without ever needing install permission.

## Sandbox JWT Token Delivery

Tokens are NOT bind-mounted from the host. The JWT lives at `/etc/openshell/auth/sandbox.jwt` inside the container overlay (not a writable volume). `OPENSHELL_SANDBOX_TOKEN_FILE` env var points there.

`podman cp` can write to the overlay on a stopped container; the change persists until the container is removed. `podman restart` resets the overlay — must stop, cp, then start (not restart).

## Sandbox Profiles

`sandbox.sh --profile <name>` controls which credentials, env vars, and network policy a sandbox receives. Profile stored in `manifest.json` so `--refresh` inherits it without re-specifying.

| Profile | Auth | Env var groups | Network policy | Skipped uploads | OTEL |
|---------|------|----------------|----------------|-----------------|------|
| (none/default) | Vertex AI | all groups | `code.yaml` | none | push + Prometheus/Loki read |
| `personal` | `ANTHROPIC_API_KEY` | ANTHROPIC + CLAUDE + OTEL only | `personal.yaml` | gcloud, gws | push-only, tagged `sandbox.profile=personal` |

Personal profile also strips Jira and Prometheus/Loki sections from the sandbox system prompt (`config/sandbox-claude.md`) at upload time. The OTEL collector endpoint (port 4318) is write-only by design — sandbox pushes telemetry but cannot query it — so sharing a collector between work and personal sandboxes does not leak data. Resource attribute `sandbox.profile=personal` enables Grafana filtering.

## Gateway Dev Script Config Override

`tasks/scripts/gateway.sh` in the OpenShell repo writes `ttl_secs = 3600` into the generated `gateway.toml` on every `mise run gateway`. Commit `e4bcfdfa` changed the compiled code default in `defaults.rs` from 3600 to 0 (no expiry) for local single-player gateways, but the script hardcodes the old value. The fix at the code level never takes effect because the script-generated config overrides it. Fix: change `ttl_secs = 3600` to `ttl_secs = 0` in `tasks/scripts/gateway.sh` line 330.
