#!/bin/sh
# precommit-slop.sh - Claude Code PreToolUse hook (matcher: Bash).
#
# Catches the AGENT's commits: when the intercepted Bash command is a
# `git commit` targeting the software submodule (mcp-win32s), it lints the
# -m subject and the submodule's staged source comments via the shared
# phase-slop linter, and DENIES the tool call on a violation so the slop
# never reaches a commit. Host-repo commits are not linted (the host uses
# "Phase N" as legitimate structure; that scope decision is deliberate).
#
# Deny contract: JSON on stdout with permissionDecision "deny" + exit 0.
#
# This is free and unencumbered software released into the public domain.

set -u

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LINT="$PROJECT_DIR/.claude/hooks/lib/phase-slop-lint.sh"
SUB="$PROJECT_DIR/mcp-win32s"

INPUT="$(cat 2>/dev/null)"

# Extract the Bash command (jq if present, else a portable fallback).
if command -v jq >/dev/null 2>&1; then
    CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"
else
    CMD="$(printf '%s' "$INPUT" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p')"
fi
[ -n "$CMD" ] || exit 0

# Only act on git commits: the command mentions git then commit (handles
# `git commit`, `git -C path commit`, `cd sub && git commit`). An
# over-match (e.g. `git log commit-graph`) is harmless - the lint then
# finds nothing and allows.
case "$CMD" in
    *git*commit*) ;;
    *) exit 0 ;;
esac

# Only act when the commit targets the submodule: a `-C mcp-win32s`, a
# `cd mcp-win32s`, or the hook's cwd already inside the submodule.
HOOK_CWD="$(printf '%s' "$INPUT" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
targets_sub=0
case "$CMD" in
    *"-C mcp-win32s"*|*"cd mcp-win32s"*|*"mcp-win32s &&"*) targets_sub=1 ;;
esac
case "$HOOK_CWD" in
    "$SUB"|"$SUB"/*) targets_sub=1 ;;
esac
[ "$targets_sub" -eq 1 ] || exit 0

[ -x "$LINT" ] || exit 0   # linter missing -> don't wedge commits

violations=""

# 1. Commit subject from -m "..." (first -m only; the subject line).
subject="$(printf '%s' "$CMD" | sed -n "s/.*-m[[:space:]]*['\"]\([^'\"]*\).*/\1/p" | head -n 1)"
if [ -n "$subject" ]; then
    sub_v="$("$LINT" --subject "$subject" 2>/dev/null)" || violations="$violations$sub_v
"
fi

# 2. Staged source comments in the submodule.
staged_v="$("$LINT" --staged "$SUB" 2>/dev/null)" || violations="$violations$staged_v
"

# Trim and decide.
violations="$(printf '%s' "$violations" | sed '/^[[:space:]]*$/d')"
if [ -n "$violations" ]; then
    reason="phase-slop linter blocked this submodule commit. Numbered phase-synonyms (Phase 1, Step 2, Pass 1 of 3, ...) are an agentic tell - rewrite to idiomatic git/Conventional-Commits vocabulary. The sanctioned 'Phase N' structure belongs only in the host plan/. Violations:
$violations"
    if command -v jq >/dev/null 2>&1; then
        jq -n --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
    else
        esc="$(printf '%s' "$reason" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')"
        printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$esc"
    fi
    exit 0
fi

exit 0
