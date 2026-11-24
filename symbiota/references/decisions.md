# Decision guide: from a goal to a route

Open this when you know what you want to happen to records on a portal and need the safest known route. Standing marks are defined in [SKILL.md](../SKILL.md#version-and-how-claims-are-marked). Each goal gives the route, the conditions it rests on, and what is still untested. The evidence is in [writing.md](writing.md) and [hazards.md](hazards.md). A route is "safest known" only for Symbiota 3.4.17 on a Live Data collection: check both ([SKILL.md](../SKILL.md#version-and-how-claims-are-marked)).

## I want to read records

- **A count, a sweep of public fields, or a check that something moved:** the v2 API, no sign-in ([reading](reading.md#the-public-v2-api)).
- **Everything, with identification history:** the signed-in download. Repair the identification file's delimiter before you read or upload it ([reading](reading.md#the-identification-file-does-not-match-its-metaxml)).
- **What an aggregator sees:** the collection's published archive.

## I want to add new records

**Route.** DwC-Archive Import of a file that holds only catalog numbers the portal does not have, with "Match on Catalog Number" and "Import Identification History" ticked, stopped at the "Pending Data Transfer Report". Measured: a file of only new catalog numbers changed nothing else (hashes over all existing rows and identifications were identical before and after, 2026-11-20), and a rehearsal added 8,085 records in about 12 seconds with every existing record and identification unchanged byte for byte (2026-11-21).

**Conditions, each from a measured hazard:**
1. **Prove the records are new from a fresh read.** Read the portal's catalog numbers immediately before building the file, from the whole collection and not a dataset, and compare without regard to case. Count a portal record you could not match to one of your own as present. Refuse to build the file if the read is stale or failed. A catalog number that already exists makes the upload rewrite that record ([identity](identity.md#the-identifiers)).
2. **Upload each file once, the day you build it, and discard it.** A second upload meets the records the first created, after experts may have named them. The archive route puts the file's name (empty, if you sent none) back on the record, and the spreadsheet route replaces the current identification with "undetermined". Nothing in Symbiota enforces this: date the file and say so.
3. **Read the report.** "Records to be updated" must be 0 and "New records" must equal your row count. If the report shows a line "Records matching on catalog number that will be appended", matching is off: stop.
4. **One person at a time**, and no report page left open from before ([writing](writing.md#before-the-transfer)).
5. **Fit the columns to what Symbiota reads:** catalog number at most 32 characters and unique within the file; a range's end in `eventDate2`; no `occurrenceID` unless the GUID source is `occurrenceId` ([identity](identity.md#what-the-guid-source-setting-decides)); an identification only if you want a current name on the new record, because a record created with no name is left for the portal's experts; identifications that differ in name, determiner or date ([writing](writing.md#dwc-archive-import)); text free of curly quotes, emoji and doubled spaces, which are changed ([hazards](hazards.md#smaller-hazards)).
6. **Load host plants and links afterwards** through Extended Data Import ([below](#i-want-to-update-host-plants)).
7. **Read the portal again afterwards**, so that the next file leaves out these records.

**Untested:** a collection managed as Snapshot or Aggregate; users with a role below collection administrator; the image import; MySQL; the real portal's PHP settings and any local code changes; a file that contains a trap sample's date range on real data (the rehearsal had none, the earlier test used invented ones).

## I want to change one field on existing records

**There is no built-in route that changes one field and leaves the rest alone.** In order of safety:

1. **A person in the record editor**, one record at a time. It is the only route built to touch one record. It clears the old current identification flag. Make the list of changes for the person (record link, field, old value, new value). Not tested: driving the editor in bulk.
2. **A skeletal upload, if the field is empty now.** It fills only empty fields and cannot correct a filled one ([writing](writing.md#skeletal-upload)). It also rewrote identification rows in the 2026-11-23 test, so keep identifications out of the file and check the result. The API's `occurrence/skeletal` route is the same idea for a short list of fields ([writing](writing.md#the-api)) and was never run.
3. **A round trip: download, change cells, upload by DwC-Archive Import.** Measured 2026-11-23: it changed exactly the cells that were edited on the records it could carry, and nothing else on the real records except an empty string for a null authorship and the modification time. It damages every column the download lacks and several formats ([hazards](hazards.md#a-round-trip-through-the-download)). Use it only if you can show on a copy that your portal's columns survive, and add the missing columns (the API has `processingStatus`) to the file yourself, which was not tested.

Whichever you use, drop every record edited since your read: list the edits since the read time from the edit feed and exclude those records ([reading](reading.md#the-edit-feed)).

**Never use the spreadsheet route** for this: it rewrites the current identification.

## I want to update host plants

**Route.** Extended Data Import ("Extended Data Importer"), import type "Associations", association type "Occurrence - External Link", with the box "Update or delete existing association with matching identifiers" ticked. Columns: `subject identifier: catalogNumber`, `resourceUrl` (the observation's address, unchanged), `verbatimSciname` (the plant). Choose the relationship once on the mapping page. Measured 2026-11-22 over associations made the way another project's files made them: occurrence rows and identification rows were identical before and after (hashes, `dateLastModified` included), the plant name was replaced in place and the existing `objectID` kept, and loading the file twice more changed nothing.

**Conditions:**
- **Never send a blank plant name where the portal holds one.** A blank erases it.
- **The observation address must match the stored one.** A changed address cannot update a row, and with the box unticked it adds a second row.
- **The relationship is overwritten** by the form's choice on every ticked update.
- **A stale association is removed only by a separate file** with the relationship "Batch Delete" and the catalog number plus the address. With the box unticked the same file inserts a junk row.
- **The record's `associatedTaxa` text is not updated**, so it keeps the old plant. A project that wants one place for the host should not write `associatedTaxa` at all.
- **"visits flowers of" is not on the page's list.** Only `hasHost` and `ecologicallyOccursWith` fit, and a person cannot pick another ([writing](writing.md#extended-data-import-for-associations)).

**Untested:** a plant with no observation (an "observational" association has no address to match on; reading the matching rule, a renamed plant would add a row, which was not run); association types other than the external link on update; a real portal; whether the page's relationship list can be extended by the portal's manager.

## I want to know what changed since my download

**Route.** Two public calls, cheapest first ([reading](reading.md#counting-and-asking-what-changed)):
1. The count of the collection, and the count modified since a day before your download, both with a far-future maximum. If both match your stored numbers, nothing moved, subject to the probe's blind spots.
2. The edit feed from your read time (`fromDate`). It lists each edit with record, field, old and new value. Use it to exclude records from a file, and to see what changed and when. It does not say who made an edit.

Download again when either moves. The probe cannot see a second edit inside its window, nor a deletion compensated by an insertion.

**Caveats.** A rise in `dateLastModified` is not proof of a real change ([hazards](hazards.md#smaller-hazards)). **Untested:** whether an upload by import page appears in the edit feed.

## I want to publish my own record identifier

Ask the collection's administrator for the GUID source setting before building anything ([identity](identity.md#what-the-guid-source-setting-decides)). Only `occurrenceId` keeps an identifier you send, and changing the setting for a shared collection changes what every record publishes.

## I want to run an import on a schedule

Only after the data's owner has agreed where records are edited. The handler needs its switches as arguments, exits 0 on failure, and runs every night without a report ([writing](writing.md#a-scheduled-fetch-from-a-url)). Test the URL, the arguments and a failing fetch on a local Symbiota first.
