# Anthropic OAuth Tokens: Token vs. Endpoint Reference

> Anthropic ships multiple OAuth-derived token types that share the
> `sk-ant-` prefix family but carry different scopes. The same prefix
> does **not** imply the same capability. Pick the token by the flow
> that produced it, not by string match on the prefix.
>
> Surfaced while building
> [claude-quota-exporter](https://github.com/jewzaam/claude-quota-exporter),
> which consumes `GET /api/oauth/usage` and went through several
> wrong-token-type attempts before settling on the requirements below.

## Token taxonomy

| Prefix | Type | Source flow | Lifetime | Verification |
|---|---|---|---|---|
| `sk-ant-oat01-` | OAuth access token (PKCE flow) | Interactive `claude login` / PKCE authorization-code exchange | ~8h (`expires_in: 28800` verified) | Verified 2026-05-24 via refresh-grant response payload |
| `sk-ant-oat01-` | OAuth access token (long-lived bearer) | `claude setup-token` CLI command | ~1 year | Verified 2026-05-24 via `claude setup-token` output |
| `sk-ant-ort01-` | OAuth refresh token | PKCE flow + refresh-grant rotation | Long-lived; rotates per refresh response | From community write-ups — invalidation policy unverified this session |
| `sk-ant-api03-` | Console API key | Anthropic Console UI | Operator-controlled | From community write-ups — not used this session |

**Key point**: the two `sk-ant-oat01-` variants are indistinguishable by
prefix or by RFC 6749 token format. They differ only in the OAuth scopes
the issuing server stamped onto them. A bearer that works for one
Anthropic endpoint can return 403 on another.

## Endpoint compatibility

| Endpoint | Required token | Verified behaviour with other tokens |
|---|---|---|
| `GET https://api.anthropic.com/api/oauth/usage` | PKCE-flow access token (needs `user:profile` scope) | `claude setup-token` output → `403 Forbidden` (verified 2026-05-24 via `curl -D -` dump) |
| `POST https://console.anthropic.com/v1/oauth/token` (also `platform.claude.com`) | Refresh token (`sk-ant-ort01-`) + public `client_id` | Returns `access_token`, `refresh_token`, `expires_in: 28800` (verified). Aggressively rate-limited (see quirks). |
| `POST https://api.anthropic.com/v1/messages` | `claude setup-token` bearer via `CLAUDE_CODE_OAUTH_TOKEN` env var, or Console API key | This is what `claude setup-token` was designed for |

When to apply: any time code or docs imply "an Anthropic OAuth token"
without specifying the source flow, treat that as a defect and pin down
which of the two `oat01-` variants is required. The wrong choice fails
with a 403 that gives no hint about which scope is missing.

## Anthropic-specific OAuth quirks

### Error envelopes are Anthropic-nested, not RFC 6749 flat

RFC 6749 §5.2 specifies a flat error envelope:

```json
{"error": "invalid_grant", "error_description": "..."}
```

Anthropic's OAuth endpoints return the Anthropic API envelope instead:

```json
{"error": {"type": "rate_limit_error", "message": "..."}}
```

Code that parses OAuth errors must read `body.error.type`, not
`body.error`. A generic RFC-6749 parser will surface
`{"type": "...", "message": "..."}` as the error code string, which is
useless for branching.

### `POST /v1/oauth/token` 429 includes no `Retry-After`

Verified 2026-05-24: the refresh grant rate-limits aggressively and the
429 response omits `Retry-After`. Operators cannot probe "is the limit
cleared" without either:

1. Burning real-token budget on a real refresh attempt (which extends
   the lockout if it fails), or
2. Sending probes that may hit a different rate-limit bucket and return
   a false-positive "all clear."

Design implication: any retry layer for the refresh grant must use an
exponential-backoff schedule with conservative caps, not a header-driven
schedule.

### `expiresAt` in `.credentials.json` is ms-since-epoch

The Claude Code CLI persists token expiry in `~/.claude/.credentials.json`
as **milliseconds** since the Unix epoch, not seconds. This is a
Claude-Code-specific convention, not a standard OAuth field. Code that
compares against `time.time()` (seconds) without dividing by 1000 will
treat valid tokens as expired ~1970 years in the future and skip
refresh entirely.

### Public `client_id` is a shared UUID

The OAuth `client_id` for the Claude Code public client is:

```text
9d1c250a-e61b-44d9-88ed-5944d1962f5e
```

Same value worldwide, baked into every Claude Code install. Required in
the body of every `refresh_token` grant per RFC 6749's public-client
model (no `client_secret`). This is not a per-user identifier and not
sensitive — it's the OAuth equivalent of a published app identifier.

## Kubernetes deployment quirk (cross-cutting)

This is not Anthropic-specific but bites every service that consumes
OAuth credentials from a Kubernetes Secret mount.

**K8s Secret volume mounts are tmpfs projections regenerated from the
Secret object on every Pod restart.** Container-side writes to a
mounted credentials file persist only for the Pod's lifetime. The Pod
is rescheduled (node drain, eviction, deploy, OOM kill) → the next
Pod starts with a fresh tmpfs copy of whatever the Secret object still
contains.

Token-rotation designs that depend on in-container write-back surviving
Pod restart are broken in vanilla Kubernetes. Refresh-rotated tokens
written to the mounted credentials file will be **lost** on the next
reschedule, and the next refresh attempt will use the now-stale
refresh token from the Secret.

Mitigations, in increasing order of operational complexity:

1. **Accept the loss**: surface a writability gauge (e.g.
   `claude_quota_credentials_writable`), latch it to `0` on the first
   failed write-back, and alert operators to refresh the Secret manually
   before the long-lived bearer expires. Suitable when refresh is rare
   (long-lived `setup-token` bearers, ~1 year).
2. **External secret operator**: use a controller (External Secrets
   Operator, Vault Agent, etc.) that owns the Secret object and
   propagates rotated tokens back to the source of truth.
3. **Persistent volume for credentials**: trade tmpfs for a PVC. Costs
   you the "Secret" semantics in `kubectl get` and complicates RBAC.

Document this trade-off at deployment-design time for any service
consuming credentials from a Secret-mounted file. Do not silently
assume in-container writes persist.

## Rationale

The 403 on `/api/oauth/usage` with a `claude setup-token` bearer is the
most surprising failure mode here, because nothing in the token, the
endpoint URL, or the CLI documentation hints that the two flows produce
different-scope tokens. Capturing this explicitly avoids the multi-hour
exploration cycle that produced this document.

The error-envelope and missing-`Retry-After` notes are necessary for
anyone writing a refresh layer: a strict RFC 6749 implementation will
silently mishandle every error response Anthropic returns, and a
header-driven retry layer will busy-loop into a deeper lockout.

The K8s tmpfs note is included here rather than in `kubernetes/` because
the failure mode only matters for credential-consuming services and is
nearly always discovered in the context of OAuth token rotation. A
reader looking up "how do Claude tokens work in a Pod" will land here
first; placing the deployment quirk in the same file shortens that path.

## Provenance

- All verified-2026-05-24 claims were observed while debugging the
  exporter referenced above against the live Anthropic OAuth endpoints.
- Community-sourced claims (`sk-ant-ort01-`, `sk-ant-api03-`) are marked
  inline and not relied upon for design decisions in this document.
- `client_id` value was extracted from the refresh-grant request body
  the Claude Code CLI itself sends.
