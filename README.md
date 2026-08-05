# Knowledgebase

Discoveries, vendor quirks, tool internals, API taxonomies — facts about how
things work that don't fit the prescriptive shape of a coding standard.

Companion to [jewzaam/standards](https://github.com/jewzaam/standards).

## What lives here vs in standards

| | Knowledgebase | Standards |
|---|---|---|
| Shape | **Descriptive** — "this is how X works" | **Prescriptive** — "do it this way" |
| Examples | Vendor APIs, K8s gotchas, tool internals, error envelopes, taxonomies | Style, naming, project structure, required Makefile targets, testing patterns |
| Reader question | "What do I need to know about X?" | "How do I do Y in this project?" |
| Stays stable when | Underlying vendor / tool changes | Team conventions evolve |

Rule of thumb: if removing the document would make a vendor / API / tool harder
to use, it belongs here. If removing it would make project structure inconsistent,
it belongs in standards.

## Related repos

- **[jewzaam/standards](https://github.com/jewzaam/standards)** — prescriptive
  coding/build/test standards. Cross-linked from individual KB pages where the
  two overlap (e.g., `fabcheck.md` here is the tool internals; the opt-in steps
  and Make target live in standards).
- **[jewzaam/gws-cli-notes](https://github.com/jewzaam/gws-cli-notes)** —
  topically part of this knowledgebase (`gws` CLI usage facts, quirks, examples)
  but kept as its own repo because it is large, gws-specific, and shared with
  collaborators outside the standards/knowledgebase split.

## Usage

Reference in your project:

```markdown
This project's discoveries live in the [Knowledgebase](https://github.com/jewzaam/knowledgebase).
```

## [Build and CI/CD](build/)

| Doc | Description |
|---|---|
| [fabcheck](build/fabcheck.md) | Fabcheck tool internals: language coverage, dist-name resolution modes, gaps |
| [GitLab Container Registry](build/gitlab-container-registry.md) | Resolving an image tag to a manifest digest via the GitLab Container Registry API; repository-id path requirement; multi-arch tag size/revision fields |
| [GHCR Publishing](build/ghcr-publish.md) | Why fine-grained PATs fail, classic PAT scoping, OCI label linkage mechanics, first-publish-private behavior |
| [Local Workflow Testing](build/local-workflow-testing.md) | How act works, runner image internals, security risks, runner-image differences from GitHub-hosted |

## [Claude Code](claude-code/)

| Doc | Description |
|---|---|
| [Agent SDK Usage Data](claude-code/agent-sdk-usage-data.md) | Extracting cost, token, context, and rate-limit data from the Agent SDK |
| [Hook State Transitions](claude-code/hook-state-transitions.md) | Hook event types, state machines, and configuration |
| [OAuth Tokens](claude-code/oauth-tokens.md) | Anthropic OAuth token taxonomy, endpoint compatibility, error-envelope quirks, K8s Secret tmpfs reset |
| [Plugins](claude-code/plugins.md) | Plugin caching behavior, env vars, marketplace mechanics |
| [OTEL Native Telemetry](claude-code/otel-native-telemetry.md) | Native OTEL event types, labels, query_source taxonomy, session state derivation signals |
| [Skills](claude-code/skills.md) | Permission enforcement detail, shell injection mechanics |
| [Workflow Structured Output](claude-code/workflow-structured-output.md) | Workflow `args` global failure, `agent(schema:)` mechanism, Ajv validation, schema constraints |

## [Common](common/)

| Doc | Description |
|---|---|
| [Atlassian API Authentication](common/atlassian-api-auth.md) | Token types, scoping, URL routing, auth methods, network policy granularity |
| [Commit Conventions](common/commit-conventions.md) | Commit type taxonomy evolution from AngularJS through Angular to Conventional Commits; why `chore` and `style` persist |
| [CRLF Line Endings Under WSL](common/crlf-wsl.md) | CRLF silently breaks bash scripts; detection via `file`, one-off `dos2unix`, durable `.gitattributes` prevention |
| [gdbus GVariant Escaping](common/gdbus-gvariant-escaping.md) | gdbus GVariant double-escaping of quotes in D-Bus extension output, JSON parsing fix |
| [Git Remote Discovery](common/git-remote-discovery.md) | Why `origin`/`upstream` are conventions not contracts |

## [Containers](containers/)

| Doc | Description |
|---|---|
| [OpenShell](containers/openshell.md) | Proxy architecture (HTTP/1.1 CONNECT, no gRPC), host.containers.internal resolution |
| [Podman Rootless Networking](containers/podman-rootless-networking.md) | Pasta TAP vs interface-copy mode, rootless-netns debugging, bridge data path, pasta version regressions |

## [.NET](dotnet/)

| Doc | Description |
|---|---|
| [NINA Plugin](dotnet/nina-plugin.md) | NINA 3.x C# plugin: build, MEF, mediators, options, HTTP, logging, publishing |

## [Kubernetes](kubernetes/)

| Doc | Description |
|---|---|
| [ApplicationSet Safety](kubernetes/applicationset-safety.md) | Argo CD cascade-delete behavior, Go template missing-key semantics |
| [Argo CD Sync Drift](kubernetes/argocd-sync-drift.md) | Four causes of perpetual OutOfSync: ignoreDifferences group stripping, kubeseal timestamp drift, Synced-vs-unchanged distinction, Grafana datasource UID preservation |
| [ConfigMap Reload](kubernetes/configmap-reload.md) | Why kubelet doesn't restart on CM/Secret content change; Reloader direct-mount gotcha |
| [GitOps Polling vs Webhooks](kubernetes/gitops-polling-vs-webhooks.md) | Argo CD default 3-min poll latency; webhook setup |
| [GUI Desktop Containers](kubernetes/gui-desktop-containers.md) | Rootless VNC/noVNC image compatibility under PSA restricted; reading an entrypoint's `id -u` branch to tell whether a root-`USER` image runs rootless; PixInsight installer-skip and package gaps |
| [Helm Values](kubernetes/helm-values.md) | Helm silent-ignore behavior, grafana subchart failure mode |
| [Image Tag Immutability](kubernetes/image-tag-immutability.md) | Tags are build identifiers; kubelet `IfNotPresent` cache behavior |
| [Job Sync Hooks](kubernetes/job-sync-hooks.md) | Jobs are immutable; Argo CD sync hooks for delete-and-recreate |
| [kubectl run Entrypoints](kubernetes/kubectl-run-entrypoints.md) | Match `kubectl run -- <args>` to image's ENTRYPOINT shape |
| [Longhorn Volume Behavior](kubernetes/longhorn-volume-behavior.md) | Thin provisioning vs scheduling reservation; failure symptoms when nominal budget exhausted; Helm hot-update limitation; space reclamation via Trim Filesystem vs in-pod fstrim; ad-hoc Backup admission webhook EOF on 1.11.x |
| [Tailscale Kubernetes Operator](kubernetes/tailscale-operator.md) | ClusterIP Service exposure, port=tailnet-port mapping, port 443 for portless URLs, L4 TCP passthrough (no TLS termination) |
| [PodSecurity Restricted Pod](kubernetes/podsecurity-restricted-pod.md) | Admission-rejection wall-of-text format and why it surfaces only at admission |
| [Resource Limits](kubernetes/resource-limits.md) | CFS bandwidth controller throttling mechanics; why CPU limits hurt |

## [Observability](observability/)

| Doc | Description |
|---|---|
| [Loki Recording Rules](observability/loki-recording-rules.md) | LogQL recording rule gotchas: timestamp comparison, count_over_time grouping, ruler remote_write config format |
| [Readiness Probes](observability/readiness-probes.md) | Why mission-capability vs dependency split matters (ServiceMonitor scrape gaps) |

## [Python](python/)

| Doc | Description |
|---|---|
| [Cross-Platform](python/cross-platform.md) | Microsoft Store alias mechanism; SAC blocks pip .exe shims |
| [Tkinter](python/tkinter.md) | Menu keyboard shortcuts: underline parameter is visual only, XWayland focus issues, bind_all() requirement |

## Guiding Principles

1. **Faithful to source** — record what was observed, not what should have been
2. **Cite provenance** — link to the issue, PR, or repo that surfaced the fact
3. **Date verification** — facts decay; note when a claim was verified
4. **Cross-link** — if a fact has a prescriptive companion in standards, link both ways
