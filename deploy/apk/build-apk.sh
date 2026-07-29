#!/usr/bin/env bash
#
# Build the field-pilot Buendia APK (WS-4). Run from anywhere.
#
#   ./build-apk.sh --make-keystore   # ONE-TIME: create the pilot signing key (see README.md)
#   ./build-apk.sh                   # release-signed APK -> deploy/apk/buendia-client-<version>.apk
#   ./build-apk.sh --debug           # debug-signed APK (app id ...client.dev) for lab use only
#   ./build-apk.sh --clean           # gradle clean first (slow; use when a build looks stale)
#
# Configuration comes from deploy/.env (git-ignored). Every value has a default, so a bare
# ./build-apk.sh always produces an installable APK; see .env.example for the APK_* block.
# An exported variable overrides .env, e.g. APK_VERSION=1.1.0 ./build-apk.sh
#
# The client/ submodule is NEVER modified: all configuration is passed as gradle -P properties.
# Release signing goes through build.gradle's CI branch (ANDROID_KEYSTORE_FILE/PASSWORD env vars),
# which is the only headless path — the non-CI branch prompts on a console for the passphrase.
#
set -euo pipefail

APK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$(cd "$APK_DIR/.." && pwd)"
REPO_ROOT="$(cd "$DEPLOY_DIR/.." && pwd)"
CLIENT_DIR="$REPO_ROOT/client"

DO_KEYSTORE=false
DO_CLEAN=false
BUILD_TYPE=release
for arg in "$@"; do
  case "$arg" in
    --make-keystore) DO_KEYSTORE=true ;;
    --debug)         BUILD_TYPE=debug ;;
    --clean)         DO_CLEAN=true ;;
    -h|--help)       tail -n +2 "$0" | grep '^#' | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "ERROR: unknown argument '$arg' (try --help)" >&2; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Configuration: deploy/.env, then defaults.
# ---------------------------------------------------------------------------
if [[ -f "$DEPLOY_DIR/.env" ]]; then
  # An explicitly-exported variable must beat the file (same precedence as docker compose),
  # so that `APK_VERSION=1.2.0 ./build-apk.sh` works for a one-off build. Snapshot the
  # relevant vars, source the file, then put the snapshot back on top.
  preset="$(export -p | grep -E '^(declare -x |export )(APK_[A-Z_]+|STATIC_IP)=' || true)"
  set -a; # shellcheck disable=SC1091
  source "$DEPLOY_DIR/.env"; set +a
  eval "$preset"
fi

# The server address baked into the APK as the default preference. Falls back to the
# server's own static IP from the same .env, so the two can't drift apart.
APK_SERVER="${APK_SERVER:-${STATIC_IP:-192.168.8.10}}"
APK_VERSION="${APK_VERSION:-1.0.0}"
APK_OPENMRS_USER="${APK_OPENMRS_USER:-buendia}"
APK_OPENMRS_PASSWORD="${APK_OPENMRS_PASSWORD:-buendia}"
APK_ENCRYPTION_PASSWORD="${APK_ENCRYPTION_PASSWORD:-}"
APK_NON_WIFI_ALLOWED="${APK_NON_WIFI_ALLOWED:-false}"
APK_STARTING_PATIENT_ID="${APK_STARTING_PATIENT_ID:-}"
# The stock 10 s update-check poll hammers a package server that the pilot may not even run.
APK_CHECK_INTERVAL="${APK_CHECK_INTERVAL:-3600}"
# Auto-logout idle limits (client drc-pilot branch makes these build-configurable).
APK_IDLE_LOGOUT_SECONDS="${APK_IDLE_LOGOUT_SECONDS:-600}"
APK_DOCKED_IDLE_LOGOUT_SECONDS="${APK_DOCKED_IDLE_LOGOUT_SECONDS:-300}"
APK_KEYSTORE="${APK_KEYSTORE:-$APK_DIR/keystore/buendia-pilot.jks}"
APK_KEYSTORE_PASSWORD="${APK_KEYSTORE_PASSWORD:-}"
APK_KEYSTORE_DNAME="${APK_KEYSTORE_DNAME:-CN=Project Buendia Field Pilot, O=SolDevelo, C=PL}"

# ---------------------------------------------------------------------------
# Toolchain preflight. JDK 8 and an Android SDK with API 28 + build-tools are required;
# ANDROID_HOME is usually unset on a dev box even when the SDK is present.
# ---------------------------------------------------------------------------
ANDROID_SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"
[[ -d "$ANDROID_SDK/platforms/android-28" ]] || {
  echo "ERROR: Android SDK platform 28 not found under $ANDROID_SDK" >&2
  echo "       Set ANDROID_HOME, or install it: sdkmanager 'platforms;android-28'" >&2
  exit 1; }
export ANDROID_HOME="$ANDROID_SDK" ANDROID_SDK_ROOT="$ANDROID_SDK"

# Pick a build-tools dir that still ships aapt (used below to read back and verify what we
# built). Prefer 28.0.3 to match compileSdkVersion; fall back to the newest that has it.
BT="$ANDROID_SDK/build-tools/28.0.3"
[[ -x "$BT/aapt" ]] || BT="$(ls -1d "$ANDROID_SDK"/build-tools/*/ 2>/dev/null \
  | while read -r d; do [[ -x "$d/aapt" ]] && echo "$d"; done | sort -V | tail -1)"

JAVA_MAJOR="$(java -version 2>&1 | sed -n '1s/.*"1\.\([0-9]*\).*/\1/p;1s/.*"\([0-9]*\)\..*/\1/p' | head -1)"
[[ "$JAVA_MAJOR" == "8" ]] || {
  echo "WARNING: java is major version '$JAVA_MAJOR'; this build is verified on JDK 8." >&2
  echo "         Android Gradle Plugin 3.2.1 / Gradle 4.6 do not work on JDK 11+." >&2; }

[[ -d "$CLIENT_DIR/app" ]] || {
  echo "ERROR: client/ submodule not checked out. Run: git submodule update --init client" >&2
  exit 1; }

# ---------------------------------------------------------------------------
# --make-keystore: one-time creation of the pilot signing key.
#
# This key IS the app's identity: Android only accepts an update whose signature matches
# the installed one. Lose it and every tablet must be wiped and reinstalled. Back it up
# out-of-band (password manager / sealed envelope) — it is git-ignored on purpose.
# ---------------------------------------------------------------------------
if $DO_KEYSTORE; then
  [[ -n "$APK_KEYSTORE_PASSWORD" ]] || {
    echo "ERROR: set APK_KEYSTORE_PASSWORD in $DEPLOY_DIR/.env before --make-keystore" >&2; exit 1; }
  [[ -e "$APK_KEYSTORE" ]] && {
    echo "ERROR: $APK_KEYSTORE already exists — refusing to overwrite the signing key." >&2
    echo "       Delete it deliberately (and re-install every tablet) if you really mean to." >&2
    exit 1; }
  mkdir -p "$(dirname "$APK_KEYSTORE")"
  echo "==> Creating pilot signing key: $APK_KEYSTORE"
  # alias must be 'buendia': client/app/build.gradle hardcodes keyAlias 'buendia'.
  # 30 years validity: an APK must not stop being installable mid-deployment.
  keytool -genkeypair -keystore "$APK_KEYSTORE" -storetype JKS -alias buendia \
    -keyalg RSA -keysize 2048 -validity 10950 \
    -storepass "$APK_KEYSTORE_PASSWORD" -keypass "$APK_KEYSTORE_PASSWORD" \
    -dname "$APK_KEYSTORE_DNAME" 2>&1 \
    | grep -v -e '^Warning:$' -e 'proprietary format' -e '^$' || true
  chmod 600 "$APK_KEYSTORE"
  echo "    Created. BACK THIS UP: losing it means no more in-place APK updates."
  echo "    Fingerprint (record it — it identifies every APK you sign with this key):"
  keytool -list -v -keystore "$APK_KEYSTORE" -storepass "$APK_KEYSTORE_PASSWORD" \
    2>/dev/null | sed -n 's/^[[:space:]]*\(SHA256:.*\)/      \1/p'
  exit 0
fi

# ---------------------------------------------------------------------------
# Build preflight
# ---------------------------------------------------------------------------
if [[ "$BUILD_TYPE" == release ]]; then
  [[ -s "$APK_KEYSTORE" ]] || {
    echo "ERROR: signing key $APK_KEYSTORE missing. Create it once: $0 --make-keystore" >&2
    echo "       (or build an unsigned lab APK with: $0 --debug)" >&2; exit 1; }
  [[ -n "$APK_KEYSTORE_PASSWORD" ]] || {
    echo "ERROR: APK_KEYSTORE_PASSWORD not set in $DEPLOY_DIR/.env" >&2; exit 1; }
fi

# The in-app updater parses the version with LexicographicVersion, which requires every
# dot-separated component to be an integer; anything else silently degrades the installed
# version to "0" so the app treats every published APK as an upgrade.
[[ "$APK_VERSION" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] || {
  echo "ERROR: APK_VERSION='$APK_VERSION' must be 1-3 dot-separated integers (e.g. 1.0.0)." >&2
  exit 1; }

if [[ -z "$APK_ENCRYPTION_PASSWORD" ]]; then
  echo "WARNING: APK_ENCRYPTION_PASSWORD is empty — the tablet's SQLite database of patient"
  echo "         data will be UNENCRYPTED. Acceptable in the lab; set it before real patients."
fi

GIT_SHA="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo nogit)"
CLIENT_DESC="$(git -C "$CLIENT_DIR" describe --tags --always --dirty 2>/dev/null || echo unknown)"

echo "==> Building $BUILD_TYPE APK"
echo "    client:            $CLIENT_DESC"
echo "    server (baked in): $APK_SERVER  (OpenMRS :9000, package server :9001)"
echo "    version:           $APK_VERSION"
echo "    OpenMRS user:      $APK_OPENMRS_USER"
echo "    DB encryption:     $([[ -n "$APK_ENCRYPTION_PASSWORD" ]] && echo enabled || echo 'DISABLED')"
echo "    non-wifi allowed:  $APK_NON_WIFI_ALLOWED"
echo "    idle logout:       ${APK_IDLE_LOGOUT_SECONDS}s on battery, ${APK_DOCKED_IDLE_LOGOUT_SECONDS}s while charging"

GRADLE_ARGS=(
  "-Pserver=$APK_SERVER"
  "-PopenmrsUser=$APK_OPENMRS_USER"
  "-PopenmrsPassword=$APK_OPENMRS_PASSWORD"
  "-PencryptionPassword=$APK_ENCRYPTION_PASSWORD"
  "-PnonWifiAllowed=$APK_NON_WIFI_ALLOWED"
  "-PapkCheckInterval=$APK_CHECK_INTERVAL"
  "-PidleLogoutSeconds=$APK_IDLE_LOGOUT_SECONDS"
  "-PdockedIdleLogoutSeconds=$APK_DOCKED_IDLE_LOGOUT_SECONDS"
)
[[ -n "$APK_STARTING_PATIENT_ID" ]] && GRADLE_ARGS+=("-PstartingPatientId=$APK_STARTING_PATIENT_ID")

if [[ "$BUILD_TYPE" == release ]]; then
  # -PversionNumber also flips the app name from 'Buendia dev' to 'Buendia' and sets a
  # real versionCode, which the in-app updater compares (a debug build is always 0).
  GRADLE_ARGS+=("-PversionNumber=$APK_VERSION")
  TASK=:app:assembleRelease
  BUILT_APK="$CLIENT_DIR/app/build/outputs/apk/release/app-release.apk"
  # CI=1 selects build.gradle's env-var signing branch instead of the interactive prompt.
  export CI=1
  export ANDROID_KEYSTORE_FILE="$APK_KEYSTORE"
  export ANDROID_KEYSTORE_PASSWORD="$APK_KEYSTORE_PASSWORD"
else
  TASK=:app:assembleDebug
  BUILT_APK="$CLIENT_DIR/app/build/outputs/apk/debug/app-debug.apk"
fi

cd "$CLIENT_DIR"
$DO_CLEAN && ./gradlew --no-daemon clean
# --no-daemon: the daemon caches -P properties across builds, which silently produces an
# APK configured for a previous run's server address.
./gradlew --no-daemon "$TASK" "${GRADLE_ARGS[@]}"

[[ -s "$BUILT_APK" ]] || { echo "ERROR: expected APK not produced at $BUILT_APK" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Publish into deploy/apk/.
#
# Release APKs are named buendia-client-<version>.apk: that is exactly the
# `<module>-<version>.apk` form buendia-pkgserver-index-apks requires to build the
# buendia-client.json index the app fetches, so the file can be dropped straight onto a
# package server. The git sha goes in the .buildinfo, not the name, because a name with an
# extra `-sha` would be parsed as version="sha" and skipped by the indexer.
#
# build.gradle normalizes the version (it strips trailing '.0', so 1.0.0 becomes '1'), so
# read the real versionName back out of the APK rather than assuming APK_VERSION.
# ---------------------------------------------------------------------------
REAL_VERSION="$APK_VERSION"
if [[ -x "$BT/aapt" ]]; then
  REAL_VERSION="$("$BT/aapt" dump badging "$BUILT_APK" \
    | sed -n "1s/.*versionName='\([^']*\)'.*/\1/p")"
fi
if [[ "$BUILD_TYPE" == release ]]; then
  OUT="$APK_DIR/buendia-client-$REAL_VERSION.apk"
else
  # Debug builds have versionName 'dev', which the updater cannot parse; keep them clearly
  # out of the indexable namespace.
  OUT="$APK_DIR/buendia-client-dev-$GIT_SHA-debug.apk"
fi
cp "$BUILT_APK" "$OUT"
( cd "$APK_DIR" && sha256sum "$(basename "$OUT")" > "$(basename "$OUT").sha256" )

# Record how it was built, so a deployed tablet can be traced back to a source state.
# Deliberately records only whether secrets were set, never their values.
cat > "${OUT%.apk}.buildinfo.txt" <<EOF
Buendia field-pilot APK
  built from repo:        $GIT_SHA
  client submodule:       $CLIENT_DESC
  build type:             $BUILD_TYPE
  version requested:      $APK_VERSION
  version in APK:         $REAL_VERSION
  server baked in:        $APK_SERVER
  OpenMRS user:           $APK_OPENMRS_USER
  OpenMRS password set:   $([[ -n "$APK_OPENMRS_PASSWORD" ]] && echo yes || echo no)
  DB encryption:          $([[ -n "$APK_ENCRYPTION_PASSWORD" ]] && echo enabled || echo DISABLED)
  non-wifi allowed:       $APK_NON_WIFI_ALLOWED
  update-check interval:  ${APK_CHECK_INTERVAL}s
  idle logout:            ${APK_IDLE_LOGOUT_SECONDS}s on battery / ${APK_DOCKED_IDLE_LOGOUT_SECONDS}s charging
  starting patient id:    ${APK_STARTING_PATIENT_ID:-(none)}
  sha256:                 $(cut -d' ' -f1 < "$OUT.sha256")
EOF

echo
echo "==> Built: $OUT"

# ---------------------------------------------------------------------------
# Verify what we actually produced (cheap, catches misconfiguration before the field).
# ---------------------------------------------------------------------------
if [[ -x "$BT/aapt" ]]; then
  echo "    $("$BT/aapt" dump badging "$OUT" | sed -n "s/^package: //p")"
  echo "    baked-in defaults read back out of the APK:"
  # Values live on the line AFTER the "resource ...:string/<name>:" line (the "spec resource"
  # lines earlier in the dump carry no value, hence the leading space in the pattern).
  "$BT/aapt" dump --values resources "$OUT" 2>/dev/null \
    | grep -A1 -E ' resource .*:string/(openmrs_root_url_default|package_server_root_url_default|openmrs_user_default):' \
    | sed -n 's/^ *(string8) "\(.*\)"$/      \1/p' | sort -u
fi
if [[ "$BUILD_TYPE" == release && -x "$BT/apksigner" ]]; then
  "$BT/apksigner" verify --print-certs "$OUT" | sed -n 's/^\(.*SHA-256 digest:.*\)/    \1/p' | head -2
fi

echo
echo "Install on a tablet (USB debugging on, then):"
echo "    adb install -r $OUT"
echo "Or copy the .apk to the tablet and tap it (needs 'install unknown apps' for the file manager)."
