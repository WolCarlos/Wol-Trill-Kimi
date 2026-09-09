#!/bin/bash
# ============================================================================
# Wol-Trill-Kimi — install.sh (macOS + Linux)
# Installa le notifiche per Kimi Code:
#   1. copia script + suoni in ~/.kimi/notify/
#   2. aggiunge gli hook a ~/.kimi/config.toml (blocco marcato, idempotente)
# Uso: bash install.sh
# Su Linux servono: bash + un player (paplay/aplay/ffplay/sox) + notify-send (opz.)
# ============================================================================
set -e

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$HOME/.kimi/notify"
CONFIG="$HOME/.kimi/config.toml"

echo "== Wol-Trill-Kimi: installazione (macOS) =="

# --- 1. Copia file ---
mkdir -p "$DEST/sounds"
cp "$SRC/src/kimi-notify.sh" "$SRC/src/stop-notifica.sh" "$DEST/"
cp "$SRC"/sounds/*.wav "$DEST/sounds/"
chmod +x "$DEST/kimi-notify.sh" "$DEST/stop-notifica.sh"
# config.json: non sovrascrivere le preferenze dell'utente se esiste gia'
if [ ! -f "$DEST/config.json" ]; then
    cp "$SRC/src/config.json" "$DEST/"
    echo "[OK] config.json installato (default)"
else
    echo "[OK] config.json esistente mantenuto"
fi
echo "[OK] File copiati in $DEST"

# --- 2. Hook in config.toml (blocco marcato, idempotente) ---
BEGIN="# >>> WOL-TRILL-KIMI >>>"
END="# <<< WOL-TRILL-KIMI <<<"

if [ -f "$CONFIG" ]; then
    BACKUP="$CONFIG.bak-$(date +%Y%m%d-%H%M%S)"
    cp "$CONFIG" "$BACKUP"
    echo "[OK] Backup config: $BACKUP"
    # Rimuovi blocco precedente
    perl -0777 -pi -e "s/\Q$BEGIN\E.*?\Q$END\E//gs" "$CONFIG"
else
    touch "$CONFIG"
fi

cat >> "$CONFIG" <<EOF

$BEGIN
[[hooks]]
event = "Notification"
command = '/bin/bash "$HOME/.kimi/notify/kimi-notify.sh" Notification'
timeout = 25

[[hooks]]
event = "PreToolUse"
matcher = "AskUserQuestion"
command = '/bin/bash "$HOME/.kimi/notify/kimi-notify.sh" Question'
timeout = 25

[[hooks]]
event = "Stop"
command = '/bin/bash "$HOME/.kimi/notify/kimi-notify.sh" Stop'
timeout = 25

[[hooks]]
event = "StopFailure"
command = '/bin/bash "$HOME/.kimi/notify/kimi-notify.sh" StopFailure'
timeout = 25

[[hooks]]
event = "SubagentStop"
command = '/bin/bash "$HOME/.kimi/notify/kimi-notify.sh" SubagentStop'
timeout = 25

[[hooks]]
event = "UserPromptSubmit"
command = '/bin/bash "$HOME/.kimi/notify/kimi-notify.sh" Answered'
timeout = 10

[[hooks]]
event = "PostToolUse"
command = 'rm -f "\${TMPDIR:-/tmp}/kimi-notify-pending.flag" 2>/dev/null; exit 0'
timeout = 5

[[hooks]]
event = "PostToolUseFailure"
command = 'rm -f "\${TMPDIR:-/tmp}/kimi-notify-pending.flag" 2>/dev/null; exit 0'
timeout = 5
$END
EOF
echo "[OK] Hook registrati in $CONFIG"

echo ""
echo "== Installazione completata =="
echo "Riavvia la sessione Kimi Code per attivare gli hook."
echo "Per fermare un suono in loop: $DEST/stop-notifica.sh"
