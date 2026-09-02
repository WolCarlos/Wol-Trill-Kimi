#!/bin/bash
# ============================================================================
# Wol-NoticheKimi — stop-notifica.sh (macOS)
# Ferma SUBITO qualunque suono in loop.
# ============================================================================
rm -f "${TMPDIR:-/tmp}/kimi-notify-pending.flag"
exit 0
