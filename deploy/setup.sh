#!/usr/bin/env bash
#
# Buendia field-pilot server setup.
#
# Turns a fresh Ubuntu Server LTS install into a configured, offline-capable
# Buendia server. Idempotent: safe to re-run.
#
#   sudo ./setup.sh              # --online (default): pull images from Docker Hub
#   sudo ./setup.sh --offline    # no internet: load images from bundled images/*.tar
#
# TWO-STEP INSTALL, for a site whose internet is not the network the server runs on (MSF's
# restricted Wi-Fi, a phone hotspot, an office drop). Run these in order, moving the cable
# in between:
#   1. sudo ./setup.sh --prepare   ONLINE, connected to the internet. Installs Docker and
#                                  chrony and pulls the images. Touches NO networking and
#                                  starts nothing, so it cannot fight the connection it is
#                                  using, and can be run anywhere with internet.
#   2. sudo ./setup.sh --finish    OFFLINE, now cabled to OUR router. Applies the static
#                                  address, starts the stack and runs the go/no-go. Needs no
#                                  internet: the images are already in the local image store.
#   sudo ./setup.sh --dry-run    # print every change without making one (test the run first)
#   sudo ./setup.sh --skip-verify        # stop after starting the stack, don't run the go/no-go
#
#   # ...and to also fetch the tablet APK payload from its PRIVATE release:
#   GITHUB_TOKEN=<fine-grained, read-only> sudo -E ./setup.sh
#   (`-E` keeps the token in the environment across sudo. It is never written to .env or the log.)
#
# INTERNET AT SETUP, NONE AT RUNTIME. --online pulls three images (db, openmrs, pkgserver)
# from Docker Hub; after that the site needs no internet ever again. The DB image carries the
# baseline seed and the pkgserver image can carry the tablet APK, so there are no heavy files
# to copy onto the machine. --offline exists for a rebuild on site with no connectivity.
#
# This script consumes PRE-BUILT artefacts (see ../README.md "Build order"); it does not
# build OpenMRS, the seed, or the APK.
#
# Exit code: 0 only if the stack came up AND passed tools/buendia-verify.sh. Non-zero
# otherwise — so a staging run can be scripted and trusted.
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Config & args
# ---------------------------------------------------------------------------
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# ONE documented path, two steps: prepare.sh (online) then setup.sh (offline). Running setup.sh
# with no arguments IS the offline step — it configures the router, applies the address, starts
# the stack and verifies. --online remains for the legacy all-in-one run used at SolDevelo.
MODE="offline"
PHASE="install"      # install (offline: router+network+stack) | prepare (online: packages+images) | all
DRY_RUN=0
DO_VERIFY=1
for arg in "$@"; do
  case "$arg" in
    --online)      MODE="online"; PHASE="all" ;;
    --offline)     MODE="offline" ;;
    --prepare)     PHASE="prepare"; MODE="online" ;;
    # --finish implies offline: by then the box is on our router, which has no uplink. That
    # makes every network-touching step (apt, tailscale, docker pull) take its no-network
    # branch without the operator having to remember a second flag.
    --finish)      PHASE="install"; MODE="offline" ;;   # kept: older notes use this name
    --dry-run)     DRY_RUN=1 ;;
    --skip-verify) DO_VERIFY=0 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//' ; exit 0 ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

log()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mWARN: %s\033[0m\n' "$*" >&2; }
ok()   { printf '\033[1;32m%s\033[0m\n' "$*"; }
die()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

# Every host-mutating command goes through run(), so --dry-run is honest: it prints
# exactly what would happen and changes nothing. (Read-only probes call tools directly.)
run() {
  if [[ $DRY_RUN -eq 1 ]]; then printf '  \033[0;36m[dry-run]\033[0m %s\n' "$*"; return 0; fi
  "$@"
}
# Same, for a shell pipeline or a redirect that run() can't take as argv.
run_sh() {
  if [[ $DRY_RUN -eq 1 ]]; then printf '  \033[0;36m[dry-run]\033[0m sh -c %q\n' "$1"; return 0; fi
  bash -c "$1"
}

if [[ ! -f "$HERE/.env" ]]; then
  die "$HERE/.env not found. Copy .env.example to .env and fill it in."
fi
# .env is `source`d by bash: an unquoted value containing a space or ; & | $ * ? aborts here.
# shellcheck disable=SC1091
set -a; source "$HERE/.env"; set +a

: "${STATIC_IP:?set STATIC_IP in .env}"
: "${OPENMRS_IMAGE:?set OPENMRS_IMAGE in .env}"
: "${TZ:=UTC}"
: "${ENABLE_REMOTE_SUPPORT:=false}"
: "${CONFIGURE_NETWORK:=true}"
: "${NET_PREFIX:=24}"
: "${ALLOW_UNSEEDED_DB:=false}"
DB_IMAGE="${DB_IMAGE:-${MYSQL_IMAGE:-}}"
[[ -n "$DB_IMAGE" ]] || die "set DB_IMAGE in .env (build it with seed/build-db-image.sh)."

[[ $EUID -eq 0 || $DRY_RUN -eq 1 ]] || die "run as root (sudo)."
[[ $DRY_RUN -eq 0 ]] || log "DRY RUN — no changes will be made"

# ---------------------------------------------------------------------------
# 1. Preflight
# ---------------------------------------------------------------------------
preflight() {
  log "Preflight"
  # x86-64 is a hard requirement, not a preference: mysql:5.6 (the last MySQL that works with
  # OpenMRS 1.10's hardcoded storage_engine) has no arm64 image. No ARM mini-PCs / Raspberry Pi.
  [[ "$(uname -m)" == "x86_64" ]] || die "x86-64 required (mysql:5.6 is amd64-only). See plan §3.1."
  . /etc/os-release
  [[ "${ID:-}" == "ubuntu" || "${ID:-}" == "debian" ]] || warn "untested OS: ${ID:-unknown}"

  # Catch a .env that was never filled in. Shipping CHANGE_ME as the DB password, or a
  # placeholder image digest, is the kind of thing that is obvious here and invisible later.
  local ph=0
  for v in MYSQL_ROOT_PASSWORD MYSQL_PASSWORD DB_IMAGE OPENMRS_IMAGE PKGSERVER_IMAGE; do
    case "${!v:-}" in
      *CHANGE_ME*|*REPLACE_WITH_DIGEST*|*YOUR_ORG*) warn "$v still holds a placeholder: ${!v}"; ph=1 ;;
    esac
  done
  [[ $ph -eq 0 ]] || die ".env has unfilled placeholders (above). Fill them in before deploying."

  [[ "$STATIC_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "STATIC_IP is not an IPv4 address: $STATIC_IP"

  # The site seed is what makes first boot zero-config (login + locations). Without it the
  # server boots with nothing to admit a patient to and nobody able to log in.
  [[ -s "$HERE/seed/initdb/20-buendia-site.sql" ]] \
    || die "seed/initdb/20-buendia-site.sql is missing — first boot would have no login and no locations."

  echo "OS=${PRETTY_NAME:-?}  mode=$MODE  static_ip=$STATIC_IP  tz=$TZ"
  echo "db=$DB_IMAGE"
  echo "openmrs=$OPENMRS_IMAGE"
  # Floating tags make a re-run months later a different deployment. Not fatal; loud.
  for v in DB_IMAGE OPENMRS_IMAGE; do
    [[ "${!v}" == *"@sha256:"* ]] || warn "$v is not pinned by digest (${!v}) — a re-run may get different bits."
  done
}

# ---------------------------------------------------------------------------
# 2. Host configuration (unattended operation, plan §3.1 / §3.4)
# ---------------------------------------------------------------------------
APT_REFRESHED=0
apt_refresh() {
  [[ "$MODE" == "offline" ]] && return 0
  [[ $APT_REFRESHED -eq 1 ]] && return 0
  run apt-get update
  APT_REFRESHED=1
}

DEBS_INSTALLED=0
# Install the whole bundled .deb set with no network. TWO PHASES, deliberately: a single
# `dpkg -i` pass processes alphabetically and leaves packages unconfigured whenever a
# dependency happens to sort later. And the usual `|| apt-get -f install -y` fallback is worse
# than useless offline — it resolves the breakage by REMOVING packages (observed on a test
# target: it removed openssh-client) and still exits 0, so the run reports success with pieces
# missing. Unpack everything, then configure, then let the caller assert what it needed.
offline_debs_install() {
  [[ $DEBS_INSTALLED -eq 1 ]] && return 0
  ls "$HERE"/debs/*.deb >/dev/null 2>&1 || return 0   # nothing bundled; the caller decides
  log "Installing bundled packages from debs/ (offline, no network)"
  # chrony declares `Conflicts: time-daemon`, and stock Ubuntu ships systemd-timesyncd, which
  # PROVIDES time-daemon. Online, apt resolves that by swapping the two. dpkg alone refuses
  # ("conflicting packages - not installing chrony") and, since chrony is one archive among a
  # hundred, the run otherwise looks healthy — leaving a server that is not a time authority.
  # So retire the incumbent first. Verified on Ubuntu 26.04: this is what blocks chrony offline.
  local td
  for td in systemd-timesyncd ntp ntpsec openntpd; do
    if dpkg -s "$td" >/dev/null 2>&1; then
      log "Removing $td first — it provides time-daemon, which chrony conflicts with"
      run_sh "dpkg --remove $td || dpkg --purge $td"
    fi
  done
  run_sh "dpkg --unpack $HERE/debs/*.deb"
  run_sh "dpkg --configure -a"
  DEBS_INSTALLED=1
}

ensure_pkg() {
  # Test the PACKAGE, not a binary named after it: `command -v chrony` never matches, because
  # the package ships chronyd/chronyc — so this used to re-install on every single run.
  dpkg -s "$1" >/dev/null 2>&1 && return 0
  command -v "$1" >/dev/null && return 0
  if [[ "$MODE" == "offline" ]]; then
    # chrony comes through here, and its absence is silent: the server stops being the LAN time
    # authority, the DNS clock intercept resolves the tablets' NTP hostnames to a host that
    # answers nothing, every clock drifts — and buendia-verify.sh has no NTP assertion, so the
    # run still reports GO. Fatal, therefore, not a warning.
    offline_debs_install
    [[ $DRY_RUN -eq 1 ]] && return 0
    dpkg -s "$1" >/dev/null 2>&1 && return 0
    die "offline: '$1' is not installed.
       In the two-step install this is what step 1 is for — run it while connected to the
       internet, then come back:
           sudo ./setup.sh --prepare
       (For a genuinely never-online box, bundle the packages instead: on the build box run
       tools/bundle-debs.sh --release \$(. /etc/os-release; echo \$VERSION_CODENAME) — note that
       path is NOT yet validated: chrony conflicts with systemd-timesyncd under plain dpkg.)"
  fi
  apt_refresh          # must precede the first install: a fresh image has a stale index
  run apt-get install -y "$1"
}

# Pick the wired interface to configure. .env NET_IFACE wins; else the interface holding the
# default route; else the first non-loopback ethernet. Interface names are host-specific
# (enp1s0/eno1/eth0...), which is exactly why this is detected rather than hardcoded.
detect_iface() {
  if [[ -n "${NET_IFACE:-}" ]]; then echo "$NET_IFACE"; return; fi
  local i
  i="$(ip -o -4 route show default 2>/dev/null | awk '{print $5}' | head -1)"
  # `|| true`: with `set -o pipefail`, a grep matching nothing fails the pipeline and would abort
  # the script here instead of reaching the "could not detect a wired interface" message below.
  [[ -n "$i" ]] || i="$(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' \
        | grep -Ev '^(lo|docker|br-|veth|virbr|wl)' | head -1 || true)"
  echo "$i"
}

host_config() {
  log "Host config: timezone → $TZ"
  run timedatectl set-timezone "$TZ"

  log "Host config: ignore laptop lid, disable suspend/sleep (run lid-OPEN for cooling, §7)"
  run install -d /etc/systemd/logind.conf.d
  run install -m 0644 "$HERE/config/logind.conf.d/buendia.conf" /etc/systemd/logind.conf.d/buendia.conf
  run_sh "systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target || true"

  # Deliberately NOT during --prepare: config_network puts the static site address on the wired
  # interface and points the default route and resolver at OUR router, which does not exist yet
  # on whatever connection is providing the internet. Doing it here would cut the very link the
  # image pull needs. It belongs to --finish, once the cable has moved.
  if [[ "$PHASE" == "prepare" ]]; then
    log "Networking: not touched by the online step (applied later, once cabled to the router)"
  else
    config_network
  fi

  log "Host config: chrony (server is the LAN time authority, §3.4)"
  ensure_pkg chrony
  local cd=/etc/chrony/conf.d
  [[ -d "$cd" ]] || cd=/etc/chrony/chrony.conf.d
  if [[ -d "$cd" ]] || [[ $DRY_RUN -eq 1 ]]; then
    run install -m 0644 "$HERE/config/chrony/buendia-ntp.conf" "$cd/buendia-ntp.conf"
  else
    warn "no chrony conf.d directory found — append config/chrony/buendia-ntp.conf to /etc/chrony/chrony.conf by hand"
  fi
  run_sh "systemctl enable --now chrony 2>/dev/null || systemctl enable --now chronyd || true"

  # A server in a clinic with no engineer must not change itself. An unattended apt upgrade can
  # restart Docker or pull in a new kernel with nobody there to notice, and a snap refresh does
  # the same on its own schedule. Both are disabled deliberately; updates become a staffed,
  # deliberate act. Nothing here needs the network, so it also holds on an offline box.
  # A name is easier to type and to tell someone over a radio than four numbers, and the browser
  # will not treat it as a search term as long as the http:// is included. .lan is used as well
  # as .local because .local is formally reserved for mDNS; /etc/hosts wins on Ubuntu either way
  # (nsswitch consults files before mdns), but the extra name costs nothing and avoids an argument.
  log "Host config: name this server 'buendia' in /etc/hosts"
  if [[ $DRY_RUN -eq 0 ]]; then
    sed -i '/[[:space:]]# buendia-pilot$/d' /etc/hosts
    printf '%s\tbuendia buendia.lan buendia.local\t# buendia-pilot\n' "$STATIC_IP" >> /etc/hosts
    echo "  $STATIC_IP -> buendia / buendia.lan / buendia.local"
  else
    echo "  [dry-run] add '$STATIC_IP buendia buendia.lan buendia.local' to /etc/hosts"
  fi

  log "Host config: disable background updates (no unattended change in the field)"
  run_sh "systemctl disable --now unattended-upgrades 2>/dev/null || true"
  run_sh "systemctl disable --now apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true"
  run_sh "systemctl mask apt-daily.service apt-daily-upgrade.service 2>/dev/null || true"
  if command -v snap >/dev/null 2>&1; then
    # Holds refreshes indefinitely (snapd >= 2.58); older snapd just reports an error, hence || true.
    run_sh "snap refresh --hold 2>/dev/null || true"
  fi

  # The router is configured over SSH from THIS box, during the offline step — when apt is not
  # available. So it has to be installed now. Ubuntu Desktop normally ships it; a minimal
  # Server install does not, and discovering that offline leaves the router unconfigurable.
  if [[ "$PHASE" == "prepare" ]]; then
    log "Host config: ssh client (needed offline, to configure the router)"
    ensure_pkg openssh-client
    # Rendering the tablet QR codes on screen at the end of the offline step needs a generator,
    # and apt is not available then. Small package, installed now.
    ensure_pkg qrencode
  fi

  # The server is the LAN time authority but has NO upstream at an offline site: its own clock
  # comes from the hardware RTC. A dead RTC battery means every encounter timestamp is wrong,
  # with no NTP to correct it — so this is a staging check, not something the script can fix.
  if [[ $DRY_RUN -eq 0 ]] && ! hwclock --show >/dev/null 2>&1; then
    warn "cannot read the hardware clock — verify the RTC battery before shipping (timestamps depend on it)."
  fi

  # Graceful shutdown on low battery / UPS: laptop battery via UPower thresholds, or Network
  # UPS Tools for an external UPS. TODO: wire to the chosen power kit (§3.1). MySQL 5.6 killed
  # mid-write is the most plausible way this pilot loses data.
  warn "TODO: configure graceful shutdown on low battery / UPS (§3.1) for the chosen power kit."
}

# Static IP, generated from .env — there is deliberately no checked-in netplan file to drift
# out of sync with STATIC_IP. Set CONFIGURE_NETWORK=false when the site network is managed by
# someone else (e.g. existing site Wi-Fi with a DHCP reservation) and this box must not touch it.
config_network() {
  if [[ "$CONFIGURE_NETWORK" != "true" ]]; then
    log "Host config: network — SKIPPED (CONFIGURE_NETWORK=$CONFIGURE_NETWORK)"
    warn "the server's address is not managed by this script — confirm it is reachable at $STATIC_IP,"
    warn "  because that address is baked into every tablet's APK."
    return 0
  fi

  local iface; iface="$(detect_iface)"
  [[ -n "$iface" ]] || die "could not detect a wired interface. Set NET_IFACE in .env (see: ip -br link)."
  log "Host config: static IP $STATIC_IP/$NET_PREFIX on $iface (netplan)"

  # Wireless interfaces need netplan's `wifis:` block with an access-points stanza; declaring one
  # under `ethernets:` is invalid config that fails at apply time. Autodetect follows the default
  # route, which on a laptop is usually Wi-Fi — so this case is common, not exotic.
  local is_wifi=0
  [[ -d "/sys/class/net/$iface/wireless" || "$iface" == wl* ]] && is_wifi=1
  if [[ $is_wifi -eq 1 && ( -z "${SITE_WIFI_SSID:-}" || -z "${SITE_WIFI_PASSWORD:-}" ) ]]; then
    die "detected interface '$iface' is wireless, and SITE_WIFI_SSID/SITE_WIFI_PASSWORD are not set.
       A server should normally be WIRED into the site network. Either:
         - set NET_IFACE=<wired-interface> in .env  (see: ip -br link), or
         - set SITE_WIFI_SSID + SITE_WIFI_PASSWORD to join that Wi-Fi with a static address, or
         - set CONFIGURE_NETWORK=false if the network is managed elsewhere (then confirm by hand
           that the server answers on $STATIC_IP — every tablet bakes in that address)."
  fi

  local gw="${GATEWAY_IP:-}" dns="${DNS_SERVERS:-}" routes="" nameservers=""
  # An isolated pilot LAN legitimately has no gateway and no DNS; emit those blocks only when
  # configured, because netplan rejects an empty list.
  if [[ -n "$gw" ]]; then
    routes=$'\n      routes:\n        - to: default\n          via: '"$gw"
  else
    warn "no GATEWAY_IP set — configuring an isolated LAN with no default route."
  fi
  [[ -n "$dns" ]] && nameservers=$'\n      nameservers:\n        addresses: ['"$dns"']'

  # Renderer must match what actually manages networking on this box. Ubuntu SERVER uses
  # systemd-networkd; Ubuntu DESKTOP uses NetworkManager, and handing it a `renderer: networkd`
  # file means the config either fails to apply or fights NM for the interface. Autodetect, with
  # NET_RENDERER as an override.
  local renderer="${NET_RENDERER:-}"
  if [[ -z "$renderer" ]]; then
    if systemctl is-active --quiet NetworkManager 2>/dev/null; then
      renderer="NetworkManager"
    else
      renderer="networkd"
    fi
  fi
  echo "  netplan renderer: $renderer"

  local block="ethernets" wifi_ap=""
  if [[ $is_wifi -eq 1 ]]; then
    block="wifis"
    # SINGLE-quoted YAML scalars, with embedded ' doubled. Double quotes would be wrong: in
    # double-quoted YAML a backslash is an escape character, so a passphrase containing '\' (or
    # one ending in a backslash) either changes meaning or makes the file unparseable — and
    # netplan then fails at apply time, on a box that is about to be shipped.
    local ssid_esc="${SITE_WIFI_SSID//\'/\'\'}"
    local pw_esc="${SITE_WIFI_PASSWORD//\'/\'\'}"
    wifi_ap=$'\n      access-points:\n        \''"${ssid_esc}"$'\':\n          password: \''"${pw_esc}"\'
    warn "configuring a STATIC address on Wi-Fi ($iface, SSID $SITE_WIFI_SSID)."
    warn "  Confirm with MSF IT that $STATIC_IP is outside their DHCP pool or reserved for this box,"
    warn "  and that the network does not isolate clients from each other (tablets must reach the server)."
  fi

  local tmp; tmp="$(mktemp)"
  cat > "$tmp" <<YAML
# GENERATED by deploy/setup.sh from deploy/.env — do not edit by hand; edit .env and re-run.
# Keep STATIC_IP identical to the address baked into the tablet APK (-Pserver=...).
network:
  version: 2
  renderer: ${renderer}
  ${block}:
    ${iface}:
      dhcp4: false
      addresses:
        - ${STATIC_IP}/${NET_PREFIX}${routes}${nameservers}${wifi_ap}
YAML
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '  \033[0;36m[dry-run]\033[0m would write /etc/netplan/60-buendia.yaml:\n'
    sed 's/^/      /' "$tmp"
    rm -f "$tmp"; return 0
  fi
  install -m 0600 "$tmp" /etc/netplan/60-buendia.yaml
  rm -f "$tmp"

  # A failed `netplan apply` used to be a warning, and the run still reported success — leaving
  # a server on the wrong address while every tablet had the old one baked in. That is a silent
  # brick, so it is fatal now, and we confirm the address actually landed rather than trusting
  # the exit code.
  netplan apply || die "netplan apply failed for interface '$iface'. Check: ip -br link"
  local i
  for i in $(seq 1 10); do
    ip -4 addr show dev "$iface" 2>/dev/null | grep -qw "$STATIC_IP" && break
    sleep 1
  done
  ip -4 addr show dev "$iface" 2>/dev/null | grep -qw "$STATIC_IP" \
    || die "$iface did not take $STATIC_IP after netplan apply. Tablets bake in this address — fix before shipping."
  ok "  $iface is up at $STATIC_IP"
}

# ---------------------------------------------------------------------------
# 3. Docker + Compose
# ---------------------------------------------------------------------------
install_docker() {
  if command -v docker >/dev/null && docker compose version >/dev/null 2>&1; then
    log "Docker already present: $(docker --version)"
  elif [[ "$MODE" == "offline" ]]; then
    offline_debs_install
    if [[ $DRY_RUN -eq 0 ]]; then
      command -v dockerd >/dev/null \
        || die "offline: Docker is still absent after unpacking debs/. The set is incomplete or
       was built for a different Ubuntu release (check debs/MANIFEST.txt against this box)."
    fi
  else
    log "Installing Docker (online${DOCKER_VERSION:+, pinned $DOCKER_VERSION})"
    apt_refresh
    run apt-get install -y ca-certificates curl gnupg
    run install -m 0755 -d /etc/apt/keyrings
    run_sh "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg"
    run chmod a+r /etc/apt/keyrings/docker.gpg
    . /etc/os-release
    run_sh "echo 'deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable' > /etc/apt/sources.list.d/docker.list"
    APT_REFRESHED=0; apt_refresh    # re-read the index now that the Docker repo is added
    # DOCKER_VERSION was previously accepted in .env and then silently ignored.
    if [[ -n "${DOCKER_VERSION:-}" ]]; then
      run apt-get install -y "docker-ce=$DOCKER_VERSION" "docker-ce-cli=$DOCKER_VERSION" \
        containerd.io docker-compose-plugin
    else
      run apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    fi
  fi

  log "Docker: log rotation caps (§3.1) + start on boot"
  run install -d /etc/docker
  # Only restart the daemon when the config actually changed: an unconditional restart on every
  # idempotent re-run bounces a healthy stack for no reason.
  if [[ $DRY_RUN -eq 0 ]] && cmp -s "$HERE/config/docker/daemon.json" /etc/docker/daemon.json; then
    echo "  /etc/docker/daemon.json already current — not restarting the daemon"
    run systemctl enable --now docker
  else
    run install -m 0644 "$HERE/config/docker/daemon.json" /etc/docker/daemon.json
    run systemctl enable --now docker
    run systemctl restart docker
  fi
}

# ---------------------------------------------------------------------------
# 4. Container images
# ---------------------------------------------------------------------------
load_images() {
  if [[ "$MODE" == "offline" ]]; then
    # An earlier --prepare already pulled these, so they are in the local image store and no
    # tarballs need to travel. Check before demanding files: requiring images/*.tar here is what
    # made a two-step install impossible without carrying ~770 MB that was already on the disk.
    if [[ $DRY_RUN -eq 1 ]]; then
      log "Images: would use the local store if populated, else images/*.tar (offline)"
    elif docker image inspect "$DB_IMAGE" >/dev/null 2>&1 \
       && docker image inspect "$OPENMRS_IMAGE" >/dev/null 2>&1; then
      log "Images already in the local store (pulled by --prepare) — nothing to load"
    else
      log "Loading container images from images/*.tar (offline)"
      ls "$HERE"/images/*.tar >/dev/null 2>&1 \
        || die "the images are not in the local store and there are no tarballs in images/.
       Either run 'sudo ./setup.sh --prepare' while connected to the internet, or produce the
       tarballs on the build box with tools/bundle-images.sh."
      local t
      for t in "$HERE"/images/*.tar; do run docker load -i "$t"; done
    fi
  else
    log "Pulling container images from the registry (online)"
    # Public images need no credentials; support a token for a private repo anyway.
    if [[ -n "${REGISTRY_USER:-}" && -n "${REGISTRY_TOKEN:-}" ]]; then
      run_sh "printf '%s' \"\$REGISTRY_TOKEN\" | docker login -u \"\$REGISTRY_USER\" --password-stdin ${REGISTRY_HOST:-docker.io}"
    fi
    run docker pull "$DB_IMAGE"
    run docker pull "$OPENMRS_IMAGE"
    # compose falls back to nginx:alpine-slim when PKGSERVER_IMAGE is empty, which is the default.
    # It was never pulled here, so the OFFLINE step went looking for it and needed the internet
    # back — exactly what splitting the install was meant to avoid. Pull it while we can.
    if [[ -z "${PKGSERVER_IMAGE:-}" ]]; then
      run docker pull nginx:alpine-slim
    fi
    # NB an `[[ test ]] && cmd` as the last statement of a function returns 1 when the test is
    # false, which under `set -e` aborts the whole run — silently, right before the stack starts.
    # PKGSERVER_IMAGE is empty by default (compose falls back to nginx:alpine-slim), so that was
    # the DEFAULT path. Keep this an if-statement.
    if [[ -n "${PKGSERVER_IMAGE:-}" ]]; then
      run docker pull "$PKGSERVER_IMAGE"
    else
      echo "  PKGSERVER_IMAGE unset — compose will use nginx:alpine-slim with the bind-mounted pkgserver/www"
    fi
  fi
}

# ---------------------------------------------------------------------------
# 4b. Fetch the tablet package-server payload from a PRIVATE release
# ---------------------------------------------------------------------------
# WHY THIS IS PRIVATE, unlike the container images: the payload contains the APK, and the APK
# carries the server password as a plain Android string resource (`openmrs_password_default` —
# extractable with one `aapt dump --values resources`). So the APK *is* a credential and must not
# sit in a public namespace. The db/openmrs images hold no secrets and stay public, which is why
# there is no registry login for them.
#
# The unit is the whole generated `www/` (APK + update index + Release stub + QR + landing page),
# because all of it is SITE-SPECIFIC: the index, landing page and QR embed the server address. That
# also means the target needs no python/QR tooling — it just unpacks what we generated at release.
#
# The token is read from the ENVIRONMENT ONLY and never written to .env or the log:
#   curl -fsSLO <url>/setup.sh && GITHUB_TOKEN=ghp_xxx sudo -E bash setup.sh
# It is needed only during setup; afterwards it has no use on this box.
fetch_apk() {
  local src="${APK_SOURCE:-auto}"
  local token="${GITHUB_TOKEN:-${TOKEN:-}}"

  shopt -s nullglob
  local have=("$HERE"/pkgserver/www/*.apk)
  shopt -u nullglob

  case "$src" in
    none)  log "APK fetch: skipped (APK_SOURCE=none)"; return 0 ;;
    local) log "APK fetch: using pkgserver/www as-is (APK_SOURCE=local)"; return 0 ;;
    auto)
      # Already populated (a re-run, or an offline USB install) — never re-download.
      if [[ ${#have[@]} -gt 0 ]]; then
        log "APK fetch: pkgserver/www already holds $(basename "${have[0]}") — nothing to download"
        return 0
      fi
      if [[ -z "${APK_RELEASE_REPO:-}" || -z "$token" ]]; then
        log "APK fetch: nothing to do (no APK present, and no APK_RELEASE_REPO + token given)"
        return 0
      fi
      ;;
    github) : ;;
    *) die "unknown APK_SOURCE: $src (expected auto|github|local|none)" ;;
  esac

  : "${APK_RELEASE_REPO:?set APK_RELEASE_REPO (owner/repo) to fetch the APK payload}"
  : "${APK_RELEASE_TAG:?set APK_RELEASE_TAG (the release tag holding the asset)}"
  local asset="${APK_RELEASE_ASSET:-pkgserver-www.tar.gz}"
  [[ -n "$token" ]] || die "no token: pass GITHUB_TOKEN=... in the environment (it is never stored in .env)."

  log "APK fetch: $asset from $APK_RELEASE_REPO @ $APK_RELEASE_TAG (private release)"
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '  \033[0;36m[dry-run]\033[0m would download %s with the supplied token (redacted)\n' "$asset"
    return 0
  fi
  command -v python3 >/dev/null || die "python3 is required to parse the GitHub release metadata."

  local api="https://api.github.com/repos/$APK_RELEASE_REPO/releases/tags/$APK_RELEASE_TAG"
  local meta id
  meta="$(curl -fsSL -H "Authorization: Bearer $token" \
            -H "Accept: application/vnd.github+json" "$api")" \
    || die "could not read release $APK_RELEASE_TAG from $APK_RELEASE_REPO (token wrong, or no access?)"
  id="$(printf '%s' "$meta" | python3 -c '
import json,sys
rel = json.load(sys.stdin)
name = sys.argv[1]
for a in rel.get("assets", []):
    if a["name"] == name:
        print(a["id"]); break
' "$asset")"
  [[ -n "$id" ]] || die "release $APK_RELEASE_TAG has no asset named '$asset'."

  local tmp; tmp="$(mktemp -d)"
  # Asset download needs the octet-stream Accept header, otherwise the API returns JSON metadata.
  curl -fsSL -H "Authorization: Bearer $token" -H "Accept: application/octet-stream" \
    -o "$tmp/$asset" "https://api.github.com/repos/$APK_RELEASE_REPO/releases/assets/$id" \
    || { rm -rf "$tmp"; die "download of $asset failed."; }

  # Verify against a sibling .sha256 asset when the release provides one.
  local sid
  sid="$(printf '%s' "$meta" | python3 -c '
import json,sys
rel = json.load(sys.stdin)
name = sys.argv[1] + ".sha256"
for a in rel.get("assets", []):
    if a["name"] == name:
        print(a["id"]); break
' "$asset")"
  if [[ -n "$sid" ]]; then
    curl -fsSL -H "Authorization: Bearer $token" -H "Accept: application/octet-stream" \
      -o "$tmp/$asset.sha256" "https://api.github.com/repos/$APK_RELEASE_REPO/releases/assets/$sid" || true
    if [[ -s "$tmp/$asset.sha256" ]]; then
      local want got
      want="$(awk '{print $1}' "$tmp/$asset.sha256")"
      got="$(sha256sum "$tmp/$asset" | cut -d' ' -f1)"
      [[ "$want" == "$got" ]] || { rm -rf "$tmp"; die "checksum mismatch on $asset (want $want, got $got)."; }
      echo "  checksum OK (${got:0:12})"
    fi
  else
    warn "release provides no $asset.sha256 — payload not checksum-verified."
  fi

  install -d "$HERE/pkgserver/www"
  tar xzf "$tmp/$asset" -C "$HERE/pkgserver/www" --strip-components=0 \
    || { rm -rf "$tmp"; die "could not unpack $asset."; }
  rm -rf "$tmp"
  shopt -s nullglob; local got=("$HERE"/pkgserver/www/*.apk); shopt -u nullglob
  [[ ${#got[@]} -gt 0 ]] || die "$asset unpacked but contains no .apk — was it built by pkgserver/publish.sh?"
  ok "  installed $(basename "${got[0]}") into pkgserver/www"
}

# ---------------------------------------------------------------------------
# 5. Bring up the stack
# ---------------------------------------------------------------------------
bring_up() {
  log "Seed check"
  # The baseline seed lives INSIDE the DB image (seed/build-db-image.sh stamps a label).
  # A bare mysql image here means a schema-less, concept-less DB: OpenMRS will appear to boot
  # and nothing will work. Previously this check looked in seed/*.sql — the wrong directory —
  # so it always warned and told the operator nothing.
  # Read-only, so it runs in --dry-run too: this is the single most consequential misconfiguration
  # the installer can catch, and a dry run should catch it.
  if ! command -v docker >/dev/null 2>&1; then
    :   # Docker not installed yet (a dry run on a bare machine) — nothing to inspect.
  elif ! docker image inspect "$DB_IMAGE" >/dev/null 2>&1; then
    # Not pulled yet. In a real run load_images() has already pulled it, so this means the pull
    # failed; in a dry run the pull was only printed, so absence is expected.
    if [[ $DRY_RUN -eq 1 ]]; then
      echo "  (dry run: $DB_IMAGE not present locally — cannot check for the baked seed yet)"
    else
      die "$DB_IMAGE is not present locally after the image step — the pull must have failed."
    fi
  else
    local seed_label
    seed_label="$(docker image inspect --format \
      '{{index .Config.Labels "org.projectbuendia.seed.sha256"}}' "$DB_IMAGE" 2>/dev/null || true)"
    if [[ -n "$seed_label" && "$seed_label" != "<no value>" ]]; then
      echo "  baseline seed baked into $DB_IMAGE (sha256 ${seed_label:0:12})"
    elif [[ "$ALLOW_UNSEEDED_DB" == "true" ]]; then
      warn "$DB_IMAGE carries no baked seed, continuing because ALLOW_UNSEEDED_DB=true."
    else
      die "$DB_IMAGE carries no baked baseline seed — the database would come up empty and unusable.
       Build it:  cd seed && ./build-seed.sh && ./build-db-image.sh   then set DB_IMAGE in .env.
       (Override with ALLOW_UNSEEDED_DB=true only if you know the volume is already seeded.)"
    fi
  fi
  echo "  site seed: seed/initdb/20-buendia-site.sql ($(wc -c < "$HERE/seed/initdb/20-buendia-site.sql" | tr -d ' ') bytes)"

  fetch_apk

  log "APK publish check"
  # The pkgserver container starts regardless, but with an empty document root there is nothing
  # for a tablet to install and the client's :9001 health check would 404.
  ls "$HERE"/pkgserver/www/*.apk >/dev/null 2>&1 \
    || warn "pkgserver/www/ has no .apk — tablets can't install over the LAN. Run: pkgserver/publish.sh"

  log "Starting the stack (docker compose up -d)"
  run_sh "cd '$HERE/compose' && docker compose --env-file '$HERE/.env' up -d"
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
    run_sh "curl -fsSL https://tailscale.com/install.sh | sh"
  fi
  if [[ "$ENABLE_REMOTE_SUPPORT" == "true" ]]; then
    : "${TAILSCALE_AUTHKEY:?set TAILSCALE_AUTHKEY in .env to enable remote support}"
    run tailscale up --ssh --hostname "buendia-${SITE_ID:-pilot}" --authkey "$TAILSCALE_AUTHKEY"
  else
    echo "  To enable later: set ENABLE_REMOTE_SUPPORT=true + TAILSCALE_AUTHKEY in .env, re-run,"
    echo "  or run: tailscale up --ssh --hostname buendia-${SITE_ID:-pilot}"
  fi
}

# ---------------------------------------------------------------------------
# 7. Wait for the stack, then prove it is USABLE (not merely listening)
# ---------------------------------------------------------------------------
wait_for_rest() {
  log "Waiting for the OpenMRS REST API on :${OPENMRS_PORT:-9000}"
  # /ws/rest/v1/session returns 200 without auth once the platform + REST framework are up.
  # (The buendia resources require auth and would 401 here — don't use them for liveness.)
  local url="http://localhost:${OPENMRS_PORT:-9000}/openmrs/ws/rest/v1/session" i
  for i in $(seq 1 90); do
    if curl -fsS -o /dev/null "$url" 2>/dev/null; then
      ok "OpenMRS REST is up ($url)"; return 0
    fi
    sleep 5
  done
  warn "REST API not reachable after ~7 min. Check: docker compose -f compose/docker-compose.yml logs"
  return 1
}

verify() {
  # health_check() used to end the run here, having proved only that the ports answer. That is
  # not the same as usable: it passes on a stack that can't authenticate, has no locations, or
  # has the duplicate-login row that locked a tablet out mid-test. buendia-verify.sh checks the
  # things a clinician's tablet actually depends on, so the installer's exit code now means it.
  log "Go/no-go verification (tools/buendia-verify.sh)"
  "$HERE/tools/buendia-verify.sh" --port "${OPENMRS_PORT:-9000}" --pkg-port "${PKGSERVER_PORT:-9001}"
}

# ---------------------------------------------------------------------------
summary() {
  local result="$1"
  log "Summary"
  cat <<TXT
  host        : $(hostname) ($(uname -m)), $(. /etc/os-release; echo "${PRETTY_NAME:-?}")
  timezone    : $TZ   clock: $(date -Is 2>/dev/null || date)
  db image    : $DB_IMAGE
  openmrs     : $OPENMRS_IMAGE
  result      : $result
TXT
  # Only advertise the URLs once something is actually serving them. After --prepare nothing is
  # running and the address has not been applied, so printing them invites the operator to test
  # a server that cannot answer, and to read the failure as a fault.
  if [[ "$PHASE" != "prepare" ]]; then
    cat <<TXT
  address     : $STATIC_IP  (baked into the tablet APK — must match)
  web         : http://$STATIC_IP:${OPENMRS_PORT:-9000}/openmrs
  apk install : http://$STATIC_IP:${PKGSERVER_PORT:-9001}/latest.apk
TXT
  fi
  # A per-device staging record, so "which box is this and did it pass" survives the day.
  [[ $DRY_RUN -eq 1 ]] || {
    printf '%s  %s  %s  db=%s  openmrs=%s  result=%s\n' \
      "$(date -Is)" "$(hostname)" "$STATIC_IP" "$DB_IMAGE" "$OPENMRS_IMAGE" "$result" \
      >> /var/log/buendia-setup.log 2>/dev/null || true
  }
}

# Run the network check, and let it repair what it can, before anything depends on the link.
# It also writes NET_IFACE into .env, which is the value config_network would otherwise have to
# guess — and guessing picks Wi-Fi on a laptop and emits an unvalidated netplan wifis: block.
network_precheck() {
  local nc="$HERE/tools/buendia-netcheck.sh"
  [[ -x "$nc" ]] || return 0
  log "Checking the connection to the router"
  if [[ $DRY_RUN -eq 1 ]]; then ( cd "$HERE" && "$nc" ) || true; return 0; fi
  ( cd "$HERE" && "$nc" --write ) \
    || die "the network is not ready — see the report above, fix it, then run this again."
  local v
  v="$(awk -F= '/^NET_IFACE=/{sub(/#.*/,"",$2); gsub(/[ \t]/,"",$2); print $2; exit}' "$HERE/.env" 2>/dev/null || true)"
  [[ -n "$v" ]] && { NET_IFACE="$v"; echo "  using NET_IFACE=$NET_IFACE"; }
}

# The router is part of the deployment, not a separate errand, so the offline step configures it.
configure_router() {
  local n="$HERE/network"
  [[ -x "$n/configure-router.sh" ]] || { warn "router scripts are not present — skipping the router"; return 0; }
  if [[ $DRY_RUN -eq 1 ]]; then log "Router: would install the key, configure, verify and back up"; return 0; fi
  log "Router: giving this server access (asks for the router's admin password once)"
  "$n/router-access.sh" || die "could not reach the router over SSH — see above."
  log "Router: applying the Buendia configuration"
  "$n/configure-router.sh" || die "the router configuration failed — see above."
  log "Router: verifying"
  if ! "$n/verify-router.sh"; then
    warn "the router did not verify. Services can still be starting for a minute after a change:"
    warn "  wait a minute, then run:  sudo $HERE/network/verify-router.sh"
  fi
  log "Router: saving a configuration backup"
  "$n/backup-router.sh" || warn "could not save the router backup (not fatal)"
}

# Both QR codes on screen at the end, so a tablet is provisioned without typing anything.
wifi_uri() {
  local e_ssid e_pass
  e_ssid="$(printf '%s' "${SITE_WIFI_SSID:-}" | sed 's/[\\;,:"]/\\&/g')"
  e_pass="$(printf '%s' "${SITE_WIFI_PASSWORD:-}" | sed 's/[\\;,:"]/\\&/g')"
  printf 'WIFI:T:WPA;S:%s;P:%s;;' "$e_ssid" "$e_pass"
}
# Run a command as the user who typed sudo, inside THEIR graphical session.
# Guessing DISPLAY=:0 is wrong on a second seat (this laptop is :1) and meaningless on Wayland,
# and without DBUS_SESSION_BUS_ADDRESS xdg-open exits silently having done nothing. So the
# session environment is read out of one of the user's own running processes instead of guessed.
# Who owns the desktop? SUDO_USER is the obvious answer and is often absent: `sudo su -` starts
# a LOGIN shell, which clears it, and a plain root console never had it. So fall back to asking
# logind who is actually logged in.
target_user() {
  local u="${SUDO_USER:-}"
  if [[ -n "$u" && "$u" != root ]]; then echo "$u"; return 0; fi
  u="$(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $3}' | grep -vx root | head -1)"
  if [[ -n "$u" ]]; then echo "$u"; return 0; fi
  u="$(ps -o user= -C gnome-shell 2>/dev/null | grep -vx root | head -1)"
  if [[ -n "$u" ]]; then echo "$u"; return 0; fi
  return 1
}

# Put the codes somewhere a person can find them without a terminal. This matters more than the
# viewer working: a file on the Desktop is findable by anyone, whereas /opt/buendia/qr is not.
publish_qr_to_desktop() {
  local u d src dest
  u="$(target_user)" || return 1
  local home; home="$(getent passwd "$u" | cut -d: -f6)"
  [[ -n "$home" && -d "$home" ]] || return 1
  for d in "$home/Desktop" "$home/Pictures" "$home"; do [[ -d "$d" ]] && break; done
  dest="$d/Buendia-tablet-setup"; mkdir -p "$dest" || return 1
  for src in "$@"; do [[ -f "$src" ]] && cp -f "$src" "$dest/"; done
  # A clickable link to the records system, so nobody has to remember an address or the /openmrs
  # that the bare port silently needs.
  cat > "$dest/Buendia records.desktop" <<DESK
[Desktop Entry]
Type=Link
Name=Buendia — patient records
Comment=Opens the Buendia records system in a browser
URL=http://buendia.lan:${OPENMRS_PORT:-9000}/openmrs
Icon=applications-internet
DESK
  chmod 0755 "$dest/Buendia records.desktop"
  chown -R "$u":"$(id -gn "$u")" "$dest" 2>/dev/null || true
  run_as_user gio set -t string "$dest/Buendia records.desktop" metadata::trusted true 2>/dev/null || true
  echo "$dest"
}

run_as_user() {
  local u uid gid pid k
  local -a envv=()
  u="$(target_user)" || return 1
  uid="$(id -u "$u" 2>/dev/null)" || return 1
  gid="$(id -g "$u" 2>/dev/null)" || return 1
  pid="$(pgrep -u "$uid" -x systemd 2>/dev/null | head -1)"
  [[ -n "$pid" ]] || pid="$(pgrep -u "$uid" -x gnome-shell 2>/dev/null | head -1)"
  [[ -n "$pid" ]] || pid="$(pgrep -u "$uid" -x gnome-session-binary 2>/dev/null | head -1)"
  if [[ -n "$pid" && -r "/proc/$pid/environ" ]]; then
    while IFS= read -r -d '' k; do
      case "$k" in
        DISPLAY=*|WAYLAND_DISPLAY=*|XAUTHORITY=*|XDG_RUNTIME_DIR=*|\
DBUS_SESSION_BUS_ADDRESS=*|XDG_SESSION_TYPE=*|XDG_CURRENT_DESKTOP=*) envv+=("$k") ;;
      esac
    done < "/proc/$pid/environ"
  fi
  [[ ${#envv[@]} -gt 0 ]] || envv=("XDG_RUNTIME_DIR=/run/user/$uid" "DISPLAY=${DISPLAY:-:0}")
  sudo -u "$u" env "${envv[@]}" "$@" >/dev/null 2>&1 &
  return 0
}

# Open a URL or an HTML page in a real BROWSER. Not xdg-open first: it honours the desktop's
# text/html association, which on the test laptop was a text editor — so the router's admin page
# and the install card both opened as source code. Browsers are tried by name first, and a local
# file is handed over as a file:// URL so the browser treats it as a page, not an argument.
open_url() {
  local target="$1" b
  [[ "$target" == /* ]] && target="file://$target"
  for b in x-www-browser sensible-browser firefox google-chrome chromium chromium-browser epiphany; do
    command -v "$b" >/dev/null 2>&1 || continue
    run_as_user "$b" "$target" && return 0
  done
  command -v xdg-open >/dev/null 2>&1 && { run_as_user xdg-open "$target" && return 0; }
  return 1
}

# Images go to an image viewer; here xdg-open is the right first choice.
open_image() {
  local target="$1" v
  for v in xdg-open eog gwenview gthumb feh; do
    command -v "$v" >/dev/null 2>&1 || continue
    run_as_user "$v" "$target" && return 0
  done
  return 1
}

wait_for() {            # wait_for <seconds> <description> <command...>
  local secs="$1" what="$2"; shift 2
  local i=0
  printf '  waiting for %s' "$what"
  while (( i < secs )); do
    if "$@" >/dev/null 2>&1; then printf ' — ok (%ds)\n' "$i"; return 0; fi
    printf '.'; sleep 3; i=$(( i + 3 ))
  done
  printf ' — gave up after %ds\n' "$secs"; return 1
}
tcp_open() { timeout 3 bash -c "exec 3<>/dev/tcp/$1/$2" 2>/dev/null; }

# The router is part of the deployment, not a separate errand, so the offline step configures it.
configure_router() {
  local n="$HERE/network" r="${ROUTER_IP:-192.168.8.1}"
  [[ -x "$n/configure-router.sh" ]] || { warn "router scripts are not present — skipping the router"; return 0; }
  if [[ $DRY_RUN -eq 1 ]]; then log "Router: would wait for it, run the wizard, configure, verify and back up"; return 0; fi

  log "Router: waiting for it to answer at $r"
  # A router that was just powered on, or just factory-reset, takes a while. Waiting is not
  # optional politeness: every previous failure here was the script arriving before the router.
  wait_for 180 "the router to respond" ping -c1 -W2 "$r" \
    || die "the router at $r never answered.
       Check it has power and its lights have settled, and that the cable is in a LAN port."

  # SSH closed means the first-boot wizard has not been done. That is a human step, so open it
  # in a browser and wait, rather than failing and making the operator find the URL themselves.
  if ! tcp_open "$r" 22; then
    log "Router: it needs its setup wizard run once — opening it in a browser"
    if open_url "http://$r/"; then
      echo "  A browser window should have opened at http://$r/"
    else
      echo "  Open this address in a browser:  http://$r/"
    fi
    cat <<TXT

  In that page:
    - complete the router's short setup wizard
    - set an ADMIN PASSWORD and keep it — you are asked for it in a moment
    - ignore its Wi-Fi settings; Buendia sets those itself

TXT
    read -r -p "  Press Enter here once the wizard is finished... " _ </dev/tty || true
    wait_for 120 "the router to allow SSH" tcp_open "$r" 22 \
      || die "the router still refuses SSH on $r:22.
       That means the setup wizard has not completed. Finish it, then run this command again."
  fi

  log "Router: giving this server access (asks for the router's admin password once)"
  "$n/router-access.sh" || die "could not reach the router over SSH — see above."
  log "Router: applying the Buendia configuration"
  "$n/configure-router.sh" || die "the router configuration failed — see above."
  log "Router: verifying"
  if ! "$n/verify-router.sh"; then
    warn "the router did not verify. Services can still be restarting for a minute after a change:"
    warn "  wait a minute, then run:  sudo $HERE/network/verify-router.sh"
  fi
  log "Router: saving a configuration backup"
  "$n/backup-router.sh" || warn "could not save the router backup (not fatal)"
}

# Both codes as PNGs plus the printable card, shown on screen. Terminal QR codes were tried
# first and tablets could not read them: the block glyphs are low-contrast and too small.
wifi_uri() {
  local e_ssid e_pass
  e_ssid="$(printf '%s' "${SITE_WIFI_SSID:-}" | sed 's/[\;,:"]/\\&/g')"
  e_pass="$(printf '%s' "${SITE_WIFI_PASSWORD:-}" | sed 's/[\;,:"]/\\&/g')"
  printf 'WIFI:T:WPA;S:%s;P:%s;;' "$e_ssid" "$e_pass"
}
show_tablet_qr() {
  local qrdir="$HERE/qr" card="$HERE/pkgserver/cards/install-card.html"
  local wifi_png="$qrdir/1-join-wifi.png" app_png="$qrdir/2-install-app.png"
  local app_url="http://$STATIC_IP:${PKGSERVER_PORT:-9001}/latest.apk"
  mkdir -p "$qrdir"; chmod 755 "$qrdir"

  if ! command -v qrencode >/dev/null 2>&1; then
    echo "  qrencode is not installed, so no codes could be drawn."
    echo "  On the tablet, open http://$STATIC_IP:${PKGSERVER_PORT:-9001}/ in the browser instead."
    return 0
  fi
  [[ -n "${SITE_WIFI_SSID:-}" ]] && qrencode -o "$wifi_png" -s 10 -m 3 "$(wifi_uri)"
  qrencode -o "$app_png" -s 10 -m 3 "$app_url"
  chmod 644 "$qrdir"/*.png 2>/dev/null || true
  ( cd "$HERE/pkgserver" && ./make-install-card.sh >/dev/null 2>&1 ) || card=""

  local pub; pub="$(publish_qr_to_desktop "$wifi_png" "$app_png" ${card:+"$card"} 2>/dev/null || true)"

  echo
  if [[ -n "$pub" ]]; then
    printf '  [1mThe codes have been copied to: %s[0m
' "$pub"
    echo "  Open that folder from the desktop if the windows below do not appear."
    echo
  fi
  if [[ -n "$card" && -f "$card" ]] && open_url "$card"; then
    echo "  A page with both codes should now be open in the browser."
  elif open_image "$wifi_png"; then
    echo "  An image viewer should now be open."
  else
    echo "  Nothing could be opened automatically — open these files from the Files application:"
  fi
  echo
  [[ -f "$wifi_png" ]] && echo "    1. JOIN THE WI-FI (${SITE_WIFI_SSID:-}):  $wifi_png"
  echo "    2. INSTALL THE APP:                $app_png"
  [[ -n "$card" && -f "$card" ]] && echo "    printable card (both codes): $card"
  cat <<TXT

  On the tablet: scan 1, then scan 2, then open the app and log in as buendia.
  Scan ONE CODE AT A TIME — cover the other with your hand, or a scanner may read the wrong
  one and there is no way to tell which it took.
  If the camera will not scan at all, open http://$STATIC_IP:${PKGSERVER_PORT:-9001}/ in the
  tablet's browser instead.

  To show these again later:  xdg-open $qrdir
TXT
}

main() {
  preflight
  [[ "$PHASE" == "install" ]] && network_precheck
  host_config
  install_docker
  load_images

  if [[ "$PHASE" == "prepare" ]]; then
    log "PREPARE complete — Docker, chrony and the container images are on this box."
    echo "  Nothing was started and no network setting was changed."
    echo
    echo "  Next: disconnect from the internet, cable this box to the Buendia router, then:"
    echo "      sudo ./buendia-netcheck.sh --write     # confirm the link, set NET_IFACE"
    echo "      sudo ./setup.sh --finish               # static address, stack, go/no-go"
    summary "PREPARE OK — not yet a working server"
    return 0
  fi

  [[ "$PHASE" == "install" ]] && configure_router

  bring_up
  remote_support

  if [[ $DRY_RUN -eq 1 ]]; then
    summary "DRY RUN — nothing changed"
    log "Dry run complete."
    return 0
  fi

  local rc=0
  wait_for_rest || rc=1

  # The seed ships a working account, but with a salt that is committed to the repository — so
  # every deployment would otherwise share a publicly-known salt. Rotating it here also applies
  # whatever password prepare.sh was given, and keeps the value the tablets carry authoritative.
  if [[ $rc -eq 0 && $DRY_RUN -eq 0 && "$PHASE" != "prepare" && -x "$HERE/tools/create-openmrs-user.sh" ]]; then
    log "Clinical login: setting the '''${APK_OPENMRS_USER:-buendia}''' password with a fresh salt"
    "$HERE/tools/create-openmrs-user.sh" "${APK_OPENMRS_USER:-buendia}" "${APK_OPENMRS_PASSWORD:-buendia}" \
      >/dev/null 2>&1 && echo "  ok" \
      || warn "could not set the clinical password — the seeded default is still in place."
  fi
  if [[ $DO_VERIFY -eq 1 && $rc -eq 0 ]]; then
    verify || rc=1
  elif [[ $DO_VERIFY -eq 0 ]]; then
    warn "verification skipped (--skip-verify) — this run does NOT prove the stack is usable."
  fi

  if [[ $rc -eq 0 ]]; then
    summary "GO"
    log "The server is ready"
    cat <<TXT
  Buendia (on this machine, or any browser on the Buendia Wi-Fi):
      http://$STATIC_IP:${OPENMRS_PORT:-9000}/openmrs
      username buendia
  NB the address needs the /openmrs on the end — without it the page is blank.

  Now set up a tablet with the two codes below.
TXT
    show_tablet_qr
  else
    summary "NO-GO"
    printf '\033[1;31m==> SETUP DID NOT PASS. Do not ship this box until the checks above pass.\033[0m\n' >&2
  fi
  return $rc
}
main
