# Project Buendia — Field Pilot: Progress & Working Log

> **START HERE in a new session.** This is the living status/handoff doc for the DRC minimum
> field-pilot. Read this first, then the plan (`FIELD-PILOT-DEPLOYMENT-PLAN.md`). Update it as you go
> (see **Working guidelines** at the bottom).

_Last updated: 2026-07-29 (full cold rebuild + QR-install smoke test PASSED on a real tablet; default-zone bug fixed)._

---

## 1. Goal

Deliver the **"minimum field-pilot"** (`docs/TECHNICAL-REVIEW.md` §3): the leanest path to a *working*
Buendia system at **one DRC site**, on **CrossCall T4/T5 tablets**, against a small **on-site x86 server**,
with **no Internet required** at the site. It is an **autonomous kit**, independent of MSF's LIME EMR /
OpenMRS 3 infrastructure (MSF confirmed this approach).

- **Full plan:** `docs/FIELD-PILOT-DEPLOYMENT-PLAN.md`
- **One-page exec summary:** `docs/FIELD-PILOT-EXECUTIVE-SUMMARY.md`
- **Parties:** SolDevelo = build/procure/stage the kit + remote support; MSF = deploy on-site + domain/site
  specifics + data-protection sign-off; Users = clinicians.

---

## 2. Current state (2026-07-29)

**MILESTONE: the complete kit was rebuilt from scratch and passed an end-to-end smoke test on a real
tablet — including first install by QR code.** This is the first run where *nothing* was done by hand:
Docker was cleaned of all Buendia artefacts, the image, seed and APK were rebuilt cold, and the tablet
was provisioned only by scanning a QR code.

The path that was exercised: **scan QR → download + install APK → app opens already pointed at the
server with credentials baked in → provider picker shows Guest + Buendia User → locations/concepts
sync → select zone → add patient → fill two `bunia.csv` forms → save.** Verified working.

One real bug was found and fixed during that test — new patients were admitted to the wrong zone
(see *location name markup* in §4); the fix was applied to the live server and **re-tested on the
tablet**, and is now in the seed.

### Done & verified
- **Deployable server package** under `deploy/` — `docker compose` stack: MySQL 5.6 + OpenMRS 1.10.6
  (Tomcat 7 / Java 7) with the Buendia omod + xforms + webservices.rest + python2 profile-apply.
- **Reproducible image build** — `deploy/image/build-image.sh` (one command; `--fetch` once for the heavy
  deps, then rebuild on each code fix). Produces `buendia-openmrs:1.10.6-<gitsha>` (~393 MB).
- **Seed** — `deploy/seed/build-seed.sh` turns the `db-snapshot` submodule into a single portable
  `initdb/10-buendia-base.sql` (~80 MB) **with the Ebola profile baked in** (active out-of-the-box).
- **Zero-config first boot** — `deploy/seed/initdb/20-buendia-site.sql` (committed, hand-editable)
  ships the **default login `buendia`/`buendia`** and the **location tree** `Facility` → Triage,
  Suspect Zone, Probable Zone, Confirmed Zone, Discharged (in that display order, with Triage as the
  zone new patients are admitted to — see *location name markup* in §4), plus a provider row. Previously both had
  to be added by hand after every fresh boot. Verified on a throwaway stack built only from the two
  seed files: auth 200 (401 on a wrong password), `/locations` returns the 6-node tree, `/charts`
  returns `buendia_form_chart`, and a `POST /patients` succeeds.
- **End-to-end validated** — fresh `docker compose up` → OpenMRS boots → profile active
  (`currentProfile=bunia.csv`) → REST 200 → **real tablet completed the clinical workflow**.
- **Reproducible APK build (WS-4, build side)** — `deploy/apk/build-apk.sh` produces a
  **release-signed** `buendia-client-<version>.apk` with the server address, login, and all tunables
  baked in, driven from `deploy/.env`. Verified: builds, signs with the pilot key, and the script
  reads the baked-in values back out of the finished APK. **Installed and used on a real tablet on
  2026-07-29** — the app opened already pointed at the server with credentials working, so a clinician
  touches no settings. See `deploy/apk/README.md`.
  NB `APK_SERVER` must be the address the tablet can actually reach: for the local test that is the
  host's LAN IP (`192.168.0.150`), **not** the site `STATIC_IP` (`192.168.8.10`).
- **APK install over the LAN (WS-5 first-install path)** — `deploy/pkgserver/` adds a static
  `nginx:alpine-slim` (~13 MB) service on **:9001**. `publish.sh` takes a built APK and generates the
  document root: `/latest.apk` (the stable URL a **QR code** encodes), the version-named copy, the
  `buendia-client.json` update index, the `/dists/stable/Release` stub, and a plain landing page with
  the version + SHA-256. Verified against a throwaway container: `.apk` served as
  `application/vnd.android.package-archive`, byte-identical to the built APK, `206 Partial Content`
  on a range request (so an interrupted ward-wifi download resumes), and both client-probed paths
  return 200. This also removes the tablet's spurious "check package server configuration" warning.
  See `deploy/pkgserver/README.md`.
- **Client `drc-pilot` branch** — `SolDevelo/buendia-client` now has a `drc-pilot` branch matching
  this superproject branch, and `.gitmodules` records `branch = drc-pilot`. Pilot client code
  changes land there. First change: the auto-logout fix below.

### Not started / deferred (the remaining pilot work)
- **Auto-logout fix not yet confirmed on a tablet** — the 30 s-while-charging fix is compiled into the
  installed APK (`IDLE_LOGOUT_SECONDS=600` / `DOCKED_IDLE_LOGOUT_SECONDS=300`) but was not explicitly
  exercised in the 2026-07-29 test. Leave a tablet **plugged in and idle for >30 s** to confirm it no
  longer bounces to the provider picker.
- **Remote-support tunnel (§3.5 / WS-7)** — Tailscale+SSH, gated on MSF data-protection sign-off.
- **In-app OTA updates** — **dropped, not deferred**: broken in the v1.0 client (§4). The `:9001`
  server now runs in compose, but it is for *first install* (QR) and to satisfy the client's health
  check; updating a tablet is a manual re-install.
- **Site-specific data** — the pilot-start location tree + default account are now **baked in**
  (`seed/initdb/20-buendia-site.sql`). Still open: the *real* ward/bed layout and the per-clinician
  provider accounts, both pending MSF input (see `FIELD-PILOT-MSF-CONFIG-REQUESTS.md`). Tailor that one
  file, no rebuild needed.
- **Runbooks (WS-6)** — Staging setup guide / Site runbook / Clinical quick-start (→ PDF) not written yet.
- **Hardware procurement**, **hypercare support model** — MSF/programme decisions (plan §8);
  **data-protection sign-off** gates WS-7 (`FIELD-PILOT-MSF-CONFIG-REQUESTS.md` C1).

### Committed
On branch `drc-pilot`, **not yet pushed** (ahead of `soldevelo/drc-pilot`):
- **`925dae3a`** — the field-pilot deployment package (containerized server + baked Ebola profile).
- **`bd52103f`** — zero-config first boot (site seed: login + location tree).
- **`73dbbcce`** — the canonical MSF config-request list.
- **`4838b326`** — the reproducible APK build (WS-4) + `.gitmodules` submodule branch.
- **`532f78bd`** — correction: the client's encryption password is inert (see §4).
- **`7d0f5e8e`** — the `:9001` QR-install package server (WS-5).
- **`0ab7ac28`** — pkgserver healthcheck fix (IPv6 `localhost`) + rootless QR fallback (segno).
- **`51c3825e`** — admit new patients to Triage (the default-zone bug found on the tablet).

In the **client** submodule, on its own `drc-pilot` branch, **pushed** to
`soldevelo` (`git@github.com:SolDevelo/buendia-client.git` — note the fork was renamed from
`SolDevelo/client`):
- **`85ce064c`** — build-configurable auto-logout idle timeouts (the 30 s-while-charging fix).

Gitignored heavy artefacts (the 80 MB base seed, the war/omods, `deploy/.env`) are correctly excluded —
regenerate them with `build-image.sh` / `build-seed.sh`. The **site seed is deliberately committed**
(`deploy/.gitignore` has an explicit negation) — the package is not zero-config without it.

- **Strays still in the tree (pre-existing, NOT from this work — review/remove):**
  `tools/profile_applyc`, `docs/PROFILE-CSV-FORMAT.md`; also an unrelated `.idea/` change.

---

## 3. How to run it locally (fresh start)

```bash
# one-time: build image + seed (artifacts persist on disk)
cd deploy/image && ./build-image.sh --fetch && ./build-image.sh     # → buendia-openmrs:latest
cd ../seed       && ./build-seed.sh                                 # → initdb/10-buendia-base.sql (profile baked)

# fresh boot
cd ../compose
docker compose --env-file ../.env down -v      # clean slate (drops DB + profile volumes)
docker compose --env-file ../.env up -d        # db loads seed, OpenMRS boots (~2–4 min first boot)

# NO configuration step — the seed ships the buendia/buendia login, the location tree and the
# active profile. (To rotate the password: ../tools/create-openmrs-user.sh buendia <new-pw>.)

# use it
#   Web:  http://<HOST-LAN-IP>:9000/openmrs   (login buendia/buendia)
#   REST: curl -u buendia:buendia http://<HOST-LAN-IP>:9000/openmrs/ws/rest/buendia/patients
```
Local test host LAN IP seen so far: **192.168.0.150**. `:9000` is bound on all interfaces (LAN-reachable);
if a tablet can't connect it's almost always the **host firewall** blocking inbound `:9000`.

### Building the tablet APK

```bash
cd deploy/apk
# one-time: fill in the APK_* block in deploy/.env, then create the signing key
./build-apk.sh --make-keystore     # -> keystore/buendia-pilot.jks  (BACK THIS UP)
./build-apk.sh                     # -> buendia-client-<version>.apk (+ .sha256 + .buildinfo.txt)
adb install -r buendia-client-<version>.apk
```
`APK_SERVER` defaults to `STATIC_IP` from the same `.env`, so tablet and server can't drift apart.
The script prints the baked-in server/user read back out of the finished APK — check that line.
Full detail, and the signing-key/encryption warnings, in `deploy/apk/README.md`.

### Publishing the APK for tablet install (QR code)

```bash
cd deploy/pkgserver && ./publish.sh          # generates www/ from the newest built APK + prints the QR
cd ../compose && docker compose --env-file ../.env up -d pkgserver
# tablet: scan the QR, or open  http://<STATIC_IP>:9001/latest.apk
```
`qrencode` isn't installed on this box — `publish.sh` prints the URL and how to get a generator
(`sudo apt install qrencode`, then `./publish.sh --qr-only`). The URL is what matters, not the image.

---

## 4. Key facts & hard-won gotchas (don't re-hit these)

- **Java 7 base:** `openjdk:7` is gone from Docker Hub → use **`azul/zulu-openjdk-debian:7`** (Debian 11);
  Maven **3.5.4** + Tomcat **7.0.109** as pinned tarballs; python2.7 + **PyMySQL `<1.0`** (1.0+ dropped py2).
- **The xforms "fork" is NOT a fork** — the `org.openmrs.module.xforms.buendia` package is **symlinked** into
  the omod from `third_party/openmrs-module-xforms/` and compiled into the buendia omod. The Docker build must
  `COPY third_party/…` and `.git` into the context (the omod's git-commit-id plugin needs `.git`).
- **OpenMRS data dir needs a trailing slash** — `OPENMRS_APPLICATION_DATA_DIRECTORY=/opt/openmrs/` (OpenMRS
  joins it with the filename/`modules` with no separator).
- **MySQL healthcheck must gate on the REAL server over TCP** (`mysql --protocol=TCP … -e 'SELECT 1'`), not
  `mysqladmin ping` — ping passes during MySQL's init-phase temp server → OpenMRS/scripts race and fail
  ("Unable to get a connection" / "server has gone away"). Same fix applied in compose **and** `build-seed.sh`.
- **profile-apply DB host** — `buendia-profile-apply` defaulted to `localhost`; in the split-container setup
  the entrypoint writes `/usr/share/buendia/site/10-openmrs-db` so it reaches host `db` as user `openmrs`.
- **DEFINER strip** — `db-snapshot`'s 6 sync triggers carried `DEFINER='openmrs_user'@'localhost'` (a user
  that doesn't exist here) → patient/obs/order inserts failed. `build-seed.sh` now **strips DEFINER clauses**
  so the triggers are definer-agnostic. (A live DB can be unblocked with
  `GRANT ALL ON openmrs.* TO 'openmrs_user'@'localhost' IDENTIFIED BY 'openmrs'`.)
- **Ports:** OpenMRS listens on **8080 inside** the container, mapped to **9000 on the host**. Scripts run
  inside the container must use `:8080`; anything from the host/LAN uses `:9000`.
- **What the base seed does NOT contain** — `db-snapshot` has the schema + ~50k concepts + `admin`/`daemon`,
  but **zero `location` rows, zero `provider` rows, and no usable login**. A fresh boot without
  `20-buendia-site.sql` is unusable: nothing to admit a patient to, nobody can log in. That file now
  fixes it; don't "fix" it by hand again.
- **Passwords** — `password = sha2(concat(pass, salt), 512)`, salt = 64 random bytes as 128 hex chars
  (`tools/openmrs_account_setup`). Seeding an account in plain SQL therefore works:
  `SHA2(CONCAT('buendia', @salt), 512)`. `deploy/tools/create-openmrs-user.sh <user> <pass>` rotates
  it with a fresh random salt.
- **Don't seed what the server creates** — `DbUtils.ensureRequiredObjectsExist()` auto-creates, on first
  use, the `Guest` provider (`uuid = buendia_provider_guest` — the client special-cases this exact
  string in `JsonUser`, sorting it first), the Buendia identifier types, and the order/placement
  concepts. Confirmed: `Guest` appears in `/providers` on a fresh DB that never seeded it.
- **Location names carry hidden markup — this is the lever for both ordering and the default zone.**
  The client strips every `[...]` segment from a location's displayed name (`Intl.java`:
  `BRACKETED_PATTERN.replaceAll("")` then trim), so brackets hold metadata clinicians never see:
  - `[<n>]` — **display order.** The client sorts locations **alphanumerically by name**
    (`LocationForest` / `Utils.ALPHANUMERIC_COMPARATOR`); insertion order and `location_id` are
    ignored and there is **no sort-order column**. Bracketed numbers sort numerically and stay hidden.
  - `[*]` — **the default location for new patients.** The add-patient dialog has **no location
    picker**: `PatientDialogFragment.java:202` always uses `LocationForest.getDefaultLocation()`,
    which is the location whose name contains `*`, or else **the first leaf in alphanumeric order**
    (`LocationForest.java:118-126`). Non-leaf nodes (the root) are skipped.
  - `[fr:…]` — a localized name; the profile CSV already uses this same convention for form names.

  **Bug this caused, found on the tablet 2026-07-29:** with plain names, a patient added while
  viewing Triage was admitted to **Confirmed Zone** — alphabetically the first leaf. Clinically wrong,
  not cosmetic. **Fixed** in `20-buendia-site.sql`: the zones are now `[1] Triage [*]`,
  `[2] Suspect Zone`, `[3] Probable Zone`, `[4] Confirmed Zone`, `[5] Discharged` → they display as
  Triage / Suspect Zone / Probable Zone / Confirmed Zone / Discharged and new patients land in Triage.
  **Verified live on a real tablet.** An earlier version of MSF config request A3 wrongly claimed the
  numeric prefixes would be visible; they are not, so ordering is free.
- **Renaming a location is safe and can be done on a live server** — `UPDATE location SET name=...`
  keyed on `uuid`, then hit any endpoint with `?clear-cache` to flush the module cache; the change
  syncs to tablets and existing patients keep their placement because the UUID is untouched. This is
  how the fix above was applied mid-test without re-seeding. `20-buendia-site.sql` is idempotent
  (`ON DUPLICATE KEY UPDATE`, keyed on uuid), so it can be re-applied to a running DB:
  `docker exec -i compose-db-1 mysql -uroot -p<pw> openmrs < seed/initdb/20-buendia-site.sql`.
- **No location UUID is hardcoded** anywhere (client or server) — the root is simply the one location
  with `parent_location = NULL`, and `LocationResource` serves `getAllLocations(false)`. So the tree is
  free to change; keep UUIDs stable once tablets have synced, or admitted patients point at dead nodes.
### Android client / APK (WS-4)

- **Toolchain that works:** JDK **8** (Zulu 1.8.0_492), Android SDK **platform 28** + build-tools
  **28.0.3**, gradle **4.6** (wrapper), AGP **3.2.1**. `ANDROID_HOME`/`ANDROID_SDK_ROOT` are unset on
  this box — `build-apk.sh` falls back to `~/Android/Sdk`. AGP 3.2.1 does **not** run on JDK 11+.
  Build-tools **19.1.0 has no `apksigner`**; ≥28 is needed to verify signatures.
- **Release signing must go through the `CI` env branch.** `client/app/build.gradle`'s non-CI branch
  prompts on a console for the passphrase (and hard-fails with "only works from command line with
  the Gradle Daemon disabled"). Setting `CI=1` + `ANDROID_KEYSTORE_FILE`/`ANDROID_KEYSTORE_PASSWORD`
  is the only scriptable path. The key alias is hardcoded to **`buendia`**.
- **The signing key is the app's identity.** Android only accepts an update signed with the same key.
  `deploy/apk/keystore/` is git-ignored — **back it up out-of-band**; losing it means uninstall +
  reinstall on every tablet, which destroys unsynced local data.
- **`-PversionNumber=1.0.0` produces `versionName='1'`** — `build.gradle:139` strips trailing `.0`.
  `build-apk.sh` therefore reads the real `versionName` back out of the built APK and names the file
  from that, rather than trusting the requested value.
- **The updater compares `versionName`, NOT `versionCode`** (`AvailableUpdateInfo.shouldUpdate()` via
  `LexicographicVersion`, integer components only). A non-numeric version silently degrades the
  installed version to `0`, so the app treats *every* published APK as an upgrade. Debug builds have
  `versionName='dev'` and hit exactly this — another reason not to field a debug build.
- **APK filename must be `buendia-client-<version>.apk`** — that is the `<module>-<version>.apk` form
  `buendia-pkgserver-index-apks` needs to generate the `buendia-client.json` index the app fetches
  (`PackageServer.MODULE_NAME = "buendia-client"`). A git sha in the name is misparsed as the version
  and the file is skipped, so the sha goes in the `.buildinfo.txt` instead.
- **In-app OTA updates are broken on v1.0 — don't plan on them (WS-5).** `UpdateManager.java:150-158`
  short-circuits the download with `if (2 > 1)` and instead opens `http://<server>/client` (port
  **80**, which the stack doesn't serve); and `installUpdate()` passes Android a raw `file://` Uri,
  which throws `FileUriExposedException` at `targetSdkVersion 24`. There is no `FileProvider` and no
  `REQUEST_INSTALL_PACKAGES`. **Pilot APK updates are manual** (adb, or copy the file and tap).
- **The app health-checks `:9001/dists/stable/Release`** and shows a "check package server
  configuration" snackbar when it 404s. **Fixed** — the `pkgserver` service serves a stub there.
- **`.apk` is NOT in nginx's default `mime.types`** — without help it is served as
  `application/octet-stream`. `pkgserver/nginx.conf` sets the type in a `location ~* \.apk$` block
  rather than a `types { }` block, because a `types` block in `server` context **replaces** the
  inherited MIME map instead of extending it.
- **Never publish an APK newer than what the tablets run.** `publish.sh` advertises only the version
  it publishes, so `shouldUpdate()` is false and clinicians get no prompt. Publish something newer
  and every tablet starts nagging about an update the broken in-app updater cannot install.
- **`pkgserver` starts even with an empty `www/`** — nginx comes up fine and the tablet gets 404s.
  `setup.sh` now warns when `pkgserver/www/` holds no `.apk`; the fix is to run `publish.sh`.
- **Upstream polls for updates every 10 seconds** (`apkCheckIntervalDefault = 10`). `build-apk.sh`
  ships **3600**.
- **Release vs debug are different app ids** — `org.projectbuendia.client` ("Buendia") vs
  `...client.dev` ("Buendia dev"), with distinct `ContentAuthority`. They coexist on a device, so
  **remove the debug app from pilot tablets** or clinicians will open the wrong one. The 2026-07-13
  smoke test used the *debug* build; its local data does not carry over to the release build.
- **Auto-logout after 30 s while charging was stock upstream behaviour, now fixed.**
  `LoggedInActivity.onTick()` (ticked every 1 s from `BaseActivity`) signed the user out to the
  provider picker after 30 s idle whenever `BatteryWatcher.isDocked()`. "Docked" is **inferred from
  AC charging**, not a dock event (the 2016 docks never fired `ACTION_DOCK_EVENT`), and idle resets
  only on `onUserInteraction()` — so *reading* a chart on a plugged-in tablet bounced the user out.
  Upstream `fb1b6099` had already relaxed it from log-out-immediately. Now build-configurable
  (`-PidleLogoutSeconds` / `-PdockedIdleLogoutSeconds`), shipping **600 s / 300 s**; see MSF config
  request **A10**. Client commit `85ce064c` on `drc-pilot`.
- **`-PencryptionPassword` is INERT — the app does not encrypt its local DB.** The property still
  feeds `BuildConfig.ENCRYPTION_PASSWORD`, but **nothing reads that constant** and
  `sync/Database.java` extends plain `android.database.sqlite.SQLiteOpenHelper` (SQLCipher was
  removed). Re-verified in v1.0 source on 2026-07-29. Don't claim the tablet DB is encrypted because
  the flag was set — data-at-rest is **device-level Android encryption + a screen-lock PIN**, which
  is a *staging checklist* step, not an APK setting. MSF config request **A11**.

### Server / seed / profile

- **Profile as a package artifact** — `deploy/profile/bunia.csv` is the committed, tailorable default; edit it
  and re-run `build-seed.sh` to change the shipped profile. Activation = apply content + set
  `projectbuendia.currentProfile` (chartUuids stays NULL, not needed).

---

## 5. Workstream status (see plan §4 for detail)

| WS | What | Status |
|----|------|--------|
| WS-1 | Server container stack + packaging | ✅ done, smoke-tested |
| WS-2 | Seed data + profile bake | ✅ done (db-snapshot + bunia.csv baked + zero-config site seed: login & locations) |
| WS-3 | Reproducible image build | ✅ done (`build-image.sh`) |
| WS-4 | Android APK build + real-tablet validation | 🟡 **build done** (`deploy/apk/build-apk.sh`, release-signed, self-verifying); **on-tablet validation outstanding** |
| WS-5 | APK delivery (QR install + OTA `:9001`) | 🟡 **QR/LAN install done** (`deploy/pkgserver/`, served + verified); **in-app OTA dropped** — broken on v1.0 (see §4), updates are manual. Untested from a real tablet browser |
| WS-6 | Runbooks (staging/site/clinical → PDF) | ⬜ not started |
| WS-7 | Remote-support tunnel + data export | ⬜ not started (gated on data-protection) |

---

## 6. Open decisions

**➡️ Configuration inputs we need from MSF now live in one place:
`docs/FIELD-PILOT-MSF-CONFIG-REQUESTS.md`** — locations tree & display order, facility name, clinician
accounts, credentials, **UI language (French?)**, profile content, patient ID scheme, timezone, network,
tablet count, data-protection sign-off. Each item records the default we ship, the file it lands in, and
its status. **Keep that file up to date** as answers arrive or new questions surface.

Programme/logistics decisions (hardware model, Staging Area location, hypercare scope) stay in
plan §8. Nothing here blocks the build — the package boots and is clinically usable on defaults; each
answer swaps out one default, mostly in `deploy/seed/initdb/20-buendia-site.sql`.

---

## 7. Working guidelines (how to continue without losing the plot)

1. **After every major step, update this file** — move items between "Done" / "Deferred", note what changed,
   and keep §2 accurate. This doc is the human-readable source of truth for a new session.
2. **Keep the plan reviewed.** When scope changes (like MSF feedback), update
   `FIELD-PILOT-DEPLOYMENT-PLAN.md` and the exec summary, and note the change here.
3. **Commit at checkpoints.** Don't let a working package sit only in the working tree. A labelled commit
   after each milestone makes it restartable and reviewable.
4. **Verify by actually running it.** The whole package exists because we built + booted + smoke-tested it,
   not because it looked right. Prefer a real `docker compose up` + REST/tablet check over assumptions.
5. **Record every bug + fix** in §4 so it's never re-hit. Most of this project's time went into EOL-stack and
   split-container gotchas; the list is the payoff.
6. **When you find a defect in the shipped tools** (`tools/profile_apply`, `tools/server_clear_cache`, seed,
   triggers), fix it in the repo (backward-compatible with the appliance) — not just live in a container.
7. **Don't disrupt an active test.** Regenerating the seed/image is safe (doesn't touch a running stack);
   `down -v` is destructive — only when the user is done. To validate a seed/config change without
   touching a live stack, boot a throwaway DB + OpenMRS on a spare port (see §2, how the site seed was verified).
8. **A new config question — or a default we invented ourselves — goes in
   `FIELD-PILOT-MSF-CONFIG-REQUESTS.md` immediately**, with the default we ship and the file it lands in.
   That list is what gets sent to MSF; anything left only in a commit message or a chat thread is lost.
9. **No manual setup steps in the package.** If a fresh `up -d` needs a human to run something before it
   is usable, that's a bug — bake it into the seed instead (this is why `20-buendia-site.sql` exists).
10. **Client code changes go on the submodule's `drc-pilot` branch** (`SolDevelo/buendia-client`), then
    the gitlink bump is committed here. Never leave a client fix uncommitted in the submodule working
    tree — it is invisible in the superproject's `git status` beyond a bare `m client`, and the next
    `submodule update` silently discards it. Prefer making behaviour **build-configurable** (a `-P`
    property surfaced as an `APK_*` var in `.env`) over changing a hardcoded constant, so the value
    can be retuned from `deploy/.env` without another client release.

---

## 8. Suggested next steps (priority order)

**➡️ NEXT SESSION STARTS HERE: install the packaged APK on a real T4/T5 and re-run the clinical
smoke test.** Everything needed is built; no device was attached this session.

1. **Finish WS-4 — validate the packaged APK on a tablet.** `adb install -r` the release build against
   a freshly-seeded stack and repeat the 2026-07-13 workflow (add patient → forms → observations →
   treatment). Specifically confirm, because these are new/untested in a *release* build:
   - the release app id installs and runs (the smoke test used a **debug** build);
   - the auto-logout change behaves — leave it **plugged in and idle for >30 s**, which previously
     bounced to the login screen, and confirm it now holds for 5 min;
   - **the QR install path end-to-end from the tablet's own browser** — scan
     `http://<STATIC_IP>:9001/latest.apk`, confirm Android accepts the download and the installer
     runs. This is verified server-side only (headers, bytes, ranges); the Android side — the
     "install unknown apps" prompt for the browser on CrossCall's Android 9–12 ROM — is untested;
   - that the `:9001` snackbar is now gone (the stub `Release` file should have fixed it);
   - that device encryption + screen-lock PIN are on (**A11**) — the app-level encryption flag is
     inert, so this is the only data-at-rest protection the tablet has.
2. **WS-6 — write the runbooks** (staging setup / site power-on / clinical quick-start). The QR card
   for the ward belongs here: `publish.sh` emits `install-qr.png` when `qrencode` is available.
3. **WS-7 — remote-support tunnel + data export**, once MSF data-protection signs off.
5. **Send MSF the config-request list** (`FIELD-PILOT-MSF-CONFIG-REQUESTS.md`) and apply answers as they
   arrive. The location tree / display order (A2, A3) and the UI language (A6) are the ones that are
   cheapest now and most expensive after tablets have synced. **A10** (auto-logout timeout) and
   **A11** (tablet DB encryption) are new — A11 must be settled before tablets are provisioned.

Also outstanding, unrelated to any workstream: the local test stack still runs the **hand-configured**
DB from before the site seed existed (`DRC Facility`, `Suspected Zone`, hand-made user). Recycle it with
`down -v && up -d` to run on the real zero-config seed. And the pre-existing strays in the tree
(`tools/profile_applyc`, `docs/PROFILE-CSV-FORMAT.md`, an `.idea/` change) still need review/removal.
