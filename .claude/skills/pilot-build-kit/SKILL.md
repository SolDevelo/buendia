---
name: pilot-build-kit
description: Build the Buendia field-pilot kit end to end — server image, DB seed, running stack, release-signed tablet APK, QR install server, printable in-zone card. Use for a cold rebuild from scratch, for staging a kit that will actually ship to the site, or when asked to rebuild the image/seed/APK. Encodes the decide-before-you-build ordering that otherwise costs a reinstall on every tablet.
---

# Build the pilot kit, A to Z

Six artefacts, in this order. Each step is one script; the value of following the sequence is that
steps 5–7 bake in decisions that are expensive to change afterwards.

## Before you build anything that ships

**Two values are compiled into the APK and cannot be changed without rebuilding it and
reinstalling every tablet:**

| Must be decided first | Lands in | MSF request |
|---|---|---|
| Server LAN address | `APK_SERVER` / `STATIC_IP` | B1 |
| Server login password | `APK_OPENMRS_PASSWORD` | A5 |

Settle both, then build. Building first and deciding later means a rebuild plus a physical
reinstall on every device — Android will not accept a re-signed or reconfigured update in place.
Check `docs/FIELD-PILOT-MSF-CONFIG-REQUESTS.md` for their current status before starting a build
that is meant to ship. For a local dev build, defaults are fine and nothing here is binding.

Also: **`APK_SERVER` must be the address the tablet can actually reach.** Locally that is the
build host's LAN IP (e.g. `192.168.0.150`), *not* the site `STATIC_IP` — the two differ until the
kit is at the site, and a tablet cannot reach an address that doesn't exist on its network yet.

## The sequence

Everything is driven from `deploy/.env` (git-ignored; `cp .env.example .env`). It is **`source`d
by bash** — quote any value containing a space or `; & | $ \ ' " * ?` or the scripts abort.

```bash
# 1. Server image  (~5-15 min; --fetch downloads the war + xforms + webservices.rest, ONCE)
cd deploy/image && ./build-image.sh --fetch && ./build-image.sh
#    → buendia-openmrs:1.10.6-<gitsha> + :latest  (~393 MB)
#    iterating on server code? ./build-image.sh --skip-tests

# 2. DB seed  (~2-5 min; needs the db-snapshot submodule)
cd ../seed && ./build-seed.sh
#    → initdb/10-buendia-base.sql (~80 MB, git-ignored) with the bunia.csv profile baked in
#    initdb/20-buendia-site.sql is COMMITTED and hand-edited — build-seed.sh does not touch it

# 2b. Bake the seed into the DB image, and SET DB_IMAGE IN .env  (required — compose reads it)
./build-db-image.sh
#    → buendia-db:5.6-<gitsha>  (the ~83 MB seed travels inside the image, so a site server
#      needs only `docker pull`; compose mounts ONLY the 12 KB site seed alongside it)
#    Forgetting the .env line is caught, not silent: setup.sh refuses to start a stack whose
#    DB_IMAGE has no baked-seed label (the DB would come up with no schema and no concepts).

# 3. Boot + verify           (see the pilot-stack skill for the destructive-action guard)
cd ../compose && docker compose --env-file ../.env up -d
cd ../.. && deploy/tools/buendia-verify.sh --write

# 4. Signing key  (ONCE per deployment — then BACK IT UP, see below)
cd deploy/apk && ./build-apk.sh --make-keystore

# 5. APK  (~3-10 min; JDK 8 required)
./build-apk.sh
#    → buendia-client-<version>.apk + .sha256 + .buildinfo.txt
#    CHECK the line it prints reading the server/user back out of the finished APK

# 6. Publish for QR install
cd ../pkgserver && ./publish.sh && cd ../compose && docker compose --env-file ../.env up -d pkgserver

# 6b. Bake the APK into a pkgserver image, so it ships by `docker pull` too (for what SHIPS)
./build-pkgserver-image.sh
#    → buendia-pkgserver:<site>-<apkver>.  SITE-SPECIFIC: the APK inside bakes in the server
#      address and password. Local dev can keep bind-mounting www/ instead (PKGSERVER_IMAGE empty).

# 7. Printable in-zone card
cd ../pkgserver && ./make-install-card.sh "Suspect Zone"
#    → cards/install-card.html (git-ignored: it carries the Wi-Fi passphrase). Print, laminate.

deploy/tools/buendia-verify.sh          # final GO/NO-GO across all of it

# 8. Publish to the registry so a site server needs only `docker pull` (internet at setup only)
deploy/tools/publish-images.sh                 # PLANS by default — prints what it would push
docker login && deploy/tools/publish-images.sh --push
#    then paste the printed DIGESTS into deploy/.env (pin by digest, never a floating tag)
#    offline fallback instead/as well: deploy/tools/bundle-images.sh → images/*.tar (~771 MB)
```

Steps 1, 2 and 2b are independent of a running stack — safe to run while one is up. Step 3 is not;
read `pilot-stack` first.

**Rehearse the installer before it touches a machine:** `cd deploy && ./setup.sh --dry-run` prints
every change and makes none (no root needed). Its exit code is meaningful — `setup.sh` ends by
running `buendia-verify.sh` and returns non-zero on NO-GO.

## Traps that have actually bitten

- **`deploy/apk/keystore/` must stay backed up out of band** (done for the pilot key on 2026-07-29:
  SolDevelo internal system + a second location on the build machine). It is git-ignored by design.
  The key *is* the app's identity: lose it and every tablet needs uninstall + reinstall, destroying
  unsynced local data. Re-check this whenever a new key is created.
- **A directory bind-mount shadows a file baked into the image at the same path.** This is why
  compose mounts `20-buendia-site.sql` as a single FILE: mounting `../seed/initdb` would hide the
  baked baseline seed and leave a DB with no schema and no concepts, on a server that looks fine.
- **Never publish an APK newer than what the tablets run.** In-app OTA is broken on the v1.0
  client, so a newer published version makes every tablet nag about an update it cannot install.
  `publish.sh` advertises only what it publishes — keep it equal to what is installed.
- **APK filename must stay `buendia-client-<version>.apk`.** The index generator parses the
  version out of the name; a git sha in there is read as the version and the file is skipped.
  The sha goes in `.buildinfo.txt`.
- **`-PversionNumber=1.0.0` yields `versionName='1'`** — trailing `.0` is stripped. `build-apk.sh`
  reads the real value back out of the built APK rather than trusting the request. Versions must
  be numeric: the updater parses integer components only, and a non-numeric name reads as `0`.
- **`--debug` builds a different app** (`org.projectbuendia.client.dev`, "Buendia dev") that
  coexists with the release app. Never field one, and remove it from tablets that have it.
- **Toolchain is fixed:** JDK 8 for the APK (AGP 3.2.1 does not run on 11+), Android platform 28 +
  build-tools ≥28 (19.1.0 has no `apksigner`). The server image needs JDK 7 *inside* it only.
- **The client submodule is never modified by the build** — all configuration goes in as gradle
  `-P` properties. If you need new behaviour, make it a `-P` property surfaced as an `APK_*` var
  rather than editing a constant, and commit it on the submodule's `drc-pilot` branch
  (progress doc §7, working guideline 10 — see also `pilot-checkpoint`).

## What is and isn't reproducible

Everything above regenerates from the repo **except** `deploy/.env` and `deploy/apk/keystore/`.
Those two are the only things worth backing up; the 80 MB seed, the image and the APK are all
derived artefacts and are correctly git-ignored.

When the build is done and validated, update `docs/FIELD-PILOT-PROGRESS.md` — see `pilot-checkpoint`.
