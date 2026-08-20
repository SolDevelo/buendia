# Router configuration (WS-8)

The field pilot ships **its own network** — see `docs/FIELD-PILOT-NETWORK-SPEC.md` (item **D2**).
This directory is that network's software: the head router's configuration as code, plus the tools to
verify and export it.

One flat network, `192.168.8.0/24`: router `.1`, server cabled at `.10`, tablets on DHCP, **one SSID
on every access point**. The same addresses at SolDevelo, at MSF Switzerland and at the site, which is
what makes the address baked into the tablet APK correct on arrival.

| File | What it is |
|---|---|
| `configure-router.sh` | **The source of truth.** Idempotent `uci` configuration over SSH |
| `verify-router.sh` | Go/no-go. Asserts the **running state**, not the configuration file |
| `backup-router.sh` | Exports the restorable archive that travels beside the script |

## The configuration travels twice, and that is deliberate

A router backup is tied to the model it came from — it carries that device's radio identity and
Ethernet topology, so restoring it onto a different model can leave the unit with no working LAN.
That makes it an excellent *fast path* and a poor *only* path.

> **Runbook rule: restore the backup; if the router is not the same model, run the script instead.**

The script is also the reviewable, diff-able, version-controlled form — which a binary archive is not.

## Prerequisites

1. **Run the first-boot wizard.** SSH is **closed** on a factory-fresh unit; the wizard's admin
   password is also the root password. Open `http://192.168.8.1`, set the password, decline any
   firmware upgrade. This step cannot be scripted away and MSF will hit it too, so it belongs in the
   staging guide rather than being treated as an oversight.
2. **Install your public key**, or every later run becomes an interactive password prompt and the
   idempotency test stops being a scripted assertion:
   ```sh
   ssh root@192.168.8.1 'mkdir -p /etc/dropbear && cat >> /etc/dropbear/authorized_keys' < ~/.ssh/id_ed25519.pub
   ```
3. Set `SITE_WIFI_SSID` and `SITE_WIFI_PASSWORD` in `deploy/.env` (**quoted**), or pass them in the
   environment for a one-off run.

## Use

```sh
./configure-router.sh --dry-run     # print every uci command, change nothing
./configure-router.sh               # apply; a second run is a no-op
./configure-router.sh --server-mac aa:bb:cc:dd:ee:ff   # ...also pin the server's lease
# reboot the router, THEN:
./verify-router.sh                  # router-only (bench)
./verify-router.sh --server 192.168.8.10
./backup-router.sh
```

Settings come from `deploy/.env`; an exported variable overrides the file, matching `build-apk.sh`.
Relevant keys: `SITE_WIFI_SSID`, `SITE_WIFI_PASSWORD`, `STATIC_IP`, `ROUTER_IP`, `ROUTER_COUNTRY`,
`ROUTER_CHANNEL_24`, `ROUTER_CHANNEL_5`, `ROUTER_HTMODE_24`, `ROUTER_HTMODE_5`, `ROUTER_TIMEZONE`.

## Why the script is written the way it is

- **Radios are selected by band, never by name.** Verified on hardware: this Flint 2 calls them
  `mt798611` and `mt798612`, not `radio0`/`radio1`. Anything hardcoding radio names breaks on its
  first Wi-Fi line — and would also break on the Beryl AX the kit carries as a spare.
- **Only `network.lan.ipaddr` is touched.** The vendor's DSA bridge (`br-lan` over `lan1`–`lan5`) is
  left alone; rewriting it is how a unit ends up with no working LAN.
- **List options compare before rewriting.** `uci add_list` appends a duplicate on every run, so
  lists are compared sorted and only rewritten when they differ. Without this, "idempotent" would be
  a claim rather than a property.
- **Channels are pinned to non-DFS** (2.4 GHz 6, 5 GHz 36). On `auto`, a 5 GHz radio re-runs
  channel-availability checking at every cold boot and can vacate on a radar event — which presents
  on site as "the Wi-Fi disappeared", unattended, with nobody to notice.
- **WPA2-PSK/CCMP, not WPA3 mixed mode.** `sae-mixed` breaks association on a non-trivial set of
  older Android builds, and the threat model for an isolated clinic LAN whose passphrase is laminated
  on a ward wall does not justify the risk.
- **The router is an NTP *client* of the server and never serves time.** This unit has **no RTC**
  (verified: no `/dev/rtc*`, `hwclock` fails), so it boots with a stale clock after every power cut.
  If it ever served time it would hand that wrong clock to anything that asked.

## The clock intercept, and how it really fails

Android ignores DHCP option 42 but does resolve a hardcoded NTP hostname, so the router maps those
names to the server. This matters clinically: **the observation timestamp comes from the tablet**, so
a drifting tablet clock writes wrong data, not a cosmetic error.

What actually breaks it, in order of likelihood:

1. **The vendor DNS layer.** GL.iNet ships `gl-dns`, `stubby` and **AdGuard Home**. AdGuard is the
   dangerous one: it takes `:53` and moves dnsmasq to `5353`, bypassing every `address=` line while
   the configuration page still looks correct.
2. **Encrypted DNS (DoH/DoT).** Queries leave for an upstream resolver and the local mapping is never
   consulted. ⚠️ `stubby` on this firmware is configured with **`trigger='wan'`** — it can only start
   once an uplink exists, so *any test run without a WAN cable is blind to it*. Assert the DNS state
   **with the uplink attached**.
3. **Private DNS on the tablet.** A *global* Android setting, not per-network. If it is set to a
   hostname, resolution leaves over DoT and the intercept dies — **while Buendia keeps working
   perfectly**, because the app addresses the server by IP. Set it to Off per tablet.

**DNS rebinding protection is *not* the trap** the network spec implies. It filters private addresses
in answers received from *upstream*; locally configured `address=` records are not filtered by it.
This firmware ships it off anyway. The script asserts it because it is free, not because it is load-bearing.

**Verify from the tablet's side, never from the router's configuration page** — that page looked
correct throughout GL.iNet's forced-Cloudflare DoH bug.

## Frozen firmware

Configured and validated against **GL.iNet 4.8.3** (OpenWrt 21.02-SNAPSHOT, `mediatek/mt7986`) on
`GL.iNet GL-MT6000`. A script proven on one firmware line is not proven on the other — GL.iNet's
stable 4.8.x and "op24" lines have **no update path in either direction**. Record the version before a
coverage walk, not after: recent firmware reduced Wi-Fi transmit power, so a coverage result is only
valid for the image it was measured on.

## Handling

- ⚠️ **The backup archive is a credential.** It contains `/etc/config/wireless` with the Wi-Fi
  passphrase in cleartext and `/etc/shadow` with the root hash. It is git-ignored here; keep it out of
  the deployment bundle. Restore it only onto the **same firmware version**.
- **Never plug USB storage into the router.** Documented heating severe enough to take the 2.4 GHz
  radio down, plus USB 3 interference with 2.4 GHz. Nothing in the pilot needs it.
- **Tape over the reset button** and label it, before the kit ships.
