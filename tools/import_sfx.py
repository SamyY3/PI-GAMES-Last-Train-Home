import array
import math
import os
import re
import struct
import sys
import wave
import zipfile

SR_OUT = 48000

SOUNDS = {
    "player_shoot": ("DSGNMisc_HIT-Mecha Laser Pistol", 6, 0.22, 60, 0.194),
    "enemy_hit": ("DSGNMisc_HIT-Fleeting Hit", 6, 0.22, 60, 0.176),
    "enemy_die": ("DSGNImpt_EXPLOSION-Mecha Limb Explosion", 6, 0.9, 150, 0.363),
    "player_hurt": ("FGHTImpt_HIT-Strong Smack", 6, 0.4, 40, 0.434),
    "dash": ("WHSH_MOVEMENT-Simple Whoosh", 6, 0.35, 40, 0.282),
    "graze": ("SWSH_MOVEMENT-Tiny Chime", 6, 0.4, 120, 0.077),
    "steam_pulse": ("MAGSpel_CAST-Energy Noise", 1, 1.6, 150, 0.391),
    "heal": ("MAGAngl_BUFF-Simple Heal", 1, 1.4, 200, 0.282),
    "upgrade_get": ("DSGNSynth_BUFF-Mecha Level Up", 1, 1.2, 100, 0.312),
    "boss_phase": ("DSGNSynth_CAST-Mecha Energy Gathering", 1, 2.6, 200, 0.336),
    "bomb_explode": ("DSGNImpt_EXPLOSION-Mecha Detonator", 1, 2.5, 300, 0.530),
    "clang": ("DSGNMisc_MELEE-Sword Parry", 6, 0.7, 100, 0.389),
    "ui_confirm": ("UIClick_INTERFACE-Positive Click", 1, 0.3, 40, 0.192),
    "ui_hover": ("UIClick_INTERFACE-Rattling Click", 1, 0.15, 40, 0.102),
    "tick": ("UIClick_INTERFACE-Metallic Click", 1, 0.16, 30, 0.185),
    "blip": ("DSGNTonl_INTERFACE-Tonal Click", 1, 0.06, 20, 0.205),
}


def decode(data):
    pos = 12
    fmt = pcm = None
    while pos < len(data) - 8:
        cid = data[pos:pos + 4]
        size = struct.unpack("<I", data[pos + 4:pos + 8])[0]
        body = data[pos + 8:pos + 8 + size]
        if cid == b"fmt ":
            fmt = struct.unpack("<HHIIHH", body[:16])
        elif cid == b"data":
            pcm = body
        pos += 8 + size + (size & 1)
    _, ch, sr, _, block, bits = fmt
    n = len(pcm) // block
    width = bits // 8
    scale = float(1 << (bits - 1))
    out = array.array("f", bytes(4 * n))
    for i in range(n):
        o = i * block
        s = 0
        for c in range(ch):
            s += int.from_bytes(pcm[o + c * width:o + (c + 1) * width], "little", signed=True)
        out[i] = s / ch / scale
    return out, sr


def downsample(x, sr):
    step = max(1, sr // SR_OUT)
    return array.array("f", [sum(x[i:i + step]) / step for i in range(0, len(x) - step + 1, step)]), sr // step


def trim(x, sr, max_len, fade_ms, thresh=10 ** (-50 / 20)):
    start = 0
    while start < len(x) and abs(x[start]) < thresh:
        start += 1
    start = max(0, start - int(sr * 0.002))
    end = len(x)
    while end > start and abs(x[end - 1]) < thresh:
        end -= 1
    end = min(end + int(sr * 0.01), start + int(sr * max_len))
    seg = x[start:end]
    f = min(len(seg), int(sr * fade_ms / 1000))
    for k in range(f):
        seg[len(seg) - 1 - k] *= k / f
    return seg


def loudness(x, sr):
    win = max(1, int(sr * 0.05))
    best = 0.0
    for i in range(0, max(1, len(x) - win + 1), max(1, win // 2)):
        s = x[i:i + win]
        best = max(best, math.sqrt(sum(v * v for v in s) / len(s)))
    return best


def save(path, x, sr, gain):
    pcm = array.array("h", (max(-32767, min(32767, int(v * gain * 32767))) for v in x))
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())


def main():
    zpath, out_dir = sys.argv[1], sys.argv[2]
    z = zipfile.ZipFile(zpath)
    files = {}
    for info in z.infolist():
        m = re.match(r"(.+)_HY_PC-(\d+)\.wav$", info.filename.split("/")[-1])
        if m:
            files.setdefault(m.group(1), []).append((int(m.group(2)), info))
    for name, (source, variants, max_len, fade_ms, target) in SOUNDS.items():
        takes = [info for _, info in sorted(files[source], key=lambda t: t[0])][:variants]
        segs = []
        for info in takes:
            raw, sr = decode(z.read(info))
            mono, sr2 = downsample(raw, sr)
            segs.append((trim(mono, sr2, max_len, fade_ms), sr2))
        ref = loudness(*segs[0]) or 1.0
        for i, (seg, sr2) in enumerate(segs):
            peak = max((abs(v) for v in seg), default=1.0) or 1.0
            gain = min(target / ref, 0.95 / peak)
            fname = f"{name}.wav" if i == 0 else f"{name}_{i + 1}.wav"
            save(os.path.join(out_dir, fname), seg, sr2, gain)
        print(f"{name}: {source} x{len(segs)} ({len(segs[0][0]) / segs[0][1]:.2f}s)")


if __name__ == "__main__":
    main()
