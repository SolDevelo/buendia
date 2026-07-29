# seed/ — database initialisation (WS-2)

MySQL runs every `*.sql` in `/docker-entrypoint-initdb.d/`, in filename order, on the first boot
of an empty `db_data` volume. Two files land there, from **two different places** — this split is
deliberate:

| File | Size | Where it lives | Why |
|---|---|---|---|
| `10-buendia-base.sql` | ~83 MB | **baked into `DB_IMAGE`** (`build-db-image.sh`) | heavy, stable, regenerable — travels by `docker pull`, so nothing has to be copied onto a site server |
| `20-buendia-site.sql` | ~12 KB | **bind-mounted** by compose | hand-edited per site (locations, accounts) — tailorable with no image rebuild or push |

> ⚠️ **Compose mounts the site seed as a single FILE, not the `initdb/` directory.** Mounting the
> directory would shadow the baked baseline inside the image, leaving a DB with no schema and no
> concepts — a server that appears to boot and does nothing. `setup.sh` fails the run if `DB_IMAGE`
> carries no baked seed (it checks the image label), so this can't ship silently broken.

## Build order

```bash
./build-seed.sh        # 1. db-snapshot -> initdb/10-buendia-base.sql   (~83 MB, git-ignored)
./build-db-image.sh    # 2. bake it     -> buendia-db:5.6-<gitsha>      (set as DB_IMAGE in .env)
```

Then publish it with `../tools/publish-images.sh` so a site server can `docker pull` it.

## Baseline seed — `build-seed.sh`

`db-snapshot/` (the git submodule) is a clean OpenMRS + Buendia instance in mysqldump `--tab`
format (per-table `.sql` schema + `.txt` data via `LOAD DATA LOCAL`, driven by `000_load.sql`).
`build-seed.sh` loads it into a throwaway `mysql:5.6` and re-dumps it as a single portable file:

```bash
./build-seed.sh            # -> initdb/10-buendia-base.sql  (~83 MB, git-ignored, regenerable)
./build-db-image.sh        # -> buendia-db:5.6-<gitsha>     (the seed, baked into an image)
```

`build-db-image.sh` refuses to bake a seed that doesn't end in mysqldump's `Dump completed`
marker — a truncated dump yields an image that boots with no concepts, which is a miserable
thing to diagnose on site. It stamps the seed's sha256, byte count and the repo git sha as
image labels (`docker image inspect --format '{{json .Config.Labels}}' buendia-db:latest`).

That baseline has the schema, ~50k concepts, global properties, and the system users (`admin`,
`daemon`) — but **no patients, no locations, no providers, and no usable login account**. The
last two are supplied by the site seed below.

## Site seed — `initdb/20-buendia-site.sql` (committed, hand-edited)

Without this file a fresh server boots but **cannot be used**: there is nowhere to admit a
patient to and nobody can log in. It ships:

- the **location tree** — `Facility` (root) → `Triage`, `Confirmed Zone`, `Suspect Zone`,
  `Probable Zone`, `Discharged`;
- the **default login account** `buendia` / `buendia` (web admin, REST, tablet credentials)
  with the six Buendia roles;
- one **provider** row so the account is selectable in the tablet's user picker.

This is the file to tailor per site (facility name, zone/ward/bed layout, clinician accounts).
It is small and idempotent (keyed on `uuid`), so it can also be applied by hand to a running DB.
Editing it only takes effect on a **fresh** DB — `down -v && up -d`; you do *not* need to re-run
`build-seed.sh`, which only rebuilds the 80 MB baseline.

> **Change the default password before a real deployment.** The salt is committed, so it is
> public — it adds no secrecy for a well-known default. Rotate with
> `../tools/create-openmrs-user.sh buendia <new-password>` (fresh random salt, running DB).

Unlike the other `initdb/*.sql`, this one is **not** git-ignored (see `../.gitignore`) — it holds
no PII and the package is not zero-config without it. Keep real patient data and any
PII-bearing site variants out of git.

The server module creates the rest of what it needs on first use (`DbUtils.ensureRequiredObjectsExist()`)
— including the special `Guest` provider (`uuid = buendia_provider_guest`, which the client
treats specially), the Buendia identifier types, and the order/placement concepts. Don't seed those.

### Optional extra layers

Add further numbered `*.sql` to `initdb/` if a deployment needs them (they run in filename order,
after the above): e.g. `30-concept-fix.sql` for the bug-12 concept-dictionary fix — though the
baseline load runs with `FOREIGN_KEY_CHECKS=0`, so it is probably unnecessary. Profile properties
no longer need a layer: `build-seed.sh` bakes them in (below).

## Baked-in clinical profile

`build-seed.sh` also **bakes the default profile into the seed** so a fresh boot comes up with
it **active out-of-the-box** (no manual upload/activate). It applies `../profile/bunia.csv` via
the `buendia-openmrs` image's `buendia-profile-apply` (sharing the throwaway MySQL's network) and
sets `projectbuendia.currentProfile`. This needs the image built first (`image/build-image.sh`);
if the image or CSV is absent, the seed is a clean baseline instead.

`../profile/bunia.csv` is the **tailorable source of truth** (committed). To change the shipped
profile: edit it (avoid bare `#%` number formats — bug 10) and re-run `build-seed.sh`. MSF can
still upload/activate a different profile at runtime via the Profile Manager UI.

## Verifying a fresh boot

After `down -v && up -d`, with **no manual configuration**, all of these must pass:

```bash
curl -s -o /dev/null -w '%{http_code}\n' -u buendia:buendia \
  http://localhost:9000/openmrs/ws/rest/v1/session                 # 200 — baked-in login works
curl -s -u buendia:buendia http://localhost:9000/openmrs/ws/rest/buendia/locations
                                                                   # 6 locations, Facility parent_uuid=null
curl -s -u buendia:buendia http://localhost:9000/openmrs/ws/rest/buendia/charts
                                                                   # buendia_form_chart — profile is active
```
