# Project Buendia — Minimum Field-Pilot Deployment Plan

**Scope shape:** "Minimum field-pilot (1–2 weeks)" from `docs/TECHNICAL-REVIEW.md` §3.
**Goal:** the leanest path to a *working* Buendia system on-site — on the users' tablets, against an on-site server.
**Companion document:** `docs/TECHNICAL-REVIEW.md` (bug numbers below, e.g. "bug 9", refer to its bug list).

SolDevelo's scope: **build the software, specify the hardware, and produce a kit that MSF stages and tests in Switzerland**, plus the runbooks and a secure remote-support channel. **MSF supplies the tablets, stages the kit in Switzerland, and deploys it on-site**; SolDevelo does not travel to site (see Parties). The system is an **autonomous kit** — independent of MSF's existing LIME EMR / OpenMRS 3 infrastructure and field-IT teams (the agreed approach; a LIME-compatible app is the deferred long-term alternative).

**End goal (stated 2026-07-30):** a Buendia system deployed at **one** DRC site; a **no-maintenance** package; **pilot-like, not perfect**; **initial setup and tests at MSF Switzerland** (with parts done at SolDevelo first); then shipped to the site **"ready to go"**. Two consequences run through everything below:

1. **No engineer is ever on site.** Anything that can only be diagnosed or fixed in person is a design defect, not a support matter.
2. **Anything that cannot be tested at MSF Switzerland ships unvalidated.** This is the sharpest design filter in this plan — it is what decides the network topology in §3.3.

---

## Parties & responsibilities

⚠️ **Revised 2026-07-30.** This table previously had SolDevelo procuring the tablets and staging the kit on its own premises. Both changed: **MSF supplies the tablets** with their own system image (decided 2026-07-29), and **staging/testing happens at MSF Switzerland**.

| Party | Role | Responsibilities |
|---|---|---|
| **SolDevelo** | Build + specify + prove + support | Builds the **deployment bundle** (server container stack, seed data/config, signed APK, install USB) and the reproducible build. **Specifies** the hardware (`FIELD-PILOT-SERVER-SPEC.md`) and the network kit, and suggests models. **Tests the package to destruction on its own hardware** — this is the technical test, and it is what has been done twice. Writes the **runbooks**. Provides the **secure remote-support channel** and a **hypercare** window (scope TBD, §8). Supports the MSF-CH session remotely or in person. Does not travel to site. |
| **MSF Switzerland** | Procurement + install + user test | **Supplies the tablets** (their own system image — see B5 in `FIELD-PILOT-MSF-CONFIG-REQUESTS.md`) and sources the server (may repurpose an existing laptop — §3.1). **Installs the actual shipping server themselves**, from our deployment package (decided — see below). **Runs the user test / UAT**, adjusts the configuration in the process, then labels, packs and ships to the site. Provides the **site specifics**, the **clinical content**, and **data-protection sign-off**. |
| **MSF at site** | Deployment + operation | Unpack, connect power, power on, verify "green", use. Owns the field environment and IPC. Nothing is built or configured here. |
| **Users** | Operation | Clinicians and staff at the site. The on-site experience (power-on, login, data entry) is designed around them. |

Consequences for this plan:
- **MSF Switzerland installs the actual shipping server, not us** (decided; MSF's reasoning: they must have a running system in order to adjust the configuration and to run their own UAT, so it is convenient for them to prepare the real box too). **This is open to change if we give a compelling reason** — but on balance it is a *good* arrangement and we should keep it: it is the only way the install path gets proven in someone else's hands, which is exactly the property the deliverable needs. What it demands of us is that `bootstrap.sh` / `setup.sh` be **customer-grade** — unambiguous prompts, failure messages a non-Buendia person can act on, and a pass/fail at every step (`buendia-verify.sh` provides it). Treat any confusing message found during the MSF session as a defect in our deliverable, not user error.
- **So SolDevelo's own install runs are a rehearsal of someone else's procedure**, which is a different standard from "it works on my machine". The two hardware installs already done are exactly this rehearsal; keep doing them after any change to the install path.
- **The staging guide (WS-6a) is a document someone else executes**, not an internal note. It must assume no Buendia knowledge.
- **The tablets never pass through SolDevelo.** So `adb install` at staging is not our step, real-tablet validation of the *shipping* build happens at MSF CH, and the T4/T5 unknowns in §7 are retired only at that session. This is why **B5** (what their image permits) is the highest-priority open question.
- **The site's own network cannot be tested in Switzerland.** See §3.3 — this is the decisive argument for shipping our own network rather than reusing the site's Wi-Fi.
- SolDevelo specifies hardware (§3.1/§3.3); the bundle and runbooks stay model-agnostic within the §3 specs so a model can be substituted without rework.
- **A joint staging session** (SolDevelo present, remote or in person) is the single highest-value event in the schedule: it is the only point where our software, MSF's tablets and the real network kit are in one room. Treat it as a scheduled milestone, not an afterthought.

---

## 1. Definition of done

**Confirmed before ship (SolDevelo staging) and again at site go-live (MSF), all with no Internet:**

1. The server boots, brings up MySQL + OpenMRS, and serves the Buendia REST API on the local network.
2. A clinician on a **CrossCall Core-T5** and on a **CrossCall Core-T4** can: log in → browse the location tree → add a patient → assign a bed → open the chart → open a form → enter vitals → save → **see the saved values persist** (the round-trip that the timezone bug breaks — bug 1).
3. Both tablets see each other's data: data entered on the T4 appears on the T5 after sync, and vice-versa (normal multi-tablet operation).
4. The workflow survives a server power-cycle (data is on the server).
5. Tablets receive their **first APK install** over the local Wi-Fi via QR/URL (WS-5).

**Not available — see WS-5 (revised 2026-07-29):** an **in-app OTA update channel**. The v1.0 client cannot download and install an update itself, so app updates are a **manual re-install** (re-scan the in-zone install QR, or `adb install -r` over USB); local data survives because the app id and signing key are unchanged. First install at the site is the QR/URL step in item 5 — that path *is* verified.

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

### 2.1 Installation model — three phases, and two levels of test

⚠️ **Revised 2026-07-30.** Previously two environments (SolDevelo staging → site). There are now **three phases**, and critically **two distinct levels of test** with different purposes and different audiences.

| Phase | Where | Test level | Purpose |
|---|---|---|---|
| **1. Build & technical test** | SolDevelo | **Technical** | Does it work at all? Build the images, seed, APK and install USB; install onto **our own test hardware**; prove the stack is *usable*, not merely up (`buendia-verify.sh`). ✅ **Executed twice on real hardware (2026-07-29/30).** |
| **2. Install + user test** | **MSF Switzerland** | **User / acceptance** | **MSF installs the actual shipping server** from our package, then: do clinicians accept it? MSF's own tablets, MSF's people, the real clinical workflow. **This phase is expected to generate change requests** — see below. Ends with the kit labelled, packed and shipped. |
| **3. Site deployment** | DRC site | none | Unpack, power on, verify "green", use. **Nothing is built or configured here.** |

Phase 1 proves the engineering; phase 2 proves the product. They fail in different ways and must not be conflated: a kit that passes phase 1 can still be rejected in phase 2 because a form asks the wrong question.

#### The user test will change the seed — and that is the point

**Expect requests to change the forms and the location tree during the MSF user test.** That is the intended output of putting clinicians in front of it, not a sign something went wrong. The plan must therefore make that loop *cheap*, because it will run several times in a session.

**What is cheap to change, and what is not** — this hierarchy decides what must be settled *before* phase 2 versus what phase 2 is *for*:

| Change | Cost | Mechanism |
|---|---|---|
| **Forms, questions, chart layout** (profile) | **Live, no rebuild, no tablet action** | Upload + activate via the Profile Manager admin page. Tablets pick it up on sync. |
| **Location tree** — zone names, order, structure, default zone | **Live, no rebuild, no tablet action** | Re-apply `20-buendia-site.sql` (idempotent, keyed on uuid) then any endpoint with `?clear-cache`. Renames are safe on a running server. |
| **Facility name, provider/clinician accounts** | **Live, no rebuild, no tablet action** | Same SQL path. |
| **Server password** | Server-side live, **but a guided Settings step on every tablet** | `create-openmrs-user.sh`; each tablet then needs its stored password updated. |
| **Server address, baked login defaults, idle timeouts, `requireWifi`** | ⚠️ **APK rebuild + reinstall on every tablet** | Baked at build time by `build-apk.sh`. The Android toolchain is not at MSF CH. |

**The scheduling consequence, and it is the useful one:** the APK-affecting decisions (**B1** address, **A5** password, **A10** timeouts) must be settled **before** the shipping APK is built for phase 2 — whereas the clinical items (**A1** facility name, **A2/A3** zones, **A4** accounts, **A7** forms) are exactly what phase 2 exists to settle, and cost nothing to change there. Split the config-request list along that line when chasing answers.

**Two rules for phase 2, both easy to get wrong:**
1. **Every accepted change must be folded back into the seed before shipping**, not left applied only to the running server — otherwise a reinstall at the site silently reverts it, and the fix exists nowhere but one disk. This is working guideline #9 ("no manual setup steps in the package"). The `pilot-site-config` skill is the apply path; `build-seed.sh` / the DB image rebuild persists a profile change.
2. **Wipe the user-test data before the kit ships.** A user test creates junk patients, encounters and orders; the site must start from an empty record, and test patients in a live clinical system are a genuine hazard. Re-verify after wiping (`buendia-verify.sh --write` proves admission still works on the clean DB).

**Freeze the UUIDs, not the names.** Restructuring the location tree after tablets have synced orphans already-admitted patients, so phase 2 is the last safe moment to change the tree's *shape*. Renaming stays safe indefinitely.

The reproducible build (WS-3) solves the broken-toolchain problems (dead Bintray/JCenter mirrors, Java-7 pinning) once, so a change accepted in phase 2 can be rebuilt and re-verified the same day.

---

## 3. Target environment

### 3.1 On-site server

The pilot runs the server on a generic machine via Docker Compose, skipping the custom SBC appliance. **SolDevelo selects and procures a specific unit meeting the spec below** (alternative: MSF supplies reset standard laptops as the base — §8). Requirements follow from the stack: MySQL 5.6 + OpenMRS 1.10.6 (Tomcat 7 / Java 7) in containers, x86-64.

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
- Real-device behavior is confirmed on the actual T4/T5 that SolDevelo procures and stages; the emulator is for early iteration only (see WS-4).

### 3.3 Network & power

The pilot does not run the server as a Wi-Fi access point.

⚠️ **Direction changed 2026-07-30. The default is now to REUSE the site's existing Wi-Fi**, with our own access point kept in the kit as the fallback. Previously the shipped autonomous router was the default. **MSF is being asked to choose between the two** (see B2/B6 in `FIELD-PILOT-MSF-CONFIG-REQUESTS.md`), because the deciding facts are theirs, not ours.

#### The two options, honestly stated

Each carries one major issue, and they are different *kinds* of risk.

| | **A. Reuse the site's Wi-Fi** ← current default | **B. Ship our own AP** |
|---|---|---|
| **Coverage** | ✅ Presumed solved — their network was designed to cover the site | ⚠️ **The main worry.** One AP may not reach across zones; needs a coverage walk and possibly extra nodes |
| **Addressing** | ⚠️ **The main worry.** Needs a fixed, reachable address in *their* subnet, agreed with whoever runs it | ✅ Ours by construction; the APK's baked address is right automatically |
| **Silent failure modes** | ⚠️ Client isolation, captive portal, APs on different subnets — fatal, invisible, and not fixable by us | ✅ None; we configure the AP |
| **Testable before shipping** | ⚠️ Not on the real network — only on a stand-in | ✅ The staging network *is* the production network |
| **Tablet clock discipline** | Depends on their Wi-Fi having internet (then Android's normal time sync just works) | Needs our DNS-intercept trick (§3.4) |
| **Remote support (§3.5)** | ✅ Works if their network has internet | ❌ Impossible on an isolated AP — no uplink, no tunnel |
| **Kit size / power** | ✅ Fewer devices to supply, power and keep spares of | One more box, one more power draw, one more failure point |

**Why A is the default despite being the less testable one:**

1. **Coverage is the risk we can neither measure nor fix from Switzerland.** If our single AP under-reaches a far tent, nobody on site can solve it and we cannot even find out until clinicians complain. Their network's coverage is at least *designed* for the site's geometry. This inverts the usual "prefer the testable option" rule, because the untestable-but-likely-fine risk (their addressing) has a *workaround on arrival*, while an AP that physically cannot reach a zone does not.
2. **The path is already proven, in exactly this shape.** The 2026-07-29/30 hardware validation *was* this configuration: a server placed on an existing, someone-else's-DHCP office network at a chosen static address (`192.168.0.250`), an APK built for that address, deployed — and the tablet just worked. So "put the server on a network we don't own, at an address we were given" is **not** a new or unvalidated arrangement; it is the one we have run twice.
3. **It reduces what we ship.** Fewer devices to supply, power, spare and document — which serves the no-maintenance goal.
4. **It is what makes remote support and tablet time-sync possible at all**, both of which need an internet path (§3.4, §3.5).

**What A actually requires — and it is organisational, not technical.** The whole risk reduces to *getting one correct address*. Someone who owns the site network must either reserve a static address for the server, or tell us the subnet and one address that is genuinely free (e.g. "we are `192.168.0.0/22`, take `192.168.0.255`"). The server's installer then asks for that address at setup time. That is a coordination task, not an engineering one — which is why B6 asks for it in precise terms rather than as "an IP".

**What must still be asked, because it is silent and fatal:** whether their network isolates clients from each other. On such a network tablets associate perfectly and cannot reach the server at all, with no visible cause and no fix available to us. Same for a captive portal, and for different APs putting clients on different subnets. **This cannot be assumed and cannot be discovered from Switzerland** — it must be asked, and ideally tested on their network before the kit ships.

**Keep the fallback in the kit regardless.** A small AP travels with the kit whatever MSF answers, because it is the only recovery if their network turns out to isolate clients, or if there is no site Wi-Fi after all (a real possibility — "the site has Wi-Fi" is currently our inference from a conversation, not a confirmed fact). It costs little and converts a pilot-ending failure into a documented fallback.

#### Sequencing trap: the address is baked into the APK, and UAT happens on a different network

The tablet APK bakes in the server's address (§3.3/WS-4), and the **user test happens at MSF Switzerland**, whose network is not the site's. So the tablets that pass UAT are pointed at an MSF-CH address, and at the site that address is wrong. Three ways out, in order of preference:

1. **Mimic the site subnet at MSF CH using the fallback AP** — configure it with the site's subnet and give the server the site's agreed address. UAT then runs against the *final* address, one APK works in both places, and nothing is reinstalled. This is the cleanest option and is a second reason to have the AP in the kit. **Requires the site address to be known before UAT.**
2. **Rebuild the APK after UAT** with the site address and re-install on every tablet by QR before packing. Cheap at MSF CH (a QR scan per tablet); requires the address before the kit ships.
3. **Accept a guided Settings change per tablet at the site** — the address is a runtime-editable preference, so this works, but it is N tablet-visits by non-technical staff, including any tablet inside a contamination zone, and each tablet cannot sync until it is done. **The fallback, not the plan.**

**Consequence for the schedule: B6 (their subnet + our address) gates the kit shipping, and ideally gates UAT.** It is the single most schedule-critical configuration answer.

- No Internet is required at the site for **clinical use** or first install. Internet, where their network provides it, is used only for the opt-in remote-support channel (§3.5) and to let tablets keep their clocks right (§3.4).
- UPS on the server; the fallback AP on a power bank if it is used (§7 power chain).

**Fallback AP specification** (was "Router specification" — the role changed with the 2026-07-30 direction change, the spec did not). A mini/travel router: low power (USB-powered, can run from a power bank); dual-band; able to operate as a plain access point and as a mesh node; and supporting **custom local DNS overrides** (OpenWrt/GL.iNet-class dnsmasq) so the §3.4 NTP interception is available if we do end up running our own network. SolDevelo selects and procures the specific model (§8). Wi-Fi throughput is never the bottleneck — clinical sync traffic is kilobytes of JSON every 10 s, easily handled for 5–10 tablets. **Coverage is the constraint.**

**This device earns its place three times over even if the site's Wi-Fi is used:** (a) it is the recovery path if their network isolates clients or turns out not to exist; (b) it is how MSF CH can **mimic the site's subnet during UAT** so one APK works in both places (§3.3 sequencing trap); and (c) it extends coverage into a zone their network misses. Buy it regardless of MSF's answer on B2/B6.

Coverage characteristics of a single small router — **relevant both to the fallback AP and to judging whether the site's own coverage is credible** (an office network covering an admin building is not evidence that it reaches a triage tent 80 m away; B6 asks for coverage over the actual zones for this reason):
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

The site is offline by default; the system must stay correct unattended and remain debuggable. (Occasional internet enables an opt-in remote-support channel — §3.5; the offline USB diagnostic dump below is the fallback when there is no connectivity.)

**Time / clock.** Buendia's sync and clinical timestamps are time-sensitive (the sensitivity behind bug 1), and the client stamps the encounter time from the **tablet** clock, so both server and tablet clocks must stay correct without Internet NTP — what the original appliance's `setclock`/`ntpserver`/`pushclock` packages handled.
- **Server (time authority):** its hardware clock is set to UTC at staging and it runs a local NTP service (chrony) for the LAN. Offline it relies on its RTC. The server, not the router, is the authority — travel routers usually have no RTC and lose time when powered off.
⚠️ **The tablet half of this design assumed we own the router — re-examine it against the 2026-07-30 network direction change (§3.3).** The DNS-interception trick below requires control of the DNS resolver the tablets use. **On the site's own Wi-Fi we do not have that**, so the mechanism is unavailable and tablet clocks need a different answer. Which answer depends on one fact we must ask for (**B6**): *does the site's Wi-Fi have internet?*

- **If their Wi-Fi has internet** — the problem disappears, and better than our workaround would have solved it: Android's normal automatic date & time works, tablets stay correct indefinitely with no trick at all. **This is a genuine advantage of reusing their network** and one of the reasons it is now the default.
- **If their Wi-Fi has no internet** — we have no way to discipline the tablets. Then: set every clock at staging as the baseline, accept slow RTC drift between visits, and add a clock check to the site runbook's power-on routine. Drift is a months-scale risk on healthy hardware, but it is unmitigated, and **the encounter timestamp comes from the tablet** (`JsonEncounter.time` is client-supplied), so drift becomes wrong clinical data. If this is the answer, reconsider running our own AP purely to regain the intercept — or ask whether MSF's tablet image has its own time source (**B5 q8**).
- **If we run our own AP** (fallback option B) — the intercept below applies as originally designed.

- **Tablets — disciplined to the local server via DNS interception** *(available only when we control the network — see above)*. Android ignores DHCP NTP (option 42), but with "automatic date & time" on it periodically makes an SNTP query to a hardcoded NTP hostname (`time.android.com` / `*.pool.ntp.org`). The router's DNS (dnsmasq) maps those hostnames to the server's static IP, so the tablet's "phone-home" SNTP lands on the local server and syncs — no root, no per-device NTP setting, no Internet. (SNTP is plain UDP, so unlike intercepting an HTTPS host there is no certificate problem.) Requirements:
  - The router must support custom local DNS overrides (OpenWrt/GL.iNet-class `dnsmasq address=/…/192.168.8.10`) and be the tablets' DNS resolver (DHCP option 6) — a router requirement (§3.3/§8).
  - Confirm the device's actual NTP hostname at staging (`adb shell settings get global ntp_server`) and map that name plus the common ones (a `pool.ntp.org` wildcard covers most).
  - Set each tablet's **Private DNS to Off** at staging, so the router resolver is actually used.
  - Android polls periodically, not instantly, so **still set each tablet's clock at staging** as the baseline; the intercept then keeps it from drifting. Verify at staging that a deliberately-wrong tablet clock corrects to server time.
- Fallback if a given router/ROM combination doesn't cooperate: manual set at staging + verify at power-on (runbook step); slow RTC drift between visits is then the only exposure.
- Failure mode to document: if an RTC battery dies or a device fully drains, its clock can reset (e.g. to 1970). A wrong **server** clock disrupts sync; a wrong **tablet** clock mis-stamps clinical times. Recovery is to reset the clock (the intercept then re-disciplines tablets). New hardware has a healthy RTC battery, so this is a months-scale risk, not a day-one one.

**Diagnostic dump.** A `buendia-diagnostics` script in the bundle collects logs (Docker, MySQL error log, OpenMRS, system journal), `docker compose ps`, and disk/version/config info into a single timestamped archive on a USB stick, for delivery to SolDevelo when an issue cannot be resolved on-site — the only debugging channel for an offline site. Because clinical-system logs may contain patient data, the archive is encrypted and handled per MSF's data-protection rules.

**Router configuration.** The router ships with its config pre-set and exported to a backup file in the bundle; the reset button is physically covered and labelled "do not reset." If the router is reset or replaced, the staging guide / runbook restores the saved config via the router's web UI — no re-engineering needed.

**In-zone (Red Zone) tablet re-provisioning.** Because install is QR-over-Wi-Fi with no cable, a reset or replacement tablet is re-provisioned in place without crossing a contamination boundary. A laminated card carrying the Wi-Fi SSID/password and the install QR is posted in each zone, including the Red Zone: rejoin Wi-Fi → scan QR → install → log in; the tablet then re-syncs from the server (the local DB is a cache, so no data is lost). The detailed clinical/IPC rule book is MSF's and comes later; the plan ensures the in-zone card and the no-cable install path exist.

### 3.5 Remote support & data extraction

The site is offline for clinical use, but internet is expected intermittently. Two capabilities ride on that occasional connectivity. **Both are patient-data-touching and require MSF data-protection sign-off (§8) before they are enabled.**

> ### ⚠️ Status 2026-07-30: NOT BUILT AND NOT TESTED
>
> **The remote connection has never been tested.** Nothing in the deployed stack has been proven to dial out or accept a remote session; `ENABLE_REMOTE_SUPPORT=false` and Tailscale is not authenticated. Treat every claim in this section as *design intent*, not delivered capability.
>
> **Two things this section previously left implicit:**
> 1. **It needs an internet path at the site, which the §3.3 decision controls.** On the site's Wi-Fi (the new default) there probably is one — this is an argument *for* reusing their network. On a fully isolated AP of our own there is none, and remote support is then **impossible**, not merely disabled. A pilot with no engineer on site and no remote access is diagnosable only by the offline USB dump (§3.4) and a phone call.
> 2. **Sign-off gates *enabling it at the site*, not *testing it*.** Building and proving the tunnel is not blocked on C1 — only pointing it at a box holding real patient data is. So it can and should be proven now.
>
> **How it gets tested (planned, PW):** locally, without waiting for MSF — put this workstation on a *different* internet connection (mobile hotspot) from the test notebook, so the two are genuinely on separate networks, and confirm the tunnel establishes and carries an SSH session. That is a faithful rehearsal of the site case at zero cost, and it retires the "untested" status before anything ships.

**Remote support channel (decided: Tailscale + SSH to start).** Skilled staff cannot be guaranteed on-site, so the kit includes an **opt-in secure tunnel**, **server-initiated** (dials out — no inbound ports, works behind the router's NAT with nothing configured at site), **dormant when offline**, connecting to a SolDevelo endpoint only when internet is present. Support is via **SSH** (terminal + a forwarded port to the OpenMRS web UI) — the server is headless, so **no remote *desktop* is needed**; "remote desktop, no VPN" is the mental model, SSH is the right tool. Transport starts with **Tailscale** (zero site-side config, NAT-traversing; it is technically a WireGuard mesh VPN, but nothing is configured at site — the honest framing to MSF is "the server dials out to us, no inbound access, no VPN client for you to manage"). Its coordination plane is a third-party service (cannot read the end-to-end-encrypted traffic, but in the path), so the **data-protection sign-off may push to self-hosted WireGuard/Headscale** — the plan is written around "server-initiated dial-out + SSH" so the transport can be swapped without rework. Properties: authenticated, encrypted, server-initiated, controllable, auditable, switch-off-able; **ships disabled until sign-off**. It is a **support side-channel only** — clinical operation never depends on it. When there is no connectivity, the offline `buendia-diagnostics` USB dump (§3.4) is the fallback.

**Data extraction.** So MSF medical teams are not "blind" to the data, the kit provides a basic export of the clinical data, leveraging the module's existing `DataExportServlet` (CSV). The export can be **pulled over the remote-support tunnel** when internet is available, or written to a **USB key at the server** as the offline fallback. As patient data leaving the kit, its format, destination, and access are governed by MSF's data-protection rules; a future option is to feed it into MSF's LIME EMR rather than flat files.

---

## 4. Development workstreams

Seven streams. WS-1 and WS-3 are the critical path; WS-4 runs in parallel once WS-3 produces a build environment; WS-7 (remote support + data export) is independent.

### WS-1 — Deployable server container stack + packaging  *(core; ~2–3 days)*

**Packaging (decided): a versioned `deploy/` tree whose entry point is one idempotent `setup.sh`** — the source of truth, run on a fresh Ubuntu install. `--online` (default, at SolDevelo staging with internet) pulls Docker + images; `--offline` rebuilds from bundled `.debs` + `docker save` tarballs with no internet. The `--offline` mode is important given **1 server, no spare** (§8): it lets a replacement be stood up on any laptop from the USB bundle without a full re-stage. A full disk image is an optional downstream *restore* artifact, not the foundation. Reproducibility comes from a pinned `.env` (Ubuntu point release, Docker version, **image digests** not tags) + the vendored Java-7/OpenMRS artifacts (WS-3). `setup.sh` phases: preflight → host config (netplan, logind lid-ignore, suspend masks, UTC, chrony, log caps, shutdown hook) → Docker install → image load → seed + `compose up` → Tailscale (§3.5) → health check.

The stack itself — a new `docker-compose.yml` (none exists in the repo) with two services:

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
- Signing: sideloaded APKs need only a self-generated keystore (`keytool` → `.jks`/`.keystore`) wired into Gradle `signingConfigs`; no Google Play Developer account is required. Reuse the keystore the repo expects under `../../release/`, or generate one. The same key must sign every build for the life of the pilot — Android installs an update only over an app signed with the identical key; a lost keystore forces uninstall + reinstall. The pilot key is created by `deploy/apk/build-apk.sh --make-keystore`. SolDevelo retains and backs up the keystore + passwords (§7).
- Early iteration (SolDevelo): run the full §1 workflow on an emulator while the procured hardware is on order. The bug-9 fix is a defensive try/catch, and the review already confirmed the app launches on an emulator post-fix.
- Real-hardware validation (SolDevelo, at staging): since SolDevelo procures and stages the tablets, it validates on the **actual T4 and T5 units before the kit ships** — telephony under CrossCall's ROM, glove-touch, screen legibility, the "install unknown apps" flow, and multi-tablet sync (data entered on one device appears on the other). This is done pre-ship, not deferred to the field.

**Acceptance:** the full clinical round-trip passes on the actual T4 and T5 units (staged by SolDevelo) before packing.

### WS-5 — APK delivery: first install + updates  *(~0.5–1 day)*  ✅ **DONE 2026-07-29**
First install is over-the-LAN by QR and is verified on a real tablet. Updates are a manual
re-install: the in-app OTA path is broken on this client (below), so it is out of scope.

**First install — over the LAN, no USB.** A tablet on the Wi-Fi installs the APK by visiting a URL on the server. The server hosts a small landing page (nginx on the static IP) offering the APK; the runbook and the page carry a QR code of that URL:
1. Join the tablet to the SSID.
2. Scan the QR → browser opens `http://192.168.8.10/app` → downloads `buendia.apk`.
3. Install (Android prompts once to allow "install unknown apps" for the browser — documented with screenshots).

`adb`/USB sideload remains a documented fallback for devices where browser install is blocked by policy.

**Updates — manual re-install. ⚠️ REVISED 2026-07-29: in-app OTA is NOT available on the v1.0 client.** This section previously assumed "the mechanism exists"; reading the code disproved it. The client polls `:9001/buendia-client.json` and compares versions correctly, but the *download and install* path is dead: `UpdateManager.java:150-158` short-circuits the download with `if (2 > 1)` and instead opens `http://<server>/client` in a browser (port **80**, which the stack does not serve), and `installUpdate()` hands Android a raw `file://` Uri, which throws `FileUriExposedException` at `targetSdkVersion 24`. There is no `FileProvider` and no `REQUEST_INSTALL_PACKAGES` permission. Making OTA work is a client code change (FileProvider + `content://` Uri + the permission + removing the short circuit) — **out of pilot scope**.

Consequence: **an update is a manual re-install** — re-scan the install QR on each tablet, or `adb install -r` over USB. Local data survives (same app id and signing key). The signing key must be the same or Android refuses the update. New APK versions still arrive at the site by USB, never from the Internet.

The server therefore serves `:9001` for **first install** and to satisfy the client's package-server health check (which probes `/dists/stable/Release` and otherwise shows a "check package server configuration" warning on the tablet). `publish.sh` advertises only the version it published, so tablets are never prompted for an update the client cannot perform.

**Acceptance:** (a) a factory tablet on the SSID installs the app via QR/URL with no cable — ✅ **met 2026-07-29** on a real tablet; (b) ~~bumping the APK version triggers installed tablets to update~~ — **withdrawn as unachievable** (see above); replaced by: a laminated in-zone card carries the Wi-Fi-join and install QRs so a tablet can be re-provisioned in place, and the documented manual re-install preserves local data — ✅ card generated by `deploy/pkgserver/make-install-card.sh`.

### WS-6 — Runbooks & clinical quick-start  *(~2–3 days)*
Three documents, authored in Markdown and delivered as PDF (§5).

**(a) Staging Area setup guide** (SolDevelo's staging procedure; delivered for MSF visibility and as the rebuild reference). The end-to-end staging procedure:
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
14. Apply an APK update: re-scan the in-zone install QR on each tablet (or `adb install -r`). There is no automatic OTA — see WS-5.
15. **Collect diagnostics for SolDevelo:** run the `buendia-diagnostics` script, copy the archive to USB, deliver it to SolDevelo (§3.4).

*Fallback appendix — full re-install from USB (only if the kit must be rebuilt):* offline Docker install, `docker load` images, set static IP, `docker compose up -d`, then continue from step 3.

**(c) Clinical-admin quick-start** — provisioning users, uploading/applying a profile via the Profile Manager admin page, adding the location/bed tree.

**Acceptance:** a technical reviewer can take a procured PC from bare Ubuntu to a packed, tested kit using guide (a); a reviewer new to Buendia can take that kit from powered-off to a working tablet using runbook (b).

### WS-7 — Remote support channel + data export  *(~1–2 days; §3.5; independent)*
- **Remote support tunnel:** a server-initiated secure tunnel (WireGuard/Tailscale-style), dormant offline, dialling a SolDevelo endpoint when internet is present; authenticated, encrypted, auditable, switch-off-able; no inbound ports exposed at the site.
- **Data export:** wire the existing `DataExportServlet` (CSV) into a one-command export that writes to a USB key and is reachable over the tunnel when online; document both paths.
- Gate: **enabled only after MSF data-protection sign-off** (§8); ships disabled-by-default if sign-off is pending.

**Acceptance:** with simulated intermittent connectivity, SolDevelo reaches the server over the tunnel and pulls a data export; offline, the same export writes to USB; with the tunnel down, clinical operation is unaffected.

---

## 5. Deliverables (SolDevelo → MSF)

**A staged, ready-to-run kit** — procured hardware with all software installed, configured, and tested, packed for shipment — plus the artefacts to operate, rebuild, and support it:
1. **The assembled kit:** server (Ubuntu + Docker + the Buendia stack, hardened per §3.1), configured tablets (APK + screen lock + clock), the pre-configured/paired router, UPS/power banks, cables, and the laminated in-zone Wi-Fi+QR cards (§3.4).
2. **The deployment bundle** (for rebuild/patch, on USB): `docker-compose.yml` + container image tarballs (`mysql:5.6`, prebuilt `openmrs` = war + 3 omods + python2, optional `pkgserver`); the server host-config setup script (static-IP netplan + hardening per §3.1; or a pre-imaged disk — §2.1); seed SQL (snapshot + concept fix + `site-<pilot>.sql`) + profile CSV; the signed release APK.
3. **Documentation as PDF** (authored in Markdown): `STAGING-SETUP-GUIDE.pdf` (SolDevelo staging procedure / rebuild reference), `SITE-RUNBOOK.pdf` (MSF site staff), `CLINICAL-QUICKSTART.pdf` (clinical admin).
4. **Operations & support tools:** the `buendia-diagnostics` dump script; the secure remote-support tunnel and the data-export (USB/tunnel) per §3.5 (subject to data-protection sign-off); the router configuration backup file.
5. The one-command build script + notes (WS-3) for rebuilding/patching the bundle.

---

## 6. Indicative timeline (one engineer, ~8–10 working days)

| Day | Work |
|---|---|
| 1 | WS-3 server build env; `.omod` builds reproducibly. WS-1 compose skeleton (db + openmrs) up locally. |
| 2 | WS-1 complete: UTC alignment, profile-apply (python2) in image, REST round-trip green. |
| 3 | WS-2: snapshot load + bug-12 fix + `site-<pilot>.sql` + profile baked; clean boot ready-to-use. |
| 4 | WS-3 Android: Gradle mirrors, reproducible release build. WS-4 signed APK produced. |
| 5 | WS-4: signed APK + emulator validation (full clinical round-trip). Real-T4/T5 validation happens at staging once the procured units arrive. |
| 6 | WS-5 APK delivery (QR first install + in-zone card); WS-7 remote-support tunnel + data export; image tarball export; bundle assembly. |
| 7–8 | WS-6 staging guide + site runbook + quick-start (Markdown → PDF); end-to-end dry-run from bare Ubuntu to a working tablet on a clean PC. |
| 9–10 | Buffer: real-hardware surprises, profile iteration with the clinical owner, bundle polish. |

A second engineer can take WS-4/WS-6 in parallel with WS-1/WS-2. **Two-person team:** dependencies (WS-1→WS-2, WS-3→WS-4) cap the speed-up, so figure ~6–8 working days of effort — about **1.5 calendar weeks (~8–11 calendar days)** — once started and given the **site specifics** (for WS-2). SolDevelo iterates on an emulator during the build; real-T4/T5 validation happens at staging once the procured units arrive (procurement lead time is separate — below). These are effort estimates, not a commitment to a start date.

The §3.4 offline-resilience items (server NTP + DNS-intercept time sync, graceful shutdown, log caps, the `buendia-diagnostics` script, router-config export, in-zone QR cards) are part of WS-1 (server/setup script) and WS-6 (tools/docs) — roughly +0.5–1 day, absorbed by the buffer. WS-7 (remote support + data export) adds ~1–2 days, gated on data-protection sign-off.

**Procurement is separate calendar lead time.** SolDevelo now selects and buys the server, tablets, router, and power kit before staging can begin — order early; this lead time runs alongside (not inside) the engineering days above. Staging consumes ~1 day once hardware and the bundle are both in hand.

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
- **Remote access & data export expose patient data** — the support tunnel makes the server reachable when online, and the export takes clinical data off the kit (§3.5). Mitigations: server-initiated tunnel (no inbound ports at the site), encrypted + authenticated + auditable + switch-off-able, and **disabled until MSF data-protection sign-off**; export format/destination governed by MSF data policy. Clinical operation never depends on the tunnel; when offline, support falls back to the `buendia-diagnostics` USB dump (§3.4).
- **Old, unsupported stack** (OpenMRS 1.10.x / Java 7 / MySQL 5.6, all EOL). Acceptable for a controlled pilot; the reason production scope eventually rebuilds the appliance.
- **Profile-apply stays Python 2** inside the container. Works because the image is controlled; not a long-term answer (Python 3 port deferred).
- **Real-hardware unknowns on T4/T5** (glove calibration, telephony under CrossCall's ROM, screen density). Low risk now: SolDevelo procures and stages the actual T4/T5, so these are validated before the kit ships rather than discovered in the field; emulator iteration during the build de-risks earlier.
- **Single server, no spare (decided).** A dead laptop takes the pilot down until a replacement is built. Mitigations: USB DB backups (no data lost) + the setup script's `--offline` restore mode, so a replacement is stood up on any laptop from the USB bundle — fast, and even doable at an MSF office — rather than re-staged from scratch; an optional `dd`/Clonezilla restore image is an extra. No live spare is shipped (a deliberate cost trade-off).
- **Patient data at rest on tablets** relies on Android device encryption + a screen lock (v1.0 has no app-level DB encryption — §3.2/§8). Residual risk: an unlocked or stolen tablet, or one with no lock set. Mitigations: set a PIN/screen lock on every tablet at staging (this activates device encryption), physical custody, and the local DB being only a cache. App-level encryption (SQLCipher) is available later if MSF's data-protection policy requires it.
- **Signing-key loss** permanently breaks in-place updates (WS-4): Android updates only over an app signed with the same key, so a lost key forces uninstall + reinstall on every tablet, destroying any not-yet-synced local data. SolDevelo retains the keystore + passwords for the life of the pilot, backed up in ≥2 access-controlled locations (mechanism per SolDevelo's secrets practice; if stored in a repo, the key material is encrypted at rest, not committed in plaintext).

---

## 8. Decisions

### Decided
- **Autonomous kit** (not integrated with MSF's LIME EMR / OpenMRS 3 infra or field-IT) — confirmed by MSF as the agreed approach; a LIME-compatible app is the deferred long-term alternative.
- **Roles (revised 2026-07-30):** SolDevelo **builds the package, specifies the hardware, and proves it on its own hardware (technical test)**, and provides remote support; **MSF supplies the tablets, installs the actual shipping server from our package, and runs the user test / UAT in Switzerland**, then ships to the site and operates it. SolDevelo does not travel to site. *(Superseded: SolDevelo procuring the tablets and staging the kit on its own premises.)*
- **Two levels of test (2026-07-30):** **technical** at SolDevelo (does it work) and **user/UAT** at MSF Switzerland (do clinicians accept it). The user test is *expected* to produce form and location-tree change requests; §2.1 records what is cheap to change then and what must be frozen before it.
- **Remote support + data export:** an opt-in, server-initiated secure tunnel (dormant offline) — **Tailscale + SSH to start** (dial-out; SSH, no remote desktop needed on a headless server; swappable to self-hosted WireGuard/Headscale at sign-off) — carrying a `DataExportServlet` CSV export; USB export as the offline fallback (§3.5). **Enabled only after MSF data-protection sign-off** (open below).
- **Tablet data-at-rest: device-level encryption + a mandatory screen lock**, not app-level. v1.0 has no working app-level DB encryption (plain Android SQLite, not SQLCipher; the `ENCRYPTION_PASSWORD` flag is inert), and the pilot does not re-introduce SQLCipher (would reverse the bug-8 cleanup and break the v1.0 freeze). Protection = Android FBE/FDE (active once a screen lock is set) + mandatory PIN/lock + physical custody; the local DB is only a cache (§3.2, §7).
- **Signing keystore custody:** the APK signing keystore + passwords are SolDevelo's to retain and back up (§7) — redundant, access-controlled, for the life of the pilot.
- **Clinical profile baseline:** upstream Ebola profile [`ebola/bunia.csv`](https://github.com/projectbuendia/profiles/blob/master/ebola/bunia.csv); deploy then adapt. (Verified free of the `#%` bug.)
- **Server OS/stack:** Ubuntu 22.04 LTS + Docker Engine + Compose; unattended hardening per §3.1.
- **Hardware (SolDevelo to select + procure):** server = small x86-64 mini-PC/NUC/laptop per §3.1; router = low-power mini/travel router (dual-band, AP/mesh-capable, custom-DNS-capable) per §3.3, plus a spare router (cheap) and one extra AP/mesh node for coverage. SolDevelo proposes exact models for MSF visibility. (Server has no spare — §7; the router spare is unaffected.)
- **Packaging & staging:** the deployment package is an idempotent `setup.sh` (source of truth; `--online` at staging, `--offline` for rebuild) with pinned versions/image digests (WS-1); an optional disk image is a downstream restore artifact. **SolDevelo staff stage the single pilot kit.** **One server, no spare** — recovery is USB backup + `--offline` restore onto any laptop (§7).

### Open
**MSF inputs (domain knowledge):**
1. **Pilot site specifics** for `site-<pilot>.sql`: facility name, ward/room/bed/zone structure, clinician user accounts.
2. **Tablet count** (drives spare-device planning).
3. **Ward layout & construction** (drives §3.3 Wi-Fi + §7 environment): open bay vs. walled rooms, wall material, longest router-to-farthest-bed distance.
4. **Clinical owner** — adapts `bunia.csv` (final form & chart content).

**MSF decisions:**
5. **Data-protection sign-off** for the remote-support tunnel and the data export (§3.5) — the "discuss with Iona / Nan Hsin" thread; gates WS-7 being enabled.
6. **Server base — spec delivered 2026-07-30, machine still to be chosen.** `FIELD-PILOT-SERVER-SPEC.md` is the deliverable; it **recommends a repurposed or refurbished business laptop** over a mini-PC (battery = built-in UPS; screen is what the tablet scans the install QR from; it is the shape validated twice). MSF sources it and may repurpose an existing machine. Asked as **D1**. Hard rule recorded there: **Intel/AMD only** — this now excludes Snapdragon X "Copilot+" laptops and Apple Silicon Macs, a large share of current retail stock.
7. **Site's existing Wi-Fi vs. our own AP — DEFAULT INVERTED 2026-07-30 (§3.3).** The default is now to **reuse the site's Wi-Fi**; our own AP stays in the kit as the fallback and as the UAT subnet-mimic device. Rationale, trade-off table and the sequencing trap are in §3.3. **MSF is being asked to choose** (B2/B6) with both options explained, because the deciding facts are theirs. Note that "the site has Wi-Fi" is currently *our inference from a conversation*, not a confirmed fact — if it is wrong, option B is the only choice and coverage becomes the live risk.
   - **The one thing that decides it in practice:** whether they will give us a fixed, reachable address in their subnet, and whether their network isolates clients. The first is a coordination task; the second is silent and fatal.
   - **Schedule impact:** this answer gates the shipping APK and therefore the kit — see the §3.3 sequencing trap. It is the most schedule-critical config answer.

**SolDevelo decisions:**
8. **Hypercare support window** — whether/how SolDevelo provides an intensive early-pilot support period (commercial/staffing scope; MSF asked for it).
9. **Exact hardware models** (server, router) meeting §3.1/§3.3 — to propose to MSF.
