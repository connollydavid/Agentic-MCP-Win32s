# Phase 5: MCP Integration — Not Started

> **Drafted 2026-06-06, pending the planning pause.** This plan was authored from June-2026 web research into current MCP best practice (sources at the foot). It is the input the `/phase open 5` planning pause reviews and amends; the **open questions** below are settled with the user in that pause (which also flips the status to In progress). Nothing executes until then.

**Goal:** Expose the MCP-Win32s server's capabilities — catalogued command execution, PTY execution, and file read/write/list/delete — to MCP **clients** through a bridge, so any modern agent host can drive a Windows 3.1-through-11 box. The C server (frozen, Phase-4-proven over serial/TCP) is unchanged; Phase 5 builds the bridge above it.

## Architecture

```
MCP client  ──MCP/JSON-RPC over stdio──▶  bridge  ──newline-JSON over serial/TCP──▶  mcp-w32s.exe
(Claude, ChatGPT,                         (modern host)                              (Win32s..Win11)
 VS Code, Gemini, …)
```

The **bridge** is simultaneously an MCP **server** (speaks MCP/JSON-RPC to the client) and an MCP-Win32s protocol **client** (speaks the frozen newline-JSON wire protocol to the device — the exact contract `tests/smoke/wire_client.c` already proves). The C server is *not* an MCP server itself: C89/Win32s cannot reasonably carry JSON-RPC/OAuth/HTTP, and the device sits behind a serial/TCP link. This split is the textbook stdio-bridge case the spec describes.

## Research-grounded decisions (June 2026; confirm in the pause)

The MCP field moved two spec revisions past a Jan-2026 baseline; these are grounded in the current spec and the cross-client landscape.

- **D1 — Target protocol `2025-11-25`** (the current *stable* revision), negotiate leniently (echo the client's version if supported, else offer ours). A **`2026-07-28` release candidate** exists (stateless core: drops the `initialize` handshake and `MCP-Session-Id`, deprecates sampling/roots/logging, replaces server-initiated requests with Multi-Round-Trip Requests). We do **not** build to the RC — but a tools-only, stateless bridge is *naturally* forward-compatible with it, which is a reason to stay in the portable subset.
- **D2 — Client transport: stdio first.** The spec's preferred default, the universal client baseline, and a direct heir to our newline-JSON-over-a-pipe heritage. Streamable HTTP is optional and later (it pulls in Origin validation, session IDs, and the whole OAuth stack); **never SSE** (deprecated 2025-03-26).
- **D3 — Tools-only portable subset.** Tools are the only universally-supported primitive across Claude, ChatGPT/OpenAI Agents SDK, Gemini, VS Code Copilot, Cursor, Windsurf, Cline, Zed, JetBrains. Resources, prompts, sampling, elicitation, roots, and OAuth are unevenly supported → **feature-detect, never depend on**. No core behaviour rests on them.
- **D4 — Result shape.** Every tool returns a `text` content block (universally rendered) **and** a `structuredContent` mirror (progressive enhancement) when an `outputSchema` is declared. `exit_code`, `exec_method`, `binary_type`, `killed_by`, truncation flags, `duration_ms` go in `structuredContent`; a human-readable summary goes in `text`.
- **D5 — Errors via `isError`.** Recoverable failures the model can fix or retry — catalog miss, argument not allowed, busy, timeout, stdin too large, invalid base64, pty-not-available — return as **tool execution errors** (`isError: true` with an actionable message), per the current spec (input-validation errors are tool errors, not protocol errors). Only malformed/unknown-tool calls are JSON-RPC protocol errors.
- **D6 — Tool schema.** Self-prefixed names (`win32_*`), 1–128 chars, `[A-Za-z0-9_.-]`; JSON Schema **2020-12**, `additionalProperties: false`, explicit `required`; conservative subset (no `oneOf`/`$ref` graphs/`patternProperties` — client validation fidelity varies). Honest, conservative tool **annotations** (`destructiveHint` for `del`/`rmdir`/etc., `readOnlyHint` for `dir`/`type`) — but they are advisory; safety is enforced server-side.
- **D7 — Security = the catalog is the OWASP MCP05 boundary, and it is already built.** Command-executing servers are the canonical MCP threat (command injection). Phase 4 already implements the required mitigations: the catalog **allow-list**, `argv` + `ArgvCmdEscape` instead of shell string-building (the very gap the review gate caught and closed), `CatalogValidateArgs`, and job-object sandboxing. The bridge adds: `isError` translation, per-tool **rate limiting** (LLMs retry aggressively — a circuit breaker for the device), **audit logging** of every invocation (identity, timestamp, args), and surfacing destructive operations for human confirmation. OAuth is **skipped** for the local stdio bridge (the spec says stdio SHOULD NOT use the OAuth flow; rely on OS-level controls).
- **D8 — Capability gating from the ready message.** The device's ready message (`codepage`, `version`, `features`) maps onto MCP capabilities: advertise `win32_pty_exec` **only when** `features.pty`; decode OEM exec output using `codepage`; surface `features` so a capability-aware client sees what the host supports. base64 stays for all binary/OEM payloads (matches MCP's own base64 for image/audio/blob content).

## The MCP surface (maps the frozen Phase-4 contract)

The Phase-4 `catalog/MCP-MAPPING.md` froze the catalog→tool-definition mapping; Phase 5 realises it. The exec/file-ops/ptyExec JSON shapes are frozen; the bridge translates them to MCP results. Candidate tool surface (granularity is **OQ2**):

| MCP tool (proposed) | Backs onto | Notes |
|---|---|---|
| `win32_exec` *(or 30 per-command tools)* | `exec` + catalog gate | catalogued command + validated args; `structuredContent` carries exit/method/type/killed_by |
| `win32_pty_exec` | `ptyExec` | advertised only when `features.pty`; merged ANSI `output_b64` |
| `win32_read_file` / `win32_write_file` / `win32_list_dir` / `win32_delete_file` | file-ops | base64 payloads; `delete`/`write` carry `destructiveHint` |

## Allium lifecycle (the bridge is behaviour → it gets specs)

Phase 5 runs the same lifecycle. Allium is language-agnostic, so the bridge's behaviour is specified before it is built: a new `mcp-bridge.allium` models the tool mapping, the `isError` translation, capability gating, statelessness, and the device round-trip — sitting *above* the existing `wire-contract.allium` (device side). elicit (settle the open questions) → tend (`mcp-bridge.allium`) → propagate (the bridge test suite: protocol-conformance + tool round-trips, traced to obligations) → implement → distill (if any module lacks a spec) → weed (zero drift) → merge gate + CI parity → review gate → complete. The deterministic `/phase-gate` arms at first-green; its gate set extends to the bridge's test suite and an MCP **conformance check** (e.g. the MCP Inspector / a 2025-11-25 protocol probe).

## Open questions — for the `/phase open 5` planning pause

1. **OQ1 — SDK / language.** Python `mcp` SDK + `pyserial` (the existing "modern bridge side" deps lean this way) vs the TypeScript SDK. Both are first-class and target the 2025-06-18+ baseline.
2. **OQ2 — Tool granularity (the central fork).** 30 catalogued commands as **30 tools** (the frozen 1:1 `MCP-MAPPING.md`, maximal discoverability) vs a **consolidated** surface (one `win32_exec` with a catalog-validated command param + the file-ops tools + `win32_pty_exec`). Research favours consolidation ("don't mirror every endpoint; tool count dilutes selection"); the Phase-4 decision favoured 1:1. May the catalog also be exposed as a read-only listing the model can consult?
3. **OQ3 — Bridge code location.** A `bridge/` directory inside the `mcp-win32s` submodule (versioned with the wire protocol it depends on) vs a new submodule (clean language/toolchain separation).
4. **OQ4 — Spec home & test style.** Where `mcp-bridge.allium` lives (follows OQ3), and how much of the bridge's logic is theft-style property-tested vs MCP-conformance-tested.
5. **OQ5 — Transport scope this phase.** stdio only, or stdio **+** Streamable HTTP (the latter adds Origin validation, session IDs, and pulls OAuth into scope).
6. **OQ6 — Cross-client acceptance.** Which non-Anthropic client(s) join the acceptance test — MCP **Inspector** (baseline conformance) plus at least one of VS Code Copilot / OpenAI Agents SDK / Gemini CLI — so we prove "no overfit," not just "works in Claude."
7. **OQ7 — Frozen-schema reconciliation.** Verify the Phase-4-frozen JSON shapes (`exit_code`, `stdout_b64`, `structuredContent` candidates) against `2025-11-25` before locking; the Phase-4 note accepted the risk of a vNext.

## Acceptance criteria (provisional; finalised in the pause)

1. The bridge speaks MCP `2025-11-25` over stdio; `initialize`/`tools/list`/`tools/call` round-trip; version negotiation is lenient.
2. Every device error surfaces as `isError: true` with an actionable message; only malformed/unknown-tool → JSON-RPC error.
3. `win32_pty_exec` is advertised iff the device reports `features.pty`; OEM output is decoded via `codepage`.
4. Tools carry 2020-12 schemas with `additionalProperties:false`; destructive tools carry `destructiveHint`; safety is enforced server-side regardless of the hint.
5. **Cross-client:** passes the MCP Inspector conformance check **and** runs unmodified in ≥1 non-Anthropic client (OQ6), not only Claude.
6. The full Allium lifecycle is clean (weed zero-drift), CI green (observed), and the adversarial review gate approves — with the gate-bypass dimension applied to the new tool-argument surface.
7. Rate limiting and audit logging are present; a destructive op is surfaced for confirmation.

## Out of scope (Phase 5)

- The **2026-07-28 RC** migration (statelessness/MRTR) — track, don't build; our portable subset is already forward-leaning.
- **OAuth / remote multi-tenant** auth — only needed if Streamable HTTP remote serving is in scope (OQ5).
- MCP **resources / prompts / sampling / elicitation / MCP Apps** — progressive enhancements, not core; revisit per client demand.
- **Streaming / async exec** — the one-line-in/one-line-out wire protocol and single-threaded device preclude it (deferred since Phase 4).

## Sources (June 2026 research)

- MCP spec `2025-11-25`: changelog, transports, lifecycle, server/tools — modelcontextprotocol.io
- MCP `2026-07-28` release candidate (stateless core) — blog.modelcontextprotocol.io
- Authorization spec (OAuth Resource Server, RFC 9728/8707, CIMD); Security Best Practices — modelcontextprotocol.io
- OWASP MCP Top 10 (MCP05 Command Injection & Execution) — owasp.org
- Anthropic, "Writing effective tools for AI agents" (2025-09-11)
- Cross-client landscape: OpenAI Agents SDK / Responses API, Google Gemini, VS Code Copilot, Cursor, Cline, Zed, JetBrains docs (2025–2026)
- (Full URLs retained in the planning-session research; folded into a `bridge/` references list during implementation.)
