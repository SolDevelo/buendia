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
| **T3** reboot survival — **soft half only** | ⚠️ PARTIAL | down 2 s, back 48 s, `/proc/uptime` reset to 39 s, **GO 34/34**. The cold power-pull (×2) is still outstanding |
| **T4b** WAN attached | ✅ PASS | **GO 34/34 with the uplink up** — the plan's highest-value unknown |
| Backup export | ✅ PASS | 36 KB, 101 files, mode 600, sha256 verified |
| **T4** web-UI Save/Apply | ⬜ not run | needs a human at the browser |
| **T4a** clock intercept with a tablet | ⬜ not run | needs the tablet + dev box temporarily at `.10` |
| **T5/T6** restore vs script-only rebuild | ⬜ not run | needs two factory resets; do last |
| **T7** per-band association | ⬜ not run | needs a wireless client |
| **T9** thermal baseline | ⬜ not run | |

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
