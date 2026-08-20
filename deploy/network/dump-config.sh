#!/usr/bin/env bash
# Print the router's configuration as a canonical, comparable list of key=value lines.
#
#   ./dump-config.sh --key ~/.ssh/buendia-flint > before.txt
#   ./dump-config.sh --key ~/.ssh/buendia-flint > after.txt && diff before.txt after.txt
#
# This exists so "the restored router and the script-built router agree" (WS-8 T5/T6) is a
# REPRODUCIBLE criterion rather than a judgement call. A raw `uci show` diff cannot serve:
# a factory reset regenerates the ULA prefix, dropbear host keys and vendor tokens, radio
# MACs and `option path` are device state, and anonymous section names (cfgXXXXXX) are
# positional. All of those differ for reasons that have nothing to do with our settings.
#
# So this emits a DECLARED ALLOWLIST of the things we actually set, addressed by stable
# handles: radios resolved BY BAND, the firewall rule found BY NAME. That also makes the
# dump valid on a different model — which is the whole point of shipping a script.
#
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$HERE/../.env"
ROUTER=""; SSH_KEY=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --router) ROUTER="$2"; shift 2 ;;
    --key)    SSH_KEY="$2"; shift 2 ;;
    -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
# shellcheck disable=SC1090
if [[ -f "$ENV_FILE" ]]; then set -a; source "$ENV_FILE"; set +a; fi
ROUTER="${ROUTER:-${ROUTER_IP:-192.168.8.1}}"
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new)
if [[ -n "$SSH_KEY" ]]; then SSH_OPTS+=(-i "$SSH_KEY"); fi

ssh "${SSH_OPTS[@]}" "root@$ROUTER" 'sh -s' <<'REMOTE'
set -u
g() { printf '%s=%s\n' "$1" "$(uci -q get "$1" || echo '<unset>')"; }

# Radios, resolved by band so this is not tied to mt798611/radio0/whatever the model calls them
for band in 2g 5g; do
  dev=""
  for d in $(uci show wireless | sed -n "s/^wireless\.\([^.=]*\)=wifi-device$/\1/p"); do
    [ "$(uci -q get "wireless.$d.band")" = "$band" ] && dev="$d"
  done
  [ -z "$dev" ] && { echo "radio[$band]=<absent>"; continue; }
  for opt in channel htmode country disabled; do
    printf 'radio[%s].%s=%s\n' "$band" "$opt" "$(uci -q get "wireless.$dev.$opt" || echo '<unset>')"
  done
  # The AP interfaces attached to this radio, by their functional settings only
  for i in $(uci show wireless | sed -n "s/^wireless\.\([^.=]*\)=wifi-iface$/\1/p"); do
    [ "$(uci -q get "wireless.$i.device")" = "$dev" ] || continue
    for opt in ssid encryption key network mode isolate disabled; do
      printf 'iface[%s:%s].%s=%s\n' "$band" "$(uci -q get "wireless.$i.ssid" || echo none)" \
             "$opt" "$(uci -q get "wireless.$i.$opt" || echo '<unset>')"
    done
  done
done

g network.lan.ipaddr
g network.lan.netmask
g dhcp.lan.start
g dhcp.lan.limit
g dhcp.lan.leasetime
g dhcp.lan.ra
g dhcp.lan.dhcpv6
g dhcp.lan.dhcp_option
g system.ntp.server
g system.ntp.enabled
g system.ntp.enable_server

# dnsmasq + system are anonymous sections; address them by type index, which is stable
printf 'dnsmasq.address=%s\n' "$(uci -q get dhcp.@dnsmasq[0].address || echo '<unset>')"
printf 'dnsmasq.rebind_protection=%s\n' "$(uci -q get dhcp.@dnsmasq[0].rebind_protection || echo '<unset>')"
printf 'dnsmasq.logqueries=%s\n' "$(uci -q get dhcp.@dnsmasq[0].logqueries || echo '<unset>')"
printf 'system.zonename=%s\n' "$(uci -q get system.@system[0].zonename || echo '<unset>')"

# Our firewall redirect, found by NAME rather than by index
sec="$(uci show firewall 2>/dev/null | sed -n "s/^firewall\.\([^.]*\)\.name='buendia-dns-intercept'$/\1/p" | head -1)"
if [ -n "$sec" ]; then
  for opt in src proto src_dport dest_port dest_ip target family enabled; do
    printf 'redirect.%s=%s\n' "$opt" "$(uci -q get "firewall.$sec.$opt" || echo '<unset>')"
  done
else
  echo "redirect=<absent>"
fi

# Boot-enabled state of the services that can silently defeat the DNS override
for s in stubby adguardhome https-dns-proxy; do
  if [ -f "/etc/init.d/$s" ]; then
    /etc/init.d/$s enabled >/dev/null 2>&1 && echo "service[$s].boot=enabled" || echo "service[$s].boot=disabled"
  else
    echo "service[$s].boot=<absent>"
  fi
done
REMOTE
