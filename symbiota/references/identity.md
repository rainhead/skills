# Identity: collections, datasets and identifiers

Open this when you must match a record, pick a join key, send an identifier, or explain why a record's published identifier is not the one you sent. Standing marks are defined in [SKILL.md](../SKILL.md#version-and-how-claims-are-marked).

## Collections and datasets

**A collection is the unit a portal manages and a person administers.** It has an institution code and a collection code (`NBSBC` and `BCBA` on one Ecdysis collection), a numeric `collid`, a management type, a GUID source and a published archive address. Read them from `GET <portal>/api/v2/collection/<collid>` (observed 2026-11-23). The record has `managementType`, `collectionGuid`, `dwcaUrl`, `rights`, and no GUID source field, so the GUID source has to be inferred ([below](#what-the-guid-source-setting-decides)).

**The management type decides how an import treats the collection.**
- **Live Data**: the portal holds the master copy and people edit records there. An import matches on catalog number only (source `SpecUploadBase.php` 612 to 625). Both collections measured on Ecdysis were Live Data (observed 2026-11-23).
- **Snapshot** and **Aggregate**: an import matches on `dbpk` as well (source `SpecUploadBase.php` 595 to 599). A Snapshot collection is meant to be replaced by each import, so edits made in the portal are lost. This was read in the source and never run ([not-tested](not-tested.md)).

Every measurement in this skill was made on a Live Data collection. The API's `managementType` filter takes `live`, `snapshot` or `aggregate` (observed in the OpenAPI description 2026-11-23).

**A dataset is a named list of records, kept by a link table, and it can lie inside one collection or cross several.** Two facts matter:
- **An upload adds no record to a dataset.** The source has no step for it (`SpecUploadBase.php` around 1060 is a comment). A record uploaded after you started reading by dataset is therefore invisible to a reader scoped by dataset. Read by collection instead, and filter by catalog prefix if the collection is shared.
- **Matching spans the whole collection, not the dataset.** An upload that matches a catalog number replaces a record in the collection whether or not the record is in your dataset.

Observed 2026-11-23: one Ecdysis collection held 111,251 records and one of its datasets 46,090.

## The identifiers

| Identifier | What it is | Use |
|---|---|---|
| `occid` | The portal's integer row number for the record. Different in every portal and every copy. | Links (`individual/index.php?occid=`), API paths. Never store it as an external key. |
| `catalogNumber` | Text, at most 32 characters. Matched case-insensitively and by exact text (the test database's collation is `utf8mb3_general_ci`; confirmed locally, not on a live portal). | The match key of a live collection. |
| `recordID` | A UUID the portal generates for every record. | A stable link and a stable key. It is the published `occurrenceID` when the GUID source is `symbiotaUUID`. |
| `occurrenceID` | A stored column that is empty unless something stored one. The published value is derived from it ([below](#what-the-guid-source-setting-decides)). | Darwin Core's record identifier. |
| `dbpk` | The source system's row id from an import, kept only on records the import inserts. | Never matches in a live collection. |
| `otherCatalogNumbers` | Free text, matched only if "Match on Other Catalog Numbers" is ticked. | A second match key. The match is exact text equality, and it **replaces the stored `catalogNumber` with the incoming one** (measured 2026-11-20, source `SpecUploadBase.php` 2477 to 2505). |
| `eventDate`, `fieldNumber`, `recordNumber` | Collecting data, not identifiers. | `fieldNumber` is `varchar(45)`. Send a number-like value as text: a spreadsheet turned `1.10` into `1.1`. |

`dbpk` detail, measured 2026-11-20: an archive whose row id is a UUID, imported with catalog matching on, matched a spreadsheet-created record and did **not** store the UUID (`dbpk` stayed empty). A later import with catalog matching off, which falls back to `dbpk`, did not match and inserted a second record. A third run with a changed locality changed nothing and inserted nothing. In a live collection `dbpk` matching never updates anything (source: `dbpk` is excluded from the update list, and the `dbpk` link at 2446 to 2456 runs for Snapshot and Aggregate only, or after inserts, 1021 to 1036). A unique key on `(collid, dbpk)` stops a second insert with the same row id.

**Disagreement between sources.** Beeline's plan of 2026-11-20 assumed that Symbiota matches a re-upload on the archive's row id by default. The test run the same day showed it does not in a live collection. The test is the later and more specific measurement, and it is the one recorded here.

### Duplicates

Measured 2026-11-20 on a spreadsheet upload:
- A catalog number twice in the file and absent from the collection makes two new records with that number.
- A catalog number twice in the file and once in the collection: only the first file row is applied.
- A catalog number twice in the collection and once in the file: only the record with the lowest `occid` is updated, and no warning is shown.

MySQL does not define which joined row an update takes, so the last two are observed, not guaranteed. An association import is different: a catalog number held twice gets the association on **both** records (source `OccurrenceImport.php` 201, measured 2026-11-20).

## What the GUID source setting decides

Each collection has a GUID source (`guidTarget`, set on the collection's metadata page). It decides two things: what the portal **publishes** as `occurrenceID`, and whether an `occurrenceID` in an **upload** is kept. The three values are `catalogNumber`, `symbiotaUUID` and `occurrenceId` (source, `DwcArchiverCore.php` 1565 to 1573 and `SpecUpload.php` 316 to 324).

| GUID source | Published as `occurrenceID` | An `occurrenceID` in an upload |
|---|---|---|
| `symbiotaUUID` | the stored `occurrenceID` if there is one, else the record's `recordID` | ignored (measured 2026-11-20 for a collection whose source is not `occurrenceId`) |
| `catalogNumber` | the stored `occurrenceID` if there is one, else the catalog number | ignored |
| `occurrenceId` | the stored `occurrenceID` only. A record with none is left out of the published archive. | stored on a new record. Replaces a different stored value on an existing record. Kept when the incoming value is blank or the column is absent. |

For the two rows where an upload's `occurrenceID` is ignored, a record that already has a stored `occurrenceID` keeps it whether the file's value differs, is blank or is absent (measured 2026-11-20 on both archive and spreadsheet routes). A new record gets none and a generated `recordID` (measured). Source for "kept when blank": `SpecUploadBase.php` 626 to 632 copies the existing value into the staged row when the incoming one is empty.

Consequences:
- **You cannot supply your own permanent identifier to a collection unless its GUID source is `occurrenceId`**, and changing that setting for a shared collection changes what is published for every record in it. Do not ask for the change lightly.
- **Changing the GUID source changes the published identifier of every record that has no stored `occurrenceID`, all at once.** A consumer such as GBIF then sees new records unless it is given a list of old and new identifiers first. That is the reasoning in Beeline's [ADR 0008](https://github.com/rainhead/beeline/blob/main/docs/adr/0008-specimen-identity.md) (the note of 2026-11-21). This skill did not check GBIF's procedure.
- **To find a collection's GUID source without administrator rights**, read its published archive and the API together: in the archive, `occurrenceID` equal to `catalogNumber` on every row is consistent with `catalogNumber` but does not prove it, because a collection could hold stored `occurrenceID` values that happen to equal its catalog numbers, so confirm the setting with the collection's administrator; equal to `recordID` on every row is consistent with `symbiotaUUID` and does not identify it either: a stored `occurrenceID` is published unchanged under all three settings, so stored values equal to the `recordID` would look the same (the record editor's whole-form save writes the `recordID` into an empty `occurrenceID`, measured 2026-11-23 and [writing](writing.md#the-record-editors-save-driven-by-a-program)), so confirm that setting with the collection's administrator too; and an API `occurrenceID` that is empty where the archive's is filled means the value is derived, which separates a derived value from a stored one but still does not name the setting. The archive route is in [reading.md](reading.md#the-published-darwin-core-archive). How Ecdysis's two collections come out is in [ecdysis.md](ecdysis.md#the-two-collections-and-dataset-44).
