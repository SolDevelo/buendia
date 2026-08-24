#!/usr/bin/env bash
# Install this server's SSH key on the router, so the router can be configured from here.
#
#   sudo ./network/router-access.sh
#
# Run it with sudo, like everything else in this deployment. It uses a DEDICATED key kept beside
# these scripts — /opt/buendia/network/router_key — rather than a user's ~/.ssh key. That is the
# whole point: a key in someone's home directory is invisible to root, and a key owned by root
# is invisible to the user, so anything relying on $HOME breaks the moment sudo is or is not
# used. An explicit path is the same for every caller.
#
# It asks for the router's admin password once — the one set in the router's setup wizard.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$HERE/../.env"
KEY="$HERE/router_key"
ROUTER=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --router) ROUTER="$2"; shift 2 ;;
    --key)    KEY="$2"; shift 2 ;;
    -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()  { printf '\033[1;32m  %s\033[0m\n' "$*"; }
die() { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "run this with sudo: sudo $0"
if [[ -z "$ROUTER" && -f "$ENV_FILE" ]]; then
  set -a; . "$ENV_FILE"; set +a
  ROUTER="${ROUTER_IP:-}"
fi
ROUTER="${ROUTER:-192.168.8.1}"
command -v ssh >/dev/null || die "the ssh client is missing — it is installed by prepare.sh, while online."

log "Router access -> root@$ROUTER  (key: $KEY)"

# Port 22 closed means the router's setup wizard has not been completed; no key can be installed
# until it is. Checking first turns a doomed password prompt into a clear instruction.
if ! timeout 5 bash -c "exec 3<>/dev/tcp/$ROUTER/22" 2>/dev/null; then
  die "nothing is listening on $ROUTER:22.
       The router's setup wizard has not been completed yet — SSH stays closed until it is.
       Open http://$ROUTER in a browser, complete the wizard, set the admin password, re-run this."
fi
ok "$ROUTER:22 is open"

if [[ ! -f "$KEY" ]]; then
  log "Creating the router key"
  ssh-keygen -t ed25519 -N "" -f "$KEY" -C "buendia-server" >/dev/null
  chmod 600 "$KEY"; ok "created $KEY"
fi

SSH_BASE=(-o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -i "$KEY")
if ssh -o BatchMode=yes "${SSH_BASE[@]}" "root@$ROUTER" true 2>/dev/null; then
  ok "already trusted — nothing to do"
else
  log "Installing the key on the router"
  echo "  Enter the router's ADMIN password (from its setup wizard) when asked."
  echo "  That is the password for the router's web page, NOT the Wi-Fi passphrase."
  echo
  ssh-copy-id -i "$KEY.pub" -o StrictHostKeyChecking=accept-new "root@$ROUTER" \
    || die "the key could not be installed. If the password was refused it is the router's admin
       password that is wanted, not the Wi-Fi passphrase."
  ssh -o BatchMode=yes "${SSH_BASE[@]}" "root@$ROUTER" true 2>/dev/null \
    || die "the key copied but key-only login still fails. Check the router permits SSH keys."
  ok "key installed and verified"
fi
