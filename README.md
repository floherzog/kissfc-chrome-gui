# KISS GUI

The KISS GUI is the crossplatform configuration tool for the [Flyduino](https://flyduino.net) flight control system like the KISSfc, KISScc and KISSfcV2F7

It runs as an app within Google Chrome and allows you to configure the flight controller

---

> ### ⚠️ Unofficial community build (Apple Silicon / macOS)
> This is an **unofficial community fork** — **not affiliated with or endorsed by Flyduino**.
> It rebuilds the macOS app natively for **Apple Silicon (arm64)** so it no longer crashes
> under Rosetta on recent macOS, and fixes a few bugs (Backup/Restore, firmware file pickers,
> serial reconnect, 3D view). See [`MODERNIZATION.md`](MODERNIZATION.md) and [`CHANGELOG`](CHANGELOG).
>
> **Download the prebuilt app:** see the [Releases](../../releases) page. The app is
> ad‑hoc signed (not notarized), so on first launch **right‑click the app → Open** to get
> past Gatekeeper.
>
> Original project: [flyduino/kissfc-chrome-gui](https://github.com/flyduino/kissfc-chrome-gui).
> Licensed under GPL‑3.0 (unchanged).

---


## Installation

Depending on target operating system, _KISS GUI_ is distributed as _standalone_ application or Chrome App.


## Supported Hardware

- KISS CC Compact CTRL
- KISS FC 32bit Flight Controller
- KISS FC v2 F7 Flight Controller

- Licensed hardware like (KISS iFlight Flyduino Kiss Licensed Flight Controller)

## Required Tools &Driver
- KISS FC v2 F7
 * [CP2102 Driver](https://www.silabs.com/products/development-tools/software/usb-to-uart-bridge-vcp-drivers)

- KISS FC / KISS CC
 * [STM Virtual Comport Driver](http://www.st.com/en/development-tools/stsw-stm32102.html)
 * [DFuse](http://www.st.com/en/development-tools/stsw-stm32080.html)
 * [Zadig](http://zadig.akeo.ie/)