# Agentic-MCP-Win32s

Agentic host repository. Agentic software-development assets (skills, plans, phase audits, harness config) live here; the software under development is vendored as git submodules.

## Layout

- `mcp-win32s/` — submodule: the software under development (MCP server for Win32s). Its own `CLAUDE.md` carries the project-specific constraints (C89, i386, Win32s API subset) and build instructions.
- `andrej-karpathy-skills/` — submodule: behavioral guidelines and skills for agentic development.
- `plan/` — committed, auditable phase plans. `plan/PLAN.md` is the index and defines the strict phase-file rules (sequential `PHASE<N>.md` naming, closed phases immutable).
- `AGENTS.md` — condensed agent guide for the software under development.

## Working in this repository

- All planning artifacts (phase plans, status changes) are committed here, in the host repo — never inside the software submodule.
- Code changes happen inside `mcp-win32s/` on a branch, are merged via PR in that repo, and the submodule pointer is then bumped here in a separate commit.
- Follow the phase-file rules in `plan/PLAN.md` strictly: phases are append-only and closed phases are never revisited.

## Specification & Test Workflow (Allium + theft)

Behaviour of the software under development is specified in [Allium](https://juxt.github.io/allium/) (`mcp-win32s/specs/*.allium`, language version 3) **before** it is implemented. The Allium plugin (`allium@juxt-plugins`, enabled via `.claude/settings.json`) provides six skills. Every phase passes through this lifecycle:

| Stage | Skill | When | Output |
|-------|-------|------|--------|
| 1. Discover | `/allium:elicit` | Phase planning — turn phase goals and open questions into draft entities/rules through structured Q&A | Draft spec content |
| 2. Specify | `/allium:tend` | ALL spec writing and editing — new specs, refinements, syntax fixes, migrations. Never hand-edit `.allium` files outside tend | Valid `specs/*.allium` (`allium check` clean) |
| 3. Derive tests | `/allium:propagate` | Before implementation — generate the test obligations the specs imply | Obligation list: unit + property + state-machine tests |
| 4. Implement | (normal coding) | Code to the spec; every test traces to a propagated obligation | `src/*.c` + `tests/*.c` |
| 5. Audit | `/allium:weed` | Before marking a phase Complete — find spec↔code drift | Drift report; zero drift is the completion gate |
| 6. Backfill | `/allium:distill` | Whenever code exists without a spec — reverse-engineer one | New `specs/*.allium` |

`/allium:allium` is the language reference for any syntax or semantics question.

### Merge gate (non-negotiable)

**Never merge a PR in the software submodule until the full Allium lifecycle has been run for the change.** Concretely, before merging any branch:

1. **Specs current (`/allium:tend`)** — every behavioural change is reflected in `specs/*.allium`, `allium check` clean. Code without a spec is backfilled (`/allium:distill`).
2. **Obligations propagated (`/allium:propagate`)** — the spec's implied unit/property/state-machine tests exist and trace to the implementation.
3. **Audit clean (`/allium:weed`)** — a weed pass reports **zero spec↔code drift**. This is the gate; a non-zero drift report blocks the merge until resolved (fix code, fix spec, or record an explicit intentional gap).

This applies to *every* PR, not just phase-completion PRs. CI green is necessary but **not sufficient** — the weed audit must also be clean. Running the lifecycle is part of preparing a PR for merge, the same way tests are.

## Guidelines

@andrej-karpathy-skills/CLAUDE.md
