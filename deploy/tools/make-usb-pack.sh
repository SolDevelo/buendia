#!/usr/bin/env bash
# Build the folder MSF copies onto their own USB stick, as one sendable archive.
#
#   ./make-usb-pack.sh                       # -> buendia-usb-<site>-<apkver>.zip (+ .sha256)
#   ./make-usb-pack.sh --keep-passwords <existing buendia.env>
#
# ⚠️ THE PACK IS A CREDENTIAL. buendia.env holds the database passwords, and the APK inside the
# payload carries the server password as a readable string resource. Send it over a private
# channel — never a public link or a public release asset.
#
# Everything in it is built by other scripts; this one only assembles, and refuses to assemble
# an inconsistent set. The check that matters: the address baked into the APK payload must equal
# STATIC_IP, or tablets install cleanly and then never connect, with nothing on the box to say why.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
D="$HERE/.."
KEEP=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep-passwords) KEEP="$2"; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
die() { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }
set -a; . "$D/.env"; set +a

STAGE="$(mktemp -d)"; trap 'rm -rf "$STAGE"' EXIT
OUT="$D/Buendia"
# Stash --keep-passwords BEFORE wiping the staging folder: the file being reused is normally the
# previous pack's own buendia.env, which lives inside it. Reading it after the rm found nothing.
if [[ -n "$KEEP" ]]; then
  [[ -f "$KEEP" ]] || die "--keep-passwords: $KEEP not found"
  cp "$KEEP" "$STAGE/keep.env"; KEEP="$STAGE/keep.env"
fi
rm -rf "$OUT"; mkdir -p "$OUT"

log "Collecting"
# Exactly ONE bundle and ONE payload: bootstrap.sh refuses an ambiguous folder, and the wrong
# payload would install an APK pointed at a different server.
mapfile -t bundles < <(ls -1 "$D"/buendia-deploy-*.tar.gz 2>/dev/null || true)
[[ ${#bundles[@]} -eq 1 ]] || die "expected exactly 1 deployment bundle in deploy/, found ${#bundles[@]}.
       Remove the stale ones and re-run tools/make-bundle.sh."
payload="$D/pkgserver/pkgserver-www-${SITE_ID}-*.tar.gz"
mapfile -t payloads < <(ls -1 $payload 2>/dev/null || true)
[[ ${#payloads[@]} -eq 1 ]] || die "expected exactly 1 payload for site '$SITE_ID', found ${#payloads[@]}.
       Build it with pkgserver/publish.sh && pkgserver/pack-www.sh."

for f in "${bundles[0]}" "${bundles[0]}.sha256" "${payloads[0]}" "${payloads[0]}.sha256" \
         "$D/prepare.sh" "$D/tools/bootstrap.sh" "$D/tools/buendia-netcheck.sh" \
         "$D/tools/buendia-backup.sh" "$D/INSTALL-TWO-STEP.md" "$D/UPGRADE.md"; do
  [[ -f "$f" ]] || die "missing: $f"
done
install -m 0755 "$D/prepare.sh"                 "$OUT/prepare.sh"
install -m 0755 "$D/tools/bootstrap.sh"         "$OUT/bootstrap.sh"
install -m 0755 "$D/tools/buendia-netcheck.sh"  "$OUT/buendia-netcheck.sh"
# Named backup.sh at the root, not buendia-backup.sh in a tools folder: it is the first thing
# anyone runs on an upgrade, and it has to be typeable from the guide without hunting.
install -m 0755 "$D/tools/buendia-backup.sh"    "$OUT/backup.sh"
install -m 0644 "$D/INSTALL-TWO-STEP.md"        "$OUT/INSTALL.md"
# A PDF as well as the Markdown: whoever installs this may have no way to render .md, and read
# as plain text it loses the emphasis that tells them which line to type.
if "$HERE/make-install-pdf.sh" --out "$OUT/INSTALL.pdf" >/dev/null 2>&1; then
  echo "    + INSTALL.pdf"
else
  echo "    WARNING: could not build INSTALL.pdf (Chrome refuses to run as root — try as your own user)" >&2
fi

# Both guides travel, because the same stick is used to install and later to upgrade, and the
# upgrade has a backup step and a password answer the install guide does not mention.
#
# UPGRADE.md ends with a section addressed to us — build commands, image digests, what is not yet
# proven end to end. That must not reach the site, so it is cut here at its own heading rather
# than kept as a second, divergent copy of the guide.
awk '/^## Notes for SolDevelo/ { exit } { print }' "$D/UPGRADE.md" \
  | awk '{ l[n++] = $0 } END { while (n > 0 && (l[n-1] == "" || l[n-1] == "---")) n--;
           for (i = 0; i < n; i++) print l[i] }' > "$STAGE/UPGRADE.md"
grep -q 'Notes for SolDevelo' "$STAGE/UPGRADE.md" && die "the internal section survived the cut in UPGRADE.md"
install -m 0644 "$STAGE/UPGRADE.md" "$OUT/UPGRADE.md"
if "$HERE/make-install-pdf.sh" --src "$STAGE/UPGRADE.md" --out "$OUT/UPGRADE.pdf" >/dev/null 2>&1; then
  echo "    + UPGRADE.md + UPGRADE.pdf"
else
  echo "    + UPGRADE.md"
  echo "    WARNING: could not build UPGRADE.pdf (Chrome refuses to run as root — try as your own user)" >&2
fi
install -m 0644 "${bundles[0]}"                 "$OUT/$(basename "${bundles[0]}")"
install -m 0644 "${bundles[0]}.sha256"          "$OUT/$(basename "${bundles[0]}").sha256"
install -m 0644 "${payloads[0]}"                "$OUT/$(basename "${payloads[0]}")"
install -m 0644 "${payloads[0]}.sha256"         "$OUT/$(basename "${payloads[0]}").sha256"
# No install-qr PNG here on purpose: setup.sh generates both codes on the server, from that
# server's own configuration. A copy shipped in the pack could only be the same or wrong.

log "Generating the server env"
if [[ -n "$KEEP" ]]; then "$HERE/make-site-env.sh" --out "$OUT/buendia.env" --keep-passwords "$KEEP"
else                      "$HERE/make-site-env.sh" --out "$OUT/buendia.env"; fi

log "Consistency check: does the payload's APK point at $STATIC_IP?"
tar xzf "${payloads[0]}" -C "$STAGE"
apk="$(find "$STAGE" -name 'buendia-client-*.apk' | head -1)"
[[ -n "$apk" ]] || die "no APK inside the payload."
aapt="$(ls -1d "$HOME"/Android/Sdk/build-tools/*/aapt 2>/dev/null | tail -1 || true)"
if [[ -n "$aapt" && -x "$aapt" ]]; then
  baked="$("$aapt" dump --values resources "$apk" 2>/dev/null | grep -oE 'http://[0-9.]+:9000' | head -1)"
  [[ "$baked" == "http://$STATIC_IP:9000" ]] \
    || die "the APK bakes in '$baked' but STATIC_IP is $STATIC_IP.
       Rebuild the APK and payload for this address (apk/build-apk.sh, then pkgserver/publish.sh
       && pack-www.sh) — a mismatch installs fine and then never connects."
  echo "    ok: APK -> $baked"
else
  echo "    SKIPPED: no aapt on this box, so the address could not be read back out of the APK."
  echo "    Verify by hand before sending: pack-www.sh printed the baked server when it built the payload."
fi

log "Verifying checksums as MSF will see them"
( cd "$OUT" && sha256sum -c ./*.sha256 )

ZIP="$D/buendia-usb-${SITE_ID}-${APK_VERSION}.zip"
rm -f "$ZIP" "$ZIP.sha256"
log "Packing"
( cd "$D" && zip -qr "$ZIP" Buendia )
( cd "$D" && sha256sum "$(basename "$ZIP")" > "$ZIP.sha256" )
printf '\n\033[1;32m==> %s (%s)\033[0m\n' "$(basename "$ZIP")" "$(du -h "$ZIP" | awk '{print $1}')"
echo "    sha256: $(awk '{print $1}' "$ZIP.sha256")"
echo
echo "Send it PRIVATELY — it contains the database passwords and an APK carrying the server password."
echo "MSF unzips it onto a USB stick, giving a 'Buendia' folder. A machine with nothing on it yet"
echo "follows INSTALL.md; a server already in use follows UPGRADE.md."
