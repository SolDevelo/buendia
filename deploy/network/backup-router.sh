#!/usr/bin/env bash
# Export the router's configuration as a restorable archive (WS-8, second of the two forms).
#
#   ./backup-router.sh                    # -> router-backup-<model>-<fw>-<date>.tar.gz (+ .sha256)
#   ./backup-router.sh --router 192.168.8.1 --key ~/.ssh/id_flint --out /path/dir
#
# The kit carries the configuration TWICE because the two forms fail differently:
#   - this archive is a 30-second restore for an IDENTICAL unit (the common case: a reset
#     router, or the spare from the kit);
#   - configure-router.sh is what survives a firmware bump, a different model, or a unit
#     bought locally in a hurry, because an archive carries this device's radio identity
#     and Ethernet topology and can leave another model with no working LAN.
#
# ⚠️ TREAT THE OUTPUT AS A CREDENTIAL. It contains /etc/config/wireless with the Wi-Fi
#    passphrase in cleartext AND /etc/shadow with the router's root password hash. It is
#    git-ignored here; keep it out of the deployment bundle and off shared storage.
# ⚠️ Restore only onto the SAME FIRMWARE VERSION it came from — a cross-version restore
#    can silently drop renamed configuration.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$HERE/../.env"
# One explicit key for every caller. A ~/.ssh key is invisible to root and a root key is
# invisible to the user, so anything depending on $HOME breaks depending on whether sudo was
# used. router-access.sh creates this; nothing here depends on who is running.
DEFAULT_KEY="$HERE/router_key"
ROUTER=""; SSH_KEY=""; OUT_DIR="$HERE"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --router) ROUTER="$2"; shift 2 ;;
    --key)    SSH_KEY="$2"; shift 2 ;;
    --out)    OUT_DIR="$2"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1 (try --help)" >&2; exit 2 ;;
  esac
done
# shellcheck disable=SC1090
[[ -f "$ENV_FILE" ]] && { set -a; source "$ENV_FILE"; set +a; }
ROUTER="${ROUTER:-${ROUTER_IP:-192.168.8.1}}"

# accept-new, not "ask": the router is on a directly-cabled LAN we own, and BatchMode
# would otherwise fail on first contact with no way to say yes. A CHANGED key still
# fails, which is the property worth keeping.
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new)
if [[ -z "$SSH_KEY" && -f "$DEFAULT_KEY" ]]; then SSH_KEY="$DEFAULT_KEY"; fi
[[ -n "$SSH_KEY" ]] && SSH_OPTS+=(-i "$SSH_KEY")
R() { ssh "${SSH_OPTS[@]}" "root@$ROUTER" "$@"; }

R true 2>/dev/null || { echo "ERROR: cannot SSH to root@$ROUTER" >&2; exit 1; }
MODEL="$(R 'cat /tmp/sysinfo/model 2>/dev/null || echo unknown' | tr ' /' '--')"
FW="$(R 'cat /etc/glversion 2>/dev/null || echo unknown' | tr -d '\r')"
# The date comes from THIS box, not the router: the Flint 2 has no RTC and boots with a
# stale clock, so a router-side date would name the file wrongly after every power cut.
STAMP="$(date +%Y%m%d)"
mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/router-backup-$MODEL-$FW-$STAMP.tar.gz"

echo "==> $MODEL / firmware $FW -> $OUT"
R 'sysupgrade -b /tmp/backup.tar.gz >/dev/null 2>&1 && cat /tmp/backup.tar.gz; rm -f /tmp/backup.tar.gz' > "$OUT"
[[ -s "$OUT" ]] || { rm -f "$OUT"; echo "ERROR: backup came back empty" >&2; exit 1; }
tar tzf "$OUT" >/dev/null 2>&1 || { echo "ERROR: $OUT is not a readable tar.gz" >&2; exit 1; }

( cd "$OUT_DIR" && sha256sum "$(basename "$OUT")" > "$(basename "$OUT").sha256" )
chmod 600 "$OUT" "$OUT.sha256"
echo "    $(du -h "$OUT" | cut -f1)  $(wc -l < <(tar tzf "$OUT")) files"
echo "    sha256: $(cut -d' ' -f1 "$OUT.sha256")"
echo
echo "Restore (identical unit, SAME firmware $FW):  GL.iNet UI -> System -> Backup & Restore"
echo "Different model, or no UI:                    run configure-router.sh instead"
