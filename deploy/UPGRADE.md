# Buendia — installing a new version over a working server

This is for a laptop that **already runs Buendia and holds real patient data**. For a machine with
nothing on it yet, use `INSTALL.md` instead.

Same shape as the first installation: **two commands, on the server laptop, everything with `sudo`.**
The difference is that this time there is data on the machine, so there is a backup step first and a
few answers that must not be changed.

**Patient data is not touched by this procedure.** The database is kept in place and the new software
is started against it. The one step that *would* destroy it is named at the bottom so it can be
avoided.

## What is in this version

- **A new version of the server software** (the Buendia application and the database container).
- **A new version of the tablet app**, which must be installed onto each tablet by hand — see
  *Tablets* below. Tablets do **not** update themselves.
- **Remote support stays as it is today: TeamViewer**, installed and run by MSF. Nothing in this
  upgrade changes it, switches it on, or replaces it. There is one thing to know about it after the
  upgrade — see *Reaching the server over TeamViewer* below.
- **The server is no longer offered to other networks.** Previously, whenever the laptop was
  connected to an office or site Wi-Fi, other people on that same Wi-Fi could open Buendia and
  download the tablet app from it. After this upgrade the server answers **only on the Buendia
  network**, where the tablets are. Nothing you do changes; this simply closes a door that should
  not have been open.

---

## Before you start — take a backup (~2 minutes)

Open a terminal inside the `Buendia` folder on the USB stick and run:

    sudo ./backup.sh

It writes one file into your home folder and changes nothing else. It then reads that file back
and checks it: that every table is there, that the patients and observations are really in it, and
that it was not cut short. It prints how many patients, visits and observations it saved, so you
can see the numbers are the ones you expect.

**Check:** the last line says **`Backup taken and verified`**, and names the file.

**If it says `THIS BACKUP CANNOT BE TRUSTED`, stop and send us everything it printed.** Do not
start the upgrade — a backup that cannot be read back is not a backup.

Copy the file onto a USB stick as well; a backup on the same laptop does not protect against the
laptop. To check a backup you took earlier, run `sudo ./backup.sh --verify-only <the file>`.

---

## Step 1 — with Internet  (~15 minutes)

1. Connect the laptop to the Internet — office Wi-Fi, a phone hotspot, a cable. Anything.

2. Open a terminal inside the new `Buendia` folder on the USB stick and run:

       sudo ./prepare.sh

3. **It asks the same questions as the first time, and the answers shown are already the ones your
   site uses. Press Enter to accept every one of them.**

   ⚠️ **The "Password for the `buendia` login" must stay exactly as it is.** The tablets carry that
   password inside the app. If it is changed here, every tablet is locked out until it is re-installed
   again. Press Enter; do not type a new one.

   **Check:** it finishes by telling you to do step 2. Nothing has started yet and the network is
   unchanged — that is correct. Buendia is still running the old version at this point, and patients
   can still be seen.

## Step 2 — on the Buendia router  (~10 minutes)

4. Put the laptop back on the Buendia router exactly as it normally runs: Ethernet cable into a **LAN**
   port, laptop Wi-Fi off.

5. Run:

       sudo /opt/buendia/setup.sh

   It stops the old version, starts the new one against the existing database, and tests the result.
   Expect a few minutes' interruption — do not use the tablets during it.

   **Check:** the last thing it prints is **`GO`**.

   *If it says `NO-GO`*, the checks above it name what failed. Send us that text. The old data is
   still there; nothing has been deleted.

6. Confirm the patients are still there — open **http://buendia.lan:9000/openmrs** on the server
   laptop and look at the patient list, or run:

       sudo /opt/buendia/tools/buendia-verify.sh

---

## Tablets

**Every tablet needs the new app installed by hand.** The app cannot update itself in this version.
Until a tablet is updated it keeps working against the new server with the old app — so the tablets
can be done one at a time, at a convenient moment, rather than all at once.

On each tablet:

1. Join the Buendia Wi-Fi if it is not already on it.
2. Open **http://192.168.8.10:9001** in the tablet's browser, or scan the install QR code from the
   in-zone card, and install the app when Android asks. It installs **over** the existing one:
   the tablet keeps its settings and nothing needs to be typed.
3. Open the app and log in as usual.
4. **Let it finish synchronising before judging anything.** The tablet keeps its own copy of the
   forms and charts, so a change made on the server appears only after a sync. If something looks
   old or missing, sync again before reporting it.

If Android refuses the install with a message about a different signature, stop — that means the app
did not come from this package. Send us the message.

---

## Reaching the server over TeamViewer

Nothing about TeamViewer itself changes, and this upgrade does not touch it. Two things are worth
knowing, because one of them will otherwise look like a broken server.

**On the server laptop, use this address for Buendia, not "localhost":**

```
http://buendia.lan:9000/openmrs
```

The laptop knows that name for itself, so there is nothing to type from memory and nothing to look
up; there is also a **"Buendia — patient records"** shortcut in the `Buendia-tablet-setup` folder on
the desktop that opens the same page. `http://192.168.8.10:9000/openmrs` is the same server by its
address, and is what a tablet or any other machine on the Buendia Wi-Fi uses.

If somebody types `http://localhost:9000` instead, the page will simply **hang and never load** — it
does not say "error", it just spins. That is expected after this upgrade and does **not** mean the
server is broken. The server is now reachable only on the Buendia network address, which is the
point of the change described above.

**Somebody on site opens TeamViewer when support is needed.** That is the arrangement we assume,
and it means there is **nothing to set up and nothing to leave running**. TeamViewer can only be
reached while the machine is on, somebody is logged in, and TeamViewer itself is open — so when you
want us to look at the server, log in and start it, and close it afterwards if you prefer.

Rebooting is safe. Everything on the server comes back by itself, including the patient records
system and the tablets' connection — nobody needs to do anything for that. The only thing a reboot
does affect is remote support: until someone logs in and opens TeamViewer again, we cannot see the
machine. The laptop is deliberately set up never to sleep and to ignore the lid closing, so leaving
it logged in with the lid open is the easiest arrangement if you expect to need support that day.

---

## What is kept, and what is not

**Kept — you do not need to re-enter any of it:**

- All patient data: patients, admissions, observations, treatments, users.
- The **`buendia` login and its password** (provided step 1's password answer was left alone).
- The **active clinical profile** — the forms and charts in use stay exactly as they are.
- Profile files previously uploaded through the server's Profile Manager page.
- The zones/wards list, the clinician accounts, and the facility name.
- The router's configuration, the Wi-Fi name and password, and the server's address `192.168.8.10`.

**Not changed by an upgrade, which is worth knowing:**

- **A new version's starting database content does not reach a server that already has data.** The
  new database container carries a fresh copy of the baseline (concepts, and the starter
  locations/accounts), but it is only ever used to build an *empty* server. On your machine it is
  ignored, and your data is used instead. That is what makes the upgrade safe — and it also means
  that **if something in the zone list, the clinician accounts or the clinical content has to
  change, that is a separate change we make with you**, not something an upgrade delivers by itself.
- The tablet app is not updated by the server (see *Tablets* above).

---

## If it goes wrong — going back

1. Tell us before doing anything else; in most cases the fix does not need a rollback.
2. If a rollback is needed, we send the previous version's folder, and it is installed exactly as
   above — the database is left alone, so the old software starts against the same data.
3. Restoring the backup file is only needed if the data itself is wrong, and we will do that with you
   on a call. It replaces everything recorded since the backup was taken.

Keep the backup file until the new version has been used normally for a few days.

---

## The one command that destroys everything

Anything containing **`down -v`**, and the `buendia-uninstall.sh` tool, **delete the database and all
patient data**. They exist for wiping a machine deliberately before a fresh install. There is no undo
and no confirmation prompt — the backup above is the only protection. Do not run either as a way of
"restarting" the server; to restart it, reboot the laptop, which is safe.

---

## Notes for SolDevelo (not for the site)

- **Build the pack with `tools/make-usb-pack.sh --keep-passwords <the site's current buendia.env>`.**
  The APK carries the server password as a build-time string resource and `setup.sh` rotates the DB
  account to whatever `.env` says, so a pack built without the site's existing password ships an APK
  and a server that disagree with the tablets already in the field — every tablet locks out.
  The same applies to `STATIC_IP`: `make-usb-pack.sh` refuses a payload whose baked address differs,
  and that check is the thing standing between us and a silent brick.
- **Verified 2026-09-22, on the two real DB image versions** (`5.6-364b9524` → `5.6-68e59eeb`, same
  named volume): a marker table written after the first boot survived the image swap intact, and the
  new image's 83 MB baked seed sat unexecuted in `/docker-entrypoint-initdb.d/`. The mysql 5.6
  entrypoint gates `docker_process_init_files` on `[ -d "$DATADIR/mysql" ]`, so **both** the baked
  `10-buendia-base.sql` **and** the bind-mounted `20-buendia-site.sql` run on first boot only.
  Consequence: site-seed edits (locations, accounts) never reach an existing deployment through an
  upgrade — they need SQL applied to the live DB, which is what the `pilot-site-config` skill does.
- Schema changes that come from the module *do* apply: `auto_update_database=true` in
  `runtime.properties.tpl`, so OpenMRS runs its Liquibase changesets against the existing database at
  startup. That is also why step 2 can take longer than a normal restart on a version that adds
  tables.
- `openmrs_profiles` and `db_data` are named volumes and survive `up -d` with changed images; only
  `down -v` or `buendia-uninstall.sh` remove them.
- Remote support is **built but not yet proven end-to-end** — the tunnel has never been exercised from
  a genuinely separate network. Do not describe it to MSF as working until
  `docs/FIELD-PILOT-WS7-REMOTE-ACCESS-TEST-PLAN.md` has been executed and passes.
