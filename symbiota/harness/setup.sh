#!/bin/bash
# Stand up a throwaway Symbiota (PHP 8.2 + Apache, MariaDB 10.11) with one empty "Live Data" collection.
# Usage: SYMBIOTA_SRC=/path/to/Symbiota ./setup.sh [guid-target]
#   guid-target is the collection's GUID source: catalogNumber (default), occurrenceId or symbiotaUUID.
# Copy this folder somewhere outside any repository first: setup writes src/, serve/, logs/ and a cookie jar beside it.
W="$(cd "$(dirname "$0")" && pwd)"; cd "$W"
SRC=${SYMBIOTA_SRC:?set SYMBIOTA_SRC to a checkout of https://github.com/Symbiota/Symbiota}
GUID=${1:-catalogNumber}
mkdir -p src serve logs
rsync -a --exclude=.git "$SRC"/ src/
cd src
for f in config/dbconnection config/symbini config/auth_config; do cp -f "${f}_template.php" "$f.php"; done
for f in $(find . -name '*_template*' -not -path './vendor/*' -not -path './config/*'); do n=${f/_template/}; [ -e "$n" ] || cp "$f" "$n"; done
chmod -R a+rwX content api/storage 2>/dev/null || true; mkdir -p temp; chmod -R a+rwX temp
sed -i "s#^\$CLIENT_ROOT = '';#\$CLIENT_ROOT = '/sym';#; s#^\$SERVER_ROOT = '';#\$SERVER_ROOT = '/var/www/html';#; s#^\$TEMP_DIR_ROOT = '';#\$TEMP_DIR_ROOT = '/var/www/html/temp';#; s#^\$PORTAL_GUID = '';#\$PORTAL_GUID = '11111111-2222-3333-4444-555555555555';#; s#^\$SECURITY_KEY = '';#\$SECURITY_KEY = 'testkey';#; s#^\$DEFAULT_TITLE = '';#\$DEFAULT_TITLE = 'symtest';#; s#^\$ADMIN_EMAIL = '';#\$ADMIN_EMAIL = 'admin@example.org';#; s/^\$HTTPS_ONLY = true;/\$HTTPS_ONLY = false;/" config/symbini.php
python3 - <<'PY'
p='config/dbconnection.php'; s=open(p).read()
s=s.replace("'host' => 'localhost'","'host' => 'symtest-db'").replace("'username' => ''","'username' => 'symb'").replace("'password' => ''","'password' => 'symbpw'").replace("'database' => ''","'database' => 'symbdb'")
open(p,'w').write(s)
PY
# The Laravel API reads its own settings from api/.env, which a checkout may lack or hold with empty values. Without it the API cannot reach the database.
[ -e api/.env ] || cp api/.env.example api/.env
sed -i "s#^DB_HOST=.*#DB_HOST=symtest-db#; s#^DB_PORT=.*#DB_PORT=3306#; s#^DB_DATABASE=.*#DB_DATABASE=symbdb#; s#^DB_USERNAME=.*#DB_USERNAME=symb#; s#^DB_PASSWORD=.*#DB_PASSWORD=symbpw#" api/.env
cd "$W"
docker compose -p symtest up -d --build 2>&1 | tail -3
# Wait until MariaDB answers with the configured login, up to 120 seconds. This script does not use set -e (a grep -c below exits 1 on zero matches), so stop explicitly.
ready=0
for i in $(seq 1 60); do
  if docker exec symtest-db mariadb -uroot -prootpw symbdb -e 'select 1' >/dev/null 2>&1; then ready=1; break; fi
  sleep 2
done
if [ "$ready" != 1 ]; then echo "setup.sh: MariaDB did not answer within 120 seconds" >&2; exit 1; fi
docker cp src/config/schema symtest-db:/s
# The baseline schema (3.0) and the patches 3.1 to 3.4. Two benign errors appear in patches 3.1 and 3.2 (ALTERs on tables the baseline lacks).
docker exec -w /s/3.0 symtest-db sh -c 'for f in db_schema-3.0.sql patches/db_schema_patch-3.1.sql patches/db_schema_patch-3.2.sql patches/db_schema_patch-3.3.sql patches/db_schema_patch-3.4.sql; do mariadb -uroot -prootpw --force symbdb < $f 2>&1 | grep -c ERROR; done' || true
. "$W/lib.sh"; login
curl -s -b "$JAR" -c "$JAR" -o /dev/null "$B/collections/misc/collmetadata.php" -F action=newCollection -F institutionCode=TEST -F collectionCode=TEST -F collectionName="Test collection" -F collType="Preserved Specimens" -F managementType="Live Data" -F guidTarget="$GUID" -F ccpk=
sql -e "select collid,institutioncode,collectioncode,managementtype,guidtarget from omcollections"
