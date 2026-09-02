# Genera i WAV delle notifiche di Kimi Code (acuti, volume alto, 44.1kHz mono 16-bit)
import math, wave, struct, os

SR = 44100
AMP = 0.95
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sounds")
os.makedirs(OUT, exist_ok=True)

def tone(freq, ms, fade=6):
    n = int(SR * ms / 1000)
    f = int(SR * fade / 1000)
    out = []
    for i in range(n):
        env = 1.0
        if i < f:
            env = i / f
        elif i > n - f:
            env = (n - i) / f
        out.append(AMP * env * math.sin(2 * math.pi * freq * i / SR))
    return out

def silence(ms):
    return [0.0] * int(SR * ms / 1000)

def sweep(f1, f2, ms):
    n = int(SR * ms / 1000)
    return [AMP * math.sin(2 * math.pi * (f1 + (f2 - f1) * i / n) * i / SR) for i in range(n)]

def save(name, samples):
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in samples))
    print("creato:", path)

# RICHIESTA (permesso): allarme urgente — 4 bip rapidi altissimi (G6=1568Hz)
save("richiesta.wav", sum([[ *tone(1568, 110), *silence(70)] for _ in range(4)], []))

# DOMANDA: due toni ascendenti ripetuti (E6->A6), interpellativo
save("domanda.wav", (tone(1319, 140) + tone(1760, 200) + silence(150)) * 2)

# FATTO (fine task): arpeggio ascendente brillante C6-E6-G6-C7
save("fatto.wav", tone(1047, 120) + tone(1319, 120) + tone(1568, 120) + tone(2093, 350))

# ERRORE: sweep discendente
save("errore.wav", sweep(900, 300, 450))

# AGENTE (subagent completato): doppio blip acuto breve (C7=2093Hz)
save("agente.wav", (tone(2093, 80) + silence(60)) * 2)
