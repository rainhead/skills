# Gotchas in detail

[SKILL.md](../SKILL.md) lists every gotcha in one line, numbered. This file holds the long entries. Numbers match.

## 10. `/taxa?id=` hides retired taxa; `/taxa/{ids}` does not

The difference is the route, not the API version. The query-parameter form filters to active taxa and reports `total_results: 0` for a retired one, with nothing to say it ever existed. The path form returns the taxon with `is_active: false` and `current_synonymous_taxon_ids` naming its replacement.

This bites hardest in a resolver that treats "requested but not returned" as a failure. A taxon retired since you last saw it silently becomes an unresolvable id.

- Use the path form whenever an id might be retired. Comma-separated ids work on it.
- Request `is_active` and `current_synonymous_taxon_ids` explicitly, since v2 returns neither by default.
- `GET /observations?taxon_id=<retired>` returns 0. iNaturalist reassigns observations to the successor, so the retired id keeps nothing.

Example: `1368491` (*Sagmatias obliquidens*) was retired in favour of `1664971`. Receipts in [CHANGES.md](../CHANGES.md#2026-08-28--retired-taxa-are-visible-on-taxaids-but-not-taxaid-verified-live).

## 11. One OAuth callback URL per app

An iNaturalist OAuth app registration holds exactly one redirect URI, with no multi-URI list, even though Doorkeeper supports one elsewhere. Every flow that shares the app (web sign-in, CLI logins) must share that one callback, so plan ports and paths accordingly.

## 13. User profiles have no bulk route, but observers do

`/v1/users/{id}` and `/v2/users/{id}` each take one id. A comma list answers 404 "User does not exist".

`/v1/observations/observers?user_id=<id,id,…>&quality_grade=any&verifiable=any&per_page=200` returns each listed user who has any observation, with their full user record. 150 ids fit in one request (440 accounts in 3 requests, 2026-10-10). A user with no observations is absent from the response.

## 14. ORCID is a connected account, not a profile field

A user links ORCID under Settings → Applications → Connected Accounts → ORCID. That signs them in to ORCID and stores it as a provider authorization ([`User#orcid`](https://github.com/inaturalist/inaturalist/blob/b1274a0b6cbf757600ff435135867b7b4021f33c/app/models/user.rb#L799)).

- The v1 API returns it as `orcid`, a full `https://orcid.org/…` URI, on the user record.
- iNaturalist's GBIF dataset writes it as `recordedByID` on that user's observations.
- Few people connect one: 2 of 437 bee-atlas volunteers' accounts in 2026-10, though experts among them have ORCIDs they never linked.

## 15. A flagged photo keeps `hidden: false` but loses its URL

While a photo has an unresolved flag for copyright infringement, or one for AI-generated content, the API serves its `url` (and every size) as a placeholder image of iNaturalist's own, and `hidden` stays false. A photo that moderators hid gets a similar placeholder.

| Cause | Placeholder path |
|-------|------------------|
| Unresolved copyright flag | `/assets/copyright-infringement-<size>.png` |
| Unresolved AI-generated-content flag | `/assets/artificially-generated-content-<size>.png` |
| Hidden by moderators | `/assets/media-hidden-<size>.png` |

All three come from [`Photo#sized_url`](https://github.com/inaturalist/inaturalist/blob/2c2bec7eee618a3c7ec8b984c16ac3d457a19985/app/models/photo.rb#L102-L113).

**Why it matters.** Filtering on `hidden` alone lets the placeholders through. They can't be shown on another site: a browser on another origin is refused them, with `Cross-Origin-Resource-Policy: same-origin` (`net::ERR_BLOCKED_BY_RESPONSE.NotSameOrigin`), so the page shows a broken image.

**How to filter.** Either of these:
- Drop a photo whose URL path matches `/assets/(copyright-infringement|artificially-generated-content|media-hidden)-`. Match on the path so a change of asset host doesn't matter.
- Request the photo's `flags` and drop any with an unresolved flag of those two kinds. v1 returns flags; v2 needs `observation_photos.photo.flags.flag,observation_photos.photo.flags.resolved`.

**Sync.** Raising the flag moved the observation's `updated_at` within 2 seconds on both observations seen, so an `updated_since` sync picks the placeholder up. Whether resolving a flag moves it too is not verified.

Receipts in [CHANGES.md](../CHANGES.md#2026-10-15--a-flagged-photos-url-becomes-a-placeholder-with-hidden-false).

## 16. Spam comes back from search unless you ask for `spam=false`

An observation iNaturalist knows is spam has `spam: true`, and its page on iNaturalist shows a spam notice instead of the observation; an observation whose owner is a spammer gets a 403 "suspended" page instead ([`block_if_spam`](https://github.com/inaturalist/inaturalist/blob/0e15a4a4bd64b914672be1e4e6492c272a79fa9a/lib/acts_as_spammable/action_controller/base.rb#L16-L32)). The API's observation search doesn't filter on it unless asked: `spam=true` or `spam=false` adds the term, and no parameter returns both ([`observation_query_builder.js`](https://github.com/inaturalist/iNaturalistAPI/blob/6695325b1e0fad0dc9579cede4b8da9df2f3fa24/lib/models/observation_query_builder.js#L1368-L1376)). v1 and v2 behave the same.

`flags` can be empty on a spam observation, so test `spam`, not the flags. The owner's `user.spam` can still be false.

**How to filter.** Pass `spam=false` on every observation search a sync makes, including fetches by `id`. An observation flagged after you stored it then drops out of the results, so a sync that reconciles a window (deletes what the window no longer returns) removes it. An `updated_since` sync alone won't, since nothing is returned to act on.

## Detecting a takedown

What each kind looks like in the API, so a mirror can follow iNaturalist when it takes something down:

| Takedown | Observation in search | What to test |
|----------|----------------------|--------------|
| Observation known to be spam | Returned unless `spam=false` | `spam: true` (see 16) |
| Photo flagged for copyright or as AI-generated | Returned, with the observation's own `flags: []` and `spam: false` | The photo's URL is a placeholder (see 15), or an unresolved `copyright infringement` / AI-content flag in the photo's own flags (`observation_photos.photo.flags`) |
| Photo hidden by moderators | Returned | `hidden: true`, and the `media-hidden` placeholder (see 15) |
| Identification or comment hidden | Returned | That item's `hidden: true`; its body may be missing → [identifications-and-comments](identifications-and-comments.md) |
| Observation deleted | Absent | Only a reconciled re-fetch of its window notices; nothing is returned for it |

A photo takedown leaves the observation up, so the observation's own fields say nothing about it. Whether to drop the observation along with the photo is the caller's decision; SalishSea.io drops it, because the observer showed someone else's evidence (its decision 081).
