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
| 2 | **Custom local DNS entries** (map a chosen hostname to a chosen local address) **and the ability to advertise itself as the tablets' DNS server.** | This is how tablet clocks stay correct with no Internet: the tablets' automatic time-check is answered by our own server instead of the Internet. Without it, an offline site has no way to keep tablet clocks right — and the clinical timestamp comes from the tablet. OpenWrt-based firmware does this natively; most consumer firmware cannot. |
| 3 | **Dual band (2.4 + 5 GHz), with 2.4 GHz able to stay enabled**, and one SSID across both bands and all nodes. | 2.4 GHz travels much further and penetrates walls better. For a spread-out ward we want range, not speed. |
| 4 | **Serves the local network normally with no uplink connected**, and accepts an optional uplink by cable **or** as a wireless client. | The normal state is "no Internet". Some consumer routers degrade or nag when the WAN port is empty. |
| 5 | **Expandable to several access points on one network and one SSID, with exactly one device handing out addresses** — either a mesh mode or a plain "access point / bridge" mode. | This is how coverage grows without any change to the server, the app, or the addresses. |
| 6 | **Configuration can be exported to a file and restored from it.** | The kit carries the saved configuration; the reset button is taped over and labelled. If a router is reset or replaced, someone restores a file — no engineering. |
| 7 | **Low power, and able to run from a power bank or 12 V battery** (USB-C / 5 V, or 12 V DC input). | Power cuts are expected. The server has a battery; the network should survive the same cut, or the tablets have nothing to talk to. |
| 8 | **WPA2/WPA3 password protection, and client isolation that we can guarantee is OFF.** | Client isolation is the exact setting that silently breaks tablet↔server communication. On our own equipment we can be certain it is off. |
| 9 | **Fanless, tolerant of a warm room (~40 °C), wall- or pole-mountable** for any node that goes up in a ward. | Field conditions; no moving parts to fill with dust. |
| 10 | **Firmware we can configure once and freeze** — no forced automatic update that could change behaviour on an unattended box. | Nobody is on site to notice a behaviour change. |

**Desirable, not required:** Power-over-Ethernet on ceiling-mounted nodes (one cable for power and
data); an IP65 weatherproof rating for anything outdoors or in a tent; a built-in LTE modem and SIM slot
(an uplink that needs nothing from MSF's IT); a dedicated backhaul radio on mesh nodes; fast-roaming
support (802.11k/v/r).

---

## The family — one head router plus *N* coverage nodes

The architecture is the same at every tier, and this is what makes the sizing decision safely
deferrable:

- **One "head" router.** It owns the network: hands out addresses, provides the local DNS entries that
  keep tablet clocks correct, and holds the optional uplink. There is exactly one of these.
- **Zero to several "coverage nodes."** Plain access points or mesh nodes on the same SSID and the same
  network. They hand out nothing and hold no configuration that matters. **Adding one is a Wi-Fi
  concern only — no change to Buendia, the server, the app or any address.**

### ⭐ Recommended family: GL.iNet (OpenWrt-based)

Why this family rather than a specific model: it runs **OpenWrt** as shipped, which satisfies
requirements **1**, **2** and **6** natively; every unit is configurable offline over a local web page;
access-point and mesh modes are standard; the units are USB-powered and small enough to run from a power
bank and cheap enough to carry a spare; and because the whole tier shares one firmware, **the head and
the nodes are interchangeable** — a spare covers either role.

| Tier | When it applies | Equipment | Indicative price (CHF) |
|---|---|---|---|
| **0 — bench + spare** | Not a site tier: the unit we configure and test with in Switzerland, and the spare that travels in the kit | GL-MT300N-V2 "Mango", or a second Beryl AX | ~30–40, or as below |
| **1 — baseline** ⭐ | One ward, hall or room; farthest tablet within ~15 m; at most one or two light walls | 1× **Flint 2** (GL-MT6000) as head — or a **Beryl AX** (GL-MT3000) if the space is small | ~260 (Flint 2) / ~190 (Beryl AX) |
| **2 — multi-zone** | Several rooms or tents, walled bays, or a farthest bed beyond ~15 m: 2–4 coverage points | Flint 2 head **+ 1–3 Beryl AX / Slate AX** as access points or mesh nodes | +~100–190 per node |
| **3 — long span / outdoor** | A tent or building 30–100 m away, or across a compound | Add an **outdoor, PoE-powered access point** (TP-Link Omada EAP-Outdoor class, IP65) or a **point-to-point bridge pair**; plus an Ethernet run or wireless backhaul | to be priced once the span is known |

⚠️ **Prices are indicative Swiss retail data points, not quotes, and were not verified per model.**
Observed while writing this: Beryl AX ≈ CHF 187 (Toppreise), Flint 2 ≈ CHF 263 on offer (techstudio.ch).
The total for tiers 0–2 is in the low hundreds of francs — a rounding error against the pilot, which is
why we would rather over-provision by one node than under-cover a ward.

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

- **Now, because it is needed for staging regardless and works for any plausible site:** the head router,
  **one** coverage node, one cheap spare, an Ethernet cable, and a power bank for the router.
- **Deferred until the layout answers arrive:** additional coverage nodes and the outdoor/long-span tier.
  These are orderable in days, the kit is functional without them, and buying them blind is how you end
  up with the wrong ones.
- **Everything is pre-configured and frozen in Switzerland**, with the configuration exported to a file
  that travels in the kit.

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
  same number and kind of walls as the site has.
- **Clock discipline**: a tablet with a deliberately wrong clock corrects itself to the server's time
  over our network, with no Internet.
- **Power cut**: router on a power bank and server on battery — tablets keep working through it, and
  everything comes back by itself afterwards.
- **Configuration restore**: wipe a router, restore from the saved file, network is back.
- **Cold start, unattended**: full power cycle of everything, no laptop, no engineer — the system comes
  up and tablets sync.
- **Adding a node**: a second access point joins the same SSID and a tablet roams onto it, with no change
  to the server or the app.

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
