---
name: inaturalist
description: Work with the iNaturalist API (v1/v2). Use when querying observations, taxa, places, identifications, or users on iNaturalist; when handling geoprivacy/private coordinates; or when setting up authenticated API access.
---

# iNaturalist API

## Overview

Two active API versions:
- **v1** (`https://api.inaturalist.org/v1`): Older, fixed response schemas (returns everything always), integer IDs
- **v2** (`https://api.inaturalist.org/v2`): Recommended. Customizable field selection, UUID-based for observations, faster (less data transferred)

Interactive Swagger docs: https://api.inaturalist.org/v2/docs/

Server source: https://github.com/inaturalist/iNaturalistAPI

---

## Authentication

Many read endpoints work unauthenticated (public data only). Auth required for:
- Private/obscured coordinates
- Write operations (create/update/delete observations, identifications, comments)
- Personal user data

**Getting a token:** JWT from https://www.inaturalist.org/users/api_token (expires every 24 hours)

**Header:** `Authorization: Bearer {JWT}` or just `Authorization: {JWT}`

v2 also supports both a user JWT and an app JWT simultaneously (comma-separated or separate headers). Auth modes:
- `userJwtOptional` — tries auth, continues unauthenticated if absent
- `userJwtRequired` — 401 if no user JWT
- `appOrUserJwtRequired` / `appAndUserJwtRequired` — for write operations

---

## v2 Field Selection

**Critical v2 behavior:** Without a `fields` parameter, responses return almost nothing — only `uuid` by default. You must explicitly request fields.

`fields` accepts multiple formats:

| Format | Example |
|--------|---------|
| Comma-delimited string | `fields=species_guess,observed_on` |
| Dot-notation for nested | `fields=user.login,taxon.name` |
| RISON object | `fields=(species_guess:!t,user:(login:!t))` |
| JSON body (POST) | `{"fields": {"species_guess": true, "user": {"login": true}}}` |
| Special value `all` | `fields=all` — returns everything (equivalent to v1 behavior) |

Nested dicts: `true` means include the field; omitting means exclude. Parent fields with `{all: true}` include all their children.

**POST for complex field selection:** When the `fields` dict is specified or you're fetching >30 IDs, use POST with `X-HTTP-Method-Override: GET` header and the full params in the request body.

**Available top-level observation fields:**

| Category | Fields |
|----------|--------|
| IDs | `uuid` (always returned), `id` |
| Core | `species_guess`, `description`, `observed_on`, `observed_on_details`, `observed_on_string`, `time_observed_at` |
| Location | `place_guess`, `private_place_guess`, `geojson`, `private_geojson`, `place_ids`, `private_place_ids`, `positional_accuracy`, `public_positional_accuracy` |
| Privacy | `geoprivacy`, `taxon_geoprivacy`, `context_geoprivacy`, `obscured`, `viewer_trusted_by_observer` |
| Taxonomy | `taxon`, `community_taxon`, `community_taxon_id` |
| Media | `photos`, `sounds`, `observation_photos`, `observation_sounds` |
| Social | `identifications`, `comments`, `annotations`, `flags`, `faves`, `votes` |
| Counts | `identifications_count`, `comments_count`, `faves_count`, `cached_votes_total` |
| OFVs | `ofvs` — array of observation field values (see below) |
| Quality | `quality_grade`, `quality_metrics`, `id_please` |
| Projects | `project_ids`, `project_observations`, `non_traditional_projects` |
| Status | `mappable`, `captive`, `out_of_range`, `spam` |
| Meta | `tags`, `outlinks`, `uri`, `license_code`, `preferences`, `application`, `site_id` |

Note: `location` in v2 is part of `geojson` (GeoJSON point), not a separate field.

---

## Observation Field Values (OFVs)

iNaturalist lets observers attach custom key-value data to observations via "observation fields." These are community-defined typed fields (text, numeric, taxon, date, etc.).

### Filtering by OFVs (search parameters)

Query syntax:
```
field:Habitat%20(s%20Afr)            # has field with any value
field:Habitat%20(s%20Afr)=Nama%20Karoo  # has field with specific value
without_field=Habitat                # lacks this field
```

### OFVs in responses

Request the `ofvs` field to get OFV data on returned observations. Each OFV object contains:
- `field_id` — numeric ID of the observation field definition
- `name` — field name
- `value` — the value stored (string representation)
- `datatype` — `text`, `numeric`, `taxon`, `date`, `datetime`, `time`, `dna`, `location`
- `taxon` — (if datatype=taxon) the associated taxon object

### Managing OFVs (write)

- Create/update: `POST /v1/observation_field_values` with `{observation_id, observation_field_id, value}`
- Delete: `DELETE /v1/observation_field_values/{id}`
- Find field IDs: `GET /v1/observation_fields/autocomplete?q=name`

---

## Key Search Parameters

### Taxonomy
| Param | Notes |
|-------|-------|
| `taxon_id` / `taxon_ids` | Numeric ID(s); comma-separated = OR |
| — | **Retired taxa:** on `/taxa`, the `id=` param filters them out while the `/taxa/{ids}` path form returns them with `is_active: false` and `current_synonymous_taxon_ids`. See Known Gotchas #10. |
| `taxon_name` | Scientific or common name. **Gotcha:** misspelling returns all taxa silently. Common names matching multiple taxa return only the first match. Use IDs for precision. |
| `without_taxon_id` | Exclude taxon(s) |
| `ident_taxon_id` | Has an active ID for taxon (not necessarily community consensus) |
| `identified` | `true`/`false` — has any identification |
| `disagreements` | `true`/`false`/`any` |
| `native` / `introduced` / `threatened` | `true`/`false`/`any` |

### Geography
| Param | Notes |
|-------|-------|
| `place_id` | Single or multiple place IDs |
| `nelat`, `nelng`, `swlat`, `swlng` | Bounding box |
| `lat`, `lng`, `radius` | Circle search (radius in km) |
| `geoprivacy` | `open`/`obscured`/`private`/`obscured_private` |
| `taxon_geoprivacy` | Set by iNat based on conservation status |
| `mappable` | `true`/`false`/`any` |
| `acc_above` / `acc_below` | Positional accuracy filter in meters |

### Time
| Param | Notes |
|-------|-------|
| `d1` / `d2` | Observed date range. Accepts date-only (`2020-10-25`) **or** datetime (`2020-10-25T10:00-05:00`) — the form you pass changes the semantics; see below. |
| `month`, `day`, `year`, `hour` | Specific time parts (month 1-12, hour 0-23) |

**`d1`/`d2` semantics depend on whether you include a time** (source: [`dateRangeFilter`](https://github.com/inaturalist/iNaturalistAPI/blob/97c7dac7cddab6d5ac84f336bf75d8e2fb866f4d/lib/util.js#L190)):
- **Date-only** (`YYYY-MM-DD`) → matches on `observed_on_details.date`, the observation's **local calendar date**, **inclusive on both ends**. No timezone conversion — an observation counts on the date the observer recorded, regardless of your (or the server's) timezone. `d1=d2=2024-06-15` returns exactly that day. This is what you almost always want; it's immune to UTC-vs-local skew.
- **With a time** (`...THH:mm:ssZ`) → matches on the `time_observed_at` **instant** for observations that have a time, falling back to the local date for those that don't. Use only when you genuinely need sub-day precision.

**Gotcha:** Timezone is ignored in month/day (and date-only `d1`/`d2`) searches — they reflect the locally recorded date, not any timezone param.

### Who
| Param | Notes |
|-------|-------|
| `user_id` | Login name or numeric ID (don't mix types in one request) |
| `not_user_id` | Exclude observer |
| `ident_user_id` | Filter by who made an identification |
| `site_id` | Network affiliation (1=iNaturalist, 9=ALA, 25=UK, ...) |

### Quality & Projects
| Param | Notes |
|-------|-------|
| `quality_grade` | `research`/`needs_id`/`casual`/`any` |
| `verifiable` | `true`/`false`/`any` (Explore mode defaults to `true`) |
| `captive` | `true`/`false`/`any` |
| `photos` / `sounds` | `true`/`false` — media presence |
| `project_id` | Filter by project |
| `license` | Observation license |
| `photo_license` | `cc0`, `cc-by`, `cc-by-sa`, `cc-by-nc` (lowercase) |

### Annotations
| Param | Notes |
|-------|-------|
| `term_id` | Annotation group: 1=Life Stage, 9=Sex, 12=Flowers/Fruits, 17=Alive/Dead, 22=Evidence of Presence, 33=Established, 36=Leaves |
| `term_value_id` | Specific annotation values (comma-separated = OR) |
| `term_id_or_unknown` | Include null-valued annotations |

### Logic
- Parameters combine with **AND**; commas within a single parameter use **OR**
- Explore mode defaults: `verifiable=true`
- Identify mode defaults: `quality_grade=needs_id`, `reviewed=false`
- Override everything: `quality_grade=any&reviewed=any&verifiable=any&place_id=any`

---

## Pagination & Rate Limits

Two ways to page. **Prefer id-keyset for anything that must be a consistent snapshot** (reconcile, sync, exporting a whole window); use `page`-number only for shallow, one-shot reads where a little drift is harmless.

- **Page-number:** `page` + `per_page` (max 200). Simple, but caps at 10,000 total records **and is non-atomic over a live/mutating window** — `d2`=today, so an observation created/edited/deleted between two page requests shifts `total_results` and slides records across the `page`×`per_page` offset boundary, silently dropping or duplicating rows. Fine for a quick look; wrong for a snapshot.
- **id-keyset (cursor):** `order_by=id&order=asc&id_above=<lastId>`, `id_above=0` to start. The cursor is an **immutable id**, so mid-page mutation can't drift the sweep — a new observation always gets a *higher* id (swept if in range, ignored if past the cursor), an edit keeps its id/place, a delete just doesn't appear. This is the drift-immune choice; sidestepping the 10k cap is a bonus, not the main reason. `id_below` + `order=desc` walks newest-first.
- **Rate limits:** Hard cap 100 req/min; keep to ≤60 req/min in practice
- **Media download limits:** 5 GB/hour, 24 GB/day — exceeding causes permanent IP block

Two subtleties that make a keyset sweep *provably complete*:
- **Stop on a short page, not just an empty one.** iNat returns exactly `per_page` rows for every page but the last, so a page with `< per_page` rows (including 0) is terminal — it can't be followed by more. Breaking only on an empty page (`if not results`) still works but costs one extra request whenever the total is an exact multiple of `per_page`.
- **Advance the cursor by the max *raw* id — before any client-side filtering.** If you drop rows locally (e.g. out-of-scope records) and then compute the cursor from the *kept* rows, a trailing dropped row never advances the cursor and the sweep stalls or re-fetches. Use the last raw result's id.

```
# id-keyset sweep — the correct pattern for a consistent snapshot
last_id = 0
loop:
    GET /v2/observations?taxon_id=47792&order_by=id&order=asc
        &id_above={last_id}&per_page=200&fields=...
    results = the page's results array   # raw, before any local filtering
    ... accumulate / filter locally ...
    if len(results) < 200: break         # short (or empty) page → terminal
    last_id = results[-1].id             # max RAW id (results are asc by id)
```

---

## Geoprivacy & Private Fields

| Field | Notes |
|-------|-------|
| `geojson` | Public GeoJSON point (may be obscured centroid) |
| `private_geojson` | Exact GeoJSON point — only with auth + observer trust |
| `place_ids` / `private_place_ids` | Place IDs from public vs private coords |
| `place_guess` / `private_place_guess` | Place name from public vs private coords |
| `geoprivacy` | `open` / `obscured` / `private` (set by observer). May arrive as `null` **or** the explicit string `"open"` — treat them as equivalent |
| `taxon_geoprivacy` | Set automatically by iNat based on conservation status. Same `null`-vs-`"open"` caveat (explicit `"open"` observed in the wild) |
| `obscured` | Bool — true means shown as broad area, not exact point |
| `positional_accuracy` | Real GPS accuracy of the true location. **Delivered to everyone — even anonymous requesters on obscured observations.** Only the coordinates themselves are protected |
| `public_positional_accuracy` | The obscured value (~26,500 m for obscured records); equals `positional_accuracy` when open |
| `viewer_trusted_by_observer` | **Personal** trust only — false does NOT mean you lack coordinate access (see below) |

Private coordinates require auth AND one of four cases (server source:
[`Observation#removeUnviewableGeo`](https://github.com/inaturalist/iNaturalistAPI/blob/97c7dac7cddab6d5ac84f336bf75d8e2fb866f4d/lib/models/observation.js#L81-L148)):
- **Self**: you are the observer.
- **Personal trust**: the observer trusts your account directly. The *only*
  case where `viewer_trusted_by_observer` is true — the flag reflects
  personal trust and nothing else.
- **Traditional-project curator**: the observation was submitted to a
  traditional project you curate and that submission allows curator
  coordinate access (a stored, per-observation preference). Works in **any**
  query context — membership lives on the observation.
- **Collection-project curator**: you curate a collection project the
  observation falls in, the project enables user trust
  (`prefers_user_trust`), its requirements have been stable for 7+ days, and
  the observer opted in (`prefers_curator_coordinate_access_for`: `"any"`,
  or `"taxon"` = taxon-obscured only). Collection membership is computed,
  not stored: this case applies **only when your authenticated search names
  exactly that one collection project** (`project_id=...`) — fetching the
  same observation by id, without `project_id`, or naming two projects
  withholds the private fields
  ([the grafting](https://github.com/inaturalist/iNaturalistAPI/blob/97c7dac7cddab6d5ac84f336bf75d8e2fb866f4d/lib/controllers/v1/observations_controller.js#L159-L187);
  [`CURATOR_COORDINATE_ACCESS_WAIT_DAYS`](https://github.com/inaturalist/iNaturalistAPI/blob/97c7dac7cddab6d5ac84f336bf75d8e2fb866f4d/lib/models/project_user.js#L57)).

Consequences:
- **The reliable "do I have the true coordinates?" signal is the presence of `private_geojson` in the response, not `viewer_trusted_by_observer`** — the flag is false in three of the four cases, including your own observations.
- For **collection projects only**, trust is per-query-context: the same observation returns different projections depending on which `project_id` the query names. Traditional-project curator access follows the observation everywhere.
- Being authenticated is not enough: a non-curator's token querying a project gets exactly the anonymous projection for obscured records (except `positional_accuracy`, which everyone gets).
- `obscured` stays `true` even when you receive the true coordinates — it describes the public representation, not your access.
- Requested private fields you lack access to are **omitted from the response entirely**, not returned as null (`viewer_trusted_by_observer` itself is omitted on anonymous requests) — another reason presence-testing is the right pattern.
- `project_observations.preferences` serializes as `{}` even where curator coordinate access is granted — don't audit access by reading preferences; fetch with the curator token and test `private_geojson` presence.

---

## v2-Only Endpoints

Beyond the core CRUD endpoints shared with v1, v2 adds:
- `GET /v2/observations/{uuid}` — fetch by UUID (v1 uses integer ID)
- `GET /v2/taxon_id_summaries` — taxon identification summaries
- `GET /v2/exemplar_identifications`
- Map tile endpoints: `/v2/grid`, `/v2/heatmap`, `/v2/points`, `/v2/taxon_places/{taxon_id}`, `/v2/taxon_ranges/{taxon_id}`, `/v2/geomodel/{taxon_id}`

v2 observations use **UUIDs** as primary identifier; integer IDs are still present but secondary. The server converts UUIDs to serial IDs internally.

---

## Known Gotchas

1. **v2 default fields are nearly empty** — just `uuid`. Always specify `fields`.
2. **Page-number pagination drifts over a live window** — offsets are non-atomic, so a mutation mid-sweep drops/duplicates rows (and it caps at 10k records). Use id-keyset (`id_above`/`id_below` + `order_by=id`) for any consistent snapshot; stop on a short page and advance the cursor by the max raw id. See Pagination.
3. **Taxon name ambiguity** — misspelling or ambiguous common name returns wrong/all taxa silently.
4. **Timezone in date filters** — month/day and **date-only `d1`/`d2`** queries use the observation's locally recorded calendar date (inclusive both ends), ignoring any timezone param. Pass a datetime to `d1`/`d2` only when you need instant-level (`time_observed_at`) precision. See Time.
5. **Deleted users** — queries return empty results with no error.
6. **`/observations/observers` bug** — stops at ~500 records with `order_by=species_count`; returns duplicates and 500 errors beyond that.
7. **Photo license case** — must be lowercase (`cc-by`, not `CC-BY`).
8. **`per_page` default is 30** — always set higher (up to 200).
9. **`viewer_trusted_by_observer: false` does not mean untrusted** — project-curator trust delivers `private_geojson` with that flag false. Test for the presence of `private_geojson` instead. See Geoprivacy & Private Fields.
10. **`/taxa?id=` hides retired taxa; `/taxa/{ids}` does not** — same API version, different route, different result set. The query-param form filters to active taxa and reports `total_results: 0` for a retired one, with nothing to say it ever existed; the path form returns it with `is_active: false` and `current_synonymous_taxon_ids` naming its replacement. This bites hardest in a closure resolver that treats "requested but not returned" as a failure: a taxon retired since you last saw it silently becomes an unresolvable id. Use the path form whenever an id might be retired, and request `is_active` and `current_synonymous_taxon_ids` explicitly (v2 returns neither by default). Note also that `GET /observations?taxon_id=<retired>` returns 0 — iNaturalist reassigns observations to the successor, so the retired id keeps nothing.
11. **One OAuth callback URL per app** — an iNat OAuth app registration holds exactly one redirect URI (no multi-URI list, despite Doorkeeper supporting it elsewhere). Every flow sharing the app (web sign-in, CLI logins) must share that one callback; plan ports/paths accordingly.

---

## Sources

Authoritative places to verify or go deeper:

- **API reference (Swagger)**: [v2](https://api.inaturalist.org/v2/docs/) · [v1](https://api.inaturalist.org/v1/docs/)
- **API server source** — the response filtering and query building described here: https://github.com/inaturalist/iNaturalistAPI. Inline code links are permalinks pinned to the revision the claim was verified against (`97c7dac`, 2026-04); to find a symbol's current form, use GitHub symbol search, e.g. [`symbol:removeUnviewableGeo`](https://github.com/search?q=repo%3Ainaturalist%2FiNaturalistAPI+symbol%3AremoveUnviewableGeo&type=code) (requires sign-in)
- **Rails app source** — obscuring, geoprivacy, projects, and everything upstream of the API: https://github.com/inaturalist/inaturalist
- **Search URL wikis** — community-maintained canonical reference for query parameters: [part 1](https://forum.inaturalist.org/t/how-to-use-inaturalists-search-urls-wiki-part-1-of-2/63) · [part 2](https://forum.inaturalist.org/t/how-to-use-inaturalists-search-urls-wiki-part-2-of-2/18792)
- **Geoprivacy explained** (user-facing semantics of obscuring): https://help.inaturalist.org/en/support/solutions/articles/151000169938
- **Help center & forum** — staff answers on API behavior: https://help.inaturalist.org/ · https://forum.inaturalist.org/
