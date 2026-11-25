# Restricting Where a Headless Session Can Write

Which mechanisms actually stop a headless session writing outside an allowed
area. Observed while building an agent work board on Windows, Claude Code
headless sessions (`-p`, bypass permissions), haiku model, single runs.

## PreToolUse hook via `--settings` (observed)

- A hook defined in a file passed with `--settings <file>` runs in `-p` bypass
  mode and inherits the environment of the launching process (so a role or
  allowed-directory variable set by the launcher reaches the hook).
- The hook gets JSON on stdin: `tool_name`, `tool_input.file_path` or
  `tool_input.command`, `cwd`. Relative paths must be resolved against `cwd`.
- Deny by `exit 2` plus stderr text, or by JSON
  `{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason}}`.
  Both block the call and the model sees the reason. The model saw
  `PreToolUse:Write hook error: ["node.exe" guard.js]: <stderr>` for exit 2 and
  `PreToolUse:Write hook error: <reason>` for JSON deny (the cleaner of the two).
- Path-prefix check with `path.resolve` (not realpath): symlink or junction
  escape from inside the allowed directory was NOT tested (UNVERIFIED).

## Where it leaks (observed)

| Mechanism | Result |
|---|---|
| Edit/Write matcher only | `echo x > ../other.txt` through Bash succeeded |
| Bash denylist (regex for `>`, tee, sed -i, cp, mv, rm, Out-File, Set-Content) | blocked the redirect; a `node -e` one-liner calling `fs.writeFileSync` wrote the file |
| Bash strict allowlist (ls, pwd, cat file, git status/log/diff/show; no shell metacharacters) | held: the node one-liner was blocked, `ls` allowed |
| `--disallowedTools "Edit Write"` under bypass mode | Write answered "No such tool available ... disabled for this session, in subagents as well as here"; Bash still wrote the file |

A denylist over Bash commands is unreliable (node, python, PowerShell
one-liners, here-docs, `git checkout`, `git apply`). An allowlist, or no Bash
at all (`--disallowedTools Bash`), is the form that held. Treat all of this as
a guard against mistakes, not a security boundary.

## Not tested (UNVERIFIED)

- Whether sub-agents spawned by the restricted session inherit the
  `--settings` hooks (the Write-disabled message mentions sub-agents, but hook
  inheritance was not tested).
- MCP tools alongside `--strict-mcp-config`.
- The interactive (non `-p`) mode.
- Behavior with the user's global hooks removed.
