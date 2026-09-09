#!/bin/bash
# ============================================================================
# Wol-Trill-Kimi — kimi-notify.sh (macOS + Linux)
# Notifiche sonore + notifiche di sistema per gli hook di Kimi Code.
# Player: afplay (macOS) / ffplay / play (sox) / paplay / aplay (Linux).
# Visuale: osascript (macOS) / notify-send (Linux).
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
CONFIG_FILE="$BASE/config.json"
TMP="${TMPDIR:-/tmp}"
FLAG_FILE="$TMP/kimi-notify-pending.flag"
MAX_MINUTES=15

# Configurazione (volumi 0-100, intervalli secondi; 0 = colpo singolo)
conf_val() {  # conf_val <sezione> <chiave> <default> — section-aware
    local v
    v=$(awk -v sec="\"$1\"" -v key="\"$2\"" '
        $0 ~ sec "[[:space:]]*:[[:space:]]*\\{" { insec=1; next }
        insec && /^[[:space:]]*}/ { insec=0 }
        insec && $0 ~ key { match($0, /[0-9]+/); print substr($0, RSTART, RLENGTH); exit }
    ' "$CONFIG_FILE" 2>/dev/null)
    echo "${v:-$3}"
}

interval_for() {
    conf_val interval "$1" "$(case "$1" in request) echo 2;; question) echo 3;; done) echo 5;; *) echo 0;; esac)"
}
volume_for() {
    conf_val volume "$1" "$(case "$1" in request) echo 25;; question) echo 25;; done) echo 30;; error) echo 30;; agent) echo 25;; info) echo 25;; esac)"
}
file_for() {  # suono personalizzato da config (sezione files), stringa
    awk -v key="\"$1\"" '
        $0 ~ "\"files\"[[:space:]]*:[[:space:]]*\\{" { insec=1; next }
        insec && /^[[:space:]]*}/ { insec=0 }
        insec && $0 ~ key { match($0, /"[^"]*"[[:space:]]*,?[[:space:]]*$/); s=substr($0, RSTART, RLENGTH); gsub(/[",[:space:]]/, "", s); print s; exit }
    ' "$CONFIG_FILE" 2>/dev/null
}

# Riproduzione cross-platform con volume best-effort (0-100)
play_sound() {
    local f="$1" v="$2"
    if command -v afplay >/dev/null 2>&1; then
        afplay -v "$(awk "BEGIN{print $v/100}")" "$f"
    elif command -v ffplay >/dev/null 2>&1; then
        ffplay -nodisp -autoexit -loglevel quiet -volume "$v" "$f"
    elif command -v play >/dev/null 2>&1; then
        play -v "$(awk "BEGIN{print $v/100}")" "$f" 2>/dev/null
    elif command -v paplay >/dev/null 2>&1; then
        paplay "$f"
    elif command -v aplay >/dev/null 2>&1; then
        aplay -q "$f"
    fi
}

visual_notify() {
    if command -v osascript >/dev/null 2>&1; then
        osascript -e "display notification \"$2\" with title \"$1\"" 2>/dev/null
    elif command -v notify-send >/dev/null 2>&1; then
        notify-send "$1" "$2" 2>/dev/null
    fi
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
CATEGORY="done"
TITLE="Kimi Code"
MESSAGE=""

case "$EVENT" in
    Notification)
        NTYPE="$(json_field notification_type)"
        NTITLE="$(json_field title)"
        NBODY="$(json_field body)"
        ALL="$NTYPE $NTITLE $NBODY"
        if echo "$ALL" | grep -qiE "fail|error|errore"; then
            # es. "Background task failed": e' un errore, NON una domanda
            CATEGORY="error"; TITLE="Kimi Code - Errore background"
        elif echo "$NTYPE" | grep -qiE "\b(question|ask|input|elicitation)\b"; then
            CATEGORY="question"; TITLE="Kimi Code - Domanda"
        elif echo "$NTYPE" | grep -qiE "permission|approval|confirm"; then
            CATEGORY="request"; TITLE="Kimi Code - Permesso richiesto"
        else
            # es. "Background task completed": informativa, colpo singolo
            CATEGORY="info"; TITLE="Kimi Code - Notifica"
        fi
        MESSAGE="$(echo "$NTITLE $NBODY" | xargs)"
        [ -z "$MESSAGE" ] && MESSAGE="Kimi richiede la tua attenzione."
        ;;
    Question)
        CATEGORY="question"; TITLE="Kimi Code - Domanda"
        MESSAGE="Kimi ti sta facendo una domanda e attende risposta."
        ;;
    Stop)
        CATEGORY="done"; TITLE="Kimi Code - Completato"
        MESSAGE="Kimi ha finito il turno e attende il tuo input."
        ;;
    StopFailure)
        CATEGORY="error"; TITLE="Kimi Code - Errore"
        MESSAGE="$(json_field error_message)"
        [ -z "$MESSAGE" ] && MESSAGE="Il turno e' terminato con un errore."
        ;;
    SubagentStop)
        CATEGORY="agent"; TITLE="Kimi Code - Agente completato"
        AGENT="$(json_field agent_name)"
        if [ -n "$AGENT" ]; then MESSAGE="Il subagente '$AGENT' ha terminato."; else MESSAGE="Un subagente ha terminato."; fi
        ;;
esac

# --- Anti-doppione / anti-spam ---
STAMP_FILE="$TMP/kimi-notify-last-$CATEGORY.txt"
NOW=$(date +%s)
if [ -f "$STAMP_FILE" ]; then
    LAST=$(cat "$STAMP_FILE" 2>/dev/null || echo 0)
    if [ "$CATEGORY" = "done" ]; then
        # Stop puo' scattare a meta' lavoro: notifica solo se >=60s dall'ultimo
        # 'done' OPPURE se l'utente ha scritto dopo quell'ultimo 'done'.
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
CUSTOM=$(file_for "$CATEGORY")
if [ -n "$CUSTOM" ]; then
    case "$CUSTOM" in /*) ;; *) CUSTOM="$SOUND_DIR/$CUSTOM";; esac
    [ -f "$CUSTOM" ] && WAV="$CUSTOM"
fi
INTERVAL=$(interval_for "$CATEGORY")
VOLUME=$(volume_for "$CATEGORY")

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
            play_sound "$WAV" "$VOLUME"
            sleep "$INTERVAL"
        done
    ) >/dev/null 2>&1 &
    disown
else
    # --- Suono singolo ---
    play_sound "$WAV" "$VOLUME"
    rm -f "$FLAG_FILE" 2>/dev/null
fi

# --- Notifica visiva (best-effort) ---
visual_notify "$TITLE" "$MESSAGE"

exit 0
