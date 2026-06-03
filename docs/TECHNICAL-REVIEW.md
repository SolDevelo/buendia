# Project Buendia: Technical Review

This document answers four review questions:

1. Architecture, libraries, dependencies.
2. How the offline mode works and where data syncs.
3. Is the app usable as-is. Can it be deployed in DRC right now.
4. Concepts for a longer-term OpenMRS "outbreak module" for future epidemics.

Findings are based on reading the source at github.com/projectbuendia/buendia and a working end-to-end demo we built locally over two days.

---

## Methodology

We stood up the full Buendia stack against the current source:

- MySQL 5.6 (in Docker), populated from the project's standard schema snapshot.
- The Buendia OpenMRS module built from source against OpenMRS 1.10.6, deployed into a local Tomcat-based OpenMRS server.
- A test profile uploaded through the OpenMRS admin UI, defining a form (Temperature, respiratory rate, SpO₂, blood pressure, weight, height, AVPU consciousness, Shock, symptoms checklist) and a patient chart (tile row + Vitals grid).
- The Android client built from the source submodule, installed on both an emulated Sony Xperia Z2 (Android 4.4, the original target hardware) and a current-generation Android 16 (API 36) emulator.

We then drove the full clinical workflow:

- Logged in as a clinician.
- Browsed the location tree (Demo Facility, then Triage / Suspect / Probable / Confirmed zones, down to individual beds).
- Added a new patient and assigned them to a bed.
- Opened the patient chart.
- Opened the data-entry form, filled in vitals, saved.
- Confirmed the new observations propagated via the REST API and back to the chart.

This validates the architecture is functional.

---

## 1. Architecture, libraries, dependencies

### Architecture

Buendia has three components:

1. **Server-side OpenMRS module** (`openmrs/` in the repo). A custom OpenMRS module compiled to one `.omod` file. Exposes a Buendia-specific REST API at `/openmrs/ws/rest/buendia/...`, implements an incremental sync data model (`Bookmark`, `SyncPage<T>`, per-resource `*SyncParameters` Hibernate-mapped entities), and adds an admin web UI for uploading and applying "profile" CSVs that customise forms and charts per facility. Two Maven submodules: `api/` (services, DAO, sync model) and `omod/` (REST resources, web controllers, JSPs).

2. **Android tablet client** (`client/` submodule). A native Android app that authenticates against the server, syncs all patient, location, concept, form, chart, observation, and order data into a local SQLite database, and renders the clinical UI. Minimum API 19 (Android 4.4, KitKat) for the original Sony Xperia Z2 hardware. Compiles against API 28.

3. **Debian appliance packages** (`packages/`). About 22 `buendia-*` Debian packages that turn a stock Debian server into a Buendia appliance: MySQL setup, OpenMRS deployment, Wi-Fi access point, in-network apt mirror for tablet updates, automated backups, monitoring. Originally targeted the Intel Edison single-board computer.

The original hardware design assumed an Intel Edison (around $80 SBC, discontinued 2017) acting as Wi-Fi access point, OpenMRS server, and apt mirror, with Sony Xperia Z2 tablets (also long discontinued) on its Wi-Fi.

### Server-side libraries (Buendia OpenMRS module)

Compiled against OpenMRS Platform 1.10.x (released 2014). The platform brings in:

- Spring Framework 3.0.5. The bundled `JdkVersion` class doesn't recognise Java 8 strings, so the server cannot run under a Java 8 JVM out of the box.
- Hibernate 3.x.
- Tomcat 7 (recommended).
- MySQL 5.6 (hard requirement; the connection string hardcodes `storage_engine=InnoDB`, removed in MySQL 5.7+, so newer MySQL versions cannot connect).
- Java 7 (source targets 1.7; the platform check insists on Java 6 or 7 at runtime).

Additional module dependencies:

- `org.openmrs.module:webservices.rest` 2.6 (OpenMRS REST framework).
- `org.openmrs.module:xforms` 4.3.5 (XForms integration for ODK Collect form rendering).

Build tools:

- Maven 3.5.4 (the last version that runs reliably on Java 7).
- `openmrs-sdk-maven-plugin` 3.13.9 (the last release compatible with Java 7; pinning is required because newer plugin versions only run on Java 8).

### Android client libraries

The Android client uses libraries representative of 2014 to 2020 Android development:

- Dependency injection: Dagger 1.2.2 (superseded by Dagger 2 / Hilt).
- HTTP: Volley 1.0.6 (superseded by OkHttp / Retrofit).
- JSON: Gson 2.3.
- Date/time: Joda-Time 2.5 (superseded by `java.time` since Android 26).
- HTML template rendering: Pebble 1.5.1 (used for the chart WebView).
- Event bus: GreenRobot EventBus 2.4.0.
- Encrypted local SQLite: vendored SQLCipher binaries circa 2014 (32-bit only). In v1.0 the Java code no longer uses SQLCipher; the native libraries are dead weight in the APK.
- HTTP debugging: Facebook Stetho 1.2.0.
- Form rendering: ODK Collect (forked, vendored under `third_party/odkcollect/`).

Build:

- Android Gradle Plugin 3.2.1 (2018).
- `minSdkVersion 19` (KitKat, Android 4.4).
- `compileSdkVersion 28` (Android 9).
- `targetSdkVersion 22` (Lollipop), below the SDK 24 threshold Android 14+ requires for new installs.

### Appliance / packaging libraries

- Debian Stretch base (released 2017, EOL 2022).
- MySQL 5.6 (EOL February 2021).
- Tomcat 7 (EOL 2021).
- Python 2 + MySQLdb for profile-apply scripts (Python 2 EOL January 2020).
- Standard Debian apt tooling.

### Dependency health

| Component | Status | Impact |
|---|---|---|
| Intel Edison hardware | Discontinued 2017 | Original appliance can't be reproduced |
| Sony Xperia Z2 tablet | Discontinued | Original tablet can't be procured |
| MySQL 5.6 | EOL Feb 2021 | Works via Docker; not in modern OS repos |
| Java 7 JDK | Not in modern Linux distributions | Works via SDKMAN install |
| Debian Stretch | EOL 2022 | Appliance needs to be rebuilt on current Debian |
| Bintray / JCenter | Shut down May 2021 | Some Android artifacts unreachable through default Gradle resolution; workaround is mirror repositories |
| SourceForge OpenMRS plugin hosting | Flaky | Workaround is pre-staging artifacts locally |
| openmrs-sdk-maven-plugin 4.0+ | Requires Java 8 | Pin to 3.13.9 (last Java-7 release) |
| OpenMRS Platform 1.10.x | Released 2014, no security updates | Functional but unsupported |

---

## 2. Sync and offline check

### What "offline" means here, and what it doesn't

The word "offline" is overloaded. Buendia's offline capability is specific.

**What Buendia's offline mode provides:**

- A deployment site needs no Internet connection, initial or ongoing, to run the system. The server, tablets, and local Wi-Fi network are entirely self-contained at the site.
- The server appliance can be fully prepared off-site (at an office with Internet) and then shipped to the deployment location. On-site, the appliance only needs power and physical setup. First boot brings up the Wi-Fi access point and OpenMRS server immediately, no further Internet handshake.
- The server needs power. Buendia runs on a small SBC with low power draw, so it can run from a battery, UPS, or solar setup.
- Software updates are distributed via USB stick. Someone at an office downloads a new release onto a USB drive (or receives one by mail), inserts it into the server, and the local package server copies the packages onto its own storage. Tablets and the server then pick up the updates over the local Wi-Fi. The package server (`buendia-pkgserver`) is a local apt + APK mirror on port 9001. No Internet involved in the update path either.

**What it is not:**

- Not "tablets can work without the server". Tablets are clients. They need to be on the local Wi-Fi and able to reach the Buendia server. If the server is down or unreachable, tablets can't accept new data entry or look up patients they haven't recently viewed.
- Not "tablets can work without Wi-Fi" in any sustained sense. Tablets cache enough state to keep displaying recently-synced patients, so a clinician walking briefly out of Wi-Fi range can keep reading a chart, but any new data entry needs the server reachable to save.
- Not "real-time updates from outside the site". Updates arrive via USB stick. A fix takes physical-media delivery time, not seconds.
- Not "no IT setup at the site". The server still has to be powered, the Wi-Fi AP has to come up, tablets have to be on-network, and someone has to insert the USB stick when an update arrives.

The shape is site-offline, Internet-optional. Once the appliance is set up at a treatment centre, that centre is self-sufficient for clinical record-keeping. The centre still operates its own local network, server, and IT setup.

This is different from a Progressive Web App model (tablet browser runs the app standalone with no server) or a peer-to-peer model (tablets sync directly to each other with no central server). Buendia is neither. It relies on a local Linux server at the site.

### Network topology at the site

The site's runtime network is fully local:

- The Linux server hosts its own Wi-Fi access point (`buendia-networking` package), typically named after the deployment site. Tablets join this Wi-Fi.
- The server runs OpenMRS internally on port 9000. The Buendia REST API is at `http://<server>:9000/openmrs/ws/rest/buendia/...`.
- Tablets address the server by hostname. The appliance runs a local DNS resolver so `server` resolves on the LAN.
- The server runs an apt + APK mirror on port 9001 (`buendia-pkgserver` package). It serves new software to tablets and to the server itself. Its content is replenished by USB stick, never by reaching out to the Internet.
- All clinical data lives on the server. Tablets are caches and clients, not authoritative.

No part of this loop touches the Internet (clinical workflow, software updates, or DNS resolution).

### Where data is stored

- Server side: MySQL on the Linux server. Contains all patients, locations, observations, encounters, orders, concepts, forms, charts, user accounts. This is the system of record.
- Client side: each tablet maintains its own SQLite database (in debug builds at `/data/data/org.projectbuendia.client.dev/databases/buendia.db`). The local DB is a cache: a denormalised projection of server-side data kept fresh by periodic sync. Tablet-side data loss isn't catastrophic; on next sync the tablet rebuilds from the server.

### How synchronization works

Buendia uses an incremental, resource-by-resource, bookmark-based sync model:

- Server-side `ProjectBuendiaService.getXxxModifiedAtOrAfter(bookmark, max)` methods return a `SyncPage<T>` (batch of changes plus a new bookmark) per resource type.
- Client-side `SyncAdapter` and per-resource `SyncWorker` classes (locations, users, concepts, patients, forms, charts, observations, orders) call the corresponding REST endpoint with a `?since=<bookmark>` parameter.

Each resource has its own bookmark. The server tracks `date_updated` per row via Hibernate-mapped `*SyncParameters` entities (`ObsSyncParameters`, `OrderSyncParameters`, `PatientSyncParameters`). The bookmark is essentially `(date_updated, last_seen_uuid)` so pagination is stable across reads.

Sync periods, configured per resource:

| Resource group | Period | Notes |
|---|---|---|
| OBSERVATIONS, ORDERS, PATIENTS | 10 seconds | High-frequency clinical writes |
| LOCATIONS, USERS | 30 seconds | Rarely change |
| Everything (LOCATIONS, USERS, CONCEPTS, CHART_ITEMS, FORMS, PATIENTS, OBSERVATIONS, ORDERS) | 120 seconds | Full sweep |

When a clinician saves a form on a tablet, the client POSTs the encounter (with embedded observations) to `/openmrs/ws/rest/buendia/encounters`. The server creates the encounter and observations, returns 201. The next periodic sync pulls those observations back into the local cache for display.

### Sync reliability: a deployment-environment requirement

During the demo we initially observed a sync round-trip failure: after saving a form, the chart showed the new values for a fraction of a second, then re-rendered empty, with the server still holding the data and only a full app reset recovering it. We traced this through several layers and the root cause turned out to be **a timezone mismatch between the MySQL container (UTC by default in Docker) and the OpenMRS JVM (inherited the host's local timezone, in our case Europe/Warsaw)**.

The OpenMRS module's incremental sync compares `(date_updated, uuid) > (bookmark.minTime, bookmark.minUuid)` in MySQL. With the legacy Connector/J JDBC driver bundled with OpenMRS 1.10's classpath (and `useLegacyDatetimeCode=true` as the default), bookmark Date values are converted to MySQL DATETIME literals using the JVM's local timezone. When the JVM is in CEST (UTC+2) but MySQL is in UTC, the bookmark string sent to MySQL is shifted +2 hours relative to the column values, putting the filter conceptually "in the future" and silently excluding every freshly-inserted observation.

This is not a code bug. It's a deployment-environment requirement: **MySQL and the OpenMRS JVM must use the same timezone** (UTC is the conventional choice). One JVM flag fixes it:

```bash
# In the JVM startup args
-Duser.timezone=UTC
```

For the appliance build, this is a one-line addition to the JVM startup options. Standard production server practice already uses system-wide UTC, so this would not arise in a properly-configured deployment.

Effort to address: ~30 minutes to add the flag and document the timezone requirement in the deployment runbook.

### What was not tested

- Multi-tablet concurrent sync. We ran one client at a time. Field deployments typically have 5 to 15 tablets per site. Race conditions there are a known sharp edge in EMR systems.
- Real Wi-Fi AP integration. The appliance side wasn't built; we tested in Docker + emulator over a local network.
- Battery / power-cycle / recovery scenarios.

---

## 3. Usability assessment: can we deploy in DRC right now?

### Short answer

No, not as-is. The design is right for the use case and the core architecture works, but deploying the current state of the repository to DRC is blocked by:

1. The original server hardware is no longer procurable.
2. The original tablet hardware is no longer procurable.
3. The build pipeline depends on shut-down third-party hosting.
4. The deployment runbook is missing several configuration requirements (timezone alignment between MySQL and JVM, modern Android target SDK, etc.) that are easy to add once known.
5. The project has no active upstream. No meaningful commits since 2020.

### Bug list

| # | Issue | Severity | Estimated fix |
|---|---|---|---|
| 1 | Form-save sync round-trip fails when MySQL and the OpenMRS JVM use different timezones (e.g., MySQL in UTC, JVM in CEST). Bookmark filter excludes freshly-inserted observations because the legacy Connector/J JDBC driver converts bookmark Date values to MySQL DATETIME literals using the JVM's local timezone. **Deployment-environment requirement, not a code bug.** A properly-configured appliance with both MySQL and the JVM in the same timezone (typically UTC) does not exhibit this. | Operational — must be documented in the deployment runbook | Add `-Duser.timezone=UTC` to JVM startup; document timezone requirement. ~30 minutes |
| 2 | Original server hardware (Intel Edison) discontinued. Original tablet (Sony Xperia Z2) not procurable. | Blocking | Hardware refresh plus appliance rebuild, 1 to 2 weeks |
| 3 | Build pipeline depends on shut-down artifact mirrors (Bintray / JCenter) and incompatible plugin versions. Build can't be reproduced from scratch without substitutions. | Blocking for any new build | 1 to 2 days of toolchain fixes |
| 4 | Profile-apply scripts use Python 2 (EOL 2020). MySQL driver for Python 2 is not in modern Debian repos. | Blocking for appliance install on modern Debian | Port to Python 3 (1 to 2 days), or vendor a Python 2 environment |
| 5 | Server module's bundled Spring 3.0.5 doesn't recognise Java 8 JVMs. Can only run on Java 7, which is EOL. | Operational. Limits hosting options. | Workaround: ship Java 7 JRE with the appliance. Longer term: upgrade to current OpenMRS. |
| 6 | Android client targets `targetSdkVersion 22`, below the SDK 24 threshold Android 14+ requires for new installs. | Blocking for installing on current tablets | One-line fix. We verified the app runs on Android 16 emulator after the bump. |
| 7 | Android client doesn't have `android:exported` declarations on activities. Required by Android 12+ for SDK 31+ targets. Doesn't block install at `targetSdk=24`, but blocks any future SDK bump to 31+ (Play Store rule). | Medium. Limits long-term tablet compatibility. | A few hours, mechanical |
| 8 | Android client bundles around 6 MB of unused vendored SQLCipher 32-bit native libraries. Prevents install on 64-bit-only Android emulators. v1.0 Java code doesn't actually use SQLCipher. | Low | 5 minutes. We removed and confirmed APK builds and installs. |
| 9 | ODK Collect's `PropertyManager` calls `getDeviceId()`, `getSubscriberId()`, `getSimSerialNumber()` on app startup. These throw `SecurityException` on Android 10+ for non-privileged apps, crashing the app on launch on modern devices. | Blocking for modern Android | Wrap calls in try/catch (10 lines). Done in the demo. |
| 10 | Chart number format `#%` in CSV profiles multiplies the value by 100 (Java `DecimalFormat` convention). Entering 89 for SpO₂ displays as `8900%`. | Low. Confusing documentation gap, not a code bug. | Update docs and sample profiles |
| 11 | The `tools/openmrs_setup` script references site SQL files (`site-*.sql`) that no longer exist in the repository (deleted 2019). Blocks fresh installs without restoring the historical files. | Blocking for setup | One commit to restore or update the script (~30 min) |
| 12 | Buendia concept dictionary SQL references a `creator=4` user that no longer exists in the snapshot. Foreign-key failures on load. | Blocking for setup | Stub-user insert or sed rewrite (~15 min) |

Most of these are mechanical, well-localised fixes. Issues 6, 8, and 9 together are everything needed to run the existing Android client on a current-generation Android tablet. We confirmed this by running it on Android 16. The "Android client is incompatible with modern devices" concern is overstated.

None of the findings have uncertain fix scope. The sync-related issue (issue 1) is a deployment-configuration requirement rather than a code defect.

### What "deployable to DRC" requires

The minimum to ship a working Buendia at a single DRC site comes in two scope shapes, depending on how much polish vs. how-soon MSF wants to trade off.

#### Minimum field-pilot (1 to 2 weeks)

A faster path for a controlled pilot at one site, with on-the-ground IT support:

- Server on a generic laptop or NUC via Docker Compose, skipping the bespoke SBC appliance rebuild. Both MySQL container and OpenMRS JVM configured for the same timezone (typically UTC). 1 to 2 days.
- Android patches we've already developed applied (targetSdkVersion bump, SQLCipher removal, telephony exception handling, chart-renderer fix, multidex, namespace patches). Already done in the demo; needs packaging. 1 day.
- Toolchain fixes to produce reproducible builds. 1 day.
- Deployment runbook for non-engineers (installer steps, user provisioning, profile upload, troubleshooting, timezone requirement). 2 to 3 days.

Suitable for: 1 site, 5 to 10 tablets, an on-site IT person who can handle setup.
Not suitable for: large fleets, sites without IT capacity, replacing existing systems clinicians depend on.

#### Production-grade single-site deployment (2 to 4 weeks)

The above plus:

- Server appliance modernization: rebuild on a Raspberry Pi 5 or similar SBC for a self-contained appliance form factor. Wi-Fi AP, package server, backups all configured, timezone standardised. 1 to 2 weeks.
- Real-device QA on the procurement-candidate tablet model. 2 to 3 days.
- Toolchain repair: full reproducible-build pipeline (bugs 3, 4, 5, 11, 12). 3 to 5 days.

Suitable for: actual outbreak-site deployment, multiple sites if the same procedure is repeated.

#### What's not in either scope

Both scopes defer:

- Multi-tablet concurrent-sync hardening. Both demo and field-pilot can still hit race conditions if multiple clinicians write to the same patient at the same instant. Needs testing and likely fixes for production reliability at scale.
- Fleet management (deploying to many sites with central operational visibility).
- Anything from Section 4.

---

## 4. OpenMRS integration: ideas for a longer-term outbreak module

This section is not a proposal. It's a menu of dimensions worth discussing with MSF when there's space for a longer conversation about future direction. The DRC deployment doesn't depend on any of these decisions.

### Starting position: Buendia is already an OpenMRS module

The server-side `openmrs/` directory compiles to `projectbuendia.openmrs.omod`, a standard OpenMRS module. It registers with the platform, declares its REST namespace, ships custom Hibernate mappings, and integrates with the OpenMRS admin UI. The "make this an OpenMRS module" goal is already met.

The longer-term question is what the next generation of that module should look like. Independent dimensions of that question, each of which can be decided separately:

### Dimensions to think about

**A. What OpenMRS platform to target.**

The current module is on OpenMRS 1.10.x (2014). The pragmatic target for any future work is the current OpenMRS 3.x line, via MSF's LIME EMR distribution. LIME is upstream O3 plus MSF configuration, with no OSS forks, so building for current O3 means automatic compatibility with LIME. No older LTS line is worth considering as a future investment target.

**B. Custom REST API vs FHIR R4.**

The current Buendia server module exposes a custom REST API at `/openmrs/ws/rest/buendia/...`. OpenMRS also ships a FHIR2 module that exposes its data as FHIR R4, the global health-IT interoperability standard. Two paths:

| Option | What stays custom | What's gained | What's harder |
|---|---|---|---|
| Keep custom API | All current Buendia REST resources | Smaller delta from current state, preserves JSON shapes the client already knows | All ongoing maintenance, no interop with other FHIR systems, we own all sync semantics |
| Migrate to FHIR R4 | Just `Chart` and `Profile` (UI configuration; FHIR has no analog). All clinical data (patients, observations, encounters, orders, locations, providers, concepts) goes through OpenMRS FHIR2 | About 80% less custom server code to maintain, interoperability with any other FHIR-aware system (DHIS2, IRIS, other MSF systems), aligned with WHO and Google industry direction | Bigger client-side rewrite, FHIR payloads are 3 to 5 times larger than custom JSON (matters less over local Wi-Fi but worth measuring), need to verify OpenMRS FHIR2's coverage of the specific queries Buendia uses |

FHIR migration is the stronger long-term move if MSF intends Buendia to be a long-lived asset. Overkill for a one-off DRC deployment.

**C. Android client: keep, rebuild, or replace.**

| Option | Effort | Trade-off |
|---|---|---|
| Keep and modernize | Smallest | Preserves Buendia UX exactly. All Android code stays under maintenance. |
| Rebuild on Google Android FHIR SDK | Medium-large upfront | Preserves Buendia UX. Storage, sync, and form rendering come from Google's SDK (used by WHO SMART Guidelines). Modern Android stack. Less code to maintain long-term. |
| Adopt a maintained OSS clinical mobile app (Muzima, OpenSRP 2) | Smallest engineering | Drops Buendia's UX (the gloved-use tile-row vitals view is the product differentiator). Probably a non-starter for outbreak ICU use, but worth knowing the option exists. |

**D. Profile mechanism: keep, generalise, or replace.**

Buendia profiles are CSV files defining forms and charts per facility. Three shapes:

- Keep as-is. Profiles are already a good abstraction. Curate a library of templates (cholera, Marburg, COVID-shape, etc.).
- Generalise. Extend the schema so non-Buendia clients can consume the same profiles. Useful if MSF wants to share customization across deployments.
- Migrate to FHIR Questionnaire. Replace the CSV format with FHIR's standard Questionnaire resource. Aligns with FHIR migration (B) and the Google FHIR SDK (C-rebuild).

**E. Admin UI for profile management.**

The current Profile Manager is a legacy JSP page in the OpenMRS admin section. O3 phases out the legacy admin pages. Options:

- REST + CLI only. Minimum viable. Clinicians lose the visual upload-and-apply flow but ops teams gain remote management.
- O3 microfrontend. Natural for an O3 / LIME deployment, matches the rest of the admin UX. Larger effort.

**F. Appliance ambitions.**

- Hand-rolled per deployment. What we'd do for DRC. Repeats for each new site.
- Reference appliance image. A downloadable `.img` MSF can flash onto an SBC. Lower per-deployment cost, higher upfront investment.
- Fleet management. Central operational visibility across multiple sites. Bigger investment; only makes sense if MSF intends wide deployment.

### Scope shapes

Each scenario combines choices on A through F:

| Scenario | Composition | Approximate effort |
|---|---|---|
| Pragmatic minimum | A=stay on current OpenMRS for now; B=keep custom API; C=keep + modernize the client; D=keep profiles; E=reuse existing Profile Manager; F=hand-rolled | Roughly the DRC deployment scope plus ongoing maintenance, around 1 to 2 person-months/year ongoing |
| Tactical upgrade | A=current O3 via LIME; B=keep custom API; C=keep + modernize; D=keep profiles; E=O3 microfrontend; F=reference appliance image | 4 to 7 person-months initial, lower ongoing cost than the minimum |
| Strategic modernization | A=O3 / LIME; B=migrate to FHIR; C=rebuild on Google Android FHIR SDK; D=migrate profiles to FHIR Questionnaire; E=O3 microfrontend; F=reference appliance image | 8 to 14 person-months initial, lower ongoing cost, product is future-proof |
| Platform play | All of Strategic plus multi-site fleet management, more outbreak-profile templates, integrations with MSF's other systems | 18+ person-months, multi-year program |

These are not exclusive paths. MSF could pick the pragmatic minimum now, then upgrade incrementally based on field experience. Choices on A through F can also be staged: upgrade the platform (A) without touching the API (B) without touching the client (C).

### Relationship to the DRC deployment

The DRC deployment doesn't require any decisions in this section. Section 3's scope is self-contained and doesn't preclude any of the longer-term options. After DRC is up, MSF will have actual field feedback that should shape Section 4 decisions: what worked, what was painful, where future investment yields the most value. That conversation will be more productive then than now.

---

## Summary

- Buendia's design is appropriate for the use case. Off-grid appliance, tablet clients, OpenMRS server, profile-based customization. Core software works end-to-end as we verified.
- The codebase has aged in predictable ways: hardware EOL, library EOL, ecosystem rot. Most of the aging is mechanical to address.
- No high-severity code defects identified. The sync-related issue we initially flagged turned out to be a deployment-environment requirement (MySQL and OpenMRS JVM must share a timezone).
- Cannot be deployed in DRC as-is. Scope to make it deployable is 1 to 4 weeks depending on polish level.
- It's already an OpenMRS module. Future direction (LIME / O3 alignment, FHIR migration, Android client modernization) is a menu of options to discuss, not a single committed path.
