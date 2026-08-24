#!/usr/bin/env bash
# Produce the .deb set that `setup.sh --offline` installs, so a server can be built with NO
# internet at any point. The companion to bundle-images.sh: that one carries the containers,
# this one carries Docker itself plus chrony.
#
#   ./bundle-debs.sh --release resolute        # Ubuntu 26.04
#   ./bundle-debs.sh --release noble           # Ubuntu 24.04
#   ./bundle-debs.sh --release resolute --dry-run
#
# WHY A CONTAINER: the packages must match the TARGET's Ubuntu release exactly, and the build
# box is usually a different one (this repo's box is jammy; the pilot laptop is resolute). So
# the download runs inside a container of the target release, which is also what makes the set
# reproducible rather than dependent on whoever ran it.
#
# WHY IT DOWNLOADS MORE THAN THE TARGET NEEDS: a minimal container has fewer packages installed
# than a desktop install, so apt resolves a LARGER dependency closure. That is the safe
# direction — a superset installs fine, a subset dies half way through an install on a box with
# no network. Do not "optimise" it by pruning against the build box's package list.
#
# chrony is in the set deliberately. It is the LAN time authority: the DNS clock intercept
# resolves the tablets' NTP hostnames to this server, so a server without chrony answers
# nothing and every tablet clock drifts, silently.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$HERE/../debs"
RELEASE=""; DRY=0
PKGS="docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-buildx-plugin chrony"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release) RELEASE="${2:-}"; shift 2 ;;
    --out)     OUT="${2:-}"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $1 (try --help)" >&2; exit 2 ;;
  esac
done

log()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

[[ -n "$RELEASE" ]] || die "--release is required (the TARGET server's Ubuntu codename, e.g. resolute
       for 26.04, noble for 24.04). Read it on the target: . /etc/os-release; echo \$VERSION_CODENAME
       A mismatch here produces a set that fails half way through an install on a box with no network."
command -v docker >/dev/null || die "docker is required on THIS box to build the set."

# Fail early and clearly if Docker does not publish this suite, rather than after a long pull.
log "Checking Docker publishes a '$RELEASE' suite"
if ! curl -fsS --max-time 20 "https://download.docker.com/linux/ubuntu/dists/$RELEASE/Release" >/dev/null 2>&1; then
  die "Docker has no '$RELEASE' suite at download.docker.com. A brand-new Ubuntu release often
       lags. Either wait for it, or build the set from Ubuntu's own archive instead (docker.io +
       docker-compose-v2) — a different Docker from the one validated online."
fi
echo "    ok: download.docker.com/linux/ubuntu/dists/$RELEASE exists"

if [[ $DRY -eq 1 ]]; then
  log "DRY RUN — would download into $OUT, for Ubuntu '$RELEASE':"
  echo "    $PKGS"
  exit 0
fi

mkdir -p "$OUT"
log "Downloading the .deb closure for Ubuntu '$RELEASE' (inside ubuntu:$RELEASE)"
# --download-only puts the whole resolved closure in the apt cache. `docker-ce` pulls in
# containerd, iptables and friends; on a minimal container that is a long list, by design.
docker run --rm -v "$OUT:/out" -e DEBIAN_FRONTEND=noninteractive "ubuntu:$RELEASE" bash -euc "
  apt-get update -qq
  apt-get install -y -qq --no-install-recommends ca-certificates curl gnupg >/dev/null
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  . /etc/os-release
  echo \"deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \$VERSION_CODENAME stable\" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -qq
  apt-get install -y --download-only $PKGS
  cp -v /var/cache/apt/archives/*.deb /out/ | tail -1
  # The keyring the target needs to trust these later is not required for dpkg -i, but ship it
  # so an operator can add the repo by hand if they ever do get connectivity.
  cp /etc/apt/keyrings/docker.gpg /out/docker-apt-keyring.gpg
"

log "Manifest"
( cd "$OUT" && rm -f MANIFEST.txt
  { echo "# Buendia offline .deb set"
    echo "# target: Ubuntu $RELEASE (amd64) — DO NOT use on another release"
    echo "# built:  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "# source: download.docker.com (docker-ce) + Ubuntu archive (dependencies, chrony)"
    echo
    sha256sum ./*.deb ./docker-apt-keyring.gpg
  } > MANIFEST.txt )

count=$(ls -1 "$OUT"/*.deb 2>/dev/null | wc -l)
size=$(du -sh "$OUT" | awk '{print $1}')
echo
printf '\033[1;32m==> done: %s .deb files, %s, in %s\033[0m\n' "$count" "$size" "$OUT"

# The two packages whose absence is silent rather than loud, so assert them by name.
for must in chrony docker-ce; do
  ls "$OUT"/${must}_*.deb >/dev/null 2>&1 \
    || die "$must is missing from the set — refusing to call this complete."
  echo "    contains $must"
done
echo
echo "Ship the whole debs/ directory next to setup.sh, then on the target:"
echo "    sudo ./setup.sh --offline      # installs Docker + chrony from debs/, images from images/*.tar"
