# Implementation Plan: MCP-Win32s

Milestone plans for the software under development (`mcp-win32s/` submodule).
Each milestone lives in its own content-named folder `plan/<NNNN-slug>/` carrying
a `README.md`. Numbers are identity; slugs are content; ordering lives in this
index, never in the names.

## Milestone Index

| # | Milestone | Focus | Status |
|------|-----------|-------|--------|
| 0001 | [Foundation](0001-foundation/README.md) | test framework, JSON parser, serial init, main loop, CI | **Complete** |
| 0002 | [File Operations + Base64](0002-file-operations-base64/README.md) | file operations + base64 + PBT | **Complete** |
| 0003 | [Network & Transport](0003-network-transport/README.md) | vtable backends, serial refactor, TCP/Winsock | **Complete** |
| 0004 | [Command Execution](0004-command-execution/README.md) | command execution + catalog + feature uplift + theft harness + spec backfill + weed remediation + wire-contract smoke harness | **Complete** |
| 0005 | [MCP Integration](0005-mcp-integration/README.md) | Rust bridge (rmcp) + API-first capability surface (files/build/exec) + memory peek/poke (tiered, user-mode) + UTF-8 floor | **Complete** |
| 0006 | [Cross-Platform Testing](0006-cross-platform-testing/README.md) | cross-platform testing | **In progress** |
| 0007 | [Documentation & Polish](0007-documentation-polish/README.md) | documentation & polish | Not started |

## Milestone Rules (strict)

1. **Content-named, numbered for identity.** Each milestone is a folder
   `plan/<NNNN-slug>/` — a four-digit zero-padded number, a hyphen, then a
   lowercase slug naming its content — carrying a `README.md`. The number is
   assigned when the milestone is accepted and never changes; read sequence from
   this index, not from the names.
2. **Closed milestone bodies are append-only.** Once a milestone is marked
   **Complete** here and in its `README.md`, the body is the audit record: never
   reworded or retroactively rescoped. The git history is the trail. (The
   adoption migration de-ordinaled only the H1 titles; every body line is
   verbatim.)
3. **Corrections go forward.** If a completed milestone turns out wrong or
   incomplete, do not reopen it — record the correction as scope in the next (or
   a new) milestone, referencing the closed one.
4. **One status transition path.** `Not started → Spec'd → In progress →
   Complete`. Status changes are recorded in both the milestone `README.md`
   heading and the index table, in the same commit.
5. **Completion gate.** A milestone may only be marked Complete after the Allium
   lifecycle gate passes (specs tended, obligations propagated, weed audit clean)
   in the `mcp-win32s/` submodule.
6. **Opening a milestone requires an explicit planning pause.** Before any code or
   spec work begins, the milestone `README.md` is reviewed and amended to current
   reality — stale references fixed, corrections carried forward from closed
   milestones scoped in, open decisions resolved via Q&A and recorded — its status
   moves to **In progress** in the same commit, and that commit is pushed.
   Execution may never start from an unreviewed plan.
