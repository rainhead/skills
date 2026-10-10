# Verification history

## 2026-08-28 — retired taxa are visible on `/taxa/{ids}` but not `/taxa?id=`, verified live

Prompted by a real mirror going stale: 9 of 512 cached taxa had been retired
upstream and nothing noticed, because the code refreshing them queried
`?id=`.

Probed taxon `1368491` (*Sagmatias obliquidens*, retired in favour of
`1664971` *Aethalodelphis obliquidens*) alongside a live control, `41777`
(*Lontra canadensis*):

| Request | Result |
|---|---|
| `v2 /taxa?id=1368491&fields=(id:!t,name:!t,is_active:!t)` | `total_results: 0`, empty results |
| `v2 /taxa/1368491?fields=(...,is_active:!t,current_synonymous_taxon_ids:!t)` | returned, `is_active: false`, `current_synonymous_taxon_ids: [1664971]` |
| `v2 /taxa/1368491,41777?fields=(...)` | both returned; comma-separated ids work on the path form |
| `v1 /taxa/1368491,41777` | both returned, `is_active` and `current_synonymous_taxon_ids` present without field selection |
| `v1 /observations?taxon_id=1368491&per_page=0` | `total_results: 0` — observations are reassigned to the successor |

So the difference is **route, not API version**: `?id=` filters to active taxa
on both v1 and v2, while the path form does not. An earlier reading of this
same evidence concluded "v2 cannot see inactive taxa and v1 can", which is
wrong — v1 was simply being called in its path form. Recorded because the
wrong conclusion is the easy one to reach from a two-request comparison.

Consequence worth carrying: a closure resolver that requests referenced taxa
by `?id=` and treats "requested but not returned" as a hard failure will abort
on the first taxon retired since it last ran.

## 2026-08-21 — traditional-project curator trust, verified live

A manager's token querying two traditional projects it curates received
`private_geojson` (true coordinates, real 3 m accuracy vs ~26,700 m public)
on other observers' obscured observations, with
`viewer_trusted_by_observer: false` — the project-trust flavor observed for
real, matching the source reading below. Also observed:
`project_observations.preferences` serializes as `{}` even where curator
coordinate access is clearly granted — the preference is not auditable from
this field; test access by fetching with the curator token and checking
`private_geojson` presence.

Process notes backing claims in [SKILL.md](SKILL.md): when a fact was
verified, against what, and how. The skill states the facts; this file keeps
the receipts.

## 2026-08-21 — project-trust semantics, verified against source

Read from `iNaturalistAPI` at `97c7dac` (2026-04-09):
[`Observation#removeUnviewableGeo`](https://github.com/inaturalist/iNaturalistAPI/blob/97c7dac7cddab6d5ac84f336bf75d8e2fb866f4d/lib/models/observation.js#L81-L148);
[collection-project grafting in `observations_controller.js`](https://github.com/inaturalist/iNaturalistAPI/blob/97c7dac7cddab6d5ac84f336bf75d8e2fb866f4d/lib/controllers/v1/observations_controller.js#L159-L187);
[`ProjectUser.CURATOR_COORDINATE_ACCESS_WAIT_DAYS`](https://github.com/inaturalist/iNaturalistAPI/blob/97c7dac7cddab6d5ac84f336bf75d8e2fb866f4d/lib/models/project_user.js#L57):

- `viewer_trusted_by_observer` is computed solely from the session's
  personal-trust grants (`trustingUserIDs`) — definitively independent of
  curator access, confirming the flag is false for self and both curator
  cases.
- **Traditional projects** store membership on the observation
  (`project_observations` with a per-observation
  `allows_curator_coordinate_access` preference); curator access applies in
  any query context.
- **Collection projects** compute membership: the controller attaches it to
  results only when an authenticated search names exactly one collection
  project, so only such queries can reveal private coordinates via this
  path. Further gates: project `prefers_user_trust`, requirements stable for
  `CURATOR_COORDINATE_ACCESS_WAIT_DAYS = 7`, and the observer's
  `prefers_curator_coordinate_access_for` (`"any"`, or `"taxon"` for
  taxon-obscured-and-not-observer-obscured).
- This narrows the earlier "trust is per-query-context" claim to collection
  projects, and reclassifies the 2026-08-20 project-trust entry below: that
  probe's requester was not a curator of the queried (traditional) project,
  so it cannot have observed project-trust delivery — its flag conclusion
  stands on this source reading instead.

## 2026-08-21 — self-trust case, verified live

Fetched an observer's own obscured observations with their JWT, then the
same observation anonymously:

- Own observations deliver `private_geojson` and `private_place_guess` with
  `viewer_trusted_by_observer: false` — the flag is true only for a direct
  personal-trust grant from another observer.
- `obscured` remained `true` alongside the delivered true coordinates.
- Anonymously, the requested-but-inaccessible fields (`private_geojson`,
  `private_place_guess`, `viewer_trusted_by_observer`) were omitted from
  the response entirely rather than returned as null; the real
  `positional_accuracy` (14 m vs `public_positional_accuracy` 26,807 m)
  was again delivered without auth.

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

## 2026-08-20 — project trust vs personal trust (superseded, see above)

Probe notes claimed project-curator trust delivered `private_geojson` with
`viewer_trusted_by_observer: false`, evaluated per query context. The
2026-08-21 source reading shows the requester could not have held curator
access in that probe; the flag conclusion is retained on source authority,
and the per-query-context claim is narrowed to collection projects.

## Undated — `d1`/`d2` date-range semantics, verified against source

Read from [`dateRangeFilter`](https://github.com/inaturalist/iNaturalistAPI/blob/97c7dac7cddab6d5ac84f336bf75d8e2fb866f4d/lib/util.js#L190) (called with
`time_observed_at` + `observed_on_details.date`): date-only values match the
observation's local calendar date inclusively; datetime values match the
`time_observed_at` instant, falling back to local date when absent.
