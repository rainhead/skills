#!/bin/bash
# usage: hashes.sh [maxoccid [maxdetid]]
# Prints the row counts and an md5 of every occurrence row and determination row, ordered, optionally limited to ids at or below a maximum.
# Run it before and after an upload: equal hashes for the records you did not mean to touch show that nothing else changed.
# A failed read stops the script before any digest is printed, so a failure cannot pass for an unchanged hash.
set -euo pipefail
W="$(cd "$(dirname "$0")" && pwd)"
o=${1:-999999999}; d=${2:-999999999}
hash(){ local out; out="$("$W/sql.sh" -N -B -e "$1")"; printf '%s\n' "$out" | md5sum | cut -c1-32; }
echo -n "occ rows: "; "$W/sql.sh" -N -B -e "select count(*) from omoccurrences where occid<=$o"
echo -n "occ md5:  "; hash "select * from omoccurrences where occid<=$o order by occid"
echo -n "det rows: "; "$W/sql.sh" -N -B -e "select count(*) from omoccurdeterminations where detid<=$d"
echo -n "det md5:  "; hash "select * from omoccurdeterminations where detid<=$d order by detid"
