# Claude Code Model Restrictions

How Claude Code (2.1.322) constrains model selection: the `availableModels`
allowlist, the `deniedModels` denylist, `enforceAvailableModels`, the picker's
Default row, selection precedence, and gateway model discovery. The observable
theme is that a `model` setting is a starting point while the allowlist,
denylist, and enforcement flag decide what can actually be selected at runtime.

## `availableModels` is an allowlist

`availableModels` is readable from user, project, local, and managed settings.
When non-empty it blocks a model from:

- the `/model` picker
- `/model <name>`
- the `--model` CLI flag
- the `model` setting
- subagent `model` configuration
- gateway-discovered models (discovery adds only models the allowlist permits)

Entries are family aliases (`sonnet`, `opus`, `haiku`, `fable`), version
prefixes, or full model IDs. Default matching is prefix matching. A specific
version entry disables that family's wildcard — listing `opus-4-6` removes the
`opus` catch-all rather than adding to it.

There is no all-Anthropic wildcard, and no documented slash-prefix matching for
gateway IDs such as `rits/...`.

## `deniedModels` is managed-only

`deniedModels` is a real denylist but is honored only from managed settings. In
user, project, local, or `--settings` it is ignored with a warning. Requires
v2.1.283 or later. `best`, `opusplan`, and `default` are ignored as entries.

## `enforceAvailableModels` has conflicting documented scope

Default `false`. The settings reference lists its scope as "Any file", while
the model page describes it as a managed-settings control. When any managed
settings are deployed, the key is read from managed settings alone.

The flag remaps the picker's Default option only when `availableModels` is
non-empty and at least one entry resolves to a model that is both allowed and
available. Otherwise enforcement is skipped with a warning that is visible only
under `--debug`.

With `enforceAvailableModels: true`, `ANTHROPIC_DEFAULT_MODEL` is documented as
ignored.

## The Default picker row is a special value, not a model alias

Default is not an alias for a family. For the Anthropic API and for any gateway
configured through `ANTHROPIC_BASE_URL`, Default resolves to Opus 5.5. On
Microsoft Foundry it resolves to Sonnet 4.5.

No documented key removes or hides the Default row. `modelPicker.replaceBuiltInOptions: true`
shows only the configured rows, Default, and the current model — it keeps
Default. `modelPicker` itself only controls rows and labels.

## The `model` setting is an initial selection, not enforcement

`model` chooses what the session starts on. A user can still open `/model` and
pick Default, which resolves to the runtime default unless
`enforceAvailableModels` or the denylist applies.

## Selection precedence

| Rank | Source |
|---|---|
| 1 | `/model` |
| 2 | `--model` |
| 3 | `ANTHROPIC_MODEL` |
| 4 | `model` setting |
| 5 | `ANTHROPIC_DEFAULT_MODEL` |

`ANTHROPIC_DEFAULT_MODEL` applies only when no settings file sets `model`.

## Gateway discovery filters on a `claude`/`anthropic` substring

With `CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1`, Claude Code keeps only
discovered IDs whose `id` contains `claude` or `anthropic`, case-insensitive,
anywhere in the string. Provider-prefixed IDs such as
`vertex_ai/claude-sonnet-4-6` pass; IDs such as `rits/zai-org/glm-5-3` are
dropped before any allowlist check. Discovery adds only models the allowlist
permits.

## `modelOverrides` maps Anthropic IDs to provider-form strings

`modelOverrides` maps Anthropic model IDs, used as keys, to provider-form
strings. Keys must be Anthropic IDs — `default` is not a valid key. The picker
label continues to read the Anthropic model name while requests go to the
mapped ID.

## Managed settings location and scope

On Linux, managed settings live at `/etc/claude-code/managed-settings.json`
(root-owned). User scope cannot widen a managed `availableModels` or
`deniedModels` list.

## Not resolved by the documentation

- Whether `enforceAvailableModels` takes effect outside managed settings: the
  settings reference and model page disagree.
- Whether `availableModels` entries match slash-prefixed gateway IDs: no
  pattern form for `rits/...` is documented.
- Whether `deniedModels` also filters gateway-discovered entries: undocumented.

## Sources

Claude Code 2.1.322. Behavior recorded while evaluating model allowlisting for
[my-claude-stuff](https://github.com/jewzaam/my-claude-stuff):

- <https://code.claude.com/docs/en/model-config.md>
- <https://code.claude.com/docs/en/settings-reference.md>
- <https://code.claude.com/docs/en/llm-gateway-protocol.md>
- <https://code.claude.com/docs/en/env-vars.md>
- <https://code.claude.com/docs/en/managed-settings.md>
- <https://code.claude.com/docs/en/errors.md>

Knowledgebase: <https://github.com/jewzaam/knowledgebase>
