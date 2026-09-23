#!/bin/sh
# "Is the pilot server online right now?" — run ON THE RELAY.
#
# Do NOT answer this by looking for the listening port. A dead tunnel leaves the port bound for
# up to ClientAliveInterval x CountMax, during which `ss -ltn` reports the port and the box is
# NOT there. Measured: the naive check said ONLINE while the laptop had been destroyed.
# The only honest answer demands an SSH banner from the far end.
PORT="${1:-12222}"
if nc -w 5 127.0.0.1 "$PORT" 2>/dev/null | head -c 4 | grep -q SSH; then
  echo "ONLINE  (banner received through the tunnel on port $PORT)"; exit 0
else
  echo "OFFLINE (no banner on port $PORT - tunnel absent or stale)"; exit 1
fi
