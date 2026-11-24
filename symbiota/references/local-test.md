# Testing on a local Symbiota

Open this when a question about an upload, a download or a version is not answered here, or before any upload that is new to you. A local copy costs minutes. A wrong upload to a live portal cannot be undone from outside. Standing marks are defined in [SKILL.md](../SKILL.md#version-and-how-claims-are-marked).

**What to do:** stand up a copy of the portal's version, put in records shaped like the real ones, run the upload through the real pages, and compare every row before and after. Stop at the pending transfer report for a dry run.

## Stand it up

You need Docker, `rsync`, `curl` and Python 3 with `requests`, and a checkout of https://github.com/Symbiota/Symbiota at the portal's version. The measurements here used commit 4491b791c, whose `config/symbbase.php` says `$CODE_VERSION = '3.4.17'`.

1. Copy the [harness/](../harness/) folder out of this skill to a folder of your own outside any repository. It writes a `src/` copy of Symbiota, a database volume, logs and a cookie jar beside it.
2. Run `SYMBIOTA_SRC=<path to the Symbiota checkout> ./setup.sh [catalogNumber|symbiotaUUID|occurrenceId]`. The argument is the new collection's GUID source: use the portal's own ([identity](identity.md#what-the-guid-source-setting-decides)).
3. It builds a PHP 8.2 with Apache image (with the `pdo_mysql` extension, which the API needs), starts MariaDB 10.11 (`utf8mb3`, `sql-mode` empty, as Symbiota expects) and an nginx container that serves a folder `serve/` on the compose network (so a scheduled import can fetch a URL), installs the schema 3.0 and the patches 3.1 to 3.4, signs in as the baseline's own administrator (`admin` with the password `admin`; a throwaway login, on 127.0.0.1 only) and creates one empty Live Data collection called `TEST`. The site is at `http://127.0.0.1:18181/sym/`.
4. The installer prints one line per patch file: the number of errors (zero, one, two, zero, zero on the last run; the notes record two benign errors from ALTERs on tables the baseline lacks).

Setup took a few minutes the first time because it builds the PHP image. A fresh run of the harness on 2026-11-23 stood up the collection and completed an archive upload, a dry run, an absent-column upload and an unticked-match upload ([CHANGES.md](../CHANGES.md)).

## Reaching the API locally

Symbiota's Laravel API needs two things the first version of the harness lacked: the `pdo_mysql` PHP extension, and a settings file `api/.env` with the database host and login. Without them its routes fail, so the read routes such as the edit feed could not be tried. The Dockerfile now adds the extension and `setup.sh` writes `api/.env` from `api/.env.example` with the harness's database settings. The 2026-11-23 editor session made the same two changes by hand and measured with them. The changed harness files were not run end to end. **Locally the API answers under `/sym/api/index.php/v2/...`**, for example `http://127.0.0.1:18181/sym/api/index.php/v2/occurrence/annotation?collid=1&type=internal`. Write routes also need an `apiToken` and were not run.

## Drive the real pages

`harness/h.py` drives the same pages a person uses, with one signed-in session. Import it with `SYMTEST_DIR` set to the harness folder if it lives elsewhere, and `SYMTEST_URL` if the port differs.

- `login()` signs in as the administrator.
- `make_zip(path, columns, rows, ...)` builds a small DwC-Archive with an optional identification extension.
- `upload(label, collid, zip, importident=True, matchcat=True, matchothercat=False, versiondata=False, dry=False)` runs "Analyze File", "Start Upload" and the transfer. With `dry=True` it stops at the "Pending Data Transfer Report" and returns its text.
- `upload_csv(...)` does the same for the spreadsheet route, with `uploadtype=7` for skeletal.
- `import_ext(label, collid, importType, path, associationType, relationship, replace=...)` runs the "Extended Data Importer" (`importType=1` is associations).
- `editor_add(...)` and `editor_det(...)` create a record and a determination through the record editor, which is how a record "entered in Symbiota" is made.
- `sql(query)`, `dump(...)`, `snap(catalogNumber)` and `diff(before, after)` read rows back. `harness/hashes.sh` prints row counts and an `md5` of every occurrence row and identification row.
- Every step saves the page it fetched under `logs/`. **Those pages hold the records.** Delete them when you finish, and never copy them into a repository.

```python
import h
h.login()
h.make_zip('t.zip', ['id', 'catalogNumber', 'scientificName'], [['1', 'T_1', 'Bombus vosnesenskii']])
h.upload('first', 1, 't.zip')                     # adds the record
h.make_zip('t2.zip', ['id', 'catalogNumber'], [['1', 'T_1']])
h.upload('second', 1, 't2.zip', dry=True)         # report: "Records to be updated: 1", writes nothing
```

A scheduled fetch is tested by creating a profile on `specuploadmanagement.php` (type "IPT/DwC-A Provider", path `http://symtest-files/<file>.zip`), saving its mapping, and running `php collections/admin/uploadhandler.php <collid> <uspid> 0 1 1 0` inside the `symtest-web` container as `www-data` ([writing](writing.md#a-scheduled-fetch-from-a-url)).

## What the copy needs to be faithful

- **The same GUID source and management type as the portal.** Both change what an upload does.
- **A taxonomic thesaurus.** With none, the download's `genus`, `specificEpithet` and `taxonRank` are blank, and a round trip wipes them from the copy. The first run of the round-trip test lacked one and was discarded. The thesaurus was built from the archive's own taxonomic columns, with ids offset so they did not clash with the baseline's kingdoms (measured 2026-11-23). Set `tidInterpreted` on the loaded records as well. Without it, the name cleanup step has nothing to refill and results differ ([hazards](hazards.md#smaller-hazards)).
- **The real records' shape.** Load them through the same DwC-Archive page, after repairing the identification extension's delimiter in `meta.xml` ([reading](reading.md#the-identification-file-does-not-match-its-metaxml)). The importer skips identification rows with no name, so the copy holds fewer identification rows than the archive did (13,682 against 15,835 in one case). Rows of the identifier extension are not loaded by the importer and have to be inserted by SQL. The `dbpk` of loaded records was set to empty by SQL, because the portal's file had blank row ids.
- **A user as limited as yours.** The round-trip test signed in as a user whose only role was collection administrator on the test collection, to see what such a user's download holds. The superuser sees more.
- **A baseline dump.** `mysqldump` the database after loading, and restore it before every trial so each trial starts from the same rows. Compare tables by primary key and column afterwards, not by eye.

## What a copy cannot tell you

The portal's own PHP and database settings (a time zone, an upload limit), local code changes, the roles of its users, its data volume and timing. State what you did not reproduce next to every result.

## Finish

Stop the containers and remove the volume and image: `docker compose -p symtest down -v` in the harness folder, then `docker image rm symtest-web`. The shared images `mariadb:10.11`, `nginx:alpine` and `php:8.2-apache` can stay. Delete the harness folder's `src/`, `logs/` and any copied records. Never put real records in a repository.
