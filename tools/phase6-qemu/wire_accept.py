#!/usr/bin/env python3
# wire_accept.py - on-target acceptance wire harness (tier-neutral). Connects to
# the guest COM1 (QEMU -serial tcp server), captures the device's ready line
# (TX on open), then sends an echo command and reads the response (RX + dispatch
# + TX round-trip). Port is the lane's COM1 TCP port: default 31800 (the Win32s
# direct-UART lane); override via SERIAL_PORT env or argv[1] (e.g. 31801 = the
# NT 3.1 lane, where the device serves over the OS comm API instead of bare UART).
# Public domain (Unlicense).
import socket, time, sys, os

HOST = '127.0.0.1'
PORT = int(os.environ.get('SERIAL_PORT') or (sys.argv[1] if len(sys.argv) > 1 else 31800))
LOG = '/tmp/wire_log.txt'
out = open(LOG, 'w')


def log(m):
    out.write(m + '\n'); out.flush()
    print(m, flush=True)


try:
    s = socket.create_connection((HOST, PORT), timeout=120)
except Exception as e:
    log("CONNECT FAIL: %r" % e); sys.exit(1)

log("connected to %s:%d - waiting (<=120s) for the device ready line..." % (HOST, PORT))
s.settimeout(120)
buf = b''
ready = None
deadline = time.time() + 120
while time.time() < deadline:
    try:
        data = s.recv(4096)
    except socket.timeout:
        log("TIMEOUT waiting for ready"); break
    if not data:
        log("peer closed before ready"); break
    buf += data
    if b'\n' in buf:
        ready, _, buf = buf.partition(b'\n')
        break

log("READY RX: %r" % (ready,))
if ready is None:
    log("VERDICT: FAIL - no ready line received"); s.close(); sys.exit(2)

cmd = b'{"cmd":"echo","id":"acc1","line":"HELLO-WIN32S-UART"}\n'
log("TX cmd: %r" % cmd)
try:
    s.send(cmd)
except Exception as e:
    log("SEND FAIL: %r" % e); s.close(); sys.exit(3)

resp = buf
s.settimeout(20)
rdl = time.time() + 20
while time.time() < rdl:
    if b'\n' in resp:
        break
    try:
        data = s.recv(4096)
    except socket.timeout:
        break
    if not data:
        break
    resp += data

line = resp.partition(b'\n')[0]
log("RESP RX: %r" % (line,))
ok = (b'"id":"acc1"' in line and b'"status":"ok"' in line and b'HELLO-WIN32S-UART' in line)
log("VERDICT: %s" % ("PASS - full wire round-trip over the serial transport (port %d)" % PORT
                     if ok else "INCOMPLETE - response did not match (see RESP RX)"))
s.close()
sys.exit(0 if ok else 4)
