# source me. The folder this file sits in is the working folder.
W="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B=http://127.0.0.1:18181/sym
JAR="$W/jar"
# The throwaway install's own administrator (it comes with Symbiota's baseline schema).
login(){ rm -f "$JAR"; curl -s -c "$JAR" -b "$JAR" -o /dev/null -d "login=admin&password=admin&action=login" "$B/profile/index.php"; }
sql(){ "$W/sql.sh" "$@"; }
