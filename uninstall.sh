#!/bin/bash
# ============================================================================
# Wol-Trill-Kimi — uninstall.sh (macOS). Uso: bash uninstall.sh
# ============================================================================
DEST="$HOME/.kimi/notify"
CONFIG="$HOME/.kimi/config.toml"
BEGIN="# >>> WOL-TRILL-KIMI >>>"
END="# <<< WOL-TRILL-KIMI <<<"

rm -f "${TMPDIR:-/tmp}/kimi-notify-pending.flag"

if [ -f "$CONFIG" ]; then
    cp "$CONFIG" "$CONFIG.bak-$(date +%Y%m%d-%H%M%S)"
    perl -0777 -pi -e "s/\Q$BEGIN\E.*?\Q$END\E//gs" "$CONFIG"
    echo "[OK] Hook rimossi da $CONFIG"
fi

rm -rf "$DEST"
echo "[OK] File rimossi da $DEST"
echo "Disinstallazione completata. Riavvia Kimi Code."
