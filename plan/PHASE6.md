# Phase 6: Cross-Platform Testing — In progress

Verify the device on the real OS ladder. Phases 1–5 verified behaviour only under
**Wine (an NT proxy) and WSL2-native modern Windows**; every OS-tier-dependent
mechanism carries an explicit "Phase 6 hardware" deferral. The device self-describes
per-tier via its **ready-message capability matrix** (`feat.c` → `ready.c`), which
gives every tier a concrete, assertable acceptance target — the harness asserts the
artifact (the observed ready line + captured test output), never prose.

## Carried-forward deferrals this phase discharges

From the closed phases (quotes live in PHASE4.md / PHASE5.md / MEMORY.md):

- **Win32s 1.25a**: the polling/`GetExitCodeProcess` capture path (KB Q125213 —
  `WaitForSingleObject(hProcess)` returns immediately on Win32s), COMMAND.COM shell
  selection, `shared_vm` memory tier, no-threads/no-jobs/no-pty floor (PHASE4.md
  manual-smoke deferral).
- **Win9x**: the `arena` memory tier, the 16-bit **`vdm-best-effort`** path (timeout →
  no `TerminateProcess`, orphan reap), manual binary classification, codepage encoding
  tier live narrowing + `StrictNarrowingRejectsUnrepresentable` on a real 9x kernel.
- **NT-era**: job objects live (memory cap = alloc-failure semantics; CPU-time cap →
  quota exit **1816** never observed on a real NT), ctrl events, `utf8_via_w` wide-API
  tier with non-ASCII paths/argv, spawn-retain RPM/WPM.
- **Win10+**: the `GetACP()==65001` manifest **runtime effect** (CI only asserts the
  manifest's presence), ConPTY `ptyExec` (skip-with-reason everywhere so far).
- **Transports**: real serial (never tested on any UART), Winsock on Win32s
  (TCP/IP-32).

## Settled decisions (planning-pause Q&A, 2026-06-11)

1. **Environments — mixed.** WfW 3.11 + Win32s 1.25a **emulated** (86Box or DOSBox-X;
   emulator serial→TCP redirect so host tooling drives the guest's real COM-port code
   path). Win98 SE and Windows XP on the **real dual-boot machine over the existing
   serial (null-modem) connection** to the dev host. Windows 11 = the dev host itself,
   natively (not WSL-interop, so the interop skips assert fully).
2. **All four tiers mandatory** for phase completion: WfW 3.11+Win32s 1.25a, Win98 SE,
   XP, Win11.
3. **DBCS deferred**: a Japanese (cp932) Win98 will be made available later — the live
   DBCS-safe path-scan / strict-narrow verification is an explicit deferred item, not
   a Phase-6 blocker. The exhaustive per-codepage unit tests stand as current evidence.
4. **Deliverable = scripted harness**: a committed per-tier acceptance harness
   (on-target runner + host-side wire/matrix checker) + committed per-tier
   verification reports with captured output. Human-triggered, repeatable.

## Per-tier expected capability matrix (the acceptance spine)

| Ready field | Win32s 1.25a | Win98 SE | XP | Win11 |
|---|---|---|---|---|
| `is_win32s/is_win9x/is_nt` | T/F/F | F/T/F | F/F/T | F/F/T |
| `threads` | false | true | true | true |
| `job_objects` / `ctrl_events` | false | false | true | true |
| `pty` | false | false | false | true |
| `binary_classify` | manual | manual* | GetBinaryTypeA | GetBinaryTypeA |
| `mem` | shared_vm | arena | process | process |
| `encoding` | utf8_from_cp | utf8_from_cp | utf8_via_w | **utf8_manifest** |
| exec capture | **polling** | threaded | threaded | threaded |
| shell | COMMAND.COM | cmd/command | cmd.exe | cmd.exe |

(*Win98: `GetBinaryTypeA` absence to be confirmed live — feat probes it. The matrix
values trace to the specs: wire-contract.allium ReadyShape, memory-ops tier selection,
encoding provenance.)

## Work items

- **6.0 Harness + deploy bundles** (the implement-heavy item, fan-out):
  - **Host-side matrix checker**: extend `tests/smoke/wire_client.c` with an
    `--expect key=value,...` mode asserting the per-tier ready matrix (expected-matrix
    data files per tier, traced to specs), and (decide at implement) a serial mode —
    OR lean on the bridge, which already supports `--serial PATH[:BAUD]`
    (`bridge/src/device.rs:95`). Serial plumbing from the dev host: candidates are
    usbipd→`/dev/ttyUSB*` into WSL2, a COM→TCP shim on the Windows side (keeps all
    existing TCP tooling unchanged), or running the host tools natively on Win11
    (wire_client is a Windows .exe already). Verify and pick at implement.
  - **On-target bundle**: deploy script producing per-tier bundles — `mcp-w32s.exe` +
    catalog + selected `test_*.exe` + `RUNTESTS.BAT` capturing output to a log file.
    **Win32s bundle needs 8.3 filenames** (FAT, no LFN) — the script maps names.
  - **Verification-report template** + per-tier checklist generated from the
    propagate-stage obligations.
- **6.1 Win11 native (dev host)**: device run natively so the skip-with-reason tests
  assert fully — live `GetACP()==65001` manifest effect, ConPTY `ptyExec` for real,
  full on-target suite, job/ctrl tests, bridge end-to-end (TCP loopback) + an MCP
  client. Folds in the 5.5 VS Code demo artifacts if convenient.
- **6.2 WfW 3.11 + Win32s 1.25a (emulated)**: boot WfW 3.11 + Win32s 1.25a in
  86Box/DOSBox-X; deploy the 8.3 bundle; device on `/SERIAL:COM1` with the emulator's
  serial redirected to host TCP; matrix assert; `exec` `command.com /c dir` through
  the **polling/GetExitCodeProcess path**; on-target tests where runnable. **Stretch**:
  TCP/IP-32 add-on for the Winsock transport on Win32s.
- **6.3 Win98 SE (real hardware, serial)**: matrix assert (arena/threads/manual);
  threaded capture; **16-bit VDM child best-effort live test** (.COM/.EXE, timeout →
  no Terminate, orphan reap); file ops; codepage tier; on-target suite; SetErrorMode
  dialog suppression observed.
- **6.4 Windows XP (same machine, dual-boot flip)**: matrix assert; **job objects
  live** (memory cap = alloc-failure semantics; CPU-time cap → quota exit **1816**
  verified); ctrl events; `utf8_via_w` wide-API tier (CJK file round-trip on real NT);
  spawn-retain RPM/WPM live; GetBinaryTypeA classification; on-target suite.
- **6.5 Close-out**: consolidated verification report committed; defects found are
  remediated via the normal lifecycle (branch→PR, specs tended, full merge+review
  gates — each fix is its own verified artifact); explicit gaps recorded (cp932 DBCS
  pending hardware; NT4/2000/Vista–8.1/Win10-1809 not separately run; CI-automated
  emulators out of scope); Phase 6 → Complete.

## Lifecycle mapping (a testing phase still walks the stages)

- **1 elicit (light)**: settle the acceptance domain model — per-tier expectations,
  harness check IDs, what "verified on tier X" means; zero open questions.
- **2 tend**: expected-matrix values must trace to the specs. New harness behaviour
  stays inside wire-contract's scope (wire_client is that spec's proof tool); spec
  changes only if the harness work reveals drift — then the safety-transform/invariant
  rules apply as usual.
- **3 propagate**: **OBLIGATIONS-6 = the per-tier checklists** — every Phase-4/5
  deferral converted to a tier × check-ID row (the carried-forward inventory above is
  the input); floor only grows.
- **4 implement**: 6.0 fan-out (checker / bundles / serial plumbing / report template
  on disjoint files); gate arm at first all-green of the harness against the existing
  CI topology (Wine TCP) before any hardware run.
- **5 distill / 6 weed**: per usual; weed includes the gate-bypass dimension on
  anything the harness or fixes touched.
- **7–9 merge/review gates**: per PR, non-negotiable, observed CI.
- **Tier runs (6.1–6.4) are HUMAN GATES**: each needs the user to boot/flip the
  machine, transfer the bundle, and confirm the physical serial hookup; the harness
  automates the host side once connected. Results are committed artifacts, not prose.

## Risks (recorded up front)

- **Win32s console-subsystem support**: the device is a CONSOLE-subsystem binary;
  whether Win32s 1.25a runs it as-is is precisely what hardware verification exists
  to answer — first checkpoint of 6.2; a failure becomes a remediation work item
  (e.g. windowed entry stub), not a plan failure.
- Serial flakiness (real UART @115200, cable quality) — keep `/BAUD` fallback in the
  checklist.
- Win32s 16 MB per-app limit + FAT 8.3 names constrain the bundle.
- Old-machine file transfer logistics (USB on XP; CD/floppy/HyperTerminal-ZMODEM on
  98SE) — documented in the bundle README, user-executed.

## Out of scope (recorded gaps)

- cp932/DBCS live verification (deferred — Japanese Win98 hardware forthcoming).
- NT 4.0 / 2000 / Vista–8.1 / Win10-1809 as separately-run tiers (XP and Win11 are
  the NT-era and modern representatives).
- CI-automated emulator boots.
- Full OpenAI agent-loop demo (unchanged from 5.5 — optional, user-run, needs a key).
