#!/usr/bin/env bash
# Bake the generated package-server document root (www/) into an image, so the tablet APK
# travels to the site over `docker pull` instead of on a USB stick. See Dockerfile.
#
#   ./publish.sh                 # generate www/ from the newest built APK, first
#   ./build-pkgserver-image.sh   # -> buendia-pkgserver:<site>-<apkversion>
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$HERE/../.env"
[[ -f "$ENV_FILE" ]] && { set -a; source "$ENV_FILE"; set +a; }
: "${SITE_ID:=pilot}"

shopt -s nullglob
apks=("$HERE"/www/*.apk)
[[ ${#apks[@]} -gt 0 ]] || {
  echo "ERROR: no .apk in $HERE/www/ — run ./publish.sh first (it generates the document root)." >&2
  exit 1
}
# publish.sh writes latest.apk plus a version-named copy; hash the real file, not the alias.
apk=""
for a in "${apks[@]}"; do [[ "$(basename "$a")" == "latest.apk" ]] || apk="$a"; done
[[ -n "$apk" ]] || apk="${apks[0]}"

# The version the tablet's updater compares is the one in the filename buendia-client-<v>.apk.
ver="$(basename "$apk" .apk)"; ver="${ver#buendia-client-}"
sha="$(sha256sum "$apk" | cut -d' ' -f1)"
[[ -f "$HERE/www/dists/stable/Release" ]] \
  || echo "WARN: www/dists/stable/Release missing — the app will show 'check package server configuration'." >&2

TAG="${PKGSERVER_IMAGE_TAG:-buendia-pkgserver:${SITE_ID}-${ver}}"
echo "==> building $TAG  (apk $(basename "$apk"), sha256 ${sha:0:12})"
docker build \
  --build-arg "NGINX_IMAGE=${NGINX_BASE_IMAGE:-nginx:alpine-slim}" \
  --build-arg "APK_VERSION=$ver" \
  --build-arg "APK_SHA256=$sha" \
  --build-arg "SITE_ID=$SITE_ID" \
  -t "$TAG" \
  "$HERE"

echo
echo "==> done: $TAG"
echo "    Set this in deploy/.env to serve it instead of the bind-mounted www/:"
echo "        PKGSERVER_IMAGE=$TAG"
echo "    ⚠️  This image is site-specific: the APK inside bakes in the server address and password."
echo "    Publish it with:  ../tools/publish-images.sh"
