@echo off
rem ============================================================================
rem Wol-Trill-Kimi — dashboard.cmd (Windows)
rem Apre la dashboard grafica delle impostazioni (volumi e intervalli).
rem ============================================================================
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0dashboard.ps1"
