#!/bin/bash
# usage: sql.sh [-e "query"], or a query on stdin. Runs against the throwaway database only.
exec docker exec -i symtest-db mariadb -uroot -prootpw symbdb "$@"
