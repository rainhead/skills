# Writing to a Symbiota portal

Open this before preparing or running an upload, or when choosing between the routes. Standing marks are defined in [SKILL.md](../SKILL.md#version-and-how-claims-are-marked). Abbreviations for source files, all under `classes/` at commit 4491b791c: SUB is `SpecUploadBase.php`, SUD is `SpecUploadDwca.php`, SUF is `SpecUploadFile.php`. Everything here was measured on a Live Data collection ([identity.md](identity.md#collections-and-datasets)).

**What to do:** pick the route from [decisions.md](decisions.md), then read that route's section here and the matching rows of [hazards.md](hazards.md). Whichever route you use, a record that the file matches is rewritten with every column the file stages.

## The routes

| Route | The page, as the screen names it | Matches a record by | On a matched record | Identifications |
|---|---|---|---|---|
| DwC-Archive Import | "Manual DwC-Archive Import" (upload type 6) | catalog number, if ticked | every staged column is written; absent and blank ones become empty | added from the identification file; the old current flag is never cleared |
| URL or IPT import | "IPT/DwC-A Provider Import" (type 8), and the command-line handler | the same, with switches given as arguments | the same | the same, if switched on |
| Spreadsheet upload | "Delimited Text File Import" (type 3) | catalog number, if ticked | the same | **the current identification is rewritten in place** |
| Skeletal upload | "Skeletal File Import" (type 7) | the identifier chosen on the page | only empty fields are filled | see [below](#skeletal-upload) |
| Restore from backup | `restorebackup.php` (type 10) | not examined in detail | see [below](#restore-from-backup) | rows were added |
| Extended Data Import | "Extended Data Importer" (`importextended.php`) | catalog number, `occurrenceID`, `occid` or other catalog numbers | adds or updates association rows only | none |
| The record editor | `collections/editor/occurrenceeditor.php` | one record at a time | the editor's own rules | clears the old current flag |
| The API | `api/v2/occurrence` and others | none for create. The skeletal route takes a chosen identifier. | create, or fill empty fields. No update or delete of an occurrence. | none |

The pages are reached from the collection's management menu. The pages in order for an upload route: `specuploadmanagement.php` (profiles), `specuploadmap.php` ("Analyze File" and the field mapping), `specuploadprocessor.php` ("Start Upload", then the "Pending Data Transfer Report" and its "Transfer Records to Central Specimen Table" button).

## How records are matched

**In a Live Data collection only catalog number matches**, and only if "Match on Catalog Number" is ticked (SUB 612 to 625; measured 2026-11-20). The DwC-Archive page ticks it by default (`specuploadmap.php` 449, read by Beeline). The scheduled handler does not: it takes the switch as an argument and defaults to off. Unticked, a row whose catalog number already exists is inserted as a **second record** with the same catalog number, the existing record is untouched, and its identifications gain a second current row (measured 2026-11-20). The report warns: "Records matching on catalog number that will be appended", "This will result in records with duplicate catalog numbers" (SUB 815 to 846).

A row whose id equals the `dbpk` of an existing record is not inserted either: with matching unticked, the report warned of duplicate catalog numbers and then inserted 0, because a unique key on `(collid, dbpk)` stopped the insert (reproduced 2026-11-23 on the harness in [local-test.md](local-test.md)). A row with a new id and an existing catalog number is inserted as a duplicate.

Matching on `otherCatalogNumbers` is a second switch. It is exact text equality, and it overwrites the stored `catalogNumber` (measured 2026-11-20). Matching on `dbpk` never updates in a Live Data collection ([identity.md](identity.md#the-identifiers)).

## Before the transfer

**Nothing is written to the collection until you press "Transfer Records to Central Specimen Table".** "Start Upload" only stages rows in two working tables. Stopping at the report changed nothing in the collection, so it is a dry run (measured 2026-11-20 and again 2026-11-21 against 9,452 real-shaped records, hashed before and after).

The report reads "Occurrences pending transfer: N", "Records to be updated: N" with "Caution: incoming records will replace existing records" when N is not zero, "New records: N", and "Identification history count: M". The text is identical for a file that changes nothing and a file that changes many records (measured 2026-11-23): it counts, it does not list. For a new-records-only file the report must read "Records to be updated: 0" and "New records" equal to the number of rows you meant to add.

Four traps in staging:
- **The transfer writes whatever is staged for the collection at that moment**, not the file the report page was shown for (measured 2026-11-21: a transfer from a stale form in a fresh session wrote the staged data). Do not use a report page left open from earlier.
- **The next upload to the collection replaces the staged one** (SUB 562 to 572, measured 2026-11-21: staging held 100 rows after a 100-row file, not 8,185). So a second person's upload changes what the first person's transfer writes. One person at a time.
- **Staged rows older than three days are purged** from every collection when any transfer runs (SUB 1820 to 1827, measured 2026-11-21).
- **Staged data is invisible** to visitors, editors and the exporter (measured 2026-11-21).

A transfer of 8,085 new records took about 12 seconds locally.

## DwC-Archive import

Page settings that matter: "Match on Catalog Number", "Import Identification History", the image import, and "Version data changes" (ticked: each changed field of a matched record gets an edit row; unticked: none; measured 2026-11-20).

**Mapping.** The mapping page reads each header of the archive's `meta.xml` as the last part of the term's address (SUD 273 to 276), lower-cases it, drops `_ . ( )` and spaces, applies a small translation map and maps it to the staging column of that name (SUB 344 to 440). So `scientificName` maps to `sciname` and `identificationIsCurrent` to `iscurrent` (SUB 389). A header with no target is left unmapped. On the associations page an unmapped header is silently ignored.

**The steps inside an import** (source, confirmed by every test):
1. SUD `uploadData` (475) stages the core rows in `uploadspectemp` and the identification rows in `uploaddetermtemp`.
2. SUB `cleanUpload` (593) matches staged rows to records (612 to 625 for a Live Data collection).
3. SUB `transferOccurrences` (955) updates every matched record with **all** columns that exist both in the staging table and in `omoccurrences` (976 to 989, `o.field = u.field`), then inserts the unmatched rows (1021). The only columns left out are `dbpk`, `observeruid`, `dateentered`, `initialtimestamp`, `occid` and `collid` (SUB `getTransferFieldArr`, 1159 to 1187).
4. SUB `transferIdentificationHistory` (1385 to 1442) adds identification rows.

Cleanup steps then also write records that are not in the file: in the round-trip test a record the file lacked still got `continent` and `tidInterpreted` filled (measured 2026-11-23).

**What the identification extension supplies, measured 2026-11-20.** Stored on the identification: `scientificName` (as `sciname`), `scientificNameAuthorship`, `identificationQualifier`, `identifiedBy`, `dateIdentified`, `identificationIsCurrent`, `identificationReferences`, `identificationRemarks`, `sourceIdentifier`. Read and then dropped: `verbatimIdentification`, `taxonRank`, `taxonRemarks`, `identificationVerificationStatus`. Not offered as a target at all: `identifiedByID`, `sex`, `caste`, `reproductiveCondition`. A row with no `scientificName` is skipped (SUB 2135 to 2140). Sex is read from the occurrence row only, and there is no caste column anywhere in the schema, so a project that needs caste has to keep it in a free column such as `reproductiveCondition`.

**How identifications meet existing ones** is in [hazards](hazards.md#the-name-comes-from-the-file-and-two-identifications-end-up-current). In short: the record's name comes from the file's occurrence row, the identification table gains rows, and nothing resets the old current flag. A new record with only identifications flagged not current ends up with no current name and a determination history (measured 2026-11-20).

**What keeps two identifications of one record apart.** The unique key is `(occid, dateIdentified, identifiedBy, sciname)` (`db_schema-3.0.sql` 1745). Of two rows agreeing on all four, only the first in file order survives, whatever their flags, qualifier, authorship or remarks. A different `dateIdentified` keeps both, even `2026-04-01T09:00` against `2026-04-01T09:05`, because the column is `varchar(45)`. A different `identifiedBy` keeps both (measured 2026-11-20). Three identifications that differed only by an accent, a capital or spacing in the determiner collapsed to the first, because the columns compare case- and accent-insensitively (measured 2026-11-20, in Beeline's synthetic test). Write identifications so that every one differs in one of the four fields, or merge the ones that agree before the file is written.

**A `sourceIdentifier` makes a re-import update in place.** An incoming identification whose `sourceIdentifier` already exists on the record is updated (name, determiner, date, qualifier, current flag, references, remarks) instead of added (SUB 1405 to 1418, measured 2026-11-20). Two rows with different source identifiers and no date still collapsed on the unique key. The column is marked deprecated in schema patch 3.1 and copied to `instanceID`, though this importer still reads and writes `sourceIdentifier`. A later version may drop it.

A re-import of the same archive duplicates nothing (measured 2026-11-20 and 2026-11-21: the report then read "Records to be updated: N Caution: incoming records will replace existing records" and "New records: 0").

## Spreadsheet upload

"Delimited Text File Import" (SUF `uploadData`, 96 and following) stages one row per file line from the **mapped columns only** (SUF 120 to 143), then runs the same matching and `transferOccurrences` as the archive route, and then SUB `setDeterminations` (1350 to 1383), which the archive route does not run.

Settings on the page: "Match on Catalog Number", "Match on Other Catalog Numbers", "Version data changes", an image link check, a processing status choice, and the choice between a general file and a skeletal file. There is no choice that skips or protects matched records. "Processing status": choosing "Unprocessed" writes that status into every record in the file, and choosing nothing sets `processingStatus` to empty on matched records (measured 2026-11-20).

**What it does to identifications, measured 2026-11-20 on a record with an older not-current and a newer current identification:**

| File | Occurrence row after | The current identification after |
|---|---|---|
| no name, determiner or date columns | name, determiner, date empty | rewritten in place to "undetermined" by "unknown" dated "s.d."; the real name is lost |
| the three columns present and blank | empty | rewritten to "undetermined", blank determiner and date |
| a different name, determiner and date | the file's | overwritten in place; the previous current identification is gone from the history |
| the same name, a different determiner and date | the file's | overwritten in place |
| the same name, determiner and date | unchanged | unchanged |
| equal to the older not-current identification | the older one | stays the newer one, because the update is blocked by the unique key, so the record and its current identification disagree |
| a record with no identification at all, and a name in the file | the name | one new current identification is inserted from the occurrence values |

Only the current row is touched, and only its name, determiner, date, family, authorship, qualifier, references and remarks (SUB 1353 to 1366, with defaults "undetermined", "unknown", "s.d.").

**In the round-trip test**, a native CSV from the search page uploaded as a general file changed real determinations: 9,322 `family` values, 135 `sciname` and authorship values, 101 `identifiedBy`, 98 `dateIdentified` and 27 qualifiers, and added 24 determination rows for test records (measured 2026-11-23). The notes of 2026-11-23 for this attempt also say 332 real current determinations were rewritten as measured on 2026-11-20. The two numbers do not match and were not reconciled: they come from different files and counted differently. Treat both as "some hundreds of current determinations are rewritten".

An "undetermined" identification by "unknown" is the mark this route leaves. Ecdysis's Washington collection carries thousands of them.

## Skeletal upload

The one built-in mode that does not overwrite. The update is `o.field = IFNULL(o.field, u.field)` (SUB 983 to 985): an empty field is filled and a filled one is kept. Measured 2026-11-20: a file with only `catalogNumber`, `locality` and `recordedBy` emptied nothing, and the file's locality did **not** replace the existing one; only empty fields were filled (`continent` and `countryCode` were filled by the geography step). So a skeletal upload cannot correct a wrong value. It can add a missing one.

Symbiota's help text says that where no record exists a new one is created and tagged unprocessed, while a general upload creates one without that tag. The catalog number is required (`specupload.en.php`, `NEED_CAT`, `SKEL_EXPLAIN_P2` to `P4`). Beeline saw a skeletal import create new records with `basisOfRecord` PreservedSpecimen and an "undetermined" identification by "unknown" dated "s.d." (measured 2026-11-20).

**Disagreement.** On 2026-11-20 a skeletal upload with a name on a record that already had one changed nothing, and one with no name columns changed nothing in the record or its identifications. On 2026-11-23 a skeletal upload of the full search-page CSV over 9,452 real-shaped records still changed identification rows: 9,322 `family` values and 9,416 `tidInterpreted` values on real records, and 135 `sciname`, 101 `identifiedBy` and 98 `dateIdentified` values, and the only occurrence column it changed on real records was `scientificNameAuthorship` on 46 of them. The determination changes are the same set that the general file upload made. The source runs `setDeterminations` for both file types ([above](#spreadsheet-upload)), which fits. The later run used a full export with a thesaurus loaded and the earlier one a small file. The reason was not isolated. Until it is, do not assume that a skeletal upload leaves identifications alone.

## Restore from backup

`collections/admin/restorebackup.php` takes the ZIP the administrator's backup page (`collbackup.php`) writes. Measured 2026-11-23 on the same 9,452 real-shaped records: it did not empty `processingStatus`, `storageLocation`, `labelProject`, `duplicateQuantity`, `observerUid`, `associatedTaxa` or `preparations` the way the archive import did. It wrote `occurrenceID` on every record (all 9,452) and added 190 determination rows to real records, and added 5 for test records. The cause of the added rows was not found. This route is the least destructive of the round trips for occurrence columns, and not clean.

## Extended Data Import for associations

The archive import builds no associations. The `associatedOccurrence:*` columns are not offered as mapping targets: the code is commented out (SUB 207 to 220, 448 to 451), and forcing the mapping by hand failed every row with an unknown-column error and loaded 0 records (measured 2026-11-20). `associatedTaxa` in a core file is plain stored text. Host plants and links go in through `collections/admin/importextended.php`, titled "Extended Data Importer".

**The page.** Choose the file, the import type "Associations", and the association type (the labels in the page: "Occurrence - External Link" is the `externalOccurrence` type; the others are resource, internal occurrence and observational), press "Initialize Import". On the mapping page choose the relationship and press "Import Data". The relationship is chosen once per file and is not a column. If the association type or the relationship is missing, nothing loads and no error is shown (`OccurrenceImport.php` 201 to 210, measured 2026-11-20).

**Headers that auto-map** (matched on the lower-cased header, `UtilitiesFileImport.php` `getTranslation`; spaces in headers are tolerated): the subject, `subject identifier: catalogNumber`, `subject identifier: otherCatalogNumbers`, `subject identifier: occurrenceID`, `subject identifier: occid`; then for every type `relationshipID`, `objectID`, `basisOfRecord`, `establishedDate`, `notes`, `accordingTo`; `resourceUrl` for resource and external occurrence; `verbatimSciname` for external occurrence and observational; object columns for internal occurrence (`OccurrenceImport.php` 440 to 485). A column such as `plant` is silently ignored: a file with only such a column loaded nothing.

**Matching the subject.** A row matches a record by `occid`, `occurrenceID` or `recordID`, `catalogNumber`, or `otherCatalogNumbers`, joined by OR (`OccurrenceImport.php` 364 to 400). One identifier is enough. A row that matches nothing is skipped ("SKIPPED: Unable to find record matching any provided identifier(s)"), and the page offers no "create new records" box for associations (a request carrying that field by hand created a blank record, measured 2026-11-20).

**The relationship list** the page offers comes from the controlled vocabulary table `ctcontrolvocabterm`: analyticalStandardOf, derivedFromSameIndividual, ecologicallyOccursWith, hasAnalyticalStandard, hasHost, hostOf, originatingSampleOf, partOf, sharesOriginatingSample, siblingOf, subsampleOf (`db_schema-3.0.sql` 3847; `OccurrenceImport.php` 570 to 591). "visits flowers of" and "visitsFlowersOf" are not offered. The server does not check the value: a form posted by hand with those strings stored and exported them as given (measured 2026-11-20). So only the drop-down enforces the list. A portal manager could add terms to the table, which was not tested.

**Running a file again**, measured 2026-11-20 and 2026-11-22:
- Without the box "Update or delete existing association with matching identifiers (subject identifier plus objectID or resourceUrl)" ticked, a row that repeats an existing association is rejected as a duplicate ("ERROR loading Occurrence Association: An error occurred while importing this occurrence; skipping row"), by unique keys on `(occid, relationship, resourceUrl)`, `(occid, verbatimSciname, associationType)` and `(occid, occidAssociate, relationship)`. Loading the same file twice adds nothing.
- With the box ticked, a row is matched to an existing association of the chosen type by `instanceID` if mapped, else `resourceUrl`, else `objectID` (`OccurrenceImport.php` 218 to 235), and the existing row is **updated in place** for the mapped columns only (`OmAssociations.php` 148 to 183). The plant name is replaced and the existing `objectID` is kept. The relationship is overwritten with the form's.
- **A blank plant name erases the existing name**, with the box ticked. Never send a blank where the portal holds a name.
- A changed observation URL cannot update a row ("Update failed: no existing association found"). Unticked, a new URL with a new or blank name adds a **second** row for the record.
- The record's own `associatedTaxa` text is not touched, so after a plant is renamed through this page it still holds the old plant.
- The relationship choice "Batch Delete", with the box ticked, deletes the association matched by catalog number plus `resourceUrl` or `objectID`. A file with only the catalog number does nothing and prints nothing. Unticked, the same file inserts a junk association with the relationship "DELETE". The record editor deletes one association at a time. No control deletes all of a record's associations.
- An update leaves `modifiedTimestamp` and `modifiedUid` empty on the association, and leaves the occurrence's `dateLastModified` unchanged (hashes equal).

**What the export then shows.** `resourceRelationships.tab` in the `dwc` schema is comma-separated with: `coreid`, `resourceRelationshipID`, `resourceID`, `relationshipOfResourceID`, `relatedResourceID`, `relationshipOfResource`, `relationshipAccordingTo`, `relationshipEstablishedDate`, `relationshipRemarks`, `scientificName`, `references`, `basisOfRecord`, `dynamicProperties`. `relatedResourceID` is the `objectID`, or the `resourceUrl` when there is no `objectID`. `scientificName` is `verbatimSciname`. `relationshipOfResourceID` is the chosen relationship's `relationshipID` (source `DwcArchiverResourceRelationship.php` 31 to 46; measured 2026-11-20). So an observation's address shows in the export only if the row had no `objectID`. A published archive (observed 2026-11-23) held `hasHost` on every row of its `resourceRelationships.csv`.

## The record editor

`collections/editor/occurrenceeditor.php` adds and edits one record at a time. Known from the tests, which used it only to make records: adding a determination through it clears the old current flag (`OccurrenceEditorDeterminations.php` 133 to 140), and it is the only place that does. Driving the editor to change an existing record in bulk was not tested ([not-tested](not-tested.md)).

## The API

Write routes, observed in the OpenAPI description 2026-11-23, all needing an `apiToken` tied to a user: `POST collection` (create a collection), `POST occurrence` (create), `POST occurrence/skeletal`, `POST media`, `PATCH` and `DELETE media/{id}`, `POST taxonomy`. The token is looked up in a user access table and the user's roles decide what is allowed (source, `Controller.php` 49 to 66).

**There is no route to update or delete an occurrence.** `PATCH` and `DELETE` for `occurrence/{id}` are commented out in `api/routes/web.php` (36 and 37), and the description lists none (observed 2026-11-23).

`POST occurrence/skeletal` fills only empty fields of a record located by `identifier` and `identifierTarget` (`CATALOGNUMBER`, `IDENTIFIERS`, `GUID`, `OCCID` or `NONE`; default `CATALOGNUMBER`). If several records match, only the first is filled. If none match, a new skeletal record is created and tagged `unprocessed` unless `processingStatus` is given, and a catalog number is then required. The fields it accepts are `catalogNumber`, `sciname`, `scientificNameAuthorship`, `family`, `recordedBy`, `recordNumber`, `eventDate`, `eventDate2`, `country`, `stateProvince`, `county` and `processingStatus`; empty values and other fields are dropped (source, `OccurrenceController.php` 1202 to 1230, and the OpenAPI text).

The Laravel API was not run, so none of this is measured. How a token is issued to a user was not looked up.

## A scheduled fetch from a URL

`collections/admin/uploadhandler.php`, run from the command line on the portal server (cron), runs a saved upload profile that holds a URL to a DwC-Archive ZIP or a folder (source, header comment). Arguments in order: `collid`, `uspid` (the profile), `importImages` (default 1), `importIdentificationHistory` (default 0), `matchCatalogNumber` (default 0), `matchOtherCatalogNumbers` (default 0). Measured 2026-11-20:
- It works unattended, with no session, and logs to `content/logs/occurImport/scheduledHarvests_<date>.log`.
- The profile stores only the URL and the field mapping. **The switches are arguments, not part of the profile, and the defaults make duplicate records and skip identifications:** with only the collection and profile ids, an existing record was not matched, a duplicate with the same catalog number was created, and identifications were skipped. Adding `0 1 1 0` after the two ids (images off, identifications on, catalog matching on, other catalog numbers off) matched the existing record, inserted the new one and added identifications.
- It fetches with PHP `copy()` and no headers (SUD 52), so `allow_url_fopen` must be on and the URL must carry any secret in itself.
- **When the URL returns 404 it exits 0.** PHP prints a `copy()` warning, the log says "ERROR uploading file" and "Malformed DWCA", staging is cleared and nothing changes. Check the log, not the exit status.
- It runs the whole import without a pre-transfer report. Everything in [hazards.md](hazards.md) applies to every night's run.

Whoever runs the portal has to schedule it. A scheduled import over records people also edit in the portal overwrites their edits, so the idea needs the owner of the data to agree who edits where.
