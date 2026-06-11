/*
 * uart-probe.c - Phase 6.2 diagnostic SPIKE (throwaway, NOT shipped device code).
 *
 * Question it answers: under Win32s 1.25a on WfW 3.11 (386-enhanced mode), can a
 * ring-3 app reach the 8250/16550 UART by DIRECT port I/O (IN/OUT to 0x3F8..0x3FF),
 * bypassing the stubbed Win32 comm API (SetCommState -> err 120) AND the Win16
 * COMM.DRV entirely? Operator-consented experiment (David, 2026-06-11).
 *
 * It does NOT open COM1 via CreateFile/OpenComm, so COMM.DRV never initialises the
 * UART and there is no driver to contend with. The only gatekeepers are the System
 * VM's I/O privilege (does the bare OUT fault?) and VCD's virtualisation.
 *
 * Built CRT-FREE (no msvcrt import) so it actually LOADS on Win32s - same lesson as
 * Finding #1. Only kernel32 + user32 imports; all on the 6.2 allowlist.
 *   i686-w64-mingw32-gcc -O2 -ffreestanding -fno-builtin -nostdlib -nostartfiles \
 *     -e _probemain -Wl,--subsystem,windows -o uartprob.exe uart-probe.c \
 *     -lkernel32 -luser32
 *
 * Reading the result:
 *   - Box 1 appears, you click OK, app VANISHES (or a GPF dialog pops) -> the bare
 *     ring-3 IN/OUT FAULTED. Direct UART access is NOT granted ring-3. Stop.
 *   - Box 2 appears with a scratch readback of AA/55 and IIR=C0 -> port I/O WORKS;
 *     direct UART access IS granted (same mechanism COMM.DRV uses). Proceed.
 *   - After Box 3, the host side (nc 127.0.0.1:31800) should show "UARTPROBE-TX":
 *     proof a byte traversed ring-3 OUT -> UART -> QEMU -> wire, no comm stack.
 *   - Box 4 / C:\UARTPROB.LOG report any bytes received (send some from the host
 *     with nc during the ~poll window) -> the RX half works too.
 *
 * This is free and unencumbered software released into the public domain.
 */

#include <windows.h>

/* COM1 register file (DLAB=0 unless noted). */
#define COM1      0x3F8
#define R_RBR_THR (COM1 + 0)   /* RX buffer / TX holding; DLL when DLAB=1 */
#define R_IER_DLM (COM1 + 1)   /* int-enable;            DLM when DLAB=1 */
#define R_IIR_FCR (COM1 + 2)   /* read: IIR   write: FCR */
#define R_LCR     (COM1 + 3)   /* line control (bit7 = DLAB) */
#define R_MCR     (COM1 + 4)   /* modem control (DTR|RTS|OUT2) */
#define R_LSR     (COM1 + 5)   /* line status (bit0 DR, bit5 THRE) */
#define R_SCR     (COM1 + 7)   /* scratch (absent on the original 8250) */

static unsigned char inb(unsigned short port)
{
    unsigned char v;
    __asm__ __volatile__ ("inb %1,%0" : "=a"(v) : "Nd"(port));
    return v;
}

static void outb(unsigned short port, unsigned char v)
{
    __asm__ __volatile__ ("outb %0,%1" : : "a"(v), "Nd"(port));
}

/* Tiny CRT-free log buffer flushed to C:\UARTPROB.LOG at the end. */
static char g_log[2048];
static int  g_len = 0;

static void logs(const char *s)
{
    while (*s != '\0' && g_len < (int)sizeof(g_log) - 1) {
        g_log[g_len++] = *s++;
    }
}

void probemain(void)
{
    char buf[256];
    unsigned char a, b, iir;
    const char *m;
    int got;
    unsigned long spins;
    HANDLE h;
    DWORD wr;

    MessageBoxA(0,
        "UART probe 1/4: about to execute the FIRST ring-3 port I/O "
        "(scratch-register write/read at 0x3FF).\n\n"
        "If this app VANISHES (or a GPF dialog pops) after you click OK, the "
        "bare IN/OUT faulted -> direct UART access is NOT granted ring-3.",
        "uartprobe 1/4", MB_OK);

    /* Scratch-register write/read: the make-or-break port I/O. If this faults,
       we never reach Box 2. If it round-trips AA/55, ring-3 port I/O is granted. */
    outb(R_SCR, 0xAA); a = inb(R_SCR);
    outb(R_SCR, 0x55); b = inb(R_SCR);

    /* 16550 FIFO detect: write FCR=0xE7, read IIR top bits (0xC0 = 16550A). */
    outb(R_IIR_FCR, 0xE7);
    iir = inb(R_IIR_FCR);

    wsprintfA(buf,
        "scratch: wrote AA/55, read %02X/%02X (match=%d).  "
        "IIR after FCR=E7: %02X  (C0=16550A FIFO).",
        a, b, (a == 0xAA && b == 0x55), iir);
    logs(buf); logs("\r\n");
    MessageBoxA(0, buf, "uartprobe 2/4  (port I/O DID work)", MB_OK);

    /* Program 19200 8N1, FIFO on, interrupts OFF (polled). 115200/19200 = div 6. */
    outb(R_LCR, 0x80);          /* DLAB=1 */
    outb(R_RBR_THR, 6);         /* DLL */
    outb(R_IER_DLM, 0);         /* DLM */
    outb(R_LCR, 0x03);          /* DLAB=0, 8N1 */
    outb(R_IIR_FCR, 0xC7);      /* FIFO on, clear, 14-byte trigger */
    outb(R_MCR, 0x0B);          /* DTR|RTS|OUT2 */
    outb(R_IER_DLM, 0x00);      /* no interrupts - we poll */

    /* TX a recognisable marker, polling THRE (LSR bit5) before each byte. */
    m = "UARTPROBE-TX\r\n";
    while (*m != '\0') {
        int guard;
        for (guard = 0; guard < 200000; guard++) {
            if (inb(R_LSR) & 0x20) break;
        }
        outb(R_RBR_THR, (unsigned char)*m);
        m++;
    }
    logs("TX: wrote UARTPROBE-TX to THR\r\n");

    MessageBoxA(0,
        "uartprobe 3/4: programmed 19200 8N1, FIFO on; wrote 'UARTPROBE-TX' to "
        "THR.\n\nCheck the HOST: nc on 127.0.0.1:31800 should now show that "
        "string (ring-3 OUT -> UART -> QEMU -> wire, no comm stack).\n\n"
        "Click OK, then send some bytes from the host - I poll RX briefly.",
        "uartprobe 3/4", MB_OK);

    /* Poll RX (LSR bit0 = data ready) for a bounded spin window. Cooperative
       multitasking: this tight loop does NOT yield, so Windows is frozen for the
       duration - fine for a probe (the QEMU monitor is out-of-band). */
    got = 0;
    for (spins = 0; spins < 40000000UL && got < 63; spins++) {
        if (inb(R_LSR) & 0x01) {
            buf[got++] = (char)inb(R_RBR_THR);
        }
    }
    buf[got] = '\0';
    {
        char rep[128];
        wsprintfA(rep, "RX: %d byte(s): [%s]", got, buf);
        logs(rep); logs("\r\n");
        MessageBoxA(0, rep, "uartprobe 4/4", MB_OK);
    }

    /* Flush the log to C: via Win32 only (no CRT). Readable later via mtools. */
    h = CreateFileA("C:\\UARTPROB.LOG", GENERIC_WRITE, 0, NULL,
                    CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (h != INVALID_HANDLE_VALUE) {
        WriteFile(h, g_log, (DWORD)g_len, &wr, NULL);
        CloseHandle(h);
    }

    ExitProcess(0);
}
