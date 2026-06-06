---
name: phase
description: Drive a software phase of MCP-Win32s through the full per-phase process — planning pause, the Allium lifecycle (elicit→tend→propagate→implement→distill→weed), the merge gate + CI parity, the review gate, and close-out. Invoke to open, check the status of, advance, review, or complete a phase. The state-aware orchestrator the host process has accreted toward.
arguments:
  - name: action
    description: "open <N> | status | gate arm|clear | review | complete <N>  (default: status)"
---

# /phase — the per-phase orchestrator

This is the executable spine of the host process. It **sequences** the
rules defined in the host `CLAUDE.md` and **refuses to skip a gate**; it
does not duplicate the rules — read `CLAUDE.md` for their full text. Note:
`/goal` is a *built-in* Claude Code command (a transcript-evaluated loop);
this orchestrator is deliberately named `/phase` so it does not shadow it,
and because it does not rely on transcript evaluation — its gates are
verified by the `/phase-gate` Stop hook, `allium`, an adversarial
sub-agent, and observed CI.

## The canonical flow (and what enforces each stage)

| # | Stage | Skill / action | Exit criterion | Enforced by |
|---|-------|----------------|----------------|-------------|
| 0 | Planning pause | `/phase open <N>` | PHASE<N>.md reviewed, open questions settled, status → In progress, committed+pushed | this skill (will not advance from an unreviewed plan) |
| 1 | Discover | `/allium:elicit` | domain model settled, zero open questions; terminology grounded in research when naming matters | recorded in PHASE<N>.md |
| 2 | Specify | `/allium:tend` | `allium check` clean; safety transforms pinned by an invariant (tend owns the final form; plan sketches are input) | `allium check` + the safety-transform rule |
| 3 | Derive tests | `/allium:propagate` | obligations listed, mapped to tests (floor only grows) | OBLIGATIONS file traces |
| 4 | Implement | **fan-out** (see below) | first all-green → **`/phase gate arm`** here | `/phase-gate` (continuous from here) + sub-agent verification |
| 5 | Backfill | `/allium:distill` | every module has a spec | `allium check` |
| 6 | Audit | `/allium:weed` | **parallel auditors** (see below); zero unrecorded drift, incl. the adversarial gate-bypass dimension | weed report |
| 7 | Merge gate | — | specs current + obligations + weed clean + **observed** CI green | `/phase-gate` (local) + `gh pr checks` (parity) |
| 8 | Review gate | `/phase review` | fresh adversarial sub-agent: verdict approve, findings fixed in-PR | the sub-agent (see review-template.md) |
| 9 | Close-out | `/phase complete <N>` | merged, submodule bumped, status Complete, lessons recorded, gate cleared | this skill |

Deterministic truth (stages 2–7 local checks) → the `/phase-gate` Stop
hook. Judgment (review gate) → the sub-agent. Parity (CI ≠ local) → the
observed run. None substitutes for another.

**Stage cadence.** Each stage exit writes a `✅ <stage> — <date>` line into
`plan/PHASE<N>.md` and is committed + pushed immediately (host repo, plan
artifacts only — the PLAN/PHASE immediate-commit rule). These markers are
the phase's state; `/phase status` reads them. Do not batch them.

## Implement and weed are fan-out jobs, not linear ones

Phase 4 was an orchestration job, not a serial slog — encode that:

**Stage 4 (implement) — fan-out.** Decompose the phase into independent
modules. **Freeze the interfaces first**: write and commit the `.h`
(public types + signatures) for each module before delegating, so
concurrent work cannot collide on a contract (Phase 4 froze `feat.h`
before spawning eight module agents). Then spawn one sub-agent per module
**in parallel** (a single message, multiple Agent calls), each with the
hard constraints, the frozen headers, and its obligation IDs. Keep the
interface-heavy seams (the dispatcher, integration glue) for the main
session. **Independently verify** every returned module — re-build and
re-run its tests yourself; never accept a sub-agent's self-report (a
Phase 4 agent reported "done" with no test output and had real
failures). Integrate, then run the whole suite.

**Stage 6 (weed) — parallel auditors.** Split the specs into clusters and
run one read-only `Explore` auditor per cluster in parallel (Phase 4 ran
four: process-ops, catalog, the distilled+wire specs, and
protocol/transport/file-ops), each told to be adversarial and hunt the
gate-bypass dimension. Synthesise the findings, then remediate in-branch
in one pass.

## Actions

Read `$ARGUMENTS`; default to `status`.

### `open <N>`
The planning pause (CLAUDE.md / PLAN.md rule 6). Do NOT start execution
from an unreviewed plan.
1. Enter plan mode. Read `plan/PHASE<N>.md` in full and `plan/PLAN.md`.
2. Surface every stale reference, carried-forward correction, and open
   question; settle them by Q&A with the user. A new phase is never just
   a preamble fixing the previous one — confirm the phase's own scope.
3. On approval: flip the PLAN.md index and the PHASE<N>.md header to
   **In progress**, commit + push (host repo; plan artifacts only).
4. Hand off to stage 1 (`/allium:elicit`).

### `status` (default)
1. Read `plan/PLAN.md` for the In-progress phase; if none, report "no
   phase in progress" and stop.
2. Read that `plan/PHASE<N>.md`; from the `✅ <stage>` markers report the
   lifecycle stage reached, the next stage, and its exit criterion.
3. Report whether `/phase-gate` is armed (`.claude/phase-gate.active`).

### `gate arm` | `gate clear`
Thin delegation to the `/phase-gate` skill. Arm at **first all-green**
(end of implement) and keep armed through distill, weed, review fixes and
merge; clear after merge. (Not a merge-time check — a continuous guard.)

### `review`
Launch the independent adversarial review gate (CLAUDE.md "Review gate").
1. Confirm the lifecycle is clean and CI is green first (necessary,
   not sufficient).
2. Spawn a fresh read-only sub-agent using
   `.claude/skills/phase/review-template.md`, filling in the diff,
   branch, base, and the PR's claims. The reviewer refutes the claims.
3. Address every finding **within the same PR**; record them as numbered
   findings in PHASE<N>.md. Re-run if a fix is non-trivial.

### `complete <N>`
The close-out (only after stages 7 + 8 are satisfied).
1. Verify: weed clean, `/phase-gate` green, **observed** CI green
   (`gh pr checks`), review verdict approve with findings fixed.
2. Squash-merge the submodule PR; delete the branch.
3. Bump the submodule pointer in the host repo as a **separate** commit.
4. Mark Complete in `plan/PLAN.md` and the PHASE<N>.md header; append the
   phase's lessons to `MEMORY.md` (separate commit).
5. `/phase gate clear`.

## Notes
- This skill only orchestrates; it writes plan/status artifacts in the
  **host** repo and never edits software code (that happens in the
  submodule on a branch, per the layout rules).
- **Verify platform facts, don't reconstruct them.** For any question
  about Claude Code / the Agent SDK / the API (built-ins like `/goal`,
  hook contracts, skill authoring), consult the `claude-code-guide`
  agent against the live docs rather than guessing from training data —
  this phase's `/goal`, Stop-hook and PreToolUse designs all rested on
  that.
- **Context budget.** The context-heavy stages (tend, implement) are
  natural fresh-session boundaries; when context grows large, finish the
  stage, push, and hand off with a copy-paste resume prompt rather than
  pushing through degraded.
- Anti-slop: commit subjects and code comments are linted by the
  phase-slop hook; keep numbered phase-synonyms out of submodule
  code/commits — the sanctioned `Phase N` structure lives only here in
  the host `plan/`.
