# Field-pilot Android APK (WS-4)

Reproducible build of the Buendia tablet app, configured for the pilot server.
`build-apk.sh` is the source of truth — don't hand-run gradle.

```bash
cp ../.env.example ../.env     # then fill in the APK_* block (at minimum APK_KEYSTORE_PASSWORD)
./build-apk.sh --make-keystore # ONE-TIME: create the pilot signing key
./build-apk.sh                 # -> buendia-client-<version>.apk  (+ .sha256, + .buildinfo.txt)
./build-apk.sh --debug         # lab build: app id ...client.dev, debug-signed, coexists with release
```

Everything the tablet needs is baked in at build time (server address, login, sync and
auto-logout tunables), so a clinician installs one file and does not touch Settings.

## Toolchain

Confirmed working: **JDK 8** (Zulu 1.8.0_492), Android SDK with **platform 28** +
build-tools **28.0.3**, gradle **4.6** (via the wrapper), Android Gradle Plugin **3.2.1**.
`ANDROID_HOME` is usually unset on a dev box — the script falls back to `~/Android/Sdk`.
AGP 3.2.1 / gradle 4.6 do **not** run on JDK 11+; the script warns if `java` isn't 8.

The `client/` submodule is never modified by the build — all configuration is passed as
gradle `-P` properties. Client source changes for the pilot live on the submodule's
**`drc-pilot`** branch (`SolDevelo/buendia-client`), which the superproject's `drc-pilot`
branch pins.

## Configuration

All from `deploy/.env` (git-ignored); see `.env.example` for the annotated block. Notable:

| Variable | Default | Notes |
|---|---|---|
| `APK_SERVER` | `STATIC_IP` from `.env` | baked in as the default server preference; app derives `:9000` (OpenMRS) and `:9001` (packages) |
| `APK_VERSION` | `1.0.0` | **must be 1–3 dot-separated integers** (see *Versioning*) |
| `APK_OPENMRS_PASSWORD` | `buendia` | baked-in default credential; rotate together with the server (config request A5) |
| `APK_ENCRYPTION_PASSWORD` | *empty* | **inert on v1.0** — see below; leave empty |
| `APK_CHECK_INTERVAL` | `3600` | upstream polls the package server every **10 s**; pointless here |
| `APK_IDLE_LOGOUT_SECONDS` | `600` | auto-logout while on battery |
| `APK_DOCKED_IDLE_LOGOUT_SECONDS` | `300` | ...and while AC-charging; upstream hardcoded **30 s** |

### The signing key is the app's identity

Android only installs an update whose signature matches the installed app. Therefore:

- **Back up `keystore/buendia-pilot.jks` and its password out-of-band** (password manager /
  sealed envelope). Losing it means every tablet must be uninstalled and reinstalled — which
  **destroys any unsynced local data**.
- It is git-ignored deliberately. Never commit it.
- `--make-keystore` refuses to overwrite an existing key.
- Release signing runs through `client/app/build.gradle`'s `CI` branch
  (`ANDROID_KEYSTORE_FILE` / `ANDROID_KEYSTORE_PASSWORD`); the non-CI branch prompts on a
  console for the passphrase and so cannot be scripted.

### `APK_ENCRYPTION_PASSWORD` does nothing — don't rely on it

The gradle property exists and feeds `BuildConfig.ENCRYPTION_PASSWORD`, but **nothing in the
v1.0 client ever reads that constant**, and `sync/Database.java` extends the plain
`android.database.sqlite.SQLiteOpenHelper` — SQLCipher was removed from this codebase. So the
tablet's local database is **not** encrypted by the app whatever you set here.

Tablet data-at-rest is covered instead by **device-level Android encryption plus a mandatory
screen-lock PIN**, which is the deployment plan's locked decision. The local DB is only a sync
cache; the server holds the record. Re-adding app-level SQLCipher is a possible future change
if MSF data-protection requires it, and only then would this knob become live.

## Versioning

`build.gradle` normalizes the version by stripping trailing `.0`, so `-PversionNumber=1.0.0`
produces `versionName='1'` (and `versionCode=1000000`). The script reads the real
`versionName` back out of the built APK and names the file after it.

Output is named **`buendia-client-<version>.apk`** — exactly the `<module>-<version>.apk`
form that `buendia-pkgserver-index-apks` needs to generate the `buendia-client.json` index
the app fetches, so the file can be dropped straight onto a package server. A git sha in the
filename would be misparsed as the version, so it goes in `.buildinfo.txt` instead.

The in-app updater compares **`versionName`**, not `versionCode`, using
`LexicographicVersion` (integer components only). A non-numeric version silently degrades
the installed version to `0`, making the app treat every published APK as an upgrade — hence
the script's format check. Debug builds have `versionName='dev'` and are affected by exactly
this, which is another reason not to field them.

## Installing on a tablet

```bash
adb install -r buendia-client-<version>.apk        # USB debugging enabled
```
Or copy the `.apk` to the tablet and tap it (the file manager needs "install unknown apps").

A release build installs as `org.projectbuendia.client` ("Buendia"); a debug build installs
as `org.projectbuendia.client.dev` ("Buendia dev"). They coexist, so **remove the debug app
from pilot tablets** to avoid clinicians opening the wrong one.

## In-app OTA updates do not work (WS-5 constraint — deferred, not dropped)

Don't plan on the in-app updater for the pilot. On the v1.0 client:

- `UpdateManager.java:150-158` short-circuits the download with `if (2 > 1)` and instead
  opens `http://<server>/client` in a browser — port **80**, which the pilot stack doesn't serve.
- `UpdateManager.installUpdate()` hands Android a raw `file://` Uri; at `targetSdkVersion 24`
  that throws `FileUriExposedException`. There is no `FileProvider` and no
  `REQUEST_INSTALL_PACKAGES` permission (verified absent from all of `app/src/`, 2026-07-30).

So APK updates during the pilot are **manual** (adb over USB, or copy the file and tap).

**Fixing it is a deferred backlog item, not an abandoned one** — see `docs/FIELD-PILOT-DEPLOYMENT-PLAN.md`
§7 for the full scoping. Two things to know before estimating it, because this README used to
under-describe the work:

- ⚠️ **The short circuit is not the bug, it is a workaround for one.** The author's own comment reads
  *"2019-09-18 — For some reason, this starts the download but Android never reports completion. So, for
  now, send the user to the /client webpage instead."* So simply deleting `if (2 > 1)` restores a download
  that never completes. **Recommended: bypass `DownloadManager` entirely** — fetch the APK with Volley or
  `HttpURLConnection` into app-internal storage — rather than debugging a 2019 completion-notification
  problem.
- **Even fixed, it cannot install silently.** A sideloaded app still raises Android's package-installer
  confirmation per update, and needs "install unknown apps" granted to *this app*. Silent updates require
  device-owner/MDM — which is what config request **B5 q1** asks MSF about, and would make this work
  unnecessary.

Separately, the app health-checks `http://<server>:9001/dists/stable/Release` and shows a
"check package server configuration" snackbar when it 404s. Running a minimal static server
on `:9001` is the cheap way to silence that; see WS-5.
