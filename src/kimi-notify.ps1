# ============================================================================
# Wol-Trill-Kimi — kimi-notify.ps1 (Windows)
# Notifiche sonore + toast per gli hook di Kimi Code.
#
# Modello: OGNI alert avvia UN loop sonoro che si ripete finche' non viene
# fermato. Un solo loop alla volta: un nuovo alert sopprime quello precedente.
# Il loop si ferma quando:
#   - l'utente risponde (hook UserPromptSubmit / PostToolUse / PostToolUseFailure)
#   - l'utente lancia stop-notifica.cmd
#   - scade il timeout di sicurezza (MaxMinutes)
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
$flagFile   = Join-Path $env:TEMP "kimi-notify-pending.flag"
$MaxMinutes = 15

# Intervallo di ripetizione (secondi) per categoria. 0 = suona una sola volta.
$Intervals = @{
    richiesta = 2    # permesso richiesto
    domanda   = 3    # domanda all'utente
    fatto     = 5    # fine lavoro
    errore    = 0    # errore (singolo)
    agente    = 0    # subagent completato (singolo)
}

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
$category = "fatto"
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
        if ($ntype -match "question|input|ask|elicitation") {
            $category = "domanda";  $title = "Kimi Code - Domanda"
        } else {
            $category = "richiesta"; $title = "Kimi Code - Permesso richiesto"
        }
        $message = ($ntitle + " " + $nbody).Trim()
        if (-not $message) { $message = "Kimi richiede la tua attenzione." }
    }
    "Question" {
        $category = "domanda"
        $title    = "Kimi Code - Domanda"
        $message  = "Kimi ti sta facendo una domanda e attende risposta."
    }
    "Stop" {
        $category = "fatto"
        $title    = "Kimi Code - Completato"
        $message  = "Kimi ha finito il turno e attende il tuo input."
    }
    "StopFailure" {
        $category = "errore"
        $title    = "Kimi Code - Errore"
        if ($json -and $json.error_message) { $message = "$($json.error_message)" }
        if (-not $message) { $message = "Il turno e' terminato con un errore." }
    }
    "SubagentStop" {
        $category = "agente"
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
        if ($category -eq "fatto") {
            # Stop puo' scattare a meta' lavoro: notifica solo se sono passati >=60s
            # dall'ultimo 'fatto' OPPURE se l'utente ha scritto dopo quell'ultimo 'fatto'.
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

$wav      = Join-Path $soundDir "$category.wav"
$interval = $Intervals[$category]

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
            "-MaxMinutes", "$MaxMinutes"
        )
    } catch {
        try { (New-Object System.Media.SoundPlayer $wav).PlaySync() } catch {}
    }
} else {
    # --- Suono singolo ---
    try {
        if (Test-Path $wav) { (New-Object System.Media.SoundPlayer $wav).PlaySync() }
        else { [Console]::Beep(1800, 400) }
    } catch {
        try { [Console]::Beep(1800, 400) } catch {}
    }
    # Alert singolo: nessun loop in attesa -> pulisci il flag
    try { Remove-Item $flagFile -Force } catch {}
}

# --- Toast visiva (best-effort, silenziosa: il suono lo gestiamo noi) ---
try {
    $t = [System.Security.SecurityElement]::Escape($title)
    $m = [System.Security.SecurityElement]::Escape($message)
    $template = @"
<toast>
  <visual>
    <binding template="ToastGeneric">
      <text>$t</text>
      <text>$m</text>
    </binding>
  </visual>
  <audio silent="true"/>
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
