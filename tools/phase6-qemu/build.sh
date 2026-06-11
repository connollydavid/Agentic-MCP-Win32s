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

# 7z exits non-zero on some archives (e.g. the El Torito header) yet still
# extracts; ignore the exit code and verify the artifact afterwards.
un7z() { 7z "$@" >/dev/null 2>&1 || true; }

echo "[1/4] genuine MS-DOS 6.22 boot floppy (WinWorld Disk1 + a clean autoexec)"
# Use the AUTHENTIC WinWorld MS-DOS 6.22 Disk 1 (genuine boot sector + IO.SYS/
# MSDOS.SYS/COMMAND.COM + FORMAT.COM/FDISK.EXE; its COMMAND.COM is byte-identical
# to the bundle's, confirming the bundle's DOS binaries were genuine — only the
# bundle's "Looka" boot wrapper was unofficial, so that boot floppy is rejected).
# Its stock AUTOEXEC.BAT auto-runs the 3-disk SETUP (busetup); replace it with a
# trivial one so the floppy boots straight to A:\ where we run FORMAT C: /S.
WWDOS="$V/dos622_winworld/Microsoft DOS 6.22 (Upgrade) (3.5)"
[ -f "$WWDOS/Disk1.img" ] || { echo "FAILED: WinWorld DOS 6.22 Disk1 missing ($WWDOS)" >&2; exit 1; }
cp -f "$WWDOS/Disk1.img" "$FLOP/dos622-boot.img"
printf '@echo off\r\nprompt $p$g\r\n' > "$STAGE/AUTOEXEC.BAT"
mcopy -o -i "$FLOP/dos622-boot.img" "$STAGE/AUTOEXEC.BAT" ::/AUTOEXEC.BAT
cp -f "$WWDOS/Disk2.img" "$FLOP/dos622-disk2.img"
cp -f "$WWDOS/Disk3.img" "$FLOP/dos622-disk3.img"
[ -s "$FLOP/dos622-boot.img" ] || { echo "FAILED: dos622-boot.img" >&2; exit 1; }

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
