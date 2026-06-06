#!/bin/sh
# phase-slop-lint.sh - anti-slop vocabulary linter for the MCP-Win32s
# agentic host. Single source of truth for the rules, called by both the
# Claude Code PreToolUse hook (catches the agent's commits) and the
# installable git hooks (catch human commits).
#
# It flags the cross-model agentic TELL: a phase-synonym noun followed by
# a numeral (Phase 1, Step 2, Stage II, Pass 1 of 3) in a commit subject
# or a source-code comment. The numeral is the tell; the noun alone is
# not. Idiomatic git/review/source vocabulary (Conventional Commits,
# Conventional Comments, code tags, WIP) is never flagged.
#
# Repo-specific exemption: this host uses "Phase N" as its LEGITIMATE
# organising structure. A commit subject that STARTS with "Phase <N>" is
# the sanctioned phase-work convention and is allowed; a phase-synonym
# anywhere else is slop.
#
# Modes:
#   --subject "<text>"     lint one commit subject line
#   --staged   <repo-dir>  lint added comment lines in that repo's staged
#                          src/** and tests/** (git diff --cached)
#
# Output: one "LOCATION: <match>" line per violation on stdout.
# Exit: 0 = clean, 1 = violations found, 2 = usage error.
#
# This is free and unencumbered software released into the public domain.

set -u

# Phase-synonym nouns (section 1 of the vocab spec). "section" included;
# "epoch/era/period/level/wave/batch" carry higher false-positive risk but
# the numeral gate + scope exclusions handle them.
SYNONYMS='phase|stage|step|part|pass|round|iteration|sprint|cycle|increment|wave|batch|section'

# Numeral gate: an arabic number or a roman numeral, on a word boundary.
NUMERAL='([0-9]+|[ivxlcdm]+)'

# The core flag pattern: <synonym> <numeral>, case-insensitive, bounded.
CORE="(^|[^a-z])($SYNONYMS)[[:space:]]+$NUMERAL([^a-z]|$)"

usage() {
    echo "usage: phase-slop-lint.sh --subject \"<text>\" | --staged <repo-dir>" >&2
    exit 2
}

# lint_text TEXT LABEL : print a violation line if TEXT trips the core
# pattern. Case-insensitive via tr (portable; no grep -P assumed).
lint_text() {
    _text="$1"
    _label="$2"
    _low="$(printf '%s' "$_text" | tr 'A-Z' 'a-z')"
    if printf '%s' "$_low" | grep -Eq "$CORE"; then
        printf '%s: %s\n' "$_label" "$_text"
        return 0
    fi
    return 1
}

case "${1:-}" in
--subject)
    [ $# -ge 2 ] || usage
    subject="$2"
    low="$(printf '%s' "$subject" | tr 'A-Z' 'a-z')"

    # Sanctioned convention: subject starts with "Phase <N>" (optionally
    # after leading spaces). Allowed - this is the host's phase-work
    # commit form ("Phase 4 implement: ...").
    if printf '%s' "$low" | grep -Eq '^[[:space:]]*phase[[:space:]]+[0-9]+([^a-z]|$)'; then
        exit 0
    fi

    if lint_text "$subject" "commit-subject"; then
        exit 1
    fi
    exit 0
    ;;

--staged)
    [ $# -ge 2 ] || usage
    repo="$2"
    [ -d "$repo" ] || { echo "phase-slop-lint: no such repo dir: $repo" >&2; exit 2; }

    found=0
    # Added lines in staged src/ and tests/, excluding CI/Docker where
    # 'stage'/'step' are reserved keywords.
    files="$(git -C "$repo" diff --cached --name-only --diff-filter=ACM 2>/dev/null \
        | grep -E '^(src|tests)/' \
        | grep -vE '(^|/)\.github/|\.ya?ml$|(^|/)Dockerfile')"

    [ -n "$files" ] || exit 0

    for f in $files; do
        # Walk the added lines (git diff with line numbers via @@ hunks is
        # heavy in sh; we lint the staged blob and report the file - close
        # enough for a commit gate, and avoids re-deriving line numbers).
        # Only comment lines are considered: leading //, /*, *, #, or --.
        git -C "$repo" show ":$f" 2>/dev/null \
            | grep -nE '^[[:space:]]*(//|/\*|\*|#|--)' \
            | while IFS=: read -r lineno rest; do
                low="$(printf '%s' "$rest" | tr 'A-Z' 'a-z')"
                if printf '%s' "$low" | grep -Eq "$CORE"; then
                    printf '%s:%s: %s\n' "$f" "$lineno" "$(printf '%s' "$rest" | sed 's/^[[:space:]]*//')"
                fi
            done
    done > /tmp/phase-slop-staged.$$  2>/dev/null

    if [ -s /tmp/phase-slop-staged.$$ ]; then
        cat /tmp/phase-slop-staged.$$
        rm -f /tmp/phase-slop-staged.$$
        exit 1
    fi
    rm -f /tmp/phase-slop-staged.$$
    exit 0
    ;;

*)
    usage
    ;;
esac
