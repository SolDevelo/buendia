# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Related documents in `docs/`

- **`docs/FIELD-PILOT-PROGRESS.md` — START HERE for the DRC field-pilot work.** Living status/handoff:
  where things stand, how to run the deployment package locally, hard-won gotchas, and working guidelines.
  Keep it updated after each major step.
- `docs/FIELD-PILOT-DEPLOYMENT-PLAN.md` — the full field-pilot deployment plan (goal, scope, workstreams,
  risks, decisions). `docs/FIELD-PILOT-EXECUTIVE-SUMMARY.md` is the one-page version.
- **`docs/FIELD-PILOT-MSF-CONFIG-REQUESTS.md` — the canonical list of configuration inputs needed from
  MSF** (locations tree & display order, clinician accounts, credentials, UI language, profile content,
  patient IDs, timezone, network, sign-offs). Each entry records the default we currently ship and the
  file it lands in. **Keep it up to date**: when an answer arrives, apply it and mark the item ✅; when a
  new config question surfaces during the build, add it there rather than burying it in a commit message.
- The deployment package itself lives in `deploy/` (server container stack, seed builder, image builder,
  APK builder, package server, tools) — see `deploy/README.md`. Two sub-READMEs matter:
  `deploy/apk/README.md` (reproducible release-signed APK build; the signing-key and versioning
  traps) and `deploy/pkgserver/README.md` (the `:9001` QR-install server and the printable in-zone
  card; why in-app OTA is not available).
- **Client (Android) changes for the pilot go on the `client` submodule's `drc-pilot` branch**
  (`git@github.com:SolDevelo/buendia-client.git` — the fork was renamed from `SolDevelo/client`),
  which the superproject's `drc-pilot` branch pins via `.gitmodules`. Prefer making behaviour
  **build-configurable** (a gradle `-P` property surfaced as an `APK_*` var in `deploy/.env`) over
  editing a hardcoded constant.
- `docs/TECHNICAL-REVIEW.md` — full technical findings from a 2026 review, including the architecture summary, known bugs, two deployment scope shapes for DRC (1.5–2.5 weeks vs 3–5 weeks), and future-direction options. Start here for the "what state is this in" question.

## Repository layout

Project Buendia is a multi-component system. Sub-projects live side-by-side in this monorepo and each has its own build:

- **`openmrs/`** — OpenMRS 1.10.x module (Maven, Java 7) that exposes the Buendia REST API. Two Maven submodules: `api/` (services, DAO, sync data model) and `omod/` (REST resources, web controllers, JSPs, packaged as `.omod`). Activator is `org.projectbuendia.openmrs.ProjectBuendiaActivator`; module config lives at `openmrs/omod/src/main/resources/config.xml`.
- **`client/`** — Android tablet app submodule (Gradle, `minSdkVersion 19`, `compileSdkVersion 28`). Source under `client/app/src/main/java/org/projectbuendia/client`. Uses Dagger 1 for DI, Volley for HTTP, EventBus, Joda-Time, Pebble templates, Stetho for debugging. Built with JDK 8+. The submodule was historically pinned to `v0.8` (2016) in the dev branch but that version's REST contract doesn't match the current server (the namespace was renamed); the working pairing is **client `v1.0` against server `v1.0`**.
- **`packages/`** — One subdirectory per Debian package (`buendia-server`, `buendia-openmrs`, `buendia-mysql`, `buendia-db-init`, `buendia-db-migrate`, `buendia-update`, site packages like `buendia-site-test`, etc.). Each package has a `Makefile` that includes `../Makefile.inc`, with package contents staged under `data/` and Debian metadata in `control/`.
- **`tools/`** — Server admin, build, and data-management scripts (`openmrs_setup`, `openmrs_build`, `openmrs_run`, `openmrs_dump`, `openmrs_load`, `mkdeb`, `generate_site_sql.py`, `dump_new_concepts_sql.py`, etc.).
- **`db-snapshot/`** — Git submodule containing the canonical MySQL snapshot used to initialise a fresh dev database. `tools/openmrs_setup` does `git submodule update --init db-snapshot`.
- **`devices/`** — Provisioning scripts for the physical Edison server hardware.
- **`openmrs/openmrs-project/`** — Generated/local OpenMRS SDK project; built `.omod` files land in `~/openmrs/server/modules` (the SDK server dir), not in the source tree.

## Common commands

### Server (OpenMRS module)

```bash
tools/openmrs_setup dev          # one-time: install OpenMRS SDK, MySQL DB, load db-snapshot + site-dev.sql
tools/openmrs_build              # build the module and deploy into ~/openmrs/server
tools/openmrs_build -DskipTests  # build without running tests
tools/openmrs_run                # run the dev server on http://localhost:9000/openmrs (login: buendia / buendia)

# Run a single test (from openmrs/):
cd openmrs && mvn -pl omod test -Dtest=ClassName#methodName

# Debug tests (waits for remote debugger):
cd openmrs && mvn -Dmaven.surefire.debug test
```

Notes:
- The server requires **JDK 7** and **MySQL 5.6** (newer MySQL versions break because OpenMRS hardcodes `storage_engine=InnoDB` in the connection string). Versions are pinned in `openmrs/pom.xml` (`openMRSVersion=1.10.0`) and `tools/openmrs_setup` (`OPENMRS_PLATFORM_VERSION`). After the 2026 demo work this is **1.10.6** with `openmrs-sdk-maven-plugin` pinned to **3.13.9** (the last Java-7-compatible plugin release). `tools/openmrs_build` duplicates the `xforms` and `webservices.rest` module versions.
- `tools/openmrs_run` launches Maven with remote-debug ports configured (uncomment `DEBUG_OPTS` in the script to enable jdwp on port 5005).
- The site argument to `openmrs_setup` (e.g. `dev`, `test`, `bunia`) selects which `site-*.sql` from `packages/buendia-db-init/data/usr/share/buendia/db/` is loaded after the snapshot. **The repo's stock setup script references `site-*.sql` files that were deleted in 2019**; for a fresh setup, restore the historical `site-demo.sql` from commit `b378f1b2^` or write a substitute.

### Client (Android)

```bash
cd client
./gradlew clean assembleDebug                  # build debug APK -> app/build/outputs/apk/
./gradlew :app:assembleRelease -PversionNumber=1.2.3   # signed release (needs ../../release/ repo for keystore)
./gradlew connectedAndroidTest                 # run instrumentation tests on attached device
./gradlew :app:spoon -PspoonClassName=org.projectbuendia.client.foo.MyTest  # run a single test class via Spoon
```

Override defaults at build time with `-Pserver=<host>`, `-PopenmrsUser=<u>`, `-PopenmrsPassword=<p>`, `-PrequireWifi=true`, `-PencryptionPassword=<pw>` (see `client/app/build.gradle`).

### Debian packages

```bash
make -C packages                                  # build every buendia-* package (.deb files end up under packages/<pkg>/)
make -C packages PACKAGE_VERSION=1.2.3            # pin a version (otherwise tools/get_package_version derives it)
make -C packages/buendia-server                   # build a single package
make -C packages tests                            # run package-level shell tests
make -C packages clean                            # remove built .debs and /tmp/buendia-packages
```

CI (`.circleci/config.yml`) runs `make -C packages` and then publishes the resulting `.deb`s into the `projectbuendia/builds` apt archive (`unstable` from `dev`, `stable` from release tags).

## Architecture

### Server (OpenMRS module)

The Buendia OpenMRS module is the synchronisation backbone. All REST endpoints are namespaced under **`/openmrs/ws/rest/buendia/...`** (note: not `/v1/projectbuendia/...`; an earlier version of the client used that path but the current server `RestController.PATH = "buendia"`). Dispatched by `RestController` (`openmrs/omod/src/main/java/org/projectbuendia/openmrs/webservices/rest/RestController.java`), which extends OpenMRS's `MainResourceController`. The controller wraps every method to (a) honour a `?clear-cache` parameter that flushes the module's caches via `ProjectBuendiaService`, (b) invalidate the HTTP session after each response so OpenMRS's session cache doesn't grow without bound, and (c) attach version headers from `VersionInfo`.

REST resources live in `openmrs/omod/.../webservices/rest/` and extend `BaseResource<T>`. The most important are `PatientResource`, `EncounterResource`, `ObservationResource`, `OrderResource`, `ConceptResource`, `ChartResource`, `LocationResource`, `XformResource`, `XformInstanceResource`. Each `@Resource`-annotated class is auto-registered by the OpenMRS REST framework.

The synchronisation pattern is the heart of the module: clients call `GET /patients?since=<bookmark>` (and the same for orders/observations) and the server returns a `SyncPage<T>` (a batch of changes plus a new bookmark). This is implemented by `ProjectBuendiaService` (interface in `openmrs/api/.../api/ProjectBuendiaService.java`, impl `ProjectBuendiaServiceImpl`) backed by `HibernateProjectBuendiaDAO`. The `Bookmark` type and `*SyncParameters` Hibernate-mapped classes (`ObsSyncParameters`, `OrderSyncParameters`, `PatientSyncParameters`) are what make incremental sync possible — see `config.xml` for the registered `.hbm.xml` mapping files.

Two-package layout: `openmrs/api/` contains the service + DAO + Hibernate-mapped sync model (no Spring/REST plumbing). `openmrs/omod/` contains everything that depends on REST/web (resources, web controllers under `org.projectbuendia.openmrs.web.controller` for the admin/print pages, the `DataExportServlet`, JSP templates in `omod/src/main/webapp/`). When adding a new sync endpoint, the DB-touching code goes in `api/`, the REST resource in `omod/`.

The module exposes two OpenMRS global properties (declared in `config.xml`): `projectbuendia.chartUuids` (comma-separated form UUIDs that should be served as charts) and `projectbuendia.currentProfile` (filename of the active profile CSV under `/usr/share/buendia/profiles/`). Profiles are uploaded/applied via the `ProfileManager` web controller and shell out to `buendia-profile-apply`.

### Client (Android)

The Android app mirrors the server's sync model. The package structure under `org.projectbuendia.client` divides into: `models/` (domain objects), `json/` (wire types), `net/` (Volley-based API client), `sync/` (Android `SyncAdapter` + `controllers/` that drive paginated `?since=<bookmark>` fetches), `providers/` (the local SQLite-backed `ContentProvider`), `events/` (EventBus payloads organised by topic: `data/`, `sync/`, `user/`, `diagnostics/`, `actions/`), `ui/` (activities/fragments grouped by feature: `login/`, `lists/`, `chart/`, `dialogs/`), `filter/db/` and `filter/matchers/` (search/filter predicates that run against the local DB or in-memory lists), `inject/` (Dagger modules), `updater/` (in-app `.apk` updater that pulls from a per-deployment package server on port 9001), `diagnostics/` (health checks), `widgets/`, `utils/`.

App ID is `org.projectbuendia.client`; debug builds get the suffix `.dev` and a distinct `ContentAuthority` so debug and release can coexist. The SQLite database is encrypted with the build-time `ENCRYPTION_PASSWORD` (empty in dev so Stetho can inspect it; supplied via `-PencryptionPassword` for release).

The app expects the OpenMRS server at `http://<server>:9000/openmrs` and the package server at `http://<server>:9001`. Default server hostnames (dev, integration, emulator-host, Edison server) are defined at the top of `client/app/build.gradle` and used to seed default preferences via `resValue`.

### Deployment / packages

A deployed Buendia "tablet edition" Edison server is just a Debian machine with the `buendia-*` packages installed. The package set splits along functional lines: `buendia-tomcat7` + `buendia-openmrs` + `buendia-server` provide the OpenMRS service; `buendia-mysql` + `buendia-db` + `buendia-db-init` provide the database (initialised from the same SQL files in `packages/buendia-db-init/data/usr/share/buendia/db/` used by `openmrs_setup`); `buendia-db-migrate` runs version-to-version migrations; `buendia-pkgserver` is the in-network apt repo served on port 9001; `buendia-update` is the in-place upgrade tool; `buendia-networking`, `buendia-sshd`, `buendia-setclock`, `buendia-ntpserver`, `buendia-pushclock`, `buendia-backup`, `buendia-monitoring`, `buendia-dashboard` round out the appliance. `buendia-site-*` packages override site-specific config (e.g. `buendia-site-test`, `buendia-site-bunia`).

Site-specific settings flow through shell variables in files under `/usr/share/buendia/site/<NN-name>` (lower numbers are defaults, higher numbers override) and are applied by config scripts in `/usr/share/buendia/config.d/<name>`. The `buendia-divert` helper lets a package replace another package's config file via dpkg-divert. See `packages/README.md` for the contract.

## Conventions

- **Java target is 1.7** across the openmrs module (set in `openmrs/pom.xml`). Don't introduce Java 8 syntax (lambdas, streams, default methods) in `openmrs/`.
- Server REST namespace is hardcoded to `/projectbuendia` (`RestController.PATH = "buendia"`); new resources should use `@Resource(name = RestController.PATH + "/<resource-name>", ...)`.
- Sync resources should return data via `BaseResource.syncItems(...)` and use `ProjectBuendiaService.getXxxModifiedAtOrAfter(...)` so that incremental sync keeps working. Update the `Bookmark` correctly or clients will re-fetch unnecessarily.
- When you add a new module dependency to the server, you must update **both** `openmrs/pom.xml` **and** `tools/openmrs_build` (the version is duplicated — comments in those files call this out).
- OpenMRS platform version is duplicated between `openmrs/pom.xml` (`openMRSVersion`) and `tools/openmrs_setup` (`OPENMRS_PLATFORM_VERSION`).
- New Debian packages: create `packages/buendia-<name>/`, put files in `data/`, declare deps in `control/control`, write a `Makefile` whose first line is `include ../Makefile.inc`. Use `data/usr/share/buendia/site/10-<name>` for default settings and `data/usr/share/buendia/config.d/<name>` for the apply-script.
- Client tests live under `client/app/src/androidTest/` and need a real device or emulator; the `androidTest` infrastructure uses `AndroidJUnitRunner` plus Spoon for multi-device runs and screenshots.
