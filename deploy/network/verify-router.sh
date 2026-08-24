#!/usr/bin/env bash
# Go/no-go for the field-pilot router. Asserts the RUNNING state, not the configuration.
#
#   ./verify-router.sh                       # router-only checks (Phase 2 bench)
#   ./verify-router.sh --server 192.168.8.10 # ...also the server-side assertions
#   ./verify-router.sh --router 192.168.8.1 --key ~/.ssh/id_flint
#
# Why running-state and not `uci show`: the named hazard on this hardware is precisely
# runtime != configuration. The vendor DNS layer, AdGuard Home or a DoT proxy can leave
# uci pristine while the override is inert — a configuration page that looks perfect is
# exactly the failure mode this has to catch. Every check below is read from a process
# table, a listening socket, a generated config file, or a real DNS answer.
#
# Exit 0 = GO, 1 = NO-GO.
#
set -uo pipefail    # NB: not -e — a failing check must be reported, not abort the run

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$HERE/../.env"
# One explicit key for every caller. A ~/.ssh key is invisible to root and a root key is
# invisible to the user, so anything depending on $HOME breaks depending on whether sudo was
# used. router-access.sh creates this; nothing here depends on who is running.
DEFAULT_KEY="$HERE/router_key"
ROUTER=""; SERVER=""; SSH_KEY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --router) ROUTER="$2"; shift 2 ;;
    --server) SERVER="$2"; shift 2 ;;
    --key)    SSH_KEY="$2"; shift 2 ;;
    -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1 (try --help)" >&2; exit 2 ;;
  esac
done

# An exported variable overrides .env, matching build-apk.sh and configure-router.sh.
_ovr_ssid="${SITE_WIFI_SSID:-}"; _ovr_ip="${STATIC_IP:-}"; _ovr_country="${ROUTER_COUNTRY:-}"
if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  if (set -a; source "$ENV_FILE"; set +a) 2>/dev/null; then set -a; source "$ENV_FILE"; set +a
  else echo "WARNING: $ENV_FILE could not be sourced — quote values with spaces or ; & | \$ * ?" >&2; fi
fi
if [ -n "$_ovr_ssid" ];    then SITE_WIFI_SSID="$_ovr_ssid"; fi
if [ -n "$_ovr_ip" ];      then STATIC_IP="$_ovr_ip"; fi
if [ -n "$_ovr_country" ]; then ROUTER_COUNTRY="$_ovr_country"; fi
ROUTER="${ROUTER:-${ROUTER_IP:-192.168.8.1}}"
SERVER_IP="${STATIC_IP:-192.168.8.10}"
SSID_WANT="${SITE_WIFI_SSID:-}"
COUNTRY_WANT="${ROUTER_COUNTRY:-CD}"
ENC_WANT="${ROUTER_ENCRYPTION:-psk2}"
FORCE_DNS_WANT="${ROUTER_FORCE_DNS:-true}"

PASS=0; FAIL=0
ok()   { printf '  \033[1;32m✓\033[0m %-42s %s\n' "$1" "${2:-}"; PASS=$((PASS+1)); }
bad()  { printf '  \033[1;31m✗\033[0m %-42s %s\n' "$1" "${2:-}"; FAIL=$((FAIL+1)); }
head_(){ printf '\n\033[1;36m── %s\033[0m\n' "$*"; }

# accept-new, not "ask": the router is on a directly-cabled LAN we own, and BatchMode
# would otherwise fail on first contact with no way to say yes. A CHANGED key still
# fails, which is the property worth keeping.
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new)
# Under sudo, HOME is /root and ssh finds no key there even though it works for the invoking
# user; BatchMode then fails and the message below blames the wizard. Nothing needs local root.
if [ -z "$SSH_KEY" ] && [ -f "$DEFAULT_KEY" ]; then SSH_KEY="$DEFAULT_KEY"; fi
if [ -z "$SSH_KEY" ] && [ -n "${SUDO_USER:-}" ]; then
  _home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
  for _k in "$_home"/.ssh/id_ed25519 "$_home"/.ssh/id_rsa "$_home"/.ssh/id_ecdsa; do
    [ -f "$_k" ] && { SSH_KEY="$_k"; break; }
  done
fi
[ -n "$SSH_KEY" ] && SSH_OPTS+=(-i "$SSH_KEY")
R() { ssh "${SSH_OPTS[@]}" "root@$ROUTER" "$@" 2>/dev/null; }

head_ "Router $ROUTER"
if ! R true; then
  bad "SSH reachable" "cannot log in as root with a key — run ./network/router-access.sh (and not under sudo)"
  printf '\n\033[1;31mNO-GO\033[0m — router unreachable\n'; exit 1
fi
ok "SSH reachable" "$(R 'cat /tmp/sysinfo/model 2>/dev/null') fw $(R 'cat /etc/glversion 2>/dev/null')"

# ── Radios and SSID ──────────────────────────────────────────────────────────
head_ "Radios"
RADIOS="$(R 'for d in $(uci show wireless | sed -n "s/^wireless\.\([^.=]*\)=wifi-device$/\1/p"); do echo "$d|$(uci -q get wireless.$d.band)|$(uci -q get wireless.$d.channel)|$(uci -q get wireless.$d.country)|$(uci -q get wireless.$d.disabled)"; done')"
n24=0; n5=0
while IFS='|' read -r dev band ch country dis; do
  [ -z "${dev:-}" ] && continue
  case "$band" in 2g) n24=1 ;; 5g) n5=1 ;; esac
  [ "$dis" = "1" ] && bad "radio $dev ($band) enabled" "disabled=1" || ok "radio $dev ($band) enabled" "ch $ch"
  [ "$country" = "$COUNTRY_WANT" ] && ok "radio $dev country" "$country" \
                                   || bad "radio $dev country" "$country, wanted $COUNTRY_WANT"
  # DFS: a 5 GHz radio on 'auto' or a DFS channel re-runs CAC at every cold boot and can
  # vacate on radar — presenting on site as "the Wi-Fi vanished" with nobody to notice.
  if [ "$band" = "5g" ]; then
    case "$ch" in
      auto) bad "radio $dev non-DFS channel" "channel=auto — may select DFS" ;;
      36|40|44|48) ok "radio $dev non-DFS channel" "$ch" ;;
      *) bad "radio $dev non-DFS channel" "$ch is outside UNII-1" ;;
    esac
  fi
done <<< "$RADIOS"
[ "$n24" = 1 ] && ok "2.4 GHz radio present" || bad "2.4 GHz radio present" "none found"
[ "$n5" = 1 ]  && ok "5 GHz radio present"   || bad "5 GHz radio present" "none found"

head_ "SSIDs"
IFACES="$(R 'for i in $(uci show wireless | sed -n "s/^wireless\.\([^.=]*\)=wifi-iface$/\1/p"); do echo "$i|$(uci -q get wireless.$i.ssid)|$(uci -q get wireless.$i.network)|$(uci -q get wireless.$i.disabled)|$(uci -q get wireless.$i.encryption)|$(uci -q get wireless.$i.isolate)"; done')"
seen_ssid=""; multi=0
while IFS='|' read -r iface ssid net dis enc iso; do
  [ -z "${iface:-}" ] && continue
  if [ "$dis" = "1" ]; then
    case "$iface" in guest*) ok "guest iface $iface disabled" ;; esac
    continue
  fi
  # A tablet provisioned onto a guest SSID is genuinely isolated and looks perfectly
  # associated — this is the check that catches it, not `isolate`.
  case "$iface" in guest*) bad "guest iface $iface disabled" "ENABLED" ;; esac
  [ "$net" = "lan" ] && ok "iface $iface on lan" || bad "iface $iface on lan" "network=$net"
  [ "$iso" = "0" ] || [ -z "$iso" ] && ok "iface $iface isolation off" "isolate=${iso:-unset}" \
                                    || bad "iface $iface isolation off" "isolate=$iso"
  # Compare to the configured value, not a loose glob: psk2+ccmp would pass a glob while
  # being a value the vendor UI refuses to save.
  [ "$enc" = "$ENC_WANT" ] && ok "iface $iface encryption" "$enc" \
                           || bad "iface $iface encryption" "$enc, wanted $ENC_WANT"
  if [ -n "$seen_ssid" ] && [ "$ssid" != "$seen_ssid" ]; then multi=1; fi
  seen_ssid="$ssid"
done <<< "$IFACES"
[ "$multi" = 0 ] && ok "one SSID across all bands" "$seen_ssid" || bad "one SSID across all bands" "differs per band"
if [ -n "$SSID_WANT" ]; then
  [ "$seen_ssid" = "$SSID_WANT" ] && ok "SSID matches .env" "$SSID_WANT" || bad "SSID matches .env" "$seen_ssid != $SSID_WANT"
fi

# ── LAN ──────────────────────────────────────────────────────────────────────
head_ "LAN"
lanip="$(R 'uci -q get network.lan.ipaddr')"
[ "$lanip" = "$ROUTER" ] && ok "lan address" "$lanip" || bad "lan address" "$lanip != $ROUTER"

# ── DNS: who actually owns :53 ───────────────────────────────────────────────
head_ "DNS (running state, not configuration)"
LISTEN="$(R 'netstat -lnp 2>/dev/null')"
if echo "$LISTEN" | grep -q "udp .*$ROUTER:53 .*dnsmasq"; then
  ok "dnsmasq owns :53 on the LAN" "$ROUTER:53"
else
  bad "dnsmasq owns :53 on the LAN" "something else is bound — AdGuard Home displaces dnsmasq to 5353"
fi
if echo "$LISTEN" | grep -qE ":853 "; then
  bad "no DoT listener (:853)" "encrypted DNS is up — the local override is bypassed"
else
  ok "no DoT listener (:853)"
fi
PROCS="$(R 'ps w')"
BOOT="$(R 'for s in stubby adguardhome https-dns-proxy; do [ -f /etc/init.d/$s ] && echo "$s $(/etc/init.d/$s enabled >/dev/null 2>&1 && echo enabled || echo disabled)"; done')"
for svc in stubby adguardhome https-dns-proxy; do
  if echo "$PROCS" | grep -v grep | grep -qi "$svc"; then
    bad "$svc not running" "RUNNING — queries may leave over encrypted DNS"
  else
    ok "$svc not running"
  fi
  # Running state is not enough: a web-UI save can re-ENABLE a service without starting it,
  # and the failure then appears at the next cold boot, when nobody is watching.
  case "$(echo "$BOOT" | grep "^$svc " | awk '{print $2}')" in
    enabled) bad "$svc disabled at boot" "ENABLED — it will start on the next power cycle" ;;
    disabled) ok "$svc disabled at boot" ;;
  esac
done
# The generated config, not uci: this is what dnsmasq is actually serving. Read the file
# the RUNNING process was started with (-C), rather than globbing: on OpenWrt /var is a
# symlink to /tmp, so globbing both paths reads the same file twice and doubles every count.
GEN="$(R 'f=$(ps w | grep "[d]nsmasq -C" | sed -n "s/.* -C \([^ ]*\).*/\1/p" | head -1); [ -n "$f" ] && cat "$f"')"
for host in time.android.com time.google.com ntp.org; do
  if echo "$GEN" | grep -q "address=/$host/$SERVER_IP"; then
    ok "override present: $host" "-> $SERVER_IP"
  else
    bad "override present: $host" "absent from the GENERATED dnsmasq config"
  fi
done
# Exactly one DNS server in the DHCP offer. A vendor-added secondary is a false-pass
# vector: our own lookups succeed while the tablet round-robins to the other resolver.
ndns="$(echo "$GEN" | grep -c "dhcp-option=.*\b6,")"
[ "$ndns" -le 1 ] && ok "one DNS server advertised" "$ndns dhcp-option(6) line(s)" \
                  || bad "one DNS server advertised" "$ndns — a tablet may resolve elsewhere"

head_ "DNS redirect (running firewall)"
if [ "$FORCE_DNS_WANT" = "true" ]; then
  # Match OUR rule by name, not any dport-53 rule: the vendor ships its own dns_dispatcher
  # rules, which made this check pass on a router that had no redirect of ours at all.
  FW="$(R 'nft list ruleset 2>/dev/null | grep -i "buendia-dns-intercept" ; iptables -t nat -S 2>/dev/null | grep "buendia-dns-intercept"')"
  if [ -n "$FW" ]; then ok "port-53 redirect active" "$(echo "$FW" | wc -l) rule(s)"
  else bad "port-53 redirect active" "no dport-53 rule in the running firewall"; fi
else
  printf '  \033[1;33m·\033[0m %-42s %s\n' "port-53 redirect" "disabled by ROUTER_FORCE_DNS"
fi

# ── The intercept, answered for real ─────────────────────────────────────────
head_ "Intercept resolves (asked of the router, from here)"
for host in time.android.com time.google.com pool.ntp.org; do
  # The first Address: line is the RESOLVER's own address — only the one after Name: is
  # the answer. Reading the last Address blindly reports success against the router itself.
  got="$(timeout 5 nslookup "$host" "$ROUTER" 2>/dev/null | awk '/^Name:/{f=1;next} f&&/^Address/{print $NF;exit}')"
  [ "$got" = "$SERVER_IP" ] && ok "$host resolves to server" "$got" \
                            || bad "$host resolves to server" "got '${got:-nothing}', wanted $SERVER_IP"
done

# ── Time ─────────────────────────────────────────────────────────────────────
head_ "Time"
srv="$(R 'uci -q get system.ntp.server')"
echo "$srv" | grep -q "$SERVER_IP" && ok "router syncs from the server" "$srv" \
                                   || bad "router syncs from the server" "$srv"
es="$(R 'uci -q get system.ntp.enable_server')"
# This unit has no RTC, so it boots with a wrong clock. If it ever served time it would
# hand that wrong clock to anything that asked.
[ "$es" = "0" ] && ok "router does NOT serve time" "enable_server=0" \
                || bad "router does NOT serve time" "enable_server=$es and this unit has no RTC"
echo "$LISTEN" | grep -qE "udp .*:123 " \
  && bad "nothing listening on udp/123" "the router is answering NTP" \
  || ok "nothing listening on udp/123"

# ── Server side (opt-in) ─────────────────────────────────────────────────────
if [ -n "$SERVER" ]; then
  head_ "Server $SERVER"
  for p in 9000 9001; do
    code="$(curl -s -o /dev/null -m 10 -w '%{http_code}' "http://$SERVER:$p/" 2>/dev/null)"
    [ -n "$code" ] && [ "$code" != 000 ] && ok "server answers :$p" "$code" || bad "server answers :$p" "no answer"
  done
  # Without an OFF-BOX probe, chrony's `allow` directive is never exercised — and it is
  # hardcoded to one subnet in the shipped config (see the plan, defect D1).
  if command -v chronyd >/dev/null 2>&1; then
    if chronyd -Q -t 5 "server $SERVER iburst" >/dev/null 2>&1; then ok "NTP reply from server" "off-box probe"
    else bad "NTP reply from server" "chrony refused or did not answer — check its 'allow'"; fi
  elif command -v sntp >/dev/null 2>&1; then
    sntp "$SERVER" >/dev/null 2>&1 && ok "NTP reply from server" || bad "NTP reply from server" "no usable reply"
  else
    printf '  \033[1;33m·\033[0m %-42s %s\n' "NTP reply from server" "skipped (no chronyd/sntp here)"
  fi
fi

printf '\n'
if [ "$FAIL" -eq 0 ]; then printf '\033[1;32mGO\033[0m — %d checks passed\n' "$PASS"; exit 0; fi
printf '\033[1;31mNO-GO\033[0m — %d passed, %d FAILED\n' "$PASS" "$FAIL"; exit 1
