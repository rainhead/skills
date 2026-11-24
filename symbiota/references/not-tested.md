# What is not known or not tested

Open this before relying on silence. Nothing here is evidence that something is safe. Standing marks are defined in [SKILL.md](../SKILL.md#version-and-how-claims-are-marked).

## Never run

- **Any Symbiota version other than 3.4.17.** The schema was 3.0 plus patches 3.1 to 3.4 (two benign errors appeared in the patches). Line numbers in this skill are for commit 4491b791c.
- **MySQL.** Only MariaDB 10.11 was used. Matching and collations were read as the same, which is not the same as run.
- **PHP other than 8.2.**
- **Snapshot and Aggregate collections.** What an import does to them (matching on `dbpk`, replacing the collection) is read in the source and was never run. Every measurement used Live Data.
- **A user with a role below collection administrator or the superuser.** The round trip used a user whose only role was collection administrator.
- **The Laravel API's write routes** (`occurrence`, `occurrence/skeletal`, `media`, `taxonomy`, `collection`). Neither a token nor a call was made. How a user gets a token was not looked up. The behaviour listed in [writing.md](writing.md#the-api) is read from the source and the OpenAPI text.
- **Driving the record editor to change existing records in bulk.** It was used only to create records and determinations.
- **The image import, material samples, and the identifier extension.** The identifier extension's rows (`identifiers.tab`) were not loaded by the importer: the table stayed empty (measured 2026-11-21).
- **Adding a term to the relationship vocabulary table** (`ctcontrolvocabterm`) so that the associations page offers it.
- **Whether Symbiota honours a `default` value in `meta.xml`.** A project wrote constants as real columns instead.
- **Real portal settings:** its PHP time zone, local code changes, and whether its users hold the same roles as the test user.

## Seen, with a cause not found

- **Whether a skeletal upload leaves identifications alone.** Two tests disagree ([writing](writing.md#skeletal-upload)).
- **Why "Restore from backup" added determination rows** to real records (190 on 2026-11-23).
- **How many current identifications a spreadsheet upload rewrites.** 332 on 2026-11-20 against the counts in [writing](writing.md#spreadsheet-upload) for 2026-11-23.
- **Whether an unchanged re-upload moves `dateLastModified`.** It varied between runs ([hazards](hazards.md#smaller-hazards)).
- **What a collection administrator sees of records with record security 1.** Their sensitive fields are blanked for a reader without rare-species rights. Which of the two groups an administrator falls into for the download was not isolated.

## Not looked up

- **Whether an import appears in the public edit feed.** Probably, if the feed reads the same edit table as "Version data changes", which was not checked. The meaning of the feed's `source` parameter and of `reviewStatus` was not looked up.
- **Request limits.** The only limit seen was HTTP 429 with `Retry-After` from the taxonomy export after three fetches in one day (2026-11-16). The v2 API's own limits are unknown.
- **GBIF's procedure when a collection's published identifiers change.** Beeline's notes say GBIF treats a changed identifier as a new record unless the publisher first sends a list of old and new, and that GBIF reads one Ecdysis collection weekly. This skill did not check either.
- **How often a portal rebuilds a collection's published archive.** One archive was last modified on 2026-11-03 and was still the current file on 2026-11-23.
- **How an administrator sets a collection's GUID source** beyond the collection metadata page's field `guidTarget`, and whether the API shows it. The v2 collection record does not (observed 2026-11-23).
- **Who may edit which Ecdysis records**, and whether a portal's users agree where records are edited. That is a question for the portal's people, and decides whether a scheduled import is acceptable.

## Untested ideas that look plausible

- A round trip made faithful by adding the API's `processingStatus` and other missing columns to the file.
- A renamed plant on an "observational" association (no address) through the update box.
- Refusing to send a record that appears in the edit feed after the read.
