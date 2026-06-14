# Implementation Plan: MCP-Win32s

Milestone plans for the software under development (`mcp-win32s/` submodule).
Each milestone lives in its own content-named folder, `plan/<NNNN-slug>/`, with a
`README.md` overview. This index is the ordering authority.

## Milestone Index

| # | Milestone | Focus | Status |
|------|------|-------|--------|
| 0001 | [Foundation](0001-foundation/README.md) | Test framework, JSON parser, serial init, main loop, CI | **Complete** |
| 0002 | [File Operations + Base64](0002-file-operations-base64/README.md) | File operations + base64 + PBT | **Complete** |
| 0003 | [Network & Transport](0003-network-transport/README.md) | Vtable backends, serial refactor, TCP/Winsock | **Complete** |
| 0004 | [Command Execution](0004-command-execution/README.md) | Command execution + catalog + feature uplift + theft harness + spec backfill + weed remediation + wire-contract smoke harness | **Complete** |
| 0005 | [MCP Integration](0005-mcp-integration/README.md) | Rust bridge (rmcp) + API-first capability surface (files/build/exec) + memory peek/poke (tiered, user-mode) + UTF-8 floor | **Complete** |
| 0006 | [Cross-Platform Testing](0006-cross-platform-testing/README.md) | Cross-platform testing | **In progress** |
| 0007 | [Documentation & Polish](0007-documentation-polish/README.md) | Documentation & polish | Not started |

## Milestone File Rules (strict)

1. **Content-named, numbered folder.** Milestones live in `plan/<NNNN-slug>/`,
   where `NNNN` is a zero-padded width-four ordinal, assigned monotonically, never
   reused and never renumbered, and `slug` describes the milestone. The number is
   an identity, not a sort key — this index is the ordering authority, so naive
   directory sort is a non-goal. A new milestone takes the next free `NNNN`. (A
   bare number at the plan root names a milestone; a numbered file under `call/`
   names a decision — see `call/0000`.)
2. **Closed milestones are immutable.** Once a milestone is marked **Complete**
   here and in its `README.md`, that `README.md` MUST NOT be edited again — no
   rewording, no retroactive scope changes, no status flips. The git history of
   each milestone file is the audit trail.
3. **Corrections go forward.** If a completed milestone turns out to be wrong or
   incomplete, do not reopen it. Record the correction as scope in the next (or a
   new) milestone, referencing the closed one.
4. **One status transition path.** `Not started → Spec'd → In progress →
   Complete`. Status changes are recorded in both the milestone's `README.md`
   heading and the index table above, in the same commit.
5. **Completion gate.** A milestone may only be marked Complete after the Allium
   lifecycle gate passes (specs tended, obligations propagated, weed audit clean)
   in the `mcp-win32s/` submodule.
6. **Opening a milestone requires an explicit planning pause.** Before any code or
   spec work for a milestone begins, its `README.md` is reviewed and amended to
   current reality — stale references fixed, corrections carried forward from
   closed milestones scoped in, open decisions resolved via Q&A and recorded — its
   status moves to **In progress** in the same commit, and that commit is pushed.
   Execution may never start from an unreviewed plan.
