# Wol-Trill-Kimi

[🇬🇧 **English**](README.md) | [🇮🇹 **Italiano**](README.it.md)

**Sound and visual notifications** for [Kimi Code](https://github.com/MoonshotAI/kimi-cli) (VS Code extension and CLI), on **Windows** and **macOS**.

Know when Kimi asks for a permission, asks you a question, or finishes its work — even when you're on another window.

## How it works

Wol-Trill-Kimi uses Kimi Code's [native hooks](https://moonshotai.github.io/kimi-cli/en/customization/hooks.html) (`~/.kimi/config.toml`). Each event starts a **looping sound** that repeats until:

- **you answer Kimi** (submit a prompt, approve/deny a tool), or
- **you stop it manually** with the stop script, or
- the safety timeout expires (15 minutes).

**Only one loop at a time**: every new notification suppresses the previous one.

## Sounds

| Category | Event | Sound | Loop |
|---|---|---|---|
| 🔴 `richiesta` | Permission requested | 4 rapid high-pitched beeps | every 2s |
| 🟡 `domanda` | Kimi asks you a question | rising two-tone | every 3s |
| 🟢 `fatto` | Turn completed | rising arpeggio | every 5s |
| ⛔ `errore` | Turn failed | descending sweep | single |
| 🤖 `agente` | Subagent completed | short double blip | single |

Anti-spam: Kimi's `Stop` event can fire mid-work → the "fatto" notification is suppressed if another one fired less than 60s ago without a prompt from you in between.

## Installation

### Windows
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File install.ps1
```

### macOS
```bash
bash install.sh
```

The installer:
1. copies scripts and sounds to `~/.kimi/notify/`
2. adds the hooks to `~/.kimi/config.toml` (automatic backup, idempotent marked block `# >>> WOL-TRILL-KIMI >>>`)
3. *(Windows only)* creates a **STOP Kimi Notifiche** shortcut on your Desktop

**Restart Kimi Code** after installation to load the hooks.

## Stop a looping sound

- **Answer Kimi** (prompt or approve/deny click) → it stops by itself
- **Windows**: double-click `STOP Kimi Notifiche` on the Desktop (or run `~/.kimi/notify/stop-notifica.cmd`)
- **macOS**: run `~/.kimi/notify/stop-notifica.sh`

## Preview the sounds

- **Windows**: `~/.kimi/notify/prova-notifiche.cmd` (all) or `prova-notifiche.cmd domanda` (single category)
- Regenerate/customize the WAVs with `python tools/generate-sounds.py`

## Uninstall

- **Windows**: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File uninstall.ps1`
- **macOS**: `bash uninstall.sh`

## Project structure

```
src/
  kimi-notify.ps1       # notification engine (Windows)
  kimi-notify-loop.ps1  # background sound loop (Windows)
  kimi-notify.sh        # engine + loop (macOS)
  stop-notifica.cmd     # manual stop (Windows)
  stop-notifica.sh      # manual stop (macOS)
  prova-notifiche.cmd   # sound preview (Windows)
sounds/                 # WAVs for the 5 categories
tools/generate-sounds.py
install.* / uninstall.*
```

## Notes

- Requires Kimi Code with hooks support (Beta). Hooks run in the same shell as Kimi (Git Bash on Windows, bash on macOS).
- On Windows sounds are played directly (`System.Media.SoundPlayer`): they don't depend on Focus Assist or notification settings.
- On macOS sounds use `afplay` and visual notifications use `osascript`.

## License

MIT
