---
name: phase-gate
description: Arm or clear the deterministic merge-gate Stop hook for the MCP-Win32s software submodule. Invoke when driving a phase or PR toward merge-readiness, so a turn cannot end while a local gate (allium check, build, ctest, import-table, FPU/486) is red. Also clears the gate after merge.
disable-model-invocation: true
arguments:
  - name: action
    description: "arm | clear | status (default: status)"
---

# /phase-gate — deterministic merge-gate enforcement

This skill arms a **script-based Stop hook** (`.claude/hooks/phase-gate.sh`)
that physically refuses to let a turn end while any deterministic local
gate on the `mcp-win32s` submodule is red. It is the engine chosen over a
prompt-based `/goal`: `/goal`'s evaluator judges the **transcript** (it
cannot run commands), so it can pass on a *claim* of success; this hook
runs the checks itself, so it passes only on **verified** success.

## Why this exists

The recurring failure mode across phases is concluding work on a *claim*
that a gate is clean — PR #10's catalog-gate bypass passed a clean weed
audit because the spec abstracted the flaw away. Deterministic gates have
machine-checkable truth and should be enforced mechanically, not trusted
to prose. This hook is that mechanism.

**Necessary, not sufficient.** A green phase-gate covers only the
deterministic local checks. Merge-readiness still requires, separately:
- the **observed CI run** on the pushed commit (`gh pr checks`), per the
  CI-parity rule — Wine ≠ native, so local green is not CI green;
- the **independent adversarial review gate** (a fresh read-only
  sub-agent), which catches what no script can — the model-judged
  defects. Run it after this hook is green and CI passes.

## Gates enforced (the hook, when armed)

1. `allium check specs/*.allium` → 0 errors (skipped with a warning if
   the CLI is absent — infrastructure, not drift).
2. `./build.sh` + `ctest --preset mingw` → all suites pass.
3. `objdump -p mcp-w32s.exe` → no static Winsock or uplift-API import.
4. `objdump -d` on app objects → no FPU/486 instructions.

The build/test tier is skipped when the verified source set
(`src/ tests/ specs/ CMakeLists.txt CMakePresets.json`) is byte-identical
to the last full-green run, so repeated turn-ends are cheap when nothing
changed. The loop is bounded: after 25 blocked stops the gate releases
with a warning, so a permanently-red gate cannot trap the session.

## Actions

Read `$ARGUMENTS` for the action (default `status`).

### `arm`
1. Write the marker so the Stop hook engages, resetting the block counter:
   `printf '0' > .claude/phase-gate.active`
2. Remove any stale green-hash so the first stop runs a full verification:
   `rm -f .claude/.phase-gate.greenhash`
3. Confirm to the user: the gate is live; turns cannot end while a local
   gate is red. Remind them this is necessary-not-sufficient (CI + review
   gate still required), and that they clear it after merge.

### `clear`
1. `rm -f .claude/phase-gate.active .claude/.phase-gate.greenhash`
2. Confirm the gate is disarmed; ordinary turn-ends are unblocked.

### `status`
1. If `.claude/phase-gate.active` exists, report ARMED and the current
   block count (its contents); else report DISARMED.
2. Do not run the gates here — arming is what runs them, on the next stop.

## Notes

- The hook lives at `.claude/hooks/phase-gate.sh` and is registered as a
  `Stop` hook in `.claude/settings.json` (project-scoped, committed, so it
  runs for anyone who clones the host repo). When not armed it exits
  instantly — zero impact on normal sessions.
- The marker (`.claude/phase-gate.active`) and green-hash
  (`.claude/.phase-gate.greenhash`) are session/working-state, not
  process artifacts: they are git-ignored, never committed.
- This is one of the accreting per-phase process rules (planning pause →
  lifecycle → safety-transform pinning → merge gate + CI parity → review
  gate → sub-agent verification) building toward a fully worked per-phase
  goal flow. See the host `CLAUDE.md`.
