# Codex Nested Sandboxes Under OpenShell

Verified: 2026-09-14  
Context: Codex CLI launched inside an OpenShell sandbox

Codex `exec --sandbox read-only` normally creates a nested Bubblewrap/user
namespace sandbox. Under OpenShell, that nested namespace can fail before the
agent starts:

```text
bwrap: No permissions to create a new namespace
```

The failure is caused by the outer sandbox's process policy (`NoNewPrivs: 1`,
seccomp filtering, and no effective capabilities), not by exhausted or
disabled `max_user_namespaces`. A direct `unshare -Ur true` fails with the
same `Operation not permitted` result. A Codex child using
`--sandbox danger-full-access` can still run because it avoids the nested
Bubblewrap namespace; OpenShell remains the outer security boundary.

## Workaround

When Codex runs under OpenShell, use:

```bash
codex exec --sandbox danger-full-access
```

The review orchestrator detects `OPENSHELL_SANDBOX=1` and selects that mode by
default. Override it with `REVIEW_ORCHESTRATOR_CODEX_SANDBOX` when running in a
different environment:

```bash
REVIEW_ORCHESTRATOR_CODEX_SANDBOX=read-only codex exec ...
```

Only use `read-only` where the host permits nested user namespaces. A failed
agent launch must be reported as an execution error; it must not be rendered
as an empty, successful review.
