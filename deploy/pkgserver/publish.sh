#!/usr/bin/env bash
#
# Publish a built APK to the on-site package server, so a tablet can install it by
# scanning a QR code. Run from anywhere, after deploy/apk/build-apk.sh.
#
#   ./publish.sh                       # publish the newest release APK from ../apk/
#   ./publish.sh ../apk/buendia-client-1.apk    # publish a specific file
#   ./publish.sh --qr-only             # just re-print the QR/URL for what's already published
#
# Populates pkgserver/www/, which the compose `pkgserver` service serves on :9001:
#
#   /                       landing page (install button + what's published)
#   /latest.apk             STABLE url — this is what the QR code encodes
#   /buendia-client-<v>.apk the version-named copy (package-index convention)
#   /buendia-client.json    update index the app polls
#   /dists/stable/Release   stub that satisfies the app's package-server health check
#
set -euo pipefail

PKG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$(cd "$PKG_DIR/.." && pwd)"
WWW="$PKG_DIR/www"

QR_ONLY=false
APK_ARG=""
for arg in "$@"; do
  case "$arg" in
    --qr-only) QR_ONLY=true ;;
    -h|--help) tail -n +2 "$0" | grep '^#' | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "ERROR: unknown argument '$arg' (try --help)" >&2; exit 1 ;;
    *)  APK_ARG="$arg" ;;
  esac
done

if [[ -f "$DEPLOY_DIR/.env" ]]; then
  preset="$(export -p | grep -E '^(declare -x |export )(APK_[A-Z_]+|STATIC_IP|PKGSERVER_PORT)=' || true)"
  set -a; # shellcheck disable=SC1091
  source "$DEPLOY_DIR/.env"; set +a
  eval "$preset"
fi
# The URL the tablet will use. Must be the address the tablet can reach on the site LAN —
# the same one baked into the APK, hence the shared default.
SERVER="${APK_SERVER:-${STATIC_IP:-192.168.8.10}}"
PORT="${PKGSERVER_PORT:-9001}"
BASE_URL="http://$SERVER:$PORT"

mkdir -p "$WWW/dists/stable"

if ! $QR_ONLY; then
  # -------------------------------------------------------------------------
  # Pick the APK to publish.
  # -------------------------------------------------------------------------
  if [[ -n "$APK_ARG" ]]; then
    APK="$APK_ARG"
    [[ -s "$APK" ]] || { echo "ERROR: $APK not found" >&2; exit 1; }
  else
    # Newest release APK. Debug builds are excluded deliberately: their versionName is
    # 'dev', which the updater cannot parse, and they install under a different app id.
    APK="$(ls -1t "$DEPLOY_DIR"/apk/buendia-client-*.apk 2>/dev/null \
      | grep -v -- '-debug\.apk$' | head -1 || true)"
    [[ -n "$APK" ]] || {
      echo "ERROR: no release APK in $DEPLOY_DIR/apk/. Build one first:" >&2
      echo "         cd $DEPLOY_DIR/apk && ./build-apk.sh" >&2; exit 1; }
  fi
  APK_NAME="$(basename "$APK")"
  # Version = whatever is between the module prefix and .apk, per the package-index convention.
  VERSION="${APK_NAME#buendia-client-}"; VERSION="${VERSION%.apk}"
  [[ "$VERSION" =~ ^[0-9]+(\.[0-9]+)*$ ]] || {
    echo "ERROR: cannot read a numeric version out of '$APK_NAME'." >&2
    echo "       Expected buendia-client-<version>.apk as produced by apk/build-apk.sh." >&2; exit 1; }

  echo "==> Publishing $APK_NAME (version $VERSION) to $WWW"
  # Clear out APKs from previous publishes so the directory listing can't offer a stale build.
  rm -f "$WWW"/buendia-client-*.apk "$WWW"/latest.apk
  install -m 644 "$APK" "$WWW/$APK_NAME"
  # A plain copy, not a symlink: the www dir is bind-mounted read-only into the container,
  # and a symlink pointing outside the mount would not resolve.
  install -m 644 "$APK" "$WWW/latest.apk"

  # -------------------------------------------------------------------------
  # Update index. Deliberately advertises ONLY the version we just published, so that
  # shouldUpdate() (availableVersion > currentVersion) is false for a tablet already
  # running it and clinicians get no update prompt. That matters because the in-app
  # download is broken on this client (see apk/README.md) — a prompt would lead nowhere.
  # -------------------------------------------------------------------------
  cat > "$WWW/buendia-client.json" <<EOF
[
  {
    "version": "$VERSION",
    "url": "$BASE_URL/$APK_NAME"
  }
]
EOF

  # Stub Debian-repo Release file: PackageServerHealthCheck only checks that this returns
  # 200, and treats a 404 as a misconfigured package server (snackbar on the tablet).
  cat > "$WWW/dists/stable/Release" <<EOF
Origin: Buendia field pilot
Label: buendia
Suite: stable
Codename: stable
Architectures: all
Components: main
Description: Placeholder Release file. This pilot serves APKs directly, not a Debian
 archive; the file exists because the Android client health-checks this path.
EOF

  SHA="$(sha256sum "$WWW/latest.apk" | cut -d' ' -f1)"
  # -------------------------------------------------------------------------
  # Landing page. Kept deliberately plain: it is opened on a phone/tablet browser over a
  # LAN with no internet, so no external CSS, fonts or scripts.
  # -------------------------------------------------------------------------
  cat > "$WWW/index.html" <<EOF
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Install Buendia</title>
<style>
  body { font-family: system-ui, -apple-system, sans-serif; margin: 0; padding: 1.5rem;
         line-height: 1.5; color: #14203a; background: #f4f6fb; }
  main { max-width: 34rem; margin: 0 auto; }
  h1 { font-size: 1.5rem; margin: 0 0 1rem; }
  a.install { display: block; text-align: center; text-decoration: none; font-size: 1.25rem;
              font-weight: 600; color: #fff; background: #1d4ed8; padding: 1rem;
              border-radius: .5rem; margin: 1.5rem 0; }
  ol { padding-left: 1.25rem; }
  dl { background: #fff; border-radius: .5rem; padding: 1rem; margin: 1.5rem 0; }
  dt { font-weight: 600; margin-top: .5rem; }
  dd { margin: 0 0 .25rem; font-family: ui-monospace, monospace; font-size: .85rem;
       word-break: break-all; }
</style>
</head>
<body>
<main>
  <h1>Install the Buendia app</h1>

  <a class="install" href="/latest.apk">Download Buendia $VERSION</a>

  <ol>
    <li>Tap the button above. The browser will warn you about the file type &mdash; accept it.</li>
    <li>Open the downloaded file. Android will ask permission to install from the browser;
        allow it for this install.</li>
    <li>Open <strong>Buendia</strong>. The server is already configured &mdash; no settings to change.</li>
  </ol>

  <dl>
    <dt>Version</dt><dd>$VERSION</dd>
    <dt>File</dt><dd>$APK_NAME</dd>
    <dt>SHA-256</dt><dd>$SHA</dd>
    <dt>Server</dt><dd>$BASE_URL</dd>
  </dl>
</main>
</body>
</html>
EOF
  echo "    published: latest.apk, $APK_NAME, buendia-client.json, dists/stable/Release, index.html"
fi

# ---------------------------------------------------------------------------
# QR code for first install.
# ---------------------------------------------------------------------------
QR_URL="$BASE_URL/latest.apk"
echo
echo "==> QR target: $QR_URL"

if command -v qrencode >/dev/null; then
  qrencode -o "$WWW/install-qr.png" -s 8 -m 2 "$QR_URL"
  echo "    wrote $WWW/install-qr.png  (also at $BASE_URL/install-qr.png — print it for the ward)"
  echo
  qrencode -t ANSIUTF8 "$QR_URL"
elif python3 -c 'import segno' 2>/dev/null; then
  # segno is pure Python (no Pillow, no system package), so it installs without root:
  #   python3 -m pip install --user segno
  python3 - "$QR_URL" "$WWW/install-qr.png" <<'PY'
import sys, segno
url, png = sys.argv[1], sys.argv[2]
qr = segno.make(url, micro=False, error='m')
qr.save(png, scale=8, border=2)
qr.terminal(compact=True)
PY
  echo "    wrote $WWW/install-qr.png (via python3 segno)"
elif python3 -c 'import qrcode' 2>/dev/null; then
  python3 -c "import qrcode,sys; qrcode.make(sys.argv[1]).save(sys.argv[2])" \
    "$QR_URL" "$WWW/install-qr.png"
  echo "    wrote $WWW/install-qr.png (via python3 qrcode)"
else
  echo "    No QR generator found, so no image was written. Install either:"
  echo "        python3 -m pip install --user segno    # pure Python, no root needed"
  echo "        sudo apt install qrencode"
  echo "    then re-run: $0 --qr-only"
  echo "    Or encode the URL above with any QR tool — the URL is what matters, not the image."
fi

cat <<EOF

Tablet first install:
  1. Join the site wifi, open the camera/QR scanner, scan the code (or type the URL).
  2. Download, then open the file. Android asks to allow installs from the browser —
     this is required, and is a per-app permission you can revoke afterwards.
  3. A landing page with the same link is at $BASE_URL/
EOF
