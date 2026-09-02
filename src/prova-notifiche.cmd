@echo off
rem ============================================================================
rem Wol-Trill-Kimi — prova-notifiche.cmd (Windows)
rem Riproduci i suoni delle notifiche per provarli.
rem Uso:
rem   prova-notifiche.cmd           -> suona tutte le categorie in sequenza
rem   prova-notifiche.cmd richiesta -> suona solo quella categoria
rem Categorie: richiesta, domanda, fatto, errore, agente
rem ============================================================================

setlocal
set "DIR=%~dp0sounds"

if not "%~1"=="" (
    call :play "%~1"
    goto :eof
)

echo Prova suoni Wol-Trill-Kimi (5 suoni in sequenza)...
echo.
call :play richiesta
call :play domanda
call :play fatto
call :play errore
call :play agente
echo.
echo Fatto.
goto :eof

:play
set "name=%~1"
if not exist "%DIR%\%name%.wav" (
    echo [ERRORE] Categoria sconosciuta o WAV mancante: %name%
    echo Categorie valide: richiesta, domanda, fatto, errore, agente
    exit /b 1
)
echo  -^> %name%
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "(New-Object System.Media.SoundPlayer '%DIR%\%name%.wav').PlaySync()"
"%SystemRoot%\System32\timeout.exe" /t 1 /nobreak >nul 2>&1
exit /b 0
