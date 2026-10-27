#!/usr/bin/env python3
"""
Gerador procedural de áudio chiptune e SFX (WAV 16-bit 44.1 kHz) para LAST TRAIN HOME.
Inclui o loop de som ambiente do trem nos trilhos (train_ambience.wav).
"""

import os
import wave
import numpy as np

SAMPLE_RATE = 44100
BASE_AUDIO_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio")


def ensure_dirs() -> None:
    os.makedirs(os.path.join(BASE_AUDIO_DIR, "sfx"), exist_ok=True)
    os.makedirs(os.path.join(BASE_AUDIO_DIR, "music"), exist_ok=True)


def save_wav(rel_path: str, samples: np.ndarray) -> None:
    full_path = os.path.join(BASE_AUDIO_DIR, rel_path)
    clipped = np.clip(samples, -1.0, 1.0)
    pcm16 = (clipped * 32767.0).astype(np.int16)
    with wave.open(full_path, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(pcm16.tobytes())


def adsr_envelope(n_samples: int, a: float, d: float, s_level: float, r: float) -> np.ndarray:
    env = np.ones(n_samples, dtype=np.float32) * s_level
    a_s = int(a * SAMPLE_RATE)
    d_s = int(d * SAMPLE_RATE)
    r_s = int(r * SAMPLE_RATE)
    if a_s > 0:
        env[:a_s] = np.linspace(0.0, 1.0, a_s)
    if d_s > 0 and a_s + d_s < n_samples:
        env[a_s:a_s + d_s] = np.linspace(1.0, s_level, d_s)
    if r_s > 0 and r_s < n_samples:
        env[-r_s:] = np.linspace(s_level, 0.0, r_s)
    return env


def synth_tone(freq_start: float, freq_end: float, duration: float, wave_type: str = "square",
               vol: float = 0.4) -> np.ndarray:
    n = int(duration * SAMPLE_RATE)
    freqs = np.linspace(freq_start, freq_end, n)
    phase = 2.0 * np.pi * np.cumsum(freqs) / SAMPLE_RATE

    if wave_type == "square":
        raw = np.sign(np.sin(phase))
    elif wave_type == "triangle":
        raw = 2.0 * np.abs(2.0 * (phase / (2.0 * np.pi) - np.floor(phase / (2.0 * np.pi) + 0.5))) - 1.0
    else:
        rng = np.random.default_rng(42)
        raw = rng.uniform(-1.0, 1.0, n)

    env = adsr_envelope(n, min(0.01, duration * 0.1), duration * 0.2, 0.6, duration * 0.3)
    return (raw * env * vol).astype(np.float32)


def generate_music_loop(filename: str, bpm: int, seconds: int, scale_hz: list[float], wave_type: str = "square") -> None:
    step_sec = (60.0 / bpm) / 2.0
    total_steps = int(seconds / step_sec)
    chunks = []
    for i in range(total_steps):
        freq = scale_hz[i % len(scale_hz)]
        if i % 4 == 0:
            freq *= 0.5
        chunks.append(synth_tone(freq, freq, step_sec, wave_type, 0.22))
    save_wav(os.path.join("music", filename), np.concatenate(chunks))


def main() -> None:
    ensure_dirs()
    a_harm_minor = [220.0, 246.94, 261.63, 293.66, 329.63, 349.23, 415.30, 329.63]
    generate_music_loop("menu.wav", 90, 16, a_harm_minor, "triangle")
    generate_music_loop("wagons_1_3.wav", 120, 24, a_harm_minor, "square")
    generate_music_loop("wagon_4.wav", 140, 16, a_harm_minor, "square")
    generate_music_loop("boss_p1_p2.wav", 150, 20, a_harm_minor, "square")
    generate_music_loop("boss_p3.wav", 170, 20, a_harm_minor, "square")
    generate_music_loop("ending.wav", 70, 16, [220.0, 261.63, 329.63, 440.0], "triangle")
    print("[OK] Músicas WAV geradas (SFX: tools/generate_sfx.py)")


if __name__ == "__main__":
    main()
