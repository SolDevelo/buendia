#!/usr/bin/env bash
# Move patients out of locations that were deleted in OpenMRS.
#
# A placement is stored as text ("<location uuid>/<bed>"), so OpenMRS lets a location be deleted
# while patients are still placed in it. Print Patient Files then fails with HTTP 500 (servers up to
# pack 1.6.0) or shows "Lieu supprimé" (later ones), on the patient list for a current placement and
# on the printout of anyone who was ever placed there. This points every such placement at one
# existing location (bed kept), lists the patients it moved, and writes an undo file. Patients placed
# in a deleted discharge location are listed and left as they are: moving them would re-admit them.
#
#   sudo bash buendia-fix-placements.sh             # list, ask, fix
#   sudo bash buendia-fix-placements.sh --dry-run   # list only, change nothing
# Options: --to <location uuid>  (default: the first non-retired location by ID that has a parent,
#                                 else the first non-retired one)
#          --yes  (do not ask)   --dir <install dir>   --project <compose -p name, for testing>
if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi
set -euo pipefail

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
HERE="$(dirname "$SELF")"

ARGS=("$@")  # kept for the re-run under sudo, since parsing consumes them
DIR=""; PROJECT=""; TO=""; DRY=""; YES=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dir)     DIR="$2"; shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
    --to)      TO="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --yes)     YES=1; shift ;;
    -h|--help) sed -n '2,15p' "$SELF" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1 (try --help)" >&2; exit 2 ;;
  esac
done

die() { printf '\n%s\n' "$1" >&2; exit 1; }

if ! docker info >/dev/null 2>&1; then
  if [ "$(id -u)" -ne 0 ]; then
    command -v sudo >/dev/null 2>&1 || die "This must be run as root:  su -c 'bash $SELF'"
    echo "Administrator rights are needed to read the database — you may be asked for your password."
    exec sudo -- bash "$SELF" "${ARGS[@]}"
  fi
  die "Docker is not running on this machine, so the database cannot be reached."
fi

for c in "$DIR" "$HERE/.." "$HERE" /opt/buendia; do
  [ -n "$c" ] && [ -f "$c/compose/docker-compose.yml" ] && { DIR="$(cd "$c" && pwd)"; break; }
done
[ -n "$DIR" ] && [ -f "$DIR/.env" ] \
  || die "Buendia does not appear to be installed here. If it is somewhere else:  --dir /path/to/buendia"

dc() {
  local p=(); [ -n "$PROJECT" ] && p=(-p "$PROJECT")
  docker compose "${p[@]}" --env-file "$DIR/.env" -f "$DIR/compose/docker-compose.yml" "$@"
}
# Password expanded inside the db container; the SQL goes in over stdin. A failed query stops the
# script with the database's own message.
SQLERR="$(mktemp)"; trap 'rm -f "$SQLERR"' EXIT
sql() {
  dc exec -T db sh -c 'exec mysql --default-character-set=utf8 -N -B -uroot -p"$MYSQL_ROOT_PASSWORD" openmrs' \
    2>"$SQLERR" || die "The database could not be read: $(grep -v 'Using a password' "$SQLERR")"
}

# Placements (not voided) whose location no longer exists.
MISSING="FROM obs o
  JOIN concept c ON c.concept_id = o.concept_id AND c.uuid = 'buendia_concept_placement'
  LEFT JOIN location l ON l.uuid = SUBSTRING_INDEX(o.value_text, '/', 1)
  WHERE o.voided = 0 AND l.location_id IS NULL"
# A patient placed in a discharged location has left; moving them would make them an inpatient
# again. Same list as DISCHARGED_LOCATION_UUIDS in the server's DataHelper.java.
DISCHARGED="'73010980-d3e7-404a-95bf-180966f04fb8', 'b990663d-b80b-41ba-9b55-de172a5db780'"
BROKEN="$MISSING AND SUBSTRING_INDEX(o.value_text, '/', 1) NOT IN ($DISCHARGED)"
KEPT="$MISSING AND SUBSTRING_INDEX(o.value_text, '/', 1) IN ($DISCHARGED)"

if [ -n "$TO" ]; then
  target="$(printf "SELECT uuid, name FROM location WHERE retired = 0 AND uuid = %s;\n" \
    "'${TO//[\'\\]/}'" | sql)"
  [ -n "$target" ] || die "No location with UUID $TO (or it is retired)."
else
  # Prefer a zone over the root (a patient at the root is in no zone on the tablet); a site whose
  # locations all lack a parent still gets its first one.
  target="$(echo "SELECT uuid, name FROM location WHERE retired = 0
                  ORDER BY parent_location IS NULL, location_id LIMIT 1;" | sql)"
  [ -n "$target" ] || die "There is no location to move patients to."
fi
TO_UUID="${target%%$'\t'*}"; TO_NAME="${target#*$'\t'}"

# One line per placement: obs id, MSF ID, name, bed, current/earlier, date.
placements() { sql <<EOF
SELECT o.obs_id,
       COALESCE((SELECT pi.identifier FROM patient_identifier pi
                 WHERE pi.patient_id = o.person_id AND pi.voided = 0 ORDER BY pi.preferred DESC LIMIT 1), '(no ID)'),
       COALESCE((SELECT CONCAT(pn.given_name, ' ', pn.family_name) FROM person_name pn
                 WHERE pn.person_id = o.person_id AND pn.voided = 0 ORDER BY pn.preferred DESC LIMIT 1), '-'),
       COALESCE(NULLIF(TRIM(IF(LOCATE('/', o.value_text) > 0,
                SUBSTRING(o.value_text, LOCATE('/', o.value_text) + 1), '')), ''), '-'),
       IF(o.obs_datetime = (SELECT MAX(o2.obs_datetime) FROM obs o2 WHERE o2.person_id = o.person_id
                            AND o2.concept_id = o.concept_id AND o2.voided = 0), 'current', 'earlier'),
       DATE_FORMAT(o.obs_datetime, '%Y-%m-%d %H:%i')
$1
ORDER BY 2, o.obs_datetime;
EOF
}
print_rows() {
  printf '  %-14s %-28s %-8s %-16s %s\n' "MSF ID" "Name" "Bed" "Placed on" "Placement"
  printf '%s\n' "$1" | while IFS=$'\t' read -r _ id name bed kind when; do
    printf '  %-14s %-28s %-8s %-16s %s\n' "$id" "$name" "$bed" "$when" "$kind"
  done
  echo
  echo "  current = where the patient is now; earlier = a past bed move in their history."
}

kept="$(placements "$KEPT")"
if [ -n "$kept" ]; then
  echo "Not moved: these patients were discharged, and their discharge location was deleted."
  echo
  print_rows "$kept"
  echo
fi

rows="$(placements "$BROKEN")"

if [ -z "$rows" ]; then
  echo "No other patient is placed in a deleted location. Nothing to fix."
  exit 0
fi

n=$(printf '%s\n' "$rows" | wc -l)
echo "Placements in a location that no longer exists: $n"
echo "They will be moved to: $TO_NAME"
echo
print_rows "$rows"

[ -n "$DRY" ] && { echo; echo "Dry run: nothing was changed."; exit 0; }

if [ -z "$YES" ]; then
  [ -t 0 ] || die "Not run from a terminal: add --yes to apply, or --dry-run to only list."
  printf '\nMove them to "%s"? [y/N] ' "$TO_NAME"
  read -r answer
  case "$answer" in y|Y|yes|YES|o|O|oui) ;; *) echo "Nothing was changed."; exit 0 ;; esac
fi

USER_NAME="${SUDO_USER:-$(id -un)}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
UNDO="${USER_HOME:-.}/buendia-placement-undo-$(date +%Y%m%d-%H%M%S).sql"
echo "SELECT CONCAT('UPDATE obs SET value_text = ', QUOTE(o.value_text), ' WHERE obs_id = ', o.obs_id, ';')
      $BROKEN;" | sql > "$UNDO.tmp"
[ "$(wc -l < "$UNDO.tmp")" -eq "$n" ] || die "Could not write the undo file $UNDO; nothing was changed."
mv "$UNDO.tmp" "$UNDO"
chown "$USER_NAME" "$UNDO" 2>/dev/null || true

# Same rows as $BROKEN (MISSING minus DISCHARGED); keep the two in step.
# The obs update trigger re-queues each row for tablet sync, so tablets pick up the new location.
left="$(sql <<EOF
START TRANSACTION;
UPDATE obs o
  JOIN concept c ON c.concept_id = o.concept_id AND c.uuid = 'buendia_concept_placement'
  LEFT JOIN location l ON l.uuid = SUBSTRING_INDEX(o.value_text, '/', 1)
  SET o.value_text = CONCAT('$TO_UUID', '/',
        IF(LOCATE('/', o.value_text) > 0, SUBSTRING(o.value_text, LOCATE('/', o.value_text) + 1), ''))
  WHERE o.voided = 0 AND l.location_id IS NULL
    AND SUBSTRING_INDEX(o.value_text, '/', 1) NOT IN ($DISCHARGED);
COMMIT;
SELECT COUNT(*) $BROKEN;
EOF
)"
[ "$left" = "0" ] || die "Some placements are still broken ($left). Send us everything above."

echo
echo "Moved $n placement(s) to \"$TO_NAME\"."
echo "Undo file (keep it): $UNDO"
echo "Sync the tablets so they show the new location. Print Patient Files should open again."
