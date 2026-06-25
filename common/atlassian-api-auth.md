# Atlassian API Authentication

Verified: 2026-06-24
Provenance: <https://github.com/jewzaam/openshell-sandbox>

Token types, scoping, URL routing, and authentication gotchas for Atlassian APIs (Jira, Confluence).

## Token Types

Atlassian offers two kinds of API tokens. They serve different purposes and work against different endpoints:

1. **Scoped API tokens** — created at `id.atlassian.com/manage-profile/security/api-tokens`. Used for Jira and Confluence REST APIs. Support fine-grained scopes like `read:jira-work`, `read:confluence-content`. Work only with Basic auth (`email:token`) against the gateway URL (`https://api.atlassian.com/ex/jira/{cloudId}/rest/api/...`).

2. **Admin API keys** — created at `admin.atlassian.com` (Settings > API keys). Used for organization administration APIs only: user provisioning, SCIM, data classification, security policies. Cannot access Jira or Confluence REST APIs regardless of scopes selected. The `read:jira-work` scope on an admin key is misleading — it covers Jira-related org settings, not Jira issue access.

## URL Routing

Atlassian APIs can be accessed via two URL patterns. Scoped API tokens only work with one of them:

- **Gateway URL** — `https://api.atlassian.com/ex/jira/{cloudId}/rest/api/...` (Jira) or `https://api.atlassian.com/ex/confluence/{cloudId}/rest/api/...` (Confluence). Required for scoped API tokens. Works with both scoped and unscoped tokens.

- **Tenant URL** — `https://<site>.atlassian.net/rest/api/...`. Works only with unscoped tokens. Scoped tokens return `404 "Issue does not exist or you do not have permission to see it."` when used against tenant URLs, even with valid scopes and credentials.

The `cloudId` needed for gateway URLs can be retrieved from `https://<site>.atlassian.net/_edge/tenant_info` (no authentication required). The response JSON contains a `cloudId` field.

## Authentication Methods

Scoped API tokens work only with Basic auth. Bearer auth fails with 404 against gateway URLs.

Example Basic auth header:

```bash
echo -n "user@example.com:scoped_token_here" | base64
# Returns: dXNlckBleGFtcGxlLmNvbTpzY29wZWRfdG9rZW5faGVyZQ==

curl -H "Authorization: Basic dXNlckBleGFtcGxlLmNvbTpzY29wZWRfdG9rZW5faGVyZQ==" \
  https://api.atlassian.com/ex/jira/{cloudId}/rest/api/3/issue/PROJ-123
```

Bearer auth does not work with scoped tokens regardless of URL:

```bash
# FAILS with 404
curl -H "Authorization: Bearer scoped_token_here" \
  https://api.atlassian.com/ex/jira/{cloudId}/rest/api/3/issue/PROJ-123
```

## Classic Scopes for Read-Only Access

Two classic scopes cover all read-only Jira access:

- `read:jira-work` — issues, projects, boards, search, attachments, worklogs
- `read:jira-user` — user profiles

Granular scopes like `read:issue:jira`, `read:project:jira` are available for finer restriction, but classic scopes are simpler and cover the common case.

## Network Policy Granularity

OpenShell network policy operates at host+port level only. No URL path filtering, no HTTP verb filtering. The L7 CONNECT proxy establishes a TLS tunnel; once up, it cannot inspect HTTP methods or paths inside the tunnel. The `access` field (`read-only`, `full`) is OpenShell's own access tier, not HTTP GET vs POST filtering.

To restrict Jira access to read-only operations at the application layer, use scoped tokens with read-only scopes. The network policy can only allow or deny the entire `api.atlassian.com:443` endpoint.
