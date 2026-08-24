#!/usr/bin/env bash
# One-time: let THIS machine configure the router over SSH.
#
#   ./network/router-access.sh            # generate a key if needed, install it on the router
#   ./network/router-access.sh --router 192.168.8.1
#
# Run it as YOUR OWN USER, not with sudo. The router scripts need no local root, and a key
# installed under sudo lands in /root/.ssh where your later commands will not look for it.
#
# It asks for the router's admin password once — the one set in the first-boot wizard. After
# this, configure-router.sh and verify-router.sh work without prompting, which is what lets them
# be idempotent and scriptable.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$HERE/../.env"
ROUTER=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --router) ROUTER="$2"; shift 2 ;;
    -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
log()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m%s\033[0m\n' "$*"; }
die()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

if [[ -n "${SUDO_USER:-}" || $EUID -eq 0 ]]; then
  die "do not run this with sudo.
       The key must belong to the user who will run configure-router.sh. Under sudo it would be
       written to /root/.ssh, and the later commands would not find it — which presents as
       'cannot SSH to the router' even though ssh works fine for you by hand.
       Re-run as yourself:  ./network/router-access.sh"
fi
if [[ -z "$ROUTER" && -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  set -a; . "$ENV_FILE"; set +a
  ROUTER="${ROUTER_IP:-}"
fi
ROUTER="${ROUTER:-192.168.8.1}"
command -v ssh >/dev/null || die "the ssh client is missing. Install it during the ONLINE step:
       sudo apt-get install -y openssh-client   (setup.sh --prepare does this for you)"

log "Router access -> root@$ROUTER"

# Is SSH even open? Closed means the first-boot wizard has not been completed, and no key can be
# installed until it is. Saying so here saves a confusing password prompt that cannot succeed.
if ! timeout 5 bash -c "exec 3<>/dev/tcp/$ROUTER/22" 2>/dev/null; then
  die "nothing is listening on $ROUTER:22.
       The router's first-boot wizard has not been completed — SSH stays shut until it is.
       Open http://$ROUTER in a browser, finish the wizard, set the admin password, then re-run."
fi
ok "  $ROUTER:22 is open"

KEY="$HOME/.ssh/id_ed25519"
if compgen -G "$HOME/.ssh/id_*" >/dev/null; then
  KEY="$(ls -1 "$HOME"/.ssh/id_*.pub 2>/dev/null | head -1 || true)"; KEY="${KEY%.pub}"
  [[ -n "$KEY" ]] || KEY="$HOME/.ssh/id_ed25519"
fi
if [[ ! -f "$KEY" ]]; then
  log "Creating an SSH key (no passphrase — this must work unattended)"
  ssh-keygen -t ed25519 -N "" -f "$KEY" -C "buendia-server-$(hostname)"
fi
echo "  using key: $KEY"

# Already trusted? Then this is a no-op and needs no password.
if ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new \
       -i "$KEY" "root@$ROUTER" true 2>/dev/null; then
  ok "already trusted — nothing to do"
else
  log "Installing the key on the router"
  echo "  Enter the router's ADMIN password (the one you set in the first-boot wizard)."
  ssh-copy-id -i "$KEY.pub" -o StrictHostKeyChecking=accept-new "root@$ROUTER" \
    || die "could not install the key. If the password was refused, it is the wizard's admin
       password that is wanted, not the Wi-Fi passphrase."
  ssh -o BatchMode=yes -o ConnectTimeout=10 -i "$KEY" "root@$ROUTER" true 2>/dev/null \
    || die "the key was copied but key-only login still fails. Check the router allows SSH keys."
  ok "key installed and verified"
fi

echo
echo "Next:  ./network/configure-router.sh        (no sudo — it needs no local root)"
