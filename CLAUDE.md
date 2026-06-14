# Agentic-MCP-Win32s

Agentic host repository. Agentic software-development assets (skills, plans, milestone audits, harness config) live here; the software under development is vendored as git submodules.

## Layout

- `mcp-win32s/` — submodule: the software under development (MCP server for Win32s). Its own `CLAUDE.md` carries the project-specific constraints (C89, i386, Win32s API subset) and build instructions.
- `template-agentic-host/` — submodule: the agentic-host methodology template this repo is sourced from (its `CLAUDE.md` is the canonical spine; its `tools/` host the verification lanes). Copied at a pinned revision — see the `.agentic-host` stamp and `call/0001`.
- `host-lint/` — submodule: the anti-slop hygiene linter (Rust CLI; rules in its `VOCABULARY.md`), the match engine behind the slop hooks.
- `plan/` — committed, auditable milestone plans. `plan/PLAN.md` is the index and defines the strict milestone-file rules (content-named `plan/<NNNN-slug>/` folders, closed milestones immutable).
- `call/` — decision records (MADR; see `call/0000`). `cast/` — personas (the project's *who*).
- `AGENTS.md` — agent guide for this host: where each concern's source of truth lives. The submodule's own docs (`mcp-win32s/CLAUDE.md`, and `mcp-win32s/vendor/theft/CLAUDE.md` for theft's internal idioms) are referenced, never duplicated.
- `MEMORY.md` — append-only record of decisions, constraints, and lessons learned.

## Working in this repository

- All planning artifacts (milestone plans, status changes) are committed here, in the host repo — never inside the software submodule.
- Code changes happen inside `mcp-win32s/` on a branch, are merged via PR in that repo, and the submodule pointer is then bumped here in a separate commit.
- Follow the milestone-file rules in `plan/PLAN.md` strictly: milestones are append-only and closed milestones are never revisited.

## Specification & Test Workflow (Allium + theft)

**Why this layer exists — verification is the cornerstone.** The cornerstone of spec-driven development is not authorship; it is verification. The failure mode it guards against is not malice but *confident-and-wrong*: fluent, well-formed claims are cheap and ubiquitous — for LLM agents especially, plausibility is exactly what is most dangerous when it is wrong — and a human reviewer cannot out-read them at scale. So every gate here exists to make the unverified claim **insufficient** and the verified artifact the **only way through**: specs make intent legible; propagate turns it into obligations; weed and the review gate are told to *refute* the claims; the `/phase-gate` Stop hook *runs* the checks instead of believing the prose; CI is the observed run, not a report of it. The discipline is deliberately **self-applying** — these gates bind the agent that wrote the change as much as anyone: the Stop hook blocks its own turns, the review sub-agent refutes its own PR, the slop linter denies its own commits. The rule, everywhere, is the same: **do not trust the claim; verify the artifact.** Every defect of consequence in this project's history was caught by verification, not by getting it right the first time — the structure is built to make that the normal path, not the lucky one.

**Respect the machine — security boundaries are not optional.** This software grants an AI agent real power over a host: run commands, read and write files, and (later phases) inspect and modify process memory. That power is treated as **bounded, consented, and logged — never as a license.** Three rules govern it. (1) **We use what each OS grants ring-3; we never subvert its protections.** Broad access on a permissive system (Win9x/Win32s share an unprotected address space) is *what the OS already hands user mode* — it is never manufactured by escalating: no ring-0, no VxD, no call gate, no defeating a protection a system provides (on NT+, memory reach is limited to children we launched, via `ReadProcessMemory`/`WriteProcessMemory`). Respect the boundary that exists. (2) **Default-deny; opt in for danger.** The command catalog is an allow-list (and the argv/shell-escape hardening the review gate forced closes injection); memory writes, unsafe exec, and anything destructive are off by default, operator-opt-in, capability-gated, surfaced for human confirmation, and audit-logged — the OWASP MCP05 / least-privilege / consent posture. (3) **Verification covers restraint, not just function.** The review gate's adversarial gate-bypass dimension hunts boundary violations specifically — it is what caught the catalog-gate bypass — and it runs on every power-granting capability before it ships. Building a careful power tool is a commitment held in writing, so it binds every phase and every agent, not just the intent of one conversation.

Behaviour of the software under development is specified in [Allium](https://juxt.github.io/allium/) (`mcp-win32s/specs/*.allium`, language version 3) **before** it is implemented. The Allium plugin (`allium@juxt-plugins`, enabled via `.claude/settings.json`) provides six skills. Every milestone passes through this lifecycle:

| Stage | Skill | When | Output |
|-------|-------|------|--------|
| 1. Discover | `/allium:elicit` | Milestone planning — turn milestone goals and open questions into draft entities/rules through structured Q&A | Draft spec content |
| 2. Specify | `/allium:tend` | ALL spec writing and editing — new specs, refinements, syntax fixes, migrations. Never hand-edit `.allium` files outside tend | Valid `specs/*.allium` (`allium check` clean) |
| 3. Derive tests | `/allium:propagate` | Before implementation — generate the test obligations the specs imply | Obligation list: unit + property + state-machine tests |
| 4. Implement | (normal coding) | Code to the spec; every test traces to a propagated obligation | `src/*.c` + `tests/*.c` |
| 5. Audit | `/allium:weed` | Before marking a milestone Complete — find spec↔code drift | Drift report; zero drift is the completion gate |
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
2. **OS-behavioural tests must be host-tolerant or runner-verified.** Any test whose outcome depends on the host (capability presence, shell line-ending normalisation, job-limit enforcement, ConPTY support) must either skip-with-reason when the host diverges, or be verified under the CI runner before claiming green — never asserted only against native WSL behaviour. (Added 2026-06-06: three command-execution-milestone tests encoded native-only behaviour and failed twice on Wine.)

CI green here means **the actual CI run on the pushed commit**, observed — not a local proxy.

### Review gate (independent sub-agent, before every merge)

After the Allium lifecycle is clean and CI passes, every PR in the software submodule gets an **independent adversarial review by a fresh sub-agent** before merge. Established 2026-06-06 on PR #9, where this process caught a spec defect (the `FileWriteResult.data` phantom field) that `allium check`, the lifecycle run, and CI all missed.

Rules for the review:

1. **Fresh context.** The reviewer is a sub-agent that did not write the change. It receives the repo path, branch, base, and the PR's claims — and is instructed to verify them, not trust them.
2. **Precise, per-dimension instructions.** The prompt enumerates review dimensions specific to the diff: code correctness against the project's hard constraints (C89/i386/Win32s), test quality (does the pinning test actually pin?), spec semantics checked against the *implementation read directly* (no double-fire rules, faithful modelling of the code paths), tool re-runs (`allium check`/`analyse`, build, test suite), and scope discipline (every changed line traces to a stated finding).
3. **Adversarial framing.** The reviewer is told to refute the PR's claims and to look for adjacent defects of the same class as those being fixed — that is what catches what the tools cannot (the checker does not validate `.created()` args against entity fields; only a reader comparing spec to entity declarations finds that).
4. **Structured output.** Findings ordered by severity (blocker / should-fix / nit / observation) with file:line and quoted evidence; explicit "none" per empty level; a merge verdict (approve / approve-with-nits / request-changes).
5. **Findings are addressed within the same PR** — never deferred out of it — and recorded as findings in the open milestone file (host repo) in the same pass.
6. **Read-only reviewer.** The sub-agent must not modify files or comment on the PR; the main session applies fixes and documents them.

### Sub-agent deliverables are verified, never trusted

When implementation work is delegated to sub-agents (parallel module builds, etc.), the orchestrating session **independently re-runs the build and tests on the integrated result** before marking the work complete — it does not accept a sub-agent's self-report as evidence. A sub-agent can report "done" without having observed its own test output, or pass in isolation but break against a sibling's changes. (Added 2026-06-06: a command-execution-milestone module agent reported completion with a content-free final message; the orchestrator's own build+test run surfaced real failures the agent never saw.) This is the implementation-stage counterpart to the review gate: trust the artifact you verified, not the claim about it.

### Vocabulary discipline (anti-slop)

Numbered milestone-synonyms — a `phase`/`step`/`stage`/`pass` noun glued to a numeral — are a cross-model agentic tell (GPT, Gemini, Claude, Cursor, Copilot all stamp them). They are slop **everywhere in this repository**: in the software submodule's `src/`/`tests/` comments and commit subjects, and in the host's own plan, decision, and memory artifacts alike. There is **no host carve-out** — milestones are content-named under `plan/<NNNN-slug>/` (the old numbered-name exemption was retired; see `call/0001`), so the host's files are bound as strictly as the software's. Commit subjects should read as idiomatic git / Conventional Commits. This boundary is enforced mechanically by the slop linter (`.claude/hooks/lib/phase-slop-lint.sh`), wired as a Claude Code PreToolUse hook (catches the agent) and as installable git hooks (catch humans):

```
git -C mcp-win32s config core.hooksPath ../.claude/hooks/git
```

(`.git/hooks` is not tracked, so the git-hook install is a per-clone step. The PreToolUse hook needs no install — it ships in `.claude/settings.json`.) There is no subject exemption: a milestone-synonym with a numeral flags anywhere. Idiomatic vocabulary — Conventional Commits types, Conventional Comments labels, code tags (`TODO/FIXME/XXX/HACK`), `WIP`, and genuine version strings and quantities — is never flagged.

The linter's **match engine** is the [`host-lint`](https://github.com/connollydavid/host-lint) tool (`host-lint/` submodule; the rule spec is its `VOCABULARY.md` — a wide term list with two-word lookahead). Build it per clone: `cargo build --release --manifest-path host-lint/Cargo.toml`. Comment-line scoping stays in the wrapper (`phase-slop-lint.sh`); the original shell pattern remains as the fallback engine when the binary is absent (hooks never wedge a fresh clone).

### Implement and weed are fan-out jobs (not linear)

A milestone's implement and weed stages are **parallel orchestration**, not serial work — this is how the command-execution milestone was actually done and what made it tractable. Implement: decompose into independent modules, **freeze each module's interface (`.h`) and commit it first** so concurrent work cannot collide on a contract, then spawn one sub-agent per module in parallel; keep the integration seams (dispatcher, glue) for the main session; **independently re-build and re-test every returned module** (sub-agent verification). Weed: split the specs into clusters and run one read-only auditor per cluster in parallel, each adversarial. Stage cadence: each lifecycle stage exit writes a `✅ <stage>` marker into the open milestone `README.md` and is committed + pushed immediately (the same immediate-commit rule as PLAN edits) — those markers are the milestone's state.

### The `/phase` orchestrator

These per-milestone process rules (planning pause, lifecycle, safety-transform pinning, merge gate + CI parity, review gate, sub-agent verification, fan-out) are sequenced by the **`/phase`** skill (`.claude/skills/phase/`) — the state-aware orchestrator that drives a milestone open→complete and refuses to skip a gate. Its deterministic gates are enforced by the `/phase-gate` Stop hook, its judgment gate by the adversarial review sub-agent (`review-template.md`), and its parity gate by observed CI. (The skill is named `/phase`, not `/goal`: `/goal` is a built-in Claude Code command — a transcript-evaluated loop — which the orchestrator deliberately does not shadow and does not depend on, since it verifies its gates by running them.)

## Sourcing

This repository is an **agentic host** sourced from the
[`template-agentic-host`](https://github.com/connollydavid/template-agentic-host)
methodology, **copied at a pinned revision** rather than tracked live: the
`.agentic-host` stamp records the adopted `template`/`revision`/`adopted`, and a
later upgrade diffs the template from that revision. The template's `CLAUDE.md`
is the canonical spine (imported below); the project-specifics above — the
Win32s constraints, the Allium lifecycle, the merge/review gates, the `/phase`
orchestrator — are this host's own and take precedence where they are more
specific. Tool *outputs* are project-owned. The adoption is recorded in
`call/0001`.

## Guidelines

@template-agentic-host/CLAUDE.md
