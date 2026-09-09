# ============================================================================
# Wol-Trill-Kimi — install.ps1 (Windows)
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

Write-Host "== Wol-Trill-Kimi: installazione =="

# --- 1. Copia file ---
New-Item -ItemType Directory -Force -Path $dest | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $dest "sounds") | Out-Null
Copy-Item (Join-Path $src "src\*.ps1")  $dest -Force
Copy-Item (Join-Path $src "src\*.cmd")  $dest -Force
Copy-Item (Join-Path $src "src\*.vbs")  $dest -Force
Copy-Item (Join-Path $src "sounds\*.wav") (Join-Path $dest "sounds") -Force
# config.json: non sovrascrivere le preferenze dell'utente se esiste gia'
if (-not (Test-Path (Join-Path $dest "config.json"))) {
    Copy-Item (Join-Path $src "src\config.json") $dest
    Write-Host "[OK] config.json installato (default)"
} else {
    Write-Host "[OK] config.json esistente mantenuto"
}
Write-Host "[OK] File copiati in $dest"

# --- 2. Hook in config.toml (blocco marcato, idempotente) ---
$begin = "# >>> WOL-TRILL-KIMI >>>"
$end   = "# <<< WOL-TRILL-KIMI <<<"

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
    $lnk.Description = "Ferma subito i suoni di Wol-Trill-Kimi"
    $lnk.Save()
    Write-Host "[OK] Collegamento Desktop: STOP Kimi Notifiche.lnk"
} catch {
    Write-Host "[WARN] Collegamento Desktop non creato: $_"
}

# --- 4. Protocollo woltrillkimi://stop (tasto "Ferma suono" dentro le toast) ---
try {
    $proto = "HKCU:\Software\Classes\woltrillkimi"
    New-Item -Path "$proto\shell\open\command" -Force | Out-Null
    Set-Item -Path $proto -Value "URL:Wol-Trill-Kimi Protocol"
    New-ItemProperty -Path $proto -Name "URL Protocol" -Value "" -PropertyType String -Force | Out-Null
    Set-Item -Path "$proto\shell\open\command" -Value "wscript.exe `"$(Join-Path $dest 'stop-notifica.vbs')`""
    Write-Host "[OK] Protocollo woltrillkimi://stop registrato (tasto nelle toast)"
} catch {
    Write-Host "[WARN] Protocollo non registrato: $_"
}

Write-Host ""
Write-Host "== Installazione completata =="
Write-Host "Riavvia la sessione Kimi Code per attivare gli hook."
Write-Host "Per provare i suoni: $dest\prova-notifiche.cmd"
Write-Host "Per fermare un suono in loop: tasto 'Ferma suono' nella notifica, doppio click su 'STOP Kimi Notifiche' sul Desktop, o rispondi a Kimi."
