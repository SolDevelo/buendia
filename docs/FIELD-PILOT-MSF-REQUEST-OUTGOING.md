# Buendia DRC Field Pilot — Configuration Inputs Needed from MSF

**From:** SolDevelo · **Date:** 2026-07-30 · **Status of our side:** the system is built, installed and
tested end-to-end on real hardware with a real tablet. What remains is site-specific configuration,
which only MSF can supply.

---

## How to read this

The pilot package **is not blocked** by anything on this list. It boots and is clinically usable today
on our default values — a clinician can admit a patient, fill in the forms and record a treatment. Each
answer below simply replaces one of our defaults with the right value for your site.

What *is* time-sensitive is the **order** the answers arrive in. Three of them can invalidate work
already done, so they come first. The rest can follow.

For each item we give: what we need, why it matters, and **what we do today if you don't answer**.
Where we have already chosen a sensible default, the question is just *"confirm or correct"* — those are
quick.

**Each item is tagged with who is likely to own it:**
🩺 clinical lead · 🖥️ site IT / network · 📋 programme / logistics · ⚖️ data protection

**To answer:** fill in the summary table at the end, or reply inline against the item numbers (A1, B5,
…). Partial answers are useful — please don't wait to have them all.

---

## Already agreed (recorded here so we're working from the same understanding)

- The pilot is an **autonomous kit** — its own server, its own tablets, **no Internet needed at the
  site**, and independent of MSF's LIME EMR / OpenMRS 3 infrastructure.
- **MSF supplies the tablets**, carrying MSF's own system image reused from previous projects. The
  Buendia app is installed onto them **by scanning a QR code** once the server is running. (This is why
  **B5** below is the most important question in this document.)
- **The site already has a Wi-Fi network**, so we expect to *not* ship a router — subject to **B2**/**B6**.
- **Server hardware:** SolDevelo specifies it, MSF sources it. **See D1 below and the accompanying
  document `FIELD-PILOT-SERVER-SPEC.md`** — if MSF has a suitable laptop to repurpose, that is the
  preferred outcome.

---

# Priority 1 — please answer these first

These have the longest lead time, and the first one can invalidate a finished part of the system.

## B5. Your tablet system image — what does it contain and permit? 🖥️📋

**This is the single most important question here.** The tablets arrive with your image, and the app is
installed by QR code. That path has hard prerequisites we cannot verify ourselves. **If the answer to
any of the first three is "no", the QR install route does not work and we need a different plan** — so
we would rather know now than at staging.

1. **Are the devices managed** (MDM / Android Enterprise device-owner)? If yes:
   - installing apps may be **blocked by policy**, which rules out QR install entirely;
   - but your MDM could instead push our app **silently to every tablet**, which would be *better* than
     the QR route and would also settle A11 and B3 for free.
   Who administers it?
2. **Is installing an app from a browser download permitted?** (Android calls this "install unknown
   apps".) This is the make-or-break setting.
3. **Is there a web browser and a QR/camera scanner on the image?** Some hardened images remove these.
4. **Is Google Play Protect present?** It adds its own "unsafe app" warning, separate from the above,
   and can block installation.
5. **Which Android version?** Ours works on current Android, but we'd like to confirm before ~20
   tablets arrive.
6. **Can a user add a Wi-Fi network by hand?** If not, the "join Wi-Fi" QR code on our in-zone cards is
   useless and Wi-Fi must be pre-configured in the image.
7. **Is device encryption on, and is a screen-lock PIN enforced?** If your image already does this,
   **A11 is answered for free** and drops off the staging checklist.
8. **How does a tablet get the correct time and timezone with no Internet?** This matters more than it
   sounds: **the time recorded against a patient's observations comes from the tablet's own clock**, so
   a tablet with a wrong clock records wrong times, and one with a wrong timezone displays wrong times.
   We cannot correct either from the server. See also A9.
9. **Is the image French?** (Relates to A6.)

> ### ⭐ Our highest-value ask: one tablet with that exact image, in our hands before staging.
> Every question above collapses into a 30-minute test. This is the cheapest risk reduction available
> to the pilot.

**What we do today:** we assume a normal Android tablet that allows installing an app from a browser
download.

---

## B6 + B2. The site network, and one reserved IP address for the server 🖥️

If we use the site's existing Wi-Fi, we need the following **before staging**:

1. **The subnet and mask** the tablets get (e.g. `192.168.0.0/24`), and the **gateway**.
2. **The DHCP pool range**, so we can take an address outside it.
3. **One address reserved for the server** — either a static address outside the pool, or a DHCP
   reservation against the server's MAC address.
4. **Confirmation that tablets and the server always land on the same subnet** — one flat network, not
   several access points on different subnets or VLANs.
5. **Confirmation that the network does not isolate clients from each other** (see the warning below).
6. **Is there a wired network port** where the server will live? A server should normally be wired.
7. **SSID and passphrase**, and whether this network is shared with other services or faces the Internet.
8. **Wi-Fi coverage across the actual zones** (tents/wards). Poor coverage is the most common cause of
   field failure.
9. **Who administers the network**, and must their IT approve a server holding patient data on it?
   (Relates to C1.)

### ⚠️ Two things that are easy to get wrong

**"A free IP address" is not enough — it must be in the tablets' own subnet.** A tablet on
`192.168.0.42/24` treats only `192.168.0.*` as local. Ask it to reach anything outside that range and it
hands the packet to the gateway, which has no route and drops it. So an address like `192.168.200.1` is
**completely unreachable from the tablets** no matter how unused it is. The server must sit in the same
subnet as the tablets.

**Client isolation is a silent killer.** Many office and guest Wi-Fi networks deliberately stop clients
from talking to each other ("AP isolation" / "client isolation"). On such a network the tablets connect
perfectly and simply **cannot reach the server at all, with no visible cause**. The same applies to VLAN
separation and to a captive portal (a login page), which would break the app's connection. **This must
be tested on your actual network — it cannot be assumed.**

**A DHCP address is not good enough on its own.** If the server's address changes, every tablet
silently loses the server.

**If a fixed address in your IP space cannot be arranged, we should ship our own small router.** That is
the only arrangement where one app build works anywhere, because then we control the addressing. We had
planned to drop the router since you have Wi-Fi — but the router is not only about coverage, it is also
about owning the address space. We're happy either way; we just need to know which.

**What we do today:** we assume our own isolated network at `192.168.8.10`. We can also leave your
network entirely untouched.

---

## B1. The server's address and a short site name 🖥️📋

- **Need:** the static IP address the server will take on the site network (this is the outcome of B6),
  and a short site identifier for labelling.
- **Why it matters:** the server's address is **built into the tablet app** as its default setting.
- **How bad is it if this changes later?** Not fatal, but not free. The address, username and password
  are all **editable on the tablet** (Settings → change → save) — a guided step a non-technical person
  can do. But it must be done on **every** tablet, including any tablet inside a contamination zone, and
  until it is done **that tablet cannot record or sync data**. So we'd like to build the shipping app
  with the real address in it.
- **If the address can only be known on arrival:** we cannot pre-build a zero-touch app, and the
  fallbacks are (a) walk each tablet through the Settings change on site, or (b) we bring our own router.
- **What we do today:** `192.168.8.10`, site name `pilot`.

---

## D1. The server machine — can MSF repurpose one? 📋🖥️

**A full specification is in the accompanying document `FIELD-PILOT-SERVER-SPEC.md`.** Please forward
that to whoever holds MSF's hardware. In short:

- The pilot needs **one** ordinary computer at the site. **We recommend a laptop, not a small sealed
  box** — its battery acts as a built-in UPS against power cuts (the pilot's main data-loss risk), its
  screen is what the tablets scan the install QR code from, and it is the exact configuration we have
  already installed and tested twice end-to-end.
- **If MSF has a suitable machine on the shelf, that is the preferred outcome** — no cost and no
  procurement delay. A 5–8 year old business laptop is entirely adequate; this software is not
  demanding.
- **The one hard rule:** the processor must be **Intel or AMD**. ❌ Not a Snapdragon X / "Copilot+"
  Windows laptop, not an Apple Silicon Mac, not an ARM Chromebook — the installer refuses to run on
  these, and a large share of current retail stock is now ARM.
- Also required: **8 GB RAM**, **128 GB+ SSD**, a **working internal clock battery** (an offline site has
  no way to correct a wrong clock, and patient timestamps depend on it), and a **healthy main battery**.
- **If buying:** we suggest a **refurbished business laptop** (ThinkPad / Latitude / EliteBook, Core i5+,
  16 GB, 256 GB SSD) — available refurbished and secondhand from Digitec in Switzerland. New and
  semi-rugged options, and a fanless mini-PC alternative for a permanently dusty installation, are all
  costed out in the spec document.

**What we need from you:** (a) do you have a machine that passes the checklist in the spec — and if so,
its processor/RAM/disk; (b) if not, which purchase option; (c) **is the site a building or a dusty
tent** (the one input that could overturn the laptop recommendation — same question as B2); (d) can the
machine reach us for staging before it goes to the site? Preparing it here is much easier than on
arrival.

**Why reasonably early:** the automatic clean-shutdown-on-low-battery step is the last unfinished piece
of our installer, and how we build it depends on whether this is a laptop or a mini-PC with an external
UPS.

---

## C1. Data-protection sign-off ⚖️

- **Need:** written approval covering (a) **remote support access** to a server holding patient data,
  and (b) **data export** off-site.
- **Why it matters:** the remote-support connection is installed but **switched off** pending this
  approval. Without sign-off, all support during the pilot must be on-site or over the phone, and we
  cannot deliver the data-export path.
- **What we do today:** remote support disabled.

---

# Priority 2 — needed before we build the version that ships

## A1. Facility name 🩺

The real name of the pilot site, as clinicians should see it at the top of the tablet's patient list.
**Today it says `Facility`** — a placeholder.

## A2 + A3. The zones, their order, and which zone receives new patients 🩺

**This one we have already filled in with a proposal — please confirm or correct it.**

We propose, in this order:

> **Triage · Suspect Zone · Probable Zone · Confirmed Zone · Discharged**

with **Triage** as the zone new patients are admitted to. No tents/wards/beds beneath them (the system
supports arbitrary depth if you want them — historically sites used `C1…C10`, `S1…S4`).

**Please confirm:** (a) that these are the right zones, (b) that this is the order clinicians want them
listed in, and (c) that **Triage** is where a newly admitted patient should land.

**Why (c) matters — this was a real bug we found in testing.** The app has **no zone picker when
admitting a patient**; it always uses one designated default zone. Before we fixed it, a patient added
while the clinician was *looking at Triage* was filed into **Confirmed Zone**. Putting a suspect case in
the confirmed zone is a clinically meaningful error, not a cosmetic one. It is fixed, and the fix is
verified on a real tablet — but it means **the choice of default zone is a clinical decision, not a
technical one.**

**One thing for you to rule on:** a **printed or exported** patient record may show some internal
ordering marks in the zone name that clinicians never see on the tablet screen. Tell us if that is
unacceptable on a printed record and we will address it.

⚠️ **Please get A1–A3 right before go-live rather than after.** Renaming a zone later is safe and easy.
Restructuring the tree after tablets have started recording data is not — patients already admitted
point at those zones.

## A4. Who records data — the clinician list 🩺

- **Need:** the list of people who will record data, and the **model**: shared accounts per role or
  shift, or one account per clinician? For each, the display name as it should appear on the tablet.
- **Why it matters:** the tablet asks "who are you?" before data entry, and **every observation, order
  and encounter is attributed to the person selected. This is the audit trail.** Today everything would
  be attributed to a generic placeholder account.
- **Also please decide:** the app always offers a **`Guest`** option, which we cannot easily remove.
  Should Guest remain available, or must every entry be attributed to a named person? (If the latter, we
  need to look at what that costs.)
- **What we do today:** one generic account, plus `Guest`.

## A5. Server credentials, and who may know them ⚖️🖥️

- **Need:** the username and password the tablets and the admin web page should use — or confirmation
  that we choose one and hand it over at staging. And **who is allowed to know it.**
- **Why it matters:** we currently ship a **default password that is published as part of the
  open-source package** — it is not a secret. That is fine for a lab. **It must be changed before the
  site handles real patient data.** Changing it is easy on the server; the cost is that each tablet then
  needs the same guided Settings change described in B1.
- **What we do today:** a published default. We recommend rotating it at staging.

## A6. Interface language — French? 🩺

- **Need:** the language clinicians should see. If French: confirmation that our existing French
  translation is acceptable — it dates from around 2016 and was not written for this deployment.
- **Why it matters:** DRC is francophone but the package currently shows an **English** interface.
  Turning French on is configuration plus a review of translation quality — cheap to do now, expensive
  to discover late. Note that the **clinical wording** (form and question labels) comes from the
  clinical content in A7, not from the app's translation, so **A6 and A7 need to be decided together.**
- **What we do today:** English.

## A7. Clinical content — the forms, charts and questions 🩺

- **Need:** confirmation that our shipped clinical content is right, or a revised version: which forms,
  which questions, in which order, which chart layout, and in which language.
- **Why it matters:** this content **is** the clinical configuration — it defines everything a clinician
  sees and fills in. Ours is the historical Bunia/Ebola content. If the pilot is a different syndrome or
  follows a different protocol, this is the main change needed, and it drives A6.
- **What we do today:** the historical Ebola form set, active out of the box. It can also be replaced at
  runtime from the server's admin page, so this is changeable on site if needed.

---

# Priority 3 — before staging / go-live

## A8. Patient ID format 🩺

The format of the patient identifiers clinicians will type (prefix, length, digits or letters), and
whether these numbers come from an existing MSF register. Today we enforce **no format at all** —
whatever is typed is accepted. Please also tell us whether the same patient number could legitimately
appear twice.

## A9. Timezone — and one specific question about printed records 🩺⚖️

We tested this, so the question is now narrow.

- **Confirm the site's timezone:** `Africa/Kinshasa` (UTC+1) or `Africa/Lubumbashi` (UTC+2) — DRC spans
  both.
- **What we established by testing:** **clinicians at the bedside already see correct local time on the
  tablet.** Internally the system stores times in UTC, and the tablet converts. An admission recorded at
  16:59 local was shown as 16:59 on the tablet. **Nothing needs changing there.**
- **The one open question:** **printed and exported records are not converted** — they read UTC, i.e.
  1–2 hours off local wall-clock time. **Must a printed patient record show local time, or is UTC
  acceptable there?** This matters if the printout goes into a physical patient file.
- **Related tablet dependency:** as noted in B5 q8, the recorded time comes from the tablet's clock. A
  tablet with a wrong clock or timezone produces wrong data and the server cannot fix it. Both need
  checking per device at staging.

## A10. How long before a tablet logs the clinician out? 🩺

- **Need:** how long a tablet may sit idle before the app returns to the "who are you?" screen —
  separately for a tablet **on battery** and one **on a charger**.
- **Why it matters:** this exists so an unattended tablet can't have the next person's data entry
  attributed to the previous clinician. The original behaviour logged users out after **30 seconds**
  whenever the tablet was charging — so simply *reading* a patient chart on a plugged-in tablet threw
  the clinician back to the login screen. Unusable in a ward where tablets live on chargers. **We have
  changed it to 10 minutes on battery, 5 minutes while charging — please confirm those values.**
- **The trade-off to weigh:** longer = fewer interruptions, but a longer window in which someone else
  could record data under the previous clinician's name.
- Note: changing this later needs a new app build and reinstall on each tablet, so it's worth confirming now.

## A11. Tablet encryption and screen-lock PIN ⚖️📋

- **Need:** confirmation that every pilot tablet will have **device encryption switched on** and a
  **mandatory screen-lock PIN** — and whether that PIN is shared across tablets or per device.
- **Why it matters, stated plainly:** **the app does not encrypt its own local data.** Protection of the
  data held on a tablet rests entirely on Android's device encryption plus the lock screen. Mitigating
  factor: the tablet only holds a working copy — the server holds the record.
- **If MSF data protection requires encryption *inside the app*, please say so now** — that is a
  software change, not a setting, and it would need to be scoped.
- If your tablet image already enforces encryption and a PIN (B5 q7), this item is closed.

## B3. How many tablets, and the device policy 📋

How many CrossCall T4/T5 tablets; who is allowed to install apps on them; whether tablets ever leave the
site; and the screen-lock policy (shared PIN or per device — relates to A11).

## C2. What happens to the data at the end of the pilot ⚖️

- Is the data retained on the box, exported to MSF, or wiped? Who owns it?
- **Specifically: may a backup copy leave the site?** We need this to design the backup properly.
- **Why we're asking early:** the server will be the **only** copy of the pilot's patient data, on one
  machine, with no Internet. We are building scheduled backups now, and whether a copy may go off-site
  changes the design.

---

## Things worth knowing before you answer

These shape which answers are practical, so they're better said once, up front.

1. **Renaming things is cheap. Restructuring is not.** Changing a zone's *name* syncs cleanly to the
   tablets at any time. Changing the *structure* of the zone tree after tablets have recorded data can
   orphan already-admitted patients. This is why we ask for A1–A3 before go-live.
2. **There is no way to order zones except by name.** The system has no sort-order setting. We achieve
   the order in A3 with hidden marks in the names — which works, and is invisible to clinicians, but
   means the order is fixed at configuration time.
3. **The server must share a subnet with the tablets.** An address outside the tablets' own subnet is
   unreachable however free it is (see B6). A fixed, reserved address in your IP space is a hard
   requirement of using your Wi-Fi. If it can't be arranged, we bring our own router.
4. **This is a 2016 Android app on an end-of-life server platform.** Configuration-shaped requests —
   names, accounts, clinical content, language, timezone — are cheap and expected. **Behaviour**
   changes — different sorting, input validation, new screens — mean modifying an unmaintained codebase
   and are outside pilot scope unless specifically agreed and funded. If something on this list looks
   like it needs a behaviour change, flag it and we'll cost it rather than quietly absorb it.
5. **Nothing here blocks us.** The package works on the defaults above. Each answer swaps out one
   default, and most of them are a single small configuration change.

---

## Summary — please fill in what you can

| # | Item | Who | Our default today | Your answer |
|---|------|-----|-------------------|-------------|
| **B5** | **Tablet image: what does it permit?** ⭐ | 🖥️📋 | assumes browser install is allowed | |
| **B5⭐** | **One tablet with your image, before staging** | 📋 | — | |
| **B6/B2** | Subnet, gateway, DHCP pool, **one reserved server IP**; client isolation checked? | 🖥️ | our own network `192.168.8.10` | |
| **B1** | Server address + short site name | 🖥️📋 | `192.168.8.10`, `pilot` | |
| **D1** | **Server machine — repurpose one, or buy?** (see spec doc) | 📋🖥️ | we recommend a refurbished business **laptop**; Intel/AMD only | |
| **C1** | Data-protection sign-off (remote support + export) | ⚖️ | remote support **off** | |
| **A1** | Facility name | 🩺 | `Facility` | |
| **A2/A3** | Zones, order, **default admission zone** — confirm our proposal | 🩺 | Triage · Suspect · Probable · Confirmed · Discharged; new patients → **Triage** | |
| **A4** | Clinician list + shared or per-person; keep `Guest`? | 🩺 | one generic account + `Guest` | |
| **A5** | Server credentials + who may know them | ⚖️🖥️ | a **published** default — must be changed | |
| **A6** | Interface language — French? | 🩺 | English | |
| **A7** | Clinical forms/questions — confirm or replace | 🩺 | historical Ebola content | |
| **A8** | Patient ID format | 🩺 | no format enforced | |
| **A9** | Timezone; **must printed records show local time?** | 🩺⚖️ | UTC internally; tablet shows local | |
| **A10** | Idle logout — confirm 10 min / 5 min charging | 🩺 | 10 min / 5 min | |
| **A11** | Device encryption + screen-lock PIN enforced? | ⚖️📋 | staging checklist step | |
| **B3** | Tablet count + device policy | 📋 | — | |
| **C2** | End-of-pilot data handling; **may a backup leave site?** | ⚖️ | nothing leaves the box | |

**If you answer only three things, make them B5, B6 and C1** — those are the ones that can change what
we build rather than just what we configure. **Add D1 if any purchasing is involved**, since that carries
a delivery lead time on top of the decision.

---

**Accompanying document:** `FIELD-PILOT-SERVER-SPEC.md` — the server hardware specification referenced
by **D1**, written to be forwarded to whoever holds MSF's hardware.
