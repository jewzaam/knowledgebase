# Codex Skills and Plugins

How Codex discovers skills and plugins, and where the format diverges from
Claude Code's. Verified against OpenAI's Codex docs and the Agent Skills
specification, September 2026.

Codex and Claude Code both consume `SKILL.md` built on the
[open agent skills standard](https://agentskills.io). The directory layouts and
the frontmatter dialects are not the same, and the differences fail quietly
rather than loudly.

## Where Codex finds skills

Codex reads skills from four scopes. None of them is `skills/` at a repo root,
which is where a Claude Code plugin keeps them.

| Scope | Location |
|---|---|
| `REPO` | `.agents/skills` in every directory from CWD up to the repo root |
| `USER` | `$HOME/.agents/skills` |
| `ADMIN` | `/etc/codex/skills` |
| `SYSTEM` | Bundled with Codex by OpenAI |

Codex follows symlinked skill folders when scanning, so a repo that keeps
skills elsewhere can expose them by symlinking into `.agents/skills` rather
than moving them.

Two skills sharing a `name` are not merged — both appear in the selectors.

Disable a skill without deleting it via `~/.codex/config.toml`:

```toml
[[skills.config]]
path = "/path/to/skill/SKILL.md"
enabled = false
```

### The initial-list budget truncates silently

Codex loads every skill's name, description, and file path at startup, capped
at 2% of the model's context window, or 8,000 characters when the window is
unknown. Over that cap it shortens descriptions first, then omits skills
entirely with a warning. Front-load trigger words in `description` — a
description that says when to trigger only in its second half loses that half
first. The cap applies to the initial list only; an activated skill still has
its full `SKILL.md` read.

## Frontmatter: spec, Codex, and Claude Code

The spec requires `name` and `description` and nothing else. `name` must match
the parent directory name, be 1-64 characters, and use only lowercase
alphanumerics and single non-leading, non-trailing hyphens.

| Field | In the spec | Notes |
|---|---|---|
| `name`, `description` | Required | `description` max 1024 chars |
| `license`, `compatibility`, `metadata` | Optional | `metadata` is string→string only |
| `allowed-tools` | Optional, **experimental** | Spec type is a **space-separated string**: `Bash(git:*) Bash(jq:*) Read`. Claude Code's YAML list is its own dialect. |
| `disable-model-invocation` | **Not in the spec** | Codex's equivalent is `policy.allow_implicit_invocation: false` in `agents/openai.yaml` |
| `argument-hint` | **Not in the spec** | Belongs to Claude Code and to deprecated Codex custom prompts |

Unknown frontmatter keys are not an error, so a skill carrying Claude Code's
dialect loads under Codex with those keys inert. `disable-model-invocation:
true` in particular reads as "will not fire implicitly" and does nothing —
under Codex the skill stays implicitly invocable unless `openai.yaml` says
otherwise.

### `!`-injection has no Codex equivalent

Claude Code executes `` !`command` `` in a `SKILL.md` body at load time and
substitutes the output. No such mechanism exists in the Agent Skills spec or in
Codex. The body is Markdown; the backtick line reaches the model as literal
text.

`${CLAUDE_PLUGIN_ROOT}` does not close the gap. Codex sets `PLUGIN_ROOT`,
`PLUGIN_DATA`, `CLAUDE_PLUGIN_ROOT`, and `CLAUDE_PLUGIN_DATA` **only in the
environment of plugin hook commands** — not as interpolation available to a
`SKILL.md` body. A skill that pre-fetches its context by injection has to be
restructured to tell the model to run the script instead.

## Optional Codex metadata

`agents/openai.yaml`, inside the skill directory, is optional and Codex-only:

```yaml
interface:
  display_name: "Optional user-facing name"
  short_description: "Optional user-facing description"
policy:
  allow_implicit_invocation: false
dependencies:
  tools:
    - type: "mcp"
      value: "openaiDeveloperDocs"
      transport: "streamable_http"
      url: "https://developers.openai.com/mcp"
```

## Plugins and marketplaces

Codex has a real plugin and marketplace system — this is not a Claude
Code-only concept. A plugin is a folder with a `.codex-plugin/plugin.json`
manifest; `skills/`, `hooks/`, `assets/`, `.mcp.json`, and `.app.json` sit at
the plugin root, and only `plugin.json` goes inside `.codex-plugin/`. Manifest
paths are `./`-prefixed and relative to the plugin root.

A plugin bundling skills therefore keeps them at `skills/<name>/SKILL.md` —
the Claude Code layout — while a *directly discovered* skill must be under
`.agents/skills`. The two paths are not interchangeable.

Marketplace files, read by the ChatGPT desktop app:

- `$REPO_ROOT/.agents/plugins/marketplace.json`
- `$REPO_ROOT/.claude-plugin/marketplace.json` — **read as legacy-compatible**
- `~/.agents/plugins/marketplace.json`

Installs land in
`~/.codex/plugins/cache/$MARKETPLACE_NAME/$PLUGIN_NAME/$VERSION/` (`$VERSION`
is `local` for local plugins) and are loaded from that cache, not from the
marketplace entry — so editing a plugin in place does nothing until the
install is refreshed. Per-plugin enable state lives in `~/.codex/config.toml`.

CLI marketplace management, which accepts GitHub shorthand:

```bash
codex plugin marketplace add owner/repo
codex plugin marketplace add owner/repo --ref main
codex plugin marketplace add https://github.com/example/plugins.git --sparse .agents/plugins
codex plugin marketplace list
codex plugin marketplace upgrade [marketplace-name]
codex plugin marketplace remove marketplace-name
```

### An unresolvable entry is skipped, not reported

Documented marketplace `source.source` values are `local`, `url`,
`git-subdir`, and `npm`. Claude Code's `"source": "github"` is not among them,
and **Codex skips a plugin entry whose source it cannot resolve instead of
failing the marketplace**. Combined with the legacy `.claude-plugin/` read,
that produces the worst diagnostic shape available: the marketplace file is
found and parsed, and the plugin silently is not there. GitHub shorthand is a
`codex plugin marketplace add` argument form, not a marketplace entry source
type.

Codex-documented entries also always carry `policy.installation` (`AVAILABLE`,
`INSTALLED_BY_DEFAULT`, `NOT_AVAILABLE`), `policy.authentication`, and
`category`, none of which Claude Code requires.

## `codex exec` for headless orchestration

`codex exec` is the seam for driving Codex from a script. Behaviors that differ
from `claude -p`:

- **A git repository is required.** `codex exec` refuses to run outside one
  unless given `--skip-git-repo-check`.
- **Read-only sandbox by default.** `--sandbox workspace-write` to allow edits,
  `--sandbox danger-full-access` for more. `--full-auto` is deprecated.
- `--json` makes stdout a JSONL event stream: `thread.started`, `turn.started`,
  `turn.completed`, `turn.failed`, `item.*`, `error`. Progress goes to stderr;
  without `--json`, stdout carries only the final agent message.
- Session identity is `thread_id`, from the `thread.started` event.
- `--output-schema <path>` takes a JSON Schema **file path**, and the schema
  must set `additionalProperties: false`. Claude Code's `--json-schema` is the
  counterpart.
- `-o` / `--output-last-message <path>` writes the final message to a file and
  still prints it.
- `codex exec resume --last` or `codex exec resume <SESSION_ID>` continues a
  session.
- `--ephemeral` skips persisting session rollout files.
- `CODEX_API_KEY` set inline overrides saved auth for one invocation.
- `--ignore-user-config` skips `$CODEX_HOME/config.toml`; `--ignore-rules`
  skips execpolicy `.rules` files.

### No cost is reported, only tokens

`turn.completed` carries `usage` with `input_tokens`, `cached_input_tokens`,
`output_tokens`, and `reasoning_output_tokens`. There is no equivalent of the
Claude CLI's `total_cost_usd`. Any per-agent budget cap built on a measured
cost has to compute it from a maintained price table, which makes the number an
estimate rather than a measurement.

### Open defects against structured output

- Schema and resume do not compose — `codex exec resume` does not accept
  `--output-schema`
  ([#14343](https://github.com/openai/codex/issues/14343)).
- `--output-schema` can be ignored once MCP servers or tools are in the request
  context ([#15451](https://github.com/openai/codex/issues/15451)).
- Intermediate `agent_message` items are forced into the schema too, so "first
  schema-valid message" is not reliably the final result
  ([#19816](https://github.com/openai/codex/issues/19816)).

## Custom prompts are deprecated

`~/.codex/prompts/*.md` exposed slash commands (`/prompts:<name>`) with
`description` / `argument-hint` frontmatter and `$1`-`$9`, `$ARGUMENTS`, and
`KEY=value` placeholders. Deprecated in favor of skills, and only top-level
`.md` files in that directory were ever scanned. Do not port toward them.

## Invoking a skill

`/skills` opens a picker, so the name is never typed there. Typing `$` mentions
a skill by name in the Codex CLI and IDE extension; ChatGPT uses `@`. Codex
picks up skill changes automatically; restart if an edit does not appear.

**A plugin-bundled skill is namespaced; a standalone one is not.** The
qualifier is the `name` from the plugin's `.codex-plugin/plugin.json`, so the
same `SKILL.md` is `$review` when dropped in `.agents/skills/` and
`$my-plugin:review` when installed as part of `my-plugin`. This mirrors Claude
Code's `/my-plugin:review`. The official docs never state the form — they say
only "the invocation syntax for your surface" — but
[codex#28608](https://github.com/openai/codex/pull/28608) ("use the provided
namespace when qualifying plugin skill names") is explicit, and published
plugins use it: `$coding:replan`, `$security:web-security-review`.

This matters for anything that writes the invocation down — an
`agents/openai.yaml` `default_prompt`, a README, or a skill body that tells the
user how to re-run it. The unqualified form silently stops resolving the moment
the skill ships inside a plugin.

## Sources

- [Build skills](https://developers.openai.com/codex/skills)
- [Package your plugin](https://developers.openai.com/plugins/build/plugins)
- [Non-interactive mode](https://developers.openai.com/codex/noninteractive)
- [Custom prompts (deprecated)](https://developers.openai.com/codex/custom-prompts)
- [Agent Skills specification](https://agentskills.io/specification)
