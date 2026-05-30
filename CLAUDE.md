# Knowledgebase Repository

Descriptive companion to [jewzaam/standards](https://github.com/jewzaam/standards).
Facts, vendor quirks, tool internals, API taxonomies, and discoveries. AI agents
read these when working in any project that needs background on a vendor / tool
behavior captured here.

The full organized index with section descriptions is in
[README.md](README.md). Every file is also linked directly below for
tool-based lookup.

Run `make help` for available validation targets.

## What lives here vs in standards

- **Here (knowledgebase):** descriptive — "this is how X works", vendor quirks,
  API facts, tool internals, discovered gotchas, error envelopes, taxonomies.
- **Standards:** prescriptive — "do it this way", project style/structure,
  required targets, naming conventions, testing patterns.

Quick decision rule: if the doc tells you *what to do in your code* it belongs
in standards. If it tells you *how the outside world behaves* it belongs here.

## Related repos

- **[jewzaam/standards](https://github.com/jewzaam/standards)** — prescriptive
  rules. Many KB docs cross-link to a standards counterpart (the prescriptive
  side of a hybrid topic).
- **[jewzaam/gws-cli-notes](https://github.com/jewzaam/gws-cli-notes)** — gws
  CLI facts and usage. Conceptually a sub-area of this knowledgebase but kept
  as its own repo because of size and shared external audience.

## Maintaining this file

Every non-infrastructure file in this repo must be linked directly from this
file. No file should require traversing intermediate documents to discover.

Run `make test-reachability` (or `python scripts/reachability.py --check`) to
verify. It fails if any content file is missing a direct link from CLAUDE.md
or README.md.

When adding a new knowledgebase doc:

1. Add the file under the appropriate section directory
2. Add a direct link here with a short description
3. Add a link in [README.md](README.md) under the matching section
4. If the topic has a prescriptive companion in standards, cross-link both ways
5. Run `make test-reachability` to confirm

## Build and CI/CD

- [build/ghcr-publish.md](build/ghcr-publish.md) — why fine-grained PATs fail, classic PAT scoping, OCI label linkage mechanics, first-publish-private behavior
- [build/local-workflow-testing.md](build/local-workflow-testing.md) — how act works, runner image internals, security risks, runner-image differences from GitHub-hosted
- [build/fabcheck.md](build/fabcheck.md) — fabcheck tool internals: language coverage, dist-name resolution modes, known gaps

## Claude Code

- [claude-code/agent-sdk-usage-data.md](claude-code/agent-sdk-usage-data.md) — extracting cost, token, context, and rate-limit data from the Agent SDK
- [claude-code/hook-state-transitions.md](claude-code/hook-state-transitions.md) — hook event types, state machines, configuration
- [claude-code/oauth-tokens.md](claude-code/oauth-tokens.md) — Anthropic OAuth token taxonomy, endpoint compatibility, error-envelope quirks, K8s Secret tmpfs reset
- [claude-code/plugins.md](claude-code/plugins.md) — plugin caching, env vars, marketplace mechanics
- [claude-code/skills.md](claude-code/skills.md) — permission enforcement detail, shell injection mechanics

## Common

- [common/git-remote-discovery.md](common/git-remote-discovery.md) — why `origin`/`upstream` are conventions not contracts

## .NET

- [dotnet/nina-plugin.md](dotnet/nina-plugin.md) — NINA 3.x C# plugin: build, MEF, mediators, options, HTTP, logging, publishing

## Kubernetes

- [kubernetes/applicationset-safety.md](kubernetes/applicationset-safety.md) — Argo CD ApplicationSet safety defaults: `preserveResourcesOnDeletion: true` for stateful generators, `goTemplateOptions: [missingkey=error]` for Go templates
- [kubernetes/configmap-reload.md](kubernetes/configmap-reload.md) — why the kubelet doesn't restart Pods on CM/Secret content change; Reloader direct-mount gotcha
- [kubernetes/gitops-polling-vs-webhooks.md](kubernetes/gitops-polling-vs-webhooks.md) — pair GitOps polling with webhooks day 1 (Argo CD, Flux)
- [kubernetes/helm-values.md](kubernetes/helm-values.md) — verify Helm value overrides with `helm template` before pushing
- [kubernetes/image-tag-immutability.md](kubernetes/image-tag-immutability.md) — tags are build identifiers, not versions; rotate the tag or pin by digest per build (kubelet `IfNotPresent` caches by tag)
- [kubernetes/job-sync-hooks.md](kubernetes/job-sync-hooks.md) — Jobs are immutable; use Argo CD sync hooks for delete-and-recreate
- [kubernetes/kubectl-run-entrypoints.md](kubernetes/kubectl-run-entrypoints.md) — match `kubectl run -- <args>` to the image's ENTRYPOINT shape
- [kubernetes/podsecurity-restricted-pod.md](kubernetes/podsecurity-restricted-pod.md) — admission-rejection wall-of-text format and why it surfaces only at admission
- [kubernetes/resource-limits.md](kubernetes/resource-limits.md) — CFS bandwidth controller throttling mechanics; why CPU limits hurt

## Observability

- [observability/readiness-probes.md](observability/readiness-probes.md) — why mission-capability vs dependency split matters (ServiceMonitor scrape gaps)

## Python

- [python/cross-platform.md](python/cross-platform.md) — Microsoft Store alias mechanism; Smart App Control blocking pip .exe shims
