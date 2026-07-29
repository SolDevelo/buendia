#!/usr/bin/env bash
# Save the pinned images to deploy/images/*.tar for `setup.sh --offline`.
#
# The normal path is `setup.sh --online`, which pulls from Docker Hub — internet at setup,
# none at runtime. This bundle is the FALLBACK for rebuilding a server on site with no
# connectivity at all (the box died mid-pilot and a spare has to be brought up).
#
#   ./bundle-images.sh          # -> deploy/images/{db,openmrs,pkgserver}.tar + MANIFEST.txt
#
# Run it where the images exist (a build machine or a staged server), then copy deploy/ to a
# USB stick. Expect roughly 0.7-1 GB.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY="$(cd "$HERE/.." && pwd)"
OUT="$DEPLOY/images"
ENV_FILE="$DEPLOY/.env"
[[ -f "$ENV_FILE" ]] || { echo "ERROR: $ENV_FILE not found." >&2; exit 1; }
set -a; source "$ENV_FILE"; set +a

DB_IMAGE="${DB_IMAGE:-${MYSQL_IMAGE:-}}"
: "${DB_IMAGE:?set DB_IMAGE in .env}"
: "${OPENMRS_IMAGE:?set OPENMRS_IMAGE in .env}"
PKG="${PKGSERVER_IMAGE:-nginx:alpine-slim}"

mkdir -p "$OUT"
: > "$OUT/MANIFEST.txt"

save() {
  local image="$1" name="$2"
  docker image inspect "$image" >/dev/null 2>&1 || {
    echo "ERROR: image not present locally: $image (docker pull it first)" >&2; exit 1; }
  echo "==> saving $image -> images/$name.tar"
  docker save -o "$OUT/$name.tar" "$image"
  printf '%-12s %s\n  sha256: %s\n  bytes:  %s\n' "$name" "$image" \
    "$(sha256sum "$OUT/$name.tar" | cut -d' ' -f1)" \
    "$(wc -c < "$OUT/$name.tar" | tr -d ' ')" >> "$OUT/MANIFEST.txt"
}

save "$DB_IMAGE" db
save "$OPENMRS_IMAGE" openmrs
save "$PKG" pkgserver

echo
echo "==> bundle ready in $OUT ($(du -sh "$OUT" | cut -f1)):"
cat "$OUT/MANIFEST.txt"
echo "Install from it with:  sudo ./setup.sh --offline"
echo "NB --offline also needs Docker itself in deploy/debs/ if the target has no Docker yet:"
echo "    apt-get download docker-ce docker-ce-cli containerd.io docker-compose-plugin"
