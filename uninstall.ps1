# ============================================================================
# Wol-Trill-Kimi — uninstall.ps1 (Windows)
# Rimuove hook e file installati. Uso:
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File uninstall.ps1
# ============================================================================
$ErrorActionPreference = "Continue"
$dest    = Join-Path $HOME ".kimi\notify"
$config  = Join-Path $HOME ".kimi\config.toml"
$begin   = "# >>> WOL-TRILL-KIMI >>>"
$end     = "# <<< WOL-TRILL-KIMI <<<"

# Ferma eventuali loop
Remove-Item (Join-Path $env:TEMP "kimi-notify-pending.flag") -Force -ErrorAction SilentlyContinue

# Rimuovi blocco hook
if (Test-Path $config) {
    Copy-Item $config "$config.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    $text = Get-Content $config -Raw
    $text = [regex]::Replace($text, "(?ms)$([regex]::Escape($begin)).*?$([regex]::Escape($end))", "")
    [System.IO.File]::WriteAllText($config, $text)
    Write-Host "[OK] Hook rimossi da $config"
}

# Rimuovi file e collegamento Desktop
Remove-Item $dest -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path ([Environment]::GetFolderPath("Desktop")) "STOP Kimi Notifiche.lnk") -Force -ErrorAction SilentlyContinue
Write-Host "[OK] File rimossi da $dest"
Write-Host "Disinstallazione completata. Riavvia Kimi Code."
