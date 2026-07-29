# buendia-openmrs image (WS-3)

Builds the deployable server image: **OpenMRS Platform 1.10.6 on Tomcat 7 / Java 7**,
with the Buendia omod + `xforms` 4.3.5 + `webservices.rest` 2.6, plus python2
profile-apply. Consumed by `deploy/compose/docker-compose.yml` (`OPENMRS_IMAGE`).

## Two-step model (optimized for the fix-and-rebuild loop)

1. **Once:** vendor the heavy deps (they rarely change):
   ```bash
   ./build-image.sh --fetch      # downloads war + xforms + webservices.rest → artifacts/
   ```
2. **Every code fix:** rebuild (fast — recompiles only the omod, reuses the warm Maven cache):
   ```bash
   ./build-image.sh --skip-tests
   ```
   Then in `deploy/`: set `OPENMRS_IMAGE` in `.env` to the printed tag and
   `docker compose up -d --force-recreate openmrs`.

Images are tagged `buendia-openmrs:<platform>-<git-sha>` and `:latest`.

## Publishing to Docker Hub (optional)

Build here, push to a registry, and let **staging** pull it:
```bash
./build-image.sh --tag=docker.io/yourorg/buendia-openmrs --push
```
Then set `OPENMRS_IMAGE` in `deploy/.env` to the printed `...@sha256:<digest>` (pin by
digest, not a mutable tag). `setup.sh --online` pulls it at staging.

Reconcile with offline: **Docker Hub is a staging convenience, not a site dependency** —
the site is offline and never pulls. For the `--offline` restore path (dead server →
replacement laptop, no internet), also `docker save` the image into `deploy/images/`.

Caveats: the build is pinned to **`linux/amd64`** (the server's arch) — on an ARM build
host this needs buildx + QEMU; verify the pushed image is amd64. The image has **no
secrets/patient data** (DB creds come from env at runtime), so a public repo is fine, but
a private repo is a reasonable default.

## Files

- `Dockerfile` — multi-stage: **builder** (`azul/zulu-openjdk-debian:7` = JDK 1.7.0_352 on
  Debian 11 + Maven 3.5.4 → compiles the omod, matching `tools/openmrs_build`; the omod's
  `buendia` xforms package comes in via the symlink to `third_party/`, so `third_party/` and
  `.git` are copied into the context) → **runtime** (same base + pinned Tomcat 7 + war + omods +
  python2/PyMySQL). BuildKit cache mount keeps `~/.m2` warm.
- `build-image.sh` — the one-command wrapper (`--fetch`, `--skip-tests`, `--tag=`, `--push`, `--no-cache`).
- `versions.env` — pinned versions + artifact URLs (single source of truth).
- `entrypoint.sh` / `runtime.properties.tpl` — render `openmrs-runtime.properties` from
  env (DB host/creds) and start Tomcat; `-Duser.timezone=UTC` (bug 1).
- `artifacts/` — vendored war + 2 omods (git-ignored; canonical names `openmrs.war`,
  `xforms.omod`, `webservices.rest.omod`).

## Status: built + smoke-tested end-to-end (2026-07-17)

Built and booted locally against MySQL 5.6 (see `deploy/seed/build-seed.sh` for the seed):
OpenMRS starts, Liquibase runs, the buendia + xforms + webservices.rest modules load, and
`GET /ws/rest/buendia/{patients,locations,concepts,charts,orders}` return **200** authenticated,
with a `Buendia-Server-Version` response header (proves the git-commit-id build).

Notes learned during that verification:
- Artifact URLs (`versions.env`) confirmed against the repo; omods publish as **`.jar`** (an
  `.omod` is a jar), so `--fetch` downloads the jar under the canonical `<name>.omod`.
- Base image: `openjdk:7` is gone from Docker Hub → **`azul/zulu-openjdk-debian:7`** (Debian 11);
  Maven 3.5.4 + Tomcat 7 are pinned tarballs; python2.7 + PyMySQL `<1.0` (1.0+ dropped py2).
- **`OPENMRS_APPLICATION_DATA_DIRECTORY` needs a trailing slash** (`/opt/openmrs/`) — OpenMRS joins
  it with `openmrs-runtime.properties` / `modules` without a separator.

Not yet exercised: the full save-observation **sync round-trip** (needs an authenticated encounter
POST; UTC is aligned on both containers, so bug 1 should be covered) and **profile-apply** against a
live server. If OpenMRS/central repos are flaky (WS-3), drop a `settings.xml` here with a mirror —
the Dockerfile picks it up automatically.
