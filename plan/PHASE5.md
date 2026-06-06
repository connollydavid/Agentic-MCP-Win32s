# Phase 5: MCP Integration — In progress

> **Opened 2026-06-06** under PLAN.md rule 6 (planning pause): the two-line stub was replaced with a research-grounded plan, every open question was settled with the user in a product-design Q&A round, and the status flips to In progress here. Grounded in June-2026 web research (MCP spec/ecosystem, the Rust SDK landscape) and a user-supplied authoritative Windows memory-model breakdown.

**Goal:** Expose the box's full agent-facing capability surface — **files, build, command execution, and memory** — to MCP clients through a **Rust bridge**, so any modern agent host can drive a Windows 3.1-through-11 machine. The design is **API-first** (capabilities map to Win32 APIs, which are uniform across the 30-year range; raw shell exec is the explicit fallback) and **tiered** (each capability does as much as the host OS allows, advertised via the ready message). Power over the machine is **bounded, consented, and logged** — see the "Respect the machine" principle in the host `CLAUDE.md`.

## Architecture

```
MCP client  ──MCP/JSON-RPC over stdio──▶  Rust bridge  ──newline-JSON over serial/TCP──▶  mcp-w32s.exe
(Claude, ChatGPT, VS Code,                (rmcp; modern host)                            (Win32s..Win11)
 Gemini, Cursor, …)
```

The **bridge** is an MCP **server** (MCP/JSON-RPC to the client) and an MCP-Win32s protocol **client** (the frozen newline-JSON wire protocol to the device — the contract `tests/smoke/wire_client.c` proves). The C server is not itself an MCP server: C89/Win32s cannot carry JSON-RPC/OAuth/HTTP, and the device sits behind serial/TCP. MCP spec churn lives on the modern, easily-updated side; the device wire contract stays frozen and proven. The C server *is* extended this phase with new **API-backed** device commands (file-management + memory), which is additive to the frozen contract.

## Settled decisions

- **D1 — Language/SDK: Rust on `rmcp`.** The official Rust MCP SDK (`modelcontextprotocol/rust-sdk`, v1.7.x, Apache-2.0, tokio), implementing our target spec **2025-11-25**; verified upstream. Single static binary, formal, memory-safe (it parses untrusted model output and drives a serial link), coherent with the project's formal-language stack. Pin the version (fast-moving, `#[non_exhaustive]` models → use builders); verify MSRV against the toolchain.
- **D2 — Target protocol `2025-11-25`, stdio transport, negotiate leniently.** `rmcp` negotiates down to the client by design. A `2026-07-28` RC (stateless core) is in flight — we do **not** build to it, but a tools-only stateless bridge is naturally forward-compatible. **stdio only** this phase; never SSE; Streamable HTTP (and its OAuth/Origin/session surface) is a later phase if remote serving is ever a goal — and *not* exposing it is the security-conscious call given the power this surface grants.
- **D3 — Tools-only portable subset.** Tools are the only universally-supported primitive; resources/prompts/sampling/elicitation/roots/OAuth are feature-detect-never-depend. No core behaviour rests on them ("don't overfit to one consumer").
- **D4 — Result shape:** `text` block (universal) **+** `structuredContent` mirror (from a derived `outputSchema`); device detail (exit_code, exec_method, binary_type, killed_by, durations) → `structuredContent`.
- **D5 — Errors via `isError`:** recoverable failures (catalog miss, argument not allowed, busy, timeout, bad base64, pty/mem unavailable) → tool execution errors the model self-corrects; only malformed/unknown-tool → JSON-RPC errors.
- **D6 — Schema:** `win32_*` names; JSON Schema **2020-12** (`schemars` emits it by default), `additionalProperties:false`, conservative subset; honest `destructiveHint`/`readOnlyHint` annotations — advisory only, safety enforced server-side.
- **D7 — API-first, security-bounded.** Every capability with a Win32 API is a structured API-backed tool (uniform across the range); raw catalogued `exec` is the explicit fallback for genuinely-no-API commands. The catalog allow-list + `argv`/`ArgvCmdEscape` + `CatalogValidateArgs` + job sandboxing (built and review-hardened in Phase 4) **are** the OWASP MCP05 command-injection defense. The bridge adds `isError` translation, per-tool rate limiting (circuit-breaker for the device), audit logging, and human-confirmation surfacing for destructive ops.
- **D8 — Capability gating from the ready message.** `features` (pty, mem tier, encoding tier, …) gate which tools are advertised and how output is decoded; base64 stays for binary/OEM payloads.

## The capability surface (organised by source, not command count)

| Tool(s) | Source | Notes |
|---|---|---|
| `win32_read_file` / `write_file` / `list_dir` / `delete_file` / **`copy_file` / `move_file` / `make_dir` / `remove_dir`** | **API-backed** (`CreateFileA`/`FindFirstFileA`/`CopyFileA`/`MoveFileA`/`CreateDirectoryA`/`RemoveDirectoryA` — Win32s-1.25a-uniform) | the structured, version-uniform core. Supersedes shell `dir`/`type`/`del`/`copy`/`ren`/`md`/`rd`, which **drop from the exposed surface** (they drift across the range; APIs don't). `write`/`delete`/`move`/`remove` carry `destructiveHint`. |
| `win32_compile` / `win32_link` / (`lib`/`assemble`) | **compositional build** | first-class typed steps the agent composes (not make/nmake); the bridge parses cl/link output into structured `{file,line,severity,message}` diagnostics. Under the hood: catalogued exec of the toolchain (the no-API zone). |
| `win32_peek` / `win32_poke` | **API-backed, tiered** (see Memory model) | off by default; operator opt-in; `poke` `destructiveHint`; human-confirmed; audit-logged. |
| `win32_exec` / `win32_pty_exec` / `win32_list_commands` | **shell fallback + discovery** | generic catalogued exec for no-API/non-build commands; pty advertised iff `features.pty`; discovery returns the catalog's per-command flags/descriptions on demand (a **tool**, not a resource — portability). |

## Memory model (grounds `win32_peek`/`win32_poke`; user-mode only, no ring-0)

Windows uses ring 0 (kernel) and ring 3 (user) only; user threads always run ring 3. The design question is **what of the linear address space is mapped user-accessible** per OS — and we use exactly what each OS grants ring-3, **never escalating** (no VxD, call gate, or ring transition). The `mem` capability advertises the tier:

| Tier | What plain ring-3 loads/stores reach (peek/poke) | Not reachable without a driver (out of scope) |
|---|---|---|
| **Win32s** (`mem: shared_vm`) | A single **shared** address space (no per-process VA): **any user-mode mapping in the Windows VM** — other apps' code/data and most of the user-mode system. | ring-0 structures, hardware, VxD pages. |
| **Win9x** (`mem: arena`) | Own **Private Arena** (4 MB–2 GB) R/W; the **Shared Arena** (2–3 GB) R/W — system DLLs (KERNEL32/USER32), Win16/global heaps, memory-mapped files (system-wide reach, patchable, no per-process COW); some low-memory (64 KB–1 MB) process/system structures mapped into every process. | the **3–4 GB Reserved System Arena** (VMM/VxDs) and hardware. Other processes' *private* arenas need a shared section (a raw VA from another process is meaningless since Win95). |
| **NT / 2000 / XP / Vista+ / 7–11** (`mem: process`) | **Only our own user-mode mappings**, plus the user-mode memory of **children we launched**, via `ReadProcessMemory`/`WriteProcessMemory` on a handle with `PROCESS_VM_READ`/`WRITE` — kernel-mediated and validated. Children inherit our token/integrity level by default → same-IL → RPM/WPM works both ways (this is exactly "process memory for a tool launched by us"). | kernel pages (supervisor-only, even though mapped in the top half); unrelated processes' private memory. Vista+ integrity levels constrain *cross-IL* handle acquisition (a low-IL child can't get `PROCESS_VM_WRITE` to a medium/high-IL process) but don't change what one process touches with plain loads/stores. |

Implications: on pre-NT, `peek`/`poke` operate on the broad reachable space the OS already exposes (no process target needed for shared/system regions); on NT+ they require a **process reference** — a child handle the device already retains from the exec/orphan machinery. The pre-NT breadth (a stray `poke` can corrupt the whole VM) is precisely why the capability is off-by-default, gated, confirmed, and audited.

## Encoding / UTF-8 (tiered, opt-in; the bridge always emits UTF-8 on the wire)

MCP's wire is UTF-8; the device speaks ANSI/OEM/DBCS tagged by `codepage`. The encoding model splits cleanly along a line the research surfaced — **the device's own surfaces** (paths, filenames, the device's own ANSI data) versus **child exec output** — because they upgrade differently:

- **Device-own surfaces (paths/files):** **Default** stays OEM/base64+codepage (the bridge transcodes to UTF-8). **Opt-in UTF-8 mode on Win10 1903+** (`encoding: utf8_native`): an embedded **`activeCodePage=UTF-8` manifest** makes the device's `-A` file/path/argv APIs UTF-8 — *same code, no W-APIs, consistent with the ANSI-only constraint* — and the **same binary stays loadable on Win32s** (the manifest is inert/never-parsed pre-SxS, ignored pre-1903; confirmed by MS docs). Reliable from build 18362 for paths/argv. **This tier ships in Phase 5 (5.4).** Build gotcha to handle: MinGW links a default `RT_MANIFEST` at ID 1 — we must ship exactly one manifest (drop/merge the default) or the resource corrupts.
- **Child exec output — does NOT follow the manifest.** A piped child emits *its own* process code page (OEM by default); the parent's manifest/console-CP cannot change that. So `exec`/`ptyExec` output **stays codepage-tagged and is transcoded in the bridge** regardless of UTF-8 mode. (Console A-path UTF-8 via `SetConsoleOutputCP(65001)` is historically unreliable — use `WriteConsoleW` for the device's own console writes, manifest for paths only.)
- **NT..Win8.1 Unicode** needs the **W-API (UTF-16) uplift** — committed, full fidelity, **its own later phase**. `-W` is stubbed on Win32s/9x → runtime-load it (like the other uplifts) so the import table stays Win32s-loadable; convert UTF-16→UTF-8 at the MCP boundary so the agent only ever sees UTF-8.

**Bridge transcoding (verified crate set):** `encoding_rs` (WHATWG/ANSI/CJK: cp1252, 932, 936, 949, 950, **866**, 65001 — with correct DBCS lead/trail handling) **+** `oem_cp` 2.x (the DOS-OEM gap `encoding_rs` lacks: **cp437, cp850**, + other IBM SBCS) **+** optional `codepage` (number→`encoding_rs` Encoding for the web-set; returns `None` for 437/850, so we own a two-branch dispatcher by CP number). Policy: **strict encode** (surface unrepresentable outbound chars as an error, not silent corruption) / **lossy decode** (U+FFFD). Avoid `codepage-strings` (single-byte only, stale). Note: cp866 is *in* `encoding_rs`, not the OEM gap; cp949 is UHC (encoding_rs covers the EUC-KR core — verify if full UHC is in scope).

## Upstream — reuse vs build

| Take from `rmcp` + crates | Build ourselves |
|---|---|
| stdio + JSON-RPC framing; lifecycle + lenient version negotiation; `tools/list`+`call` via `#[tool_router]`; `inputSchema`/`outputSchema` (2020-12 via `schemars`); `structuredContent`; `isError`; annotations; capability gating | the **device relay** (`tokio-serial`/`tokio::net` + `LinesCodec`); the **per-tool mapping**; the **build diagnostic parser**; the **capability gate**; the **memory/encoding tiering** |

Minimal deps: `rmcp` (`server,macros,transport-io`) + `tokio` (current-thread) + `serde`/`serde_json` + `schemars` + `tokio-serial`; dev: `jsonschema` (arg validation), `proptest` (+`proptest-state-machine`) as the theft analog. Distribution: hand-rolled GH Actions musl/zigbuild static-binary matrix (cargo-dist/`dist` has a maintenance question mark); ship three config snippets (`mcpServers`/`servers`/`context_servers` — mismatched keys fail silently).

## Work items (each through the Allium lifecycle)

- **5.0** — bridge core: rmcp, stdio, tools-only, lifecycle/negotiation; mock-device harness.
- **5.1** — API-first file-ops + **device expansion** (Copy/Move/MakeDir/RemoveDir in the C server).
- **5.2** — compositional build steps + cl/link diagnostic parsing.
- **5.3** — **memory** peek/poke (device, tiered/user-mode; tools; the gating/safety model).
- **5.4** — UTF-8 floor (Win10 manifest) + bridge transcoding contract.
- **5.5** — exec/pty/discovery + cross-client acceptance.

## Allium lifecycle & specs

`mcp-bridge.allium` (in `mcp-win32s/specs/`, beside `wire-contract.allium`) models the tool mapping, `isError` translation, capability gating, the memory tiers, and the device round-trip; the device file-ops/memory additions extend `file-ops.allium` / a new `memory-ops.allium`. Standard order: elicit → tend → propagate → implement → distill → weed → merge gate + CI parity → review gate → complete. `/phase-gate` arms at first-green; its gate set extends to the Rust test suite (`cargo test`, proptest) and the **MCP Inspector CLI conformance check**. The review gate's **gate-bypass dimension** is pointed at both the new tool-argument surface *and* the memory surface.

## Supersessions & reconciliation

- The Phase-4-frozen **catalog 1:1 → tools** mapping (`MCP-MAPPING.md`) is **superseded** by the API-first, capability-organised surface; the catalog narrows to the exec allow-list + the build steps' backends, and shell file builtins drop from the exposed surface. (`MCP-MAPPING.md`'s per-command schemas live on as the `win32_list_commands` discovery payload.)
- **OQ7 resolved:** the device wire schema stays **frozen**; the bridge derives 2020-12 schemas from Rust types and maps replies into `structuredContent`/`isError`. No C-server churn for encoding shapes.

## Deferred / out of scope (Phase 5)

- The **W-API (UTF-16) Unicode uplift** across NT..Win8.1 — committed, full fidelity, **its own later phase** (numbered when scheduled).
- Streamable **HTTP** transport + OAuth/remote multi-tenant.
- MCP **resources / prompts / sampling / elicitation / MCP Apps** — progressive enhancements, feature-detected later per demand.
- **Streaming / async exec** — precluded by the one-line wire protocol + single-threaded device (since Phase 4).
- The **2026-07-28 RC** migration (statelessness/MRTR) — track, don't build.

## Acceptance criteria

1. Rust bridge speaks MCP `2025-11-25` over stdio; `initialize`/`tools/list`/`tools/call` round-trip; lenient negotiation.
2. API-first file-ops (incl. the four new device commands) work via Win32 APIs; the shell file builtins are not exposed.
3. Compositional build steps return structured diagnostics; a deliberate compile error surfaces as `{file,line,…}`.
4. `win32_peek`/`win32_poke` honour the tier (process-scoped on NT+; reachable-space on pre-NT), are **off by default**, operator-opt-in, `poke` human-confirmed + audit-logged; the gate-bypass review finds no escalation path.
5. UTF-8 floor: on Win10+, opt-in UTF-8 mode round-trips a non-ASCII filename losslessly; default OEM/base64 path unchanged.
6. Every device error → `isError:true` with an actionable message; only malformed/unknown-tool → JSON-RPC error.
7. **Cross-client:** MCP Inspector CLI conformance (in CI) **+** runs unmodified under the **OpenAI Agents SDK** (automatable) **+** a **VS Code Copilot** manual demo — not Claude-only.
8. Full Allium lifecycle clean (weed zero-drift), CI green (observed), review gate approves; rate limiting + audit logging present.

## Open questions

None — settled in the planning-pause Q&A round (2026-06-06). The encoding research is **done** (folded into the Encoding section: Win10 `activeCodePage` manifest for device paths, exec output stays codepage-tagged/bridge-transcoded, `encoding_rs`+`oem_cp` crate set, the MinGW default-manifest gotcha).

## Sources (June 2026 research)

- MCP spec `2025-11-25` (changelog/transports/lifecycle/tools); `2026-07-28` RC; Authorization + Security Best Practices — modelcontextprotocol.io
- OWASP MCP Top 10 (MCP05) — owasp.org; Anthropic "Writing effective tools for AI agents" (2025-09-11)
- Rust SDK: `modelcontextprotocol/rust-sdk` (`rmcp` 1.7.x); crates: `schemars`, `jsonschema`, `tokio-serial`, `proptest` — crates.io/docs.rs/github
- Windows memory model by tier (Win32s shared VA; Win9x arenas per KB 125691; NT per-process VA + RPM/WPM; Vista+ integrity levels) — user-supplied authoritative breakdown
- Cross-client landscape (OpenAI Agents SDK, Gemini, VS Code Copilot, Cursor, Cline, Zed, JetBrains; MCP Inspector CLI) — 2025–2026 vendor docs
