#!/usr/bin/env bash
# Undo a Buendia installation, so the machine can be installed again from scratch.
#
#   sudo ./buendia-uninstall.sh --dry-run    # print everything it would do, change nothing
#   sudo ./buendia-uninstall.sh              # do it (asks for confirmation)
#   sudo ./buendia-uninstall.sh --keep-docker
#
# DESTROYS ALL PATIENT DATA on this machine. There is no backup mechanism yet, so anything the
# tablets have not synced elsewhere is gone. It exists for repeat testing and for a clean
# reinstall, and it is the reverse of setup.sh: the stack and its volumes, /opt/buendia, the
# static address, chrony's config, the Docker daemon config, and (unless --keep-docker) Docker
# itself, so that a later install genuinely exercises the install path.
#
# It does NOT touch the router: run network/configure-router.sh again, or factory-reset it.
set -euo pipefail
DRY=0; KEEP_DOCKER=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY=1; shift ;;
    --keep-docker) KEEP_DOCKER=1; shift ;;
    -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
C=$'\033[1;36m'; Y=$'\033[1;33m'; R=$'\033[1;31m'; G=$'\033[1;32m'; N=$'\033[0m'
log() { printf '\n%s==> %s%s\n' "$C" "$*" "$N"; }
run() { if [[ $DRY -eq 1 ]]; then printf '  [dry-run] %s\n' "$*"; else printf '  %s\n' "$*"; eval "$@" || true; fi; }
# --dry-run needs no privileges: the point is to read it before running it.
[[ $EUID -eq 0 || $DRY -eq 1 ]] || { printf '%sERROR: run with sudo%s\n' "$R" "$N" >&2; exit 1; }

if [[ $DRY -eq 0 ]]; then
  printf '%sThis deletes the Buendia database and all patient data on this machine.%s\n' "$Y" "$N"
  read -r -p 'Type ERASE to continue: ' a </dev/tty || a=""
  [[ "$a" == "ERASE" ]] || { echo "aborted — nothing changed."; exit 1; }
fi

log "Stopping the stack and deleting its volumes"
if [[ -f /opt/buendia/compose/docker-compose.yml ]]; then
  run "cd /opt/buendia/compose && docker compose --env-file /opt/buendia/.env down -v --remove-orphans"
fi
run "docker ps -aq | xargs -r docker rm -f"
run "docker volume ls -q | xargs -r docker volume rm -f"
run "docker system prune -af --volumes"

log "Forgetting the router's SSH identity"
# The router key lives inside /opt/buendia and goes with it, but the known_hosts records do not.
# Leaving them means the next install against a re-reset router fails with a host-key warning
# that looks alarming and has nothing to do with Buendia.
ROUTER_IP_SEEN="$(awk -F= '/^ROUTER_IP=/{sub(/#.*/,"",$2); gsub(/[ \t]/,"",$2); print $2; exit}' /opt/buendia/.env 2>/dev/null || true)"
ROUTER_IP_SEEN="${ROUTER_IP_SEEN:-192.168.8.1}"
for f in /root/.ssh/known_hosts "$(getent passwd "${SUDO_USER:-root}" | cut -d: -f6)/.ssh/known_hosts"; do
  [[ -f "$f" ]] && run "ssh-keygen -f '$f' -R '$ROUTER_IP_SEEN' >/dev/null 2>&1 || true"
done

log "Removing the deployment"
run "rm -rf /opt/buendia /var/log/buendia-setup.log"

log "Undoing the host configuration"
run "rm -f /etc/netplan/60-buendia.yaml"
run "netplan apply"
run "rm -f /etc/chrony/conf.d/buendia-ntp.conf /etc/chrony/chrony.conf.d/buendia-ntp.conf"
run "systemctl restart chrony 2>/dev/null || true"
run "rm -f /etc/docker/daemon.json"
run "rm -f /etc/systemd/logind.conf.d/buendia.conf"
run "systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target"
# Background updates were disabled on purpose; put them back so the box is stock again.
run "systemctl unmask apt-daily.service apt-daily-upgrade.service"
run "systemctl enable --now apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true"
run "systemctl enable --now unattended-upgrades 2>/dev/null || true"
command -v snap >/dev/null 2>&1 && run "snap refresh --unhold 2>/dev/null || true"

if [[ $KEEP_DOCKER -eq 0 ]]; then
  log "Removing Docker and chrony, so a reinstall really exercises the install path"
  run "apt-get purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-buildx-plugin docker.io chrony"
  run "apt-get autoremove -y"
  run "rm -rf /var/lib/docker /etc/docker"
  run "rm -f /etc/apt/sources.list.d/docker.list /etc/apt/keyrings/docker.gpg"
else
  log "Keeping Docker (--keep-docker): a reinstall will skip the Docker install step"
fi

log "Done"
cat <<TXT
  This machine is back to a plain Ubuntu install.

  ${Y}One thing to check by hand:${N} the wired connection's IPv4 may still be set to Automatic
  from the install — that is fine and is what you want.

  To install again: plug in the USB stick and start from step 1 (sudo ./prepare.sh).
  The router keeps its configuration; re-run /opt/buendia/network/configure-router.sh after the
  reinstall, or factory-reset the router to rehearse that part too.
TXT
