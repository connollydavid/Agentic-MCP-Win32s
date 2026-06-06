# Agentic-MCP-Win32s

Agentic host repository. Agentic software-development assets (skills, plans, phase audits, harness config) live here; the software under development is vendored as git submodules.

## Layout

- `mcp-win32s/` — submodule: the software under development (MCP server for Win32s). Its own `CLAUDE.md` carries the project-specific constraints (C89, i386, Win32s API subset) and build instructions.
- `andrej-karpathy-skills/` — submodule: behavioral guidelines and skills for agentic development.
- `plan/` — committed, auditable phase plans. `plan/PLAN.md` is the index and defines the strict phase-file rules (sequential `PHASE<N>.md` naming, closed phases immutable).
- `AGENTS.md` — agent guide for this host: where each concern's source of truth lives. The submodule's own docs (`mcp-win32s/CLAUDE.md`, and `mcp-win32s/vendor/theft/CLAUDE.md` for theft's internal idioms) are referenced, never duplicated.
- `MEMORY.md` — append-only record of decisions, constraints, and lessons learned.

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

### Safety-relevant transformations must be pinned, not abstracted (tend + weed)

When a spec models a **security- or safety-relevant transformation** — escaping, sanitisation, validation, whitelist gating, auth, a quota/length cap — as a black-box helper (e.g. `effective_cmd_line(cmd)`, `args_allowed(entry, argv)`), the spec MUST *also* carry an explicit `invariant` (or `@invariant` in a contract) naming the property the transformation guarantees. A black box tells weed *that* a transformation happens, never *what it must hold* — so a construct-by-construct weed audit cannot detect when the implementation's transformation diverges from the intent. The named invariant is what makes the property auditable.

Established 2026-06-06 on PR #10: the catalog gate's shell-builtin route skipped the cmd-metacharacter escape the external route applied, allowing `argv:["dir","x&calc"]` to run an uncatalogued `calc` against an enforced catalog. `allium check`, propagate, and a clean weed audit all passed it — the spec had abstracted the escaping into `effective_cmd_line`, hiding the divergence. The fix added a `ShellTailNeutralised` invariant pinning that *both* shell routes neutralise the user tail identically. tend writes these invariants when it introduces the helper; weed treats a black-box safety transform with no backing invariant as drift.

### Merge gate (non-negotiable)

**Never merge a PR in the software submodule until the full Allium lifecycle has been run for the change.** Concretely, before merging any branch:

1. **Specs current (`/allium:tend`)** — every behavioural change is reflected in `specs/*.allium`, `allium check` clean. Code without a spec is backfilled (`/allium:distill`).
2. **Obligations propagated (`/allium:propagate`)** — the spec's implied unit/property/state-machine tests exist and trace to the implementation.
3. **Audit clean (`/allium:weed`)** — a weed pass reports **zero spec↔code drift**. This is the gate; a non-zero drift report blocks the merge until resolved (fix code, fix spec, or record an explicit intentional gap). The weed pass includes an **adversarial gate-bypass dimension**: for every security- or safety-relevant boundary the change touches (a whitelist, an escaper, a length/quota cap, an auth check), actively try to construct an input that defeats it, rather than only matching constructs to code. (Added 2026-06-06: PR #10's catalog-gate bypass passed a construct-by-construct weed because the spec abstracted the escaping into a black box — see the safety-transformation rule below.)

This applies to *every* PR, not just phase-completion PRs. CI green is necessary but **not sufficient** — the weed audit must also be clean. Running the lifecycle is part of preparing a PR for merge, the same way tests are.

#### CI parity (local green ≠ merge-ready)

The dev host runs the PEs **natively via WSL interop**; CI runs them under **Wine**. A locally-green suite is evidence, not proof. Before declaring a branch CI-ready:

1. **The committed tree is what gets tested, not the working tree.** Test data and fixtures that match a `.gitignore` glob (e.g. `*.exe` binary fixtures) must be force-tracked (`git add -f`) and their presence asserted — a passing local run with an untracked fixture is a false green. (Added 2026-06-06: PR #10's binfmt fixtures were silently ignored; CI never had them.)
2. **OS-behavioural tests must be host-tolerant or runner-verified.** Any test whose outcome depends on the host (capability presence, shell line-ending normalisation, job-limit enforcement, ConPTY support) must either skip-with-reason when the host diverges, or be verified under the CI runner before claiming green — never asserted only against native WSL behaviour. (Added 2026-06-06: three Phase 4 tests encoded native-only behaviour and failed twice on Wine.)

CI green here means **the actual CI run on the pushed commit**, observed — not a local proxy.

### Review gate (independent sub-agent, before every merge)

After the Allium lifecycle is clean and CI passes, every PR in the software submodule gets an **independent adversarial review by a fresh sub-agent** before merge. Established 2026-06-06 on PR #9, where this process caught a spec defect (`FileWriteResult.data` phantom field, finding #7) that `allium check`, the lifecycle pass, and CI all missed.

Rules for the review:

1. **Fresh context.** The reviewer is a sub-agent that did not write the change. It receives the repo path, branch, base, and the PR's claims — and is instructed to verify them, not trust them.
2. **Precise, per-dimension instructions.** The prompt enumerates review dimensions specific to the diff: code correctness against the project's hard constraints (C89/i386/Win32s), test quality (does the pinning test actually pin?), spec semantics checked against the *implementation read directly* (no double-fire rules, faithful modelling of the code paths), tool re-runs (`allium check`/`analyse`, build, test suite), and scope discipline (every changed line traces to a stated finding).
3. **Adversarial framing.** The reviewer is told to refute the PR's claims and to look for adjacent defects of the same class as those being fixed — that is what catches what the tools cannot (the checker does not validate `.created()` args against entity fields; only a reader comparing spec to entity declarations finds that).
4. **Structured output.** Findings ordered by severity (blocker / should-fix / nit / observation) with file:line and quoted evidence; explicit "none" per empty level; a merge verdict (approve / approve-with-nits / request-changes).
5. **Findings are addressed within the same PR** — never deferred out of it — and recorded as numbered findings in the open phase file (host repo) in the same pass.
6. **Read-only reviewer.** The sub-agent must not modify files or comment on the PR; the main session applies fixes and documents them.

### Sub-agent deliverables are verified, never trusted

When implementation work is delegated to sub-agents (parallel module builds, etc.), the orchestrating session **independently re-runs the build and tests on the integrated result** before marking the work complete — it does not accept a sub-agent's self-report as evidence. A sub-agent can report "done" without having observed its own test output, or pass in isolation but break against a sibling's changes. (Added 2026-06-06: a Phase 4 module agent reported completion with a content-free final message; the orchestrator's own build+test run surfaced real failures the agent never saw.) This is the implementation-stage counterpart to the review gate: trust the artifact you verified, not the claim about it.

These per-phase process rules (planning pause, lifecycle, safety-transform pinning, merge gate + CI parity, review gate, sub-agent verification) are accreting toward a fully worked `/goal` skill per phase.

## Guidelines

@andrej-karpathy-skills/CLAUDE.md
