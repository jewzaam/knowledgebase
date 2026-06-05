# gdbus GVariant String Escaping

When calling GNOME Shell D-Bus extensions via `gdbus call`, the output wraps return values in GVariant syntax: `('json_string',)`. Inside that string, any literal double quotes in the data (e.g., a window title containing `"Hamnet"`) are double-escaped as `\\"`.

If you strip the GVariant wrapper and feed the inner string directly to `json.loads()`, the double-escaped quotes (`\\"`) produce invalid JSON — the parser sees a literal backslash followed by a quote instead of an escaped quote.

## Fix

```python
json_str.replace('\\\\"', '\\"')
```

Apply this replacement before parsing.

## Discovery Context

Discovered in [claude-dashboard](https://github.com/jewzaam/claude-dashboard.git/) `claude_dashboard/platform/linux.py` — the `_list_windows_dbus()` function calls the `window-calls` GNOME Shell extension. A music player window title containing literal quotes in a track name (`"Hamnet"`) caused every D-Bus window query to return empty, silently breaking all window-based features (VS Code detection for sandboxes, live session foregrounding).

## Verification Date

2026-06-05
