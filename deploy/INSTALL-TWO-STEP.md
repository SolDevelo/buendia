# Buendia server — installation

For the person installing the server. No previous knowledge of Buendia assumed. Everything is
done **on the server laptop itself** — you need no second computer.

Every step says how to tell whether it worked. If a step fails its check, stop and report it
with the text on screen; do not continue.

**Why two steps.** The server needs the internet **once**, to download Docker and the Buendia
software. After that it runs on its own private network, which has no internet. Those are two
different connections, so the install is split in two. Nothing in step 1 changes the laptop's
network settings, so it cannot break the connection it is using.

## What you need

- The **server laptop**, with Ubuntu freshly installed, and you able to run `sudo`.
- A **USB stick** with the `Buendia` folder copied onto it (unzip the archive we sent you
  straight onto the stick; the folder must keep its name and contents).
- The **Buendia router** (GL.iNet Flint 2), its power supply, and one Ethernet cable.
- Internet for step 1 — office Wi-Fi, a phone hotspot, or a cable. Anything will do.
- The router's admin password, which you set yourself in step 3 below.

---

## Step 1 — with internet  (~15 minutes, mostly downloading)

1. Connect the laptop to the internet. Check that a browser can load a web page.

2. Plug in the USB stick and open a terminal **inside** the `Buendia` folder on it — in the file
   manager, right-click in the folder and choose "Open in Terminal". If you prefer to type it,
   the stick is under one of these two, depending on the Ubuntu version:

       cd /run/media/$USER/*/Buendia     # newer Ubuntu
       cd /media/$USER/*/Buendia         # older Ubuntu

   Check you are in the right place: `ls` should list `bootstrap.sh` and `INSTALL.md`.

3. Install, and download everything the server needs:

       sudo ./bootstrap.sh --prepare

   It copies the software to `/opt/buendia`, then downloads about 800 MB.

   **Check:** the last line reads `PREPARE OK — not yet a working server`. That wording is
   correct — nothing is running yet.

   *If it fails while downloading,* the internet connection is restricted (a login page, or a
   filter blocking the download). Try another connection — a phone hotspot is usually enough —
   and run the same command again. Repeating it is safe.

**Do not go on to step 2 until you have seen `PREPARE OK`.**

---

## Step 2 — on the Buendia router, no internet  (~10 minutes)

4. **Turn the laptop's Wi-Fi off** — off, not just disconnected.

5. Power on the router. Wait two minutes for it to finish starting.

6. Plug the Ethernet cable from the laptop into one of the router's **LAN** ports.
   **Not the WAN port** — WAN is for an incoming internet cable and hands out no addresses.

7. Check the connection. This also repairs the most common problem by itself and records which
   network port you used, so run it with `sudo`:

       cd /opt/buendia
       sudo ./tools/buendia-netcheck.sh --write

   **Check:** it ends with `READY`. It also prints the router's address — normally
   `http://192.168.8.1`. Write that down; the next steps use it.

   A fresh Ubuntu install often has the wired connection set to "Link-Local Only", which means it
   never asks for an address. **The script detects that and fixes it for you**, printing
   `repaired:` and the address it then received.

   *If it does not say READY* it explains what is wrong. The usual causes:
   - **`NO CARRIER`** — the cable is not pushed in, or that port is faulty. Try another port and
     another cable.
   - **still no address after the repair** — the cable is almost certainly in the **WAN** port. A
     router hands out addresses on its LAN ports only. Move it and run the same command again.

8. **Set up the router**, first time only. Open the router's address from step 7 in a browser and
   complete its setup wizard:
   - set an **admin password** and keep it safe — you need it in step 9 and nobody can recover it;
   - set the Wi-Fi name and password to **exactly** the values on the sheet supplied with this
     kit. Tablets are configured for that name, so a different one leaves them unable to connect.

9. Give this laptop permission to configure the router. One command; it asks for the router's
   admin password from step 8. **Do not use `sudo` for this or for step 10** — these commands
   need no administrator rights, and under `sudo` they look for the key in the wrong place and
   report that they cannot reach the router:

       ./network/router-access.sh

   **Check:** it ends with `key installed and verified` (or `already trusted`).

10. Configure the router:

        ./network/configure-router.sh

    This applies the whole Buendia network configuration — Wi-Fi name and password, addresses,
    and the time service the tablet clocks depend on. It sets the Wi-Fi itself, so it does not
    matter what the wizard in step 8 called it.

   **Check:** it ends with either a list of applied changes or `Already correct — nothing to
   commit`. Both are success.

11. Restart the router and confirm it came back correctly. Wait one minute after the restart:

        ./network/verify-router.sh

    **Check:** the last line says **`GO`**. If it says `NO-GO`, wait another minute and run it
    once more — some services are still starting for a short while after a restart. If it still
    says NO-GO, send the output.

12. Save a copy of the router's configuration, in case the router ever has to be replaced:

        ./network/backup-router.sh

13. Finish installing the server:

        sudo ./setup.sh --finish

    This gives the laptop its fixed address, starts Buendia, and checks it. No internet needed.

    **Check:** the last line says **`GO`**. If it says `NO-GO`, the checks above it show which
    one failed — send that output, and do not put the server into use.

---

## When it is finished

- Buendia is at **http://192.168.8.10:9000/openmrs**
- Tablets install the app by scanning the QR code on the printed card, or by opening
  **http://192.168.8.10:9001** in the tablet's browser.
- To check the server at any later time — this is the single check to run if anyone reports a
  problem:

      sudo /opt/buendia/tools/buendia-verify.sh --quick

  `GO` means it is working.

- **Automatic updates are switched off deliberately.** A server in a clinic must not change
  itself: an unattended upgrade can restart the software or the machine with nobody there.
  Updates are something we do with you, not something the box does overnight.

- Leave the server **switched on, plugged in, and with the lid open**. The lid is deliberately
  set not to suspend the machine, and an open lid runs cooler. Rebooting is safe: everything
  starts again by itself, and the router is back about a minute after power returns.

## Starting over

Every command above is safe to run again. Re-running changes nothing that is already correct.
