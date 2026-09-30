#!/usr/bin/env python3
"""
Générateur des sons et des musiques du jeu (synthèse en Python pur, sans bibliothèque).

Tout est fabriqué par programme : bruitages courts (coups, pas, récolte, magie, interface),
ambiances en boucle (jour, nuit, feu) et musiques en boucle (titre, jour, nuit, combat).
Les fichiers vont dans assets/audio/sfx/ et assets/audio/music/ (WAV 16 bits mono).
Pour remplacer un son par un vrai enregistrement : garde le même nom de fichier (.wav ou .ogg).

Usage :
    python audio_generator.py            (tout)
    python audio_generator.py --only hit,swing
"""
import argparse, math, os, random, struct, wave

SR = 22050
TAU = math.pi * 2


# ---------------------------------------------------------------- briques de base

def silence(sec):
    return [0.0] * int(sec * SR)


def osc(kind, freq, sec, phase=0.0):
    """Oscillateur : sine, square, saw, tri. `freq` peut être une fonction du temps (glissando)."""
    n = int(sec * SR)
    out = [0.0] * n
    ph = phase
    for i in range(n):
        f = freq(i / SR) if callable(freq) else freq
        ph += f / SR
        x = ph - math.floor(ph)
        if kind == 'sine':
            v = math.sin(TAU * x)
        elif kind == 'square':
            v = 1.0 if x < 0.5 else -1.0
        elif kind == 'saw':
            v = 2.0 * x - 1.0
        else:  # tri
            v = 4.0 * abs(x - 0.5) - 1.0
        out[i] = v
    return out


def noise(sec, seed=1):
    rnd = random.Random(seed)
    return [rnd.uniform(-1.0, 1.0) for _ in range(int(sec * SR))]


def env(sig, a=0.005, d=0.1, s=0.0, r=0.05, hold=None):
    """Enveloppe ADSR (s = niveau de maintien, hold = durée du maintien, sinon jusqu'à la fin - r)."""
    n = len(sig)
    A, D, R = int(a * SR), int(d * SR), int(r * SR)
    H = int(hold * SR) if hold is not None else max(0, n - A - D - R)
    out = [0.0] * n
    for i in range(n):
        if i < A:
            g = i / max(1, A)
        elif i < A + D:
            g = 1.0 + (s - 1.0) * (i - A) / max(1, D)
        elif i < A + D + H:
            g = s
        else:
            g = s * max(0.0, 1.0 - (i - A - D - H) / max(1, R))
        out[i] = sig[i] * g
    return out


def expdecay(sig, t):
    """Décroissance exponentielle (t = temps pour diviser par e)."""
    k = 1.0 / (t * SR)
    return [v * math.exp(-i * k) for i, v in enumerate(sig)]


def lowpass(sig, cutoff):
    """Filtre passe-bas à un pôle ; `cutoff` peut être une fonction du temps."""
    out = [0.0] * len(sig)
    y = 0.0
    for i, v in enumerate(sig):
        c = cutoff(i / SR) if callable(cutoff) else cutoff
        a = 1.0 - math.exp(-TAU * c / SR)
        y += a * (v - y)
        out[i] = y
    return out


def highpass(sig, cutoff):
    lp = lowpass(sig, cutoff)
    return [a - b for a, b in zip(sig, lp)]


def bandpass(sig, lo, hi):
    return lowpass(highpass(sig, lo), hi)


def gain(sig, g):
    return [v * g for v in sig]


def mix(*sigs):
    n = max(len(s) for s in sigs)
    out = [0.0] * n
    for s in sigs:
        for i, v in enumerate(s):
            out[i] += v
    return out


def place(dst, src, at_sec, g=1.0):
    """Ajoute `src` dans `dst` à partir de `at_sec` (avec bouclage : pour les musiques en boucle)."""
    i0 = int(at_sec * SR)
    n = len(dst)
    for i, v in enumerate(src):
        dst[(i0 + i) % n] += v * g


def normalize(sig, peak=0.9):
    m = max(1e-6, max(abs(v) for v in sig))
    return [v * peak / m for v in sig]


def fade(sig, fin=0.004, fout=0.02):
    n = len(sig)
    a, b = int(fin * SR), int(fout * SR)
    out = list(sig)
    for i in range(min(a, n)):
        out[i] *= i / max(1, a)
    for i in range(min(b, n)):
        out[n - 1 - i] *= i / max(1, b)
    return out


def write(path, sig, peak=0.9):
    sig = normalize(sig, peak)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1.0, min(1.0, v)) * 32000)) for v in sig))


def note(n):
    """Fréquence d'une note MIDI."""
    return 440.0 * 2 ** ((n - 69) / 12.0)


# ---------------------------------------------------------------- bruitages

def sfx_swing():
    s = noise(0.22, 3)
    s = bandpass(s, 400, lambda t: 900 + 5000 * math.sin(math.pi * min(1.0, t / 0.22)))
    return env(s, 0.03, 0.19, 0, 0)


def sfx_hit():
    body = expdecay(osc('sine', lambda t: 170 - 260 * t, 0.18), 0.05)
    click = expdecay(bandpass(noise(0.08, 5), 800, 4000), 0.012)
    return mix(gain(body, 1.0), gain(click, 0.7))


def sfx_hit_heavy():
    body = expdecay(osc('sine', lambda t: 120 - 150 * t, 0.35), 0.1)
    crunch = expdecay(lowpass(noise(0.2, 7), 2500), 0.04)
    return mix(body, gain(crunch, 0.8))


def sfx_block():
    parts = [expdecay(osc('sine', f, 0.35), 0.08) for f in (620, 1260, 1990, 2710)]
    thud = expdecay(lowpass(noise(0.1, 9), 1200), 0.02)
    return mix(*[gain(p, 1.0 / (i + 1)) for i, p in enumerate(parts)], gain(thud, 0.8))


def sfx_parry():
    ring = mix(*[gain(expdecay(osc('sine', f, 0.9), 0.35), g) for f, g in ((1320, 1.0), (1980, 0.6), (2640, 0.35), (3960, 0.2))])
    hit = expdecay(bandpass(noise(0.05, 11), 2000, 8000), 0.01)
    return mix(ring, gain(hit, 0.8))


def sfx_dash():
    s = bandpass(noise(0.3, 13), 200, lambda t: 600 + 2500 * (1 - t / 0.3))
    return env(s, 0.02, 0.28, 0, 0)


def sfx_hurt():
    s = osc('saw', lambda t: 330 - 400 * t, 0.2)
    return expdecay(lowpass(s, 1500), 0.07)


def sfx_enemy_die():
    s = osc('square', lambda t: 300 * (1 - t * 1.6) + 60, 0.45)
    return env(lowpass(s, 1400), 0.005, 0.44, 0, 0)


def sfx_player_die():
    notes = [67, 63, 60, 55]
    out = silence(1.3)
    for i, n in enumerate(notes):
        place(out, env(osc('tri', note(n), 0.4), 0.01, 0.39, 0, 0), i * 0.25, 0.8)
    return out


def _step(seed, lo, hi, t):
    return expdecay(bandpass(noise(0.12, seed), lo, hi), t)


def sfx_step_grass(): return _step(21, 300, 2500, 0.025)
def sfx_step_stone(): return mix(_step(22, 800, 5000, 0.012), gain(expdecay(osc('sine', 220, 0.06), 0.01), 0.4))
def sfx_step_wood(): return mix(_step(23, 200, 1500, 0.02), gain(expdecay(osc('sine', 150, 0.1), 0.03), 0.7))
def sfx_step_sand(): return _step(24, 1500, 7000, 0.035)


def sfx_chop():
    thock = expdecay(osc('sine', lambda t: 260 - 300 * t, 0.2), 0.04)
    crack = expdecay(bandpass(noise(0.15, 31), 600, 3500), 0.02)
    return mix(thock, gain(crack, 0.9))


def sfx_pick():
    parts = [expdecay(osc('sine', f, 0.25), 0.04) for f in (1800, 2750, 4100)]
    click = expdecay(highpass(noise(0.05, 33), 3000), 0.006)
    return mix(*parts, gain(click, 1.2))


def sfx_break_wood():
    out = silence(0.5)
    for i in range(5):
        place(out, expdecay(bandpass(noise(0.15, 40 + i), 400, 3000), 0.03), i * 0.06, 1.0 - i * 0.15)
    place(out, expdecay(osc('sine', 110, 0.3), 0.08), 0.0, 0.8)
    return out


def sfx_break_stone():
    out = silence(0.6)
    for i in range(6):
        place(out, expdecay(bandpass(noise(0.12, 50 + i), 900, 6000), 0.02), i * 0.05, 1.0 - i * 0.12)
    place(out, expdecay(lowpass(noise(0.4, 59), 600), 0.12), 0.0, 0.9)
    return out


def sfx_dig():
    s = mix(expdecay(lowpass(noise(0.25, 61), 900), 0.06), gain(expdecay(osc('sine', 90, 0.2), 0.05), 0.6))
    return s


def sfx_place():
    return mix(expdecay(osc('sine', lambda t: 200 - 200 * t, 0.15), 0.03), gain(expdecay(lowpass(noise(0.1, 63), 1500), 0.015), 0.6))


def sfx_pickup():
    out = silence(0.22)
    place(out, env(osc('square', note(79), 0.08), 0.002, 0.07, 0, 0.005), 0.0, 0.5)
    place(out, env(osc('square', note(86), 0.12), 0.002, 0.11, 0, 0.005), 0.07, 0.5)
    return lowpass(out, 5000)


def sfx_levelup():
    out = silence(1.2)
    for i, n in enumerate((60, 64, 67, 72, 76, 79, 84)):
        place(out, env(osc('tri', note(n), 0.5), 0.005, 0.49, 0, 0), i * 0.07, 0.7)
    place(out, env(osc('sine', note(84), 0.8), 0.01, 0.79, 0, 0), 0.5, 0.4)
    return out


def sfx_cast():
    s = mix(osc('sine', lambda t: 500 + 1500 * t, 0.5), gain(osc('sine', lambda t: 753 + 2200 * t, 0.5), 0.5))
    sh = bandpass(noise(0.5, 71), 3000, 9000)
    return env(mix(s, gain(sh, 0.3)), 0.05, 0.45, 0, 0)


def sfx_boss_roar():
    s = osc('saw', lambda t: 70 + 25 * math.sin(t * 18) - 20 * t, 1.6)
    n = lowpass(noise(1.6, 73), 700)
    return env(lowpass(mix(s, gain(n, 0.8)), 900), 0.15, 1.2, 0.0, 0.25, hold=0.0)


def sfx_horn():
    out = silence(2.2)
    for f, g in ((note(50), 1.0), (note(57), 0.7)):
        s = mix(osc('saw', f, 2.0), gain(osc('saw', f * 1.005, 2.0), 0.7))
        place(out, env(lowpass(s, 1400), 0.25, 0.3, 0.8, 0.6), 0.0, g)
    return out


def sfx_ui_click():
    return env(osc('square', 1400, 0.035), 0.001, 0.034, 0, 0)


def sfx_ui_open():
    out = silence(0.18)
    place(out, env(osc('tri', note(72), 0.08), 0.002, 0.078, 0, 0), 0.0, 0.6)
    place(out, env(osc('tri', note(79), 0.1), 0.002, 0.098, 0, 0), 0.06, 0.6)
    return out


def sfx_craft():
    out = silence(0.55)
    for i in range(3):
        place(out, mix(*[expdecay(osc('sine', f, 0.2), 0.05) for f in (900, 1400, 2300)]), i * 0.16, 0.8)
    return out


def sfx_talent():
    out = silence(1.0)
    for i, n in enumerate((72, 76, 79, 83, 88)):
        place(out, expdecay(osc('sine', note(n), 0.6), 0.25), i * 0.09, 0.6)
    return out


def sfx_night():
    s = mix(*[gain(expdecay(osc('sine', f, 3.0), 1.0), g) for f, g in ((110, 1.0), (165, 0.5), (220, 0.35), (330, 0.15))])
    return env(s, 0.01, 2.9, 0, 0.1)


def sfx_day():
    out = silence(1.6)
    for i, n in enumerate((67, 72, 76, 79)):
        place(out, expdecay(osc('tri', note(n), 1.0), 0.4), i * 0.15, 0.6)
    return out


def sfx_sleep():
    out = silence(2.2)
    for i, n in enumerate((76, 72, 69, 64)):
        place(out, expdecay(osc('sine', note(n), 1.2), 0.5), i * 0.35, 0.5)
    return out


def sfx_eat():
    out = silence(0.55)
    for i in range(3):
        place(out, expdecay(bandpass(noise(0.1, 90 + i), 500, 3500), 0.03), i * 0.15, 0.9 - i * 0.2)
    return out


def sfx_coins():
    """Pièces qui tintent (achat, vente)."""
    out = silence(0.45)
    for i, (n, at) in enumerate(((91, 0.0), (96, 0.06), (88, 0.13), (94, 0.2))):
        ring = mix(osc('sine', note(n), 0.25), gain(osc('sine', note(n) * 2.76, 0.25), 0.35))
        place(out, expdecay(ring, 0.06), at, 0.55 - i * 0.07)
    return highpass(out, 900)


def sfx_door():
    return mix(expdecay(osc('saw', lambda t: 180 + 80 * math.sin(t * 40), 0.4), 0.15), gain(expdecay(lowpass(noise(0.2, 81), 900), 0.05), 0.5))


# ---------------------------------------------------------------- ambiances en boucle

def amb_day():
    sec = 12.0
    out = gain(lowpass(noise(sec, 101), 400), 0.25)  # vent doux
    rnd = random.Random(7)
    for k in range(16):
        t0 = rnd.uniform(0, sec)
        base = rnd.uniform(2400, 4200)
        for j in range(rnd.randint(2, 5)):
            chirp = env(osc('sine', lambda t, b=base: b + 1200 * math.sin(t * 60), 0.07), 0.005, 0.06, 0, 0.005)
            place(out, chirp, t0 + j * 0.1, 0.18)
    return out


def amb_night():
    sec = 12.0
    out = gain(lowpass(noise(sec, 103), 250), 0.2)
    rnd = random.Random(9)
    cricket = []
    for i in range(int(0.3 * SR)):
        t = i / SR
        pulse = 1.0 if (t * 30) % 1.0 < 0.5 else 0.0
        cricket.append(math.sin(TAU * 4200 * t) * pulse * (1 - t / 0.3))
    for k in range(26):
        place(out, cricket, rnd.uniform(0, sec), rnd.uniform(0.06, 0.14))
    return out


def amb_rain():
    """Pluie : un souffle aigu régulier et des gouttes qui claquent."""
    sec = 8.0
    out = mix(gain(bandpass(noise(sec, 131), 900, 7000), 0.5), gain(lowpass(noise(sec, 133), 500), 0.35))
    rnd = random.Random(17)
    for k in range(260):
        drop = expdecay(bandpass(noise(0.03, 200 + k), 2500, 9000), 0.008)
        place(out, drop, rnd.uniform(0, sec - 0.05), rnd.uniform(0.05, 0.22))
    return out


def amb_wind():
    """Vent fort (neige, sable) : souffle grave qui enfle et retombe."""
    sec = 10.0
    base = bandpass(noise(sec, 141), 150, 1400)
    out = []
    for i, v in enumerate(base):
        t = i / SR
        swell = 0.55 + 0.45 * math.sin(TAU * t / sec * 2) * math.sin(TAU * t / sec * 3 + 1.0)
        out.append(v * swell)
    return mix(out, gain(highpass(noise(sec, 143), 3000), 0.08))


def sfx_thunder():
    """Tonnerre : craquement puis grondement grave."""
    crack = expdecay(highpass(noise(0.25, 151), 1200), 0.05)
    rumble = env(lowpass(noise(3.2, 153), 180), 0.05, 0.6, 0.55, 2.2)
    out = silence(3.4)
    place(out, crack, 0.0, 0.7)
    place(out, rumble, 0.05, 1.6)
    place(out, gain(lowpass(noise(1.5, 155), 90), 1.0), 0.6, 0.9)
    return out


def amb_fire():
    sec = 6.0
    out = gain(lowpass(noise(sec, 105), 600), 0.4)
    rnd = random.Random(11)
    for k in range(60):
        pop = expdecay(bandpass(noise(0.03, 200 + k), 1500, 7000), 0.004)
        place(out, pop, rnd.uniform(0, sec), rnd.uniform(0.3, 1.0))
    return out


# ---------------------------------------------------------------- musiques en boucle

def pluck(freq, sec, kind='tri', decay=0.35):
    return expdecay(lowpass(osc(kind, freq, sec), 3000), decay)


def pad(freqs, sec, vol=0.12, cutoff=1200):
    s = mix(*[osc('saw', f, sec) for f in freqs] + [osc('saw', f * 1.004, sec) for f in freqs])
    return gain(env(lowpass(s, cutoff), 0.4, 0.2, 0.8, 0.5), vol)


def kick():
    return expdecay(osc('sine', lambda t: 140 - 400 * t if t < 0.2 else 60, 0.3), 0.08)


def snare():
    return mix(expdecay(bandpass(noise(0.2, 301), 1000, 7000), 0.05), gain(expdecay(osc('tri', 190, 0.15), 0.04), 0.5))


def hat():
    return expdecay(highpass(noise(0.05, 303), 7000), 0.012)


CHORDS = {  # accords en notes MIDI
    'C': [48, 55, 60, 64, 67], 'G': [43, 50, 55, 59, 62], 'Am': [45, 52, 57, 60, 64], 'F': [41, 48, 53, 57, 60],
    'Dm': [38, 45, 50, 53, 57], 'Em': [40, 47, 52, 55, 59], 'E': [40, 47, 52, 56, 59], 'Bb': [46, 53, 58, 62, 65],
    'A': [45, 52, 57, 61, 64], 'Gm': [43, 50, 55, 58, 62], 'C7': [48, 55, 58, 64, 67],
}


def song(progression, bpm, bars_per_chord, melody, style):
    beat = 60.0 / bpm
    bar = beat * 4
    total = bar * bars_per_chord * len(progression)
    out = [0.0] * int(total * SR)
    t = 0.0
    for ch in progression:
        notes = CHORDS[ch]
        for b in range(bars_per_chord):
            if style in ('day', 'title'):
                # arpège doux + basse
                for k in range(8):
                    n = notes[1 + (k % 4)] + (12 if style == 'title' and k % 4 == 3 else 0)
                    place(out, pluck(note(n), beat, 'tri', 0.25), t + k * beat / 2, 0.22)
                place(out, pluck(note(notes[0]), bar, 'sine', 0.6), t, 0.45)
                place(out, pluck(note(notes[0]), bar, 'sine', 0.6), t + 2 * beat, 0.3)
            elif style == 'night':
                place(out, pad([note(n) for n in notes[1:4]], bar * 1.02, 0.1, 700), t, 1.0)
                place(out, pluck(note(notes[0]), bar, 'sine', 1.0), t, 0.35)
            elif style == 'combat':
                for k in range(8):
                    n = notes[0] + (12 if k % 2 else 0)
                    place(out, pluck(note(n), beat / 2, 'square', 0.08), t + k * beat / 2, 0.16)
                for k in range(4):
                    place(out, kick(), t + k * beat, 0.7 if k % 2 == 0 else 0.0)
                    place(out, snare(), t + k * beat, 0.45 if k % 2 == 1 else 0.0)
                    place(out, hat(), t + k * beat + beat / 2, 0.25)
                place(out, pad([note(n) for n in notes[2:5]], bar, 0.07, 1800), t, 1.0)
            t += bar
    # mélodie : liste de (temps en temps, note MIDI, durée en temps)
    lead = {'day': ('tri', 0.35, 0.3), 'title': ('saw', 0.25, 0.4), 'night': ('sine', 0.8, 0.28), 'combat': ('square', 0.12, 0.18)}[style]
    for (tb, n, d) in melody:
        s = osc(lead[0], note(n), d * beat)
        s = env(lowpass(s, 2600), 0.01, d * beat * 0.4, 0.5, d * beat * 0.4)
        place(out, expdecay(s, lead[1] + d * beat), tb * beat, lead[2])
    return fade(out, 0.0, 0.0)


def music_day():
    prog = ['C', 'G', 'Am', 'F', 'C', 'G', 'F', 'C']
    mel = []
    phrase = [(0, 72, 1), (1, 74, 1), (2, 76, 2), (4, 79, 1.5), (5.5, 77, 0.5), (6, 76, 2),
              (8, 74, 1), (9, 72, 1), (10, 74, 2), (12, 76, 1), (13, 74, 1), (14, 72, 2)]
    for rep in range(2):
        mel += [(t + rep * 16, n - (0 if rep == 0 else 0), d) for t, n, d in phrase]
    return song(prog, 92, 1, mel, 'day')


def music_night():
    prog = ['Am', 'F', 'C', 'G', 'Am', 'Dm', 'E', 'Am']
    mel = [(2, 76, 3), (6, 72, 2), (10, 71, 3), (14, 67, 2), (18, 69, 3), (22, 74, 2), (26, 71, 4)]
    return song(prog, 64, 1, mel, 'night')


def music_combat():
    prog = ['Dm', 'Dm', 'Bb', 'C', 'Dm', 'Dm', 'Gm', 'A']
    mel = []
    riff = [(0, 74, 0.5), (0.5, 77, 0.5), (1, 81, 1), (2, 79, 0.5), (2.5, 77, 0.5), (3, 76, 1)]
    for bar in range(8):
        shift = {2: -2, 3: 0, 6: -2, 7: 1}.get(bar, 0)
        mel += [(t + bar * 4, n + shift, d) for t, n, d in riff]
    return song(prog, 140, 1, mel, 'combat')


def music_title():
    prog = ['F', 'C', 'Dm', 'Bb', 'F', 'C', 'Bb', 'C7']
    mel = [(0, 72, 2), (2, 77, 2), (4, 76, 1), (5, 74, 1), (6, 72, 2), (8, 70, 2), (10, 74, 2), (12, 72, 4),
           (16, 72, 2), (18, 77, 2), (20, 79, 1), (21, 81, 1), (22, 79, 2), (24, 77, 2), (26, 76, 2), (28, 77, 4)]
    return song(prog, 84, 1, mel, 'title')


SFX = {k[4:]: v for k, v in globals().items() if k.startswith('sfx_')}
AMB = {'amb_day': amb_day, 'amb_night': amb_night, 'amb_fire': amb_fire, 'amb_rain': amb_rain, 'amb_wind': amb_wind}
MUSIC = {'day': music_day, 'night': music_night, 'combat': music_combat, 'title': music_title}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='../assets/audio')
    ap.add_argument('--only', default='')
    a = ap.parse_args()
    only = [n for n in a.only.split(',') if n]
    os.makedirs(os.path.join(a.out, 'sfx'), exist_ok=True)
    os.makedirs(os.path.join(a.out, 'music'), exist_ok=True)
    n = 0
    for name, fn in list(SFX.items()) + list(AMB.items()):
        if only and name not in only:
            continue
        write(os.path.join(a.out, 'sfx', name + '.wav'), fade(fn()), 0.85 if name.startswith('amb') else 0.9)
        n += 1
    for name, fn in MUSIC.items():
        if only and name not in only:
            continue
        write(os.path.join(a.out, 'music', name + '.wav'), fn(), 0.8)
        n += 1
    print('%d son(s) écrit(s) dans %s' % (n, a.out))


if __name__ == '__main__':
    main()
