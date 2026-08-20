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
> ## ✉️ SENT TO MSF — 2026-07-30. We are now waiting for answers.
>
> The whole list went to MSF on **2026-07-30**, as the send-ready extract
> `FIELD-PILOT-MSF-REQUEST-OUTGOING.md` plus `FIELD-PILOT-SERVER-SPEC.md` (for **D1**). Every item is
> therefore **🟡 asked, awaiting answer** — none is ⬜ any more.
>
> **When an answer arrives:** fill in *Answer* **here** (this file is the master), flip the item to ✅,
> apply it to the named file — the `pilot-site-config` skill is the apply path — and note it in
> `FIELD-PILOT-PROGRESS.md` §2. The outgoing extract is *derived*; don't log answers into it.
>
> ## 🌐 The network is ours — settled, and it removed several questions
>
> **SolDevelo supplies the network: our own router, `192.168.8.0/24`, server at `192.168.8.10`.** No site
> network is used. Consequences for this list, so nobody chases a dead question:
> - **B2** asks only about the site's **physical layout**, which sizes the Wi-Fi equipment. It is not a
>   networking question and no network settings are needed from MSF.
> - **The server's address is ours and final** (`192.168.8.10`) — identical at SolDevelo, at MSF
>   Switzerland during UAT and at the site. **B1** is reduced to a cosmetic site label.
> - **"Our own router" does not mean "no internet".** The router's WAN port optionally takes an uplink
>   (cable, the site's Wi-Fi joined as a client, or a cellular SIM), which keeps tablet clock sync and
>   remote support available while nothing clinical depends on it. Asked as a non-blocking option in **B2**.
> - **D2** carries the equipment specification: `docs/FIELD-PILOT-NETWORK-SPEC.md` — a *family with three
>   coverage tiers* rather than a model, because the layout that picks the tier is the missing input.
>   SolDevelo procures.
>
> **Priority of the answers we are waiting on**, highest first:
> 1. **B5** — what MSF's tablet image permits. Can invalidate the QR install route outright, and the
>    tablets must also be able to **join our SSID** (q6 — no longer optional now that the network is ours).
> 2. **C1** — data-protection sign-off. Gates WS-7 being enabled at a site.
> 3. **D1** — the server machine, if anything is to be purchased (delivery lead time).
> 4. **D2 / B2** — the site layout, so the network equipment can be sized. Only the *extra* coverage nodes
>    wait on this; the baseline is bought and staged regardless.
>
> _Last updated: 2026-08-10. The network questions that were sent on 2026-07-30 (their subnet, gateway,
> DHCP pool, a reserved server address, VLANs, client isolation — the former item **B6**) are **withdrawn**:
> we supply the network. **The outgoing extract has been revised accordingly and needs re-sending**, with
> `FIELD-PILOT-NETWORK-SPEC.md` as a third attachment._

**Status legend:** ⬜ not asked · 🟡 asked, awaiting answer · ✅ answered & applied

---

## A. Clinical & site data

### A1. Facility name (root location) — 🟡

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
- **Default shipped (pilot start, per SolDevelo/PW):** `Facility` → Triage, Suspect Zone,
  Probable Zone, Confirmed Zone, Discharged (that display order, Triage receiving new patients — see
  A3 for the bracket markup that achieves it). No beds/tents.
- **Lands in:** `deploy/seed/initdb/20-buendia-site.sql` §1 / §1b.
- **⚠️ Ask MSF specifically about display order — see A3.**
- **Answer:** _(pending — expected to be adjusted before the final package)_

### A3. Zone display order + which zone receives new patients — 🟡 *(default chosen; confirm)*

- **Need:** (a) the order clinicians want the zones listed in, and (b) **which zone new patients are
  admitted to** by default.
- **Why (the constraint):** the Android client sorts locations **alphanumerically by name**
  (`LocationForest` / `Utils.ALPHANUMERIC_COMPARATOR`) and there is **no sort-order column**. Also,
  the add-patient dialog has **no location picker at all** — it always uses
  `LocationForest.getDefaultLocation()`, which is the location whose name contains an asterisk, or,
  failing that, **the first leaf in alphanumeric order**.
- **The good news — the fix is free and invisible.** The client strips anything in **square
  brackets** from a location's displayed name (`Intl.java`), so brackets can carry metadata:
  `[<n>]` sets sort order, `[*]` marks the default location, `[fr:…]` gives a localized name. This is
  the same convention the profile CSV already uses for form names. So:

  > `[1] Triage [*]` · `[2] Suspect Zone` · `[3] Probable Zone` · `[4] Confirmed Zone` · `[5] Discharged`

  displays as **Triage · Suspect Zone · Probable Zone · Confirmed Zone · Discharged** — clinical-flow
  order, no visible numbers — and admits new patients to Triage.

  *(This corrects an earlier version of this document, which claimed the prefixes would be visible in
  the UI and framed that as a trade-off. There is no trade-off; brackets are hidden.)*
- **Why it matters — found in testing:** during the 2026-07-29 tablet smoke test, a patient added
  while viewing **Triage** was assigned **Confirmed Zone**, because "Confirmed Zone" was
  alphabetically the first leaf. Admitting a suspect case into the confirmed zone is a clinically
  meaningful error, not a cosmetic one.
- **Default shipped:** the bracketed scheme above — clinical-flow order, **Triage** as the default
  landing zone. Applied to the running pilot DB and to the seed.
- **⚠️ To verify with MSF:** whether the **printed/exported** record shows the raw name (with
  brackets) — the stripping is client-side, so server-rendered output may show `[1] Triage [*]`.
- **Lands in:** `deploy/seed/initdb/20-buendia-site.sql` §1 (zone `name` values).
- **Answer:** _(pending — confirm Triage is the right landing zone and the order is right)_

### A4. Clinician accounts → provider list — 🟡

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

### A5. Server login credentials & password policy — 🟡

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

### A6. Interface language — French? — 🟡 **likely important; raised 2026-07-30**

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

### A7. Clinical profile — forms, charts, questions — 🟡

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

### A8. Patient ID scheme — 🟡

- **Need:** the format of patient identifiers clinicians will type or scan (prefix, length, digits vs
  alphanumeric), and whether MSF numbers come from an existing external register.
- **Why:** the server keeps two identifier types — `MSF` (the externally meaningful number) and `LOCAL`
  (an auto-assigned fallback) — created automatically by `DbUtils`. We should confirm the expected shape
  before clinicians start typing, and whether duplicates across zones are possible.
- **Default shipped:** no constraint enforced; whatever the client sends becomes the MSF identifier.
- **Lands in:** no config file today — a validation/format decision; may need a client or profile change.
- **Answer:** _(pending)_

### A9. Timezone — 🟡 *(narrowed on 2026-07-29: only printed/exported output is affected)*

- **Need now:** confirmation of the site's timezone (`Africa/Kinshasa` UTC+1 or `Africa/Lubumbashi`
  UTC+2 — DRC spans both), and a ruling on **one specific thing**: must the **printed patient record
  and any data export** show *local* time, or is UTC acceptable there?
- **What we established by testing (so this is no longer a broad question):** the stack runs **UTC**
  end-to-end and the **tablet displays device-local time**. An admission recorded at 16:59 local was
  stored as `14:59:27Z` and shown on the tablet as **~16:59**. So:
  - **clinicians at the bedside already see local time** — nothing to change, and we specifically do
    *not* want to change `TZ`, because UTC end-to-end was chosen to fix an earlier timezone bug;
  - **server-rendered output is NOT converted** — the OpenMRS admin web UI, the printable record and
    `DataExportServlet` CSV read UTC, i.e. 1–2 h off local wall-clock. This is the only remaining
    exposure, and it matters for a printed record that goes in a physical file.
- **Dependencies on the tablets, worth stating to MSF (see B5 q8):** the stored instant comes from the
  **tablet's** clock (the sync payload carries a client-supplied time), so a tablet with a wrong clock
  writes wrong data, and a tablet with a wrong timezone displays wrong times. The server cannot
  compensate for either — both are per-device staging checks.
- **Default shipped:** `TZ=UTC` (host + MySQL + JVM). **Recommend keeping it.**
- **Lands in:** `deploy/.env` (`TZ=`). Changing it must be validated on a throwaway stack first.
- **Answer:** _(pending — only the printed/exported-record question remains)_

---

## B. Network & devices

### B1. Site identifier — 🟡 *(the server address is ours: `192.168.8.10`, settled)*

- **Need:** a short site identifier for labelling equipment, backups and diagnostics (e.g. `bunia`).
  Cosmetic; it blocks nothing.
- **The server address is not an MSF input.** We own the subnet (**B2**), so `192.168.8.10` is correct
  everywhere — at SolDevelo, at MSF Switzerland during UAT, and at the site. The APK is built once with
  that address and no tablet is ever repointed.
- **Worth keeping in mind anyway**, because it governs **A5** and **A10** which *are* baked in: the server
  address, username and password are all editable on the tablet (cog → Settings → *Buendia server* /
  *OpenMRS username* / *OpenMRS password* → save), so a wrong value is recoverable by a guided step a
  non-technical person can perform — but it must be done on **every** tablet, and until it is, that tablet
  cannot sync. Avoid needing it.
- **Default shipped:** `STATIC_IP=192.168.8.10`, `SITE_ID=pilot`.
- **Lands in:** `deploy/.env` (`STATIC_IP`, `SITE_ID`) → netplan + the APK's `APK_SERVER`.
- **Answer:** _(pending — `SITE_ID` only)_

### B2. Site layout — how much Wi-Fi equipment to bring — 🟡 *(the network itself is settled: ours)*

> **The network is SolDevelo's**: our own router, `192.168.8.0/24`, server cabled to it at
> `192.168.8.10`, one SSID across every access point. **No site network is used, and no network settings
> are needed from MSF.** Rationale in `FIELD-PILOT-DEPLOYMENT-PLAN.md` §3.3; equipment in
> `docs/FIELD-PILOT-NETWORK-SPEC.md` (**D2**).
>
> What that leaves as a genuine ask is **coverage sizing**, which depends on the site's physical layout —
> the one thing we cannot look up. The accepted cost of owning the network is that coverage is our risk;
> it is a fair trade because coverage is measurable, incrementally fixable and cheap, whereas nothing
> about somebody else's network could be tested from Switzerland at all.

- **Need from MSF — layout, not networking.** A sketch or photos answer these better than prose, and none
  needs a technical person. Full list in `FIELD-PILOT-NETWORK-SPEC.md`:
  1. how many separate spaces (buildings/wards/tents) tablets are used in;
  2. a sketch/photos with rough distances — where the server sits, where the farthest tablet works;
  3. the longest server→farthest-point distance in metres, and whether it is line of sight;
  4. **what the walls are made of** — the single biggest factor (plastic sheeting is nearly RF-transparent;
     concrete and metal are close to opaque);
  5. mains power at candidate AP positions, and whether we may mount hardware on a wall/pole/ceiling;
  6. whether a Green/Red contamination boundary is crossed (IPC constrains the answer — plan §3.3);
  7. any outdoor span between buildings (>~30 m changes the equipment class);
  8. environment (dust/heat/humidity), socket type and voltage — this also settles the **D1**
     laptop-vs-fanless question;
  9. *optional, non-blocking* — is any internet available for an uplink to our router, or should we plan a
     cellular SIM? Nothing clinical depends on it; it buys native tablet clock sync and remote support;
  10. tablet count (**B3**) — for node placement, not capacity.
  **Questions 1–5 decide the tier; nothing in the pilot is blocked while they are outstanding**, since the
  baseline tier is bought and staged either way and growing coverage is purely additive (same SSID, same
  LAN, no Buendia change).
- **Also needed, and it is permission rather than information:** is there any site rule or IT policy
  against us running our own Wi-Fi and our own server on it? We assume not, but if site IT must approve it,
  that is worth starting early (ties to **C1**).
- **Client isolation, captive portals and per-AP subnets** — the failure modes that would have been fatal
  and invisible on a shared network — are settled by owning the equipment. They survive only as hard
  requirement 8 of the D2 spec, verified once at staging.
- **Default shipped (the intended shipping mode):** `CONFIGURE_NETWORK=true`, static `192.168.8.10/24`,
  `GATEWAY_IP=` empty (isolated LAN; set to the router's `192.168.8.1` only when an uplink is present).
  ⚠️ **Still to verify:** generated netplan has **never been applied on hardware** (both real installs used
  `CONFIGURE_NETWORK=false`), so the **`ethernets:`** branch must be tested before staging — MSF executes
  that step, not us. The **`wifis:`** branch is not on the shipping path (the server is cabled to our
  router); it remains a documented fallback for a thin laptop with no RJ45 and no adapter.
- **Lands in:** `deploy/.env` (`STATIC_IP`, `NET_IFACE`, `NET_PREFIX`, `GATEWAY_IP`, `DNS_SERVERS`,
  `CONFIGURE_NETWORK`) → `setup.sh` generates `/etc/netplan/60-buendia.yaml`. `SITE_WIFI_*` is used only by
  the `wifis:` fallback above.
- **Answer:** _(pending — the layout answers)_

### B5. MSF's tablet system image — what does it contain and permit? — 🟡 **can invalidate the whole install path**

- **Context / decision taken:** MSF will supply the tablets with **their own system image**, reused
  from previous projects, and the Buendia APK is installed **by scanning the QR code after the server
  is up**. That settles **B4**'s shape — but the image's contents are unknown to us, and the QR path
  has hard prerequisites. If any of the first three answers below is "no", the QR path does not work
  and we need a different provisioning route.
- **Need — please ask whoever maintains that image:**
  1. **Is the device managed (MDM / Android Enterprise device-owner)?** If yes: (a) sideloading may be
     blocked by policy, which kills QR install outright; (b) their MDM could push our APK **silently**,
     which would be *better* than QR and would also satisfy **A11**/**B3**. Who administers it?
  2. **Is "install unknown apps" permitted** for the browser that will download the APK? This is the
     single make-or-break setting.
  3. **Is there a browser and a QR/camera scanner** on the image? Some hardened images strip Google
     apps entirely.
  4. **Is Google Play Services / Play Protect present?** Play Protect adds its own "unsafe app" scan
     warning, separate from the sideload gate, and can block installation.
  5. **Which Android version?** Our client is `minSdkVersion 19` / **`targetSdkVersion 24`**. Fine on
     current Android (14+ only blocks `targetSdk < 23`), but worth confirming before 20 tablets arrive.
  6. **Can a user add a Wi-Fi network manually?** ⚠️ **Make-or-break, alongside q2.** The tablets must join
     **our** SSID — we supply the network (**B2**), so it cannot already be in their image and there is no
     "the site Wi-Fi is already configured" path. If manual Wi-Fi joining is blocked by policy, neither the
     `WIFI:`-URI join QR on our in-zone card nor a hand-typed passphrase works, and the tablets cannot reach
     the server at all. If it is blocked, we need their MDM to push our SSID.
  7. **Is device encryption on, and a screen lock enforced?** If the image already does this, **A11**
     is answered for free and it is no longer a staging step.
  8. **What is the tablet's time source, and is "automatic date & time" on with Private DNS off?**
     ⚠️ The wire format carries a client-supplied encounter time (`JsonEncounter.time`), so a wrong tablet
     clock writes wrong clinical timestamps. Android accepts no custom NTP server without root, so we
     discipline tablets by **answering their SNTP lookup from our own router's DNS** (plan §3.4) — which
     needs automatic time **on** and Private DNS **off**. If the image locks either, tablet clocks are
     unmitigated unless the router carries an internet uplink. Related: **A9**.
  9. **Locale** — is the image French? (ties to **A6**).
- **Highest-value ask: one tablet with that exact image, in our hands before staging.** Everything
  above collapses into a 30-minute test.
- **Default shipped:** nothing — we assume a stock-ish Android that permits sideload from a browser.
- **Lands in:** the staging checklist / Site runbook (WS-6); may change `deploy/apk/README.md` and, in
  the worst case, the provisioning route itself.
- **Answer:** _(pending)_

### A10. Auto-logout idle timeout — 🟡 *(we changed the shipped default — confirm it)*

- **Need:** how long a tablet may sit idle before the app signs the clinician out back to the
  provider picker — separately for a tablet on battery and one on a charger.
- **Why:** the app auto-logs-out on idle so an unattended tablet can't have the next person's data
  entry attributed to the previous clinician. Upstream hardcoded **30 seconds** whenever the tablet
  is AC-charging (it infers "docked" from charging, because the 2016 docks never fired a dock
  event). Since idle time only resets on a touch, *reading* a chart for 30 s on a plugged-in tablet
  bounced the user to the login screen — unusable in a ward where tablets live on chargers.
  Trade-off to state: longer = fewer interruptions, but a longer window in which someone else could
  record data under the previous clinician's name.
- **Default shipped:** **10 min on battery, 5 min while charging** (we raised the charging value
  from 30 s). Now build-configurable rather than hardcoded.
- **Lands in:** `deploy/.env` (`APK_IDLE_LOGOUT_SECONDS`, `APK_DOCKED_IDLE_LOGOUT_SECONDS`) → baked
  into the APK by `deploy/apk/build-apk.sh`. Requires a rebuild + reinstall to change.
- **Answer:** _(pending)_

### A11. Tablet data-at-rest protection & screen-lock PIN — 🟡 **staging-blocking, cheap**

- **Need:** confirmation that every pilot tablet will have **device encryption on** and a
  **mandatory screen-lock PIN**, and whether the PIN is shared across tablets or per device (see
  also B3). If MSF data protection instead requires *app-level* encryption, say so now — that is a
  code change, not a setting.
- **Why:** the app does **not** encrypt its local database. `-PencryptionPassword` /
  `BuildConfig.ENCRYPTION_PASSWORD` still exists in the build, but **nothing reads it** and
  `sync/Database.java` uses plain `SQLiteOpenHelper` (SQLCipher was removed from this codebase), so
  that knob is inert — verified in the v1.0 source. Data-at-rest on the tablet therefore rests
  entirely on Android device encryption + the lock screen. Mitigating factor: the tablet DB is only
  a sync cache, and the server holds the record.
- **Default shipped:** no app-level encryption (inert flag left empty); device encryption + PIN are a
  **staging checklist step**, not something the APK can enforce.
- **Lands in:** the staging/provisioning checklist (WS-6), not a config file.
- **Answer:** _(pending)_

### B3. Tablet count & device policy — 🟡

- **Need:** how many CrossCall T4/T5 tablets, and the device policy: screen-lock PIN (shared or per
  device?), who may install apps, whether tablets leave the site.
- **Why:** drives APK provisioning (WS-4/WS-5), the encryption password, and the staging checklist.
- **Default shipped:** none.
- **Lands in:** staging checklist + APK build parameters.
- **Answer:** _(pending)_

---

### B4. Tablet provisioning model — ✅ **settled: plain sideload, installed by QR on site**

- **The shape:** MSF supplies tablets carrying **their own system image**, and the Buendia APK is installed
  **by scanning the QR code from our package server once the server is up**. Sideload is the route and the
  QR is the *primary* path, not a fallback, because the tablets never pass through our hands. **This is what
  makes B5 critical** — whether it works at all depends on what that image permits (q2 install-unknown-apps,
  q3 browser + scanner, q6 joining our SSID).
- **The install warning is unavoidable, and it is a one-time step.** It is Android's sideload gate, and
  publishing to the Play Store would *not* remove it: Play only suppresses the prompt for apps installed
  *from* Play, and the tablets have no internet path to it. (It would also mean modernising a 2016 app to a
  current `targetSdkVersion`, which the plan descopes; and Android has no purchasable code-signing trust
  like Windows Authenticode, so no certificate makes a sideloaded APK "trusted".) The prompt is **per
  install source and persists**, so clinicians do not meet it repeatedly.
- **The alternative we are not doing, and when to revisit it:** a **managed device** (Android Enterprise
  device-owner) would install the APK silently, enforce the screen lock (**A11**) and could lock the tablet
  to the Buendia app. It needs an EMM and is separate work — but if **B5 q1** comes back "yes, the devices
  are MDM-managed", it becomes the *better* route rather than a bigger one: their MDM can push our APK, and
  our SSID, with no prompt at all. Worth asking who administers it.
- **`adb install` at staging is not available to us** — it raises no warning whatsoever, but it needs the
  tablets in hand. Keep it in the runbook only for any tablet that does reach us.
- **To check on the actual hardware:** whether CrossCall T4/T5 ship Google Play Services / Play Protect
  (which adds its own "unsafe app" scan warning, separately from the sideload gate) and whether Play
  Protect should be turned off before the tablets ship.
- **Default shipped:** plain sideload; QR install is the documented route (`deploy/pkgserver/` + the in-zone
  card).
- **Lands in:** the staging checklist / Site runbook (WS-6), `deploy/apk/README.md`.
- **Answer:** ✅ settled — the remaining risk is tracked in **B5**.

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

### C2. Data retention & handover — 🟡

- **Need:** what happens to the data at the end of the pilot: retained on the box, exported to MSF,
  wiped? Who owns it, and is a backup allowed to leave the site?
- **Why:** determines the backup/export design and the decommissioning step of the site runbook.
- **Default shipped:** local snapshot backups only, nothing leaves the box.
- **Answer:** _(pending)_

---

## D. Hardware

### D1. The server machine — repurpose or buy? — 🟡 *(spec delivered 2026-07-30)*

- **Need:** either a machine MSF already has that passes the checklist, or a decision on which option to
  purchase. Plus the **site environment** (building vs dusty tent), which is the one input that could
  overturn our recommendation.
- **Full specification:** `docs/FIELD-PILOT-SERVER-SPEC.md`, written to be forwarded to whoever holds
  MSF's hardware. It went to MSF with the outgoing request.
- **Why it is here** and not only in plan §8: it is now an **asked** item awaiting an answer, so it needs
  answer-tracking alongside the rest. The *procurement* decision stays a programme matter (plan §8).
- **What we recommend:** a **repurposed or refurbished business laptop**, not a mini-PC — the battery is a
  built-in UPS against the pilot's main data-loss risk, the screen is what tablets scan the install QR
  from, and it is the shape validated twice on hardware. A 5–8 year old Core i5 is entirely adequate.
- **Hard rule to restate every time this is discussed:** **Intel or AMD only.** `mysql:5.6` is amd64-only
  and `setup.sh` hard-fails on anything else, which rules out **Snapdragon X / "Copilot+" laptops and
  Apple Silicon Macs** — a large share of current retail stock. Also required: 8 GB RAM (16 preferred), a
  real SSD (**not eMMC**), a **working RTC/CMOS battery** (an offline site cannot correct a wrong clock and
  patient timestamps depend on it), and a healthy main battery.
- **Default shipped:** none — no machine is chosen. `setup.sh` refuses non-x86_64.
- **Lands in:** no config file; it gates the UPS/graceful-shutdown work still open in `setup.sh`
  (on a laptop that is UPower battery thresholds; on a mini-PC it needs an external UPS wired up).
- **Answer:** _(pending)_

### D2. The network equipment — router family & coverage sizing — 🟡 *(SolDevelo specifies and procures)*

- **Context:** we supply the network (**B2**), so the equipment is ours to specify and buy. **MSF is not
  asked to provide a network** — only the site's **physical layout**, which decides how much is needed.
- **Full specification:** `docs/FIELD-PILOT-NETWORK-SPEC.md`, written to be forwarded like the server spec.
  It is deliberately a **family + three coverage tiers**, not a model, because the layout is unknown:
  - **tier 1** one ward/hall, farthest tablet ≤~15 m → a single head router;
  - **tier 2** several rooms/tents or a farther bed → head + 1–3 access-point nodes;
  - **tier 3** an outdoor span of 30–100 m → an outdoor/PoE AP or a point-to-point bridge pair.
  Recommended family is **GL.iNet (OpenWrt)**; alternatives (TP-Link Omada, UniFi, industrial Teltonika)
  are listed with the conditions under which they win. Total for tiers 0–2 is a few hundred CHF.
- **Need from MSF:** the layout answers enumerated in **B2** (spaces, distances, **wall material**, power
  and mounting at candidate AP spots, contamination boundary, outdoor spans, environment) — plus, optional
  and non-blocking, whether an internet uplink can be made available to our router or we should plan a
  cellular SIM. Also worth asking: would MSF rather we used an equipment family they already standardise
  on (fine, if it meets the ten hard requirements in the spec).
- **The two requirements that constrain the choice** (spec requirements 1–2), because ordinary consumer
  mesh kits fail them: it must work **fully standalone with no cloud account or internet to configure**,
  and it must support **custom local DNS entries** and advertise itself as the tablets' resolver — which is
  the only mechanism that keeps **tablet clocks** right at an offline site, and the tablet supplies the
  clinical timestamp (**A9**, **B5 q8**, plan §3.4).
- **Procurement stance:** buy the **baseline now** (Flint 2 head + one Beryl AX node + a second Beryl AX as
  bench unit and spare + cable + power bank, ~CHF 640) since it is needed for staging regardless and fits
  any plausible site; **defer** the extra nodes and the outdoor tier until layout answers arrive — they are
  orderable in days and the kit works without them. The spare is deliberately a full dual-band unit: the
  ~CHF 35 single-band travel routers fail spec requirement 3, so they validate none of the wireless config
  that ships and cannot stand in for a node.
- **Default shipped:** the LAN design is fixed and final — `192.168.8.0/24`, router `.1`, server `.10`, one
  flat L2, one SSID across all nodes. No equipment purchased yet.
- **Lands in:** no config file (`deploy/.env` already matches). It gates the coverage-walk and clock-intercept
  validation steps in the staging checklist (WS-6) and **WS-8**, which produces the router configuration
  that travels in the kit — as a `uci` script *and* an exported backup, since a backup archive is tied to the
  model it came from and would not restore onto a replacement router of a different model.
- **Answer:** _(pending — layout answers)_

---

## Cross-cutting technical constraints to state when asking

Worth putting in front of MSF once, because they shape acceptable answers:

1. **Location UUID stability.** UUIDs are not hardcoded anywhere (client or server), so the tree can be
   changed freely *before* tablets sync. After that, keep UUIDs stable — patients already admitted
   reference them, and changing a UUID orphans them. **Get A1–A3 right before go-live**, not after.
2. **Renaming is safe; re-parenting and deleting are not.** A `name` change syncs cleanly to tablets.
3. **No sort-order field exists** — ordering is name-based only (A3).
3b. **The server shares one flat subnet with the tablets** — `192.168.8.10` inside the `192.168.8.0/24`
   our own router hands out. An address outside the tablets' subnet is unreachable however free it is;
   owning the router is what makes this a design fact rather than something to negotiate.
4. **This is a 2016 Android app on an end-of-life server stack.** Config-shaped requests (names, accounts,
   profile content, locale, timezone) are cheap. Behaviour changes (sorting, validation, new screens) are
   code changes to an unmaintained codebase and are out of pilot scope unless explicitly funded.
5. **The package is never blocked on these answers** — it boots and is clinically usable with the defaults
   above. Each answer swaps out one default, mostly in a single small SQL file.
6. **Several of these are *expected* to be settled at the MSF user test, not before it** (added
   2026-07-30). There are two levels of test — technical at SolDevelo, **user/UAT at MSF Switzerland** —
   and the UAT is *for* eliciting changes to the clinical configuration. So split this list by cost:
   - **What UAT can change freely, live, with no rebuild and no tablet action:** **A1** facility name,
     **A2/A3** the zone tree, its order and the default zone, **A4** provider accounts, **A7** the forms
     and chart content. Chase these, but a "we'll decide when we see it" answer is perfectly workable.
   - ⚠️ **What must be settled BEFORE the shipping APK is built:** **A5** the password and **A10** the idle
     timeouts. (The server address is baked in too, but it is ours and settled — **B1**.) These are
     baked into the APK, so changing them later means a
     rebuild plus a reinstall on every tablet, or a guided Settings visit per tablet in the field. **These
     are the ones to push on.**
   - **Two rules for the UAT itself** (plan §2.1): every accepted change must be **folded back into the
     seed** or a reinstall silently reverts it, and the **UAT test data must be wiped** before the kit
     ships.
