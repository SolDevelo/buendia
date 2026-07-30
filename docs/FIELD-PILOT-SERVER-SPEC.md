# Buendia DRC Field Pilot — Server Hardware Specification

**From:** SolDevelo · **Date:** 2026-07-30 · **Purpose:** the specification for the one on-site server the
pilot needs, so MSF can either **repurpose an existing machine** or buy one. Written to be forwarded to
whoever holds MSF's hardware.

---

## Summary and recommendation

The pilot needs **one** ordinary computer at the site. It runs the database and the medical record
service; the tablets talk to it over Wi-Fi. It needs **no Internet** once installed.

> ### We recommend a laptop / notebook — not a small black box.
>
> Not because a mini-PC wouldn't work, but because for this deployment a laptop is **better on the
> things that actually go wrong in the field**, and because it is the configuration we have already
> installed and tested twice, end to end, with a real tablet.

A **refurbished business laptop** is the best value and is our first suggestion. If MSF already has a
suitable machine on the shelf, **that is the preferred outcome** — zero cost, zero procurement lead
time, and it is exactly what we validated.

**The one hard rule:** the processor must be **Intel or AMD (x86-64)**. See the warning below — this
disqualifies a whole class of current laptops, and the installer refuses to run on them.

---

## Why a laptop, specifically

1. **Its battery is a built-in UPS.** This is the strongest argument. The most plausible way this pilot
   loses patient data is the database being cut off mid-write by a power failure. A laptop simply keeps
   running through a power cut and can shut itself down cleanly when the battery gets low. A mini-PC
   needs a separate UPS to be bought, shipped, wired and maintained.
2. **It has a screen — and we already depend on that.** In our validated install, the tablet was
   provisioned by **scanning the install QR code directly off the laptop's screen.** With a headless box
   you need the printed card (we supply one) and no way to see what the server is doing.
3. **It has a keyboard, so it can be troubleshooted on the spot** — without carrying a monitor,
   keyboard and video cable to a tent.
4. **Someone can just use it.** A laptop is a machine site staff already understand. It can double as a
   normal computer for viewing the admin web page, printing a patient record, or checking the system —
   whereas a sealed box is opaque and, in practice, slightly frightening to non-technical staff.
5. **This is the tested configuration.** Two full installs on a plain Ubuntu 24 laptop: install from a
   USB stick, tablet provisioned by QR, full clinical workflow, verified remotely, then rebooted to
   confirm it comes back on its own after a power cut. Choosing a laptop means shipping what we
   actually proved.

---

## Hard requirements

These are not preferences. The system will not run, or will silently produce wrong data, without them.

| # | Requirement | Why |
|---|---|---|
| 1 | **Intel or AMD processor (x86-64)** | The database version this system needs is only published for x86-64. **The installer checks this and refuses to continue.** |
| 2 | **8 GB RAM** (16 GB comfortable and usually cheap) | Database + application server together. |
| 3 | **SSD, 128 GB minimum** (256 GB recommended) | ~15–20 GB is used by the system, database and images; the rest is headroom for on-box backups. A mechanical hard disk will work but is slow and fragile in transport. |
| 4 | **A working real-time-clock (CMOS) battery** | ⚠️ Explained below — this is the most commonly overlooked item on an older machine. |
| 5 | **A healthy main battery** | This is the power protection. A machine with a dead battery loses the main advantage of being a laptop. |
| 6 | **Able to run Ubuntu 24.04 LTS** | The tested platform. The machine will be wiped and installed with Ubuntu. |
| 7 | **Wired Ethernet port (RJ45)** — strongly preferred | A server should be wired into the network. Many thin laptops no longer have one; a **USB-to-Ethernet adapter** is an acceptable and cheap substitute. Wi-Fi-only will work but is less reliable. |

### ⚠️ Requirement 1 in detail: not every new laptop qualifies

Many laptops sold today use **ARM** processors, and **none of them will work**:

- ❌ **Windows "Copilot+" laptops with Snapdragon X** processors — a large share of current retail stock
- ❌ **Apple Silicon Macs** (M1/M2/M3/M4 and later)
- ❌ **ARM Chromebooks**
- ✅ **Anything with Intel Core / Core Ultra, Intel N-series, or AMD Ryzen** is fine

When checking a spec sheet, the processor name is the thing to look at. If it says Intel or AMD, it
qualifies. If it says Snapdragon, or it's a modern Mac, it does not.

### ⚠️ Requirement 4 in detail: the clock battery matters more than it sounds

The site has no Internet, so the server cannot check the time against anything — **it is the clock
authority for the whole site**, and it gets its own time from a small internal battery when powered off.

On an older laptop that battery is often dead. The symptom is that the machine boots thinking it is
years in the past. Because the time recorded against patient observations flows from this, **a dead
clock battery means every timestamp in the pilot is wrong, with nothing available to correct it.**

Our installer warns if it cannot read the hardware clock, but it cannot fix it. **Please check this on
any repurposed machine**: power it off fully, unplug it for an hour, power it on, and confirm the date
and time are still correct.

---

## Environment — the one case where a laptop is the wrong choice

| Site conditions | Recommendation |
|---|---|
| A building, a hall, or a tent with a table — the server sits in a reasonably clean, ventilated spot | **Laptop.** Recommended. |
| A genuinely dusty tent, high heat, or the machine must be sealed away and never touched | **Fanless mini-PC + external UPS.** See the alternative below. |

A laptop pulls air through a fan, so dust is its main enemy, and a laptop battery in sustained high heat
ages badly (and a swollen battery is a safety issue, not just a fault). We need **B2 q5 / the site
architecture question** — tents in a field vs a building — answered to settle this. If the answer is "a
dusty tent, permanently", tell us and we'll switch to the sealed option.

Practical notes either way: run the laptop with the **lid open** for airflow (we configure it so that
closing the lid does *not* shut the server down, but open is better for cooling), keep it off the floor,
and out of direct sun.

---

## Checklist for repurposing a machine MSF already has

Ten minutes with the machine answers all of this. If every box ticks, we can use it.

- [ ] Processor is **Intel or AMD** — not Snapdragon, not an Apple Silicon Mac
- [ ] **8 GB RAM** or more
- [ ] **SSD of 128 GB** or more
- [ ] Clock keeps correct time after being unplugged overnight (**requirement 4**)
- [ ] Battery still holds a useful charge — roughly, does it survive 30+ minutes unplugged?
- [ ] Battery is **not swollen or deformed** (if it is, the machine is not suitable at any price)
- [ ] Has an **Ethernet port**, or we add a USB-Ethernet adapter
- [ ] Nothing on it needs keeping — **the disk will be wiped**
- [ ] It is **surplus for the whole pilot**, not borrowed — this machine holds the only copy of the
      site's patient data and cannot be taken back mid-pilot

**Age:** a 5–8 year old business laptop is entirely adequate. This software is not demanding; it was
designed in 2016 for far weaker hardware. Condition of the battery and clock matters much more than the
processor generation.

---

## If buying: options available in Switzerland

Prices move, so treat these as *classes of machine* and current examples rather than a fixed quote.
[Digitec](https://www.digitec.ch/en) and [Brack](https://www.brack.ch) are the usual Swiss retailers;
Digitec also has dedicated
[refurbished](https://www.digitec.ch/de/s1/producttype/toplist/rating/notebook-refurbished-3710) and
[secondhand](https://www.digitec.ch/en/s1/secondhand/producttype/notebooks-6) notebook sections.

### Option A — Refurbished business laptop ⭐ our recommendation

The best value by a wide margin, and it meets the spec comfortably.

- **What to look for:** a **Lenovo ThinkPad** (T/L/E series), **Dell Latitude**, or **HP EliteBook /
  ProBook**, with an Intel Core i5 or better, **16 GB RAM**, **256 GB SSD**.
- **Why this class:** business laptops nearly always have a **real Ethernet port**, they are extremely
  well supported by Linux, spare parts and batteries are easy to get, and they are built for years of
  daily handling.
- **Buy a new battery with it if the listing doesn't confirm battery health** — on a refurbished
  machine that is the part most likely to be tired, and here the battery is the power protection.

### Option B — New entry-level business laptop

If procurement rules require new hardware with a warranty. All of these are x86 and meet the spec:

- **Lenovo ThinkPad E14** (Intel Core Ultra 5, 16 GB) — available at Digitec
- **HP ProBook 4 G1i** (Intel Core Ultra 5 225U, 16 GB, 512 GB SSD) — available at Digitec
- **Dell Latitude** 5000-series equivalents

These are considerably more powerful than the pilot needs; the reason to choose one is warranty and
supply, not performance.

### Option C — Semi-rugged laptop

Only if the deployment environment is genuinely harsh *and* a laptop is still wanted: **Dell Latitude
Rugged** or **Panasonic Toughbook**. Both are dust- and drop-resistant with sealed keyboards, and both
are several times the price of Option A. Worth pricing only if the site is a field tent — in which case
compare against the fanless option below.

### The alternative — fanless mini-PC + external UPS

The right answer *only* for a permanently dusty/hot, sealed installation. Fully supported by our
installer; it just gives up the screen, keyboard and built-in battery.

- **Consumer, Swiss retail:** [**Minix NEO Z100-0dB**](https://www.digitec.ch/en/s1/product/minix-neo-z100-0db-intel-n100-8-gb-256-gb-ssd-intel-uhd-graphics-pc-42926202)
  (Intel N100, 8/16 GB, SSD) — genuinely fanless, at Digitec. Similar: Geekom Mini Air 12, Beelink
  S12 Pro, Minisforum UN100L.
- **Industrial, built for this:** [**Shuttle DS10U series**](https://www.shuttle.eu/en/products/slim/ds10u)
  (fanless, approved for 24/7, 12 V or 19 V input) or the newer
  [**OnLogic CL260**](https://www.onlogic.com) (fanless, 12–24 V wide DC input, up to 8 GB RAM — note
  that 8 GB is our minimum, so specify it fully populated). These accept **12 V DC directly**, which
  makes running from a battery or solar setup straightforward.
- ⚠️ **Budget a UPS with it.** Without one, this option is *less* protected against power loss than a
  second-hand laptop, which is the pilot's main data-loss risk.

---

## What we do to the machine

For information — none of this needs a decision, but it explains why an ordinary laptop is safe to use
as a server:

- The disk is **wiped and Ubuntu 24.04 LTS installed**.
- The install itself is **one command from a USB stick** and takes roughly 10–15 minutes.
- We configure the machine so that **closing the lid does not stop the server**, and **sleep/suspend is
  disabled entirely** — a laptop left alone will not drop off the network.
- We configure it as the **time authority** for the site's network, since there is no Internet.
- Docker comes up automatically on boot and the system restarts itself after a power cut — **confirmed
  by testing:** the machine was rebooted and the tablet reconnected with no intervention.

**One thing still open on our side:** automatic clean shutdown when the battery gets low. It is
straightforward on a laptop (the battery reports its own level) and needs an external UPS to be wired up
on a mini-PC. We will finish this once the hardware shape is decided — **which is the main reason we'd
like this decision reasonably early.**

---

## The decision we need

1. **Does MSF have a suitable machine to repurpose?** Run the checklist above. If yes, this is settled
   at no cost — and please tell us the processor, RAM and disk so we can confirm.
2. **If not, which option should be purchased** (A, B, C, or the fanless alternative)? We recommend
   **A — a refurbished business laptop with a good battery.**
3. **What is the site environment** — a building, or a dusty tent? This is the one input that could
   overturn the laptop recommendation, and it is the same question as **B2** in the configuration
   request.
4. **Who buys it**, and does it need to reach us for staging before it goes to the site? Preparing it
   here is significantly easier than preparing it on arrival.
