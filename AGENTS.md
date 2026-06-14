# AGENTS.md — Agentic host guide

This is the agentic host repository. The software under development lives in the `mcp-win32s/` submodule and is the **single source of truth for everything about itself** — do not duplicate its content here.

## Where things live

| Concern | Source of truth |
|---------|-----------------|
| Technical constraints (C89, i386, Win32s API subset), build commands, code conventions | `mcp-win32s/CLAUDE.md` |
| Behavioural specs | `mcp-win32s/specs/*.allium` |
| Vendored theft library internal idioms | `mcp-win32s/vendor/theft/CLAUDE.md` (third-party; referenced, not duplicated) |
| Milestone plans, milestone index, per-milestone status | `plan/PLAN.md` + `plan/<NNNN-slug>/README.md` (here) |
| Agentic process: Allium lifecycle, merge gate, milestone-file rules | `CLAUDE.md` (here) |
| Methodology spine + the agentic-host template it is sourced from | `template-agentic-host/` (its `CLAUDE.md`; pinned via `.agentic-host`) |
| Anti-slop hygiene linter (match engine) | `host-lint/` (rules in its `VOCABULARY.md`) |
| Decisions (MADR) | `call/` (here; see `call/0000`) |
| Personas (the project's *who*) | `cast/` (here) |
| Lessons learned | `MEMORY.md` (here) |

## How agents work here

1. Read `CLAUDE.md` (here) for the process; read `mcp-win32s/CLAUDE.md` before touching any code.
2. Plan in `plan/` (host commits, pushed immediately); code in `mcp-win32s/` on a branch, merged via PR in that repo behind the Allium merge gate; bump the submodule pointer here in a separate commit.
3. Record non-obvious findings in `MEMORY.md` (here), in separate commits.
