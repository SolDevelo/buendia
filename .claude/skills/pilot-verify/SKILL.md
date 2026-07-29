---
name: pilot-verify
description: Verify that a Buendia field-pilot stack is genuinely usable by a tablet, not merely running — REST auth, location tree and default zone, active profile, DB integrity, and the :9001 APK install path. Use after any stack boot, seed edit, profile change, APK publish, or when a tablet "can't connect" / "can't log in". Also the go/no-go check at staging and on site.
---

# Verify a Buendia pilot stack

`docker compose ps` showing three healthy containers proves the ports answer. It does **not**
prove a clinician can log in, that there is anywhere to admit a patient *to*, or that the APK
will install. Those have all been green-while-broken at least once on this project.

## Run it

```bash
deploy/tools/buendia-verify.sh              # full: REST + DB + package server (read-only)
deploy/tools/buendia-verify.sh --quick      # REST only — the field go/no-go, no docker needed
deploy/tools/buendia-verify.sh --write      # also admit a throwaway patient, then void it
```

Exit 0 = GO, 1 = NO-GO. Read-only by default: safe against a live clinical stack and against
the validated local test stack. Options: `--host --port --pkg-port --user --pass --project
--no-db --no-pkg`.

Credentials and DB name come from `deploy/.env` when present, else the seed defaults
(`buendia`/`buendia`). It always uses GET — **`curl -I` returns 500** on buendia resources
while GET returns 200, which will send you chasing ghosts.

## When to run which

| Situation | Command |
|---|---|
| After `docker compose up -d` on a fresh stack | full, then `--write` |
| After editing `20-buendia-site.sql` or applying a config answer | full (the location/default-zone/login-row checks are the point) |
| After `publish.sh` or a new APK build | full (byte-identity + numeric-version checks) |
| Tablet can't connect / can't log in | `--quick` first, then full |
| On site, non-technical operator | `--quick` |
| Validating a change without touching the live stack | boot a throwaway on a spare port, then `--port 9100 --project throwaway` |

`--write` is the only mode that proves admission actually works end-to-end. It voids the patient
afterwards, so active counts are unchanged — but OpenMRS never hard-deletes, so a voided row
remains and the sync bookmark advances. Prefer it on fresh and throwaway stacks; on a stack
holding real clinical data, use it deliberately.

## Reading a failure

Each check names its own remedy. The three that mean something non-obvious:

- **`exactly one login row` fails with a count > 1** — this is the lockout bug. `users` has no
  unique index on `uuid`, so re-applying the site seed inserts a duplicate and OpenMRS then
  rejects **every** login, even though both rows hold a correct password hash. The REST check
  above it will show 401-with-the-right-password. Recovery: delete the **higher** `user_id`
  (`user_role` first), then hit any endpoint with `?clear-cache`. Full detail in progress doc §4.
- **`exactly one default zone [*]` fails with NONE** — new patients will be admitted to whichever
  leaf sorts first *alphabetically*, not the zone the clinician is looking at. This is clinically
  wrong, not cosmetic, and it is invisible in the UI because the client strips `[...]` from
  displayed names. Fix in `deploy/seed/initdb/20-buendia-site.sql`; see `pilot-site-config`.
- **`sync trigger definers resolve` fails** — the six sync triggers point at a MySQL user that
  doesn't exist, so every patient/obs/order INSERT fails. `build-seed.sh` strips DEFINER clauses;
  a live DB can be unblocked with a GRANT (progress doc §4).

A `WARN` is informational — a dropped download won't resume, Guest isn't created yet — and does
not fail the run.

## What it deliberately does not check

It verifies the **server side**. It cannot tell you that the clinical workflow works on a real
tablet, that two tablets sync bidirectionally, that the APK has the right server address and
password baked in (`build-apk.sh` reads those back out — check its output line), or that the
published version isn't newer than what tablets run. Those need a device; see the WS-4/WS-5
notes in `docs/FIELD-PILOT-PROGRESS.md`.

Do not treat GO as "ready to ship". The shipping APK still has to be rebuilt with the real site
IP and password, and the signing key still has to be backed up.
