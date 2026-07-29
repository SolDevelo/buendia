# Project Buendia — Field Pilot: Executive Summary

*One-page summary of the full plan (`FIELD-PILOT-DEPLOYMENT-PLAN.md`).*

## What this is

A lean path to put Project Buendia — an offline electronic patient-record system for outbreak treatment centres — into use at **one DRC site**, on **CrossCall T4/T5 tablets**, against a small **on-site server**, with **no Internet required** at the site.

It is an **autonomous kit**, independent of MSF's existing LIME EMR / OpenMRS 3 infrastructure and field-IT teams — the approach MSF has confirmed (a LIME-compatible app is the deferred long-term alternative). This is the "minimum field-pilot" scope: a controlled, single-site pilot. It defers the larger production rebuild (custom appliance hardware, multi-site management).

## Estimated effort

Once started, and given the **site specifics**, the engineering is roughly **1.5 calendar weeks — about 8–11 calendar days — for a two-person team** (~6–8 working days; a single engineer ~8–10). The remote-support + data-export work adds ~1–2 days. **Hardware procurement is separate calendar lead time** (SolDevelo now selects and buys the kit — order early), and staging on the real hardware is ~1 day once devices and software are both in hand. These are effort estimates, **not a commitment to a start date**.

## How it works

- **Server:** a small off-the-shelf x86 mini-PC (or laptop) running Ubuntu + Docker. The whole Buendia server (OpenMRS + database) is pre-built containers — no Internet on-site.
- **Tablets:** the existing Buendia Android app, frozen at the working baseline and patched only for these Android versions. Installed over local Wi-Fi by scanning a QR code; updated over-the-air thereafter.
- **Network:** a standalone Wi-Fi router (the server is wired to it). Everything runs offline; software updates arrive by USB.
- **Built for the field:** hardened to run unattended (survives lid-close, power-cycles, self-reboots), keeps the tablets' clocks correct without the Internet (they sync from the local server), can't fill its own disk, and ships with an offline diagnostics dump.
- **Remote support & data:** an opt-in, secure, server-initiated tunnel — dormant offline — lets SolDevelo support the server and lets MSF pull a clinical-data export when occasional internet is available; USB export is the offline fallback. Subject to MSF data-protection sign-off.
- **Operation:** SolDevelo ships a fully set-up, tested kit; on-site, staff only power it on and verify it works.

## Who does what

- **SolDevelo (technical + procurement + staging):** selects and **buys the hardware**, builds the software, **stages, tests, and packs** the ready-to-run kit, writes the runbooks, and provides remote support. Does not travel to site.
- **MSF (deployment + domain):** provides the site specifics, clinical content, and data-protection sign-off; **receives the kit and deploys it on-site** (power-on + verify); operates it.
- **Users:** clinicians at the site.

## Status & key decisions

- The core software is validated end-to-end in a working demo; the required fixes are understood and largely in place.
- Decided: **autonomous kit** (not LIME-integrated); **SolDevelo procures + stages, MSF deploys**; **opt-in secure remote-support tunnel + data export** (pending data-protection sign-off); tablet data-at-rest via **device encryption + screen lock**; clinical content from the upstream **Ebola profile**; server on **Ubuntu + Docker**; a **standalone mesh-capable Wi-Fi router**.

## Next steps

*No start date is committed in this plan.* When the work is greenlit:

1. **SolDevelo can begin immediately** — order hardware (the long-lead item) and start the device-agnostic build (server stack, reproducible build, signed app, update channel, remote-support + data-export, field-robustness tooling).
2. **MSF provides the inputs:** the **site specifics** (facility, ward/bed layout, clinician accounts), the clinical content owner, tablet count, ward layout for Wi-Fi coverage, and **data-protection sign-off** for remote access + data export.
3. **Main convergence point:** the final site configuration (ward/bed layout + clinician list). On-device validation is handled by SolDevelo on the procured tablets at staging — not a field unknown.
4. **Open decisions:** a hypercare support window (SolDevelo, commercial); server base (SolDevelo-procured mini-PC vs. reset MSF laptops); exact hardware models.
5. **Hand-off:** SolDevelo ships the staged kit + runbooks; MSF deploys on-site.

The open inputs do **not** block the start once greenlit — they're needed to *finish* and to deploy. See §8 of the full plan for the checklist.
