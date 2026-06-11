#!/usr/bin/env bash
# mon-win.sh — drive/observe the QEMU guest that is running on the WINDOWS host
# (run-win.bat), from here in WSL2, over the QEMU monitor's TCP socket.
#
#   HOST  Windows host as seen from WSL2 (default: the WSL2 default gateway;
#         in WSL2 *mirrored* networking use HOST=127.0.0.1)
#   MON_PORT  monitor port (default 55555; must match run-win.bat's BIND/MON_PORT,
#         and run-win.bat must use BIND=0.0.0.0 in NAT mode + a firewall allow)
#
# Usage:
#   mon-win.sh ping                 check the monitor is reachable
#   mon-win.sh shot [name]          screendump -> build/shots/<name>.png (viewable)
#   mon-win.sh key  <keys...>       sendkey (QEMU key names: 'ret' 'spc' 'shift-a')
#   mon-win.sh type "<text>"        type an ASCII line (letters/digits/common punct)
#   mon-win.sh enter                send Return
#   mon-win.sh cmd  "<monitor cmd>" raw monitor command
#
# This is free and unencumbered software released into the public domain.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
B="$HERE/../../vendor/win311/build"; SHOTS="$B/shots"; mkdir -p "$SHOTS"
HOST="${HOST:-$(ip route show default 2>/dev/null | awk '{print $3; exit}')}"
PORT="${MON_PORT:-55555}"

mon() { printf '%s\r\n' "$1" | timeout 10 nc -w3 "$HOST" "$PORT" 2>/dev/null; }

# map one ASCII char -> a QEMU sendkey keyname (lowercase; DOS is case-insensitive)
keyname() {
  case "$1" in
    [a-z]) printf '%s' "$1";; [A-Z]) printf 'shift-%s' "$(printf '%s' "$1" | tr A-Z a-z)";;
    [0-9]) printf '%s' "$1";; ' ') printf 'spc';; '\') printf 'backslash';;
    '/') printf 'slash';; ':') printf 'shift-semicolon';; ';') printf 'semicolon';;
    '.') printf 'dot';; ',') printf 'comma';; '-') printf 'minus';; '_') printf 'shift-minus';;
    '=') printf 'equal';; '>') printf 'shift-dot';; '<') printf 'shift-comma';;
    '*') printf 'shift-8';; '?') printf 'shift-slash';; '!') printf 'shift-1';;
    '"') printf 'shift-apostrophe';; "'") printf 'apostrophe';;
    *) printf '';;   # unsupported -> skipped
  esac
}

case "${1:-}" in
  ping) if mon "info status" | grep -qiE 'running|paused|VM status'; then echo "monitor OK at $HOST:$PORT"; else echo "NO monitor at $HOST:$PORT (host/port/firewall? mirrored-net?)" >&2; exit 1; fi;;
  shot)
    name="${2:-shot}"; win="$(wslpath -w "$SHOTS/$name.ppm" 2>/dev/null || echo "$SHOTS/$name.ppm")"
    rm -f "$SHOTS/$name.ppm"
    mon "screendump $win" >/dev/null
    for _ in $(seq 1 25); do [ -s "$SHOTS/$name.ppm" ] && break; sleep 0.2; done
    if [ -s "$SHOTS/$name.ppm" ]; then pnmtopng "$SHOTS/$name.ppm" > "$SHOTS/$name.png" 2>/dev/null; echo "$SHOTS/$name.png"
    else echo "no screendump (monitor unreachable, or QEMU can't write $win)" >&2; exit 1; fi;;
  key)  shift; mon "sendkey $*" >/dev/null;;
  enter) mon "sendkey ret" >/dev/null;;
  type)
    s="${2:-}"; i=0
    while [ $i -lt ${#s} ]; do c="${s:$i:1}"; k="$(keyname "$c")"; [ -n "$k" ] && mon "sendkey $k" >/dev/null; i=$((i+1)); done;;
  cmd)  mon "$2";;
  *) echo "usage: mon-win.sh ping|shot [name]|key <keys>|type \"<text>\"|enter|cmd \"<cmd>\"" >&2; exit 2;;
esac
