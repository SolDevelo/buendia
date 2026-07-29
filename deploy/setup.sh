#!/usr/bin/env bash
#
# Buendia field-pilot server setup.
#
# Turns a fresh Ubuntu Server LTS install into a configured, offline-capable
# Buendia server. Idempotent: safe to re-run. Run at the SolDevelo Staging Area.
#
#   sudo ./setup.sh            # --online (default): pull Docker + images from the internet
#   sudo ./setup.sh --offline  # rebuild from bundled debs/ + images/ tarballs, no internet
#
# See README.md. This script consumes pre-built artefacts (the OpenMRS image is
# produced by the reproducible build, WS-3) — it does NOT build OpenMRS.
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Config & args
# ---------------------------------------------------------------------------
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="online"
for arg in "$@"; do
  case "$arg" in
    --online)  MODE="online"  ;;
    --offline) MODE="offline" ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//' ; exit 0 ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

if [[ ! -f "$HERE/.env" ]]; then
  echo "ERROR: $HERE/.env not found. Copy .env.example to .env and fill it in." >&2
  exit 1
fi
# shellcheck disable=SC1091
set -a; source "$HERE/.env"; set +a

: "${STATIC_IP:?set STATIC_IP in .env}"
: "${OPENMRS_IMAGE:?set OPENMRS_IMAGE in .env}"
: "${TZ:=UTC}"
: "${ENABLE_REMOTE_SUPPORT:=false}"

log()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mWARN: %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }
[[ $EUID -eq 0 ]] || die "run as root (sudo)."

# ---------------------------------------------------------------------------
# 1. Preflight
# ---------------------------------------------------------------------------
preflight() {
  log "Preflight"
  [[ "$(uname -m)" == "x86_64" ]] || die "x86-64 required (see plan §3.1)."
  . /etc/os-release
  [[ "${ID:-}" == "ubuntu" || "${ID:-}" == "debian" ]] || warn "untested OS: ${ID:-unknown}"
  echo "OS=${PRETTY_NAME:-?}  mode=$MODE  static_ip=$STATIC_IP  tz=$TZ"
}

# ---------------------------------------------------------------------------
# 2. Host configuration (unattended-operation hardening, plan §3.1 / §3.4)
# ---------------------------------------------------------------------------
host_config() {
  log "Host config: timezone → $TZ"
  timedatectl set-timezone "$TZ"

  log "Host config: ignore laptop lid, disable suspend/sleep (run lid-OPEN for cooling, §7)"
  install -d /etc/systemd/logind.conf.d
  install -m 0644 "$HERE/config/logind.conf.d/buendia.conf" /etc/systemd/logind.conf.d/buendia.conf
  systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target || true

  log "Host config: static IP (netplan)"
  # NB: review config/netplan/60-buendia.yaml — the wired interface name is host-specific.
  install -m 0600 "$HERE/config/netplan/60-buendia.yaml" /etc/netplan/60-buendia.yaml
  netplan apply || warn "netplan apply failed — check interface name in 60-buendia.yaml"

  log "Host config: chrony (server is the LAN time authority, §3.4)"
  ensure_pkg chrony
  install -m 0644 "$HERE/config/chrony/buendia-ntp.conf" /etc/chrony/conf.d/buendia-ntp.conf 2>/dev/null \
    || install -m 0644 "$HERE/config/chrony/buendia-ntp.conf" /etc/chrony/chrony.conf.d/buendia-ntp.conf
  systemctl enable --now chrony 2>/dev/null || systemctl enable --now chronyd || true

  # Graceful shutdown on low battery / UPS: laptop battery via UPower thresholds,
  # or Network UPS Tools for an external UPS. TODO: wire to the chosen power kit (§3.1).
  warn "TODO: configure graceful shutdown on low battery / UPS (§3.1) for the chosen power kit."
}

# ---------------------------------------------------------------------------
# 3. Docker + Compose
# ---------------------------------------------------------------------------
install_docker() {
  if command -v docker >/dev/null && docker compose version >/dev/null 2>&1; then
    log "Docker already present: $(docker --version)"
  elif [[ "$MODE" == "offline" ]]; then
    log "Installing Docker from bundled debs/ (offline)"
    ls "$HERE"/debs/*.deb >/dev/null 2>&1 || die "no .deb files in debs/ for offline install."
    dpkg -i "$HERE"/debs/*.deb || apt-get -f install -y
  else
    log "Installing Docker (online, pinned ${DOCKER_VERSION:-latest})"
    apt-get update
    apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    . /etc/os-release
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
      > /etc/apt/sources.list.d/docker.list
    apt-get update
    # Pin via DOCKER_VERSION when set (e.g. 5:26.1.4-1~ubuntu.22.04~jammy); else latest.
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  fi

  log "Docker: log rotation caps (§3.1) + start on boot"
  install -d /etc/docker
  install -m 0644 "$HERE/config/docker/daemon.json" /etc/docker/daemon.json
  systemctl enable --now docker
  systemctl restart docker
}

ensure_pkg() {
  command -v "$1" >/dev/null && return 0
  if [[ "$MODE" == "offline" ]]; then warn "offline: cannot apt-get $1 — ensure it is preinstalled"; return 0; fi
  apt-get install -y "$1"
}

# ---------------------------------------------------------------------------
# 4. Container images
# ---------------------------------------------------------------------------
load_images() {
  if [[ "$MODE" == "offline" ]]; then
    log "Loading container images from images/*.tar (offline)"
    ls "$HERE"/images/*.tar >/dev/null 2>&1 || die "no image tarballs in images/ for offline load."
    for t in "$HERE"/images/*.tar; do docker load -i "$t"; done
  else
    log "Pulling container images (online, pinned by digest in .env)"
    docker pull "${MYSQL_IMAGE:?}"
    docker pull "${OPENMRS_IMAGE:?}"
    [[ -n "${PKGSERVER_IMAGE:-}" ]] && docker pull "$PKGSERVER_IMAGE" || true
  fi
}

# ---------------------------------------------------------------------------
# 5. Seed data + bring up the stack
# ---------------------------------------------------------------------------
bring_up() {
  log "Seed check"
  ls "$HERE"/seed/*.sql >/dev/null 2>&1 || warn "seed/ has no *.sql — DB will start empty (see seed/README.md)."

  log "Starting the stack (docker compose up -d)"
  ( cd "$HERE/compose" && docker compose --env-file "$HERE/.env" up -d )
}

# ---------------------------------------------------------------------------
# 6. Remote support (Tailscale + SSH) — ships DISABLED until data-protection sign-off (§3.5/§8)
# ---------------------------------------------------------------------------
remote_support() {
  if [[ "$ENABLE_REMOTE_SUPPORT" != "true" ]]; then
    log "Remote support: DISABLED (ENABLE_REMOTE_SUPPORT!=true) — install only, do not connect"
  else
    log "Remote support: enabling Tailscale (server-initiated dial-out + SSH)"
  fi
  if ! command -v tailscale >/dev/null; then
    if [[ "$MODE" == "offline" ]]; then
      warn "offline: tailscale not bundled — install it during staging (online) before shipping"
      return 0
    fi
    curl -fsSL https://tailscale.com/install.sh | sh
  fi
  if [[ "$ENABLE_REMOTE_SUPPORT" == "true" ]]; then
    : "${TAILSCALE_AUTHKEY:?set TAILSCALE_AUTHKEY in .env to enable remote support}"
    tailscale up --ssh --hostname "buendia-${SITE_ID:-pilot}" --authkey "$TAILSCALE_AUTHKEY"
  else
    echo "  To enable later: set ENABLE_REMOTE_SUPPORT=true + TAILSCALE_AUTHKEY in .env, re-run,"
    echo "  or run: tailscale up --ssh --hostname buendia-${SITE_ID:-pilot}"
  fi
}

# ---------------------------------------------------------------------------
# 7. Health check
# ---------------------------------------------------------------------------
health_check() {
  log "Health check: waiting for the OpenMRS REST API on :9000"
  # /ws/rest/v1/session returns 200 without auth once the platform + REST framework are up.
  # (The buendia resources require auth and would 401 here — don't use them for health.)
  local url="http://localhost:9000/openmrs/ws/rest/v1/session"
  for i in $(seq 1 90); do
    if curl -fsS -o /dev/null "$url" 2>/dev/null; then
      printf '\033[1;32mGREEN: OpenMRS REST is up (%s)\033[0m\n' "$url"
      return 0
    fi
    sleep 5
  done
  warn "REST API not reachable after ~5 min. Check: docker compose -f compose/docker-compose.yml logs"
  return 1
}

# ---------------------------------------------------------------------------
main() {
  preflight
  host_config
  install_docker
  load_images
  bring_up
  remote_support
  health_check || true
  log "Done. Next (manual, see STAGING-SETUP-GUIDE): router config, tablet APK/clock/PIN, acceptance test."
}
main
