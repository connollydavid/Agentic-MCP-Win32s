# Implementation Plan: MCP-Win32s

Phase plans for the software under development (`mcp-win32s/` submodule). Each phase lives in its own `PHASE<N>.md` file in this directory.

## Phase Index

| Phase | File | Focus | Status |
|-------|------|-------|--------|
| 1 | [PHASE1.md](PHASE1.md) | Foundation: test framework, JSON parser, serial init, main loop, CI | **Complete** |
| 2 | [PHASE2.md](PHASE2.md) | File operations + base64 + PBT | **Complete** |
| 3 | [PHASE3.md](PHASE3.md) | Network & transport: vtable backends, serial refactor, TCP/Winsock | **Complete** |
| 4 | [PHASE4.md](PHASE4.md) | Command execution + catalog + feature uplift + theft harness + spec backfill + weed remediation (4.0) + wire-contract smoke harness | **Complete** |
| 5 | [PHASE5.md](PHASE5.md) | MCP integration: Rust bridge (rmcp) + API-first capability surface (files/build/exec) + memory peek/poke (tiered, user-mode) + UTF-8 floor | **In progress** |
| 6 | [PHASE6.md](PHASE6.md) | Cross-platform testing | Not started |
| 7 | [PHASE7.md](PHASE7.md) | Documentation & polish | Not started |

## Phase File Rules (strict)

1. **Sequential naming.** Phase files are named `PHASE<N>.md` with `N` a positive integer, no gaps, no zero-padding. A new phase MUST be `PHASE<max+1>.md` — never insert, renumber, or reuse a number.
2. **Closed phases are immutable.** Once a phase is marked **Complete** in its file and in the index above, its `PHASE<N>.md` MUST NOT be edited again — no rewording, no retroactive scope changes, no status flips. The git history of each phase file is the audit trail.
3. **Corrections go forward.** If a completed phase turns out to be wrong or incomplete, do not reopen it. Record the correction as scope in the next (or a new) phase file, referencing the closed phase.
4. **One status transition path.** `Not started → Spec'd → In progress → Complete`. Status changes are recorded in both the phase file heading and the index table, in the same commit.
5. **Completion gate.** A phase may only be marked Complete after the Allium lifecycle gate passes (specs tended, obligations propagated, weed audit clean) in the `mcp-win32s/` submodule.
6. **Opening a phase requires an explicit planning pause.** Before any code or spec work for a phase begins, the phase file is reviewed and amended to current reality — stale references fixed, corrections carried forward from closed phases scoped in, open decisions resolved via Q&A and recorded — its status moves to **In progress** in the same commit, and that commit is pushed. Execution may never start from an unreviewed plan.
