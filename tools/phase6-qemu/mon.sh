#!/usr/bin/env bash
# mon.sh — talk to the running guest's QEMU monitor (telnet on MON_PORT).
# Lets the orchestrator observe (screendump -> PNG) and drive (sendkey) the
# guest without a graphical display, complementing the operator's VNC session.
#
# Usage:
#   mon.sh shot [name]      capture the VGA framebuffer to build/shots/<name>.png
#   mon.sh key <keys...>    sendkey (QEMU key names, e.g. 'f', 'ret', 'ctrl-alt-delete')
#   mon.sh cmd "<monitor command>"
#
# This is free and unencumbered software released into the public domain.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
B="$HERE/../../vendor/win311/build"; SHOTS="$B/shots"; mkdir -p "$SHOTS"
MON_PORT="${MON_PORT:-55555}"

mon() { printf '%s\r\n' "$1" | timeout 10 nc -q1 127.0.0.1 "$MON_PORT" >/dev/null 2>&1 || true; }

case "${1:-}" in
  shot)
    name="${2:-shot}"; ppm="$SHOTS/$name.ppm"; png="$SHOTS/$name.png"
    rm -f "$ppm"
    mon "screendump $ppm"
    for _ in $(seq 1 20); do [ -s "$ppm" ] && break; sleep 0.2; done
    if [ -s "$ppm" ]; then
      if command -v pnmtopng >/dev/null 2>&1; then pnmtopng "$ppm" > "$png" 2>/dev/null
      elif command -v convert  >/dev/null 2>&1; then convert "$ppm" "$png"
      elif command -v ffmpeg   >/dev/null 2>&1; then ffmpeg -y -loglevel error -i "$ppm" "$png"; fi
      echo "${png:-$ppm}"
    else echo "no framebuffer captured (is the guest running?)" >&2; exit 1; fi
    ;;
  key)  shift; mon "sendkey $*";;
  cmd)  mon "$2";;
  *) echo "usage: mon.sh shot [name] | key <keys> | cmd \"<monitor cmd>\"" >&2; exit 2;;
esac
