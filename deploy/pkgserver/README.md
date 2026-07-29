# Package server — tablet APK install over the LAN (WS-5)

A static file server on **:9001** so a tablet can install the app by scanning a QR code,
with no USB cable, no adb and no internet. It also serves the two paths the Android client
probes on that port, which stops a spurious warning on the tablet.

```bash
cd deploy/apk       && ./build-apk.sh      # build the APK first
cd ../pkgserver     && ./publish.sh        # populate www/ + print the QR
cd ../compose       && docker compose --env-file ../.env up -d pkgserver
```

Then scan the QR (or open the URL) on the tablet:

```
http://<STATIC_IP>:9001/latest.apk
```

## What it serves

| Path | What it is |
|---|---|
| `/latest.apk` | **stable URL — this is what the QR encodes.** A copy, so the QR never changes when the version does |
| `/buendia-client-<version>.apk` | the version-named copy (the package-index naming convention) |
| `/buendia-client.json` | the update index the app polls (`PackageServer.MODULE_NAME = "buendia-client"`) |
| `/dists/stable/Release` | stub that satisfies the app's package-server health check |
| `/` | plain landing page: install button, version, SHA-256, server address |
| `/install-qr.png` | the QR image, when a generator was available at publish time |

`www/` is entirely generated — it's git-ignored, and `publish.sh` rebuilds it from a built
APK. Nothing in it should be hand-edited.

## Why this also silences a tablet warning

The client health-checks `http://<server>:9001/dists/stable/Release` and shows a *"check
package server configuration"* snackbar when it 404s. Nothing served :9001 before, so that
warning appeared in normal operation. Serving the stub removes it.

## The update index will not nag clinicians

`publish.sh` writes an index advertising **only the version it just published**. A tablet
already running that version evaluates `shouldUpdate()` as
`availableVersion.greaterThan(currentVersion)` → false, so no update prompt appears.

That is deliberate, because **the in-app update flow is broken on this client** (see
`../apk/README.md`): the download is short-circuited to a browser hit on port 80, and the
installer is handed a `file://` Uri that throws at `targetSdkVersion 24`. So:

> **If you publish an APK newer than what a tablet has, that tablet will start prompting for
> an update it cannot install.** Update tablets by re-scanning the QR (or via adb), and
> publish only what you intend people to install.

## Image choice

Default is **`nginx:alpine-slim`** — ~13 MB pulled, and it handles Range requests, so a 5 MB
download interrupted by ward wifi resumes instead of restarting. Override with
`PKGSERVER_IMAGE` in `deploy/.env` (pin by digest for production). Anything that serves
static files works; if you swap it, keep two things:

1. `.apk` must be served as `application/vnd.android.package-archive`. It is **not** in
   nginx's default `mime.types`, which is why `nginx.conf` sets it per-location. Note a
   server-level `types { }` block would *replace* the inherited MIME map, not extend it.
2. `/dists/stable/Release` must return 200.

For `--offline` staging, `docker save` the image into `deploy/images/` like the others;
`setup.sh` pulls it when online (it already honoured `PKGSERVER_IMAGE`).

## Installing on the tablet, in practice

1. Join the site wifi, scan the QR with the camera, download.
2. Open the file. **Android asks to allow installs from the browser** — this is required for
   sideloading, and is a per-app permission that can be revoked afterwards. On CrossCall
   T4/T5 (Android 9–12) it's *Settings → Apps → special access → Install unknown apps*.
3. Open **Buendia**. Server, login and all tunables are already baked into the APK.

If a debug build was installed earlier it stays alongside as a separate app ("Buendia dev",
app id `...client.dev`) — remove it so clinicians can't open the wrong one.

## Not included

No authentication and no TLS: it's plain HTTP on an isolated LAN, and it serves only a public
application binary — no patient data. Don't expose :9001 beyond the site network.
