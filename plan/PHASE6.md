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

  **Build status (2026-06-11) — tooling done, install pending operator.** The build
  tooling is committed under `tools/phase6-qemu/` (`build.sh`, `make-installdisk.sh`,
  `run.sh`, `run-win.bat`, `mon.sh`, `README.md`). `build.sh` deterministically stages
  (gitignored `vendor/win311/build/`): the bootable **DOS 6.22** floppy (El Torito from
  the bundle ISO), a 500 MB **C:** with a pre-created bootable FAT16 primary (unformatted),
  and a 33 MB **D:** install disk (`install-d.img` — `WIN311\` merged SETUP tree +
  `W32S\` Win32s 1.25a), all verified with `mtools`. **Win32s = 1.25a floor** for this
  build (1.30c ceiling pass is a later option). **Hard environment constraint discovered:
  QEMU cannot run in the WSL2 agent sandbox** — it is reaped after a few seconds
  (SIGUSR1 → exit 144; sub-5 s only, less than a DOS boot). So prep + verification run on
  this side via `mtools` (no running VM), and the **interactive GUI install is driven by
  the operator on the Windows host** (`run-win.bat`, native display) — the operator
  offered to drive. Repeatability: drive once → `hdd.img` is the hash-pinned base; then
  capture the installed `C:` tree (mtools) so rebuilds are scripted. Operator checklist is
  in `tools/phase6-qemu/README.md`: `FORMAT C: /S` → `D:\WIN311\SETUP` (Express) →
  `D:\W32S\SETUP.EXE` (FreeCell = Win32s smoke). After install, this side verifies the
  `device=*w32s.386` line in `SYSTEM.INI` and pins the image.

  **✅ GUEST BUILT + Win32s VERIFIED (2026-06-11).** The Win32s/Win16 baseline tier guest
  is installed and Win32s 1.25a is **confirmed working**. Driven end-to-end **from the
  agent side** via the QEMU monitor (`sendkey`/`screendump`) over the host's *mirrored*
  localhost (operator only launched `run-win.bat`; no per-step mousing). Sequence executed
  and screenshotted: boot genuine MS-DOS 6.22 → `FORMAT C: /S` → `FDISK /MBR` (sfdisk
  writes the partition table but no MBR bootstrap — added to the procedure) → boot C: =
  genuine **MS-DOS 6.22** → `D:\WIN311\SETUP` Express → genuine **Windows 3.11** → reboot →
  `WIN` → Program Manager → `D:\W32S\SETUP.EXE` → genuine **Win32s 1.25a** installed
  (`C:\WINDOWS\SYSTEM` + `WIN32S`, FreeCell to `C:\WIN32APP\FREECELL`) → restart → **FreeCell
  launches and renders** = the official Win32s smoke test **PASSES**. All media genuine
  Microsoft (the unofficial "Looka" boot floppy was replaced with WinWorld MS-DOS 6.22;
  its `COMMAND.COM` is byte-identical to the bundle's, confirming the bundle binaries were
  genuine). Known follow-up: `SHARE.EXE` is not yet loaded (Win32s setup warned but
  proceeded; FreeCell ran anyway) — add genuine `SHARE.EXE` to `AUTOEXEC.BAT` before the
  device runtime test (Win32s file-locking). Next: clean-shutdown + pin `hdd.img` sha256 +
  capture the installed `C:` tree (repeatable rebuild), then deploy `mcp-w32s.exe` and run
  the wire harness against COM1 (`127.0.0.1:31800`).

  **🔴 6.2 FINDING #1 — the device does not load on bare Win32s 1.25a (`MSVCRT.DLL`
  missing).** Deployed `mcp-w32s.exe` (CI's MinGW-w64 build) to the verified guest and ran
  it from Program Manager; Windows refused it with **"Cannot find MSVCRT.DLL"**. Confirmed
  by `objdump -p`: the device imports `KERNEL32.dll`, `USER32.dll`, **`msvcrt.dll`** — but
  **Win32s 1.25a ships `CRTDLL.DLL`, not `msvcrt.dll`** (it's in the Win32s redist as
  `Setup/CRTDLL.DL_`). The MinGW toolchain links the C runtime to `msvcrt.dll` implicitly
  (the device's own `target_link_libraries` is just `kernel32 user32`, but the CRT pulls
  `msvcrt`). **This is a CI-parity blind spot of exactly the class Phase 6 exists to catch:**
  CI runs the PEs under **Wine, which provides `msvcrt.dll`**, so every prior green run
  masked it; real Win32s 1.25a does not. The device's "single .exe runs on bare Win32s
  1.25a" premise is therefore **not yet met as built**. Resolution needs a decision
  (deferred to instructions): (a) build the device against **`CRTDLL.DLL`** (the Win32-SDK
  CRT that Win32s provides — a `vc6-nmake` toolchain already exists in `toolchains/` but VC6
  also links `msvcrt`, so this needs the older Win32 SDK CRT or an `-lcrtdll`-style MinGW
  variant); (b) **statically link** the CRT so no external runtime is needed; (c) **bundle**
  a Win32s-compatible (period ~1995) `MSVCRT.DLL` redistributable (2-file deploy, and its
  own Win32s compatibility is unverified). The environment + Win32s are proven good
  (FreeCell ran); this is purely the device's runtime-link target. The baseline guest is
  pinned regardless so re-testing a fixed build is one deploy away.

  **Baseline PINNED (2026-06-11).** Clean-shutdown image preserved at
  `vendor/win311/build/baseline/win32s-125a-baseline.img` (gitignored), sha256
  `edcd749716861157cc0c6aae12046c30fd04d6c5692e2ae0c7a8141d23016179` (in `SHA256SUMS`).
  mtools-verified: `C:\WINDOWS\SYSTEM.INI` carries `device=C:\WINDOWS\SYSTEM\WIN32S\W32S.386`
  (Win32s loaded), `C:\WIN32APP\FREECELL` present. **6.2 status: environment ✅ complete +
  verified; device acceptance BLOCKED on Finding #1 (msvcrt.dll) pending a CRT-link
  decision.** To resume after a fixed device build: `run-win.bat hdd`, insert the deploy
  floppy, run the device, connect the wire harness at `127.0.0.1:31800` (the driving tooling
  — `run-win.bat`/`mon-win.sh` — is committed and proven).

  **🟢 FINDING #1 FIXED at the source (branch `claude/win32s-mini-crt`, 2026-06-11).** Root
  cause: MinGW links the C runtime to `msvcrt.dll`; Win32s has none. Fix = a freestanding
  **C89 minimal CRT** (`src/mini_crt.c`): custom `mainCRTStartup` = `ExitProcess(main())`
  (main() is `int main(void)`, reads `GetCommandLineA()` itself), `__main` stub, and thin
  Win32-backed shims (`malloc/calloc/free`→HeapAlloc; `memset/memcpy/memmove/memcmp`;
  `strcmp/strncmp/strlen`; `exit/abort`→ExitProcess). MinGW build links `-nostdlib` + libgcc;
  **imports collapse to `{kernel32,user32}`** (ImageBase 0x10000, .reloc kept, i386-clean).
  The device's whole CRT surface was tiny (no stdio — formatting is `wsprintfA`/`lstr*`).
  Tests + VC6 path untouched. Also added: the **exhaustive import-allowlist CI assertion**
  (catches this class statically on the Ubuntu runner, where Wine can't) and a **real-Windows
  CI job** (MSYS2; runs exec/Winsock/ConPTY without Wine — currently non-blocking, stuck on
  an MSYS2 windres quirk). **Gates passed:** observed CI green on the required jobs
  (build-and-test/bridge/conformance); independent adversarial **review = APPROVE** (the
  reviewer rebuilt + brute-tested every shim against libc semantics — no defect). Remaining
  to fully close: (1) on-Win32s re-deploy — confirm the fixed device *loads* on the pinned
  guest (needs the VM relaunched); (2) merge the branch (submodule bump) once the on-target
  confirmation is in hand; (3) stabilise or shelve the real-Windows CI job.

  **🟢 FINDING #2 FIXED + DEVICE LOADS & RUNS ON Win32s (branch `claude/win32s-mini-crt`,
  2026-06-11).** With Finding #1 fixed, the re-deployed device cleared the MSVCRT error and
  surfaced **Finding #2: `GetFileSizeEx` is absent from the Win32s 1.25a thunk**
  (`w32scomb.dll`) — the loader reported "the procedure entry point GetFileSizeEx could not be
  located in w32scomb.dll". Same CI-parity blind spot class: `GetFileSizeEx` lives *in*
  `kernel32.dll` (so the DLL-level import allowlist passed it) and Wine provides it, so CI was
  green. Root cause: one use in `FileOpRead` (`src/file_ops.c:137`). **Fix:** swap to
  `GetFileSize` (exported by the thunk; sufficient — reads are buffer-bounded, far under the
  16 MB cap), error-checked per its `INVALID_FILE_SIZE` + `GetLastError()!=NO_ERROR` contract.
  Behaviour-preserving (only `fileSize.LowPart` was ever used); `test_file_ops` 26/26 green
  under Wine (commit `c1ba1ef`).

  **Deeper audit (operator request "do a deeper audit for missing APIs").** Extracted all three
  Win32s 1.25a thunk DLLs (`W32SCOMB`/`W32SKRNL`/`W32SYS`, **2221** exported functions) from the
  pinned baseline and diffed the device's **58** static imports against them — after the
  `GetFileSize` swap, **every one of the 58 is in the Win32s 1.25a export set (zero missing).**
  Institutionalised as a **function-level CI guard** (commit `a791b73`):
  `tools/win32s-import-allowlist.txt` (the exhaustive 58 the device may import, each verified
  against the thunk) + a CI step asserting the binary's actual imports equal it exactly. Any new
  static import now fails CI until added — i.e. forces the per-symbol Win32s check that
  `GetFileSizeEx` slipped past. (The DLL-level kernel32+user32 allowlist was necessary but not
  sufficient — this is its function-level twin.)

  **ON-Win32s CONFIRMATION ✅ (2026-06-11, pinned guest via `run-win.bat hdd` + QEMU monitor):**
  the fixed device **loads and runs on real Win32s 1.25a** — no missing-entry-point, no MSVCRT,
  no `GetFileSizeEx` dialog. It executes the full device startup (`FeatInit` → catalog load →
  exec gate → toolchain probe → backend register) and reaches `TransportOpen`, where it emits
  its *own* diagnostic **"failed to open serial port"** (MessageBoxA) — proof real device code
  is running, not just loading. **Both loadability findings (#1 msvcrt, #2 GetFileSizeEx) are
  closed and verified live.** Screenshot: `vendor/win311/build/shots/redeploy-02-launched.png`.

  **OPEN — serial transport on Win32s (next step; possible Finding #3).** The device defaults to
  serial COM1 (`CreateFileA("COM1", GENERIC_READ|GENERIC_WRITE, …)`, `serial.c:63`; default set
  in `transport.c:163`) and the open fails on the guest. Win32s 1.25a *exports*
  `CreateFileA`/`SetCommState`/`SetCommTimeouts` (all allowlisted), so it intends to support
  Win32 serial — the failure is a fresh boundary, **not** a loadability defect: either
  environmental (guest COM1 config / QEMU `-serial tcp:…,server,nowait` with no client) or a
  genuine Win32s serial limitation needing a different open path (the 16-bit `COM1:` device-name
  form, or `OpenComm`). Bare Win 3.11 has no Winsock, so `/TCP` is out until the TCP/IP-32
  stretch — serial is the only wire transport on this tier, so this gates full wire conformance.
  **This is the session pause point:** the loadability goal ("device loads + runs on Win32s") is
  met; whether to chase the serial transport now (full conformance) or merge the loadability
  fixes first is the operator's call.

  **Merge readiness.** Branch `claude/win32s-mini-crt` = Finding #1 (mini CRT, reviewed APPROVE)
  + Finding #2 (`GetFileSize`) + the function-allowlist CI guard. Before merge: the GetFileSize
  change is behaviour-preserving (no spec change; weed re-run trivial); observed CI on the new
  commits must be green (run `27363257401` on `a791b73`); the **review gate must re-run over the
  new commits** (the prior APPROVE covered only the mini-CRT commits); merge needs explicit
  authorization (irreversible) + the submodule bump. Held here per the pause directive.
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

✅ 6.2 device LOADS + RUNS on Win32s 1.25a — 2026-06-11 (Findings #1 msvcrt + #2 GetFileSizeEx both fixed & confirmed live on the pinned guest; deeper-audit clean — all 58 imports in the 2221-fn thunk export set; function-allowlist CI guard added. Branch claude/win32s-mini-crt @ a791b73 pushed. OPEN: serial transport on Win32s — pause point.)

✅ 6.2 serial WIRE proven on Win32s via DIRECT UART (Finding #3 root-caused; operator-consented spike) — 2026-06-11. The 0-bytes serial result is **NOT** a Win32s limitation — it was the stubbed Win32 comm API (`SetCommState` → err 120 `ERROR_CALL_NOT_IMPLEMENTED`). A throwaway CRT-free probe (`tools/phase6-qemu/uart-probe.c` → `UARTPROB.EXE`) that drives the 16550 by **direct ring-3 port I/O** (`IN`/`OUT` 0x3F8–0x3FF) and **never opens COM1 via CreateFile/OpenComm** (so COMM.DRV stays passive — nothing to contend with) proved live on the pinned guest: **(1)** bare ring-3 `IN`/`OUT` is **granted** — no `#GP`, VCD passes it through (scratch reg `AA`/`55` round-trip, app did not fault); **(2)** TX works — host `nc` captured `UARTPROBE-TX\r\n` off COM1's QEMU TCP, no comm stack in the path; **(3)** RX works — guest polled-read 17 bytes `HELLO-FROM-HOST\r\n` from the host. Full duplex, clean `ExitProcess`. Screenshots `vendor/win311/build/shots/box{1..4}.png`; on-guest log `C:\UARTPROB.LOG`. **Implication:** direct-UART (option D) **supersedes deferred-option-A** (16-bit Universal Thunk) — cleaner, needs no Win16 toolchain, keeps the single-binary/zero-dep/C89 constraints. Operator **expressly consented** to detecting/reprogramming the UART directly (David, 2026-06-11). Boundary: bare ring-3 `OUT` only — **no VxD, no IOPL flip, no call gate, no IRQ hook** (polled, exclusive ownership) — keeps it inside the project security posture ("use what the OS grants ring-3; never escalate"); to be pinned by an invariant when this becomes device code. **NOT yet implemented in the device** — architectural decision (implement now vs. record-and-defer + merge loadability fixes first) pending.

✅ 6.2 loadability fixes MERGED — 2026-06-11 (PR #17 squash `9809aab`; host pointer bump `117bfee`). Findings #1 (msvcrt → freestanding mini-CRT) + #2 (GetFileSizeEx → GetFileSize) + the function-level import-allowlist CI guard. **Merge gate clean:** independent adversarial **review APPROVE**-with-nits (0 blocker / 0 should-fix / 0 nit — the reviewer independently rebuilt the exe, re-derived imports == `{kernel32,user32}` incl. the libgcc helpers being i386-clean, disassembled the mini-CRT shims confirming no self-recursive `memcpy`, ran `test_file_ops` 26/26, and **injected a fake `GetFileSizeEx` import to prove the allowlist gate fails on drift**); **weed ZERO** spec↔code drift; **observed CI green** (`build-and-test` + `conformance` + `bridge`; `real-Windows` non-blocking `continue-on-error`, overall run conclusion success). Three non-blocking **observations** recorded + dispositioned: **(Obs-1)** the `real-Windows` (windows-native MSYS2) job is red — incomplete windres-spawn fix; non-blocking by design, tracked as a **separate CI-stabilisation** item (not a defect in this change). **(Obs-2)** `fileSize.HighPart = 0` written-not-read — cosmetic, keeps the diff minimal; left as-is. **(Obs-3)** `mini_crt.c` built without `-ffreestanding`/`-fno-builtin` — verified i386-clean + non-recursive on GCC 10, defence-in-depth vs a future GCC. **Obs-3 + the weed `awk` ordinal-import fail-closed hardening both fold into #37**, which already touches `CMakeLists.txt` (build) and the import-guard CI. Serial spike held in `stash@{0}` for #37; the SetCommState-tolerance is superseded by direct-UART. (Task #36 → complete.)

✅ 6.2 #37 direct-UART backend — PLANNING PAUSE complete + lifecycle opened — 2026-06-11 (branch `claude/win32s-uart`). Settled by Q&A: **tier-aware /SERIAL** (the existing serial backend gains a Win32s-only internal route; transport kind/name stay `serial`, so the harness matrix checker + bridge are unchanged) · **Win32s-only** (direct ring-3 IN/OUT reached **iff `is_win32s`** — bare OUT `#GP`s on NT at IOPL 0 — gated as the FIRST line of `SerialBackendOpen`, the sole selector, holding even through `/AUTO`'s re-entrant fallback) · **full robust detection ladder now** (IER store-test → FIFO **iff IIR&0xC0==0xC0** → scratch 8250/16450 split → loopback self-test fail-closed → divisor read-back → ≤detected-FIFO-depth bursts → LSR-before-RBR error decode). Decomposition mirrors 5.3 mem_ops: pure ladder/driving over an injected `UartPortIo` seam, host-tested (theft 50k + ASan) against a **simulated-16550 transcribed from the proven spike**, behind a `#ifndef UART_HOST_PURE` wall; the x86 `inb`/`outb` asm + `UartBackendOpenDirect` compile target-only (double-guarded `#if defined(__i386__)||defined(_M_IX86)`). Six backing security invariants pinned in a NEW `specs/uart.allium`: serving-via-UART⇒is_win32s; bare-port-I/O-only (no VxD/IOPL/call-gate/IRQ-hook); IER=0∧OUT2=0 while live; FIFO⇒16550A; UART owned exclusively (COM1 never CreateFile/OpenComm-opened); every open/TX loop bounded — steady-state RX is the one yielding exception (an idle serial line is a live session). Reuses `stash@{0}` /BAUD (drops the superseded SetCommState-tolerance). Folds in PR-#17 dispositions (mini_crt `-ffreestanding -fno-builtin`; import-guard awk fail-closed on ordinal imports). Lifecycle now at **tend** — no implementation code until `specs/uart.allium` is `allium check`-clean and obligations propagated.

➕ 6.2 #37 verification add (operator directive 2026-06-11): **smoke-test DEGRADED UART hardware paths on QEMU too**, after the code is built — exercise the detection-ladder downgrade branches (8250/16450 no-FIFO → tx_chunk=1; broken non-A 16550 IIR=0x80 → FIFO refused; dead-clone loopback-fail → open fails-closed) against emulated hardware, not only the host fake. **Feasibility caveat:** QEMU's `-serial`/isa-serial models a 16550A always (no stock knob for an older/broken UART), so this needs investigation at verification time — QEMU device options, a small QEMU patch (force FIFO off / spoof IIR), or a secondary emulator (86Box selects UART types). The host simulated-16550 remains the **exhaustive** degraded-logic coverage; the QEMU degraded run is the real-hardware-fidelity stretch. Tracked as **task #39** (blocked by #37).

✅ 6.2 #37 tend — 2026-06-11 (branch `claude/win32s-uart` @ 1501f43). New `specs/uart.allium`: a `UartChip` detection-ladder lifecycle (`detecting → loopback_pending → live`; either detection state `→ open_failed` fail-closed; `live → closed`) plus the **six backing security/safety invariants** — 3 expression-bearing (`ServingViaUartImpliesWin32s` the tier gate; `NoInterruptPathArmed` = IER=0 ∧ OUT2-clear while live; `FifoEnabledImpliesDetected16550A`), 3 prose-discipline (`BarePortIoNoEscalation`, `UartOwnedExclusively`, `EveryPollLoopBounded` with steady-state RX as the sole yielding exception). The one load-bearing detection rule pins FIFO-enabled **iff** the chip is a positively-detected 16550A. One clarifying note added to `serial.allium` (Win32s-route open failure is terminal — no COMM.DRV degrade). `allium check`: 0 errors / 0 warnings (1 info `base_port`, parity with serial's `baud_rate`); `allium analyse`: 0 findings. Next: **propagate**.

✅ 6.2 #37 propagate — 2026-06-11 (branch `claude/win32s-uart` @ 4439e66). `tests/OBLIGATIONS-6.2.md`: **37 structural obligations** (`allium plan specs/uart.allium`, all new) + the **3 prose-discipline invariants** (no structural ID — `BarePortIoNoEscalation`, `UartOwnedExclusively`, `EveryPollLoopBounded`) traced to concrete tests + static CI checks + the weed gate-bypass audit. Each mapped to: **theft host PBT** (simulated 16550, transcribed from the spike), **`prop.h` on-target mirror**, and the **`test_serial.c` dispatch gate** (via `UartLastRouteForTest()`, no real port I/O). CI-parity boundary pinned: the asm `IN`/`OUT` is verified live on the pinned Win32s guest (the #35 acceptance), **never on Wine**; degraded-chip runs are the QEMU stretch (#39). Floor: ≥7 theft + ≥7 on-target + ≥2 dispatch units + the static checks. Next: **implement** (freeze `src/uart.h` first, then fan out).

✅ 6.2 #37 implement — DONE (branch `claude/win32s-uart` @ daf84ac, pushed). Interface frozen first (`src/uart.h` @ bea05ce + the `UartLastRouteForTest` route-probe decl @ 2892e6b), then a two-wave pipeline (the genuine dep graph: B's tests link A's `uart.c` + the dispatch seam, so "parallel A+B" was unverifiable — sequenced A → main-session seam → B, each independently re-verified by the orchestrator).
  **Wave 1 (sub-agent A, @ 85eaf45):** `src/uart.c` pure ladder (8 functions over the injected `UartPortIo`), `tests/uart_sim.h` (a strict-C89 simulated 16550 transcribed from the spike — shared by host theft + on-target prop), `tests/host/theft_uart.c` (9 properties, 50k trials, ASan/UBSan). **A surfaced + resolved a contradiction** between the task prose ("scratch as presence probe") and the frozen header (IER store-test): the theft run *refuted* scratch-as-presence (a real 8250 has no scratch → false-rejects), so the code follows the header. **Orchestrator verification found a real defect by READING** (not by the green suite): `UartRxDrain` could return 0 when a poll pass consumed only a line break (BI without framing error) — which the transport contract reads as a peer-close a serial line cannot have. Fixed (keeps waiting → returns >0/<0, never 0) + pinned by a new `rx_break_never_zero` property that **refuted the original 24509/50000 trials** (red→green demonstrated). The 16-byte FIFO depth, BI+FE→<0 decode, and loopback-MSR (RTS→CTS, OUT2 stays clear) calls were judgement-recorded.
  **Main-session seam (the security-critical, non-delegated part):** the `uart.c` `#ifndef UART_HOST_PURE` real backend — the x86 `inb`/`outb` asm (double-guarded `#if defined(__i386__)||defined(_M_IX86)`, GNU/MSVC/`#error`), `Sleep(0)` cooperative yield, the `uart_read`/`uart_write`/`uart_close` vtable, `UartTierWantsDirect()` (returns `g_features.is_win32s`, no I/O) and `UartBackendOpenDirect()` (terminal open, no COMM.DRV degrade); the one-line tier-gate dispatch + `UartLastRouteForTest` dry-run probe in `serial.c`; `uart.c` into `CORE_SOURCES`; the `build.sh host-pbt` theft_uart line.
  **Wave 2 (sub-agent B, @ daf84ac):** `tests/test_uart.c` (the 9 theft properties mirrored on-target via `prop.h`, `-DUART_HOST_PURE`, 1500 trials) + 3 `test_serial.c` dispatch-gate tests pinning SECURITY PIN #1 (`UartTierWantsDirect()==tier`; `SerialBackendOpen` selects direct ⇔ `is_win32s`, read via the probe, **no real port I/O**) + the `test_uart` CMake target.
  **Verification (orchestrator-run, independent):** theft 9/9 @ 50k green; `test_uart` 9/9 green; the 3 dispatch tests green; **strict-flags integrated build clean** (`-std=c90 -pedantic -Werror -march=i386` — the asm survives); **import table = `{kernel32,user32}` only** (zero new imports); **`uart.c.obj` opcode audit = only `in (%dx),%al` (0xEC) + `out %al,(%dx)` (0xEE), nothing escalating** (SECURITY PIN #2 at the object level). No regression: the 7 `exec_*`/`ptyexec_*` `test_serial` failures are a **local wine-vs-native divergence** (WSL interop down this session) — **proven** by the unmodified baseline failing the identical 7, and **confirmed** by **observed CI green** on all required jobs (`build-and-test` + `conformance` + `bridge`; `real-Windows` is the known non-blocking MSYS2 job, task #38).

✅ 6.2 #37 distill — verify no-op (2026-06-12). `specs/uart.allium` was authored up front (tend), not reverse-engineered from code, so there is no spec-less module to backfill. `allium check` remains clean.

✅ 6.2 #37 weed — ZERO DRIFT (2026-06-12, dedicated adversarial auditor). `allium check`/`analyse` clean. All six invariants HOLD under adversarial construction — the auditor could NOT build a path that reaches direct port I/O off-Win32s (the `/AUTO` re-entry re-checks the tier; `UartBackendOpenDirect` has one caller, inside the gate), arms an interrupt while live (loopback `MCR_TEST=0x16` excludes OUT2), enables the FIFO on a non-16550A (exact `==0xC0`), opens COM1 via the OS, degrades to COMM.DRV after a failed open, spins an open/TX loop unbounded, or returns 0 from `UartRxDrain`. Transition graph + `.created()` field lists + the `serial.allium` terminal-open note all match the code; scope disciplined. **One observation actioned in-PR:** the simulated 16550 could only emit IIR `0xC0`/`0x00`, so the non-A 16550's `0x80` readback — the false-16550A-positive PIN #4 guards, which `uart.allium` names as the only dangerous detection direction — was never fed to `UartDetect`. Closed by a `UART_SIM_NONA_16550` fake variant + a `nona_16550_no_fifo` property (theft 50k + on-target, @ 4e85f5c) that constructs the `0x80` input directly. Floor now 10 theft + 10 on-target + 3 dispatch.

✅ 6.2 #37 review gate — APPROVE-with-nits (2026-06-12, fresh adversarial sub-agent, read-only). Independently re-ran `allium check`/`analyse` (clean), the strict-flags build (warning-free), objdump (bare IN/OUT, zero escalation/FPU/486, imports `{kernel32,user32}`), theft host-pbt (10/10 @ 50k), `test_uart` (10/10), the 3 dispatch tests (ok). Refuted the base commit too (it fails a SUPERSET of the wine divergences — this change adds none and flips `mem_wire_roundtrip` green). 0 blocker. **1 should-fix, FIXED in-PR (@ 4af7815):** `OBLIGATIONS-6.2.md` named two CI security guards (`no_escalation_opcodes` PIN #2, `no_os_comm_open` PIN #5) that were never added to the workflow — the properties held by construction but the claimed automated enforcement did not exist. Added both: an objdump check that `uart.c.obj` is bare IN/OUT with no ring-0/escalation/software-int/far-transfer op, and an `nm`-on-object check (comment-proof) that `uart.c` references no `CreateFile`/`OpenComm`/`SetCommState`. **1 nit, accepted:** `prop_nona_16550_no_fifo` reuses the `chip_info` generator (≈15k dups, ≈34650 effective trials — ample); recorded, not changed. **Merge gate now: weed clean + review approve (findings fixed) + observed CI green on the final commit** — the human-authorisation + on-target #35 acceptance are the remaining (operator-driven) steps.

✅ 6.2 #37 / #35 ON-TARGET ACCEPTANCE — PASS (2026-06-12, operator-driven, the pinned QEMU Win32s guest). The integrated direct-UART backend wire-responds LIVE on real Win32s — what the throwaway spike proved by hand, now as shipped device code. Deployed `mcp-w32s.exe` (sha `5636374…`, this session's strict build, mtools read-back `cmp`-verified) onto the guest `C:\`; QEMU relaunched (`run-win.bat run`, COM1 → `127.0.0.1:31800`); drove Windows 3.11 startup + `File ▸ Run C:\MCPW32S.EXE /SERIAL:COM1 /BAUD:19200` from WSL over the QEMU monitor (`mon-win.sh`, screendump-verified each step). Wire harness (`tools/phase6-qemu/wire_accept.py`) over the COM1 TCP bridge captured the **full-duplex round-trip**:
  - **ready line (direct-UART TX on open):** `{"status":"ready","codepage":437,"version":"Windows 3.10 (Win32s)","transport":"serial","features":{"is_win32s":true,...,"mem":"shared_vm","encoding":"utf8_from_cp"},"warning":"catalog not loaded"}` — `is_win32s:true` (real Win32s), `transport:"serial"` (the direct route is invisible above the backend, exactly as designed);
  - **command in (direct-UART RX + JSON parse + dispatch):** WSL → TCP 31800 → QEMU 16550 → UART → device received `{"cmd":"echo","id":"acc1","line":"HELLO-WIN32S-UART"}`;
  - **response out (direct-UART TX back):** `{"id":"acc1","status":"ok","data":"HELLO-WIN32S-UART"}` — id echoed, status ok, payload returned.
  The device launched headless under Win32s (console app, no PM window), ran the loopback-self-test + divisor-verify open ladder against QEMU's 16550A, went live, and served the round-trip cleanly (no GPF, no error dialog). **Task #35 (device wire-responding on Win32s) is satisfied by the direct-UART tier.** The merge gate is now fully green end-to-end; only the irreversible squash-merge + submodule-pointer bump await authorisation.

## Out of scope (recorded gaps)

- cp932/DBCS live verification (deferred — Japanese Win98 hardware forthcoming).
- NT 4.0 / 2000 / Vista–8.1 / Win10-1809 as separately-run tiers (XP and Win11 are
  the NT-era and modern representatives).
- CI-automated emulator boots.
- Full OpenAI agent-loop demo (unchanged from 5.5 — optional, user-run, needs a key).
