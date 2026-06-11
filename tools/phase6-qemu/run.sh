#!/usr/bin/env bash
# run.sh — Phase 6 / work-item 6.2 QEMU launcher for the
# Windows 3.11 + Win32s 1.25a guest (the Win16/Win32s baseline tier).
#
# Repeatable by construction: all guest media is the hash-pinned, gitignored
# vendored Microsoft media under vendor/win311/ (see plan/PHASE6.md provenance,
# status TBC). This script only assembles + boots it; it makes no network
# fetches and embeds no binaries.
#
# Displays a VNC server for an operator to drive the interactive installer
# screens; exposes the guest COM1 as a host TCP server for the device wire
# harness; exposes the QEMU monitor on TCP for scripted screendump/sendkey.
#
# Usage:  run.sh <phase>
#   boot-dos   first boot from the DOS 6.22 boot floppy (partition/format C:)
#   hdd        boot from the installed hard disk (C:)
# Env overrides: VNC_DISP, SERIAL_PORT, MON_PORT, MEM, CPU.
#
# This is free and unencumbered software released into the public domain.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
BUILD="$HERE/../../vendor/win311/build"     # gitignored: images live here
FLOP="$BUILD/floppies"

PHASE="${1:-hdd}"
VNC_DISP="${VNC_DISP:-0}"                     # VNC on 5900+VNC_DISP
SERIAL_PORT="${SERIAL_PORT:-31800}"          # guest COM1  -> host TCP (device harness)
MON_PORT="${MON_PORT:-55555}"                # QEMU monitor (screendump/sendkey)
MEM="${MEM:-32}"                              # MB; Win32s wants >=8, 32 is comfortable
CPU="${CPU:-pentium}"                         # period-appropriate; Win32s needs 386+

[ -f "$BUILD/hdd.img" ] || { echo "missing $BUILD/hdd.img — run build.sh first" >&2; exit 1; }

# -daemonize forks QEMU into a detached daemon that SURVIVES the launching
# shell/tool-call (which otherwise SIGTERMs the process group). VNC + monitor +
# serial stay up; stop with: kill "$(cat "$BUILD/qemu.pid")".
COMMON=(
  -name "win311-win32s-125a"
  -machine pc -cpu "$CPU" -m "$MEM"
  -drive file="$BUILD/hdd.img",format=raw,if=ide,index=0,media=disk
  -vga std
  -vnc "0.0.0.0:$VNC_DISP"
  -serial "tcp:127.0.0.1:$SERIAL_PORT,server,nowait"
  -monitor "telnet:127.0.0.1:$MON_PORT,server,nowait"
  -rtc base=localtime
  -daemonize -pidfile "$BUILD/qemu.pid"
)

# the D: install data disk (Win 3.11 SETUP + Win32s), when present
INSTALL_D=()
[ -f "$BUILD/install-d.img" ] && INSTALL_D=(-drive file="$BUILD/install-d.img",format=raw,if=ide,index=1,media=disk)

case "$PHASE" in
  install)   # A:=DOS boot floppy, C:=blank(partitioned), D:=install files
    qemu-system-i386 "${COMMON[@]}" "${INSTALL_D[@]}" \
      -drive file="$FLOP/dos622-boot.img",format=raw,if=floppy,index=0 \
      -boot order=a
    ;;
  boot-dos)  # A:=DOS boot floppy, C:  (no D:)
    qemu-system-i386 "${COMMON[@]}" \
      -drive file="$FLOP/dos622-boot.img",format=raw,if=floppy,index=0 \
      -boot order=a
    ;;
  hdd)       # boot installed C:, with D: install disk attached
    qemu-system-i386 "${COMMON[@]}" "${INSTALL_D[@]}" -boot order=c
    ;;
  run)       # boot installed C: only (no install media) — the test-run config
    qemu-system-i386 "${COMMON[@]}" -boot order=c
    ;;
  *) echo "unknown phase: $PHASE (install|boot-dos|hdd|run)" >&2; exit 2 ;;
esac
echo "QEMU daemonized (pid $(cat "$BUILD/qemu.pid" 2>/dev/null)). VNC :$VNC_DISP (5900+), monitor 127.0.0.1:$MON_PORT, COM1->tcp 127.0.0.1:$SERIAL_PORT"
