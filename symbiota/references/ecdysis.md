# Ecdysis

Open this when you work with https://ecdysis.org in particular: its version and hosting, its collections, how the signed-in download is made, what was sampled from its API, and the hand-made upload files of the Washington Bee Atlas. Everything general about Symbiota is in the other reference files. Standing marks are defined in [SKILL.md](../SKILL.md#version-and-how-claims-are-marked). "Observed" means an unauthenticated request I made on 2026-11-23, one at a time with a pause between them, unless a line says another source.

Beeline, the project these facts were gathered for, keeps its own design (which specimens it uploads, its tables, its pages) in https://github.com/rainhead/beeline/blob/main/docs/architecture/the-upload-to-ecdysis.md. This file does not repeat it.

## What it is

Ecdysis calls itself "a portal for live-data arthropod collections" and "for live-managing arthropod occurrence data". Its home page says it offers record editing and batch tools, loans, labels, georeferencing, a community taxonomy, and publishing to GBIF, iDigBio and Bionomia (observed). It is a Symbiota portal.

- **Version.** `GET https://ecdysis.org/api/v2/installation/status` answered `symbiotaVersion` 3.4.17 and `apiVersion` 2.0 (observed). The skill's measurements were made on 3.4.17, so they apply as far as the portal runs unmodified code, which was not checked.
- **API description.** `https://ecdysis.org/api/docs` is the OpenAPI JSON and `https://ecdysis.org/api/v2/documentation` its viewer. The description's contact is the "Symbiota Support Hub Team" (observed).
- **Hosting.** The portal's address resolved to 129.237.92.69, which the ARIN registry lists under the University of Kansas (observed by DNS and an RDAP lookup). The home page does not say who hosts the portal. Its contacts page lists a steering committee at several universities.
- **Source and docs.** https://github.com/Symbiota/Symbiota; the portal runs the upstream software, so a local copy of the same version is a fair test ([local-test](local-test.md)).

## The two collections and dataset 44

Observed on 2026-11-23 through `api/v2/collection/<collid>` and `api/v2/occurrence`:

| | British Columbia Bee Atlas | Washington State University collection |
|---|---|---|
| `collid` | 196 | 164 |
| Institution and collection codes | `NBSBC`, `BCBA` | `WSU`, `WSUC` |
| Management type | Live Data | Live Data |
| Records (`count`) | 9,452 | 111,251 |
| Edits in the public feed (`type=internal`; `type=external` was empty) | 34,260 | 474,857 |
| Published archive | `https://ecdysis.org/content/dwca/NBSBC-BCBA_DwC-A.zip` (1,513,787 bytes, last modified 2026-11-03) | `https://ecdysis.org/content/dwca/WSU-WSUC_DwC-A.zip` (14,512,834 bytes, last modified 2026-11-03) |
| Rights shown on the collection record | CC BY-NC 4.0 | CC BY-NC 4.0 |

**Washington's bee atlas records are dataset 44 within collection 164**, which other collections' specimens share. `datasetID=44` alone and `collid=164&datasetID=44` both counted 46,090 (observed). An earlier count of the collection was 106,870 (beeatlas, July 2026), then 111,253 (Beeline, 2026-11-21), then 111,251 today, so counts move in both directions. An upload adds no record to a dataset ([identity](identity.md#collections-and-datasets)), so records uploaded later are not in dataset 44. Beeline reads Washington only as dataset 44 today. Its plan to read the collection by catalog prefix is open (bead beeline-8dx9.13).

**Catalog numbers carry a prefix per atlas**: `WSDA_` then the label number for Washington's, `BCBA_` then the label number for British Columbia's. Symbiota's catalog number is at most 32 characters. Twelve old Washington catalog numbers are longer, and one repeats (Beeline's notes).

**GUID source, by what each collection publishes** ([identity](identity.md#what-the-guid-source-setting-decides)). The collection records do not show the setting, so it is inferred:
- **British Columbia: `catalogNumber`.** Every one of the 9,374 rows of the published archive (generated 2026-11-03) had `occurrenceID` equal to `catalogNumber`, and the API's stored `occurrenceID` was empty on the record sampled (observed). Beeline's decision of 2026-11-21 is to ask for a change to Symbiota UUIDs, after a list of old and new identifiers goes to GBIF (bead beeline-8dx9.14). Whether that has happened is not known: read the published archive again before relying on this.
- **Washington (collection 164): Symbiota's own UUID.** The record sampled through the API had `occurrenceID` equal to `recordID`, a 36-character UUID (observed). Beeline measured 46,090 of 46,090 records of dataset 44 with a UUID in the July 2026 archive (its notes). Changing the setting would affect every record of the shared collection.

Both collections hold their identifications in the same table. The Washington archive of July 2026 held 87,205 identifications over 46,090 records, one to five each, exactly one flagged current (532 records have none, being undetermined). `dateIdentified` was "s.d." on 57,008, a bare year on 30,124, a full date on 17 (a column slip on 56). `identificationQualifier` is free text. These are Beeline's counts, 2026-09-26.

## The signed-in download, as Beeline uses it

The general procedure is in [reading.md](reading.md#the-signed-in-download). What is particular to Ecdysis:
- The download needs an Ecdysis login. An anonymous request answers 401 (beeatlas, since 2026-06-24). Beeline keeps the login in its host's secrets and never logs it.
- It is scoped by `db=<collid>` for a collection read whole (British Columbia's 196) or `datasetid=44` for Washington's dataset.
- Ecdysis builds the ZIP on request: about two minutes for dataset 44.
- Beeline reads each collection nightly at 3am Pacific. It asks the API first for the total and the count modified since a day before the last download, and downloads only if either moved (collection 196 has been read every night since 2026-11-17). A button forces a download, because the probe misses a second edit to a record already inside the day's window.
- British Columbia's ZIP on 2026-11-20 was 1,015,385 bytes with 9,452 occurrence rows.
- The ZIP's identification file is comma-separated against a `meta.xml` that says tab, so Beeline and beeatlas read the delimiter off the header.

## What was sampled from the API on 2026-11-23

My own requests, all unauthenticated:
- `api/v2/installation/status`, `api/docs`, `api/v2/documentation`, `api/v2/collection/196` and `/164`, the home page, the contacts page.
- `api/v2/occurrence?collid=196&limit=1`, `?collid=164&datasetID=44&limit=1`, `?datasetID=44&limit=1`, `?collid=164&limit=1`. Counts as above. Each result carried `processingStatus` and `recordSecurity`.
- `api/v2/occurrence?collid=196&dateLastModifiedMin=2026-11-22&limit=1` answered HTTP 500. The same with `dateLastModifiedMax=2999-01-01` answered 200 with a count of 0 and `endOfRecords` false.
- `api/v2/occurrence/annotation?collid=<196 or 164>&type=<internal or external>&limit=2`. Counts as above. The two oldest edits of collection 196 were dated 2025-09-29 and 2025-09-30.
- `collections/individual/index.php?guid=<recordID>` answered 200.
- The two published archives: headers only for both, and one full download of British Columbia's, to read its `meta.xml` and column headers. Its `meta.xml` declares comma-separated files and the files are comma-separated, with `resourceRelationships.csv` holding `hasHost` on every row.

Sampled by the author of bead beeline-8dx9.17 on the same day and not repeated by me (300 records at each of two offsets per collection): British Columbia's records carry `processingStatus` (filled on all 300 of the first sample and on none of the second), which the signed-in download lacks. Washington's `associatedTaxa` starts with a double quote on every filled record sampled (455 of 600). So a round trip through the download would empty the first and strip the second ([hazards](hazards.md#a-round-trip-through-the-download)).

What was not asked: any request that needs a sign-in, and any write.

The records in Ecdysis's Washington collection include 4,935 from 2025 whose identification is "undetermined" by "unknown". They look like the work of the spreadsheet upload route on new records (Beeline's notes, 2026-11-20). That is the mark [writing.md](writing.md#spreadsheet-upload) describes.

## The Washington upload files

Joel Gardner, at Washington State University, prepares the Washington Bee Atlas's upload files by hand and uploads them to Ecdysis. Beeline read his 2025 files (sent 2026-11-18) and wrote a column-by-column account of them on 2026-11-20 (https://github.com/rainhead/beeline/blob/main/docs/research/ecdysis-upload-files.md). In summary, counts only:

- **The input** is the old Beeline's export: 60 columns, 29,954 rows. **The specimen upload** is a spreadsheet of 33 columns and the same rows. **The associations upload** has 7 columns and 25,845 rows, one for each specimen that has an iNaturalist observation. What reaches Ecdysis (the sheet itself or a CSV saved from it, and in what encoding) is not known.
- **The specimen upload's headers:** `catalogNumber`, `recordedBy`, `fieldNumber`, `day`, `month`, `year`, `verbatimEventDate`, `eventDate2`, `country`, `stateProvince`, `county`, `locality`, `municipality`, `habitat`, `verbatimCoordinates`, `verbatimElevation`, `minimumElevationInMeters`, `decimalLatitude`, `decimalLongitude`, `coordinateUncertaintyInMeters`, `geodeticDatum`, `georeferenceSource`, `samplingProtocol`, `relationshipOfResource`, `associationType`, `relatedResourceID`, `relationshipRemarks`, `associatedTaxa`, `url`, `lifeStage`, `preparations`, `labelproject`, `individualCount`. It has no scientific name, `identifiedBy`, `sex`, `occurrenceID`, `disposition` or remarks column, and none of the input's identification columns hold anything.
- **Fixed values he writes:** the country and the state spelled out, `WGS84`, "label" as the georeference source, life stage "adult", preparations "pinned", the program's name in `labelproject`, individual count 1, `hasHost` and "Occurrence - External Link" as the association's relationship and type.
- **Catalog number** is `WSDA_` plus the label number. **`fieldNumber`** is the sample number, a dot, and the specimen number, written as a number, so 1.10 reads 1.1: 2,257 rows share a value with another specimen. **`verbatimCoordinates`** holds the label's locality, because (his sheet says) Ecdysis has no verbatim locality field.
- **By hand:** `locality` is rewritten (abbreviations expanded, a nearest town replaced by a park or refuge, or "near <town>"): 87.8 percent of rows differ from the input. `municipality` is filled on 10.6 percent, `recordedBy` corrected on 6.4 percent.
- **`associatedTaxa`:** his sheet says quotes must be replaced by the word QUOTE during upload or they are dropped, and he batch-edits them back afterwards. That matches the measured loss of a leading double quote ([hazards](hazards.md#smaller-hazards)). The sheet says the relationship word comes from the input ("visits flowers of"), but all 17,654 filled cells use `host`.
- **Host plants:** hosts named only to genus are dropped (5,942 of the 25,845 association rows), and 2,249 more have no genus at all, so 8,191 associations carry no plant name.
- **Associations are loaded after the specimens:** he uploads the specimens, downloads them to get each `occurrenceID`, pastes those into the associations file, and loads it through "Extended Data Import". The page matches on catalog number alone, so the download is not needed (source, `OccurrenceImport.php` 364 to 383).
- **His method is safe only for specimens new to Ecdysis**, because it is a spreadsheet upload and the specimen file has no name columns ([hazards](hazards.md#spreadsheet-uploads-rewrite-the-current-identification)).

Where his description and his data disagree, measured by Beeline: `associatedTaxa` uses `host`, not the original word; genus-only hosts are dropped though the sheet says to use the genus; `relationshipOfResource` is "always hasHost" in the sheet and filled on 25,843 of 29,954 rows; `verbatimEventDate` is "no change" but 27,917 date cells became `M/D/YYYY` text; `recordedBy` is "no change" but 1,921 rows differ; `habitat` is in the data and not in the sheet.

Questions only he can answer, still open: whether the file uploaded is the sheet or a CSV and with what encoding; which columns he leaves unmapped; whether a field number such as 1.10 survives; whether he ever uploads again for specimens already in Ecdysis; which association type and relationship he picks; what drops the quotes; how he decides a point is inside a city; whether he changes records in Ecdysis after the upload; whether Ecdysis expands "USA" and "WA" itself.
