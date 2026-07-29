---
name: pilot-stack
description: Manage the local Buendia field-pilot docker stack — reattach to a running one, boot a fresh one, boot a throwaway alongside it to test a change safely, or tear one down. Use whenever starting a session on the pilot, or when asked to start/stop/restart/reset the local stack, load the seed, or free up the environment. Contains the guard against destroying validated test data.
---

# Run the local pilot stack

Three containers: `db` (MySQL 5.6), `openmrs` (1.10.6 / Tomcat 7 / Java 7), `pkgserver` (nginx).
All commands run from `deploy/compose/` and need `--env-file ../.env`.

## Always start here — never boot blind

```bash
cd deploy/compose && docker compose --env-file ../.env ps
```

**A running stack usually holds test data that is expensive to recreate** (the validated
smoke-test dataset, or a state someone is mid-test on). `docs/FIELD-PILOT-PROGRESS.md` §3 records
what the current stack is holding — read it before touching anything.

- **3× healthy** → reattach, don't rebuild. Confirm with `deploy/tools/buendia-verify.sh`.
- **Some unhealthy / exited** → `docker compose --env-file ../.env up -d` (non-destructive; keeps
  the DB volume) and check `logs`. Do **not** reach for `down -v`.
- **Nothing** → fresh boot below.

## Fresh boot

Needs the OpenMRS image and the **DB image** to exist already: `deploy/image/build-image.sh`, and
`deploy/seed/build-seed.sh` → `initdb/10-buendia-base.sql` (~83 MB, git-ignored) →
`deploy/seed/build-db-image.sh` → `buendia-db:5.6-<gitsha>`, referenced as **`DB_IMAGE` in
`deploy/.env`**. The baseline seed lives *inside* that image now; only the 12 KB
`20-buendia-site.sql` is bind-mounted. If anything is missing, see the `pilot-build-kit` skill.

```bash
cd deploy/compose
docker compose --env-file ../.env up -d
docker compose --env-file ../.env logs -f openmrs      # Ctrl-C when it settles
deploy/tools/buendia-verify.sh --write                 # from the repo root
```

**First boot takes ~1–4 minutes** — MySQL loads the ~80 MB seed, then OpenMRS runs its Liquibase
startup (measured ~1 min total on this box with the image already local; allow longer on a cold
or slower machine). `up -d` returning is not readiness; the healthchecks are (`db` has a 180 s
start period, `openmrs` 300 s). Don't diagnose anything until both report healthy.

There is **no configuration step**. The seed ships the `buendia`/`buendia` login, the location
tree and the active profile. If a fresh boot ever needs a manual step to be usable, that is a bug
in the seed — fix it there (working guideline #9), don't patch the running container.

## Throwaway stack — test a change without touching a live one

The safe way to validate a seed or config edit while a stack is running (working guideline #7):

```bash
cd deploy/compose
OPENMRS_PORT=9100 PKGSERVER_PORT=9101 docker compose -p throwaway --env-file ../.env up -d
deploy/tools/buendia-verify.sh --port 9100 --pkg-port 9101 --project throwaway --write
OPENMRS_PORT=9100 PKGSERVER_PORT=9101 docker compose -p throwaway --env-file ../.env down -v
```

`-p throwaway` gives it its own containers **and its own named volumes**, so it cannot touch the
real stack's database. It does share `../seed/initdb/20-buendia-site.sql` and `../pkgserver/www`,
both mounted read-only. Always pass the same `-p` and port vars to every command in the group, including
`down` — otherwise you will act on the wrong stack. **Tear it down when finished**; a second
MySQL + Tomcat is not free.

## Teardown

```bash
docker compose --env-file ../.env stop     # pause; keeps everything
docker compose --env-file ../.env down     # remove containers; KEEPS the DB volume
docker compose --env-file ../.env down -v  # DESTROYS the DB and profile volumes
```

**`down -v` is irreversible and destroys all clinical data on that stack.** Only run it when the
user has said they are done with the data, or on a throwaway. Say what will be lost and get
agreement first. Everything else is reproducible from the seed; the *data* is not.

## Gotchas

- **`deploy/.env` is `source`d by bash.** Quote any value containing a space or `; & | $ \ ' " * ?`
  or the shell scripts abort with "command not found". docker compose itself tolerates them.
- **Ports:** OpenMRS is **8080 inside** the container, **9000 on the host**. Anything run with
  `docker exec` uses 8080; anything from the host or the LAN uses 9000.
- **Use the host LAN IP for anything a tablet must reach** (`192.168.0.150` on this box), not
  `127.0.0.1`. If a tablet can't connect but the host can, it is almost always the **host firewall**
  blocking inbound `:9000`.
- **`curl -I` returns 500** on buendia REST resources; GET returns 200. Never probe with HEAD.
- **Re-running the site seed against a live DB can lock every user out** — see `pilot-site-config`.
- Rebuilding the image or seed does **not** disturb a running stack; only `down -v` does.

`.env` and `apk/keystore/` are git-ignored and are the only things not reproducible from the repo.
