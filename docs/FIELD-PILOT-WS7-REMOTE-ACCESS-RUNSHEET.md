# Field Pilot — WS-7 Remote Access: Runsheet

**Date:** 2026-09-22 · **For:** the engineer running the tests, alone, at the bench in Poland.

This is the **procedure**. `FIELD-PILOT-WS7-REMOTE-ACCESS-TEST-PLAN.md` is the **plan** — what each
case proves, its pass criterion, and why it is worth running. Nothing is restated here: cases are
referenced by their IDs (R0…R15) and the plan stays the single source of truth for what "pass" means.

What this document adds is the part the plan assumes you already have: **a working tailnet**, and an
**ordered path from the box you actually have today** (initial version, deployed, running) to the
point where R0 can be executed.

Read once end to end before starting. The Tailscale setup in §5 is the long pole and is best done at
a desk, not while also holding a laptop and a phone.

---

> ### ⚠️ Read first — scope change, 2026-09-22
>
> **MSF installed TeamViewer on the server laptop themselves**, joined it to their corporate Wi-Fi while
> it stayed wired to our router, and confirmed the tablets kept working and that access worked. A person
> on site can reboot the box and make sure TeamViewer is up. **That is the pilot's remote-support
> channel.**
>
> For this runsheet that means:
> - **§5 (Tailscale) and §7 (the tunnel rehearsal) are optional.** Kept intact and runnable, off the
>   critical path. Skip them unless you want the tunnel proven anyway — its value is the scriptable
>   access TeamViewer cannot give.
> - **§2, §3, §4 and §6 are unchanged and matter more than before**, because dual-homing on a foreign
>   network is now the normal operating condition. **R4 in §6 is the most important case you will run:**
>   MSF's laptop has already sat on their corporate network with `:9000` and `:9001` open to it.
> - **New: §6a — the two TeamViewer cases (R18, R19).** Short. *How* TeamViewer is run is MSF's to
>   decide and the assumption is **attended access** — someone on site opens it when support is needed —
>   so the reboot/unattended cases (R16, R17) were **withdrawn on 2026-09-23**.
>
> Shortest useful path: **§2 → §3 → §4 → §6 → §6a.** Roughly half a day, no second internet connection
> and no tailnet required.

## 0. Prerequisites checklist

Tick every line before starting. Discovering a gap mid-session costs the session.

**Lines marked *(parked)* are only needed if you choose to run the optional tunnel sections §5 and §7.**

**Hardware**

- [ ] **Server laptop** — the bench box with the **initial version already deployed**, currently on
      `192.168.8.10`, cabled to the Flint 2.
- [ ] **Flint 2**, configured per WS-8, **WAN port unplugged** and staying that way. The uplink is on
      the laptop in every case here.
- [ ] **This workstation** — the support end. Holds the repo, and doubles as the machine you
      connect *from* for the TeamViewer cases (§6a).
- [ ] **Foreign-network witness** — a second device (phone, spare laptop, tablet) that can join the
      same foreign Wi-Fi as the server. **Without it R4 cannot be run at all**, and R4 is the case
      that matters most.
- [ ] **Test tablet** — the Android device that carries the new app (§4). It doubles as the **LAN
      witness** for R3's loop, so one tablet covers both roles.
- [ ] **Spare Beryl AX, factory default** — it is the hostile network for R6 (its default LAN is
      `192.168.8.1/24`, which *is* the collision case). Do not reconfigure it.
- [ ] **A phone with a hotspot** (Phase 1 needs one foreign Wi-Fi) **and a USB cable that carries
      data** (Phase 3 — a charge-only cable will waste twenty minutes).

**Connectivity**

- [ ] One foreign Wi-Fi the server laptop and the witness can both join — that is all Phase 1 needs.
- [ ] *(parked)* **Two genuinely separate internet connections** for Phase 2 — e.g. this workstation on
      a mobile hotspot while the server uses the house Wi-Fi. Same ISP is acceptable; **same NAT is
      not**. §0 of the plan has the assertion that decides it; record both public IPs before R8.

**Accounts**

- [ ] **TeamViewer** on the bench box and on this workstation (your own account is fine)
      on the box — that property is what §6a tests. Your own account is fine for the bench; MSF's is
      what counts at staging.
- [ ] *(parked)* A **Tailscale account** with admin rights on the tailnet you will use (§5.1).
- [ ] The **new package** (`deploy/` tree or USB pack) built from the current working tree.
- [ ] A **built APK** for this version — or, to build one, **JDK 8 and the Android SDK** (platform 28
      + build-tools 28.0.3). AGP 3.2.1 does not run on JDK 11+, so the system default Java will not
      do; see §4.1.
- [ ] The bench box's existing `.env` — you need its `buendia` password to keep tablets working
      (§3).

**Time**

| Session | Content | Needs |
|---|---|---|
| 1 | §2 gate, §3 upgrade, §4 tablet | ~2 h, one internet connection |
| 2 | Phase 1 — R0–R7 | ~3 h, phone hotspot + both witnesses |
| 2b | **§6a — TeamViewer, R18–R19** | ~20 min, a second machine |
| 3 | *(parked)* §5 tailnet + Phase 2 — R8–R11 | ~3 h, **two separate internet connections** |
| 4 | Phase 3 — R13–R14 | ~1 h, phone + data cable |
| — | *(parked)* R11(c) | a weekend of wall clock, unattended |

**Critical path is sessions 1, 2 and 2b** — about half a day, no tailnet and no second internet
connection required.

---

## 1. Order of work, and why it is this order

1. **§2 — the `ip_nonlocal_bind` gate.** Ten minutes, and it can invalidate the design. Do it first,
   on the box as it is now, before upgrading anything.
2. **§3 — upgrade the bench box** to the new version, by the real documented path.
3. **§4 — put the new app on the test tablet**, and prove the pair works together. The server is
   only half of what ships.
4. **§6 — Phase 1, bench dual-homed.** The negative test (R4) is the point of the whole exercise.
5. **§6a — the TeamViewer cases (R18, R19).** What ships depends on these.
6. *(Optional)* **§5 then §7 — the tailnet and the tunnel rehearsal**, parked but runnable. §5 is
   entirely off-box work; nothing there touches the server until §5.4.
7. *(Optional)* **§8 — Path B, USB tethering**, still worth having as the documented fallback for a
   site with no usable Wi-Fi.

Do not reorder 1 and 2. If the gate fails, the upgrade is pointless until `LAN_BIND` is redesigned.

---

## 2. The gate — verify `ip_nonlocal_bind` on real hardware  *(~10 min)*

**This is the one change in the whole set that has never been verified on hardware.** A subagent
confirmed the *failure* (Docker refuses to publish on an address the box does not hold:
`exit 125, cannot assign requested address`) but could not obtain sudo to confirm the *fix*.

Everything else in this exercise rests on it. `LAN_BIND` publishes the stack on `192.168.8.10`, and
a laptop booted with the cable out does not have that address — so without this sysctl the stack
does not start at all, which is a worse failure than the exposure it was added to prevent.

Run on the **server laptop**:

```sh
# 1. Reproduce the failure, with the address absent. Unplug the ethernet cable first.
ip -br addr | grep 192.168.8.10          # expect NO output
sudo sysctl net.ipv4.ip_nonlocal_bind    # expect: net.ipv4.ip_nonlocal_bind = 0
docker run --rm -d -p 192.168.8.10:9999:80 nginx:alpine-slim
#   expect FAILURE: "cannot assign requested address"

# 2. Apply the knob and retry.
sudo sysctl -w net.ipv4.ip_nonlocal_bind=1
docker run --rm -d --name bindgate -p 192.168.8.10:9999:80 nginx:alpine-slim
#   expect SUCCESS: a container ID
docker rm -f bindgate
```

**If step 2 still fails, stop.** `LAN_BIND` as designed cannot ship — report it, and the fallback is
an interface-based firewall rule in `DOCKER-USER` instead of an address bind. Do not continue to §3;
the rest of the exercise would be testing a mechanism that cannot work.

**If it succeeds**, note that the shipped form is a **drop-in file**, not a live `sysctl -w`
(`deploy/config/sysctl.d/buendia.conf`). R5 is what proves it survives a reboot — the live value you
just set does not.

---

## 3. Put the new version on the bench box  *(~30 min)*

Follow **`deploy/UPGRADE.md`** exactly as written. Do not shortcut it to `docker compose up -d`: the
point is to exercise the path MSF will run, and the upgrade path is itself part of what ships.

Two things that document flags, carried here because they are easy to get wrong at a bench where
nothing feels precious:

- **The `buendia` password must not change.** Press Enter through `prepare.sh`'s prompts. If you
  change it, the tablets you test against are locked out and R3's clinical loop becomes a debugging
  session about credentials.
- **`down -v` and `buendia-uninstall.sh` destroy the database.** Neither prompts. To restart the
  stack, reboot.

Build the pack with `tools/make-usb-pack.sh --keep-passwords <this box's buendia.env>` so the APK and
the server agree.

**Then confirm the new controls are actually present** — all three are new in this version, and a
half-applied upgrade produces confusing results three cases later:

```sh
grep -E '^(LAN_BIND|NET_ROUTE_METRIC)=' /opt/buendia/.env
#   expect: LAN_BIND=192.168.8.10   and   NET_ROUTE_METRIC=1000

sysctl net.ipv4.ip_nonlocal_bind         # expect 1, now from the drop-in
ls -l /etc/sysctl.d/ | grep buendia      # the drop-in exists

ls -l /opt/buendia/tools/buendia-uplink.sh   # the new diagnostic tool
```

The server half is now done. **R0 is the first real case** and it checks the binding properly, but
do not jump to it yet: put the matching app on the tablet first (§4), because every Phase 1 case that
means anything — R3's clinical loop above all — needs a tablet that actually works against this box.

---

## 4. Put the new app on the test tablet  *(~45 min)*

The server is half of what ships. The APK is the other half, and it is the half MSF installs **by
hand on every device** — this version cannot update itself. So deploy it the way the site will, over
the `:9001` QR path, not with `adb`.

### 4.1 Build it, if you have not already

Skip if `deploy/apk/buendia-client-<version>.apk` already exists for this version. Build on the
machine that has the toolchain — the **workstation**, not the server laptop:

```sh
cd deploy/apk
JAVA_HOME=$HOME/.sdkman/candidates/java/8.0.492-zulu PATH=$JAVA_HOME/bin:$PATH ./build-apk.sh
#   expect: buendia-client-<version>.apk  +  .sha256  +  .buildinfo.txt
```

`build-apk.sh` is the source of truth — do not hand-run gradle. It needs `APK_KEYSTORE_PASSWORD` in
`deploy/.env`, and **JDK 8**: AGP 3.2.1 does not run on JDK 11+, and the script warns if `java` is
not 8. Everything else — versioning rules, the `--debug` variant, why in-app OTA is unavailable —
is in `deploy/apk/README.md`.

Read `.buildinfo.txt` before going further. It records what was baked into this binary, and the
server address and account in it must match the box you upgraded in §3.

### 4.2 Publish it to the package server

`publish.sh` publishes **the newest release APK it finds in `../apk/`**, so the binary has to be on
the box first. At the bench, copy it across and publish in place:

Carry it over on a **USB stick** — `scp` will not work unless you have separately installed an
sshd on that box, and nothing in `deploy/` installs one (which is the point of D3, and why the
tunnel serves SSH itself).

```sh
# on the server laptop, with the stick mounted
cp /media/*/buendia-client-<version>.apk /opt/buendia/apk/
cd /opt/buendia/pkgserver && ./publish.sh
#   expect: www/ regenerated, and the install QR printed
```

That is the bench shortcut. **What actually ships is the pre-built payload** — `publish.sh` then
`pack-www.sh` on the workstation, the resulting `pkgserver-www-<site>-*.tar.gz` travelling in the
USB pack and being unpacked into `www/` by `setup.sh` (`APK_SOURCE`). Use the shortcut here because
you are iterating; do not let it become the documented route.

The compose service bind-mounts `pkgserver/www` read-only, so the new APK is served immediately —
no restart, no `docker compose up`. `deploy/pkgserver/README.md` covers what each served path is
for; note its warning that `publish.sh` advertises **only the version it just published**, so
publish as part of rolling an update out, not ahead of it.

Then confirm the port is bound where it should now be — this is `LAN_BIND` doing its job, and it is
the first time you see it in effect:

```sh
ss -ltnp | grep 9001
#   expect the listener on 192.168.8.10:9001, NOT 0.0.0.0:9001
curl -sS -o /dev/null -w '%{http_code}\n' http://192.168.8.10:9001/latest.apk   # expect 200
```

### 4.3 Install on the tablet

Follow **`deploy/UPGRADE.md` § Tablets**: join `MSF-Buendia`, open `http://192.168.8.10:9001` or
scan the install QR, install over the existing app, log in, and let it finish synchronising.

Three traps, all previously established in this project, stated where you will actually hit them:

- **Signature mismatch.** Android only installs an update signed with the same key. If it refuses,
  the APK did not come from this package — check you built with `keystore/buendia-pilot.jks` and
  not a fresh key. *At the bench* you may uninstall and reinstall to get moving: the tablet's local
  database is a cache and re-syncs from the server. **In the field that is an escalation, not a
  workaround** — `UPGRADE.md` tells the site to stop and send us the message, and it should.
- **The APK bakes in the server address and the `buendia` password.** An APK built with a different
  password than the box now carries produces a tablet that installs perfectly and then cannot log
  in. This is the `--keep-passwords` trap from §3, seen from the tablet end; `.buildinfo.txt` is
  how you check it without printing the password into your terminal.
- **The tablet caches forms and charts.** Anything that looks old or missing after an upgrade needs
  a sync before it is a defect. Sync, then judge.

### 4.4 The gate — one clinical round trip

Before any remote-access case, prove the pair actually works together. On the tablet, against its
own account: **admit a patient → record an observation → enter a treatment**, and confirm the
result is visible on the server.

This is not ceremony. It is precisely the loop **R3** later asserts stays unbroken while the uplink
appears, fails and is pulled — so if it does not pass now, every Phase 1 result is uninterpretable
and R3 becomes a debugging session about the tablet rather than a measurement of the network.

**If the round trip fails, stop and fix it before §5.** As with the §2 sysctl gate, continuing past
a failure here only produces results you cannot trust.

---

## 5. Tailscale, from nothing  *(PARKED — optional; ~45 min, off-box until §5.4)*

> Parked on 2026-09-22: TeamViewer is the pilot's channel. Everything below is kept current and correct
> so the tunnel can be picked up without rediscovering it — including the four corrections in §9, which
> cost an afternoon each if missed. Skip to §6 unless you are deliberately proving the tunnel.

Nothing in the repo covers this today. Everything below was verified against Tailscale's current
documentation on 2026-09-22; where their docs have moved on from what our design notes assumed, it is
flagged ⚠️ and §9 collects the corrections.

### 5.1 The tailnet, and who owns it

Sign in at **https://login.tailscale.com** with any identity provider. A new tailnet is created
automatically on first login. The free plan covers 3 users and 100 devices — far more than this
exercise needs.

> ⚠️ **Ownership is a decision to make before anything ships, not now.** For this bench exercise a
> personal tailnet is fine. The pilot must **not** ship attached to a personal account: it cannot be
> handed over, audited, or survive someone leaving, and C1 will ask who controls the coordination
> plane. Raise it as a question when the bench results are folded back — the transport is deliberately
> swappable (Headscale on a SolDevelo VPS is the documented alternative), so this does not block
> testing.

### 5.2 The policy file — do this BEFORE generating a key

Admin console → **Access controls**. A new tailnet ships with a permissive default that will **not**
work here, for one specific reason: its default SSH rule targets `autogroup:self`, and **a tagged
device has no user owner, so `autogroup:self` never matches it**. Tailscale SSH would then be enabled
on the server and silently grant nothing.

Replace the policy with this (JSON with comments and trailing commas is valid in Tailscale's editor):

```jsonc
{
  // A tag is what makes the server a piece of infrastructure rather than "Piotr's laptop".
  // It must exist here BEFORE an auth key can be issued against it.
  "tagOwners": {
    "tag:buendia": ["autogroup:admin"],
  },

  "grants": [
    // Reach the node itself.
    {
      "src": ["autogroup:member"],
      "dst": ["tag:buendia"],
      "ip":  ["*"],
    },
    // Reach the pilot LAN THROUGH it. Route approval alone is not enough — without a grant
    // whose dst is the CIDR, an approved route still carries nothing. This is the half of
    // R8a that is easiest to miss.
    {
      "src": ["autogroup:member"],
      "dst": ["192.168.8.0/24"],
      "ip":  ["*"],
    },
  ],

  // Tailscale SSH is ACL-gated: `--ssh` on the server does nothing without a rule here.
  "ssh": [
    {
      "action": "accept",
      "src":    ["autogroup:member"],
      "dst":    ["tag:buendia"],           // NOT autogroup:self — see above
      "users":  ["root", "autogroup:nonroot"],
    },
  ],

  // Lets the node approve its own subnet route at registration, instead of a console click
  // every time it re-registers.
  "autoApprovers": {
    "routes": {
      "192.168.8.0/24": ["tag:buendia"],
    },
  },
}
```

Save. The editor rejects malformed policy, so a successful save is itself the syntax check.

> **On `grants` vs `acls`:** Tailscale now recommends `grants`, which supersede `acls` and do
> everything they did. Both still work; use `grants` — older examples you find online will use
> `acls` and are not wrong, merely older. The `ssh` block is separate from both.

### 5.3 The auth key

Admin console → **Settings → Keys → Generate auth key**. Set:

| Option | Value | What it buys, and what breaks without it |
|---|---|---|
| **Reusable** | ✅ on | Lets you re-register the box during testing without minting a new key each time |
| **Ephemeral** | ❌ **off** | ⚠️ **The one that must not be wrong.** An ephemeral node is *removed from the tailnet when it goes offline* — catastrophic for a box that is offline by design and reachable only in occasional windows |
| **Tags** | `tag:buendia` | Makes it infrastructure: policy applies by tag, and it is what the `ssh` and `autoApprovers` blocks above key on |
| **Expiry** | 90 days (max) | This is the **key's** lifetime for *registering new devices* — not the node's. See below |

Copy the key now; it is shown once. Keep it out of the repo and out of the transcript
(`TAILSCALE_AUTHKEY` in `.env` is git-ignored).

> ⚠️ **Correction to our design notes.** We assumed node-key expiry had to be disabled by hand.
> Tailscale's documentation is explicit that **a device authenticated with a tag has key expiry
> disabled by default**. So using a tagged key already gives us what R11(a) asserts. **Verify it
> rather than assume it** (§5.7) — and do not confuse it with the 90-day expiry of the auth key
> above, which is a different thing and only governs new registrations.

### 5.4 Install on the server laptop

The bench box predates the fix, so the binary will not be there — `remote_support()` never ran on the
path that built it (defect D1). Install it directly for this test:

```sh
curl -fsSL https://tailscale.com/install.sh | sh
tailscale version
```

The `--prepare`-phase install and the `bundle-debs.sh` package apply only to boxes built by the
**new** package. Proving *that* path works is a separate check — C-6 in the plan — and needs a box
built by the real two-step install, not this one.

### 5.5 Bring the node up

On the **server laptop**, with an uplink present:

```sh
sudo tailscale up \
  --ssh \
  --accept-dns=false \
  --advertise-routes=192.168.8.0/24 \
  --hostname=buendia-pilot \
  --authkey=tskey-auth-XXXX
```

Expected: it returns without printing a login URL. **A login URL means the key was rejected** —
usually a tag that does not exist in `tagOwners`, or a key already consumed.

- `--accept-dns=false` stops MagicDNS rewriting the resolver on a box that is offline most of its
  life. It affects **this box's own** name resolution only; the support end still resolves
  `buendia-pilot` normally.
- `--hostname` matches what `setup.sh` generates (`buendia-${SITE_ID:-pilot}`).

> For a box where Tailscale is already up, `sudo tailscale set --ssh` and
> `sudo tailscale set --advertise-routes=...` change these without tearing the session down — which
> is the safer form when you are connected *over* the tunnel.

### 5.6 The support end — the step that is missed twice as often as route approval

On **this workstation**:

```sh
curl -fsSL https://tailscale.com/install.sh | sh     # if not already installed
sudo tailscale up
sudo tailscale set --accept-routes                   # ⚠️ REQUIRED on Linux
```

> ⚠️ **Second correction.** The plan calls route approval "the single most commonly missed step".
> There is a second one stacked behind it: **Linux clients do not use advertised subnet routes unless
> `--accept-routes` is set.** macOS, Windows, Android and tvOS pick them up automatically; Linux does
> not. Your support end is Linux. Without this, R8a fails with everything on the server side correct,
> and the time goes into debugging the wrong end.

### 5.7 Verify the tailnet before running any case

Five checks. Each one catches a misconfiguration that would otherwise surface as a confusing failure
several cases later.

```sh
# --- on the SERVER laptop ---

# 1. Up, tagged, and NOT ephemeral.
tailscale status --json | grep -E '"(Online|Tags|Self)"' -A3
tailscale status --json | python3 -c \
  'import json,sys; d=json.load(sys.stdin)["Self"]; \
   print("tags:", d.get("Tags")); print("keyexpiry:", d.get("KeyExpiry")); \
   print("exit-node/ephemeral flags:", d.get("ExitNodeOption"))'
#   expect tags: ['tag:buendia']   and KeyExpiry absent/null (tagged => expiry disabled)

# 2. The route is being advertised AND approved.
tailscale status --json | grep -i -A3 'AllowedIPs\|PrimaryRoutes'
#   192.168.8.0/24 must appear as an ALLOWED/primary route, not merely advertised.
#   If it is advertised but not allowed, autoApprovers did not fire — approve it by hand:
#   admin console -> Machines -> the node -> Subnets -> Edit -> approve -> Save

# 3. Forwarding is on, or the subnet route carries nothing.
sysctl net.ipv4.ip_forward
#   expect 1. Docker normally enables it globally; if it is 0, Tailscale's own docs say to add
#   a drop-in: echo 'net.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.d/99-tailscale.conf

# 4. The resolver was not hijacked (this is R8b's subject, checked early).
resolvectl status | grep -c 100.100.100.53      # expect 0

# --- on the SUPPORT end ---

# 5. The node is visible, reachable, and SSH is actually granted.
tailscale status | grep buendia-pilot
tailscale ping buendia-pilot
ssh root@buendia-pilot 'hostname; uptime'
#   A refusal here with everything else green means the `ssh` policy block is wrong —
#   most likely dst is autogroup:self instead of tag:buendia.
```

Only when all five pass is the tailnet ready. **These are setup checks, not test cases** — R8 and
R8a are still run properly, from a genuinely separate internet connection, in Session 3.

---

## 6. Session 2 — Phase 1, bench dual-homed  *(R0–R7, ~3 h)*

Plan §2. Uplink is the **phone hotspot**; the router's WAN stays unplugged.

Before starting, have ready and in reach:

- the **foreign-network witness**, already joined to the phone hotspot;
- the **LAN witness**, with R3's loop running in a terminal you can see throughout — start it first
  and leave it running across every case in this phase, since its value is the *unbroken* run;
- the **spare Beryl AX**, powered but not configured, for R6;
- a note of the laptop's Wi-Fi address (`ip -br addr`), which is the address the witness uses — **not**
  `192.168.8.10`.

Order: R0, R0a, R0b (binding), then R1, R2, R2a (dual-homing and routing), then **R4 with its control
first** (plan §2.1 — a negative test without its positive control proves nothing), then R5 (needs a
reboot), R6 (needs the Beryl), R7.

R7 references the tunnel, so either run it after Session 3 or, since the tailnet is already up from
§5, run it here with the two ends on the same internet connection — recording that the *reconnect*
behaviour it measures is not affected by the ends sharing a NAT, while R8's result would be.

---

## 6a. Session 2b — TeamViewer, the channel that ships  *(R18–R19, ~20 min)*

Plan §2a has the pass criteria. This is the order to run them in and what to have ready.

**How TeamViewer is run is MSF's to decide** (settled 2026-09-23), and the assumption is **attended
access**: someone on site opens it when support is needed. So there is nothing here about unattended
access, autologin, or surviving a reboot untouched — see the withdrawal note in plan §2a. What is left
is ours: that the port rebinding does not defeat a supporter who *has* a session, and that our stack
does not care whether TeamViewer is running.

You need: TeamViewer installed on the bench box (your own account is fine here) and a second machine to
connect *from*. Do this after §6, so the box is already carrying the new bindings.

```sh
# R18 first — it is 30 seconds and it is the one that will bite a supporter who knows the old box.
# On the server laptop, inside a TeamViewer session (or locally, same thing):
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:9000/openmrs/
#   expect 000 / connection refused — localhost NO LONGER answers once LAN_BIND is set
curl -s -o /dev/null -w '%{http_code}\n' http://192.168.8.10:9000/openmrs/
#   expect 200 — this is the URL the support runbook must carry (see deploy/README)
```

Then **R19**: with R3's clinical loop running from the tablet, start TeamViewer, open a session from
the second machine, close it, and quit TeamViewer. The loop must not break, `docker compose ps` must be
unchanged, and:

```sh
sudo ./tools/buendia-uplink.sh          # with TeamViewer running, then again with it stopped
#   expect the same connection picture both times, and "installed but not running" reported
#   NEUTRALLY — under attended access that is the normal state, not a fault
```

⚠️ **R18 should still be repeated at MSF staging on their build**, since a bench pass on your own
machine does not transfer. R19 is ours alone and does not need repeating there.

**Worth knowing while you are here:** attended access means nobody can look at a sick server unless
somebody on site opens TeamViewer — so no out-of-hours diagnosis, and none at all while the site is
unreachable by phone. That is accepted, and it is why R5 (boots with the cable out) and the offline USB
diagnostic dump carry more weight than they look like they should.

---

## 7. Session 3 — Phase 2, the tunnel rehearsal  *(PARKED — optional; R8–R11, ~2 h)*

> Requires §5 done and two genuinely separate internet connections. Off the critical path.

Plan §3. **Do the §0 separation assertion first and paste both public IPs into the log** — this is
the rehearsal the deployment plan has carried since July, and the whole value of it is that the two
ends are genuinely apart.

`tailscale up` is already done from §5.5, so R8 is about proving it works *across separate networks*,
not about first-time registration. If you want R8 to be a true cold start, run
`sudo tailscale logout` on the server first and re-register with the key at the top of the case.

R11(c) — the ≥72 h power-off — starts here and finishes next week. Begin it at the end of this
session so the wall clock runs while you do other work.

---

## 8. Session 4 — Phase 3, USB tethering  *(R13–R14, ~1 h)*

Plan §4. The fallback path, and the one most likely to be used in practice.

Confirm the cable carries data before blaming the configuration: `nmcli device status` must show a
new device appear within a couple of seconds of enabling USB tethering on the phone. A charge-only
cable shows nothing at all.

Note the plan's caveat on R13a: R4's positive control may be unavailable on a tether with no second
client, in which case record R4 as **not decisive on this path** and rely on the Path A result plus
`ss -ltnp`. Do not quietly downgrade it to a pass.

---

## 9. Corrections to the plan, found while verifying against current Tailscale docs

The plan was written before these were checked. None invalidate a case; all three change how a case
is executed, and the plan should be amended when results are folded back.

| # | What the plan says | What is actually true |
|---|---|---|
| 1 | R8a treats **route approval** as the single most commonly missed step | True, but a **second** step sits behind it: a **Linux** support end must also run `tailscale set --accept-routes`, or approved routes are never used. Other platforms accept them automatically |
| 2 | R11(a) asserts key expiry is disabled, implying it must be set | A device authenticated with a **tag** has key expiry **disabled by default**. Using a tagged key already satisfies it — verify, do not configure. Distinct from the auth key's own 90-day maximum |
| 3 | `tailscale up --ssh` (still valid) | `tailscale set --ssh` is the documented way to change it on a **running** node without dropping the session — which matters when you are connected over the tunnel you are modifying |

A fourth, not a correction but a trap worth recording: a new tailnet's **default SSH rule targets
`autogroup:self`, which never matches a tagged node**. Tailscale SSH then appears enabled on the
server and grants nothing. §5.2's policy is written to avoid it.

---

## 10. Results

Record against the plan's §9 matrix — same case IDs, same shape. Results go in a
**`docs/FIELD-PILOT-WS7-BENCH-LOG.md`** committed to the repo, following
`FIELD-PILOT-WS8-BENCH-LOG.md`'s precedent: the WS-8 log exists in the repo because its first version
lived in `/tmp` and was lost to a reboot.

Capture, for each case: the command, its **actual output** (not "passed"), and for the negative tests
the exit codes. A pass recorded without its evidence cannot be defended when MSF asks.

| Case | Result | Evidence / note |
|---|---|---|
| Gate — `ip_nonlocal_bind` fix binds | ⬜ | |
| §3 — upgrade reached `GO`, data intact | ⬜ | |
| §4 — tablet installed, synced, clinical round trip | ⬜ | |
| **R18** — OpenMRS UI reachable inside a TeamViewer session | ⬜ | |
| **R19** — stack indifferent to TeamViewer start/stop | ⬜ | |
| ~~R16 / R17~~ — withdrawn 2026-09-23 (attended access; MSF's to decide) | ❌ | |
| §5.7 — tailnet ready (5 checks) | 🅿️ parked | |
| R0 / R0a / R0b | ⬜ | |
| R1 / R2 / R2a | ⬜ | |
| R3 | ⬜ | |
| **R4** (+ positive control) | ⬜ | |
| R5 / R6 / R7 | ⬜ | |
| R8 / R8a / R8b / R8c / R8d | 🅿️ parked | |
| R9 / R10 / R10a | 🅿️ parked | |
| R11 (a/b/c) | 🅿️ parked | |
| R13 / R13a / R14 | ⬜ | |

Then close out per plan §7 — progress doc, new config questions, the D1–D6 defects tracked as work,
and `pilot-checkpoint`. **Wipe the test data before anything ships** (C1).
