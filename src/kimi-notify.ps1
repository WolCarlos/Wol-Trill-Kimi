# ============================================================================
# Wol-Trill-Kimi — kimi-notify.ps1 (Windows)
# Notifiche sonore + toast per gli hook di Kimi Code.
#
# Modello: OGNI alert avvia UN loop sonoro che si ripete finche' non viene
# fermato. Un solo loop alla volta: un nuovo alert sopprime quello precedente.
# Il loop si ferma quando:
#   - l'utente clicca "Ferma suono" (o il corpo) della toast / della notifica
#     nel Centro notifiche (protocollo woltrillkimi://stop)
#   - l'utente risponde (hook UserPromptSubmit / PostToolUse / PostToolUseFailure)
#   - l'utente lancia stop-notifica.cmd
#   - scade il timeout di sicurezza (MaxMinutes)
#
# Volumi e intervalli: config.json nella stessa cartella (letto a ogni evento).
#
# Uso (hook Kimi): riceve il JSON dell'evento via stdin.
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File kimi-notify.ps1 -Event <Evento>
# Eventi: Notification | Question | Stop | StopFailure | SubagentStop | Answered
# ============================================================================

param(
    [string]$Event = "Stop"
)

$ErrorActionPreference = "SilentlyContinue"
$base       = Split-Path -Parent $MyInvocation.MyCommand.Path
$soundDir   = Join-Path $base "sounds"
$loopScript = Join-Path $base "kimi-notify-loop.ps1"
$configFile = Join-Path $base "config.json"
$flagFile   = Join-Path $env:TEMP "kimi-notify-pending.flag"
$MaxMinutes = 15

# --- Configurazione (volumi 0-100, intervalli secondi; 0 = colpo singolo) ---
$Volumes   = @{ request=25; question=25; done=30; error=30; agent=25; info=25 }
$Intervals = @{ request=2;   question=3;  done=5;  error=0;   agent=0;  info=0  }
$Files     = @{}
try {
    if (Test-Path $configFile) {
        $cfg = Get-Content $configFile -Raw | ConvertFrom-Json
        foreach ($k in @($Volumes.Keys)) {
            if ($cfg.volume.$k   -ne $null) { $Volumes[$k]   = [int]$cfg.volume.$k }
            if ($cfg.interval.$k -ne $null) { $Intervals[$k] = [int]$cfg.interval.$k }
            if ($cfg.files.$k)              { $Files[$k]     = "$($cfg.files.$k)" }
        }
    }
} catch {}

# --- Evento Answered: l'utente ha risposto -> ferma il loop + marca il prompt ---
if ($Event -eq "Answered") {
    try { Remove-Item $flagFile -Force } catch {}
    try { [System.IO.File]::WriteAllText((Join-Path $env:TEMP "kimi-notify-prompt.txt"), "$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())") } catch {}
    exit 0
}

# --- Leggi il JSON dell'hook da stdin ---
$json = $null
try {
    $stdin = [Console]::In.ReadToEnd()
    if ($stdin) { $json = $stdin | ConvertFrom-Json }
} catch {}

# --- Mappa evento -> categoria / testo ---
$category = "done"
$title    = "Kimi Code"
$message  = ""

switch ($Event) {
    "Notification" {
        $ntype = ""; $ntitle = ""; $nbody = ""
        if ($json) {
            $ntype  = "$($json.notification_type)"
            $ntitle = "$($json.title)"
            $nbody  = "$($json.body)"
        }
        $all = "$ntype $ntitle $nbody"
        if ($all -match "fail|error|errore") {
            # es. "Background task failed": e' un errore, NON una domanda
            $category = "error";   $title = "Kimi Code - Errore background"
        } elseif ($ntype -match "\b(question|ask|input|elicitation)\b") {
            $category = "question"; $title = "Kimi Code - Domanda"
        } elseif ($ntype -match "permission|approval|confirm") {
            $category = "request";  $title = "Kimi Code - Permesso richiesto"
        } else {
            # es. "Background task completed": informativa, colpo singolo
            $category = "info";     $title = "Kimi Code - Notifica"
        }
        $message = ($ntitle + " " + $nbody).Trim()
        if (-not $message) { $message = "Kimi richiede la tua attenzione." }
    }
    "Question" {
        $category = "question"
        $title    = "Kimi Code - Domanda"
        $message  = "Kimi ti sta facendo una domanda e attende risposta."
    }
    "Stop" {
        $category = "done"
        $title    = "Kimi Code - Completato"
        $message  = "Kimi ha finito il turno e attende il tuo input."
    }
    "StopFailure" {
        $category = "error"
        $title    = "Kimi Code - Errore"
        if ($json -and $json.error_message) { $message = "$($json.error_message)" }
        if (-not $message) { $message = "Il turno e' terminato con un errore." }
    }
    "SubagentStop" {
        $category = "agent"
        $title    = "Kimi Code - Agente completato"
        $agent = ""
        if ($json -and $json.agent_name) { $agent = "$($json.agent_name)" }
        if ($agent) { $message = "Il subagente '$agent' ha terminato." } else { $message = "Un subagente ha terminato." }
    }
}

# --- Anti-doppione / anti-spam ---
$stampFile = Join-Path $env:TEMP "kimi-notify-last-$category.txt"
$now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
try {
    if (Test-Path $stampFile) {
        $last = [int64](Get-Content $stampFile -Raw).Trim()
        if ($category -eq "done") {
            # Stop puo' scattare a meta' lavoro: notifica solo se sono passati >=60s
            # dall'ultimo 'done' OPPURE se l'utente ha scritto dopo quell'ultimo 'done'.
            if (($now - $last) -lt 60) {
                $promptStamp = Join-Path $env:TEMP "kimi-notify-prompt.txt"
                $promptTime = 0
                if (Test-Path $promptStamp) { $promptTime = [int64](Get-Content $promptStamp -Raw).Trim() }
                if ($promptTime -le $last) { exit 0 }
            }
        } elseif (($now - $last) -lt 4) { exit 0 }
    }
    [System.IO.File]::WriteAllText($stampFile, "$now")
} catch {}

# Suono: personalizzato da config (files) o predefinito
$wav = Join-Path $soundDir "$category.wav"
if ($Files.ContainsKey($category)) {
    $custom = $Files[$category]
    if (-not [System.IO.Path]::IsPathRooted($custom)) { $custom = Join-Path $soundDir $custom }
    if (Test-Path $custom) { $wav = $custom }
}
$interval = $Intervals[$category]
$volume   = $Volumes[$category]

# --- Un solo loop alla volta: il nuovo alert sopprime il precedente ---
$loopId = "$now-$PID"
try { [System.IO.File]::WriteAllText($flagFile, $loopId) } catch {}

if ($interval -gt 0) {
    # --- Loop finche' non fermato ---
    try {
        Start-Process powershell.exe -WindowStyle Hidden -ArgumentList @(
            "-NoProfile", "-ExecutionPolicy", "Bypass",
            "-File", "`"$loopScript`"",
            "-Wav", "`"$wav`"",
            "-FlagFile", "`"$flagFile`"",
            "-LoopId", "`"$loopId`"",
            "-IntervalSec", "$interval",
            "-Volume", "$volume",
            "-MaxMinutes", "$MaxMinutes"
        )
    } catch {
        try { (New-Object System.Media.SoundPlayer $wav).PlaySync() } catch {}
    }
} else {
    # --- Suono singolo (volume da config, via WMP COM; fallback SoundPlayer) ---
    try {
        $wmp = New-Object -ComObject WMPlayer.OCX
        $wmp.settings.volume = $volume
        $wmp.URL = $wav
        Start-Sleep -Milliseconds 250  # lascia partire la riproduzione
        $t0 = Get-Date
        # attendi la fine: playState 1=stopped, 8=media ended
        while (($wmp.playState -ne 1 -and $wmp.playState -ne 8) -and ((Get-Date) - $t0).TotalSeconds -lt 10) {
            Start-Sleep -Milliseconds 100
        }
        $wmp.close()
    } catch {
        try { (New-Object System.Media.SoundPlayer $wav).PlaySync() } catch { try { [Console]::Beep(1800, 400) } catch {} }
    }
    # Alert singolo: nessun loop in attesa -> pulisci il flag
    try { Remove-Item $flagFile -Force } catch {}
}

# --- Toast visiva (best-effort, silenziosa: il suono lo gestiamo noi) ---
# Il CORPO della toast (anche nel Centro notifiche) e il tasto fermano il suono.
try {
    $t = [System.Security.SecurityElement]::Escape($title)
    $m = [System.Security.SecurityElement]::Escape($message)
    $template = @"
<toast activationType="protocol" launch="woltrillkimi://stop">
  <visual>
    <binding template="ToastGeneric">
      <text>$t</text>
      <text>$m</text>
    </binding>
  </visual>
  <audio silent="true"/>
  <actions>
    <action content="Ferma suono" activationType="protocol" arguments="woltrillkimi://stop"/>
  </actions>
</toast>
"@
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null
    $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $xml.LoadXml($template)
    $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
    $appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)
} catch {}

exit 0
