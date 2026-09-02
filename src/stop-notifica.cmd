@echo off
rem ============================================================================
rem Wol-NoticheKimi — stop-notifica.cmd (Windows)
rem Ferma SUBITO qualunque suono in loop. Doppio click e il suono si ferma.
rem ============================================================================
del /q "%TEMP%\kimi-notify-pending.flag" 2>nul
exit /b 0
