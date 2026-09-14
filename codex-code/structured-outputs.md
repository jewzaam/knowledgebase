# Codex Structured Outputs

What JSON Schema `codex exec --output-schema` actually accepts, why a
rejection is catastrophic rather than degraded, and how to adapt an existing
schema without losing the validation it was expressing. Verified against
codex 0.154.0 (`@openai/codex` npm package) and OpenAI's structured-outputs
documentation, read September 2026.

## The rejection comes from the API, not Codex

`codex exec --output-schema <path>` passes the schema through to the OpenAI
Responses API as a strict structured-output format. Codex does not validate
the schema locally: the string `invalid_json_schema` does not appear anywhere
in the codex 0.154.0 linux-musl binary, so a rejection is the API's error, not
a Codex-side check.

That places the failure before the agent runs — the whole turn is lost, not
just the output. A pipeline that treats a failed agent stage as graceful
degradation will silently ship whatever that stage was supposed to check. This
was observed in a review pipeline that dispatches agents through both
`claude -p` and `codex exec`: a verdict schema with nested `allOf` +
`if`/`then`/`not` conditionals made the API reject every validator request,
the pipeline handled the failure "gracefully", and the run completed and
reported its findings — with nothing having adversarially checked them.
Nested composition is the trap: an adapter that only guards against
root-level composition (which is what Anthropic's API rejects, see below)
passes a schema like this straight through.

## Supported subset

From [OpenAI's structured-outputs guide](https://platform.openai.com/docs/guides/structured-outputs),
read 2026-09-14:

- Types: `string`, `number`, `boolean`, `integer`, `object`, `array`, `enum`,
  `anyOf`.
- Strings: `pattern`, `format` (`date-time`, `time`, `date`, `duration`,
  `email`, `hostname`, `ipv4`, `ipv6`, `uuid`).
- Numbers: `multipleOf`, `maximum`, `exclusiveMaximum`, `minimum`,
  `exclusiveMinimum`.
- Arrays: `minItems`, `maxItems`.
- Recursive schemas are supported, both `$ref: "#"` and explicit recursion.
- Output keys are produced in the schema's key order.

## Explicitly not supported

- Composition and conditionals: `allOf`, `not`, `dependentRequired`,
  `dependentSchemas`, `if`, `then`, `else` — all named by the docs as
  unsupported. `oneOf` is absent from the supported-types list, so treat it as
  rejected too. `anyOf` is the only composition keyword that works.
- `minLength` / `maxLength` are never named in the supported-string list. The
  docs name them only under "for fine-tuned models we additionally do not
  support," which is ambiguous — the safe read is to strip them. The same
  reasoning applies to `minProperties`/`maxProperties`, `patternProperties`,
  `propertyNames`, `uniqueItems`, `contains`, and the `unevaluated*` keywords.
- For fine-tuned models specifically, the docs drop more: strings
  `minLength`/`maxLength`/`pattern`/`format`; numbers
  `minimum`/`maximum`/`multipleOf`; objects `patternProperties`; arrays
  `minItems`/`maxItems`.

## Structural rules

- The root must be an object and must not be `anyOf` — a Zod discriminated
  union produces exactly that shape and fails.
- Every key under `properties` must appear in `required`, recursively, on
  every nested object. There are no optional fields.
- `additionalProperties: false` must be set on every object.

## Size limits

- Up to 5000 object properties total, up to 10 levels of nesting.
- Total string length of all property names, definition names, enum values,
  and const values: 120,000 characters.
- Up to 1000 enum values across all enum properties; a single string enum
  with more than 250 values caps at 15,000 characters of enum text.

## Adapting a schema without losing validation

Three transformations make a typical schema acceptable:

1. Delete the unsupported keywords.
2. Force every property into `required`, and widen the genuinely-optional
   ones to `anyOf: [<original schema>, {"type": "null"}]`. Strip the nulls
   back out of the response before consuming it.
3. Close every object with `additionalProperties: false`.

Deleting a keyword does not have to mean losing the constraint it expressed.
Keep the unmodified source schema and re-validate the agent's result against
it locally, with retries — the constraint then holds after generation instead
of during it. This matters most for the conditionals: a `remove` verdict that
requires a `remove_reason`, or a `rescore` that requires new values, is
expressible as `allOf` + `if`/`then` for Anthropic but has to survive as a
local check for OpenAI.

Guard the adapter with a test that walks the adapted schema and asserts none
of the unsupported keywords survive, for every schema the code sends. The
failure this prevents is not a bad result but a missing pipeline stage.

## Contrast with Claude Code

Anthropic's `--json-schema` and the Workflow tool's `agent(schema:)` sit close
to the inverse of this subset. They accept `if`/`then`/`else`, `not`, nested
`allOf`, `minLength`, `maxLength`, `minProperties`, `pattern`, and the numeric
bounds, and do not support recursive schemas; they reject only
`allOf`/`anyOf`/`oneOf` at the schema root. See
[claude-code/workflow-structured-output.md](https://github.com/jewzaam/knowledgebase/blob/main/claude-code/workflow-structured-output.md)
for the tested support matrix on that side. Schemas written for one harness
are not portable to the other without an adapter — nested composition that
Anthropic accepts is exactly what OpenAI rejects.

## Reproducing this

`/usr/bin/codex` is a Node shim. The real Rust binary lives at
`@openai/codex/node_modules/@openai/codex-<platform>/vendor/<target-triple>/bin/codex`
(for example, `x86_64-unknown-linux-musl`). Grepping that binary for an error
string is how to establish whether a rejection is local to the CLI or came
back from the API:

```bash
strings @openai/codex/node_modules/@openai/codex-linux-musl-x64/vendor/x86_64-unknown-linux-musl/bin/codex \
  | grep invalid_json_schema
```

No match in 0.154.0 — the string is absent, confirming the API is the source
of the error.

## Verified against

- codex 0.154.0 (`@openai/codex` npm package).
- [OpenAI structured-outputs documentation](https://platform.openai.com/docs/guides/structured-outputs),
  read 2026-09-14.

See [codex-code/skills-and-plugins.md](skills-and-plugins.md) for
`--output-schema` invocation and its open defects (resume incompatibility,
MCP-context interference, intermediate messages matching the schema).
