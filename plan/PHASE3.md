# Phase 3: Network & Transport (serial + TCP/Winsock) — **Complete**

**Goal.** Make the network a first-class peer of the serial port. Replace the `HANDLE`-hardwired protocol I/O with a transport-agnostic byte-pipe interface backed by pluggable, runtime-registered backends; refactor serial onto it; add a TCP backend over Winsock 1.1; add a mock backend that makes response bytes assertable in tests. The same seam admits future backends — UDP / HTTP-3 (QUIC), then exotic message/RDMA transports (e.g. ibverbs-over-Thunderbolt) — without touching the protocol core. Phase 3 is fully self-contained: abstraction + registry + serial refactor + TCP backend + runtime detection + mock backend + specs + tests + CI, all in scope here.

**Why this is its own phase, ahead of command execution.** Today the protocol I/O is hard-wired to a Win32 `HANDLE`: `MainLoop`, `SendReady`, `ProcessCommand`, and `ProcessBuffer`'s handler all call `ReadFile`/`WriteFile` directly (`src/mcp-w32s.c:84,197,213`; handler typedef at `:51`). That works for serial because a COM port *is* a file handle — but a Winsock `SOCKET` is **not** a Win32 file handle on Win32s/Win9x, so `ReadFile`/`WriteFile` cannot drive it (README §449 says exactly this). Phase 4 (command execution) emits the ready message and exec stdout/stderr over the transport, so this abstraction must exist first — otherwise exec ships serial-only and is rewritten later.

### Pre-decisions (non-negotiable)

1. **vtable interface, not tagged dispatch.** A backend is a struct of function pointers; the core knows only the interface. This is what makes the layer agnostic and future-proof.
2. **Network backends are runtime-probed (`LoadLibraryA`/`GetProcAddress`), never statically imported.** `wsock32.dll` is absent on bare Win32s; a static import would stop the binary loading there. Same philosophy as Phase 4's `feat.c`.
3. **TCP server is single-client-sequential.** `listen(s, 1)` → `accept` one client → serve until disconnect → accept the next. Matches the single-threaded, one-exec-at-a-time model. Blocking sockets; no `select` loop.
4. **Framing stays above the transport.** Newline-JSON (`LineBuffer`) lives in the core; any reliable ordered byte backend works unchanged. A message-oriented backend sets a `flags` bit to bypass `LineBuffer`.
5. **Transport config moves to the transport module.** `TransportConfig`, `TRANSPORT_*`, and `ParseCommandLine` move from `serial.{c,h}` to `transport.{c,h}` — they are transport-level, not serial-level.
6. **Serial is the always-available baseline + auto-detect fallback.** Explicit `/SERIAL`/`/TCP` are honored exactly; default (no flag) stays serial COM1 (preserves current behavior + tests). Auto-detect, if requested, probes TCP then falls back to serial (README chain: TCP > serial).
7. **`htons`/`htonl` implemented by hand** (`((x&0xff)<<8)|((x>>8)&0xff)`) — avoids importing the symbols and avoids the banned `bswap` (486+) instruction. Integer-only, i386-safe.
8. **The mock backend is the test seam.** Response-byte assertions (impossible today) become possible; unit tests never open a real port or socket.

### Critical Winsock 1.1 / Win32s quirks to design around

| # | Quirk | Mitigation |
|---|-------|-----------|
| T1 | A `SOCKET` is **not** a Win32 file handle on Win32s/Win9x | TCP backend uses `recv`/`send`, never `ReadFile`/`WriteFile`; the vtable hides the difference |
| T2 | `wsock32.dll` absent on bare Win32s (needs TCP/IP-32 add-on on WfW 3.11) | `LoadLibraryA("wsock32.dll")` + `GetProcAddress`; probe fail ⇒ backend unavailable, fall back to serial |
| T3 | Winsock must be initialized/negotiated | `WSAStartup(MAKEWORD(1,1), &wsaData)`; verify `wsaData.wVersion == 0x0101`; one `WSACleanup` at shutdown |
| T4 | `SOCKET` is `unsigned int`; failure sentinel differs | Check `== INVALID_SOCKET` (not `INVALID_HANDLE_VALUE`); API errors are `SOCKET_ERROR` (-1) |
| T5 | Socket teardown differs from handles | `closesocket()` per socket (not `CloseHandle`); pair the single `WSAStartup` with one `WSACleanup` |
| T6 | Network byte order needed for `bind`/port | Manual `htons`/`htonl` (shift, not `bswap` — 486+ banned) |
| T7 | `recv` returns 0 on orderly close, <0 on error | Treat 0 as peer-closed (advance accept loop); <0 → check `WSAGetLastError`, close conn |
| T8 | `send` may move fewer bytes than requested | `TransportWriteAll` loops until all bytes sent or hard error |
| T9 | Socket errors don't use `GetLastError` | Use `WSAGetLastError()` for socket diagnostics in `errMsg` |
| T10 | **Winsock 1.1 only** — no `ws2_32` | Resolve from `wsock32.dll`; never link/`LoadLibrary` `ws2_32` |
| T11 | Win32s has a low socket-handle ceiling and shared address space | `closesocket` promptly on disconnect; one listener + one conn at a time |
| T12 | `accept` blocks the single thread | Acceptable by design (single-client-sequential); no concurrent work expected while idle |

Sources to cite in code comments: README §447–453 (Win32s socket vs handle, no ws2_32), §1147–1199 (Winsock 1.1 TCP design + runtime detection), MS Docs *Winsock 1.1 reference* (`WSAStartup`, `recv`, `send`).

### Design: vtable interface + backend registry

A backend is a small struct of function pointers (C89 indirect calls — fine on i386; Phase 4's `feat.c` uses the same pattern). The protocol core knows only the interface.

```c
/* transport.h */
typedef struct Transport Transport;

struct Transport {
    const char *name;     /* "serial" | "tcp" | "mock" | ... — surfaced in ready message */
    int kind;             /* TRANSPORT_SERIAL | TRANSPORT_TCP | ... */
    int flags;            /* bit0: message-oriented (bypass LineBuffer); else byte-stream */

    /* Connection vtable. Return: >0 bytes moved, 0 = orderly peer close, <0 = error. */
    int  (*read)(Transport *t, void *buf, int len);
    int  (*write)(Transport *t, const void *buf, int len);
    void (*close)(Transport *t);

    /* Server lifecycle. NULL for point-to-point backends (serial).
     * For listeners (tcp): blocks for a client, returns a *connection* Transport
     * (may be `t` itself reused, or a distinct conn). NULL `accept` => one-shot peer. */
    Transport *(*accept)(Transport *t);

    union { HANDLE handle; unsigned int sock; void *ptr; } io;  /* backend-private */
};

/* Backend registry — enables agnostic auto-detect + future backends */
typedef struct {
    int kind;
    const char *name;
    int  (*probe)(void);                                   /* 1 if usable on this host */
    int  (*open)(const TransportConfig *cfg, Transport *out, char *err, int errSize);
} TransportBackend;

int  TransportOpen(const TransportConfig *cfg, Transport *out, char *err, int errSize);
int  TransportWriteAll(Transport *t, const void *buf, int len);   /* loops on short writes */
const char *TransportName(const Transport *t);
```

**Framing stays above the transport.** Newline-delimited JSON (`LineBuffer`) sits in the core and is fed by whatever bytes a backend's `read` delivers. Reliable, ordered byte transports (serial, TCP, and later QUIC/RDMA) need no change. A genuinely message-oriented exotic backend sets `flags` bit0 so the core treats one message = one command and skips `LineBuffer`. This is the only concession the core makes to non-stream transports — everything else is the backend's problem (reliability, ordering, MTU).

**The main loop becomes transport- and lifecycle-agnostic:**
```c
TransportOpen(&cfg, &listener, err, sizeof err);
for (;;) {
    Transport *conn = listener.accept ? listener.accept(&listener) : &listener;
    SendReady(conn);
    Serve(conn);                       /* read → LineBuffer → ProcessCommand(line, conn) */
    if (conn != &listener) conn->close(conn);
    if (!listener.accept) break;       /* serial: one peer, done */
    /* tcp: loop back to accept the next client (single-client-sequential) */
}
listener.close(&listener);
```

### Backends in scope here

| Backend | File | Mechanism | Availability |
|---------|------|-----------|--------------|
| serial | `src/serial.c` (refactor) | wraps existing `OpenSerialPort` + `ReadFile`/`WriteFile`; `accept = NULL` | All Win32 |
| tcp | `src/tcp.c` (new) | Winsock 1.1 `socket`/`bind`/`listen`/`accept`/`recv`/`send`/`closesocket`; `recv`/`send` (NOT ReadFile) | WfW 3.11 + TCP/IP-32, Win95+ |
| mock | `tests/mock_transport.c` (new) | in-memory buffers; captures written bytes, feeds scripted input | Test-only |

The **mock backend is a testability win**: today `ProcessCommand` tests pass `INVALID_HANDLE_VALUE` and cannot assert response bytes (`tests/test_serial.c:330`). With a mock transport, tests assert the exact JSON written.

### TCP backend (`src/tcp.c`) — Winsock 1.1, runtime-probed

`wsock32.dll` is absent on bare Win32s without TCP/IP-32, so a **static import would prevent the binary from loading there**. Per README §1191, the TCP backend `LoadLibraryA("wsock32.dll")` + `GetProcAddress` for every entry point and stores them in a function-pointer table (same philosophy as `feat.c`). Probe fails ⇒ backend unavailable ⇒ explicit `/TCP` errors cleanly, auto-detect falls back to serial.

- `WSAStartup(MAKEWORD(1,1), &wsaData)`; verify `wsaData.wVersion`.
- `socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)` → `SOCKET` (`unsigned int`, `INVALID_SOCKET` on failure — **not** `INVALID_HANDLE_VALUE`).
- `bind` to `INADDR_ANY:htons(port)`; `listen(s, 1)` (backlog 1 — single client).
- `accept` blocks; returns the client `SOCKET` wrapped in a connection `Transport`.
- `recv(conn, buf, len, 0)`: `>0` data, `0` orderly close, `SOCKET_ERROR` (<0) error. `send` likewise.
- `closesocket` per socket; `WSACleanup` at process shutdown.
- **`htons`/`htonl` implemented manually** (`((x&0xff)<<8)|((x>>8)&0xff)`) — avoids pulling the symbols *and* avoids the banned `bswap` instruction. Integer-only, i386-safe.
- Blocking sockets only (no `select` loop needed for one client; single-threaded honored).

### Files

**Create:** `src/transport.{c,h}` (interface + registry + `TransportOpen`/`TransportWriteAll`), `src/tcp.{c,h}` (TCP backend + Winsock fnptr table), `tests/mock_transport.{c,h}`, `tests/test_transport.c` (≥10), `tests/test_tcp.c` (≥6, in-process loopback; proven natively on the Windows host against real Winsock), `specs/transport.allium`.

**Modify:**
- `src/serial.{c,h}` — keep `BuildSerialDCB`/`BuildSerialTimeouts`/`OpenSerialPort`; add `SerialBackendOpen` producing a serial `Transport`. **Move** `TransportConfig`, `TRANSPORT_*`, and `ParseCommandLine` out to `transport.{c,h}` (they are transport-level, not serial-level); `serial.h` includes `transport.h`.
- `src/mcp-w32s.c` — `MainLoop`/`SendReady`/`Serve`/`ProcessCommand`/`ProcessBuffer` handler take `Transport *` instead of `HANDLE`; writes go through `TransportWriteAll`. `main` calls `TransportOpen`, runs the accept loop, drops the "only serial supported" rejection.
- `tests/test_serial.c` — update handler signature to `Transport *`; switch the `ProcessCommand` stub tests to the mock backend and assert real response bytes; fix `ParseCommandLine` include path.
- `CMakeLists.txt` (the single source of truth; `build.sh`/`build.bat` are thin wrappers around the mingw/vc6 presets) — add `transport.c`, `tcp.c` to the link; add `test_transport`, `test_tcp` targets (link `-lwsock32` for the tcp test only). Link main with `-lwsock32` **only if** static-link is chosen; default is runtime-probe, so main does **not** statically import wsock32 (CI assertion below).
- `.github/workflows/build-and-test.yml` — run `test_transport`, `test_tcp` (CI is Ubuntu+Wine; local dev runs the PEs natively on the Windows host via WSL2 interop — Wine is a convenience, not the source of truth). **Import-table assertion:** `objdump -p mcp-w32s.exe | grep -i wsock32` must be empty (TCP is runtime-loaded, so the binary still loads on bare Win32s). FPU/486 grep auto-applies to `transport.o`/`tcp.o`.
- `README.md` — replace the "TCP is Phase 3+ / not yet implemented" notes (§1161, §1191–1194) with the implemented design; document the vtable interface and the backend-registry extension point for future UDP/QUIC/RDMA backends.
- `specs/mcp-protocol.allium` — tend the existing `entity Transport { ready: Boolean }` and `surface SerialPort` into a backend-agnostic model (see below).

### Public APIs

```c
/* transport.h — interface, registry, config (moved here from serial.h) */

#define TRANSPORT_NONE   0
#define TRANSPORT_SERIAL 1
#define TRANSPORT_TCP    2
#define TRANSPORT_PIPE   3        /* reserved — Phase 5+ */
#define TRANSPORT_MOCK   99       /* test-only */

#define TRANSPORT_FLAG_MESSAGE 0x01   /* one message = one command; bypass LineBuffer */

typedef struct {
    int   transport;              /* TRANSPORT_SERIAL | TRANSPORT_TCP | ... */
    char  port[32];               /* "COM1" ... (serial) */
    DWORD baudRate;               /* serial */
    int   tcpPort;                /* TCP listen port */
    char  pipeName[260];          /* reserved */
    int   autodetect;             /* 1 = probe TCP then fall back to serial */
} TransportConfig;

typedef struct Transport Transport;
struct Transport {
    const char *name;             /* "serial" | "tcp" | "mock" — surfaced in ready message */
    int   kind;
    int   flags;                  /* TRANSPORT_FLAG_* */
    int   (*read)(Transport *t, void *buf, int len);        /* >0 / 0=close / <0=error */
    int   (*write)(Transport *t, const void *buf, int len); /* >0 / <0=error */
    void  (*close)(Transport *t);
    Transport *(*accept)(Transport *t);                     /* NULL for point-to-point */
    union { HANDLE handle; unsigned int sock; void *ptr; } io;
};

typedef struct {
    int   kind;
    const char *name;
    int   (*probe)(void);                                              /* 1 if usable here */
    int   (*open)(const TransportConfig *cfg, Transport *out,
                  char *err, int errSize);
} TransportBackend;

int         ParseCommandLine(const char *cmdLine, TransportConfig *cfg);   /* moved from serial */
int         TransportOpen(const TransportConfig *cfg, Transport *out,
                          char *err, int errSize);  /* registry dispatch + fallback */
int         TransportWriteAll(Transport *t, const void *buf, int len);     /* loops short writes */
const char *TransportName(const Transport *t);
int         TransportRegister(const TransportBackend *backend);            /* used by backends */

/* serial.h — backend factory (config/parse now live in transport.h) */
int  SerialBackendOpen(const TransportConfig *cfg, Transport *out, char *err, int errSize);
/* existing BuildSerialDCB / BuildSerialTimeouts / OpenSerialPort / CloseSerialPort retained */

/* tcp.h — Winsock 1.1 backend, runtime-probed */
int  TcpBackendProbe(void);   /* 1 if wsock32 loads + WSAStartup(1,1) succeeds */
int  TcpBackendOpen(const TransportConfig *cfg, Transport *out, char *err, int errSize);
void TcpBackendCleanup(void); /* WSACleanup at process shutdown */
unsigned short McpHtons(unsigned short x);   /* manual; no bswap */
unsigned long  McpHtonl(unsigned long x);

/* tests/mock_transport.h — in-memory backend */
typedef struct {
    Transport t;
    const char *scriptIn;   /* bytes delivered by read(), then 0 (close) */
    int  inPos, inLen;
    char outBuf[MCP_MAX_RESPONSE];   /* bytes captured from write() */
    int  outLen;
    int  shortWrite;        /* if >0, write() returns at most this many bytes/call */
} MockTransport;
void MockTransportInit(MockTransport *m, const char *scriptIn, int scriptLen);
```

### Implementation checklist (the dangerous parts)

**Serial refactor (do first — pure restructure, behavior-preserving):**
1. Move `TransportConfig`, `TRANSPORT_*`, `ParseCommandLine` into `transport.{c,h}`. `serial.h` includes `transport.h`. Update includes in `mcp-w32s.c`, `test_serial.c`.
2. Wrap the existing serial open into `SerialBackendOpen`: fill `Transport` with `name="serial"`, `kind=TRANSPORT_SERIAL`, `flags=0`, `accept=NULL`, `read`/`write` = thin `ReadFile`/`WriteFile` wrappers over `io.handle`, `close` = `CloseSerialPort`.
3. Register the serial backend at startup. Confirm the existing serial behavior is byte-identical (regression test).

**Core dispatch retargeting:**
4. Change `ProcessBuffer`'s handler typedef and `ProcessCommand`/`SendReady`/`MainLoop`/new `Serve` from `HANDLE` to `Transport *`. Replace every `WriteFile(...)` with `TransportWriteAll(t, buf, len)`.
5. Rewrite `main` to: `ParseCommandLine` → `TransportOpen` → accept loop (see below). Delete the "only serial supported" rejection.

**Accept loop (transport- and lifecycle-agnostic):**
```c
if (!TransportOpen(&cfg, &listener, err, sizeof err)) { /* MessageBoxA(err); return 1; */ }
for (;;) {
    Transport *conn = listener.accept ? listener.accept(&listener) : &listener;
    if (conn == NULL) break;                 /* accept error */
    SendReady(conn);
    Serve(conn);                             /* read → LineBuffer → ProcessCommand(line, conn) */
    if (conn != &listener) conn->close(conn);
    if (!listener.accept) break;             /* serial: single peer, done */
}
listener.close(&listener);
TcpBackendCleanup();                          /* no-op unless TCP was used */
```

**TCP backend (`tcp.c`) — strict Winsock 1.1 ordering:**
6. Probe: `LoadLibraryA("wsock32.dll")`; `GetProcAddress` for `WSAStartup,WSACleanup,socket,bind,listen,accept,recv,send,closesocket,WSAGetLastError`; store in a fnptr table. Any NULL ⇒ probe fails (return 0).
7. Open listener: `WSAStartup(MAKEWORD(1,1),&wsa)`; verify `wsa.wVersion==0x0101`; `socket(AF_INET,SOCK_STREAM,IPPROTO_TCP)`; fill `sockaddr_in` with `sin_family=AF_INET`, `sin_port=McpHtons(cfg->tcpPort)`, `sin_addr=INADDR_ANY`; `bind`; `listen(s,1)`. On any failure: `errMsg` via `WSAGetLastError`, `closesocket`, `WSACleanup`, return 0.
8. `accept` method: blocking `accept(listener.io.sock,...)`; on `INVALID_SOCKET` return NULL; else fill a connection `Transport` (`name="tcp"`, `read`=`recv` wrapper, `write`=`send` wrapper, `close`=`closesocket`, `accept`=NULL).
9. `read` wrapper: `n=recv(sock,buf,len,0)`; map `0`→0 (close), `SOCKET_ERROR`→-1, else `n`. `write` wrapper: `send(...)`; `SOCKET_ERROR`→-1.
10. Cleanup: `closesocket` both sockets; `TcpBackendCleanup` calls `WSACleanup` once. Track init so double-cleanup is safe.

**`TransportWriteAll`:** loop `t->write` over the buffer; sum bytes; return total or <0 on hard error. Handles serial short writes and TCP `send` partials (T8).

**`TransportOpen`:** look up backend by `cfg->transport` in the registry; if `autodetect`, try TCP `probe`+`open`, on failure fall back to the serial backend; write a clear `errMsg` if the explicitly-requested backend is unavailable.

**Mock backend (`mock_transport.c`):** `read` drains `scriptIn` then returns 0; `write` appends to `outBuf` (honoring `shortWrite` to exercise `TransportWriteAll`); `accept=NULL`; `close` is idempotent.

### Allium lifecycle (mandatory)

1. `/allium:elicit` — settle the transport domain model (listener vs connection lifecycle, the message-vs-stream `flags` bit, fallback semantics). This also resolves the standing open question in `mcp-protocol.allium` ("Should the ready message include transport metadata?") — yes: the ready message names the active backend.
2. `/allium:tend` — write `specs/transport.allium`; update `mcp-protocol.allium`. `allium check` clean.
3. `/allium:propagate` — derive test obligations (table below is the floor).
4. Implement.
5. `/allium:weed` — zero spec↔code drift before this work is marked done.

`specs/transport.allium` sketch (tend owns final form):
```
entity Transport {
    name: String
    kind: serial | tcp | mock
    role: listener | connection | point_to_point
    message_oriented: Boolean
    status: opening | listening | connected | closed | error
    transitions status {
        opening   -> listening      -- server backends (tcp)
        opening   -> connected      -- point-to-point (serial)
        opening   -> error
        listening -> connected      -- accept() returns a client
        connected -> closed         -- peer disconnect / orderly close
        connected -> listening      -- tcp: client gone, back to accept (single-client-sequential)
        terminal: closed, error
    }
}
rule SerialIsPointToPoint   { ... }   -- serial has no accept; role = point_to_point
rule TcpListensThenAccepts  { ... }   -- tcp: listening -> connected via accept
rule UnavailableBackendFallsBack { ... } -- probe fail + auto-detect => serial
rule ReadyOnConnect         { ... }   -- ready message emitted once per connection
invariant ConnectionCanIO   { for t in Transports: t.status = connected implies t.name.size > 0 }
invariant ClosedIsTerminal  { ... }
```

### Tests (floor; propagate may add)

`tests/test_transport.c` (≥10): registry lookup by kind; `TransportOpen` selects serial by default; explicit unknown kind errors; `TransportWriteAll` loops on short writes (mock returns partial); mock read delivers scripted bytes then 0 (close); `accept == NULL` ⇒ one-shot loop exits; message-oriented flag routes around `LineBuffer`; serial backend `accept` is NULL; name surfaced correctly; double-close is safe.

`tests/test_tcp.c` (≥6, run natively on Windows against real Winsock — not skipped locally; self-skips with a printed reason only where Winsock is genuinely absent, e.g. CI/Wine): probe returns availability honestly; open listener binds a port; `accept` + `recv` round-trips a line over loopback (client = a second socket in the test); `send` delivers a response; orderly close returns 0 from `read`; `htons` matches a known value (e.g. `htons(8932)` byte pattern).

Integration (extend `tests/test_serial.c`): full command → mock transport → assert exact response JSON bytes (now possible).

### Future backends (design intent, NOT implemented here)

The registry + vtable is the extension seam. A new backend implements `{probe, open}` and the connection vtable, then registers — the core is untouched.
- **UDP / HTTP-3 (QUIC):** QUIC gives reliable, ordered byte streams → reuse the stream path and `LineBuffer` unchanged; only the backend differs. Modern-only ⇒ runtime-probed/feature-detected, never statically linked on the Win32s path.
- **Exotic message/RDMA (ibverbs-over-Thunderbolt class):** set `flags` message-oriented bit; one message = one command, bypassing `LineBuffer`. These are uplift backends present only on capable hosts; the Win32s baseline always retains serial.

### Test execution environment (WSL2 + Windows host)

The dev host is **WSL2 on Windows**, so MinGW-built PEs run **natively on the Windows host via WSL interop** (`./test_tcp.exe` executes through real `kernel32`/`wsock32`, no Wine). This is the source of truth for local verification — **Wine is a convenience/fallback, not a requirement.** Consequence: `test_tcp` and the end-to-end TCP path are **proven against real Winsock locally and must not be skipped**; the `wsock32`-probe self-skip exists only for environments that genuinely lack Winsock (e.g. CI's Ubuntu+Wine if its Winsock is unusable). `build.sh test` should detect WSL2-with-interop and run the PEs natively, falling back to Wine only when no Windows host is reachable.

### Build/CI integration

- `CMakeLists.txt` (single source of truth; `build.sh`/`build.bat` wrap the mingw/vc6 presets): add `src/transport.c` + `src/tcp.c` to the main link; add `test_transport` and `test_tcp` targets (link `-lwsock32` for `test_tcp` only). Main does **not** statically import `wsock32` (runtime-probed) — so do **not** add `-lwsock32` to the main link.
- `build.sh test`: prefer **native Windows execution** of the test PEs on WSL2 (run `tests/*.exe` directly via interop); use Wine only as a fallback. `host-pbt` (Phase 4) stays native Linux.
- `.github/workflows/build-and-test.yml` (Ubuntu — no Windows host): runs `test_transport` + `test_tcp` under Wine; `test_tcp` self-skips with a printed reason only if Wine's Winsock is unusable. Existing FPU/486 grep auto-applies to `transport.o`/`tcp.o`. **Import-table assertion:** `objdump -p mcp-w32s.exe | grep -i 'wsock32\|ws2_32'` must be empty.
- Stack-frame watch: `sockaddr_in`/`WSADATA` are small, but keep them off oversized frames; if `__chkstk` appears in `tcp.o`, move buffers to `static`.

### Out of scope for Phase 3 (architectural reasons)

- **Named pipes backend.** Win95+ only, not Win32s; same vtable shape, deferred to Phase 5+ (cross-platform) where it adds value. The registry already reserves `TRANSPORT_PIPE`.
- **Multi-client / `select` concurrency.** Conflicts with the single-threaded, single-exec model. Single-client-sequential is the deliberate design.
- **UDP / HTTP-3 / RDMA backends.** Design seam is provided (registry + `flags`), but implementations are modern-host uplift work, not part of the Win32s baseline. Future phases.
- **TLS / authentication.** No crypto libraries compile on the Win32s target; out of the project's threat model (trusted serial/LAN link).

### Verification (sub-agent acceptance criteria)

1. `./build.sh test` clean (strict flags); `transport.o`/`tcp.o` FPU/486-free.
2. `objdump -p mcp-w32s.exe | grep -i 'wsock32\|ws2_32'` empty — binary still loads on bare Win32s; TCP is runtime-loaded.
3. `test_transport`, `test_tcp`, and refactored `test_serial` all pass **run natively on the Windows host (WSL2 interop)**; `test_tcp` is proven against real Winsock (not skipped). Wine is a fallback only.
4. End-to-end serial path unchanged: existing behavior preserved (regression check).
5. End-to-end TCP, run natively on the Windows host: start `mcp-w32s.exe /TCP:8932` as a Windows process; a Windows-side client (e.g. `powershell.exe` `System.Net.Sockets.TcpClient`, so both ends share Windows loopback) sends `{"cmd":"echo","id":"1","line":"hi"}\n` and receives the echo response; disconnect; the server then accepts a second client (sequential). The in-process loopback in `test_tcp.exe` is the primary automated proof.
6. `specs/transport.allium` `allium check` clean; `/allium:weed` reports zero drift; all six Allium skills exercised per the lifecycle above.
7. Phase 4 exec/ready code, when written, uses `Transport *` — no `HANDLE`-typed I/O in the protocol core.
8. Total tests: 87 + ≥10 (transport) + ≥6 (tcp) + mock-backed `test_serial` response-byte assertions = **≥103 tests**.

