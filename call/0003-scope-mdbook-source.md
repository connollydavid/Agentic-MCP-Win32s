# Scope the mdBook source to docs/; upgrade to tool-submodule coherence (bcd1631 → 0401bff)

- Status: accepted
- Date: 2026-06-15
- Relates: `call/0002` (the `bcd1631` upgrade), `call/0004` + `call/0005` (bare store + coherence)

## Context and Problem Statement

Two coupled issues surfaced from the `bcd1631` state:

1. The template (at `bcd1631`) tracked its own tool-skill symlinks (`.claude/skills/*` → `tools/{allium,specula}`), which **dangle** until those tools are materialized. Our published docs build used `book.toml` `src = "."`, so mdBook recursively scanned the whole repo — including the template submodule — and **hard-failed (rc=101)** on those dangling symlinks. CI (un-materialized) was green; a materialized local checkout broke. (Reported upstream; the template fixed it in this span.)
2. `src = "."` is over-broad regardless: it copies the tool submodules, the `mcp-win32s` worktree + bare store, and `vendor/` into the book as static assets — none of which is published content.

The template advanced `bcd1631 → 0401bff`, whose `UPGRADING.md` adds one action — **coherence generalized to tool submodules** (the widened `software --check` now flags **any** tracked symlink whose target is not tracked here, not just software-worktree paths) — untracks/generates its own tool-skill symlinks, and **recommends a scoped mdBook src**.

## Decision

1. **Upgrade `bcd1631 → 0401bff`.** Rebuilt `host-lifecycle` from the new pin (**v0.4.1**). The one ledger action is a **no-op for this host**: we track zero symlinks, so the widened `software --check` flags nothing — recorded, nothing to untrack. Re-stamped `.agentic-host → 0401bff`.
2. **Scope the mdBook source** (the template's recommendation). `book.toml` now sets `src = "docs"`; `docs/` is a thin tree of `{{#include}}` stubs over the canonical root files (`CLAUDE.md`, `AGENTS.md`, `MEMORY.md`, `plan/*`). mdBook scans only `docs/`, so it never walks the submodules / worktree / `vendor/` — the build is robust independent of materialization state.

## Consequences

- Good: the docs build is green **materialized and un-materialized**; the source↔materialization coupling (and the dangling-symlink fragility) is removed at the host level too, not only via the template fix.
- Good: the published book contains only the host's governance/plan docs — no vendored or submodule trees copied in.
- Neutral: chapters are now `{{#include}}` stubs (one per published file); adding a published doc means a stub + a `SUMMARY` entry. The canonical files stay at their canonical paths (`CLAUDE.md` at root, `plan/<NNNN-slug>/`).
- Neutral: stale `book/` output from prior `src="."` builds must be removed once (it had copied `vendor/` in, which can wedge `rm`); CI always builds fresh.
