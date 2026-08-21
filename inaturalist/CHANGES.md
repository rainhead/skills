# Verification history

Process notes backing claims in [SKILL.md](SKILL.md): when a fact was
verified, against what, and how. The skill states the facts; this file keeps
the receipts.

## 2026-08-21 — geoprivacy & trusted access, verified live

Observed during authenticated and anonymous v2 sweeps of a curated project
(199 observations, 6 obscured):

- `positional_accuracy` (the true location's accuracy) is delivered to
  **everyone** — anonymous and untrusted-authenticated reads both received
  the real 6–15 m values on obscured records whose
  `public_positional_accuracy` was ~26,679 m. Only the coordinates
  themselves are protected.
- An authenticated non-curator's token querying `project_id` received the
  anonymous projection for obscured records: no `private_geojson`, no
  `private_place_guess`.
- `taxon_geoprivacy` arrived as the explicit string `"open"` (not only
  `null`) on an obscured-by-observer record.

## 2026-08-20 — project trust vs personal trust, verified live

Probe of the same project with a curator-trusted context:

- Project-level (curator) trust delivered `private_geojson` while
  `viewer_trusted_by_observer` remained `false` — the flag signals only
  personal trust. Presence of `private_geojson` is the operative signal.
- The same observation yields different projections through different
  project queries: trust is evaluated per query context (requester's
  curator role on the `project_id` named in the query + the observer's
  per-project opt-in).

## Undated — `d1`/`d2` date-range semantics, verified against source

Read from `iNaturalistAPI/lib/util.js` (`dateRangeFilter`, called with
`time_observed_at` + `observed_on_details.date`): date-only values match the
observation's local calendar date inclusively; datetime values match the
`time_observed_at` instant, falling back to local date when absent.
