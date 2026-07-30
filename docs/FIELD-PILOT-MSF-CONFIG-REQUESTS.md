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
> **Priority of the answers we are waiting on**, highest first:
> 1. **B5** — what MSF's tablet image permits. Can invalidate the QR install route outright.
> 2. **B2/B6** — the network choice and the server's address. **Most schedule-critical**: the address is
>    baked into the tablet APK and the MSF-CH user test runs on a different network from the site.
> 3. **C1** — data-protection sign-off. Gates WS-7 being enabled at a site.
> 4. **D1** — the server machine, if anything is to be purchased (delivery lead time).
>
> _Last updated: 2026-07-30 (**all items marked sent**; **D1 added** — server hardware, with the spec
> delivered as its own document; **B2/B6 rewritten** — the default inverted to *reusing* the site's Wi-Fi
> and both options are now put to MSF; **new question added** — does the site Wi-Fi have internet, which
> decides tablet clock discipline and whether remote support is possible at all; **A6** no longer "not yet
> raised". Previously, 2026-07-29: B5 and B6 added, B2 rewritten, B1/A5 re-scoped to cheap-but-manual,
> B4 shape decided.)_

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

### B1. Server LAN address & site ID — 🟡 **blocks the shipping APK**

- **Need:** the static IP the server should take on the site network, and a short site identifier.
  If we are using the site's existing Wi-Fi (**B2**), this must be an address on **their** subnet that
  is free or reserved for us.
- **Why:** the server address is **baked into the tablet APK** at build time, as the default for a
  runtime preference. Changing it later does **not** require a reinstall — the address, username and
  password are all editable on the tablet (cog → Settings → *Buendia server* / *OpenMRS username* /
  *OpenMRS password* → save), a guided step a non-technical person can perform. But it must be done
  on **every** tablet, and until it is, that tablet cannot sync. So B1 and **A5** are **cheap-but-manual
  ×N**, not blocking: still worth deciding before the shipping APK build, just not a crisis if they slip.
- **If the address can only be known on arrival:** we cannot pre-build a zero-touch APK (the Android
  toolchain is not on the site server), so the fallbacks are (a) walk each tablet through the Settings
  change on site, or (b) ship our own router so we control the subnet. Neither is expensive; both cost
  per-tablet time in the field, which is the thing worth avoiding.
- **Default shipped:** `STATIC_IP=192.168.8.10`, `SITE_ID=pilot`.
- **Lands in:** `deploy/.env` (`STATIC_IP`, `SITE_ID`) → netplan + the APK's `APK_SERVER`.
- **Answer:** _(pending)_

### B2. Site network — 🟡 *(default INVERTED 2026-07-30: reusing their Wi-Fi is now our preference; both options put to MSF)*

> **⚠️ Direction change 2026-07-30 — this item was rewritten.** The default *was* our own shipped
> autonomous router, with their Wi-Fi as an option. It is now **the other way round**: reusing the site's
> Wi-Fi is our stated preference, and our own AP is the fallback (and the UAT subnet-mimic device). Full
> reasoning and the trade-off table are in `FIELD-PILOT-DEPLOYMENT-PLAN.md` §3.3; the short version is that
> **coverage is the risk we can neither measure nor fix from Switzerland**, whereas the addressing risk has
> a workaround on arrival — **and reusing someone else's network is already validated**, since both
> hardware runs (2026-07-29/30) put the server on an existing office network at a given static address
> (`192.168.0.250`) with the APK built for it, and it worked first time.
>
> **MSF has been asked to choose**, with both options explained, because "the site has Wi-Fi" is our
> inference from a conversation and not a confirmed fact.

- **⭐ NEW QUESTION (2026-07-30) — does the site's Wi-Fi have internet access, even intermittently?**
  This is small to ask and decides two things we cannot otherwise solve:
  1. **Tablet clock discipline.** With internet, Android's normal automatic time works and the problem
     disappears — *better* than the workaround we had designed. Without it, we have no way to discipline
     tablet clocks (our DNS-interception trick needs a resolver we control, which we do not have on their
     network), and since the encounter timestamp is supplied by the tablet, drift becomes **wrong clinical
     data**. See **A9** and **B5 q8**.
  2. **Whether remote support is possible at all.** No internet path means the tunnel is *impossible*, not
     merely disabled — a box nobody can look inside (**C1**, plan §3.5).
- **Need:** if the site's existing Wi-Fi is the network we use, we need, **before staging**:
  1. **subnet / netmask / gateway**, and a **free static address** for the server — ideally a DHCP
     reservation on their AP or controller;
  2. confirmation the network does **not isolate clients from each other** (see below);
  3. whether there is a **wired port** (AP or switch) where the server will live;
  4. SSID + passphrase, and whether the network is shared with other services or internet-facing;
  5. coverage over the actual zones (tents/wards) — poor coverage is the most common field failure.
     ⚠️ Ask specifically about the *zones*, not the site in general: a network covering an admin building
     is not evidence that it reaches a triage tent 80 m away;
  6. who administers it, and whether their IT must approve an unmanaged server holding patient data
     on it (ties to **C1**/**C2**).
- **⏱️ Why this is the most schedule-critical answer on the list:** the server's address is baked into the
  tablet APK, and the **MSF-CH user test runs on a different network from the site**. Either the address is
  known before the shipping APK is built, or the APK is rebuilt and reinstalled per tablet after UAT, or
  somebody performs a guided Settings change on every tablet at the site. Plan §3.3 records the neat way
  out: configure the fallback AP at MSF CH to **mimic the site's subnet**, so UAT runs against the final
  address and nothing needs touching afterwards — which only works if the address is settled before UAT.
- **⚠️ The silent killer — client isolation.** Many office/guest Wi-Fi networks isolate clients from
  each other ("AP isolation" / "client isolation"). On such a network tablets associate perfectly and
  simply **cannot reach the server at all**, with no visible cause. Same for VLAN separation and for a
  **captive portal**, which would break the app's HTTP calls. This must be tested on *their* actual
  network, not assumed.
- **Server on Wi-Fi vs wired:** a server should normally be **wired** into the network. `setup.sh`
  can put a static address on a wireless interface (it generates a netplan `wifis:` block), but that
  needs their passphrase stored on the box and is less reliable.
- **Contingency — now a firm decision, not a maybe: buy the AP regardless of MSF's answer.** It earns its
  place three times over (plan §3.3): it is the recovery path if their network isolates clients or turns out
  not to exist; it is how MSF CH can **mimic the site's subnet during UAT**; and it can extend coverage into
  a zone their network misses.
- **Default shipped (code):** `CONFIGURE_NETWORK=true` with a static `192.168.8.10/24` and no gateway (an
  isolated LAN). Set `CONFIGURE_NETWORK=false` to leave their network alone.
  **Expected shipping mode after the direction change:** `CONFIGURE_NETWORK=true` with *their* subnet and
  *our given* address — i.e. a static address on a network we do not own.
  ⚠️ **This puts a previously optional code path onto the shipping path.** Generated netplan has **never
  been applied on hardware** (both real installs used `CONFIGURE_NETWORK=false`), and if the site gives us
  no wired port it is the completely unproven **`wifis:`** branch that runs — executed by MSF, not us.
  **Test both branches before the MSF session** (progress §8 item 5).
- **Lands in:** `deploy/.env` (`STATIC_IP`, `NET_IFACE`, `NET_PREFIX`, `GATEWAY_IP`, `DNS_SERVERS`,
  `CONFIGURE_NETWORK`, `SITE_WIFI_*`) → `setup.sh` generates `/etc/netplan/60-buendia.yaml`.
- **Answer:** _(pending — "the site already has Wi-Fi" is so far a note to re-confirm, not an answer)_

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
  6. **Can a user add a Wi-Fi network manually?** If not, the `WIFI:`-URI join QR on our in-zone card
     is useless and the Wi-Fi must be pre-provisioned in the image.
  7. **Is device encryption on, and a screen lock enforced?** If the image already does this, **A11**
     is answered for free and it is no longer a staging step.
  8. **What is the tablet's time source with no internet?** ⚠️ The sync wire format carries a
     client-supplied encounter time (`JsonEncounter.time`), so a tablet with a wrong clock plausibly
     writes wrong timestamps — and Android will not accept a custom NTP server without root, so our
     chrony-on-the-server design does **not** reach the tablets. We should verify this properly rather
     than promise anything about timestamps. Related: **A9**.
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

### B4. Tablet provisioning model — plain sideload, or managed (Android Enterprise)? — 🟡 *(shape decided 2026-07-29)*

> **Decision (2026-07-29):** MSF supplies tablets carrying **their own system image** (reused from
> previous projects) and the APK is installed **by QR code after the server is up** — i.e. option (a),
> sideload, with the QR route as the *primary* path rather than the in-field fallback. The
> `adb install`-at-staging recommendation below therefore no longer applies, since the tablets do not
> pass through our hands. **This makes B5 critical**: whether QR install works at all depends on what
> that image permits.


- **Need:** a decision on how tablets are provisioned: (a) **plain sideload** — install the APK at
  staging and accept Android's one-time "install unknown apps" prompt per tablet, or (b) **managed
  device (Android Enterprise device-owner)** — factory-reset + QR enrollment into a device policy
  controller that installs the APK **silently** and can enforce the screen lock and lock the tablet to
  the Buendia app (kiosk).
- **Why:** the install warning clinicians see is Android's sideload gate, and it **cannot be removed by
  publishing to the Play Store** — Play only suppresses it for apps installed *from Play*, and the
  site has no internet, so tablets can never reach it. (Play would also require modernizing a 2016 app
  to a current `targetSdkVersion`, which the plan descopes, and Android has no purchasable
  code-signing trust like Windows Authenticode, so no certificate makes a sideloaded APK "trusted".)
  The prompt is **per install source and persists**, so with (a) it is a one-time staging step, not
  something clinicians meet repeatedly. Option (b) removes it entirely and is the same mechanism that
  would satisfy the screen-lock requirement in **A11**/**B3** — but it needs an EMM (self-hosted, or
  Google's Android Management API which needs internet at enrollment time) and is a separate piece of
  work.
- **Recommendation for the pilot:** (a). Provision at staging over USB with `adb install`, which raises
  **no warning at all** (there is no "unknown source"), and keep the QR install as the in-field
  fallback — notably for a tablet inside a contamination zone that cannot come out. Revisit (b) only if
  MSF wants managed fleet control.
- **To check on the actual hardware:** whether CrossCall T4/T5 ship Google Play Services / Play Protect
  (which adds its own "unsafe app" scan warning, separately from the sideload gate) and whether Play
  Protect should be turned off at staging.
- **Default shipped:** plain sideload; QR install documented, `adb install` recommended at staging.
- **Lands in:** the staging checklist / Site runbook (WS-6), `deploy/apk/README.md`.
- **Answer:** _(pending)_

### B6. If we use the site's existing Wi-Fi: the IP space — 🟡 **the consequences here are not obvious**

- **Need, precisely:**
  1. the **subnet and mask** the tablets get (e.g. `192.168.0.0/24`) and the **gateway**;
  2. the **DHCP pool range**, so we can take an address *outside* it;
  3. **one address reserved for the server** — either a static address outside the pool, or a DHCP
     reservation against the server's MAC;
  4. whether tablets and the server will **always land on the same subnet** — i.e. one flat L2
     network, not several APs on different subnets/VLANs;
  5. whether the network isolates clients from each other (see **B2** — this one is fatal and silent).

- **Why this is not just "pick a free IP":** an IP has to be **routable from the tablet**, not merely
  unused. A tablet on `192.168.0.42/24` treats only `192.168.0.*` as local; ask it for an address
  outside that range and it hands the packet to the gateway, which has no route to it and drops it.
  So a "probably free anywhere" address such as `192.168.200.1` is **completely unreachable** from a
  tablet on a `192.168.0.0/24` network, however free it is. **The server must sit in the same subnet
  as the tablets.**

- **Consequences to state to MSF:**
  - **The server address becomes a per-site value.** It is baked into the APK as the default for a
    runtime preference, so a wrong value is fixable by a guided Settings change on each tablet
    (**B1**) — but that is N tablet-visits, in the field.
  - **A DHCP address is not good enough on its own.** If the server's lease changes, every tablet
    silently loses the server. We need a reservation or a static address outside the pool.
  - **Roaming across subnets breaks it.** If different APs put clients on different subnets, tablets
    can reach the server from some places and not others — which will look like "the app is broken
    in that ward".
  - **If they cannot give us a fixed address in their space, we should ship our own router.** That is
    the only arrangement where one APK works at any site without per-site tailoring, because then we
    own the subnet. Worth weighing against the router we were planning to drop: the router is not
    only about coverage, it is about owning the address space.

- **Default shipped:** `STATIC_IP=192.168.8.10/24`, gateway unset (an isolated LAN — i.e. assumes
  **our own** router). `setup.sh` can instead leave their network alone (`CONFIGURE_NETWORK=false`).
- **Lands in:** `deploy/.env` — `STATIC_IP`, `NET_PREFIX`, `GATEWAY_IP`, `DNS_SERVERS`,
  `CONFIGURE_NETWORK`, `NET_IFACE`; and the APK's `APK_SERVER` (which defaults to `STATIC_IP`).
- **Answer:** _(pending)_

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

---

## Cross-cutting technical constraints to state when asking

Worth putting in front of MSF once, because they shape acceptable answers:

1. **Location UUID stability.** UUIDs are not hardcoded anywhere (client or server), so the tree can be
   changed freely *before* tablets sync. After that, keep UUIDs stable — patients already admitted
   reference them, and changing a UUID orphans them. **Get A1–A3 right before go-live**, not after.
2. **Renaming is safe; re-parenting and deleting are not.** A `name` change syncs cleanly to tablets.
3. **No sort-order field exists** — ordering is name-based only (A3).
3b. **The server must share a subnet with the tablets.** An address outside the tablets' subnet is
   unreachable no matter how free it is (see **B6**). A fixed, reserved address in their IP space is
   a hard requirement of using their Wi-Fi; if it can't be had, we bring our own router.
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
   - ⚠️ **What must be settled BEFORE the shipping APK is built:** **B1** the server address, **A5** the
     password, **A10** the idle timeouts. These are baked into the APK, so changing them later means a
     rebuild plus a reinstall on every tablet, or a guided Settings visit per tablet in the field. **These
     are the ones to push on.**
   - **Two rules for the UAT itself** (plan §2.1): every accepted change must be **folded back into the
     seed** or a reinstall silently reverts it, and the **UAT test data must be wiped** before the kit
     ships.
