# Workflow Tool and Structured Output Mechanics

How the Workflow tool's `args` parameter and `agent(schema:)` structured output
mechanism work in practice. Observations from testing with claude-agent-sdk and
Claude Code's internal Workflow executor.

> Authoring conventions for Workflow tool usage live in
> [standards/claude-code/](https://github.com/jewzaam/standards/blob/main/claude-code/)
> (when that doc exists).

## Workflow `args` global is broken

The Workflow tool accepts an `args` parameter that should be exposed as a global
object in the script runtime. **This does not work.** Testing with both inline
`script` and `scriptPath` configurations shows `args` is completely undefined
inside the executed code.

**Observed failure:**

```javascript
// Workflow call with args
Workflow({
  script: "console.log(args.dimensions.length)",
  args: { dimensions: ["x", "y", "z"] }
})

// Runtime error:
// ReferenceError: args is not defined
```

**HTML entity encoding observed:** When inspecting serialized values in error
traces, `args` content appears mangled with HTML entity encoding (`&amp;` for
`&`), suggesting corruption in the args delivery pipeline before it reaches the
script executor.

**Workaround:** Embed all configuration as `const` literals directly in the
script body. Do not rely on the `args` parameter for any production Workflow
calls.

```javascript
// Instead of args, inline everything
Workflow({
  script: `
    const dimensions = ["x", "y", "z"];
    console.log(dimensions.length);
  `
})
```

This is a Claude Code bug, not a usage error. The tool documentation claims
`args` is available, but the runtime doesn't provide it.

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

## Schema constraints: supported vs. unsupported

Not all JSON Schema features work with `StructuredOutput`. Some cause errors at
schema compilation time, some are silently stripped by the SDK, and some are
unsupported by the underlying tool-use mechanism.

### Unsupported (causes 400 error)

- **`pattern` (string regex):** Returns 400 error with message "string patterns
  are not supported". The Anthropic API's tool-use validation does not support
  regex constraints.

- **`if/then/else/not` (conditional schemas):** Undocumented but likely
  unsupported. Avoid conditional logic in schemas intended for
  `StructuredOutput`.

### Silently stripped by SDK (client-side validation only)

These constraints are removed from the schema before sending to the API, so the
model never sees them. However, client-side Ajv validation still enforces them
— if the model violates the constraint, validation fails and triggers a retry.

- `minimum`, `maximum`, `multipleOf` (numeric bounds)
- `minLength`, `maxLength` (string length)
- `minProperties`, `maxProperties` (object size)

The model doesn't know these rules exist, so it can't bias toward satisfying
them — it just gets retry feedback when it guesses wrong.

### Not supported

- **Recursive schemas:** Schemas with `$ref` cycles or unbounded nesting are
  not supported.

### Complexity limits

Large schemas (~50+ properties, ~8KB serialized) can trigger "compiled grammar
is too large" errors. The Anthropic API compiles the schema into a constrained
grammar for tool-use validation. This grammar has a state-space explosion
problem with optional parameters — each optional field roughly doubles the
grammar size.

**Timeout:** Schema compilation has a 180-second server-side timeout. Complex
schemas can hit this and fail the request.

**Mitigation:** Keep schemas small. Use `required` for most fields to reduce
optional combinatorics. Split large output shapes across multiple
`agent(schema:)` calls if needed.

## Verified against

- claude-agent-sdk==0.1.56
- Claude Code CLI (version not specified in session, behavior observed July 2026)
- Anthropic Messages API (inferred from SDK behavior and error messages)

Cross-reference: [jewzaam-reviews](https://github.com/jewzaam/jewzaam-reviews) (local repo where
failures were discovered).
