# KISS GUI — macOS modernization notes

## This build at a glance
- **Name / version:** `2.0.34-arm64` — "KISS GUI · Apple Silicon" (upstream GUI is 2.0.34;
  the `-arm64` suffix marks this native macOS build). Window title shows "· Apple Silicon".
- **What it fixes:** the constant crashes on Apple Silicon / macOS Tahoe, and the dead
  Backup/Restore buttons.
- **Artifact:** `~/kiss-gui-build/out/KISS GUI.app` (native arm64, ad-hoc signed).
- **Build it:** `./build-macos-arm64.sh`  • **Run with logs:** `./run-macos-debug.sh`

## Files added / changed in this repo
- `build-macos-arm64.sh` — native arm64 build (new).
- `run-macos-debug.sh` — launch the build with console logging (new).
- `MODERNIZATION.md` — this document (new).
- `content/configuration.js` — Backup/Restore rewritten off `chrome.fileSystem` (see below).
- `start.js` — window title gets "· Apple Silicon".
- `package.json` — removed obsolete `--disable-features=nw2` chromium-arg.
- `CHANGELOG` — entry for `2.0.34-arm64`.

## Backup / Restore fix
The Configuration-tab **Backup** and **Restore** buttons did nothing. Cause: they used the
Chrome-Apps `chrome.fileSystem.chooseEntry()` API, which under NW.js fails immediately with
*"Invalid calling page. This function can't be called from a background page."* — the error
only went to the console, so the buttons appeared dead. Rewritten in `content/configuration.js`
to use NW.js-native file dialogs (`<input nwsaveas>` / `<input type=file>`) plus Node `fs`:
**Backup** writes the connected FC's settings to a `.txt` file; **Restore** reads one back.

The same `chrome.fileSystem` bug also broke the `.hex` file pickers in the firmware flashers;
these are now fixed too with the same `<input type=file>` + fs pattern:
`content/fc_flasher.js` (FC v2), `content/flasher.js` (FC), `content/esc_flasher.js` (ESC).
Note: the flash *operation* itself (serial/USB DFU) was not changed — only the file selection.
A real firmware flash should still be tested against hardware before relying on it.

## Background: why the app crashed on Apple Silicon / recent macOS
The shipped builds (and `gulpfile.js` / nw-builder@3.x) produce an **Intel-only**
NW.js app on an ancient Chromium (the historical `flyduino/kiss-gui` wrapper used
NW.js 0.17; this repo's gulpfile pins 0.36.4 / `nw@^0.37`). On Apple Silicon it runs
under **Rosetta 2** and segfaults inside the old Chromium engine — observed as repeated
`SIGSEGV / EXC_BAD_ACCESS` crashes on macOS Tahoe, with or without a drone connected.

The fix is to ship a **native arm64** runtime.

## Option A — DONE: native arm64 rebuild on NW.js 0.77 (`build-macos-arm64.sh`)
NW.js **0.77.0 (Chromium 114)** is the newest tested NW.js that still bundles the legacy
`chrome.serial` / `chrome.usb` APIs this app uses, so it runs **unchanged**. The build
script downloads the arm64 runtime, drops the source into `app.nw`, brands the bundle,
and ad-hoc signs it. Verified: native arm64, GUI loads, `chrome.serial.getDevices()`
returns real ports, no crashes.

Run: `./build-macos-arm64.sh` → `~/kiss-gui-build/out/KISS GUI.app`.

Limitation: Chromium 114 is old/unmaintained and `chrome.serial`/`chrome.usb` are
deprecated Chrome-App APIs. Fine as an immediate fix; Option B is the long-term path.

## Option B — TODO: move to latest NW.js + standard web device APIs
Latest NW.js (tested **0.112 / Chromium 149**) **removed** `chrome.serial` and
`chrome.usb`. They are replaced by the standardized **Web Serial** (`navigator.serial`)
and **WebUSB** (`navigator.usb`), both confirmed present in 0.112. Everything else the
app uses still works there (`chrome.storage`, `chrome.notifications`, `chrome.app`,
`chrome.runtime.getManifest`).

Work required:
1. **`js/chrome_serial.js`** (~293 lines, 14 `chrome.serial` calls) → rewrite onto
   `navigator.serial`:
   - `getDevices()` → `navigator.serial.getPorts()` (already-granted ports).
   - `connect(path, {bitrate})` → `port.open({ baudRate })`; read via
     `port.readable.getReader()`, write via `port.writable.getWriter()`.
   - `onReceive` / `onReceiveError` listeners → the reader loop / stream errors.
   - `chrome.runtime.lastError` checks → try/catch on the promises.
2. **`js/libraries/stm32usbdfu.js`** (~770 lines, 11 `chrome.usb` calls) → rewrite onto
   `navigator.usb` (`requestDevice`, `open`, `claimInterface`, `controlTransferIn/Out`,
   `reset`). This is the DFU firmware-flasher.
3. **Permission / device-picker model.** Web Serial/WebUSB normally require a user gesture
   and show a chooser. NW.js lets you auto-grant by handling the picker events on the
   window, e.g.:
   ```js
   // pick the first offered port/device so enumeration stays programmatic
   win.on('select-serial-port', (ports, cb) => cb(ports[0] ? ports[0].portId : ''));
   ```
   (and the equivalent `select-usb-device`/`usb` permission handling). Confirm the exact
   NW.js API for the chosen version.
4. Update `build-macos-arm64.sh` `NWJS_VERSION` to the latest stable; consider a
   **universal** build for Intel users too.
5. Re-test end-to-end against real hardware: serial connect/read/write **and** a DFU flash.

## How to verify everything works
Launch with logging so the app's console output is captured:
`./run-macos-debug.sh` → log at `~/kiss-gui-build/kiss-session.log`
(app `console.log`/`console.error` appear as lines containing `CONSOLE`).

Checklist:
1. **App launches, no crash.** Confirmed: arm64, 0 crashes (vs. the old Intel build's repeated
   `SIGSEGV`). Cross-check: no new `nwjs-*.ips` in `~/Library/Logs/DiagnosticReports/`.
2. **Drone connects.** Plug in the FC, pick its port (`/dev/cu.usb...`), Connect. The log should
   show the settings being received (`"RECEIVED:"` from configuration.js) and the firmware
   version populates on the Configuration tab.
3. **Backup writes a file.** On the Configuration tab (connected), click **Backup** → a Save
   dialog appears → choose a location → a `kissfc-backup.txt` is written. The log shows
   `"Config has been exported to: <path>"`. Open the file: human-readable JSON of the settings.
4. **Restore reads it back.** Click **Restore** → pick that `.txt` → settings reload (log shows
   `"Import config from: <path>"`).
5. **Other tabs render** (Rates, Data Output / 3D view, etc.) without console errors.

Diagnose later from the log:
`grep CONSOLE ~/kiss-gui-build/kiss-session.log` (app messages) and
`grep -Ei "uncaught|TypeError|ReferenceError" ~/kiss-gui-build/kiss-session.log` (JS errors).
