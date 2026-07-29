# Buendia field-pilot — deployment package

Turns a fresh **Ubuntu Server LTS** laptop/mini-PC into a configured, offline-capable
Buendia server. `setup.sh` is the **source of truth**; a disk image is an optional
downstream restore artefact. See `docs/FIELD-PILOT-DEPLOYMENT-PLAN.md` (WS-1, §3).

## Layout

```
deploy/
  setup.sh              idempotent orchestrator (--online default | --offline)
  .env.example          copy to .env; PIN versions/digests; holds secrets (git-ignored)
  compose/              docker-compose.yml (mysql:5.6 + openmrs, both UTC)
  config/               netplan (static IP), logind (lid-ignore), docker (log caps), chrony (LAN NTP)
  seed/                 build-seed.sh → initdb/*.sql (db init; only initdb/ is mounted) — see seed/README.md
  profile/              bunia.csv — default clinical profile (committed; baked into the seed)
  apk/                  build-apk.sh → release-signed Buendia APK (the .apk + signing key are
                        git-ignored; ship via Releases/USB) — see apk/README.md
  images/               docker-save tarballs for --offline (git-ignored)
  debs/                 Docker/Compose .debs for --offline (git-ignored)
  tools/                buendia-diagnostics.sh, buendia-export.sh
```

## Build order (engineering, before bundling)

`setup.sh` consumes a pre-built image and seed. Produce them first:
1. **Image** — `cd image && ./build-image.sh --fetch && ./build-image.sh` (see `image/README.md`).
2. **Seed** — `cd seed && ./build-seed.sh` → `initdb/10-buendia-base.sql` (see `seed/README.md`).

At a Staging Area these already come in the bundle (image tarball + seed), so the operator jumps
straight to Run.

## Run (at the SolDevelo Staging Area)

```bash
cp .env.example .env      # then edit: STATIC_IP, image digests, DB passwords, ...
sudo ./setup.sh           # --online: pull Docker + images from the internet
# or, with no internet (rebuild/restore on any laptop from the USB bundle):
sudo ./setup.sh --offline
```

The server comes up **ready to use — no configuration steps**. The seed ships the login account
`buendia` / `buendia`, the location tree (`Facility` → Triage / Confirmed / Suspect / Probable /
Discharged), and the active clinical profile. See `seed/README.md` to tailor the locations and
accounts (`seed/initdb/20-buendia-site.sql`) and for the fresh-boot verification commands.

**Before a real deployment, change the default password** (the seed's salt is committed, so the
default credential is public):
```bash
../tools/create-openmrs-user.sh buendia <new-password>   # fresh random salt, running DB
```

`setup.sh` configures the host (static IP, no-suspend, UTC + chrony, log caps),
installs Docker, loads the images, seeds + starts the stack, installs Tailscale
(**disabled** until data-protection sign-off), and health-checks the REST API.
It is **idempotent** — safe to re-run. Then complete the manual staging steps
(router config, tablet APK/clock/PIN, acceptance test) from the Staging Area guide.

## Reproducibility

Pin everything in `.env`: Ubuntu point release, `DOCKER_VERSION`, and image **digests**
(`@sha256:…`, not floating tags). The OpenMRS image (1.10.6 + buendia.omod + xforms +
webservices.rest + python2) is produced by the reproducible build (WS-3), not here.

## Hosting on GitHub

- **Public repo is fine** for this scaffold (scripts + config) — it's auditable.
- **Never commit secrets or site data:** `.env`, `TAILSCALE_AUTHKEY`, DB passwords,
  `seed/*site*.sql`, real clinician names. `.gitignore` covers these — keep it that way.
- **Pin to a tagged release**; don't `curl … main | bash`. Cloning a tag at staging
  (where you have internet) is reproducible; piping a moving branch is not.
- **Heavy binaries** (image tarballs, `.war`, APK) → GitHub **Releases** or Git LFS, or
  keep them off git and assemble onto the USB bundle. Don't bloat the repo.

## Status

The **server stack is built and smoke-tested end-to-end** (2026-07-17): `image/build-image.sh`
produces the OpenMRS image, `seed/build-seed.sh` produces the DB seed from `db-snapshot`, and
`docker compose up` boots a working server whose Buendia REST API answers 200 (see
`image/README.md`). Remaining known gaps, by design, not bugs:
- **Site data + profile:** `seed/` ships the clean baseline; wards/beds, clinician accounts, and
  the `bunia.csv` profile are layered in per deployment (WS-2 / staging).
- **Genuine TODOs in the scaffold:** the `DataExportServlet` endpoint in `tools/buendia-export.sh`
  (§3.5), the netplan interface name in `config/netplan/60-buendia.yaml`, and the UPS/battery
  graceful-shutdown wiring in `setup.sh` (§3.1) — each host-/deployment-specific.
- **APK:** the build is now reproducible (`apk/build-apk.sh`, release-signed, configured from `.env`)
  but **has not been installed on a real tablet yet**. In-app OTA updates don't work on the v1.0
  client, so pilot APK updates are manual — see `apk/README.md`.
- **Not yet exercised:** tablet validation of the packaged APK, the remote-support tunnel, and
  the full save-observation sync round-trip.
