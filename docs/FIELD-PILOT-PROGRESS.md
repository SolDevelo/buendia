# Project Buendia — Field Pilot: Progress & Working Log

> **START HERE in a new session.** This is the living status/handoff doc for the DRC minimum
> field-pilot. Read this first, then the plan (`FIELD-PILOT-DEPLOYMENT-PLAN.md`). Update it as you go
> (see **Working guidelines** at the bottom).

_Last updated: 2026-07-30. **WS-1..WS-5 COMPLETE and twice validated on real hardware.** A bare Ubuntu 24
notebook was installed from a USB stick — the second time from the 36 KB deployment bundle, with no git
clone — smoke-tested through the tablet, rebooted, wiped and reinstalled. Images are public on Docker Hub;
the tablet APK payload ships from a private GitHub release. The branch is now **pushed** to
`soldevelo/drc-pilot`, and the two MSF-facing documents are written and ready to send
(`FIELD-PILOT-MSF-REQUEST-OUTGOING.md` + `FIELD-PILOT-SERVER-SPEC.md`). **Next: send those, then WS-6
runbooks.**_

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
sync → select zone → add patient → fill `bunia.csv` forms → record a treatment → save.**

Confirmed in the database afterwards: **2 patients, 8 encounters, 62 observations** (via `[1] Admission`
and `[3] Vitals / Physical exam`) and **1 order** written by the tablet's own account (`creator=101`) —
so add-patient, observations *and* treatment were all genuinely exercised from the app, not just over
REST. The `buendia_concept_placement` obs also record the zone bug and its fix in sequence: the first
patient landed in `[4] Confirmed Zone` at 10:55, the second in `[1] Triage [*]` at 11:06.
The **auto-logout fix was verified too** — a charging tablet no longer drops to the provider picker
after 30 s.

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
- **In-zone install card (WS-5 artefact, plan §3.4)** — `deploy/pkgserver/make-install-card.sh` writes a
  self-contained, print-ready A5 `cards/install-card.html` with **two** QR codes: a `WIFI:`-URI
  **join-Wi-Fi** code (so nobody types a passphrase while gloved; reserved characters escaped and
  round-trip-verified) and the **install** code. Optional per-zone label
  (`./make-install-card.sh "Suspect Zone"`). Print from a browser → laminate → post in every zone
  **including the Red Zone**, so a reset/replacement tablet is re-provisioned in place without
  crossing a contamination boundary. Cards go to `cards/` (git-ignored), never `www/`, because they
  carry the Wi-Fi passphrase.
- **Go/no-go verification tool** — `deploy/tools/buendia-verify.sh` checks that a stack is
  *usable*, not merely up: REST auth (200 / 401 on a wrong password), the location tree, **exactly
  one `[*]` default zone**, `/charts`, Guest provider, the **single-login-row** guard (the lockout
  bug), the active profile, the **six sync triggers' DEFINER resolving**, and the `:9001` install
  path (APK mime type, `206` range, `/dists/stable/Release`, byte-identity with the built APK,
  numeric version). `--quick` is the field go/no-go (REST only, no docker); `--write` admits and
  then voids a throwaway patient — the only check that proves admission works end to end.
  Exit 0/1. Verified against the live stack (16 checks) and a cold throwaway (17 with `--write`),
  and its failure paths were exercised. This is what `setup.sh`'s `health_check()` is not: that
  only proves the ports answer.
- **Throwaway stacks are now actually possible.** Working guideline #7 recommended validating a
  change "on a spare port" but `docker-compose.yml` hardcoded `"9000:8080"`, so it could not be
  done. Now `${OPENMRS_PORT:-9000}` (pkgserver was already parameterized) — defaults are unchanged
  for every real deployment. Verified: a `-p throwaway` stack boots alongside the live one on
  9100/9101 with **its own volumes** (0 patients vs the live 2, full 51k-concept seed), passes
  `--write`, and tears down without touching the live stack.
- **Claude Code skills** — `.claude/skills/` (committed, so they travel with the repo):
  `pilot-stack` (reattach/fresh/throwaway/teardown + the `down -v` guard), `pilot-verify`,
  `pilot-build-kit` (A→Z cold rebuild + the decide-before-you-build ordering), `pilot-site-config`
  (apply an MSF config answer + the cost hierarchy), `pilot-checkpoint` (this close-out routine), `pilot-usb` (stage an install USB + the
  one-bundle/one-payload and address-match traps).
  They carry procedure and guards only, and point here for the facts, to avoid drifting from §4.
- **Client `drc-pilot` branch** — `SolDevelo/buendia-client` now has a `drc-pilot` branch matching
  this superproject branch, and `.gitmodules` records `branch = drc-pilot`. Pilot client code
  changes land there. First change: the auto-logout fix below.
- **Registry delivery: internet at SETUP, none at runtime (2026-07-29).** The deployment model is
  now *"`docker pull` is enough"*. The heavy, awkward artefacts travel inside the images instead of
  as files someone must copy onto the server:
  - `deploy/seed/build-db-image.sh` bakes the ~83 MB baseline seed into **`DB_IMAGE`**
    (`buendia-db:5.6-<gitsha>`, 386 MB; only ~83 MB of new layer to push). It refuses to bake a
    dump lacking mysqldump's `Dump completed` marker, and stamps the seed sha256/bytes/git-sha as
    image labels for provenance.
  - `deploy/pkgserver/build-pkgserver-image.sh` bakes the generated `www/` (the **APK** + index +
    `Release` stub) into `buendia-pkgserver:<site>-<apkver>`, so the tablet APK reaches the site the
    same way. ⚠️ That image is **site-specific** — the APK inside bakes in the server address and
    password.
  - The 12 KB `20-buendia-site.sql` stays **committed and bind-mounted**, so locations/accounts are
    still tailorable with no image rebuild or push.
  - `deploy/tools/publish-images.sh` tags + pushes to Docker Hub **`soldevelo`** (public — no
    registry credential needed on the site server; `REGISTRY_USER`/`REGISTRY_TOKEN` supported if it
    ever goes private). It **plans by default** and only pushes with `--push`, resolves `:latest` to
    the concrete git-sha tag rather than publishing a floating tag, and prints the digests to paste
    into `.env`.
  - `deploy/tools/bundle-images.sh` produces the `--offline` fallback (`images/*.tar`, **771 MB**
    measured, plus a MANIFEST with sha256s) for rebuilding on site with no connectivity. **Verified**:
    the tarballs load back with `docker load`. Previously `--offline` was impossible — `images/` and
    `debs/` held only `.gitkeep` and nothing produced them.
  - **Verified end-to-end**: the live stack was torn down (`down -v`) and cold-booted from the baked
    DB image with only the single-file site mount — DB healthy in 41 s, whole stack in ~90 s, and
    `buendia-verify.sh --write` passed **17/17 → GO** (admit + void included).
- **`setup.sh` is now a deliverable, not a sketch (2026-07-29).** Six real defects fixed, and its
  exit code now means something:
  - it ends by running **`buendia-verify.sh`** and returns non-zero on NO-GO (it previously
    finished with `health_check || true`, so it reported success even when unhealthy — and
    `health_check` only proved the ports answered);
  - **`--dry-run`** prints every change and makes none, so the run can be rehearsed before it
    touches a machine (this is what caught three of the bugs in §4);
  - the seed check looked in `seed/*.sql`, **the wrong directory**, so it always warned "DB will
    start empty"; it now checks the image's baked-seed label and **fails** if absent;
  - **netplan is generated from `.env`** — the checked-in `config/netplan/60-buendia.yaml` (with a
    hardcoded `192.168.8.10` and `enp1s0`) is **deleted**. It was a second source of truth for the
    address that every tablet bakes in. The interface is autodetected, Wi-Fi is handled, a failed
    apply is now **fatal**, and the script confirms the address actually landed;
  - `DOCKER_VERSION` was accepted in `.env` and silently ignored — now honoured;
  - `apt-get install chrony` ran before the first `apt-get update` (fails on a fresh image), and
    `systemctl restart docker` ran on every re-run, bouncing a healthy stack for nothing;
  - plus: placeholder detection (refuses to deploy a `.env` still holding `CHANGE_ME` /
    `REPLACE_WITH_DIGEST`), a digest-pinning warning, an RTC-readable check (timestamps depend on
    it), and a per-box staging record appended to `/var/log/buendia-setup.log`.
- **APK signing key is BACKED UP** (2026-07-29, per PW) — on SolDevelo's internal system and a
  second location on the build machine. This was the kit's biggest single-point loss risk; closed.

### Decisions taken with MSF (2026-07-29)

- **Tablet provisioning: MSF supplies the tablets with their own system image**, reused from previous
  projects, and the Buendia APK is installed **by QR code after the server is up**. This settles the
  shape of **B4**, but the image's contents are unknown to us and the QR path has hard prerequisites
  (sideload permission, a browser + scanner, no MDM install block) — see the new **B5**, and ask for
  **one tablet with that image** before staging.
- **The site already has a Wi-Fi network** → we probably **skip the router**, and instead need a free
  address on their subnet that tablets can reach. This removes procurement but adds real risk
  (client isolation, DHCP we don't control) — see the rewritten **B2**.
- **Server hardware is SolDevelo's call** — we produce the specification and suggest models. Not
  started; it gates a real `setup.sh` run.
- **Site architecture** (tents in a field vs a building with a triage yard/hall) — asked, **no answer
  yet**. It drives Wi-Fi coverage, power and the zone tree.

### Decisions taken internally (2026-07-29, PW)

- **The tablet password is NOT a setup-time parameter — deliberately rejected.** It is compiled into
  the APK as a plain string resource, and the Android toolchain isn't on the site server, so setup
  could only change the *server* half. A `SERVER_PASSWORD=…` option would therefore rely on the
  operator supplying a value that happens to match the APK — and a mismatch stops every tablet
  syncing. Accepted instead: **the APK's value is the default**, and the shipping build should carry
  the real one.
  **Correction (PW):** the baked values are only *defaults for runtime preferences* — the tablet's
  **server address, username and password are all editable in the app** (`res/xml/pref_general.xml`
  keys `openmrs_user`, `openmrs_password`, plus the "Buendia server" setting): cog → Settings →
  change → save, which a non-technical person can do from a guide. So changing them later costs **a
  guided manual step per tablet, not a reinstall** — this downgrades **A5** and **B1** from
  "blocking" to "cheap but manual, ×N tablets". Two caveats keep them worth settling early: the step
  must be done on *every* tablet (including any inside a contamination zone), and until it is done
  that tablet cannot sync. In practice the baked default is what will be used, because nobody
  changes a working setting.
- **The APK is a credential, so it ships privately: a private GitHub release asset.** The password
  is readable out of the APK with one `aapt dump --values resources`, so publishing the APK publicly
  publishes the site's server password. Chosen over a private Docker Hub repo because a **fine-grained
  GitHub PAT can be scoped to one repo, read-only**, whereas a Docker Hub read token can pull every
  private repo in the account — and this token ends up in a shell history on a laptop in the field.
  - The unit is the whole generated `www/` (`pkgserver/pack-www.sh` → `pkgserver-www-<site>-<ver>.tar.gz`,
    8.1 MB, git-ignored), because the update index, landing page and QR **all embed the server
    address** — and shipping it whole means the target needs no python/segno/qrencode.
  - `setup.sh` fetches and unpacks it (`APK_SOURCE=auto|github|local|none`), verifies a sibling
    `.sha256` asset when present, and **skips the download when `www/` is already populated** (a
    re-run, or an offline USB install).
  - The token comes **from the environment only** — never `.env` (which travels to the site server)
    and never the staging log: `GITHUB_TOKEN=… sudo -E ./setup.sh`.
  - `buendia-db` and `buendia-openmrs` stay **public** (no secrets, no registry login on site).
    `build-pkgserver-image.sh` remains for a private-registry/USB workflow but is not the ship path.
- **`curl … | bash` rejected** for the installer: a tagged release + sha256 check gives the same
  ergonomics while staying reproducible and auditable, and the ~800 MB of images comes from Docker
  Hub either way. (Also note `PASS=x curl … | sh` passes the variable to *curl*, not to the shell.)
- **`setup.sh` will be tested on real hardware soon** — an old notebook with **Ubuntu 24**. That
  test found its first bug before it even ran: the generated netplan hardcoded `renderer: networkd`,
  which is wrong on Ubuntu **Desktop** (NetworkManager) and would have silently failed to apply the
  static IP. Now autodetected (`NET_RENDERER` overrides). Verified: this box runs NetworkManager and
  the generated file now says so.

### ✅ VALIDATED ON REAL HARDWARE — 2026-07-29 (second machine, bare Ubuntu 24)

**`setup.sh`'s first run on real hardware succeeded, from a USB stick, on a machine that had never
seen this project.** This closes what was the kit's biggest untested claim.

What was exercised: bare Ubuntu 24 notebook → `deploy/tools/bootstrap.sh` from USB (installs
git/curl, clones the public repo `--depth 1 --no-recurse-submodules`, drops in `.env`, unpacks the
tablet payload after a sha256 check) → `setup.sh` (Docker install, host config, **pull of both
digest-pinned images from Docker Hub**, stack up, go/no-go) → **tablet installed the APK by scanning
the QR from the notebook** → smoke test through the app.

Independently verified **from a different machine** (this box, over the WiFi), not just self-reported:
`buendia-verify.sh --host 192.168.0.250 --no-db` → **13/13 GO**. And in the data:

| | |
|---|---|
| Patient | `TEST/1659 Piotr TESTER` |
| Placement | **`[1] Triage [*]`** (uuid `255800b2`) — the default-zone fix holds on a fresh deployment |
| Obs | `buendia_concept_placement` + datetime, `2026-07-29T14:59:27Z` |
| Order | created `15:01:01Z` — the treatment path works |
| Reachability | `:9000` REST and `:9001` install path both answer across the LAN |

**Reinstalled from the bundle and re-verified (2026-07-30).** After the box was wiped (containers,
volumes, images, network and `/opt/buendia`), it was installed again from the USB — this time via
`bootstrap.sh` + `buendia-deploy-*.tar.gz`, so **no git clone and no internal docs ever touched the
server** — and smoke-tested from the tablet again. Independently re-verified from this box:
`buendia-verify.sh --host 192.168.0.250 --no-db` → **13/13 GO**, and in the data: a genuinely fresh DB
(the previous `TEST/1659` is gone), `TEST/1028` placed in `[1] Triage [*]`, **30 observations** and
**1 order** at `08:29:57Z`. So the bundle path is now the *proven* path, not just the tidier one.

**Unattended restart confirmed (2026-07-29):** the notebook was rebooted — Docker came up on boot,
the stack restarted on its own (`restart: unless-stopped` on all three services), and **the tablet
reconnected and worked** with no intervention. That is the behaviour a site needs after a power cut.
The box was then wiped (containers, volumes, images, network and `/opt/buendia`) and is a clean
target again.

Notes from that run:
- **`CONFIGURE_NETWORK=false`** was used, so netplan was *not* exercised; the box got its address by
  other means. The generated-netplan path (and especially the `wifis:` branch) is **still unproven on
  hardware**.
- **The host clock reads UTC** — `setup.sh` does `timedatectl set-timezone "$TZ"` with `TZ=UTC`, and
  the containers + JVM match. Working as designed: the 16:59 local admission is stored `14:59:27Z`
  and the **tablet displayed it as ~16:59**, confirming the client converts to device-local. **Keep
  `TZ=UTC`.** Only server-rendered/exported output stays UTC — see §4 and **A9**.
- The bootstrap script is now committed as **`deploy/tools/bootstrap.sh`**.
- **The server no longer gets a git clone (changed 2026-07-29, after the test).** The validated run
  cloned the repo, which put `CLAUDE.md`, all of `docs/` (deployment plan, MSF config requests,
  technical review), `.claude/skills/`, the whole source tree and ~76 MB of history onto a box that
  ships to a site and is handled outside SolDevelo. Replaced by **`deploy/tools/make-bundle.sh`** →
  `buendia-deploy-<version>.tar.gz`, **~36 KB**, containing only the nine files the deployment
  actually touches (derived from what `setup.sh` reads, what compose bind-mounts and what
  `buendia-verify.sh` needs) plus a purpose-written operator README. It is an **allowlist**, so a
  file added to the repo later cannot leak by default, and it **fails the build** if `CLAUDE.md`,
  anything under `docs/`, a stray `*.md`, `.env` or `.git` ends up inside. `bootstrap.sh` now
  unpacks that bundle (USB, or `BUNDLE_URL` release asset) instead of cloning, and needs no `git`.
  Verified: the bundle unpacks standalone and `setup.sh --dry-run` completes from it with exit 0,
  and the unpacked target contains no internal files. The bundle carries **no secrets**, so it can be
  a public release asset — only the APK payload stays private.

### Not started / deferred (the remaining pilot work)
- **Server hardware — spec WRITTEN and sent to MSF (2026-07-30), machine not yet chosen.**
  `docs/FIELD-PILOT-SERVER-SPEC.md` is the deliverable we owed, and it is item **D1** in the outgoing
  request. **The recommendation changed shape: a laptop, not a mini-PC** (PW's preference, and it is
  what we actually validated twice). The arguments that decided it: the laptop **battery is a built-in
  UPS** — which is the pilot's main data-loss risk and would otherwise need a UPS bought and wired; the
  **screen is what the tablet scans the install QR from**; a keyboard means on-the-spot
  troubleshooting; and site staff can just use it. `setup.sh` already masks suspend and sets
  `HandleLidSwitch=ignore` (`config/logind.conf.d/buendia.conf`), so the laptop path was already
  engineered for. First suggestion is a **refurbished business laptop** (ThinkPad/Latitude/EliteBook,
  i5+, 16 GB, 256 GB) from Digitec/Brack; fanless mini-PC (Minix NEO Z100-0dB, Shuttle DS10U, OnLogic
  CL260) is documented as the alternative for a permanently dusty tent, with a UPS budgeted.
  Hard constraints recorded there: **x86-64 only** — `mysql:5.6` has no arm64 image and `setup.sh`
  hard-fails, which now rules out **Snapdragon X / "Copilot+" laptops and Apple Silicon Macs**, a large
  share of current retail stock; ~8 GB RAM; SSD; a **healthy RTC battery** (timestamps depend on it —
  no NTP upstream at an offline site).
- **No backup mechanism.** Nothing takes a scheduled snapshot: binlog is deliberately off
  (`docker-compose.yml` says "snapshot backups") but no snapshot mechanism exists, and
  `tools/buendia-export.sh` still has the `DataExportServlet` TODO. The old Debian appliance had
  `buendia-backup`; the container stack dropped it. **After the signing key, this is the biggest data
  risk**: real patient data, one mini-PC, no internet, no copy. Needs an MSF decision too (C2 — may a
  backup leave the site?).
- **UPS / graceful shutdown on low battery** is still a `TODO` in `setup.sh` — MySQL 5.6 killed
  mid-write is the most plausible way this pilot loses data. Gated on the power kit / hardware choice.
- **The shipping APK must be rebuilt at staging** — the tested build bakes in `APK_SERVER=192.168.0.150`
  (this dev box). At staging, set `APK_SERVER` to the site `STATIC_IP` and rebuild.
  The server password is baked in too (`APK_OPENMRS_PASSWORD`). Rotating it later does **not** need a
  reinstall — address/user/password are runtime-editable preferences on the tablet (see the
  correction under *Decisions taken internally*) — but it does need a guided manual step on **every**
  tablet, and that tablet can't sync until it's done. So still cheaper to decide the final password
  and site IP **first**, then build the APK that ships.
- **Multi-tablet not re-tested with the packaged build** — two devices syncing bidirectionally was
  confirmed in an earlier ad-hoc demo, not with this APK.
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
On branch `drc-pilot`, **pushed to `soldevelo/drc-pilot` on 2026-07-30** (previously 6 commits ahead;
the submodule gitlink `85ce064c` was confirmed reachable on the client remote, so a fresh clone +
`submodule update` works):
- **`925dae3a`** — the field-pilot deployment package (containerized server + baked Ebola profile).
- **`bd52103f`** — zero-config first boot (site seed: login + location tree).
- **`73dbbcce`** — the canonical MSF config-request list.
- **`4838b326`** — the reproducible APK build (WS-4) + `.gitmodules` submodule branch.
- **`532f78bd`** — correction: the client's encryption password is inert (see §4).
- **`7d0f5e8e`** — the `:9001` QR-install package server (WS-5).
- **`0ab7ac28`** — pkgserver healthcheck fix (IPv6 `localhost`) + rootless QR fallback (segno).
- **`51c3825e`** — admit new patients to Triage (the default-zone bug found on the tablet).
- **`029c650d`** — config request B4: tablet provisioning (Play Store is not the answer).
- **`8856fa16`** — make the site seed's login account genuinely idempotent (see §4; this bug
  locked the test tablet out mid-session).
- **`82521099`** — close out WS-4/WS-5 after the tablet validation.
- plus the WS-5 finalization commit (in-zone install card, plan corrections, this handoff).

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
# one-time: build image + seed + DB image (artifacts persist on disk)
cd deploy/image && ./build-image.sh --fetch && ./build-image.sh     # → buendia-openmrs:latest
cd ../seed       && ./build-seed.sh                                 # → initdb/10-buendia-base.sql (profile baked)
cd ../seed       && ./build-db-image.sh                             # → buendia-db:5.6-<gitsha>  (seed BAKED IN)
#   then set DB_IMAGE=buendia-db:5.6-<gitsha> in deploy/.env  ← required; compose uses it

# fresh boot
cd ../compose
docker compose --env-file ../.env down -v      # clean slate (drops DB + profile volumes)
docker compose --env-file ../.env up -d        # db loads baked seed + mounted site seed; ~90 s to healthy

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

### State of things RIGHT NOW (2026-07-30, end of session)

**Two machines are involved. Neither holds anything precious — both are reproducible.**

**A. This build box** — the local stack is **running and healthy**, rebuilt cold from the baked DB image:

| | |
|---|---|
| Services | `compose-db-1`, `compose-openmrs-1`, `compose-pkgserver-1` — all healthy |
| Images | `buendia-db:5.6-68e59eeb` (running), `buendia-openmrs:1.10.6-7d0f5e8e` |
| URL | `http://192.168.0.150:9000/openmrs` — login `buendia` / `buendia` |
| Data | empty apart from anything a `--write` check left voided |
| `.env` | `SITE_ID=notebook-test`, `STATIC_IP`/`APK_SERVER=192.168.0.250`, images pinned by **digest** |

⚠️ `deploy/.env` is aimed at the **notebook** (`192.168.0.250`), not at this box. If you rebuild an APK
here for local use, set `APK_SERVER=192.168.0.150` first — otherwise the tablet points at the notebook.

**B. The test notebook** (`192.168.0.250`) — installed from the USB bundle, smoke-tested, verified 13/13.
Holds `TEST/1028` + 30 obs + 1 order. Free to wipe; `pilot-usb` + the stick reinstall it in ~10 minutes.

Re-attach / re-check:
```bash
cd deploy/compose && docker compose --env-file ../.env ps    # local: expect 3× healthy
deploy/tools/buendia-verify.sh                               # local, 16 checks
deploy/tools/buendia-verify.sh --host 192.168.0.250 --no-db   # the notebook, 13 checks
```

**Artefacts on disk** (all git-ignored and regenerable — only `.env` and the signing key are not):
`seed/initdb/10-buendia-base.sql` (83 MB), `apk/buendia-client-1.apk` (baked for `.250`),
`pkgserver/pkgserver-www-notebook-test-1.tar.gz`, `buendia-deploy-<ver>.tar.gz`.
The **USB stick** (`DataTravele`) holds `bootstrap.sh` + bundle + `buendia.env` + payload + the QR PNG;
it is currently unmounted. Regenerate any of it with `make-bundle.sh` / `pack-www.sh`, or follow the
**`pilot-usb`** skill.

To validate a seed/config change without touching the local stack, boot a throwaway alongside it
(own containers, own volumes):
```bash
cd deploy/compose
OPENMRS_PORT=9100 PKGSERVER_PORT=9101 docker compose -p throwaway --env-file ../.env up -d
deploy/tools/buendia-verify.sh --port 9100 --pkg-port 9101 --project throwaway --write
OPENMRS_PORT=9100 PKGSERVER_PORT=9101 docker compose -p throwaway --env-file ../.env down -v
```
Pass the same `-p` and port vars to **every** command in the group, `down` included, or you will act on
the wrong stack.

⚠️ **Use GET, not `curl -I`**, to probe the REST API: `HEAD` on the buendia resources returns **500**
while `GET` returns 200. Harmless (the client only uses GET) but it will send you chasing ghosts.

### Publishing the APK for tablet install (QR code)

```bash
cd deploy/pkgserver && ./publish.sh          # generates www/ from the newest built APK + prints the QR
cd ../compose && docker compose --env-file ../.env up -d pkgserver
# tablet: scan the QR, or open  http://<STATIC_IP>:9001/latest.apk
```
QR generation needs no root: **`segno` is installed** (`python3 -m pip install --user segno`) and
`publish.sh` / `make-install-card.sh` use it. `qrencode` also works if present.

```bash
./make-install-card.sh                 # printable in-zone card -> cards/install-card.html
./make-install-card.sh "Suspect Zone"  # ...with a zone label
```
Set `SITE_WIFI_SSID` / `SITE_WIFI_PASSWORD` / `SITE_FACILITY_NAME` in `deploy/.env` first, or the
card prints a blank line to fill in by hand.

⚠️ **`deploy/.env` is `source`d by bash**, so quote any value with a space or a shell metacharacter
(`; & | $ \ ' " * ?`). `NAME=DRC Pilot Site` or a passphrase containing `;` aborts the scripts with
"command not found". docker compose itself is fine with them — this bit only the shell scripts.

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
- **`users` has NO unique index on `uuid` — `ON DUPLICATE KEY UPDATE` does not de-duplicate it.**
  `location`, `person`, `person_name` and `provider` all have a unique uuid index; `users` does not.
  Re-applying `20-buendia-site.sql` to a running server therefore inserted a **second `users` row
  with the same uuid and username**, and OpenMRS then rejected **every** login with *"OpenMRS username
  or password incorrect"* — even though both rows held a correct password hash, which makes it a
  confusing failure to diagnose. Hit on 2026-07-29 and it locked the test tablet out.
  **Recovery:** `DELETE FROM user_role WHERE user_id=<higher>; DELETE FROM users WHERE
  user_id=<higher>;` — keep the **lower** id, that's the row tablets authenticate against — then any
  endpoint with `?clear-cache`. **Fixed** in the seed with an explicit `NOT EXISTS` guard + a
  following `UPDATE`, plus a self-check that prints `FATAL` when more than one row holds the login
  username. Verified idempotent over three consecutive applies.
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
- **A directory bind-mount SHADOWS a file baked into the image at the same path.** The baseline seed
  now lives inside `DB_IMAGE` at `/docker-entrypoint-initdb.d/10-buendia-base.sql`; compose used to
  mount the whole `../seed/initdb` directory there, which hides it. Result: a DB with **no schema and
  no concepts**, on a server that otherwise appears to boot normally. Compose now mounts the **single
  file** `20-buendia-site.sql`. `setup.sh` also refuses to start a stack whose `DB_IMAGE` carries no
  baked-seed label, so this cannot ship silently broken.

### Packaging traps (2026-07-30)

- **`local a="$1" b="$a"` in ONE declaration is fatal under `set -u`.** Bash marks every name in a
  single `local` as local *before* performing the assignments, so `$a` is unset while evaluating `b`
  → "unbound variable". Split it into two `local` statements. Hit in `make-bundle.sh`.
- **A glob whose "last match wins" silently selects the wrong artefact.** A build machine accumulates
  payloads for several server addresses (`pkgserver-www-pilot-1`, `pkgserver-www-notebook-test-1`),
  and glob order is alphabetical, so "pilot" beat "notebook-test" for no reason anyone could guess.
  Since the APK bakes in a server address, the wrong payload **installs cleanly and then never
  connects**, with nothing on the box to explain why. `bootstrap.sh` now refuses an ambiguous USB
  (lists the candidates, exits 1) rather than choosing. Prefer failing closed over picking.
- **A deployment must not be a git clone.** See §2: the bundle is an **allowlist** of the nine paths
  the deployment touches, and `make-bundle.sh` fails the build if `CLAUDE.md`, anything under `docs/`,
  a stray `*.md`, `.env` or `.git` appears inside. A denylist would leak whatever the repo gains next.

### Timezone: the stack is UTC end-to-end, and it shows (A9)

- `setup.sh` sets the **host** timezone from `TZ` in `.env`, and compose passes the same `TZ` to
  MySQL and `-Duser.timezone=UTC` to the JVM. With the shipped `TZ=UTC` the whole box reads UTC:
  on the 2026-07-29 notebook test, an admission done at **16:59 local (UTC+2)** was stored as
  **`14:59:27Z`** and the desktop clock showed 14:59. That is by design (UTC end-to-end fixed an
  earlier timezone bug) but it **will** be noticed at a DRC site (UTC+1/+2) for shift boundaries and
  "when was this taken".
- **✅ ANSWERED on the tablet (2026-07-29): the client renders times in DEVICE-LOCAL.** The admission
  stored as `14:59:27Z` displayed as **~16:59** on a UTC+2 tablet. So **keep `TZ=UTC`** — the UTC
  storage is purely internal, clinicians already see local time, and we avoid touching the setting
  that was chosen to fix an earlier bug. **Do not "fix" this.**
- **Residual, still open:** *server-rendered* output is not converted — the OpenMRS admin web UI, the
  printable patient record, and `DataExportServlet` CSV will read **UTC**. So a printed or exported
  record is 1–2 h off local wall-clock at a DRC site. That is the part of **A9** MSF still needs to
  rule on (and it lands in WS-7 / **C2** for exports).
- **Two dependencies this creates on the tablets** (see **B5** q8): the stored instant comes from the
  *tablet's* clock (`JsonEncounter.time` is client-supplied), so a wrong tablet clock writes wrong
  data; and the displayed time depends on the tablet's *timezone* being right. Both must be verified
  per device at staging — the server cannot compensate for either.

### REST quirks that look like faults but aren't

- **`?since=` with an EMPTY value returns zero results.** `GET /observations` (no param) returns the
  data; `GET /observations?since=` returns an empty set. Cost a false "the smoke test wrote nothing"
  conclusion on 2026-07-29. Omit the parameter rather than passing it empty.
- **`GET /encounters` returns `UnsupportedOperationException: Listing all encounters is not
  implemented`.** Expected upstream behaviour, not a broken deployment. Encounters come back nested
  inside `/patients` and via the obs sync endpoints.

### Shell traps in the deploy scripts (all three cost real debugging time on 2026-07-29)

- **`[[ test ]] && cmd` as the LAST statement of a function is fatal under `set -e`.** When the test
  is false the list returns 1, the function returns 1, and the *function call* trips `set -e` — so
  the run aborts. In `load_images()` this was the line pulling `PKGSERVER_IMAGE`, which is **empty by
  default**, so the default path aborted `setup.sh` immediately before starting the stack. It looked
  like a clean finish because the exit code being printed was a `tail`'s, not the script's. Use an
  explicit `if`, and check exit codes of the script itself, not of a pipeline ending in `tail`/`head`.
- **`set -o pipefail` + a `| grep` that matches nothing = script death with no output.** grep returns
  1 on no match, pipefail propagates it, and inside `var="$(...)"` that trips `set -e` before
  anything is printed. Bit `publish-images.sh` (no pkgserver image built yet — a normal state) and
  `detect_iface()`. Append `|| true` to any pipeline whose "no results" case is legitimate.
- **YAML double-quoted scalars treat `\` as an escape character.** Writing a Wi-Fi passphrase as
  `password: "…"` makes the file unparseable (or silently changes the value) when the passphrase
  contains a backslash. Generated netplan now uses **single quotes with embedded `'` doubled**, which
  has no escapes at all. This would have failed at `netplan apply` on a box about to be shipped.
- **netplan: a wireless interface must be declared under `wifis:`, not `ethernets:`**, with an
  `access-points:` stanza. And interface autodetection *by default route* picks Wi-Fi on any laptop —
  so this is the common case, not an exotic one. `setup.sh` detects wireless
  (`/sys/class/net/<if>/wireless`) and either generates a `wifis:` block from
  `SITE_WIFI_SSID`/`SITE_WIFI_PASSWORD` or refuses with instructions.

---

## 5. Workstream status (see plan §4 for detail)

| WS | What | Status |
|----|------|--------|
| WS-1 | Server container stack + packaging | ✅ done. Installer hardened (6 defects fixed, `--dry-run`, netplan generated from `.env`, go/no-go wired in) and **validated on real hardware 2026-07-29** — bare Ubuntu 24 notebook → USB bootstrap → GO, verified remotely 13/13, tablet installed by QR. Netplan branch still unexercised (`CONFIGURE_NETWORK=false` was used) |
| WS-2 | Seed data + profile bake | ✅ done (db-snapshot + bunia.csv baked + zero-config site seed: login & locations). **Seed now baked into `DB_IMAGE`** so it travels by `docker pull` |
| WS-3 | Reproducible image build + registry delivery | ✅ done (`build-image.sh`, `build-db-image.sh`, `build-pkgserver-image.sh`, `publish-images.sh`, `bundle-images.sh`). Internet at setup, none at runtime; cold-boot verified 17/17 |
| WS-4 | Android APK build + real-tablet validation | ✅ **done** — reproducible release-signed build (`deploy/apk/build-apk.sh`) installed on a real tablet by QR and validated through the full clinical workflow (2026-07-29). Two loose ends are *deployment* steps, not build work: **back up the signing key**, and rebuild with the real site `APK_SERVER`/password at staging |
| WS-5 | APK delivery (QR first install + in-zone card) | ✅ **done** — `deploy/pkgserver/` serves the APK on `:9001` and a real tablet installed from the QR (2026-07-29); `make-install-card.sh` produces the laminatable in-zone card (Wi-Fi-join + install QRs) required by plan §3.4. **In-app OTA withdrawn** as unachievable on v1.0 (§4) — updates are a documented manual re-install, and the plan's acceptance criterion was revised accordingly |
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

**➡️ NEXT SESSION STARTS HERE — the technical kit is done and twice proven on hardware. What
remains is documentation, MSF's answers, and two real gaps (backup, hardware).**

1. **WS-6 — the three runbooks** (plan §WS-6, ~2–3 days). This is now largely *transcription*: the
   procedure has been executed twice end to end, and every gotcha is in §4.
   - **`STAGING-SETUP-GUIDE`** — the flow that was actually validated: `make-bundle.sh` →
     `publish.sh` + `pack-www.sh` → stage the USB (`pilot-usb` skill) → `bootstrap.sh --dry-run` →
     `bootstrap.sh` → `buendia-verify.sh` → tablet by QR → label and pack.
   - **`SITE-RUNBOOK`** — non-technical MSF staff: power-on, the single go/no-go
     (`buendia-verify.sh --quick`), add/replace a tablet, troubleshooting, and the from-USB
     reinstall appendix (which is now a genuinely short procedure).
   - **`CLINICAL-QUICKSTART`** — add providers, upload/activate a profile, extend the location tree.
   **No pandoc on this box** (needs root) — print the Markdown from a browser, as
   `make-install-card.sh` already does.
2. ✅ **Config-request list prepared for MSF (2026-07-30) — send it.** The send-ready extract is
   `docs/FIELD-PILOT-MSF-REQUEST-OUTGOING.md`, plus `docs/FIELD-PILOT-SERVER-SPEC.md` as an
   accompanying attachment. Reordered by lead time, not by the internal A/B/C grouping: **B5** (what
   their tablet image permits — can invalidate the QR install path outright), **B6/B2** (their IP space,
   and why a "probably free" address is unreachable), **B1**, **D1** (hardware), **C1**
   (data-protection, gates WS-7) come first; the clinical items follow. Each item is tagged with who at
   MSF owns it (clinical / IT / programme / data-protection) so the mail can be routed, and it ends with
   a fill-in summary table. **Remaining action is non-technical: actually send it** and log answers back
   into the canonical `FIELD-PILOT-MSF-CONFIG-REQUESTS.md`.
3. **Backup — the largest remaining technical gap.** Nothing snapshots the DB; binlog is off and
   `tools/buendia-export.sh` still has the `DataExportServlet` TODO. Needs an MSF decision too
   (**C2**: may a backup leave the site?). One mini-PC holding the only copy of patient data.
4. ✅ **Server hardware spec written** (`docs/FIELD-PILOT-SERVER-SPEC.md`, 2026-07-30) — **recommends a
   repurposed or refurbished business laptop**, not a mini-PC; see the hardware entry under *Not started
   / deferred* for the reasoning. Now waiting on MSF (**D1**). Once the shape is known it unblocks the
   **UPS/graceful-shutdown TODO** at `setup.sh:186` — on a laptop this is UPower battery thresholds,
   which is much simpler than wiring Network UPS Tools to an external UPS — and gives a box on which
   the netplan path can be tested without disturbing anything.
5. **Test the untested branch:** `CONFIGURE_NETWORK=true` — generated netplan, and especially the
   `wifis:` block — has **never been applied on hardware**. Both real installs used
   `CONFIGURE_NETWORK=false`.
6. **Optional, cheap:** publish `buendia-deploy-<ver>.tar.gz` as a release asset on the public repo so
   `bootstrap.sh` can fetch it via `BUNDLE_URL` with no USB.
7. **WS-7 — remote-support tunnel + data export**, once **C1** signs off.

Also outstanding, unrelated to any workstream: the pre-existing strays in the tree
(`tools/profile_applyc`, `docs/PROFILE-CSV-FORMAT.md`, an `.idea/` change) still need review/removal —
they predate this work. Both branches (superproject and client submodule) are now pushed to `soldevelo`.

*(The old note here — that the local stack ran a hand-configured DB — no longer applies: it was
rebuilt cold from the seed on 2026-07-29. See §3 for its current state.)*
