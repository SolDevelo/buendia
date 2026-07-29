---
name: pilot-site-config
description: Apply a site-configuration answer to the Buendia pilot — facility name, zone/ward tree, default zone, clinician provider accounts, credentials, timezone, language, profile content, idle timeout. Use when an MSF config answer arrives, when asked to change locations/accounts/passwords/the profile, or when editing deploy/seed/initdb/20-buendia-site.sql. Covers the apply paths and the traps that lock tablets out.
---

# Apply a site-configuration change

Nearly all remaining pilot configuration lands in **one hand-editable file**:
`deploy/seed/initdb/20-buendia-site.sql` (committed on purpose; the package is not zero-config
without it). That file's own header comments are the authoritative reference for its structure —
read them before editing. This skill covers the surrounding workflow.

`docs/FIELD-PILOT-MSF-CONFIG-REQUESTS.md` is canonical for **which** file each answer lands in;
every item carries a *Lands in* field. Check it first, and update it last.

## 1. Route the answer, and know what it costs

Cost is what makes this a judgement call, not a text edit:

| Change | Where | Cost to apply |
|---|---|---|
| Facility name, zones, wards/beds, default zone, provider accounts | `20-buendia-site.sql` | **Cheap now.** Live-apply + `?clear-cache`. Expensive once tablets have synced — see UUID stability |
| Server password (A5) | `deploy/tools/create-openmrs-user.sh` on the running DB **and** `APK_OPENMRS_PASSWORD` | **Rebuild the APK + reinstall every tablet** |
| Site IP (B1), idle timeouts (A10), APK tunables | `deploy/.env` | **Rebuild the APK + reinstall every tablet** |
| Timezone (A9) | `deploy/.env` (`TZ=`) | Container restart |
| Clinical profile / forms (A7) | `deploy/profile/bunia.csv` | Re-run `build-seed.sh`, then a fresh DB — or upload via the Profile Manager page |
| Tablet PIN, device policy, provisioning (A11, B3, B4) | Staging checklist (WS-6) | No code change |

**Anything baked into the APK must be decided before the shipping APK is built.** Deciding
afterwards costs a physical reinstall on every device. See `pilot-build-kit`.

## 2. Edit

For locations, the whole mechanism lives in the location **name**, because the client strips
`[...]` before display:

- `[<n>]` — display order (the client sorts alphanumerically by name; there is no sort column)
- `[*]` — the zone new patients are admitted to (there is **no location picker** in the app)
- `[fr:…]` — a localized name

Exactly one location must carry `[*]`. With none, new patients silently land in whichever leaf
sorts first alphabetically — the bug that put patients in "Confirmed Zone" on 2026-07-29. It is
invisible in the UI, so only the verify check catches it.

**Keep UUIDs stable once a tablet has synced.** Renaming is safe and syncs; changing a UUID
orphans already-admitted patients. Nothing hardcodes a location UUID, so new nodes can use any
fresh UUID — but existing nodes must keep theirs.

## 3. Apply

**Preferred — fresh DB** (the file is only auto-applied on first init):
```bash
cd deploy/compose
docker compose --env-file ../.env down -v && docker compose --env-file ../.env up -d
```
`down -v` destroys all data on that stack. Read `pilot-stack` first; on a stack holding data
someone cares about, use the live path instead, or validate on a throwaway.

**Live server** — every statement is idempotent, so it can be replayed:
```bash
cd deploy
docker compose --env-file .env exec -T db mysql -uroot -p"$MYSQL_ROOT_PASSWORD" openmrs \
  < seed/initdb/20-buendia-site.sql
curl -u buendia:buendia 'http://localhost:9000/openmrs/ws/rest/buendia/locations?clear-cache'
```
The `?clear-cache` is not optional — without it the module cache keeps serving the old tree and
the change never reaches the tablets.

Watch the apply output for the file's **section 4 self-check**. If it prints `FATAL`, stop and fix
it before a tablet touches the server.

## 4. The trap that locks everyone out

`users` is the one table here with **no unique index on `uuid`**, so `ON DUPLICATE KEY UPDATE`
does not de-duplicate it. A careless re-apply inserts a second row with the same username, and
OpenMRS then rejects **every** login — with both rows holding a correct password hash, which makes
it a baffling failure. The file now guards against this with an explicit `NOT EXISTS`, but if you
hand-write user SQL you can still cause it.

Recovery: delete the **higher** `user_id` (from `user_role` first, then `users`), then
`?clear-cache`. Keep the lower id — that is the row tablets authenticate against.

## 5. Verify, then close the loop

```bash
deploy/tools/buendia-verify.sh
```
The location-tree, default-zone and login-row checks exist for exactly these edits. On a throwaway
or fresh stack add `--write`.

Then — this is the step that keeps getting dropped:

1. **`docs/FIELD-PILOT-MSF-CONFIG-REQUESTS.md`** — fill in *Answer*, flip *Status* to ✅.
2. **`docs/FIELD-PILOT-PROGRESS.md` §2** — note what changed.
3. If a **new** config question surfaced while doing this, add it to the requests doc immediately,
   with the default we currently ship and the file it lands in. Anything left in a commit message
   or a chat thread is lost.

See `pilot-checkpoint` for the full close-out.
