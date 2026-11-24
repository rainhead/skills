#!/bin/bash
# usage: hashes.sh [maxoccid [maxdetid]]
# Prints the row counts and an md5 of every occurrence row and determination row, ordered, optionally limited to ids at or below a maximum.
# Run it before and after an upload: equal hashes for the records you did not mean to touch show that nothing else changed.
W="$(cd "$(dirname "$0")" && pwd)"
o=${1:-999999999}; d=${2:-999999999}
echo -n "occ rows: "; $W/sql.sh -N -B -e "select count(*) from omoccurrences where occid<=$o"
echo -n "occ md5:  "; $W/sql.sh -N -B -e "select * from omoccurrences where occid<=$o order by occid" | md5sum | cut -c1-32
echo -n "det rows: "; $W/sql.sh -N -B -e "select count(*) from omoccurdeterminations where detid<=$d"
echo -n "det md5:  "; $W/sql.sh -N -B -e "select * from omoccurdeterminations where detid<=$d order by detid" | md5sum | cut -c1-32
