#!/usr/bin/env python3
"""LASTROOT placeholder audio generator (standard library only, deterministic).

Synthesises small licence-free placeholder cues so the game has feedback
before final sound exists. Every cue is listed in docs/AUDIO_LEDGER.csv; a
finished file in assets/audio/final/<cue>.ogg overrides the placeholder.

Output: assets/audio/placeholder/<cue>.wav, 22050 Hz mono 16-bit PCM.
Music loops use whole-cycle oscillators and a short crossfade so the loop
point does not click. One-shots are normalised to about -6 dBFS, music to -12.

Usage: python3 tools/gen_placeholder_audio.py [--out DIR]
"""
import argparse
import math
import os
import random
import struct
import wave

SR = 22050
TAU = 2.0 * math.pi
rng = random.Random(4207)


def n(sec):
    return int(round(sec * SR))


def tone(freq, sec, shape="sine", amp=1.0, glide=None):
    """Oscillator; glide = end frequency for a linear pitch sweep."""
    out = []
    ph = 0.0
    total = n(sec)
    for i in range(total):
        f = freq if glide is None else freq + (glide - freq) * i / max(1, total - 1)
        ph += TAU * f / SR
        if shape == "sine":
            v = math.sin(ph)
        elif shape == "tri":
            v = 2.0 / math.pi * math.asin(math.sin(ph))
        elif shape == "square":
            v = 1.0 if math.sin(ph) >= 0 else -1.0
            v *= 0.5
        else:  # saw
            v = ((ph / TAU) % 1.0) * 2.0 - 1.0
            v *= 0.6
        out.append(v * amp)
    return out


def noise(sec, amp=1.0):
    return [amp * (rng.random() * 2 - 1) for _ in range(n(sec))]


def lowpass(sig, cutoff):
    a = 1.0 - math.exp(-TAU * cutoff / SR)
    y = 0.0
    out = []
    for x in sig:
        y += a * (x - y)
        out.append(y)
    return out


def highpass(sig, cutoff):
    lp = lowpass(sig, cutoff)
    return [x - l for x, l in zip(sig, lp)]


def env(sig, attack=0.005, release=None, curve=3.0):
    """Fast attack, exponential-ish decay over the whole length."""
    total = len(sig)
    na = max(1, n(attack))
    out = []
    for i, x in enumerate(sig):
        if i < na:
            g = i / na
        else:
            t = (i - na) / max(1, total - na)
            g = (1.0 - t) ** curve
        out.append(x * g)
    return out


def mix(*sigs):
    total = max(len(s) for s in sigs)
    out = [0.0] * total
    for s in sigs:
        for i, v in enumerate(s):
            out[i] += v
    return out


def at(sig, offset_sec, total_sec=None):
    pad = [0.0] * n(offset_sec)
    s = pad + sig
    if total_sec is not None:
        s = (s + [0.0] * n(total_sec))[: n(total_sec)]
    return s


def gain(sig, g):
    return [v * g for v in sig]


def normalise(sig, peak_db=-6.0):
    m = max((abs(v) for v in sig), default=0.0) or 1.0
    g = 10 ** (peak_db / 20.0) / m
    return [v * g for v in sig]


def fade_edges(sig, sec=0.004):
    k = min(n(sec), len(sig) // 2)
    for i in range(k):
        sig[i] *= i / k
        sig[-1 - i] *= i / k
    return sig


def write(path, sig):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767)) for v in sig))


def chime(freqs, sec, step=0.0, shape="sine", curve=3.0, amp=1.0):
    parts = [at(env(tone(f, sec, shape), curve=curve), i * step) for i, f in enumerate(freqs)]
    return gain(mix(*parts), amp)


def thump(freq=90, sec=0.25, glide=40):
    return env(tone(freq, sec, glide=glide), 0.002, curve=4.0)


def whoosh(sec, lo=300, hi=2000):
    s = noise(sec)
    s = lowpass(highpass(s, lo), hi)
    total = len(s)
    return [v * math.sin(math.pi * i / total) for i, v in enumerate(s)]


# ------------------------------------------------------------- cue designs
def cues():
    c = {}
    c["ui_click"] = env(tone(1200, 0.05, "tri"), 0.001, curve=4)
    c["ui_confirm"] = chime([660, 990], 0.18, 0.06, "tri")
    c["ui_cancel"] = chime([520, 390], 0.16, 0.05, "tri")
    c["ui_invalid"] = env(tone(150, 0.22, "square"), 0.002, curve=1.5)
    c["card_hover"] = env(lowpass(noise(0.07), 3000), 0.002, curve=2)
    c["card_play"] = mix(whoosh(0.22, 400, 3000), at(env(tone(520, 0.12, "tri"), curve=3), 0.1))
    c["unit_summon"] = mix(thump(120, 0.35, 60), at(chime([392, 523, 659], 0.4, 0.05), 0.04))
    c["spell_cast"] = mix(env(tone(400, 0.45, "sine", glide=1200), 0.02, curve=2), gain(whoosh(0.45, 1500, 6000), 0.4))
    c["attack_bark"] = mix(thump(80, 0.3, 45), gain(env(lowpass(noise(0.2), 900)), 0.7))
    c["attack_spore"] = mix(gain(whoosh(0.3, 800, 4000), 0.8), at(env(tone(300, 0.2, "tri", glide=180)), 0.05))
    c["attack_enemy"] = mix(env(tone(220, 0.25, "saw", glide=110), curve=2), gain(env(highpass(noise(0.15), 2000)), 0.4))
    c["hit"] = mix(thump(140, 0.15, 70), gain(env(noise(0.08), 0.001, curve=4), 0.6))
    c["armor_block"] = chime([1800, 2400, 3100], 0.3, 0.0, "sine", 5)
    c["poison_apply"] = mix(env(tone(330, 0.35, "sine", glide=250)), gain(env(lowpass(noise(0.35), 1200)), 0.3))
    c["poison_tick"] = env(tone(260, 0.12, "tri", glide=200), curve=2)
    c["heal"] = chime([523, 659, 784, 1047], 0.5, 0.07, "sine", 2.5)
    c["growth"] = mix(env(tone(200, 0.5, "tri", glide=420), 0.03, curve=2), at(chime([784], 0.3), 0.25))
    c["thorns"] = mix(gain(env(highpass(noise(0.12), 3000), 0.001, curve=5), 0.8), env(tone(1500, 0.1, "saw"), curve=5))
    c["death_ally"] = chime([440, 370, 294], 0.5, 0.12, "tri", 2)
    c["death_enemy"] = mix(env(lowpass(noise(0.45), 700), 0.002, curve=2), env(tone(160, 0.4, "saw", glide=50), curve=2))
    c["enemy_climb"] = mix(env(lowpass(noise(0.3), 500), 0.05, curve=1.5), env(tone(110, 0.3, "tri", glide=165), 0.05))
    c["heart_hit"] = mix(thump(60, 0.5, 35), gain(env(tone(880, 0.3, "sine", glide=600), curve=4), 0.3))
    c["heart_pulse"] = mix(thump(70, 0.18, 50), at(thump(65, 0.2, 45), 0.22))
    c["wave_arrive"] = env(tone(98, 0.9, "saw", glide=110), 0.2, curve=1.2)
    c["boss_arrive"] = mix(env(tone(55, 1.6, "saw", glide=49), 0.3, curve=1.2), gain(env(tone(82.5, 1.6, "saw"), 0.4, curve=1.2), 0.6),
                           gain(whoosh(1.6, 100, 900), 0.5))
    c["boss_escalate"] = mix(chime([110, 116.5], 0.9, 0.0, "saw", 1.5), gain(env(noise(0.6), 0.1, curve=2), 0.2))
    c["victory"] = chime([523, 659, 784, 1047, 1319], 1.2, 0.12, "tri", 2)
    c["defeat"] = chime([392, 330, 262, 196], 1.2, 0.2, "tri", 1.8)
    c["reward"] = chime([784, 988, 1175], 0.5, 0.06, "sine", 2.5)
    c["resin"] = chime([1319, 1568], 0.25, 0.04, "sine", 4)
    c["route_select"] = mix(gain(whoosh(0.3, 300, 1500), 0.6), at(chime([587, 880], 0.3, 0.05, "tri"), 0.08))
    c["camp_upgrade"] = mix(thump(200, 0.12, 150), at(chime([659, 988, 1319], 0.5, 0.05), 0.08))
    c["mutation_grow"] = mix(env(tone(150, 0.9, "tri", glide=300), 0.1, curve=1.5), at(chime([523, 784, 1047], 0.6, 0.1), 0.3))
    return c


def music_loop(root, chords, sec=8.0, pulse=False):
    """Slow ambient pad loop; frequencies snapped to whole cycles per chord."""
    per = sec / len(chords)
    out = []
    for ch in chords:
        seg = [0.0] * n(per)
        for semis in ch:
            f = root * 2 ** (semis / 12.0)
            f = max(1, round(f * per)) / per
            for shape, amp, det in (("sine", 0.5, 1.0), ("tri", 0.25, 1.003)):
                t = tone(f * det, per, shape, amp)
                for i, v in enumerate(t):
                    seg[i] += v
        # swell in/out within the chord so chord changes are smooth
        total = len(seg)
        seg = [v * (0.55 + 0.45 * math.sin(math.pi * i / total)) for i, v in enumerate(seg)]
        out.extend(seg)
    if pulse:
        beat = n(sec / 16)
        for i in range(len(out)):
            ph = (i % beat) / beat
            out[i] *= 0.75 + 0.25 * math.exp(-ph * 6)
        kick = thump(55, 0.2, 40)
        for b in range(0, 16, 4):
            o = b * beat
            for j, v in enumerate(kick):
                if o + j < len(out):
                    out[o + j] += v * 1.5
    out = lowpass(out, 2400)
    # crossfade tail into head for a seamless loop
    k = n(0.05)
    for i in range(k):
        a = i / k
        out[i] = out[i] * a + out[-k + i] * (1 - a)
    return out[:-k]


def music():
    return {
        "music_menu": music_loop(110.0, [[0, 7, 12, 16], [-3, 4, 9, 12], [-7, 0, 5, 12], [-5, 2, 7, 14]], 8.0),
        "music_battle": music_loop(98.0, [[0, 7, 15], [-2, 5, 14], [-4, 3, 12], [-5, 2, 10]], 6.0, pulse=True),
        "music_boss": music_loop(73.4, [[0, 6, 12], [1, 7, 13], [0, 6, 15], [-1, 5, 11]], 6.0, pulse=True),
    }


def main():
    ap = argparse.ArgumentParser()
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    ap.add_argument("--out", default=os.path.join(root, "assets", "audio", "placeholder"))
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    total = 0
    items = list(cues().items()) + list(music().items())
    for name, sig in items:
        sig = normalise(sig, -12.0 if name.startswith("music_") else -6.0)
        if not name.startswith("music_"):
            sig = fade_edges(sig)
        p = os.path.join(args.out, name + ".wav")
        write(p, sig)
        total += os.path.getsize(p)
    print("gen_placeholder_audio: %d files, %.1f KB -> %s" % (len(items), total / 1024, args.out))


if __name__ == "__main__":
    main()
