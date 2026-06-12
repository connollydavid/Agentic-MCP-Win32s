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

---

# NT 3.1 lane — Windows NT 3.1 Advanced Server (native-Win32 floor, task #40)

A **separate, isolated lane** that reuses the Win32s assets/patterns but never touches the
win311 guest: own disk (`vendor/winnt31/build/hdd.img`), own ports (COM1→**31801**,
monitor→**55556**, VNC **:1**), reusing the `dos622-boot.img` floppy + the mtools build
pattern + `mon-win.sh`/`wire_accept.py`. Goal: the device **loads + runs** on NT 3.1 and
**wire-responds over the OS-serial path** (`CreateFile`+`SetCommState`, which works on NT —
unlike Win32s, where the #37 direct-UART tier was needed) — the NT counterpart to #35.

**NT 3.1 install facts (verified from the disc):** the CD is **not bootable**; `WINNT.EXE`
has **no `/B`** floppyless switch (NT 3.5+ only) — it copies the source to a temp dir on C:
and **writes a Setup boot floppy**, then you reboot from it; **no ready floppy image** ships
on the CD (the `DISK1/DISK2` entries are 2-byte volume tags). Hence: DOS boots, runs
`WINNT /S:D:\I386`, writes the boot floppy, reboot → NT text setup.

## Build (here)

```sh
tools/phase6-qemu/build.sh        # win311 lane first (provides dos622-boot.img)
tools/phase6-qemu/build-nt31.sh   # NT lane; vendor the ISO at vendor/winnt31/WINNT_AS_511.ISO
```

Produces under `vendor/winnt31/build/` (gitignored): `hdd.img` (C:, 500 MB, bootable FAT16,
**unformatted**), `install-i386.img` (D: = the `I386` setup tree, 64 MB FAT16),
`floppies/dos622-boot.img` (reused), `floppies/ntsetup-boot.img` (blank, for WINNT to write).

## Install (Windows host — operator checklist, monitor-driven)

NT 3.1 is the **hardest NT to emulate** — the launcher pins `-cpu 486 -vga cirrus -net none`.
The monitor commands below run from WSL: `MON_PORT=55556 bash tools/phase6-qemu/mon-win.sh cmd "…"`.

1. `tools\phase6-qemu\run-nt-win.bat install` → DOS `A:\>` (C: blank, D:=I386 source).
2. **Make C: bootable:** `FDISK /MBR` then `FORMAT C: /S` (answer `Y`). The `FDISK /MBR`
   is **required**: `sfdisk` wrote the partition table but **no MBR bootstrap code**, and
   `FORMAT /S` only writes the partition's VBR — without the MBR loader, SeaBIOS hangs at
   "Booting from Hard Disk…". Then `eject floppy0` (monitor) so the next reset boots DOS
   from C:, and `system_reset`.
3. At `C:\>`, kick off NT setup: `D:\I386\WINNT /S:D:\I386`. It copies files to a C: temp dir.
4. When WINNT asks for **a blank formatted floppy in A:**, swap it in (monitor):
   `change floppy0 <build>\floppies\ntsetup-boot.img` — let WINNT write the Setup boot floppy.
5. On WINNT's reboot prompt, `system_reset` → boots the **NT Setup floppy** → NT text-mode
   setup (express; let it detect the IDE disk + Cirrus video; FAT; install to `C:\WINNT`).
   It reboots itself through text → GUI setup; skip networking (no NIC). Finishes in NT.
6. Shut down. `hdd.img` is the installed NT 3.1 guest.

## Acceptance (here — the #35-equivalent wire round-trip)

- Deploy `mcp-w32s.exe` onto C: (mtools or via a deploy floppy), `run-nt-win.bat run`.
- Launch it under NT with `/SERIAL:COM1 /BAUD:19200`; point the harness at `127.0.0.1:31801`
  (`SERIAL_PORT=31801 python3 tools/phase6-qemu/wire_accept.py`) and confirm the ready line +
  an echo round-trip (`status:ok`). On NT the OS-serial path serves it (no direct-UART).
- **If NT 3.1 fights QEMU** (disk/CPU/video detection) after reasonable effort: **stop and
  consult** before pivoting to NT 3.51 (per plan/PHASE6.md #40).
