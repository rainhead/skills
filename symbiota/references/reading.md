# Reading from a Symbiota portal

Open this when you need records, counts or change information out of a portal, or need to know what a download leaves out. Standing marks are defined in [SKILL.md](../SKILL.md#version-and-how-claims-are-marked). Where a fact comes from Ecdysis only, it says so and [ecdysis.md](ecdysis.md) has the rest.

## Choose the route

| You need | Use | Sign-in |
|---|---|---|
| A count, or "has anything changed" | `api/v2/occurrence` with `limit=1`, read `count` | no |
| A sweep of public fields | `api/v2/occurrence`, up to 300 a page | no |
| Most fields and the whole identification history (not every record or stored field, see [what the download leaves out](#what-the-download-leaves-out)) | the signed-in download (`downloadhandler.php`) | yes |
| A snapshot a collection publishes for aggregators | the collection's `dwcaUrl` | no |
| Which records were edited, when, and what changed | `api/v2/occurrence/annotation` | no |
| One record as a person sees it | `collections/individual/index.php?guid=<id>` | no |
| The taxonomic thesaurus | `taxa/taxonomy/taxonomydisplay.php` | no |

## The public v2 API

Base address: `<portal>/api/v2/`. Check the version first (`installation/status`, field `symbiotaVersion`; Ecdysis answered 3.4.17 and API 2.0 on 2026-11-23, observed). The OpenAPI description is at `<portal>/api/docs` (JSON, title "Symbiota API", version 2.0) and the viewer at `<portal>/api/v2/documentation`, observed 2026-11-23.

Read routes in the description, observed 2026-11-23: `collection`, `collection/{id}`, `exsiccata`, `installation` and its `status`, `inventory`, `media/{id}`, `morphology`, `occurrence`, `occurrence/{id}` (with `includeMedia`, `includeIdentifications`, `includeDatasets`), `occurrence/{id}/identification`, `occurrence/{id}/media`, `occurrence/{id}/annotation`, `occurrence/{id}/reharvest`, `occurrence/annotation`, `occurrence/dataset` and `occurrence/dataset/{id}/occurrence`, `occurrence/duplicate`, `taxonomy` and its descriptions. The write routes are in [writing.md](writing.md#the-api).

`GET occurrence` filters, observed in the OpenAPI description 2026-11-23: `collid`, `catalogNumber`, `occurrenceID`, `additionalIdentifier`, `family`, `scientificName`, `tid`, `includeChildTaxa`, `recordedBy`, `recordedByLastName`, `recordNumber`, `eventDateMin` and `Max`, `country`, `stateProvince`, `county`, the four coordinate bounds, `elevationMin` and `Max`, `depthMin` and `Max`, `datasetID`, `dateLastModifiedMin` and `Max`, `returnStatistics`, `limit`, `offset`. Filters combine with AND.

The answer is an object: `offset`, `limit`, `endOfRecords`, `count`, `results`. `limit` defaults to 100 and is at most 300 (source, `api/app/Http/Controllers/OccurrenceController.php` 269 and 294). Page with `offset`. `endOfRecords` was `false` on an answer whose `count` was 0 (observed 2026-11-23), so stop on `offset >= count` or on a short page, never on that flag.

A result carries the occurrence's stored columns, including `occid`, `catalogNumber`, `occurrenceID`, `recordID`, `dbpk`, `collid`, `processingStatus`, `recordSecurity`, `cultivationStatus`, `sciname`, `dateLastModified` (observed 2026-11-23). Two cautions:
- `occurrenceID` is the stored value. A collection that derives its published identifier from the catalog number or the record's UUID shows an empty `occurrenceID` here for records that have none stored (observed 2026-11-23 on one Ecdysis collection). The published value is in the collection's Darwin Core archive ([identity.md](identity.md#what-the-guid-source-setting-decides)).
- `processingStatus` is here and is missing from the signed-in download ([below](#what-the-download-leaves-out)).

### Counting and asking what changed

To count a collection or a dataset, ask with `limit=1` and read `count`. To ask what changed since a day, send `dateLastModifiedMin=<day>&dateLastModifiedMax=<far future, such as 2999-01-01>`.

**Always send both bounds.** `dateLastModifiedMin` alone answers HTTP 500, observed on Ecdysis 2026-11-23 and first by beeatlas on 2026-07-23. The source shows why: the branch with no max passes its bound values to `whereRaw` as separate arguments (source, `OccurrenceController.php` 461). The min bound is exclusive (`dateLastModified > min`), and the max bound is exclusive of the day after it (`< max + 1 day`) (source, same file, 456 to 465).

A cheap change probe is two counts: the total, and the number modified since a day before your last download. Compare both with the numbers you stored when you last downloaded. It misses a second edit to a record already inside the window, and a swap of deleted for inserted records with a back-dated modification time. Both are healed by the next full download. beeatlas's [ADR 0023](https://github.com/rainhead/beeatlas/blob/main/docs/adr/0023-ecdysis-change-probe.md) has the reasoning, including why the baseline is read before the download and stored only after it succeeds.

**A bump of `dateLastModified` does not always mean a real change.** Whether an unchanged re-upload moves it varies between tests ([hazards](hazards.md#smaller-hazards)). The edit feed below is the finer test.

### Scope: collection and dataset

`collid` selects a collection and `datasetID` a dataset, which is a named subset of a collection ([identity.md](identity.md#collections-and-datasets)). A request with both answers the same count as the dataset alone when the dataset lies in that collection (observed 2026-11-23).

## The edit feed

`GET <portal>/api/v2/occurrence/annotation?collid=<collid>&type=internal` lists the edits made to records of a collection, without signing in. Parameters (observed in the OpenAPI description 2026-11-23): `collid`, `type` (`internal` or `external`), `source`, `fieldName`, `fromDate`, `toDate`, `limit` (at most 500, source `OccurrenceAnnotationController.php` 99), `offset`. A result has `annotationID`, `occid`, `occurrenceID`, `recordID`, `fieldName`, `oldValue`, `newValue`, `recordTimestamp`, `appliedStatus`, `reviewStatus` (observed 2026-11-23).

Use it to refuse to overwrite a record that someone edited after your download: list the edits since your read (`fromDate`), and drop the records they name from your file.

Observed 2026-11-23 on Ecdysis: `type=internal` held 34,260 edits for a collection of 9,452 records and 474,857 for a collection of 111,251. `type=external` was empty for both collections. The first results of the smaller collection were dated in September 2025, so the feed starts at the beginning: pass `fromDate`, or you page through everything. `fieldName` is recorded as the editor wrote it (`stateProvince` and `basisofrecord` both appeared).

**What the feed holds and leaves out**, measured 2026-11-23 on a local Symbiota 3.4.17 and read from `OccurrenceAnnotationController.php` 115 to 116:
- **`recordID` is null on an edit made in the record editor.** Match edits to records by `occid`, not by `recordID`.
- **The feed lists only records whose record security is 0.** An edit to a record with security 1 was saved and applied, and its edit row exists, but it is not in the feed (0 results for it, while the same call listed an edit on a security 0 record). So the feed cannot confirm that a program's edit reached such a record, and a silence in the feed does not mean a record is unchanged. A sweep of 300 saves showed 290 in the feed, the ten missing being the security 1 records.
- **An import's edits are in the feed, if "Version data changes" was ticked**: the 6 edit rows of a one-record import appeared, with lowercase field names, and an import with it unticked wrote none. An edit by the record editor's save appears within the same second. Held edits (`appliedStatus` 0) also appear.
- **Never in the feed:** an identification added in the editor or by an upload (they write no edit row), and any change by an upload without "Version data changes". Nor is any change to a record other than the matched one ([hazards](hazards.md#an-import-of-one-record-changes-other-records-and-the-matched-one)). The feed is a lower bound on what changed.
- **The per-record route `api/v2/occurrence/{id}/annotation` answered HTTP 500 locally for every id**, because the controller calls a function that does not exist (the error log names `getOccidFromOtherIds`). Use the collection route with `collid` and filter, or `fieldName`.
- **Reaching the API locally.** In the local harness the Laravel API answered only under `/sym/api/index.php/v2/...`, and needed the `pdo_mysql` extension and database settings in `api/.env`, which the harness now sets ([local-test](local-test.md#reaching-the-api-locally)).

## The signed-in download

`collections/download/downloadhandler.php` builds a ZIP on request, and takes about two minutes for a collection of tens of thousands of records on Ecdysis. An anonymous request is answered 401 with `{"error":"Unauthorized access"}`, observed by beeatlas on 2026-06-24.

**Sign in, then post the form.** Both steps are what Beeline and beeatlas do nightly:

1. `POST <portal>/profile/index.php`, form fields `login`, `password`, `action=login`, `remember=0`. There is no CSRF token. The reply is a redirect carrying the session cookie: do not follow it, keep the cookie. A reply with no cookie means the sign-in was refused.
2. `POST <portal>/collections/download/downloadhandler.php` with the cookie and form fields: `schema=symbiota`, `identifications=1`, `images=0`, `identifiers=1`, `format=tab`, `cset=utf-8`, `zip=1`, `publicsearch=1`, `taxonFilterCode=0`, `sourcepage=specimen`, `submitaction=` (empty), and `searchvar` holding a URL-encoded query string: `usethes=1&taxontype=4&association-type=none&comingFrom=newsearch` plus `db=<collid>` for a collection or `datasetid=<id>` for a dataset.

**Test the body, not the status.** A refused sign-in still answers the download with JSON or a page. Accept the answer only if it begins with the bytes `PK\x03\x04`.

The switches `identifications`, `images`, `attributes`, `materialsample`, `identifiers` and `associations` are on when the key is present, whatever its value (source, `downloadhandler.php` 178 to 188). `images=0` therefore still asks for images, and the ZIP held a `multimedia.tab` (measured 2026-11-23). Add `associations=1` to get `resourceRelationships.tab`, the host-plant and link rows.

The ZIP held `occurrences.tab`, `identifications.tab`, `multimedia.tab`, `identifiers.tab`, `meta.xml`, `eml.xml` (measured 2026-11-23).

### The two schemas

`schema=symbiota` writes Symbiota's own columns, including `eventDate2`, `recordSecurity`, `cultivationStatus`, `associatedCollectors` and `securityReason`. `schema=dwc` writes Darwin Core: the end of a date range is joined to `eventDate` with `/`, parts written as `-00` are dropped, and `eventDate2` is not a column (source, `DwcArchiverCore.php` 1609 to 1617). Uploaded back, a `dwc` download additionally emptied `associatedCollectors`, `cultivationStatus`, `eventDate2`, `recordSecurity` and `securityReason` on the test records (measured 2026-11-23). Use `symbiota` if the file is to be uploaded again.

### The identification file does not match its `meta.xml`

`occurrences.tab` is tab-separated. `identifications.tab` and `resourceRelationships.tab` are comma-separated with quoted fields, while `meta.xml` declares tab for them (measured 2026-11-20, 2026-11-21 and 2026-11-23; beeatlas reads the delimiter off the header: a tab in the header means tab, otherwise comma). Symbiota's own importer takes the delimiter from `meta.xml` (source, `SpecUploadDwca.php` 375 to 381), so the ZIP as downloaded loaded **zero identifications** when uploaded to a fresh collection (measured 2026-11-21). Repair: change `fieldsTerminatedBy` of the `Identification` extension in `meta.xml` to a comma. With the repair, 13,682 identifications loaded from a file that held 15,835 rows, because a row with no `scientificName` is skipped (measured 2026-11-21).

The collection's published archive (next section) is consistent: its `meta.xml` says comma and the files are comma-separated (observed 2026-11-23).

### What the download leaves out

- **Records with `cultivationStatus` 1.** Left out of a search download (measured 2026-11-23).
- **Records with `recordSecurity` 5 when `publicsearch=1`**, for every user, an administrator included. The source removes them deliberately so that they cannot reach a public copy (source, `DwcArchiverCore.php` 1812 to 1845). A download without `publicsearch` keeps them for a user with SuperAdmin, or CollAdmin or CollEditor on that collection. On the test collection 3 of 9,484 records were absent (measured 2026-11-23).
- **Records with `recordSecurity` 1** are kept. Their sensitive fields (locality and coordinates among them) are blanked for a reader without rights to rare species, and the record's `informationWithheld` says which fields (source, `DwcArchiverCore.php` 1577 to 1586). What a collection administrator sees of them was not isolated in the notes.
- **`processingStatus`.** It is not a column of the download. A file built from the download and uploaded back sets it to empty ([hazards](hazards.md#absent-and-blank-columns-are-emptied)). The API carries it.
- Columns the portal stores but the download has no column for were emptied by a round trip too: `storageLocation`, `labelProject`, `duplicateQuantity`, `observerUid`, `dynamicProperties`, `fieldNotes`, `samplingEffort` and others ([hazards](hazards.md#a-round-trip-through-the-download)).
- Without a taxonomic thesaurus loaded, the download's `genus`, `specificEpithet` and `taxonRank` are blank, so a local copy needs the thesaurus before a round trip means anything ([local-test.md](local-test.md#what-the-copy-needs-to-be-faithful)).

## The published Darwin Core archive

Each collection record from `api/v2/collection/<collid>` has a `dwcaUrl`, a public ZIP that Symbiota rebuilds on a schedule for aggregators such as GBIF (observed 2026-11-23: the file for one Ecdysis collection was last modified 2026-11-03). Use it when you want what GBIF sees. It is not a fresh read: its age is in `Last-Modified`.

It holds `occurrences.csv`, `identifications.csv`, `identifiers.csv`, `resourceRelationships.csv`, `meta.xml`, `eml.xml` and `CITEME.txt`, comma-separated and consistent with its `meta.xml` (observed 2026-11-23). Its `occurrenceID` is the published identifier, which is the one thing the API's `occurrenceID` does not give you ([identity.md](identity.md#what-the-guid-source-setting-decides)). It leaves out records that have no `occurrenceID` and no GUID source (source, `DwcArchiverCore.php` 1565 to 1573 with `limitToGuids`).

## Record links

A record's page is `<portal>/collections/individual/index.php?guid=<id>`, where `<id>` is the record's `occurrenceID` or its `recordID`. The page answers 200 for a `recordID` (observed 2026-11-23). The records sampled all had a `recordID` that is a 36-character UUID (observed 2026-11-23), so it is the safer link. The older form is `?occid=<n>&clid=0`, where `occid` is the portal's own row number ([identity.md](identity.md#the-identifiers)).

The page lists the record's associations; beeatlas reads the iNaturalist link out of it by selecting `#association-div a[target="_blank"]`. That page scrape is the only way known to read associations without signing in. Fetch pages slowly: beeatlas allows itself at most 20 a second and caches each page.

## The taxonomic thesaurus

Symbiota exports a branch of its thesaurus as CSV without signing in: `POST <portal>/taxa/taxonomy/taxonomydisplay.php` with `target=<tid>`, `displayauthor=1`, `displaysubgenera=1`, `displayfulltree=1`, `taxauthid=1`, `tdsubmit=exportTaxonTree`. The CSV holds every name in the branch with rank, author, parent, whether it is accepted, which name a synonym points to, and the chain above the branch. Source: Beeline's `src/fetch-ecdysis-taxonomy.ts`, run against Ecdysis since 2026-10-23.

Traps, all from that fetcher's experience on Ecdysis:
- **Target by `tid`, never by name.** The page reads a name as a prefix, so `Bombus` matches every name that starts so. Find a class's `tid` with `GET <portal>/api/v2/taxonomy?taxon=<name>`.
- **A large branch fails.** Insecta in one export fails, as did Coleoptera: the answer is 500 or an empty body. Split it: ask `taxa/taxonomy/rpc/getdynamicchildren.php?id=<tid>` for the children and export each. Hymenoptera (138,652 names) answered in about ten seconds.
- **Ask again before believing a 500**, because a passing fault answers 500 too.
- **Honour 429 with its `Retry-After`.**
- Some text is stored double-encoded in the thesaurus (an author's umlaut read as two characters). Keep it as the portal has it.
