#!/usr/bin/env bash
# Pack the generated package-server document root into a release asset, for upload to a PRIVATE
# GitHub release. `setup.sh` downloads and unpacks it on the target server.
#
#   ./publish.sh        # first: generate www/ from the newest built APK
#   ./pack-www.sh       # -> pkgserver-www-<site>-<ver>.tar.gz (+ .sha256)
#
# WHY PRIVATE: the payload contains the APK, and the APK carries the server password as a plain
# Android string resource (`openmrs_password_default`), extractable with one
# `aapt dump --values resources`. The APK is therefore a credential. The db/openmrs container
# images hold no secrets and stay public; this does not.
#
# WHY THE WHOLE www/, not just the .apk: the update index, landing page and QR code all embed the
# server address, so the payload is site-specific — and shipping it whole means the target server
# needs no python/segno/qrencode to regenerate any of it.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$HERE/../.env"
[[ -f "$ENV_FILE" ]] && { set -a; source "$ENV_FILE"; set +a; }
: "${SITE_ID:=pilot}"
WWW="$HERE/www"

shopt -s nullglob
apks=("$WWW"/*.apk)
shopt -u nullglob
[[ ${#apks[@]} -gt 0 ]] || {
  echo "ERROR: no .apk in $WWW — run ./publish.sh first." >&2; exit 1; }

# publish.sh writes latest.apk plus a version-named copy; take the version from the real name.
apk=""
for a in "${apks[@]}"; do [[ "$(basename "$a")" == "latest.apk" ]] || apk="$a"; done
[[ -n "$apk" ]] || apk="${apks[0]}"
ver="$(basename "$apk" .apk)"; ver="${ver#buendia-client-}"

for required in latest.apk buendia-client.json dists/stable/Release; do
  [[ -e "$WWW/$required" ]] || echo "WARN: $WWW/$required is missing — re-run ./publish.sh" >&2
done

OUT="$HERE/pkgserver-www-${SITE_ID}-${ver}.tar.gz"
echo "==> packing $WWW -> $(basename "$OUT")"
# Exclude .gitkeep; store paths relative to www/ so setup.sh can unpack straight into it.
tar czf "$OUT" -C "$WWW" --exclude='.gitkeep' .
sha256sum "$OUT" | awk -v n="$(basename "$OUT")" '{print $1"  "n}' > "$OUT.sha256"

echo "==> done: $(basename "$OUT") ($(du -h "$OUT" | cut -f1)), APK version $ver"
echo "    server baked into this payload: ${APK_SERVER:-${STATIC_IP:-?}}"
echo
echo "    Upload to a PRIVATE release (never a public one):"
echo "        gh release upload <tag> '$OUT' '$OUT.sha256' --repo <owner>/<private-repo>"
echo "    Then on the target server, in deploy/.env:"
echo "        APK_RELEASE_REPO=<owner>/<private-repo>"
echo "        APK_RELEASE_TAG=<tag>"
echo "        APK_RELEASE_ASSET=$(basename "$OUT")"
echo "    ...and pass the token in the ENVIRONMENT at setup time (never in .env):"
echo "        GITHUB_TOKEN=<fine-grained, read-only, this repo only> sudo -E ./setup.sh"
