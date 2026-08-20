#!/usr/bin/env bash
# Configure the field-pilot head router (WS-8). Idempotent; safe to re-run.
#
#   ./configure-router.sh                      # configure from ../.env
#   ./configure-router.sh --dry-run            # print every uci command, change nothing
#   ./configure-router.sh --server-mac AA:BB:.. # ...also pin the server's DHCP lease
#   ./configure-router.sh --router 192.168.8.1 --key ~/.ssh/id_flint
#
# This is the SOURCE OF TRUTH for the router's configuration. The exported backup
# (backup-router.sh) is the fast restore path for an IDENTICAL unit; this script is what
# survives a firmware bump, a different model, or a unit bought locally in a hurry.
# See docs/FIELD-PILOT-WS8-E2E-TEST-PLAN.md and FIELD-PILOT-NETWORK-SPEC.md (item D2).
#
# Written DISCOVERY-BASED on purpose. Verified on hardware 2026-08-20: this unit's radios
# are named `mt798611`/`mt798612`, NOT radio0/radio1 — anything that hardcodes radio names
# breaks on the first Wi-Fi line. Radios are therefore selected BY BAND, and only the `lan`
# interface's address is touched (never the vendor's DSA bridge).
#
# Exit 0 = applied (or already correct). Non-zero = nothing was committed.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$HERE/../.env"

ROUTER_IP_DEFAULT=192.168.8.1
DRY_RUN=0; SERVER_MAC=""; SSH_KEY=""; ROUTER=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --router)     ROUTER="$2"; shift 2 ;;
    --server-mac) SERVER_MAC="$2"; shift 2 ;;
    --key)        SSH_KEY="$2"; shift 2 ;;
    --dry-run)    DRY_RUN=1; shift ;;
    -h|--help)    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1 (try --help)" >&2; exit 2 ;;
  esac
done

log()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mWARN: %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

# .env is `source`d by bash — an unquoted value with a space or ; & | $ * ? aborts here.
# An EXPORTED variable overrides .env, matching build-apk.sh's convention, so a one-off
# run (`SITE_WIFI_SSID=... ./configure-router.sh`) does not require editing .env.
_ovr_ssid="${SITE_WIFI_SSID:-}"; _ovr_key="${SITE_WIFI_PASSWORD:-}"
_ovr_ip="${STATIC_IP:-}";        _ovr_country="${ROUTER_COUNTRY:-}"
_ovr_router="${ROUTER_IP:-}"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  set -a; source "$ENV_FILE"; set +a
else
  warn "$ENV_FILE not found — relying on environment variables only."
fi
# Explicit `if`, not `[[ ... ]] && assign`. Mid-script the short form is safe under
# `set -e` (verified), but it returns 1 when the test is false — which is fatal as the last
# statement of a FUNCTION, and silently poisons the exit code as the last statement of a
# script. Progress doc §4 records both. Explicit `if` has neither failure mode.
if [[ -n "$_ovr_ssid" ]];    then SITE_WIFI_SSID="$_ovr_ssid"; fi
if [[ -n "$_ovr_key" ]];     then SITE_WIFI_PASSWORD="$_ovr_key"; fi
if [[ -n "$_ovr_ip" ]];      then STATIC_IP="$_ovr_ip"; fi
if [[ -n "$_ovr_country" ]]; then ROUTER_COUNTRY="$_ovr_country"; fi
if [[ -n "$_ovr_router" ]];  then ROUTER_IP="$_ovr_router"; fi

ROUTER="${ROUTER:-${ROUTER_IP:-$ROUTER_IP_DEFAULT}}"
SERVER_IP="${STATIC_IP:-192.168.8.10}"
SSID="${SITE_WIFI_SSID:-}"
WIFI_KEY="${SITE_WIFI_PASSWORD:-}"
COUNTRY="${ROUTER_COUNTRY:-CD}"
CH24="${ROUTER_CHANNEL_24:-6}"      # non-DFS by construction; 1/6/11 are the only sane picks
CH5="${ROUTER_CHANNEL_5:-36}"       # UNII-1: non-DFS, legal in every domain we care about
HT24="${ROUTER_HTMODE_24:-HE20}"    # 20 MHz on 2.4: range and robustness beat throughput here
HT5="${ROUTER_HTMODE_5:-HE80}"
LAN_PREFIX="${ROUTER_LAN_PREFIX:-24}"
ROUTER_TZ="${ROUTER_TIMEZONE:-UTC}"
# psk2 (WPA2-PSK), NOT psk2+ccmp. Both are valid OpenWrt, but the GL.iNet web UI cannot
# WRITE psk2+ccmp — it displays the value and then rejects a save with "incorrect parameter
# value" (verified on 4.8.3). That makes the Wireless page unusable for a legitimate change
# like rotating the passphrase, and the obvious way out for whoever hits it is to pick a
# different encryption from the dropdown. Matching what the vendor can represent is worth
# more than forbidding a cipher no pilot device will request: Android negotiates CCMP
# anyway, and the passphrase is laminated on a ward wall.
ENCRYPTION="${ROUTER_ENCRYPTION:-psk2}"
# Redirect ALL client port-53 traffic to the router, so the clock intercept still works for a
# tablet that ignores DHCP option 6 — one with a hardcoded resolver, or an MDM-set one. Written
# as a plain OpenWrt firewall redirect rather than GL.iNet's force_dns key: same effect, but
# portable to the Beryl AX and to a non-GL.iNet replacement, and reviewable here instead of
# buried in a vendor layer. NB it does NOT catch Private DNS over TLS, which leaves on :853 —
# that stays a per-tablet staging step.
FORCE_DNS="${ROUTER_FORCE_DNS:-true}"

[[ -n "$SSID" ]]     || die "SITE_WIFI_SSID is not set (put it in .env, quoted)."
[[ -n "$WIFI_KEY" ]] || die "SITE_WIFI_PASSWORD is not set (put it in .env, quoted)."
[[ ${#WIFI_KEY} -ge 8 ]] || die "SITE_WIFI_PASSWORD must be at least 8 characters (WPA2 minimum)."
if [[ -n "$SERVER_MAC" && ! "$SERVER_MAC" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]]; then
  die "--server-mac '$SERVER_MAC' is not a MAC address."
fi

# accept-new, not "ask": the router is on a directly-cabled LAN we own, and BatchMode
# would otherwise fail on first contact with no way to say yes. A CHANGED key still
# fails, which is the property worth keeping.
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new)
if [[ -n "$SSH_KEY" ]]; then SSH_OPTS+=(-i "$SSH_KEY"); fi

# POSIX-safe single-quoting, so a passphrase containing spaces or metacharacters survives
# the trip into the remote shell intact.
q() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

log "Router $ROUTER — server $SERVER_IP — SSID '$SSID' — country $COUNTRY"
ssh "${SSH_OPTS[@]}" "root@$ROUTER" true 2>/dev/null \
  || die "cannot SSH to root@$ROUTER with a key. Run the first-boot wizard and install your key first (see README.md)."

PRE="SSID=$(q "$SSID") WIFI_KEY=$(q "$WIFI_KEY") SERVER_IP=$(q "$SERVER_IP") \
COUNTRY=$(q "$COUNTRY") CH24=$(q "$CH24") CH5=$(q "$CH5") HT24=$(q "$HT24") HT5=$(q "$HT5") \
ENCRYPTION=$(q "$ENCRYPTION") FORCE_DNS=$(q "$FORCE_DNS") LAN_PREFIX=$(q "$LAN_PREFIX") ROUTER_TZ=$(q "$ROUTER_TZ") SERVER_MAC=$(q "$SERVER_MAC") \
ROUTER_IP=$(q "$ROUTER") DRY=$(q "$DRY_RUN")"

# shellcheck disable=SC2087
ssh "${SSH_OPTS[@]}" "root@$ROUTER" "$PRE sh -s" <<'REMOTE'
set -u
# BusyBox ash on OpenWrt. No bash-isms below.

DRY="${DRY:-0}"
changed=0

u() {   # every uci mutation goes through here, so --dry-run is honest
  if [ "$DRY" = 1 ]; then echo "  [dry-run] uci $*"; else uci "$@"; fi
}
note() { echo "  $*"; }
head_() { printf '\n-- %s\n' "$*"; }

# uci set on an identical value still records a delta on some builds, so compare first:
# that is what makes a second run genuinely a no-op rather than merely harmless.
setv() { # setv <option> <value>
  cur="$(uci -q get "$1" || true)"
  if [ "$cur" = "$2" ]; then return 0; fi
  u set "$1=$2"; changed=$((changed+1))
}
# List options need delete-then-add, which would always look like a change. Compare the
# sorted list first so idempotency survives.
setlist() { # setlist <option> <value>...
  opt="$1"; shift
  want="$(printf '%s\n' "$@" | sort | tr '\n' ' ')"
  cur="$(uci -q get "$opt" | tr ' ' '\n' | sort | tr '\n' ' ')"
  if [ "$cur" = "$want" ]; then return 0; fi
  u -q delete "$opt" 2>/dev/null || true
  for v in "$@"; do u add_list "$opt=$v"; done
  changed=$((changed+1))
}

# ── Discovery ────────────────────────────────────────────────────────────────
head_ "Discovery"
MODEL="$(cat /tmp/sysinfo/model 2>/dev/null || echo unknown)"
FW="$(cat /etc/glversion 2>/dev/null || echo unknown)"
note "model=$MODEL firmware=$FW"

# Select radios BY BAND. Never by name: this unit calls them mt798611/mt798612.
R24=""; R5=""
for dev in $(uci show wireless | sed -n "s/^wireless\.\([^.=]*\)=wifi-device$/\1/p"); do
  band="$(uci -q get "wireless.$dev.band" || true)"
  case "$band" in
    2g) R24="$dev" ;;
    5g) R5="$dev" ;;
  esac
done
[ -n "$R24" ] || { echo "ERROR: no 2.4 GHz radio found"; exit 1; }
[ -n "$R5" ]  || { echo "ERROR: no 5 GHz radio found"; exit 1; }
note "radios: 2.4GHz=$R24  5GHz=$R5"

# ── Radios ───────────────────────────────────────────────────────────────────
head_ "Radios (country $COUNTRY, non-DFS channels)"
for pair in "$R24 $CH24 $HT24" "$R5 $CH5 $HT5"; do
  set -- $pair; dev="$1"; ch="$2"; ht="$3"
  setv "wireless.$dev.country" "$COUNTRY"
  setv "wireless.$dev.channel" "$ch"     # pinned: 'auto' on 5 GHz can land on DFS and
  setv "wireless.$dev.htmode"  "$ht"     # re-run CAC at every cold boot, or vacate on radar
  setv "wireless.$dev.disabled" "0"
done

# ── One SSID across both bands ───────────────────────────────────────────────
head_ "SSID '$SSID' ($ENCRYPTION, one name on both bands)"
for iface in $(uci show wireless | sed -n "s/^wireless\.\([^.=]*\)=wifi-iface$/\1/p"); do
  dev="$(uci -q get "wireless.$iface.device" || true)"
  case "$iface" in
    guest*)   # vendor guest networks: a tablet provisioned onto one is genuinely isolated
              setv "wireless.$iface.disabled" "1"; continue ;;
  esac
  [ "$dev" = "$R24" ] || [ "$dev" = "$R5" ] || continue
  setv "wireless.$iface.ssid"       "$SSID"
  setv "wireless.$iface.encryption" "$ENCRYPTION"  # not sae-mixed: it breaks association on
  setv "wireless.$iface.key"        "$WIFI_KEY"   # a non-trivial set of older Android builds
  setv "wireless.$iface.network"    "lan"
  setv "wireless.$iface.mode"       "ap"
  setv "wireless.$iface.isolate"    "0"
  setv "wireless.$iface.disabled"   "0"
done

# ── LAN ──────────────────────────────────────────────────────────────────────
# Only the address. NEVER the vendor's br-lan device/ports (DSA here) — rewriting that
# is how a unit ends up with no working LAN.
head_ "LAN $ROUTER_IP/$LAN_PREFIX"
setv network.lan.ipaddr "$ROUTER_IP"
setv network.lan.netmask "$( [ "$LAN_PREFIX" = 24 ] && echo 255.255.255.0 || echo 255.255.0.0 )"

# ── DHCP ─────────────────────────────────────────────────────────────────────
head_ "DHCP"
setv dhcp.lan.start "100"      # .100-.249: excludes .1 (router) and .10 (server)
setv dhcp.lan.limit "150"
setv dhcp.lan.leasetime "12h"
setv dhcp.lan.dhcpv4 "server"
setv dhcp.lan.ra "disabled"       # IPv4-only deployment; an untested dimension otherwise
setv dhcp.lan.dhcpv6 "disabled"
# Exactly one DNS server in the offer (option 6) — a vendor-added secondary is a
# false-pass vector: our checks succeed while the tablet round-robins to the other one.
# Option 42 (NTP) is free and helps any non-Android client; Android ignores it.
setlist dhcp.lan.dhcp_option "6,$ROUTER_IP" "42,$SERVER_IP"

# ── DNS: the tablet clock intercept (plan §3.4) ──────────────────────────────
# Android ignores DHCP option 42 but does resolve a hardcoded NTP hostname. Map those to
# the server so an offline site still disciplines tablet clocks — the clinical timestamp
# comes from the TABLET, so this is data correctness, not cosmetics.
head_ "DNS overrides -> $SERVER_IP"
setlist dhcp.@dnsmasq[0].address \
  "/time.android.com/$SERVER_IP" \
  "/time.google.com/$SERVER_IP" \
  "/ntp.org/$SERVER_IP"
# Harmless and already off on 4.8.3, but assert it: it is cheap and the vendor UI can
# re-enable it. NB it filters UPSTREAM answers, not local address= records — it is not
# the thing that would break the intercept (the vendor DNS layer is).
setv dhcp.@dnsmasq[0].rebind_protection "0"

# ── Vendor DNS layer: the thing that actually breaks the intercept ───────────
# Encrypted DNS sends queries to an upstream resolver and our local mapping is simply
# never consulted, while the configuration page keeps looking correct. AdGuard Home is
# worse: it takes :53 and moves dnsmasq to 5353, bypassing every address= line.
head_ "Vendor DNS services off"
for svc in stubby adguardhome https-dns-proxy; do
  [ -f "/etc/init.d/$svc" ] || continue
  # Only act if it is actually running or start-enabled, else a re-run would report a
  # change every time and idempotency would be a fiction.
  running=0; enabled=0
  if ps w | grep -v grep | grep -q "[/ ]$svc"; then running=1; fi
  if /etc/init.d/$svc enabled >/dev/null 2>&1; then enabled=1; fi
  if [ "$running" = 0 ] && [ "$enabled" = 0 ]; then
    note "$svc already stopped and disabled"
    continue
  fi
  if [ "$DRY" = 1 ]; then
    echo "  [dry-run] /etc/init.d/$svc stop; /etc/init.d/$svc disable  (running=$running enabled=$enabled)"
  else
    /etc/init.d/$svc stop >/dev/null 2>&1 || true
    /etc/init.d/$svc disable >/dev/null 2>&1 || true
  fi
  changed=$((changed+1))
done
[ -n "$(uci -q get adguardhome.config.enabled || true)" ] && setv adguardhome.config.enabled "0"

# ── Force every client onto our resolver ─────────────────────────────────────
# The whole clock-discipline mechanism assumes tablets resolve through us. option 6 asks
# politely; this enforces it.
head_ "DNS redirect (force_dns=$FORCE_DNS)"
RULE_NAME=buendia-dns-intercept
sec="$(uci show firewall 2>/dev/null | sed -n "s/^firewall\.\([^.]*\)\.name='$RULE_NAME'$/\1/p" | head -1)"
if [ "$FORCE_DNS" = "true" ]; then
  if [ -z "$sec" ]; then
    if [ "$DRY" = 1 ]; then
      echo "  [dry-run] uci add firewall redirect + name/src/proto/src_dport/dest_port/dest_ip/target"
      changed=$((changed+1))
    else
      sec="$(uci add firewall redirect)"
      uci set "firewall.$sec.name=$RULE_NAME"
      uci set "firewall.$sec.src=lan"
      uci set "firewall.$sec.proto=tcp udp"
      uci set "firewall.$sec.src_dport=53"
      uci set "firewall.$sec.dest_port=53"
      uci set "firewall.$sec.dest_ip=$ROUTER_IP"
      uci set "firewall.$sec.target=DNAT"
      uci set "firewall.$sec.family=ipv4"
      changed=$((changed+1))
    fi
  else
    note "redirect already present ($sec)"
    setv "firewall.$sec.dest_ip" "$ROUTER_IP"
    # Only touch `enabled` if it is explicitly off. The key is ABSENT by default (meaning
    # enabled), so setting it unconditionally would register a change on every run and make
    # idempotency a fiction — the same trap as the vendor-service block above.
    if [ "$(uci -q get "firewall.$sec.enabled" || true)" = "0" ]; then
      setv "firewall.$sec.enabled" "1"
    fi
  fi
else
  if [ -n "$sec" ]; then u -q delete "firewall.$sec"; changed=$((changed+1)); else note "not configured"; fi
fi

# ── Time ─────────────────────────────────────────────────────────────────────
# This unit has NO RTC (verified 2026-08-20), so it boots with a wrong clock after every
# power cut. It must therefore be a CLIENT of the server and must never serve time.
head_ "Time: client of $SERVER_IP, serves nothing"
setlist system.ntp.server "$SERVER_IP"
setv system.ntp.enabled "1"
setv system.ntp.enable_server "0"
sysname="$(uci show system | sed -n 's/^system\.\([^.=]*\)=system$/\1/p' | head -1)"
[ -n "$sysname" ] && setv "system.$sysname.zonename" "$ROUTER_TZ"

# ── Static lease (optional) ──────────────────────────────────────────────────
# Belt-and-braces only: the server holds its address from netplan and never sends a
# DHCPDISCOVER, so this fires only after an OS reinstall or if netplan is set to DHCP.
if [ -n "$SERVER_MAC" ]; then
  head_ "Static lease $SERVER_MAC -> $SERVER_IP"
  if ! uci show dhcp | grep -q "=host$" || ! uci show dhcp | grep -qi "$SERVER_MAC"; then
    if [ "$DRY" = 1 ]; then
      echo "  [dry-run] uci add dhcp host + set name/mac/ip"
    else
      h="$(uci add dhcp host)"
      uci set "dhcp.$h.name=buendia-server"
      uci set "dhcp.$h.mac=$SERVER_MAC"
      uci set "dhcp.$h.ip=$SERVER_IP"
      changed=$((changed+1))
    fi
  else
    note "already present"
  fi
fi

# ── Commit ───────────────────────────────────────────────────────────────────
head_ "Pending changes"
uci changes || true
if [ "$DRY" = 1 ]; then
  echo
  echo "DRY RUN — nothing committed. ($changed change(s) would be made.)"
  uci revert wireless network dhcp system adguardhome 2>/dev/null || true
  exit 0
fi

if [ "$changed" -eq 0 ]; then
  echo
  echo "Already correct — nothing to commit (idempotent no-op)."
else
  uci commit
  head_ "Applying"
  # `uci commit` alone changes nothing that is running, and reload_config does not restart
  # the vendor services. Be explicit, then trust nothing until after a reboot.
  /etc/init.d/dnsmasq restart  >/dev/null 2>&1 || true
  /etc/init.d/firewall restart >/dev/null 2>&1 || true
  /etc/init.d/network reload   >/dev/null 2>&1 || true
  wifi reload                  >/dev/null 2>&1 || true
  echo "  applied ($changed change(s))"
fi

echo
echo "NEXT: reboot the router, then run verify-router.sh. Reboot survival is the property"
echo "      being sold, so a verify that has not survived a power cycle proves little."
REMOTE
