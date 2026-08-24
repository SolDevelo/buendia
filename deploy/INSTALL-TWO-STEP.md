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
- The **USB stick** with the `Buendia` folder on it.
- The **Buendia router** (GL.iNet Flint 2), its power supply, and one Ethernet cable.
- Internet for step 1 — office Wi-Fi, a phone hotspot, or a cable. Anything will do.
- The router's admin password, which you set yourself in step 3 below.

---

## Step 1 — with internet  (~15 minutes, mostly downloading)

1. Connect the laptop to the internet. Check that a browser can load a web page.

2. Plug in the USB stick, open a terminal, and go to the `Buendia` folder on it:

       cd /media/$USER/*/Buendia

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

7. Check the connection, and let the script record which network port you used:

       cd /opt/buendia
       sudo ./tools/buendia-netcheck.sh --write

   **Check:** it ends with `READY`. It also prints the router's address — normally
   `http://192.168.8.1`. Write that down; the next steps use it.

   *If it does not say READY* it explains what is wrong. The two usual causes:
   - **an address starting `169.254`, or "no DHCP lease"** — either the cable is in the WAN port,
     or this laptop's IPv4 is not set to Automatic. To fix the second: Settings → Network → the
     wired connection → IPv4 → **Automatic (DHCP)**. The script tells you which of the two it is.
   - **`NO CARRIER`** — the cable is not pushed in, or that port is faulty. Try another port and
     another cable.

8. **Set up the router**, first time only. Open the router's address from step 7 in a browser and
   complete its setup wizard:
   - set an **admin password** and keep it safe — you need it in step 9 and nobody can recover it;
   - set the Wi-Fi name and password to **exactly** the values on the sheet supplied with this
     kit. Tablets are configured for that name, so a different one leaves them unable to connect.

9. Give the laptop permission to configure the router, then configure it:

       ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519    # skip if you already have a key
       ssh-copy-id root@192.168.8.1                        # asks for the admin password from step 8
       sudo ./network/configure-router.sh

   This applies the whole Buendia network configuration — Wi-Fi, addresses, and the time service
   the tablet clocks depend on.

   **Check:** it ends with either a list of applied changes or `Already correct — nothing to
   commit`. Both are success.

10. Restart the router and confirm it came back correctly. Wait one minute after the restart:

        sudo ./network/verify-router.sh

    **Check:** the last line says **`GO`**. If it says `NO-GO`, wait another minute and run it
    once more — some services are still starting for a short while after a restart. If it still
    says NO-GO, send the output.

11. Save a copy of the router's configuration onto the USB stick, in case the router ever has to
    be replaced:

        sudo ./network/backup-router.sh

12. Finish installing the server:

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

- Leave the server **switched on, plugged in, and with the lid open**. The lid is deliberately
  set not to suspend the machine, and an open lid runs cooler. Rebooting is safe: everything
  starts again by itself, and the router is back about a minute after power returns.

## Starting over

Every command above is safe to run again. Re-running changes nothing that is already correct.
