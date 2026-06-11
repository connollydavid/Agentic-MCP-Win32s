@echo off
REM run-win.bat - launch the Phase 6 Windows 3.11 + Win32s 1.25a guest on the
REM Windows host, where it can run (the WSL2 agent sandbox reaps QEMU after a
REM few seconds, so the interactive install is driven here).
REM
REM Prereq: QEMU for Windows (https://qemu.weilnetz.de/w64/) with
REM         qemu-system-i386.exe on PATH.
REM
REM Usage:  run-win.bat install   A:=DOS boot floppy  C:=blank  D:=install files
REM         run-win.bat hdd       boot installed C:, D: still attached
REM         run-win.bat run       boot installed C: only (device test-run config)
REM
REM The guest COM1 is exposed as a host TCP server on 127.0.0.1:31800 for the
REM device wire harness. This is free/unencumbered software (Unlicense).
setlocal
set HERE=%~dp0
set BUILD=%HERE%..\..\vendor\win311\build
set PHASE=%1
if "%PHASE%"=="" set PHASE=install

set COMMON=-machine pc -cpu pentium -m 32 -vga std -rtc base=localtime ^
 -drive file="%BUILD%\hdd.img",format=raw,if=ide,index=0,media=disk ^
 -serial tcp:127.0.0.1:31800,server,nowait

if /I "%PHASE%"=="install" (
  qemu-system-i386 %COMMON% ^
    -drive file="%BUILD%\install-d.img",format=raw,if=ide,index=1,media=disk ^
    -drive file="%BUILD%\floppies\dos622-boot.img",format=raw,if=floppy,index=0 ^
    -boot order=a
) else if /I "%PHASE%"=="hdd" (
  qemu-system-i386 %COMMON% ^
    -drive file="%BUILD%\install-d.img",format=raw,if=ide,index=1,media=disk ^
    -boot order=c
) else if /I "%PHASE%"=="run" (
  qemu-system-i386 %COMMON% -boot order=c
) else (
  echo unknown phase: %PHASE%  ^(install ^| hdd ^| run^)
  exit /b 2
)
endlocal
