# ============================================================================
# Wol-NoticheKimi — install.ps1 (Windows)
# Installa le notifiche per Kimi Code:
#   1. copia script + suoni in ~\.kimi\notify\
#   2. aggiunge gli hook a ~\.kimi\config.toml (blocco marcato, idempotente)
#   3. crea il collegamento "STOP Kimi Notifiche" sul Desktop
# Uso: powershell.exe -NoProfile -ExecutionPolicy Bypass -File install.ps1
# ============================================================================

$ErrorActionPreference = "Stop"
$src     = Split-Path -Parent $MyInvocation.MyCommand.Path
$dest    = Join-Path $HOME ".kimi\notify"
$config  = Join-Path $HOME ".kimi\config.toml"

Write-Host "== Wol-NoticheKimi: installazione =="

# --- 1. Copia file ---
New-Item -ItemType Directory -Force -Path $dest | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $dest "sounds") | Out-Null
Copy-Item (Join-Path $src "src\*.ps1")  $dest -Force
Copy-Item (Join-Path $src "src\*.cmd")  $dest -Force
Copy-Item (Join-Path $src "sounds\*.wav") (Join-Path $dest "sounds") -Force
Write-Host "[OK] File copiati in $dest"

# --- 2. Hook in config.toml (blocco marcato, idempotente) ---
$begin = "# >>> WOL-NOTICHEKIMI >>>"
$end   = "# <<< WOL-NOTICHEKIMI <<<"

$notify = Join-Path $dest "kimi-notify.ps1"
$block = @"
$begin
[[hooks]]
event = "Notification"
command = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$notify" -Event Notification'
timeout = 25

[[hooks]]
event = "PreToolUse"
matcher = "AskUserQuestion"
command = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$notify" -Event Question'
timeout = 25

[[hooks]]
event = "Stop"
command = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$notify" -Event Stop'
timeout = 25

[[hooks]]
event = "StopFailure"
command = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$notify" -Event StopFailure'
timeout = 25

[[hooks]]
event = "SubagentStop"
command = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$notify" -Event SubagentStop'
timeout = 25

[[hooks]]
event = "UserPromptSubmit"
command = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$notify" -Event Answered'
timeout = 10

[[hooks]]
event = "PostToolUse"
command = 'rm -f /tmp/kimi-notify-pending.flag 2>/dev/null; exit 0'
timeout = 5

[[hooks]]
event = "PostToolUseFailure"
command = 'rm -f /tmp/kimi-notify-pending.flag 2>/dev/null; exit 0'
timeout = 5
$end
"@

if (Test-Path $config) {
    $backup = "$config.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item $config $backup
    Write-Host "[OK] Backup config: $backup"
    $text = Get-Content $config -Raw
} else {
    $text = ""
}

# Rimuovi un eventuale blocco precedente + hook orfani con kimi-notify (vecchie installazioni)
$text = [regex]::Replace($text, "(?ms)$([regex]::Escape($begin)).*?$([regex]::Escape($end))", "")
$text = [regex]::Replace($text, "(?ms)\[\[hooks\]\]\s*event\s*=\s*""[^""]+""[^\[]*?kimi-notify[^\[]*?(?=\[\[hooks\]\]|\z)", "")
$text = $text.TrimEnd() + "`r`n`r`n" + $block + "`r`n"
[System.IO.File]::WriteAllText($config, $text)
Write-Host "[OK] Hook registrati in $config"

# --- 3. Collegamento Desktop per fermare i suoni ---
try {
    $desktop = [Environment]::GetFolderPath("Desktop")
    $wsh = New-Object -ComObject WScript.Shell
    $lnk = $wsh.CreateShortcut((Join-Path $desktop "STOP Kimi Notifiche.lnk"))
    $lnk.TargetPath = Join-Path $dest "stop-notifica.cmd"
    $lnk.WindowStyle = 7  # minimizzata
    $lnk.Description = "Ferma subito i suoni di Wol-NoticheKimi"
    $lnk.Save()
    Write-Host "[OK] Collegamento Desktop: STOP Kimi Notifiche.lnk"
} catch {
    Write-Host "[WARN] Collegamento Desktop non creato: $_"
}

Write-Host ""
Write-Host "== Installazione completata =="
Write-Host "Riavvia la sessione Kimi Code per attivare gli hook."
Write-Host "Per provare i suoni: $dest\prova-notifiche.cmd"
Write-Host "Per fermare un suono in loop: doppio click su 'STOP Kimi Notifiche' sul Desktop."
