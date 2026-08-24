# Buendia server — installation

For the person installing the server. No Buendia knowledge assumed. Every step says how to tell
whether it worked; if a step fails its check, stop there and report it rather than continuing.

**Why two steps.** The server needs the internet **once**, to download Docker and the Buendia
software. It then runs on its own network, which has no internet. Those are two different
connections, so the install is split: step 1 uses whatever internet you have, step 2 uses the
Buendia router. Nothing in step 1 changes the machine's networking, so it cannot break the
connection it is using.

## What you need

- The laptop that will be the server, with **Ubuntu freshly installed** and its **Wi-Fi off**
  for step 2.
- This USB stick.
- The **Buendia router** (GL.iNet Flint 2) and an Ethernet cable.
- An internet connection for step 1 (office Wi-Fi, a hotspot, or a cable — anything).

---

## Step 1 — with internet (about 15 minutes, mostly downloading)

1. Connect the laptop to the internet however is convenient. Confirm a browser can load a page.
2. Plug in the USB stick and open a terminal in its `Buendia` folder.
3. Copy the files onto the laptop and download everything it needs — one command:

       sudo ./bootstrap.sh --prepare

   This copies the software to `/opt/buendia` and then downloads roughly 800 MB (Docker and
   the Buendia containers). It takes about 15 minutes on a normal connection.

   **Check:** the last line says
   `PREPARE OK — not yet a working server`. That wording is expected: nothing is running yet.

   *If it fails while downloading:* the internet connection is restricted (a login page, or a
   filter blocking Docker). Try a different connection — a phone hotspot is usually enough — and
   run the same command again. It is safe to repeat.

**Do not continue to step 2 until step 1 has reported PREPARE OK.**

---

## Step 2 — on the Buendia router, no internet (about 5 minutes)

5. **Disconnect the laptop from the internet.** Turn Wi-Fi **off** — not just disconnected.
6. Plug the Ethernet cable from the laptop into one of the router's **LAN** ports. Not the WAN
   port: WAN is for an incoming internet cable and gives out no addresses.
7. Check the connection and let the script record which network port you used. Run it from
   `/opt/buendia` — it writes the setting into the configuration file in the folder you are in:

       cd /opt/buendia
       sudo ./tools/buendia-netcheck.sh --write

   **Check:** it ends with `READY`. It also prints the router's address, so you can open the
   router's admin page in a browser if you ever need to.

   *If it does not say READY*, it explains what is wrong. The two common causes:
   - **`no DHCP lease` / an address starting `169.254`** — either the cable is in the WAN port,
     or this laptop's IPv4 is not set to Automatic. In Settings → Network → the wired connection
     → IPv4, choose **Automatic (DHCP)**. The script says which of the two it is.
   - **`NO CARRIER`** — the cable is not seated, or that port is dead. Try another port and cable.

8. Finish the installation:

       sudo ./setup.sh --finish

   This sets the server's fixed address, starts Buendia and checks it. It needs no internet.

   **Check:** the last line says **`GO`**. If it says `NO-GO`, the checks above it show which one
   failed — send that output; do not put the server into use.

---

## When it is finished

- Buendia is at **http://192.168.8.10:9000/openmrs**
- Tablets install the app by scanning the QR code on the printed card, or from
  **http://192.168.8.10:9001**
- To check the server later, at any time:

      sudo /opt/buendia/tools/buendia-verify.sh --quick

  `GO` means it is working. This is the single check to run if anyone reports a problem.

- The server is meant to stay **on, plugged in, and with the lid open** (the lid is set not to
  suspend it; open lids run cooler). Rebooting is safe — everything restarts by itself.

## If you need to start over

Both steps are safe to repeat. Re-running them changes nothing that is already correct.
