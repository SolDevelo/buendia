# Field Pilot — Configuration Inputs Needed from MSF

> **Purpose:** the single, canonical list of *configuration data* SolDevelo needs from MSF to finish
> the pilot package. Each item says what we need, why it matters, **what we ship today as a default**,
> and exactly which file it lands in — so the package is never blocked: it already boots and works
> with the defaults below, and each answer replaces one default.
>
> **Keep this up to date.** When an answer arrives: fill in *Answer*, flip *Status* to ✅, apply it to
> the named file, and note it in `FIELD-PILOT-PROGRESS.md` §2. When a new config question surfaces
> during the build, add it here rather than in a commit message or a chat thread.
>
> This file covers **configuration**. Programme/logistics decisions (hardware model, staging location,
> hypercare scope, budget) live in `FIELD-PILOT-DEPLOYMENT-PLAN.md` §8 — don't duplicate them here.
>
> _Last updated: 2026-07-29._

**Status legend:** ⬜ not asked · 🟡 asked, awaiting answer · ✅ answered & applied

---

## A. Clinical & site data

### A1. Facility name (root location) — ⬜

- **Need:** the real name of the pilot site, as clinicians should see it on the tablet.
- **Why:** Buendia's location tree has exactly one parentless root, shown as the top of the patient-list
  navigation. Ours is a placeholder.
- **Default shipped:** `Facility`.
- **Lands in:** `deploy/seed/initdb/20-buendia-site.sql` §1 (root `INSERT`).
- **Answer:** _(pending)_

### A2. Location tree — zones, and wards/tents/beds — 🟡 *(pilot-start version agreed internally)*

- **Need:** the real ward/zone/bed layout: which zones exist, and whether each zone subdivides into
  tents/wards/beds (Buendia supports arbitrary depth; historically sites used `C1…C10`, `S1…S4`).
- **Why:** this is where patients are admitted. Nothing else in the app works without it, and changing
  it after tablets have synced orphans already-admitted patients (see *UUID stability* below).
- **Default shipped (pilot start, per SolDevelo/PW):** `Facility` → `Triage`, `Confirmed Zone`,
  `Suspect Zone`, `Probable Zone`, `Discharged`. No beds/tents.
- **Lands in:** `deploy/seed/initdb/20-buendia-site.sql` §1 / §1b.
- **⚠️ Ask MSF specifically about display order — see A3.**
- **Answer:** _(pending — expected to be adjusted before the final package)_

### A3. Zone display order → do you want numeric name prefixes? — ⬜ **needs an explicit MSF decision**

- **Need:** confirmation of the order clinicians want the zones listed in, and whether they accept
  numeric prefixes in the names to achieve it.
- **Why (the constraint):** the Android client sorts locations **alphanumerically by name**
  (`LocationForest` / `Utils.ALPHANUMERIC_COMPARATOR`); insertion order and `location_id` are ignored.
  There is **no sort-order field** in the data model. So with plain names the tablet shows:

  > Confirmed Zone · Discharged · Probable Zone · Suspect Zone · Triage

  …which is alphabetical, not clinical flow. The comparator sorts numeric prefixes *numerically*, so
  the only way to control order is to put it in the name:

  > `1 Triage` · `2 Suspect Zone` · `3 Probable Zone` · `4 Confirmed Zone` · `5 Discharged`

- **Trade-off to put to MSF:** prefixes give clinical-flow order but the numbers are visible in the UI
  (and in printed/exported records). Alphabetical order needs no name changes. Changing the client's
  sort logic is possible but is a code change to a 2016 app — out of scope for the pilot.
- **Recommendation:** use the prefixes. Triage-first matches the patient journey and reduces mis-taps.
- **Default shipped:** plain names (alphabetical order).
- **Lands in:** `deploy/seed/initdb/20-buendia-site.sql` §1 (zone `name` values).
- **Answer:** _(pending)_

### A4. Clinician accounts → provider list — ⬜

- **Need:** the list of people who will record data, and the **model**: shared accounts per role/shift,
  or one per clinician? For each: display name (given + family) as it should appear on the tablet.
- **Why:** the tablet's "who are you?" picker reads `GET /ws/rest/buendia/providers`. Every observation,
  order and encounter is attributed to the selected provider — this is the audit trail. Today everything
  would be attributed to `Guest` or to our placeholder account.
- **Note:** the special `Guest` provider is created by the server itself
  (`DbUtils.ensureRequiredObjectsExist()`, uuid `buendia_provider_guest`) and always appears first in the
  picker. Ask MSF whether Guest should remain available or whether attribution must always be a named person.
- **Default shipped:** one provider, `Buendia User`, plus the server-created `Guest`.
- **Lands in:** `deploy/seed/initdb/20-buendia-site.sql` §3 (one `provider` row per person).
- **Answer:** _(pending)_

### A5. Server login credentials & password policy — ⬜

- **Need:** the username/password the tablets and the web admin UI should use, or confirmation that we
  set one and hand it over at staging. Also: who is allowed to know it.
- **Why:** we currently ship a **public default** — `buendia` / `buendia`, with the salt committed in the
  repo, so the credential is effectively published. Acceptable for a lab; **must be rotated before the
  site handles real patient data.**
- **Default shipped:** `buendia` / `buendia`.
- **Lands in:** rotate on the running server with
  `deploy/tools/create-openmrs-user.sh buendia <new-password>` (generates a fresh random salt);
  the seed default lives in `20-buendia-site.sql` §2.
- **Answer:** _(pending)_

### A6. Interface language — French? — ⬜ **likely important, not yet raised**

- **Need:** the UI language for clinicians, and if French: confirmation that the shipped French strings
  are acceptable (they are from ~2016 and were not written for this deployment).
- **Why:** DRC is francophone, but the package currently ships an **English** UI. The client *does*
  contain French resources (`client/app/src/main/res/values-fr`), and the server's allowed locales are
  `en, en_GB_client`. Turning French on is a config + verification task (allowed-locale list, tablet
  locale, and a review of coverage/quality of `values-fr`) — cheap to do, expensive to discover late.
  Note the **clinical content** (form and question labels) comes from the profile CSV (A7), not from
  `values-fr`, so the two must be decided together.
- **Default shipped:** English.
- **Lands in:** `locale.allowed.list` global property + tablet locale; clinical wording in the profile CSV.
- **Answer:** _(pending)_

### A7. Clinical profile — forms, charts, questions — ⬜

- **Need:** confirmation that the shipped Ebola profile is the right clinical content, or a revised
  profile (which forms, which questions, which order, which chart layout, and in which language).
- **Why:** the profile CSV *is* the clinical configuration — it defines the charts, forms and fields
  clinicians see. Ours is the historical Bunia/Ebola profile. If the pilot is a different syndrome or a
  different protocol, this is the main content change, and it drives A6 (wording language).
- **Default shipped:** `deploy/profile/bunia.csv`, baked active into the seed
  (`projectbuendia.currentProfile = bunia.csv`).
- **Lands in:** `deploy/profile/bunia.csv`, then re-run `deploy/seed/build-seed.sh`. MSF can also
  upload/activate a profile at runtime via the Profile Manager web page.
- **Answer:** _(pending)_

### A8. Patient ID scheme — ⬜

- **Need:** the format of patient identifiers clinicians will type or scan (prefix, length, digits vs
  alphanumeric), and whether MSF numbers come from an existing external register.
- **Why:** the server keeps two identifier types — `MSF` (the externally meaningful number) and `LOCAL`
  (an auto-assigned fallback) — created automatically by `DbUtils`. We should confirm the expected shape
  before clinicians start typing, and whether duplicates across zones are possible.
- **Default shipped:** no constraint enforced; whatever the client sends becomes the MSF identifier.
- **Lands in:** no config file today — a validation/format decision; may need a client or profile change.
- **Answer:** _(pending)_

### A9. Timezone — ⬜

- **Need:** the site's timezone (e.g. `Africa/Kinshasa` UTC+1, or `Africa/Lubumbashi` UTC+2 — DRC spans both).
- **Why:** the stack currently runs **UTC** end-to-end (deliberately, to fix an earlier timezone bug).
  Observation timestamps and the printed/exported record will read in UTC unless set. Clinically this
  matters for shift boundaries and "when was this observation taken".
- **Default shipped:** `TZ=UTC`.
- **Lands in:** `deploy/.env` (`TZ=`) — applied to both containers and the JVM.
- **Answer:** _(pending)_

---

## B. Network & devices

### B1. Server LAN address & site ID — 🟡

- **Need:** the static IP the server should take on the site LAN, and a short site identifier.
- **Why:** tablets are configured to point at a fixed server address; changing it later means
  re-configuring every tablet.
- **Default shipped:** `STATIC_IP=192.168.8.10`, `SITE_ID=pilot`.
- **Lands in:** `deploy/.env`.
- **Answer:** _(pending)_

### B2. Wi-Fi / router — ⬜

- **Need:** router model, SSID + passphrase, coverage expectations (how many rooms/tents, distance),
  and whether the network is Buendia-only or shared.
- **Why:** the kit assumes an isolated LAN with no Internet. Tablets must associate automatically; poor
  coverage is the most common field failure.
- **Default shipped:** none — staging step.
- **Lands in:** router config at staging + the Staging Area runbook (WS-6).
- **Answer:** _(pending)_

### B3. Tablet count & device policy — ⬜

- **Need:** how many CrossCall T4/T5 tablets, and the device policy: screen-lock PIN (shared or per
  device?), who may install apps, whether tablets leave the site.
- **Why:** drives APK provisioning (WS-4/WS-5), the encryption password, and the staging checklist.
- **Default shipped:** none.
- **Lands in:** staging checklist + APK build parameters.
- **Answer:** _(pending)_

---

## C. Governance (gates work, not just config)

### C1. Data-protection sign-off — 🟡 **blocking WS-7**

- **Need:** written approval covering (a) remote support access to a server holding patient data, and
  (b) data export off-site.
- **Why:** the remote-support tunnel (Tailscale + SSH) is **installed but disabled** pending this, and
  `deploy/tools/buendia-export.sh` moves patient data. Without sign-off, WS-7 cannot be delivered and
  all support must be on-site or over the phone.
- **Default shipped:** `ENABLE_REMOTE_SUPPORT=false` in `deploy/.env`; Tailscale installed, not authed.
- **Answer:** _(pending)_

### C2. Data retention & handover — ⬜

- **Need:** what happens to the data at the end of the pilot: retained on the box, exported to MSF,
  wiped? Who owns it, and is a backup allowed to leave the site?
- **Why:** determines the backup/export design and the decommissioning step of the site runbook.
- **Default shipped:** local snapshot backups only, nothing leaves the box.
- **Answer:** _(pending)_

---

## Cross-cutting technical constraints to state when asking

Worth putting in front of MSF once, because they shape acceptable answers:

1. **Location UUID stability.** UUIDs are not hardcoded anywhere (client or server), so the tree can be
   changed freely *before* tablets sync. After that, keep UUIDs stable — patients already admitted
   reference them, and changing a UUID orphans them. **Get A1–A3 right before go-live**, not after.
2. **Renaming is safe; re-parenting and deleting are not.** A `name` change syncs cleanly to tablets.
3. **No sort-order field exists** — ordering is name-based only (A3).
4. **This is a 2016 Android app on an end-of-life server stack.** Config-shaped requests (names, accounts,
   profile content, locale, timezone) are cheap. Behaviour changes (sorting, validation, new screens) are
   code changes to an unmaintained codebase and are out of pilot scope unless explicitly funded.
5. **The package is never blocked on these answers** — it boots and is clinically usable with the defaults
   above. Each answer swaps out one default, mostly in a single small SQL file.
