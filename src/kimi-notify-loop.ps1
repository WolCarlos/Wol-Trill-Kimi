# ============================================================================
# Wol-Trill-Kimi — kimi-notify-loop.ps1 (Windows)
# Ripete un WAV finche' il flag file contiene il proprio LoopId (o timeout).
# Lanciato in background da kimi-notify.ps1. Un nuovo alert sovrascrive il
# flag con un nuovo LoopId -> questo loop esce da solo.
# Volume 0-100 da config.json (via WMP COM, indipendente per categoria).
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
$end = (Get-Date).AddMinutes($MaxMinutes)

# Player con volume configurabile (fallback: SoundPlayer a volume pieno)
$wmp = $null
try {
    $wmp = New-Object -ComObject WMPlayer.OCX
    $wmp.settings.volume = $Volume
} catch {
    $wmp = $null
}

while ((Get-Date) -lt $end) {
    $current = ""
    try { $current = (Get-Content $FlagFile -Raw).Trim() } catch { break }
    if ($current -ne $LoopId) { break }

    if ($wmp) {
        try {
            $wmp.URL = $Wav
            Start-Sleep -Milliseconds 250  # lascia partire la riproduzione
            $t0 = Get-Date
            # attendi la fine: playState 1=stopped, 8=media ended
            while (($wmp.playState -ne 1 -and $wmp.playState -ne 8) -and ((Get-Date) - $t0).TotalSeconds -lt 10) {
                Start-Sleep -Milliseconds 100
            }
        } catch {}
    } else {
        try { (New-Object System.Media.SoundPlayer $Wav).PlaySync() } catch {}
    }

    Start-Sleep -Seconds $IntervalSec
}

try { if ($wmp) { $wmp.close() } } catch {}
exit 0
