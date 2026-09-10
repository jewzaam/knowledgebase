# Claude Code Settings Rewrites

Claude Code writes back to `~/.claude/settings.json` during normal operation.
What survives that rewrite decides where per-hook metadata can live — a marker
that does not survive fails silently, with the hook simply absent from whatever
consumes the file next.

> Prescriptive counterpart:
> [standards/common/skill-hook-registration.md](https://github.com/jewzaam/standards/blob/main/common/skill-hook-registration.md)
> — how skills ship hook registrations and why the retention marker is a shell
> comment.

## Claude Code rewrites the file itself

Observed triggers: persisting a plugin toggle (`claude plugin disable`), and
adding `skipDangerousModePermissionPrompt`. The rewrite is a full re-serialize,
not a targeted patch — it is the re-serialize that loses keys.

## Unknown keys survive only at the top level

| Location of the unknown key | Survives a rewrite |
|---|---|
| Top level of `settings.json` (e.g. `_source`) | Yes |
| Nested inside a hook object | No |
| Nested inside a permission rule entry | No |

Nothing warns. The key is simply gone from the file afterwards.

**Measured:** 19 hooks seeded with a `_keep` marker key, one
`claude plugin disable`, 0 markers left.

`claude doctor` does not surface this. It only reads settings, so a clean
`doctor` run proves the schema tolerates the key — never that a rewrite
preserves it.

## The command string survives, and it goes through a shell

The hook `command` string itself is preserved verbatim across the rewrite, and
hook commands are executed through a shell. Two consequences:

- A trailing `# comment` in the command survives the rewrite **and** never
  reaches the hook program: a probe hook whose command ended in `# KEEP:`
  reported `argc=0`.
- A dummy positional argument would survive the rewrite equally well, but does
  land in the hook program's `argv` — where a real hook that parses arguments
  (Codex's `observe-hook.py`, for instance) then sees it.

So per-hook metadata that must outlive a rewrite goes in the command string, as
a shell comment.

## Who relies on this

`openshell-sandbox`'s `scripts/strip-settings.py` strips every hook from the
copy of `settings.json` staged for a sandbox unless the hook's command carries
a `# KEEP` comment. That marker is the only reason any hook — including the
no-op hooks that gate OTEL emission — reaches a sandbox at all. Retention is
declared where the hook is defined, so the stripper needs no per-hook list.

## Sources

Measured during `openshell-sandbox` work; recorded in that repo's
`scripts/strip-settings.py` and `CLAUDE.md`, with the marker tests in
`my-claude-stuff/tests/test_settings_fragments.py` and
`my-codex-stuff/tests/test_hooks.py`.
