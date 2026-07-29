# seed/ — database initialisation (WS-2)

The MySQL container loads the **`initdb/`** subdirectory (mounted read-only into
`/docker-entrypoint-initdb.d/`); every `*.sql` there runs, in filename order, on the first
boot of an empty `db_data` volume. Only `initdb/` is mounted — so `build-seed.sh` and this
README are *not* executed by MySQL init.

## Baseline seed — `build-seed.sh`

`db-snapshot/` (the git submodule) is a clean OpenMRS + Buendia instance in mysqldump `--tab`
format (per-table `.sql` schema + `.txt` data via `LOAD DATA LOCAL`, driven by `000_load.sql`).
`build-seed.sh` loads it into a throwaway `mysql:5.6` and re-dumps it as a single portable file:

```bash
./build-seed.sh            # -> initdb/10-buendia-base.sql  (~83 MB, git-ignored, regenerable)
```

That baseline has the schema, ~50k concepts, global properties, and the system users — but
**no patients, no locations, no forms** (those are layered on per deployment).

## Layering (per deployment, later)

Add further numbered `*.sql` to `initdb/` (they run after the baseline):

- `20-concept-fix.sql` — bug-12 fix if needed (concept dictionary `creator=4`); note the
  baseline load already runs with `FOREIGN_KEY_CHECKS=0`, so it may be unnecessary.
- `30-site-<pilot>.sql` — **site-specific**: facility, ward/bed/zone tree, clinician accounts.
- `40-profile-props.sql` — sets `projectbuendia.currentProfile` / `projectbuendia.chartUuids`.

All `initdb/*.sql` are git-ignored (the baseline is regenerable; site SQL is sensitive).

## Baked-in clinical profile

`build-seed.sh` also **bakes the default profile into the seed** so a fresh boot comes up with
it **active out-of-the-box** (no manual upload/activate). It applies `../profile/bunia.csv` via
the `buendia-openmrs` image's `buendia-profile-apply` (sharing the throwaway MySQL's network) and
sets `projectbuendia.currentProfile`. This needs the image built first (`image/build-image.sh`);
if the image or CSV is absent, the seed is a clean baseline instead.

`../profile/bunia.csv` is the **tailorable source of truth** (committed). To change the shipped
profile: edit it (avoid bare `#%` number formats — bug 10) and re-run `build-seed.sh`. MSF can
still upload/activate a different profile at runtime via the Profile Manager UI.

The Buendia API user (`buendia`) is created by `tools/openmrs_account_setup <user> <pass>`
(`password = sha2(concat(pass, salt), 512)`), not shipped in the baseline.
