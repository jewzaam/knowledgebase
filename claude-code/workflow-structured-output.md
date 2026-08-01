# Workflow Tool and Structured Output Mechanics

How the Workflow tool's `args` parameter and `agent(schema:)` structured output
mechanism work in practice. Observations from testing with claude-agent-sdk and
Claude Code's internal Workflow executor.

> Authoring conventions for Workflow tool usage live in
> [standards/claude-code/](https://github.com/jewzaam/standards/blob/main/claude-code/)
> (when that doc exists).

## Workflow `args` is double-serialized

The Workflow tool serializes `args` as a **JSON string**, not a native object.
`typeof args === "string"`. Direct property access (`args.dimensions`) fails
with `undefined` because you're reading a property of a string.

**Fix:** `JSON.parse(args)` at the top of the script recovers the original object.

```javascript
const config = JSON.parse(args)
console.log(config.dimensions.length)  // works
```

Earlier observations that `args` was "completely undefined" were caused by
treating the string as an object — `"string".dimensions` is `undefined`, not a
`ReferenceError`. The `args` global IS available; its value is a JSON string.

**HTML entity encoding:** Enum values containing `&` (e.g., `Architecture & Design`)
get entity-encoded to `&amp;` during serialization. Avoid `&` in values passed
through args. Use `and` instead.

## `agent(schema:)` mechanism

The Workflow `agent(prompt, {schema: ...})` and Agent SDK
`client.query(prompt, {schema: ...})` parameter wraps the provided JSON schema
as a synthetic tool named `StructuredOutput`. The model must "call" this tool
with schema-valid arguments to complete the turn.

### How it works

1. **Tool synthesis:** The schema is wrapped as a tool definition. Tool name is
   always `StructuredOutput`. The schema becomes the tool's input schema.

2. **Constrained generation:** The model generates a response and must invoke
   `StructuredOutput` with arguments matching the schema. This is NOT
   constrained decoding (like the Messages API `response_format`). The model
   can fail to call the tool or call it with invalid data.

3. **Validation:** When the model calls `StructuredOutput`, arguments are
   validated client-side using [Ajv](https://ajv.js.org/). If validation fails,
   the error is fed back to the model with a retry prompt.

4. **Retry loop:** The model gets up to 5 attempts to produce valid output
   (configurable via `MAX_STRUCTURED_OUTPUT_RETRIES` env var). Each validation
   failure triggers a new turn with the Ajv error message.

5. **Stop hook enforcement:** A Stop hook with a 5-second timeout ensures the
   model calls `StructuredOutput` exactly once per turn. Multiple invocations
   or skipping the tool triggers the hook.

6. **Tool inheritance filter:** `StructuredOutput` is filtered from the child
   agent's `subtools` to prevent it from being inherited by nested agents
   spawned with the Agent tool.

### Ajv validator caching

Ajv validators are cached by schema object reference. First validation for a
schema takes ~110ms; subsequent validations with the same schema object drop to
~4ms. If you're calling `agent(schema:)` in a loop, reuse the schema object —
don't reconstruct it each iteration.

### Availability

- **Workflow scripts:** `agent(prompt, {schema: ...})` works.
- **Agent SDK:** `client.query(prompt, {schema: ...})` works.
- **Agent tool:** NOT available. GitHub issue
  [#20625](https://github.com/anthropics/claude-code/issues/20625) requested
  this, closed as stale with no Anthropic response. To use structured output
  from a skill or main-thread agent, dispatch a Workflow or use the Agent SDK
  directly.

## Schema constraints: tested support matrix

All constraints tested July 2026 via Workflow `agent(schema:)` with Haiku and
Sonnet models. Results contradict earlier documentation that claimed many
constraints were unsupported.

### Supported (tested, confirmed working)

| Constraint | Notes |
|---|---|
| `pattern` | Regex on strings. Works. Earlier claim of 400 error was wrong. |
| `minLength` / `maxLength` | String length bounds. Works. |
| `minimum` / `maximum` | Numeric bounds. Works. |
| `minProperties` | Object size minimum. Works. |
| `if` / `then` / `else` | Conditional schemas. Works at root and nested. |
| `not` | Negation. Works (tested nested inside `allOf` inside array items). |
| `allOf` (nested) | Works inside properties and array items. |
| `enum` | Primitive values only. Works. |
| `const` | Works. |
| `additionalProperties: false` | Works and recommended. |
| `required` | Works. |
| `$ref` / `$defs` | Internal references only (no external URLs). Works. |

### Unsupported (causes 400 error)

| Constraint | Error | Notes |
|---|---|---|
| `allOf` at schema root | `input_schema does not support oneOf, allOf, or anyOf at the top level` | Move composition inside a property or array items. |
| `anyOf` at schema root | Same 400 error | Same workaround. |
| `oneOf` at schema root | Same 400 error | Same workaround. |
| Recursive schemas | Not supported | Schemas with `$ref` cycles. |

### Not tested

- `multipleOf` (numeric)
- `maxProperties`
- Complex array constraints (`maxItems`, `uniqueItems`)
- `format` keyword enforcement
- Schemas exceeding ~50 properties / ~8KB

### Complexity limits

Large schemas (~50+ properties, ~8KB serialized) may trigger "compiled grammar
is too large" errors. Each optional parameter roughly doubles grammar state
space. 180-second server-side compilation timeout.

**Mitigation:** Use `required` for most fields to reduce optional combinatorics.

## Verified against

- claude-agent-sdk==0.1.56
- Claude Code CLI (version not specified in session, behavior observed July 2026)
- Anthropic Messages API (inferred from SDK behavior and error messages)

Cross-reference: [jewzaam-reviews](https://github.com/jewzaam/jewzaam-reviews) (local repo where
failures were discovered).
