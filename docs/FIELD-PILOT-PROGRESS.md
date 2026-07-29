# Project Buendia — Field Pilot: Progress & Working Log

> **START HERE in a new session.** This is the living status/handoff doc for the DRC minimum
> field-pilot. Read this first, then the plan (`FIELD-PILOT-DEPLOYMENT-PLAN.md`). Update it as you go
> (see **Working guidelines** at the bottom).

_Last updated: 2026-07-29._

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
- **End-to-end validated** — fresh `docker compose up` → OpenMRS boots → profile active
  (`currentProfile=bunia.csv`) → REST 200 → **real tablet completed the clinical workflow**.

### Not started / deferred (the remaining pilot work)
- **Android APK build + on-tablet validation (WS-4)** — the app currently used is not built by this repo's
  pipeline yet. This is the biggest remaining piece to make the tablet side part of the package.
- **Remote-support tunnel (§3.5 / WS-7)** — Tailscale+SSH, gated on MSF data-protection sign-off.
- **Package/update server `:9001`** — optional; not running in compose (in-app updater inactive without it).
- **Site-specific data** — wards/beds + clinician accounts (`site-<pilot>.sql`); currently added by hand.
- **Runbooks (WS-6)** — Staging setup guide / Site runbook / Clinical quick-start (→ PDF) not written yet.
- **Hardware procurement**, **hypercare support model**, **data-protection sign-off** — MSF decisions (§8).

### ⚠ Uncommitted
All of this session's work is **uncommitted** on branch `drc-pilot` (last commit `923ac3eb`):
- untracked: `deploy/`, `.dockerignore`, `docs/FIELD-PILOT-PROGRESS.md` (this file)
- modified: `tools/profile_apply`, `tools/server_clear_cache`, `docs/FIELD-PILOT-DEPLOYMENT-PLAN.md`,
  `docs/FIELD-PILOT-EXECUTIVE-SUMMARY.md`
- **strays to review (pre-existing, not from this work):** `tools/profile_applyc`, `docs/PROFILE-CSV-FORMAT.md`

**→ First action in a new session: commit this working package** (a "WS-1/WS-2/WS-3 server package +
baked profile, smoke-tested" checkpoint) so it stops living only in the working tree.

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

# provision a login (the clean seed ships none)
../tools/create-openmrs-user.sh buendia buendia

# use it
#   Web:  http://<HOST-LAN-IP>:9000/openmrs   (login buendia/buendia)
#   REST: curl -u buendia:buendia http://<HOST-LAN-IP>:9000/openmrs/ws/rest/buendia/patients
```
Local test host LAN IP seen so far: **192.168.0.150**. `:9000` is bound on all interfaces (LAN-reachable);
if a tablet can't connect it's almost always the **host firewall** blocking inbound `:9000`.

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
- **The clean seed has no login user** — provision with `deploy/tools/create-openmrs-user.sh <user> <pass>`
  (mirrors `tools/openmrs_account_setup`; `password = sha2(concat(pass,salt),512)`).
- **Profile as a package artifact** — `deploy/profile/bunia.csv` is the committed, tailorable default; edit it
  and re-run `build-seed.sh` to change the shipped profile. Activation = apply content + set
  `projectbuendia.currentProfile` (chartUuids stays NULL, not needed).

---

## 5. Workstream status (see plan §4 for detail)

| WS | What | Status |
|----|------|--------|
| WS-1 | Server container stack + packaging | ✅ done, smoke-tested |
| WS-2 | Seed data + profile bake | ✅ done (db-snapshot + bunia.csv baked) |
| WS-3 | Reproducible image build | ✅ done (`build-image.sh`) |
| WS-4 | Android APK build + real-tablet validation | ⬜ **not started** (biggest remaining) |
| WS-5 | APK delivery (QR install + OTA `:9001`) | ⬜ not started |
| WS-6 | Runbooks (staging/site/clinical → PDF) | ⬜ not started |
| WS-7 | Remote-support tunnel + data export | ⬜ not started (gated on data-protection) |

---

## 6. Open decisions (MSF inputs / SolDevelo — plan §8)

Server hardware model; Staging Area location; ward/bed layout + clinician accounts (for `site-<pilot>.sql`);
tablet count; Wi-Fi coverage / router model; **data-protection sign-off** (gates remote access + data export);
hypercare support scope. None block the build; they're needed to *finish* and deploy.

---

## 7. Working guidelines (how to continue without losing the plot)

1. **After every major step, update this file** — move items between "Done" / "Deferred", note what changed,
   and keep §2 accurate. This doc is the human-readable source of truth for a new session.
2. **Keep the plan reviewed.** When scope changes (like MSF feedback), update
   `FIELD-PILOT-DEPLOYMENT-PLAN.md` and the exec summary, and note the change here.
3. **Commit at checkpoints.** Don't let a working package sit only in the working tree. A labelled commit
   after each milestone makes it restartable and reviewable. (Right now: everything is uncommitted — commit first.)
4. **Verify by actually running it.** The whole package exists because we built + booted + smoke-tested it,
   not because it looked right. Prefer a real `docker compose up` + REST/tablet check over assumptions.
5. **Record every bug + fix** in §4 so it's never re-hit. Most of this project's time went into EOL-stack and
   split-container gotchas; the list is the payoff.
6. **When you find a defect in the shipped tools** (`tools/profile_apply`, `tools/server_clear_cache`, seed,
   triggers), fix it in the repo (backward-compatible with the appliance) — not just live in a container.
7. **Don't disrupt an active test.** Regenerating the seed/image is safe (doesn't touch a running stack);
   `down -v` is destructive — only when the user is done.

---

## 8. Suggested next steps (priority order)

1. **Commit** the current working package (checkpoint).
2. **WS-4 — build the Android APK** from `client/` (v1.0 baseline) configured for the pilot server, and
   validate on a real T4/T5. This makes the tablet side reproducible/packaged rather than ad-hoc.
3. **WS-6 — write the runbooks** (staging setup / site power-on / clinical quick-start).
4. **WS-7 — remote-support tunnel + data export**, once MSF data-protection signs off.
5. Revisit the **open decisions** with MSF (§6) as procurement/site details firm up.
