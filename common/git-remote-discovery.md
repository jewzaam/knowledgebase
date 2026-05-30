# Git Remote Naming Conventions Are Not Contracts

Why `origin` and `upstream` aren't safe to hardcode in scripts.

> Prescriptive rule (discover by URL match) and the implementation pattern
> live in
> [standards/common/git-remote-discovery.md](https://github.com/jewzaam/standards/blob/main/common/git-remote-discovery.md).

## The problem

`origin` and `upstream` are conventions, not contracts. Developers differ on
which name points where:

- Some set `origin` to their fork and `upstream` to the canonical repo.
- Others set `origin` to the canonical repo and `upstream` to their fork.
- Some have neither name — just a custom remote like `fork` or `canonical`.

A script that hardcodes `git push origin` or `git fetch upstream` works for
the author and breaks silently for everyone else. "Breaks silently" because
the wrong remote may still exist; the command succeeds against the wrong
target and the script keeps going. There is no error to surface, no exit code
to check — the bug shows up later as "wrong branch on the wrong server".
