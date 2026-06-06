#!/bin/sh
# phase-gate.sh - deterministic merge-gate Stop hook for the MCP-Win32s
# agentic host.
#
# When ARMED (the marker file exists), this refuses to let a turn end
# while any deterministic LOCAL gate is red, feeding the exact failing
# gate back to the model so it keeps working. When NOT armed it exits
# immediately, so ordinary sessions are unaffected (one stat + exit).
#
# It is the script-based backstop the lifecycle's own "I declared it
# clean" claim cannot bypass: /goal and the weed audit are evaluated
# from the transcript, but this runs the checks itself.
#
# Scope - the deterministic local gates ONLY:
#   1. allium check specs/*.allium          -> 0 errors
#   2. ./build.sh + ctest --preset mingw    -> all suites pass
#   3. import-table grep on mcp-w32s.exe    -> no static uplift/Winsock imports
#   4. FPU/486 grep on application objects  -> none
# It does NOT cover the model-judged review gate or the observed CI run.
# Green here is NECESSARY, NOT SUFFICIENT (see the /phase-gate skill).
#
# Loop bounding: the marker holds a block counter; after MAX_BLOCKS
# blocked stops the gate releases with a loud warning so a permanently
# red gate cannot trap the session. (stop_hook_active is also honoured by
# the platform's own block cap; the counter is the explicit belt.)
#
# This is free and unencumbered software released into the public domain.

set -u

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
MARKER="$PROJECT_DIR/.claude/phase-gate.active"
HASHFILE="$PROJECT_DIR/.claude/.phase-gate.greenhash"
SUB="$PROJECT_DIR/mcp-win32s"
MAX_BLOCKS=25

# Drain stdin so the pipe never breaks (we bound via the counter, not
# stop_hook_active, so the field is read but not required).
INPUT="$(cat 2>/dev/null)"
: "${INPUT:=}"

# 1. Not armed -> do nothing. Keeps every ordinary turn-end instant.
[ -f "$MARKER" ] || exit 0

# Block counter (single integer in the marker).
count="$(cat "$MARKER" 2>/dev/null)"
case "$count" in ''|*[!0-9]*) count=0 ;; esac

# 2. Exhausted -> release loudly. A red gate must never trap the loop.
if [ "$count" -ge "$MAX_BLOCKS" ]; then
    echo "phase-gate: $MAX_BLOCKS blocked stops reached; releasing. A gate is still red - resolve manually or run /phase-gate clear." >&2
    exit 0
fi

# JSON string escaper: collapse to one line, escape backslash then quote.
json_str() {
    printf '"%s"' "$(printf '%s' "$1" | tr '\n\r\t' '   ' | sed 's/\\/\\\\/g; s/"/\\"/g')"
}

# block REASON: increment the counter, emit a structured block, allow the
# script itself to exit 0 (the decision field does the blocking).
block() {
    echo "$((count + 1))" > "$MARKER"
    printf '{"decision":"block","reason":%s}\n' "$(json_str "$1")"
    exit 0
}

cd "$SUB" 2>/dev/null || block "phase-gate: software submodule not found at mcp-win32s/ - cannot verify the gates."

OBJDUMP="$(command -v i686-w64-mingw32-objdump 2>/dev/null || command -v objdump 2>/dev/null || true)"

# --- Gate 1: allium check (cheap, sub-second). -----------------------------
# A missing CLI is infrastructure, not drift: warn, do not block (the gate
# cannot be silently defeated by uninstalling a tool in our own repo, and
# wedging the loop on a missing binary helps no one).
if command -v allium >/dev/null 2>&1; then
    errs="$(allium check specs/*.allium 2>/dev/null | grep -c '"severity": "error"')"
    case "$errs" in ''|*[!0-9]*) errs=0 ;; esac
    if [ "$errs" -ne 0 ]; then
        block "phase-gate: allium check reports $errs error(s) across specs/. The spec layer must be clean before the phase concludes."
    fi
else
    echo "phase-gate: allium CLI not found; spec gate skipped (install allium to enforce it)." >&2
fi

# --- Cost control: skip the build/test tier when nothing under the verified
# source set changed since the last full-green run. -------------------------
curhash="$(find src tests specs CMakeLists.txt CMakePresets.json \
                bridge/src bridge/tests bridge/examples bridge/Cargo.toml \
                -type f 2>/dev/null \
           | LC_ALL=C sort | xargs cat 2>/dev/null | cksum | awk '{print $1}')"
if [ -f "$HASHFILE" ] && [ "$(cat "$HASHFILE" 2>/dev/null)" = "$curhash" ]; then
    exit 0   # verified green and unchanged -> allow the stop
fi

# --- Gate 2: build + the full ctest suite. ---------------------------------
if ! ./build.sh >/tmp/phase-gate-build.log 2>&1; then
    block "phase-gate: ./build.sh failed. Tail: $(tail -n 3 /tmp/phase-gate-build.log)"
fi
if ! ctest --preset mingw >/tmp/phase-gate-test.log 2>&1; then
    block "phase-gate: ctest has failing suites. $(grep -iE 'tests? failed|FAILED' /tmp/phase-gate-test.log | tail -n 4)"
fi

# --- Gate 3: import-table purity (binary must still load on Win32s). --------
if [ -n "$OBJDUMP" ] && [ -f build/mingw/mcp-w32s.exe ]; then
    if "$OBJDUMP" -p build/mingw/mcp-w32s.exe 2>/dev/null \
        | grep -iE 'wsock32|ws2_32|CreateJobObject|CreatePseudoConsole|IsWow64|GenerateConsoleCtrl|QueryFullProcess|SetProcessMitigation' >/dev/null; then
        block "phase-gate: mcp-w32s.exe carries a forbidden static import (Winsock or an uplift API must be GetProcAddress-only, or it fails to load on Win32s)."
    fi
fi

# --- Gate 4: i386/no-FP purity in application object code. ------------------
if [ -n "$OBJDUMP" ] && ls build/mingw/CMakeFiles/mcp-w32s.dir/src/*.obj >/dev/null 2>&1; then
    if "$OBJDUMP" -d build/mingw/CMakeFiles/mcp-w32s.dir/src/*.obj 2>/dev/null \
        | grep -qE '\bfld|\bfst[^r]|\bfadd|\bfmul|\bfdiv|\bfsub|cpuid|cmpxchg|bswap|rdtsc'; then
        block "phase-gate: application object code contains FPU or 486+ instructions (i386/no-floating-point constraint)."
    fi
fi

# --- Gate 5: theft host-native property suite (CI runs this first). ---------
# This is the layer that found the base64 signed-shift UB; omitting it would
# let a 'green' gate pass while a property is violated. A missing target is
# infrastructure (warn); a real property failure blocks.
if grep -q 'host-pbt' build.sh 2>/dev/null; then
    if ! ./build.sh host-pbt >/tmp/phase-gate-hostpbt.log 2>&1; then
        block "phase-gate: host-pbt (theft property suite) failed: $(grep -iE 'fail|runtime error' /tmp/phase-gate-hostpbt.log | grep -v theft_random.c | tail -n 3)"
    fi
fi

# --- Gate 6: wire-contract smoke (server over TCP + spec-driven client). ----
# The client is designed to exit 0 iff every check passes (and nonzero if it
# cannot even get a valid ready message), so its EXIT CODE is the truth - we
# do not grep its output (the success summary contains the word "failed" as
# in "0 failed"). A hard 30s client timeout prevents any hang.
if [ -f build/mingw/mcp-w32s.exe ] && [ -f build/mingw/wire_client.exe ]; then
    taskkill.exe /F /IM mcp-w32s.exe >/dev/null 2>&1 || true   # clear strays
    ( cd build/mingw && cp -r ../../catalog . >/dev/null 2>&1; \
      ./mcp-w32s.exe /TCP:31798 >/dev/null 2>&1 & echo $! > /tmp/phase-gate-srv.pid )
    sleep 3
    wire_rc=0
    ( cd build/mingw && timeout 30 ./wire_client.exe 127.0.0.1 31798 \
        >/tmp/phase-gate-wire.log 2>&1 ) || wire_rc=$?
    kill "$(cat /tmp/phase-gate-srv.pid 2>/dev/null)" 2>/dev/null || true
    taskkill.exe /F /IM mcp-w32s.exe >/dev/null 2>&1 || true
    rm -f /tmp/phase-gate-srv.pid
    if [ "$wire_rc" != "0" ]; then
        block "phase-gate: wire-contract smoke failed (client rc=$wire_rc): $(tail -n 3 /tmp/phase-gate-wire.log)"
    fi
fi

# --- Gate 7: Rust bridge (Phase 5) - cargo test (compiles lib+bin+tests). ---
# `cargo test` builds and runs the bridge's integration + proptest suites; a
# compile error or a failing test blocks. A missing cargo is infrastructure,
# not drift (warn, do not block), matching the allium gate above. The Inspector
# CLI conformance run is a model-judged gate, not a deterministic one, so it
# lives in the review gate, not here.
if [ -f bridge/Cargo.toml ]; then
    if command -v cargo >/dev/null 2>&1; then
        if ! ( cd bridge && cargo test --quiet ) >/tmp/phase-gate-bridge.log 2>&1; then
            block "phase-gate: bridge cargo test failed: $(grep -iE 'error|test result: FAILED|panicked' /tmp/phase-gate-bridge.log | tail -n 4)"
        fi
    else
        echo "phase-gate: cargo not found; bridge gate skipped (install Rust to enforce it)." >&2
    fi
fi

# --- All deterministic local gates green. ----------------------------------
echo "$curhash" > "$HASHFILE"
exit 0
