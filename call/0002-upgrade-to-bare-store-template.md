# Upgrade to the bare-store-with-worktrees template (7dd7556 → bcd1631)

- Status: accepted
- Date: 2026-06-15
- Relates: `call/0001` (the initial adoption at `7dd7556`)

## Context and Problem Statement

`call/0001` adopted `template-agentic-host` at `7dd7556`, which embedded the
software under development (`mcp-win32s`) as a git **submodule**. The template then
advanced to `bcd1631`, introducing two structural migrations in the *Where* room:
embedding the software as a **bare store with worktrees** instead of a gitlink (the
template's `8c28e33`, `call/0004`), and hardening every host reference that had
relied on the submodule's **auto-presence** (the template's `325f2cf`, `call/0005`).
`host-lifecycle upgrade .` printed exactly those two actions as newer than the stamp,
each with its required tool version.

## Decision

Apply both actions per `MIGRATION.md`, then re-stamp:

1. **Tool.** Bump the template submodule `7dd7556 → bcd1631` and rebuild
   `host-lifecycle` from its pinned source — **v0.4.0**, which carries the
   `upgrade` and `software` subcommands (satisfies the steps' v0.3.0 / v0.3.1 floors).
2. **Bare-store conversion (`call/0004`).** Convert `mcp-win32s` from a gitlink
   submodule to a bare store + worktrees, **preserving the pin exactly**: record the
   gitlink SHA `e52e667` as the `.host-software` pin; de-register the gitlink (drop
   the `.gitmodules` stanza, `git rm --cached`, remove `.git/modules/mcp-win32s`);
   gitignore `/mcp-win32s/`, `/mcp-win32s.git/`, `/mcp-win32s.*/`; then
   `software --materialize`. No software commit was created, rewritten, or moved;
   the canonical worktree keeps the path `mcp-win32s/`, so build/hook/routing
   references still resolve.
3. **Worktree-absence coherence (`call/0005`).** This host tracks **no** symlinks
   into the software, so the symlink-untracking is a no-op and `software --check`
   reports no HAZARD by construction. Updated the now-inaccurate
   submodule / pointer-bump vocabulary in the governance docs, the `phase` /
   `phase-gate` skills, and the hook comments to the worktree / recipe-pin model;
   the phase-gate miss message now points the operator at `software --materialize`.
   The mdBook CI job already runs **un-materialized** and stays green.
4. **Re-stamped** `.agentic-host` to `bcd1631`.

## Consequences

- Good: parallel agents and multiple live release branches can coexist on one
  object store; the canonical worktree stays the single audited, CI-run state.
- Neutral: audit shifts from `git submodule status` to `host-lifecycle software
  --check`; a fresh host clone no longer auto-fetches the software — it runs
  `host-lifecycle software --materialize` (replacing `git submodule update --init`),
  and "bump the submodule pointer" becomes "update the `.host-software` pin".
- Follow-up: the host-lint git-hook install into the software repo
  (`git -C mcp-win32s config core.hooksPath …`) is a path-string reference outside
  `software --check`'s symlink-bounded scope (`call/0005`); confirm it still
  resolves under the worktree git-dir on a fresh clone. The PreToolUse hook is the
  primary anti-slop gate regardless.
