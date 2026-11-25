# Headless Session IDs

`claude -p --session-id <uuid>` starts a headless session with a caller-chosen
id, and `claude -p --resume <uuid>` continues it. Observed while building an
agent work board: recording the uuid against a work item lets a later run
resume the same session instead of starting a new one.
