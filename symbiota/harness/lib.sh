# source me. The folder this file sits in is the working folder.
# SYMTEST_PREFIX names the containers, the image and the volume (default symtest), and SYMTEST_PORT is the port on 127.0.0.1 (default 18181). Set both to run a second copy beside the first.
W="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
P=${SYMTEST_PREFIX:-symtest}
PORT=${SYMTEST_PORT:-18181}
B=http://127.0.0.1:$PORT/sym
JAR="$W/jar"
# The throwaway install's own administrator (it comes with Symbiota's baseline schema).
# Returns non-zero unless the sign-in worked: the request must answer 200 or 302 and the portal must have set a session cookie.
login(){
  rm -f "$JAR"
  local code
  code=$(curl -s -c "$JAR" -b "$JAR" -o /dev/null -w '%{http_code}' -d "login=admin&password=admin&action=login" "$B/profile/index.php") || { echo "login: curl failed" >&2; return 1; }
  case "$code" in 200|302) ;; *) echo "login: the portal answered HTTP $code" >&2; return 1;; esac
  grep -q PHPSESSID "$JAR" || { echo "login: the portal set no session cookie" >&2; return 1; }
}
sql(){ "$W/sql.sh" "$@"; }
