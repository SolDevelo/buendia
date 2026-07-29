#!/usr/bin/env bash
#
# Buendia field-pilot — one-command bootstrap for a fresh Ubuntu box, from a USB stick.
#
# VALIDATED on real hardware 2026-07-29: an Ubuntu 24 notebook went from bare install to a
# GO stack, with a tablet installing the APK by QR, using only this script + buendia.env
# + the payload tarball on a USB stick.
#
#   sudo ./buendia-notebook-setup.sh --dry-run    # rehearse: prints every change, makes none
#   sudo ./buendia-notebook-setup.sh              # do it
#
# Copy this whole directory to a USB stick. It expects, alongside itself:
#
#   buendia.env                          REQUIRED — becomes <clone>/deploy/.env. Build it from
#                                                   deploy/.env.example; it holds DB passwords, so
#                                                   it is NEVER committed.
#   token.txt                            optional — a GitHub fine-grained PAT, read-only, scoped to
#                                                   SolDevelo/buendia-pilot-artifacts. One line.
#   pkgserver-www-*.tar.gz               optional — the tablet payload. If present, it is used
#                                                   directly and NO token is needed at all.
#
# Precedence for the tablet APK payload: local tarball on the USB > token.txt > interactive prompt.
#
# Everything else (Docker, the images, the seed) comes from the network: this box needs internet
# during setup and never again afterwards.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_URL="${REPO_URL:-https://github.com/SolDevelo/buendia.git}"
REPO_REF="${REPO_REF:-drc-pilot}"          # branch or tag to deploy from
TARGET="${TARGET:-/opt/buendia}"
PASSTHRU=("$@")                            # forwarded verbatim to deploy/setup.sh

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

log "Bootstrap: $REPO_URL @ $REPO_REF  ->  $TARGET"
echo "  usb dir : $HERE"
[[ $DRY -eq 1 ]] && echo "  MODE    : DRY RUN (nothing will be changed)"

# ---------------------------------------------------------------------------
# 1. Prerequisites for the bootstrap itself (Docker is installed by deploy/setup.sh)
# ---------------------------------------------------------------------------
log "Installing git + curl if needed"
if command -v git >/dev/null && command -v curl >/dev/null; then
  echo "  already present"
elif [[ $DRY -eq 1 ]]; then
  echo "  [dry-run] apt-get update && apt-get install -y git curl ca-certificates"
else
  apt-get update
  apt-get install -y git curl ca-certificates
fi

# ---------------------------------------------------------------------------
# 2. Get the deployment package
# ---------------------------------------------------------------------------
# --no-recurse-submodules matters: this repo has a db-snapshot submodule of ~hundreds of MB that a
# deployment does not need (the seed lives inside the DB image) and a client submodule for the
# Android build, which does not happen here.
log "Fetching the deployment package"
if [[ -d "$TARGET/.git" ]]; then
  echo "  $TARGET already exists — reusing it (idempotent)"
  if [[ $DRY -eq 0 ]]; then
    git -C "$TARGET" fetch --depth 1 origin "$REPO_REF"
    git -C "$TARGET" checkout -q FETCH_HEAD
  fi
elif [[ $DRY -eq 1 ]]; then
  echo "  [dry-run] git clone --depth 1 --no-recurse-submodules -b $REPO_REF $REPO_URL $TARGET"
else
  git clone --depth 1 --no-recurse-submodules -b "$REPO_REF" "$REPO_URL" "$TARGET"
fi
echo "  at: $(git -C "$TARGET" log --oneline -1 2>/dev/null || echo '(not cloned yet — dry run)')"

DEPLOY="$TARGET/deploy"
[[ -d "$DEPLOY" || $DRY -eq 1 ]] || die "$DEPLOY missing — is $REPO_REF the right ref?"

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
local_tars=("$HERE"/pkgserver-www-*.tar.gz)
shopt -u nullglob

TOKEN=""
if [[ ${#local_tars[@]} -gt 0 ]]; then
  tar_src="${local_tars[0]}"
  echo "  found on the USB: $(basename "$tar_src") — using it, no token needed"
  if [[ -f "$tar_src.sha256" ]]; then
    want="$(awk '{print $1}' "$tar_src.sha256")"
    got="$(sha256sum "$tar_src" | cut -d' ' -f1)"
    [[ "$want" == "$got" ]] || die "checksum mismatch on $(basename "$tar_src") — bad copy to USB?"
    echo "  checksum OK (${got:0:12})"
  else
    warn "no .sha256 beside it — payload not verified"
  fi
  if [[ $DRY -eq 1 ]]; then
    echo "  [dry-run] unpack into $DEPLOY/pkgserver/www and set APK_SOURCE=local"
  else
    install -d "$DEPLOY/pkgserver/www"
    tar xzf "$tar_src" -C "$DEPLOY/pkgserver/www"
    # www/ is already populated, so setup.sh will not try to download. Make that explicit.
    sed -i 's|^APK_SOURCE=.*|APK_SOURCE=local|' "$DEPLOY/.env"
    echo "  unpacked $(ls "$DEPLOY/pkgserver/www"/*.apk | xargs -n1 basename | tr '\n' ' ')"
  fi
elif [[ -s "$HERE/token.txt" ]]; then
  TOKEN="$(tr -d ' \t\r\n' < "$HERE/token.txt")"
  echo "  using the token in token.txt (${#TOKEN} chars) to fetch the private release"
elif [[ $DRY -eq 1 ]]; then
  echo "  [dry-run] would prompt for a GitHub token"
else
  echo "  No payload tarball and no token.txt on the USB."
  echo "  Paste a GitHub fine-grained PAT (read-only, buendia-pilot-artifacts only), or press"
  echo "  Enter to skip the tablet APK entirely and set it up later:"
  read -rsp "  token: " TOKEN; echo
  [[ -n "$TOKEN" ]] || warn "no token — the server will come up but tablets will have nothing to install."
fi

# ---------------------------------------------------------------------------
# 5. Hand over to the real installer
# ---------------------------------------------------------------------------
log "Running deploy/setup.sh"
cd "$DEPLOY"
rc=0
if [[ ${#PASSTHRU[@]} -gt 0 ]]; then
  if [[ -n "$TOKEN" ]]; then GITHUB_TOKEN="$TOKEN" ./setup.sh "${PASSTHRU[@]}" || rc=$?
  else                        ./setup.sh "${PASSTHRU[@]}" || rc=$?; fi
else
  if [[ -n "$TOKEN" ]]; then GITHUB_TOKEN="$TOKEN" ./setup.sh || rc=$?
  else                        ./setup.sh || rc=$?; fi
fi

# ---------------------------------------------------------------------------
log "Bootstrap finished (deploy/setup.sh exit: $rc)"
if [[ $rc -eq 0 && $DRY -eq 0 ]]; then
  ip="$(grep -E "^STATIC_IP=" "$DEPLOY/.env" | cut -d= -f2 | sed "s/#.*//" | tr -d "[:space:]")"
  cat <<TXT

  Next, from ANOTHER machine on the same WiFi (this is the check that matters — tablets are
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
