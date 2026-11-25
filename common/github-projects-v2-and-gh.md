# GitHub Projects v2 and the gh CLI

Observed while building an agent work board on GitHub Issues and Projects v2,
driven from Windows PowerShell 5.1 with `gh` 2.105.0. Items marked (docs) come
from GitHub documentation and were not run.

## Polling cost

- `gh project item-list` returns every field of every item. It is expensive
  to poll.
- A custom GraphQL query that asks only for `content { ... on Issue { number } }`
  and the wanted fields through `fieldValueByName(name: "Status")` (and
  `"Priority"`) costs about 1 rate-limit point per 100 items.
- REST list issues and list issue comments for a repo accept `since`
  (docs: "last updated after the given time", ISO 8601; the docs do not say
  whether the bound is inclusive or which timestamp it tests) and
  `sort=updated&direction=asc`. Conditional requests answered 304 do not
  count against the primary rate limit (docs).
- The Projects UI filter has an `updated:` qualifier with day granularity
  (docs). GraphQL `ProjectV2Item` has `updatedAt`, but `items` can only be
  ordered by POSITION (docs).
- Verified by running it: `ProjectV2.items(query: "...")` accepts the same
  `updated:` qualifier. With 16 items, `updated:@today` and
  `updated:>@today-1w` returned all 16 and `updated:<@today` returned 0.
  `updated:>@today-1h` returned 0 without an error: an unsupported unit is
  silently treated as matching nothing, so the filter cannot poll below one
  day.
- Verified by running it: a Status change made only on the project board
  (`gh project item-edit`) does not change the issue's own `updated_at`, so
  a REST `?since=` poll of issues does not see board moves. Board column
  changes have to be read from the project items themselves.

## Rate limiting

- Bursts of concurrent `gh` calls from several sessions on one token
  produced "API rate limit already exceeded".
- The GraphQL `rateLimit { remaining }` field and `gh api rate_limit`
  disagreed at times (unexplained).
- Serialize callers with a lock.

## Single-select fields (Status, Priority)

- `updateProjectV2Field` with `singleSelectOptions` replaces the whole option
  list. Each option input takes `id`, `name`, `color`, `description`.
- Passing an existing option's `id` keeps the items that hold it; renaming an
  option this way keeps its items. Omitting an existing option clears the
  value on items that used it. New options omit `id`.
- A project created from GitHub's template ships Priority (P0, P1, P2),
  Size and Estimate fields and extra views. Options can be renamed as above.

## Views

- `createProjectV2View` accepts only `projectId`, `name`, `layout`
  (`BOARD_LAYOUT`, `TABLE_LAYOUT`, `ROADMAP_LAYOUT`) and a configuration with
  only `visibleFieldIds`. Introspection shows no way to set a view's filter
  through the API. `deleteProjectV2View` exists.

## gh on Windows PowerShell 5.1

- Pass a multi-line GraphQL query as `-F query=@file`.
- A `--jq` / `-q` expression containing inner double quotes is mangled by
  native-argument quoting. Parse the JSON in PowerShell instead.
- `gh api --paginate --slurp` returns an array of pages; flatten the nested
  arrays.

## Attachments

- `gh issue comment --attach <file>` uploads images and videos into the
  comment (up to 50 files; alt text cannot be set on videos). A 2.5 MB mp4
  plus a png uploaded in about 4 s. Video limit is 10 MB on free plans
  (docs).
