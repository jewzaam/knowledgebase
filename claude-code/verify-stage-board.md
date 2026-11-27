# A Verify stage keeps builders from looping on checks they cannot do

A builder can prove only what it can run before merge. Checks that need the
merged software in its real environment (a router restart, a device, a
measurement over time) have no owner in a Build-only flow, so the dispatcher
relaunched builders with nothing to do and invented "builder stopped twice"
user actions (work card #62, fixed in card #75).

- Columns: Backlog, Refinement, Ready, Build, In review, Verify, Done. Build is
  only a builder; Verify is only a check by its named owner.
- Criteria the builder cannot prove are tagged `[verify]` and copied into a
  `## Verification` section, one box each, owned by `@verifier:` (dispatcher
  session) or `@jewzaam:` (the user).
- A line may end with `(prepare: restart-router)`. After the merge the closer
  files that request once, then moves the card to Verify; the verifier starts
  when the request is done. The builder never files it: a restart before the
  merge would test the old code.
- A failed check sends the card to Ready with the evidence; it is a fix cycle,
  not a failed builder attempt. Verifier runs have their own counter.
- Renaming a Projects v2 single-select option keeps its id when
  `updateProjectV2Field` is given the full option list with each `id`, so no
  card moves (`tools\project-columns.ps1` in claude-orchestrator).
