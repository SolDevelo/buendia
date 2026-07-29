#!/usr/bin/env bash
# Build the deployment bundle: ONLY the files a site server needs to run, and nothing else.
#
#   ./make-bundle.sh                 # -> buendia-deploy-<version>.tar.gz (+ .sha256)
#   ./make-bundle.sh 1.0.0           # explicit version instead of `git describe`
#
# WHY THIS EXISTS: the bootstrap used to `git clone` the repo onto the server, which put CLAUDE.md,
# the whole docs/ set (deployment plan, MSF config requests, the technical review), .claude/skills/,
# the entire source tree and ~76 MB of git history onto a machine that ships to a site and is handled
# by people outside SolDevelo. None of that is needed to run the server, and some of it is internal
# assessment that should not travel. The bundle is ~100 KB of scripts and config.
#
# The list below is an ALLOWLIST on purpose. A denylist ("everything except docs/") silently leaks
# whatever gets added to the repo later; an allowlist fails closed.
#
# Publish it as a release asset on the PUBLIC repo — it contains no secrets (deploy/.env is supplied
# separately, per site) so the server needs no credential to fetch it.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY="$(cd "$HERE/.." && pwd)"
REPO="$(cd "$DEPLOY/.." && pwd)"

VERSION="${1:-$(cd "$REPO" && git describe --tags --always --dirty 2>/dev/null || echo unknown)}"
OUT_DIR="${OUT_DIR:-$DEPLOY}"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
ROOT="$STAGE/buendia-deploy"

# --- the allowlist: every path the deployment actually touches ---------------
# Derived from: what setup.sh reads ($HERE/...), what docker-compose.yml bind-mounts, and what
# buendia-verify.sh needs. Keep it in sync when you add a file that setup.sh depends on — the
# completeness check at the bottom of this script is what catches a mistake.
REQUIRED=(
  setup.sh                                  # the installer
  compose/docker-compose.yml                # the stack
  config/chrony/buendia-ntp.conf            # LAN time authority
  config/docker/daemon.json                 # log rotation caps
  config/logind.conf.d/buendia.conf         # ignore the lid, no suspend
  seed/initdb/20-buendia-site.sql           # bind-mounted: locations + login (tailorable per site)
  pkgserver/nginx.conf                      # bind-mounted: serves the APK with the right mime type
  tools/buendia-verify.sh                   # setup.sh's go/no-go; also the on-site health check
)
# Genuinely useful ON SITE, so worth the few KB: rotate the password, collect diagnostics for a
# support request, and reprint an in-zone install card without a laptop from the build side.
OPTIONAL=(
  tools/create-openmrs-user.sh
  tools/buendia-diagnostics.sh
  pkgserver/publish.sh
  pkgserver/make-install-card.sh
)

mkdir -p "$ROOT"
copy() {
  # NB two statements, not `local rel=.. src=..`: in a single `local` bash marks every name local
  # before assigning, so $rel would be unset while evaluating src (fatal under `set -u`).
  local rel="$1"
  local src="$DEPLOY/$rel"
  [[ -f "$src" ]] || return 1
  install -D -m "$( [[ -x "$src" ]] && echo 0755 || echo 0644 )" "$src" "$ROOT/$rel"
}

echo "==> staging bundle (version $VERSION)"
missing=0
for f in "${REQUIRED[@]}"; do
  copy "$f" && echo "    + $f" || { echo "    MISSING (required): $f" >&2; missing=1; }
done
[[ $missing -eq 0 ]] || { echo "ERROR: required files are missing — bundle not built." >&2; exit 1; }
for f in "${OPTIONAL[@]}"; do
  copy "$f" && echo "    + $f (optional)" || echo "    - $f (optional, absent)"
done

# Directories the scripts expect to exist. www/ is filled by the tablet payload; debs/ only by
# --offline. Empty dirs don't survive tar reliably, so mark them.
for d in pkgserver/www debs images apk; do
  mkdir -p "$ROOT/$d"; : > "$ROOT/$d/.gitkeep"
done

# --- operator README, written for this audience (not the internal one) ------
cat > "$ROOT/README.md" <<'EOF'
# Buendia field-pilot server — deployment bundle

Everything needed to bring up a Buendia server, and nothing else. There is no source code and no
project documentation here; this is the runtime package.

## Install

```bash
cp <the .env supplied for this site> ./.env    # holds the site address + database passwords
sudo ./setup.sh --dry-run                      # prints every change, makes none
sudo ./setup.sh                                # do it
```

`setup.sh` configures the host (timezone, no-suspend, log caps, LAN time service, optionally a
static IP), installs Docker, pulls the two container images, starts the stack, and finishes by
verifying the result. **It exits non-zero unless the server is actually usable** — not merely
listening. Re-running it is safe.

## Check it

```bash
./tools/buendia-verify.sh              # full check, needs Docker on this box
./tools/buendia-verify.sh --quick      # REST-only go/no-go, safe for a non-technical operator
```

Both print `GO` or `NO-GO`. Use `--quick` as the on-site check after a power cut or a move.

## Use it

- Clinical web UI / admin: `http://<server>:9000/openmrs`
- Tablet APK install page (QR code): `http://<server>:9001/`

## Day-to-day

```bash
docker compose -f compose/docker-compose.yml --env-file .env ps       # is it up?
docker compose -f compose/docker-compose.yml --env-file .env restart  # bounce it
./tools/create-openmrs-user.sh buendia <new-password>                 # rotate the login
./tools/buendia-diagnostics.sh                                        # bundle logs for support
```

⚠️ Changing the server password means each tablet also needs updating: in the app, cog → Settings →
*OpenMRS password*. Until that is done, that tablet cannot sync.

⚠️ `docker compose ... down -v` **destroys the database**, including all patient data. There is no
undo. Never use `-v` unless you intend exactly that.

## Files

| Path | What |
|---|---|
| `setup.sh` | the installer |
| `.env` | site configuration + secrets (supplied per site; not in this bundle) |
| `compose/docker-compose.yml` | the three services: database, OpenMRS, package server |
| `config/` | host config applied by setup.sh |
| `seed/initdb/20-buendia-site.sql` | the site's locations and login account, applied on first boot |
| `pkgserver/www/` | the tablet APK and its install page (supplied separately) |
| `tools/` | verification, password rotation, diagnostics |
EOF
echo "    + README.md (generated for the operator)"

# --- self-check: prove nothing internal slipped in --------------------------
echo "==> leak check"
leaks="$(cd "$ROOT" && find . -type f \( -iname 'CLAUDE.md' -o -path './docs/*' -o -path './.claude/*' \
  -o -iname '*FIELD-PILOT*' -o -iname 'TECHNICAL-REVIEW*' \) -print)"
[[ -z "$leaks" ]] || { echo "ERROR: internal files in the bundle:"$'\n'"$leaks" >&2; exit 1; }
mds="$(cd "$ROOT" && find . -name '*.md' -not -name 'README.md' -print)"
[[ -z "$mds" ]] || { echo "ERROR: unexpected markdown in the bundle:"$'\n'"$mds" >&2; exit 1; }
[[ ! -e "$ROOT/.env" ]] || { echo "ERROR: .env must never be bundled (it holds secrets)." >&2; exit 1; }
[[ ! -d "$ROOT/.git" ]] || { echo "ERROR: .git must never be bundled." >&2; exit 1; }
echo "    no internal docs, no .env, no git history"

# --- manifest + tarball -----------------------------------------------------
( cd "$ROOT" && find . -type f -not -name .gitkeep -not -name MANIFEST.txt \
    -exec sha256sum {} + | sort -k2 > MANIFEST.txt )
printf 'version: %s\n' "$VERSION" >> "$ROOT/MANIFEST.txt"

OUT="$OUT_DIR/buendia-deploy-${VERSION}.tar.gz"
tar czf "$OUT" -C "$STAGE" buendia-deploy
sha256sum "$OUT" | awk -v n="$(basename "$OUT")" '{print $1"  "n}' > "$OUT.sha256"

echo
echo "==> done: $(basename "$OUT") ($(du -h "$OUT" | cut -f1), $(tar tzf "$OUT" | grep -c . ) entries)"
echo "    Publish on the PUBLIC repo (it holds no secrets, so the server needs no token):"
echo "        gh release upload <tag> '$OUT' '$OUT.sha256' --repo SolDevelo/buendia"
echo "    Or just copy it to the USB stick next to bootstrap.sh."
