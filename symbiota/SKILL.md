---
name: symbiota
description: Work with a Symbiota collections portal, such as Ecdysis (ecdysis.org) or SEINet. Use before reading records from one (the public v2 API, the signed-in download, a published Darwin Core archive, the edit feed), before preparing or running any upload to one (DwC-Archive Import, spreadsheet or skeletal upload, Extended Data Import for associations, the API), when deciding how occurrenceID, catalog number or the GUID source setting behave, when identifications or host-plant associations must survive an upload, or when testing an import on a local Symbiota first.
---

# Symbiota portals

Symbiota is open-source PHP and MySQL software that runs specimen collection portals. Each portal is its own installation with its own version, collections and settings. A record that an upload matches is rewritten whole, and nothing in the portal compares what it holds with what you send, so most mistakes are made on the way in and cannot be undone from outside.

Ecdysis (https://ecdysis.org, entomological collections) is the one portal this skill has been measured against. Everything specific to it, including its collections and its hosting, is in [references/ecdysis.md](references/ecdysis.md). Everything else here is about Symbiota in general.

## Version, and how claims are marked

Every measurement here was made on a local Symbiota 3.4.17 (commit 4491b791c, PHP 8.2, MariaDB 10.11), the version Ecdysis reported on 2026-11-23. Another portal may run another version. Check with one request: `GET <portal>/api/v2/installation/status` returns `symbiotaVersion`. If it is not 3.4.17, treat the upload behaviour in these files as a hypothesis and re-measure on a local Symbiota of that version ([references/local-test.md](references/local-test.md)).

Each claim says how it is known:
- **measured**: run on a local Symbiota, with the date, and the rows read afterwards.
- **source**: read in the Symbiota source, with file and line at commit 4491b791c. Line numbers move between versions.
- **observed**: seen on a live portal with an unauthenticated request, with the date.

Source: https://github.com/Symbiota/Symbiota. A portal publishes its API description at `<portal>/api/docs` (OpenAPI) and a viewer at `<portal>/api/v2/documentation`.

## Where to look

| You are | Read |
|---|---|
| Reading records, counting them, asking what changed, downloading, or fetching the taxonomy | [references/reading.md](references/reading.md) |
| Matching records, or deciding what `occurrenceID`, `catalogNumber`, `recordID`, `occid`, collection or dataset mean | [references/identity.md](references/identity.md) |
| About to upload, or choosing between upload routes | [references/writing.md](references/writing.md) |
| Wondering what an upload will empty, rewrite or damage | [references/hazards.md](references/hazards.md) |
| Starting from a goal ("add records", "change one field", "update host plants", "what changed") | [references/decisions.md](references/decisions.md) |
| Unsure whether something was ever tested | [references/not-tested.md](references/not-tested.md) |
| Testing a question before it touches a real portal | [references/local-test.md](references/local-test.md) and the scripts in [harness/](harness/) |
| Working with Ecdysis in particular | [references/ecdysis.md](references/ecdysis.md) |
| Checking when and how a claim was verified | [CHANGES.md](CHANGES.md) |

## Rules to follow first

1. **Treat every upload that can match an existing record as destructive.** A matched record takes every column of the file. A column the file lacks, or leaves blank, becomes empty. The portal's own pages and the API offer no setting that protects a matched record except the skeletal route, which only fills empty fields ([hazards](references/hazards.md#absent-and-blank-columns-are-emptied)).
2. **Upload only records that are new to the portal**, with "Match on Catalog Number" ticked, so that a file of new catalog numbers changes nothing else. Prove the newness from a fresh read of the portal just before you build the file ([decisions](references/decisions.md#i-want-to-add-new-records)).
3. **Stop at the pending transfer report.** Nothing is written until you press the transfer button. The report says how many records will be updated and how many are new, and cannot say which ones. When you mean to add new records only, a count of updated records other than zero means stop ([writing](references/writing.md#before-the-transfer)).
4. **Read the portal before you write to it, and keep the read.** You need the catalog numbers it holds, its version, and the management type of the collection (`GET <portal>/api/v2/collection/<collid>`, field `managementType`).
5. **Rehearse on a local Symbiota** with a copy of the real records when an upload is new to you or the version differs ([local-test](references/local-test.md)).
6. **Keep credentials out of code, logs and files.** A signed-in download needs a login. Read it from the environment.
7. **Be gentle with someone else's server.** One request at a time, a pause between requests, and a User-Agent that names your project. A portal is run by a university, and the taxonomy export answered 429 with a retry-after header when it was fetched three times in a day.

## Quick start

Count the records of a collection, with no sign-in:

```
GET <portal>/api/v2/occurrence?collid=<collid>&limit=1
```

The `count` field of the answer is the total. `limit` is at most 300. Nothing else is needed for a count, and the same call with `datasetID=<id>` counts a dataset.

## Known gotchas

One line each. Entries marked **→** have the evidence in a reference file.

1. **An upload over a matched record empties every column the file lacks or leaves blank.** → [hazards](references/hazards.md#absent-and-blank-columns-are-emptied)
2. **Spreadsheet and skeletal uploads also rewrite the record's current identification in place**, turning a real one into "undetermined" by "unknown" when the file has no name columns. → [hazards](references/hazards.md#spreadsheet-uploads-rewrite-the-current-identification)
3. **The record's name always comes from the file's occurrence row, with no date comparison,** so an old file puts an old name back. → [hazards](references/hazards.md#the-name-comes-from-the-file-and-two-identifications-end-up-current)
4. **The archive import never clears the old current flag,** so two identifications are current after one arrives. → same section.
5. **In a live collection only catalog number matches**, and only when "Match on Catalog Number" is ticked. Unticked, a second record with the same catalog number is made. A scheduled run from the command line defaults to unticked. → [writing](references/writing.md#how-records-are-matched)
6. **An `occurrenceID` you send is stored only if the collection's GUID source is `occurrenceID`.** Otherwise it is ignored. → [identity](references/identity.md#what-the-guid-source-setting-decides)
7. **The signed-in download's identification file is comma-separated while its `meta.xml` says tab.** Imported as it is, no identifications load. → [reading](references/reading.md#the-signed-in-download)
8. **The signed-in download leaves out cultivated records and records with record security 5, and lacks `processingStatus`.** A round trip empties what it lacks. → [reading](references/reading.md#what-the-download-leaves-out)
9. **The v2 API answers 500 to `dateLastModifiedMin` without `dateLastModifiedMax`.** Pair them. → [reading](references/reading.md#counting-and-asking-what-changed)
10. **The archive import builds no associations.** Host plants and links go through the separate "Extended Data Import" page, whose relationship list is fixed. → [writing](references/writing.md#extended-data-import-for-associations)
11. **A range in `eventDate` loses its end date.** Send the end in a column named `eventDate2`. → [hazards](references/hazards.md#smaller-hazards)
12. **A leading double quote in `associatedTaxa`, tabs, backslashes, a zero count and a year-only date do not survive an upload unchanged.** → [hazards](references/hazards.md#smaller-hazards)
13. **A staged upload is replaced by the next upload to the collection, and the transfer writes whatever is staged at that moment,** not what the report page showed. One person at a time. → [writing](references/writing.md#before-the-transfer)
14. **The API has no route to update or delete an occurrence.** Its write routes create records or fill empty fields. → [writing](references/writing.md#the-api)
15. **A scheduled import exits 0 when its fetch fails.** → [writing](references/writing.md#a-scheduled-fetch-from-a-url)
16. **The edit feed is public and lists every edit, field by field.** Use it to tell whether a record changed since your read. → [reading](references/reading.md#the-edit-feed)

## Sources

- Symbiota source and docs: https://github.com/Symbiota/Symbiota. The measurements were made on commit 4491b791c.
- The portal's own API description: `<portal>/api/docs`.
- Darwin Core terms: https://dwc.tdwg.org/terms/. Symbiota's own terms (`eventDate2`, `identificationIsCurrent`, `labelProject`) live under https://symbiota.org/terms/.
- Beeline, a project that reads from and prepares uploads to Ecdysis, keeps its design in https://github.com/rainhead/beeline/blob/main/docs/architecture/the-upload-to-ecdysis.md. That file is about Beeline's own choices, which this skill does not repeat.
