#!/usr/bin/env bash
# Buendia field pilot — pre-install network check.
#
# Answers the one question a technician cannot answer without us: "is this box wired to the
# Buendia router correctly, and what do I put in NET_IFACE?" Runs on a BARE Ubuntu box before
# anything is installed, from the USB stick, as an ordinary user.
#
# Deliberately depends on nothing but bash, iproute2, ping and /sys — no ethtool, no dig, no
# curl, no nmcli. Those are exactly what a fresh install may not have, and a diagnostic that
# cannot run when things are broken is not a diagnostic.
#
#   ./buendia-netcheck.sh              read-only: report and advise
#   sudo ./buendia-netcheck.sh --renew  also force a DHCP renew on the wired interface
#
# Exit 0 = ready to install. Exit 1 = something needs fixing first (the report says what).
set -uo pipefail

ROUTER="${ROUTER_IP:-192.168.8.1}"
SERVER="${STATIC_IP:-192.168.8.10}"
SUBNET_PREFIX="${ROUTER%.*}."            # 192.168.8.
RENEW=0
for a in "$@"; do
  case "$a" in
    --renew) RENEW=1 ;;
    -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $a (try --help)" >&2; exit 1 ;;
  esac
done

B=$'\033[1m'; R=$'\033[0;31m'; G=$'\033[0;32m'; Y=$'\033[1;33m'; C=$'\033[1;36m'; N=$'\033[0m'
hdr()  { printf '\n%s== %s%s\n' "$C" "$1" "$N"; }
ok()   { printf '  %s OK  %s %s\n'   "$G" "$N" "$1"; }
warn() { printf '  %s WARN%s %s\n'   "$Y" "$N" "$1"; PROBLEMS=$((PROBLEMS+1)); }
bad()  { printf '  %s FAIL%s %s\n'   "$R" "$N" "$1"; PROBLEMS=$((PROBLEMS+1)); }
info() { printf '       %s\n' "$1"; }
PROBLEMS=0
ADVICE=()
advise() { ADVICE+=("$1"); }

# A real NIC has a device symlink; that excludes lo, docker0, br-*, veth*, tun* with no allowlist.
is_real()     { [[ -e "/sys/class/net/$1/device" ]]; }
is_wireless() { [[ -d "/sys/class/net/$1/wireless" || -e "/sys/class/net/$1/phy80211" ]]; }
carrier()     { cat "/sys/class/net/$1/carrier" 2>/dev/null || echo 0; }
speed()       { local s; s="$(cat "/sys/class/net/$1/speed" 2>/dev/null || echo -1)"
                [[ "$s" =~ ^[0-9]+$ ]] && (( s > 0 )) && echo "${s} Mb/s" || echo "-"; }
addrs()       { ip -br -4 addr show "$1" 2>/dev/null | awk '{$1="";$2="";print}' | xargs || true; }
# TCP reachability with no curl/nc: bash's own /dev/tcp, bounded by timeout.
tcp()         { timeout 2 bash -c "exec 3<>/dev/tcp/$1/$2" 2>/dev/null; }

printf '%sBuendia network check%s   router %s · server %s   (%s)\n' \
       "$B" "$N" "$ROUTER" "$SERVER" "$(date '+%Y-%m-%d %H:%M')"

# ---------------------------------------------------------------------------
hdr "Network interfaces on this box"
WIRED=(); WIRELESS=()
for path in /sys/class/net/*; do
  i="$(basename "$path")"
  is_real "$i" || continue
  if is_wireless "$i"; then WIRELESS+=("$i"); else WIRED+=("$i"); fi
done
for i in "${WIRED[@]:-}" ; do
  [[ -z "$i" ]] && continue
  printf '  wired     %-12s carrier=%s  %-9s  %s\n' \
         "$i" "$(carrier "$i")" "$(speed "$i")" "$(addrs "$i")"
done
for i in "${WIRELESS[@]:-}"; do
  [[ -z "$i" ]] && continue
  printf '  wireless  %-12s carrier=%s  %-9s  %s\n' \
         "$i" "$(carrier "$i")" "$(speed "$i")" "$(addrs "$i")"
done
[[ ${#WIRED[@]} -eq 0 ]] && bad "no wired interface at all — this box needs an RJ45 port or a USB-Ethernet adapter"

# ---------------------------------------------------------------------------
# Optional renew, before we judge the addresses.
if [[ $RENEW -eq 1 ]]; then
  hdr "Forcing a DHCP renew"
  if [[ $EUID -ne 0 ]]; then
    bad "--renew needs root: re-run with sudo"
  else
    for i in "${WIRED[@]:-}"; do
      [[ -z "$i" ]] && continue
      if command -v nmcli >/dev/null 2>&1; then
        info "nmcli: $i down/up"; nmcli dev disconnect "$i" >/dev/null 2>&1
        nmcli dev connect "$i" >/dev/null 2>&1 || true
      else
        info "ip link: $i down/up"; ip link set "$i" down; ip link set "$i" up
        command -v dhclient >/dev/null 2>&1 && dhclient -1 "$i" >/dev/null 2>&1 || true
      fi
    done
    sleep 4
  fi
fi

# ---------------------------------------------------------------------------
hdr "Wired link and address"
CANDIDATE=""
for i in "${WIRED[@]:-}"; do
  [[ -z "$i" ]] && continue
  car="$(carrier "$i")"
  a4="$(ip -br -4 addr show "$i" | awk '{print $3}')"
  if [[ "$car" != "1" ]]; then
    bad "$i has NO CARRIER — nothing is electrically connected"
    advise "Seat the cable at BOTH ends. On the router use a port labelled LAN, never WAN."
    advise "If the cable is definitely in, try another port and another cable — a dead port looks identical."
    continue
  fi
  ok "$i link is up ($(speed "$i"))"
  case "$a4" in
    "")
      bad "$i has NO IPv4 address — the link is up but DHCP never answered"
      advise "This is the classic WAN-port mistake: the router serves DHCP on LAN only."
      advise "Move the cable to a LAN port, then: sudo $0 --renew"
      ;;
    169.254.*)
      bad "$i fell back to link-local $a4 — the link is up but DHCP never answered"
      advise "169.254.x.x is self-assigned by this box. There is NO router at 169.254.x.1 — do not try to browse it."
      advise "Almost always the WAN port: the router serves DHCP on LAN ports only. Move the cable, then: sudo $0 --renew"
      advise "If it is already in a LAN port, a freshly-reset router needs ~2 min to finish booting — wait, then renew again."
      ;;
    "$SUBNET_PREFIX"*)
      ok "$i holds $a4 — this is the Buendia subnet"
      CANDIDATE="$i"
      [[ "${a4%/*}" == "$SERVER" ]] && info "note: this box already holds the SERVER address $SERVER"
      ;;
    *)
      warn "$i holds $a4 — that is NOT the Buendia subnet ($SUBNET_PREFIX0/24)"
      advise "This box is cabled to some other network. Plug it into the Buendia router instead."
      CANDIDATE="${CANDIDATE:-$i}"
      ;;
  esac
done

# ---------------------------------------------------------------------------
hdr "The netplan trap: which interface would setup.sh choose?"
DEFROUTE_IF="$(ip route show default 2>/dev/null | awk '/^default/{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1); exit}')"
if [[ -z "$DEFROUTE_IF" ]]; then
  info "no default route installed (normal for an isolated LAN, or a deliberately pinned NIC)"
elif is_wireless "$DEFROUTE_IF"; then
  warn "the default route runs over WIRELESS ($DEFROUTE_IF)"
  advise "With NET_IFACE empty, setup.sh autodetects by the default route: it would pick $DEFROUTE_IF and generate a netplan wifis: block, which is NOT the shipping path and has never been validated on hardware."
  advise "Turn this box's Wi-Fi OFF, or set NET_IFACE to the wired interface by hand."
else
  ok "the default route runs over wired $DEFROUTE_IF"
fi

# ---------------------------------------------------------------------------
hdr "Can we reach the router at $ROUTER?"
if ping -c1 -W2 "$ROUTER" >/dev/null 2>&1; then
  ok "$ROUTER answers ping"
  if tcp "$ROUTER" 80; then ok "$ROUTER:80 open — admin page at http://$ROUTER"
  else warn "$ROUTER:80 closed — unexpected for the GL.iNet admin panel"; fi
  if tcp "$ROUTER" 22; then ok "$ROUTER:22 open — SSH available (first-boot wizard has been completed)"
  else
    warn "$ROUTER:22 closed — the first-boot wizard has NOT been completed yet"
    advise "Open http://$ROUTER in a browser and finish the first-boot wizard. SSH stays shut until it is done, and configure-router.sh cannot run before that."
  fi
else
  bad "$ROUTER does not answer — this box cannot see the router"
  advise "Fix the wired link above first; the router is always $ROUTER on this kit."
fi

# ---------------------------------------------------------------------------
hdr "Is anything already answering on the server address $SERVER?"
MYADDRS="$(ip -br -4 addr | awk '{for(i=3;i<=NF;i++) print $i}' | cut -d/ -f1)"
if grep -qx "$SERVER" <<<"$MYADDRS"; then
  info "$SERVER is held by THIS box"
  tcp "$SERVER" 9000 && ok "$SERVER:9000 OpenMRS answers"   || info "$SERVER:9000 not answering (stack not up yet)"
  tcp "$SERVER" 9001 && ok "$SERVER:9001 install page answers" || info "$SERVER:9001 not answering (stack not up yet)"
elif ping -c1 -W2 "$SERVER" >/dev/null 2>&1; then
  warn "$SERVER is ALREADY IN USE by another host on this LAN"
  advise "Two hosts on $SERVER is a silent fault: tablets reach whichever answers first, and time sync breaks in a way nothing reports. Find and remove the other host BEFORE installing."
  advise "A dev box that impersonated the server for a clock test is the usual culprit — on that box: sudo ip addr del $SERVER/24 dev <iface>"
else
  ok "$SERVER is free — safe to install the server here"
fi

# ---------------------------------------------------------------------------
hdr "Verdict"
if [[ -n "$CANDIDATE" ]]; then
  printf '  Put this line in buendia.env (or /opt/buendia/.env) before running setup.sh:\n\n'
  printf '      %sNET_IFACE=%s%s\n\n' "$B" "$CANDIDATE" "$N"
else
  printf '  %sNET_IFACE cannot be determined yet%s — no wired interface is on the Buendia subnet.\n\n' "$Y" "$N"
fi
if [[ ${#ADVICE[@]} -gt 0 ]]; then
  printf '  What to do:\n'
  for a in "${ADVICE[@]}"; do printf '    - %s\n' "$a"; done
  printf '\n'
fi
if [[ $PROBLEMS -eq 0 ]]; then
  printf '  %sREADY%s — network looks correct. Next: sudo ./bootstrap.sh --dry-run\n' "$G" "$N"
  exit 0
fi
printf '  %s%d problem(s) found%s — fix the above, then re-run this script.\n' "$R" "$PROBLEMS" "$N"
exit 1
