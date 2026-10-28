#!/usr/bin/env python3
"""
Trilhas chiptune de LAST TRAIN HOME (menu, embarque, vagões, cabine, chefe, desarme e final).

Cada faixa tem tonalidade, andamento, progressão, levada de bateria e timbres próprios.
A melodia é composta a partir de motivos de dois compassos (forma A A' B C ...) que se
encaixam nas notas do acorde de cada compasso, então a mesma ideia ganha cores diferentes.

Os vagões também geram uma camada calma (<nome>_calm.wav) com o mesmo tamanho e andamento:
o jogo toca as duas juntas e alterna entre elas conforme há inimigos na tela.

Saída: assets/audio/music/*.wav (mono 16-bit 32 kHz, em loop perfeito).
A trilha dos créditos fica em tools/generate_credits_music.py.
"""

import os
import wave
import numpy as np
from scipy.signal import butter, lfilter

SR = 32000
OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio", "music")

PC = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
      "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}
QUALITY = {"": [0, 4, 7], "m": [0, 3, 7], "dim": [0, 3, 6], "sus4": [0, 5, 7], "7": [0, 4, 7, 10],
           "m7": [0, 3, 7, 10], "maj7": [0, 4, 7, 11], "aug": [0, 4, 8]}
SCALE = {"minor": [0, 2, 3, 5, 7, 8, 10], "harmonic": [0, 2, 3, 5, 7, 8, 11], "dorian": [0, 2, 3, 5, 7, 9, 10],
         "phrygian": [0, 1, 3, 5, 7, 8, 10], "major": [0, 2, 4, 5, 7, 9, 11]}

RHYTHMS = {
    "calm": [[4, 4, 8], [6, 2, 8], [4, 4, 4, 4], [8, 4, 4], [4, 2, 2, 8], [6, 2, 4, 4]],
    "drive": [[2, 2, 4, 2, 2, 4], [4, 2, 2, 4, 4], [3, 3, 2, 4, 4], [2, 2, 2, 2, 8], [6, 2, 4, 4], [4, 4, 2, 2, 4]],
    "fast": [[2, 2, 2, 2, 2, 2, 4], [1, 1, 2, 2, 2, 4, 4], [2, 2, 4, 2, 2, 4], [3, 3, 2, 2, 2, 4], [2, 1, 1, 4, 2, 2, 4]],
    "synco": [[3, 3, 2, 3, 3, 2], [2, 1, 3, 2, 4, 4], [3, 3, 4, -2, 4], [2, 2, 3, 3, 6], [3, 1, 4, 3, 1, 4]],
    "sparse": [[8, 8], [12, -4], [4, -4, 8], [6, 2, -8], [4, 4, 8]],
}
CADENCE = {"calm": [[8, 8], [4, 12]], "drive": [[4, 4, 8], [2, 2, 12]], "fast": [[2, 2, 4, 8], [4, 12]],
           "synco": [[3, 3, 10], [6, 10]], "sparse": [[16], [4, 12]]}

BASS = {
    "root8": [(0, 2, "r"), (2, 2, "r"), (4, 2, "o"), (6, 2, "r"), (8, 2, "r"), (10, 2, "r"), (12, 2, "o"), (14, 2, "5")],
    "octave8": [(i * 2, 2, "r" if i % 2 == 0 else "o") for i in range(8)],
    "half": [(0, 8, "r"), (8, 8, "5")],
    "whole": [(0, 16, "r")],
    "walk": [(0, 4, "r"), (4, 4, "5"), (8, 4, "o"), (12, 4, "5")],
    "funk16": [(0, 3, "r"), (3, 1, "o"), (4, 2, "r"), (6, 2, "5"), (8, 3, "r"), (11, 1, "r"), (12, 2, "o"), (14, 2, "5")],
    "heavy": [(0, 6, "r"), (6, 2, "r"), (8, 4, "r"), (12, 2, "5"), (14, 2, "o")],
    "pulse16": [(i, 1, "r") for i in range(16)],
    "gallop": [(i * 4 + k, l, "r" if k < 3 else "o") for i in range(4) for k, l in ((0, 2), (2, 1), (3, 1))],
    "heart": [(0, 2, "r"), (3, 2, "r"), (8, 2, "r"), (11, 2, "r")],
}


def midi_hz(m: float) -> float:
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def parse_chord(sym: str) -> tuple[int, list[int]]:
    root = sym[:2] if len(sym) > 1 and sym[1] in "#b" else sym[:1]
    return PC[root], QUALITY[sym[len(root):]]


# ---------------------------------------------------------------- timbres
rng_noise = np.random.default_rng(11)


def osc(kind: str, freq: np.ndarray, duty: float = 0.5) -> np.ndarray:
    ph = np.cumsum(freq) / SR
    if kind == "tri":
        return 2.0 * np.abs(2.0 * (ph % 1.0) - 1.0) - 1.0
    if kind == "saw":
        return 2.0 * (ph % 1.0) - 1.0
    return np.where((ph % 1.0) < duty, 1.0, -1.0)


def env(n: int, a: float, d: float, s: float, r: float) -> np.ndarray:
    e = np.full(n, s, dtype=np.float64)
    a_n = min(int(a * SR), n)
    d_n = int(d * SR)
    r_n = int(r * SR)
    e[:a_n] = np.linspace(0.0, 1.0, a_n, endpoint=False)
    d_end = min(n, a_n + d_n)
    e[a_n:d_end] = np.linspace(1.0, s, d_end - a_n, endpoint=False)
    if 0 < r_n < n:
        e[-r_n:] *= np.linspace(1.0, 0.0, r_n)
    return e


def tone(m: float, dur: float, kind: str, duty: float, vol: float, adsr: tuple, vibrato: float = 0.0,
         slide_from: float | None = None) -> np.ndarray:
    n = max(1, int(dur * SR))
    t = np.arange(n) / SR
    f = np.full(n, midi_hz(m))
    if slide_from is not None:
        k = np.clip(t / 0.04, 0.0, 1.0)
        f = midi_hz(slide_from) * (1.0 - k) + f * k
    if vibrato > 0.0:
        depth = np.clip((t - 0.18) / 0.25, 0.0, 1.0) * vibrato
        f = f * (1.0 + depth * np.sin(2 * np.pi * 5.5 * t))
    a, d, s, r = adsr
    return osc(kind, f, duty) * env(n, a, d, s, min(r, dur * 0.4)) * vol


def noise(n: int, hp: float = 0.0) -> np.ndarray:
    nz = rng_noise.uniform(-1.0, 1.0, n)
    if hp > 0.0:
        nz = nz - np.concatenate(([0.0], nz[:-1])) * hp
    return nz


def drum(name: str) -> np.ndarray:
    if name == "kick":
        n = int(0.16 * SR)
        t = np.arange(n) / SR
        f = 130 * np.exp(-t * 30) + 45
        return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 16)
    if name == "snare":
        n = int(0.15 * SR)
        t = np.arange(n) / SR
        return noise(n, 0.6) * np.exp(-t * 22) * 0.6 + np.sin(2 * np.pi * 185 * t) * np.exp(-t * 30) * 0.35
    if name == "hat":
        n = int(0.035 * SR)
        return noise(n, 1.0) * np.exp(-np.arange(n) / SR * 100) * 0.35
    if name == "ohat":
        n = int(0.16 * SR)
        return noise(n, 1.0) * np.exp(-np.arange(n) / SR * 18) * 0.28
    if name == "chug":
        n = int(0.07 * SR)
        t = np.arange(n) / SR
        return noise(n, 0.85) * np.exp(-t * 45) * (1.0 - np.exp(-t * 400)) * 0.45
    if name == "tick":
        n = int(0.03 * SR)
        t = np.arange(n) / SR
        return np.sign(np.sin(2 * np.pi * 2400 * t)) * np.exp(-t * 160) * 0.25
    if name == "steam":
        n = int(0.5 * SR)
        t = np.arange(n) / SR
        return noise(n, 0.95) * np.minimum(1.0, t / 0.05) * np.exp(-t * 5) * 0.3
    if name == "crash":
        n = int(0.9 * SR)
        t = np.arange(n) / SR
        return noise(n, 0.9) * np.exp(-t * 4.5) * 0.35
    if name == "tom":
        n = int(0.18 * SR)
        t = np.arange(n) / SR
        f = 160 * np.exp(-t * 10) + 80
        return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 14) * 0.8
    raise ValueError(name)


DRUM_CACHE = {k: drum(k) for k in ("kick", "snare", "hat", "ohat", "chug", "tick", "steam", "crash", "tom")}
ACCENT = {"X": 1.0, "x": 0.75, "o": 0.45}


def place(buf: np.ndarray, start: float, samples: np.ndarray) -> None:
    i = int(start * SR)
    j = min(len(buf), i + len(samples))
    if j > i:
        buf[i:j] += samples[: j - i]


# ---------------------------------------------------------------- composição
class Track:
    def __init__(self, spec: dict):
        self.s = spec
        self.bpm = spec["bpm"]
        self.step = 60.0 / self.bpm / 4.0
        self.bar = self.step * 16
        self.chords = [parse_chord(c) for c in spec["chords"]]
        self.bars = len(self.chords)
        self.total = self.bars * self.bar
        self.n = int(round(self.total * SR))
        self.key = PC[spec["key"]]
        self.scale = SCALE[spec["scale"]]
        self.rng = np.random.default_rng(spec["seed"])

    def buf(self) -> np.ndarray:
        return np.zeros(self.n + 2 * SR)

    # ---- melodia
    def degree_midi(self, d: int) -> int:
        base = 12 * (self.s["lead_oct"] + 1) + self.key
        return base + self.scale[d % 7] + 12 * (d // 7)

    def snap(self, m: int, chord: tuple[int, list[int]], avoid: int | None = None) -> int:
        root, ivs = chord
        pcs = {(root + i) % 12 for i in ivs}
        for off in (0, -1, 1, -2, 2, -3, 3, -4, 4):
            if (m + off) % 12 in pcs and (off == 0 or m + off != avoid):
                return m + off
        return m

    def motif_bar(self, style: str, start_deg: int, cadence: bool = False) -> list[tuple[int, int | None]]:
        cells = CADENCE[style] if cadence else RHYTHMS[style]
        rhythm = cells[self.rng.integers(len(cells))]
        lo, hi = self.s.get("lead_range", (-2, 9))
        notes = []
        d = start_deg
        for i, dur in enumerate(rhythm):
            if dur < 0:
                notes.append((-dur, None))
                continue
            if i > 0:
                d += int(self.rng.choice([-2, -1, -1, 1, 1, 2, 0, 3, -3], p=[.11, .21, .1, .21, .1, .11, .02, .07, .07]))
                if d > hi or d < lo:
                    d = int(np.clip(d, lo, hi)) - int(np.sign(d - (lo + hi) / 2)) * 2
            notes.append((dur, d))
        if cadence:
            notes[-1] = (notes[-1][0], 0 if self.rng.random() < 0.6 else 4)
        return notes

    def melody(self) -> list[tuple[int, int, int | None]]:
        style = self.s["rhythm"]
        motifs: dict[str, list] = {}
        out = []
        for idx, label in enumerate(self.s["form"]):
            if label not in motifs:
                base = label.rstrip("0123456789")
                if base != label and base in motifs:
                    first = motifs[base][0]
                    last_deg = next((d for _, d in reversed(first) if d is not None), 2)
                    motifs[label] = [first, self.motif_bar(style, last_deg)]
                elif label == "E":
                    a = motifs.get("A")
                    first = a[0] if a else self.motif_bar(style, 4)
                    motifs[label] = [first, self.motif_bar(style, 2, cadence=True)]
                else:
                    start = int(self.rng.choice([0, 2, 4, 5, 7]))
                    b1 = self.motif_bar(style, start)
                    last_deg = next((d for _, d in reversed(b1) if d is not None), start)
                    motifs[label] = [b1, self.motif_bar(style, last_deg)]
            prev = None
            for k in range(2):
                bar = idx * 2 + k
                pos = 0
                for dur, d in motifs[label][k]:
                    if d is None:
                        out.append((bar * 16 + pos, dur, None))
                    else:
                        m = self.degree_midi(d)
                        if pos in (0, 8) or dur >= 6:
                            m = self.snap(m, self.chords[bar % self.bars], avoid=prev)
                        out.append((bar * 16 + pos, dur, m))
                        prev = m
                    pos += dur
        return out

    def render_lead(self) -> np.ndarray:
        b = self.buf()
        if "form" not in self.s:
            return b
        kind = self.s.get("lead_wave", "pulse")
        duty = self.s.get("lead_duty", 0.25)
        vol = self.s.get("lead_vol", 0.16)
        prev = None
        for step, dur, m in self.melody():
            if m is None:
                prev = None
                continue
            d = dur * self.step
            slide = prev if self.s.get("lead_slide") and prev is not None and abs(prev - m) <= 4 else None
            place(b, step * self.step, tone(m, d * 0.92, kind, duty, vol, (0.006, 0.1, 0.7, 0.06),
                                            vibrato=0.012 if dur >= 6 else 0.0, slide_from=slide))
            if self.s.get("lead_double"):
                place(b, step * self.step, tone(m - 12, d * 0.92, "pulse", 0.5, vol * 0.45, (0.006, 0.1, 0.6, 0.05)))
            prev = m
        echo = self.s.get("echo", 0.25)
        if echo > 0:
            delay = int(self.step * 3 * SR)
            wet = np.zeros_like(b)
            wet[delay:] = b[:-delay] * echo
            wet[2 * delay:] += b[:-2 * delay] * echo * 0.5
            b += wet
        return b

    # ---- acompanhamento
    def bass_midi(self, chord: tuple[int, list[int]], which: str) -> int:
        root, ivs = chord
        r = 36 + root if root <= 7 else 24 + root
        r += 12 * self.s.get("bass_shift", 0)
        if which == "o":
            return r + 12
        if which == "5":
            return r + ivs[2]
        return r

    def render_bass(self, style: str, vol: float) -> np.ndarray:
        b = self.buf()
        kind = self.s.get("bass_wave", "tri")
        for bar, ch in enumerate(self.chords):
            for st, ln, which in BASS[style]:
                d = ln * self.step
                place(b, bar * self.bar + st * self.step,
                      tone(self.bass_midi(ch, which), d * 0.88, kind, 0.5, vol, (0.004, 0.06, 0.8, 0.03)))
        return b

    def render_arp(self, vol: float) -> np.ndarray:
        b = self.buf()
        if "arp" not in self.s:
            return b
        pattern, rate = self.s["arp"]
        oct_ = self.s.get("arp_oct", 4)
        for bar, (root, ivs) in enumerate(self.chords):
            base = 12 * (oct_ + 1) + root
            tones = [base + i for i in ivs[:3]] + [base + 12]
            k = 0
            for st in range(0, 16, rate):
                idx = pattern[k % len(pattern)]
                k += 1
                if idx is None:
                    continue
                place(b, bar * self.bar + st * self.step,
                      tone(tones[idx], rate * self.step * 0.8, "pulse", self.s.get("arp_duty", 0.5), vol,
                           (0.002, 0.04, 0.3, 0.02)))
        return b

    def render_pad(self, vol: float) -> np.ndarray:
        b = self.buf()
        oct_ = self.s.get("pad_oct", 4)
        for bar, (root, ivs) in enumerate(self.chords):
            base = 12 * (oct_ + 1) + root
            for i in ivs[:3]:
                m = base + i
                if m > 12 * (oct_ + 1) + 7:
                    m -= 12
                for det in (-0.06, 0.06):
                    place(b, bar * self.bar,
                          tone(m + det, self.bar, "pulse", 0.125, vol / 2, (0.25, 0.3, 0.75, 0.3)))
        return b

    def render_drums(self, kit: dict, vol: float) -> np.ndarray:
        b = self.buf()
        fill = self.s.get("fill")
        for bar in range(self.bars):
            use = dict(kit)
            if fill and bar % 4 == 3:
                use.update(fill)
            for inst, pat in use.items():
                if isinstance(pat, list):
                    pat = pat[bar % len(pat)]
                for st, ch in enumerate(pat):
                    if ch in ACCENT:
                        place(b, bar * self.bar + st * self.step, DRUM_CACHE[inst] * ACCENT[ch] * vol)
            if self.s.get("crash") and bar % 8 == 0:
                place(b, bar * self.bar, DRUM_CACHE["crash"] * vol)
        return b

    # ---- mixagem
    def finish(self, b: np.ndarray, rms_db: float) -> np.ndarray:
        tail = b[self.n:]
        b = b[: self.n].copy()
        b[: len(tail)] += tail
        bb, aa = butter(1, 9000 / (SR / 2))
        b = lfilter(bb, aa, np.concatenate((b[-2048:], b)))[2048:]
        b = b * (10 ** (rms_db / 20) / max(1e-9, np.sqrt(np.mean(b ** 2))))
        return np.tanh(b / 0.9) * 0.9

    def render(self) -> dict[str, np.ndarray]:
        s = self.s
        out = {}
        full = (self.render_lead() + self.render_arp(s.get("arp_vol", 0.05))
                + self.render_bass(s["bass"], s.get("bass_vol", 0.22))
                + self.render_drums(s.get("drums", {}), s.get("drum_vol", 0.5)))
        if s.get("pad_vol"):
            full += self.render_pad(s["pad_vol"])
        out[s["name"]] = self.finish(full, s.get("rms_db", -15.0))
        if "calm" in s:
            c = s["calm"]
            calm = (self.render_pad(c.get("pad_vol", 0.06)) + self.render_bass(c["bass"], c.get("bass_vol", 0.16))
                    + self.render_arp(c.get("arp_vol", 0.0)) + self.render_drums(c.get("drums", {}), c.get("drum_vol", 0.3)))
            out[s["name"] + "_calm"] = self.finish(calm, -18.0)
        return out


# ---------------------------------------------------------------- faixas
TRACKS = [
    {   # menu: "A Última Plataforma" — melancólica, só arpejo e pulso de trem ao fundo
        "name": "menu", "key": "A", "scale": "harmonic", "bpm": 84, "seed": 3, "rms_db": -17.0,
        "chords": ["Am", "F", "C", "G", "Am", "F", "Dm", "E", "F", "G", "Em", "Am", "Dm", "Am", "F", "E"],
        "form": ["A", "A2", "B", "E"] * 2, "rhythm": "calm", "lead_oct": 4, "lead_duty": 0.25, "lead_vol": 0.15,
        "lead_slide": True, "echo": 0.3,
        "arp": ([0, 1, 2, 3, 2, 1, 2, 1], 2), "arp_vol": 0.05, "bass": "half", "bass_vol": 0.2, "pad_vol": 0.04,
        "drums": {"chug": "o.o.o.o.o.o.o.o."}, "drum_vol": 0.35,
    },
    {   # embarque: suspense, baixo pulsando como as rodas ganhando velocidade
        "name": "intro", "key": "D", "scale": "minor", "bpm": 100, "seed": 21,
        "chords": ["Dm", "Dm", "Bb", "A", "Dm", "Gm", "A", "A", "Bb", "C", "Dm", "Dm", "Gm", "Bb", "A", "A7"],
        "form": ["A", "B", "A2", "E", "A", "B2", "A2", "E"], "rhythm": "sparse", "lead_oct": 4, "lead_duty": 0.125,
        "lead_vol": 0.14, "echo": 0.35,
        "arp": ([0, None, 2, None, 1, None, 2, None], 2), "arp_vol": 0.04, "bass": "root8", "bass_vol": 0.2,
        "pad_vol": 0.05,
        "drums": {"chug": "x.o.x.o.x.o.x.o.", "kick": "x.......x.......", "tick": "....x.......x..."}, "drum_vol": 0.4,
    },
    {   # vagão 1 — passageiros: animada, rock de trem em Mi menor
        "name": "wagon_1", "key": "E", "scale": "minor", "bpm": 124, "seed": 104,
        "chords": ["Em", "C", "D", "Bm", "Em", "C", "Am", "B", "C", "D", "Bm", "Em", "Am", "C", "B", "B7"],
        "form": ["A", "A2", "B", "C", "A", "A2", "B2", "E"], "rhythm": "drive", "lead_oct": 4, "lead_duty": 0.25,
        "lead_vol": 0.15, "lead_slide": True,
        "arp": ([0, 1, 2, 1], 2), "arp_vol": 0.04, "bass": "octave8", "bass_vol": 0.22,
        "drums": {"kick": "x.......x.x.....", "snare": "....x.......x...", "chug": "o.x.o.x.o.x.o.x."},
        "fill": {"snare": "....x.......x.xx", "tom": "............x.x."}, "crash": True, "drum_vol": 0.5,
        "calm": {"bass": "half", "bass_vol": 0.16, "pad_vol": 0.06, "arp_vol": 0.025,
                 "drums": {"chug": "o...o...o...o..."}, "drum_vol": 0.35},
    },
    {   # vagão 2 — tubulações de vapor: dórico, sincopado, chiados de vapor
        "name": "wagon_2", "key": "D", "scale": "dorian", "bpm": 116, "seed": 222,
        "chords": ["Dm7", "G", "Dm7", "G", "Am7", "C", "G", "Dm", "Bb", "C", "Dm", "G", "Bb", "C", "A", "A7"],
        "form": ["A", "A2", "B", "C", "A", "A2", "B2", "E"], "rhythm": "synco", "lead_oct": 4, "lead_duty": 0.125,
        "lead_vol": 0.15, "echo": 0.2,
        "arp": ([0, 2, 1, 3], 1), "arp_vol": 0.025, "arp_oct": 5, "bass": "funk16", "bass_wave": "pulse",
        "bass_vol": 0.13,
        "drums": {"kick": "x..x......x.....", "snare": "....x..o....x...", "hat": "x.xxx.xxx.xxx.xx",
                  "steam": ["................", "..............x."]},
        "fill": {"snare": "....x..o..x.x.xx"}, "drum_vol": 0.5,
        "calm": {"bass": "whole", "bass_vol": 0.15, "pad_vol": 0.06,
                 "drums": {"hat": "..x...x...x...x.", "steam": ["................", "........x......."]},
                 "drum_vol": 0.3},
    },
    {   # vagão 3 — cargueiro: pesado, meio-tempo em Dó menor
        "name": "wagon_3", "key": "C", "scale": "minor", "bpm": 104, "seed": 333,
        "chords": ["Cm", "Ab", "Bb", "Cm", "Cm", "Ab", "Fm", "G", "Ab", "Bb", "Gm", "Cm", "Fm", "Ab", "G", "G7"],
        "form": ["A", "A2", "B", "C", "A", "A2", "B2", "E"], "rhythm": "drive", "lead_oct": 4, "lead_duty": 0.5,
        "lead_vol": 0.12, "lead_double": True, "echo": 0.15,
        "arp": ([0, None, 1, None, 2, None, 1, None], 2), "arp_vol": 0.03, "bass": "heavy", "bass_wave": "pulse",
        "bass_vol": 0.14, "bass_shift": -1,
        "drums": {"kick": "x.....x.x.......", "snare": "........x.......", "hat": "x.x.x.x.x.x.x.x.",
                  "chug": "....o.......o..."},
        "fill": {"tom": "..........x.x.x.", "snare": "........x.....x."}, "crash": True, "drum_vol": 0.55,
        "calm": {"bass": "whole", "bass_vol": 0.16, "pad_vol": 0.065,
                 "drums": {"kick": "x...............", "chug": "....o.......o..."}, "drum_vol": 0.35},
    },
    {   # vagão 4 — velocidade máxima: rápida, arpejo em semicolcheias
        "name": "wagon_4", "key": "F#", "scale": "harmonic", "bpm": 152, "seed": 404,
        "chords": ["F#m", "D", "E", "C#m", "F#m", "D", "E", "E", "D", "E", "F#m", "F#m", "Bm", "D", "C#", "C#7"],
        "form": ["A", "A2", "B", "C", "A", "A2", "B2", "E"], "rhythm": "fast", "lead_oct": 4, "lead_duty": 0.25,
        "lead_vol": 0.14, "echo": 0.15,
        "arp": ([0, 1, 2, 3, 2, 1], 1), "arp_vol": 0.03, "bass": "gallop", "bass_vol": 0.2,
        "drums": {"kick": "x.x.....x.x.....", "snare": "....x.......x...", "hat": "xoxoxoxoxoxoxoxo",
                  "chug": "o.o.o.o.o.o.o.o."},
        "fill": {"snare": "....x.......xxxx"}, "crash": True, "drum_vol": 0.5,
        "calm": {"bass": "octave8", "bass_vol": 0.13, "pad_vol": 0.055, "arp_vol": 0.018,
                 "drums": {"chug": "x.o.x.o.x.o.x.o."}, "drum_vol": 0.3},
    },
    {   # cabine da locomotiva: tensão antes do chefe, batida de coração
        "name": "cabin", "key": "G", "scale": "harmonic", "bpm": 72, "seed": 55, "rms_db": -17.0,
        "chords": ["Gm", "Eb", "Cm", "D", "Gm", "Eb", "Ab", "D"],
        "form": ["A", "B", "A2", "E"], "rhythm": "sparse", "lead_oct": 4, "lead_duty": 0.125, "lead_vol": 0.12,
        "echo": 0.4, "bass": "heart", "bass_vol": 0.22, "bass_shift": -1, "pad_vol": 0.07,
        "drums": {"kick": "x..x....x..x....", "tick": "x...x...x...x..."}, "drum_vol": 0.45,
    },
    {   # chefe, fases 1 e 2: "O Maquinista"
        "name": "boss_p1_p2", "key": "B", "scale": "harmonic", "bpm": 148, "seed": 777,
        "chords": ["Bm", "G", "A", "F#", "Bm", "G", "Em", "F#", "G", "A", "Bm", "Bm", "Em", "F#", "G", "F#7"],
        "form": ["A", "A2", "B", "C", "A", "A2", "B2", "E"], "rhythm": "drive", "lead_oct": 4, "lead_duty": 0.25,
        "lead_vol": 0.13, "lead_double": True, "lead_slide": True, "echo": 0.15,
        "arp": ([0, 2, 1, 3], 1), "arp_vol": 0.022, "bass": "pulse16", "bass_wave": "pulse", "bass_vol": 0.12,
        "drums": {"kick": "x...x...x...x...", "snare": "....x.......x...", "hat": "..x...x...x...x.",
                  "steam": ["................", "................", "................", "x..............."]},
        "fill": {"snare": "....x...x.x.xxxx", "tom": "..x.x..........."}, "crash": True, "drum_vol": 0.55,
    },
    {   # chefe, fase 3: "Caldeira em Chamas" — frígio, frenético
        "name": "boss_p3", "key": "E", "scale": "phrygian", "bpm": 168, "seed": 913,
        "chords": ["Em", "F", "Em", "F", "Em", "F", "G", "F", "Am", "G", "F", "E", "Am", "G", "F", "E7"],
        "form": ["A", "A2", "B", "C", "A", "A2", "B2", "E"], "rhythm": "fast", "lead_oct": 4, "lead_duty": 0.25,
        "lead_vol": 0.13, "lead_double": True, "echo": 0.12,
        "arp": ([0, 1, 2, 3, 2, 1, 0, 1], 1), "arp_vol": 0.025, "bass": "pulse16", "bass_wave": "saw",
        "bass_vol": 0.12,
        "drums": {"kick": "x.x.x.x.x.x.x.x.", "snare": "....x.......x...", "hat": "xxxxxxxxxxxxxxxx"},
        "fill": {"snare": "....x...xxxxxxxx"}, "crash": True, "drum_vol": 0.5,
    },
    {   # desarme: relógio tiquetaqueando e baixo nervoso
        "name": "disarm", "key": "A", "scale": "harmonic", "bpm": 132, "seed": 61,
        "chords": ["Am", "Am", "Bb", "Bb", "Am", "Am", "E", "E7"],
        "form": ["A", "B", "A2", "E"], "rhythm": "sparse", "lead_oct": 5, "lead_duty": 0.125, "lead_vol": 0.1,
        "echo": 0.3, "bass": "pulse16", "bass_wave": "pulse", "bass_vol": 0.1, "pad_vol": 0.05,
        "drums": {"tick": "x...x...x...x...", "kick": "x.......x.......", "hat": "..o...o...o...o."},
        "fill": {"tom": "............x.x."}, "drum_vol": 0.5,
    },
    {   # final: noite tranquila depois da bomba desativada
        "name": "ending", "key": "F", "scale": "major", "bpm": 76, "seed": 8, "rms_db": -17.0,
        "chords": ["F", "C", "Dm", "Bb", "F", "C", "Bb", "C"],
        "form": ["A", "B", "A2", "E"], "rhythm": "calm", "lead_oct": 4, "lead_wave": "tri", "lead_vol": 0.22,
        "echo": 0.3, "arp": ([0, 1, 2, 3, 2, 1, 2, 3], 2), "arp_vol": 0.035, "bass": "half", "bass_vol": 0.2,
        "pad_vol": 0.04, "drums": {"chug": "o.......o......."}, "drum_vol": 0.3,
    },
]


def save(name: str, samples: np.ndarray) -> None:
    pcm = (np.clip(samples, -1.0, 1.0) * 32767.0).astype(np.int16)
    path = os.path.join(OUT_DIR, name + ".wav")
    with wave.open(path, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        wf.writeframes(pcm.tobytes())
    print("[OK] %-16s %5.1f s" % (name + ".wav", len(samples) / SR))


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    for spec in TRACKS:
        for name, samples in Track(spec).render().items():
            save(name, samples)


if __name__ == "__main__":
    main()
