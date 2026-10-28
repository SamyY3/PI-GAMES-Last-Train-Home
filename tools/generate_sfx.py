# Sintetiza todo o SFX de Last Train Home (steampunk: vapor, latão, engrenagens, ferro)
# Uso: python tools/generate_sfx.py assets/audio/sfx
import sys, wave
import numpy as np

SR = 44100
OUT = sys.argv[1]
rng = np.random.default_rng(7)


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def env_adsr(n, a=0.005, d=0.05, s=0.6, r=0.1):
    a_n, d_n, r_n = int(a * SR), int(d * SR), int(r * SR)
    s_n = max(0, n - a_n - d_n - r_n)
    e = np.concatenate([
        np.linspace(0, 1, a_n, endpoint=False),
        np.linspace(1, s, d_n, endpoint=False),
        np.full(s_n, s),
        np.linspace(s, 0, r_n),
    ])
    return np.pad(e, (0, max(0, n - len(e))))[:n]


def exp_env(n, tau):
    return np.exp(-np.arange(n) / (SR * tau))


def noise(n):
    return rng.uniform(-1, 1, n)


def lowpass(x, cutoff):
    # filtro de um polo (cutoff pode ser array)
    cutoff = np.broadcast_to(np.asarray(cutoff, dtype=float), x.shape)
    a = 1.0 - np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a[i] * (x[i] - acc)
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def bandnoise(n, lo, hi):
    return highpass(lowpass(noise(n), hi), lo)


def sweep(f0, f1, dur, wave_fn=np.sin, curve=1.0):
    t = t_axis(dur)
    k = (t / dur) ** curve
    f = f0 + (f1 - f0) * k
    ph = 2 * np.pi * np.cumsum(f) / SR
    return wave_fn(ph)


def square(ph):
    return np.sign(np.sin(ph))


def tri(ph):
    return 2 / np.pi * np.arcsin(np.sin(ph))


def metal(dur, base, tau, partials=(1.0, 2.76, 5.40, 8.93, 13.34)):
    t = t_axis(dur)
    out = np.zeros_like(t)
    for i, p in enumerate(partials):
        out += np.sin(2 * np.pi * base * p * t + rng.uniform(0, 6)) * exp_env(len(t), tau / (1 + i * 0.7)) / (1 + i * 0.5)
    return out


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def at(x, delay):
    return np.concatenate([np.zeros(int(delay * SR)), x])


def save(name, x, gain=0.9, fade=0.004):
    x = np.asarray(x, dtype=float)
    f = int(fade * SR)
    if f and len(x) > 2 * f:
        x[:f] *= np.linspace(0, 1, f)
        x[-f:] *= np.linspace(1, 0, f)
    peak = np.max(np.abs(x)) or 1.0
    x = np.tanh(x / peak * 1.2) / np.tanh(1.2) * gain
    data = (x * 32767).astype(np.int16)
    with wave.open(f"{OUT}/{name}.wav", "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(name, f"{len(x) / SR:.2f}s")


# --- Combate -------------------------------------------------------------
# Tiro da chave-pneumática: estalo de pistão + sopro de vapor curto
n = int(0.11 * SR)
shoot = mix(
    sweep(900, 180, 0.06, square) * exp_env(int(0.06 * SR), 0.018) * 0.5,
    bandnoise(n, 2500, 9000) * exp_env(n, 0.025) * 0.6,
    metal(0.11, 1400, 0.02) * 0.25,
)
save("player_shoot", shoot, 0.6)

# Impacto em inimigo: tinido metálico seco
save("enemy_hit", mix(metal(0.12, 820, 0.03) * 0.8, bandnoise(int(0.05 * SR), 3000, 10000) * exp_env(int(0.05 * SR), 0.01)), 0.6)

# Inimigo destruído: estouro de caldeira + engrenagens caindo
n = int(0.55 * SR)
die = mix(
    lowpass(noise(n), np.linspace(4000, 300, n)) * exp_env(n, 0.12),
    sweep(220, 50, 0.3, tri) * exp_env(int(0.3 * SR), 0.1) * 0.7,
    *[at(metal(0.15, 1200 + 300 * k, 0.04) * 0.35, 0.12 + 0.07 * k) for k in range(4)],
)
save("enemy_die", die, 0.8)

# Jogador ferido: baque grave + apito de dor desafinado
n = int(0.35 * SR)
hurt = mix(
    sweep(300, 90, 0.2, square) * exp_env(int(0.2 * SR), 0.07) * 0.6,
    lowpass(noise(n), 1200) * exp_env(n, 0.06),
    sweep(1200, 700, 0.25) * exp_env(int(0.25 * SR), 0.08) * 0.25,
)
save("player_hurt", hurt, 0.8)

# Dash: rajada de vapor com chiado direcional
n = int(0.28 * SR)
dash = bandnoise(n, 800, 7000) * env_adsr(n, 0.01, 0.05, 0.5, 0.18)
dash = lowpass(dash, np.linspace(9000, 1500, n)) * 1.2
save("dash", mix(dash, sweep(500, 1500, 0.12, tri) * exp_env(int(0.12 * SR), 0.05) * 0.2), 0.7)

# Pulso de vapor (limpa projéteis): explosão de pressão + válvula
n = int(0.7 * SR)
pulse = mix(
    sweep(90, 40, 0.5) * exp_env(int(0.5 * SR), 0.2),
    lowpass(noise(n), np.linspace(8000, 600, n)) * exp_env(n, 0.25) * 0.9,
    at(metal(0.3, 520, 0.1) * 0.3, 0.02),
)
save("steam_pulse", pulse, 0.85)

# Cura: arpejo de sinos de latão + suspiro de vapor
heal = mix(*[at(metal(0.5, f, 0.18, (1.0, 2.0, 3.0)) * 0.5, i * 0.07) for i, f in enumerate([523, 659, 784, 1047])],
           bandnoise(int(0.4 * SR), 3000, 9000) * env_adsr(int(0.4 * SR), 0.05, 0.1, 0.3, 0.2) * 0.15)
save("heal", heal, 0.7)

# Upgrade obtido: engrenagens encaixando + fanfarra de órgão a vapor
gear = mix(*[at(metal(0.06, 2400, 0.012) * 0.5, i * 0.045) for i in range(5)])
fan = mix(*[at((sweep(f, f, 0.35, tri) + 0.4 * sweep(f * 2, f * 2, 0.35)) * env_adsr(int(0.35 * SR), 0.01, 0.1, 0.6, 0.15) * 0.4, 0.25 + i * 0.09)
            for i, f in enumerate([392, 523, 659, 784])])
save("upgrade_get", mix(gear, fan), 0.75)

# --- Mundo / eventos -------------------------------------------------------
# Clang: pancada de ferro no casco do trem
n = int(0.6 * SR)
save("clang", mix(metal(0.6, 180, 0.25, (1.0, 2.31, 3.9, 5.7, 8.1)), lowpass(noise(int(0.04 * SR)), 3000) * 0.8), 0.85)

# Tique do relógio: mola + escape
tick = mix(metal(0.05, 3200, 0.008, (1.0, 1.6)) * 0.8, at(metal(0.04, 2100, 0.006, (1.0, 1.5)) * 0.4, 0.012))
save("tick", tick, 0.7)

# Apito do trem: acorde de três tubos com vibrato e sopro
dur = 1.6
t = t_axis(dur)
vib = 1 + 0.006 * np.sin(2 * np.pi * 5.5 * t)
whistle = np.zeros_like(t)
for f in (466, 587, 698):
    ph = 2 * np.pi * np.cumsum(f * vib) / SR
    whistle += np.sin(ph) + 0.3 * np.sin(2 * ph) + 0.12 * np.sin(3 * ph)
whistle *= env_adsr(len(t), 0.08, 0.2, 0.75, 0.5)
breath = bandnoise(len(t), 1500, 6000) * env_adsr(len(t), 0.03, 0.2, 0.25, 0.5) * 0.6
save("whistle", mix(whistle * 0.35, breath), 0.75)

# Fase do chefe: sirene descendente + martelo de pistão
n = int(1.0 * SR)
siren = sweep(880, 330, 1.0, square) * env_adsr(n, 0.02, 0.2, 0.5, 0.4) * 0.25
hammer = mix(*[at(mix(sweep(120, 45, 0.18) * exp_env(int(0.18 * SR), 0.06), metal(0.2, 260, 0.06) * 0.5), i * 0.28) for i in range(3)])
save("boss_phase", mix(siren, hammer), 0.85)

# Explosão da bomba: estrondo longo, rugido grave e destroços
n = int(3.0 * SR)
boom = mix(
    lowpass(noise(n), np.concatenate([np.linspace(9000, 1500, int(0.4 * SR)), np.linspace(1500, 200, n - int(0.4 * SR))])) * exp_env(n, 0.7),
    sweep(70, 28, 2.5) * exp_env(int(2.5 * SR), 0.9) * 1.2,
    *[at(metal(0.3, 600 + 250 * k, 0.08) * 0.25, 0.3 + 0.18 * k) for k in range(8)],
)
save("bomb_explode", boom, 0.95, fade=0.02)

# --- Interface --------------------------------------------------------------
save("ui_hover", mix(metal(0.05, 2600, 0.01, (1.0, 2.0)) * 0.6, sweep(1800, 2200, 0.03, tri) * exp_env(int(0.03 * SR), 0.01) * 0.3), 0.45)
save("ui_confirm", mix(metal(0.09, 1300, 0.03, (1.0, 2.0, 3.0)), at(metal(0.14, 1950, 0.05, (1.0, 2.0, 3.0)) * 0.8, 0.06),
                       bandnoise(int(0.08 * SR), 4000, 10000) * exp_env(int(0.08 * SR), 0.02) * 0.3), 0.55)
save("blip", sweep(1500, 1500, 0.04, square) * exp_env(int(0.04 * SR), 0.012), 0.4)

# --- Ambiente do trem (loop perfeito de 4 compassos) -------------------------
loop = 4.8
n = int(loop * SR)
t = t_axis(loop)
def circular(fn, x):
    # filtra o sinal repetido duas vezes e fica com a 2a cópia: o estado do filtro emenda, loop perfeito
    return fn(np.concatenate([x, x]))[len(x):]


base_noise = noise(n)
rumble = circular(lambda v: lowpass(v, 160), base_noise) * 3.0 + 0.3 * np.sin(2 * np.pi * 43 * t)
amb = rumble
for beat in range(4):
    for k, off in enumerate((0.0, 0.16)):
        start = beat * (loop / 4) + off
        hit = mix(lowpass(noise(int(0.12 * SR)), 900) * exp_env(int(0.12 * SR), 0.03) * 1.6,
                  metal(0.15, 210 + 40 * k, 0.04) * 0.35)
        s0 = int(start * SR)
        e = min(n, s0 + len(hit))
        amb[s0:e] += hit[:e - s0]
hiss = circular(lambda v: highpass(lowpass(v, 8000), 3000), noise(n))
amb += hiss * (0.08 + 0.05 * np.sin(2 * np.pi * (4 / loop) * t) ** 2)
save("train_ambience", amb, 0.5, fade=0.0)

n = int(0.07 * SR)
graze = mix(bandnoise(n, 5000, 11000) * exp_env(n, 0.018), metal(0.05, 4200, 0.01, (1.0, 1.5)) * 0.35)
save("graze", graze, 0.35)
