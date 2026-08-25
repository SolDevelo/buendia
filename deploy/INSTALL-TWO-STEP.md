# Buendia server — installation

Two commands, in two steps. Everything is done on the **server laptop** — you need no second
computer. Run everything with `sudo`.

**Why two steps.** The server needs the internet **once**, to download Docker and the Buendia
software. Afterwards it runs on the Buendia router's own network, which has no internet. So:
step 1 uses whatever internet you have, step 2 uses the router.

## What you need

- The **server laptop**, with Ubuntu freshly installed.
- A **USB stick** with the `Buendia` folder copied onto it (unzip the archive we sent straight
  onto the stick; keep the folder's name and contents).
- The **Buendia router** and one Ethernet cable.
- Internet for step 1 — office Wi-Fi, a phone hotspot, a cable. Anything.

---

## Step 1 — with internet  (~15 minutes)

1. Connect the laptop to the internet. Check a browser can load a page.

2. Open a terminal **inside** the `Buendia` folder on the stick — in the file manager, right-click
   in the folder and choose "Open in Terminal".

3. Run:

       sudo ./prepare.sh

   It asks a few questions (press Enter to accept what is shown), then downloads about 800 MB.

   **Check:** it ends by telling you to do step 2. Nothing is running yet and the laptop's
   network is unchanged — that is correct.

   *If it fails while downloading,* the connection is restricted. Try another one — a phone
   hotspot is usually enough — and run it again. Repeating is safe.

---

## Step 2 — on the Buendia router, no internet  (~10 minutes)

4. **Turn the laptop's Wi-Fi off** — off, not just disconnected.

5. Switch the router on and wait two minutes for it to start.

6. Plug the Ethernet cable from the laptop into one of the router's **LAN** ports.
   **Not the WAN port** — that one is for an incoming internet cable and gives out no addresses.

7. **The router's own setup, first time only.** Open **http://192.168.8.1** in a browser and
   complete the router's wizard. Set an **admin password** and keep it — you are asked for it
   once in the next step, and nobody can recover it. Ignore its Wi-Fi settings; Buendia sets
   those itself.

8. Run:

       sudo /opt/buendia/setup.sh

   This checks the cable, configures the router, gives the server its fixed address, starts
   Buendia and tests it. It asks for the router's admin password once, near the beginning.

   **Check:** the last thing it prints is **`GO`**, followed by two QR codes.

   *If it says `NO-GO`*, the checks just above it name what failed. Send that text; do not put
   the server into use.

---

## Setting up a tablet

At the end of step 2 the screen shows two QR codes. On the tablet:

1. Scan the **first** code — it joins the Buendia Wi-Fi, so no password is typed.
2. Scan the **second** code — it downloads the Buendia app. Allow the install when Android asks.
3. Open the app. It is already pointed at the server. Log in as **buendia**.

If the tablet's camera does not offer to install, open **http://192.168.8.10:9001** in the
tablet's browser instead.

## Day-to-day

- Buendia in a browser **on the server itself**: use the shortcut
  **"Buendia — patient records"** in the `Buendia-tablet-setup` folder on the desktop, or type
  **http://buendia.lan:9000/openmrs**
- From any other machine on the Buendia Wi-Fi: **http://192.168.8.10:9000/openmrs**
  The `/openmrs` on the end is required — without it the page is blank.
- To check the server whenever anyone reports a problem:

      sudo /opt/buendia/tools/buendia-verify.sh --quick

  `GO` means it is working.
- Leave the server **on, plugged in, and with the lid open**. The lid is set not to suspend it,
  and an open lid runs cooler. Rebooting is safe: everything comes back by itself, and the
  router is back about a minute after power returns.
- **Automatic updates are switched off deliberately.** A clinic server must not restart its own
  software overnight with nobody there. Updates are something we do with you.

## Known quirk: no mouse pointer after closing and opening the lid

On some laptops the touchpad stops responding after the lid is closed and opened again: the
screen and everything on it are fine, but there is no pointer, and the touchpad's own on/off key
does nothing. Plugging in a USB mouse restores it immediately.

The cause is that this server is deliberately configured **not to suspend when the lid closes**,
so the machine never goes through the sleep-and-wake cycle that would normally re-initialise the
touchpad. Reloading its driver brings it back without a reboot:

    sudo modprobe -r psmouse && sudo modprobe psmouse          # most laptops
    sudo modprobe -r i2c_hid_acpi && sudo modprobe i2c_hid_acpi  # if that one is "not found"

The simplest avoidance is the one the server wants anyway: **leave the lid open.** It is how the
machine is meant to run — it stays cooler, and the screen is what a tablet scans the QR codes
from.

## Starting again

Every command above is safe to re-run; it changes nothing that is already correct.

To wipe this machine and install from scratch — **this deletes all patient data**:

    sudo /opt/buendia/tools/buendia-uninstall.sh --dry-run   # see what it would do
    sudo /opt/buendia/tools/buendia-uninstall.sh             # then do it

Then start again from step 1.
