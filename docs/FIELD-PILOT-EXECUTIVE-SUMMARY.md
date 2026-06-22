# Project Buendia — Field Pilot: Executive Summary

*One-page summary of the full plan (`FIELD-PILOT-DEPLOYMENT-PLAN.md`).*

## What this is

A lean path to put Project Buendia — an offline electronic patient-record system for outbreak treatment centres — into use at **one DRC site**, on **CrossCall T4/T5 tablets**, against a small **on-site server**, with **no Internet required** at the site.

This is the "minimum field-pilot" scope from the technical review: a controlled, single-site pilot. It deliberately defers the larger production rebuild (custom appliance hardware, multi-site management).

## Estimated effort

Once started, and given the **site specifics**, the engineering is roughly **1.5 calendar weeks — about 8–11 calendar days — for a two-person team** (~6–8 working days of effort; a single engineer is ~8–10 working days). SolDevelo validates on an emulator and a representative device, so the build does not wait on the actual tablets — the real-T4/T5 check happens at MSF's staging step. This is an estimate of effort, **not a commitment to a start date** (see Next steps).

## How it works

- **Server:** a small off-the-shelf x86 mini-PC (or laptop) running Ubuntu + Docker. The whole Buendia server (OpenMRS + database) ships as pre-built containers — no building and no Internet on-site.
- **Tablets:** the existing Buendia Android app, frozen at the working baseline and patched only for these Android versions. Installed over local Wi-Fi by scanning a QR code; updated over-the-air thereafter.
- **Network:** a standalone Wi-Fi router (the server is wired to it). Everything runs offline; software updates arrive by USB.
- **Built for the field:** the server is hardened to run unattended (survives lid-close, power-cycles, reboots on its own), keeps the tablets' clocks correct without the Internet (they sync from the local server), can't fill its own disk, and ships with an offline diagnostics tool so SolDevelo can debug issues by post.
- **Operation:** the kit is fully set up and tested before it ships, then delivered to the site, where staff only power it on and verify it works.

## Who does what

- **SolDevelo (technical):** builds the deployment bundle (server, app, configuration, tools) and the runbooks; advises on hardware and setup.
- **MSF (execution + domain):** procures the devices, sets up and tests the kit at a staging location, delivers it to the site, and owns all clinical/site specifics.
- **Users:** clinicians at the site.

The split between a **Staging Area** (anywhere with Internet and a technical person — sets up and tests the kit) and the **Site Area** (the field hospital — only powers it on) is what keeps on-site demands minimal.

## Status & key decisions

- The core software has been validated end-to-end in a working demo; the required fixes are understood and largely already in place.
- Decided: tablet data-at-rest protected by **device encryption + a mandatory screen lock**; clinical content starts from the upstream **Ebola profile** and is adapted; server on **Ubuntu + Docker**; a **standalone Wi-Fi router** (mesh-capable, for coverage).

## Next steps

*No start date is committed in this plan.* When the work is greenlit:

1. **SolDevelo can begin immediately** on the device-agnostic workstreams — the server container stack, the reproducible build, the signed Android app, the update channel, the field-robustness tooling. These need no further input and run in parallel with procurement.
2. **MSF provides the inputs** (SolDevelo advises): server hardware choice, the staging location, the **site specifics** (facility, ward/bed layout, clinician accounts), tablet count, ward layout for Wi-Fi coverage, and the router model.
3. **Main convergence point:** the final site configuration (ward/bed layout + clinician list). On-device validation does **not** block the build — SolDevelo validates on an emulator + a representative device, and the real-T4/T5 confirmation rides on MSF's staging step, with SolDevelo on standby to patch any device-specific quirk.
4. **Hand-off and deployment:** SolDevelo delivers the bundle + runbooks; MSF stages, tests, and deploys to the site.

The open inputs do **not** block the start once work is greenlit — they're needed to *finish* and to deploy. See §8 of the full plan for the input checklist.
