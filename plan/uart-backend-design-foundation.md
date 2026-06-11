# Direct-UART backend — design foundation (research synthesis)

Foundation for the Win32s direct-UART transport backend (work item **6.2 / task #37**),
proven viable by the `tools/phase6-qemu/uart-probe.c` spike (ring-3 `IN`/`OUT` to the
16550 works on real Win32s; full duplex confirmed). This note consolidates two
primary-source research passes (2026-06-11) into the design spine the `tend`/spec stage
will pin. **It is research input, not yet a spec.**

Provenance: National Semiconductor **AN-493** (*Comparison of the INS8250, NS16450 and
NS16550AF*, Apr 1989) and **AN-491** (*NS16550A Design Considerations*); the **PC16550D**
datasheet; the **Linux `8250`** driver (`drivers/tty/serial/8250/8250_port.c`,
`include/uapi/linux/serial_reg.h`); the **FreeBSD `uart`** ns8250 driver
(`sys/dev/uart/uart_dev_ns8250.c`); **OSDev Serial Ports**; the **Serial Programming**
Wikibook; **helppc**; **Lammert Bies**. Both passes cross-corroborated — where a
secondary source disagreed with a datasheet it is flagged below.

## The governing principle

**Detect, never assume; degrade to correct single-byte polling.** The worst-case chip is
the original **INS8250** (the 1986 Compaq DeskPro 386 is AT-compatible ISA → single-byte
8250/16450 baseline; a FIFO is a bonus you must *prove*). A polled, single-byte, 8N1
driver is correct on **every** chip from the 8250 up; every optimisation above that
(FIFO bursts) must be positively detected first.

**The one load-bearing rule (AN-493 §5.0, primary):** enable the FIFO **iff
`IIR & 0xC0 == 0xC0`**. A `0x80` readback is the original NS16550 (non-A) whose RX FIFO
*"will sometimes transfer extra characters … should NOT be used in the FIFO mode."* A
*false positive* for "16550A" is the only dangerous direction, so require **both** IIR
bits 7 and 6.

## Register map (`base + offset`; COM1 base `0x3F8`)

| Off | Read (DLAB=0) | Write (DLAB=0) | DLAB=1 |
|----|------|------|------|
| +0 | RBR | THR | DLL |
| +1 | IER | IER | DLM |
| +2 | IIR | FCR | — |
| +3 | LCR (bit7=DLAB) | LCR | LCR |
| +4 | MCR (bit4=LOOP) | MCR | MCR |
| +5 | LSR (bit0 DR, bit5 THRE, bit6 TEMT, bits1-4 OE/PE/FE/BI) | — | LSR |
| +6 | MSR (bit4 CTS, bit5 DSR, bit7 DCD) | — | MSR |
| +7 | SCR (absent on INS8250/-B) | SCR | SCR |

Standard bases/IRQs: COM1 `0x3F8`/IRQ4, COM2 `0x2F8`/IRQ3, COM3 `0x3E8`/IRQ4,
COM4 `0x2E8`/IRQ3 (COM3/4 "semistandard"). **IRQs are moot — we poll.**

## Detection ladder (concrete ops)

1. **Presence (IER store-test)** — save IER; write `0x00`→+1, read `&0x0F` expect `0x00`;
   write `0x0F`→+1, read `&0x0F` expect `0x0F`; mismatch → **no port** (a floating ISA
   bus reads `0xFF`). (Linux `autoconfig` step 1.)
2. **FIFO probe** — write `FCR = 0xE7` (enable+clear+64-byte bit), read `IIR & 0xC0`:
   `0xC0` → **16550A** (FIFO usable; `0xE0` with bit5 → 16750); `0x80` → **16550 non-A**
   (FIFO **broken → treat as no-FIFO**); `0x00` → no FIFO → step 3.
3. **Scratch test (8250 vs 16450)** — only to split the no-FIFO group; write **two**
   patterns (`0x55`, then `0xAA`) to +7 with an intervening read of a *different* register
   to defeat bus-float aliasing on clones. **Do not branch behaviour on the result** —
   both are driven identically (single-byte). (Contested: AN-493 says the scratch reg was
   *added* on the 8250A; the Wikibook says the 8250A scratch is broken — irrelevant since
   we don't branch on it.)
4. **(Optional) enhanced parts** — 16650 via EFR (LCR=`0xBF`, write/read EFR); 16C950 via
   ICR ID bytes `16 C9 54`. Not needed for correctness.
5. **Loopback self-test (fail-closed)** — set `MCR` LOOP (bit4); send `0xAE`→THR, poll DR,
   read RBR == `0xAE`; and confirm `MCR`→`MSR` (LOOP|OUT2|RTS gives `MSR & (DCD|CTS)`).
   A dead/clone chip that decodes registers but doesn't truly loop fails here (the
   documented Rockwell-modem guard). Restore MCR after.

## Robust polled driving

- **TX:** poll **LSR THRE (`0x20`)** before writing. Write **1 byte** on 8250/16450; up to
  **16 bytes** in a burst **only on a positively-detected genuine 16550A** (THRE then means
  "FIFO empty"). Use **TEMT (`0x40`)** *only* for a final drain before close/baud-change —
  never as the feed gate (TEMT semantics differ across parts; AN-493).
- **RX:** poll **LSR DR (`0x01`)**. **Read LSR once, decode the error bits from that
  snapshot, *then* read RBR** — reading LSR clears OE/PE/FE/BI, so the order is mandatory
  (the error bits associate with the byte at the FIFO head). Error handling: **OE** (bit1)
  = a byte was lost (count it; current byte still valid); **PE/FE** (bits2/3) = flag suspect
  (in 8N1 they signal a baud/line mismatch); **BI** (bit4) = break, discard the spurious
  `0x00`. Drain the FIFO while DR stays set; **even on app-buffer-full, keep emptying the
  hardware FIFO** so the chip can't wedge.
- **Bounded everything (never spin forever).** Every poll loop has a hard bound: Linux
  `wait_for_lsr` uses ~2 character-times with a 10 ms floor; FreeBSD caps drains at 10240
  (TX) / 40960 (RX) iterations. On expiry → **abort and surface an error**, never retry
  indefinitely. (This is where our cooperative-yield design plugs in — see below.)
- **Clear stale state at open** — read **LSR, RBR, IIR, MSR** (once or twice) so the first
  real poll sees true state. (Linux `serial8250_clear_interrupts`; FreeBSD `ns8250_clrint`.)

## Baud / divisor

`divisor = 115200 / baud` (1.8432 MHz / 16). Program: `LCR=0x80` (DLAB) → `DLL`/`DLM` →
`LCR=0x03` (8N1, DLAB clear). **Read the divisor back** (DLAB=1, compare, clear) to catch a
clone that ignored the write. Table: 9600→12, 19200→6, 38400→3, 115200→1.
**Safe ceiling 9600/19200 for the 8250-era single-byte chips** (one character-time is the
whole window before overrun: ≈1.04 ms @9600, ≈0.52 ms @19200 — comfortable on a 386 doing
other work; 38400+ is not).

## Line / modem control (polled)

`LCR=0x03` (8N1). `IER=0x00` (all interrupts off — the foundation of polling). `FCR`: only
on a confirmed 16550A (`0xC7` = enable+clear+14-byte trigger), else `0x00`. `MCR=0x03`
(**DTR|RTS, OUT2 *clear***) — **OUT2 is the IRQ gate to the 8259; leaving it 0 means a stray
UART interrupt can never reach the PIC.** No hardware flow control for the simplest robust
link (assert DTR+RTS statically); if CTS is honoured, bound the wait (Linux caps at 1 s).

## Concrete OPEN / TX / RX (works from the 8250 up)

**OPEN:** `IER=0` → clear-stale (read LSR,RBR,IIR,MSR ×1-2) → `LCR=0x80`, `DLL/DLM` →
(verify divisor) → `LCR=0x03` → detect (FCR=`0xE7`/IIR; scratch) → FIFO conservatively
(`FCR=0xC7`,`tx_chunk=16` iff 16550A, else `FCR=0`,`tx_chunk=1`) → `MCR=0x03` → (loopback
self-test) → final read LSR,RBR.
**TX chunk:** bounded-wait THRE → write ≤`tx_chunk` bytes to THR → repeat; drain on TEMT
before close.
**RX:** read LSR once; DR clear → return none; decode error bits; read RBR; loop (hard cap)
re-reading LSR while DR set, draining the FIFO.

## What this means for OUR backend (the design decisions for #37)

1. **Polled + exclusive-owner is not a compromise — it *is* the security invariant.** No
   IRQ hook, and with **OUT2=0 we never even wire the UART's interrupt to the PIC**. That
   directly satisfies the pinned boundary: *bare ring-3 port I/O only; no VxD/IOPL/call-gate/
   IRQ-hook; UART owned exclusively (COM1 never opened via the OS)*. The robustness research
   and the security posture point at the **same** design.
2. **Bounded waits become bounded *yields*.** Win 3.11 is cooperatively scheduled, so the
   serve loop cannot busy-spin on DR/THRE — it must pump messages. The driver-grade
   "bounded-timeout" pattern maps onto our cooperative loop directly: replace each
   `udelay(1); --tmout` with "yield to the message pump (PeekMessage/Yield), then re-poll,"
   keeping the same hard bound so a wedged/clone UART fails fast instead of freezing Windows.
   This is the concrete answer to the operator's "we're not cooperatively threading
   correctly" instinct.
3. **Detection at open; single-byte 8250 is the always-correct floor.** Ship the conservative
   path first; FIFO is a detected bonus. Never trust a FIFO not proven `IIR & 0xC0 == 0xC0`.
4. **`/BAUD` (stashed spike) maps to the divisor table** and is reusable; the
   SetCommState-tolerance from that spike is superseded (we don't touch the Win32 comm API).
5. **A backing invariant is required** (project rule for a power-granting capability): pin
   the boundary line above, plus "FIFO enabled ⇒ chip detected as 16550A" and "every poll
   loop is bounded." `weed`'s gate-bypass dimension audits these.

## Sources (primary → secondary)

Primary: NS **AN-493** (bitsavers AN-0493), **AN-491** (bitsavers AN-0491), **PC16550D**
datasheet; **Linux** `8250_port.c` + `serial_reg.h`; **FreeBSD** `uart_dev_ns8250.c`;
**Compaq DeskPro 386 Technical Reference Guide** (archive.org, 1986).
Secondary (corroborated): **OSDev Serial Ports**; **Serial Programming / 8250** Wikibook;
**helppc** `8250.html`; **Lammert Bies** serial-uart tutorial.

Contested/cautionary: 16-byte TX burst + FIFO safe only on a *positively-detected genuine*
16550A; PE/FE bits unreliable on some clones (FreeBSD #237576); COM3/4 bases semistandard;
exact DeskPro 386 UART part inferred from AT-compatibility (confirm vs the Tech Ref);
divisor read-back + loopback self-test are recommended engineering practice, not datasheet
mandates.
