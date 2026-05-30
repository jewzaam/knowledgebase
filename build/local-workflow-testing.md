# act: Internals and Security Model

How [act](https://github.com/nektos/act) executes workflows locally, what's
inside the approved runner image, and why its defaults are permissive.

> Prescriptive setup (install recipe, required flags, usage commands, custom
> runner image pattern) lives in
> [standards/build/local-workflow-testing.md](https://github.com/jewzaam/standards/blob/main/build/local-workflow-testing.md).

## How act works

Act parses `.github/workflows/` YAML files, builds an execution plan of
stages (serial) and jobs (parallel), and runs each step inside Docker
containers. Remote actions (e.g., `uses: actions/checkout@v4`) are cloned
from GitHub and executed inside the container. The execution model
intentionally mirrors GitHub's hosted runners.

## Safety assessment

| Use Case | Safe? | Notes |
|----------|-------|-------|
| Local dev with trusted workflows | Yes | You control the workflow content; container isolation is sufficient |
| Testing workflows before pushing to GitHub | Yes | Risks are comparable to GitHub-hosted runners |
| Running untrusted or third-party workflows | No | Docker socket access enables container escape |
| Shared CI/CD infrastructure | No | Multiple users could exploit Docker socket; secret masking is best-effort |

## Approved runner image

[catthehacker/ubuntu](https://github.com/catthehacker/docker_images) provides
purpose-built runner images for act. The Dockerfiles are public and
auditable. Reviewed image: `act-22.04` (reviewed 2026-04-10).

### What the image contains

Built from `ubuntu:22.04` with a single install script
(`linux/ubuntu/scripts/act.sh`):

- **System packages:** ssh, curl, jq, wget, sudo, gnupg, ca-certificates,
  zstd, zip, unzip, python3-pip, python3-venv, pipx
- **Git:** latest from ppa:git-core/ppa, plus git-lfs
- **Docker CLI:** moby-engine, moby-cli, moby-buildx, moby-compose (from
  Microsoft's Ubuntu repo). Inert when `--container-daemon-socket=-` is used
- **Node.js:** versions 20 and 24, downloaded from nodejs.org
- **yq:** from GitHub releases with checksum verification

No services, daemons, cron jobs, or telemetry. Build-time only — the script
installs packages and exits.

### Why pinning by digest matters

Mutable tags (`:latest`, `:act-latest`, `:act-22.04` without digest) can
change underneath the operator. A pinned digest is immutable — what you
audit is what runs.

## Container runtime: Podman rootless vs Docker

| Vector | Docker | Podman rootless |
|--------|--------|-----------------|
| Container escape | Root on host | Unprivileged user (your own UID) |
| Daemon | Runs as root | No daemon — direct fork/exec |
| Socket access | Root-equivalent | User-scoped, no privilege escalation |

With Podman rootless + `--container-daemon-socket=-`, the risk profile is
comparable to running `pip install` in your own terminal. The container
isolation actually makes it *more* constrained than running commands
natively.

## Security risks

Act's defaults are permissive because its goal is fidelity to GitHub's
execution model. GitHub's hosted runners also mount Docker, allow privileged
containers, accept mutable action refs, and use string-replacement secret
masking. Locking these down by default would break workflows that work on
GitHub.

### Docker socket exposure

The Docker socket mount is the primary risk. A workflow step with socket
access can create privileged containers, access host filesystems, or escape
the container entirely. This is equivalent to root on the host.

### Environment variable injection

Workflows can write to `GITHUB_ENV` to set environment variables for
subsequent steps, including `PATH` and `LD_PRELOAD`. The env file parser
accepts multi-line values and buffers up to 1GB. This mirrors real GitHub
Actions behavior. Mitigated by container isolation, but one step can
influence the environment of all subsequent steps.

### Remote action integrity

Actions referenced by tag or branch use mutable Git refs — if the upstream
repo is compromised, malicious code executes. Full commit SHAs are accepted
but not required. No signature verification is performed. This matches
GitHub's own model.

### Secret masking

Secret masking uses string replacement on log output. Secrets can leak
through encoding (base64, hex, URL encoding), case differences, or
structured output that splits values across fields.

## Runner-image differences from GitHub-hosted runners

Workflows that run cleanly on GitHub-hosted `ubuntu-latest` can fail under
act because the runner images are not equivalent.

### `apt-get update` before `apt-get install`

GitHub-hosted `ubuntu-latest` ships with a pre-warmed apt cache, so a naked
`apt-get install -y <pkg>` step works. The `catthehacker/ubuntu` act images
ship with empty or stale `/var/lib/apt/lists/` and fail with `E: Unable to
locate package <pkg>` for everything — even packages in default repos.

### docker compose plugin present, podman binary absent

The act image (`catthehacker/ubuntu:act-22.04`) includes the `docker compose`
plugin (Compose v2) but does **not** include the `podman` binary. Workflows
that pip-install `podman-compose` then invoke it fail with
`FileNotFoundError: 'podman'` because `podman-compose` requires podman as
backend.

## Worktree-support fork

Upstream act fails inside git worktrees because it cannot resolve `.git`
file references. The fork `jewzaam/act` branch `fix/git-worktree-support`
adds reconstitution and a `.git` skip in FileCollector. Upstream PR:
[nektos/act#6075](https://github.com/nektos/act/pull/6075). The fork does
not change the version string or module path, so identifying it requires
either build metadata (`go version -m`) or behavioral testing (running
inside a worktree).

## Limitations

- **Container runtime required** — needs Docker or Podman
- **Not identical to GitHub** — hosted runner tools, OIDC tokens, and
  GitHub-managed secrets are unavailable locally
- **Jobs needing Docker inside containers** will fail with the required
  `--container-daemon-socket=-` flag (testcontainers, compose, etc.)

## Project health

As of April 2026: MIT licensed (fork/modify permitted with copyright
notice), actively maintained, ~35 human contributors. Primary maintainers
are ChristopherHX and Casey Lee (project creator). 40% of commits are
automated dependency bumps (dependabot).
