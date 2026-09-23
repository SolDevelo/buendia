# Field Pilot — WS-7 Remote Access: Test Plan

**Date:** 2026-09-22 · **Owner:** SolDevelo · **Status:** ⬜ not started — this is the plan, written
before execution.

> ### ⚠️ Scope change, 2026-09-22 — the channel is settled; this plan's centre of gravity moved
>
> **MSF installed TeamViewer on the server laptop themselves**, joined that laptop to their corporate
> Wi-Fi while it stayed wired to our router, and confirmed both that the tablets kept working and that
> TeamViewer access worked. A person on site can reboot the machine and make sure it is up. That is the
> pilot's remote-support channel; continuation beyond the pilot will be judged on experience.
>
> - **Phase 2 (R8–R11) — the Tailscale tunnel rehearsal — is PARKED.** It is kept intact and runnable,
>   not deleted, for whoever picks the tunnel up if the pilot shows TeamViewer is not enough (anything
>   **scriptable**, or a session with **nobody at the keyboard**). It is off the shipping critical path.
> - **Everything else matters more than before, not less.** Dual-homing on a foreign network is now the
>   *normal operating condition*, not a contingency — so the gate, the upgrade, the tablet section and
>   all of Phase 1 stand. **R4, the negative test, is the single most important case in this document**:
>   MSF's laptop has *already* sat on their corporate network with `:9000` and `:9001` published on
>   `0.0.0.0`, serving patient data behind one well-known account alongside an APK that carries the
>   server password. That is a demonstrated exposure, not a hypothetical one.
> - **New on the critical path: R18 and R19** (§2a), covering the little TeamViewer leaves for us to
>   prove. **R16 and R17 were withdrawn on 2026-09-23**: *how* TeamViewer is run is MSF's to decide, and
>   the working assumption is **attended access** — someone on site opens it when support is needed.
> - **R12** (corporate Wi-Fi association) is already **evidenced** by MSF's test. It stays as a formal
>   case so the result is recorded against a known build, not to discover the answer.

**What this closes.** **WS-7's remote-support capability** (`FIELD-PILOT-DEPLOYMENT-PLAN.md` §3.5 / §4),
the one workstream long marked *"not started — and never tested"*. Two thirds of that is now settled by
MSF's own test and by the safe-dual-homing work in the package under test; the remaining third — the
Tailscale rehearsal the plan has carried since 2026-07-30 — is preserved here in full, parked.

**The topology decision this plan tests (2026-09-22).** The uplink lands on the **server laptop**,
not on the router:

- **Path A (primary) — the laptop joins a third-party Wi-Fi**: the site's own Wi-Fi, MSF's corporate
  Wi-Fi, or a phone hotspot.
- **Path B (fallback) — a phone USB-tethered to the laptop.**

**Why not the router.** Router-side uplinks (repeater mode, a cable into the WAN port, a USB
tether/SIM on the router) are *operationally* cleaner — the laptop stays single-homed and nothing is
exposed — but they are **PSK-only**: GL.iNet's repeater UI does not offer 802.1X as a client. MSF's
corporate Wi-Fi is near-certainly WPA-Enterprise, and the site may have neither a spare cable nor a
PSK we are given. So A and B are the only two paths that work everywhere, and they are the ones that
must be proven. Router-side uplinks remain available where the site allows them, are strictly easier,
and are **out of scope here** beyond case R15.

**What the laptop-side uplink costs, and therefore what this plan is really about.** Dual-homing a
box that holds patient data is the whole risk. The interesting tests here are **negative** — proving
that nothing on the clinical stack becomes reachable from the foreign network — and they are weighted
accordingly.

> ⚠️ **C1 has narrowed.** `FIELD-PILOT-MSF-CONFIG-REQUESTS.md` C1 (data-protection sign-off) had two
> halves. The **remote-access** half largely dissolves: the channel is MSF's own tool, on MSF's own
> account, approved by their own IT, so the access decision sits with the data owner and they have made
> it — though their written confirmation is still worth having. The **data-export** half is untouched and
> still gates taking clinical data off the kit. Every case below runs against the **seeded baseline or
> synthetic data**; anything written during testing is disposable and **must be wiped before shipping**.

---

## 0. Machines, roles, and the one condition that makes the rehearsal valid

| Role | Machine | In this exercise |
|---|---|---|
| **Support end** | this workstation | Stands in for SolDevelo support. **Must be on a genuinely separate internet connection** — a mobile hotspot — for R8 onward. Holds the repo and the tailnet admin access. |
| **Server under test** | the test laptop (Ubuntu 26.04, `192.168.8.10`) | Cabled to the Flint 2. Joins the foreign Wi-Fi (A) or takes the USB tether (B). Nothing is built here. |
| **Foreign-network witness** | a second device (phone, tablet or spare laptop) **on the same foreign Wi-Fi as the server** | **The instrument for every negative test.** Without it, "not exposed" is a claim about configuration rather than an observation. |
| **LAN witness** | a tablet, or the dev box joined to `MSF-Buendia` | Proves the clinical path stays up throughout. |
| **Router** | Flint 2 (GL-MT6000), configured per WS-8 | Unchanged by this exercise. Its WAN stays **unplugged** — the uplink is on the laptop. |
| **Spare Beryl AX** | the bench/spare unit | Used **as the hostile network** in R6: its factory LAN is `192.168.8.1/24`, which is exactly the collision case. |

> ⚠️ **The condition that makes or breaks the whole exercise: the two ends must be on genuinely
> separate internet connections.** A tunnel "working" between two machines that share a LAN, a NAT, or
> an ISP proves nothing about a server in Bunia and a laptop in Gdańsk. **Assert it, do not assume it:**
>
> ```sh
> curl -s https://ifconfig.me                 # run on BOTH ends — the two public IPs must DIFFER
> ping -c2 <other end's LAN address>          # must FAIL — no local path between them
> ip route get <other end's public IP>        # must leave via the uplink, not a local interface
> ```
>
> If the public IPs match, both ends are behind the same NAT and every result from R8 onward is void.

### 0.1 The implementation this plan tests

Built by the parallel `deploy/**` work; every case below is written against these names.

| Name | What it does | Why it exists |
|---|---|---|
| `LAN_BIND` | Publishes `9000`/`9001` on the LAN address instead of `0.0.0.0` | Without it, joining any foreign Wi-Fi exposes OpenMRS (patient data, one known account) and the APK (which carries the server password as a plain string resource) to everyone on that network |
| `NET_ROUTE_METRIC` (default `1000`) | Metric on the generated wired default route | NetworkManager's automatic metrics are per device type — ethernet 100, Wi-Fi 600 — so an unmetered wired default route via `192.168.8.1` **wins and black-holes the internet** even with a working uplink |
| `net.ipv4.ip_nonlocal_bind=1` | Lets Docker bind `192.168.8.10` when the address is absent | A laptop booted with the cable out would otherwise fail to publish the ports and the stack would not start |
| `deploy/tools/buendia-uplink.sh` | Status and diagnosis: which interface holds the default route, is the internet reachable, is the tunnel up, does the uplink subnet collide | Turns a support phone call into "read me the four lines" |
| `tailscale up --ssh --accept-dns=false --advertise-routes=192.168.8.0/24` | The tunnel | `--ssh` removes key distribution; `--accept-dns=false` stops MagicDNS rewriting the resolver on a box that is offline most of its life; `--advertise-routes` reaches the router UI and the tablet subnet through the same tunnel |

---

## 1. What this exercise proves — and what it must not be read as proving

**Proves:**

- That the pilot's **actual** channel works on the terms it is relied upon for: with a TeamViewer
  session open, the supporter can reach the OpenMRS web UI at the documented address, and our stack is
  indifferent to TeamViewer being started or stopped (R18, R19).
- *(Parked)* That a server laptop on a foreign network is reachable over a tunnel it dialled out itself,
  with nothing inbound configured anywhere.
- That the same dual-homing does **not** expose the clinical stack to that foreign network — observed
  from a device on it, against a positive control.
- That clinical operation is indifferent to the uplink appearing, failing, or being pulled mid-session.
- That the stack survives a boot with no cable, and recovers when the cable returns.
- That the failure modes we can name in advance — default-route capture, subnet collision, blocked
  UDP, node-key expiry — are each either prevented or reported, not silent.

**Does not prove:**

| Not proven | Why | Blocked on |
|---|---|---|
| That **MSF's corporate Wi-Fi** behaves the same for a *build we ship* | Their 2026-09-22 test proved association and TeamViewer access on **their** setup — real evidence, but not against the package version under test, and captive-portal/NAC behaviour may differ per site. R12 records it against a known build | MSF staging access |
| That **TeamViewer's account security** is adequate | Two-factor, the device allowlist, who holds access and how ours is revoked are MSF IT policy, not technical properties we can test | MSF IT |
| Anything about the **site's** Wi-Fi in DRC | Not visited | Site |
| That MSF **permits** a SolDevelo server on their network | Policy, not a technical property | C1 / MSF IT |
| DERP relay latency and reachability **from DRC** | Tailscale's relay selection is geographic; an EU bench says nothing about Kinshasa/Bunia egress | Site |
| That the **third-party coordination plane** is acceptable | *(Parked with Phase 2.)* A governance question the tests cannot answer; if reopened, the comparison is against Headscale, and `deploy/remote-access-spike/` records a measured self-hosted alternative | C1 |
| A **CSV data export** | `buendia-export.sh` still has `DataExportServlet` as a `TODO` and falls back to `mysqldump`. With TeamViewer there is also no unattended pull at all — a human saves and transfers the file | WS-3/omod work (D2) |
| Multi-week unattended behaviour | R11 simulates key expiry rather than waiting for it | Time |

A green run here is a green run for *the mechanism on a bench*. Say so in the write-up — and note
specifically that **R18 should be repeated on MSF's own build at staging**, because a bench pass on our
own machine does not transfer. How TeamViewer itself is run — who opens it, under which account, with
what session policy — is **not tested here at all**: it is MSF's to decide (see §2a).

---

## 2. Phase 1 — Bench, dual-homed  *(~3 h; Poland; no second internet connection needed yet)*

Uplink for this phase is a **phone hotspot**, which stands in for "some third-party Wi-Fi". The
router's WAN stays unplugged throughout.

| # | Case | Pass criterion — and the command that decides it |
|---|---|---|
| **R0** | **`LAN_BIND` is actually in effect** | `ss -ltnp \| grep -E ':(9000\|9001)'` shows **`192.168.8.10:9000`** and `192.168.8.10:9001` and **no `0.0.0.0:` line**. ⚠️ `docker compose config` is not evidence — read the listening sockets |
| **R0a** | The go/no-go still passes with the bind narrowed | `tools/buendia-verify.sh --host 192.168.8.10` → **GO**, all checks. ⚠️ `buendia-verify.sh` defaults to `HOST=127.0.0.1`, which **no longer answers** once `LAN_BIND` is set. `setup.sh` must pass `--host`; if this case fails on the loopback default, it is a defect in the caller, not in the bind |
| **R0b** | `127.0.0.1:9000` **stops** answering | `curl --max-time 3 http://127.0.0.1:9000/openmrs/` fails. **Expected, and recorded deliberately** so nobody later reads it as a regression and "fixes" it by rebinding to `0.0.0.0` |
| **R1** | The laptop associates with the foreign Wi-Fi while keeping `192.168.8.10` | `ip -br addr` shows the static `192.168.8.10/24` on the wired interface **and** a DHCP address on `wl*`. Both present simultaneously |
| **R2** | **The internet actually works** — the default-route fix | `ip route show default` lists the wired route with **`metric 1000`** and the Wi-Fi route below it; `ip route get 1.1.1.1` resolves **via the Wi-Fi interface**; `curl -fsS -o /dev/null -w '%{http_code}\n' https://connectivity-check.ubuntu.com/` returns `204`. ⚠️ All three, not just the last: a working `curl` with the wrong route ordering is luck, and it reverses the moment the router's WAN is touched |
| **R2a** | Name resolution is not captured by the offline router | `resolvectl query ntp.ubuntu.com` succeeds while `DNS_SERVERS=192.168.8.1` is configured on the wired link. ⚠️ `systemd-resolved` sends unmatched queries to **every** link that has DNS and no route-only domain, taking the first success; the router SERVFAILs fast when it has no uplink, so this normally passes — record the **latency**, because a slow pass here is the signature of the query going to the router first |
| **R3** | **Clinical operation is unaffected** across the whole phase | From the LAN witness, run for the duration: `while :; do curl -s -o /dev/null -w "%{http_code} " --max-time 3 http://192.168.8.10:9000/openmrs/ws/rest/v1/session; sleep 2; done`. Must be an **unbroken run of `200`** across joining the Wi-Fi, losing it, and rejoining. A single non-200 is a fail worth chasing |
| **R4** | 🔴 **THE NEGATIVE TEST — the stack is not reachable from the foreign network** | Four steps, in order, from the **foreign-network witness**. See §2.1 — a negative test without its positive control proves nothing |
| **R5** | **Boot with the ethernet cable unplugged** | Unplug the cable, `reboot`. Then: `sysctl net.ipv4.ip_nonlocal_bind` is **`1`** (persisted by a drop-in, not a live `sysctl -w`); `docker compose ps` shows every service **healthy**; `ss -ltn` shows `192.168.8.10:9000` bound **although the address is not on any interface** (`ip -br addr` confirms its absence). Then plug the cable in: a LAN device reaches `http://192.168.8.10:9000/openmrs/` within 30 s **with no restart of anything** |
| **R6** | **Subnet collision is caught, not suffered** | Use the spare **Beryl AX at its factory default** as the foreign Wi-Fi — its LAN is `192.168.8.1/24`, so joining it hands the laptop a `192.168.8.x` address while the wired NIC holds `192.168.8.10/24`. `deploy/tools/buendia-uplink.sh` must **exit non-zero and name the overlap** in plain words. Also record the clinical symptom it is protecting against: with both links in the same /24, check whether the LAN witness still reaches `.10` (expect breakage or asymmetry — capture whichever happens, because that is what the site would experience) |
| **R7** | **Uplink pulled mid-session** | With SSH live over the tunnel, disable the Wi-Fi. The session drops (expected); `docker compose ps` unchanged; R3's loop unbroken; and when the Wi-Fi is re-enabled the node comes back **with no operator action on the server** — `tailscale status` from the support end shows it online again. Record the reconnect time |

### 2.1 R4 in full — the negative test, with its control

Run every step from the **foreign-network witness**, using the laptop's **Wi-Fi** address (`W`, read
from `ip -br addr`), never its `192.168.8.10`.

1. **Positive control first.** On the laptop: `python3 -m http.server 8099 --bind 0.0.0.0`. From the
   witness: `curl --max-time 5 http://W:8099/` must **succeed**.
   ⚠️ Without this, a "pass" may only mean the access point isolates its clients, and the same laptop
   on a non-isolating network would be wide open. **If the control fails, R4 is void** — find a
   network that does not isolate clients, or the test is theatre.
2. **The assertion.** `curl --max-time 5 http://W:9000/openmrs/` and `curl --max-time 5 http://W:9001/latest.apk`
   must both **fail** (refused or timed out). Capture the actual curl exit codes as evidence.
3. **Sweep the box, not just the two ports.** `nmap -Pn -p 22,80,443,3306,9000,9001 W` from the
   witness. ⚠️ **Port 22 is a live question:** `setup.sh` installs `openssh-client`, not the server,
   but whether Ubuntu's `openssh-server` is present and listening on `0.0.0.0` depends on the base
   image. If it is open here, that is an exposure in its own right — and an unnecessary one, because
   **Tailscale SSH does not need `sshd` published**. Record it against D3.
4. **Prove the clinical path still works at the same instant.** From the LAN witness:
   `curl -s -o /dev/null -w '%{http_code}\n' http://192.168.8.10:9000/openmrs/ws/rest/v1/session` → `200`;
   and on the laptop itself `curl -s -o /dev/null -w '%{http_code}\n' http://192.168.8.10:9000/openmrs/ws/rest/v1/session` → `200`.
   Both must hold **while** step 2 is failing. A pass on step 2 with a broken step 4 is not a pass;
   it is an outage.

---

## 2a. TeamViewer — the channel that actually ships  *(R18–R19; ~20 min; Poland)*

MSF proved TeamViewer *works*. **How it is run is theirs to decide** (settled 2026-09-23), and the
working assumption is **attended access**: when support is needed, someone on site opens TeamViewer. We
do not require unattended access, and we do not require the machine to be left permanently logged in and
reachable. That removes most of what this section used to test, and leaves only what is genuinely ours:
that a supporter who *has* a session open is not defeated by the port rebinding, and that our stack does
not care whether TeamViewer is running.

> **Withdrawn 2026-09-23 — R16 (survives a reboot, unattended) and R17 (reachable with nobody at the
> keyboard).** Both tested properties of *unattended* access, which is no longer assumed and may not be
> what MSF wants. They are not ours to verify: the account, its policy and any unattended password are
> MSF's. **The autologin question dies with them** — R16's likely failure was the box sitting at the
> login greeter after a reboot, whose only fix is desktop autologin, i.e. an unattended, permanently
> logged-in desktop holding patient data. We considered that trade and **chose not to take it**; with
> attended access it never arises. Recorded here so it is not rediscovered and quietly accepted later.

| # | Case | Pass criterion — and what decides it |
|---|---|---|
| ~~R16~~ | ~~Survives a reboot, unattended~~ | **Withdrawn 2026-09-23** — see the note above |
| ~~R17~~ | ~~Reachable with nobody at the keyboard~~ | **Withdrawn 2026-09-23** — see the note above |
| **R18** | **The supporter can reach the OpenMRS web UI from inside the session** | With `LAN_BIND` set, `localhost:9000` **no longer answers** — the port is bound to the LAN address. Pass: from the server's own browser inside the TeamViewer session, the URL documented in `deploy/README` returns the OpenMRS login page. ⚠️ This is the most likely way the new package version surprises a supporter who knows the old box: a habit that used to work now fails, and the failure looks like a broken server rather than a changed binding. It belongs in the support runbook, not only in a test result |
| **R19** | **The stack is indifferent to TeamViewer starting and stopping** | With the clinical loop of R3 running from a tablet, start TeamViewer, open a session, close it, and quit TeamViewer. Pass: the loop is unbroken throughout, `docker compose ps` is unchanged, and `buendia-uplink.sh` reports the same connection picture with TeamViewer stopped as with it running — reporting it **neutrally**, since "installed but not running" is the *expected* steady state under attended access, not a finding |

**Three things to record rather than test**, because they are MSF's to own and ours only to raise:
**how the session is opened** — we assume someone on site starts TeamViewer when support is needed, and
that assumption is put to MSF for confirmation rather than tested here (**B8**).
TeamViewer is an inbound-capable remote desktop on a machine holding patient data, so account security —
two-factor, the device allowlist, who in MSF holds access, and how SolDevelo's access is granted and
later revoked — is a policy question for MSF's IT. And TeamViewer is proprietary and commercially
licensed; confirm the licence covers this use, since free-tier commercial-use detection would strand
support at the worst possible moment.

**What attended access costs, stated plainly.** We cannot look at a sick server unless somebody is on
site, available, and able to open TeamViewer — so nothing can be diagnosed out of hours, or while the
site cannot be reached by phone. That is an accepted constraint, not a defect, and it raises the value of
two things already in the design: the **offline USB diagnostic dump**, which needs no connectivity and no
supporter, and the server's **self-recovery after a power cut** (`restart: unless-stopped`, Docker enabled
at boot, static addressing applied by the setup script), which is what keeps an unreachable site from
becoming an outage. R5 and R19 are the cases that keep both honest.

---

## 3. Phase 2 — The tunnel rehearsal  *(PARKED 2026-09-22; ~2 h; Poland; needs two separate internet connections)*

> **Parked, not deleted.** TeamViewer is the pilot's channel (see the scope change at the top), so none
> of R8–R11 is on the shipping critical path and none of them gates a release. Everything below is kept
> current and runnable so that picking the tunnel back up is a matter of executing this section rather
> than rediscovering it. Run it if the pilot shows TeamViewer is not enough — or opportunistically, if a
> bench afternoon is free, since the tunnel's value is precisely the scriptable access TeamViewer cannot
> give. If C1's remote-access half is ever reopened, the honest comparison is against **Headscale**, not
> against a hand-rolled tunnel: see `deploy/remote-access-spike/` for the measured alternative.

This is the rehearsal the deployment plan has carried since July. Do §0's separation assertion first
and record both public IPs in the log.

| # | Case | Pass criterion — and the command that decides it |
|---|---|---|
| **R8** | **The tunnel establishes and carries a session** | Support end on a mobile hotspot; server on a different uplink. On the server: `tailscale up --ssh --accept-dns=false --advertise-routes=192.168.8.0/24 --hostname buendia-<site>` with a **tagged, reusable, non-ephemeral** auth key. Then, from the support end: `tailscale status` lists the node; `tailscale ping buendia-<site>` succeeds; `ssh buendia@buendia-<site>` opens a shell **with no SSH key having been distributed** |
| **R8a** | ⚠️ **The advertised route is approved** | `--advertise-routes` does **nothing** until the route is approved in the tailnet admin console. This is the single most commonly missed step. Pass: from the support end, `curl -s -o /dev/null -w '%{http_code}\n' http://192.168.8.1/` (the **router's** UI) returns a response, and `http://192.168.8.10:9000/openmrs/ws/rest/v1/session` returns `200` — both **through the tunnel**, from a machine that has no other path to that subnet |
| **R8b** | **The resolver was not touched** | On the server: `resolvectl status` shows **no** `100.100.100.53`, and `/etc/resolv.conf` is unchanged from before `tailscale up`. This is what `--accept-dns=false` buys, and it matters because the box spends most of its life offline |
| **R8c** | **An export can be pulled over the tunnel** | Over the SSH session: `sudo /opt/buendia/tools/buendia-export.sh /tmp` then `scp` it back. ⚠️ Records a **`mysqldump`**, not the intended CSV — `buendia-export.sh`'s `DataExportServlet` path is still a `TODO` (D2). Run it against the **seeded baseline**, and delete both copies afterwards (C1) |
| **R8d** | **The go/no-go runs remotely** | `tools/buendia-verify.sh --host 192.168.8.10` executed over the tunnel returns **GO**. This is the actual support capability being sold: diagnose without anyone on site |
| **R9** | **The clock chain closes** | With the uplink up: `chronyc tracking` on the server shows **Leap status: Normal**, a real upstream reference (an `ntp.ubuntu.com` pool member) and **stratum < 10** — i.e. the server is genuinely disciplined rather than asserting `local stratum 10`. Then `chronyc clients` shows the tablet's address incrementing. ⚠️ Assert that the router's `/ntp.org/` intercept does **not** capture the server's own sync: Ubuntu's pools are `*.ntp.ubuntu.com`, which the override does not match — confirm rather than assume, with `chronyc sources -v` |
| **R10** | **UDP blocked → the relay fallback actually engages** | Baseline: `tailscale netcheck` (record UDP status and the nearest DERP). Then, on the server, deliberately break direct connectivity: `sudo iptables -I OUTPUT -p udp --dport 41641 -j DROP; sudo iptables -I OUTPUT -p udp --dport 3478 -j DROP`. Pass: `tailscale status` shows the peer as **`relay "<derp>"`** rather than `direct`, `tailscale ping buendia-<site>` reports it is going **via DERP**, and **the SSH session still works**. ⚠️ Prove it, do not assume it — "Tailscale falls back to TCP/443" is the reason this transport was chosen over plain WireGuard, so it is exactly the claim that must be tested. Remove the rules afterwards and confirm it returns to `direct` |
| **R10a** | What happens if **443 to DERP is also blocked** | Block TCP/443 to the DERP host and confirm the tunnel goes down **cleanly** — clinical operation unaffected, `buendia-uplink.sh` reports the tunnel down rather than claiming health. This is the honest bound on the transport, and it is what triggers contingency C-4 |
| **R11** | **Node-key expiry — tested without waiting months** | Three parts. (a) **Assert the shipping state:** `tailscale status --json` shows the node's key expiry **disabled/null**, and the node is **not ephemeral** (an ephemeral node disappears from the tailnet when it goes offline — catastrophic for a box that is offline by design). (b) **Prove the failure mode is real**, on a throwaway node, not on the pilot server: create a second node with the admin console's shortest expiry, let it expire, and confirm it **cannot reconnect without re-auth** — a box in DRC that needs a browser login is a box we have lost. (c) **Prove reconnection after a long gap:** power the server off for a weekend (≥72 h), boot it with the uplink present, and confirm it re-registers with **no operator action** |

---

## 4. Phase 3 — Path B, USB tethering  *(~1 h; Poland)*

The fallback, and in practice the shortest runbook line: *plug the phone in, turn on USB tethering.*
No SSID, no passphrase, no captive portal, no 802.1X, no corporate policy.

| # | Case | Pass criterion — and the command that decides it |
|---|---|---|
| **R13** | The tether is picked up and **beats the wired default route** | Plug the phone in, enable USB tethering. `nmcli device status` shows a new device (`usb0` / `enp0s20u*`) as `connected`; `ip route show default` lists it at NetworkManager's automatic ethernet metric (**100**) against the wired link's **1000**; `ip route get 1.1.1.1` leaves via the tether. ⚠️ The tether presents as **ethernet**, not Wi-Fi — this is precisely why the wired metric must be 1000 rather than merely "higher than Wi-Fi's 600" |
| **R13a** | The abbreviated battery on this path | Re-run **R3** (clinical loop unbroken), **R4** (negative test, witness now on the phone's hotspot side — note the control from step 1 may be unavailable on a USB tether with no other clients, in which case record R4 as **not decisive on this path** and rely on the R4 result from Path A plus `ss -ltnp`), and **R8** (tunnel establishes, SSH carries) |
| **R14** | **Unplugging the phone leaves a clean state** | `ip route show default` no longer lists the tether and holds **no stale route to a dead gateway**; `docker compose ps` unchanged; R3's loop unbroken across the unplug; `buendia-uplink.sh` reports **no uplink** without erroring; and re-plugging restores the tunnel with no operator action |

---

## 5. Phase 4 — MSF staging  *(cannot be run in Poland)*

The pilot's standing rule is that **nothing untestable in Switzerland may ship**. These cases are the
reason a staging slot is needed rather than a bench sign-off.

| # | Case | Pass criterion |
|---|---|---|
| **R12** | **MSF corporate Wi-Fi — association** | The laptop associates with the corporate SSID. If it is **802.1X/EAP**, record the exact EAP method, whether a certificate is required, and **whose credential is used** — ⚠️ see C-1; a named person's account on a shared server box is both an access-control leak and a support liability |
| **R12a** | **Captive portal, if present** | Someone clicks through on the laptop's own browser (it has a screen — this is a Path A advantage over every router-side option). Record **how long the authorisation lasts**: a portal that re-authenticates every few hours silently kills the tunnel, and that is C-2 |
| **R12b** | **The full battery on that network** | Re-run **R2** (internet works), **R4** (negative test, with the control — a corporate network is exactly where an exposed `:9000` would matter most), **R8** (tunnel), **R10** (relay fallback, since corporate egress filtering is the likeliest place for UDP to be blocked) |
| **R12c** | **Device registration / NAC** | Record whether the network requires the MAC to be registered, and whether MDM/NAC posture checks refuse an unmanaged Linux box. This can invalidate Path A outright at MSF and is the trigger for falling back to Path B |
| **R15** | **Router-side uplink, opportunistically** | If a spare cable or a PSK Wi-Fi exists at staging, plug the WAN port in (or repeat the site Wi-Fi) and confirm the laptop stays single-homed and everything still works with `LAN_BIND` unchanged. Half an hour, and it retires the easiest path as a documented option. ⚠️ Re-running `configure-router.sh` after putting the router into repeater mode would convert the station interface into an access point — do not re-run it on a repeating router until that is fixed |

**Confirmable only on site:** DERP reachability and latency from DRC; whether the site's Wi-Fi exists,
is PSK, and reaches where the server sits; whether a wired drop is available.

---

## 6. Contingencies (planned branches)

**C-1 — corporate Wi-Fi is 802.1X with per-user credentials.** A personal account on an unattended
shared server is not acceptable, and MSF IT may not issue a service account. → **Path B**, and ask for
it early as a config question rather than discovering it at staging.

**C-2 — captive portal re-authenticates periodically.** The tunnel dies silently hours after everyone
has left. Cheap mitigation: `buendia-uplink.sh` run on a timer that records the last successful
outbound reachability, so the failure is visible in the next diagnostics dump. Durable mitigation:
Path B, which has no portal.

**C-3 — MSF IT forbids the server on the corporate network.** → Path B only. Nothing else changes.

**C-4 — Tailscale is blocked outright** (SNI filtering, no 443 egress to DERP). R10a is the test that
distinguishes this from an ordinary NAT problem. → Headscale on a SolDevelo VPS (same client, our
control plane — which also answers C1's third-party objection), or `autossh` over 443. The plan is
deliberately written around "server-initiated dial-out + SSH" so the transport swaps without rework.

**C-5 — the uplink hands out `192.168.8.x`.** R6. We **cannot** renumber our LAN — every tablet APK
bakes in `192.168.8.10` — so the remedy is a different uplink (the tether), not a reconfiguration.
`buendia-uplink.sh` must refuse loudly rather than let it half-work.

**C-6 — `tailscaled` is not installed on the shipping path.** See D1. The check is
`command -v tailscale` **on a box built by the real two-step install**, not on a dev machine where it
may have arrived by another route.

---

## 7. Phase 5 — Fold back  *(~1 h, non-negotiable)*

Progress doc (WS-7 status, the new §4-style gotchas, refreshed state block); results recorded in a
**`FIELD-PILOT-WS7-BENCH-LOG.md`** in the repo, not a scratchpad — the WS-8 log exists because the
first version of it lived in `/tmp` and was lost to a reboot; new config questions into
`FIELD-PILOT-MSF-CONFIG-REQUESTS.md` (at minimum: corporate Wi-Fi authentication type, whether a
service account can be issued, whether a phone tether is acceptable, and whether a wired drop exists
at the site); the §8 defects tracked as work rather than prose; `pilot-checkpoint` for the close-out.
**Copy §1's "does not prove" table into the progress doc verbatim.**

---

## 8. Defects and open items this exercise exposes

Not test steps. They exist in the tree today and outlive this exercise.

| # | Defect | Fix |
|---|---|---|
| **D1** | **`tailscale` is never installed on the shipping path.** `remote_support()` runs only in the install phase; `--prepare` (the online one) returns before it, and `--finish` is offline where the function warns "not bundled" and returns. `debs/` contains no tailscale package. So the two-step install produces a box with no tunnel binary at all | Install it in the **prepare** phase, and add it to `bundle-debs.sh` so an offline rebuild keeps it |
| **D2** | `buendia-export.sh` has `DataExportServlet` as a `TODO` and falls back to `mysqldump`. The "pull a data export" capability in plan §3.5 is therefore a DB dump, which is a different data-protection conversation | Wire the CSV endpoint, or amend §3.5 to describe what actually ships |
| **D3** | **`sshd` exposure is unassessed.** `setup.sh` installs `openssh-client` only, but whether the base image runs `openssh-server` on `0.0.0.0` is unknown — and on a dual-homed box that is a second exposed surface. Tailscale SSH makes a published `sshd` unnecessary | R4 step 3 measures it; if open, bind it to the LAN address or disable it in favour of Tailscale SSH |
| **D4** | **`buendia-verify.sh` asserts nothing about exposure or the uplink.** A "GO" is silent on whether `:9000` is bound to the world | Add a bind-address check (`ss -ltn` shows no `0.0.0.0:9000`) and an uplink summary line |
| **D5** | **Nothing notices the tunnel has been down for weeks.** Same shape as WS-8's D9: a silent failure with no engineer on site | A timer that records last-successful-dial-out into the diagnostics dump, so the gap is visible when the dump is finally collected |
| **D6** | `.env.example` documents `GATEWAY_IP=192.168.8.1` with no metric and warns against leaving it empty — correct for a router-side uplink, wrong for Path A unless `NET_ROUTE_METRIC` is applied | Ship the metric by default and document the two topologies separately |

---

## 9. Go/no-go summary

Record results here in the same shape as the WS-8 matrix.

| # | Case | Where runnable | Result | Evidence |
|---|---|---|---|---|
| R0 | `LAN_BIND` in effect | Bench PL | ⬜ | |
| R0a | Verify GO with `--host` | Bench PL | ⬜ | |
| R0b | Loopback no longer answers (expected) | Bench PL | ⬜ | |
| R1 | Dual-homed association | Bench PL | ⬜ | |
| R2 | Internet works (route metric) | Bench PL | ⬜ | |
| R2a | Resolution not captured by the router | Bench PL | ⬜ | |
| R3 | Clinical loop unbroken | Bench PL | ⬜ | |
| **R4** | **Stack NOT reachable from foreign net** (+ control) | Bench PL | ⬜ | |
| R5 | Boot with cable unplugged | Bench PL | ⬜ | |
| R6 | Subnet collision caught | Bench PL | ⬜ | |
| R7 | Uplink pulled mid-session | Bench PL | ⬜ | |
| ~~R16~~ | ~~TeamViewer survives a reboot, unattended~~ | — | ❌ withdrawn 2026-09-23 | MSF's to decide; attended access assumed |
| ~~R17~~ | ~~Reachable with nobody at the keyboard~~ | — | ❌ withdrawn 2026-09-23 | as above |
| **R18** | **OpenMRS UI reachable inside the session** | Bench PL | ⬜ | |
| **R19** | **Stack indifferent to TeamViewer start/stop** | Bench PL | ⬜ | |
| R8 | Tunnel establishes, SSH carries | Bench PL (2 uplinks) | 🅿️ parked | |
| R8a | Advertised route approved and usable | Bench PL | 🅿️ parked | |
| R8b | Resolver untouched | Bench PL | 🅿️ parked | |
| R8c | Export pulled over the tunnel | Bench PL | 🅿️ parked | |
| R8d | Remote go/no-go | Bench PL | 🅿️ parked | |
| R9 | Clock chain closes | Bench PL | 🅿️ parked | |
| R10 | UDP blocked → relay engages | Bench PL | 🅿️ parked | |
| R10a | 443 blocked → clean failure | Bench PL | 🅿️ parked | |
| R11 | Key expiry / long offline | Bench PL (+72 h) | 🅿️ parked | |
| R13 | USB tether beats wired route | Bench PL | ⬜ | |
| R13a | Path B abbreviated battery | Bench PL | ⬜ | |
| R14 | Clean state on unplug | Bench PL | ⬜ | |
| R12 | Corporate Wi-Fi association | **MSF staging** | ⬜ | |
| R12a | Captive portal | **MSF staging** | ⬜ | |
| R12b | Full battery on corporate | **MSF staging** | ⬜ | |
| R12c | Device registration / NAC | **MSF staging** | ⬜ | |
| R15 | Router-side uplink (opportunistic) | **MSF staging** | ⬜ | |
| — | DERP latency from DRC | **Site only** | 🅿️ parked | |
| — | Site Wi-Fi exists / is PSK / reaches the server | **Site only** | ⬜ | |

**Exit condition for shipping (revised 2026-09-23):** R0–R7 and R13–R14 pass on the bench; **R18 and R19
pass on the bench**, with R18 repeated on MSF's build at staging; R12–R12c pass at MSF staging
or Path B is adopted as the documented fallback; and the tunnel **ships disabled**
(`ENABLE_REMOTE_SUPPORT=false`). **R8–R11 are parked and do not gate a release.** D1 (tailscale absent on
the shipping path) is fixed in the package under test but, being parked, is no longer a release blocker —
it stays recorded so the tunnel is not picked up later on the false belief that the binary ships.

---

## 10. Effort

| Phase | Work | Effort |
|---|---|---|
| 1 | Bench, dual-homed (R0–R7) | ~3 h |
| 2 | Tunnel rehearsal (R8–R11) | ~2 h, plus a weekend of wall-clock for R11(c) |
| 3 | Path B (R13–R14) | ~1 h |
| 4 | MSF staging (R12–R15) | ~2 h on site at staging |
| 5 | Fold back | ~1 h |
| 8 | Defects D1–D6 | ~0.5 day, separable |

**~1.5 days of bench work**, of which the two irreducible prerequisites are a **second internet
connection** and a **foreign-network witness device**. Neither costs anything; both are the difference
between a result and a claim.
