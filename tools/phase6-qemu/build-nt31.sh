#!/usr/bin/env bash
# build-nt31.sh — stage the Windows NT 3.1 Advanced Server guest media in a
# SEPARATE lane that reuses the Win 3.11/Win32s assets but never touches that
# guest. Deterministic / repeatable; built entirely with qemu-img + mtools +
# 7z (no running VM).
#
# NT 3.1 install facts that shape this (verified from the disc itself):
#   - The CD is NOT bootable (no NT 3.x/4.0 CD is El-Torito bootable).
#   - WINNT.EXE has NO /B floppyless switch (that arrived in NT 3.5): its usage is
#       WINNT [/S:sourcepath] [/T:tempdrive] [/I:inffile] [/X|[/F][/C]]
#     so it copies the source to a temp dir on C: and *writes a Setup boot floppy*,
#     then you reboot from that floppy into NT text-mode setup.
#   - No ready-made floppy image ships on the CD (the "DISK1/DISK2" entries are
#     2-byte volume tags). The boot floppy is manufactured by WINNT.EXE.
# So the lane provides: a DOS 6.22 boot floppy (reused) to FORMAT C: and run WINNT,
# the I386 tree on a FAT data disk (no MSCDEX needed), a blank C: to format, and a
# blank formatted floppy for WINNT to write the Setup boot floppy onto.
#
# Inputs (gitignored, operator-vendored — see plan/PHASE6.md provenance):
#   vendor/winnt31/WINNT_AS_511.ISO   (NT 3.1 AS, sha256 940dcefd…; or set NT_ISO=)
#   vendor/win311/build/floppies/dos622-boot.img   (reused DOS 6.22 boot floppy)
#
# This is free and unencumbered software released into the public domain.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/../.."
V="$ROOT/vendor/winnt31"
B="$V/build"; FLOP="$B/floppies"
W311FLOP="$ROOT/vendor/win311/build/floppies"
ISO="${NT_ISO:-$V/WINNT_AS_511.ISO}"
mkdir -p "$FLOP"

[ -f "$ISO" ] || { echo "FAILED: NT 3.1 ISO not found at $ISO (vendor it there or set NT_ISO=)" >&2; exit 1; }
[ -f "$W311FLOP/dos622-boot.img" ] || { echo "FAILED: reused DOS 6.22 boot floppy missing ($W311FLOP/dos622-boot.img) — run build.sh in the win311 lane first" >&2; exit 1; }

echo "[1/4] reuse the DOS 6.22 boot floppy (to FORMAT C: and run WINNT under DOS)"
cp -f "$W311FLOP/dos622-boot.img" "$FLOP/dos622-boot.img"

echo "[2/4] C: system disk — 500M raw, one bootable FAT16 primary, UNFORMATTED"
# 500M keeps the whole partition within the first 1024 cylinders (NT 3.1 must boot
# from there). Left unformatted: the operator runs FORMAT C: /S once (canonical DOS
# way to make C: a bootable DOS partition), exactly as the win311 lane does.
if [ -f "$B/hdd.img" ] && [ "${FRESH:-0}" != "1" ]; then
  echo "    keeping existing hdd.img ($(du -h "$B/hdd.img" | cut -f1)); FRESH=1 to recreate"
else
  qemu-img create -f raw "$B/hdd.img" 500M >/dev/null
  printf 'label: dos\nstart=63, type=6, bootable\n' | sfdisk --no-reread -q -f "$B/hdd.img" >/dev/null 2>&1
  echo "    created 500M hdd.img with a bootable FAT16 primary partition (unformatted)"
fi

echo "[3/4] D: install data disk — the I386 tree on a 64M FAT16 disk (WINNT /S:D:\\I386)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
7z x "$ISO" -o"$TMP" "I386/*" -y >/dev/null 2>&1 || true
[ -f "$TMP/I386/WINNT.EXE" ] || { echo "FAILED: I386/WINNT.EXE not extracted from $ISO" >&2; exit 1; }
echo "    I386: $(find "$TMP/I386" -type f | wc -l) files, $(du -sh "$TMP/I386" | cut -f1)"
IMG="$B/install-i386.img"
qemu-img create -f raw "$IMG" 64M >/dev/null
printf 'label: dos\nstart=63, type=6, bootable\n' | sfdisk --no-reread -q -f "$IMG" >/dev/null 2>&1
OFF=32256          # partition start: sector 63 * 512
mformat -i "$IMG@@$OFF" -v NT31I386 ::
mmd   -i "$IMG@@$OFF" ::/I386
mcopy -i "$IMG@@$OFF" -s -Q "$TMP/I386/"* ::/I386/

echo "[4/4] blank formatted HD floppy for WINNT to write the Setup boot floppy onto"
# WINNT.EXE requires a formatted, blank high-density floppy in A:. Provide one;
# the operator swaps it into floppy0 via the monitor when WINNT asks.
qemu-img create -f raw "$FLOP/ntsetup-boot.img" 1440K >/dev/null
mformat -i "$FLOP/ntsetup-boot.img" -f 1440 ::

echo "=== D: top-level ==="; mdir -i "$IMG@@$OFF" ::/
echo "=== D:\\I386 (WINNT.EXE present?) ==="; mdir -i "$IMG@@$OFF" ::/I386 2>/dev/null | grep -iE 'WINNT|TXTSETUP|files' | head
echo "done. NT 3.1 lane media staged under $B"
