#!/usr/bin/env bash
# Build the Buendia DB image: mysql:5.6 with the baseline seed baked in.
#
#   ./build-seed.sh          # first: generate initdb/10-buendia-base.sql from db-snapshot
#   ./build-db-image.sh      # then: bake it into buendia-db:5.6-<gitsha>
#
# Why: with the seed baked in, a site server needs `docker pull` and nothing else — no
# 83 MB file to copy onto the machine. Push it with ../tools/publish-images.sh.
# See Dockerfile for the base/site split.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
SEED="$HERE/initdb/10-buendia-base.sql"
BASE_IMAGE="${MYSQL_IMAGE:-mysql:5.6}"

if [[ ! -s "$SEED" ]]; then
  echo "ERROR: $SEED is missing or empty." >&2
  echo "       Generate it first:  ./build-seed.sh" >&2
  exit 1
fi

# Guard against baking a seed that build-seed.sh did not finish writing. A truncated dump
# produces an image that boots but has no concepts, which is a miserable thing to debug on
# site: mysqldump always ends with this marker line.
if ! tail -c 200 "$SEED" | grep -q "Dump completed"; then
  echo "ERROR: $SEED does not end with mysqldump's 'Dump completed' marker — it looks truncated." >&2
  echo "       Re-run ./build-seed.sh before baking an image from it." >&2
  exit 1
fi

GIT_SHA="$(cd "$REPO" && git rev-parse --short HEAD 2>/dev/null || echo unknown)"
SEED_BYTES="$(wc -c < "$SEED" | tr -d ' ')"
echo "==> hashing the seed ($(( SEED_BYTES / 1048576 )) MB)"
SEED_SHA256="$(sha256sum "$SEED" | cut -d' ' -f1)"

MYSQL_VER="${BASE_IMAGE##*:}"; MYSQL_VER="${MYSQL_VER%%@*}"
TAG="${DB_IMAGE_TAG:-buendia-db:${MYSQL_VER}-${GIT_SHA}}"

echo "==> building $TAG  (base $BASE_IMAGE, seed ${SEED_SHA256:0:12})"
docker build \
  --build-arg "MYSQL_IMAGE=$BASE_IMAGE" \
  --build-arg "SEED_SHA256=$SEED_SHA256" \
  --build-arg "SEED_BYTES=$SEED_BYTES" \
  --build-arg "GIT_SHA=$GIT_SHA" \
  -t "$TAG" \
  -t "buendia-db:latest" \
  "$HERE"

echo
echo "==> done: $TAG (also tagged buendia-db:latest)"
echo "    Set this in deploy/.env so compose and setup.sh use it:"
echo "        DB_IMAGE=$TAG"
echo "    Publish it to Docker Hub with:  ../tools/publish-images.sh"
