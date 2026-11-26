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

## Astrophotography

- [astrophotography/pixinsight-headless-automation.md](astrophotography/pixinsight-headless-automation.md) — PixInsight 1.9.6 headless runs: `--automation-mode --run` flags and settings slots, silent-failure traps in PJSR scripts, `#define` macros vs `eval`, loading the Canon Banding Reduction engine without its dialog, RC-Astro BlurX/NoiseX/StarX parameters and CPU timings, PixelMath `symbols`, MMT layer array, near-zero stars layers, GUI automation on scaled displays

## Build and CI/CD

- [build/ghcr-publish.md](build/ghcr-publish.md) — why fine-grained PATs fail, classic PAT scoping, OCI label linkage mechanics, first-publish-private behavior
- [build/local-workflow-testing.md](build/local-workflow-testing.md) — how act works, runner image internals, security risks, runner-image differences from GitHub-hosted
- [build/fabcheck.md](build/fabcheck.md) — fabcheck tool internals: language coverage, dist-name resolution modes, known gaps
- [build/pyinstaller-windows-installer.md](build/pyinstaller-windows-installer.md) — PyInstaller/Inno Setup Windows installer behaviors: astropy hook failing with pytest installed, `copy_metadata` for importlib.metadata version reads, hiddenimports for run-time imports, one-Analysis GUI+console exes, Linux binutils need, Inno Setup absent from GitHub Windows runners, conflicting `git+` pins
- [build/gitlab-container-registry.md](build/gitlab-container-registry.md) — resolving an image tag to a manifest digest via the GitLab Container Registry API

## Claude Code

- [claude-code/agent-sdk-usage-data.md](claude-code/agent-sdk-usage-data.md) — extracting cost, token, context, and rate-limit data from the Agent SDK
- [claude-code/headless-stream-json-sessions.md](claude-code/headless-stream-json-sessions.md) — `claude -p` stream-json persistent session (one process, many messages, mid-turn folding), context size from the last API call, AskUserQuestion via `--permission-prompt-tool stdio`, `--session-id` vs `--resume` errors, plugin MCP servers and `--strict-mcp-config`, variadic `--channels`, what bypass mode still prompts for, usage-limit windows and status line fields, sub-agent model resolution order
- [claude-code/hook-state-transitions.md](claude-code/hook-state-transitions.md) — hook event types, state machines, configuration, `Stop` vs `StopFailure`, fail-open on unstartable hooks
- [claude-code/headless-session-ids.md](claude-code/headless-session-ids.md) — `claude -p --session-id` chooses the id, `--resume` continues it
- [claude-code/headless-session-ids.md](claude-code/headless-session-ids.md) — `claude -p --session-id` chooses the id, `--resume` continues it; second process on a busy id, resume from another cwd or worktree, kill mid-turn then resume
- [claude-code/headless-injection-and-interrupt.md](claude-code/headless-injection-and-interrupt.md) — stream-json mid-turn message folding (reaction only between steps, sub-agent not cancelled), the interrupt control request (~120 ms, process survives, interrupt before the first tool loses the turn), spawn-to-init latency and haiku cost per run
- [claude-code/headless-write-enforcement.md](claude-code/headless-write-enforcement.md) — `--settings` PreToolUse hooks in headless bypass mode, exit 2 vs JSON deny, Edit/Write matcher not covering Bash, Bash denylist bypass vs allowlist, `--disallowedTools`, untested areas
- [claude-code/hook-state-transitions.md](claude-code/hook-state-transitions.md) — hook event types, state machines, configuration
- [claude-code/model-restrictions.md](claude-code/model-restrictions.md) — `availableModels` allowlist scope and entry matching, managed-only `deniedModels`, `enforceAvailableModels` scope conflict, the Default picker row, precedence chain, gateway discovery `claude`/`anthropic` substring filter, `modelOverrides` key rules
- [claude-code/oauth-tokens.md](claude-code/oauth-tokens.md) — Anthropic OAuth token taxonomy, endpoint compatibility, error-envelope quirks, `~/.claude.json` auth-file requirement, K8s Secret tmpfs reset
- [claude-code/plugins.md](claude-code/plugins.md) — plugin caching, env vars, marketplace mechanics
- [claude-code/settings-json-rewrites.md](claude-code/settings-json-rewrites.md) — Claude Code rewrites `settings.json`: unknown keys survive only at the top level, nested hook/rule keys are dropped, hook command strings (and their shell comments) survive
- [claude-code/reviews-standards-skill-headless.md](claude-code/reviews-standards-skill-headless.md) — `jewzaam-reviews` `standards` and `review` skills are slash-only (headless `claude -p "/jewzaam-reviews:standards <path>"`), findings files written after the host exits, owner gate `NOT_APPLICABLE` skipped by passing the standards path, count findings from the JSON not the chat summary
- [claude-code/skills.md](claude-code/skills.md) — permission enforcement detail, shell injection mechanics
- [claude-code/otel-native-telemetry.md](claude-code/otel-native-telemetry.md) — native OTEL event types, labels, query_source taxonomy, session state derivation signals
- [claude-code/workflow-structured-output.md](claude-code/workflow-structured-output.md) — Workflow tool `args` global failure, `agent(schema:)` StructuredOutput mechanism, Ajv validation, schema constraint support matrix
- [claude-code/websearch-and-subagent-tools.md](claude-code/websearch-and-subagent-tools.md) — WebSearch server-side execution vs WebFetch client-side egress, per-session search budget, non-verbatim results, sub-agent permission-prompt visibility, Bash output visibility

## Codex CLI

- [codex-code/otel-native-telemetry.md](codex-code/otel-native-telemetry.md) — Codex hook/config file locations, project trust scoping, hook payload fields, `codex_turn_token_usage_sum` histogram token_type values, native OTEL export behavior, managed app-server environment sharing across clients
- [codex-code/model-context-window.md](codex-code/model-context-window.md) — catalog `context_window` vs `max_context_window` per model, the `model_context_window` config key (i64, no feature flag, no `model_max_output_tokens`), absent client-side clamp, `model_auto_compact_token_limit`/`_scope` riding on the effective window, `model_catalog_json` override, no offline way to read either effective value
- [codex-code/skills-and-plugins.md](codex-code/skills-and-plugins.md) — `.agents/skills` discovery scopes, initial-list truncation budget, Agent Skills frontmatter vs Claude Code's dialect, absent `!`-injection, `request_user_input` as the AskUserQuestion counterpart (Plan-only by default, `default_mode_request_user_input` config flag to get Default mode, root-thread-only, max 3 questions, fallbacks if the flag goes) vs the unshipped `ask_user_question`, plugin-namespaced `$plugin:skill` invocation vs bare `$skill`, `.codex-plugin/plugin.json` and marketplace sources (legacy `.claude-plugin/` read, silent skip on unresolvable source), `codex exec` JSONL/`--output-schema` behavior and its token-only usage data, plus the separate authenticated app-server `account/usage/read` per-thread Enterprise usage/cost estimate (`estimatedUsageUsdMicros`)
- [codex-code/structured-outputs.md](codex-code/structured-outputs.md) — `--output-schema` JSON Schema subset actually accepted by the OpenAI Responses API (rejection happens server-side, before the agent runs), supported/unsupported keyword lists, root/required/`additionalProperties` structural rules, size limits, adapting a schema without losing validation, contrast with Claude Code's inverse support matrix

## OpenCode

- [opencode/permissions.md](opencode/permissions.md) — permission model: base `*:* allow`, catch-all `*:* ask` flip, `external_directory` checked separately from read/edit so a blanket edit allow leaks into dynamically approved dirs, glob semantics with no regex or negation, `~`/`$HOME`-only expansion, relative-vs-absolute resources and why `edit * allow` + `edit /* ask` is not a safe project boundary, Plan agent's unrestricted shell
- [opencode/skills.md](opencode/skills.md) — skill discovery from `~/.claude/skills` and `.claude/skills`, skills are not slash commands, absent `!` command injection so Claude skills silently lose their pre-flight, skill permission gating by ID
- [opencode/plugins.md](opencode/plugins.md) — V2 plugin shape and loading paths, `tool.execute.before`/`after`, mutable `permission.evaluate` effect, shell/session hooks, external-guard bridge pattern, absent lifecycle/exit-code protocol, and unverified loader details
- [opencode/vs-claude-code.md](opencode/vs-claude-code.md) — harness differences, centered on permission interaction: Claude shows the exact rule and accepts a note on allow or deny, OpenCode's "Allow always" persists a tool-chosen pattern with no pre-save edit; also default posture, rule precedence, modes vs agents, hooks vs plugins, instruction files and skills, and isolation gaps

## Containers

- [containers/openshell-codex-nested-sandbox.md](containers/openshell-codex-nested-sandbox.md) — OpenShell blocks the nested user namespace required by Codex read-only Bubblewrap; use `danger-full-access` inside the outer sandbox and surface launch failures instead of empty results

## Common

- [common/atlassian-api-auth.md](common/atlassian-api-auth.md) — Atlassian API token types, scoping, URL routing, auth methods, and network policy granularity
- [common/commit-conventions.md](common/commit-conventions.md) — commit type taxonomy evolution from AngularJS through Angular to Conventional Commits; why `chore` and `style` persist despite Angular dropping them
- [common/crlf-wsl.md](common/crlf-wsl.md) — CRLF line endings silently break bash scripts under WSL; detection, one-off fix, and durable `.gitattributes` prevention
- [common/gdbus-gvariant-escaping.md](common/gdbus-gvariant-escaping.md) — gdbus GVariant double-escaping of quotes in D-Bus extension output, JSON parsing fix
- [common/git-worktrees.md](common/git-worktrees.md) — one branch per worktree (exact error), worktree isolation, removing a dirty worktree needs `--force`
- [common/git-remote-discovery.md](common/git-remote-discovery.md) — why `origin`/`upstream` are conventions not contracts
- [common/mermaid-rendering.md](common/mermaid-rendering.md) — Mermaid rendering behaviors: node placement via connections, style color inheritance, subgraph nesting contrast, legend rendering, label quoting
- [common/github-projects-v2-and-gh.md](common/github-projects-v2-and-gh.md) — Projects v2 polling cost, single-select option replacement keeping item values, view API limits, `since` filters, rate-limit behavior, `gh` quoting on PowerShell 5.1, `--attach` uploads
- [common/powershell-5-1-traps.md](common/powershell-5-1-traps.md) — `ConvertFrom-Json` array unrolling, case-insensitive variables, ANSI source without BOM, `Set-Content` BOM
- [common/tar-mtime.md](common/tar-mtime.md) — GNU tar mtime handling: default format stores whole seconds (extraction truncates nanoseconds), `--newer` tests mtime or ctime while `--newer-mtime` tests mtime only, filtering does not affect directory traversal, consequences for mtime-based delta transfers
- [common/windows-11-and-powershell-5-1.md](common/windows-11-and-powershell-5-1.md) — Windows 11 Home missing features, `conhost --headless`, whisper-cli VC runtime exit code, Autologon, whisper.cpp Windows releases/model speed, PowerShell 5.1 ExitCode/stderr/BOM/alias traps
- [common/vscode-gnome-window-calls.md](common/vscode-gnome-window-calls.md) — GNOME `window-calls` extension facts for VS Code windows: `wm_class` is `com.microsoft.VSCode` not `code`, shared pid across windows making terminal-tab attribution unobservable, `List` response shape and null-title guard, title-to-workspace extraction, `gdbus` vs `psutil.children(recursive=True)` call cost

Standards counterpart: [standards/common/documentation-diagrams.md](https://github.com/jewzaam/standards/blob/main/common/documentation-diagrams.md) — prescriptive rules for diagram structure

## Containers

- [containers/openshell.md](containers/openshell.md) — OpenShell proxy architecture (HTTP/1.1 CONNECT, no gRPC), proxy chaining limits, host.containers.internal resolution, TLS fingerprint impersonation surviving the CONNECT tunnel opaquely, opt-in fetch-service for hosts outside policy, `/sandbox/.env` OTEL_RESOURCE_ATTRIBUTES leaking into tests, narrower git commit.gpgsign override, Xvfb extracted via apt failing on xkbcomp path, `sandbox exec` buffering stdin until EOF (deadlocking rsync-over-exec)
- [containers/podman-rootless-networking.md](containers/podman-rootless-networking.md) — pasta TAP vs interface-copy mode, rootless-netns debugging, bridge data path, pasta version regressions
- [containers/terminal-multiplexers-in-sandboxes.md](containers/terminal-multiplexers-in-sandboxes.md) — screen/tmux/dtach inside Landlock-enforced sandboxes: `/dev/pts` PTY fix, terminal emulation vs Claude Code TUI, dtach raw passthrough as working solution

## Discord

- [discord/bot-rest-api.md](discord/bot-rest-api.md) — message send and reaction endpoints, required headers and limits, permission bits, invite URL, Message Content intent, poll limits, voice message format

## .NET

- [dotnet/windows-ui-testing.md](dotnet/windows-ui-testing.md) — FlaUI.UIA3 on net10.0-windows, xUnit v3 missing `Parallelization` attribute, WinForms `AccessibleName` as UIA Name
- [dotnet/nina-plugin.md](dotnet/nina-plugin.md) — NINA 3.x C# plugin: build, MEF, mediators, options, HTTP, logging, publishing

## Astronomy data services

- [astro/gaia-tap.md](astro/gaia-tap.md) — Gaia DR3 star counts through the ESA TAP sync endpoint: request shape, box search, which ADQL forms failed
- [astro/nina-sequence-files.md](astro/nina-sequence-files.md) — NINA 3.2 sequence JSON: building it with NINA's own classes, instruction names seen, TakeManyExposures structure, binning $ref sharing, target-name file-pattern token, UI Automation cannot see tab content

## Kubernetes

- [kubernetes/applicationset-safety.md](kubernetes/applicationset-safety.md) — Argo CD ApplicationSet safety defaults: `preserveResourcesOnDeletion: true` for stateful generators, `goTemplateOptions: [missingkey=error]` for Go templates
- [kubernetes/argocd-sync-drift.md](kubernetes/argocd-sync-drift.md) — four causes of perpetual Argo CD OutOfSync: `ignoreDifferences` group-key stripping, kubeseal null-timestamp drift, Synced-vs-unchanged-resource distinction, Grafana datasource UID name-match preservation
- [kubernetes/configmap-reload.md](kubernetes/configmap-reload.md) — why the kubelet doesn't restart Pods on CM/Secret content change; Reloader direct-mount gotcha
- [kubernetes/gitops-polling-vs-webhooks.md](kubernetes/gitops-polling-vs-webhooks.md) — pair GitOps polling with webhooks day 1 (Argo CD, Flux)
- [kubernetes/gui-desktop-containers.md](kubernetes/gui-desktop-containers.md) — rootless VNC/noVNC images under PSA restricted (accetto fails, kasmweb works); why a root `USER` line doesn't settle rootless capability (read the entrypoint's `id -u` branch); PixInsight installer-skip and system-package gaps
- [kubernetes/helm-values.md](kubernetes/helm-values.md) — verify Helm value overrides with `helm template` before pushing
- [kubernetes/image-tag-immutability.md](kubernetes/image-tag-immutability.md) — tags are build identifiers, not versions; rotate the tag or pin by digest per build (kubelet `IfNotPresent` caches by tag)
- [kubernetes/job-sync-hooks.md](kubernetes/job-sync-hooks.md) — Jobs are immutable; use Argo CD sync hooks for delete-and-recreate
- [kubernetes/kubectl-run-entrypoints.md](kubernetes/kubectl-run-entrypoints.md) — match `kubectl run -- <args>` to the image's ENTRYPOINT shape
- [kubernetes/longhorn-volume-behavior.md](kubernetes/longhorn-volume-behavior.md) — thin provisioning vs scheduling reservation at op%=100; failure symptoms when nominal budget exhausted; Helm defaultSettings hot-update limitation; space reclamation via Trim Filesystem action vs in-pod fstrim (blocked by restricted PSA); ad-hoc Backup admission webhook EOF on 1.11.x
- [kubernetes/openshell-helm-chart.md](kubernetes/openshell-helm-chart.md) — NVIDIA OpenShell Helm chart: chart named `helm-chart` so `nameOverride` decides resource names; `fullnameOverride` renames resources but NOT selector labels (StatefulSet rename hazard); `lookup`-based credential KEK regenerates under `helm template`/Argo; agent-sandbox preflight `fail`; silently-ignored `service.annotations`; manylinux_2_39-only wheels; no CLI/gateway version negotiation
- [kubernetes/tailscale-operator.md](kubernetes/tailscale-operator.md) — Tailscale K8s operator: ClusterIP Service exposure, port=tailnet-port mapping, port 443 for portless URLs, L4 TCP passthrough (no TLS termination)
- [kubernetes/podsecurity-restricted-pod.md](kubernetes/podsecurity-restricted-pod.md) — admission-rejection wall-of-text format and why it surfaces only at admission
- [kubernetes/resource-limits.md](kubernetes/resource-limits.md) — CFS bandwidth controller throttling mechanics; why CPU limits hurt

## Discord

- [discord/threads.md](discord/threads.md) — docs-sourced thread facts: auto-unarchive on message unless locked, permissions for posting/un-archiving, `auto_archive_duration` values, name length, unstated rename/creation limits, deletion

## Observability

- [observability/readiness-probes.md](observability/readiness-probes.md) — why mission-capability vs dependency split matters (ServiceMonitor scrape gaps)
- [observability/loki-recording-rules.md](observability/loki-recording-rules.md) — LogQL recording rule gotchas: timestamp comparison, count_over_time grouping, ruler remote_write config format

## Python

- [python/cross-platform.md](python/cross-platform.md) — Microsoft Store alias mechanism; Smart App Control blocking pip .exe shims
- [python/tkinter.md](python/tkinter.md) — Tkinter menu keyboard shortcuts (underline parameter is visual only, XWayland focus issues, bind_all() requirement, toplevel `<Key>` handler returning "break" starves bind_all, deriving shortcuts from entry underline + invoke(), dock-type/overrideredirect windows not taking click focus), Unicode rendering (supplementary plane broken on Linux), Canvas scroll events (embedded widgets consume events), ttk.Notebook scroll-to-change-tab behavior, text tag bindings vs embedded widgets for row controls (line-height and widget-count cost, tag_bind replaces rather than accumulates), synthesizing clicks on text tags (Motion first, ButtonPress/Release pair)
- [python/web-frameworks.md](python/web-frameworks.md) — FastAPI/uvicorn HTTPS with self-signed certs (browser acceptance requirement, curl -k flag, dev vs production TLS)
- [python/ddgs-metasearch.md](python/ddgs-metasearch.md) — `ddgs` is a nine-backend metasearch layer not a DuckDuckGo client; `ENGINES` registry; silent fallback on unknown backend names; per-call vs cross-call result diversity; wikipedia/grokipedia as lookups not indexes; yahoo backend is Bing-powered; backend availability volatility; TLS fingerprint as the anti-bot discriminator
