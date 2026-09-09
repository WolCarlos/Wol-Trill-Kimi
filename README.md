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
| 🔴 `request` | Permission requested | 4 rapid high-pitched beeps | every 2s |
| 🟡 `question` | Kimi asks you a question | rising two-tone | every 3s |
| 🟢 `done` | Turn completed | rising arpeggio | every 5s |
| ⛔ `error` | Turn failed / background task failed | descending sweep | single |
| 🤖 `agent` | Subagent completed | short double blip | single |
| ℹ️ `info` | Other notifications (e.g. background task completed) | soft single ping | single |

Anti-spam: Kimi's `Stop` event can fire mid-work → the "done" notification is suppressed if another one fired less than 60s ago without a prompt from you in between.

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

- **Click the toast — the "Ferma suono" button or the notification body** (works from the Action Center too; uses the `woltrillkimi://stop` protocol)
- **Answer Kimi** (prompt or approve/deny click) → it stops by itself
- **Windows**: double-click `STOP Kimi Notifiche` on the Desktop (or run `~/.kimi/notify/stop-notifica.cmd`)
- **macOS**: run `~/.kimi/notify/stop-notifica.sh`

Note: closing the toast (or clicking its body) does NOT stop the sound — use the button or one of the methods above.

## Configuration (volumes & intervals)

Each category has its own **volume** (0–100, per-category, independent of the Windows notification volume) and **interval** (seconds between repetitions, `0` = single shot) in `~/.kimi/notify/config.json`:

```json
{
  "volume":   { "request": 100, "question": 90, "done": 70, "error": 100, "agent": 60, "info": 50 },
  "interval": { "request": 2,   "question": 3,  "done": 5,  "error": 0,   "agent": 0,  "info": 0 }
}
```

- **Windows**: run `~/.kimi/notify/modifica-configurazione.cmd` to open it in Notepad
- Changes apply from the next notification — no restart needed
- Reinstalling does NOT overwrite your `config.json`

## Preview the sounds

- **Windows**: `~/.kimi/notify/prova-notifiche.cmd` (all) or `prova-notifiche.cmd question` (single category; categories: `request`, `question`, `done`, `error`, `agent`, `info`)
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
