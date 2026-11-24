#!/bin/bash
# usage: sql.sh [-e "query"], or a query on stdin. Runs against the throwaway database only.
# SYMTEST_PREFIX names the container, as in lib.sh.
exec docker exec -i "${SYMTEST_PREFIX:-symtest}-db" mariadb -uroot -prootpw symbdb "$@"
