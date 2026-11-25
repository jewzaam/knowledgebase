# Headless Mid-Turn Messages and Interrupt

Behavior of `claude -p --input-format stream-json --output-format stream-json`
when a second message or an interrupt arrives while a turn is running. Observed
while building an agent work board on Windows, Claude Code headless sessions,
haiku model, one run per scenario (not repeated). Arguments used:
`--verbose --dangerously-skip-permissions --strict-mcp-config --session-id <uuid>`;
no `--permission-prompt-tool`, `--max-turns` or `--append-system-prompt`.

## Mid-turn message folding (observed)

- A message written to stdin during a running turn is folded into that turn:
  one `result` event, no new turn, `queued_turn_count` 0, and the model honored
  both messages.
- The model reacts only between steps. With a 40 s tool running, the message
  sent at 22.8 s produced no assistant event until the tool returned at 58.5 s;
  the tool was not aborted. Reaction is delayed by the rest of the running tool.
- With a sub-agent running, the message reached the main agent only after the
  sub-agent handed back (sent 30.5 s, hand-back 63.1 s, next main action
  65.6 s). The sub-agent was not cancelled or restarted (stats: spawned 1,
  completed 1, killed 0).
- UNVERIFIED: whether a message is seen when it arrives during an LLM call
  rather than during a tool.
- The `system/init` event appears only after message 1 is processed; a message
  sent before init is just part of message 1.

## Interrupt control request (observed)

- Sending a `control_request` with subtype `interrupt` during a running tool
  ended the step in about 120 ms: `control_response` after 25 ms, the running
  tool killed, a tool result "user doesn't want to proceed", then `result` with
  subtype `error_during_execution`.
- The process stays alive and keeps context: a follow-up message in the same
  process was answered correctly (a new `system/init` event appears per turn
  after an interrupt).
- An interrupt sent before the first tool call (during turn start) lost the
  whole turn: it was not persisted and the follow-up had no context. Interrupt
  only after the first tool use.

## Cost and latency (observed, haiku)

- About 9-13 s from spawn to `system/init`, because user SessionStart hooks run
  first. About 22k cache-creation tokens on the first call.
- `total_cost_usd` per small run: 0.0058 (3 turns), 0.0092 (with a sub-agent),
  0.0046 (interrupted turn; 0.0051 cumulative with a 2 s follow-up).
