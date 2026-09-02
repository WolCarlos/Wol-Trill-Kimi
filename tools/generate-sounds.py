# Generates the notification WAVs for Wol-Trill-Kimi (high-pitched, loud, 44.1kHz mono 16-bit)
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
    print("created:", path)

# REQUEST (permission): urgent alarm — 4 rapid high-pitched beeps (G6=1568Hz)
save("request.wav", sum([[ *tone(1568, 110), *silence(70)] for _ in range(4)], []))

# QUESTION: rising two-tone repeated (E6->A6), inquisitive
save("question.wav", (tone(1319, 140) + tone(1760, 200) + silence(150)) * 2)

# DONE (work finished): bright rising arpeggio C6-E6-G6-C7
save("done.wav", tone(1047, 120) + tone(1319, 120) + tone(1568, 120) + tone(2093, 350))

# ERROR: descending sweep
save("error.wav", sweep(900, 300, 450))

# AGENT (subagent completed): short double high blip (C7=2093Hz)
save("agent.wav", (tone(2093, 80) + silence(60)) * 2)
