# Identifications and comments

Read this when you request `identifications` or `comments`, sync with `updated_since`, or reuse other people's content.

Both come back on an observation only when you ask for them in `fields`.

## Fields (v2)

**Identification**

| Field | Meaning |
|-------|---------|
| `id`, `uuid` | Identifiers |
| `body` | What the identifier wrote. Usually null |
| `created_at` | When it was made |
| `current` | False once the identifier withdrew it or replaced it with a newer one of their own |
| `category` | `improving` / `supporting` / `leading` / `maverick`: its standing against the community taxon, so a derived value |
| `own_observation` | True for the observer's own identification |
| `disagreement` | Null on the observer's own and on the first identification. Otherwise, whether it disagreed with what came before |
| `hidden` | Hidden by moderators |
| `vision` | The identifier took the computer-vision suggestion |
| `user`, `taxon` | Who made it and what they identified |

Every observation with a taxon has at least one identification. An empty list on such an observation means your field selection is wrong.

**Comment**: `id`, `uuid`, `body`, `created_at`, `hidden`, `user`. Requesting `updated_at` on a comment returns nothing.

Treat `user` on either as nullable, and a hidden comment's `body` too. A strict schema that validates a whole page at once would let one odd entry refuse the page every time it comes round.

## Incremental sync and `updated_since`

**The rule.** An `updated_since` sync sees new identifications but not new comments. A comment is picked up only when something else touches the observation, or when you refetch it for your own reasons.

**What was observed.** See [CHANGES.md](../CHANGES.md#2026-10-10--identifications-move-updated_at-comments-dont-id-lists-licensing) for the probes.

- A new identification moves the observation's served `updated_at` by itself, not by way of the community taxon or quality grade it might change. In 270 sampled observations whose latest identification was a third-or-later agreement with an already-settled taxon (so it changed neither), `updated_at` moved every time. Before those, none of 675 identifications by others postdated it.
- A comment doesn't. In 4 of 15 sampled observations with comments, the latest comment was newer than the observation's `updated_at`.

**Why, as read from the source.** This is a reading of the Rails code, not something confirmed against the index.

*Identifications.* The mechanism is the identification count.
1. An identification's commit callbacks are declared [`update_observation`, then `update_obs_stats`](https://github.com/inaturalist/inaturalist/blob/b1274a0b6cbf757600ff435135867b7b4021f33c/app/models/identification.rb#L48-L51), but they run in reverse. The app is on Rails 6.1 with `load_defaults 5.0`, and in-order transaction callbacks only arrived in Rails 7.1.
2. So [`Observation#update_stats`](https://github.com/inaturalist/inaturalist/blob/b1274a0b6cbf757600ff435135867b7b4021f33c/app/models/observation.rb#L2528-L2567) runs first. It sets `identifications_count` on the in-memory observation and writes it with `update_all`, which leaves the attribute marked as changed.
3. Then [`Identification#update_observation`](https://github.com/inaturalist/inaturalist/blob/b1274a0b6cbf757600ff435135867b7b4021f33c/app/models/identification.rb#L299-L335) ends in `observation.update(attrs)`. That has the changed attribute to save, and saving moves `updated_at`.

Not verified: a withdrawal (an update, not a create, which usually changes the agreement counts the same way) and a deletion (which runs separate callbacks).

*Comments.* The app writes a new `updated_at` to the database when a comment is created ([`Comment#update_parent_counter_cache`](https://github.com/inaturalist/inaturalist/blob/b1274a0b6cbf757600ff435135867b7b4021f33c/app/models/comment.rb#L89-L98), an `update_all`), then reindexes the observation ([`Comment#index_parent`](https://github.com/inaturalist/inaturalist/blob/b1274a0b6cbf757600ff435135867b7b4021f33c/app/models/comment.rb#L116-L127)). But `update_all` doesn't refresh the in-memory record, so the index most likely keeps the old value. The API serves the index, and `updated_since` filters on it.

## Licensing

An observation and each of its photos and sounds carry a license the observer chooses. Identifications and comments have no license setting, so the Terms of Service default most likely applies: contributed content is licensed CC BY-NC "unless you specify otherwise when you post". The Terms don't say outright that identifications and comments count as contributed content, so this is an interpretation. On that reading, someone else's identification or comment is their content under the default, and the observation's license doesn't cover it.

This was asked on the forum ([Comment licensing](https://forum.inaturalist.org/t/comment-licensing/80310), 2026-06). Community replies agree, and no staff had answered as of 2026-10. The Terms page (`/pages/terms`) sits behind a Cloudflare challenge that refuses non-browser clients, so a script can't fetch it.
