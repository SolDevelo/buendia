# Field Pilot — WS-8 Router Configuration & Full Installation Rehearsal

**Date:** 2026-08-20 · **Owner:** SolDevelo · **Status:** ⬜ not started — this is the plan, written
before execution. **Revision 2**, after two independent reviews (repo-consistency and
network-correctness) and the first hardware contact with the router. Findings that changed the plan
are folded in below; findings that turned out to be **defects in already-shipped artefacts** are
collected in §9, because they outlive this exercise.

**What this closes.** Two open items that have blocked nothing so far but gate staging:

- **WS-8 — router configuration as code** (`FIELD-PILOT-DEPLOYMENT-PLAN.md` §4/WS-8, spec
  `FIELD-PILOT-NETWORK-SPEC.md`). Never started; the router arrived (**Flint 2 / GL-MT6000**), so it
  is now buildable.
- **§8 item 5 — `CONFIGURE_NETWORK=true` on the `ethernets:` branch.** Generated netplan has **never
  been applied on hardware**; both real installs used `CONFIGURE_NETWORK=false` and took their
  address by other means.

**Why they belong in one exercise.** Both are the same missing fact: *the shipping addressing has
never existed.* Every install to date ran on the home LAN (`192.168.0.x`). This is the first run on
**`192.168.8.0/24`** — our router at `.1`, our server at `.10` — which is the addressing the tablet
APK bakes in and the address MSF's own install will produce. It also drafts WS-6's
`STAGING-SETUP-GUIDE` as a by-product, because the procedure is executed end to end for the first
time in the shape MSF will execute it.

---

## 0. Machines, equipment, and who does what

| Role | Machine | In this exercise |
|---|---|---|
| **Dev box** | this workstation (currently `192.168.0.150` on the home LAN) | Holds the repo. Builds image / seed / APK / payload / bundle, stages the USB. **Develops and runs `configure-router.sh`** over SSH to the router. Acts as the **independent verifier** — `buendia-verify.sh` run from a *different* machine than the one under test, which is how the two previous hardware validations were kept honest. |
| **Test laptop** | the spare Ubuntu 24 notebook (was `192.168.0.250`) | **The server under test.** Wiped to a fresh Ubuntu install, then provisioned only from the USB stick, exactly as MSF will. Becomes `192.168.8.10`. Nothing is built here and the repo never touches it. |
| **Tablet** | a personal Android tablet | Stands in for the CrossCall T4/T5. Proves the *mechanism*; proves nothing about MSF's device image — see §2. |
| **Router** | **Flint 2 (GL-MT6000)**, in hand | The head router. Factory-reset at the start of each phase that claims a cold start. |

**Physical setup, phases 1–2 (script development).** The Flint 2 must be **cabled to the dev box**:
WAN port → the home router (so the dev box keeps internet while working), one LAN port → the dev
box's Ethernet. The dev box then holds an address on `192.168.8.0/24` and can reach `192.168.8.1`.
If the dev box's Wi-Fi stays joined to the home network, check the route metrics — a stale default
route through the home Wi-Fi is a plausible ten-minute distraction.

**Physical setup, phase 3 (full rehearsal).** Flint 2 WAN → home router (internet **only** during
setup; unplugged at gate G6). Test laptop cabled to a LAN port. Dev box joined to **our SSID** so it
can verify across the network the way a tablet sees it. Tablet on the same SSID.

**Not present, and therefore not testable:** the Beryl AX coverage node, a 12 V power source for the
Flint 2, an elevated-temperature enclosure, MSF's tablet image, MSF's site.

### 0.1 Measured on first contact (2026-08-20, pre-wizard)

Recorded before the first-boot wizard, so it is the true factory baseline:

| Fact | Value | Consequence |
|---|---|---|
| Factory LAN | `192.168.8.1/24`, DHCP served | **Confirms the subnet choice**: the script's LAN step is a verified no-op, so contingency C-4 is downgraded |
| Open ports | 53, 80, 443 — **22 is CLOSED** | The first-boot wizard is a hard gate, not a formality. The script cannot start before it |
| Web layer | nginx/1.26.1 serving GL.iNet "Admin Panel" (gl-ui) | Vendor fork confirmed; the `glconfig` layer is real and must be discovered, not assumed |
| Router clock | 2025-10-16 — ~10 months stale, no uplink | **The router can never be a time source.** Reinforces the server-as-authority design, and see §3 step 8 |
| Pre-wizard DNS | every name resolves to `192.168.8.1` | See the trap below |
| WAN uplink | no route to the internet through the router | Must be fixed before gate G1; check the cable is in the 2.5 G **WAN** port |

> ⚠️ **Trap, hit immediately: cabling the dev box to a pre-wizard GL.iNet router kills the dev box's
> internet.** The router hijacks all DNS to its setup page, and NetworkManager accepts
> `DNS=192.168.8.1` plus a default route from its DHCP offer. Raw IP traffic keeps working while every
> name lookup returns the router — which presents exactly as "the internet is down". This recurs on
> every DHCP renewal, and Phase 2 power-cycles the router repeatedly. **Fix once, on the dev box:**
> `nmcli con mod "<wired connection>" ipv4.never-default yes ipv4.ignore-auto-dns yes ipv6.never-default yes ipv6.ignore-auto-dns yes`.
> Explicit queries (`nslookup … 192.168.8.1`) still work, which is all the testing needs.

### 0.2 Post-wizard discovery (2026-08-20) — the vendor layer, mapped

Firmware **4.8.3** / OpenWrt **21.02-SNAPSHOT**, `mediatek/mt7986`, aarch64, model `GL.iNet GL-MT6000`.
Full `uci show` baseline captured (1972 lines). The dev box's key is installed in
`/etc/dropbear/authorized_keys`, so everything from here is scripted.

| Finding | Value | What it changes |
|---|---|---|
| **Radio names** | **`mt798611` (2g), `mt798612` (5g)** — *not* `radio0`/`radio1` | **The portability trap, confirmed on hardware.** Selecting by `band` is mandatory, not defensive. Vindicates the discovery-based design |
| LAN topology | **DSA**: `br-lan` bridging `lan1`–`lan5`, no `swconfig` | Touch only `network.lan.ipaddr`; the vendor bridge stays untouched, as planned |
| `rebind_protection` | **already `'0'`** as shipped | The step is a **no-op**. Confirms §3 step 6's correction: this was never the trap |
| IPv6 on LAN | `dhcp.lan.ra='disabled'`, `dhcpv6='disabled'` already | One planned change **drops out** — the vendor already ships it off |
| DHCP pool | `.100` + 150 → `.100–.249` | Already excludes `.1` and `.10`; only needs asserting, not changing |
| Guest SSIDs | `guest2g`/`guest5g` **`disabled='1'`** | Assert, don't change |
| **Vendor DNS layer** | `gl-dns` (`mode='auto'`, `dot_provider='D'`, `override_vpn='1'`), plus **`adguardhome` (`enabled='0'`)** and **`stubby` (`trigger='wan'`)** | All three exist. **Only dnsmasq is bound to :53** right now, and neither AdGuard nor stubby is running |
| **`system.ntp`** | `enabled='1'`, **`enable_server='0'`**, servers = the OpenWrt pool | Already does not serve time ✓. Needs `server='192.168.8.10'` |
| **RTC** | **none** — no `/dev/rtc*`, `hwclock` fails | ✅ Answers an open question: the router boots with a wrong clock after every power cut. Harmless *only because* `enable_server='0'` — which must therefore be asserted, not assumed |
| Timezone / country | `Europe/Warsaw`; radios `country='DE'` | Both are wizard/locale artefacts and must be set deliberately |
| Channels | **both radios `channel='auto'`** | The DFS risk is live: pin non-DFS (2.4: 1/6/11; 5: 36–48) |
| Also present | a `tailscale` config package in the firmware | Noted for **WS-7**: the *router* could host the support tunnel instead of the server. Not pursued here |

> ⚠️ **The one that is still dangerous: `stubby.global.trigger='wan'`.** Encrypted DNS is not running
> now — but the trigger is the **WAN coming up**, and the rehearsal attaches an uplink at G1–G3 for the
> image pull. So a bench test with no WAN would pass while the real staging run could silently start
> resolving over DoT. **The DoH/DoT assertion must be made with the uplink attached**, which was not
> true of any test as previously written. Added as T4b.

**Net effect on Phase 1:** the delta is smaller than planned — unified SSID across both bands, country
and channels, the `address=` overrides, `system.ntp.server`, the vendor DNS layer, and the firewall
assertion. Four intended changes turn out to be already-correct defaults that need *asserting* instead.

---

---

## 1. Decisions to take before writing a line (~30 min)

Cheap now, expensive later — several are baked into artefacts that get printed or installed.

| # | Decision | Recommendation |
|---|---|---|
| **1.1** | **Firmware branch and exact version** | ✅ **Settled on hardware: 4.8.3 / OpenWrt 21.02-SNAPSHOT** (§0.2) — the stable line as shipped, and the version the network spec singles out as the one to respect (4.8.3 was itself a driver rollback undoing a 4.8.2 regression). The honest reason is *"it is what the unit ships with, and reflashing before a rehearsal adds a variable we do not need"* — **not** the DoH argument. ⚠️ `FIELD-PILOT-NETWORK-SPEC.md` records the opposite lean (op24 is published for both models, which is what keeps one script valid across head and spare) and notes the forced-Cloudflare bug was **fixed** by removing `stubby`. The two documents must be reconciled once the script exists; until then this plan's choice governs the rehearsal and the disagreement is recorded, not hidden. |
| **1.2** | **SSID, passphrase, and encryption mode** | Choose the shipping values now — they are printed on the in-zone card. Use **WPA2-PSK / CCMP, PMF optional, no 802.11r**: `sae-mixed` breaks association on a non-trivial set of older Android builds, and the threat model for an isolated clinic LAN whose passphrase is laminated on a ward wall does not justify it. Avoid `\ ; & $ ' " * ? # |` in the passphrase — the live trap is that `.env` is `source`d by bash (`setup.sh`), *not* netplan, which already emits single-quoted scalars correctly. |
| **1.3** | ✅ **Addressing — settled on hardware** | `192.168.8.1` / `.10`. Confirmed factory default (§0.1). |
| **1.4** | **Uplink during the rehearsal** | WAN cable attached for the image pull at G1–G3, unplugged from G6 onward. ⚠️ **No-uplink is the shipping state**, so Phase 2 runs with the WAN *unplugged* by default and "WAN attached" is the extra case, not the baseline. |
| **1.5** | **`GATEWAY_IP` / `DNS_SERVERS`** | Set both to `192.168.8.1` in the **USB `buendia.env`**. ⚠️ Left empty, `setup.sh` emits an isolated netplan with no route and no resolver and the run dies at the **`chrony` install** (`host_config` calls `config_network` at `setup.sh:165`, then `ensure_pkg chrony` at `:168` — the first `apt-get`), well before the image pull. Real defect, wrong step named in revision 1. ⚠️ A default route to an absent uplink is **not** free: it converts instant `ENETUNREACH` into multi-second timeouts, and `DNS_SERVERS=192.168.8.1` makes the server's resolution depend on the router being up — which matters because MySQL 5.6 has no `skip-name-resolve` and does a reverse lookup per connection. See §9. |
| **1.6** | **Where the router configuration travels** | Not in `buendia-deploy-*.tar.gz`. Correction to revision 1: that allowlist is **8 required + 4 optional paths, not nine**, and its leak check is **name-based only** (`CLAUDE.md`, `docs/`, `.claude/`, `*FIELD-PILOT*`, stray `*.md`, `.env`, `.git`) — it does **not** scan content for secrets. The router artefacts stay out simply because the allowlist never copies `deploy/network/`. ⚠️ Note what the exported backup contains: `/etc/config/wireless` with the PSK in cleartext **and `/etc/shadow`**. The PSK is not really a secret (it is on the laminated card); the root hash is. Handle the backup as a credential. |
| **1.7** | 🆕 **`SITE_ID` and `APK_VERSION`** | Both must change before any build. `pack-www.sh` names the payload `<SITE_ID>-<version>`, so keeping `SITE_ID=notebook-test` and `APK_VERSION=1.0.0` **silently overwrites** the existing hardware-validated payload and APK rather than sitting beside them. Pick e.g. `SITE_ID=pilot` and bump the version so old and new are distinguishable by filename. |
| **1.8** | 🆕 **Docker address pools on the server** | `deploy/config/docker/daemon.json` sets only log caps. Docker's default pools reach into `192.168.0.0/16` — this dev box has bridges at `192.168.16.1`, `.32.1`, `.48.1`, `.64.1`, and the first slot Docker hands out in that range is `192.168.0.0/20`, which **contains the entire site subnet**. Unlikely on a one-stack server (the `172.x` pools go first) but silent and catastrophic on an unattended box. Pin `default-address-pools` to `172.16.0.0/12`. See §9. |

---

## 2. What this exercise proves — and what it must not be read as proving

**Proves:**

- The `uci` script produces a working network on a factory-reset Flint 2, is idempotent, and survives
  a cold power-pull *and* a Save/Apply in the vendor web interface.
- The DNS clock intercept genuinely corrects a wrong tablet clock with no uplink — verified from the
  **router's** traffic, against a **negative control**, not from a configuration page.
- Configuration restore by both paths (backup file, script-only rebuild) over a declared key set.
- `setup.sh`'s netplan `ethernets:` branch applies a static address on real hardware.
- The whole install on the real shipping subnet, from three factory resets, ending in a clinical smoke
  test whose stored timestamp is checked against a known instant.

**Does not prove, and the write-up must say so explicitly:**

| Not proven | Why | Blocked on |
|---|---|---|
| Coverage at site distances / through site walls | No site layout, one node only | **B2** |
| Thermal behaviour at ~40 °C | Bench is a Swiss room; units are rated 0–40 °C, no headroom. T9 gives a baseline only | An elevated-ambient rig |
| A second AP on the same SSID, and roaming | Beryl AX not purchased | §8 item 10 procurement |
| **Portability of the script to a different model** — its core claim | Only a second model exercises the discovery logic | T8, when the Beryl AX arrives |
| Router riding out a power cut | Flint 2 is 12 V/4 A barrel jack; an ordinary USB power bank cannot drive it | A verified 12 V source |
| Anything about MSF's tablets | Different Android version, vendor and policy set: sideload permission, MDM install block, Private DNS lock, NTP source, SIM/NITZ | **B5** |
| Multi-tablet bidirectional sync with the packaged build | One tablet on the desk | MSF UAT |

⚠️ **The power-cut exclusion is a shipping blocker, not a caveat.** As things stand the kit would ship
with the network dying on every real power cut while the server's battery carries on — which
contradicts plan §3.3's "router on a power bank". Either add a verified 12 V source to procurement, or
record it in §7 as a known shipping gap. It must not stay implicit.

A green run here is a green run for *the mechanism*. Recording that distinction is the difference
between a useful result and one that quietly licenses shipping something untested.

---

## 3. Phase 1 — Build the WS-8 artefacts  *(~0.5–1 day, dev box + router cabled)*

New directory **`deploy/network/`**. Written **discovery-based**, per plan §WS-8: most of a `uci`
configuration is portable, and the part that is not is small and known.

**Prerequisite the script cannot create for itself:** SSH is closed until the first-boot wizard runs
(§0.1), and root SSH then uses the wizard password. `sshpass` is not installed here, so **install the
dev box's public key on the router as the last step of the wizard** — otherwise T2 and G5 become
interactive password prompts and idempotency stops being a scripted assertion.

### `configure-router.sh`

1. **Preflight and record** — model, firmware, full `uci show` → `baseline-<fw>.uci`. The before/after
   diff is the idempotency evidence.
2. **Discovery** — this is where the vendor layer gets mapped rather than guessed:
   `ls /etc/config`, `uci show | grep -iE 'dns|dnsmasq|stubby|adguard|glconfig'`, `ls /etc/init.d`,
   `ss -lunp`. ⚠️ **AdGuard Home is the one that matters most** and was missing from revision 1: it is
   the GL.iNet feature that *displaces dnsmasq from :53* (dnsmasq moves to 5353), which bypasses every
   `address=` override while leaving the configuration page looking perfect.
3. **Radios** — select **by band**, never `radio0`; `option path` is a literal hardware path. Set
   `country` explicitly and **pin non-DFS channels** (2.4: 1/6/11; 5: 36–48): a 5 GHz radio that
   auto-selects DFS does channel-availability checking at every cold boot and can vacate on a radar
   event — "Wi-Fi missing after a power cut", unattended, with nobody on site.
4. **LAN** — only `network.lan.ipaddr`/`netmask`; never the vendor bridge or switch section.
   **Disable LAN IPv6** (`network.lan.ipv6='0'`, `dhcp.lan.ra='disabled'`, `dhcpv6='disabled'`) — it
   is on by default and is an entirely untested dimension in an IPv4-only deployment.
5. **DHCP** — pool pinned to exclude `.1` and `.10`; option 6 = the router; option 42 = `.10` as a
   free extra for non-Android clients. ⚠️ **Exactly one DNS server in the offer.** A vendor-added
   secondary is a first-class false-pass vector: `nslookup … 192.168.8.1` from the dev box succeeds
   while the tablet round-robins half its queries to the secondary.
6. **DNS clock intercept** — `address=` overrides for `time.android.com`, `time.google.com` and the
   wildcard `/ntp.org/` (which covers `*.pool.ntp.org`) → `192.168.8.10`; `rebind_protection='0'`;
   vendor DNS layer and any `stubby` / `https-dns-proxy` / **AdGuard Home** stopped *and* `disable`d.
   ⚠️ **Correction to the framing inherited from the network spec:** rebinding protection filters
   private addresses in answers received *from upstream*; locally configured `address=` records are
   not filtered by it. Setting it off is harmless and worth doing for the vendor UI's sake, but it is
   **not** the mechanism that would break the intercept — the vendor DNS layer and encrypted DNS are.
   Treat those as the primary assertions. *(Whether GL.iNet's dnsmasq fork changes this is on the
   verify-on-hardware list, §8.)*
7. **Wi-Fi isolation and SSID hygiene** — set `isolate='0'` (free), but ⚠️ **correction:** `isolate`
   is hostapd's intra-BSS flag; it blocks client↔client frames on one BSS and does **not** affect
   wireless→wired traffic, so it could never have broken tablet↔server with a cabled server. The
   genuinely adjacent risk is different and must be asserted instead: **the vendor guest network is
   disabled, and every enabled `wifi-iface` has `network='lan'`.** A tablet provisioned onto a guest
   SSID is truly isolated and looks perfectly associated.
8. **Router's own time** — `system.ntp.server='192.168.8.10'`. The router boots ten months stale
   (§0.1), so it must be a *client* of the server; set `enable_server='0'` unless the redirect design
   in C-5 is adopted, so it can never hand its own wrong time to anything that asks.
9. **Firewall** — WS-8's plan text requires "a firewall that permits the LAN traffic the stack needs
   whether or not a WAN uplink is present", and revision 1 dropped it. OpenWrt's default `lan` zone
   is permissive enough that every test would pass without it, which is exactly how an unasserted
   requirement gets read as met. Set it explicitly and assert it.
10. **Static lease for the server** — `--server-mac`, optional (the server does not exist on the first
    run). ⚠️ **As designed it asserts nothing:** the server holds `.10` from netplan and never sends a
    DHCPDISCOVER, so the reservation can never fire. Document it as a reinstall aid, or test it
    honestly by booting the server once with `dhcp4: true`.
11. **Apply** — `commit` is not enough. `reload_config` does not restart `stubby`/`https-dns-proxy`/
    AdGuard, and wireless reconfiguration through netifd is uneven on vendor builds. Do explicit
    `/etc/init.d/dnsmasq restart`, `/etc/init.d/firewall restart`, `wifi reload`,
    `/etc/init.d/network reload` — **and require a full reboot before `verify-router.sh` is trusted**,
    since reboot-survival is the property being sold.

⚠️ **Idempotency has to be designed, not hoped for.** `dhcp.@dnsmasq[0].address` and
`dhcp.lan.dhcp_option` are **list** options: `uci add_list` appends a duplicate on every run, so T2
fails on the second run unless every list is `uci -q delete`d before being re-added.

### `verify-router.sh`

Go/no-go with an exit code. ⚠️ **It must assert the running state, not `uci`** — the named GL.iNet
hazard is precisely *runtime ≠ configuration*:

- `ps | grep dnsmasq`, then grep the `address=/…/192.168.8.10` lines out of the **generated**
  `/tmp/etc/dnsmasq.conf.*`.
- `ss -lunp | grep :53` shows dnsmasq and **nothing else** bound on `br-lan`; nothing on 853.
- A real **DHCP offer** (not `uci`) carries exactly one DNS server and an address outside `.1`/`.10`.
- Guest SSID absent; every `wifi-iface` on `network='lan'`; firewall rules present.
- Server assertions (`.10:9000`, `:9001`) are **opt-in via `--server <ip>`** — Phase 2 runs with no
  server on the bench, so as written in revision 1 every Phase 2 row would have failed.

### `verify-clock-intercept.sh` 🆕

Packaged separately and deliberately: the population that matters is **MSF's CrossCall tablets**,
which this bench will never see. Wraps the router-side capture plus the `chronyc clients` delta so the
whole check is re-runnable in five minutes against the real devices at staging.

### `backup-router.sh` · `README.md`

`sysupgrade -b` plus sha256 (handle as a credential — §1.6). README carries: the frozen firmware
version, the wizard step, "restore the backup; if it is not the same model, run the script",
**restore only onto the recorded firmware version** (a cross-version restore can silently drop renamed
config), the taped reset button, and the prohibition on plugging USB storage into the router.

---

## 4. Phase 2 — Bench tests  *(~4 h, router + dev box + tablet; WAN unplugged throughout)*

No-uplink is the shipping state, so it is the default here. Each row is pass/fail with evidence.

| # | Test | Pass criterion |
|---|---|---|
| **T1** | Factory reset → wizard → install SSH key → run the script once | exits 0; `verify-router.sh` green |
| **T2** | Run it a **second** time | zero changes over a **normalized** dump (volatile keys filtered — see T6); verify still green |
| **T3** | **Cold power-pull**, twice (not a soft `reboot` — that does not reproduce a power cut) | verify green; both SSIDs beaconing within a recorded time; router's clock converges to server time. ⚠️ **Assert the reboot actually happened** — read `/proc/uptime` before and after. A backgrounded `reboot` over SSH is killed with the session, and the router then answers instantly, which is indistinguishable from a fast boot and produces a green verify that proves nothing |
| **T4** | GL.iNet web UI: open the DNS, Wireless and Internet pages and **click Save/Apply**, then log out | verify still green, and re-run T2's idempotency check. Viewing is not the hazard; the vendor layer re-templating on *apply* is |
| **T4a** 🆕 | **The clock intercept, on the bench.** Temporarily give the dev box `192.168.8.10`, run chrony with the shipped `buendia-ntp.conf`, join the tablet, and execute the whole of G8 procedure below | The single most important mechanism in this exercise, provable **now** with what is on the desk — two hours, no wipe, and a failure costs nothing. Deferring it to G8 on day 3, after the laptop is wiped, was the worst sequencing error in revision 1 |
| **T4b** 🆕 | **Attach the WAN uplink**, wait for it to come up, then re-run `verify-router.sh` | `stubby` has `trigger='wan'` (§0.2), so encrypted DNS can only start once an uplink exists. Assert nothing but dnsmasq is on :53 and nothing is listening on 853 **with the uplink up** — every no-WAN test is blind to this |
| **T5** | `backup-router.sh` → factory reset → restore backup via web UI | verify green |
| **T6** | Factory reset → **script only** | verify green, **and** a diff over a **declared key allowlist** (`network.lan.*`, `dhcp.*`, functional `wifi-iface` keys, our firewall rules) matches T5. ⚠️ Revision 1's "`uci show` identical" was **unachievable**: a reset regenerates `ula_prefix`, dropbear/rpcd host keys and vendor tokens, and `macaddr`/`path` are device state. The filter lives in the repo so the criterion is reproducible |
| **T7** | Per-band association: disable one radio at a time, associate a client on each | Same-SSID dual-band otherwise **hides a dead radio**, and checking "both bands present" from `uci` does not test the air |
| **T8** | *(deferred — needs the Beryl AX)* run `configure-router.sh` **unmodified** on a second model | The script's core claim is portability to a different model, and only a second model exercises the discovery logic. Needs no site and no MSF — schedule it when the node arrives |
| **T9** | Thermal baseline: `/sys/class/thermal/thermal_zone*/temp` at idle, under 30 min of Wi-Fi load, and once with airflow deliberately obstructed | Not a 40 °C soak, but a free bench baseline the site can be compared against. The spec calls thermal the largest single risk in the network design |

Exit condition: T1–T7 pass, T9 recorded, `deploy/network/` committed (which must happen **before**
`make-bundle.sh` runs, or the bundle ships tagged `-dirty`).

---

## 5. Phase 3 — Full installation rehearsal  *(~1 day)*

### 5.1 Two `.env` files, not one — and they must agree

⚠️ **Revision 1's biggest structural error.** `deploy/.env` drives only the **build side**
(`build-apk.sh`, `publish.sh`, `pack-www.sh`, `make-install-card.sh`). The test laptop never reads it:
`bootstrap.sh` requires a **`buendia.env`** on the USB and installs it as `<target>/.env`
(`bootstrap.sh:50,145`). So every value G3 tests — `CONFIGURE_NETWORK`, `GATEWAY_IP`, `DNS_SERVERS`,
`STATIC_IP` — belongs in `buendia.env`, hand-written from `.env.example`.

**Build-side `deploy/.env`:** `STATIC_IP=192.168.8.10`, `APK_SERVER=` (inherits), `SITE_ID`,
`APK_VERSION` (both bumped per §1.7), SSID/passphrase, `SITE_FACILITY_NAME`.

**USB `buendia.env`:** the above plus everything `setup.sh` hard-fails on — it dies if
`MYSQL_ROOT_PASSWORD`, `MYSQL_PASSWORD`, `DB_IMAGE`, `OPENMRS_IMAGE` or `PKGSERVER_IMAGE` still hold
`CHANGE_ME` / `REPLACE_WITH_DIGEST` / `YOUR_ORG`, and again if `DB_IMAGE` carries no baked-seed label:

```
SITE_ID / TZ=UTC / STATIC_IP=192.168.8.10
CONFIGURE_NETWORK=true / NET_IFACE=<the wired iface> / NET_RENDERER=
GATEWAY_IP=192.168.8.1 / DNS_SERVERS=192.168.8.1
DB_IMAGE=<digest> / OPENMRS_IMAGE=<digest> / PKGSERVER_IMAGE=
MYSQL_ROOT_PASSWORD / MYSQL_DATABASE / MYSQL_USER / MYSQL_PASSWORD
```

⚠️ **`NET_IFACE` must be set explicitly.** If the test laptop's Wi-Fi is also on our SSID and holds
the default route, `detect_iface` picks `wl*`, sets `is_wifi=1`, and the run silently exercises the
**`wifis:` branch that is off the shipping path** — the opposite of what G3 exists to test.

**Check `STATIC_IP` matches between the two files.** A mismatch produces an APK that installs cleanly
and never connects, with nothing on the box to explain why.

### 5.2 The APK payload reaches the server on the USB, not from GitHub

⚠️ **Correction:** `.env` has no `APK_RELEASE_*` keys and no private release has ever been created.
With `APK_SOURCE=auto` and an empty `www/`, `setup.sh` merely warns — but `buendia-verify.sh` then
**fails** `/latest.apk served`, so `setup.sh` exits non-zero and G3/G4 go NO-GO before G7 is reached.
Use the **validated USB path**: `pkgserver-www-<SITE_ID>-<ver>.tar.gz` + `.sha256` on the stick. The
GitHub-release path stays unexercised and out of this rehearsal.

### 5.3 Step zero: back up what is not reproducible

`pilot-build-kit` names `deploy/.env` and `apk/keystore/` as the only non-reproducible things in the
tree — and §5.1 overwrites the first. Also, `APK_VERSION=1.0.0` yields `buendia-client-1.apk`, the
**exact filename** of the existing hardware-validated build, and `publish.sh` does
`rm -f www/buendia-client-*.apk www/latest.apk`. Copy `deploy/.env`, `apk/`, `pkgserver/www/` and
`pkgserver/cards/` aside first. Clear the stale `deploy/*.tar.gz` (three are present, one `-dirty`) or
`bootstrap.sh` will refuse the stick.

### 5.4 Gates

| Gate | Step | Pass criterion |
|---|---|---|
| **G0** | Router: reset → wizard → key → `configure-router.sh` → `verify-router.sh` | green |
| **G1** | Test laptop: fresh Ubuntu, cabled to a LAN port, WAN uplink attached | DHCP + internet |
| **G2** | `bootstrap.sh` from USB, **then `sudo /opt/buendia/setup.sh --dry-run`** | ⚠️ `bootstrap.sh --dry-run` on a bare box neither unpacks nor reaches `setup.sh`, so it checks only the sha256 and payload selection. The meaningful rehearsal is `setup.sh --dry-run` *after* a real unpack — that is what pre-flights the netplan branch |
| **G3** | `setup.sh` | **netplan `ethernets:` applies and the box holds `192.168.8.10`** (`setup.sh` polls and dies if it never lands). **Rollback if it strands the box: `rm /etc/netplan/60-buendia.yaml && netplan apply`, from the console** — there is no other address and no repo on it |
| **G3a** 🆕 | **Set and verify the server's clock**: `timedatectl`, `hwclock --systohc`, confirm UTC | G8 proves the tablet copies the server — **not that the server is right**. A green G8 against a server three days out is indistinguishable from a pass, and every encounter is then mis-stamped. `setup.sh` only *warns* if the RTC is unreadable |
| **G4** | `buendia-verify.sh` from `setup.sh`, then again **from the dev box** on our SSID | GO both times. ⚠️ It contains **no NTP assertion at all** — G4 says nothing about the time authority (§9) |
| **G5** | Re-run `configure-router.sh --server-mac <MAC>` | idempotent. Reservation is a reinstall aid only (§3 step 10) |
| **G6** | **Unplug the WAN** | verify still GO |
| **G7** | Tablet: reset → join SSID → **Private DNS Off**, `captive_portal_mode 0`, TZ pinned, auto-timezone off → scan QR → install | app opens pointed at `.10` and works. ⚠️ Private DNS is a **global** setting, not per-network; if MSF's image or MDM sets it to `hostname`, resolution leaves over DoT and the intercept dies **while Buendia keeps working perfectly**, because the app addresses the server by IP. Add to **B5** |
| **G8** | **Clock intercept** — re-confirmation of T4a on the real server | See the method below |
| **G9** | Clinical smoke test, then a full unattended power cycle | Rows written by the tablet's account, **and `encounter_datetime` compared against a hand-noted reference instant** — the entire exercise exists because the tablet stamps that value, and no gate previously checked it. Data is disposable and **must be wiped before anything ships** (there is still no backup mechanism) |

### 5.5 How G8/T4a is actually verified

Revision 1's method — `chronyc clients` / `tcpdump` on the server — is blind by construction to every
interesting failure: a query that resolved elsewhere, a query never sent, a reply the tablet rejected.

- **Capture on the router**, not the server: `tcpdump -i br-lan -n 'port 53 or port 123'` for the whole
  window. That is the only vantage point that sees queries which *did not* land on `.10`.
- **Assert no udp/123 leaves for any destination other than `.10`** — this is what catches an OEM
  hardcoded NTP **IP literal**, against which no DNS override can work and which produces zero DNS
  traffic (invisible to every other check).
- **Negative control, or the test cannot fail:** step the server's chrony by a distinctive offset
  (e.g. +00:07:13) and require the tablet to land on *that* — only `.10` can produce it. Re-enabling
  automatic time can otherwise re-apply a cached suggestion and show green. Run one iteration with the
  `address=` lines removed and **require failure**. Assert no SIM and mobile data off.
- **On the tablet:** `dumpsys network_time_update_service` and `dumpsys time_detector` show the
  accepted suggestion, its origin and its age. ⚠️ `settings get global ntp_server` returns `null` on
  stock AOSP — the name lives in a framework resource `settings` cannot read, so §3.4's stated
  discovery method misleads and must be corrected in the staging guide.
- **Numeric pass criterion:** tablet-vs-server offset < 1 s, and the `chronyc clients` packet count
  for the tablet's IP incremented during the window. Then **reboot the router and repeat**.

---

## 6. Contingencies (planned branches)

**C-1 — Android marks the network "no internet".** ⚠️ Revision 1's HTTP-204 fix is only half-workable:
validation requires the **HTTPS** probe to succeed, so a 204 from the pkgserver yields at best partial
connectivity — and serving port 80 would need a new published port in `docker-compose.yml`, a file
inside the bundle allowlist, i.e. a change to the shipping artefact. Do it the supported way instead:
`settings put global captive_portal_mode 0` at staging, plus answering "always connect". **Add a test
the plan lacks:** leave the tablet on the uplink-less SSID for 24 h across a reboot and confirm it is
still associated — Android de-prioritizing an unvalidated network is the failure that appears after
everyone has gone home.

**C-2 — an NTP hostname we did not override.** Add it, record the device and Android version, and feed
it to **B5 q8**.

**C-3 — netplan apply fails at G3.** Wrong renderer, or interface autodetection choosing Wi-Fi. Fix
`buendia.env` and re-run; rollback path in G3.

**C-4 — LAN address change drops the SSH session.** *Downgraded* — §0.1 confirmed the factory default
already matches.

**C-5 🆕 — the tablet queries a hardcoded NTP IP.** No DNS override can help. Prepared fix: an OpenWrt
firewall `redirect` on `src='lan' proto='udp' src_dport='123'`. ⚠️ **DNAT to `192.168.8.10` does not
work** — the server replies with source `.10` while the tablet expects the original destination, and
the reply is dropped. The clean form is a `REDIRECT` to the router itself with the router disciplined
from `.10`, so conntrack un-NATs the reply. This is the only case where the router serves time, and it
reverses §3 step 8's `enable_server='0'`.

---

## 7. Phase 4 — Fold back  *(~1 h, non-negotiable)*

Progress doc (WS-8 ✅, §8 item 5 ✅, firmware version, new §4 gotchas, refreshed state block); new
config questions into `FIELD-PILOT-MSF-CONFIG-REQUESTS.md` — at minimum **B5** gains *"is Private DNS
settable or MDM-locked, what is the image's NTP source, and does it ship with a SIM"*; commit
`deploy/network/`; `pilot-checkpoint` for the close-out. **Copy §2's "does not prove" table into the
progress doc verbatim**, and add the §9 defects as tracked work rather than prose.

---

## 8. Still to verify on the hardware

Answered by §0.2: where the vendor DNS layer lives (`gl-dns` + `adguardhome` + `stubby`); that the
Flint 2 has **no RTC**; that rebind protection ships off; and that the stock DHCP pool is already safe.

Genuinely still open:

- **Whether encrypted DNS activates when the WAN comes up** (`stubby.trigger='wan'`) — T4b exists for
  exactly this, and it is the highest-value unknown left.
- **Whether disabling `gl-dns`'s override breaks their web UI's DNS page**, or gets re-templated on a
  Save/Apply — T4's purpose.
- **Whether GL.iNet's `isolate` adds bridge-port isolation** on top of hostapd's intra-BSS flag. If it
  does, §3 step 7's conclusion flips and wireless→wired *would* be affected.
- **Whether a real DHCP offer carries a second DNS server** — must be read off an actual offer, not
  `uci`.
- **Whether `NetworkTimeUpdateService` polls over an unvalidated Wi-Fi** on the tablet, and what the
  CrossCall image uses as its time source (hostname vs IP literal) — T4a and **B5**.
- **Country code:** radios ship `DE`; the deployment is DRC. Decide deliberately — it changes
  available channels and transmit power, and the coverage walk is only valid for the setting used.

**Recommend shipping tablets without SIMs** pending the CrossCall answer: AOSP's default source
priority is `telephony,network`, so carrier NITZ would outrank our NTP suggestion.

---

## 9. Defects found in already-shipped artefacts

These are not test steps. They exist in the tree today, they outlive this exercise, and two of them
mean a previously "validated" claim was weaker than recorded.

| # | Defect | Fix |
|---|---|---|
| **D1** | `config/chrony/buendia-ntp.conf` hardcodes `allow 192.168.8.0/24` while `STATIC_IP` is templated. On any other subnet chrony silently refuses every client — so on **both previous `192.168.0.x` installs the time authority was not merely untested but unserviceable** | Derive the prefix from `STATIC_IP` in `setup.sh`; assert it covers the host's own address |
| **D2** | `buendia-verify.sh` has **no NTP assertion whatsoever** — "GO" says nothing about the time authority | Add: `chronyc -n tracking` Leap normal + stratum ≤ 10; `ss -lunp` shows 123/udp bound; and an **off-box** probe from another machine, without which the `allow` line is never exercised |
| **D3** | `config/docker/daemon.json` sets no `default-address-pools`; Docker's defaults reach into `192.168.0.0/16` and its first slot there contains the site subnet | Pin to `172.16.0.0/12` |
| **D4** | MySQL 5.6 has no `skip-name-resolve`, so it reverse-resolves per connection; with `DNS_SERVERS=192.168.8.1` every app→DB connection stalls while the router reboots | Add `skip-name-resolve`; test by rebooting the router with the stack up |
| **D5** | `.env.example` ships `GATEWAY_IP`/`DNS_SERVERS` empty as the documented default, which breaks the shipping path at the `chrony` install | Default them to the router address, with a comment |
| **D6** | `make-install-card.sh` hard-requires python3 `segno` and exits otherwise, despite a header comment claiming `qrencode` also works | Fix the fallback or the comment; both exist here but will not on a staging machine |
| **D7** | `build-apk.sh`'s read-back check is skipped **silently** when build-tools `aapt` is absent, and `REAL_VERSION` then falls back to the requested value — so "check the read-back line" can have nothing to check and no warning | Fail loudly when `aapt` is missing |
| **D8** | Progress doc §2/§4 describe the bundle as "the nine files"; it is 8 required + 4 optional, and its leak check is name-based, not a content scan | Correct both places |
| **D9** | Nothing at a site ever notices the intercept has stopped working — it fails silently and there is no engineer | Cheap: a server timer that fails loudly into `buendia-diagnostics` if `chronyc clients` has seen no client in 24 h. Durable: flag at ingest when client-supplied `JsonEncounter.time` deviates from server receipt time |

---

## 10. Effort and sequencing

| Phase | Work | Effort |
|---|---|---|
| 1 | Decisions | ~30 min |
| 3 | `deploy/network/` artefacts | ~0.5–1 day |
| 4 | Bench T1–T7, T9 (**incl. T4a, the clock test**) | ~4 h |
| 5 | Full rehearsal G0–G9 | ~1 day |
| 7 | Fold back | ~1 h |
| 9 | Shipped-artefact defects D1–D9 | ~0.5 day, separable |

**~2.5–3 days**, up from revision 1's 2 — the growth is T4a, the second `.env`, the honest verification
method for G8, and D1–D9. Phases 1 and 4 need only the dev box, the router and a tablet, so the test
laptop stays untouched until Phase 5.

⚠️ **Sequencing note vs the progress doc.** §8 there orders item 10 → item 7 → item 5. This plan does
items 10 and 5 and defers item 7 (the remote-support tunnel, which needs a mobile hotspot rather than
the router). That reordering is deliberate — the router is in hand — and should be recorded rather
than left as an apparent contradiction.
