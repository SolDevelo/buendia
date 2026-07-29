# Project Buendia — Field Pilot: Progress & Working Log

> **START HERE in a new session.** This is the living status/handoff doc for the DRC minimum
> field-pilot. Read this first, then the plan (`FIELD-PILOT-DEPLOYMENT-PLAN.md`). Update it as you go
> (see **Working guidelines** at the bottom).

_Last updated: 2026-07-29 (WS-4: reproducible APK build + client `drc-pilot` branch; auto-logout fix)._

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

**Milestone reached: the containerized server is built, boots, and PASSED a full clinical smoke test on a
real tablet** — add patient → fill forms (from `bunia.csv`) → record observations → record treatment.

### Done & verified
- **Deployable server package** under `deploy/` — `docker compose` stack: MySQL 5.6 + OpenMRS 1.10.6
  (Tomcat 7 / Java 7) with the Buendia omod + xforms + webservices.rest + python2 profile-apply.
- **Reproducible image build** — `deploy/image/build-image.sh` (one command; `--fetch` once for the heavy
  deps, then rebuild on each code fix). Produces `buendia-openmrs:1.10.6-<gitsha>` (~393 MB).
- **Seed** — `deploy/seed/build-seed.sh` turns the `db-snapshot` submodule into a single portable
  `initdb/10-buendia-base.sql` (~80 MB) **with the Ebola profile baked in** (active out-of-the-box).
- **Zero-config first boot** — `deploy/seed/initdb/20-buendia-site.sql` (committed, hand-editable)
  ships the **default login `buendia`/`buendia`** and the **location tree** `Facility` → Triage,
  Confirmed Zone, Suspect Zone, Probable Zone, Discharged, plus a provider row. Previously both had
  to be added by hand after every fresh boot. Verified on a throwaway stack built only from the two
  seed files: auth 200 (401 on a wrong password), `/locations` returns the 6-node tree, `/charts`
  returns `buendia_form_chart`, and a `POST /patients` succeeds.
- **End-to-end validated** — fresh `docker compose up` → OpenMRS boots → profile active
  (`currentProfile=bunia.csv`) → REST 200 → **real tablet completed the clinical workflow**.
- **Reproducible APK build (WS-4, build side)** — `deploy/apk/build-apk.sh` produces a
  **release-signed** `buendia-client-<version>.apk` with the server address, login, and all tunables
  baked in, driven from `deploy/.env`. Verified: builds, signs with the pilot key, and the script
  reads the baked-in values back out of the finished APK (`http://192.168.8.10:9000/openmrs`,
  `:9001`, user `buendia`). See `deploy/apk/README.md`. **Not yet installed on a real tablet.**
- **Client `drc-pilot` branch** — `SolDevelo/buendia-client` now has a `drc-pilot` branch matching
  this superproject branch, and `.gitmodules` records `branch = drc-pilot`. Pilot client code
  changes land there. First change: the auto-logout fix below.

### Not started / deferred (the remaining pilot work)
- **On-tablet validation of the packaged APK (rest of WS-4)** — the APK now builds reproducibly, but
  the build has **not been installed on a T4/T5 yet** (no device attached during this session). The
  tablet that passed the clinical smoke test on 2026-07-13 ran an ad-hoc **debug** build; the
  packaged build is a *release* build, so it installs as a different app id — see the caveat in §4.
- **Remote-support tunnel (§3.5 / WS-7)** — Tailscale+SSH, gated on MSF data-protection sign-off.
- **Package/update server `:9001`** — optional; not running in compose (in-app updater inactive without it).
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
- plus the WS-4 commit (APK build script + `.gitmodules` submodule branch + this status update).

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
- **The client sorts locations ALPHANUMERICALLY BY NAME** (`LocationForest` /
  `Utils.ALPHANUMERIC_COMPARATOR`) — insertion order and `location_id` are ignored. So the zones
  display as Confirmed / Discharged / Probable / Suspect / Triage, *not* in clinical-flow order. To
  control order, prefix the names (`1 Triage`, `2 Suspect Zone`, …); the comparator handles numeric
  prefixes numerically. **Open question for MSF** (see §6).
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
  configuration" snackbar when it 404s. Nothing runs on `:9001` in compose, so expect that warning
  on the tablet; a minimal static server on `:9001` is the cheap fix (WS-5).
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
| WS-5 | APK delivery (QR install + OTA `:9001`) | ⬜ not started — **in-app OTA is broken on v1.0** (see §4); scope is manual install + optional `:9001` static server to silence the health-check warning |
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
   - whether the `:9001` package-server snackbar is intrusive enough to justify WS-5's static server;
   - that device encryption + screen-lock PIN are on (**A11**) — the app-level encryption flag is
     inert, so this is the only data-at-rest protection the tablet has.
2. **WS-6 — write the runbooks** (staging setup / site power-on / clinical quick-start).
3. **WS-5 — APK delivery**, rescoped: in-app OTA is broken on v1.0 (see §4), so this is manual install
   (USB/adb, or a file + tap) plus optionally a minimal static `:9001` server to serve the APK, its
   `buendia-client.json` index, and the `/dists/stable/Release` file the health check probes.
4. **WS-7 — remote-support tunnel + data export**, once MSF data-protection signs off.
5. **Send MSF the config-request list** (`FIELD-PILOT-MSF-CONFIG-REQUESTS.md`) and apply answers as they
   arrive. The location tree / display order (A2, A3) and the UI language (A6) are the ones that are
   cheapest now and most expensive after tablets have synced. **A10** (auto-logout timeout) and
   **A11** (tablet DB encryption) are new — A11 must be settled before tablets are provisioned.

Also outstanding, unrelated to any workstream: the local test stack still runs the **hand-configured**
DB from before the site seed existed (`DRC Facility`, `Suspected Zone`, hand-made user). Recycle it with
`down -v && up -d` to run on the real zero-config seed. And the pre-existing strays in the tree
(`tools/profile_applyc`, `docs/PROFILE-CSV-FORMAT.md`, an `.idea/` change) still need review/removal.
