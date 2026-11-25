# Discord Threads

Source: a small-model summary of the Discord developer docs (channel and thread
resources and the rate-limits page), not a first-hand test. Confirm wording on
the live pages before relying on it.

## Archiving

- Sending a message into an archived thread un-archives it automatically,
  unless a moderator locked the thread. Docs wording: "Sending a message will
  automatically unarchive the thread, unless the thread has been locked by a
  moderator".
- Posting in a thread needs `SEND_MESSAGES_IN_THREADS`.
- Explicitly un-archiving (PATCH with `archived=false`) needs only
  `SEND_MESSAGES` when the thread is not locked; otherwise `MANAGE_THREADS`.
- A locked thread can only be un-archived by someone with `MANAGE_THREADS`.
- `auto_archive_duration` takes 60, 1440, 4320 or 10080 minutes.

## Limits

- Thread name: 1-100 characters.
- An active-thread cap per guild exists; the docs state no number.
- Thread or channel rename limits and thread-creation rate limits are NOT stated
  on the rate-limits page. The commonly quoted "2 renames per 10 minutes" is not
  in the fetched docs: UNVERIFIED.

## Deleting

- Deleting a channel cannot be undone.
- Deleting a thread needs `MANAGE_THREADS`.
