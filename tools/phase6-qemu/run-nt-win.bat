@echo off
REM run-nt-win.bat - launch the Windows NT 3.1 Advanced Server guest (the
REM native-Win32/NT baseline floor) on the Windows host, in a SEPARATE lane from
REM the Win 3.11/Win32s guest (own disk + own ports, so both can run at once).
REM The WSL2 agent sandbox reaps qemu* after a few seconds, so this runs here.
REM
REM Prereq: QEMU for Windows at C:\Program Files\qemu (override with QEMU_DIR=).
REM         Stage the media first (in WSL):  bash tools/phase6-qemu/build-nt31.sh
REM
REM NT-3.1 tuning (it is the hardest NT to emulate): -cpu 486 (Pentium can
REM bugcheck NT 3.1), -vga cirrus (NT 3.1 ships a Cirrus GD5430 driver -> a usable
REM 256-colour GUI; std VGA is 16-colour only), -net none (no NT-3.1 NIC driver for
REM QEMU's models; not needed for the serial-wire test), small 500M FAT C: (boot
REM files within the first 1024 cylinders).
REM
REM Ports (distinct from the win311 lane's 31800/55555/:0 so both coexist):
REM   guest COM1 -> host TCP 31801   (the device wire harness: wire_accept.py)
REM   QEMU monitor -> host TCP 55556 (screendump/sendkey/change/eject: mon-win.sh)
REM   VNC :1 (5901)                  (operator drives the interactive installer)
REM
REM Usage:  run-nt-win.bat install   DOS boots (A:), C: blank, D:=I386 source
REM         run-nt-win.bat run       boot installed NT off C: (device test-run)
REM
REM Install walk (monitor-driven, see tools/phase6-qemu/README.md):
REM   1) install: A:=DOS. FORMAT C: /S. Then D:\I386\WINNT /S:D:\I386 .
REM   2) when WINNT asks for a blank floppy in A:, from WSL:
REM        MON_PORT=55556 bash mon-win.sh cmd "change floppy0 <build>\floppies\ntsetup-boot.img"
REM      let WINNT write it; on its prompt, system_reset -> boots the NT Setup floppy.
REM   3) NT text-mode setup runs (reads C: temp + D:), then GUI setup; reboots into NT.
REM This is free/unencumbered software (Unlicense).
setlocal
if "%QEMU_DIR%"=="" set QEMU_DIR=C:\Program Files\qemu
set QEMU=%QEMU_DIR%\qemu-system-i386.exe
if "%BIND%"=="" set BIND=127.0.0.1
if "%MON_PORT%"=="" set MON_PORT=55556
if "%SERIAL_PORT%"=="" set SERIAL_PORT=31801
if "%VNC_DISP%"=="" set VNC_DISP=1
set HERE=%~dp0
set BUILD=%HERE%..\..\vendor\winnt31\build
set PHASE=%1
if "%PHASE%"=="" set PHASE=install

if not exist "%QEMU%" (
  echo ERROR: qemu-system-i386.exe not found at "%QEMU%"
  echo Install QEMU for Windows ^(https://qemu.weilnetz.de/w64/^) there, or set QEMU_DIR.
  exit /b 3
)
if not exist "%BUILD%\hdd.img" (
  echo ERROR: %BUILD%\hdd.img missing - stage media first: bash tools/phase6-qemu/build-nt31.sh
  exit /b 3
)
if not exist "%BUILD%\shots" mkdir "%BUILD%\shots"

REM Era-appropriate NIC: the Novell NE2000 ISA (~1990) at the settings NT 3.1's
REM "Novell NE2000 Compatible" driver defaults to (I/O 0x300, IRQ 3). NT 3.1
REM predates good PCI NIC support, so the ISA NE2000 is the period-correct pick
REM (pcnet/ne2k_pci are NT-3.5-era). -netdev user gives a usermode NAT slirp so
REM the guest has a working stack without host bridging; networking is not needed
REM for the serial device test, but a real detected NIC avoids a blind/no-card
REM install and the first-boot "couldn't start adapter" error.
set COMMON=-machine pc -cpu 486 -m 32 -vga cirrus -rtc base=localtime ^
 -netdev user,id=n0 -device ne2k_isa,netdev=n0,iobase=0x300,irq=3 ^
 -drive file="%BUILD%\hdd.img",format=raw,if=ide,index=0,media=disk ^
 -serial tcp:%BIND%:%SERIAL_PORT%,server,nowait ^
 -monitor tcp:%BIND%:%MON_PORT%,server,nowait ^
 -vnc %BIND%:%VNC_DISP%

echo Launching NT 3.1 %PHASE%  (monitor %BIND%:%MON_PORT%, COM1 %BIND%:%SERIAL_PORT%, VNC :%VNC_DISP%)
if /I "%PHASE%"=="install" (
  "%QEMU%" %COMMON% ^
    -drive file="%BUILD%\install-i386.img",format=raw,if=ide,index=1,media=disk ^
    -drive file="%BUILD%\floppies\dos622-boot.img",format=raw,if=floppy,index=0 ^
    -boot order=a
) else if /I "%PHASE%"=="run" (
  "%QEMU%" %COMMON% -boot order=c
) else (
  echo unknown phase: %PHASE%  ^(install ^| run^)
  exit /b 2
)
endlocal
