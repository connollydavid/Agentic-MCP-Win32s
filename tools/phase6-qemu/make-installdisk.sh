#!/usr/bin/env bash
# make-installdisk.sh — build a FAT16 *data* disk (attached as D: in the guest)
# holding the full Windows 3.11 SETUP tree + the Win32s 1.25a redist, so the
# operator installs from one drive (no 6-floppy swapping). Built entirely with
# mtools — no running VM required. Deterministic / repeatable.
#
# Output: vendor/win311/build/install-d.img  (32MB raw, 1 primary FAT16 partition)
#   D:\WIN311\   all files from the six Win 3.11 install floppies, merged
#   D:\W32S\     the Win32s 1.25a Setup tree (run D:\W32S\SETUP.EXE inside Windows)
#
# This is free and unencumbered software released into the public domain.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
B="$HERE/../../vendor/win311/build"; FLOP="$B/floppies"; STAGE="$B/stage"
IMG="$B/install-d.img"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

echo "[1/4] merge the six Win 3.11 floppies into one SETUP tree"
mkdir -p "$TMP/WIN311"
for n in 1 2 3 4 5 6; do mcopy -n -i "$FLOP/win311-disk$n.img" "::/*" "$TMP/WIN311/" 2>/dev/null || true; done
echo "    $(find "$TMP/WIN311" -type f | wc -l) files merged"

echo "[2/4] collect the Win32s 1.25a Setup tree"
cp -r "$STAGE/w32s/Microsoft Win32s 1.25a (1.25.142.0)/Setup" "$TMP/W32S"
echo "    $(find "$TMP/W32S" -type f | wc -l) Win32s files"

echo "[3/4] create a 33MB raw disk, one bootable FAT16 primary partition (sfdisk)"
qemu-img create -f raw "$IMG" 33M >/dev/null
printf 'label: dos\nstart=63, type=6, bootable\n' | sfdisk --no-reread -q -f "$IMG" >/dev/null 2>&1
OFF=32256          # partition start: sector 63 * 512
mformat -i "$IMG@@$OFF" -v WIN311INST ::

echo "[4/4] copy the trees onto D:"
mmd -i "$IMG@@$OFF" ::/WIN311 ::/W32S
mcopy -i "$IMG@@$OFF" -s -Q "$TMP/WIN311/"* ::/WIN311/
mcopy -i "$IMG@@$OFF" -s -Q "$TMP/W32S/"*   ::/W32S/
echo "=== D: top-level ==="; mdir -i "$IMG@@$OFF" ::/
echo "=== D:\\WIN311 (SETUP present?) ==="; mdir -i "$IMG@@$OFF" ::/WIN311 2>/dev/null | grep -iE 'SETUP|files' | head
echo "=== D:\\W32S (SETUP present?) ==="; mdir -i "$IMG@@$OFF" ::/W32S 2>/dev/null | grep -iE 'SETUP|files' | head
echo "done: $IMG"
