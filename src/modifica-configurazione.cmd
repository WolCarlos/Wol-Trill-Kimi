@echo off
rem ============================================================================
rem Wol-Trill-Kimi — modifica-configurazione.cmd (Windows)
rem Apre config.json in Notepad: volumi (0-100) e intervalli (secondi, 0=singolo)
rem per ogni categoria. Le modifiche valgono dalla prossima notifica.
rem ============================================================================
notepad.exe "%~dp0config.json"
