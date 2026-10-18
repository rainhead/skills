---
name: inaturalist
description: Work with the iNaturalist API (v1/v2). Use when querying observations, taxa, places, identifications, or users on iNaturalist; when handling geoprivacy/private coordinates; or when setting up authenticated API access.
---

# iNaturalist API

Use **v2** (`https://api.inaturalist.org/v2`). You choose the fields you get back, observations are identified by UUID, and responses are smaller. **v1** (`https://api.inaturalist.org/v1`) always returns every field and uses integer ids. It is still the right choice for a few routes, such as observation field values.

Interactive docs: [v2](https://api.inaturalist.org/v2/docs/) · [v1](https://api.inaturalist.org/v1/docs/). Server source: https://github.com/inaturalist/iNaturalistAPI.

## Where to look

| You are… | Read |
|----------|------|
| Writing any query | This file |
| Wanting exact coordinates, or missing location fields | [references/geoprivacy.md](references/geoprivacy.md) |
| Exporting or syncing a whole window of observations | [references/pagination.md](references/pagination.md) |
| Requesting identifications or comments, or syncing with `updated_since` | [references/identifications-and-comments.md](references/identifications-and-comments.md) |
| Hitting something odd with taxa, users, photos or OAuth | [Known gotchas](#known-gotchas), then [references/gotchas.md](references/gotchas.md) |
| Checking when and how a claim was verified | [CHANGES.md](CHANGES.md) |

## Quick start

```
GET https://api.inaturalist.org/v2/observations
    ?taxon_id=47792
    &d1=2024-06-01&d2=2024-06-30
    &quality_grade=research
    &per_page=200
    &fields=uuid,observed_on,geojson,taxon.name,user.login
```

Without `fields` you get only `uuid`. Without `per_page` you get 30 rows.

## Authentication

Many read endpoints work without a token and return public data only. You need one for:
- private or obscured coordinates (see [geoprivacy](references/geoprivacy.md));
- writes: creating, updating or deleting observations, identifications and comments;
- personal user data.

**Getting a token:** a JWT from https://www.inaturalist.org/users/api_token. It expires every 24 hours.

**Header:** `Authorization: Bearer {JWT}`, or just `Authorization: {JWT}`.

v2 also accepts a user JWT and an app JWT at the same time (comma-separated, or in separate headers). The server's auth modes:
- `userJwtOptional`: uses the token if present, carries on unauthenticated if not
- `userJwtRequired`: 401 without a user JWT
- `appOrUserJwtRequired` / `appAndUserJwtRequired`: for writes

## v2 field selection

Without a `fields` parameter a v2 response returns only `uuid`. `fields` accepts several formats:

| Format | Example |
|--------|---------|
| Comma-delimited string | `fields=species_guess,observed_on` |
| Dot notation for nested | `fields=user.login,taxon.name` |
| RISON object | `fields=(species_guess:!t,user:(login:!t))` |
| JSON body (POST) | `{"fields": {"species_guess": true, "user": {"login": true}}}` |
| Everything | `fields=all` (the same as v1) |

In nested objects, `true` includes a field and leaving it out excludes it. A parent with `{all: true}` includes all its children.

**POST for large requests.** When you pass a `fields` object, send a POST with the header `X-HTTP-Method-Override: GET` and put the full parameters in the body.

**Top-level observation fields:**

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
| Observation fields | `ofvs` (see [below](#observation-field-values-ofvs)) |
| Quality | `quality_grade`, `quality_metrics`, `id_please` |
| Projects | `project_ids`, `project_observations`, `non_traditional_projects` |
| Status | `mappable`, `captive`, `out_of_range`, `spam` |
| Meta | `tags`, `outlinks`, `uri`, `license_code`, `preferences`, `application`, `site_id` |

`location` is not a separate field in v2. It is part of `geojson`, a GeoJSON point.

## Search parameters

**Combining:** parameters combine with AND. Commas inside one parameter mean OR.

**Defaults you may not expect:**
- Explore mode: `verifiable=true`.
- Identify mode: `quality_grade=needs_id` and `reviewed=false`.
- To remove every filter: `quality_grade=any&reviewed=any&verifiable=any&place_id=any`.

### Taxonomy

| Param | Notes |
|-------|-------|
| `taxon_id` / `taxon_ids` | Numeric id(s); comma-separated = OR |
| `taxon_name` | Scientific or common name. A misspelling returns all taxa, silently. A common name matching several taxa returns only the first. Use ids when precision matters |
| `without_taxon_id` | Exclude taxa |
| `ident_taxon_id` | Has an active identification of this taxon (not necessarily the community consensus) |
| `identified` | `true`/`false`: has any identification |
| `disagreements` | `true`/`false`/`any` |
| `native` / `introduced` / `threatened` | `true`/`false`/`any` |

On `/taxa`, the `id=` parameter hides retired taxa and the `/taxa/{ids}` path form doesn't. See gotcha 10.

### Geography

| Param | Notes |
|-------|-------|
| `place_id` | One or more place ids |
| `nelat`, `nelng`, `swlat`, `swlng` | Bounding box |
| `lat`, `lng`, `radius` | Circle search (radius in km) |
| `geoprivacy` | `open`/`obscured`/`private`/`obscured_private` |
| `taxon_geoprivacy` | Set by iNaturalist from conservation status |
| `mappable` | `true`/`false`/`any` |
| `acc_above` / `acc_below` | Positional accuracy in meters |

### Time

| Param | Notes |
|-------|-------|
| `d1` / `d2` | Observed date range. Takes a date (`2020-10-25`) or a datetime (`2020-10-25T10:00-05:00`), and the two behave differently (below) |
| `month`, `day`, `year`, `hour` | Parts of the time (month 1–12, hour 0–23) |

How `d1`/`d2` behave depends on whether you include a time (source: [`dateRangeFilter`](https://github.com/inaturalist/iNaturalistAPI/blob/97c7dac7cddab6d5ac84f336bf75d8e2fb866f4d/lib/util.js#L190)):

- **Date only** (`YYYY-MM-DD`): matches the observation's **local calendar date** (`observed_on_details.date`), inclusive at both ends. There is no timezone conversion, so an observation counts on the date the observer recorded, whatever your timezone or the server's. `d1=d2=2024-06-15` returns exactly that day. This is what you almost always want.
- **With a time** (`…THH:mm:ssZ`): matches the `time_observed_at` instant for observations that have one, and falls back to the local date for those that don't. Use it only when you need precision finer than a day.

Date-only `d1`/`d2` and `month`/`day` ignore any timezone parameter, because they use the locally recorded date.

### Who

| Param | Notes |
|-------|-------|
| `user_id` | Login or numeric id. Don't mix the two in one request |
| `not_user_id` | Exclude an observer |
| `ident_user_id` | Filter by who made an identification |
| `site_id` | Network affiliation (1 = iNaturalist, 9 = ALA, 25 = UK, …) |

### Quality, media and projects

| Param | Notes |
|-------|-------|
| `quality_grade` | `research`/`needs_id`/`casual`/`any` |
| `verifiable` | `true`/`false`/`any` |
| `captive` | `true`/`false`/`any` |
| `photos` / `sounds` | `true`/`false`: has media |
| `project_id` | Filter by project |
| `license` | Observation license |
| `photo_license` | `cc0`, `cc-by`, `cc-by-sa`, `cc-by-nc`. Lowercase only |

### Annotations

| Param | Notes |
|-------|-------|
| `term_id` | Annotation group: 1 = Life Stage, 9 = Sex, 12 = Flowers/Fruits, 17 = Alive/Dead, 22 = Evidence of Presence, 33 = Established, 36 = Leaves |
| `term_value_id` | Specific values (comma-separated = OR) |
| `term_id_or_unknown` | Include observations where the annotation is unset |

## Observation field values (OFVs)

Observers can attach custom typed key-value data to an observation through community-defined "observation fields".

**Filtering by OFV:**
```
field:Habitat%20(s%20Afr)               # has the field, any value
field:Habitat%20(s%20Afr)=Nama%20Karoo  # has the field with this value
without_field=Habitat                   # lacks the field
```

**Reading OFVs:** request `ofvs`. Each entry has:
- `field_id`: numeric id of the field definition
- `name`: the field's name
- `value`: the stored value, as a string
- `datatype`: `text`, `numeric`, `taxon`, `date`, `datetime`, `time`, `dna` or `location`
- `taxon`: the taxon object, when `datatype` is `taxon`

**Writing OFVs (v1):**
- Create or update: `POST /v1/observation_field_values` with `{observation_id, observation_field_id, value}`
- Delete: `DELETE /v1/observation_field_values/{id}`
- Find a field's id: `GET /v1/observation_fields/autocomplete?q=name`

## Pagination and rate limits

- `per_page` defaults to 30. Set it to 200, the maximum.
- `page` is fine for a shallow, one-off read. It stops at 10,000 records and can drop or repeat rows if data changes mid-sweep.
- For anything that must be a consistent snapshot, page by id with `order_by=id&order=asc&id_above=<lastId>`. Details and a loop in [references/pagination.md](references/pagination.md).
- Fetch up to 200 specific observations in one GET with `id=1,2,3`.
- **Rate limit:** 100 requests a minute is the hard cap. Stay at or under 60.
- **Media downloads:** 5 GB an hour and 24 GB a day. Going over gets your IP blocked permanently.

## v2-only endpoints

- `GET /v2/observations/{uuid}`: fetch by UUID (v1 uses the integer id)
- `GET /v2/taxon_id_summaries`: taxon identification summaries
- `GET /v2/exemplar_identifications`
- Map tiles: `/v2/grid`, `/v2/heatmap`, `/v2/points`, `/v2/taxon_places/{taxon_id}`, `/v2/taxon_ranges/{taxon_id}`, `/v2/geomodel/{taxon_id}`

v2 observations use UUIDs as the main identifier. Integer ids are still present. The server converts UUIDs to integer ids internally.

## Known gotchas

One line each. Entries marked **→** have a longer account in [references/gotchas.md](references/gotchas.md) or the file named.

1. **v2 returns only `uuid` by default.** Always pass `fields`.
2. **`page` drifts on live data.** Use id paging for a consistent snapshot. → [pagination](references/pagination.md)
3. **Taxon names fail silently.** A misspelling or ambiguous common name matches the wrong taxa, or all of them.
4. **Dates are local.** Date-only `d1`/`d2` and `month`/`day` use the locally recorded date and ignore timezone. Pass a datetime only for instant-level precision. See [Time](#time).
5. **Deleted users** return empty results with no error.
6. **`/observations/observers` breaks past about 500 records** with `order_by=species_count`, returning duplicates and 500 errors.
7. **Photo license is lowercase:** `cc-by`, not `CC-BY`.
8. **`per_page` defaults to 30.** Set it to 200.
9. **`viewer_trusted_by_observer: false` doesn't mean you lack coordinates.** Test for `private_geojson` instead. → [geoprivacy](references/geoprivacy.md)
10. **`/taxa?id=` hides retired taxa, but `/taxa/{ids}` returns them** with `is_active: false` and `current_synonymous_taxon_ids`. Use the path form when an id might be retired. → [detail](references/gotchas.md#10-taxaid-hides-retired-taxa-taxaids-does-not)
11. **One OAuth callback URL per app.** Every flow sharing the app must share it. → [detail](references/gotchas.md#11-one-oauth-callback-url-per-app)
12. **`updated_since` misses new comments,** though it catches new identifications. → [detail](references/identifications-and-comments.md#incremental-sync-and-updated_since)
13. **No bulk route for user profiles, but `/v1/observations/observers?user_id=a,b,c` returns many users at once.** → [detail](references/gotchas.md#13-user-profiles-have-no-bulk-route-but-observers-do)
14. **ORCID is a connected account,** not a profile field, and few users link one. → [detail](references/gotchas.md#14-orcid-is-a-connected-account-not-a-profile-field)
15. **A photo with an unresolved copyright or AI-content flag keeps `hidden: false`** but its URL becomes a placeholder that other sites can't display. Drop URLs under `/assets/(copyright-infringement|artificially-generated-content|media-hidden)-`. → [detail](references/gotchas.md#15-a-flagged-photo-keeps-hidden-false-but-loses-its-url)

## Sources

Where to verify a claim or go deeper:

- **API reference:** [v2](https://api.inaturalist.org/v2/docs/) · [v1](https://api.inaturalist.org/v1/docs/)
- **API server source** (response filtering and query building): https://github.com/inaturalist/iNaturalistAPI. Inline code links are permalinks pinned to the revision the claim was checked against (`97c7dac`, 2026-04). To find a symbol's current form, use GitHub symbol search, for example [`symbol:removeUnviewableGeo`](https://github.com/search?q=repo%3Ainaturalist%2FiNaturalistAPI+symbol%3AremoveUnviewableGeo&type=code) (needs sign-in)
- **Rails app source** (obscuring, geoprivacy, projects, and everything behind the API): https://github.com/inaturalist/inaturalist
- **Search URL wikis** (community-maintained list of query parameters): [part 1](https://forum.inaturalist.org/t/how-to-use-inaturalists-search-urls-wiki-part-1-of-2/63) · [part 2](https://forum.inaturalist.org/t/how-to-use-inaturalists-search-urls-wiki-part-2-of-2/18792)
- **Geoprivacy explained** (what obscuring means to users): https://help.inaturalist.org/en/support/solutions/articles/151000169938
- **Help center and forum** (staff answers on API behavior): https://help.inaturalist.org/ · https://forum.inaturalist.org/
