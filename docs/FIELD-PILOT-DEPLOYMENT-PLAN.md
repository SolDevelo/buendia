# Project Buendia — Minimum Field-Pilot Deployment Plan

**Scope shape:** "Minimum field-pilot (1–2 weeks)" from `docs/TECHNICAL-REVIEW.md` §3.
**Goal:** the leanest path to a *working* Buendia system on-site — on the users' tablets, against an on-site server.
**Companion document:** `docs/TECHNICAL-REVIEW.md` (bug numbers below, e.g. "bug 9", refer to its bug list).

This plan covers **development work and documentation only**. Hardware procurement, staging, and physical delivery are MSF's (see Parties). The output is a single, self-contained **deployment bundle** plus runbooks that MSF uses to stage, test, deploy, and operate the system.

---

## Parties & responsibilities

| Party | Role | Responsibilities |
|---|---|---|
| **SolDevelo** | Technical | Builds the **deployment bundle** (server container stack, seed data/config, signed APK) and the **runbooks**. Provides the reproducible build. Consults and advises (hardware specs, network/Wi-Fi, environment, troubleshooting). Does not procure hardware or travel to site. |
| **MSF** | Execution + domain knowledge | Procures the devices (server PC, tablets, router, power kit). Operates the **Staging Area**: installs the bundle, runs the quick test. Delivers and sets up the system on-site. Owns all domain/clinical knowledge and site specifics (facility, ward/bed structure, clinician accounts, form content). |
| **Users** | Operation | Clinicians and staff at the site who use the system for patient care. The on-site experience (power-on, login, data entry) is designed around them. |

Consequences for this plan:
- The Staging Area is operated by MSF's technical person, who installs the SolDevelo-built bundle and runs the quick test before delivery.
- The Site Area runbook targets non-technical staff (power-on + verify + recover); the Staging Area setup guide targets MSF's technical staff.
- The open items in §8 are MSF's to decide; SolDevelo advises.
- SolDevelo's deliverables are portable: bundle and runbooks must work for any devices within the §3 specs and any Staging Area.

---

## 1. Definition of done

**Confirmed on-site, with no Internet** (run during the Staging Area quick test, and briefly again at site go-live):

1. The server boots, brings up MySQL + OpenMRS, and serves the Buendia REST API on the local network.
2. A clinician on a **CrossCall Core-T5** and on a **CrossCall Core-T4** can: log in → browse the location tree → add a patient → assign a bed → open the chart → open a form → enter vitals → save → **see the saved values persist** (the round-trip that the timezone bug breaks — bug 1).
3. Both tablets see each other's data: data entered on the T4 appears on the T5 after sync, and vice-versa (normal multi-tablet operation).
4. The workflow survives a server power-cycle (data is on the server).
5. Tablets receive their **first APK install** over the local Wi-Fi via QR/URL (WS-5).

**Verified by SolDevelo, not re-tested at initial setup:** the **OTA update channel** — a new signed APK on the server installs on the tablets over local Wi-Fi. SolDevelo proves this once in WS-5 (its acceptance test). Neither the Staging nor the Site Area pushes a fresh APK during initial bring-up to test it; OTA is exercised later, when an actual update ships. (First install at the site is the QR/URL step in item 5, which is a different path from OTA.)

Not required for "done" (deferred to §7): hardening of the narrow *same-patient simultaneous-write* edge case (ordinary multi-tablet use **is** in scope, item 3); the bespoke SBC appliance; central multi-site management (one dashboard across many facilities — irrelevant to a single site; this site's tablets are managed by hand per WS-5).

---

## 2. Scope

**In scope:**
- A containerized, deployable server stack (replaces the bespoke Edison/Debian appliance for the pilot).
- A signed, pilot-configured Android release APK (functionally validated by SolDevelo; final T4/T5 confirmation at staging).
- Seed data + site/profile configuration.
- A reproducible build.
- A Staging Area setup guide, a Site Area runbook, and a clinical-admin quick-start.

**Out of scope (deferred — see §7):** the `buendia-*` Debian appliance rebuild and Raspberry-Pi/SBC form factor (also what a server-hosted Wi-Fi AP would require — the pilot uses a standalone router instead, §3.3); Python 3 port of profile-apply; same-patient simultaneous-write conflict hardening (ordinary multi-tablet sync is in scope; only the concurrent-conflict edge case is deferred); anything in TECHNICAL-REVIEW §4.

### 2.1 Installation model — two environments

The deployment is defined by **capability, not geography**:

- **Staging Area** — any location with **Internet access and a technical person**. SolDevelo delivers the software **pre-built** (server image tarballs, signed APK, seed data, compose file — §5); the Staging Area **installs finished artefacts, it does not build from source**. Work: on the procured PC's fresh Ubuntu install, run the bundle's setup script (applies the static-IP netplan + unattended-operation hardening), load the container images, start the stack; install the signed APK on every tablet; run the quick test (the §1 round-trip); then power off, pair, label, and pack the kit (server + tablets + router + cables + UPS/power banks).
- **Site Area** — the field hospital. **No Internet, non-technical staff.** Work: unpack, connect the power chain, power on, verify "green," use. Adding or replacing a tablet = join Wi-Fi + scan QR (WS-5). Nothing is built or configured here.

Everything technical happens at a Staging Area; the Site Area only powers on a kit that already works. The Site Area runbook is therefore a power-on + verify + recover guide, with a fallback re-install appendix (the from-USB path) for the rare case where the kit must be rebuilt — which must itself happen at a Staging Area, never in the field.

**Build vs. install boundary.** All compilation, dependency wrangling, and the reproducible build (WS-3) happen at SolDevelo, before anything reaches a Staging Area; the broken-toolchain problems (dead Bintray/JCenter mirrors, Java-7 pinning) are solved once. The Staging Area consumes finished artefacts and installs them on the procured devices (which only MSF has). The Staging Area's skill bar is "follow an install checklist," not "build Android/OpenMRS from source." Once MSF fixes the server hardware model, SolDevelo may instead ship a full pre-built server disk image to flash, reducing the Staging Area's server step to "flash and boot"; until then the portable artefact bundle is the default.

---

## 3. Target environment

### 3.1 On-site server

The pilot runs the server on a generic machine via Docker Compose, skipping the custom SBC appliance. Requirements follow from the stack: MySQL 5.6 + OpenMRS 1.10.6 (Tomcat 7 / Java 7) in containers, x86-64.

**Specification — small x86-64 mini-PC (NUC-class):**

| Attribute | Minimum | Recommended | Rationale |
|---|---|---|---|
| CPU | x86-64, 2 cores | x86-64, 4 cores | x86-64 so the stock `mysql:5.6` and Tomcat/Java-7 images run without ARM rebuilds. |
| RAM | 4 GB | 8 GB | JVM heap + MySQL buffer pool + OS. 4 GB covers ~5–10 tablets; 8 GB is comfortable. |
| Storage | 64 GB SSD | 128 GB+ SSD | DB, backups, container images, APK. SSD for DB write latency. |
| OS | Ubuntu Server 22.04/24.04 LTS (or Debian 12) | same | First-class Docker support; long support window; runs headless. |
| Networking | 1× Gigabit Ethernet | same | Wired link to the Wi-Fi router (§3.3). |
| Power | mains | mains **+ UPS** | A power blip mid-write must not corrupt MySQL; a laptop's battery counts. |

**Acceptable alternatives:**
- A business laptop running Ubuntu — battery doubles as a UPS; lid-close set to "do nothing," but run it **lid-open** for cooling (§3.1 hardening, §7 heat).
- Intel NUC / Beelink / MinisForum-class mini-PC — small, quiet, low-power, 24/7.

**Excluded:**
- Windows/macOS + Docker Desktop — adds a VM layer, licensing, and a GUI dependency; unsuitable for an unattended box. Use bare Linux + Docker Engine.
- Raspberry Pi / ARM SBC — MySQL 5.6 and the Java-7 OpenMRS images are x86; running them on ARM is the appliance-rebuild work this scope avoids (production scope, TECHNICAL-REVIEW §3).

**Unattended-operation hardening (required).** The server runs unattended and is power-cycled by non-technical staff. A setup script in the bundle applies the following host configuration to the fresh Ubuntu install at the Staging Area, so that:
- Closing the laptop lid does nothing (`logind.conf`: `HandleLidSwitch=ignore`, `HandleLidSwitchExternalPower=ignore`, `HandleLidSwitchDocked=ignore`). The screen may turn off; the server keeps running. This is a safety net against an accidental close — **not** a recommendation to run closed: in a hot environment a closed lid traps heat (laptops vent through the keyboard deck), so a laptop server should run **lid-open** with airflow (§7 heat).
- Suspend / sleep / hibernate are disabled (`systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target`). Screen blanking is acceptable; suspend is not.
- Containers start on boot and restart on crash (`restart: unless-stopped` on every service; `systemctl enable docker`), so a cold power-on brings the stack up with no human action.
- No desktop auto-login is required; the stack runs as a system service.
- A status indicator (a small always-on local web page, or the OpenMRS login page) lets staff confirm "green." The runbook names this as the single check.
- Graceful shutdown on low battery / UPS signal — the script configures it (laptop battery, or `nut`/USB signal from a UPS) so MySQL stops cleanly. Abrupt power loss otherwise relies on InnoDB crash recovery, which the design does not want to depend on.
- Log rotation and disk-use caps — Docker `json-file` `max-size`/`max-file`, journald `SystemMaxUse`, and app/DB log rotation — so an unattended box cannot fill its disk over a long deployment. **MySQL binary logging is left disabled** (the default; not needed for a single-server pilot — the backup is a volume snapshot, not point-in-time replay). If ever enabled, cap it with `max_binlog_size` + `binlog_expire_logs_seconds`.

### 3.2 Tablets — CrossCall Core-T4 and Core-T5

| | Core-T4 | Core-T5 |
|---|---|---|
| Android | 9 Pie (some units 10) | 11 (→ 12) |
| SoC | Snapdragon 450 (arm64-v8a, runs 32-bit) | Snapdragon 665 (arm64-v8a, runs 32-bit) |
| RAM / storage | 3 GB / 32 GB | 4 GB / 32–64 GB |

Build implications:
- The app installs on both: `minSdk 19`, and neither tablet is Android 14+, so the `targetSdk` install threshold (bug 6) does not apply. The committed `targetSdk 24` already clears it.
- Bug 9 (telephony `SecurityException` on Android 10+) is the one true blocker: it crashes the app on launch on the T5 (Android 11) and on any T4 on Android 10. Already fixed in the committed `PropertyManager.java` (try/catch around `getDeviceId`/`getSubscriberId`/`getSimSerialNumber`); verify on real hardware.
- Bug 8 (32-bit SQLCipher libs): both SoCs run 32-bit, so it never blocked these devices; the libs are already removed.
- No app-level DB encryption in v1.0 — the code uses plain Android SQLite (not SQLCipher), and `ENCRYPTION_PASSWORD` is inert. Data-at-rest is covered by **Android device encryption + a mandatory screen lock** (decided, §8); SQLCipher is not re-introduced. The local DB is a cache, rebuildable from the server.
- Both tablets support glove/wet-touch — matches Buendia's gloved-use UI.
- Both are IP68 (rugged and washable), suiting a treatment-unit environment. The server and router are not rugged and stay in a clean zone (§7).

**Build principle: target the deployed Android versions only.**
- Freeze the client at the `v1.0` baseline; apply only the fixes needed for Android 9–12 (the telephony try/catch, harmless on Android 9 where it may not even throw). Do not pull in unrelated upstream changes.
- Keep `targetSdkVersion 24`. It is the floor that already triggers the runtime-permission model these devices use, and it opts the app out of the stricter scoped-storage/permission behaviors of newer targets. A higher target adds risk and no benefit for T4/T5.
- Do not do bug 7 (`android:exported`) or any SDK-31+ work; that is only needed to target 31+, which the pilot does not.
- Real-device behavior is confirmed on the actual T4/T5 at staging (not just an emulator); SolDevelo's own gate is an emulator + a representative arm64 device (see WS-4).

### 3.3 Network & power

The pilot does not run the server as a Wi-Fi access point. Topology:

- One off-the-shelf Wi-Fi router at the site. The server connects by Ethernet; tablets join the router's SSID.
- The network is predetermined by the bundle; the installer never inspects or chooses an IP. One address (e.g. `192.168.8.10`) is fixed and shipped three ways:
  1. A static-IP netplan config for the server's wired interface is applied by the bundle's setup script at the Staging Area.
  2. The router config is pre-set (SSID, password, matching subnet) and shipped paired with the server; a DHCP reservation for the server's MAC is the belt-and-suspenders backup.
  3. The APK is built with the same IP baked in (`-Pserver=192.168.8.10`) plus `-PrequireWifi=true`.

  Result: power on the router, power on the server, and the tablets already address the server — no command line, no IP lookup.
- No Internet is required at the site for clinical use or OTA updates.
- UPS on the server; router on a power bank (§7 power chain).

**Router specification.** A mini/travel router: low power (USB-powered, can run from a power bank); dual-band; able to operate as a plain access point and as a mesh node (for the coverage fallback); and supporting **custom local DNS overrides** (OpenWrt/GL.iNet-class dnsmasq), required for the local-NTP-via-DNS-interception in §3.4. Specific model is an open procurement item (§8). Wi-Fi throughput is never the bottleneck — clinical sync traffic is kilobytes of JSON every 10 s, easily handled for 5–10 tablets. **Coverage of the ward is the constraint.**

Coverage characteristics of a single small router:
- Range vs. walls: small antennas and low transmit power give solid coverage to ~10–15 m line-of-sight, degrading quickly through walls.
- 2.4 GHz penetrates walls better than 5 GHz and is the preferred band for a spread-out ward (range over speed).
- Drywall / wood / glass: typically holds through 1–2 interior walls.
- Concrete, brick, cinder block, or metal (common in field hospitals and metal-framed tents): expect difficulty past 1 wall; signal can dead-zone.
- Open ICU bay or single room: one router is likely sufficient. Linear ward with walled bays, multi-room building, or a spread-out tent compound: a single router will likely leave dead zones at the far beds.

Coverage provisioning:
- The runbook includes a coverage walk-through (carry a tablet to the farthest/most-walled bed and confirm a form saves).
- The bundle carries a coverage fallback: an additional access point or mesh node (and an Ethernet cable for a cabled AP). Within an open ward, a PoE AP on an Ethernet drop is the most reliable extension where cabling is feasible; across a Green/Red zone boundary, prefer wireless backhaul instead (see the zone-boundary note below).
- Extending coverage is a Wi-Fi-layer concern only; no Buendia config changes when adding a mesh node or AP, provided it is the same LAN/SSID and the server keeps its static IP.

Ward layout and construction (§8) determine whether one router suffices or a mesh/AP fallback is needed.

**Coverage across a Green/Red zone boundary.** Extending Wi-Fi into a contaminated (Red) zone is an IPC concern, not just an RF one — a cable crossing the boundary cannot be decontaminated and physically bridges the barrier, so it is avoided. Preference order:
1. Cover the Red Zone *from* the Green Zone with one well-placed router (or higher-gain antennas). ETU barriers are often plastic sheeting, which is largely RF-transparent, so no electronics need cross the boundary at all — the cleanest IPC outcome.
2. If that is insufficient, place a **wireless mesh node in the Red Zone, backhauling over the air** (same SSID, no Buendia config change). It is then zone-dedicated, contaminated equipment: in a wipeable/sealed enclosure, powered locally (power bank or Red Zone mains), decontaminated in place or treated as consumable — it does not return to the Green Zone.
3. A cabled AP across the boundary only if wireless backhaul cannot penetrate a solid barrier, and only as an IPC-approved exception.
Barrier material (plastic sheeting vs. concrete/metal) decides which applies — an §8 ward-layout input. Confirm with MSF's IPC / field-engineering teams.

### 3.4 Offline resilience & recovery

The site has no Internet and no remote access; the system must stay correct unattended and remain debuggable by post.

**Time / clock.** Buendia's sync and clinical timestamps are time-sensitive (the sensitivity behind bug 1), and the client stamps the encounter time from the **tablet** clock, so both server and tablet clocks must stay correct without Internet NTP — what the original appliance's `setclock`/`ntpserver`/`pushclock` packages handled.
- **Server (time authority):** its hardware clock is set to UTC at staging and it runs a local NTP service (chrony) for the LAN. Offline it relies on its RTC. The server, not the router, is the authority — travel routers usually have no RTC and lose time when powered off.
- **Tablets — disciplined to the local server via DNS interception.** Android ignores DHCP NTP (option 42), but with "automatic date & time" on it periodically makes an SNTP query to a hardcoded NTP hostname (`time.android.com` / `*.pool.ntp.org`). The router's DNS (dnsmasq) maps those hostnames to the server's static IP, so the tablet's "phone-home" SNTP lands on the local server and syncs — no root, no per-device NTP setting, no Internet. (SNTP is plain UDP, so unlike intercepting an HTTPS host there is no certificate problem.) Requirements:
  - The router must support custom local DNS overrides (OpenWrt/GL.iNet-class `dnsmasq address=/…/192.168.8.10`) and be the tablets' DNS resolver (DHCP option 6) — a router requirement (§3.3/§8).
  - Confirm the device's actual NTP hostname at staging (`adb shell settings get global ntp_server`) and map that name plus the common ones (a `pool.ntp.org` wildcard covers most).
  - Set each tablet's **Private DNS to Off** at staging, so the router resolver is actually used.
  - Android polls periodically, not instantly, so **still set each tablet's clock at staging** as the baseline; the intercept then keeps it from drifting. Verify at staging that a deliberately-wrong tablet clock corrects to server time.
- Fallback if a given router/ROM combination doesn't cooperate: manual set at staging + verify at power-on (runbook step); slow RTC drift between visits is then the only exposure.
- Failure mode to document: if an RTC battery dies or a device fully drains, its clock can reset (e.g. to 1970). A wrong **server** clock disrupts sync; a wrong **tablet** clock mis-stamps clinical times. Recovery is to reset the clock (the intercept then re-disciplines tablets). New hardware has a healthy RTC battery, so this is a months-scale risk, not a day-one one.

**Diagnostic dump.** A `buendia-diagnostics` script in the bundle collects logs (Docker, MySQL error log, OpenMRS, system journal), `docker compose ps`, and disk/version/config info into a single timestamped archive on a USB stick, for delivery to SolDevelo when an issue cannot be resolved on-site — the only debugging channel for an offline site. Because clinical-system logs may contain patient data, the archive is encrypted and handled per MSF's data-protection rules.

**Router configuration.** The router ships with its config pre-set and exported to a backup file in the bundle; the reset button is physically covered and labelled "do not reset." If the router is reset or replaced, the staging guide / runbook restores the saved config via the router's web UI — no re-engineering needed.

**In-zone (Red Zone) tablet re-provisioning.** Because install is QR-over-Wi-Fi with no cable, a reset or replacement tablet is re-provisioned in place without crossing a contamination boundary. A laminated card carrying the Wi-Fi SSID/password and the install QR is posted in each zone, including the Red Zone: rejoin Wi-Fi → scan QR → install → log in; the tablet then re-syncs from the server (the local DB is a cache, so no data is lost). The detailed clinical/IPC rule book is MSF's and comes later; the plan ensures the in-zone card and the no-cable install path exist.

---

## 4. Development workstreams

Six streams. WS-1 and WS-3 are the critical path; WS-4 runs in parallel once WS-3 produces a build environment.

### WS-1 — Deployable server container stack  *(core; ~2–3 days)*
A new `docker-compose.yml` (none exists in the repo) with two services:

- **`db`**: stock `mysql:5.6`, `TZ=UTC`, `default-time-zone=+00:00`, init SQL mounted into `/docker-entrypoint-initdb.d/` (WS-2), named volume for persistence.
- **`openmrs`**: Tomcat 7 + JRE 7 + OpenMRS Platform 1.10.6 `.war` + three modules in the modules dir: the Buendia `.omod` (WS-3), `xforms 4.3.5`, `webservices.rest 2.6`. Runtime properties point at `db`. `JAVA_OPTS=-Duser.timezone=UTC` (fixes bug 1; both containers must share UTC). Python 2 + pymysql baked in so the shelled-out `buendia-profile-apply` runs without a Python 3 port (handles bug 4; the port is deferred to production scope).

Containers, not the dev SDK runner: `tools/openmrs_run` launches via the Maven SDK (embedded Jetty), which suits development but not an unattended box. The container runs Tomcat directly with no Maven at runtime.

**Offline operation.** Docker is not part of a stock Ubuntu install, and the Site Area has no Internet. The stack is therefore fully self-contained:
- Docker + Compose are installed at the Staging Area (where apt access exists). For the from-USB fallback, the bundle carries the Docker + Compose `.deb` files and dependencies for offline `apt install`.
- Container images are never pulled from a registry on-site: every image (`mysql:5.6`, the prebuilt `openmrs`, the optional `pkgserver`) ships as a `docker save` tarball and is loaded with `docker load`.
- `docker compose up` requires no Internet once images are loaded.

**Unattended boot** (with §3.1): every service uses `restart: unless-stopped`, Docker is `systemctl enable`d, and the static IP is set via a netplan file applied by the setup script, so a cold power-on brings up the network and stack unattended.

**Acceptance:** on a clean Ubuntu box with networking disabled, `docker load` + `docker compose up -d` brings the REST API up on `:9000`; `curl` to `/openmrs/ws/rest/buendia/patients` returns; saving an observation via REST and re-reading it succeeds (timezone fix); a reboot restores everything automatically.

### WS-2 — Seed data & site/profile configuration  *(~1–1.5 days)*
- Load the canonical schema snapshot (`db-snapshot/` submodule) as the base init SQL.
- Fix bug 12: the concept-dictionary SQL references `creator=4`, a user absent from the snapshot → FK failure. Stub-insert that user or rewrite the creator id.
- Site SQL (bug 11): only `site-demo.sql` exists. Author `site-<pilot>.sql` (bed/zone location tree, clinician accounts, facility name) from the `site-demo.sql` template. Ward/bed structure is an open input (§8).
- Clinical profile: start from the upstream Ebola profile [`projectbuendia/profiles/ebola/bunia.csv`](https://github.com/projectbuendia/profiles/blob/master/ebola/bunia.csv) — 8 forms (Admission → Discharge), ~85 concepts, chart sections for Vitals / Symptoms / Bleeding / Coloration / Neuro / Respiratory / Circulation. Deploy as baseline; adapt with the clinical owner. The profile uses `#'%'` (a quoted literal percent), not the bugged `#%`, so it does not trip bug 10; new fields added during adaptation must likewise avoid bare `#%`.
- Bake the profile and the `projectbuendia.currentProfile` / `projectbuendia.chartUuids` global properties into the seed.

**Acceptance:** a fresh `docker compose up` yields a server with the location tree, clinician logins, and an active chart/form, with no manual admin steps.

### WS-3 — Reproducible build toolchain  *(~1–2 days; bug 3)*
The from-scratch build is broken by dead artifact hosts (Bintray/JCenter) and Java-8-only plugin versions.
- Server: use the existing `tools/docker/Dockerfile` (Debian Stretch + OpenJDK 7 + Maven) as the pinned build image. Pre-stage the OpenMRS SDK plugin (3.13.9) and `xforms`/`webservices.rest` artifacts (SourceForge hosting is flaky). Produce the Buendia `.omod`.
- Android: add mirror repositories to the Gradle config to replace JCenter/Bintray; confirm `./gradlew :app:assembleRelease` completes after a warm cache.
- Capture both in a single documented build script that produces the whole bundle.

**Acceptance:** on a clean checkout, one documented command produces the `.omod` and a release `.apk` without hand-editing.

### WS-4 — Android client release build + real-tablet validation  *(~1–1.5 days; patches already committed)*
The demo patches are already in the `v1.0` client submodule (`targetSdkVersion 24`, multidex on, SQLCipher `.so` removed, telephony try/catch in `third_party/odkcollect/.../PropertyManager.java`). This is the frozen baseline (§3.2). Remaining work:
- Build a signed release APK with pilot config: `-Pserver=<static-IP>`, `-PrequireWifi=true`. Set `versionNumber`. (No `-PencryptionPassword`: the flag is inert in v1.0 — data-at-rest is device-level per §3.2/§8.)
- Signing: sideloaded APKs need only a self-generated keystore (`keytool` → `.jks`/`.keystore`) wired into Gradle `signingConfigs`; no Google Play Developer account is required. Reuse the keystore the repo expects under `../../release/`, or generate one. The same key must sign every build for the life of the pilot — Android installs an OTA update only over an app signed with the identical key; a lost keystore forces uninstall + reinstall. SolDevelo retains and backs up the keystore + passwords (§7).
- Functional validation (SolDevelo): run the full §1 workflow on an emulator **and** a representative arm64 Android 9–12 device. The bug-9 fix is a defensive try/catch, and the review already confirmed the app launches on an emulator post-fix, so SolDevelo does **not** need the actual CrossCall units to validate functionality.
- Confirm multi-tablet operation: with two devices on the network, data entered on one appears on the other after sync.
- OEM-specific + physical confirmation on the real T4/T5: telephony behavior under CrossCall's ROM, glove-touch, screen legibility, and the "install unknown apps" flow. **MSF performs this as part of the Staging Area quick test** (it has the tablets there); SolDevelo supports remotely, optionally via a brief remote session or one sample unit shipped early. This de-risks; it is not a hard gate on the build.

**Acceptance:** the full clinical round-trip passes on SolDevelo's emulator + representative device, and on the real T4/T5 at the Staging Area quick test (MSF, with SolDevelo support).

### WS-5 — APK delivery: first install + OTA updates  *(~0.5–1 day; OTA mechanism already implemented)*
First install is manual and one-time; subsequent updates are OTA.

**First install — over the LAN, no USB.** A tablet on the Wi-Fi installs the APK by visiting a URL on the server. The server hosts a small landing page (nginx on the static IP) offering the APK; the runbook and the page carry a QR code of that URL:
1. Join the tablet to the SSID.
2. Scan the QR → browser opens `http://192.168.8.10/app` → downloads `buendia.apk`.
3. Install (Android prompts once to allow "install unknown apps" for the browser — documented with screenshots).

`adb`/USB sideload remains a documented fallback for devices where browser install is blocked by policy.

**Updates — OTA.** The mechanism exists (client `UpdateManager`/`PackageServer` polls `:9001/buendia-client.json`; server-side `buendia-pkgserver-import` ingests `projectbuendia-*.zip` bundles). The server serves `/usr/share/buendia/packages` on `:9001` with a `buendia-client.json` index. To push an update: drop a new (same-keystore-signed) `.apk` and bump the index; tablets poll, download, and install over local Wi-Fi. New APK versions arrive at the site by USB, never from the Internet.

**Acceptance:** (a) a factory tablet on the SSID installs the app via QR/URL with no cable; (b) bumping the APK version on the server triggers installed tablets to update.

### WS-6 — Runbooks & clinical quick-start  *(~2–3 days)*
Three documents, authored in Markdown and delivered as PDF (§5).

**(a) Staging Area setup guide** (MSF's technical person). The end-to-end staging procedure:
1. Install Ubuntu Server LTS on the procured PC.
2. Run the bundle's setup script (static-IP netplan, unattended-operation hardening, clean shutdown, log caps, host clock → UTC — §3.1, §3.4).
3. `docker load` the image tarballs; `docker compose up -d`; confirm the stack is healthy (status page, REST round-trip).
4. Pre-configure the router (SSID, password, subnet, and the dnsmasq NTP-hostname → server mapping per §3.4); pair it with the server; verify reachability at the static IP; **export the router config to the bundle's backup file**.
5. Install the signed APK on every tablet via QR/URL (WS-5); join each to the SSID; set Private DNS Off, set the clock, and confirm it auto-syncs from the server (§3.4); set a screen-lock PIN (activates device encryption — §8).
6. Run the quick test (the §1 round-trip) on a T4 and a T5; confirm cross-tablet visibility and correct date/time.
7. Power off; pair, label, and pack the kit (server + tablets + router + cables + UPS/power banks); include the laminated in-zone Wi-Fi+QR cards (§3.4) and the diagnostic-dump instructions.
This guide is also the basis for the from-USB rebuild referenced in the Site Area runbook appendix.

**(b) Site Area runbook** (non-technical staff) — power-on + verify + recover, with a separated from-USB re-install appendix.

*Main path (kit staged and tested at a Staging Area):*
1. Hardware checklist + power chain (server, router, UPS, power banks, cables) — §7.
2. Power on the router, then the server. Wait N minutes.
3. Verify "green": open the status page / OpenMRS login (server screen or a tablet). Single go/no-go check.
4. Power on a tablet (already on the SSID and pointed at the server) → log in → run the §1 round-trip once.
5. Add or replace a tablet: join SSID, scan the QR to install the APK (WS-5), log in.
6. Hand off to clinicians (clinical quick-start).

*Recover / troubleshoot:*
7. Timezone (bug 1) — symptom "saved vitals vanish after a second," cause "containers not both in UTC," fix. (Should not occur if staged correctly.)
8. "Can't reach server" → router powered, tablet on correct SSID, server status page.
9. "App crashes on launch" → wrong/old APK; reinstall via the in-zone QR (§3.4).
10. "Screen is dark / lid was closed" → the server is still running; press a key to wake the screen. A dark screen is not a dead server.
11. "Wrong date/time" → reset the device clock (§3.4); confirm the server's date first, as it is the time source.
12. "Wi-Fi gone / router was reset" → restore the saved router config (§3.4).
13. Backup: snapshot the MySQL volume to USB; restore.
14. Apply an APK update (WS-5 OTA).
15. **Collect diagnostics for SolDevelo:** run the `buendia-diagnostics` script, copy the archive to USB, deliver it to SolDevelo (§3.4).

*Fallback appendix — full re-install from USB (only if the kit must be rebuilt):* offline Docker install, `docker load` images, set static IP, `docker compose up -d`, then continue from step 3.

**(c) Clinical-admin quick-start** — provisioning users, uploading/applying a profile via the Profile Manager admin page, adding the location/bed tree.

**Acceptance:** a technical reviewer can take a procured PC from bare Ubuntu to a packed, tested kit using guide (a); a reviewer new to Buendia can take that kit from powered-off to a working tablet using runbook (b).

---

## 5. Deliverables (SolDevelo → MSF)

A single USB bundle:
1. `docker-compose.yml` + container images as tarballs (no registry/Internet needed on-site): `mysql:5.6`, the prebuilt `openmrs` image (war + 3 omods + python2), and the optional `pkgserver` image.
2. **Server host-configuration** — a setup script plus config files (static-IP netplan, lid/suspend/restart hardening per §3.1) that the Staging Area applies to the procured PC's fresh Ubuntu install. SolDevelo ships configuration + a script, **not a full OS image**, because the server hardware is not fixed. (If MSF later fixes the hardware model, this item can be replaced by a full pre-built disk image to flash — §2.1.)
3. Seed SQL (snapshot + concept fix + `site-<pilot>.sql`) and the profile CSV.
4. The signed, pilot-configured release APK.
5. **Documentation as PDF** (authored and maintained in Markdown, exported to PDF for delivery): `STAGING-SETUP-GUIDE.pdf` (MSF technical staff), `SITE-RUNBOOK.pdf` (non-technical site staff), `CLINICAL-QUICKSTART.pdf` (clinical admin).
6. **Operations tools** — the `buendia-diagnostics` dump script, the router configuration backup file, and the printable in-zone Wi-Fi+QR cards (§3.4).
7. The one-command build script + notes (WS-3) for rebuilding/patching the bundle.

---

## 6. Indicative timeline (one engineer, ~8–10 working days)

| Day | Work |
|---|---|
| 1 | WS-3 server build env; `.omod` builds reproducibly. WS-1 compose skeleton (db + openmrs) up locally. |
| 2 | WS-1 complete: UTC alignment, profile-apply (python2) in image, REST round-trip green. |
| 3 | WS-2: snapshot load + bug-12 fix + `site-<pilot>.sql` + profile baked; clean boot ready-to-use. |
| 4 | WS-3 Android: Gradle mirrors, reproducible release build. WS-4 signed APK produced. |
| 5 | WS-4: validation on emulator + a representative device (full clinical round-trip). Real-T4/T5 confirmation happens later at MSF staging. |
| 6 | WS-5 OTA channel; image tarball export; bundle assembly. |
| 7–8 | WS-6 staging guide + site runbook + quick-start (Markdown → PDF); end-to-end dry-run from bare Ubuntu to a working tablet on a clean PC. |
| 9–10 | Buffer: real-hardware surprises, profile iteration with the clinical owner, bundle polish. |

A second engineer can take WS-4/WS-6 in parallel with WS-1/WS-2. **Two-person team:** dependencies (WS-1→WS-2, WS-3→WS-4) cap the speed-up, so figure ~6–8 working days of effort — about **1.5 calendar weeks (~8–11 calendar days)** — once started and given the **site specifics** (for WS-2). SolDevelo validates on an emulator + a representative device, so the build does not wait on the actual CrossCall units; the real-T4/T5 confirmation rides on MSF's Staging Area quick test (WS-4). These are effort estimates, not a commitment to a start date.

The §3.4 offline-resilience items (server NTP + DNS-intercept time sync, graceful shutdown, log caps, the `buendia-diagnostics` script, router-config export, in-zone QR cards) are part of WS-1 (server/setup script) and WS-6 (tools/docs) — roughly +0.5–1 day, absorbed by the buffer.

---

## 7. Risks & deferred items

- **Wi-Fi coverage below ward needs** (most likely field issue). A single small router may not reach the farthest/most-walled beds (§3.3). Mitigations: prefer 2.4 GHz; add a mesh node or AP on the same SSID. Within an open ward, a cabled AP is fine; **across a Green/Red zone boundary, use wireless backhaul, not a cable** (§3.3 zone-boundary note). The bundle ships at least one extra AP/mesh node (and an Ethernet cable for the open-ward case). No Buendia config change is needed. The runbook includes a coverage walk-through.
- **Environment: DRC field hospital, active Ebola outbreak.**
  - Dust & dirt: the server PC and router are not rugged. Keep them in a sealed, ventilated enclosure in a clean zone, away from the contaminated area. (The tablets are IP68 and can be cleaned/disinfected; the disinfection procedure itself is MSF's IPC domain, not part of this plan.)
  - Heat: ensure airflow around the server enclosure to avoid thermal throttling/shutdown. A laptop server should run **lid-open** (a closed lid traps heat through the keyboard deck); the lid-ignore setting (§3.1) prevents suspend, it does not endorse running closed.
- **Unreliable power.** Power chain: mains/generator → UPS → server (battery + UPS ride through blips and allow clean shutdown); router → power bank (Wi-Fi survives a server/UPS event and the router can be repositioned for coverage); rotate spare charged power banks. A clean-shutdown-on-low-battery hook protects MySQL. The bundle ships a spare router and spare power banks/cables.
- **The Wi-Fi router is a single point of failure** — the pilot uses a standalone router rather than an appliance-hosted AP. Mitigation: spare router in the bundle.
- **Multi-tablet operation is the normal designed mode, not a risk.** Buendia is a multi-tablet field system (the review targets 5–15 tablets per site); the demo confirmed two devices syncing bidirectionally. The only unverified item is the narrow case of two clinicians writing the same patient record at the same instant — conflict semantics (last-write-wins vs. merge) were not stress-tested. In practice a patient is handled by one clinician at a time, and sequential edits from different tablets sync normally. Pilot stance: multi-tablet use is expected and supported; avoid simultaneous edits to the same patient and capture any anomaly as field feedback. Conflict hardening, if ever needed, is production scope.
- **Device clock reset / drift** (RTC battery dead or full drain → e.g. 1970). A wrong server clock disrupts sync; a wrong tablet clock mis-stamps clinical times. Mitigation: server runs local NTP and tablets are disciplined to it via DNS interception of the NTP hostname (§3.4); clocks are also set at staging as the baseline, with a manual check at power-on as the fallback. Server clock is the sync reference.
- **On-site router factory-reset** wipes the pre-set Wi-Fi config and strands the tablets. Mitigation: reset button covered + labelled, and the router config backup in the bundle restores it (§3.4).
- **Disk fill from logs** over a long unattended deployment. Mitigation: log rotation + disk caps set by the setup script (§3.1).
- **No remote access for debugging** an offline site. Mitigation: the offline `buendia-diagnostics` dump delivered by USB (§3.4).
- **Old, unsupported stack** (OpenMRS 1.10.x / Java 7 / MySQL 5.6, all EOL). Acceptable for a controlled pilot; the reason production scope eventually rebuilds the appliance.
- **Profile-apply stays Python 2** inside the container. Works because the image is controlled; not a long-term answer (Python 3 port deferred).
- **Real-hardware unknowns on T4/T5** (glove calibration, telephony fix under each OEM Android build, screen density). Surfaced at the Staging Area quick test (MSF has the tablets), with SolDevelo on standby to patch; shrinkable to near-zero if MSF ships one sample T4/T5 early.
- **Single point of failure**: one server, one DB. Mitigation: documented USB backup/restore; optionally a cloned spare SSD in the kit.
- **Patient data at rest on tablets** relies on Android device encryption + a screen lock (v1.0 has no app-level DB encryption — §3.2/§8). Residual risk: an unlocked or stolen tablet, or one with no lock set. Mitigations: set a PIN/screen lock on every tablet at staging (this activates device encryption), physical custody, and the local DB being only a cache. App-level encryption (SQLCipher) is available later if MSF's data-protection policy requires it.
- **Signing-key loss** permanently breaks in-place OTA updates (WS-4): Android updates only over an app signed with the same key. SolDevelo retains the keystore + passwords for the life of the pilot, backed up in ≥2 access-controlled locations (mechanism per SolDevelo's secrets practice; if stored in a repo, the key material is encrypted at rest, not committed in plaintext).

---

## 8. Decisions

### Decided
- **Tablet data-at-rest: device-level encryption + a mandatory screen lock**, not app-level. v1.0 has no working app-level DB encryption (the code uses plain Android SQLite, not SQLCipher; the `ENCRYPTION_PASSWORD` flag is inert), and the pilot does not re-introduce SQLCipher — doing so would reverse the bug-8 cleanup and break the v1.0 freeze. Protection = Android's built-in FBE/FDE (active once a screen lock is set on T4/T5) + a mandatory PIN/lock + physical custody; the local DB is only a cache (§3.2, §7). App-level encryption (SQLCipher) is available later if MSF's data-protection policy requires it.
- **Signing keystore custody:** the APK signing keystore + passwords are **SolDevelo's to retain and back up** (§7) — redundant, access-controlled, for the life of the pilot; mechanism is SolDevelo's secrets practice. (Separate from data-at-rest; required for OTA updates.)
- **Clinical profile baseline:** upstream Ebola profile [`ebola/bunia.csv`](https://github.com/projectbuendia/profiles/blob/master/ebola/bunia.csv); deploy then adapt. (Verified free of the `#%` bug.)
- **Server OS/stack:** Ubuntu 22.04 LTS + Docker Engine + Compose; unattended hardening per §3.1.
- **Router approach:** a low-power mini/travel router (dual-band, AP/mesh-capable) per §3.3, plus a spare and one extra AP/mesh node for coverage fallback. Specific model is an open procurement item (below).

### Open — MSF inputs (execution + domain knowledge); SolDevelo advises
1. **Server hardware** — buy a mini-PC vs. repurpose an on-hand laptop (within §3.1 specs).
2. **Staging Area** — the plan requires a Staging Area (Internet + technical person + space). Where it sits and who staffs it is operational; MSF may already operate one.
3. **Pilot site specifics** for `site-<pilot>.sql`: facility name, ward/room/bed/zone structure, clinician user accounts.
4. **Tablet count** (drives install runbook + spare-device planning).
5. **Ward layout & construction** (drives §3.3 Wi-Fi + §7 environment): open bay vs. walled rooms, wall material, longest router-to-farthest-bed distance.
6. **Router model** — specific unit meeting the §3.3 specification (including custom local DNS support, per §3.4).
7. **Clinical owner** — adapts `bunia.csv` (final form & chart content).
