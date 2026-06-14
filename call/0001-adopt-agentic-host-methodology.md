# Adopt the agentic-host methodology

- Status: accepted
- Date: 2026-06-14

## Context and Problem Statement

This repository began as a bespoke agentic host with its own conventions: two
behaviour-and-tooling submodules (`andrej-karpathy-skills`, `no-phase-skill`), an
ordinal milestone scheme (`plan/PHASEN.md` files, ordinal-prefixed titles, and a
sanctioned ordinal commit-subject carve-out), and ad-hoc governance prose. The
reusable [`template-agentic-host`](https://github.com/connollydavid/template-agentic-host)
methodology — five rooms (`cast/` `plan/` `call/` `<software>/` `CLAUDE.md`+`tools/`),
MADR decisions, content-named milestones, and the `host-*` lint/lifecycle tooling —
supersedes those conventions. We needed to adopt it **without rewriting the
project's append-only history**.

## Decision

Adopt the template at revision `7dd7556` (recorded in `.agentic-host`,
copy-at-version), driven by the deterministic `host-lifecycle` / `host-lint`
tooling rather than a free-form rewrite:

1. **Re-point the tool submodules.** `andrej-karpathy-skills` → `template-agentic-host`
   and `no-phase-skill` → `host-lint`. The upstreams were renamed and rewritten, so
   their old gitlink SHAs no longer exist — the submodules were swapped, not moved.
   The software submodule `mcp-win32s` is left exactly as is.
2. **Scaffold the rooms and stamp.** `host-lifecycle adopt . 7dd7556` created
   `cast/` (Who) and `call/` (Why) and wrote the `.agentic-host` stamp.
3. **Retire the ordinal carve-out.** Milestones are content-named
   `plan/<NNNN-slug>/README.md`; numbers are identity, slugs are content, order
   lives in the index. The phase-slop linter no longer exempts an ordinal commit
   subject — the form is a tell everywhere, enforced by the `host-lint` engine.
4. **Exclude, never rewrite, the record.** The append-only history (`MEMORY.md`
   and the closed milestone bodies) is excluded from the audit via
   `.host-lintignore` and left verbatim; only each milestone's H1 title was
   de-ordinaled.
5. **Rename the live layer deterministically.** A one-shot `host-lifecycle remap`
   dictionary performed the milestone-token substitution across governance,
   skills, the docs index, and the QEMU tool scripts. Non-milestone tells the
   dictionary could not resolve were hand-dispositioned (a false-positive run-mode
   variable, detection-ladder step references, a review-code, and work-item
   decimals reduced to their durable task handles), and genuine guest-OS / library
   versions and hardware quantities were allow-listed in `.host-lint-allow`. The
   dictionary scaffold was then removed; this decision is its durable record.

### The durable old → new milestone map

The renamed folders are the canonical map; recorded here so it survives the
removal of the one-shot remap dictionary:

| Old file | New milestone (content-named folder) |
|---|---|
| `plan/PHASE1.md` | Foundation — `plan/0001-foundation/README.md` |
| `plan/PHASE2.md` | File Operations + Base64 — `plan/0002-file-operations-base64/README.md` |
| `plan/PHASE3.md` | Network & Transport — `plan/0003-network-transport/README.md` |
| `plan/PHASE4.md` | Command Execution — `plan/0004-command-execution/README.md` |
| `plan/PHASE5.md` | MCP Integration — `plan/0005-mcp-integration/README.md` |
| `plan/PHASE6.md` | Cross-Platform Testing — `plan/0006-cross-platform-testing/README.md` |
| `plan/PHASE7.md` | Documentation & Polish — `plan/0007-documentation-polish/README.md` |

## Consequences

- Good: the host follows a reusable, documented methodology; milestone names are
  stable under re-cutting; the anti-slop rule is uniform with no carve-out; and
  the project history is preserved verbatim rather than rewritten.
- Good: the methodology is pinned at a revision (copy-at-version), so it cannot
  drift between submodule bumps — an upgrade is a deliberate `.agentic-host` diff
  handled by `host-lifecycle classify`/`adopt`.
- Neutral: `host-lint` and `host-lifecycle` must be built per clone (Rust); the
  `.host-lint-allow` and `.host-lintignore` files now govern the ongoing audit.
- Neutral: `template-agentic-host/CLAUDE.md` is referenced at the pinned revision,
  not `@`-imported, so the methodology manual is read copy-at-version.
