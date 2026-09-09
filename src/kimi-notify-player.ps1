# ============================================================================
# Wol-Trill-Kimi — kimi-notify-player.ps1 (Windows)
# Riproduzione audio condivisa, affidabile e headless-safe.
# - WAV 16-bit PCM: volume applicato scalando i campioni (SoundPlayer, sempre affidabile)
# - WAV altri formati: SoundPlayer a volume pieno
# - MP3/M4A/... (suoni custom): WMP COM best-effort con volume
# ============================================================================

function Play-NotificationSound {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [int]$Volume = 100
    )
    try {
        if ($Path -match '\.wav$') {
            if ($Volume -ge 100) {
                (New-Object System.Media.SoundPlayer $Path).PlaySync()
                return
            }
            $bytes = [System.IO.File]::ReadAllBytes($Path)
            # Cerca il chunk 'data' e verifica PCM 16-bit
            $pos = 12; $dataPos = -1; $dataSize = 0
            $audioFormat = [BitConverter]::ToUInt16($bytes, 20)
            $bits = [BitConverter]::ToUInt16($bytes, 34)
            while ($pos -lt ($bytes.Length - 8)) {
                $id   = [System.Text.Encoding]::ASCII.GetString($bytes, $pos, 4)
                $size = [BitConverter]::ToUInt32($bytes, $pos + 4)
                if ($id -eq 'data') { $dataPos = $pos + 8; $dataSize = $size; break }
                $pos += 8 + $size + ($size -band 1)
            }
            if ($audioFormat -eq 1 -and $bits -eq 16 -and $dataPos -gt 0) {
                $scaled = $bytes.Clone()
                $end = [math]::Min($dataPos + $dataSize, $scaled.Length) - 1
                for ($i = $dataPos; $i -lt $end; $i += 2) {
                    $sv = [int]([BitConverter]::ToInt16($scaled, $i) * $Volume / 100)
                    if ($sv -gt 32767)  { $sv = 32767 }
                    if ($sv -lt -32768) { $sv = -32768 }
                    [BitConverter]::GetBytes([int16]$sv).CopyTo($scaled, $i)
                }
                $ms = New-Object System.IO.MemoryStream(,$scaled)
                (New-Object System.Media.SoundPlayer $ms).PlaySync()
                return
            }
            # WAV non PCM-16: volume non scalabile, riproduci a pieno volume
            (New-Object System.Media.SoundPlayer $Path).PlaySync()
            return
        }
        # Suoni custom non-WAV (mp3/m4a/...): WMP best-effort
        $wmp = New-Object -ComObject WMPlayer.OCX
        $wmp.settings.volume = $Volume
        $wmp.URL = $Path
        Start-Sleep -Milliseconds 250
        $t0 = Get-Date
        while (($wmp.playState -ne 1 -and $wmp.playState -ne 8) -and ((Get-Date) - $t0).TotalSeconds -lt 30) {
            Start-Sleep -Milliseconds 100
        }
        $wmp.close()
    } catch {
        try { [Console]::Beep(1800, 300) } catch {}
    }
}
