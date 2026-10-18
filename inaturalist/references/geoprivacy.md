# Geoprivacy and private fields

Read this when you need exact coordinates, or when a response has fewer location fields than you asked for.

## The fields

| Field | Notes |
|-------|-------|
| `geojson` | Public GeoJSON point (may be an obscured centroid) |
| `private_geojson` | Exact GeoJSON point. Only with auth and one of the four access cases below |
| `place_ids` / `private_place_ids` | Place IDs from the public vs private coordinates |
| `place_guess` / `private_place_guess` | Place name from the public vs private coordinates |
| `geoprivacy` | `open` / `obscured` / `private`, set by the observer. May arrive as `null` **or** the string `"open"`; treat them as the same |
| `taxon_geoprivacy` | Set by iNaturalist from conservation status. Same `null`-vs-`"open"` caveat |
| `obscured` | Boolean. True means the public location is a broad area, not the exact point |
| `positional_accuracy` | The real GPS accuracy of the true location. **Delivered to everyone, even anonymous requests on obscured observations.** The server removes only the private location fields (`private_geojson`, `private_location`, `private_place_ids`, `private_place_guess`); this accuracy value stays visible |
| `public_positional_accuracy` | The obscured value (about 26,500 m for obscured records). Equals `positional_accuracy` when the record is open |
| `viewer_trusted_by_observer` | **Personal** trust only. False does not mean you lack coordinate access |

## Who gets the true coordinates

Private coordinates need authentication **and** one of four cases. Server source: [`Observation#removeUnviewableGeo`](https://github.com/inaturalist/iNaturalistAPI/blob/97c7dac7cddab6d5ac84f336bf75d8e2fb866f4d/lib/models/observation.js#L81-L148).

1. **Self.** You are the observer.
2. **Personal trust.** The observer trusts your account directly. This is the only case where `viewer_trusted_by_observer` is true.
3. **Traditional-project curator.** The observation was submitted to a traditional project you curate, and that submission allows curator coordinate access (a stored, per-observation preference). Works in any query context, because membership lives on the observation.
4. **Collection-project curator.** All of these must hold:
   - you curate a collection project the observation falls in;
   - the project enables user trust (`prefers_user_trust`);
   - its requirements last changed more than 7 days ago ([`CURATOR_COORDINATE_ACCESS_WAIT_DAYS`](https://github.com/inaturalist/iNaturalistAPI/blob/97c7dac7cddab6d5ac84f336bf75d8e2fb866f4d/lib/models/project_user.js#L57));
   - the observer opted in (`prefers_curator_coordinate_access_for` is `"any"`, or `"taxon"`, which covers only records whose `taxon_geoprivacy` is `obscured` or `private` and whose own `geoprivacy` is neither);
   - your authenticated search names exactly that one collection project (`project_id=...`).

   Collection membership is computed, not stored, so a search without `project_id`, or one naming two or more collection projects, withholds the private fields. `project_id` can be combined with `id=` ([the grafting](https://github.com/inaturalist/iNaturalistAPI/blob/97c7dac7cddab6d5ac84f336bf75d8e2fb866f4d/lib/controllers/v1/observations_controller.js#L159-L187)).

## What follows from that

- **On obscured or private observations, test for the presence of `private_geojson`** to learn whether you have the true coordinates. (On an open observation it is absent too, but `geojson` is already exact.) Don't use `viewer_trusted_by_observer`: it is false in three of the four cases, including your own observations.
- Only collection projects are per-query-context. The same observation returns different fields depending on which `project_id` the query names. Traditional-project curator access follows the observation everywhere.
- A token is not enough. A non-curator's token querying a project gets exactly the anonymous view of obscured records, except `positional_accuracy`, which everyone gets.
- `obscured` stays `true` even when you receive the true coordinates. It describes the public representation, not your access.
- Private fields you can't see are **omitted from the response**, not returned as null. `viewer_trusted_by_observer` is itself omitted on anonymous requests. This is another reason to test for presence.
- `project_observations.preferences` serializes as `{}` even where curator access is granted, so you can't audit access from it. Fetch with the curator token and test for `private_geojson`.
