# MEMORY.md — decisions, constraints, lessons learned

Append-only. Newer entries correct older ones by reference; never rewrite or delete.

## 2026-06-06 — Repo separation

- The original inline MCP-Win32s repo was split: agentic assets (plans, harness config, process docs) moved to this host repo; the software itself is vendored as the `mcp-win32s/` submodule. PLAN.md was split into `plan/PHASE1-7.md` with strict sequencing rules in `plan/PLAN.md`.
- **Submodule paths are lowercase** (`mcp-win32s/`, `andrej-karpathy-skills/`). A WSL2 9p/drvfs bug poisoned the dentry for the mixed-case path `MCP-Win32s` after a rename-then-failed-clone sequence; the poison survived `drop_caches` and remounts. Lowercase paths sidestep the entire class of case-mismatch problems on /mnt/c — prefer them for all new top-level entries.
- The allium plugin is registered project-scope in `~/.claude/plugins/installed_plugins.json` keyed by **absolute project path** — moving/renaming the project directory silently orphans the plugin (`/reload-plugins` reports 0 plugins). `.claude/settings.json` here carries `extraKnownMarketplaces` + `enabledPlugins` so a fresh clone self-registers.
- Planning state must exist in exactly one place: `plan/PLAN.md` index here. The submodule's CLAUDE.md previously carried a duplicate phase-status table (removed in MCP-Win32s@91df55a) and host AGENTS.md was a stale copy of the submodule's constraints (rewritten as a source-of-truth map). Watch for this drift pattern when adding docs.
- `mcp-win32s/specs/transport.allium` has 2 pre-existing parse errors at line 202: a stray `@` and an `invariant SerialHasNoOrderlyClose` with a comment but no body (truncated edit, committed). The merge gate ("allium check clean") was therefore not actually met at MCP-Win32s@28055d7. Fix must go through `/allium:tend` once the plugin session loads.
- Version drift found 2026-06-06: allium CLI 3.2.3 installed vs 3.2.4 on crates.io; allium plugin 3.1.5 cached vs 3.3.0 in the juxt-plugins marketplace (3.3.0 adds tend/weed agents). Update via `cargo install allium-cli` and `/plugin update allium@juxt-plugins`.
- The `@invariant` prose form is only valid **inside contract declarations** (allium 3); top-level prose properties go in `--` comments, expression invariants use `invariant Name { ... }`. The transport.allium parse errors (see 2026-06-06 entry above) were exactly this misuse — fixed via tend in MCP-Win32s@e143fef; `allium check` now reports info-only across all three specs.

## 2026-06-06 — Phase 4 opening

- **Process correction (user):** opening a phase is never "bolt a preamble onto the existing plan." It requires an explicit planning pause — full review of the phase file, Q&A on open decisions (SDKs, scope boundaries), stale-reference fixes — codified as PLAN.md rule 6. The pause caught real plan rot: a `/STDIO` acceptance criterion for a transport that doesn't exist, cmdline parsing attributed to serial.c after Phase 3 moved it to transport.c, and doc references predating the repo split.
- Phase 4 decisions: weed #1 = code bug (empty list path must error, not expose CWD); weed #6 (transport surfaces) in 4.0 scope; bridge in Phase 4 = C+PBT wire-contract smoke client under an Allium spec (no SDK); MCP SDK choice deferred to Phase 5; catalog schema must map 1:1 to MCP tool definitions (catalog/MCP-MAPPING.md) to avoid a v2.
