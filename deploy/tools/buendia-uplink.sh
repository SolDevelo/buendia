#!/usr/bin/env bash
# Report how this server is connected, in plain language — for the person standing in front of
# it, reading the answers down a phone line.
#
#   ./buendia-uplink.sh            # read-only status
#   ./buendia-uplink.sh --env /opt/buendia/.env
#
# The pilot server takes its internet by joining a third-party Wi-Fi ITSELF (the site's Wi-Fi,
# MSF's corporate Wi-Fi, or a phone tethered over USB) while staying cabled to the Buendia
# router for the tablets. That is two networks at once, and three things can go wrong in ways
# nobody would guess from the screen:
#
#   1. the clinical side stops working, because the wired address went away;
#   2. the internet looks connected but is a captive portal waiting for somebody to click;
#   3. the Wi-Fi hands out addresses in the SAME range as the Buendia LAN, which breaks
#      tablet traffic in a way that looks like the server crashed.
#
# Being on two networks at once is the NORMAL state for this pilot, not an anomaly: MSF reach
# the laptop with TeamViewer over whatever Wi-Fi it is joined to, while the tablets keep using
# the cabled Buendia network. So this script reports that arrangement as the expected picture —
# including whether patient data or a remote-login service is exposed to the joined network, and
# which address to open Buendia on. Nothing here changes anything.
#
# Exit 0 = nothing wrong. Exit 1 = something is genuinely wrong (each one is spelled out).
set -uo pipefail   # NB: not -e; a failing check must be reported, not abort the run

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$HERE/../.env"

while [ $# -gt 0 ]; do
  case "$1" in
    --env)     ENV_FILE="$2"; shift 2 ;;
    -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1 (try --help)" >&2; exit 2 ;;
  esac
done

# .env is optional: without it the shipping defaults still describe the pilot correctly.
if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  if (set -a; . "$ENV_FILE"; set +a) 2>/dev/null; then
    set -a; . "$ENV_FILE"; set +a
  else
    echo "WARNING: $ENV_FILE could not be read — using defaults" >&2
  fi
fi
STATIC_IP="${STATIC_IP:-192.168.8.10}"
PREFIX="${NET_PREFIX:-24}"
BIND="${LAN_BIND:-}"

pass_n=0; fail_n=0; warn_n=0
g="\033[32m"; r="\033[31m"; y="\033[33m"; d="\033[2m"; z="\033[0m"
[ -t 1 ] || { g=""; r=""; y=""; d=""; z=""; }
ok()   { printf "  ${g}OK${z}    %-30s ${d}%s${z}\n" "$1" "${2:-}"; pass_n=$((pass_n+1)); }
bad()  { printf "  ${r}WRONG${z} %-30s %s\n"         "$1" "${2:-}"; fail_n=$((fail_n+1)); }
warn() { printf "  ${y}CHECK${z} %-30s %s\n"         "$1" "${2:-}"; warn_n=$((warn_n+1)); }
info() { printf "  ${d}····  %-30s %s${z}\n"         "$1" "${2:-}"; }
note() { printf "        ${d}%s${z}\n" "$1"; }
head_() { printf "\n${d}── %s ${z}\n" "$1"; }

# The comparable leading part of an address under the configured mask. Only the shipping /24
# and a /16 are handled; anything else returns nothing and the overlap test is skipped rather
# than answered wrongly.
netkey() {
  case "$PREFIX" in
    24) echo "${1%.*}" ;;
    16) echo "$1" | cut -d. -f1,2 ;;
    *)  echo "" ;;
  esac
}
LAN_KEY="$(netkey "$STATIC_IP")"

# ── The clinical side: can the tablets reach this server at all? ─────────────
head_ "The Buendia network (the tablets)"
LAN_IFACE="$(ip -o -4 addr show 2>/dev/null \
  | awk -v ip="$STATIC_IP" '{split($4,a,"/"); if (a[1]==ip) {print $2; exit}}')"
if [ -n "$LAN_IFACE" ]; then
  ok "server address $STATIC_IP" "on $LAN_IFACE"
else
  bad "server address $STATIC_IP" "NOT on this machine"
  note "Every tablet is set to this address, so nothing can sync until it is back."
  note "Usually the network cable is out. Plug it in, wait 20 seconds, run this again."
fi

# ── The way out: which connection carries the internet? ─────────────────────
head_ "The way out to the internet"
# Lowest metric wins, which is the whole point of NET_ROUTE_METRIC: the wired route to the
# Buendia router is weighted to LOSE to any real uplink.
DEF="$(ip -o -4 route show default 2>/dev/null \
  | awk '{m=1e9; for(i=1;i<=NF;i++){if($i=="dev")dev=$(i+1); if($i=="via")via=$(i+1); if($i=="metric")m=$(i+1)} print m, dev, via}' \
  | sort -n | head -1)"
UP_IFACE="$(echo "$DEF" | awk '{print $2}')"
UP_VIA="$(echo "$DEF" | awk '{print $3}')"
UP_METRIC="$(echo "$DEF" | awk '{print $1}')"

if [ -z "$UP_IFACE" ]; then
  info "no connection to the internet" "normal during clinical use"
  note "The tablets and the server work exactly as usual. Remote support is simply asleep."
elif [ "$UP_IFACE" = "$LAN_IFACE" ]; then
  info "via the Buendia router" "$UP_IFACE, metric $UP_METRIC"
  note "Internet would have to come from the router's own uplink, which the pilot does not use."
else
  ok "via $UP_IFACE" "gateway $UP_VIA, metric $UP_METRIC"
  note "This is the expected setup: Wi-Fi or a tethered phone carries the internet."
fi

# ── Does the internet actually work, or is a portal waiting? ────────────────
if [ -n "$UP_IFACE" ]; then
  # A 204 with no body is the whole point of this endpoint: anything else means something is
  # answering on its behalf, which is what a hotel/office/corporate sign-in page does.
  CODE="$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 \
      http://connectivitycheck.gstatic.com/generate_204 2>/dev/null)"
  case "$CODE" in
    204) ok "internet reachable" "remote support can reach this machine" ;;
    000) bad "internet not reachable" "connected to $UP_IFACE, but nothing gets through"
         note "The Wi-Fi may need a password re-entered, or it may have no internet itself." ;;
    *)   warn "a sign-in page is in the way" "got HTTP $CODE, expected 204"
         note "Open a web browser on this laptop and accept/sign in to the Wi-Fi, then re-run." ;;
  esac
fi

# ── The collision that looks like a crashed server ──────────────────────────
head_ "Address clash with the Buendia network"
if [ -z "$LAN_KEY" ]; then
  info "not checked" "unusual netmask (/$PREFIX)"
else
  CLASH=""
  while read -r iface addr; do
    [ "$iface" = "lo" ] && continue
    [ "$iface" = "$LAN_IFACE" ] && continue
    [ "$(netkey "$addr")" = "$LAN_KEY" ] && CLASH="$CLASH $iface($addr)"
  done <<EOF
$(ip -o -4 addr show 2>/dev/null | awk '{split($4,a,"/"); print $2, a[1]}')
EOF
  if [ -n "$CLASH" ]; then
    bad "another network uses $LAN_KEY.x" "$(echo "$CLASH" | sed 's/^ //')"
    note "This machine now has two networks claiming the same addresses, and tablet traffic"
    note "can go the wrong way. Disconnect that Wi-Fi and use a phone hotspot instead."
  else
    ok "no clash" "nothing else uses $LAN_KEY.x"
  fi
fi

# ── Is patient data exposed to the network we just joined? ──────────────────
head_ "Who can reach the patient data"
case "$BIND" in
  ""|0.0.0.0)
    if [ -n "$UP_IFACE" ] && [ "$UP_IFACE" != "$LAN_IFACE" ]; then
      bad "open to $UP_IFACE as well" "LAN_BIND is not set"
      note "Anyone else on that Wi-Fi can open Buendia and download the tablet app."
      note "Fix: set LAN_BIND=$STATIC_IP in the configuration and restart the stack."
    else
      warn "open on every connection" "LAN_BIND is not set"
      note "Harmless while this machine is only on the Buendia network, but set"
      note "LAN_BIND=$STATIC_IP before it is ever joined to another Wi-Fi."
    fi ;;
  "$STATIC_IP")
    ok "only the Buendia network" "published on $BIND" ;;
  *)
    warn "published on $BIND" "expected $STATIC_IP"
    note "If that is not an address the tablets can reach, they cannot sync." ;;
esac

# The address to type. Worth stating every run: over TeamViewer the obvious thing to try is
# localhost, and once LAN_BIND is set that HANGS instead of refusing — indistinguishable from a
# dead server unless you already know.
if [ -n "$LAN_IFACE" ]; then
  info "open Buendia at" "http://$STATIC_IP:${OPENMRS_PORT:-9000}/openmrs"
  [ -n "$BIND" ] && [ "$BIND" != "0.0.0.0" ] \
    && note "Not http://localhost:${OPENMRS_PORT:-9000} — that one hangs forever, by design."
else
  warn "Buendia cannot be opened" "the server address is not up"
  note "http://$STATIC_IP:${OPENMRS_PORT:-9000}/openmrs will hang until the cable is back."
fi

# ── Remote login exposed to that same network ───────────────────────────────
# Nothing in this deployment installs or enables an SSH SERVER: setup.sh installs
# openssh-CLIENT (to configure the router), and Tailscale SSH is served by tailscaled itself,
# not by a host sshd. But Ubuntu Server's installer offers "Install OpenSSH server" as a
# checkbox, so whether one is listening depends on how this laptop was installed — which is
# exactly why it is checked here rather than assumed either way.
head_ "Remote login (SSH)"
if ! command -v ss >/dev/null 2>&1; then
  info "not checked" "the 'ss' command is not installed"
else
  SSH_ON="$(ss -ltnH 2>/dev/null | awk '$4 ~ /:22$/ {print $4}' | sed 's/:22$//; s/^\[//; s/\]$//' | sort -u)"
  SSH_ANY=""
  for a in $SSH_ON; do
    case "$a" in
      0.0.0.0|::|'*') SSH_ANY="yes" ;;
    esac
  done
  if [ -z "$SSH_ON" ]; then
    ok "no SSH server running" "nothing to expose"
  elif [ -n "$SSH_ANY" ] && [ -n "$UP_IFACE" ] && [ "$UP_IFACE" != "$LAN_IFACE" ]; then
    bad "SSH open to $UP_IFACE too" "listening on every connection"
    note "Everyone on that Wi-Fi is offered a login prompt on this server. Either switch it off"
    note "(sudo systemctl disable --now ssh) or bind it to $STATIC_IP in /etc/ssh/sshd_config."
    note "Support over the tunnel does not need it: Tailscale serves SSH itself."
  elif [ -n "$SSH_ANY" ]; then
    warn "SSH listening on everything" "$(echo "$SSH_ON" | tr '\n' ' ')"
    note "Harmless while this machine is only on the Buendia network — but it would be offered"
    note "to any Wi-Fi it joins. Bind it to $STATIC_IP, or switch it off before travelling."
  else
    ok "SSH limited" "$(echo "$SSH_ON" | tr '\n' ' ')"
  fi
fi

# ── Remote support ──────────────────────────────────────────────────────────
# The pilot's channel is TeamViewer, installed and run by MSF on their own account. We neither
# install nor configure it, so this only LOOKS for it and reports what it finds — it is part of
# the connection picture, not a finding. The Tailscale tunnel below is parked: shipped installed
# and switched off, kept for the day support needs something scripted.
head_ "Remote support"

TV_BIN=""; TV_RUN=""
command -v teamviewer >/dev/null 2>&1 && TV_BIN="yes"
if command -v pgrep >/dev/null 2>&1; then
  pgrep -x teamviewerd >/dev/null 2>&1 && TV_RUN="yes"
fi
if [ -n "$TV_RUN" ]; then
  if [ -n "$UP_IFACE" ]; then
    ok "TeamViewer running" "reachable while $UP_IFACE has internet"
  else
    info "TeamViewer running" "but this machine has no internet right now"
    note "It will be reachable again as soon as the laptop is back on a Wi-Fi."
  fi
elif [ -n "$TV_BIN" ]; then
  # Attended access is the working assumption (2026-09-23): somebody on site starts TeamViewer when
  # support is needed, so "installed, not running" is the EXPECTED steady state. Flagging it as a
  # problem would teach the reader to ignore this script's warnings, which is the opposite of the job.
  info "TeamViewer installed" "not running at the moment — that is normal"
  note "Start it when support is needed; support cannot reach this machine until somebody does."
else
  info "TeamViewer not detected" "nothing installed on this machine"
  note "If MSF expect to support this server remotely, it belongs here — it is their tool,"
  note "on their account, and nothing in the Buendia package installs or configures it."
fi

# Parked fallback. Absent is the shipping state and says nothing is wrong.
if command -v tailscale >/dev/null 2>&1; then
  STATE="$(tailscale status --json 2>/dev/null \
    | grep -o '"BackendState":[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([A-Za-z]*\)"$/\1/')"
  TSIP="$(tailscale ip -4 2>/dev/null | head -1)"
  case "$STATE" in
    Running) ok "backup tunnel connected" "this server is ${TSIP:-reachable} to support" ;;
    *)       info "backup tunnel off" "${STATE:-not started} — the shipped state" ;;
  esac
fi

# ── Verdict ─────────────────────────────────────────────────────────────────
printf "\n"
if [ "$fail_n" -gt 0 ]; then
  printf "${r}%s thing(s) wrong${z}, %s to check, %s fine\n" "$fail_n" "$warn_n" "$pass_n"
  exit 1
fi
printf "${g}Nothing wrong${z} — %s to check, %s fine\n" "$warn_n" "$pass_n"
exit 0
