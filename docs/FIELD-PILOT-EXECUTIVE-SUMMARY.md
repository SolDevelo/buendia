# Project Buendia — Field Pilot: Executive Summary

*One-page summary of the full plan (`FIELD-PILOT-DEPLOYMENT-PLAN.md`). Last revised **2026-07-30**.*

> **⚠️ This document was rewritten on 2026-07-30.** It previously described the pilot as not-yet-started
> ("when the work is greenlit"), promised over-the-air app updates, and had SolDevelo procuring the
> tablets and staging the kit. All three are out of date: **the software is built and twice validated on
> real hardware**, OTA updates were withdrawn as unachievable on this client, and MSF supplies the
> tablets and installs the shipping server.

## What this is

A lean path to put Project Buendia — an offline electronic patient-record system for outbreak treatment
centres — into use at **one DRC site**, on **CrossCall T4/T5 tablets**, against a small **on-site
server**, with **no Internet required for clinical use**.

It is an **autonomous kit**, independent of MSF's existing LIME EMR / OpenMRS 3 infrastructure and
field-IT teams — the approach MSF confirmed. This is the "minimum field-pilot" scope: **pilot-like, not
perfect**, deliberately deferring the larger production rebuild (custom appliance hardware, multi-site
management).

**End goal:** one site, a **no-maintenance** package, set up and tested at **MSF Switzerland**, then
shipped **"ready to go"**. Two consequences shape every decision: **no engineer is ever on site**, and
**anything that cannot be tested in Switzerland ships unvalidated**.

## Status — the software is done

**The complete kit has been built from scratch and validated end-to-end on real hardware twice
(2026-07-29 and 2026-07-30).** A bare Ubuntu laptop was installed from a USB stick, a tablet installed
the app by scanning a QR code, and a clinician workflow was completed and confirmed in the database —
patient admitted, observations recorded, treatment ordered. The machine was then rebooted (the stack came
back unattended), wiped, and reinstalled from the deployment bundle with the same result.

| Workstream | Status |
|---|---|
| Server container stack + one-command installer | ✅ done, validated on hardware |
| Seed data, clinical profile, zero-config first boot | ✅ done |
| Reproducible image build + delivery by `docker pull` | ✅ done |
| Signed Android app build + real-tablet validation | ✅ done |
| App install by QR code + printable in-zone card | ✅ done |
| Runbooks | ⬜ not started |
| Remote support + data export | ⚠️ **designed, never tested** |

## How it works

- **Server:** an ordinary x86 laptop or mini-PC running Ubuntu + Docker; the whole Buendia server
  (OpenMRS + database) ships as pre-built containers. **A laptop is recommended** — its battery is a
  built-in UPS against power cuts, and its screen is what tablets scan the install QR from.
- **Tablets:** the existing Buendia app, frozen at the working baseline. Installed over local Wi-Fi by
  scanning a QR code. **App updates are a manual re-install** — the in-app update mechanism is broken in
  this version of the client and was withdrawn from scope rather than rebuilt.
- **Network:** the current plan is to **reuse the site's existing Wi-Fi**, with a small access point kept
  in the kit as a fallback. This is an open question with MSF — see below.
- **Built for the field:** runs unattended (survives lid-close, power cuts and self-reboots), can't fill
  its own disk, and ships with an offline diagnostics dump plus a single go/no-go check that proves the
  system is genuinely *usable*, not merely powered on.
- **Remote support & data export:** an opt-in, server-initiated tunnel, dormant when offline, plus a
  clinical-data export. **Designed but not yet tested**, and gated on MSF data-protection sign-off before
  it may be enabled at a site holding patient data.

## Who does what

- **SolDevelo** — builds the package, specifies the hardware, **proves it on its own hardware
  (technical test)**, writes the runbooks, provides remote support. Does not travel to site.
- **MSF Switzerland** — **supplies the tablets**, sources the server, **installs the actual shipping
  server** from our package, and **runs the user test / UAT**, adjusting the configuration in the
  process; then labels, packs and ships.
- **MSF at site** — unpack, power on, verify, use. Nothing is built or configured here.
- **Users** — clinicians at the site.

**Two levels of test:** *technical* at SolDevelo (does it work — done twice) and *user/acceptance* at MSF
Switzerland (do clinicians accept it). They fail differently: a kit that passes the technical test can
still be rejected because a form asks the wrong question. **The user test is expected to produce changes
to the forms and the zone list** — those are cheap and need no rebuild, provided they are folded back into
the shipped configuration afterwards.

## What remains

1. **MSF's configuration answers** — sent as `FIELD-PILOT-MSF-REQUEST-OUTGOING.md`. The
   time-critical ones: what their tablet system image permits (it can invalidate the QR install route),
   the network decision below, and data-protection sign-off.
2. **The network decision** (below) — the most schedule-critical answer, because the server's address is
   built into the tablet app.
3. **Server hardware** — specification delivered (`FIELD-PILOT-SERVER-SPEC.md`); MSF may repurpose an
   existing laptop, which would be the cheapest and fastest outcome.
4. **Backup** — the largest remaining technical gap. Nothing yet takes a scheduled copy of the database,
   and the site server will hold the only copy of the pilot's patient data.
5. **Runbooks** (~2–3 days) and **proving the remote-support tunnel** (~1–2 days).

## The open network decision

Tablets and server must share one network. Two options, each with one real risk:

| | Reuse the site's Wi-Fi *(current preference)* | Ship our own access point |
|---|---|---|
| **Main risk** | Getting a fixed, reachable address in their subnet — and confirming their network doesn't isolate clients from each other (a silent, fatal setting) | **Range.** One access point may not reach every zone, and we cannot measure that from Switzerland |
| **Coverage** | Already designed for the site | Unknown until arrival |
| **Remote support & tablet clocks** | Work, if their network has Internet | Not possible on an isolated network |

The preference for reusing their Wi-Fi rests on coverage being the risk we can neither measure nor fix
remotely — and on the fact that **this arrangement is already validated**: both hardware runs placed the
server on an existing network we don't administer, at an address we were given, and it worked. **MSF is
being asked to choose**, with both options explained; a fallback access point travels with the kit either
way.

## Principal risks

- **No backup mechanism yet** — one machine will hold the only copy of the patient data (see above).
- **The remote-support tunnel is untested**, and on a fully isolated network it would be impossible
  rather than merely disabled — meaning a box nobody can look inside.
- **MSF's tablet system image is an unknown** that could invalidate the QR install route entirely; the
  cheapest mitigation is one tablet with that image in our hands before the MSF session.
- **An end-of-life software stack** (OpenMRS 1.10 / Java 7 / MySQL 5.6). Acceptable for a controlled
  pilot; it is the reason a production deployment would eventually rebuild the platform.

See §8 of the full plan for the decision checklist, and `FIELD-PILOT-PROGRESS.md` for current state.
