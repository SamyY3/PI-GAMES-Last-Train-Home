#!/usr/bin/env python3
"""
Trilha dos créditos de LAST TRAIN HOME: "A Caminho de Casa".
Chiptune nostálgico em Dó maior, 84 BPM, 32 compassos (~91 s), em loop perfeito.

Vozes: melodia (pulso 25% com vibrato tardio), contracanto (pulso 12,5% suave),
arpejo de acordes, baixo (triângulo) e percussão leve (bumbo, caixa de ruído, chimbal).
Forma: A (8) · A' (8) · B (8, sobe para Lá menor/Fá) · A'' (8, final e volta ao início).

Saída: assets/audio/music/credits.wav (mono 16-bit 44,1 kHz)
"""

import os
import wave
import numpy as np

SR = 44100
BPM = 84
BEAT = 60.0 / BPM
BAR = BEAT * 4
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio", "music", "credits.wav")

NOTE = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def hz(name: str) -> float:
    """'C4', 'G#3'... -> frequência"""
    pitch, octave = name[:-1], int(name[-1])
    midi = 12 * (octave + 1) + NOTE[pitch]
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


# ---------------------------------------------------------------- osciladores
def pulse(freq: np.ndarray, duty: float) -> np.ndarray:
    ph = np.cumsum(freq) / SR
    return np.where((ph % 1.0) < duty, 1.0, -1.0)


def triangle(freq: np.ndarray) -> np.ndarray:
    ph = np.cumsum(freq) / SR
    return 2.0 * np.abs(2.0 * (ph % 1.0) - 1.0) - 1.0


def env(n: int, a: float, d: float, s: float, r: float) -> np.ndarray:
    e = np.full(n, s, dtype=np.float64)
    a_n, d_n, r_n = int(a * SR), int(d * SR), int(r * SR)
    a_n = min(a_n, n)
    e[:a_n] = np.linspace(0.0, 1.0, a_n, endpoint=False)
    d_end = min(n, a_n + d_n)
    e[a_n:d_end] = np.linspace(1.0, s, d_end - a_n, endpoint=False)
    if 0 < r_n < n:
        e[-r_n:] *= np.linspace(1.0, 0.0, r_n)
    return e


def note(freq_hz: float, dur: float, kind: str, vol: float, vibrato: bool = False) -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = np.full(n, freq_hz)
    if vibrato:
        depth = np.clip((t - 0.25) / 0.3, 0.0, 1.0) * 0.012
        f = f * (1.0 + depth * np.sin(2 * np.pi * 5.5 * t))
    if kind == "lead":
        w = pulse(f, 0.25)
        e = env(n, 0.008, 0.12, 0.7, min(0.08, dur * 0.3))
    elif kind == "counter":
        w = pulse(f, 0.125)
        e = env(n, 0.02, 0.2, 0.5, min(0.1, dur * 0.4))
    elif kind == "arp":
        w = pulse(f, 0.5)
        e = env(n, 0.003, 0.05, 0.25, min(0.03, dur * 0.3))
    else:  # bass
        w = triangle(f)
        e = env(n, 0.005, 0.1, 0.8, min(0.05, dur * 0.2))
    return w * e * vol


def place(track: np.ndarray, start: float, samples: np.ndarray) -> None:
    i = int(start * SR)
    j = min(len(track), i + len(samples))
    track[i:j] += samples[: j - i]


# ---------------------------------------------------------------- percussão
rng = np.random.default_rng(7)


def kick() -> np.ndarray:
    n = int(0.18 * SR)
    t = np.arange(n) / SR
    f = 120 * np.exp(-t * 28) + 42
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 18)


def snare() -> np.ndarray:
    n = int(0.16 * SR)
    t = np.arange(n) / SR
    nz = rng.uniform(-1, 1, n)
    nz = nz - np.concatenate(([0.0], nz[:-1])) * 0.6  # leve passa-alta
    return nz * np.exp(-t * 22) * 0.6 + np.sin(2 * np.pi * 190 * t) * np.exp(-t * 30) * 0.3


def hat() -> np.ndarray:
    n = int(0.04 * SR)
    nz = rng.uniform(-1, 1, n)
    nz = nz - np.concatenate(([0.0], nz[:-1]))
    return nz * np.exp(-np.arange(n) / SR * 90) * 0.35


# ---------------------------------------------------------------- composição
# acordes por compasso (fundamental do baixo, notas do arpejo)
CH = {
    "C": ("C2", ["C4", "E4", "G4", "C5"]),
    "G/B": ("B1", ["B3", "D4", "G4", "B4"]),
    "G": ("G1", ["B3", "D4", "G4", "D5"]),
    "Am": ("A1", ["A3", "C4", "E4", "A4"]),
    "Em": ("E2", ["B3", "E4", "G4", "B4"]),
    "F": ("F1", ["A3", "C4", "F4", "A4"]),
    "Dm": ("D2", ["A3", "D4", "F4", "A4"]),
    "Fm": ("F1", ["G#3", "C4", "F4", "G#4"]),
    "Gsus": ("G1", ["C4", "D4", "G4", "C5"]),
}
PROG = (
    ["C", "G/B", "Am", "F", "C", "G/B", "F", "G"] +        # A
    ["C", "G/B", "Am", "Em", "F", "C", "Dm", "G"] +         # A'
    ["Am", "F", "C", "G", "Am", "F", "Fm", "Gsus"] +        # B
    ["C", "G/B", "Am", "F", "C", "G/B", "F", "Gsus"]        # A'' (Gsus prepara o loop)
)

# melodia: (nota ou None, duração em batidas) — 4 batidas por compasso
A = [
    ("E5", 1.5), ("D5", 0.5), ("C5", 1), ("G4", 1),
    ("D5", 1.5), ("C5", 0.5), ("B4", 2),
    ("C5", 1), ("E5", 1), ("A5", 1.5), ("G5", 0.5),
    ("F5", 1), ("E5", 1), ("C5", 2),
    ("E5", 1.5), ("D5", 0.5), ("C5", 1), ("G4", 1),
    ("D5", 1), ("B4", 1), ("G4", 2),
    ("A4", 1), ("C5", 1), ("F5", 1.5), ("E5", 0.5),
    ("D5", 3), (None, 1),
]
A2 = A[:14] + [  # 4 primeiros compassos de A + 4 novos
    ("C5", 1), ("D5", 1), ("E5", 1), ("G5", 1),
    ("A5", 1.5), ("G5", 0.5), ("F5", 1), ("A4", 1),
    ("E5", 1.5), ("D5", 0.5), ("C5", 2),
    ("D5", 2), ("B4", 1), ("G4", 1),
]
B = [
    ("A4", 1), ("C5", 1), ("E5", 1), ("A5", 1),
    ("G5", 1.5), ("F5", 0.5), ("C5", 2),
    ("E5", 1), ("G5", 1), ("C6", 1.5), ("B5", 0.5),
    ("A5", 1), ("G5", 1), ("D5", 2),
    ("A4", 1), ("C5", 1), ("E5", 1), ("A5", 1),
    ("C6", 1.5), ("A5", 0.5), ("F5", 2),
    ("G#5", 1.5), ("F5", 0.5), ("C5", 2),
    ("D5", 2), ("G5", 2),
]
A3 = A[:21] + [  # 6 primeiros compassos de A + final novo
    ("A4", 1), ("C5", 1), ("F5", 1.5), ("A5", 0.5),
    ("G5", 2), ("D5", 1), (None, 1),
]
MELODY = A + A2 + B + A3

# contracanto: notas longas uma terça/sexta abaixo, só em A' e A''
COUNTER = {8 + i: n for i, n in enumerate(["G4", "G4", "E4", "B4", "A4", "G4", "F4", "B4"])}
COUNTER.update({24 + i: n for i, n in enumerate(["G4", "D4", "E4", "C4", "E4", "D4", "C4", "B3"])})

total = len(PROG) * BAR
mix = np.zeros(int(total * SR) + SR)

# melodia
t = 0.0
for n, beats in MELODY:
    dur = beats * BEAT
    if n is not None:
        place(mix, t, note(hz(n), dur * 0.95, "lead", 0.16, vibrato=beats >= 1.5))
    t += dur
assert abs(t - total) < 1e-6, (t, total)

for bar, name in enumerate(PROG):
    t0 = bar * BAR
    root, arp = CH[name]
    # baixo: fundamental nas batidas 1 e 3, oitava na 2 e 4 (nos compassos B fica mais cheio)
    for b in range(4):
        f = hz(root) * (2.0 if b % 2 else 1.0)
        place(mix, t0 + b * BEAT, note(f, BEAT * 0.9, "bass", 0.22))
    # arpejo em colcheias (sobe e desce)
    order = [0, 1, 2, 3, 2, 1, 2, 3]
    for k, idx in enumerate(order):
        place(mix, t0 + k * BEAT / 2, note(hz(arp[idx]), BEAT / 2 * 0.9, "arp", 0.05))
    if bar in COUNTER:
        place(mix, t0, note(hz(COUNTER[bar]), BAR * 0.95, "counter", 0.06))
    # percussão: entra no compasso 4 (intro só com melodia, arpejo e baixo)
    if bar >= 4:
        place(mix, t0, kick() * 0.5)
        place(mix, t0 + 2 * BEAT, kick() * 0.4)
        place(mix, t0 + 1 * BEAT, snare() * 0.25)
        place(mix, t0 + 3 * BEAT, snare() * 0.25)
        for k in range(8):
            place(mix, t0 + k * BEAT / 2, hat() * (0.18 if k % 2 else 0.1))

# o que vaza depois do último compasso volta para o início (loop sem emenda)
tail = mix[int(total * SR):]
mix = mix[: int(total * SR)]
mix[: len(tail)] += tail

# eco suave (reverb barato) para o clima de lembrança
delay = int(BEAT * 0.75 * SR)
wet = np.zeros_like(mix)
wet[delay:] = mix[:-delay] * 0.22
mix = mix + wet

mix = mix / max(1e-6, np.max(np.abs(mix))) * 0.85
pcm = (mix * 32767).astype(np.int16)
with wave.open(OUT, "wb") as wf:
    wf.setnchannels(1)
    wf.setsampwidth(2)
    wf.setframerate(SR)
    wf.writeframes(pcm.tobytes())
print("[OK] %s — %.1f s" % (OUT, len(mix) / SR))
