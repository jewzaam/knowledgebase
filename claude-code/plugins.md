# Claude Code Plugin Internals

Mechanics of plugin caching, environment, marketplace sources, and recurring
failure modes. Discovered behavior — not authoring rules.

> Authoring rules (directory structure, manifest fields, versioning, component
> conventions, permission guidance) live in
> [standards/claude-code/plugins.md](https://github.com/jewzaam/standards/blob/main/claude-code/plugins.md).
>
> Upstream docs:
> [plugins-reference](https://code.claude.com/docs/en/plugins-reference),
> [plugins](https://code.claude.com/docs/en/plugins),
> [plugin-marketplaces](https://code.claude.com/docs/en/plugin-marketplaces).
> If details here conflict, trust the upstream docs.

## Plugin caching

Marketplace plugins are copied to `~/.claude/plugins/cache/`. Each version gets
its own directory. Previous versions are orphaned and removed after 7 days.

Plugins cannot reference files outside their directory — `../` traversal does
not work after installation. Use symlinks for shared files.

When `--plugin-dir` loads a plugin with the same name as an installed
marketplace plugin, the local copy takes precedence for that session.

## Environment variables

| Variable | Description |
|----------|-------------|
| `${CLAUDE_PLUGIN_ROOT}` | Absolute path to plugin install directory. Changes on update — files written here do not survive updates. |
| `${CLAUDE_PLUGIN_DATA}` | Persistent directory for plugin state (deps, caches). Survives updates. Created on first reference. Resolves to `~/.claude/plugins/data/{id}/`. |

Both are substituted inline in skill content, agent content, hook commands,
MCP/LSP server configs, and `allowed-tools` frontmatter patterns. Both are
also exported as environment variables to subprocesses.

### Persistent data pattern

Install dependencies once, reinstall only when manifest changes:

```json
{
  "hooks": {
    "SessionStart": [{
      "hooks": [{
        "type": "command",
        "command": "diff -q \"${CLAUDE_PLUGIN_ROOT}/package.json\" \"${CLAUDE_PLUGIN_DATA}/package.json\" >/dev/null 2>&1 || (cd \"${CLAUDE_PLUGIN_DATA}\" && cp \"${CLAUDE_PLUGIN_ROOT}/package.json\" . && npm install) || rm -f \"${CLAUDE_PLUGIN_DATA}/package.json\""
      }]
    }]
  }
}
```

## Marketplace plugin sources

A marketplace is a git repo with `.claude-plugin/marketplace.json` listing
plugins. Each entry's `source` field selects the install mechanism:

| Source | Type | Required fields |
|--------|------|-----------------|
| Relative path | string (`"./my-plugin"`) | — |
| GitHub | object | `source: "github"`, `repo` |
| Git URL | object | `source: "url"`, `url` |
| Git subdirectory | object | `source: "git-subdir"`, `url`, `path` |
| npm | object | `source: "npm"`, `package` |

All object sources accept optional `ref` (branch/tag) and `sha` (pin to commit).
npm accepts `version` and `registry` instead.

## CLI commands

| Command | Description |
|---------|-------------|
| `claude plugin install <plugin> [-s scope]` | Install from marketplace |
| `claude plugin uninstall <plugin> [-s scope] [--keep-data]` | Remove plugin |
| `claude plugin enable <plugin> [-s scope]` | Enable disabled plugin |
| `claude plugin disable <plugin> [-s scope]` | Disable without uninstalling |
| `claude plugin update <plugin> [-s scope]` | Update to latest version |

## Installation scopes

| Scope | Settings file | Use case |
|-------|---------------|----------|
| `user` | `~/.claude/settings.json` | Personal, all projects (default) |
| `project` | `.claude/settings.json` | Team, committed to VCS |
| `local` | `.claude/settings.local.json` | Project-specific, gitignored |
| `managed` | Managed settings | Read-only, update only |

## User configuration mechanics

`userConfig` values declared in `plugin.json` are prompted at install/enable
time and made available as:

- `${user_config.KEY}` substitution in MCP/LSP configs, hook commands, and
  (non-sensitive only) skill/agent content.
- `CLAUDE_PLUGIN_OPTION_<KEY>` environment variables to subprocesses.

Sensitive values go to the system keychain — ~2 KB total limit shared with
OAuth tokens. Exceeding the budget silently truncates.

## Common failure modes

- **Component directories inside `.claude-plugin/`.** Only `plugin.json` goes
  there. Component dirs (`skills/`, `agents/`, etc.) must be at plugin root.
- **Absolute paths instead of `./`-relative.** Path fields require `./` prefix.
- **Hook scripts missing executable bit.** `chmod +x` required.
- **LSP server binary not installed on the user's machine.** Plugins configure
  the connection but do not bundle the server.
- **Not bumping version after code changes.** Cache serves the same version
  directory, so users do not see new code.
- **Referencing files outside the plugin directory.** Breaks after cache copy
  (no `../` traversal).
- **Marketplace name colliding with plugin name.** The marketplace `name` in
  `marketplace.json` must differ from the plugin `name` in `plugin.json`. When
  they match, the plugin cache directory
  (`~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`) is not created
  on disk — the plugin works in the installing session but fails to load in
  new sessions. Use a distinct marketplace name (e.g., `my-plugin-marketplace`
  for plugin `my-plugin`).

## Plugin-agent restrictions

Plugin-bundled agents cannot declare `hooks`, `mcpServers`, or `permissionMode`
in frontmatter. These are blocked for security. Supported fields: `name`,
`description`, `model`, `effort`, `maxTurns`, `tools`, `disallowedTools`,
`skills`, `memory`, `background`, `isolation` (only `"worktree"`).

## Hook types in plugins

Same event types as user-defined hooks (see
[hook-state-transitions.md](hook-state-transitions.md)). Hook handler types:
`command`, `http`, `prompt`, `agent`.
