#!/usr/bin/env bash
# Collect an offline diagnostic dump for SolDevelo (plan §3.4).
# Writes a single timestamped archive to $1 (default: current dir / a mounted USB).
# NOTE: logs may contain patient data — the archive is encrypted if a passphrase is set
# (BUENDIA_DIAG_PASSPHRASE) and handled per MSF data-protection rules.
# Run with `sh`, the shebang is ignored and dash cannot run this; re-run it under bash.
if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi
set -euo pipefail
OUT_DIR="${1:-$PWD}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
WORK="$(mktemp -d)"
DEST="$WORK/buendia-diag-$STAMP"
mkdir -p "$DEST"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "collecting diagnostics → $DEST"
{ uname -a; . /etc/os-release 2>/dev/null && echo "$PRETTY_NAME"; } > "$DEST/system.txt" 2>&1 || true
docker --version                              > "$DEST/docker-version.txt" 2>&1 || true
compose() { docker compose --env-file "$HERE/.env" -f "$HERE/compose/docker-compose.yml" "$@"; }
compose ps                                    > "$DEST/compose-ps.txt"     2>&1 || true
compose logs --tail=2000                      > "$DEST/compose-logs.txt"   2>&1 || true
# Tomcat writes request errors (the stack trace behind an HTTP 500) to its own files, not to stdout.
# Print Patient Files logs a patient it could not print to openmrs.log.
compose exec -T openmrs sh -c 'tar -czf - /opt/tomcat/logs /opt/openmrs/openmrs.log 2>/dev/null' \
                                              > "$DEST/openmrs-logs.tar.gz" 2>"$DEST/openmrs-logs.err" || true
df -h                                         > "$DEST/disk.txt"           2>&1 || true
free -h                                       > "$DEST/memory.txt"         2>&1 || true
timedatectl                                   > "$DEST/time.txt"           2>&1 || true
journalctl -b --no-pager | tail -n 5000       > "$DEST/journal.txt"        2>&1 || true

ARCHIVE="$OUT_DIR/buendia-diag-$STAMP.tar.gz"
tar -C "$WORK" -czf "$ARCHIVE" "buendia-diag-$STAMP"
rm -rf "$WORK"

if [[ -n "${BUENDIA_DIAG_PASSPHRASE:-}" ]] && command -v gpg >/dev/null; then
  gpg --batch --yes --symmetric --cipher-algo AES256 \
      --passphrase "$BUENDIA_DIAG_PASSPHRASE" "$ARCHIVE"
  rm -f "$ARCHIVE"
  echo "wrote (encrypted): $ARCHIVE.gpg"
else
  echo "wrote: $ARCHIVE"
  echo "  (set BUENDIA_DIAG_PASSPHRASE + install gpg to encrypt — recommended, patient data)"
fi
