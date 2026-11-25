# Git Worktrees

Observed with git 2.56.1 on Windows while building an agent work board.

- A branch checked out in one worktree cannot be checked out in another.
  `git worktree add ../w3 card-01` and `git -C ../w2 checkout card-01` both fail
  with `fatal: 'card-01' is already used by worktree at '<path of the first worktree>'`.
- Worktrees are isolated: an edit in one is not visible in another, and
  `git status` in the other stays clean.
- `git worktree remove <path>` on a worktree with modified or untracked files is
  refused: `fatal: '<path>' contains modified or untracked files, use --force to
  delete it` (exit code 128). With `--force` it succeeds (exit 0).
