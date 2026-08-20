# Buendia DRC Field Pilot — Site Network Specification

**From:** SolDevelo · **Date:** 2026-08-10 · **Purpose:** the specification for the Wi-Fi network the
pilot runs on. **SolDevelo supplies this network**; MSF does not need to provide one. Written to be
forwarded alongside `FIELD-PILOT-SERVER-SPEC.md`.

> **Why this is a *specification* and not a shopping list.** The one thing that decides how much
> equipment is needed is the **physical layout of the site**, which we do not know yet. So this document
> fixes the **requirements** (what any device must do) and defines a **family of equipment with three
> coverage tiers**. When the layout is known we pick the tier — or simply add another node from the same
> family, which needs no change to the software, the server or the tablets.

---

## The design: SolDevelo supplies the network

The tablets and the server must sit on **one shared local network**, and nothing in the clinical workflow
needs the Internet. **We supply that network** — our own router, our own addresses, our own Wi-Fi name.
MSF does not need to provide Wi-Fi, and we need no network settings from anyone at the site.

One flat network, `192.168.8.0/24`: the router at `.1`, the server cabled to it at the fixed
`192.168.8.10`, tablets on DHCP, and **the same Wi-Fi name (SSID) on every access point** so a tablet
moves between them without anyone noticing.

**Why this rather than sharing an existing network at the site:**

1. **It is the only arrangement that can be fully tested before it ships.** The pilot's design rule is
   that nothing untestable in Switzerland may travel, because there will be no engineer at the site. When
   the network is ours, the network tested at MSF Switzerland **is** the network the site runs — same
   equipment, same addresses, same configuration.
2. **The tablet app is correct on arrival.** The server's address is built into the app. On our own network
   we choose that address, it is identical in Switzerland and at the site, and **nobody touches a setting
   on any tablet after it arrives.**
3. **It removes a class of failure that is invisible on site and unfixable by us.** On a shared network,
   "client isolation" — a common setting — lets tablets associate perfectly while making the server
   unreachable, with no visible cause. Captive portals and access points on different address ranges fail
   similarly. None of it could be diagnosed from Switzerland or repaired by non-technical staff.
4. **It keeps another team off the critical path.** Sharing a network would require someone who
   administers it to reserve an address and confirm several settings before the kit could ship.

**What this costs, and why we accept it: Wi-Fi coverage is ours to get right.** An existing site network
would presumably already cover the site; ours has to be sized to it. That trade is deliberate, because
coverage is **measurable** (walk it with a tablet), **incrementally fixable** (reposition, or add a node
on the same SSID), and **cheap** (~CHF 100–190 a node) — the opposite of a silent failure. It is also the
reason this document specifies a family rather than a model, and the reason for the layout questions near
the end: they are the one input we cannot look up.

## Important: "our own network" does **not** mean "no Internet"

This is worth stating plainly, because the two things are easy to conflate.

Our router **owns the local network** — it hands out the addresses, the tablets and server join it, and
we configure all of it. Separately, its **WAN (uplink) port is optional** and can be fed from whatever
the site happens to have:

- an Ethernet cable from an existing site network, or
- the site's existing Wi-Fi, joined **as a client** (repeater / "WISP" mode), or
- a cellular SIM, either in a router with a modem or via a USB LTE stick.

In all three cases the tablets and the server stay on **our** network at **our** addresses. The uplink
can be added, removed or fail at any time and **nothing clinical is affected**.

**Why this matters:** the two capabilities that a fully isolated network would lose are

- **tablet clock accuracy** — with an Internet path, Android's normal automatic time works and the
  problem disappears. (This matters clinically: the time recorded against a patient observation comes
  from the tablet, not the server.) Without one, we discipline the tablets from the server instead — see
  hard requirement **2** below, which is why the DNS capability is non-negotiable.
- **remote support** — without any Internet path at the site, a secure support connection is
  *impossible* rather than merely disabled, and the only diagnostic channel is a USB dump plus a phone
  call.

The asymmetry is what makes this the right shape: **an uplink that turns out not to work costs us
nothing**, because clinical operation never uses it — whereas taking our *addresses* from someone else's
network would put the whole deployment at the mercy of its behaviour. We take the upside and decline the
risk.

**Consequence for the equipment choice:** prefer models with a WAN port **and** a wireless client mode,
so the uplink can be either wired or wireless without buying different hardware.

---

## What the network actually has to carry

Worth stating because it removes a whole dimension from the decision:

| | |
|---|---|
| Devices | 5–10 tablets + 1 server |
| Traffic | a few kilobytes of JSON every ~10 seconds per tablet, plus the one-off app download at install |
| Peak | installing the app on several tablets at once — a few tens of MB, once |

**Every device in this document is orders of magnitude beyond what that needs. Wi-Fi speed is not a
selection criterion at all.** The only things that matter are **coverage**, **reliability unattended**,
and the specific capabilities listed below.

---

## Hard requirements

These are the requirements that actually constrain the choice. A device that fails any of them is not a
candidate, however good it looks. Requirements **1** and **2** are the ones that ordinary consumer mesh
kits typically fail.

| # | Requirement | Why |
|---|---|---|
| 1 | **Works fully standalone — no cloud account, no phone app that needs the Internet, no Internet needed to configure or to boot.** Local web interface. | The site is offline. A router that wants to phone home before it will serve a network is unusable here. ⚠️ This disqualifies several popular mesh systems that require an app and an account for setup. |
| 2 | **Custom local DNS entries** (map a chosen hostname to a chosen local address) **and the ability to advertise itself as the tablets' DNS server.** | This is how tablet clocks stay correct with no Internet: the tablets' automatic time-check is answered by our own server instead of the Internet. Without it, an offline site has no way to keep tablet clocks right — and the clinical timestamp comes from the tablet. OpenWrt-based firmware does this natively; most consumer firmware cannot. ⚠️ **DNS rebinding protection must be off, and encrypted DNS (DoH/DoT) must be off** — both silently defeat the override; see the note below. |
| 3 | **Dual band (2.4 + 5 GHz), with 2.4 GHz able to stay enabled**, and one SSID across both bands and all nodes. | 2.4 GHz travels much further and penetrates walls better. For a spread-out ward we want range, not speed. |
| 4 | **Serves the local network normally with no uplink connected**, and accepts an optional uplink by cable **or** as a wireless client. | The normal state is "no Internet". Some consumer routers degrade or nag when the WAN port is empty. |
| 5 | **Expandable to several access points on one network and one SSID, with exactly one device handing out addresses** — either a mesh mode or a plain "access point / bridge" mode. | This is how coverage grows without any change to the server, the app, or the addresses. ⚠️ Our recommended units have **no mesh mode at all** (see below) — they satisfy this via plain AP mode, which is the path we take. |
| 6 | **Configuration can be exported to a file and restored from it, *and* can be applied non-interactively** (OpenWrt: SSH + `uci`). | The kit carries the configuration in **two** forms, because they fail differently — see the note below. The reset button is taped over and labelled. If a router is reset, someone restores a file; if it is replaced by a different model, someone runs the script — no engineering either way. |
| 7 | **Low power, and able to run from a power bank or 12 V battery** (USB-C / 5 V, or 12 V DC input). | Power cuts are expected. The server has a battery; the network should survive the same cut, or the tablets have nothing to talk to. |
| 8 | **WPA2/WPA3 password protection, and client isolation that we can guarantee is OFF.** | Client isolation is the exact setting that silently breaks tablet↔server communication. On our own equipment we can be certain it is off. |
| 9 | **Fanless, tolerant of a warm room (~40 °C), wall- or pole-mountable** for any node that goes up in a ward. | Field conditions; no moving parts to fill with dust. ⚠️ The recommended units are rated **0–40 °C**, so a 40 °C room is the *top* of the rating, not comfortably inside it. ⚠️ **The Beryl AX fails the "fanless" half of this requirement** — it has an active fan. This is the one hard requirement anything in the family fails; see the note below. |
| 10 | **Firmware we can configure once and freeze** — no forced automatic update that could change behaviour on an unattended box. | Nobody is on site to notice a behaviour change. |

**Desirable, not required:** Power-over-Ethernet on ceiling-mounted nodes (one cable for power and
data); an IP65 weatherproof rating for anything outdoors or in a tent; a built-in LTE modem and SIM slot
(an uplink that needs nothing from MSF's IT); a dedicated backhaul radio on mesh nodes; fast-roaming
support (802.11k/v/r).

### Note on requirement 2 — rebinding protection is the trap that breaks clock discipline

Keeping tablet clocks right means resolving a *public* hostname (the tablets' automatic time-check) to a
*private* address — our server at `192.168.8.10`. That is, by construction, indistinguishable from a DNS
rebinding attack, and routers ship with rebinding protection **on**: GL.iNet's own documentation warns
that it "may cause private DNS lookup failure."

So the local DNS override is not simply "supported or not." It has to be configured *and* the protection
explicitly disabled, and the combination has to be verified to survive a reboot — the failure mode is
silent and only shows up as tablets slowly drifting off the correct time. This is a WS-8 test item, not
an assumption.

**Encrypted DNS is a second, independent way to lose the same override (found 2026-08-12).** If the
router resolves names over DoH/DoT, queries leave for an upstream resolver and our local mapping is
simply not consulted — the override is present in the configuration and inert in practice. This is not
hypothetical on this hardware: GL.iNet's **OP24 branch shipped a bug where encrypted DNS defaulted to
Cloudflare regardless of the user's setting**, fixed only in the second beta by removing the `stubby`
service. Two consequences: **encrypted DNS must be explicitly disabled and asserted**, not assumed off;
and the WS-8 test has to verify the override by observing what the *tablet* resolves, not by reading the
router's configuration page — the configuration page looked correct throughout that bug.

### Note on requirements 7 and 9 — where the recommended hardware has no margin

Both of these pass on the letter and are tight in practice. Neither is a reason to choose different
equipment; both are reasons to test deliberately rather than assume.

**Thermal (requirement 9).** Every GL.iNet unit in the family is rated **0–40 °C operating** — the Beryl
AX and the Flint 2 alike. A ~40 °C ward therefore leaves *no* headroom, and the Flint 2 has considerably
more heat to shed than the smaller units (<20 W rated, ~8.5 W typical, dissipated passively through the
case). Field reports put the Flint 2's SoC around 55 °C at idle in an ordinary room. Consequences:
mount it on a wall with clear airflow, **never** in a cupboard, box or cable tray, and add an
**elevated-ambient soak test** to the bench programme rather than only testing it on a desk in
Switzerland. This is the largest single technical risk in the network design.

**The Beryl AX has a fan; the Flint 2 does not (found 2026-08-12).** The GL-MT3000 is *actively* cooled —
a fan on a heatsink, confirmed by two independent teardowns and exposed by OpenWrt as `pwmfan-isa-0000`,
with a threshold slider in GL.iNet's firmware (default **76 °C**, adjustable 70–90 °C). It therefore
fails the "fanless / no moving parts to fill with dust" half of requirement **9** outright — the only
hard-requirement failure anywhere in the recommended family.

The reason this matters more than the spec sheet suggests: **fan duty cycle is a function of ambient, and
every published reassurance was measured in a European room.** Reviewers report never hearing it; users
measuring the SoC see ~51 °C at idle in an ordinary room, i.e. roughly a **+30 °C rise over ambient**. In
the ~40 °C ward this document plans for, that puts the SoC near 70 °C *at idle* and over the 76 °C
threshold under any load. The unit whose fan "never spins" in Switzerland is one whose fan **runs more or
less continuously in DRC**, drawing dusty air through the case, unattended, for the length of the pilot.
That is precisely the failure mode requirement 9 exists to exclude, and — this is the trap — **bench
testing at Swiss room temperature will not reveal it.** It is the strongest argument in this document for
the passively-cooled Flint 2 as the head, and the reason the elevated-ambient soak test above is
mandatory rather than nice-to-have for any Beryl AX that ships.

**Never plug USB storage into the router.** Two documented problems converge on the Beryl AX's USB 3.0
port: USB devices have caused heating severe enough to take the 2.4 GHz radio down, and USB 3 emissions
interfere with 2.4 GHz directly. Nothing in the pilot needs it. This is a runbook prohibition, not a
preference.

**Power (requirement 7).** The two tiers differ in a way that matters for the power-cut rehearsal:

- **Beryl AX (GL-MT3000)** — USB-C, 5 V/3 A. Runs from any ordinary USB power bank.
- **Flint 2 (GL-MT6000)** — **12 V/4 A barrel jack (DC5521), not USB-C.** A normal USB power bank
  **cannot** drive it: 12 V is an optional USB-PD voltage that many banks never advertise, so a generic
  PD trigger cable is not a safe assumption.

If the Flint 2 is the head, the kit needs one of: a power bank with a genuine 12 V DC output, a PD
trigger cable **verified against the exact bank model bought**, or a small 12 V DC UPS. This is a
purchase decision with a lead time, not a detail to discover during staging. It is also a point in
favour of a Beryl AX head if the layout answers show a small enough site.

### Note on requirement 6 — the configuration travels twice, not once

A router backup file (OpenWrt's `sysupgrade -b` archive, or the equivalent "export settings" in a web UI)
is **tied to the model it came from**: it carries that device's radio identity and its Ethernet/switch
topology, so restoring it onto a different model can leave the unit with no working LAN. That makes it an
excellent *fast path* and a poor *only* path.

So the kit carries both:

1. **A configuration script** (OpenWrt `uci` commands over SSH) — the source of truth. Written to
   *discover* the hardware rather than assume it, it survives a firmware update, a different model, and a
   replacement unit bought locally in a hurry. It is also reviewable, diff-able and version-controlled
   alongside the rest of the deployment, which a binary backup is not.
2. **The exported backup file** — the thirty-second restore for an *identical* unit, which is the common
   case (a reset router, or the spare from the kit).

The runbook instruction is therefore "restore the backup; if the router is not the same model, run the
script instead." Building and validating that script is a deliverable — see **WS-8** in
`FIELD-PILOT-DEPLOYMENT-PLAN.md`.

---

## The family — one head router plus *N* coverage nodes

The architecture is the same at every tier, and this is what makes the sizing decision safely
deferrable:

- **One "head" router.** It owns the network: hands out addresses, provides the local DNS entries that
  keep tablet clocks correct, and holds the optional uplink. There is exactly one of these.
- **Zero to several "coverage nodes."** Plain access points on the same SSID and the same
  network. They hand out nothing and hold no configuration that matters. **Adding one is a Wi-Fi
  concern only — no change to Buendia, the server, the app or any address.**

### ⭐ Recommended family: GL.iNet (OpenWrt-based)

Why this family rather than a specific model: it runs **OpenWrt** as shipped, which satisfies
requirements **1**, **2** and **6** natively; every unit is configurable offline over a local web page;
access-point and wireless-bridge modes are standard; the units are USB-powered and small enough to run from a power
bank, and cheap enough that carrying a spare is not a budget question; and because the whole tier shares
one firmware, **the head and the nodes are interchangeable** — a spare covers either role.

**The head router has since been checked in depth (2026-08-12).** The **Flint 2 (GL-MT6000)** was
verified against all ten hard requirements individually and **passes every one**, so the recommendation
stands. Three findings came out of that check and are folded into this document: the thermal and 12 V
power notes under requirements 7 and 9, the rebinding-protection trap under requirement 2, and the
firmware-branch decision in the caveat below. None of them is a reason to choose different equipment;
all three are reasons the bench programme has to be deliberate.

**The Beryl AX (GL-MT3000) was then checked to the same depth (2026-08-12). It passes nine of the ten and
fails requirement 9**, because it has an active cooling fan (see the note above). The other nine hold,
and on two of them it is the **best unit in the family**: requirement **4**, because wireless-uplink
(repeater/WISP) operation is what the product is built for, and requirement **7**, because it runs from
USB-C at 5 V/3 A and under 8 W — meaning **any ordinary USB power bank drives it**, dissolving the 12 V
barrel-jack procurement problem that the Flint 2 creates. Four further findings from that check are
folded in below: the absent mesh mode, the encrypted-DNS trap under requirement 2, the single LAN port,
and the transmit-power change in recent firmware.

⚠️ **Neither recommended model has a mesh mode at all.** This document previously offered Beryl AX
coverage nodes "as access points **or mesh nodes**" and described GL.iNet's mesh as proprietary. That was
wrong: GL.iNet's mesh (AstroMesh) is a **Flint 3 / Slate 7** feature and exists on **neither the MT3000
nor the MT6000**. Requirement **5** explicitly permits plain AP mode, so the architecture is unaffected
and nothing needs re-sizing — but the runbook and the WS-8 script must say **access point**, full stop,
and nobody should go looking for a mesh setting that is not there. Wireless-backhauled nodes (the Red
Zone case in the deployment plan) are a **wireless bridge / repeater**, which these units do support.

⚠️ **One caveat to hold onto: GL.iNet ships a *fork* of OpenWrt, not upstream OpenWrt.** Their own web
interface sits on top of stock OpenWrt with its own configuration and services beneath it, and their
firmware lags upstream. Three practical consequences, all for **WS-8** rather than for procurement:
settings applied over SSH can in principle be re-templated by the vendor layer, so the frozen
configuration must be verified to survive both a reboot *and* a visit to the web interface; their
mesh, where it exists in their range at all, is **proprietary and absent from both recommended models**
(see above), so coverage nodes join as plain access points (requirement **5** explicitly allows either);
and there are
**two incompatible firmware lines**, which makes "freeze the firmware" a choice of *branch*, not just of
version:

| Branch | Base | Notes |
|---|---|---|
| **Stable 4.8.x** (default) | an OpenWrt 21.02 snapshot | partly closed-source; what the unit ships with and what the upgrade reminder offers |
| **"op24"** | OpenWrt 24.10 | open-source; **no update path to or from the stable line** |

We must pick one, record it, and write and validate the `uci` configuration script against *that*
branch — a script proven on one line is not proven on the other. Freeze on a version that has been in
the field for a while rather than the newest: the alarming Flint 2 reports (random reboots, Wi-Fi
vanishing) are from firmware 4.5.5 in early 2024 and do not reflect the current 4.8.x, but 4.8.3 was
itself a driver rollback to undo a 4.8.2 regression, which is the pattern to respect.

✅ **The branch decision is one decision, not two (checked 2026-08-12).** GL.iNet publishes the OP24 line
for **both** models — 4.9.0-OP24, on OpenWrt 24.10.4 — so head and nodes can be frozen on the same
branch, which is what keeps a single `uci` script valid across the kit and keeps the spare genuinely
interchangeable. Upstream OpenWrt also supports the MT3000 directly (24.10.x in the firmware selector),
which is a real escape hatch if the vendor layer ever gets in the way. Note that the OP24 encrypted-DNS
bug described under requirement 2 was on this branch: whichever line we freeze, the DNS behaviour is
verified on **that image**, not inherited from the other.

⚠️ **Firmware choice now changes Wi-Fi range.** April 2026 firmware is reported to have **reduced Wi-Fi
transmit power** for FCC compliance. Coverage is the one thing this whole document is sized around, so
the coverage walk must be run on **the exact image that ships**, and the frozen version recorded before
the walk rather than after — a later "harmless" firmware bump can silently shrink the coverage we
measured and signed off.

✅ **One thing that turned out better than assumed:** GL.iNet firmware 4.x has **no automatic update
mechanism at all** — only an upgrade reminder shown when someone signs in to the admin panel. Requirement
**10** is therefore satisfied by default rather than by configuration, and an unattended box cannot
change behaviour under us.

| Tier | When it applies | Equipment | Indicative price (CHF) |
|---|---|---|---|
| **0 — bench + spare** | Not a site tier: the unit the configuration is developed and tested on in Switzerland, and the spare that travels in the kit | A second **Beryl AX** (GL-MT3000) — deliberately *not* a cheaper single-band unit (see below) | ~190 |
| **1 — baseline** ⭐ | One ward, hall or room; farthest tablet within ~15 m; at most one or two light walls | 1× **Flint 2** (GL-MT6000) as head — or a **Beryl AX** (GL-MT3000) if the space is small, accepting the fan and **adding a small unmanaged switch** (see below) | ~260 (Flint 2) / ~190 (Beryl AX) |
| **2 — multi-zone** | Several rooms or tents, walled bays, or a farthest bed beyond ~15 m: 2–4 coverage points | Flint 2 head **+ 1–3 Beryl AX / Slate AX** as access points — **plain AP mode; there is no mesh mode on these units** | +~100–190 per node |
| **3 — long span / outdoor** | A tent or building 30–100 m away, or across a compound | Add an **outdoor, PoE-powered access point** (TP-Link Omada EAP-Outdoor class, IP65) or a **point-to-point bridge pair**; plus an Ethernet run or wireless backhaul | to be priced once the span is known |

⚠️ **Prices are indicative retail data points, not quotes, and were not verified per model.**
Observed while writing this: Beryl AX ≈ CHF 187 (Toppreise), Flint 2 ≈ CHF 263 on offer (techstudio.ch).
The total for tiers 0–2 is in the low hundreds of francs — a rounding error against the pilot, which is
why we would rather over-provision by one node than under-cover a ward.

⚠️ **The CHF column is the wrong currency for procurement.** The kit is bought by SolDevelo **on the
Polish market** and only staged in Switzerland, so PL availability and pricing are what actually apply.
The Flint 2 is widely stocked there — roughly **629–699 PLN** on Allegro, 829 PLN at dmtrade.pl — which
appears materially cheaper than the Swiss figure above, though the conversion has not been checked
against a current rate. The **Beryl AX is listed around 416 PLN** on Allegro (checked 2026-08-12), also
well under the CHF ~187 (≈830 PLN) figure. Supply is not a constraint for either model; treat the CHF
numbers as an order-of-magnitude sanity check only.

**Why tier 0 is a full second Beryl AX and not a ~CHF 35 travel router.** The cheap end of this family
(the GL-MT300N-V2 "Mango" class) is **single-band 2.4 GHz**, so it fails hard requirement **3** outright.
That has two consequences, and each one is enough on its own: it **cannot validate the configuration we
intend to ship** — half the wireless config, the 5 GHz radio, is simply not exercised, and per-radio
differences are exactly the kind of thing a bench unit exists to catch — and it is **not a real spare**,
because a unit that cannot serve the second band cannot stand in for a coverage node or for the head
router. Spending CHF ~155 more buys a bench unit identical in capability to what ships and a spare that
covers either role. A single-band unit has a place only as a throwaway for destructive experiments, and
the pilot does not need one.

### ⬜ Open decision: should the bench unit and spare be a second *Flint 2* rather than a Beryl AX?

**Raised 2026-08-12 by the Beryl AX check; asked internally, awaiting colleagues' view.** The paragraph
above argues that the bench unit must be *"identical in capability to what ships."* Applied consistently,
that argument does not stop at "dual-band" — **if the head is a Flint 2, a Beryl AX bench unit is not
identical to it either**: different port layout, different power input (12 V barrel jack vs USB-C),
different thermal design (passive vs fanned), and different firmware images. On the reasoning already in
this document, the bench/spare would be a **second Flint 2**.

The counter-argument is genuine and not merely cost: a Beryl AX spare **covers both roles** — it can
stand in for a failed head at reduced coverage *and* serve as a coverage node — whereas a second Flint 2
is a better bench unit but a clumsy node. It is also roughly a third of the price, and it is the unit
that runs from an ordinary power bank.

Both readings are defensible, which is why this is recorded as a decision rather than settled here. The
cost delta is small enough that **buying one of each** is a legitimate third answer, and probably the one
that survives contact with the site. **Nothing is blocked while this is open** — the head router is
unaffected, and both candidates are stocked in PL.

### Alternatives, if MSF prefers a family it already standardises on

Any of these is acceptable **provided it meets the ten hard requirements**, and we are happy to work with
MSF's existing standard rather than introduce a new brand:

- **TP-Link Omada** (EAP access points + a local software controller or an OC200 box). Better
  ceiling/outdoor access points, proper PoE and real roaming — the strongest option for **tier 3**. Costs
  one more component (the controller) and the local-DNS requirement then has to be met by whichever
  device routes the network.
- **Ubiquiti UniFi.** The same shape, stronger access points, a local controller; the heaviest and most
  over-specified option for 10 tablets.
- **Teltonika RUT200 / RUT241** (≈ CHF 105 / 138 at Digitec). Industrial: DIN-rail mountable, 9–30 V DC
  input, wide temperature range, built for years unattended, and the RUT241 has an **LTE modem and SIM
  slot** — an uplink that needs nothing at all from MSF's IT. The right **head** if the environment is
  harsh or a cellular uplink is wanted; its firmware supports the static DNS entries requirement **2**
  needs. Weaker Wi-Fi coverage than the GL.iNet units, so it pairs with coverage nodes.

### What we buy now, and what waits for the layout

- **Now, because it is needed for staging regardless and works for any plausible site:** the head router
  (Flint 2), **one** coverage node (Beryl AX), **one bench unit and spare** — Beryl AX or a second Flint 2,
  see the open decision above — an Ethernet cable, and a battery source for the router. Three units, ~CHF 640.
  ⚠️ **If a Beryl AX is ever the head, add a small unmanaged switch.** It has only **one LAN port** (plus
  the WAN port): the server takes it and nothing else can be cabled — no wired coverage node, no laptop
  for staging. The Flint 2 has four, so this is a Beryl-AX-head-only item, but it is a purchase, not an
  improvisation.
  ⚠️ **The battery source is not a generic USB power bank** — the Flint 2 takes 12 V on a barrel jack, so
  this must be a bank with a real 12 V DC output, a PD trigger cable verified against the exact bank
  bought, or a small 12 V DC UPS. See the note on requirement 7. Buy it with the routers; discovering
  this during staging costs a shipping cycle.
- **Deferred until the layout answers arrive:** additional coverage nodes and the outdoor/long-span tier.
  These are orderable in days, the kit is functional without them, and buying them blind is how you end
  up with the wrong ones.
- **Everything is pre-configured and frozen in Switzerland**, with the configuration travelling in the kit
  as both a script and an exported backup file (see the requirement-6 note above).

---

## What we need from MSF to size this

These are the questions that decide tier 1 vs 2 vs 3. **A sketch on paper or a few photos with rough
distances answers most of them better than prose** — and none of them requires a technical person.

1. **How many separate spaces** (buildings, wards, tents, triage points) will tablets be used in, and
   what is each one used for?
2. **A rough sketch or photos**, with approximate distances. Where would the server sit, and where is
   the farthest place a tablet needs to work?
3. **The longest distance** from the server's likely spot to the farthest working point, in metres — and
   whether there is line of sight or something in between.
4. **What are the walls and partitions made of?** Plastic sheeting, wood, drywall, brick, concrete,
   metal, shipping container? **This is the single biggest factor** — plastic sheeting is nearly
   transparent to Wi-Fi, concrete and metal are close to opaque.
5. **Is there mains power** at the places where an extra access point might need to go, and **are we
   allowed to mount** something on a wall, pole or ceiling there?
6. **Does a contamination (Green/Red zone) boundary get crossed?** This changes the answer: a cable
   across such a boundary cannot be decontaminated, so we would cover the zone wirelessly from outside
   it or place a dedicated node inside it. We would want MSF's IPC view on that.
7. **Any outdoor span between buildings?** Anything beyond roughly 30 m outdoors needs different
   (weatherproof, higher-gain) equipment.
8. **Environment and power practicalities:** dusty, hot, humid? What socket type and voltage is at the
   site?
9. **Optional and not blocking — is there any Internet at the site our router could take an uplink
   from** (a spare network cable, or a Wi-Fi we could join as a client)? Or should we plan on a cellular
   SIM instead? This is worth having (tablet clocks and remote support) but nothing waits for it.
10. **How many tablets** — for node count and placement, not for capacity.

**Questions 1–5 decide the equipment. Nothing else in the pilot is blocked while they are outstanding**:
the baseline tier is bought and staged in the meantime, and growing it is additive.

---

## What we will prove in Switzerland before anything ships

Because we own the network, every one of these is a **real rehearsal rather than a stand-in** — which is
the whole point of the decision:

- **Coverage walk** with a real tablet: a form saves at the farthest planned distance, and through the
  same number and kind of walls as the site has. **Run on the exact frozen firmware image, with that
  version recorded first** — recent firmware reduced transmit power, so a coverage result is only valid
  for the image it was measured on.
- **Clock discipline**: a tablet with a deliberately wrong clock corrects itself to the server's time
  over our network, with no Internet — **and again after a router reboot**, which is what proves the DNS
  override and the disabled rebinding protection both survive a power cycle rather than only a
  configuration session. **Verify from the tablet's side, and assert encrypted DNS (DoH/DoT) is off** —
  a router configuration page can show a correct override while queries are silently leaving over DoH.
- **Heat soak**: the head router run at load in an elevated ambient (approaching its 40 °C rating), not
  on a bench at room temperature, confirming it neither throttles nor drops its radios. The unit is
  rated exactly to the temperature we expect, so this is measured, not assumed. **For any fanned unit
  (every Beryl AX), also record what fraction of the soak the fan is actually running** — at 40 °C
  ambient it is expected to run near-continuously, which is a dust-ingress and wear question that room
  temperature testing cannot surface.
- **Power cut**: router on its 12 V battery source and server on battery — tablets keep working through
  it, and everything comes back by itself afterwards. This also validates the specific bank/trigger/UPS
  combination bought, which is the part that cannot be assumed from the spec sheet.
- **Configuration restore, both paths**: wipe a router and restore from the saved backup file, network is
  back; then wipe it again and rebuild it **from the script alone**, and confirm the result is identical.
  The second half is what proves the kit can survive a replacement unit that is not the same model.
- **Cold start, unattended**: full power cycle of everything, no laptop, no engineer — the system comes
  up and tablets sync.
- **Adding a node**: a second access point joins the same SSID **in plain AP mode** (not mesh — these
  units have none) and a tablet roams onto it, with no change to the server or the app.

---

## The decision we need from MSF

Very little, which is the intent:

1. **Confirmation that SolDevelo supplies the network** — i.e. that there is no site policy against us
   running our own Wi-Fi and our own server on it (this may still need a word from whoever governs IT at
   the site, and it ties to the data-protection sign-off).
2. **Answers to the layout questions above**, questions 1–5 in particular, or a sketch and photos.
3. **Optional:** whether an Internet uplink can be made available to our router, or whether we should
   plan for a cellular SIM.
4. **Optional:** whether MSF would rather we use an equipment family they already standardise on, in
   which case we check it against the ten hard requirements.
