#!/bin/bash
# ============================================================================
# Wol-NoticheKimi — kimi-notify.sh (macOS)
# Notifiche sonore + notifiche di sistema per gli hook di Kimi Code.
# Stessa logica della versione Windows: un solo loop alla volta, il nuovo
# alert sopprime il precedente, stop su risposta utente / stop-notifica.sh /
# timeout di sicurezza.
#
# Uso (hook Kimi): riceve il JSON dell'evento via stdin.
#   kimi-notify.sh <Notification|Question|Stop|StopFailure|SubagentStop|Answered>
# ============================================================================

EVENT="${1:-Stop}"
BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOUND_DIR="$BASE/sounds"
TMP="${TMPDIR:-/tmp}"
FLAG_FILE="$TMP/kimi-notify-pending.flag"
MAX_MINUTES=15

# Intervallo di ripetizione (secondi) per categoria. 0 = suona una sola volta.
interval_for() {
    case "$1" in
        richiesta) echo 2 ;;
        domanda)   echo 3 ;;
        fatto)     echo 5 ;;
        *)         echo 0 ;;  # errore, agente
    esac
}

# --- Answered: l'utente ha risposto -> ferma il loop + marca il prompt ---
if [ "$EVENT" = "Answered" ]; then
    rm -f "$FLAG_FILE" 2>/dev/null
    date +%s > "$TMP/kimi-notify-prompt.txt" 2>/dev/null
    exit 0
fi

# --- Leggi il JSON dell'hook da stdin ---
JSON="$(cat 2>/dev/null)"

json_field() {  # estrae un campo stringa semplice dal JSON (best-effort, senza jq)
    echo "$JSON" | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1
}

# --- Mappa evento -> categoria / testo ---
CATEGORY="fatto"
TITLE="Kimi Code"
MESSAGE=""

case "$EVENT" in
    Notification)
        NTYPE="$(json_field notification_type)"
        NTITLE="$(json_field title)"
        NBODY="$(json_field body)"
        if echo "$NTYPE" | grep -qiE "question|input|ask|elicitation"; then
            CATEGORY="domanda"; TITLE="Kimi Code - Domanda"
        else
            CATEGORY="richiesta"; TITLE="Kimi Code - Permesso richiesto"
        fi
        MESSAGE="$(echo "$NTITLE $NBODY" | xargs)"
        [ -z "$MESSAGE" ] && MESSAGE="Kimi richiede la tua attenzione."
        ;;
    Question)
        CATEGORY="domanda"; TITLE="Kimi Code - Domanda"
        MESSAGE="Kimi ti sta facendo una domanda e attende risposta."
        ;;
    Stop)
        CATEGORY="fatto"; TITLE="Kimi Code - Completato"
        MESSAGE="Kimi ha finito il turno e attende il tuo input."
        ;;
    StopFailure)
        CATEGORY="errore"; TITLE="Kimi Code - Errore"
        MESSAGE="$(json_field error_message)"
        [ -z "$MESSAGE" ] && MESSAGE="Il turno e' terminato con un errore."
        ;;
    SubagentStop)
        CATEGORY="agente"; TITLE="Kimi Code - Agente completato"
        AGENT="$(json_field agent_name)"
        if [ -n "$AGENT" ]; then MESSAGE="Il subagente '$AGENT' ha terminato."; else MESSAGE="Un subagente ha terminato."; fi
        ;;
esac

# --- Anti-doppione / anti-spam ---
STAMP_FILE="$TMP/kimi-notify-last-$CATEGORY.txt"
NOW=$(date +%s)
if [ -f "$STAMP_FILE" ]; then
    LAST=$(cat "$STAMP_FILE" 2>/dev/null || echo 0)
    if [ "$CATEGORY" = "fatto" ]; then
        # Stop puo' scattare a meta' lavoro: notifica solo se >=60s dall'ultimo
        # 'fatto' OPPURE se l'utente ha scritto dopo quell'ultimo 'fatto'.
        if [ $((NOW - LAST)) -lt 60 ]; then
            PROMPT_TIME=0
            [ -f "$TMP/kimi-notify-prompt.txt" ] && PROMPT_TIME=$(cat "$TMP/kimi-notify-prompt.txt" 2>/dev/null || echo 0)
            [ "$PROMPT_TIME" -le "$LAST" ] && exit 0
        fi
    elif [ $((NOW - LAST)) -lt 4 ]; then
        exit 0
    fi
fi
echo "$NOW" > "$STAMP_FILE" 2>/dev/null

WAV="$SOUND_DIR/$CATEGORY.wav"
INTERVAL=$(interval_for "$CATEGORY")

# --- Un solo loop alla volta: il nuovo alert sopprime il precedente ---
LOOP_ID="$NOW-$$"
echo "$LOOP_ID" > "$FLAG_FILE" 2>/dev/null

if [ "$INTERVAL" -gt 0 ]; then
    # --- Loop finche' non fermato (processo staccato) ---
    (
        END=$(( $(date +%s) + MAX_MINUTES * 60 ))
        while [ "$(date +%s)" -lt "$END" ]; do
            CURRENT="$(cat "$FLAG_FILE" 2>/dev/null)" || break
            [ "$CURRENT" != "$LOOP_ID" ] && break
            afplay "$WAV" 2>/dev/null
            sleep "$INTERVAL"
        done
    ) >/dev/null 2>&1 &
    disown
else
    # --- Suono singolo ---
    afplay "$WAV" 2>/dev/null
    rm -f "$FLAG_FILE" 2>/dev/null
fi

# --- Notifica visiva macOS (best-effort, silenziosa) ---
osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\"" 2>/dev/null

exit 0
