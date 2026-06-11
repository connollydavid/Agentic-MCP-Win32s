@echo off
REM run-win.bat - launch the Phase 6 Windows 3.11 + Win32s 1.25a guest on the
REM Windows host, where it can run (the WSL2 agent sandbox reaps QEMU after a
REM few seconds, so the interactive install is driven here).
REM
REM Prereq: QEMU for Windows (https://qemu.weilnetz.de/w64/) installed at
REM         C:\Program Files\qemu . NOT required to be on PATH - the full path
REM         is used below. Override with:  set QEMU_DIR=...  before running.
REM
REM Usage:  run-win.bat install   A:=DOS boot floppy  C:=blank  D:=install files
REM         run-win.bat hdd       boot installed C:, D: still attached
REM         run-win.bat run       boot installed C: only (device test-run config)
REM
REM Remote control: the QEMU monitor (sendkey/screendump) and the guest COM1 are
REM exposed as TCP servers so the agent in WSL2 can drive the keyboard, capture
REM the screen, and (later) run the device wire harness. By default they bind to
REM 127.0.0.1 (local only). For WSL2 to reach them you typically need EITHER WSL2
REM mirrored networking (.wslconfig: networkingMode=mirrored, shares localhost)
REM OR set BIND=0.0.0.0 here and allow qemu-system-i386.exe through the Windows
REM Firewall. Screendumps are written under build\shots\ (shared via /mnt/c).
REM This is free/unencumbered software (Unlicense).
setlocal
if "%QEMU_DIR%"=="" set QEMU_DIR=C:\Program Files\qemu
set QEMU=%QEMU_DIR%\qemu-system-i386.exe
if "%BIND%"=="" set BIND=127.0.0.1
if "%MON_PORT%"=="" set MON_PORT=55555
if "%SERIAL_PORT%"=="" set SERIAL_PORT=31800
set HERE=%~dp0
set BUILD=%HERE%..\..\vendor\win311\build
set PHASE=%1
if "%PHASE%"=="" set PHASE=install

if not exist "%QEMU%" (
  echo ERROR: qemu-system-i386.exe not found at "%QEMU%"
  echo Install QEMU for Windows ^(https://qemu.weilnetz.de/w64/^) there,
  echo or set QEMU_DIR to its folder before running.
  exit /b 3
)
if not exist "%BUILD%\shots" mkdir "%BUILD%\shots"

set COMMON=-machine pc -cpu pentium -m 32 -vga std -rtc base=localtime ^
 -drive file="%BUILD%\hdd.img",format=raw,if=ide,index=0,media=disk ^
 -serial tcp:%BIND%:%SERIAL_PORT%,server,nowait ^
 -monitor tcp:%BIND%:%MON_PORT%,server,nowait

echo Launching %PHASE%  (monitor %BIND%:%MON_PORT%, COM1 %BIND%:%SERIAL_PORT%)
if /I "%PHASE%"=="install" (
  "%QEMU%" %COMMON% ^
    -drive file="%BUILD%\install-d.img",format=raw,if=ide,index=1,media=disk ^
    -drive file="%BUILD%\floppies\dos622-boot.img",format=raw,if=floppy,index=0 ^
    -boot order=a
) else if /I "%PHASE%"=="hdd" (
  "%QEMU%" %COMMON% ^
    -drive file="%BUILD%\install-d.img",format=raw,if=ide,index=1,media=disk ^
    -boot order=c
) else if /I "%PHASE%"=="run" (
  "%QEMU%" %COMMON% -boot order=c
) else (
  echo unknown phase: %PHASE%  ^(install ^| hdd ^| run^)
  exit /b 2
)
endlocal
