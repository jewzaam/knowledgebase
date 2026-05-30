# GHCR: Auth Model and Quirks

Discovered facts about GitHub Container Registry authentication, package
linkage, and first-publish visibility behavior.

> Prescriptive rules (which token to use when, OCI label requirement, push
> recipes) live in
> [standards/build/ghcr-publish.md](https://github.com/jewzaam/standards/blob/main/build/ghcr-publish.md).

## Fine-grained PATs do not support GHCR

The fine-grained PAT permission set has no Packages scope. Verified against
[GitHub's "Permissions required for fine-grained personal access tokens"](https://docs.github.com/en/rest/authentication/permissions-required-for-fine-grained-personal-access-tokens)
on 2026-05-24 — the document contains no Packages permission. The community
feature request has been open since 2022 at
[github/community discussion #36441](https://github.com/orgs/community/discussions/36441).
Portainer's March 2026 documentation states plainly that "GitHub does not
currently support the use of fine-grained tokens for registry access".

The failure mode is silent: the fine-grained UI simply does not surface a
Packages toggle, so people hunt for it for roughly an hour before concluding
it does not exist.

## Classic PAT scoping limitations

Classic PATs cannot be scoped to a single repository or package. The token
can push to any user-owned package. This is a known limitation of the legacy
PAT model and is unlikely to change. Pair with shortest viable expiry.

## `GITHUB_TOKEN` is per-run, per-repo scoped

`GITHUB_TOKEN` is minted per workflow run, scoped to the running workflow's
repository, and disappears when the run ends. No long-lived credential to
rotate. The workflow YAML must declare the package write permission
explicitly — `GITHUB_TOKEN` defaults to read-only for packages.

## Package-to-repo linkage via OCI label

On first push, GHCR reads the `org.opencontainers.image.source` LABEL from
the image and links the package to the repository indicated by the label.
The package then appears in the repo's Packages sidebar and becomes eligible
for provenance attestation.

Without the label, the package is orphaned at the account level —
discoverable only by typing the full URL. The linkage is impossible to add
later without re-publishing the image.

## First publish defaults to private

GHCR's default visibility is private. For open-source images, this means
`docker pull` returns 401 until the visibility is changed. The flip is a
one-time, per-package, click-through action via the package's web UI:
Package Settings → Change visibility → Public. No API or workflow flag
flips it.

## Provenance

Surfaced while building
[claude-quota-exporter](https://github.com/jewzaam/claude-quota-exporter)
— added a Makefile push-image target and walked the operator through the
fine-grained-token dead-end before landing on classic PAT for the manual
path.
