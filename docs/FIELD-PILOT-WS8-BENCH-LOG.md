# WS-8 bench log — Flint 2 (GL-MT6000), firmware 4.8.3

Evidence for the Phase 2 test matrix in `FIELD-PILOT-WS8-E2E-TEST-PLAN.md` §4. Kept **in the repo,
not in a scratchpad**: the first version of this file lived in `/tmp` and was destroyed by a reboot
partway through the run. A workstream whose whole purpose is "prove it" cannot keep its proof on
tmpfs.

**Setup.** Dev box cabled to a LAN port. `SSID=MSF-Buendia`, `ROUTER_COUNTRY=CD`, 2.4 GHz ch 6 HE20,
5 GHz ch 36 HE80, server address `192.168.8.10` (not yet installed). Router SSH key at
`~/.ssh/buendia-flint`.

## Results

| Test | Result | Evidence |
|---|---|---|
| **T1** apply from post-wizard state | ✅ PASS | 19 changes, exit 0; `verify-router.sh` **GO 34/34** |
| **T2** second run (idempotency) | ✅ PASS | "Already correct — nothing to commit"; `uci changes` empty |
| **T3** reboot survival, **incl. two cold power-pulls** | ✅ PASS | see below |
| **T4b** WAN attached | ✅ PASS | **GO 34/34 with the uplink up** — the plan's highest-value unknown |
| Backup export | ✅ PASS | 36 KB, 101 files, mode 600, sha256 verified |
| **T4** web-UI Save/Apply | ⬜ not run | needs a human at the browser |
| **T4a** clock intercept, end to end | ✅ PASS | proven from traffic, not from the clock display — see below |
| **T5/T6** restore vs script-only rebuild | ⬜ not run | needs two factory resets; do last |
| **T7** per-band association | ⬜ not run | needs a wireless client |
| **T9** thermal baseline | ⬜ not run | |

## T3 — cold power-pulls

The soft reboot passed first (down 2 s, back 48 s, uptime reset to 39 s, GO 34/34), then two real
power-pulls with the plug out ~10 s:

| Pull | Uptime before | Downtime | Uptime after | Verify | Over the air |
|---|---|---|---|---|---|
| 1 | 673 s | 61 s | **38 s** | GO 34/34 | `MSF-Buendia` ch 6 (2437 MHz) + ch 36 (5180 MHz), WPA2, signal 100 |
| 2 | 73 s | 65 s | **38 s** | GO 34/34 | both bands again, ch 6 + ch 36 |

`configure-router.sh` re-run after the second pull: **"Already correct — nothing to commit"**. So the
configuration is genuinely in flash, not a first-boot artefact — which is what a second pull exists to
distinguish.

**Boot time is reproducibly 38 s to SSH** (~60 s wall-clock including the plug being out). That is the
number for the site runbook: after mains returns, expect the network back in about a minute.

The over-the-air scan is the first RF evidence in this workstream — everything before it ran over the
cable. It confirms three things `uci` cannot: both radios actually come back, they come back on the
**pinned non-DFS channels** rather than wandering, and the encryption really is WPA2 rather than the
mixed mode that breaks association on older Android builds.

## T4 — the vendor web UI, and a real defect it exposed

Two findings from opening the GL.iNet UI against our applied configuration:

- **The DNS page refuses a no-op apply.** It will not submit unless something changed. That is a
  *good* property: an idle visit to that page cannot silently clobber the `address=` overrides the
  clock intercept depends on.
- **The Wireless page could not save at all.** It *displayed* `encryption=psk2+ccmp` and then rejected
  the save with "incorrect parameter value". Both values are valid OpenWrt, but the vendor UI can only
  write its own enumerated set (`WPA/WPA2-PSK`, `WPA2-PSK`, `WPA2-PSK/WPA3-SAE`).

The second is a defect in what we shipped, not in the router. Our value was *sticky*, which sounds
like a pass — but it made the Wireless page unusable for a legitimate runbook action such as rotating
the passphrase, and the obvious escape for whoever hits that error is to pick a different encryption
from the dropdown, which is exactly the unsupervised change we do not want.

**Resolved by shipping plain `psk2`**, now `ROUTER_ENCRYPTION` in `.env` rather than hardcoded. The
security delta is negligible here — Android negotiates CCMP regardless, TKIP appears only if a client
asks, and the passphrase is laminated on a ward wall — while requirement 6 explicitly demands the
configuration survive a web-UI visit. Matching what the vendor can represent is worth more than
forbidding a cipher no pilot device will request.

Re-applied as exactly 2 changes (encryption on each interface, nothing else), GO 34/34, still WPA2
over the air on channels 6 and 36, and a re-run is a clean no-op.

**With `psk2` in place the UI saves cleanly, and T4 then PASSED.** After saving the Wireless page and
toggling-saving-toggling-saving the DNS page:

- Verify **GO 34/34**; `configure-router.sh` re-run is a no-op.
- `address=` overrides intact, `rebind_protection` still `0`, SSID and encryption unchanged.
- **`stubby` and `adguardhome` are still `disabled` at boot**, not merely not running. This is the
  check that matters: a UI save could have re-enabled a service without starting it, which would then
  ambush the next cold boot. `verify-router.sh` only inspects the *running* state, so boot-enabled
  state has to be asserted separately — a gap worth closing in the script.
- The vendor layer **does** write on save: the DNS page added `gl-dns.@dns[0].force_dns='0'`, a key
  that did not previously exist. It did not touch anything of ours, but it confirms the layer is live
  and is the reason this test exists.

### Open: should `force_dns` be ON rather than off?

GL.iNet's "force DNS" installs a firewall redirect sending all client port-53 traffic to the router.
That would make the clock intercept work even for a tablet that ignores DHCP option 6 — a device with
a hardcoded resolver, or an MDM-set one. Since the entire clock-discipline mechanism assumes tablets
use our resolver, this is real hardening for the exact failure the plan flags under Private DNS.

Prefer implementing it as a **plain OpenWrt firewall redirect** (lan, udp+tcp dport 53 → the router)
rather than by setting the vendor key: same effect, portable to the Beryl AX and to a non-GL.iNet
replacement, and reviewable in the script instead of hidden in a vendor layer.

## T4a — the clock intercept, proven end to end

Rig: dev box given `192.168.8.10` as a second address on the LAN, running **chrony with the shipped
`buendia-ntp.conf`** (not a hand-rolled substitute). Tablet: Redmi Pad Pro, airplane mode + Wi-Fi, no
SIM. **Router WAN unplugged** — so `192.168.8.10` was the only reachable time source in existence.

Evidence, from the router's dnsmasq query log and chrony:

```
15:13:31  192.168.8.156  query[A] time.android.com  ->  config time.android.com is 192.168.8.10
15:13:31  192.168.8.156  query[A] time.google.com   ->  config time.google.com  is 192.168.8.10

chronyc clients:   192.168.8.156   NTP: 4 packets
                   192.168.8.1     NTP: 5 packets
```

The tablet's clock corrected at that moment. Corroboration: those two names are the **only** ones of
267 queries that were not retried with a `.lan` suffix, because they are the only ones that resolved
first time — everything else was REFUSED, there being no upstream.

### The test method was wrong first, and the wrong version passed

The obvious procedure — turn "set time automatically" off, set a wrong date, turn it back on — **passes
on a tablet with no network at all.** Android re-applies a *cached* network-time suggestion; nothing is
sent. We reproduced exactly that: correct date restored with Wi-Fi off.

A reboot invalidates the cache. The valid sequence is: automatic OFF and clock wrong → **reboot** →
join Wi-Fi → automatic ON. Then the clock stays wrong until the network comes up, and corrects when it
does.

**The clock display is not evidence.** It moved for a reason unrelated to our network. What counts is a
DNS query for an NTP hostname answered with the server's address, plus NTP packets arriving at chrony.
G8 in the plan must say so.

### Two findings beyond the pass

- **Contingency C-1 did not materialise on this build.** The tablet queried
  `connectivitycheck.gstatic.com`, got REFUSED, and therefore knew the network had no internet — and
  performed the NTP check anyway. One device; MSF's CrossCall build may differ, which is B5's job.
- **The router's stale clock self-heals.** It synced from `.10` (5 NTP packets) as configured; log
  timestamps went from `Oct 16 2025` to the correct date the moment the server appeared. The earlier
  open question about adding a fallback internet time source is therefore **closed — no fallback
  needed.**

## Hardening: force every client onto our resolver

DHCP option 6 only asks politely. A plain OpenWrt redirect (lan, tcp+udp dport 53 → the router) now
enforces it, written portably rather than via GL.iNet's `force_dns` key.

**Verified against a client that ignores option 6:** the tablet was reconfigured with a static DNS of
`8.8.8.8`, and its queries still arrived at our dnsmasq. Combined with our dnsmasq answering
`time.android.com` as `192.168.8.10`, the intercept holds whatever resolver a tablet is set to.

Limits, so this is not over-trusted: it catches **plaintext port 53 only**. Private DNS over TLS leaves
on `:853` and is *not* caught — that remains a per-tablet staging step. A hardcoded NTP **IP** would not
be caught either, since no DNS is involved (contingency C-5).

Two implementation traps hit: setting `firewall.<sec>.enabled` unconditionally registered a change on
every run (the key is absent by default, meaning enabled), breaking idempotency; and `iptables` showed
the rule four times until fw3 was restarted cleanly — stale rules, not duplicate config. `uci` held one
section throughout.

## What T4b settled

`stubby` ships with `trigger='wan'`, so encrypted DNS can only start once an uplink exists — meaning
**every test without a WAN cable is structurally blind to it**. With the uplink up
(`eth1 = 192.168.0.151`, internet reachable):

- `stubby` did **not** start; nothing on `:853`; no DoH/DoT process. Disabling the init script holds
  against the trigger.
- The intercept still resolves: `time.android.com`, `time.google.com`, `pool.ntp.org` → `192.168.8.10`.
- Normal names still forward upstream (`registry-1.docker.io` resolved) — the prerequisite for Phase 3's
  `DNS_SERVERS=192.168.8.1` during the image pull.
- The router's DNS is **not** reachable from the WAN side (a query from `192.168.0.150` timed out).
  dnsmasq does bind the WAN address, so this is worth keeping asserted rather than assumed.

## Traps hit, and what they cost

**A reboot that silently did not happen.** A backgrounded `nohup sh -c "sleep 1; reboot" &` over SSH
is killed with the session. The router answered immediately, and `verify-router.sh` returned a clean
**GO 34/34** — indistinguishable from genuine reboot survival. Only `/proc/uptime` (unchanged at
1:09) exposed it. T3's criterion now requires asserting the uptime reset.

**Four bugs in `verify-router.sh`, found by running it against a known-bad state before applying
anything.** The first would have mattered enormously:

1. **A false GO on the clock intercept** — the single check this workstream exists for. `nslookup`
   parsing took the last `Address:` line, which is the *resolver's own address*, so it reported
   success against the router itself. Now reads only the address following `Name:`.
2. **Default `IFS` collapsed empty `uci` values**, shifting every later field one place, so the
   encryption check read `0` instead of `psk2`. Now `|`-delimited.
3. **`.env` overrode the environment** (the reverse of `build-apk.sh`'s convention), so `--dry-run`
   was silently testing against the notebook's `192.168.0.250`.
4. **`/var` is a symlink to `/tmp`** on OpenWrt, so globbing both `dnsmasq.conf` paths read the same
   file twice and doubled every count — reporting two advertised DNS servers where there is one. Now
   reads the config the running dnsmasq was started with (`-C`).

**Cabling the dev box to a pre-wizard router kills the dev box's internet.** The router hijacks all
DNS to its setup page and NetworkManager accepts it. Fixed once with
`nmcli con mod "<wired>" ipv4.never-default yes ipv4.ignore-auto-dns yes` (+ the ipv6 pair).

## Open consequence to decide

**The router's own clock never becomes correct, even with an uplink.** It still reads Oct 2025:
`system.ntp.server` is `192.168.8.10` only, and the router resolves through its own dnsmasq, so the
`/ntp.org/` override would redirect any pool name to `.10` regardless. It self-heals once the server
exists — which is the design — but until then the router's logs are ~10 months stale, which will
mislead whoever reads a support bundle. If that matters, add a name **outside** the `/ntp.org/`
override (e.g. `time.cloudflare.com`) as a secondary source used only when an uplink is present.

Confirmed on this unit: **no RTC** (`hwclock` fails, no `/dev/rtc*`), which is why
`system.ntp.enable_server='0'` is asserted rather than assumed — a router that served time would hand
out that stale clock.
