# WebSearch, WebFetch, and Sub-Agent Tool Behaviors

Discovered facts about how the built-in `WebSearch`/`WebFetch` tools and
sub-agent tool calls actually behave, distinct from their documented
interface.

## `WebSearch` executes server-side; `WebFetch` executes client-side

`WebSearch` runs server-side via the Anthropic API rather than egressing
from the local machine. This means it keeps working in a sandboxed
environment where outbound network access is restricted — it never touches
the local network policy.

`WebFetch` egresses client-side (from the machine running Claude Code) and
fails in that same restricted environment, surfacing as `Socket is closed`
when the target host isn't reachable from the sandbox.

Observed in [claude-skill-cited-research](https://github.com/jewzaam/claude-skill-cited-research)
running inside a rootless OpenShell sandbox with an HTTP CONNECT egress
proxy: `WebSearch` calls succeeded throughout the session while `WebFetch`
calls to arbitrary hosts failed with the closed-socket error.

## `WebSearch` has a per-session call budget

A per-session limit on `WebSearch` invocations exists (observed limit: 200),
surfaced via a message naming the environment variable
`CLAUDE_CODE_MAX_WEB_SEARCHES_PER_SESSION`. Once exhausted, calls return a
notice instead of results — not an error, a budget-exhausted notice. The
budget is session-wide and shared across all sub-agents dispatched within
that session, not per-agent.

## `WebSearch` results are not reliable verbatim source text

`WebSearch` returns a model-synthesized answer plus a list of links. It does
not reliably return per-URL verbatim snippets suitable for direct quotation.
Observed across multiple sub-agents in
[claude-skill-cited-research](https://github.com/jewzaam/claude-skill-cited-research):
agents asked to quote source text from `WebSearch` results reported having
nothing quotable and declined to quote rather than paraphrase and
misattribute it as a direct quote.

## Sub-agents can surface permission prompts, but can't observe them

A sub-agent's tool call (e.g. `Bash` invoking a non-allowlisted script) can
still produce a permission approval prompt shown to the user, even though the
call originates inside a sub-agent rather than the main agent. Verified: such
a prompt appeared and the user accepted it.

The sub-agent itself cannot see the approval dialog — it has no way to detect
whether a prompt appeared, was accepted, or was denied, only whether its tool
call ultimately succeeded or failed. It cannot self-report on prompt
occurrence.

## Bash tool output reaches the model, not reliably the user

Output from the `Bash` tool is displayed to the model but is not reliably
shown to the user in the transcript. Anything from a `Bash` call that the
user needs to see has to be explicitly pasted into the agent's response body
— relying on the user having seen raw tool output is not safe.
