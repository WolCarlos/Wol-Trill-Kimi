# ============================================================================
# Wol-Trill-Kimi — kimi-notify-loop.ps1 (Windows)
# Ripete un suono finche' il flag file contiene il proprio LoopId (o timeout).
# Lanciato in background da kimi-notify.ps1. Un nuovo alert sovrascrive il
# flag con un nuovo LoopId -> questo loop esce da solo.
# Volume 0-100 da config.json (player condiviso kimi-notify-player.ps1).
# ============================================================================

param(
    [Parameter(Mandatory=$true)][string]$Wav,
    [Parameter(Mandatory=$true)][string]$FlagFile,
    [Parameter(Mandatory=$true)][string]$LoopId,
    [int]$IntervalSec = 3,
    [int]$Volume      = 100,
    [int]$MaxMinutes  = 15
)

$ErrorActionPreference = "SilentlyContinue"
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "kimi-notify-player.ps1")

$end = (Get-Date).AddMinutes($MaxMinutes)

while ((Get-Date) -lt $end) {
    $current = ""
    try { $current = (Get-Content $FlagFile -Raw).Trim() } catch { break }
    if ($current -ne $LoopId) { break }
    Play-NotificationSound -Path $Wav -Volume $Volume
    Start-Sleep -Seconds $IntervalSec
}

exit 0
