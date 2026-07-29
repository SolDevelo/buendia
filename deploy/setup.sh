#!/usr/bin/env bash
#
# Buendia field-pilot server setup.
#
# Turns a fresh Ubuntu Server LTS install into a configured, offline-capable
# Buendia server. Idempotent: safe to re-run.
#
#   sudo ./setup.sh              # --online (default): pull images from Docker Hub
#   sudo ./setup.sh --offline    # no internet: load images from bundled images/*.tar
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
MODE="online"
DRY_RUN=0
DO_VERIFY=1
for arg in "$@"; do
  case "$arg" in
    --online)      MODE="online"  ;;
    --offline)     MODE="offline" ;;
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

ensure_pkg() {
  command -v "$1" >/dev/null && return 0
  if [[ "$MODE" == "offline" ]]; then
    warn "offline: cannot apt-get $1 — ensure it is preinstalled"; return 0
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

  config_network

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
    log "Installing Docker from bundled debs/ (offline)"
    ls "$HERE"/debs/*.deb >/dev/null 2>&1 || die "no .deb files in debs/ for offline install."
    run_sh "dpkg -i $HERE/debs/*.deb || apt-get -f install -y"
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
    log "Loading container images from images/*.tar (offline)"
    ls "$HERE"/images/*.tar >/dev/null 2>&1 \
      || die "no image tarballs in images/ for offline load. Produce them with tools/bundle-images.sh (needs internet)."
    local t
    for t in "$HERE"/images/*.tar; do run docker load -i "$t"; done
  else
    log "Pulling container images from the registry (online)"
    # Public images need no credentials; support a token for a private repo anyway.
    if [[ -n "${REGISTRY_USER:-}" && -n "${REGISTRY_TOKEN:-}" ]]; then
      run_sh "printf '%s' \"\$REGISTRY_TOKEN\" | docker login -u \"\$REGISTRY_USER\" --password-stdin ${REGISTRY_HOST:-docker.io}"
    fi
    run docker pull "$DB_IMAGE"
    run docker pull "$OPENMRS_IMAGE"
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
  address     : $STATIC_IP  (baked into the tablet APK — must match)
  timezone    : $TZ   clock: $(date -Is 2>/dev/null || date)
  db image    : $DB_IMAGE
  openmrs     : $OPENMRS_IMAGE
  web         : http://$STATIC_IP:${OPENMRS_PORT:-9000}/openmrs
  apk install : http://$STATIC_IP:${PKGSERVER_PORT:-9001}/latest.apk
  result      : $result
TXT
  # A per-device staging record, so "which box is this and did it pass" survives the day.
  [[ $DRY_RUN -eq 1 ]] || {
    printf '%s  %s  %s  db=%s  openmrs=%s  result=%s\n' \
      "$(date -Is)" "$(hostname)" "$STATIC_IP" "$DB_IMAGE" "$OPENMRS_IMAGE" "$result" \
      >> /var/log/buendia-setup.log 2>/dev/null || true
  }
}

main() {
  preflight
  host_config
  install_docker
  load_images
  bring_up
  remote_support

  if [[ $DRY_RUN -eq 1 ]]; then
    summary "DRY RUN — nothing changed"
    log "Dry run complete."
    return 0
  fi

  local rc=0
  wait_for_rest || rc=1
  if [[ $DO_VERIFY -eq 1 && $rc -eq 0 ]]; then
    verify || rc=1
  elif [[ $DO_VERIFY -eq 0 ]]; then
    warn "verification skipped (--skip-verify) — this run does NOT prove the stack is usable."
  fi

  if [[ $rc -eq 0 ]]; then
    summary "GO"
    log "Done. Next (manual, see STAGING-SETUP-GUIDE): tablet APK install, clock + PIN, acceptance test."
  else
    summary "NO-GO"
    printf '\033[1;31m==> SETUP DID NOT PASS. Do not ship this box until the checks above pass.\033[0m\n' >&2
  fi
  return $rc
}
main
