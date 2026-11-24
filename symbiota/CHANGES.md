# Verification history

## 2026-11-23, later: the record editor's save, and four checks of the bulk import

Measured the same day on a second local Symbiota 3.4.17 (commit 4491b791c, PHP 8.2, MariaDB 10.11) built from the harness in [harness/](harness/). Invented data only, and nothing real was touched: 300 records in one Live Data collection, 20 in another, 9 probe records with deliberate gaps, and users with each role. Each trial started from a restored dump, and every table was compared by primary key afterwards.

| What was run | Where it is used |
|---|---|
| The record editor's save posted by a program: the smallest request that works, the whole form re-sent, a field listed and not posted, posted and not listed, an empty list, the response texts, a record that does not exist | [writing](references/writing.md#the-record-editors-save-driven-by-a-program) |
| 221 saves of 13 text fields with 17 values each, the number, date and coordinate fields, and twenty fields in one save | [writing](references/writing.md#traps) |
| Locks (a person with the record open), record security 1 and a sensitive taxon, the roles (collection administrator, collection editor, taxon editor, no role, the `publicEdits` flag), 300 saves for speed | [writing](references/writing.md#locks), [roles](references/writing.md#roles-and-review) |
| The editor's batch update on 10 records, and adding an identification | [writing](references/writing.md#the-editors-batch-update) |
| Four checks of a one-record import: whether other records change, whether the matched record loses columns the download lacks, what "Version data changes" logs, and whether the edit feed leaves out security 1 records | [hazards](references/hazards.md#an-import-of-one-record-changes-other-records-and-the-matched-one), [reading](references/reading.md#the-edit-feed) |

What changed in the skill: a full section on the editor's save in `writing.md`; the new section on the one-record import in `hazards.md`; what the edit feed holds and leaves out in `reading.md`; the editor's save as the first route for changing one field in `decisions.md`; the tests moved out of `not-tested.md` and the new gaps added; `SKILL.md` rule 1 and the gotchas made to agree.

**The harness was fixed.** The first harness lacked the `pdo_mysql` extension and the API's `api/.env` settings, so the API's routes failed. The Dockerfile and `setup.sh` now add both ([local-test](references/local-test.md#reaching-the-api-locally)). That session made the same changes by hand. The changed harness was not run end to end.

**Disagreement with the earlier notes, and which the skill follows.** The notes of 2026-11-20 listed "driving the editor in bulk" and "whether an import appears in the edit feed" as untested. Both are now measured, and the skill follows the measurements. The earlier statement that no route protects a matched record except the skeletal one is true of the uploads only: the editor's save does.

## 2026-11-23: first version, and what was checked for it

Written from Beeline's research notes and the Symbiota source, then checked against the public parts of ecdysis.org and against a fresh local Symbiota. Beeline's tests (2026-11-20 to 2026-11-23) were run by earlier sessions and are carried in as measurements with their dates. The sections below say which is which.

### Requests made to ecdysis.org for this skill

All unauthenticated, one at a time with a pause of about a second and a half, with a generic User-Agent ("agent-skill-check"). No sign-in and no write.

| Request | Result |
|---|---|
| `GET /api/v2/installation/status` | 200: Ecdysis, `symbiotaVersion` 3.4.17, `apiVersion` 2.0, an empty `managerEmail` |
| `GET /api/docs` | 200, OpenAPI 3.0.0 JSON of 134 KB, title "Symbiota API", version 2.0, contact "Symbiota Support Hub Team". Write routes (all with an `apiToken` parameter): `POST collection`, `POST occurrence`, `POST occurrence/skeletal`, `POST media`, `PATCH` and `DELETE media/{id}`, `POST taxonomy`. No update or delete route for an occurrence. |
| `GET /api/v2/documentation` | 200, HTML, 4 KB (the viewer) |
| `GET /api/v2/collection/196` and `/164` | 200. Both `managementType` "Live Data". Codes `NBSBC`/`BCBA` and `WSU`/`WSUC`. `dwcaUrl` set on both. The record has no GUID source field. |
| `GET /api/v2/occurrence?collid=196&limit=1` | `count` 9,452 |
| `GET /api/v2/occurrence?collid=164&datasetID=44&limit=1` and `?datasetID=44&limit=1` | `count` 46,090 both |
| `GET /api/v2/occurrence?collid=164&limit=1` | `count` 111,251 |
| The first result of each of the four | carries `processingStatus` and `recordSecurity`. The sampled British Columbia record: `occurrenceID` empty and `recordID` a 36-character UUID. The sampled Washington record: `occurrenceID` equal to `recordID`. |
| `GET /api/v2/occurrence?collid=196&dateLastModifiedMin=2026-11-22&limit=1` | **500**, an HTML error page |
| The same with `&dateLastModifiedMax=2999-01-01` | 200, `count` 0, `endOfRecords` false |
| `GET /api/v2/occurrence/annotation?collid=196&type=internal&limit=2` | 200, `count` 34,260. Fields `annotationID`, `appliedStatus`, `fieldName`, `newValue`, `occid`, `occurrenceID`, `oldValue`, `recordID`, `recordTimestamp`, `reviewStatus`. The two oldest results dated 2025-09-29 and 2025-09-30. |
| The same with `collid=164` | `count` 474,857 |
| The same with `type=external`, for both collections | `count` 0 |
| `GET /collections/individual/index.php?guid=<recordID of a sampled record>` | 200, "Occurrence Profile" |
| `GET /` and `GET /misc/contacts.php` | 200. The home page does not name a host. The contacts page lists a steering committee. |
| `HEAD` of the two `dwcaUrl` files | 200, `application/zip`, 1,513,787 and 14,512,834 bytes, both last modified 2026-11-03 |
| `GET` of the British Columbia archive | `meta.xml` declares comma-separated files and they are. 9,374 occurrence rows, 99 columns, `occurrenceID` equal to `catalogNumber` on all of them. `resourceRelationships.csv` has `hasHost` on every row. |
| An ARIN RDAP lookup of the address `ecdysis.org` resolved to (129.237.92.69) | Network `JAYHAWKNET`, 129.237.0.0 to 129.237.255.255, registered to the University of Kansas. This is the only evidence for "hosted at Kansas": the portal does not say so. |

I sent one request more than I needed to the home page (once to read it, once to find the contacts link). The ZIP of the British Columbia archive was downloaded once, to a scratch folder, and deleted afterwards.

### Source read at commit 4491b791c

`config/symbbase.php` 8 (version 3.4.17); `api/routes/web.php` 34 to 48 (occurrence routes, the update and delete lines commented out at 36 and 37); `api/app/Http/Controllers/OccurrenceController.php` 269, 294 (paging), 456 to 465 (date filter), 1202 to 1230 (skeletal route and its allowed fields); `OccurrenceAnnotationController.php` 99 (annotation paging); `Controller.php` 49 to 66 (token check); `classes/DwcArchiverCore.php` 1565 to 1573 (published identifier by GUID source), 1577 to 1586 (redaction), 1599 to 1617 (the `dwc` schema's dates), 1812 to 1845 (record security 5); `collections/download/downloadhandler.php` 178 to 188 (switches by presence); `collections/admin/uploadhandler.php` (arguments and defaults); `classes/SpecUpload.php` 34 and 433 to 437 (upload type numbers and page titles). The remaining line numbers in the reference files come from Beeline's notes and were not re-read.

### Reproduced on a fresh local Symbiota

The harness in [harness/](harness/), copied from the earlier sessions' scripts and made generic, was run from a scratch folder: PHP 8.2 image built, MariaDB 10.11 started, schema 3.0 and patches 3.1 to 3.4 installed (zero, one, two, zero, zero errors per patch file), one Live Data collection with GUID source `catalogNumber` created through the real metadata page.

| Test | Result |
|---|---|
| Archive of two new records through `upload()` | "Records to be updated: 0", "New records: 2", both inserted |
| `upload(dry=True)` of a file for an existing catalog number | The report read "Records to be updated: 1 Caution: incoming records will replace existing records" and the record was unchanged afterwards (a dry run writes nothing) |
| A file of only `id` and `catalogNumber` over a record that had a name and a locality | Both emptied (absent columns are emptied) |
| The same with "Match on Catalog Number" unticked | The report warned "Records matching on catalog number that will be appended: 1" and "This will result in records with duplicate catalog numbers", then inserted 0. The row id equalled an existing record's `dbpk`, and the unique key on `(collid, dbpk)` stopped the insert. This is narrower than the notes' result of a second record, which had a new row id. |

One defect in the harness copy was found and fixed on the way: `setup.sh` carried `set -e`, and `grep -c ERROR` exits 1 when it counts zero errors, so the script stopped after the schema step. The setup now continues.

### Measured by earlier sessions, carried in

Dates are the days the runs were made, on Symbiota commit 4491b791c with MariaDB 10.11.

| Date | What | Where it is used |
|---|---|---|
| 2026-11-20 | Archive import into Live Data collections: identifications meeting existing ones (tests A1 to A8), matching and keys (B1 to B4), other fields (C1 to C4), and the spreadsheet and skeletal upload (D1 to D8), including Extended Data Import (D7) | [writing](references/writing.md), [hazards](references/hazards.md), [identity](references/identity.md) |
| 2026-11-20 | A synthetic store of 32 specimens imported through the real pages into a collection holding four other records, read back cell by cell; a second import; the association load; the export | [writing](references/writing.md), [hazards](references/hazards.md#smaller-hazards) |
| 2026-11-21 | A rehearsal with 9,452 copied real records and an upload of 8,085 new ones: dry run, transfer, associations, repeat, export, staging behaviour, purge of old staged rows | [writing](references/writing.md#before-the-transfer), [decisions](references/decisions.md) |
| 2026-11-22 | Updating associations already on records: the matching rule with the update box ticked and unticked, blank names, changed addresses, Batch Delete | [writing](references/writing.md#extended-data-import-for-associations), [decisions](references/decisions.md#i-want-to-update-host-plants) |
| 2026-11-23 | A round trip: download, upload unchanged, compare every table, on 9,452 copied records plus 32 invented ones. Seven routes. Public API samples of 300 records at two offsets per collection (by the notes' author) | [hazards](references/hazards.md#a-round-trip-through-the-download), [ecdysis](references/ecdysis.md) |

The notes of these runs live outside any repository and will be deleted. What matters from them is in the reference files. The helper scripts and the setup were copied into [harness/](harness/). The probe-by-probe diffs of the round trip were summarised in [hazards](references/hazards.md#a-round-trip-through-the-download) and not kept.

### Disagreements found between sources, and which the skill follows

| Matter | Sources | Followed |
|---|---|---|
| Whether Symbiota matches a re-upload on the archive's row id by default | Beeline's plan of 2026-11-20 says it does. The test of the same day says a Live Data collection never matches or updates on `dbpk`. | The test |
| Whether the archive import can build associations | Beeline's bead notes of 2026-11-18 say it can, from `associatedOccurrence` columns. The test of 2026-11-20 found the code commented out and the load failing. | The test |
| Whether "send only the fields you own" is possible | The notes of 2026-11-18 say so. The test says every unsent column is emptied. | The test |
| Whether a skeletal upload leaves identifications alone | The test of 2026-11-20 says it did. The round trip of 2026-11-23 shows it rewrote identification rows. | Both are stated, and the cause is not found |
| How many current identifications a spreadsheet upload rewrites | 332 (bead notes, 2026-11-20) against the per-column counts of 2026-11-23 | Both are stated |
| Whether an unchanged re-upload moves `dateLastModified` | It did not in one run and did in three | Stated as varying, with the likely cause |
| Delimiter of identification files | The signed-in download's `meta.xml` says tab and the files are comma-separated. The published archive's says comma and is. | Both |
| Number of records in collection 164 | 106,870 (July 2026), 111,253 (2026-11-21), 111,251 (2026-11-23) | The latest, dated |
