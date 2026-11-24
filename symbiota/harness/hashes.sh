#!/bin/bash
# usage: hashes.sh [maxoccid [maxdetid]]
# Prints the row counts and an md5 of every occurrence row and determination row, ordered, optionally limited to ids at or below a maximum.
# Run it before and after an upload: equal hashes for the records you did not mean to touch show that nothing else changed.
# Each row is read as one JSON array, so a NULL (null) stays apart from the text NULL and from an empty string. Every read finishes before anything is printed, so a failed read cannot leave a partial answer that passes for an unchanged hash.
set -euo pipefail
W="$(cd "$(dirname "$0")" && pwd)"
o=${1:-999999999}; d=${2:-999999999}
case "$o$d" in *[!0-9]*) echo "hashes.sh: the limits must be whole numbers" >&2; exit 2;; esac
rows(){ "$W/sql.sh" -N -B -e "$1"; }
cols(){ rows "select group_concat(concat('\`',column_name,'\`') order by ordinal_position) from information_schema.columns where table_schema='symbdb' and table_name='$1'"; }
hash(){ local c out; c="$(cols "$1")"; [ -n "$c" ] || { echo "hashes.sh: no columns for $1" >&2; exit 1; }
  out="$("$W/sql.sh" -N -B -r -e "select json_array($c) from $1 where $2<=$3 order by $2")"; printf '%s\n' "$out" | md5sum | cut -c1-32; }
oc="$(rows "select count(*) from omoccurrences where occid<=$o")"
oh="$(hash omoccurrences occid "$o")"
dc="$(rows "select count(*) from omoccurdeterminations where detid<=$d")"
dh="$(hash omoccurdeterminations detid "$d")"
echo "occ rows: $oc"
echo "occ md5:  $oh"
echo "det rows: $dc"
echo "det md5:  $dh"
