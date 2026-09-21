# Project Buendia — System Overview

*Shareable, non-internal description of the Buendia system. Derived from
`FIELD-PILOT-DEPLOYMENT-PLAN.md`, `FIELD-PILOT-SERVER-SPEC.md`, `FIELD-PILOT-NETWORK-SPEC.md` and
`TECHNICAL-REVIEW.md`; those stay canonical. Regenerate rather than editing both. Revised 2026-09-11.*

*Everything below this line is the document as it goes out — no file paths, credentials, hostnames,
internal status or cost reasoning.*

---

## 1. What it is

Project Buendia is an **electronic patient record system for outbreak treatment centres** — settings
where paper records cannot safely be carried out of the high-risk zone and where clinicians work in
full protective equipment.

It is built on **OpenMRS**, the open-source medical record platform already in use by ministries of
health and health organisations across Africa and Asia. Buendia adds two things to it: a **rugged
tablet application** for bedside use, and the **synchronisation layer** that allows those tablets to
work against a small local server with no Internet connection of any kind.

A Buendia deployment is one self-contained kit — tablets, one server, one Wi-Fi router. It is
independent of every other system: it connects to nothing else and transmits nothing on its own.
Buendia is open-source software (project home: `github.com/projectbuendia/buendia`).

---

## 2. Equipment

| Component | What is used | Role |
|---|---|---|
| **Tablets** | Crosscall Core-T5 (Core-T4 also supported) — rugged, IP68 water/dust rated, disinfectable | Clinicians record data at the bedside |
| **Server** | One ordinary x86-64 laptop (Ubuntu Linux) | Holds all patient data; serves the tablets |
| **Network** | One GL.iNet GL-MT6000 "Flint 2" Wi-Fi 6 router (additional access points if the site layout requires them) | Private local Wi-Fi linking tablets to the server |

The tablets are rugged and chlorine-tolerant because they are used inside the high-risk zone. A
**laptop** is used as the server deliberately: its battery acts as an uninterruptible power supply, so
a power cut cannot interrupt or corrupt the records. Nothing depends on site IT infrastructure.

---

## 3. Software

| Layer | Component | Version |
|---|---|---|
| Record platform | **OpenMRS Platform** (open source) | 1.10.6 |
| Sync + API layer | **Buendia OpenMRS module** | 1.0 |
| Database | **MySQL** | 5.6 |
| Tablet app | **Buendia Android application** | 1.0 |
| Server host | Ubuntu Linux with containerised services | — |
| Router firmware | GL.iNet (OpenWrt-based) | 4.8.3 |

> *On version numbering: "v1.0" refers to the Buendia module and the Buendia Android application. The
> underlying OpenMRS platform version is 1.10.6.*

The tablet application is a **native Android app**, not a web page. It authenticates against the local
server, keeps a working copy of the data it needs, presents the patient list by treatment zone, and
renders the clinical forms and the patient chart. The interface and the clinical forms are **bilingual
English / French**.

---

## 4. Data collection, storage and transfer

Clinicians enter data on tablets over a private local Wi-Fi network; every record is saved to a single
server standing in the treatment centre itself; nothing leaves the site unless a person deliberately
exports it.

Data is recorded on a tablet by a clinician signed in with their own named account, created by the
site administrator. Patients are shown grouped by treatment zone and by bed; the clinician opens a
form — admission, vitals and physical examination, laboratory samples and results, discharge — and
records the observations. This is the step performed inside the high-risk zone. On save, the tablet
sends the encounter and its observations to the server over the local Wi-Fi; the server writes them
and confirms.

The server is the **system of record**: all patients, encounters, observations, treatments, users and
clinical form definitions live in its database, at the site. Tablets re-synchronise with it
continuously — clinical data roughly every ten seconds — so a record entered on one tablet appears on
the others within seconds, and several clinicians can work the same ward at once.

Each tablet keeps only a working copy, rebuilt from the server on the next synchronisation.
**Losing or breaking a tablet does not lose patient data.**

### Network

- The kit brings **its own private network**. The site's existing network is not used and is not
  required.
- One router creates a WPA2-protected Wi-Fi network covering the treatment area; the server has a
  fixed address on it, and tablets connect only to the server.
- **No Internet connection is needed** for any clinical function: registration, data entry, charts,
  search and synchronisation all work fully offline.
- The router can optionally take an Internet uplink (cable, existing site Wi-Fi, or a mobile SIM),
  used only for remote technical support and clock synchronisation. If it is absent or fails, clinical
  work is unaffected — it never touches it.

### Where the data goes, and where it does not

- Patient data is stored **only on the site server**. There is no cloud service, no external hosting,
  and no automatic transmission to any other system, in DRC or abroad.
- Data is extracted only by a **deliberate human action**: an export of the clinical data in CSV
  format, written to a USB key at the server, or retrieved by MSF over a secured, opt-in, encrypted
  support connection that is dormant by default.
- Both extraction paths are governed by MSF's data-protection rules and require MSF sign-off before
  they may be used at a site holding patient data.
- Access to the tablets and to the server requires a user account and password. Tablets are
  site-assigned equipment and remain inside the treatment centre.

---

## 5. Installation and support

- The kit is assembled, configured and **fully tested before shipping**, and arrives ready to use.
- On site there is **no installation work**: the server and the router are switched on and the system
  starts by itself. It restarts unattended after a power cut.
- Tablets install the application by **scanning a QR code** displayed by the server, over the local
  Wi-Fi — no Internet, no app store, no cable.
- **No engineer travels to the site.** Support is provided remotely when an Internet uplink is
  available, and otherwise by a diagnostic report the site can send by any means.

---

## 6. Known limitations

- **Tablets are clients, not standalone devices.** They need the local Wi-Fi and a running server in
  order to save new data. A clinician briefly out of range can keep reading a chart, but not keep
  entering data indefinitely.
- **One server at the site** holds the only copy of the data; scheduled backup is part of the
  deployment preparation.
- The underlying OpenMRS platform is a long-established version (1.10.x). It is functional and proven
  in this use, but it is not the current OpenMRS 3 generation; a future version would address this.
