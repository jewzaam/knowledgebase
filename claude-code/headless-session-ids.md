# Headless Session IDs

`claude -p --session-id <uuid>` starts a headless session with a caller-chosen
id, and `claude -p --resume <uuid>` continues it. Observed while building an
agent work board: recording the uuid against a work item lets a later run
resume the same session instead of starting a new one.

All findings below were observed while building an agent work board on Windows,
with Claude Code headless sessions on the haiku model (single runs, not
repeated; evidence level noted per item).

## Two processes, one session id (observed)

- A second process started with `--session-id X` while X is in use exits 1 with
  `Error: Session ID X is already in use.`
- A second process started with `--resume X` while X is busy in another process
  is NOT refused: it ran a full turn in parallel.
- UNVERIFIED: whether the parallel turn corrupts the shared transcript (both
  processes wrote it; the file was not inspected). Do not rely on `--resume`
  as a lock.

## Resume from another directory (observed)

- `--resume <uuid>` works from the creation directory, an unrelated directory,
  and a git worktree of the same repo. The returned `session_id` stays equal to
  the uuid (no fork).
- The transcript lives at `~/.claude/projects/<creation cwd>/<uuid>.jsonl`, where
  the folder name is the creation cwd with every non-alphanumeric character
  replaced by `-` (`:\` becomes `--`, `_` becomes `-`). Resuming from another
  directory appends to that same file (no second file or folder); the per-message
  `cwd` field changes and tool cwd follows the new launch directory.
- UNVERIFIED: resuming after the creation directory was deleted (for example a
  removed worktree). The transcript is outside that directory so it likely works.

## Kill mid-turn, then resume (observed)

Setup: a background sub-agent and a foreground tool call running, process tree
killed with `taskkill /F /T` after 15 s, then `--resume`.

- The resumed session knows the task, that a sub-agent was launched, and that
  the foreground call was unfinished. It does not know their partial results.
- The transcript gets a synthetic tool result for the dangling call ("Tool call
  interrupted: the session ended before this call's result was recorded, so its
  outcome is unknown"); resume coped. A task notification records the sub-agent
  as stopped.
- `taskkill /F /T` left no orphans: 11 descendants were snapshotted, none alive
  3 s later. The killed work did not continue (the marker file the command would
  have written was absent).
