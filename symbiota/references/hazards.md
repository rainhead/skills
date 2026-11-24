# Hazards of uploading to a matched record

Open this when an upload could meet a record that already exists, to see what it will empty, rewrite or damage. Standing marks are defined in [SKILL.md](../SKILL.md#version-and-how-claims-are-marked). The routes are described in [writing.md](writing.md). All of it was measured on a local Symbiota 3.4.17 with a Live Data collection unless a line says otherwise.

**What to do:** if the file can meet an existing record, either do not send it ([decisions](decisions.md)), or send every column the portal holds for that record, taken from a read made just before, and expect the damage in the last section anyway.

## Absent and blank columns are emptied

An upload writes every column that exists both in its staging table and in the records table, so a column the file does not stage is written as empty (source, `SpecUploadBase.php` 987, `o.field = u.field`). The columns excluded from that are `dbpk`, `observeruid`, `dateentered`, `initialtimestamp`, `occid` and `collid`.

- **Measured 2026-11-20, archive route.** A file holding only an id and a catalog number, uploaded over a fully filled record, emptied: `otherCatalogNumbers`, `sciname`, authorship, `identifiedBy`, `dateIdentified`, `recordedBy`, `recordNumber`, `associatedCollectors`, every date part, `habitat`, remarks, `associatedTaxa`, `reproductiveCondition`, `establishmentMeans`, `lifeStage`, `sex`, `individualCount`, `preparations`, `country`, `stateProvince`, `county`, `locality`, coordinates, `disposition`, `language` and `processingStatus`. Kept: `catalogNumber`, `occurrenceID`, `recordID`, `basisOfRecord`, `dateEntered`.
- **Blank cells empty exactly like absent columns**, and the two cannot be told apart (measured 2026-11-20, archive and spreadsheet).
- **No setting prevents it.** Choosing no processing status does not keep the old one: `processingStatus` was set to empty on a record that held "reviewed" (measured 2026-11-20). Choosing a status writes it into every record in the file.
- The one exception is the skeletal route, which fills only empty fields ([writing](writing.md#skeletal-upload)).
- Blank handling differs in detail: `identifiedBy` and `dateIdentified` become empty strings and the other blank columns become null (source, `getSqlFragments` 2273 to 2375, measured 2026-11-20).

So an automated import and people editing the same records in the portal cannot both be safe. Whatever the file omits is erased, including what the portal's users entered.

## The name comes from the file, and two identifications end up current

Measured 2026-11-20 on a record made through the editor (current name A by one person, one identification row current), imported by archive with matching on catalog number:

| Test | Result |
|---|---|
| The file's occurrence row has name B and one identification flagged current | The record's name becomes B. The identification table keeps A current **and** adds B current. Two rows are current. |
| The same, B dated earlier than A | The same. No comparison of dates exists anywhere in the import (SUB 1385 to 1442 and 987). |
| The file's occurrence row has no name columns, and the identification is flagged **not** current | The record's name, determiner and date become **empty**. The identification table is untouched and gains the incoming row as not current. |
| The same, flagged current | The record takes the incoming name; both rows are current. A staged row is filled from an incoming current identification only when its name, determiner and date are all empty (SUB 774 to 780). |
| Name columns present and blank | Name empty, determiner and date empty strings. |
| A record with no identification, receiving only not-current ones | No current identification, no name on the record. The page shows "Determination History" and no name line. |
| After an editor adds a newer current name C, the old archive is imported again | The record's name goes **back** to the archive's. The identification table keeps C current. Record and history disagree. With a `sourceIdentifier` on the archive's identification, that row flips back to current as well, leaving two current. |

Why: the record's columns come from the core row (SUB 987), identification rows are inserted with their own flag copied and no other row is cleared (SUB 1426 to 1434). The portal's editor clears the old flag (`OccurrenceEditorDeterminations.php` 133 to 140). The importer does not.

**What to do.** Do not send a file for existing records at all: the table above shows that a row with no name, and a not-current identification, empties the existing record's name, determiner and date, so leaving the name out does not preserve it. If you must, send a complete current row for every record, with the name, determiner and date taken from a read made moments earlier, and send identifications that each differ in name, determiner or date from the others. A volunteer's identification sent as not current to a record with no other one leaves the record with no name.

## Spreadsheet uploads rewrite the current identification

The general file and skeletal routes run `setDeterminations` (SUB 1350 to 1383), which sets the current identification's name, determiner and date from the record's own columns, defaulting to "undetermined", "unknown" and "s.d.". A file with no name columns turned an expert's current identification into "undetermined" by "unknown" (measured 2026-11-20). A file with a different name overwrote it in place with no history of the earlier one. Table and counts are in [writing.md](writing.md#spreadsheet-upload).

The archive route does not do this ([writing](writing.md#dwc-archive-import)).

## A round trip through the download

The tempting method is to download a collection, change some cells, and upload the file. Measured 2026-11-23 on a local collection holding 9,452 copied real records plus 32 invented records that fill every column and exercise formats, signed in as a collection administrator. Every route was run against a restored copy of the same baseline.

| Route | What changed on the real records | What the invented records show |
|---|---|---|
| The download (`schema=symbiota`, tab, ZIP) imported by DwC-Archive Import with "Match on Catalog Number", identification history ticked or not, delimiter repaired or not | Nothing except `scientificNameAuthorship` from empty to an empty string on 46, and `dateLastModified` on all 9,452. Identifications, associations, identifiers and comments untouched. A second round trip changed nothing more. Changing `occurrenceRemarks` on 105 records changed exactly those cells. | Every column the download lacks is emptied (below). |
| The same download with `schema=dwc` | As above | In addition `associatedCollectors`, `cultivationStatus`, `eventDate2`, `recordSecurity` and `securityReason` are emptied |
| The search-page CSV uploaded as a general file | Current identifications rewritten: `family` on 9,322, `sciname` and authorship on 135, `identifiedBy` on 101, `dateIdentified` on 98, qualifier on 27 | 24 identification rows added |
| The same file as a skeletal upload | The same determination changes. Occurrence rows changed only in `scientificNameAuthorship` on 46. | |
| The collection menu's "Data Exporter" CSV and the administrator backup CSV, as a general file | As the search-page CSV | |
| The administrator backup ZIP through "Restore from backup" | `occurrenceID` written on all 9,452. 190 determination rows added to real records. | 5 added |

**The columns a download lacks are emptied on every record that is re-uploaded**: `processingStatus`, `observerUid`, `storageLocation`, `labelProject`, `duplicateQuantity`, `dynamicProperties`, `fieldNotes`, `samplingEffort`, `organismID`, `parentLocationID`, `footprintWKT`, `georeferencedDate`, `previousIdentifications` and others. `institutionCode` and `collectionCode` are unmapped on import.

**Real-collection check.** The API shows `processingStatus` filled on real records of one Ecdysis collection, and a leading double quote on `associatedTaxa` of one Ecdysis collection's filled records ([ecdysis.md](ecdysis.md#what-was-sampled-from-the-api-on-2026-11-23)). A round trip there would empty the first and strip the second.

**What a round trip needs to be faithful.** Without a taxonomic thesaurus in the local copy, a download's `genus`, `specificEpithet` and `taxonRank` are blank, and the round trip then wipes them from the copy: the first run of the test had no thesaurus and was discarded for that reason ([local-test](local-test.md#what-the-copy-needs-to-be-faithful)).

**The pre-transfer report cannot tell you.** It reads the same for an unchanged file and a file with changes (measured 2026-11-23).

## What runs on every transfer

**The file's own rows are not the only thing a transfer writes.** After the rows are written, the transfer ends with `finalCleanup` (source, `SpecUploadBase.php` 1811 to 1875, called from `SpecUploadDwca.php` 723 and 940, `SpecUploadBase.php` 908 and `SpecUploadFile.php` 221, which are the archive, base and delimited-file transfers). It runs whether or not any record matched, so a file of only new records runs it too. In order:
- **Staging.** It sets the collection's `uploaddate` and deletes the collection's staged rows, and also deletes staged rows of any collection that are older than three days (measured 2026-11-21).
- **Temporary row ids.** It clears `dbpk` values that start with `SYMBDBPK-` in the collection.
- **General cleaning** (`OccurrenceMaintenance::generalOccurrenceCleaning`, source, `OccurrenceMaintenance.php` 31 and following). Most steps are limited to the collection: the taxon index (`tidInterpreted`), `family` and `sciname` fills, dates. The two steps that fill `countryCode` and `continent` have their collection filter commented out (lines 172 and 195), so they run over every collection of the portal.
- **Record security.** `protectRareSpecies` (482 and following) sets `recordSecurity` to 1 on records of a taxon the thesaurus marks sensitive when `securityReason` is empty, in the collection only.
- **Statistics.** `updateCollectionStatsFull` (599 and following) recomputes the collection's counts and stored statistics text.
- **Record UUIDs.** `populateGuids` fills `recordID` where it is empty. The call passes the collection, but the method takes no argument and `GuidManager::$collid` stays 0, so it covers every collection of the portal (source, `GuidManager.php` 39 and 64 to 65).

**What was measured.** With a file of only new records, a collection of 9,452 copied real records that had itself been loaded through these pages came out byte for byte identical, rows and identifications, after 8,085 new records were added (hashes, 2026-11-21). With a one-record file against a collection that had deliberate gaps, 15 other records changed ([next section](#an-import-of-one-record-changes-other-records-and-the-matched-one), 2026-11-23). Both fit the source: the cleanup changes a record only where it finds a gap, and the first collection had none. That is an inference. No new-records-only file was run against a collection with gaps, and a real portal's records may have them (a record of a sensitive taxon at security 0, a name the thesaurus lacked, a blank `recordID`).

**So promise only this:** the file does not overwrite existing records, and the cleanup that follows can still fill or set values on other records, in other collections for `recordID`, `countryCode` and `continent`. The edit history does not show it ([below](#an-import-of-one-record-changes-other-records-and-the-matched-one)). Compare a copy of the portal's records before and after on a local Symbiota ([local-test](local-test.md)) when the difference matters.

## An import of one record changes other records and the matched one

The belief that an import writes only the records in the file is wrong, because of the cleanup above. Measured 2026-11-23, with a file of one row (the portal's own downloaded row for one record, its locality changed), "Match on Catalog Number" ticked, identification history unticked, imported by the superuser into a collection of 300 records plus 9 probe records with deliberate gaps. Sixteen records changed, only one of them in the file.

**Other records, in the collection imported into:**
- **`recordSecurity` went from 0 to 1 on every record of a sensitive taxon** (the thesaurus marks the taxon, 8 records), and `securityReason` stayed empty on them. A record already at 1 stayed. A record of the same taxon in another collection did not change.
- `tidInterpreted` and `family` were filled on a record whose name had no thesaurus id.
- `recordID` was filled on a record that had none, and `continent` and `countryCode` on a record that lacked them. **These two fill steps are not limited to the collection imported into**: a record of another collection was filled too.
- `scientificNameAuthorship` went from null to an empty string on the 7 probe records that had null.
- `dateLastModified` moved on all 16.
- **The collection's statistics were recomputed**: the record and georeferenced counts and the stored statistics text changed (the count rose by 7 here only because the probes had been inserted by SQL, not through the portal). Another collection's statistics did not change.
- Not changed: other records' identifications and associations, the coordinate point table, the taxa.

**The matched record**, besides its own columns being rewritten: `observerUid` went from 1 to null and `processingStatus` from "reviewed" to null (neither is in the download), `genus` and `specificEpithet` were filled, `verbatimEventDate` went from null to a value the file carried, and a leading double quote in `associatedTaxa` was lost.

**What "Version data changes" logs.** Ticked, the import wrote 6 edit rows, all for the matched record, all with the importing user's `uid` and lowercase field names (`genus`, `specificepithet`, `verbatimeventdate`, `associatedtaxa`, `locality`, `modified`), and they show in the public edit feed. It did **not** log `observerUid` and `processingStatus` being emptied, nor any change to another record (`recordSecurity`, `tidInterpreted`, `recordID`, `continent` and the others). Unticked, no edit row was written at all (the table's checksum was identical). So the edit history cannot show what an import did to records outside the file, nor the emptied columns.

## Smaller hazards

| Hazard | What happens | Standing |
|---|---|---|
| A leading double quote in `associatedTaxa` | Stripped by an upload, but **kept by the record editor's save** ([writing](writing.md#traps)). A project that writes `"host":"<plant>"` loses the opening quote. One project replaced quotes by a placeholder word before uploading and batch-edited them back ([ecdysis.md](ecdysis.md#the-washington-upload-files)). | measured 2026-11-23 |
| Backslashes | Double on each round trip | measured 2026-11-23 |
| Tabs inside a value | Dropped | measured 2026-11-23 |
| `individualCount` of 0 | Becomes empty | measured 2026-11-23 |
| A year-only date | Becomes `YYYY-00-00` after a round trip: the symbiota download writes the parts as `-00` and the `dwc` schema drops them | measured 2026-11-23; source `DwcArchiverCore.php` 1599 to 1617 |
| A range in `eventDate` (`2026-06-01/2026-06-05`) | The first date is kept, `eventDate2` stays empty, `day` is set to 1, and the end date is lost. A separate column named `eventDate2` auto-maps and keeps it, with `endDayOfYear` set and `day` empty. A column named `endDate` is ignored unless you map it to `eventdate2` by hand. | measured 2026-11-20; source `OccurrenceUtil.php` 22 and following |
| Dates written `6/1/2026` or "June 1 2026" | Converted to ISO, and the original text goes into `verbatimEventDate` when that is empty | measured 2026-11-20 |
| Text normalisation on every field | Curly quotes become straight, an em dash becomes `-`, an ellipsis becomes `...`, runs of two or more white-space characters become one space, emoji, dingbats and the Miscellaneous Symbols block are deleted. An en dash and the euro sign survive. | measured 2026-11-20; source `SpecUploadBase.php` 2742 to 2757 |
| `disposition` | Column is `varchar(250)`: longer values are cut | measured 2026-11-20 |
| `occurrenceRemarks`, `sex`, `reproductiveCondition`, `associatedTaxa` | Stored as sent, case kept, no vocabulary check. Quotes, semicolons, tags and accents survive in remarks (354 characters tested). | measured 2026-11-20 |
| `processingStatus` | A chosen status is written to every record in the file | measured 2026-11-20 |
| `dateLastModified` | A changed record moves to the current time and its neighbours do not. Whether an **unchanged** re-upload moves it differs between runs. It did not in the first 2026-11-20 test, where the archive had no geography to refill. It moved every record in Beeline's synthetic test of the same day, where the update blanked `countryCode` and `continent` and then filled them again, and the blanking counts as a change. It moved all 9,452 records on 2026-11-23, where the update blanked `tidInterpreted` and the thesaurus step filled it again (read in the database's general log). A real change and a bump cannot be told apart by this column alone. | measured; source `db_schema-3.0.sql` 2231 (`ON UPDATE current_timestamp()`) |
| `dateEntered` against `dateLastModified` | `dateEntered` is written in the web server's time zone and `dateLastModified` in the database's. They differed by seven hours in the test because PHP's time zone setting was empty. | measured 2026-11-20; SUB 1022 uses PHP `date()` |
| A name the thesaurus lacks | `tidInterpreted` ends empty | measured 2026-11-23 |
| Cleanup steps | Run after every transfer and write records that are not in the file: `continent` and `tidInterpreted` appeared on a record the file did not contain ([what runs](#what-runs-on-every-transfer)) | measured 2026-11-23; source `SpecUploadBase.php` 1811 to 1875 |
| An edit history | Field-level for occurrence columns only, and only with "Version data changes" ticked, and only for the matched record's changed fields ([above](#an-import-of-one-record-changes-other-records-and-the-matched-one)). Identification rewrites are never versioned. | measured 2026-11-20 and 2026-11-23 |
| Staged upload | Replaced by the next upload to the collection. The transfer writes whatever is staged. Rows older than 3 days are purged. | [writing](writing.md#before-the-transfer) |
| Same catalog number twice | See [identity](identity.md#duplicates) | measured 2026-11-20 |
| An uploaded `occurrenceID` | Ignored unless the GUID source is `occurrenceId` | [identity](identity.md#what-the-guid-source-setting-decides) |
| A host plant on the associations page | A blank erases the existing name | [writing](writing.md#extended-data-import-for-associations) |
