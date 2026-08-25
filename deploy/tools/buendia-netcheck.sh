#!/usr/bin/env bash
# Buendia field pilot — check the network and fill in the one value .env cannot know.
#
# Run it from the install USB before bootstrap.sh, or from /opt/buendia afterwards. It answers
# the two questions a technician cannot answer on a bare box with no repo and no engineer:
#
#   1. Where is the router?   Discovered, never assumed. The pilot's 192.168.8.0/24 only exists
#      AFTER deploy/network/configure-router.sh has run; a factory-reset GL.iNet moves its LAN
#      when that subnet collides with what its WAN hands it, and a replacement bought locally
#      is on something else entirely.
#   2. What goes in NET_IFACE?  Detected, and with --write, written into .env for you. Left
#      empty, setup.sh autodetects by default route — which picks Wi-Fi on a laptop and
#      generates a netplan wifis: block that is NOT the shipping path.
#
#   ./buendia-netcheck.sh                 report only (default: changes nothing)
#   ./buendia-netcheck.sh --write         also write NET_IFACE into the .env it found
#   sudo ./buendia-netcheck.sh --renew    force a DHCP renew first
#   sudo ./buendia-netcheck.sh --probe    no lease at all: borrow an address in each likely
#                                         router subnet and see who answers. Finds a router
#                                         whose DHCP is off, or one sitting in u-boot recovery.
#
# Needs only bash, iproute2, ping and /sys. nmcli/networkctl are used when present because the
# DHCP server identifier they expose is the only authoritative answer to question 1.
#
# Exit 0 = ready to install. Exit 1 = something needs fixing (the report says what).
set -uo pipefail

WRITE=0; RENEW=0; PROBE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --write) WRITE=1; shift ;;
    --renew) RENEW=1; shift ;;
    --probe) PROBE=1; shift ;;
    -h|--help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $1 (try --help)" >&2; exit 1 ;;
  esac
done

B=$'\033[1m'; R=$'\033[0;31m'; G=$'\033[0;32m'; Y=$'\033[1;33m'; C=$'\033[1;36m'; N=$'\033[0m'
hdr()  { printf '\n%s== %s%s\n' "$C" "$1" "$N"; }
ok()   { printf '  %s OK  %s %s\n' "$G" "$N" "$1"; }
warn() { printf '  %s WARN%s %s\n' "$Y" "$N" "$1"; PROBLEMS=$((PROBLEMS+1)); }
bad()  { printf '  %s FAIL%s %s\n' "$R" "$N" "$1"; PROBLEMS=$((PROBLEMS+1)); }
info() { printf '       %s\n' "$1"; }
PROBLEMS=0; ADVICE=(); PROBE_FOUND=""; PROBE_IF=""; FIXED_NET=0
advise() { ADVICE+=("$1"); }

is_real()     { [[ -e "/sys/class/net/$1/device" ]]; }
is_wireless() { [[ -d "/sys/class/net/$1/wireless" || -e "/sys/class/net/$1/phy80211" ]]; }
carrier()     { cat "/sys/class/net/$1/carrier" 2>/dev/null || echo 0; }
speed()       { local s; s="$(cat "/sys/class/net/$1/speed" 2>/dev/null || echo -1)"
                [[ "$s" =~ ^[0-9]+$ ]] && (( s > 0 )) && echo "${s}Mb" || echo "-"; }
cidr()        { ip -br -4 addr show "$1" 2>/dev/null | awk '{print $3}' | head -1; }
tcp()         { timeout 2 bash -c "exec 3<>/dev/tcp/$1/$2" 2>/dev/null; }
pingable()    { ping -c1 -W2 "$1" >/dev/null 2>&1; }
net24()       { local ip="${1%/*}"; echo "${ip%.*}"; }

# --- the .env this box will actually be configured from --------------------------------------
ENVF=""; WANT_STATIC=""; WANT_ROUTER=""; ENV_IFACE=""
for f in ./buendia.env ./.env /opt/buendia/.env; do
  [[ -f "$f" ]] || continue
  ENVF="$f"; break
done
getk() { awk -F= -v k="^$1=" '$0 ~ k {sub(/#.*/,"",$2); gsub(/[ \t"'"'"']/,"",$2); print $2; exit}' "$ENVF"; }
if [[ -n "$ENVF" ]]; then
  WANT_STATIC="$(getk STATIC_IP)"; WANT_ROUTER="$(getk GATEWAY_IP)"; ENV_IFACE="$(getk NET_IFACE)"
fi

# Why is there no lease? Two causes look identical and need opposite fixes: the cable is in a
# port that serves no DHCP, or this box never asked. Distinguish them before blaming the cable.
diagnose_no_lease() {
  local i="$1" found=0 state prof method np
  if command -v nmcli >/dev/null 2>&1; then
    state="$(nmcli -t -g GENERAL.STATE dev show "$i" 2>/dev/null)"
    prof="$(nmcli -t -g GENERAL.CONNECTION dev show "$i" 2>/dev/null)"
    [[ -n "$state" ]] && info "NetworkManager state: $state"
    if [[ "$state" == *unmanaged* ]]; then
      found=1; bad "$i is UNMANAGED by NetworkManager — nothing here is asking for a lease"
      advise "Something else owns it: check /etc/netplan/*.yaml and /etc/NetworkManager/conf.d/*.conf"
    fi
    if [[ -n "$prof" && "$prof" != "--" ]]; then
      method="$(nmcli -t -g ipv4.method con show "$prof" 2>/dev/null)"
      info "profile $prof — ipv4.method=$method"
      case "$method" in
        auto) ;;
        link-local|disabled|manual|shared)
          # A fresh Ubuntu install can come up with the wired profile set to link-local, so this
          # is not necessarily anyone's mistake — and it is one nmcli call to repair. With --write
          # and root, just fix it: an install procedure that says "now go and change a setting in
          # the GUI" is a step someone performs wrongly at two in the morning.
          if [[ $WRITE -eq 1 && $EUID -eq 0 ]]; then
            bad "ipv4.method is $method, not auto — this box would NEVER send a DHCP request"
            info "repairing: nmcli con mod \"$prof\" ipv4.method auto"
            if nmcli con mod "$prof" ipv4.method auto 2>/dev/null \
               && nmcli con up "$prof" >/dev/null 2>&1; then
              # A lease takes as long as it takes: the router may still be booting, and the link
              # has just been brought down and up. A fixed sleep was too short in practice.
              local now="" w=0
              printf '       waiting for an address'
              while (( w < 45 )); do
                now="$(cidr "$i")"
                case "$now" in ""|169.254.*) printf '.'; sleep 3; w=$(( w + 3 ));; *) break;; esac
              done
              printf '\n'
              case "$now" in
                ""|169.254.*) advise "set ipv4.method=auto on $prof, but still no lease — see the cable/port advice above." ;;
                *) ok "repaired: $i now holds $now"; PROBLEMS=$((PROBLEMS-2)); FIXED_NET=1; return 0 ;;
              esac
            else
              advise "could not set ipv4.method automatically. By hand: sudo nmcli con mod \"$prof\" ipv4.method auto && sudo nmcli con up \"$prof\""
            fi
          else
            found=1; bad "ipv4.method is $method, not auto — this box will NEVER send a DHCP request"
            advise "No cable move fixes this. Re-run with --write as root and it will be repaired for you:"
            advise "  sudo $0 --write"
            advise "Or by hand: sudo nmcli con mod \"$prof\" ipv4.method auto && sudo nmcli con up \"$prof\""
          fi ;;
      esac
    else
      found=1; bad "$i has no active NetworkManager profile — no DHCP client is running on it"
      advise "Bring it up: sudo nmcli dev connect $i"
    fi
  fi
  for np in /etc/netplan/*.yaml; do
    [[ -f "$np" ]] || continue
    grep -q "$i" "$np" 2>/dev/null || continue
    info "note: $i is mentioned in $np"
    if grep -qE 'dhcp4:[[:space:]]*(false|no)' "$np" 2>/dev/null; then
      found=1; bad "$np sets dhcp4: false — DHCP is switched off in configuration"
      advise "Leftover from a previous install. sudo mv $np /root/ && sudo netplan apply"
    fi
  done
  if [[ $found -eq 0 ]]; then
    info "this box IS asking and getting no answer, so the fault is on the other end of the cable:"
    advise "Use a port labelled LAN on the router, never WAN — DHCP is served on LAN only. Then: sudo $0 --renew"
    advise "If it already is a LAN port: confirm the router has power and has finished booting, then try that same port with another machine — that is what distinguishes a dead port from a dead DHCP server."
    advise "No lease at all and nothing else to go on? sudo $0 --probe"
  fi
}

# No lease means nothing to discover FROM. Borrow an address in each plausible router subnet and
# see who answers. Restores the interface on every exit path, Ctrl-C included.
PROBE_ADDED=""
probe_cleanup() { [[ -n "$PROBE_ADDED" ]] && ip addr del "$PROBE_ADDED" dev "$PROBE_IF" 2>/dev/null; PROBE_ADDED=""; }
probe_subnets() {
  local i="$1" nets mine net gw hit=0 extra
  PROBE_IF="$i"; trap probe_cleanup EXIT INT TERM
  # .8.1 is GL.iNet's default; .1.1 is both the generic default and where a unit in u-boot
  # recovery sits — recovery serves NO DHCP, which presents exactly as "no lease".
  nets="192.168.8 192.168.1 192.168.0 192.168.10 192.168.2 192.168.11 10.0.0"
  mine="$(ip -br -4 addr | awk '{for(k=3;k<=NF;k++) print $k}')"
  for net in $nets; do
    if grep -q "^$net\." <<<"$mine"; then info "skip $net.0/24 — this box already has an address there"; continue; fi
    PROBE_ADDED="$net.222/24"
    ip addr add "$PROBE_ADDED" dev "$i" 2>/dev/null || { PROBE_ADDED=""; continue; }
    for gw in "$net.1" "$net.254"; do
      pingable "$gw" || continue
      extra=""; tcp "$gw" 80 && extra="http:80"; tcp "$gw" 22 && extra="${extra:+$extra,}ssh:22"
      printf '  %s FOUND%s %-15s via %s  [%s]\n' "$G" "$N" "$gw" "$i" "${extra:-ping only}"
      PROBE_FOUND="${PROBE_FOUND:-$gw}"; hit=1
    done
    probe_cleanup
  done
  trap - EXIT INT TERM
  if [[ $hit -eq 0 ]]; then
    bad "nothing answered in any probed subnet on $i"
    advise "Nothing is alive on the other end of this cable. Confirm power and LEDs, try another port and cable, then power-cycle the router (unplug 10 s) and wait two full minutes."
    advise "A GL.iNet held on reset too long boots into u-boot recovery, which serves no DHCP — a plain power-cycle, no reset button, returns it to the wizard."
  else
    advise "A router answered but gave no lease: its DHCP is off, or it is in a recovery mode."
  fi
}

printf '%sBuendia network check%s  (%s)\n' "$B" "$N" "$(date '+%Y-%m-%d %H:%M')"
[[ -n "$ENVF" ]] && info "reading $ENVF — STATIC_IP=${WANT_STATIC:-unset} GATEWAY_IP=${WANT_ROUTER:-unset} NET_IFACE=${ENV_IFACE:-empty}"

# ---------------------------------------------------------------------------
hdr "Interfaces"
WIRED=(); WIRELESS=()
for p in /sys/class/net/*; do
  i="$(basename "$p")"; is_real "$i" || continue
  if is_wireless "$i"; then WIRELESS+=("$i"); else WIRED+=("$i"); fi
done
for i in "${WIRED[@]:-}" "${WIRELESS[@]:-}"; do
  [[ -z "$i" ]] && continue
  printf '  %-9s %-12s carrier=%s %-6s %s\n' \
    "$(is_wireless "$i" && echo wireless || echo wired)" "$i" "$(carrier "$i")" "$(speed "$i")" "$(cidr "$i")"
done
[[ ${#WIRED[@]} -eq 0 ]] && bad "no wired interface — the server is cabled to the router by design"

if [[ $RENEW -eq 1 ]]; then
  hdr "Forcing a DHCP renew"
  if [[ $EUID -ne 0 ]]; then bad "--renew needs root: re-run with sudo"
  else
    for i in "${WIRED[@]:-}"; do
      [[ -z "$i" ]] && continue
      if command -v nmcli >/dev/null 2>&1; then
        info "nmcli down/up $i"; nmcli dev disconnect "$i" >/dev/null 2>&1; nmcli dev connect "$i" >/dev/null 2>&1 || true
      else
        info "ip link down/up $i"; ip link set "$i" down; ip link set "$i" up
        command -v dhclient >/dev/null 2>&1 && dhclient -1 "$i" >/dev/null 2>&1 || true
      fi
    done
    sleep 4
  fi
fi

# ---------------------------------------------------------------------------
hdr "Wired link"
IFACE=""; MYCIDR=""
# diagnose_no_lease may REPAIR the interface (ipv4.method), so the address is re-read after it
# rather than trusted from before — otherwise a successful fix still reports "no lease".
for i in "${WIRED[@]:-}"; do
  [[ -z "$i" ]] && continue
  if [[ "$(carrier "$i")" != "1" ]]; then
    bad "$i NO CARRIER — nothing electrically connected"
    advise "Seat the cable at both ends; use a LAN port on the router, never WAN. A dead port looks identical, so try another."
    continue
  fi
  a="$(cidr "$i")"
  case "$a" in
    "")          bad "$i is up but has NO IPv4 address"; diagnose_no_lease "$i" ;;
    169.254.*)   bad "$i fell back to link-local $a — no DHCP lease"
                 info "169.254.x.x is assigned by this box itself; there is no router at 169.254.x.1."
                 diagnose_no_lease "$i"
                 a="$(cidr "$i")"          # re-read: the line above may have repaired it
                 case "$a" in
                   ""|169.254.*) ;;
                   *) ok "$i now holds $a"; IFACE="${IFACE:-$i}"; MYCIDR="${MYCIDR:-$a}" ;;
                 esac ;;
    *)           ok "$i is up ($(speed "$i")) with $a"; IFACE="${IFACE:-$i}"; MYCIDR="${MYCIDR:-$a}" ;;
  esac
done

if [[ $PROBE -eq 1 ]]; then
  hdr "Probing likely router subnets (temporary addresses, removed afterwards)"
  if [[ $EUID -ne 0 ]]; then bad "--probe needs root: re-run with sudo"
  else
    for i in "${WIRED[@]:-}"; do
      [[ -z "$i" ]] && continue
      [[ "$(carrier "$i")" == "1" ]] && probe_subnets "$i"
    done
  fi
fi

# ---------------------------------------------------------------------------
hdr "Where is the router?"
CANDS=()
add_cand() { local ip="$1" why="$2" e
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
  add_cand "$(nmcli -g IP4.GATEWAY dev show "$IFACE" 2>/dev/null)" "NetworkManager gateway"
fi
if [[ -n "$IFACE" ]] && command -v networkctl >/dev/null 2>&1; then
  add_cand "$(networkctl status "$IFACE" 2>/dev/null | awk -F': ' '/DHCP4 Server Address/{print $2}')" "systemd-networkd DHCP server"
fi
for lf in /var/lib/dhcp/dhclient*.leases; do
  [[ -f "$lf" ]] && add_cand "$(awk '/dhcp-server-identifier/{gsub(/;/,"");print $NF}' "$lf" 2>/dev/null | tail -1)" "dhclient lease file"
done
add_cand "$(ip route show default 2>/dev/null | awk '/^default/{print $3; exit}')" "default route"
[[ -n "$MYCIDR" ]] && { add_cand "$(net24 "$MYCIDR").1" "convention: first host of this /24"
                        add_cand "$(net24 "$MYCIDR").254" "convention: last host of this /24"; }

ROUTER="${PROBE_FOUND:-}"
[[ -n "$ROUTER" ]] && ok "found by probing: $ROUTER"
if [[ ${#CANDS[@]} -eq 0 && -z "$ROUTER" ]]; then
  bad "no candidate to test — there is no lease and no route to work from"
  advise "Fix the wired link first: with no address there is nothing to discover."
else
  for e in "${CANDS[@]:-}"; do
    [[ -z "$e" ]] && continue
    ip="${e%%|*}"; why="${e#*|}"; reach=""
    pingable "$ip" && reach="ping"
    tcp "$ip" 80 && reach="${reach:+$reach,}http:80"
    if [[ -n "$reach" ]]; then
      printf '  %s FOUND%s %-15s %-40s [%s]\n' "$G" "$N" "$ip" "$why" "$reach"
      ROUTER="${ROUTER:-$ip}"
    else
      printf '  %s  --  %s %-15s %-40s [no answer]\n' "$Y" "$N" "$ip" "$why"
    fi
  done
fi

if [[ -n "$ROUTER" ]]; then
  ok "router admin: http://$ROUTER"
  if tcp "$ROUTER" 22; then ok "$ROUTER:22 SSH open — configure-router.sh can reach it"
  else
    info "$ROUTER:22 SSH closed. On the GL.iNet head router that means the first-boot wizard is"
    info "not finished (SSH stays shut until it is) — complete it, then install the build box's key."
    info "On another router it may simply not offer SSH, which is not a fault by itself."
  fi
  # Does the router's CURRENT subnet match what this box is about to be configured for?
  if [[ -n "$WANT_STATIC" && "$(net24 "$ROUTER")" != "$(net24 "$WANT_STATIC")" ]]; then
    info "the router is on $(net24 "$ROUTER").0/24 but STATIC_IP is $WANT_STATIC"
    info "Expected before configure-router.sh runs — it moves the LAN onto the pilot subnet."
    info "Do NOT change STATIC_IP to match: every tablet APK bakes in a server address from that"
    info "subnet, so changing it means rebuilding and reinstalling the APK on every device."
  fi
elif [[ ${#CANDS[@]} -gt 0 ]]; then
  bad "no candidate answered — cannot locate the router"
  advise "Check you are cabled to the router itself, not to a switch or a different network."
fi

# ---------------------------------------------------------------------------
if [[ -n "$WANT_STATIC" ]]; then
  hdr "Is the server address $WANT_STATIC free?"
  MINE="$(ip -br -4 addr | awk '{for(k=3;k<=NF;k++) print $k}' | cut -d/ -f1)"
  if grep -qx "$WANT_STATIC" <<<"$MINE"; then
    info "$WANT_STATIC is held by THIS box"
    tcp "$WANT_STATIC" 9000 && ok ":9000 OpenMRS answers" || info ":9000 not answering (stack not up yet)"
    tcp "$WANT_STATIC" 9001 && ok ":9001 install page answers" || info ":9001 not answering (stack not up yet)"
  elif pingable "$WANT_STATIC"; then
    warn "$WANT_STATIC is ALREADY IN USE by another host"
    advise "Two hosts on one address is a silent fault: tablets reach whichever answers first and time sync breaks with nothing reporting it. Remove the other host before installing."
    advise "A build box that impersonated the server for a clock test is the usual culprit — there: sudo ip addr del $WANT_STATIC/24 dev <iface>"
  else
    ok "$WANT_STATIC is free"
  fi
fi

# ---------------------------------------------------------------------------
hdr "NET_IFACE"
if [[ -z "$IFACE" ]]; then
  warn "cannot determine the wired interface yet — fix the link above first"
elif [[ "$ENV_IFACE" == "$IFACE" ]]; then
  ok "$ENVF already has NET_IFACE=$IFACE"
elif [[ $WRITE -eq 1 && -n "$ENVF" ]]; then
  if [[ ! -w "$ENVF" ]]; then
    bad "$ENVF is not writable — re-run with sudo, or set it by hand: NET_IFACE=$IFACE"
  else
    cp -p "$ENVF" "$ENVF.bak" 2>/dev/null || true
    if grep -q '^NET_IFACE=' "$ENVF"; then
      sed -i "s|^NET_IFACE=.*|NET_IFACE=$IFACE   # detected by buendia-netcheck.sh on $(date '+%Y-%m-%d')|" "$ENVF"
    else
      printf 'NET_IFACE=%s   # detected by buendia-netcheck.sh on %s\n' "$IFACE" "$(date '+%Y-%m-%d')" >> "$ENVF"
    fi
    ok "wrote NET_IFACE=$IFACE into $ENVF (previous kept as $(basename "$ENVF").bak)"
    info "setup.sh no longer autodetects, so it cannot pick Wi-Fi and emit a wifis: block."
  fi
else
  warn "$ENVF has NET_IFACE=${ENV_IFACE:-empty}, but the wired interface is $IFACE"
  advise "Apply it: $0 --write   (or edit $ENVF and set NET_IFACE=$IFACE)"
  advise "Left empty, setup.sh autodetects by default route and would pick Wi-Fi on a laptop, generating a netplan wifis: block that is not the shipping path."
fi

# ---------------------------------------------------------------------------
hdr "Verdict"
[[ -n "$IFACE" ]] && printf '  wired interface : %s%s%s\n' "$B" "$IFACE" "$N"
[[ -n "$ROUTER" ]] && printf '  router admin    : %shttp://%s%s\n' "$B" "$ROUTER" "$N"
if [[ ${#ADVICE[@]} -gt 0 ]]; then
  printf '\n  What to do:\n'; for a in "${ADVICE[@]}"; do [[ -n "$a" ]] && printf '    - %s\n' "$a"; done
fi
printf '\n'
if [[ $PROBLEMS -eq 0 ]]; then
  printf '  %sREADY%s — the network is correct.\n' "$G" "$N"; exit 0
fi
printf '  %s%d problem(s)%s — fix the above, then re-run.\n' "$R" "$PROBLEMS" "$N"; exit 1
