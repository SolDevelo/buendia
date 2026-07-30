---
name: pilot-usb
description: Stage a Buendia field-pilot install USB — the bootstrap script, the deployment bundle, the per-site .env and the tablet APK payload — so a bare Ubuntu box becomes a working server with one command. Use when preparing a stick for a server install or a staging run, when asked to "make the USB", or when a server has to be (re)installed somewhere with no repo access.
---

# Stage an install USB

The target box gets **no git clone** — only a 36 KB bundle of what actually runs. Deciding what
travels is the whole job; the traps below are why this is a procedure and not one `cp`.

Facts (image digests, current tags, what has been validated) live in
`docs/FIELD-PILOT-PROGRESS.md` §2. Don't duplicate them here — read them there.

## What goes on the stick

| File | Required? | Source |
|---|---|---|
| `bootstrap.sh` | **yes** | `deploy/tools/bootstrap.sh` |
| `buendia-deploy-<ver>.tar.gz` + `.sha256` | **yes** | `deploy/tools/make-bundle.sh` |
| `buendia.env` | **yes** | hand-written per site from `deploy/.env.example` |
| `pkgserver-www-<site>-<ver>.tar.gz` + `.sha256` | recommended | `pkgserver/publish.sh && pkgserver/pack-www.sh` |
| `install-qr-<ip>.png` | optional | `pkgserver/www/install-qr.png` — handy before the box is up |
| `token.txt` | only if the payload is *not* on the stick | a fine-grained, read-only GitHub PAT |

## Sequence

```bash
cd deploy
tools/make-bundle.sh                  # rebuild so its version matches HEAD (it embeds git describe)
#   -> buendia-deploy-<ver>.tar.gz (+ .sha256), ~36 KB, git-ignored

D=/media/<user>/<STICK>
cp tools/bootstrap.sh buendia-deploy-*.tar.gz buendia-deploy-*.tar.gz.sha256 "$D/"
cp pkgserver/pkgserver-www-<the-right-one>.tar.gz{,.sha256} "$D/"
cp pkgserver/www/install-qr.png "$D/install-qr-<ip>.png"
$EDITOR "$D/buendia.env"              # see "the .env" below
sync

cd "$D" && sha256sum -c ./*.sha256    # verify ON THE STICK, not on the build machine
```

Then on the target: `sudo ./bootstrap.sh --dry-run`, read it, then `sudo ./bootstrap.sh`.

## Traps

1. **Exactly ONE bundle and ONE payload may be on the stick.** `bootstrap.sh` now refuses an
   ambiguous stick, but the underlying mistake is easy: build machines accumulate payloads for
   several addresses, and copying two means the wrong one could ship. The APK bakes in a server
   address, so the wrong payload installs cleanly and then never reaches the server.
2. **`buendia.env`'s `STATIC_IP` must equal the address baked into the payload's APK.** Check it —
   `pack-www.sh` prints the baked server, and `apk/build-apk.sh` reads it back out of the APK. A
   mismatch is recoverable (cog → Settings on each tablet) but costs a visit to every device.
3. **The stick carries secrets.** `buendia.env` holds the database passwords, and the payload
   contains the APK, which carries the server password as a readable string resource. Treat the
   stick as a credential: don't leave it as the long-term copy, and `shred -u token.txt` once setup
   has run.
4. **Verify checksums *on the stick*.** A truncated write to removable media is a real failure mode
   and `bootstrap.sh`'s own check would then abort halfway through an install instead of before it.
5. **Never put `.env` inside the bundle.** `make-bundle.sh` fails the build if it finds one — the
   bundle is publishable, the `.env` is per-site and secret.

## The .env

Start from `deploy/.env.example`; the values that matter per site are `SITE_ID`, `STATIC_IP`, the
image digests, the DB passwords, and the `APK_RELEASE_*` coordinates. Keep `TZ=UTC` — the tablet
already displays device-local time, and UTC end-to-end fixed an earlier bug (**A9**).

For a first install on hardware you don't want to disturb, set `CONFIGURE_NETWORK=false` and give
the box its address by a DHCP reservation instead. `CONFIGURE_NETWORK=true` over WiFi generates a
netplan `wifis:` block, which **has never been applied on real hardware** — don't debug that on the
same run as an install.

## If the box has internet and you'd rather not carry the bundle

Publish it as a release asset on the **public** repo (it holds no secrets) and set `BUNDLE_URL`;
`bootstrap.sh` downloads and checksum-verifies it. The APK payload stays **private** either way.
