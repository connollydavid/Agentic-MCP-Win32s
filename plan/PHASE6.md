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
2a. **Two compatibility floors to baseline against** (operator directive 2026-06-11):
   the **Win16/Win32s floor** = Windows 3.x + **Win32s 1.25a**, and the
   **native-Win32/NT floor** = **Windows NT 3.1** (July 1993, the first Windows NT and
   the first Win32 platform — https://en.wikipedia.org/wiki/Windows_NT_3.1). These are
   the *earliest/hardest* targets in each family: if the device loads and runs on NT 3.1,
   every later NT (3.51/4.0/2000/XP/…/11) is covered by superset; if it runs on Win32s
   1.25a, every later Win32s is covered. NT 3.1 exercises the device's delay-load floor
   hardest — only the base Win32 of 1993 is present, so every API we resolve via
   `GetProcAddress` and guard must correctly read as absent. Practical sourcing note: the
   MSDN Jan-1998 set carries **NT 3.51**, not 3.1; **NT 3.1 needs separate sourcing**, and
   **NT 3.51** (already in-hand) is the nearest *runnable* early-NT representative if NT
   3.1 proves too hardware-picky under QEMU. Status: NT 3.1 is a **declared baseline
   target**; whether it becomes a *run* tier in Phase 6 depends on sourcing + QEMU boot
   (recorded as a work item, not yet a hard gate).
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
6. **The OVA's contents must be verified to contain nothing unofficial** before use.
   **Verification result (2026-06-11): the OVA is REJECTED as the base image.** All
   hashes verified (archive md5/sha256, internal `.mf` sha1 — see below), and the
   61 MB second disk is benign (the standard VirtualBox Guest Additions ISO). But the
   primary VMDK's guest filesystem is **contaminated with preloaded third-party /
   non-base software** — a `COBOL\` toolchain and an `F32\` tree (Microsoft FORTRAN
   PowerStation 32), matching the OVF's own "Programmer's Edition … preloaded with
   Microsoft FORTRAN PowerStation and QBASIC" annotation and a third-party EULA
   (© A. Scott Fulkerson). It is not an official-only baseline, so it fails the bar.
7. **Pivot (operator directive 2026-06-11): build a fresh, scripted install** under
   QEMU from **verified, official-only Microsoft media**. DOS substrate settled as
   **MS-DOS 6.22** (operator directive — bundle item below). Win32s 1.25a (the actual
   device target) still to source + verify the same way. Edition (plain 3.11 vs WfW
   for the TCP/IP-32 stretch) left open; plain 3.11 is sufficient for the serial
   baseline.

### Authenticity note — Microsoft never shipped these as ISOs

Windows 3.1 / 3.11 / WfW 3.11 / MS-DOS 6.22 were distributed by Microsoft on **floppy
disks** (1993–94), not CD-ROM. Every "Windows 3.11 ISO" in circulation is a **community
repackaging** of the original floppy install files onto a CD image — the *file payloads*
can be genuine Microsoft files, but the ISO container is not an official Microsoft
product. Confirmed empirically: two "Windows 3.11" sources here disagree — the
`win311_202602` floppies are a 6-disk `MSWIN3111` set (`SETUP.EXE` 436,560 B, Dec 1993)
while the `windows-3.11_Dos_6.22_ISO` bundle is an 8-disk set (`SETUP.EXE` 244,255 B,
Nov 1993): **different official builds**, not a clean byte-match. Consequence for the
"nothing unofficial" bar: trust is anchored on the **floppy file set** (the authentic
original distribution form, hash-verified against archive metadata); ISOs are treated as
convenience transports whose payloads are inspected for foreign content (both bundle
ISOs scanned clean — only classic MS-DOS 6.22 / Windows 3.1x files, no foreign
executables) but are not assumed identical to the floppies.

**Preferred sourcing strategy — MSDN (operator directive 2026-06-11).** The one form
in which Microsoft *did* officially ship these on CD-ROM is **MSDN** (and the
Win32 SDK / TechNet). MSDN Operating-Systems subscription discs carried MS-DOS,
Windows 3.1 / 3.11 / WfW 3.11, **and Win32s** as genuine Microsoft developer
distributions — a single coherent, license-clean provenance, and the authoritative
home for **Win32s 1.25a** (which Microsoft distributed through the developer channel,
not retail). The plan therefore prefers a verified MSDN OS disc as the source of
record for Win32s 1.25a (and WfW 3.11 for the TCP stretch), with the floppy/ISO sets
above as already-verified fallbacks for the DOS+Windows substrate.

## Environment provenance (6.2 base images)

> **Verification status — what `md5 ✓` here does and does NOT prove (read first).**
> Throughout this file, `md5 ✓` means **the local copy matches the hash published by the
> *same* archive.org item** — i.e. it confirms **transit integrity / reproducibility only**
> (the download wasn't truncated or corrupted, and anyone re-pulling the item gets the same
> bytes). It does **NOT** establish **authenticity** — that the disc image is genuine,
> complete, unmodified **official Microsoft** media — because these are **community uploads
> with no independent authority** behind them (an uploader's modified image would still
> match its own md5). Authenticity is only as strong as a second, independent check:
> against-the-floppy-set cross-reference, an official Microsoft hash, a redump.org match, or
> the MSDN **CD Index**. Where we have such a check it is noted; where we do not, the
> artifact is **integrity-confirmed but authenticity-TBC**.
>
> **The MSDN Platform Archive Jan-1998 set is therefore `TBC`, not "clean/verified".** It is
> (a) **incomplete** — discs 6/7/8/15 are missing — and (b) only **integrity-confirmed**
> against archive.org's own metadata, never cross-checked against an authoritative Microsoft
> reference. Treat "we have a clean MSDN set" as **unproven**. Upgrade TBC→confirmed requires
> an independent authority (official hashes / CD Index / redump set match).

| Artifact | archive.org item | File | Size | md5 (archive) | verified |
|---|---|---|---|---|---|
| ~~Prebuilt VM~~ **REJECTED** | `CE55E93B…` ("Windows 3.11 VM for VirtualBox", 2021-07-31) | `Windows 3.11.ova` | 83,561,472 | `81c7335681347d16b42ffeaea4546a88` | hashes ✓ (md5+sha256+internal .mf sha1); **contents contaminated → rejected** |
| **Original floppies** (trust anchor) | `win311_202602` ("Microsoft Windows 3.11", real-media dump, 2026-02-17) | `disk1.img`…`disk6.img` (6 × 1,474,560) | see md5 list below | md5 ✓ all six |
| **MS-DOS 6.22** (substrate) | `windows-3.11_Dos_6.22_ISO` ("Windows 3.11 and Dos 6.22 bootable CDROM", 2022-02-02) | `MS-Dos 6.22.iso` | 6,473,728 | `0b805cfca48fddfb6c1f106083df36f5` | md5 ✓; contents = standard MS-DOS 6.22 (1994-05-31), clean |
| Windows 3.11 (alt, 8-disk) | same bundle | `Windows 3.11.iso` | 11,948,032 | `a9e5ebc8219ddf800ad427d644ac8cfc` | md5 ✓; classic Win 3.1x files (1993-11), clean; different build from the floppies |
| **MSDN-style international 16-bit collection** | `1998-01-01-ms-doswindows3.1windows3.11andwfw3.11` (2019-09-25) | `16-BIT.ISO` | 547,997,696 | `d1aac83b8febbb8b80bf5ea41f0506b0` | md5 pending full pull; **path-table enumerated** — NOT Greek-only (see below) |

**`16-BIT.ISO` is mislabelled "Greek" — it is a multi-language MSDN-style OS disc**
(enumerated cheaply from the ISO9660 path table via HTTP range reads, ~5 KB, before any
full download; volume ID `16-BIT`). Four product trees, each with many localisations:
- **MSDOS**/ — usa (6.0, 6.22), brazil, danish, dutch, finnish, french, german, hebrew,
  italian, **japanese (MSDOS62V — the DBCS /V build)**, **korean**, norway, russian,
  **simpchin (DOS 6.22 Simplified Chinese)**, spanish, swedish, arabic.
- **WFW311**/ — **usa**, arabic, danish, dutch, eng_ara, finnish, france, french,
  frn_ara, german, hebrew, hungary, italian, norwegn, polish, portugse, russian,
  spanish, swedish, thailand.
- **WIN31**/ — **greek**, arabic, catalan, centeur, czech, danish, finnish, frn_ara,
  hebrew, hungary, **japanese (98 / V / WDL — PC-98 + DOS/V)**, **korean**, norwegn,
  **persian (9 disks)**, polish, russian.
- **WIN311**/ — **usa**, dutch, french, german, italian, portugse, spanish, swedish,
  thailand, turkish.

Why this matters here: it supplies **USA WfW 3.11** (the TCP/IP-32 Winsock **stretch**
media) from a coherent MSDN-style source, and it carries the **Japanese (cp932) /
Korean (cp949) / Simplified-Chinese (cp936) DBCS** environments — the exact substrates
the 5.4 encoding tier's live DBCS-safe path-scan + strict-narrow verification was
deferred for. Candidate to **un-defer** part of that DBCS gap on a Win 3.1 + Win32s
DBCS guest (closer to the device's actual Win32s target than the forthcoming Win98).
Contents to be inventoried + verified after the full pull (md5 against archive,
foreign-content scan of the USA trees we actually use).

Local sha256 of every vendored file recorded at `vendor/win311/SHA256SUMS` at vendor
time (gitignored with the binaries; the hashes are mirrored into the verification report).

### MSDN January 1998 disc set — candidate source (survey) — **status: TBC**

The "MSDN is our best hope" strategy pointed at the **MSDN January 1998** subscription
disc set (in principle official Microsoft CD-ROM media). **But the set we have is `TBC`,
not confirmed clean** (see the Verification-status banner above): it is **incomplete**
(discs 6/7/8/15 missing) and only **integrity-confirmed** against archive.org's own
metadata, never authenticated against an independent Microsoft reference. Surveyed cheaply
via ISO9660 path-table range-reads before downloading; the operator is acquiring the full
set locally (not git). Discs relevant to Phase 6:

| Disc (part #) | Title | Holds | Relevance |
|---|---|---|---|
| 1 (the "Greek" item) | International 16-bit OS collection | MS-DOS 6.0/6.22/5, Win 3.1, **Win 3.11**, **WfW 3.11** across ~20 locales (incl. **Japanese/Korean/SimpChin DBCS**) | OS media + DBCS substrates; vendored, integrity ✓ / **auth-TBC** |
| 2 (X03-54208) | 16-bit SDKs and Tools | **Win32s** (`/WIN32S`, 3-disk installer) + **Far East DBCS Win32s** (`/WIN32S/FAREAST`, JPN/KOR/CHN/TWN); OLE, ODBC, TAPI16, VFW; WfW311/Win31; NT 3.51 SP5 (Danish) | **the Win32s source**; vendored, integrity ✓ / **auth-TBC** |
| 3 (X03-54209) | 16-bit DDKs | VISUALC (16-bit) + WIN31 driver kits | not needed (we don't build drivers) |
| 4 (X03-54210) | Windows NT Workstation 3.51 (U.S.) + SP5 | NT 3.51 CHECKED/FREE builds, hotfixes | optional — NT 3.51 peer tier (earliest native Win32) |
| 5 (X03-54211) | Win32 SDK (Win95 + NT 3.51) + NT 3.51 ResKit | the Win32 SDK; **another Win32s** (`…/WIN32S/DISKS/RETAIL/{WIN32S,OLE32S}`) | NT 3.51 dev refs; second Win32s copy |

**Win32s version finding (decision needed).** The MSDN-set Win32s is **1.30c**
(`WIN32S/README.TXT`: *"February '96 Win32s 1.30c … the last release of the Win32 SDK
that will have Win32s … The DBCS versions (Japanese and Fareast) are part of this
release"*) — i.e. the **final, most-capable** Win32s, **not** the **1.25a** named as the
device's baseline floor. Options: (a) test on **1.30c** (official, easy, includes DBCS —
verifies the *upper* end); (b) **also** source **1.25a** to verify the named *floor*;
(c) make 1.25a primary. The device only *uses* the 1.25a API subset, so 1.30c (a
superset) is a valid run — but a strict floor check wants 1.25a. **RESOLVED 2026-06-11 — both ends now in hand**, so Phase 6 can verify the
strict **floor** *and* the **ceiling**: Win32s **1.25a** (build `1.25.142.0`, Microsoft
PSS Application Note **PW1118** "Win32s Upgrade", rev 5/95) sourced from **WinWorld**
(`win32s-1.25a-1.25.142.0.7z`, 986,626 B, sha256
`72b6f7a1f87e23c2d588da2b9a23eb9f99daadb4e858ec972835cd33b6ae8523`; real redist —
`W32SKRNL/W32SYS/W32SCOMB/WIN32S16.DL_`, the `W32S.386` VxD, `32SINST.INF`, FreeCell;
WinWorld preservation provenance, README is the genuine Microsoft PW1118 note); Win32s
**1.30c** from the official MSDN disc 2. Plan: install on **1.25a** as the baseline floor
pass and (optionally) **1.30c** as the superset pass. (Rejected source, 2026-06-11: a local
`Microsoft Win32s Software Development Ki.rar` was offered — but it is a **scene/warez
release** (`WIN32/SODOM/` dir + `SODOM.NFO` at the root) of the **1996 Win32 SDK**
docs/samples, not an official Win32s 1.25a redist. Fails the "nothing unofficial" bar and
is redundant with the official MSDN disc 2 (1.30c) / disc 5 (Win32 SDK); not used. A 1.25a
floor, if wanted, must come from an official source.)

### Full-set acquisition manifest (replication record)

The complete MSDN Platform Archive **January 1998** set is being mirrored locally (gitignored
`vendor/win311/msdn_jan1998/`; **never committed**). Disc 1 was confirmed identical
(md5 `d1aac83b…`) to the earlier `16-BIT.ISO` pull, so it is already local. **All "local"
rows below are integrity-confirmed only (md5 = archive metadata) — authenticity is `TBC`**
(community uploads, no independent authority; set incomplete). Status:

| Disc | Part | ISO | md5 | Status |
|---|---|---|---|---|
| 1 | X03-54207 | `1_16-BIT.iso` (523 MB) | `d1aac83b8febbb8b80bf5ea41f0506b0` | local (integrity ✓, **auth-TBC**) (= `msdn_intl/16-BIT.ISO`) |
| 2 | X03-54208 | `1_16-BIT_TOOLS.iso` (545 MB) | `75f36f715055f52671dfa426ec5a9481` | local (integrity ✓, **auth-TBC**) (`msdn_disc2/`) |
| 3 | X03-54209 | `1_WIN31_DDKS.iso` (585 MB) | `f9f4432860352367182059e6d652cc30` | fetching |
| 4 | X03-54210 | `1_WINNT351_WKS.iso` (612 MB) | `aaa7d6d32076a8bd4be5e208c74bf461` | fetching |
| 5 | X03-54211 | `1_WIN32_SDK.iso` (614 MB) | `3fbe9711c7d7d5f6afb588e84cd5a519` | fetching |
| **6** | **unconfirmed** | — | — | **GAP — not on archive.org; part # NOT known (see caution)** |
| **7** | **unconfirmed** | — | — | **GAP — not on archive.org; part # NOT known (see caution)** |
| **8** | **unconfirmed** | — | — | **GAP — not on archive.org; part # NOT known (see caution)** |
| 9 | X03-54215 | `1_NT351WKS_ES_IT.iso` (603 MB) | `0c6c18c3dae6192a57420a898ecafdc2` | fetching |
| 10 | X03-54216 | `1_NT351WKS_NL_SV.iso` (588 MB) | `828cd2b6ee51dae90e406b3e932c42ac` | fetching |
| 11 | X03-54217 | `1_NT351WKS_FI_NO.iso` (577 MB) | `7f3604fca7e1887cb9ed0b0d45852b7b` | fetching |
| 12 | X03-54218 | `1_NT351WKS_DA_PT.iso` (592 MB) | `3f6f02d7733fde5ad1e28eb93f565814` | fetching |
| 13 | X03-54219 | `1_NT351WKS_DE_KO.iso` (597 MB) | `501e9a9be10f6b3d4958d918198d2953` | fetching |
| 14 | X03-54220 | `1_NT351WKS_JA_SP5.iso` (561 MB) | `4519a4ca19d0b10158a985220180d76f` | fetching (**Japanese NT — DBCS-on-NT**) |
| **15** | **unconfirmed** | — | — | **GAP — not on archive.org; part # NOT known (see caution)** |
| 16 | X03-54222 | `1_NT351WKS_FR_SP5.iso` (609 MB) | `e0fb9815b233a4374c46dd6aedc314fb` | fetching |

Notes: discs **9–16** are NT 3.51 Workstation language localisations (only **14/Japanese** is
Phase-6-relevant, for DBCS-on-NT; the European ones are archival completeness).

**CAUTION — the gap discs (6/7/8/15) part numbers are NOT known.** Earlier this file
extrapolated them from the rule `part = X03-(54206 + disc#)`, which fits all **11**
confirmed discs exactly. That was a plausible-but-unverified inference and is **retracted**:
the operator found **X03-54212** (the rule's predicted disc-6) referencing a **1996**
product, and an archive.org search for the four predicted numbers returns only unrelated
noise. The most likely reconciliation (operator hypothesis): MSDN Platform Archive shipped
**quarterly**, and discs **unchanged** since an earlier release were re-pressed **as-is**,
keeping their **original older part number and date** — so the Jan-1998 set physically
includes discs stamped 1996/97, and the gap discs' real numbers are not in the contiguous
Jan-1998 block. Confirm the gap discs' true part numbers *and*
contents from a primary source (the set's own index/disc-1 catalog, a redump.org set
manifest, or the physical disc labels) — do not record extrapolated numbers as fact. (A
small instance of the project's cornerstone: a rule that fits every visible data point is
still a claim, not a verified artifact, the moment it is extended past its evidence.)

**Primary-source evidence (2026-06-11 research — the hypothesis is confirmed).** The
Computer History Museum catalog record for an MSDN 1998 subscription
([CHM 102788150](https://www.computerhistory.org/collections/catalog/102788150)) lists a
single set's DDK discs with their actual part numbers *and* dates, and they are
**mixed-vintage**: Win95 Far East DDK **X03-54113 / July 1996**, Windows NT DDK
**X03-54115 / January 1997**, Windows NT 4.0 HCT **X03-54121 / August 1996**, NT WKS 4.0
HCT (Japanese) **X03-54123 / January 1998** — i.e. one MSDN set **bundles discs pressed
across 1996–1998, each retaining its own original SKU and date**. This is direct
confirmation of the carried-over-disc hypothesis, and **X03-54113 = a July-1996 disc** in
the same X03-541xx band proves an X03-54xxx number here can map to 1996 (mirroring the
operator's X03-54212→1996 finding). Conclusion: the Platform-Archive SKUs are
**per-disc-when-pressed, not contiguous-by-position**, so the `54206+N` extrapolation is
definitively unsafe; the gap discs (likely the Win95/OSR2/Win95-DDK-era media carried
over from 1996–97) keep their own older numbers. The *general practice* is now
primary-sourced; the **specific** gap-disc identities still require the actual discs or a
redump.org set entry (BetaArchive's MSDN wiki + the contemporaneous Usenet disc-list posts
on `microsoft.public.win98`/`alt.windows98` corroborate but are Cloudflare/JS-walled to
automated fetch — read them in a browser to finish the confirmation).

The separate MSDN **Library** (docs) and **NT Server 4.0** disc are a different
product line, out of scope for the *run* tiers — but the **Library disc 1 carries the
"MSDN CD Index"**, the authoritative set catalog that would resolve the gap discs (6/7/8/15)
with certainty. **1998 MSDN Library (English) — official-hash manifest** (operator-supplied; the `SW_CD_…`
names are Microsoft's official download-repository form, so these are clean primary-source
hash anchors). The Library's **disc 1 carries the MSDN CD Index** — the authoritative set
catalog that resolves the gap discs. Fetching these needs the source-catalog download URL
(SW_CD EXEs live on the MS CDN); recorded here as the verification anchor regardless:

| File | Part | Size (B) | md5 | sha256 |
|---|---|---|---|---|
| `…Library_98_English_1…X03-86022.EXE` | X03-86022 | 254,724,304 | `3645f702458e0e9de95257787c08a774` | `b5eb4983dd1d41c577655e21fee8367d8e0903fdfee3057b69de988fd65c5762` |
| `…Library_98_English_2…X03-86026.EXE` | X03-86026 | 563,864,648 | `13da56d41d7a4b5441693723fe2b092e` | `b2379d624324938b945f3ae042ea3f2e474d06aa95e0d3ec6759be70ba4e1e94` |

Every fetched Platform-Archive ISO is md5-checked against the disc table above on download;
local sha256 appended to `SHA256SUMS`.

**NT as a peer of Win32s (operator observation).** Correct — Win32 originated on
**Windows NT** (NT 3.1, 1993); **Win32s is the *subset* back-ported onto 16-bit Windows
3.1**, so "the first Win32" is NT's native Win32 and Win32s is the stand-in below it. The
device already treats NT as a **first-class peer, not via Win32s**: the `is_nt` path uses
native Win32 directly — the `process` memory tier (RPM/WPM), the `utf8_via_w` wide-API
encoding tier, job objects, threads, ctrl-events. In the mandatory matrix **XP** is the
NT-era representative. Discs 4+5 make an **NT 3.51** peer tier *available* (the earliest
practical native-Win32 target — it would exercise the NT-3.x wide-API floor that 5.4
flagged as "NT 3.1+ but compat unproven"); recorded as an **optional add**, not a
mandatory tier.

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
- **6.2 Windows 3.11 + Win32s 1.25a (QEMU, fresh scripted install)**: build a clean,
  reproducible guest from verified official media (no prebuilt VM — the OVA was
  rejected). Steps: install QEMU; create a blank qcow2; **scripted install of MS-DOS
  6.22** (boot the verified DOS media, partition/format/`sys` C:, copy the DOS tree);
  **unattended Windows 3.11 install** driving `SETUP /B` with a `SETUP.SHH` answer
  file; **apply Win32s 1.25a** (source + verify first); boot headless under QEMU with
  `-serial tcp:…` redirect; deploy the 8.3 bundle; device on `/SERIAL:COM1`; matrix
  assert; `exec` `command.com /c dir` through the **polling/GetExitCodeProcess path**;
  on-target tests where runnable. The whole build is captured as a committed,
  re-runnable script (the harness's "make the 6.2 guest" target). **Stretch**:
  TCP/IP-32 add-on for the Winsock transport (needs WfW 3.11 media — the Greek
  collection or another WfW source, verified).
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
