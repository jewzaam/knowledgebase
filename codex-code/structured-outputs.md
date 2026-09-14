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

### Composition and conditionals: convert to a discriminated union

`anyOf` is the one composition keyword strict mode accepts, and it is legal
anywhere except the schema root. That makes it the target for a schema that
uses `allOf` + `if`/`then`/`not` to express "field X only when field Y
equals Z": rewrite the shared-object-plus-conditionals shape as `anyOf` over
complete variants, one per discriminator value, each pinning the
discriminator with `const` and declaring only its own fields under
`additionalProperties: false`.

This is the correct approach, not a stylistic preference. The structural
rule above — every key under `properties` must appear in `required`,
recursively — makes a presence-based conditional meaningless once a schema
is adapted, not just unsupported: `if action == "rescore" then required:
["new_dimensions"]` is trivially satisfied because `new_dimensions` is
already required unconditionally, and `then: {not: {required:
["remove_reason"]}}` is unsatisfiable for the same reason. There is no way
to express "field X is present only when field Y has value Z" as a
conditional over a single object shape under strict mode — the all-required
rule has already flattened the distinction before `if`/`then` would run.

The union form is also lossless where deleting the conditional and
re-validating locally is not: a `confirm` variant has no `remove_reason`
property at all, so the model cannot emit one — the constraint is enforced
during generation, which is what the conditional was for. Genuinely optional
fields inside one variant still take the `anyOf: [<original schema>,
{"type": "null"}]` widening (strip the nulls back out of the response before
consuming it), and every object, including each variant, still needs
`additionalProperties: false`.

Condensed worked example — a review pipeline's verdict schema, `anyOf`
inside an array's `items`, replacing four `allOf` + `if`/`then`/`not`
conditionals:

```json
"verdicts": {
  "type": "array",
  "items": {
    "anyOf": [
      { "type": "object", "additionalProperties": false,
        "required": ["finding_ref", "action", "reasoning"],
        "properties": { "finding_ref": {...}, "action": {"type": "string", "const": "confirm"},
                        "reasoning": {"type": "string"} } },
      { "type": "object", "additionalProperties": false,
        "required": ["finding_ref", "action", "new_dimensions", "reasoning"],
        "properties": { "finding_ref": {...}, "action": {"type": "string", "const": "rescore"},
                        "new_dimensions": {...}, "reasoning": {"type": "string"} } },
      { "type": "object", "additionalProperties": false,
        "required": ["finding_ref", "action", "remove_reason", "reasoning"],
        "properties": { "finding_ref": {...}, "action": {"type": "string", "const": "remove"},
                        "remove_reason": {"type": "string", "enum": ["not_real", "pre_existing", "positive_observation"]},
                        "reasoning": {"type": "string"} } }
    ]
  }
}
```

Verified exhaustively equivalent to the conditional form it replaced: every
combination of action value and optional-field presence (37 documents across
two schemas) validates identically against the old `allOf`/`if`/`then` form
and the new union, with zero mismatches. Cost was about 700 characters of
schema.

Verified on both harnesses: a nested `anyOf` of `const`-discriminated
variants is also accepted by Anthropic's `claude -p --json-schema` (probed
against the live API with Haiku; it returned a correctly-shaped variant).
The union form is portable across both providers; the conditional form is
not — there is no reason to keep conditionals in a schema that must serve
both.

### Residual: stripping scalar bounds

Once composition is converted to a union, the only unsupported keywords left
to strip are scalar bounds — `minLength`, `maxLength`, `minProperties`, and
the rest of the "explicitly not supported" list above that isn't a
composition keyword. Dropping one of those costs only up-front enforcement
of a bound. Keep the unmodified source schema and re-validate the agent's
result against it locally, with retries — the constraint then holds after
generation instead of during it.

An adapter should refuse to drop a keyword whose value is an object or array
(a subschema) rather than flattening it away. Silently dropping a subschema
hands the agent a contract weaker than the one its output is later judged
against, with nothing reporting the gap — the same silent-weakening failure
this doc describes for the API's own rejection (see above), just relocated
from the provider to the adapter. Raising there turns it into a loud,
attributable error instead of a quiet one.

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
