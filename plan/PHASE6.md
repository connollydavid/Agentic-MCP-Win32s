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

1. **Environments — mixed.** Windows 3.11 + Win32s 1.25a **emulated under QEMU**
   (operator directive 2026-06-11, superseding the 86Box/DOSBox-X candidates; QEMU's
   `-serial tcp:…` redirect lets host tooling drive the guest's real COM-port code
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
5. **Win 3.11 base image is vendored, never committed** (operator directive
   2026-06-11): the guest images live in a **gitignored `vendor/` directory** at the
   host-repo root. Replication is documented *in this file* (provenance + hashes
   below; local sha256 recorded at vendor time); the binaries stay out of git.
6. **The OVA's contents must be verified to contain nothing unofficial** before use:
   it is a third-party prebuilt VM, so its guest filesystem is inventoried and
   diffed against the **original-floppies baseline** (item below). Anything not
   traceable to official Microsoft Windows 3.11 / Win32s 1.25a distribution files
   (or inert VM scaffolding) is removed or the image is rebuilt from the floppies.
7. **Win32s 1.25a** still has to be sourced/applied separately if the OVA does not
   already carry it — recorded during verification.

## Environment provenance (6.2 base images)

| Artifact | archive.org item | File | Size | md5 (archive) | sha1 (archive) |
|---|---|---|---|---|---|
| Prebuilt VM | `CE55E93BC43C767067BD371EFB97259FE20BC97FB09055AF7BCFD3BA374B1824` ("Windows 3.11 Virtual Machine for Virtual Box", uploaded 2021-07-31) | `Windows 3.11.ova` | 83,561,472 | `81c7335681347d16b42ffeaea4546a88` | `6c0e0ff277ee4b0e99922a6747195ba48b4d58f7` |
| Original floppies | `win311_202602` ("Microsoft Windows 3.11", real-media dump, uploaded 2026-02-17) | `disk1.img` … `disk6.img` (6 × 1,474,560) | see md5 list | `fec70046…`, `807403c3…`, `0986d880…`, `f8e92a83…`, `b2846c30…`, `1281a806…` | per-item metadata |

Full per-disk hashes: disk1 `fec70046eaa9b774035fad6cfd7f7fa0`, disk2
`807403c3bbb0c5b6d0c26f4cbdb6e239`, disk3 `0986d880b621d8f0cc895008c9880009`,
disk4 `f8e92a836acfe2ea3313d3d4c55d19c1`, disk5 `b2846c309097edd7c5b2fa77cb957776`,
disk6 `1281a806b8bd1fe43844ef501803b907` (md5; sha1 in the item metadata; local
sha256 of every vendored file recorded here at vendor time).

Notes: the six-disk set titles as plain **Windows 3.11**, not Windows *for
Workgroups* 3.11 — to be confirmed from the disk contents during verification. If
plain, the TCP/IP-32 Winsock **stretch** goal needs WfW media later; the serial
baseline for the Win32s tier is unaffected. For QEMU the OVA's disk is extracted
(an OVA is a tar of OVF + VMDK) and converted via `qemu-img convert` to qcow2.

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
- **6.2 Windows 3.11 + Win32s 1.25a (QEMU)**: vendor + verify the base images (see
  Environment provenance), convert the OVA disk to qcow2, boot under QEMU with
  `-serial tcp:…` redirect; apply Win32s 1.25a if the image lacks it; deploy the 8.3
  bundle; device on `/SERIAL:COM1`; matrix assert; `exec` `command.com /c dir` through
  the **polling/GetExitCodeProcess path**; on-target tests where runnable. **Stretch**:
  TCP/IP-32 add-on for the Winsock transport (needs WfW media if the image is plain
  3.11).
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

## Stage markers

✅ 0 planning pause — 2026-06-11 (Q&A settled environments/tiers/DBCS/deliverable; PHASE6.md expanded from stub; status In progress; commit 18ddde9)

## Out of scope (recorded gaps)

- cp932/DBCS live verification (deferred — Japanese Win98 hardware forthcoming).
- NT 4.0 / 2000 / Vista–8.1 / Win10-1809 as separately-run tiers (XP and Win11 are
  the NT-era and modern representatives).
- CI-automated emulator boots.
- Full OpenAI agent-loop demo (unchanged from 5.5 — optional, user-run, needs a key).
