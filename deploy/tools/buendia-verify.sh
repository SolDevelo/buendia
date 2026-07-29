#!/usr/bin/env bash
# Verify that a Buendia stack is not merely up, but actually USABLE by a tablet.
#
#   ./buendia-verify.sh                 # read-only; REST + DB + package server
#   ./buendia-verify.sh --quick         # the field go/no-go check (REST only, 4 checks)
#   ./buendia-verify.sh --write         # ...also admit + void a throwaway patient
#   ./buendia-verify.sh --host 192.168.0.150 --port 9100 --project throwaway
#
# setup.sh's health_check() only proves the ports answer. This proves the things a
# clinician's tablet actually depends on: that the login works, that there is somewhere
# to admit a patient TO, that exactly one zone is the default, that the profile is
# active, and that the APK is installable over the LAN.
#
# Every failure mode checked here has actually happened at least once — see
# docs/FIELD-PILOT-PROGRESS.md §4. Exit 0 = go, 1 = no-go.
#
set -uo pipefail   # NB: not -e; a failing check must be reported, not abort the run

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$HERE/../compose/docker-compose.yml"
ENV_FILE="$HERE/../.env"
APK_DIR="$HERE/../apk"
WWW_DIR="$HERE/../pkgserver/www"

HOST=127.0.0.1; PORT=9000; PKG_PORT=9001
USER=""; PASS=""; PROJECT=""
DO_DB=1; DO_PKG=1; DO_WRITE=0; QUICK=0

while [ $# -gt 0 ]; do
  case "$1" in
    --host)     HOST="$2"; shift 2 ;;
    --port)     PORT="$2"; shift 2 ;;
    --pkg-port) PKG_PORT="$2"; shift 2 ;;
    --user)     USER="$2"; shift 2 ;;
    --pass)     PASS="$2"; shift 2 ;;
    --project)  PROJECT="$2"; shift 2 ;;   # compose -p name, for a throwaway stack
    --no-db)    DO_DB=0; shift ;;
    --no-pkg)   DO_PKG=0; shift ;;
    --write)    DO_WRITE=1; shift ;;
    --quick)    QUICK=1; DO_DB=0; DO_PKG=0; shift ;;
    -h|--help)  sed -n '2,17p' "$0"; exit 0 ;;
    *) echo "unknown option: $1 (try --help)" >&2; exit 2 ;;
  esac
done

# .env is optional here: the defaults below are what the seed ships, so a bare
# clone with no .env still verifies a stack. (.env is `source`d by bash — an
# unquoted value with a space or ';' in it aborts; that trap is why this is guarded.)
if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  if ! (set -a; source "$ENV_FILE"; set +a) 2>/dev/null; then
    echo "WARNING: $ENV_FILE could not be sourced — quote values containing spaces or ; & | \$ * ?" >&2
  else
    set -a; source "$ENV_FILE"; set +a
  fi
fi
USER="${USER:-${APK_OPENMRS_USER:-buendia}}"
PASS="${PASS:-${APK_OPENMRS_PASSWORD:-buendia}}"
DB_NAME="${MYSQL_DATABASE:-openmrs}"

API="http://$HOST:$PORT/openmrs/ws/rest/buendia"
PKG="http://$HOST:$PKG_PORT"

pass_n=0; fail_n=0; warn_n=0
g="\033[32m"; r="\033[31m"; y="\033[33m"; d="\033[2m"; z="\033[0m"
[ -t 1 ] || { g=""; r=""; y=""; d=""; z=""; }
ok()   { printf "  ${g}PASS${z}  %-34s ${d}%s${z}\n" "$1" "${2:-}"; pass_n=$((pass_n+1)); }
bad()  { printf "  ${r}FAIL${z}  %-34s %s\n"        "$1" "${2:-}"; fail_n=$((fail_n+1)); }
warn() { printf "  ${y}WARN${z}  %-34s %s\n"        "$1" "${2:-}"; warn_n=$((warn_n+1)); }
info() { printf "  ${d}····  %-34s %s${z}\n"        "$1" "${2:-}"; }
head_() { printf "\n${d}── %s ${z}\n" "$1"; }

# ALWAYS GET, never HEAD: HEAD on a buendia resource returns 500 while GET returns 200.
# Harmless (the client only GETs) but it will send you chasing ghosts.
code() { curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$@"; }
body() { curl -s --max-time 20 "$@"; }
auth=(-u "$USER:$PASS")

jqpy() { python3 -c "$1" 2>/dev/null; }

dbq() {
  local p=(); [ -n "$PROJECT" ] && p=(-p "$PROJECT")
  docker compose "${p[@]}" --env-file "$ENV_FILE" -f "$COMPOSE_FILE" exec -T db \
    mysql -uroot -p"${MYSQL_ROOT_PASSWORD:-}" -N -B "$DB_NAME" -e "$1" 2>/dev/null
}

# ── REST: what the tablet talks to ────────────────────────────────────────────
head_ "REST API  $API  (as $USER)"

c="$(code "${auth[@]}" "$API/locations")"
if [ "$c" = 000 ]; then
  # Everything downstream would fail for the same reason; say it once and stop.
  bad "server reachable" "nothing answered on $HOST:$PORT"
  echo "        → The stack is down, still booting (first boot takes 2-4 min), or the host"
  echo "          firewall is blocking inbound :$PORT — the usual cause when a tablet can't"
  echo "          connect. Check:  docker compose --env-file ../.env ps"
  printf "\n  ${r}NO-GO${z} — server unreachable\n"
  exit 1
fi
if [ "$c" = 200 ]; then ok "authenticated GET /locations" "200"
else
  bad "authenticated GET /locations" "got $c (expected 200)"
  if [ "$c" = 401 ]; then
    echo "        → 401 with the RIGHT password usually means DUPLICATE rows in \`users\`:"
    echo "          OpenMRS then rejects every login. See progress doc §4, and the"
    echo "          login-row check below (it is the authoritative test)."
  fi
fi

c="$(code -u "$USER:definitely-not-the-password" "$API/locations")"
[ "$c" = 401 ] && ok "wrong password rejected" "401" \
               || bad "wrong password rejected" "got $c (expected 401) — auth is not being enforced"

locs="$(body "${auth[@]}" "$API/locations")"
n_loc="$(printf '%s' "$locs" | jqpy 'import sys,json; print(len(json.load(sys.stdin)["results"]))')"
if [ -n "${n_loc:-}" ] && [ "${n_loc:-0}" -gt 0 ]; then
  ok "/locations returns a tree" "$n_loc nodes"
  printf '%s' "$locs" | jqpy '
import sys,json
for x in json.load(sys.stdin)["results"]: print("        ", x.get("name",""))'
  # Exactly one default zone. Zero → new patients silently land in the first leaf
  # ALPHABETICALLY, which is how patients ended up in "Confirmed Zone" on 2026-07-29.
  n_star="$(printf '%s' "$locs" | jqpy '
import sys,json
print(sum(1 for x in json.load(sys.stdin)["results"] if "*" in (x.get("name") or "")))')"
  case "${n_star:-0}" in
    1) ok "exactly one default zone [*]" "new patients land there" ;;
    0) bad "exactly one default zone [*]" "NONE — new patients will land in the first leaf alphabetically" ;;
    *) bad "exactly one default zone [*]" "$n_star found — the default zone is ambiguous" ;;
  esac
else
  bad "/locations returns a tree" "empty or unparseable — nothing to admit a patient to"
fi

charts="$(body "${auth[@]}" "$API/charts")"
printf '%s' "$charts" | grep -q 'buendia_form_chart' \
  && ok "/charts serves the chart form" "buendia_form_chart" \
  || bad "/charts serves the chart form" "buendia_form_chart missing — the profile is not active"

provs="$(body "${auth[@]}" "$API/providers")"
printf '%s' "$provs" | grep -q 'buendia_provider_guest' \
  && ok "/providers includes Guest" "$(printf '%s' "$provs" | jqpy 'import sys,json; print(str(len(json.load(sys.stdin)["results"]))+" providers")')" \
  || warn "/providers includes Guest" "no buendia_provider_guest — the client sorts it first; created on first use"

c="$(code "${auth[@]}" "$API/patients")"
[ "$c" = 200 ] && ok "GET /patients" "200" || bad "GET /patients" "got $c"

if [ "$DO_WRITE" = 1 ]; then
  stamp="$(date -u +%H%M%S)"
  resp="$(body "${auth[@]}" -X POST -H 'Content-Type: application/json' \
          -d "{\"id\":\"VERIFY-$stamp\",\"given_name\":\"Verify\",\"family_name\":\"Throwaway\",\"sex\":\"F\",\"birthdate\":\"1990-01-01\"}" \
          "$API/patients")"
  uuid="$(printf '%s' "$resp" | jqpy 'import sys,json; print(json.load(sys.stdin).get("uuid",""))')"
  if [ -n "${uuid:-}" ]; then
    ok "POST /patients (admit)" "VERIFY-$stamp"
    # Void it so the check leaves no clinical residue. Voided rows still exist in the DB
    # (by design — OpenMRS never hard-deletes) but drop out of the active counts.
    # Admitting a patient also creates a placement ENCOUNTER; void that and its obs too,
    # or the encounter count creeps up by one on every --write run.
    if [ "$DO_DB" = 1 ] && dbq "
           SET @pid := (SELECT person_id FROM person WHERE uuid='$uuid');
           UPDATE obs       SET voided=1 WHERE person_id=@pid;
           UPDATE encounter SET voided=1 WHERE patient_id=@pid;
           UPDATE patient   SET voided=1 WHERE patient_id=@pid;
           UPDATE person    SET voided=1 WHERE person_id=@pid;" >/dev/null 2>&1; then
      info "  (voided the throwaway patient)" "$uuid"
    else
      warn "throwaway patient left in place" "$uuid — void it by hand on a clinical DB"
    fi
  else
    bad "POST /patients (admit)" "no uuid returned: $(printf '%s' "$resp" | head -c 160)"
  fi
fi

# ── DB: the failure modes REST cannot show you ────────────────────────────────
if [ "$DO_DB" = 1 ]; then
  head_ "Database"
  if ! dbq "SELECT 1;" >/dev/null 2>&1; then
    warn "database reachable" "no compose db container (remote host? try --no-db)"
  else
    # THE lockout bug: `users` has no unique index on uuid, so re-applying the site
    # seed inserts a second row and OpenMRS then rejects EVERY login, with both rows
    # holding a valid hash. Recovery: delete the HIGHER user_id (see progress doc §4).
    n="$(dbq "SELECT COUNT(*) FROM users WHERE username='$USER';")"
    case "${n:-0}" in
      1) ok "exactly one login row" "username=$USER" ;;
      0) bad "exactly one login row" "no user '$USER' — nobody can log in" ;;
      *) bad "exactly one login row" "$n rows for '$USER' → OpenMRS will reject EVERY login. Delete the higher user_id." ;;
    esac

    prof="$(dbq "SELECT property_value FROM global_property WHERE property='projectbuendia.currentProfile';")"
    [ -n "${prof:-}" ] && [ "$prof" != NULL ] \
      && ok "clinical profile active" "$prof" \
      || bad "clinical profile active" "projectbuendia.currentProfile is unset"

    # The db-snapshot's 6 sync triggers carried DEFINER='openmrs_user'@'localhost',
    # a user that does not exist here → every patient/obs/order INSERT failed.
    orphan="$(dbq "SELECT COUNT(*) FROM information_schema.triggers t
                   WHERE t.trigger_schema='$DB_NAME'
                     AND NOT EXISTS (SELECT 1 FROM mysql.user u
                                     WHERE CONCAT(u.user,'@',u.host)=t.definer);")"
    n_trig="$(dbq "SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_schema='$DB_NAME';")"
    if [ "${orphan:-0}" != 0 ]; then
      bad "sync trigger definers resolve" "$orphan of $n_trig point at a missing user → inserts will fail"
    elif [ "${n_trig:-0}" -lt 6 ]; then
      bad "sync trigger definers resolve" "only $n_trig sync triggers (expected 6) — incremental sync will break"
    else
      ok "sync trigger definers resolve" "$n_trig triggers"
    fi

    head_ "Data on this stack ${d}(a fingerprint, not a pass/fail)${z}"
    dbq "SELECT 'patients',   COUNT(*) FROM patient  WHERE voided=0
     UNION ALL SELECT 'encounters', COUNT(*) FROM encounter WHERE voided=0
     UNION ALL SELECT 'observations', COUNT(*) FROM obs WHERE voided=0
     UNION ALL SELECT 'orders', COUNT(*) FROM orders WHERE voided=0
     UNION ALL SELECT 'locations', COUNT(*) FROM location WHERE retired=0
     UNION ALL SELECT 'providers', COUNT(*) FROM provider WHERE retired=0;" \
      | while read -r k v; do info "$k" "$v"; done
  fi
fi

# ── Package server: how the APK reaches a tablet ──────────────────────────────
if [ "$DO_PKG" = 1 ]; then
  head_ "Package server  $PKG"
  hdr="$(curl -s -o /dev/null --max-time 20 -w '%{http_code} %{content_type} %{size_download}' "$PKG/latest.apk")"
  set -- $hdr; c="$1"; ctype="${2:-}"; size="${3:-0}"
  if [ "$c" != 200 ]; then
    bad "/latest.apk served" "got $c — run pkgserver/publish.sh (nginx starts fine with an empty www/)"
  else
    ok "/latest.apk served" "$size bytes"
    [ "$ctype" = "application/vnd.android.package-archive" ] \
      && ok "APK content-type" "$ctype" \
      || bad "APK content-type" "$ctype — Android may refuse to install it"
  fi

  # 206 means an interrupted ward-wifi download resumes instead of restarting.
  c="$(code -H 'Range: bytes=0-99' "$PKG/latest.apk")"
  [ "$c" = 206 ] && ok "range requests (resumable)" "206" \
                 || warn "range requests (resumable)" "got $c — a dropped download restarts from zero"

  # The client health-checks this exact path; a 404 shows clinicians a scary snackbar.
  c="$(code "$PKG/dists/stable/Release")"
  [ "$c" = 200 ] && ok "/dists/stable/Release stub" "200" \
                 || bad "/dists/stable/Release stub" "got $c → 'check package server configuration' on the tablet"

  idx="$(body "$PKG/buendia-client.json")"
  ver="$(printf '%s' "$idx" | jqpy 'import sys,json; d=json.load(sys.stdin); print(d[0]["version"] if d else "")')"
  if [ -z "${ver:-}" ]; then
    bad "update index parses" "buendia-client.json missing or empty"
  elif printf '%s' "$ver" | grep -qE '^[0-9]+(\.[0-9]+)*$'; then
    ok "update index parses" "version $ver"
  else
    # The updater compares versionName with integer components only; a non-numeric
    # version reads as 0, so every tablet treats every publish as an upgrade.
    bad "update index parses" "version '$ver' is not numeric — tablets will nag about a bogus update"
  fi

  # Byte-identity: catches a stale publish (www/ older than the APK you just built).
  newest="$(ls -t "$APK_DIR"/buendia-client-*.apk 2>/dev/null | head -1)"
  if [ -n "$newest" ] && [ -f "$WWW_DIR/latest.apk" ]; then
    if [ "$(sha256sum <"$newest" | cut -d' ' -f1)" = "$(sha256sum <"$WWW_DIR/latest.apk" | cut -d' ' -f1)" ]; then
      ok "published APK is the built APK" "$(basename "$newest")"
    else
      warn "published APK is the built APK" "www/latest.apk differs from $(basename "$newest") — re-run publish.sh"
    fi
  fi
fi

# ── Verdict ───────────────────────────────────────────────────────────────────
printf "\n"
if [ "$fail_n" -eq 0 ]; then
  printf "  ${g}GO${z}  — %d checks passed" "$pass_n"
  [ "$warn_n" -gt 0 ] && printf ", %d warning(s)" "$warn_n"
  printf "\n"
  [ "$QUICK" = 1 ] && printf "  ${d}(--quick: REST only. Drop it to check the DB and package server too.)${z}\n"
  exit 0
else
  printf "  ${r}NO-GO${z} — %d check(s) failed, %d passed\n" "$fail_n" "$pass_n"
  printf "  ${d}Gotchas and recovery steps: docs/FIELD-PILOT-PROGRESS.md §4${z}\n"
  exit 1
fi
