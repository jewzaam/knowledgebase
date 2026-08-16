# The `ddgs` Python Library Is a Metasearch Layer, Not a DuckDuckGo Client

Observed in the multi-engine search helper of
[claude-skill-cited-research](https://github.com/jewzaam/claude-skill-cited-research)
(`scripts/multi_search.py`). Version pinned: `ddgs==9.14.4`.

## It fans out to nine backends, not one

Despite the name, `ddgs` is not a DuckDuckGo-specific client. It is a
metasearch layer that registers nine text-search backends: `brave`,
`duckduckgo`, `google`, `grokipedia`, `mojeek`, `startpage`, `wikipedia`,
`yahoo`, `yandex`.

The registry is programmatic, not documented as a fixed list:

```python
from ddgs.engines import ENGINES
# dict keyed by category: "text", "news", "images", "videos", "books"
```

Read `ENGINES` at runtime to enumerate available backends per category
instead of hardcoding a backend list — the set differs by category. For
example, `bing` is registered for `images` and `news` only, not `text`.
Naming `backend="bing"` for a text search is not an error and not a silent
no-op for a different reason than expected — it fails for the reason below.

## Unknown or wrong-category backend names silently fall back to auto-selection

Passing a `backend` value that doesn't exist, or exists but isn't registered
for the requested category (e.g. `bing` for `text`), raises no exception and
no warning. It silently falls back to `ddgs`'s auto-selection across all
registered backends for that category.

Verified: `backend="totallyfakeengine"` returned a result set identical to
`backend="bing"` for the same `text` query — both fell back to the same auto
pool. The practical consequence is that a typo or a wrong-category backend
name looks like it's isolating one engine but actually returns the full auto
pool, and there's no signal in the response that this happened.

## One call does not guarantee cross-engine diversity

`ddgs.text(..., backend="a,b,c")` fills `max_results` from whichever backend
in the list answers first — it is not a merge-and-dedupe across all named
backends. Measured: a single backend alone and all eight backends named
together both returned 10 of 10 requested results for the same query. Listing
many backends in one call does not by itself produce diverse cross-engine
results.

Querying disjoint backend subsets in **separate calls** is what forces
independent samples. Even then, overlap is significant: two healthy disjoint
waves returned 6 results each, of which only 2 were unique to the second wave
on one query, and 0 unique on another.

## `wikipedia` and `grokipedia` backends are lookups, not indexes

The `wikipedia` backend calls `https://{lang}.wikipedia.org/w/api.php?action=opensearch`
with `limit=1`. The `grokipedia` backend calls `https://grokipedia.com/api/typeahead`,
also capped at 1 result. Both return a single hit regardless of `max_results`
requested — they behave as name-lookup/typeahead endpoints, not search
indexes, and should not be relied on for multiple results per query.

## `yahoo` text results are Bing-powered

The `yahoo` text engine implementation references both `search.yahoo.com` and
`www.bing.com`, because Yahoo's text search results are sourced from Bing.
Any network allowlist scoped to the `yahoo` backend must also permit
`www.bing.com`, or requests fail even though `yahoo` is the named backend.
Consequence for diversity: `yahoo` results are not independent of `bing`
results — treating them as two separate sources undercounts correlation.

## Backend availability is volatile and clusters in outages

Probes taken minutes apart returned 3 of 8, 2 of 9, and 4 of 9 backends alive.
Failures surface as `DDGSException: No results found.` — the same exception
whether a single backend is briefly down or every backend is unreachable, so
this exception alone doesn't distinguish "engine down" from "no matches
exist." Expect intermittent partial availability rather than all-or-nothing
uptime.

## Why `ddgs` succeeds where plain HTTP clients get blocked

`ddgs`'s HTTP transport (`primp`) impersonates Chrome's TLS fingerprint.
Major search engines (including the backends `ddgs` wraps) answer a plain
`urllib`/`curl` GET with an anti-bot challenge response (HTTP 202, zero
results) regardless of the `User-Agent` header sent. Verified from one host
and IP with both a browser `User-Agent` string and a custom service
`User-Agent` — both got an identical 202 challenge. The discriminator is the
TLS/JA3 fingerprint of the client, not the `User-Agent` header. `primp`'s
Chrome-impersonating handshake is why `ddgs` gets real results from the same
network path where a plain HTTP client gets challenged.
