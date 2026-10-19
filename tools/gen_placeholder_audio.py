#!/usr/bin/env python3
"""LASTROOT placeholder audio generator v2 (standard library only, deterministic).

Synthesises every cue in docs/AUDIO_LEDGER.csv so a playtest sounds intended,
not like test tones. All sound is generated here from oscillators, filtered
noise and plucked-string models: no samples, licence clean (project-owned).

Palette (bible tone: living wood, spores, ash, a crystal heart):
  bark   - woody thunks: modal wood partials + low body + click
  spore  - soft puffs: band-swept noise + bubbly blips
  ash    - enemies: sparse crackle impulses + low growl
  heart  - crystalline FM bell chimes with a short room
  boss   - low booms and brass-like swells
Loudness: SFX matched to -18 dBFS RMS (peak cap -3), UI -27 RMS (cap -10),
music peak -9 dBFS.
Frequent cues (hit, attack_*) get _2/_3 variants; AudioService picks one at
random per play (presentation-only randomness).

Output: assets/audio/placeholder/<cue>.wav (22050 Hz mono 16-bit; music 16000 Hz).
A finished file in assets/audio/final/<cue>.ogg overrides any placeholder.
Usage: python3 tools/gen_placeholder_audio.py [--out DIR]
"""
import argparse
import math
import os
import random
import struct
import wave

SR = 22050
MSR = 16000          # music sample rate (smaller files, content is < 7 kHz)
TAU = 2.0 * math.pi
rng = random.Random(4207)


# ------------------------------------------------------------- primitives
def n(sec, sr=SR):
    return int(round(sec * sr))


def zeros(sec, sr=SR):
    return [0.0] * n(sec, sr)


def osc(freq, sec, shape="sine", amp=1.0, glide=None, sr=SR, phase=0.0):
    out = []
    ph = phase
    total = n(sec, sr)
    for i in range(total):
        f = freq if glide is None else freq * (glide / freq) ** (i / max(1, total - 1))
        ph += TAU * f / sr
        if shape == "sine":
            v = math.sin(ph)
        elif shape == "tri":
            v = 2.0 / math.pi * math.asin(math.sin(ph))
        elif shape == "saw":
            v = ((ph / TAU) % 1.0) * 2.0 - 1.0
        else:  # soft square
            v = math.tanh(3.0 * math.sin(ph))
        out.append(v * amp)
    return out


def noise(sec, amp=1.0, sr=SR):
    return [amp * (rng.random() * 2 - 1) for _ in range(n(sec, sr))]


def onepole_lp(sig, cutoff, sr=SR):
    a = 1.0 - math.exp(-TAU * cutoff / sr)
    y = 0.0
    out = []
    for x in sig:
        y += a * (x - y)
        out.append(y)
    return out


def onepole_hp(sig, cutoff, sr=SR):
    lp = onepole_lp(sig, cutoff, sr)
    return [x - l for x, l in zip(sig, lp)]


def bandpass(sig, f0, q=4.0, sr=SR, f1=None):
    """RBJ biquad band-pass; optional linear sweep f0 -> f1."""
    out = []
    x1 = x2 = y1 = y2 = 0.0
    total = len(sig)
    for i, x in enumerate(sig):
        f = f0 if f1 is None else f0 + (f1 - f0) * i / max(1, total - 1)
        w = TAU * f / sr
        alpha = math.sin(w) / (2 * q)
        b0, b2 = alpha, -alpha
        a0, a1, a2 = 1 + alpha, -2 * math.cos(w), 1 - alpha
        y = (b0 * x + b2 * x2 - a1 * y1 - a2 * y2) / a0
        x2, x1 = x1, x
        y2, y1 = y1, y
        out.append(y)
    return out


def env_exp(sig, attack=0.003, decay=0.2, sr=SR):
    """Fast linear attack, exponential decay with time constant `decay`."""
    na = max(1, n(attack, sr))
    out = []
    for i, x in enumerate(sig):
        if i < na:
            g = i / na
        else:
            g = math.exp(-(i - na) / (decay * sr))
        out.append(x * g)
    return out


def env_ar(sig, attack, release, sr=SR):
    total = len(sig)
    na, nr = max(1, n(attack, sr)), max(1, n(release, sr))
    out = []
    for i, x in enumerate(sig):
        g = 1.0
        if i < na:
            g = i / na
        if i > total - nr:
            g *= max(0.0, (total - i) / nr)
        out.append(x * g)
    return out


def mix(*sigs):
    total = max(len(s) for s in sigs)
    out = [0.0] * total
    for s in sigs:
        for i, v in enumerate(s):
            out[i] += v
    return out


def place(dst, src, at_sec, gain=1.0, sr=SR, wrap=False):
    o = n(at_sec, sr)
    L = len(dst)
    for i, v in enumerate(src):
        j = o + i
        if j >= L:
            if not wrap:
                break
            j %= L
        dst[j] += v * gain


def gain(sig, g):
    return [v * g for v in sig]


def soft_clip(sig, drive=1.5):
    return [math.tanh(v * drive) / math.tanh(drive) for v in sig]


def room(sig, wet=0.25, sr=SR, size=1.0):
    """Tiny Schroeder-ish room: three feedback combs + one all-pass."""
    out = list(sig) + [0.0] * n(0.25 * size, sr)
    dry = list(out)
    acc = [0.0] * len(out)
    for d_ms, fb in ((29.7, 0.72), (37.1, 0.70), (41.1, 0.68)):
        d = int(sr * d_ms * size / 1000.0)
        buf = [0.0] * len(out)
        for i in range(len(out)):
            prev = buf[i - d] if i >= d else 0.0
            buf[i] = dry[i] + prev * fb
            acc[i] += buf[i] / 3.0
    d = int(sr * 5.0 / 1000.0)
    ap = [0.0] * len(out)
    for i in range(len(out)):
        xd = acc[i - d] if i >= d else 0.0
        yd = ap[i - d] if i >= d else 0.0
        ap[i] = -0.5 * acc[i] + xd + 0.5 * yd
    return [d0 + wet * w for d0, w in zip(dry, ap)]


def normalise(sig, peak_db):
    m = max((abs(v) for v in sig), default=0.0) or 1.0
    g = 10 ** (peak_db / 20.0) / m
    return [v * g for v in sig]


def loudness(sig, rms_db, peak_db):
    """Match a target RMS (perceived level) but never exceed the peak ceiling."""
    m = max((abs(v) for v in sig), default=0.0) or 1.0
    r = math.sqrt(sum(v * v for v in sig) / max(1, len(sig))) or 1e-9
    g = min(10 ** (rms_db / 20.0) / r, 10 ** (peak_db / 20.0) / m)
    return [v * g for v in sig]


def fade_edges(sig, sec=0.004, sr=SR):
    k = min(n(sec, sr), len(sig) // 2)
    for i in range(k):
        sig[i] *= i / k
        sig[-1 - i] *= i / k
    return sig


def trim_tail(sig, thresh=0.0008):
    end = len(sig)
    while end > 1 and abs(sig[end - 1]) < thresh:
        end -= 1
    return sig[: max(end + n(0.01), 1)]


def write(path, sig, sr=SR):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767)) for v in sig))


# ---------------------------------------------------------- sound families
def wood_knock(f=180.0, dur=0.35, bright=1.0):
    """Struck wood: inharmonic modal partials, a body thump and a click."""
    parts = []
    for ratio, amp, dec in ((1.0, 1.0, 0.09), (2.76, 0.45, 0.05), (5.4, 0.25 * bright, 0.025), (8.9, 0.12 * bright, 0.015)):
        parts.append(env_exp(osc(f * ratio, dur), 0.001, dec))
    body = env_exp(osc(f * 0.5, dur, glide=f * 0.35), 0.002, 0.08)
    click = env_exp(bandpass(noise(0.03), 2500 * bright, 1.5), 0.0005, 0.006)
    return mix(*[gain(p, a) for p, a in zip(parts, [1.0, 1.0, 1.0, 1.0])], gain(body, 0.8), gain(click, 0.6))


def spore_puff(dur=0.35, f0=2600, f1=500, amp=1.0):
    s = bandpass(noise(dur), f0, 1.2, f1=f1)
    return gain(env_ar(s, dur * 0.25, dur * 0.7), amp)


def bubbles(count=4, dur=0.4, base=500):
    out = zeros(dur)
    for i in range(count):
        f = base * (1.0 + rng.random())
        b = env_exp(osc(f, 0.08, glide=f * 1.8), 0.002, 0.02)
        place(out, b, rng.random() * (dur - 0.09), 0.5)
    return out


def crackle(dur=0.3, density=180, hp=1800):
    s = [0.0] * n(dur)
    for i in range(len(s)):
        if rng.random() < density / SR:
            s[i] = (rng.random() * 2 - 1)
    s = onepole_hp(s, hp)
    # give each impulse a tiny ring
    return bandpass(s, 3200, 2.0)


def growl(f=70, dur=0.4):
    g = osc(f, dur, "saw", glide=f * 0.8)
    g = onepole_lp(g, 600)
    return soft_clip(env_exp(g, 0.01, dur * 0.4), 2.0)


def bell(f=880.0, dur=1.2, ratio=3.5, index=2.0, decay=0.45):
    """FM bell (crystal): carrier f, modulator f*ratio with decaying index."""
    out = []
    total = n(dur)
    for i in range(total):
        t = i / SR
        idx = index * math.exp(-t / (decay * 0.6))
        v = math.sin(TAU * f * t + idx * math.sin(TAU * f * ratio * t))
        out.append(v * math.exp(-t / decay))
    return out


def boom(f=48.0, dur=1.2):
    sub = env_exp(osc(f, dur, glide=f * 0.6), 0.004, dur * 0.35)
    rumble = env_exp(onepole_lp(noise(dur), 180), 0.01, dur * 0.3)
    return soft_clip(mix(gain(sub, 1.0), gain(rumble, 0.9)), 1.8)


def whoosh(dur=0.3, f0=400, f1=2500, amp=1.0):
    return gain(env_ar(bandpass(noise(dur), f0, 0.9, f1=f1), dur * 0.4, dur * 0.55), amp)


def chord_bell(freqs, step=0.07, dur=0.6, decay=0.3, ratio=2.0, index=1.2):
    out = zeros(dur + step * len(freqs))
    for i, f in enumerate(freqs):
        place(out, bell(f, dur, ratio, index, decay), i * step, 1.0 / len(freqs) ** 0.5)
    return out


# --------------------------------------------------------------- the cues
def cues():
    c = {}
    # UI (quiet): small wooden ticks and soft bell confirmations.
    c["ui_click"] = wood_knock(900, 0.08, 0.6)
    c["ui_confirm"] = mix(wood_knock(700, 0.12, 0.5), [0] * n(0.04) + chord_bell([784, 1175], 0.05, 0.3, 0.12))
    c["ui_cancel"] = mix(wood_knock(520, 0.12, 0.4), [0] * n(0.03) + chord_bell([659, 494], 0.06, 0.25, 0.1))
    c["ui_invalid"] = env_exp(onepole_lp(osc(130, 0.2, "square", glide=110), 900), 0.002, 0.07)
    c["card_hover"] = env_ar(bandpass(noise(0.07), 3500, 1.5, f1=5000), 0.01, 0.05)
    c["route_select"] = mix(whoosh(0.28, 300, 1400, 0.6), [0] * n(0.12) + wood_knock(260, 0.25, 0.7))
    c["reward"] = room(chord_bell([1047, 1319, 1568], 0.06, 0.5, 0.25), 0.3)
    c["resin"] = mix(chord_bell([1568, 2093], 0.035, 0.25, 0.08, 1.4, 0.8), bubbles(2, 0.25, 900))
    c["camp_upgrade"] = mix(wood_knock(220, 0.3), [0] * n(0.1) + room(chord_bell([659, 988, 1319], 0.05, 0.5, 0.2), 0.25))
    c["mutation_grow"] = room(mix(env_ar(onepole_lp(osc(110, 1.0, "saw", glide=220), 900), 0.25, 0.5),
                                   [0] * n(0.35) + chord_bell([523, 784, 1047], 0.09, 0.7, 0.3)), 0.35)
    # Cards and units
    c["card_play"] = mix(whoosh(0.18, 900, 3500, 0.7), [0] * n(0.12) + wood_knock(420, 0.15, 0.8))
    c["card_play_2"] = mix(whoosh(0.2, 800, 3000, 0.7), [0] * n(0.13) + wood_knock(380, 0.15, 0.8))
    c["spell_cast"] = room(mix(whoosh(0.35, 500, 4000, 0.8), [0] * n(0.15) + chord_bell([1175, 1760], 0.04, 0.35, 0.15)), 0.3)
    c["unit_summon"] = mix(wood_knock(110, 0.45), spore_puff(0.3, 1800, 400, 0.4), [0] * n(0.1) + chord_bell([392, 587], 0.06, 0.4, 0.18))
    # Attacks with variants
    for i, (f, b) in enumerate(((150, 1.0), (135, 0.9), (165, 1.1))):
        c["attack_bark" + ("" if i == 0 else "_%d" % (i + 1))] = mix(whoosh(0.12, 300, 1200, 0.5), [0] * n(0.08) + wood_knock(f, 0.32, b))
    for i, (f0, f1) in enumerate(((2800, 600), (3200, 700), (2400, 500))):
        c["attack_spore" + ("" if i == 0 else "_%d" % (i + 1))] = mix(spore_puff(0.28, f0, f1), bubbles(3, 0.3, 450 + 60 * i))
    for i, f in enumerate((75, 68, 82)):
        c["attack_enemy" + ("" if i == 0 else "_%d" % (i + 1))] = mix(crackle(0.3, 260), gain(growl(f, 0.35), 0.8))
    for i, f in enumerate((120, 105, 135)):
        c["hit" + ("" if i == 0 else "_%d" % (i + 1))] = mix(env_exp(osc(f, 0.18, glide=f * 0.5), 0.001, 0.05),
                                                              gain(env_exp(bandpass(noise(0.1), 1200 + 200 * i, 1.0), 0.0005, 0.02), 0.8))
    # Statuses
    c["armor_block"] = mix(bell(1400, 0.4, 2.7, 1.5, 0.12), gain(wood_knock(300, 0.2, 1.2), 0.6))
    c["poison_apply"] = mix(bubbles(5, 0.4, 350), gain(env_ar(bandpass(noise(0.4), 900, 3.0, f1=500), 0.05, 0.3), 0.6))
    c["poison_tick"] = bubbles(2, 0.14, 420)
    c["heal"] = room(chord_bell([523, 659, 784, 1047], 0.07, 0.6, 0.3, 2.0, 0.8), 0.35)
    c["growth"] = mix(env_ar(onepole_lp(osc(180, 0.5, "tri", glide=360), 1200), 0.05, 0.3), [0] * n(0.25) + chord_bell([880], 0.0, 0.3, 0.12))
    c["thorns"] = mix(gain(env_exp(onepole_hp(noise(0.08), 3500), 0.0005, 0.012), 1.0), wood_knock(700, 0.1, 1.4))
    # Deaths, climbing, waves
    c["death_ally"] = room(mix(wood_knock(140, 0.5, 0.6), [0] * n(0.08) + chord_bell([440, 349, 294], 0.12, 0.5, 0.25)), 0.3)
    c["death_enemy"] = mix(crackle(0.5, 400, 1200), gain(env_exp(onepole_lp(noise(0.5), 500), 0.005, 0.15), 0.8))
    c["enemy_climb"] = mix(crackle(0.35, 120), env_ar(onepole_lp(noise(0.35), 400), 0.08, 0.2), gain(growl(60, 0.3), 0.5))
    c["wave_arrive"] = room(mix(env_ar(onepole_lp(osc(98, 1.0, "saw", glide=110), 700), 0.25, 0.5),
                                gain(env_ar(onepole_lp(osc(147, 1.0, "saw"), 600), 0.3, 0.5), 0.5), crackle(1.0, 60)), 0.3)
    # Heart (crystal) and boss (low)
    c["heart_hit"] = room(mix(boom(60, 0.6), [0] * n(0.02) + gain(bell(1320, 0.8, 1.41, 3.0, 0.25), 0.7)), 0.3)
    c["heart_pulse"] = mix(gain(env_exp(osc(70, 0.2, glide=55), 0.004, 0.06), 1.0),
                           [0] * n(0.22) + gain(env_exp(osc(65, 0.2, glide=52), 0.004, 0.06), 0.8),
                           gain(bell(1760, 0.5, 3.5, 0.6, 0.2), 0.2))
    c["boss_arrive"] = room(mix(boom(42, 1.8), gain(env_ar(onepole_lp(osc(55, 1.8, "saw"), 500), 0.4, 0.8), 0.6),
                                gain(env_ar(onepole_lp(osc(82.4, 1.8, "saw"), 600), 0.6, 0.8), 0.4), crackle(1.8, 90)), 0.35, size=1.4)
    c["boss_escalate"] = mix(env_ar(onepole_lp(mix(osc(110, 0.9, "saw", glide=165), osc(116.5, 0.9, "saw", glide=174.6)), 900), 0.3, 0.3),
                             crackle(0.9, 150))
    c["victory"] = room(mix(*[[0] * n(i * 0.14) + bell(f, 1.1, 2.0, 1.0, 0.5) for i, f in enumerate((523, 659, 784, 1047))],
                            [0] * n(0.56) + gain(bell(1319, 1.2, 2.0, 1.0, 0.6), 0.8)), 0.35)
    c["defeat"] = room(mix(*[[0] * n(i * 0.25) + gain(wood_knock(f, 0.7, 0.5), 0.8) for i, f in enumerate((392, 330, 262, 196))],
                           env_ar(onepole_lp(osc(98, 1.4, "tri"), 500), 0.3, 0.8)), 0.4)
    return c


UI_CUES = {"ui_click", "ui_confirm", "ui_cancel", "ui_invalid", "card_hover", "route_select", "resin"}


# ------------------------------------------------------------------- music
NOTE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def hz(name):
    """'D4', 'Bb3', 'F#5' -> frequency."""
    letter = name[0]
    acc = 1 if "#" in name else (-1 if "b" in name[1:] else 0)
    octave = int(name[-1])
    semis = NOTE[letter] + acc + (octave - 4) * 12 - 9
    return 440.0 * 2 ** (semis / 12.0)


def pluck(f, dur, sr=MSR, damp=0.996, bright=0.5):
    """Karplus-Strong plucked string (harp / koto-like)."""
    period = max(2, int(sr / f))
    buf = [rng.random() * 2 - 1 for _ in range(period)]
    # soften the initial burst
    for _ in range(int(3 * (1 - bright)) + 1):
        buf = [(buf[i] + buf[i - 1]) * 0.5 for i in range(period)]
    out = []
    for i in range(n(dur, sr)):
        v = buf[i % period]
        nxt = buf[(i + 1) % period]
        buf[i % period] = damp * 0.5 * (v + nxt)
        out.append(v)
    return out


def pad(freqs, dur, sr=MSR, cutoff=1200, amp=0.25):
    s = mix(*[mix(osc(f, dur, "saw", 0.5, sr=sr), osc(f * 1.004, dur, "saw", 0.5, sr=sr)) for f in freqs])
    s = onepole_lp(onepole_lp(s, cutoff, sr), cutoff, sr)
    return gain(env_ar(s, dur * 0.3, dur * 0.4, sr), amp / max(1, len(freqs)))


def kick(sr=MSR):
    return env_exp(osc(90, 0.25, glide=45, sr=sr), 0.001, 0.07, sr)


def hand_drum(f=180, sr=MSR):
    s = mix(env_exp(osc(f, 0.15, glide=f * 0.7, sr=sr), 0.001, 0.04, sr), gain(env_exp(onepole_lp(noise(0.1, sr=sr), 2500, sr), 0.0005, 0.02, sr), 0.5))
    return s


def shaker(sr=MSR):
    return env_ar(onepole_hp(noise(0.06, sr=sr), 4000, sr), 0.01, 0.04, sr)


def soft_bell(f, dur, sr=MSR, decay=0.6):
    out = []
    for i in range(n(dur, sr)):
        t = i / sr
        out.append(math.sin(TAU * f * t + 1.2 * math.exp(-t / 0.3) * math.sin(TAU * f * 2 * t)) * math.exp(-t / decay))
    return out


def song(bpm, bars, chords, motif, style):
    beat = 60.0 / bpm
    length = bars * 4 * beat
    L = n(length, MSR)
    out = [0.0] * L

    def put(sig, t, g):
        place(out, sig, t, g, MSR, wrap=True)   # tails wrap -> seamless loop

    bar = 4 * beat
    for b in range(bars):
        root, notes = chords[b % len(chords)]
        t0 = b * bar
        put(pad([hz(x) for x in notes], bar * 1.05, cutoff=900 if style != "boss" else 700, amp=0.5), t0, 1.0)
        # bass
        if style == "menu":
            put(gain(pluck(hz(root), bar, damp=0.998, bright=0.2), 1.0), t0, 0.5)
        else:
            for k in range(8 if style == "boss" else 4):
                step = beat * (0.5 if style == "boss" else 1.0)
                put(env_exp(onepole_lp(osc(hz(root), step * 0.9, "saw", sr=MSR), 500, MSR), 0.004, step * 0.4, MSR), t0 + k * step, 0.35)
        # arpeggio / plucks
        arp = notes + notes[::-1][1:-1]
        steps = 8
        for k in range(steps):
            f = hz(arp[k % len(arp)]) * 2
            put(pluck(f, beat * 1.5, bright=0.6 if style != "boss" else 0.4), t0 + k * beat / 2, 0.22 if style == "menu" else 0.16)
        # percussion
        if style == "battle":
            for k in range(4):
                put(kick(), t0 + k * beat, 0.7 if k % 2 == 0 else 0.4)
                put(hand_drum(200), t0 + k * beat + beat * 0.5, 0.35)
                put(shaker(), t0 + k * beat + beat * 0.75, 0.15)
        elif style == "boss":
            for k in range(4):
                put(kick(), t0 + k * beat, 0.9)
                put(kick(), t0 + k * beat + beat * 0.75, 0.4 if k % 2 else 0.0)
                put(hand_drum(140), t0 + k * beat + beat * 0.5, 0.5)
                put(shaker(), t0 + k * beat + beat * 0.25, 0.18)
    # motif (bell melody): list of (bar, beat, note, beats)
    for (mb, mbeat, note, beats) in motif:
        t = mb * bar + mbeat * beat
        put(soft_bell(hz(note), beat * beats + 0.8, decay=0.5 if style != "boss" else 0.35), t, 0.32 if style == "menu" else 0.26)
    out = room(out, 0.22, MSR, 1.2)
    # fold the reverb tail back into the start for a seamless loop
    tail = out[L:]
    out = out[:L]
    for i, v in enumerate(tail):
        out[i % L] += v
    return out


# Shared LASTROOT motif: D - F - A - G | F - E - D (the "root" phrase).
MOTIF = ["D5", "F5", "A5", "G5", "F5", "E5", "D5"]


def music():
    menu_chords = [("D2", ["D3", "A3", "F4"]), ("A1", ["A2", "E3", "C4"]), ("Bb1", ["Bb2", "F3", "D4"]), ("C2", ["C3", "G3", "E4"])]
    menu_motif = [(0, 0, MOTIF[0], 1), (0, 1, MOTIF[1], 1), (0, 2, MOTIF[2], 2), (1, 0, MOTIF[3], 1), (1, 1, MOTIF[4], 1),
                  (1, 2, MOTIF[5], 1), (1, 3, MOTIF[6], 1), (4, 0, "A5", 1), (4, 1, "G5", 1), (4, 2, "F5", 2), (5, 0, "E5", 2),
                  (5, 2, "D5", 2)]
    battle_chords = [("D2", ["D3", "A3", "F4"]), ("D2", ["D3", "A3", "G4"]), ("Bb1", ["Bb2", "F3", "D4"]), ("C2", ["C3", "G3", "E4"])]
    battle_motif = [(0, 0, "D5", 0.5), (0, 0.5, "F5", 0.5), (0, 1, "A5", 1), (1, 2, "G5", 0.5), (1, 2.5, "F5", 0.5), (1, 3, "D5", 1),
                    (4, 0, "D5", 0.5), (4, 0.5, "F5", 0.5), (4, 1, "C6", 1), (5, 2, "A5", 0.5), (5, 2.5, "G5", 0.5), (5, 3, "E5", 1)]
    boss_chords = [("D2", ["D3", "Ab3", "F4"]), ("Eb2", ["Eb3", "Bb3", "G4"]), ("D2", ["D3", "A3", "F4"]), ("C#2", ["C#3", "G#3", "E4"])]
    boss_motif = [(0, 0, "D5", 1), (0, 1, "F5", 1), (0, 2, "Ab5", 2), (1, 0, "G5", 1), (1, 1, "Eb5", 1), (1, 2, "D5", 2),
                  (2, 0, "D5", 1), (2, 1, "F5", 1), (2, 2, "A5", 2), (3, 0, "Ab5", 2), (3, 2, "C#5", 2)]
    return {
        "music_menu": song(72, 8, menu_chords, menu_motif, "menu"),
        "music_battle": song(100, 8, battle_chords, battle_motif, "battle"),
        "music_boss": song(108, 4, boss_chords, boss_motif, "boss"),
    }


def main():
    ap = argparse.ArgumentParser()
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    ap.add_argument("--out", default=os.path.join(root, "assets", "audio", "placeholder"))
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    total = 0
    count = 0
    for name, sig in cues().items():
        sig = trim_tail(sig)
        # Same perceived level per family; peaks capped (-3 dBFS SFX, -10 UI).
        sig = loudness(sig, -27.0, -10.0) if name in UI_CUES else loudness(sig, -18.0, -3.0)
        sig = fade_edges(sig)
        p = os.path.join(args.out, name + ".wav")
        write(p, sig)
        total += os.path.getsize(p)
        count += 1
    for name, sig in music().items():
        sig = normalise(sig, -9.0)
        p = os.path.join(args.out, name + ".wav")
        write(p, sig, MSR)
        total += os.path.getsize(p)
        count += 1
    print("gen_placeholder_audio: %d files, %.1f KB -> %s" % (count, total / 1024, args.out))


if __name__ == "__main__":
    main()
