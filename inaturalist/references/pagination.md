# Pagination for consistent sweeps

Read this when you are exporting, syncing or reconciling a whole window of observations.

## Why not `page`

`page` and `per_page` (max 200) are fine for a quick, shallow look. They have two limits:

- They stop at 10,000 records in total.
- They are **not atomic over a live window**. If an observation is created, edited or deleted between two page requests, `total_results` shifts and records slide across the page boundary. Rows are silently dropped or repeated. This happens in practice, because `d2` of today always includes live data.

## id-keyset (the cursor method)

Order by id and ask for ids above the last one you saw: `order_by=id&order=asc&id_above=<lastId>`, starting from `id_above=0`. Use `id_below` with `order=desc` to walk newest-first.

The cursor is an immutable id, so changes during the sweep can't move it:

- a new observation gets a higher id, so it is swept if it is in range and ignored if it is past the cursor;
- an edit keeps its id;
- a delete simply doesn't appear.

Getting past the 10,000 cap is a bonus. Drift immunity is the reason to choose it.

## Two rules that make the sweep complete

- **Stop on a short page, not only an empty one.** iNaturalist returns exactly `per_page` rows for every page except the last, so a page with fewer rows (including none) is the last. Waiting for an empty page works but costs one extra request whenever the total is an exact multiple of `per_page`.
- **Advance the cursor by the last raw id, before any client-side filtering.** If you drop rows locally and then take the cursor from the rows you kept, a trailing dropped row never advances it, and the sweep stalls or refetches.

```
last_id = 0
loop:
    GET /v2/observations?taxon_id=47792&order_by=id&order=asc
        &id_above={last_id}&per_page=200&fields=...
    results = the page's results array   # raw, before any local filtering
    ... accumulate / filter locally ...
    if len(results) < 200: break         # short (or empty) page: last page
    last_id = results[-1].id             # max raw id (results are ascending)
```

## Fetching by id

`/v2/observations?id=1,2,3` takes a comma-separated list, and the other search parameters still filter it. 200 ids fit in one GET (a URL of about 1.8 KB) and all 200 come back. An id that no longer matches the filters, or was deleted, is absent.

## Staying current: `updated_since`

A sweep that keys on `updated_since` misses new comments. See [identifications-and-comments.md](identifications-and-comments.md#incremental-sync-and-updated_since).
