# VS Code Window Detection via GNOME `window-calls`

Querying GNOME Shell's `window-calls` extension for VS Code windows (to map
editor windows and integrated terminals to projects) surfaces several
non-obvious facts about what the extension reports and what it cannot.

## `wm_class` is `com.microsoft.VSCode`, not `code`

VS Code windows report both `wm_class` and `wm_class_instance` as
`com.microsoft.VSCode`. Code written to match `wm_class.lower() in ("code",
"cursor")` matches nothing against this value — the comparison silently
fails and disables whatever depends on it (e.g., terminal detection), with
no error raised. A substring test (`"code" in wm_class.lower()`) matches.

`com.microsoft.VSCode` is also the Flathub app id for VS Code. It was not
verified whether the host observed here was running the Flatpak build;
integrated-terminal shells were still descendants of the window's reported
pid regardless.

## All windows share one pid; terminals are indistinguishable by process tree

Every VS Code window on a host reports the same `pid` — the single main VS
Code process. Four open windows all report that one pid. Integrated
terminal shells (bash) are descendants of that same pid: on one host,
`pstree -p <pid> | grep -c bash` returned 10 for 4 windows.

Consequence: the process tree alone cannot determine which window, or which
terminal tab within a window, a given shell belongs to. That mapping is not
observable from outside the VS Code process.

## `List` response shape and its gotchas

The `window-calls` extension's `List` method returns one object per window
with these keys: `focus, frame_type, id, in_current_workspace, pid, title,
window_type, wm_class, wm_class_instance, workspace`.

- `focus` is a boolean, true for exactly one window (the focused one) across
  the whole response.
- `title` can be `null` for some windows. Any code doing substring checks on
  `title` (e.g. `"- Visual Studio Code" in title`) must guard against `None`
  first — `'x' in None` raises `TypeError`, not a false match.

## VS Code title format and workspace extraction

VS Code window titles follow:

```text
[<active editor> - ]<workspace> - Visual Studio Code
```

Examples observed:

- `CLAUDE.md (Working Tree) (CLAUDE.md) - claude-dashboard-main - Visual Studio Code`
- `jira-context.md - anstrat-1742 - Visual Studio Code`

The workspace name is the second-to-last segment when splitting on `" - "` from the right:

```python
workspace = title.rsplit(" - ", 2)[-2]
```

Window-level focus is observable via the `focus` key; which terminal *tab*
is active inside a focused window is not observable externally.

## Call cost: `gdbus` vs `psutil` process-tree walks

On one measured host, the `gdbus call` to `List` cost ~6 ms wall time.
Python's `psutil.Process(1).children(recursive=True)` cost ~15 ms —
`psutil` builds its parent map by reading every process in `/proc`, so
`children(recursive=True)` on any single pid scans the whole process table,
not just the target subtree. Calling it once per distinct pid repeats that
full-table scan each time; batching to one call for all pids needed avoids
the repeated cost.

## Discovery Context

Discovered on a Fedora 43 GNOME (Wayland) desktop with the `window-calls`
GNOME Shell extension installed, queried via:

```bash
gdbus call --session --dest org.gnome.Shell \
  --object-path /org/gnome/Shell/Extensions/Windows \
  --method org.gnome.Shell.Extensions.Windows.List
```

from a Python desktop dashboard that maps VS Code windows and integrated
terminals to projects.

## Verification Date

2026-10-21
