# Running the jewzaam-reviews Skills Headless

Behavior of the `jewzaam-reviews` plugin skills (`standards`, `review`) when
run non-interactively. Observed running the plugin skills headless on Windows
with `claude -p`, single runs.

## Invocation (observed)

- Both skills are slash-command only (`disable-model-invocation`). A model
  session cannot call them through the Skill tool; the slash command must be the
  prompt itself.
- Headless form, with the repository to audit as the working directory:
  `claude -p "/jewzaam-reviews:standards <standards repo path>"` and
  `claude -p "/jewzaam-reviews:review"`.
- `standards` audits a repository against a standards repo. It is read-only and
  writes `Findings-standards.json`, `Findings-standards.md` and
  `Findings-standards-supplementary.md` at the project root.
- `review` behaves the same way: slash-only, detaches its orchestrator, writes
  `Findings-review*.json`.
- Findings schema is shared: severities `critical`, `important`, `suggestion`.
  The JSON is authoritative; the markdown is rendered from it.

## Owner gate (observed)

Run from a repository whose `origin` owner is not the user's own account, the
`standards` skill stops with
`NOT_APPLICABLE: origin owner '<x>' is not a user-owned repo` and prints the
reason without auditing. Passing the standards repo path explicitly as the
argument skips the gate: it then ran and produced findings.

## Timing and completion (observed)

- One background audit agent is spawned per applicable standards group. On a
  small C# repo with 5 of 11 groups applicable, wall time was a few minutes.
- The host session exits before the findings files exist. Poll for
  `Findings-standards.md` / `.json` instead of treating process exit as done.

## Counting findings (observed)

Count from the JSON (`findings[].severity`), not from the model's closing chat
summary. In one run the chat said 12 important findings while the JSON held 13.
