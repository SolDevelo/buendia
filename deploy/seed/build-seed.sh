#!/usr/bin/env bash
# Build the baseline seed (deploy/seed/10-buendia-base.sql) from the db-snapshot submodule.
# db-snapshot is mysqldump --tab format (per-table .sql schema + .txt data via LOAD DATA LOCAL,
# loaded by 000_load.sql). We load it once into a throwaway mysql:5.6 and re-dump it as a single
# portable SQL file (plain INSERTs) so the shipped container needs no LOAD DATA INFILE / file access.
#
# Re-run this whenever the seed baseline changes. The generated .sql is git-ignored (regenerable).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
SNAP="$REPO/db-snapshot"
OUT="$HERE/initdb/10-buendia-base.sql"   # only initdb/ is mounted into the container's initdb.d
mkdir -p "$HERE/initdb"
PW=seedbuild
# Default profile baked into the seed (the tailorable source artifact). Applied via the
# buendia-openmrs image's profile-apply. Override PROFILE / IMAGE to change.
PROFILE="${PROFILE:-$REPO/deploy/profile/bunia.csv}"
IMAGE="${IMAGE:-buendia-openmrs:latest}"

[ -f "$SNAP/000_load.sql" ] || { echo "ERROR: db-snapshot not populated (git submodule update --init db-snapshot)"; exit 1; }

echo "==> starting throwaway mysql:5.6"
CID=$(docker run -d --rm \
  -e MYSQL_ROOT_PASSWORD="$PW" -e MYSQL_DATABASE=openmrs \
  -v "$SNAP":/snap:ro \
  mysql:5.6 --local-infile=1 --secure-file-priv="")
trap 'docker stop "$CID" >/dev/null 2>&1 || true' EXIT

echo "==> waiting for the REAL mysql server (TCP) to accept connections"
# NB: `mysqladmin ping` passes during MySQL's init-phase (socket-only) temp server, which then
# restarts → "MySQL server has gone away" mid-load. Gate on a real query over TCP instead.
ready=""
for i in $(seq 1 120); do
  if docker exec "$CID" mysql -h127.0.0.1 --protocol=TCP -uroot -p"$PW" -e 'SELECT 1' >/dev/null 2>&1; then
    ready=1; break
  fi
  sleep 2
done
[ -n "$ready" ] || { echo "mysql did not become ready" >&2; exit 1; }

echo "==> loading db-snapshot (source schema + LOAD DATA LOCAL, 115 tables)"
docker exec -w /snap "$CID" sh -c "mysql --local-infile=1 -uroot -p'$PW' openmrs < 000_load.sql"

# Bake the default clinical profile into the seed (so a fresh boot is active out-of-the-box).
# Uses the buendia-openmrs image's profile-apply, sharing the throwaway MySQL's network namespace
# (so MySQL is reachable at 127.0.0.1). Skipped (clean baseline) if the profile or image is absent.
if [ -f "$PROFILE" ] && docker image inspect "$IMAGE" >/dev/null 2>&1; then
  pname="$(basename "$PROFILE")"
  echo "==> baking profile into the seed: $pname"
  docker run --rm --network "container:$CID" -e SEEDPW="$PW" \
    -v "$PROFILE":/tmp/$pname:ro --entrypoint bash "$IMAGE" -c '
      mkdir -p /usr/share/buendia/site
      printf "OPENMRS_MYSQL_HOST=127.0.0.1\nOPENMRS_MYSQL_USER=root\nOPENMRS_MYSQL_PASSWORD=%s\n" "$SEEDPW" \
        > /usr/share/buendia/site/10-seedbuild
      buendia-profile-apply /tmp/'"$pname"'' 2>&1 | grep -E "Stored|Error|Traceback|error" | tail -12
  docker exec "$CID" mysql -uroot -p"$PW" openmrs \
    -e "UPDATE global_property SET property_value='$pname' WHERE property='projectbuendia.currentProfile';"
  echo "    profile applied; projectbuendia.currentProfile=$pname"
else
  echo "==> no profile baked (missing $PROFILE or image $IMAGE) — seed is a clean baseline"
fi

echo "==> re-dumping as a single portable seed (DEFINER clauses stripped) -> $OUT"
# Strip DEFINER=`user`@`host` from triggers/views/routines. The db-snapshot's 6 sync triggers
# (buendia_{obs,order,patient}_{insert,update}_date_updated) carry DEFINER=`openmrs_user`@`localhost`,
# a user that doesn't exist in this deployment → "definer does not exist" on patient/obs insert.
# Stripping makes them definer-agnostic (created by the loading user at init → always exists).
docker exec "$CID" sh -c "mysqldump --no-tablespaces --single-transaction -uroot -p'$PW' openmrs" \
  | sed -e 's#/\*!50017 DEFINER=[^*]*\*/##g' -e 's/ DEFINER=`[^`]*`@`[^`]*`//g' > "$OUT"

echo "==> done: $OUT ($(wc -c < "$OUT") bytes)"
