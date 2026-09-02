# ============================================================================
# Wol-NoticheKimi — kimi-notify-loop.ps1 (Windows)
# Ripete un WAV finche' il flag file contiene il proprio LoopId (o timeout).
# Lanciato in background da kimi-notify.ps1. Un nuovo alert sovrascrive il
# flag con un nuovo LoopId -> questo loop esce da solo.
# ============================================================================

param(
    [Parameter(Mandatory=$true)][string]$Wav,
    [Parameter(Mandatory=$true)][string]$FlagFile,
    [Parameter(Mandatory=$true)][string]$LoopId,
    [int]$IntervalSec = 3,
    [int]$MaxMinutes  = 15
)

$ErrorActionPreference = "SilentlyContinue"
$end = (Get-Date).AddMinutes($MaxMinutes)

try {
    $player = New-Object System.Media.SoundPlayer $Wav
} catch {
    exit 0
}

while ((Get-Date) -lt $end) {
    $current = ""
    try { $current = (Get-Content $FlagFile -Raw).Trim() } catch { break }
    if ($current -ne $LoopId) { break }
    try { $player.PlaySync() } catch {}
    Start-Sleep -Seconds $IntervalSec
}

exit 0
