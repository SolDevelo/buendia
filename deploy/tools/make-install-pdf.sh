#!/usr/bin/env bash
# Render INSTALL-TWO-STEP.md to a PDF for the USB pack.
#
#   ./make-install-pdf.sh                    # -> ../INSTALL.pdf
#   ./make-install-pdf.sh --out /tmp/x.pdf
#
# A PDF is in the pack because the person installing may have no way to render Markdown, and a
# plain .md read in a text editor loses exactly the emphasis that matters — which command to
# type, and what each step should print.
#
# There is no pandoc on the build box (it wants root to install), so this converts the small
# subset of Markdown the guide actually uses and prints it with headless Chrome. Run it as a
# normal user: Chrome refuses to run as root.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/../INSTALL-TWO-STEP.md"
OUT="$HERE/../INSTALL.pdf"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --src) SRC="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
[[ -f "$SRC" ]] || { echo "ERROR: $SRC not found" >&2; exit 1; }

HTML="$(mktemp --suffix=.html)"; trap 'rm -f "$HTML"' EXIT
python3 - "$SRC" "$HTML" <<'PY'
import sys, html, re
src, dst = sys.argv[1], sys.argv[2]
lines = open(src, encoding='utf-8').read().split('\n')

def inline(t):
    t = html.escape(t)
    t = re.sub(r'`([^`]+)`', r'<code>\1</code>', t)
    t = re.sub(r'\*\*([^*]+)\*\*', r'<strong>\1</strong>', t)
    # single asterisks are italics; run it after bold so ** is not eaten first
    t = re.sub(r'(?<!\*)\*([^*]+)\*(?!\*)', r'<em>\1</em>', t)
    return t

out, mode, buf = [], None, []
ol_start = 1
def close():
    global mode, buf
    if mode == 'pre':
        out.append('<pre>' + '\n'.join(buf) + '</pre>')
    elif mode == 'p':
        out.append('<p>' + ' '.join(buf) + '</p>')
    elif mode == 'ol':
        # A code block between steps closes the list, so the next one must resume the numbering
        # rather than restart at 1 — the guide's steps are referred to by number.
        out.append(f'<ol start="{ol_start}">' + ''.join(buf) + '</ol>')
    elif mode == 'ul':
        out.append('<ul>' + ''.join(buf) + '</ul>')
    mode, buf = None, []

for raw in lines:
    line = raw.rstrip()
    # code: indented four or more spaces (the guide indents commands under numbered steps)
    if re.match(r'^ {4,}\S', line):
        if mode != 'pre': close(); mode = 'pre'
        buf.append(html.escape(line.strip()))
        continue
    if not line.strip():
        if mode == 'pre': buf.append('')
        else: close()
        continue
    if mode == 'pre': close()
    m = re.match(r'^(#{1,4})\s+(.*)$', line)
    if m:
        close(); out.append(f'<h{len(m.group(1))}>{inline(m.group(2))}</h{len(m.group(1))}>'); continue
    if re.match(r'^-{3,}$', line):
        close(); out.append('<hr>'); continue
    m = re.match(r'^(\d+)\.\s+(.*)$', line)
    if m:
        if mode != 'ol':
            close(); mode = 'ol'; ol_start = int(m.group(1))
        buf.append(f'<li>{inline(m.group(2))}')
        continue
    if re.match(r'^[-*]\s+', line):
        if mode != 'ul': close(); mode = 'ul'
        buf.append('<li>' + inline(re.sub(r'^[-*]\s+', '', line)))
        continue
    # a continuation line: belongs to the item or paragraph above
    if mode in ('ol', 'ul') and re.match(r'^ {1,3}\S', line):
        buf[-1] += ' ' + inline(line.strip()); continue
    if mode == 'p': buf.append(inline(line.strip()))
    else: close(); mode = 'p'; buf = [inline(line.strip())]
close()

open(dst, 'w', encoding='utf-8').write("""<!doctype html><html><head><meta charset="utf-8">
<title>Buendia server — installation</title><style>
@page { size: A4; margin: 18mm 16mm; }
body { font: 10.5pt/1.5 "DejaVu Sans", Arial, sans-serif; color:#111; max-width: 100%; }
h1 { font-size: 19pt; margin: 0 0 2mm; }
h2 { font-size: 13.5pt; margin: 7mm 0 2mm; padding-bottom: 1mm; border-bottom: 1.5pt solid #10192e; }
h3 { font-size: 11.5pt; margin: 5mm 0 1mm; }
p, li { margin: 0 0 2mm; }
ol, ul { margin: 0 0 3mm; padding-left: 8mm; }
ol > li::marker { font-weight: 700; }
li { page-break-inside: avoid; }
code { font-family: "DejaVu Sans Mono", monospace; font-size: 9.5pt;
       background: #f2f3f5; padding: 0 1mm; border-radius: 1mm; }
pre { font-family: "DejaVu Sans Mono", monospace; font-size: 9.5pt; background: #10192e;
      color: #eef; padding: 2.5mm 3mm; border-radius: 1.5mm; margin: 1.5mm 0 3mm;
      white-space: pre-wrap; page-break-inside: avoid; }
pre code { background: none; color: inherit; padding: 0; }
strong { font-weight: 700; }
hr { border: 0; border-top: .5pt solid #ccd; margin: 6mm 0; }
h1,h2,h3 { page-break-after: avoid; }
</style></head><body>
""" + '\n'.join(out) + "\n</body></html>")
print("  html built")
PY

pdf_ok=0
for c in google-chrome chromium chromium-browser google-chrome-stable; do
  command -v "$c" >/dev/null 2>&1 || continue
  tmpprof="$(mktemp -d)"
  if "$c" --headless=new --disable-gpu --no-first-run --no-pdf-header-footer \
        --user-data-dir="$tmpprof" --print-to-pdf="$OUT" "file://$HTML" >/dev/null 2>&1 \
     && [[ -s "$OUT" ]]; then pdf_ok=1; fi
  rm -rf "$tmpprof"
  [[ $pdf_ok -eq 1 ]] && break
done
if [[ $pdf_ok -eq 0 ]] && command -v wkhtmltopdf >/dev/null 2>&1; then
  wkhtmltopdf -q "$HTML" "$OUT" && pdf_ok=1
fi
if [[ $pdf_ok -eq 0 ]] && command -v weasyprint >/dev/null 2>&1; then
  weasyprint "$HTML" "$OUT" && pdf_ok=1
fi
[[ $pdf_ok -eq 1 ]] || { echo "ERROR: no working PDF renderer (tried Chrome, wkhtmltopdf, weasyprint)." >&2; exit 1; }
printf '\033[1;32m==> %s (%s)\033[0m\n' "$OUT" "$(du -h "$OUT" | awk '{print $1}')"
