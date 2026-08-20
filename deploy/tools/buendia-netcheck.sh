#!/usr/bin/env bash
# Buendia field pilot — pre-install network check and router discovery.
#
# Answers the two questions a technician cannot answer on a bare box with no repo and no
# engineer: "what is the router's address?" and "what do I put in NET_IFACE?"
#
# It DISCOVERS the router rather than assuming an address. That matters: a factory-reset
# GL.iNet is usually 192.168.8.1 but moves its LAN when the subnet collides with what its WAN
# is given, and any replacement router bought locally will be on something else entirely. The
# pilot's own 192.168.8.0/24 only exists AFTER deploy/network/configure-router.sh has run.
#
# Depends on nothing but bash, iproute2, ping and /sys. No ethtool, dig, curl, nc or nmcli
# required — those are what a fresh install may lack, and a diagnostic that cannot run when
# the network is broken is not a diagnostic. nmcli/networkctl are USED when present, because
# the DHCP server identifier they expose is the only authoritative answer.
#
#   ./buendia-netcheck.sh                 read-only: discover and advise
#   sudo ./buendia-netcheck.sh --renew    also force a DHCP renew first
#   sudo ./buendia-netcheck.sh --probe    DHCP is dead: self-assign a temporary address in each
#                                         likely router subnet and probe it. The only way to find
#                                         a router that hands out no lease — including one sitting
#                                         in u-boot recovery, which serves no DHCP at all.
#   ./buendia-netcheck.sh --expect 192.168.8.1   also check it matches the pilot addressing
#
# Exit 0 = a router was found and the link looks sane. Exit 1 = something needs fixing.
set -uo pipefail

RENEW=0; EXPECT=""; PROBE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --renew)  RENEW=1; shift ;;
    --probe)  PROBE=1; shift ;;
    --expect) EXPECT="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $1 (try --help)" >&2; exit 1 ;;
  esac
done

B=$'\033[1m'; R=$'\033[0;31m'; G=$'\033[0;32m'; Y=$'\033[1;33m'; C=$'\033[1;36m'; N=$'\033[0m'
hdr()  { printf '\n%s== %s%s\n' "$C" "$1" "$N"; }
ok()   { printf '  %s OK  %s %s\n' "$G" "$N" "$1"; }
warn() { printf '  %s WARN%s %s\n' "$Y" "$N" "$1"; PROBLEMS=$((PROBLEMS+1)); }
bad()  { printf '  %s FAIL%s %s\n' "$R" "$N" "$1"; PROBLEMS=$((PROBLEMS+1)); }
info() { printf '       %s\n' "$1"; }
PROBLEMS=0; ADVICE=(); PROBE_FOUND=""; PROBE_IF=""
advise() { ADVICE+=("$1"); }

is_real()     { [[ -e "/sys/class/net/$1/device" ]]; }
is_wireless() { [[ -d "/sys/class/net/$1/wireless" || -e "/sys/class/net/$1/phy80211" ]]; }
carrier()     { cat "/sys/class/net/$1/carrier" 2>/dev/null || echo 0; }
speed()       { local s; s="$(cat "/sys/class/net/$1/speed" 2>/dev/null || echo -1)"
                [[ "$s" =~ ^[0-9]+$ ]] && (( s > 0 )) && echo "${s}Mb" || echo "-"; }
cidr()        { ip -br -4 addr show "$1" 2>/dev/null | awk '{print $3}' | head -1; }
tcp()         { timeout 2 bash -c "exec 3<>/dev/tcp/$1/$2" 2>/dev/null; }
pingable()    { ping -c1 -W2 "$1" >/dev/null 2>&1; }

# Why is there no lease? "carrier but no address" has two completely different causes that look
# identical: the cable is in a port that serves no DHCP, or this box never asked. Distinguish
# them, because one is a cable move and the other is a one-line setting change.
diagnose_no_lease() {
  local i="$1" found=0
  if command -v nmcli >/dev/null 2>&1; then
    local state prof method
    state="$(nmcli -t -g GENERAL.STATE dev show "$i" 2>/dev/null)"
    prof="$(nmcli -t -g GENERAL.CONNECTION dev show "$i" 2>/dev/null)"
    [[ -n "$state" ]] && info "NetworkManager device state: $state"
    case "$state" in
      *unmanaged*)
        found=1
        bad "$i is UNMANAGED by NetworkManager — nothing on this box is asking for a lease"
        advise "Something else owns the interface (netplan/systemd-networkd, or an explicit unmanaged rule)."
        advise "Check: /etc/netplan/*.yaml and /etc/NetworkManager/conf.d/*.conf"
        ;;
    esac
    if [[ -n "$prof" && "$prof" != "--" ]]; then
      method="$(nmcli -t -g ipv4.method con show "$prof" 2>/dev/null)"
      info "profile $prof — ipv4.method=$method"
      case "$method" in
        auto) ;;
        link-local|disabled|manual|shared)
          found=1
          bad "ipv4.method is $method, not auto — this box will NEVER send a DHCP request"
          advise "THIS is why there is no lease, and no cable move will fix it. Set it to auto:"
          advise "Fix: sudo nmcli con mod \"$prof\" ipv4.method auto && sudo nmcli con up \"$prof\""
          ;;
      esac
    else
      found=1
      bad "$i has NO active NetworkManager profile — so no DHCP client is running on it"
      advise "Bring it up: sudo nmcli dev connect $i"
    fi
  fi
  # netplan can pin an interface to a static or link-local config, which NM then honours.
  local np
  for np in /etc/netplan/*.yaml; do
    [[ -f "$np" ]] || continue
    if grep -q "$i" "$np" 2>/dev/null; then
      info "note: $i is mentioned in $np"
      grep -qE 'dhcp4:\s*(false|no)' "$np" 2>/dev/null && {
        found=1
        bad "$np sets dhcp4: false for this interface — DHCP is switched off in config"
        advise "That file is a leftover from a previous install. Move it aside and re-apply:"
        advise "  sudo mv $np /root/ && sudo netplan apply"
      }
    fi
  done
  if [[ $found -eq 0 ]]; then
    info "this box IS asking for a lease and getting no answer — so the fault is upstream:"
    advise "Nothing on this box is blocking DHCP, so the cable is in a port that serves none."
    advise "On the router use a port labelled LAN, never WAN. Then: sudo $0 --renew"
    advise "If it is already a LAN port: confirm the router is powered and finished booting, then test that same port with another machine — that is what tells a dead port from a dead DHCP server."
  fi
}

# When there is no lease there is nothing to discover FROM, so stop discovering and go looking:
# borrow an address in each plausible router subnet and see who answers. Restores the interface
# on every exit path, including Ctrl-C — leaving a stray address behind would be worse than the
# fault being diagnosed.
PROBE_ADDED=""
probe_cleanup() {
  [[ -n "$PROBE_ADDED" ]] || return 0
  ip addr del "$PROBE_ADDED" dev "$PROBE_IF" 2>/dev/null
  PROBE_ADDED=""
}
probe_subnets() {
  local i="$1"
  PROBE_IF="$i"
  trap probe_cleanup EXIT INT TERM
  # GL.iNet ships .8.1; .1.1 is both the generic default AND where a unit in u-boot recovery
  # sits (recovery serves NO DHCP, which presents exactly as this fault).
  local nets="192.168.8 192.168.1 192.168.0 192.168.10 192.168.2 10.0.0 192.168.11"
  local mine net gw hit=0
  mine="$(ip -br -4 addr | awk '{for(k=3;k<=NF;k++) print $k}')"
  for net in $nets; do
    # Never touch a subnet this box is legitimately on already.
    if grep -q "^$net\." <<<"$mine"; then info "skipping $net.0/24 — this box already has an address there"; continue; fi
    PROBE_ADDED="$net.222/24"
    if ! ip addr add "$PROBE_ADDED" dev "$i" 2>/dev/null; then PROBE_ADDED=""; continue; fi
    for gw in "$net.1" "$net.254"; do
      if ping -c1 -W1 "$gw" >/dev/null 2>&1; then
        local extra=""
        tcp "$gw" 80  && extra="${extra:+$extra,}http:80"
        tcp "$gw" 443 && extra="${extra:+$extra,}https:443"
        tcp "$gw" 22  && extra="${extra:+$extra,}ssh:22"
        printf '  %s FOUND%s %-15s answers on %s  [%s]\n' "$G" "$N" "$gw" "$i" "${extra:-ping only}"
        PROBE_FOUND="${PROBE_FOUND:-$gw}"; hit=1
      fi
    done
    probe_cleanup
  done
  trap - EXIT INT TERM
  if [[ $hit -eq 0 ]]; then
    bad "no router answered in any probed subnet on $i"
    advise "Nothing is alive on the other end of this cable. In order: confirm the router has power and"
    advise "its LEDs have settled; confirm the cable is in a LAN port; try a different port and cable;"
    advise "then power-cycle the router (unplug 10 s) and wait two full minutes before retrying."
    advise "A GL.iNet held in reset too long boots into u-boot recovery, which serves no DHCP at all —"
    advise "a normal power-cycle (no reset button) is what brings it back to the wizard."
  else
    advise "A router answered but gave this box no lease. Its DHCP server is off or it is in a"
    advise "recovery/failsafe mode. Open its admin page from a box with a static address in that subnet."
  fi
}

printf '%sBuendia network check%s  (%s)\n' "$B" "$N" "$(date '+%Y-%m-%d %H:%M')"

# ---------------------------------------------------------------------------
hdr "Interfaces"
WIRED=(); WIRELESS=()
for path in /sys/class/net/*; do
  i="$(basename "$path")"; is_real "$i" || continue
  if is_wireless "$i"; then WIRELESS+=("$i"); else WIRED+=("$i"); fi
done
show() { printf '  %-9s %-12s carrier=%s %-6s %s\n' "$1" "$2" "$(carrier "$2")" "$(speed "$2")" "$(cidr "$2")"; }
for i in "${WIRED[@]:-}";    do [[ -n "$i" ]] && show wired    "$i"; done
for i in "${WIRELESS[@]:-}"; do [[ -n "$i" ]] && show wireless "$i"; done
[[ ${#WIRED[@]} -eq 0 ]] && bad "no wired interface — this box needs an RJ45 port or a USB-Ethernet adapter"

if [[ $RENEW -eq 1 ]]; then
  hdr "Forcing a DHCP renew"
  if [[ $EUID -ne 0 ]]; then bad "--renew needs root: re-run with sudo"
  else
    for i in "${WIRED[@]:-}"; do
      [[ -z "$i" ]] && continue
      if command -v nmcli >/dev/null 2>&1; then
        info "nmcli down/up $i"
        nmcli dev disconnect "$i" >/dev/null 2>&1; nmcli dev connect "$i" >/dev/null 2>&1 || true
      else
        info "ip link down/up $i"; ip link set "$i" down; ip link set "$i" up
        command -v dhclient >/dev/null 2>&1 && dhclient -1 "$i" >/dev/null 2>&1 || true
      fi
    done
    sleep 4
  fi
fi

# ---------------------------------------------------------------------------
# Pick the interface to reason about: a wired one holding a routable address, else any wired
# one with a carrier. Never a wireless one — the server is cabled to the router by design.
hdr "Wired link"
IFACE=""; MYCIDR=""
for i in "${WIRED[@]:-}"; do
  [[ -z "$i" ]] && continue
  car="$(carrier "$i")"; a="$(cidr "$i")"
  if [[ "$car" != "1" ]]; then
    bad "$i NO CARRIER — nothing electrically connected"
    advise "Seat the cable at both ends, and use a port labelled LAN on the router, never WAN."
    advise "If the cable is definitely in, try another port and another cable — a dead port looks identical."
    continue
  fi
  case "$a" in
    "")
      bad "$i link is up but has NO IPv4 address"
      diagnose_no_lease "$i"
      ;;
    169.254.*)
      bad "$i fell back to link-local $a — no DHCP lease"
      info "169.254.x.x is assigned by this box itself. There is NO router at 169.254.x.1."
      diagnose_no_lease "$i"
      ;;
    *)
      ok "$i is up ($(speed "$i")) with $a"
      IFACE="${IFACE:-$i}"; MYCIDR="${MYCIDR:-$a}"
      ;;
  esac
done

# ---------------------------------------------------------------------------
if [[ $PROBE -eq 1 ]]; then
  hdr "Probing likely router subnets (temporary addresses, removed afterwards)"
  if [[ $EUID -ne 0 ]]; then
    bad "--probe needs root: re-run with sudo"
  else
    for i in "${WIRED[@]:-}"; do
      [[ -z "$i" ]] && continue
      [[ "$(carrier "$i")" == "1" ]] || continue
      probe_subnets "$i"
    done
  fi
fi

hdr "Where is the router?"
# Four independent sources, best first. The DHCP server identifier is authoritative: whatever
# handed out this lease IS the router. A default route can be absent (isolated LAN) or
# deliberately suppressed (a build box pinned with ipv4.never-default), so it is not first.
CANDS=()
add_cand() { local ip="$1" why="$2"
  [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 0
  [[ "$ip" == 0.0.0.0 ]] && return 0
  for e in "${CANDS[@]:-}"; do [[ "${e%%|*}" == "$ip" ]] && return 0; done
  CANDS+=("$ip|$why"); }

if [[ -n "$IFACE" ]] && command -v nmcli >/dev/null 2>&1; then
  while read -r k v; do
    case "$k" in
      *dhcp_server_identifier:*) add_cand "$v" "DHCP server identifier (authoritative)" ;;
      *routers:*)                add_cand "$v" "DHCP option 3 (router)" ;;
      *domain_name_servers:*)    for d in $v; do add_cand "$d" "DHCP option 6 (DNS)"; done ;;
    esac
  done < <(nmcli -f DHCP4 dev show "$IFACE" 2>/dev/null | sed 's/=/ /' | awk '{print $2, $3}')
  g="$(nmcli -g IP4.GATEWAY dev show "$IFACE" 2>/dev/null)"; add_cand "$g" "NetworkManager gateway"
fi
if [[ -n "$IFACE" ]] && command -v networkctl >/dev/null 2>&1; then
  s="$(networkctl status "$IFACE" 2>/dev/null | awk -F': ' '/DHCP4 Server Address/{print $2}')"
  add_cand "$s" "systemd-networkd DHCP server address"
fi
for lf in /var/lib/dhcp/dhclient*.leases /var/lib/NetworkManager/*.lease; do
  [[ -f "$lf" ]] || continue
  s="$(awk '/dhcp-server-identifier/{gsub(/;/,"");print $NF}' "$lf" 2>/dev/null | tail -1)"
  add_cand "$s" "dhclient lease file"
done
g="$(ip route show default 2>/dev/null | awk '/^default/{print $3; exit}')"; add_cand "$g" "default route"
# Heuristic last: the usual first and last host of our own /24.
if [[ -n "$MYCIDR" ]]; then
  net="${MYCIDR%/*}"; pre="${net%.*}"
  add_cand "$pre.1"   "convention: first host of $pre.0/24"
  add_cand "$pre.254" "convention: last host of $pre.0/24"
fi

ROUTER="${PROBE_FOUND:-}"
if [[ -n "$ROUTER" ]]; then
  ok "found by probing: $ROUTER"
fi
if [[ ${#CANDS[@]} -eq 0 ]]; then
  bad "no router candidate at all — there is no lease and no route to work from"
  advise "Fix the wired link above first: without an address there is nothing to discover."
else
  for e in "${CANDS[@]}"; do
    ip="${e%%|*}"; why="${e#*|}"
    reach=""; pingable "$ip" && reach="ping"
    tcp "$ip" 80  && reach="${reach:+$reach,}http:80"
    tcp "$ip" 443 && reach="${reach:+$reach,}https:443"
    if [[ -n "$reach" ]]; then
      printf '  %s FOUND%s %-15s %-42s [%s]\n' "$G" "$N" "$ip" "$why" "$reach"
      ROUTER="${ROUTER:-$ip}"
    else
      printf '  %s  --  %s %-15s %-42s [no answer]\n' "$Y" "$N" "$ip" "$why"
    fi
  done
fi

if [[ -n "$ROUTER" ]]; then
  hdr "Router at $ROUTER"
  ok "admin page: http://$ROUTER"
  if tcp "$ROUTER" 22; then
    ok "$ROUTER:22 SSH is open — configure-router.sh can reach it"
  else
    info "$ROUTER:22 SSH is closed"
    info "On the GL.iNet head router that means the first-boot wizard is not finished (SSH stays"
    info "shut until it is) — open http://$ROUTER, complete it, and install the build box's key."
    info "On any other router it may simply not offer SSH, which is not a fault by itself."
  fi
elif [[ ${#CANDS[@]} -gt 0 ]]; then
  bad "none of the candidates answered — cannot locate the router"
  advise "Check you are cabled to the router and not to a switch or another network."
fi

# ---------------------------------------------------------------------------
if [[ -n "$EXPECT" ]]; then
  hdr "Pilot addressing check (--expect $EXPECT)"
  if [[ "$ROUTER" == "$EXPECT" ]]; then
    ok "the router is already on the pilot address $EXPECT"
  elif [[ -n "$ROUTER" ]]; then
    info "the router is at $ROUTER, not the pilot address $EXPECT"
    info "That is EXPECTED before configure-router.sh runs — it moves the LAN to the pilot subnet."
    info "Afterwards this box's address changes too, and STATIC_IP must sit in the new subnet."
  fi
fi

# ---------------------------------------------------------------------------
hdr "The netplan trap: which interface would setup.sh choose?"
DEF_IF="$(ip route show default 2>/dev/null | awk '/^default/{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1); exit}')"
if [[ -z "$DEF_IF" ]]; then
  info "no default route (normal on an isolated LAN, or on a build box pinned ipv4.never-default)"
elif is_wireless "$DEF_IF"; then
  warn "the default route runs over WIRELESS ($DEF_IF)"
  advise "With NET_IFACE empty, setup.sh autodetects by default route: it would pick $DEF_IF and generate a netplan wifis: block, which is NOT the shipping path and has never been validated on hardware."
  advise "Turn this box's Wi-Fi OFF, or set NET_IFACE to the wired interface by hand."
else
  ok "the default route runs over wired $DEF_IF"
fi

# ---------------------------------------------------------------------------
# Only meaningful once the address the server will take is known — read it from a .env if one
# is beside us, rather than assuming the pilot value.
STATIC_IP=""; STATIC_SRC=""
for envf in ./buendia.env ./.env /opt/buendia/.env; do
  [[ -f "$envf" ]] || continue
  v="$(awk -F= '/^STATIC_IP=/{print $2}' "$envf" | awk '{print $1}' | tr -d '"'"'"'')"
  [[ -n "$v" ]] && { STATIC_IP="$v"; STATIC_SRC="$envf"; break; }
done
if [[ -n "$STATIC_IP" ]]; then
  hdr "Is the server address $STATIC_IP free?"
  info "STATIC_IP=$STATIC_IP (read from $STATIC_SRC)"
  MINE="$(ip -br -4 addr | awk '{for(i=3;i<=NF;i++) print $i}' | cut -d/ -f1)"
  if grep -qx "$STATIC_IP" <<<"$MINE"; then
    info "$STATIC_IP is held by THIS box"
    tcp "$STATIC_IP" 9000 && ok "$STATIC_IP:9000 OpenMRS answers" || info ":9000 not answering (stack not up yet)"
    tcp "$STATIC_IP" 9001 && ok "$STATIC_IP:9001 install page answers" || info ":9001 not answering (stack not up yet)"
  elif pingable "$STATIC_IP"; then
    warn "$STATIC_IP is ALREADY IN USE by another host"
    advise "Two hosts on one address is a silent fault: tablets reach whichever answers first and time sync breaks with nothing reporting it. Remove the other host before installing."
    advise "A build box that impersonated the server for a clock test is the usual culprit — on that box: sudo ip addr del $STATIC_IP/24 dev <iface>"
  else
    ok "$STATIC_IP is free"
  fi
fi

# ---------------------------------------------------------------------------
hdr "Verdict"
if [[ -n "$IFACE" ]]; then
  printf '  Wired interface to use — put this in buendia.env before running setup.sh:\n\n'
  printf '      %sNET_IFACE=%s%s\n\n' "$B" "$IFACE" "$N"
fi
[[ -n "$ROUTER" ]] && printf '  Router admin:  %shttp://%s%s\n\n' "$B" "$ROUTER" "$N"
if [[ ${#ADVICE[@]} -gt 0 ]]; then
  printf '  What to do:\n'; for a in "${ADVICE[@]}"; do printf '    - %s\n' "$a"; done; printf '\n'
fi
if [[ $PROBLEMS -eq 0 ]]; then
  printf '  %sREADY%s — next: sudo ./bootstrap.sh --dry-run\n' "$G" "$N"; exit 0
fi
printf '  %s%d problem(s) found%s — fix the above, then re-run.\n' "$R" "$PROBLEMS" "$N"; exit 1
