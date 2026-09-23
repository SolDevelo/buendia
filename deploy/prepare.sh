#!/usr/bin/env bash
# Buendia field pilot — STEP 1 of 2: everything that needs the internet.
#
#   sudo ./prepare.sh
#
# Run it from the Buendia folder on the USB stick, with the laptop connected to the internet by
# any means. It asks a few questions, copies the software onto this machine, installs Docker and
# downloads the Buendia containers. It deliberately does NOT change this machine's network
# settings and starts nothing, so it cannot disturb the connection it is using.
#
# Step 2 is /opt/buendia/setup.sh, run after the laptop is cabled to the Buendia router.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${TARGET:-/opt/buendia}"

B=$'\033[1m'; C=$'\033[1;36m'; G=$'\033[1;32m'; Y=$'\033[1;33m'; R=$'\033[1;31m'; N=$'\033[0m'
log()  { printf '\n%s==> %s%s\n' "$C" "$*" "$N"; }
die()  { printf '%sERROR: %s%s\n' "$R" "$*" "$N" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "run this with sudo:   sudo ./prepare.sh"
[[ -f "$HERE/buendia.env" ]] || die "buendia.env is missing from this folder — the USB pack is incomplete."

printf '%sBuendia server — step 1 of 2 (needs the internet)%s\n' "$B" "$N"
echo "This asks a few questions, then downloads about 800 MB. Nothing is started yet."

# Read the shipped defaults, so every answer can simply be accepted with Enter.
set -a; . "$HERE/buendia.env"; set +a

# On an UPGRADE the shipped defaults are the wrong ones to offer. They come from our build
# machine, while the site may have typed its own answers at the first install — and since
# bootstrap.sh installs this file over <target>/.env wholesale, "press Enter to accept" would
# then quietly replace the site's settings with ours. The Wi-Fi password is the one that hurts:
# setup.sh hands it to the router, so every tablet would drop off the network at once.
#
# So when there is already an installation here, its own values are what gets offered. Only
# these few keys: everything else in the new file (image digests, addresses, the payload) is
# the point of the upgrade and must come from the stick.
live() {   # live <VAR> -> that variable's value in the installed .env, empty if there is none
  [[ -f "$TARGET/.env" ]] || return 0
  ( set -a; . "$TARGET/.env" >/dev/null 2>&1; set +a; printf '%s' "${!1:-}" ) 2>/dev/null || true
}
UPGRADE=0
if [[ -f "$TARGET/.env" ]]; then
  UPGRADE=1
  for k in SITE_FACILITY_NAME SITE_WIFI_SSID SITE_WIFI_PASSWORD APK_OPENMRS_PASSWORD; do
    v="$(live "$k")"
    [[ -n "$v" ]] && printf -v "$k" '%s' "$v"
  done
  printf '\n  %sThis machine already runs Buendia.%s The answers below are the ones it uses now —\n' "$Y" "$N"
  printf '  press Enter to keep each of them.\n'
fi

ask() {                       # ask <prompt> <current> -> ANSWER
  local prompt="$1" current="$2" reply
  read -r -p "  $prompt [$current]: " reply </dev/tty || reply=""
  ANSWER="${reply:-$current}"
}
ask_secret() {                # same, but does not echo, and confirms
  local prompt="$1" current="$2" a b
  while :; do
    read -r -s -p "  $prompt [keep current]: " a </dev/tty; echo
    [[ -z "$a" ]] && { ANSWER="$current"; return 0; }
    read -r -s -p "  repeat it: " b </dev/tty; echo
    [[ "$a" == "$b" ]] && { ANSWER="$a"; return 0; }
    printf '  %sthey do not match — try again%s\n' "$Y" "$N"
  done
}

log "Site details"
ask "Facility name (appears in the app)" "${SITE_FACILITY_NAME:-Buendia}";  NEW_FACILITY="$ANSWER"
ask "Wi-Fi name (SSID) of the Buendia router" "${SITE_WIFI_SSID:-MSF-Buendia}"; NEW_SSID="$ANSWER"
ask "Wi-Fi password" "${SITE_WIFI_PASSWORD:-}";                            NEW_WIFIPW="$ANSWER"
[[ ${#NEW_WIFIPW} -ge 8 ]] || die "the Wi-Fi password must be at least 8 characters."

log "Clinical login used on the tablets"
cat <<TXT
  The tablets have this password built in. If you change it here, every tablet has to be
  updated by hand (in the app: cog > Settings > password) and cannot sync until it is.
  Press Enter to keep the one the tablets already carry.
TXT
ask_secret "Password for the 'buendia' login" "${APK_OPENMRS_PASSWORD:-buendia}"; NEW_APPPW="$ANSWER"

log "Writing the configuration"
ENVF="$HERE/.buendia.env.tmp"; trap 'rm -f "$ENVF"' EXIT
umask 077
# Rewrite only the answered keys; everything else (addresses, image digests) is kept exactly as
# shipped — those are matched to the tablet app and must not be edited here.
sed -e "s|^SITE_FACILITY_NAME=.*|SITE_FACILITY_NAME='$NEW_FACILITY'|" \
    -e "s|^SITE_WIFI_SSID=.*|SITE_WIFI_SSID='$NEW_SSID'|" \
    -e "s|^SITE_WIFI_PASSWORD=.*|SITE_WIFI_PASSWORD='$NEW_WIFIPW'|" \
    "$HERE/buendia.env" > "$ENVF"
if [[ "$NEW_APPPW" != "${APK_OPENMRS_PASSWORD:-buendia}" ]]; then   # NB now the offered default
  printf '  %severy tablet will need its password changed by hand to match%s\n' "$Y" "$N"
fi
# setup.sh rotates the server account to whatever this says, so it is the single source of truth.
sed -i "s|^APK_OPENMRS_PASSWORD=.*|APK_OPENMRS_PASSWORD=$NEW_APPPW|" "$ENVF"

# The database credentials are not a question anyone can be asked: MySQL keeps them inside the
# data directory, so on a machine that already holds a database the running one is the only
# possible answer and a pack built with the wrong value would simply fail to start. The pack is
# built with --keep-passwords to carry them, but this makes it impossible to get wrong.
if [[ $UPGRADE -eq 1 ]]; then
  for k in MYSQL_ROOT_PASSWORD MYSQL_PASSWORD; do
    v="$(live "$k")"
    [[ -n "$v" ]] || continue
    if [[ "$v" != "$(set -a; . "$ENVF"; set +a; printf '%s' "${!k}")" ]]; then
      printf '  %skeeping this server'"'"'s %s — the database will not open with any other%s\n' "$Y" "$k" "$N"
    fi
    sed -i "s|^$k=.*|$k=$v|" "$ENVF"
  done
fi
echo "  ok"

log "Copying the software onto this machine and downloading the containers"
BUENDIA_ENV="$ENVF" "$HERE/bootstrap.sh" --prepare
