# Claude Code Skill Mechanics

How `allowed-tools` enforcement actually behaves, how shell injection works
behind the scenes, and other discovered facts about skill execution.

> Authoring rules (frontmatter reference, `allowed-tools` path patterns to use,
> file structure, what to avoid) live in
> [standards/claude-code/skills.md](https://github.com/jewzaam/standards/blob/main/claude-code/skills.md).

## Permission scope and enforcement

`allowed-tools` has a narrow, confirmed scope. Understanding its limits prevents
wasted effort on entries that don't do what you expect.

### What `allowed-tools` enforces

1. **`!` shell injection gating (load-bearing).** When a skill declares
   `allowed-tools`, every `!` command in the skill content is checked against
   the listed patterns. This is the primary reason to declare `allowed-tools` —
   without it, pre-fetch injections that invoke plugin scripts fail. Skills
   that omit `allowed-tools` entirely get unrestricted `!` execution.

2. **Main-agent tool calls (inconsistent enforcement).** The main agent
   running the skill may have its tool calls checked against `allowed-tools`,
   but enforcement is unreliable across Claude Code versions
   ([#14956](https://github.com/anthropics/claude-code/issues/14956),
   [#18837](https://github.com/anthropics/claude-code/issues/18837),
   [#29360](https://github.com/anthropics/claude-code/issues/29360)). Treat
   these entries as documentation of what the skill needs, not as a reliable
   permission grant.

### What `allowed-tools` does NOT enforce

1. **Sub-agent permissions.** `allowed-tools` does not propagate to sub-agents
   dispatched via the Agent tool
   ([#18950](https://github.com/anthropics/claude-code/issues/18950)).
   Sub-agents get their permissions exclusively from global
   (`~/.claude/settings.json`) or project (`.claude/settings.json`) settings.

2. **Post-skill permissions.** `allowed-tools` applies only while the skill
   is active. It does not persist after the skill completes.

### Reliable permission mechanism

Global settings (`~/.claude/settings.json` > `permissions.allow`) and project
settings (`.claude/settings.json` > `permissions.allow`) are the only mechanism
that works across all contexts: pre-fetch injections, main agent, and
sub-agents.

For plugins that bundle scripts, the plugin README should document the
required global permission entries so users can add them once and avoid
per-invocation prompts.

## Shell injection mechanics

Shell injection runs commands **before Claude sees the skill content**. The
output replaces the placeholder inline. This is preprocessing — Claude
receives the rendered result, not the command.

### Inline form

`` !`command` `` — single command output substituted inline.

### Block form

A fenced block opened with `` ```! `` runs each line in sequence and replaces
the block with the combined output.

### Disabling

Set `"disableSkillShellExecution": true` in settings.json. Each command is
replaced with `[shell command execution disabled by policy]`. Only affects
user, project, plugin, and additional-directory skills — bundled (first-party)
skills are not subject to this policy. Managed settings cannot be overridden
by users.

### Why pre-fetch breaks without `allowed-tools` coverage

When a skill has `allowed-tools` set but a `!` command is not covered by any
pattern, the command fails with "Shell command permission check failed."
Skills that mix bundled scripts with `!` injection must list both the
`${CLAUDE_SKILL_DIR}/**` and `${CLAUDE_PLUGIN_ROOT}/**` (or `**`) globs to
cover the resolved invocation. Without these entries, every session prompts
the user before the skill body is even loaded.

## Extended thinking trigger

Include the word `ultrathink` anywhere in skill content to activate extended
thinking mode for the skill's execution. The token is matched by the dispatcher
before the skill content reaches the model.

## String substitutions

These are resolved by the dispatcher, not the model. They appear as literal
text in the rendered skill content the model sees.

| Variable | Description |
|----------|-------------|
| `$ARGUMENTS` | All arguments passed when invoking the skill. If not present in content, arguments are appended as `ARGUMENTS: <value>`. |
| `$ARGUMENTS[N]` | Specific argument by 0-based index (e.g., `$ARGUMENTS[0]`). |
| `$N` | Shorthand for `$ARGUMENTS[N]` (e.g., `$0`, `$1`). |
| `${CLAUDE_SESSION_ID}` | Current session ID. |
| `${CLAUDE_SKILL_DIR}` | Directory containing the skill's `SKILL.md`. Use in shell injection to reference bundled scripts regardless of working directory. |
| `${CLAUDE_PLUGIN_ROOT}` | Plugin install directory. Available only for plugin-packaged skills. Works in skill content, `allowed-tools`, and `!` commands. |
| `${CLAUDE_PLUGIN_DATA}` | Persistent plugin data directory (survives updates). Available only for plugin-packaged skills. |

## Frontmatter is silently ignored on typos

Invalid frontmatter fields are silently dropped, not flagged. Typos like
`disable-model-invocaton` (missing `i`) are no-ops with no warning. Triple-
check field names against the
[standards reference](https://github.com/jewzaam/standards/blob/main/claude-code/skills.md#frontmatter)
before debugging behavior that "should work."

## Description truncation

Skill `description` fields are truncated at 250 characters in the `/` menu and
in listing displays. Front-load the key use case in the first sentence.
