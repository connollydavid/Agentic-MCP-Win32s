# Phase 6 / 6.2 — Windows 3.11 + Win32s 1.25a guest (QEMU)

Builds and runs the **Win16/Win32s baseline tier** guest for Phase 6 cross-platform
testing. The device target is Windows 3.x + Win32s 1.25a; this stands up exactly that
under QEMU so the device's polling-exec / `shared_vm` / codepage-encoding / no-threads
floor can be exercised on a real Win32s.

All guest media is the **hash-pinned, gitignored** vendored Microsoft media under
`vendor/win311/` (provenance + hashes in `plan/PHASE6.md`, **status TBC** — integrity-
confirmed, authenticity unverified). Nothing here fetches from the network or embeds a
binary; the scripts only assemble what `build.sh` stages.

## Why the install is driven on the Windows host, not here

QEMU **cannot run in the WSL2 agent sandbox** — the harness reaps it after a few seconds
(SIGUSR1 → exit 144); only sub-5-second runs survive, less than a DOS boot. So:

- **Deterministic prep + verification runs here** (this side), via `build.sh` + `mtools`
  (fast, no long-running process). The disk images are built and inspected directly.
- **The interactive install runs on the Windows host** (`run-win.bat`), where there is no
  reaper and you have a native display to drive the two GUI installers.
- The result — `vendor/win311/build/hdd.img` — persists on the shared drive; this side
  then verifies it with `mtools` and captures the installed `C:` tree so future rebuilds
  are scripted.

## Files

| File | Runs | Purpose |
|---|---|---|
| `build.sh` | here (WSL) | stage all media deterministically: DOS boot floppy, the C: disk (pre-partitioned bootable FAT16, unformatted), the D: install disk (`make-installdisk.sh`) |
| `make-installdisk.sh` | here (WSL) | build `install-d.img` = D: with `WIN311\` (merged SETUP tree) + `W32S\` (Win32s 1.25a) |
| `run-win.bat` | **Windows host** | launch the guest in QEMU-for-Windows (`install` / `hdd` / `run` phases) |
| `run.sh` | any real QEMU host | the canonical Linux QEMU invocation (CI / non-sandboxed hosts) |
| `mon.sh` | here (WSL) | drive/observe a *locally* running guest via the QEMU monitor (screendump→PNG, sendkey) — only usable in the <5s windows or on a non-reaping host |

## Build (here)

```sh
tools/phase6-qemu/build.sh          # idempotent; keeps an existing hdd.img
FRESH=1 tools/phase6-qemu/build.sh  # recreate a blank, freshly-partitioned C:
```

Produces under `vendor/win311/build/` (gitignored): `hdd.img` (C:, 500 MB, bootable FAT16
primary, **unformatted**), `install-d.img` (D:), `floppies/dos622-boot.img`.

## Install (Windows host — operator checklist)

Prereq: QEMU for Windows (https://qemu.weilnetz.de/w64/), `qemu-system-i386.exe` on PATH.
(VirtualBox works too — attach `hdd.img`/`install-d.img` as raw disks and
`dos622-boot.img` as a floppy; same steps.)

1. `tools\phase6-qemu\run-win.bat install`
   Boots the **DOS 6.22** floppy → `A:\>`. C: is a blank partitioned disk; D: is the
   install disk.
2. **Make C: bootable** (FDISK already done for you):
   ```
   FORMAT C: /S
   ```
   Answer `Y`; when done, optionally `LABEL C: WIN311`.
3. Close QEMU, then `run-win.bat hdd` — boots from **C:** (`C:\>`), D: still attached.
4. **Install Windows 3.11:**
   ```
   D:\WIN311\SETUP
   ```
   Choose **Express Setup**; accept defaults (install to `C:\WINDOWS`); when it asks,
   skip printers/network; let it finish and exit to DOS (don't reboot into the floppy).
5. **Install Win32s 1.25a:** start Windows (`WIN`), then in Program Manager
   **File ▸ Run** →
   ```
   D:\W32S\SETUP.EXE
   ```
   Accept defaults; it copies the Win32s runtime + the `W32S.386` VxD and updates
   `SYSTEM.INI`; let it restart Windows. (FreeCell under `C:\WIN32S\` is the smoke test —
   if it runs, Win32s is live.)
6. Shut down. `hdd.img` is now the installed baseline guest.

## After the install (here — verification + repeatability)

- Verify via mtools: `mdir -i vendor/win311/build/hdd.img@@32256 ::/WINDOWS` and confirm
  `SYSTEM.INI` carries the `device=*w32s.386` line (Win32s loaded).
- Capture the installed `C:` tree so rebuilds are scripted (no re-driving): tar it out
  with mtools; a future `make-c-from-capture.sh` repopulates a fresh formatted C:.
- Record `hdd.img`'s sha256 in `vendor/win311/SHA256SUMS` as the pinned base image.
- Then deploy the device (`mcp-w32s.exe`) onto C:, launch `run-win.bat run`, and point the
  host wire harness at `127.0.0.1:31800`.
