# Adopt the agentic-host template and retire the milestone-name carve-out

- Status: accepted
- Date: 2026-06-14

## Context and Problem Statement

This repository was an agentic host before the methodology was extracted into a
reusable template. It carried the ideas — a committed plan, audited milestones, a
hygiene linter, an Allium specification lifecycle — under the repo's own ad-hoc
names. Two things then changed upstream:

- The two tool submodules were renamed: `andrej-karpathy-skills` became
  `template-agentic-host`, and `no-phase-skill` became `host-lint`.
- The carve-out that let the host's own plan documents use numbered
  milestone-synonym names (the `Phase N` filename and header convention) was
  retired. With it gone, those ordinal names are hygiene findings like any other
  — the linter that guards the software submodule now also binds the host's own
  artifacts.

The repository had no `.agentic-host` stamp, so it could not be upgraded by
diffing template revisions; it had to be first-stamped.

## Decision

Bring the repository under the template methodology in one reviewed change:

- **Re-point** the two renamed tool submodules to their new paths and URLs; the
  hosted-software submodule (`mcp-win32s`) is untouched.
- **Stamp** the repo against the template at revision
  `d57c29ad5a47e829a66f05f26b187c20e7fd6b86` and scaffold the rooms the template
  defines (`cast/`, `call/`; `plan/` already existed).
- **Rename** the ordinal milestone documents to content-named homes under
  `plan/`, generated to the shared naming rules the tools enforce, and update
  every reference and path that pointed at the old names.
- **Retire the carve-out** in the hygiene wrapper: the milestone-synonym subject
  exemption is removed, since the structure it protected no longer exists.
- **Eliminate the residual ordinal-synonym names** from every tracked live file —
  including the closed milestone bodies and `MEMORY.md`. This deliberately
  overrides the closed-milestone-immutability and append-only-`MEMORY` rules for
  this one change, because a clean baseline is worth more than the immutability
  of records that only ever named themselves by ordinal. The commit history is
  left intact (it is acknowledged, not rewritten).

## Consequences

- Good: the host now carries the template stamp, so future upgrades are a
  revision diff; the hygiene linter is clean across all live files, binding the
  host's own artifacts as strictly as the software's; milestones are named by
  what they are, not by an ordinal.
- Cost: a large one-time rewrite of historical documents, justified and bounded
  by this record; the override of two standing rules is explicit and recorded
  here rather than silent.
- Neutral: the milestone register and this decision register are two numbered
  sequences, told apart by home (`plan/` root versus `call/`) per record `0000`.
