#!/usr/bin/env bash
# build.sh — deterministically stage the Win 3.11 + Win32s 1.25a guest media
# from the hash-pinned vendored Microsoft archives. Repeatable: same inputs ->
# same staged media. Does NOT clobber an existing hdd.img (an install in
# progress) unless FRESH=1.
#
# Inputs (gitignored, hash-pinned — see plan/PHASE6.md, status TBC):
#   vendor/win311/dos622_bundle/MS-Dos 6.22.iso   (bootable DOS 6.22; El Torito floppy)
#   vendor/win311/floppies/disk{1..6}.img         (Microsoft Windows 3.11 install floppies)
#   vendor/win311/win32s_125/win32s-1.25a-1.25.142.0.7z  (WinWorld PW1118 redist)
#
# This is free and unencumbered software released into the public domain.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
V="$HERE/../../vendor/win311"
B="$V/build"; FLOP="$B/floppies"; STAGE="$B/stage"
mkdir -p "$FLOP" "$STAGE"

# 7z exits non-zero on the DOS ISO's El Torito header (reports the big-endian
# boot-catalog as an error) yet still extracts the requested file. So ignore the
# exit code entirely and verify the artifact afterwards — never trust the claim.
un7z() { 7z "$@" >/dev/null 2>&1 || true; }

echo "[1/4] extract bootable DOS 6.22 floppy"
un7z e -y "$V/dos622_bundle/MS-Dos 6.22.iso" "[BOOT]/Boot-1.44M.img" -o"$FLOP"
mv -f "$FLOP/Boot-1.44M.img" "$FLOP/dos622-boot.img"
[ -s "$FLOP/dos622-boot.img" ] || { echo "FAILED: dos622-boot.img not extracted" >&2; exit 1; }

echo "[2/4] stage the 6 Windows 3.11 install floppies"
for n in 1 2 3 4 5 6; do cp -f "$V/floppies/disk$n.img" "$FLOP/win311-disk$n.img"; done

echo "[3/4] extract Win32s 1.25a redist (staged to C: post-format, not a floppy)"
rm -rf "$STAGE/w32s"; mkdir -p "$STAGE/w32s"
un7z x -y "$V/win32s_125/win32s-1.25a-1.25.142.0.7z" -o"$STAGE/w32s"
[ -d "$STAGE/w32s/Microsoft Win32s 1.25a (1.25.142.0)/Setup" ] || { echo "FAILED: win32s Setup not extracted" >&2; exit 1; }

echo "[4/5] C: hard disk image (pre-partitioned, so the operator skips FDISK)"
if [ -f "$B/hdd.img" ] && [ "${FRESH:-0}" != "1" ]; then
  echo "    keeping existing hdd.img ($(du -h "$B/hdd.img" | cut -f1)); FRESH=1 to recreate"
else
  qemu-img create -f raw "$B/hdd.img" 500M >/dev/null
  # one bootable FAT16 primary spanning the disk, left UNFORMATTED — the
  # operator runs `FORMAT C: /S` once (canonical DOS way to make C: bootable).
  printf 'label: dos\nstart=63, type=6, bootable\n' | sfdisk --no-reread -q -f "$B/hdd.img" >/dev/null 2>&1
  echo "    created 500M hdd.img with a bootable FAT16 primary partition (unformatted)"
fi

echo "[5/5] D: install data disk (Win 3.11 SETUP + Win32s 1.25a)"
"$HERE/make-installdisk.sh" >/dev/null
echo "    built install-d.img"
echo "done. media staged under $B"
