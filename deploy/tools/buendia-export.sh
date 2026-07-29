#!/usr/bin/env bash
# Export clinical data so MSF medical teams are not "blind" (plan §3.5).
# Primary path: the module's DataExportServlet (CSV). Fallback: a raw mysqldump.
# Patient data — destination/access governed by MSF data-protection rules.
set -euo pipefail
OUT_DIR="${1:-$PWD}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
set -a; source "$HERE/.env"; set +a

# --- Preferred: DataExportServlet (CSV) -----------------------------------
# TODO(WS-3/omod): confirm the servlet path + auth for the built image, then:
#   curl -fsS -u "$USER:$PASS" "http://localhost:9000/openmrs/module/.../dataExport.csv" \
#        -o "$OUT_DIR/buendia-export-$STAMP.csv"
echo "TODO: wire DataExportServlet CSV endpoint (see plan §3.5). Falling back to mysqldump."

# --- Fallback: raw SQL dump -----------------------------------------------
DUMP="$OUT_DIR/buendia-db-$STAMP.sql.gz"
( cd "$HERE/compose" && docker compose exec -T db \
    mysqldump -u root -p"${MYSQL_ROOT_PASSWORD}" "${MYSQL_DATABASE}" ) | gzip > "$DUMP"
echo "wrote: $DUMP"
echo "  This is patient data — handle per MSF data-protection rules; deliver via the"
echo "  remote-support tunnel when online, or on a USB key otherwise (§3.5)."
