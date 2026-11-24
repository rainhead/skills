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
| The record editor, posted by a program | `collections/editor/occurrenceeditor.php` | `occid`, one record per request | only the posted fields, each logged ([below](#the-record-editors-save-driven-by-a-program)) | adding one clears the old current flag and writes no edit row |
| The API | `api/v2/occurrence` and others | none for create. The skeletal route takes a chosen identifier. | create, or fill empty fields. No update or delete of an occurrence. | none |

The pages are reached from the collection's management menu. The pages in order for an upload route: `specuploadmanagement.php` (profiles), `specuploadmap.php` ("Analyze File" and the field mapping), `specuploadprocessor.php` ("Start Upload", then the "Pending Data Transfer Report" and its "Transfer Records to Central Specimen Table" button).

## How records are matched

**In a Live Data collection only catalog number matches**, and only if "Match on Catalog Number" is ticked (SUB 612 to 625; measured 2026-11-20). The DwC-Archive page ticks it by default (`specuploadmap.php` 449, read by Beeline). The scheduled handler does not: it takes the switch as an argument and defaults to off. Unticked, a row whose catalog number already exists is inserted as a **second record** with the same catalog number, the existing record is untouched, and its identifications gain a second current row (measured 2026-11-20). The report warns: "Records matching on catalog number that will be appended", "This will result in records with duplicate catalog numbers" (SUB 815 to 846).

A row whose id equals the `dbpk` of an existing record is not inserted either: with matching unticked, the report warned of duplicate catalog numbers and then inserted 0, because a unique key on `(collid, dbpk)` stopped the insert (reproduced 2026-11-23 on the harness in [local-test.md](local-test.md)). A row with a new id and an existing catalog number is inserted as a duplicate.

Matching on `otherCatalogNumbers` is a second switch. It is exact text equality, and it overwrites the stored `catalogNumber` (measured 2026-11-20). Matching on `dbpk` never updates in a Live Data collection ([identity.md](identity.md#the-identifiers)).

## Before the transfer

**On the portal's pages, nothing is written to the collection until you press "Transfer Records to Central Specimen Table".** "Start Upload" only stages rows in two working tables. The exception is the scheduled command-line import ([below](#a-scheduled-fetch-from-a-url)), which has no report and no pause and transfers in the same run. Stopping at the report changed nothing in the collection, so it is a dry run (measured 2026-11-20 and again 2026-11-21 against 9,452 real-shaped records, hashed before and after).

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
5. After the transfer, `finalCleanup` runs, whether or not a record matched. It also writes records that are not in the file: in the round-trip test a record the file lacked still got `continent` and `tidInterpreted` filled (measured 2026-11-23). The full list of its steps and what is known about each is in [hazards](hazards.md#what-runs-on-every-transfer).

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

## The record editor's save, driven by a program

The one route that changes a named field of an existing record and nothing else. Measured on 2026-11-23 on a local Symbiota 3.4.17 with 300 invented records, one request per change and every table compared by primary key before and after. The page that a person uses is `collections/editor/occurrenceeditor.php`. A program can post to it the same request the page's Save button posts. Source for the request: `occurrenceeditor.php` 164 and `OccurrenceEditorManager.php` 896 to 1075 (`editOccurrence`); the page's script `js/symb/collections.editor.main.js` fills the hidden field `editedfields`.

### The recipe

1. Sign in as for the download: `POST <portal>/profile/index.php` with `login`, `password`, `action=login`, and keep the session cookie ([reading](reading.md#the-signed-in-download)). There is no CSRF token and no lock token. A signed-out request is answered 302 to the sign-in page. A session lasts an hour (source, `config/symbbase.php` 12).
2. `POST <portal>/collections/editor/occurrenceeditor.php`, form-encoded, with exactly these fields: `occid` (the record), `collid` (the id of the collection that holds the record), `editedfields` (the names of the fields you send, each followed by a semicolon: `locality;`), `submitaction=saveOccurEdits`, and each field to change under its **lowercase** name (`locality=...`, `eventdate=...`). The fields are the columns of the records table. A request with these four plus one field changed that field and `dateLastModified` on that record and nothing else (measured).
3. Read the value back ([next section](#how-to-tell-that-a-save-happened)).

### How to tell that a save happened

The answer is always HTTP 200 and an editor page of about 120 KB, whatever happened. The message in it is not proof:
- `SUCCESS: edits submitted and activated` means the edit was applied. It is **also printed for an `occid` that does not exist**, which changes and logs nothing (measured with occid 99999). A missing `occid` prints no message.
- `Edits submitted, but not activated...` means the edit was held for review: the record is unchanged ([roles](#roles-and-review)).
- `ERROR: edits empty for occid #N` means `editedfields` was empty. Nothing changed.
- `ERROR: Sorry, you are not authorized to edit occurrences within this collection...` means the user has no right to edit there.

**Read the value back.** The response page is drawn from the database after the update, so its `occid` input names the record and its input for the field holds the stored value. Compare that with what you meant to store. Or read the record through the public API (`occurrence/<occid>`) afterwards. A record that another person has open shows "Record Locked!" and no form ([locks](#locks)), so a program that must read the form cannot rely on the response page for such a record.

### What a save writes

Measured on one field of one record, signed in as a collection administrator:
- The record's column, and `dateLastModified` (the database stamps it).
- One row in `omoccuredits` for each field that changed and was listed: `fieldName` as posted (lowercase), old and new value, `reviewStatus` 1, `appliedStatus` 1, `editType` 0, and the `uid` of the signed-in user. It shows in the public edit feed at once, with `recordID` null ([reading](reading.md#the-edit-feed)).
- A row in `omoccureditlocks` for the program's user and that record ([locks](#locks)), and `lastLoginDate` of the user.
- Nothing else: not the other records, not the identifications, associations, `sciname`, `tidInterpreted`, `family`, `recordSecurity`, `securityReason`, `processingStatus`, `observerUid`, or the collection's statistics. Twenty fields in one save wrote 20 edit rows and changed those 20 columns, three date-derived columns, `dateLastModified` and the coordinate point (below), and no other table.
- A change of `associatedTaxa` does not touch the association rows, and a change of `country` or `stateProvince` does not touch `countryCode` or `continent`.
- A change of `decimalLatitude` or `decimalLongitude` rewrites the record's row in `omoccurpoints` (a database trigger). The georeferencing columns, datum and uncertainty do not move.

A change is logged only if PHP's loose `!=` finds the old and the new value different (source, line 1021). `45.5` against a stored `45.500000` is not logged, though the value is written.

### Traps

- **Never send the whole form.** Re-sending every field that the page shows, with one changed and only that one listed, also wrote `occurrenceID` (empty became the record's `recordID`, because the page shows that value in the box) and `scientificNameAuthorship` (empty became null), with no edit row for either. The UPDATE sets every posted column that exists in the records table, except `observeruid` (source, line 1049). `editedfields` decides only what is logged. A whole form taken before another writer's change also puts back that writer's old value silently (measured on `habitat`).
- **A field posted but not listed is written and not logged** (measured with `habitat`).
- **A field listed but not posted is set to the string `0`** and logged (measured: `habitat` "meadow" became "0"; source, line 1015). List only what you send.
- **Text longer than the column is cut silently** (the UPDATE ignores the error). The edit row still holds the full text, so the log shows more than the record keeps. Measured limits: `recordedBy` 255, `country` 64, `samplingProtocol` 100, `fieldNumber` and `recordNumber` 45, and 65,535 for `locality` and `associatedTaxa`. Compare the value read back.
- **Whitespace is changed.** Leading and trailing spaces are trimmed, and any run of two or more white-space characters (spaces, tabs, newlines, a carriage return and newline) becomes one space (source, `OccurrenceEditorManager.php` 121). A single tab or single newline survives, a carriage return and newline pair does not.
- **Emoji are stored as `????`** (the database is `utf8mb3`), in the record and in the edit row.
- **An empty value is stored as null**, never as an empty string, and the edit row's new value is empty. To empty a field, post it empty and list it.
- **Everything else is stored byte for byte**, measured on 13 text fields: plain text, a leading double quote (an upload strips it, the editor keeps it, so `"host":"Salvia apiana"` in `associatedTaxa` survives), inner quotes, backslashes, accents, typographic quotes, en dash and CJK. A value exactly as long as the column was stored whole. 221 saves, 141 exact, and the 80 that were not each fell under a rule above.
- **Dates: send ISO `YYYY-MM-DD` and nothing else.** `eventDate` is a date column: `2025`, `2025-06`, `06/04/2025`, `abc` and `2025-02-30` were stored as `0000-00-00`. `2025-6-4` was stored as `2025-06-04` with `year`, `month` and `day` set to null. `2025-06-14 10:30` kept the date. Empty became null.
- **`eventDate` alone leaves `eventDate2` stale.** The year, month, day and day-of-year columns are recomputed from `eventDate`, `endDayOfYear` is reset to the start day, and an existing `eventDate2` stays as it was. Send both, or neither. With both sent, `day` is null, `month` is null if the months differ, `year` and `month` are null if the years differ. `eventDate2` alone changes nothing else, so the day-of-year columns stay stale. `verbatimEventDate` is separate text.
- **Numbers are coerced, not checked.** Coordinates are doubles (`45.500000` becomes 45.5, `abc` becomes 0, 100 and 12345678901 are accepted with no range check, empty becomes null). `coordinateUncertaintyInMeters` is an unsigned integer (45.5 becomes 46, -5 becomes 0, `abc` becomes 0). Elevations are integers (45.5 becomes 46, `abc` becomes 0, empty becomes null). Check the range yourself before you send.
- **`editedfields` listing only an unknown name** prints SUCCESS and logs nothing, yet the posted columns are still written (measured).

### Locks

Opening a record in the editor inserts a lock row for that person, valid for 900 seconds, and a person holds one lock at a time (source, `getLock`, `OccurrenceEditorManager.php` 2607). Measured on 2026-11-23:
- **The save does not look at locks.** While a collection editor had a record open, the program's save succeeded.
- **A person who has the record open later overwrites the program's change.** Their whole-form save wrote the old value of the field the program had changed, silently, and logged only the field they edited. The program cannot tell, and neither can they. The edit feed shows the person's edit, not the lost one.
- **Every program save leaves a lock** for the program's user on that record for up to 15 minutes. A person who opens the record in that time sees "Record Locked!" and no form. The lock is deleted when the program saves its next record.

So an edit by program belongs where nobody is editing the same records: tell the people, and read each record back after a delay if it matters.

### Roles and review

- **The least role that saves and applies is collection editor** on the collection (the same result as collection administrator: applied at once, the user's `uid` recorded). A superuser works too. No role is refused with the "not authorized" message. There is no role narrower than a collection. Dataset roles are not read by the editor (source). A general-observation collection lets a user edit the records they entered (source, not run).
- **A user with no role is refused unless the collection's `publicEdits` flag is 1**, and then the edit is logged with `appliedStatus` 0, the record is unchanged and the message says "not activated". Such edits show in the edit feed as not applied.
- **Taxon editors are held.** A user who is a taxon editor without a collection role is limited by taxon: a record of a family they edit was held (`appliedStatus` 0), a record of another family was refused, and geography is not checked (source, a TODO near `OccurrenceEditorManager.php` 2723). The page then stopped with a PHP fatal error (`occurrenceeditor.php` 1578, `in_array` on null) after the edit was logged. Never applied.
- **Record security is not touched.** A record with security 1 saved and applied, and its edit row was written. A record of a taxon that the thesaurus marks sensitive kept `recordSecurity` and `securityReason` unchanged, also when `stateProvince` was edited. The edit feed leaves out the first and includes the second ([reading](reading.md#the-edit-feed)).

### Speed

300 saves of one field, one session, one after another: 3.5 seconds in all, mean 12 ms, none slower than 18 ms, no slowdown across the run and the session stayed valid (measured locally, no network latency, one user). The editor code has no throttle (source, searched). A real portal is slower, and its owners can see the load: one request at a time, with a pause ([SKILL.md](../SKILL.md#rules-to-follow-first)).

### The editor's batch update

`collections/editor/occurrencetabledisplay.php`, the table view's "batch update" panel, changes one field on many records of one collection. The request carries `collid`, a query that selects records (for example `q_catalognumber=A,B,C`), `bufieldname`, `buoldvalue`, `bunewvalue` and `bumatch` (empty means the whole value, any value means any part). It writes one edit row per record (`editType` 1, applied, the user's `uid`) and runs `UPDATE omoccurrences SET <field> = <new> WHERE occid IN (...)`. Measured on 10 records with `country`: 10 records and 10 edit rows changed, and only `country` and `dateLastModified` moved, with no derived column, no lock and no other table. The values are escaped but **not trimmed or collapsed**, unlike the single-record save. The edits show in the edit feed. Read the records back afterwards as for the save.

### Adding an identification

`submitaction=submitDetermination` (with `occid`, `sciname`, `identifiedby`, `dateidentified`, `makecurrent=1`) adds an identification the way a person does. Measured on one record: **no `omoccuredits` row is written**, so the change is in neither the edit list nor the public edit feed. A new current row is added in `omoccurdeterminations` and the previous current row is set not current and kept. The record's `sciname`, `tidInterpreted` (from the thesaurus), `identifiedBy`, `dateIdentified` and `dateLastModified` change and `scientificNameAuthorship` goes from empty to null. `family` did not change, so a new name in another family leaves a stale family. Adding a determination through the editor clears the old current flag (`OccurrenceEditorDeterminations.php` 133 to 140), and no upload route does.

### What was not tested

See [not-tested](not-tested.md#the-record-editors-save).

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
