#!/usr/bin/env bash
#
# Buendia field-pilot — one-command bootstrap for a fresh Ubuntu box, from a USB stick.
#
#   sudo ./bootstrap.sh --dry-run    # rehearse: prints every change, makes none
#   sudo ./bootstrap.sh              # do it
#
# VALIDATED on real hardware 2026-07-29: an Ubuntu 24 notebook went from a bare install to a GO
# stack, with a tablet installing the APK by QR, using only this script plus the files below on a
# USB stick.
#
# Copy this whole directory to a USB stick. It expects, alongside itself:
#
#   buendia.env                  REQUIRED — becomes <target>/.env. Build it from deploy/.env.example;
#                                           it holds DB passwords, so it is NEVER committed.
#   buendia-deploy-*.tar.gz      the deployment bundle (deploy/tools/make-bundle.sh). If absent, it
#                                           is downloaded from BUNDLE_URL.
#   pkgserver-www-*.tar.gz       optional — the tablet APK payload. If present it is used directly
#                                           and NO GitHub token is needed.
#   token.txt                    optional — a GitHub fine-grained PAT (read-only, scoped to the
#                                           artifacts repo) to fetch that payload if it is not on
#                                           the USB. One line.
#
# NOTE this deliberately does NOT clone the git repository. A clone would put CLAUDE.md, the whole
# docs/ set, .claude/skills/, the entire source tree and ~76 MB of history onto a machine that ships
# to a site and is handled outside SolDevelo. The bundle is ~36 KB and holds only what runs.
#
# Everything else (Docker, the container images) comes from the network: the box needs internet
# during setup and never again afterwards.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${TARGET:-/opt/buendia}"
BUNDLE_URL="${BUNDLE_URL:-}"   # e.g. https://github.com/SolDevelo/buendia/releases/download/<tag>/buendia-deploy-<ver>.tar.gz
PASSTHRU=("$@")                # forwarded verbatim to setup.sh

log()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mWARN: %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

DRY=0
# NB "${arr[@]:-}" on an EMPTY array expands to one empty-string argument, which would both make
# this loop run once with a="" and pass a bogus "" arg to setup.sh ("unknown arg"). Guard on length.
if [[ ${#PASSTHRU[@]} -gt 0 ]]; then
  for a in "${PASSTHRU[@]}"; do [[ "$a" == "--dry-run" ]] && DRY=1; done
fi

[[ $EUID -eq 0 || $DRY -eq 1 ]] || die "run with sudo."
[[ -f "$HERE/buendia.env" ]] || die "buendia.env not found next to this script (expected on the USB)."

log "Bootstrap  ->  $TARGET"
echo "  usb dir : $HERE"
[[ $DRY -eq 1 ]] && echo "  MODE    : DRY RUN (nothing will be changed)"

# Verify a copied/downloaded file against a sibling .sha256, when there is one.
check_sha() {
  local f="$1"
  [[ -f "$f.sha256" ]] || { warn "no $(basename "$f").sha256 beside it — not verified"; return 0; }
  local want; want="$(awk '{print $1}' "$f.sha256")"
  local got;  got="$(sha256sum "$f" | cut -d' ' -f1)"
  [[ "$want" == "$got" ]] || die "checksum mismatch on $(basename "$f") — bad copy or truncated download."
  echo "  checksum OK (${got:0:12})"
}

# Pick the tarball, not its .sha256 sibling, from a glob.
pick_tar() {
  local out=""
  local f
  for f in "$@"; do [[ "$f" == *.sha256 ]] || out="$f"; done
  printf '%s' "$out"
}

# ---------------------------------------------------------------------------
# 1. Prerequisites for the bootstrap itself (Docker is installed by setup.sh)
# ---------------------------------------------------------------------------
log "Prerequisites (curl; tar is in the base system)"
if command -v curl >/dev/null; then
  echo "  already present"
elif [[ $DRY -eq 1 ]]; then
  echo "  [dry-run] apt-get update && apt-get install -y curl ca-certificates"
else
  apt-get update
  apt-get install -y curl ca-certificates
fi

# ---------------------------------------------------------------------------
# 2. Get the deployment bundle (USB first, else download). No git clone: see the note above.
# ---------------------------------------------------------------------------
log "Deployment bundle"
shopt -s nullglob
bundle="$(pick_tar "$HERE"/buendia-deploy-*.tar.gz)"
shopt -u nullglob

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
src=""
if [[ -n "$bundle" ]]; then
  echo "  found on the USB: $(basename "$bundle")"
  check_sha "$bundle"
  src="$bundle"
elif [[ -n "$BUNDLE_URL" ]]; then
  echo "  downloading: $BUNDLE_URL"
  if [[ $DRY -eq 1 ]]; then
    echo "  [dry-run] curl -fsSLo <tmp>/bundle.tar.gz '$BUNDLE_URL'"
  else
    curl -fsSLo "$tmp/bundle.tar.gz" "$BUNDLE_URL" || die "download failed: $BUNDLE_URL"
    curl -fsSLo "$tmp/bundle.tar.gz.sha256" "$BUNDLE_URL.sha256" 2>/dev/null || true
    check_sha "$tmp/bundle.tar.gz"
    src="$tmp/bundle.tar.gz"
  fi
else
  die "no buendia-deploy-*.tar.gz on the USB, and BUNDLE_URL is not set.
       Build one with deploy/tools/make-bundle.sh and copy it next to this script, or set
       BUNDLE_URL to a release-asset URL."
fi

if [[ $DRY -eq 1 ]]; then
  echo "  [dry-run] unpack into $TARGET"
elif [[ -n "$src" ]]; then
  install -d "$TARGET"
  # --strip-components=1: the tarball holds a top-level buendia-deploy/ directory.
  tar xzf "$src" -C "$TARGET" --strip-components=1
  echo "  unpacked into $TARGET"
  [[ -x "$TARGET/setup.sh" ]] || die "$TARGET/setup.sh missing after unpack — wrong bundle?"
  grep -m1 '^version:' "$TARGET/MANIFEST.txt" 2>/dev/null | sed 's/^/  bundle /' || true
fi

DEPLOY="$TARGET"

# ---------------------------------------------------------------------------
# 3. Install the .env from the USB
# ---------------------------------------------------------------------------
log "Installing .env from the USB"
if [[ $DRY -eq 1 ]]; then
  echo "  [dry-run] install -m 0600 $HERE/buendia.env $DEPLOY/.env"
else
  install -m 0600 "$HERE/buendia.env" "$DEPLOY/.env"
  echo "  wrote $DEPLOY/.env (0600)"
fi

# ---------------------------------------------------------------------------
# 4. The tablet payload: local tarball, else a token for the private release
# ---------------------------------------------------------------------------
log "Tablet APK payload"
shopt -s nullglob
payload="$(pick_tar "$HERE"/pkgserver-www-*.tar.gz)"
shopt -u nullglob

TOKEN=""
if [[ -n "$payload" ]]; then
  echo "  found on the USB: $(basename "$payload") — using it, no token needed"
  check_sha "$payload"
  if [[ $DRY -eq 1 ]]; then
    echo "  [dry-run] unpack into $DEPLOY/pkgserver/www and set APK_SOURCE=local"
  else
    install -d "$DEPLOY/pkgserver/www"
    tar xzf "$payload" -C "$DEPLOY/pkgserver/www"
    # www/ is populated, so setup.sh will not try to download. Make that explicit.
    sed -i 's|^APK_SOURCE=.*|APK_SOURCE=local|' "$DEPLOY/.env"
    echo "  unpacked $(ls "$DEPLOY/pkgserver/www"/*.apk 2>/dev/null | xargs -n1 basename | tr '\n' ' ')"
  fi
elif [[ -s "$HERE/token.txt" ]]; then
  TOKEN="$(tr -d ' \t\r\n' < "$HERE/token.txt")"
  echo "  using the token in token.txt (${#TOKEN} chars) to fetch the private release"
elif [[ $DRY -eq 1 ]]; then
  echo "  [dry-run] would prompt for a GitHub token"
else
  echo "  No payload tarball and no token.txt on the USB."
  echo "  Paste a GitHub fine-grained PAT (read-only, artifacts repo only), or press Enter to"
  echo "  skip the tablet APK and set it up later:"
  read -rsp "  token: " TOKEN; echo
  [[ -n "$TOKEN" ]] || warn "no token — the server will come up but tablets will have nothing to install."
fi

# ---------------------------------------------------------------------------
# 5. Hand over to the real installer
# ---------------------------------------------------------------------------
log "Running setup.sh"
if ! cd "$DEPLOY" 2>/dev/null; then
  if [[ $DRY -eq 1 ]]; then
    log "Dry run: $DEPLOY does not exist yet (nothing was unpacked), so stopping here."
    exit 0
  fi
  die "$DEPLOY is missing."
fi
rc=0
if [[ ${#PASSTHRU[@]} -gt 0 ]]; then
  if [[ -n "$TOKEN" ]]; then GITHUB_TOKEN="$TOKEN" ./setup.sh "${PASSTHRU[@]}" || rc=$?
  else                        ./setup.sh "${PASSTHRU[@]}" || rc=$?; fi
else
  if [[ -n "$TOKEN" ]]; then GITHUB_TOKEN="$TOKEN" ./setup.sh || rc=$?
  else                        ./setup.sh || rc=$?; fi
fi

# ---------------------------------------------------------------------------
log "Bootstrap finished (setup.sh exit: $rc)"
if [[ $rc -eq 0 && $DRY -eq 0 ]]; then
  ip="$(grep -E "^STATIC_IP=" "$DEPLOY/.env" | cut -d= -f2 | sed "s/#.*//" | tr -d "[:space:]")"
  cat <<TXT

  Next, from ANOTHER machine on the same network (this is the check that matters — tablets are
  remote clients, so localhost proving out is not enough):

      curl -s -o /dev/null -w '%{http_code}\n' -u buendia:buendia \\
        http://$ip:9000/openmrs/ws/rest/buendia/locations        # want 200
      curl -sI http://$ip:9001/latest.apk | head -1              # want 200

  If those hang while this box was fine locally, it is the firewall:
      sudo ufw status ; sudo ufw allow 9000,9001/tcp

  Tablet: browse to  http://$ip:9001/  and install from the QR or the link.
TXT
  if [[ -s "$HERE/token.txt" ]]; then
    echo "  ⚠️  token.txt is still on the USB stick. Delete it now that setup has run:"
    echo "        shred -u '$HERE/token.txt'   # or just delete it"
  fi
fi
exit $rc
