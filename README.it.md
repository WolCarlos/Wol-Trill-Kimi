# Wol-Trill-Kimi

[🇬🇧 **English**](README.md) | [🇮🇹 **Italiano**](README.it.md)

Notifiche **sonore e visive** per [Kimi Code](https://github.com/MoonshotAI/kimi-cli) (estensione VS Code e CLI), per **Windows**, **macOS** e **Linux**.

Sai quando Kimi ti chiede un permesso, ti fa una domanda o finisce il lavoro — anche se sei su un'altra finestra.

## Come funziona

Wol-Trill-Kimi usa gli [hook nativi di Kimi Code](https://moonshotai.github.io/kimi-cli/en/customization/hooks.html) (`~/.kimi/config.toml`). A ogni evento parte un **suono in loop** che si ripete finché:

- **rispondi a Kimi** (scrivi un prompt, approvi/neghi un tool), oppure
- **lo fermi manualmente** con lo script di stop, oppure
- scade il timeout di sicurezza (15 minuti).

**Un solo loop alla volta**: ogni nuova notifica sopprime quella precedente.

## Suoni

| Categoria | Evento | Suono | Loop |
|---|---|---|---|
| 🔴 `request` | Permesso richiesto | 4 bip rapidi altissimi | ogni 2s |
| 🟡 `question` | Kimi ti fa una domanda | due toni ascendenti | ogni 3s |
| 🟢 `done` | Turno completato | arpeggio ascendente | ogni 5s |
| ⛔ `error` | Turno fallito / task background fallito | sweep discendente | singolo |
| 🤖 `agent` | Subagent completato | doppio blip acuto | singolo |
| ℹ️ `info` | Altre notifiche (es. task background completato) | ping singolo morbido | singolo |

Anti-spam: il `Stop` di Kimi può scattare a metà lavoro → la notifica "done" viene soppressa se ne è partita un'altra da meno di 60s senza un tuo prompt in mezzo.

## Installazione

### Windows
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File install.ps1
```

### macOS
```bash
bash install.sh
```

L'installer:
1. copia script e suoni in `~/.kimi/notify/`
2. aggiunge gli hook a `~/.kimi/config.toml` (backup automatico, blocco marcato idempotente `# >>> WOL-TRILL-KIMI >>>`)
3. *(solo Windows)* crea sul Desktop il collegamento **STOP Kimi Notifiche**

**Riavvia Kimi Code** dopo l'installazione per caricare gli hook.

## Fermare un suono in loop

- **Clicca la toast — il tasto "Ferma suono" o il corpo della notifica** (funziona anche dal Centro notifiche; usa il protocollo `woltrillkimi://stop`)
- **Rispondi a Kimi** (prompt o click su approva/nega) → si ferma da solo
- **Windows**: doppio click su `STOP Kimi Notifiche` sul Desktop (o esegui `~/.kimi/notify/stop-notifica.cmd`)
- **macOS**: esegui `~/.kimi/notify/stop-notifica.sh`

Nota: chiudere la toast (o cliccare sul suo corpo) NON ferma il suono — usa il tasto o uno dei metodi sopra.

## Dashboard impostazioni (Windows)

Doppio click su **`Wol-Trill-Kimi Impostazioni`** sul Desktop (oppure esegui `~/.kimi/notify/dashboard.cmd`): interfaccia grafica scura con:

- **Slider volume + numero** per categoria (0-100, indipendente per suono)
- **Intervallo di ripetizione** per categoria (secondi, 0 = colpo singolo)
- **Suoni personalizzati**: trascina un file audio (.wav .mp3 .m4a .aac .ogg) sulla card, oppure usa il tasto cartella per sfogliare — salvati in `sounds/custom/`, ripristinabili con il tasto ↺
- **▶ Test** per suono, **Ferma suoni**, **Ripristina default**, **Salva** (scrive `config.json`, vale dalla prossima notifica)

### Note Linux

`kimi-notify.sh` rileva automaticamente il player audio (`afplay`, `ffplay`, `play`/sox, `paplay`, `aplay`) e il notificatore visivo (`osascript` su macOS, `notify-send` su Linux). Niente dashboard su macOS/Linux: modifica direttamente `~/.kimi/notify/config.json`.

## Configurazione (volumi e intervalli)

Ogni categoria ha il suo **volume** (0–100, per categoria, indipendente dal volume delle notifiche di Windows) e il suo **intervallo** (secondi tra una ripetizione e l'altra, `0` = colpo singolo) in `~/.kimi/notify/config.json`:

```json
{
  "volume":   { "request": 100, "question": 90, "done": 70, "error": 100, "agent": 60, "info": 50 },
  "interval": { "request": 2,   "question": 3,  "done": 5,  "error": 0,   "agent": 0,  "info": 0 }
}
```

- **Windows**: esegui `~/.kimi/notify/modifica-configurazione.cmd` per aprirlo in Blocco note (oppure usa la dashboard impostazioni qui sopra)
- Le modifiche valgono dalla prossima notifica — nessun riavvio necessario
- La reinstallazione NON sovrascrive il tuo `config.json`

## Provare i suoni

- **Windows**: `~/.kimi/notify/prova-notifiche.cmd` (tutti) oppure `prova-notifiche.cmd question` (singolo; categorie: `request`, `question`, `done`, `error`, `agent`, `info`)
- I WAV si rigenerano/modificano con `python tools/generate-sounds.py`

## Disinstallazione

- **Windows**: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File uninstall.ps1`
- **macOS**: `bash uninstall.sh`

## Struttura

```
src/
  kimi-notify.ps1       # motore notifiche (Windows)
  kimi-notify-loop.ps1  # loop sonoro in background (Windows)
  kimi-notify.sh        # motore + loop (macOS)
  dashboard.ps1 / .cmd / .vbs  # GUI impostazioni (Windows)
  stop-notifica.cmd     # stop manuale (Windows)
  stop-notifica.sh      # stop manuale (macOS)
  prova-notifiche.cmd   # prova i suoni (Windows)
sounds/                 # WAV delle 5 categorie
tools/generate-sounds.py
install.* / uninstall.*
```

## Note

- Richiede Kimi Code con supporto hooks (Beta). Gli hook girano nello stesso shell di Kimi (Git Bash su Windows, bash su macOS).
- Su Windows i suoni vengono riprodotti direttamente (`System.Media.SoundPlayer`): non dipendono da Focus Assist né dalle impostazioni delle notifiche.
- Su macOS i suoni usano `afplay` e le notifiche visive `osascript`.

## Licenza

MIT
