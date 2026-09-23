#!/usr/bin/env bash
# Take a backup of the Buendia database — and prove that what landed on disk is a real one.
#
#   ./backup.sh                      # asks for the administrator password if it needs it
#   ./backup.sh --out /media/usb     # write it somewhere else (default: your home folder)
#   ./backup.sh --dir /opt/buendia   # point at the installation, if it is not found by itself
#   ./backup.sh --verify-only <file> # re-check a backup taken earlier, without taking a new one
#
# WHY IT VERIFIES: a backup that is never read back is a guess. `mysqldump` piped into `gzip`
# reports gzip's exit status, not its own, so a dump that died half way through still looks
# like a success and still leaves a plausible .sql.gz behind — the failure only surfaces on the
# day someone tries to restore it. So this reads the file back and checks that every table is
# present, that the tables that hold data actually carry rows, and that mysqldump wrote its own
# "Dump completed" trailer, which it only does when it finished.
#
# Exit 0 = the backup is good. Exit 1 = do not upgrade; send us the output.
set -uo pipefail

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
HERE="$(dirname "$SELF")"

DIR=""; OUT_DIR=""; PROJECT=""; VERIFY_ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dir)     DIR="$2"; shift 2 ;;
    --out)     OUT_DIR="$2"; shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;   # compose -p name, for testing against a throwaway stack
    --verify-only) VERIFY_ONLY="$2"; shift 2 ;;   # re-check a backup taken earlier, take no new one
    -h|--help) sed -n '2,9p' "$SELF" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1 (try --help)" >&2; exit 2 ;;
  esac
done

g="\033[32m"; r="\033[31m"; y="\033[33m"; d="\033[2m"; z="\033[0m"
[ -t 1 ] || { g=""; r=""; y=""; d=""; z=""; }
ok()   { printf "  ${g}PASS${z}  %-34s ${d}%s${z}\n" "$1" "${2:-}"; }
bad()  { printf "  ${r}FAIL${z}  %-34s %s\n"         "$1" "${2:-}"; fail=$((fail+1)); }
warn() { printf "  ${y}WARN${z}  %-34s %s\n"         "$1" "${2:-}"; }
info() { printf "  ${d}····  %-34s %s${z}\n"         "$1" "${2:-}"; }
head_() { printf "\n${d}── %s ${z}\n" "$1"; }
die()  { printf "\n${r}%s${z}\n" "$1" >&2; exit 1; }
fail=0

# Talking to the database means talking to Docker, which usually needs root — but not always:
# whoever installed the server may already be in the `docker` group. So this asks for the
# administrator password only when Docker actually refuses, which keeps the command to teach
# down to "./backup.sh" without demanding a password that is not needed.
if ! docker info >/dev/null 2>&1; then
  if [ "$(id -u)" -ne 0 ]; then
    command -v sudo >/dev/null 2>&1 || die "This must be run as root, and sudo is not installed:  su -c '$SELF'"
    echo "Administrator rights are needed to read the database — you may be asked for your password."
    exec sudo -- "$SELF" "$@"
  fi
  die "Docker is not running on this machine, so the database cannot be reached."
fi

# Where the server is installed. The same script ships twice: at the root of the USB folder
# (where there is no installation next to it) and inside the installation itself.
for c in "$DIR" "$HERE/.." "$HERE" /opt/buendia; do
  [ -n "$c" ] && [ -f "$c/compose/docker-compose.yml" ] && { DIR="$(cd "$c" && pwd)"; break; }
done
[ -n "$DIR" ] && [ -f "$DIR/compose/docker-compose.yml" ] \
  || die "Buendia does not appear to be installed here. If it is somewhere else:  ./backup.sh --dir /path/to/buendia"
[ -f "$DIR/.env" ] || die "$DIR/.env is missing — this does not look like a working installation."
command -v docker >/dev/null 2>&1 || die "Docker is not installed on this machine."

# shellcheck disable=SC1091
set -a; . "$DIR/.env" 2>/dev/null; set +a
DB_NAME="${MYSQL_DATABASE:-openmrs}"
SITE="${SITE_ID:-buendia}"

dc() {
  local p=(); [ -n "$PROJECT" ] && p=(-p "$PROJECT")
  docker compose "${p[@]}" --env-file "$DIR/.env" -f "$DIR/compose/docker-compose.yml" "$@"
}
# The password stays inside the container: it is already in the db container's environment, so
# expanding it there keeps it out of this machine's process list, where `ps` would show it.
# The query goes in over STDIN, not as -e "...". Interpolating it into the double-quoted sh -c
# string put a second round of shell parsing between here and mysql, where a backtick-quoted
# table name became a command substitution and every count came back empty — silently, which
# in turn disabled the check that the dump actually contains rows.
dbq() { printf '%s\n' "$1" | dc exec -T db sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -N -B "$MYSQL_DATABASE"' 2>/dev/null; }

check_file() {   # everything below reads the FILE back; it never touches the server
  local FILE="$1"
  head_ "Checking the file is a real backup"
  SIZE="$(stat -c %s "$FILE" 2>/dev/null || echo 0)"
  HUMAN="$(du -h "$FILE" | awk '{print $1}')"
  
  if gzip -t "$FILE" 2>/dev/null; then ok "file is not corrupt" "$HUMAN"
  else bad "file is not corrupt" "the compressed file will not open"; fi
  
  if   [ "$SIZE" -lt 102400 ]; then bad "file is a sensible size" "$SIZE bytes — far too small to hold a database"
  elif [ "$SIZE" -lt 1048576 ]; then warn "file is a sensible size" "$HUMAN — smaller than expected; check the numbers below"
  else ok "file is a sensible size" "$HUMAN"; fi
  
  # One pass over the decompressed dump: count the tables, note which of the ones that matter
  # carry INSERTs, and keep the last line (mysqldump writes its trailer only if it got there).
  READBACK="$(gzip -dc "$FILE" 2>/dev/null | awk '
    /^CREATE TABLE/ { ct++ }
    /^INSERT INTO/  { for (t in want) if (index($0, "`" t "`")) seen[t] = 1 }
    { last = $0 }
    BEGIN { split("patient encounter obs orders users location", a, " "); for (i in a) want[a[i]] = 1 }
    END { printf "%d\n", ct; for (t in want) printf "%s=%d\n", t, (t in seen) ? 1 : 0; print "LAST=" last }')"
  
  DUMP_TABLES="$(printf '%s\n' "$READBACK" | head -1)"
  LIVE_TABLES="$(dbq "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB_NAME' AND table_type='BASE TABLE';" | tr -d '[:space:]')"
  case "$LIVE_TABLES" in ''|*[!0-9]*) LIVE_TABLES="" ;; esac
  if [ -n "$LIVE_TABLES" ] && [ "$DUMP_TABLES" = "$LIVE_TABLES" ]; then
    ok "every table is in the file" "$DUMP_TABLES tables"
  elif [ -n "$LIVE_TABLES" ]; then
    bad "every table is in the file" "the server has $LIVE_TABLES, the file has $DUMP_TABLES"
  else
    info "tables in the file" "$DUMP_TABLES"
  fi
  
  # A table with rows on the server and none in the file is the exact shape of a dump that was
  # cut short, and it is invisible in the file size.
  missing=""
  for t in patient encounter obs orders users location; do
    live="${LIVE[$t]:-}"
    got="$(printf '%s\n' "$READBACK" | sed -n "s/^$t=//p")"
    [ -z "$live" ] && continue
    if [ "$live" -gt 0 ] && [ "${got:-0}" -ne 1 ]; then missing="$missing $t"; fi
  done
  if [ -n "$missing" ]; then bad "the records are in the file" "no data for:$missing"
  else ok "the records are in the file" "patients, visits, observations, treatments, users"; fi
  
  if printf '%s\n' "$READBACK" | grep -q '^LAST=-- Dump completed'; then
    ok "the file is complete" "it ends where it should"
  else
    bad "the file is complete" "it stops in the middle — the backup was interrupted"
  fi
}

head_ "The server"
dc exec -T db sh -c 'true' >/dev/null 2>&1 \
  || die "The database is not running, so there is nothing to back up.
Start the server first:  sudo $DIR/setup.sh
(If it has only just started, wait a minute and try again.)"
ok "database is running" "$DIR"

# Where it goes. Under sudo, $HOME is root's — the file belongs to the person who ran this.
USER_NAME="${SUDO_USER:-root}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
[ -n "$USER_HOME" ] && [ -d "$USER_HOME" ] || USER_HOME="/root"
OUT_DIR="${OUT_DIR:-$USER_HOME}"
[ -d "$OUT_DIR" ] || die "$OUT_DIR does not exist."
OUT="$OUT_DIR/buendia-backup-$SITE-$(date +%Y-%m-%d-%H%M).sql.gz"

# Room to write it. The dump compresses several times over, so the raw data size is a
# deliberately pessimistic requirement — if that fits, the .sql.gz certainly does.
RAW="$(dbq "SELECT COALESCE(SUM(data_length+index_length),0) FROM information_schema.tables WHERE table_schema='$DB_NAME';" | tr -d '[:space:]')"
case "$RAW" in ''|*[!0-9]*) RAW=0 ;; esac
AVAIL_KB="$(df -Pk "$OUT_DIR" 2>/dev/null | awk 'NR==2{print $4}')"
case "$AVAIL_KB" in ''|*[!0-9]*) AVAIL_KB=0 ;; esac
if [ "$RAW" -gt 0 ] && [ "$AVAIL_KB" -gt 0 ] && [ "$AVAIL_KB" -lt "$((RAW / 1024))" ]; then
  die "Not enough free space in $OUT_DIR ($((AVAIL_KB / 1024)) MB free, database is $((RAW / 1048576)) MB).
Delete an old backup, or write this one elsewhere:  ./backup.sh --out /media/<your usb>"
fi
info "database size" "$((RAW / 1048576)) MB"

# What is in there now, so the operator can see the numbers the backup is supposed to contain.
head_ "What is being backed up"
declare -A LIVE
for t in patient encounter obs orders users location; do
  n="$(dbq "SELECT COUNT(*) FROM \`$t\`;" | tr -d '[:space:]')"
  case "$n" in ''|*[!0-9]*) n="" ;; esac
  LIVE[$t]="$n"
  [ -n "$n" ] && info "$t" "$n rows"
done

# Re-checking a backup taken earlier: the same read-back, no new file. Useful before an upgrade
# when a backup already exists, and the only honest way to answer "is that old one any good?".
if [ -n "$VERIFY_ONLY" ]; then
  [ -f "$VERIFY_ONLY" ] || die "$VERIFY_ONLY not found."
  head_ "Checking a backup taken earlier"
  info "file" "$VERIFY_ONLY"
  check_file "$VERIFY_ONLY"
  printf "\n"
  if [ "$fail" -gt 0 ]; then
    printf "${r}THIS BACKUP CANNOT BE TRUSTED${z} — %s check(s) failed.\n" "$fail"
    echo "Take a fresh one:  ./backup.sh"
    exit 1
  fi
  printf "${g}That backup is good${z}  (%s)\n" "$HUMAN"
  exit 0
fi

head_ "Taking the backup"
ERR="$(mktemp)"; trap 'rm -f "$ERR"' EXIT
umask 077        # the dump holds every patient record; nobody else on this machine may read it
dc exec -T db sh -c \
  'mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction --routines --triggers "$MYSQL_DATABASE"' \
  2>"$ERR" | gzip -c > "$OUT"
st=("${PIPESTATUS[@]}")
# grep -v: mysqldump 5.6 prints this on every single run, and a warning nobody can act on
# teaches the reader to ignore the ones that matter.
sed -i '/Using a password on the command line interface can be insecure/d' "$ERR"

if [ "${st[0]}" -ne 0 ]; then
  bad "the database could be read" "mysqldump exited ${st[0]}"
  [ -s "$ERR" ] && sed 's/^/        /' "$ERR"
  rm -f "$OUT"
  die "NO BACKUP WAS TAKEN. Do not upgrade — send us the text above."
fi
[ "${st[1]}" -eq 0 ] || { rm -f "$OUT"; die "The file could not be written to $OUT_DIR."; }
[ -s "$ERR" ] && { warn "mysqldump said something"; sed 's/^/        /' "$ERR"; }
ok "database read to the end" "mysqldump finished"

check_file "$OUT"
chown "$USER_NAME": "$OUT" 2>/dev/null || true
chmod 600 "$OUT"

printf "\n"
if [ "$fail" -gt 0 ]; then
  printf "${r}THIS BACKUP CANNOT BE TRUSTED${z} — %s check(s) failed.\n" "$fail"
  echo "Do not upgrade. Send us everything above; the file has been left at:"
  echo "  $OUT"
  exit 1
fi
printf "${g}Backup taken and verified${z}\n"
echo "  $OUT  ($HUMAN)"
echo
echo "Copy it onto a USB stick as well — a backup on this laptop does not protect against the laptop."
old="$(ls -1t "$OUT_DIR"/buendia-backup-*.sql.gz 2>/dev/null | tail -n +2 | head -3)"
[ -n "$old" ] && { echo; echo "Earlier backups in $OUT_DIR:"; printf '%s\n' "$old" | sed 's/^/  /'; }
exit 0
