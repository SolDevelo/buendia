#!/usr/bin/env bash
#
# Generate the printable in-zone tablet install card (plan §3.4 / WS-5).
#
#   ./make-install-card.sh            # -> cards/install-card.html + the two QR PNGs
#
# One laminated card is posted in each zone, INCLUDING the Red Zone, so a reset or
# replacement tablet is re-provisioned in place without carrying it across a contamination
# boundary. It carries two QR codes:
#
#   1. JOIN WI-FI   — Android/iOS join the network directly from this QR, so nobody has to
#                     type the passphrase while gloved.
#   2. INSTALL APP  — the stable http://<server>:<port>/latest.apk URL.
#
# Print the HTML from a browser (Ctrl+P -> Save as PDF, or straight to paper), then laminate.
# There is deliberately no pandoc/LaTeX dependency: a browser is always available at staging
# and produces a better result than a Markdown-to-PDF chain.
#
# The card is written to cards/ and NOT into www/, because it carries the Wi-Fi passphrase and
# www/ is served to anyone who can reach the LAN.
#
set -euo pipefail

PKG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$(cd "$PKG_DIR/.." && pwd)"
OUT_DIR="$PKG_DIR/cards"

if [[ -f "$DEPLOY_DIR/.env" ]]; then
  preset="$(export -p | grep -E '^(declare -x |export )(APK_[A-Z_]+|STATIC_IP|PKGSERVER_PORT|SITE_[A-Z_]+)=' || true)"
  set -a; # shellcheck disable=SC1091
  source "$DEPLOY_DIR/.env"; set +a
  eval "$preset"
fi

SERVER="${APK_SERVER:-${STATIC_IP:-192.168.8.10}}"
PORT="${PKGSERVER_PORT:-9001}"
APK_URL="http://$SERVER:$PORT/latest.apk"
SSID="${SITE_WIFI_SSID:-}"
WIFI_PASS="${SITE_WIFI_PASSWORD:-}"
FACILITY="${SITE_FACILITY_NAME:-Buendia}"
ZONE="${1:-}"   # optional: print a zone name on the card, e.g. ./make-install-card.sh "Suspect Zone"

mkdir -p "$OUT_DIR"

if [[ -z "$SSID" ]]; then
  echo "WARNING: SITE_WIFI_SSID is not set in $DEPLOY_DIR/.env — the card will show a blank"
  echo "         network name and no join-QR. Set SITE_WIFI_SSID / SITE_WIFI_PASSWORD at staging,"
  echo "         once the router is configured, and re-run."
fi

# ---------------------------------------------------------------------------
# QR codes. segno is pure Python (pip install --user segno); qrencode also works.
# ---------------------------------------------------------------------------
python3 - "$OUT_DIR" "$APK_URL" "$SSID" "$WIFI_PASS" <<'PY'
import sys, os
out_dir, apk_url, ssid, wifi_pass = sys.argv[1:5]
try:
    import segno
except ImportError:
    sys.exit("ERROR: need a QR generator: python3 -m pip install --user segno")

def save(data, name):
    segno.make(data, micro=False, error='m').save(
        os.path.join(out_dir, name), scale=10, border=2)

save(apk_url, 'install-qr.png')

if ssid:
    # WIFI: URI scheme understood by the Android and iOS camera/QR scanners.
    # ; , : \ and " are the reserved characters and must be backslash-escaped.
    def esc(s):
        for ch in ('\\', ';', ',', ':', '"'):
            s = s.replace(ch, '\\' + ch)
        return s
    auth = 'WPA' if wifi_pass else 'nopass'
    save('WIFI:T:%s;S:%s;P:%s;;' % (auth, esc(ssid), esc(wifi_pass)), 'wifi-qr.png')
    print('  wrote install-qr.png and wifi-qr.png')
else:
    print('  wrote install-qr.png (no wifi-qr.png: SITE_WIFI_SSID unset)')
PY

# ---------------------------------------------------------------------------
# Print-ready card. QR images are embedded as data: URIs so the HTML is a single
# self-contained file that prints correctly from any machine, online or not.
# ---------------------------------------------------------------------------
python3 - "$OUT_DIR" "$APK_URL" "$SSID" "$WIFI_PASS" "$FACILITY" "$ZONE" <<'PY'
import base64, os, sys, html
out_dir, apk_url, ssid, wifi_pass, facility, zone = sys.argv[1:7]

def data_uri(name):
    p = os.path.join(out_dir, name)
    if not os.path.exists(p):
        return None
    return 'data:image/png;base64,' + base64.b64encode(open(p, 'rb').read()).decode()

install_qr = data_uri('install-qr.png')
wifi_qr = data_uri('wifi-qr.png')
e = html.escape

wifi_block = ''
if ssid:
    img = ('<img src="%s" alt="Wi-Fi join QR">' % wifi_qr) if wifi_qr else ''
    wifi_block = """
  <section>
    <div class="num">1</div>
    <div class="body">
      <h2>Join the Wi-Fi</h2>
      <p>Scan with the tablet camera &mdash; it joins automatically.</p>
      <dl><dt>Network</dt><dd>%s</dd><dt>Password</dt><dd>%s</dd></dl>
    </div>
    <div class="qr">%s</div>
  </section>""" % (e(ssid), e(wifi_pass) or '(none)', img)
else:
    wifi_block = """
  <section>
    <div class="num">1</div>
    <div class="body">
      <h2>Join the Wi-Fi</h2>
      <dl><dt>Network</dt><dd class="blank">&nbsp;</dd><dt>Password</dt><dd class="blank">&nbsp;</dd></dl>
      <p class="warn">Fill in before laminating (SITE_WIFI_SSID was not configured).</p>
    </div>
    <div class="qr"></div>
  </section>"""

zone_label = ('<span class="zone">%s</span>' % e(zone)) if zone else ''
install_img = ('<img src="%s" alt="Install QR">' % install_qr) if install_qr else ''

doc = """<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<title>Buendia tablet install card</title>
<style>
  @page { size: A5 portrait; margin: 10mm; }
  * { box-sizing: border-box; }
  body { font-family: system-ui, -apple-system, "Segoe UI", sans-serif; margin: 0;
         color: #10192e; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  .card { width: 128mm; margin: 0 auto; padding: 6mm 0; }
  header { border-bottom: 3px solid #10192e; padding-bottom: 3mm; margin-bottom: 4mm; }
  h1 { font-size: 17pt; margin: 0 0 1mm; letter-spacing: -.2pt; }
  .sub { font-size: 9pt; color: #4a5568; }
  .zone { display: inline-block; margin-left: 2mm; padding: .5mm 2mm; font-size: 9pt;
          font-weight: 600; background: #10192e; color: #fff; border-radius: 2mm;
          vertical-align: 2px; }
  section { display: flex; gap: 4mm; align-items: flex-start;
            padding: 4mm 0; border-bottom: 1px solid #d5dae4; }
  section:last-of-type { border-bottom: 0; }
  .num { flex: 0 0 8mm; height: 8mm; border-radius: 50%%; background: #10192e; color: #fff;
         font-weight: 700; font-size: 12pt; display: flex; align-items: center;
         justify-content: center; }
  .body { flex: 1 1 auto; }
  .body h2 { font-size: 12pt; margin: 0 0 1.5mm; }
  .body p { font-size: 9.5pt; margin: 0 0 2mm; }
  .qr { flex: 0 0 34mm; }
  .qr img { width: 34mm; height: 34mm; display: block; }
  dl { margin: 0; font-size: 10pt; }
  dt { font-weight: 600; color: #4a5568; font-size: 8.5pt; text-transform: uppercase;
       letter-spacing: .3pt; margin-top: 1.5mm; }
  dd { margin: 0; font-family: ui-monospace, "SF Mono", Menlo, monospace; font-size: 11pt; }
  dd.blank { border-bottom: 1px solid #10192e; min-width: 55mm; }
  code { font-family: ui-monospace, Menlo, monospace; font-size: 9.5pt; }
  .warn { color: #a4331f; font-weight: 600; font-size: 9pt; }
  footer { margin-top: 4mm; padding-top: 3mm; border-top: 1px solid #d5dae4;
           font-size: 8.5pt; color: #4a5568; }
  footer b { color: #10192e; }
</style></head><body>
<div class="card">
  <header>
    <h1>Install the Buendia app%(zone_label)s</h1>
    <div class="sub">%(facility)s &middot; tablet setup &mdash; no cable needed</div>
  </header>
%(wifi_block)s
  <section>
    <div class="num">2</div>
    <div class="body">
      <h2>Install the app</h2>
      <p>Scan, download, then open the downloaded file.
         Android asks once for permission to install &mdash; <b>allow it</b>.</p>
      <dl><dt>Or type this address</dt><dd>%(apk_url)s</dd></dl>
    </div>
    <div class="qr">%(install_img)s</div>
  </section>
  <section>
    <div class="num">3</div>
    <div class="body">
      <h2>Open Buendia and pick your name</h2>
      <p>The server is already configured &mdash; change nothing in Settings.
         The patient list fills in by itself.</p>
    </div>
    <div class="qr"></div>
  </section>
  <footer>
    <b>Replacing a tablet?</b> Nothing is lost. The tablet only holds a copy; the record lives
    on the server and syncs back after you log in.<br>
    <b>Not working?</b> Check the tablet is on the network above, then tell the site focal point.
  </footer>
</div>
</body></html>
""" % dict(zone_label=zone_label, facility=e(facility), wifi_block=wifi_block,
           apk_url=e(apk_url), install_img=install_img)

path = os.path.join(out_dir, 'install-card.html')
open(path, 'w').write(doc)
print('  wrote %s' % path)
PY

cat <<EOF

==> Install card ready: $OUT_DIR/install-card.html
    Print it:  open in a browser -> Ctrl+P -> A5 -> Save as PDF or print, then LAMINATE.
    Post one in EVERY zone, including the Red Zone (plan §3.4) — that is the whole point:
    a tablet is re-provisioned in place, without crossing a contamination boundary.

    Per-zone copies:  ./make-install-card.sh "Suspect Zone"
EOF
