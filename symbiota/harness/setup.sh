#!/bin/bash
# Stand up a throwaway Symbiota (PHP 8.2 + Apache, MariaDB 10.11) with one empty "Live Data" collection.
# Usage: SYMBIOTA_SRC=/path/to/Symbiota ./setup.sh [guid-target]
#   guid-target is the collection's GUID source: catalogNumber (default), occurrenceId or symbiotaUUID.
# Copy this folder somewhere outside any repository first: setup writes src/, serve/, logs/ and a cookie jar beside it.
# SYMTEST_PREFIX and SYMTEST_PORT (see lib.sh) let a second copy run beside the first.
# The script exits 0 only when the TEST collection exists at the end. Every required step is checked and stops the script when it fails.
set -uo pipefail
die(){ echo "setup.sh: $*" >&2; exit 1; }
W="$(cd "$(dirname "$0")" && pwd)" || die "cannot find the harness folder"; cd "$W" || die "cannot enter $W"
SRC=${SYMBIOTA_SRC:?set SYMBIOTA_SRC to a checkout of https://github.com/Symbiota/Symbiota}
. "$W/lib.sh"
GUID=${1:-catalogNumber}
case "$GUID" in catalogNumber|occurrenceId|symbiotaUUID) ;; *) die "guid-target must be catalogNumber, occurrenceId or symbiotaUUID, not $GUID";; esac
mkdir -p src serve logs || die "cannot make the working folders"
rsync -a --exclude=.git "$SRC"/ src/ || die "rsync of the Symbiota checkout failed"
cd src || die "no src folder"
for f in config/dbconnection config/symbini config/auth_config; do cp -f "${f}_template.php" "$f.php" || die "cannot copy ${f}_template.php"; done
for f in $(find . -name '*_template*' -not -path './vendor/*' -not -path './config/*'); do n=${f/_template/}; [ -e "$n" ] || cp "$f" "$n" || die "cannot copy $f"; done
# A checkout may lack content/ or api/storage, so a failed chmod there is tolerated; temp/ is required.
chmod -R a+rwX content api/storage 2>/dev/null || true
mkdir -p temp && chmod -R a+rwX temp || die "cannot prepare temp/"
sed -i "s#^\$CLIENT_ROOT = '';#\$CLIENT_ROOT = '/sym';#; s#^\$SERVER_ROOT = '';#\$SERVER_ROOT = '/var/www/html';#; s#^\$TEMP_DIR_ROOT = '';#\$TEMP_DIR_ROOT = '/var/www/html/temp';#; s#^\$PORTAL_GUID = '';#\$PORTAL_GUID = '11111111-2222-3333-4444-555555555555';#; s#^\$SECURITY_KEY = '';#\$SECURITY_KEY = 'testkey';#; s#^\$DEFAULT_TITLE = '';#\$DEFAULT_TITLE = 'symtest';#; s#^\$ADMIN_EMAIL = '';#\$ADMIN_EMAIL = 'admin@example.org';#; s/^\$HTTPS_ONLY = true;/\$HTTPS_ONLY = false;/" config/symbini.php || die "cannot edit config/symbini.php"
python3 - <<'PY' || die "cannot write config/dbconnection.php"
p='config/dbconnection.php'; s=open(p).read()
s=s.replace("'host' => 'localhost'","'host' => 'symtest-db'").replace("'username' => ''","'username' => 'symb'").replace("'password' => ''","'password' => 'symbpw'").replace("'database' => ''","'database' => 'symbdb'")
open(p,'w').write(s)
PY
# The Laravel API reads its own settings from api/.env, which a checkout may lack or hold with empty values. Without it the API cannot reach the database.
[ -e api/.env ] || cp api/.env.example api/.env || die "cannot create api/.env"
sed -i "s#^DB_HOST=.*#DB_HOST=symtest-db#; s#^DB_PORT=.*#DB_PORT=3306#; s#^DB_DATABASE=.*#DB_DATABASE=symbdb#; s#^DB_USERNAME=.*#DB_USERNAME=symb#; s#^DB_PASSWORD=.*#DB_PASSWORD=symbpw#" api/.env || die "cannot edit api/.env"
cd "$W" || die "cannot enter $W"
# docker compose writes its progress to stderr. Keep the whole output in a file and show its tail, so that a failure is neither hidden by a pipe nor lost.
if ! docker compose -p "$P" up -d --build >"$W/logs/compose.log" 2>&1; then tail -20 "$W/logs/compose.log" >&2; die "docker compose up failed (full output in logs/compose.log)"; fi
tail -3 "$W/logs/compose.log"
# Wait until MariaDB answers with the configured login, up to 120 seconds.
ready=0
for i in $(seq 1 60); do
  if docker exec "$P-db" mariadb -uroot -prootpw symbdb -e 'select 1' >/dev/null 2>&1; then ready=1; break; fi
  sleep 2
done
[ "$ready" = 1 ] || die "MariaDB did not answer within 120 seconds"
# The schema can be installed once. A database that already has tables (an earlier run, even a failed one) would give a wall of duplicate-key errors, so refuse it.
have=$(docker exec "$P-db" mariadb -uroot -prootpw -N -B symbdb -e "select count(*) from information_schema.tables where table_schema='symbdb'") || die "cannot count the tables in the database"
[ "$have" = 0 ] || die "the database already holds $have tables. Remove the old copy first: docker compose -p $P down -v"
# Wait until the web service answers, up to 120 seconds.
ready=0
for i in $(seq 1 60); do
  code=$(curl -s -o /dev/null -w '%{http_code}' "$B/index.php" 2>/dev/null) || code=000
  case "$code" in 200|302) ready=1; break;; esac
  sleep 2
done
[ "$ready" = 1 ] || die "the web service at $B did not answer within 120 seconds (last status $code)"
# The baseline schema (3.0) and the patches 3.1 to 3.4. The patches run with --force, so one failed statement does not stop the rest. Errors that are known to be harmless are listed here and printed; any other error stops the script.
# Known benign: BENIGN_RE below, in the patches named in BENIGN_IN only. The columns the patches add to tables that the baseline lacks cannot be added.
BENIGN_IN=" db_schema_patch-3.1.sql db_schema_patch-3.2.sql "
BENIGN_RE="ERROR 1146 .*doesn't exist"
# The baseline reads other files by relative path ("source data/..."), so each file runs inside the container from the schema folder.
docker cp src/config/schema "$P-db:/s" || die "cannot copy the schema folder into the database container"
for f in db_schema-3.0.sql patches/db_schema_patch-3.1.sql patches/db_schema_patch-3.2.sql patches/db_schema_patch-3.3.sql patches/db_schema_patch-3.4.sql; do
  [ -r "src/config/schema/3.0/$f" ] || die "missing src/config/schema/3.0/$f"
  out=$(docker exec -w /s/3.0 "$P-db" sh -c 'mariadb -uroot -prootpw --force symbdb < "$1"' sh "$f" 2>&1); rc=$?
  errs=$(printf '%s\n' "$out" | grep ERROR || true)
  if [ "$rc" != 0 ] && [ -z "$errs" ]; then die "applying $f failed with status $rc and no ERROR line: $out"; fi
  unexpected="$errs"
  case "$BENIGN_IN" in *" $(basename "$f") "*) unexpected=$(printf '%s\n' "$errs" | grep -v -E "$BENIGN_RE" || true);; esac
  echo "$f: $(printf '%s' "$errs" | grep -c .) errors, $(printf '%s' "$unexpected" | grep -c .) unexpected"
  [ -z "$unexpected" ] || die "unexpected errors applying $f: $unexpected"
done
login || die "cannot sign in as the administrator"
code=$(curl -s -b "$JAR" -c "$JAR" -o "$W/logs/newcollection.html" -w '%{http_code}' "$B/collections/misc/collmetadata.php" -F action=newCollection -F institutionCode=TEST -F collectionCode=TEST -F collectionName="Test collection" -F collType="Preserved Specimens" -F managementType="Live Data" -F guidTarget="$GUID" -F ccpk=) || die "the collection-creation request failed"
case "$code" in 200|302) ;; *) die "creating the collection answered HTTP $code (page in logs/newcollection.html)";; esac
# The only proof that sign-in and creation worked: the collection is in the database with the settings asked for.
n=$("$W/sql.sh" -N -B -e "select count(*) from omcollections where institutioncode='TEST' and collectioncode='TEST' and managementtype='Live Data' and guidtarget='$GUID'") || die "cannot read omcollections"
[ "$n" = 1 ] || die "the TEST collection does not exist after the request (found $n)"
sql -e "select collid,institutioncode,collectioncode,managementtype,guidtarget from omcollections" || die "cannot list the collections"
