#!/usr/bin/env python3
"""
Générateur des sons et des musiques du jeu (synthèse en Python pur, sans bibliothèque).

Tout est fabriqué par programme : bruitages courts (coups, pas, récolte, magie, interface),
ambiances en boucle (jour, nuit, feu) et musiques (titre, jour, nuit, combat, régions, donjon, boss),
chacune avec deux variantes (<nom>_2, <nom>_3) que le jeu enchaîne au hasard.
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
    """Bouton en planche : un petit « toc » de bois."""
    knock = expdecay(osc('sine', lambda t: 520 - 900 * t, 0.07), 0.018)
    tick = expdecay(bandpass(noise(0.03, 401), 1500, 5000), 0.006)
    return mix(gain(knock, 0.9), gain(tick, 0.5))


def sfx_ui_open():
    """Parchemin qu'on déroule : un froissement qui glisse, puis un léger claquement."""
    out = silence(0.42)
    rustle = env(bandpass(noise(0.34, 403), lambda t: 900 + 2600 * t, 6500), 0.03, 0.12, 0.6, 0.15)
    place(out, rustle, 0.0, 0.55)
    place(out, expdecay(lowpass(noise(0.05, 404), 1800), 0.012), 0.33, 0.6)
    return out


def sfx_ui_close():
    """Parchemin qu'on roule : froissement plus court, vers le grave."""
    rustle = env(bandpass(noise(0.24, 405), lambda t: 3200 - 6000 * t, 6000), 0.01, 0.1, 0.4, 0.1)
    return gain(rustle, 0.6)


def sfx_ui_page():
    """Page tournée (changement d'onglet) : un souffle de papier."""
    swish = env(bandpass(noise(0.2, 407), lambda t: 1400 + 5000 * t, 8000), 0.02, 0.06, 0.3, 0.1)
    flick = expdecay(highpass(noise(0.03, 408), 3000), 0.008)
    out = silence(0.24)
    place(out, swish, 0.0, 0.6)
    place(out, flick, 0.16, 0.35)
    return out


def sfx_ui_hover():
    """Survol : un tic très doux."""
    return gain(expdecay(osc('sine', 1900, 0.03), 0.006), 0.35)


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


# Variantes : pour que la musique ne tourne pas en rond, chaque morceau a deux variantes (<nom>_2, <nom>_3)
# que le jeu enchaîne avec le thème d'origine dans un ordre au hasard (voir scripts/audio/sound.gd).
# Une variante garde les accords, le tempo et les instruments, mais invente une nouvelle mélodie
# sur les notes des accords ; elle répète la grille assez de fois pour durer au moins VARIANT_SEC.
VARIANTS = 2
VARIANT_SEC = 30.0

RHYTHMS = [  # motifs d'une mesure : (début, durée) en temps
    [(0, 2), (2, 2)], [(0, 1), (1, 1), (2, 2)], [(0, 3), (3, 1)], [(0, 1.5), (1.5, 0.5), (2, 2)], [(0, 4)],
    [(0, 1), (1, 1), (2, 1), (3, 1)], [(0, 0.5), (0.5, 0.5), (1, 1), (2, 0.5), (2.5, 0.5), (3, 1)],
    [(0, 0.5), (0.5, 0.5), (1, 0.5), (1.5, 0.5), (2, 1), (3, 1)], [(1, 1), (2, 2)], [(0, 2), (2, 1), (3, 1)],
]


def invented_melody(prog, ref, seed, bars_per_chord=1, sparse=False):
    """Mélodie inventée sur les notes des accords, dans le registre et au débit de la mélodie `ref`."""
    rnd = random.Random(seed)
    lo = min(n for _, n, _ in ref)
    hi = max(n for _, n, _ in ref)
    if hi - lo < 7:
        lo, hi = lo - 3, hi + 4
    # débit de la mélodie d'origine : notes par mesure
    span = max(4.0, max(t + d for t, _, d in ref))
    per_bar = len(ref) / (span / 4.0)
    if sparse:
        per_bar = max(0.5, per_bar * 0.5)
    pool = sorted(RHYTHMS, key=lambda r: abs(len(r) - per_bar))[:4]
    out = []
    prev = (lo + hi) // 2
    t = 0.0
    bars = [ch for ch in prog for _ in range(bars_per_chord)]
    motif = rnd.choice(pool)
    for i, ch in enumerate(bars):
        pcs = {n % 12 for n in CHORDS[ch]}
        tones = [n for n in range(lo, hi + 1) if n % 12 in pcs]
        # un motif rythmique repris sur deux mesures, puis un autre ; une mesure sur quatre respire (sparse)
        if i % 2 == 0:
            motif = rnd.choice(pool)
        last = i == len(bars) - 1
        if sparse and i % 4 == 3 and not last:
            t += 4
            continue
        rhythm = [(0, 4)] if last else motif
        for at, d in rhythm:
            near = sorted(tones, key=lambda n: (abs(n - prev), rnd.random()))
            choice = [n for n in near[:4] if n != prev] or near
            n = choice[0] if rnd.random() < 0.55 else rnd.choice(choice)
            if last:
                n = min(tones, key=lambda m: (m % 12 != CHORDS[ch][0] % 12, abs(m - prev)))
            out.append((t + at, n, d))
            prev = n
        t += 4
    return out


def vary(prog, melody, bpm, v, bars_per_chord=1):
    """Variante n° v d'un morceau (0 = l'original) : (accords, mélodie, calme ?).
    v = 1 : nouvelles mélodies sur la même grille ; v = 2 : passage plus calme (grille décalée, mélodie clairsemée)."""
    if v == 0:
        return prog, melody, False
    calm = v >= 2
    if calm and len(prog) >= 8:
        prog = prog[len(prog) // 2:] + prog[:len(prog) // 2]
    one = 60.0 / bpm * 4 * bars_per_chord * len(prog)
    passes = max(1, int(math.ceil(VARIANT_SEC / one)))
    beats = 4 * bars_per_chord * len(prog)
    mel = []
    for k in range(passes):
        part = invented_melody(prog, melody, 1000 * v + 37 * k + len(melody), bars_per_chord, sparse=calm)
        mel += [(tb + k * beats, n, d) for tb, n, d in part]
    return prog * passes, mel, calm


def song(progression, bpm, bars_per_chord, melody, style, v=0):
    progression, melody, _ = vary(progression, melody, bpm, v, bars_per_chord)
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


def music_day(v=0):
    prog = ['C', 'G', 'Am', 'F', 'C', 'G', 'F', 'C']
    mel = []
    phrase = [(0, 72, 1), (1, 74, 1), (2, 76, 2), (4, 79, 1.5), (5.5, 77, 0.5), (6, 76, 2),
              (8, 74, 1), (9, 72, 1), (10, 74, 2), (12, 76, 1), (13, 74, 1), (14, 72, 2)]
    for rep in range(2):
        mel += [(t + rep * 16, n - (0 if rep == 0 else 0), d) for t, n, d in phrase]
    return song(prog, 92, 1, mel, 'day', v=v)


def music_night(v=0):
    prog = ['Am', 'F', 'C', 'G', 'Am', 'Dm', 'E', 'Am']
    mel = [(2, 76, 3), (6, 72, 2), (10, 71, 3), (14, 67, 2), (18, 69, 3), (22, 74, 2), (26, 71, 4)]
    return song(prog, 64, 1, mel, 'night', v=v)


def music_combat(v=0):
    prog = ['Dm', 'Dm', 'Bb', 'C', 'Dm', 'Dm', 'Gm', 'A']
    mel = []
    riff = [(0, 74, 0.5), (0.5, 77, 0.5), (1, 81, 1), (2, 79, 0.5), (2.5, 77, 0.5), (3, 76, 1)]
    for bar in range(8):
        shift = {2: -2, 3: 0, 6: -2, 7: 1}.get(bar, 0)
        mel += [(t + bar * 4, n + shift, d) for t, n, d in riff]
    return song(prog, 140, 1, mel, 'combat', v=v)


def music_title(v=0):
    prog = ['F', 'C', 'Dm', 'Bb', 'F', 'C', 'Bb', 'C7']
    mel = [(0, 72, 2), (2, 77, 2), (4, 76, 1), (5, 74, 1), (6, 72, 2), (8, 70, 2), (10, 74, 2), (12, 72, 4),
           (16, 72, 2), (18, 77, 2), (20, 79, 1), (21, 81, 1), (22, 79, 2), (24, 77, 2), (26, 76, 2), (28, 77, 4)]
    return song(prog, 84, 1, mel, 'title', v=v)


# ---------------------------------------------------------------- nouveaux systèmes (leviers, pièges, potions, succès, événements...)

def sfx_hit_light():
    click = expdecay(bandpass(noise(0.06, 81), 1200, 5000), 0.012)
    body = expdecay(osc('sine', lambda t: 260 - 300 * t, 0.1), 0.03)
    return mix(gain(click, 0.8), gain(body, 0.6))


def sfx_lever():
    out = silence(0.5)
    clunk = expdecay(lowpass(noise(0.12, 83), 900), 0.04)
    place(out, mix(clunk, gain(expdecay(osc('sine', 110, 0.2), 0.06), 0.8)), 0.0, 1.0)
    place(out, expdecay(bandpass(noise(0.08, 84), 1500, 6000), 0.015), 0.22, 0.6)
    return out


def sfx_spikes():
    shink = mix(*[gain(expdecay(osc('sine', f, 0.35), 0.09), g) for f, g in ((2100, 0.6), (3150, 0.4), (4400, 0.3))])
    scrape = env(bandpass(noise(0.18, 85), 2500, 9000), 0.005, 0.17, 0, 0)
    return mix(shink, gain(scrape, 0.7))


def sfx_stone_grind():
    s = lowpass(noise(1.2, 87), lambda t: 300 + 500 * math.sin(math.pi * t / 1.2))
    rumble = osc('sine', lambda t: 55 + 10 * math.sin(t * 9), 1.2)
    return env(mix(s, gain(rumble, 0.6)), 0.15, 0.6, 0.6, 0.4)


def sfx_potion():
    out = silence(0.7)
    for i in range(5):
        b = env(osc('sine', lambda t, i=i: 300 + 90 * i + 900 * t, 0.09), 0.005, 0.085, 0, 0)
        place(out, b, 0.05 + i * 0.1, 0.6)
    place(out, env(bandpass(noise(0.3, 89), 2000, 7000), 0.05, 0.25, 0, 0), 0.35, 0.3)
    return out


def sfx_socket():
    out = silence(0.8)
    place(out, expdecay(osc('sine', 1800, 0.08), 0.02), 0.0, 0.6)
    for i, n in enumerate((88, 91, 95, 100)):
        place(out, env(osc('sine', note(n), 0.35), 0.003, 0.34, 0, 0), 0.08 + i * 0.06, 0.35)
    return out


def sfx_rune():
    hum = mix(osc('sine', lambda t: 220 + 30 * t, 1.0), gain(osc('sine', lambda t: 331 + 50 * t, 1.0), 0.6))
    sh = bandpass(noise(1.0, 91), 4000, 9000)
    return env(mix(hum, gain(sh, 0.25)), 0.2, 0.5, 0.4, 0.3)


def sfx_achievement():
    out = silence(1.4)
    for i, n in enumerate((72, 76, 79, 84)):
        place(out, env(osc('tri', note(n), 0.6), 0.005, 0.59, 0, 0), i * 0.09, 0.6)
    for n in (84, 88, 91):
        place(out, env(osc('sine', note(n), 0.9), 0.01, 0.89, 0, 0), 0.38, 0.3)
    return out


def sfx_event():
    out = silence(1.8)
    for i, f in enumerate((note(67), note(72))):
        bell = mix(*[gain(expdecay(osc('sine', f * h, 1.4), 0.5 / h), g) for h, g in ((1, 1.0), (2.01, 0.5), (3.02, 0.3), (4.2, 0.2))])
        place(out, bell, i * 0.35, 0.6)
    return out


def sfx_war_drums():
    out = silence(2.0)
    for i, t in enumerate((0.0, 0.25, 0.5, 1.0, 1.25, 1.5, 1.75)):
        d = expdecay(osc('sine', lambda tt: 70 - 40 * tt, 0.35), 0.12)
        place(out, mix(d, gain(expdecay(lowpass(noise(0.1, 93 + i), 600), 0.03), 0.6)), t, 1.0 if i % 3 == 0 else 0.7)
    return out


def sfx_fanfare():
    out = silence(1.6)
    seq = ((67, 0.0, 0.18), (67, 0.2, 0.18), (72, 0.4, 0.18), (76, 0.6, 0.7))
    for n, at, d in seq:
        s = mix(osc('saw', note(n), d), gain(osc('saw', note(n) * 1.004, d), 0.6))
        place(out, env(lowpass(s, 2200), 0.02, d * 0.4, 0.6, d * 0.4), at, 0.6)
    return out


def sfx_treaty():
    out = silence(0.9)
    scratch = env(bandpass(noise(0.4, 95), 2500, 8000), 0.02, 0.38, 0, 0)
    place(out, scratch, 0.0, 0.4)
    seal = mix(expdecay(osc('sine', 140, 0.25), 0.06), expdecay(lowpass(noise(0.08, 96), 1500), 0.02))
    place(out, seal, 0.45, 1.0)
    return out


# ---------------------------------------------------------------- musiques des régions, des donjons et des boss

CHORDS.update({
    'D': [38, 45, 50, 54, 57], 'Eb': [39, 46, 51, 55, 58], 'Cm': [36, 43, 48, 51, 55], 'Ab': [44, 51, 56, 60, 63],
    'B': [47, 54, 59, 63, 66], 'Fm': [41, 48, 53, 56, 60], 'Bm': [47, 54, 59, 62, 66], 'Gsus': [43, 50, 55, 60, 62],
})


def flute(n, sec):
    """Flûte : sinus avec un vibrato qui s'installe."""
    f = note(n)
    s = osc('sine', lambda t: f * (1 + 0.006 * min(1.0, t * 3) * math.sin(TAU * 5.2 * t)), sec)
    breath = gain(bandpass(noise(sec, 501), f, f * 3), 0.06)
    return env(mix(s, breath), 0.06, 0.1, 0.8, min(0.25, sec * 0.3))


def bell(n, sec, decay=0.9):
    f = note(n)
    return mix(*[gain(expdecay(osc('sine', f * h, sec), decay / h), g) for h, g in ((1, 1.0), (2.76, 0.35), (5.4, 0.15))])


def marimba(n, sec):
    f = note(n)
    return mix(expdecay(osc('sine', f, sec), 0.18), gain(expdecay(osc('sine', f * 4, sec), 0.04), 0.3))


def oud(n, sec):
    return expdecay(lowpass(osc('saw', note(n), sec), 2400), 0.22)


def horn(n, sec):
    f = note(n)
    s = mix(osc('saw', f, sec), gain(osc('saw', f * 1.003, sec), 0.7))
    return env(lowpass(s, 1300), 0.12, 0.2, 0.75, min(0.3, sec * 0.3))


def tom(pitch=110):
    return expdecay(osc('sine', lambda t: pitch - 120 * t, 0.3), 0.09)


LEADS = {'flute': flute, 'bell': lambda n, d: bell(n, d + 0.6), 'marimba': marimba, 'oud': oud, 'horn': horn,
         'square': lambda n, d: env(lowpass(osc('square', note(n), d), 1500), 0.01, d * 0.4, 0.5, d * 0.3)}


def region_song(prog, bpm, melody, lead, accomp, drums='', bass=True, lead_gain=0.32, pad_cut=900, pad_vol=0.08, v=0):
    """Boucle d'une région : accords (pad), accompagnement (arpège ou accords frappés), percussions, mélodie.
    `v` > 0 : une variante (voir vary), la 2e sans percussions."""
    prog, melody, calm = vary(prog, melody, bpm, v)
    if calm:
        drums = ''
    beat = 60.0 / bpm
    bar = beat * 4
    out = [0.0] * int(bar * len(prog) * SR)
    t = 0.0
    for ch in prog:
        notes = CHORDS[ch]
        place(out, pad([note(n) for n in notes[1:4]], bar * 1.02, pad_vol, pad_cut), t, 1.0)
        if bass:
            place(out, pluck(note(notes[0]), bar, 'sine', 0.9), t, 0.4)
        if accomp == 'harp':
            for k in range(8):
                place(out, pluck(note(notes[1 + (k % 4)] + 12), beat, 'tri', 0.3), t + k * beat / 2, 0.14)
        elif accomp == 'celesta':
            for k in range(8):
                place(out, bell(notes[1 + (k * 3) % 4] + 24, beat, 0.4), t + k * beat / 2, 0.08)
        elif accomp == 'marimba':
            for k in range(16):
                if k % 3 != 2:
                    place(out, marimba(notes[1 + (k % 4)] + 12, beat / 2), t + k * beat / 4, 0.16)
        elif accomp == 'oud':
            for k, at in enumerate((0, 1.5, 2, 3, 3.5)):
                place(out, oud(notes[1 + k % 3], beat), t + at * beat, 0.18)
        elif accomp == 'drops':
            for k, at in enumerate((0.5, 2.75)):
                place(out, bell(notes[2 + k] + 24, 1.2, 0.3), t + at * beat, 0.07)
        elif accomp == 'stabs':
            for at in (0, 0.75, 2, 2.75):
                place(out, horn(notes[2], beat * 0.4), t + at * beat, 0.12)
                place(out, horn(notes[3], beat * 0.4), t + at * beat, 0.1)
        if drums == 'hand':
            for at, p, g in ((0, 120, 0.5), (1.5, 160, 0.35), (2, 120, 0.45), (3, 180, 0.3), (3.5, 160, 0.3)):
                place(out, tom(p), t + at * beat, g)
        elif drums == 'shaker':
            for k in range(8):
                place(out, hat(), t + k * beat / 2, 0.18 if k % 2 else 0.1)
            place(out, tom(90), t, 0.4)
            place(out, tom(130), t + 2.5 * beat, 0.3)
        elif drums == 'war':
            for k in range(4):
                place(out, kick(), t + k * beat, 0.7)
                place(out, tom(70), t + k * beat + beat / 2, 0.35 if k % 2 else 0.0)
            place(out, snare(), t + 3 * beat, 0.4)
        elif drums == 'battle':
            for k in range(8):
                place(out, kick(), t + k * beat / 2, 0.6 if k % 2 == 0 else 0.25)
                place(out, hat(), t + k * beat / 2 + beat / 4, 0.2)
            place(out, snare(), t + beat, 0.5)
            place(out, snare(), t + 3 * beat, 0.5)
        elif drums == 'heart':
            place(out, kick(), t, 0.5)
            place(out, kick(), t + beat * 0.4, 0.3)
        t += bar
    fn = LEADS[lead]
    for (tb, n, d) in melody:
        place(out, fn(n, d * beat), tb * beat, lead_gain)
    return fade(out, 0.0, 0.0)


def music_foret(v=0):
    mel = [(0, 69, 2), (2, 72, 1), (3, 74, 1), (4, 72, 3), (8, 69, 1), (9, 67, 1), (10, 69, 2), (12, 64, 4),
           (16, 69, 2), (18, 72, 1), (19, 76, 1), (20, 74, 3), (24, 72, 1), (25, 71, 1), (26, 67, 2), (28, 69, 4)]
    return region_song(['Dm', 'C', 'G', 'Dm', 'Dm', 'C', 'Gsus', 'Am'], 80, mel, 'flute', 'harp', v=v)


def music_marais(v=0):
    mel = [(2, 64, 3), (8, 67, 2), (10, 66, 4), (18, 64, 3), (24, 71, 2), (26, 69, 4)]
    return region_song(['Em', 'C', 'Am', 'B', 'Em', 'C', 'Am', 'B'], 60, mel, 'bell', 'drops', 'heart', pad_cut=600, lead_gain=0.22, v=v)


def music_desert(v=0):
    mel = [(0, 74, 1), (1, 75, 0.5), (1.5, 78, 0.5), (2, 79, 1), (3, 78, 0.5), (3.5, 75, 0.5), (4, 74, 2),
           (8, 81, 1), (9, 79, 0.5), (9.5, 78, 0.5), (10, 75, 1), (11, 74, 1), (12, 74, 4),
           (16, 74, 1), (17, 75, 0.5), (17.5, 78, 0.5), (18, 79, 2), (20, 81, 1), (21, 82, 1), (22, 81, 2),
           (24, 79, 1), (25, 78, 1), (26, 75, 1), (27, 74, 1), (28, 74, 4)]
    return region_song(['D', 'Eb', 'D', 'Cm', 'D', 'Eb', 'Cm', 'D'], 96, mel, 'oud', 'oud', 'hand', lead_gain=0.3, v=v)


def music_montagnes(v=0):
    mel = [(0, 67, 3), (3, 71, 1), (4, 74, 4), (8, 72, 2), (10, 71, 2), (12, 67, 4),
           (16, 67, 3), (19, 71, 1), (20, 76, 4), (24, 74, 2), (26, 72, 2), (28, 71, 4)]
    return region_song(['G', 'D', 'Em', 'C', 'G', 'D', 'C', 'D'], 70, mel, 'horn', 'harp', pad_vol=0.1, pad_cut=1100, lead_gain=0.22, v=v)


def music_toundra(v=0):
    mel = [(0, 81, 2), (4, 76, 2), (8, 79, 2), (12, 72, 4), (16, 81, 2), (20, 84, 2), (24, 79, 2), (28, 76, 4)]
    return region_song(['Am', 'F', 'C', 'Em', 'Am', 'F', 'C', 'Em'], 56, mel, 'bell', 'drops', bass=False, pad_cut=700, lead_gain=0.2, v=v)


def music_bois_enchante(v=0):
    mel = [(0, 77, 1), (1, 79, 1), (2, 81, 2), (4, 83, 1), (5, 81, 1), (6, 79, 2), (8, 77, 3), (12, 72, 4),
           (16, 77, 1), (17, 79, 1), (18, 81, 2), (20, 84, 2), (22, 83, 2), (24, 81, 3), (28, 79, 4)]
    return region_song(['F', 'G', 'Am', 'F', 'F', 'G', 'Em', 'F'], 76, mel, 'flute', 'celesta', lead_gain=0.28, v=v)


def music_volcan(v=0):
    mel = [(0, 60, 1), (1, 63, 1), (2, 67, 2), (4, 68, 2), (6, 67, 2), (8, 65, 1), (9, 63, 1), (10, 62, 2), (12, 60, 4),
           (16, 60, 1), (17, 63, 1), (18, 67, 2), (20, 72, 2), (22, 71, 2), (24, 68, 2), (26, 67, 2), (28, 67, 4)]
    return region_song(['Cm', 'Ab', 'Bb', 'G', 'Cm', 'Ab', 'Fm', 'G'], 100, mel, 'square', 'stabs', 'war', pad_cut=700, lead_gain=0.2, v=v)


def music_jungle(v=0):
    mel = [(0, 72, 0.5), (0.5, 74, 0.5), (1, 76, 1), (2, 79, 1), (3, 76, 1), (4, 74, 2), (6, 72, 2),
           (8, 69, 1), (9, 72, 1), (10, 74, 2), (12, 76, 4),
           (16, 79, 0.5), (16.5, 81, 0.5), (17, 79, 1), (18, 76, 1), (19, 74, 1), (20, 72, 2), (22, 74, 2), (24, 69, 4), (28, 72, 4)]
    return region_song(['Am', 'C', 'G', 'Am', 'F', 'C', 'G', 'Am'], 112, mel, 'flute', 'marimba', 'shaker', lead_gain=0.24, v=v)


def music_dungeon(v=0):
    mel = [(4, 64, 2), (12, 65, 2), (20, 64, 2), (26, 68, 4)]
    return region_song(['Am', 'Am', 'Dm', 'E', 'Am', 'Fm', 'Dm', 'E'], 58, mel, 'bell', 'drops', 'heart', pad_cut=500, pad_vol=0.1, lead_gain=0.18, v=v)


def music_boss(v=0):
    mel = []
    riff = [(0, 72, 0.5), (0.5, 72, 0.5), (1, 75, 0.5), (1.5, 72, 0.5), (2, 79, 1), (3, 77, 0.5), (3.5, 75, 0.5)]
    for b in range(8):
        sh = {1: -4, 2: -2, 3: -5, 5: -4, 6: -7, 7: -5}.get(b, 0)
        mel += [(t + b * 4, n + sh, d) for t, n, d in riff]
    return region_song(['Cm', 'Ab', 'Bb', 'G', 'Cm', 'Ab', 'Fm', 'G'], 150, mel, 'horn', 'stabs', 'battle', pad_cut=1400, pad_vol=0.1, lead_gain=0.22, v=v)


# ---------------------------------------------------------------- impacts : arme qui frappe et matière touchée

def sfx_hit_blade():
    """Lame : un « tchac » vif, sifflement métallique très court et chair entaillée."""
    slice_ = expdecay(bandpass(noise(0.12, 101), 2500, 9000), 0.018)
    ring = mix(*[gain(expdecay(osc('sine', f, 0.2), 0.04), g) for f, g in ((2400, 0.25), (3700, 0.15))])
    body = expdecay(osc('sine', lambda t: 210 - 300 * t, 0.12), 0.03)
    return mix(gain(slice_, 1.0), ring, gain(body, 0.7))


def sfx_hit_blunt():
    """Masse, marteau : un coup sourd et lourd."""
    body = expdecay(osc('sine', lambda t: 95 - 90 * t, 0.32), 0.07)
    thud = expdecay(lowpass(noise(0.18, 103), 900), 0.03)
    return mix(gain(body, 1.0), gain(thud, 1.0))


def sfx_hit_pierce():
    """Lance, dague, flèche : un « tock » sec et pointu."""
    tick = expdecay(bandpass(noise(0.06, 105), 1800, 7000), 0.008)
    body = expdecay(osc('sine', lambda t: 320 - 500 * t, 0.08), 0.02)
    return mix(gain(tick, 1.0), gain(body, 0.6))


def sfx_hit_fist():
    """Poing : un « pof » mat."""
    body = expdecay(osc('sine', lambda t: 150 - 120 * t, 0.14), 0.035)
    puff = expdecay(lowpass(noise(0.1, 107), 1500), 0.02)
    return mix(gain(body, 0.9), gain(puff, 0.8))


def sfx_hit_magic():
    """Bâton, sort : un claquement d'énergie qui grésille."""
    zap = expdecay(osc('saw', lambda t: 1400 - 2600 * t, 0.16), 0.04)
    fizz = expdecay(bandpass(noise(0.16, 109), 3000, 9000), 0.05)
    return mix(gain(lowpass(zap, 4000), 0.6), gain(fizz, 0.6))


def sfx_mat_bone():
    """Os (squelettes) : des claquements secs qui s'entrechoquent."""
    out = silence(0.22)
    for i, (at, f) in enumerate(((0.0, 1900), (0.035, 1500), (0.075, 2300))):
        c = mix(expdecay(osc('square', f, 0.05), 0.008), expdecay(bandpass(noise(0.05, 111 + i), 1500, 6000), 0.006))
        place(out, lowpass(c, 6000), at, 0.8 - i * 0.2)
    return out


def sfx_mat_armor():
    """Armure de métal : un « clang » qui résonne."""
    ring = mix(*[gain(expdecay(osc('sine', f, 0.5), 0.12), g) for f, g in ((880, 1.0), (1420, 0.6), (2210, 0.4), (3170, 0.25))])
    hit = expdecay(bandpass(noise(0.05, 113), 1500, 8000), 0.01)
    return mix(gain(ring, 0.7), hit)


def sfx_mat_stone():
    """Pierre (golems, gargouilles) : un choc minéral et des gravillons."""
    knock = expdecay(osc('sine', lambda t: 260 - 200 * t, 0.18), 0.03)
    grit = expdecay(bandpass(noise(0.25, 115), 1200, 6000), 0.06)
    return mix(gain(knock, 0.8), gain(grit, 0.7))


def sfx_mat_wood():
    """Bois (sylvains, dryades) : un « toc » creux."""
    return mix(expdecay(osc('sine', lambda t: 340 - 120 * t, 0.2), 0.05), gain(expdecay(osc('sine', 690, 0.15), 0.03), 0.4),
               gain(expdecay(bandpass(noise(0.06, 117), 800, 3000), 0.01), 0.5))


def sfx_mat_slime():
    """Gelée, grenouille : un « splotch » mouillé."""
    blob = expdecay(osc('sine', lambda t: 180 + 500 * math.sin(math.pi * min(1.0, t / 0.18)), 0.22), 0.06)
    wet = expdecay(lowpass(noise(0.22, 119), 1200), 0.05)
    return mix(gain(blob, 0.8), gain(wet, 0.8))


def sfx_mat_spirit():
    """Esprits, fantômes : un souffle cristallin."""
    s = mix(*[gain(expdecay(osc('sine', f, 0.45), 0.15), 0.4) for f in (1046, 1568, 2093)])
    air = expdecay(bandpass(noise(0.4, 121), 3000, 9000), 0.12)
    return mix(s, gain(air, 0.5))


# ---------------------------------------------------------------- sorts : un son par genre de magie

def sfx_cast_fire():
    """Feu : une flamme qui s'embrase (souffle grave qui gronde)."""
    roar = env(lowpass(noise(0.7, 131), lambda t: 600 + 2500 * min(1.0, t / 0.25)), 0.04, 0.3, 0.5, 0.3)
    crackle = silence(0.7)
    rnd = random.Random(133)
    for i in range(14):
        place(crackle, expdecay(bandpass(noise(0.03, 140 + i), 2000, 8000), 0.005), rnd.uniform(0.05, 0.6), rnd.uniform(0.3, 0.7))
    return mix(gain(roar, 0.9), crackle, gain(expdecay(osc('sine', lambda t: 80 + 40 * t, 0.7), 0.25), 0.5))


def sfx_cast_ice():
    """Glace : des cristaux qui tintent et se figent."""
    out = silence(0.8)
    for i, f in enumerate((2093, 2637, 3136, 3951, 2349)):
        place(out, expdecay(osc('sine', f, 0.5), 0.12), i * 0.05, 0.35)
    crack = expdecay(bandpass(noise(0.2, 151), 3000, 9000), 0.03)
    return mix(out, gain(crack, 0.6), gain(env(bandpass(noise(0.8, 153), 4000, 10000), 0.2, 0.4, 0, 0.2), 0.2))


def sfx_cast_lightning():
    """Foudre : un claquement électrique et un grésillement."""
    snap = expdecay(bandpass(noise(0.08, 161), 1500, 10000), 0.01)
    buzz = env(lowpass(osc('saw', lambda t: 110 + 30 * math.sin(t * 260), 0.5), 3000), 0.005, 0.2, 0.3, 0.2)
    sizzle = expdecay(highpass(noise(0.5, 163), 5000), 0.12)
    boom = expdecay(osc('sine', lambda t: 70 - 30 * t, 0.5), 0.15)
    return mix(gain(snap, 1.0), gain(buzz, 0.35), gain(sizzle, 0.5), gain(boom, 0.6))


def sfx_cast_holy():
    """Lumière, soin : un accord de cloches qui s'élève."""
    out = silence(1.0)
    for i, n in enumerate((72, 76, 79, 84)):
        place(out, env(mix(osc('sine', note(n), 0.8), gain(osc('sine', note(n) * 2.01, 0.8), 0.25)), 0.02, 0.2, 0.4, 0.4), i * 0.06, 0.4)
    shimmer = env(bandpass(noise(1.0, 171), 5000, 10000), 0.3, 0.3, 0.2, 0.4)
    return mix(out, gain(shimmer, 0.15))


def sfx_cast_shadow():
    """Ombre, vide : un souffle grave inversé qui aspire."""
    swell = env(lowpass(osc('saw', lambda t: 55 + 20 * t, 0.8), lambda t: 200 + 900 * t), 0.6, 0.0, 1.0, 0.15)
    whisper = env(bandpass(noise(0.8, 181), 400, 1800), 0.5, 0.0, 1.0, 0.2)
    return mix(gain(swell, 0.8), gain(whisper, 0.5))


def sfx_cast_nature():
    """Nature : un bruissement de feuilles et un appel de bois."""
    rustle = env(bandpass(noise(0.6, 191), 1500, 6000), 0.1, 0.2, 0.4, 0.25)
    out = silence(0.6)
    for i, n in enumerate((67, 71, 74)):
        place(out, env(osc('tri', note(n), 0.3), 0.01, 0.25, 0, 0.05), i * 0.08, 0.35)
    return mix(gain(rustle, 0.6), out)


def sfx_cast_arcane():
    """Arcane : un scintillement qui monte et tourbillonne."""
    s = mix(osc('sine', lambda t: 600 + 1800 * t + 120 * math.sin(t * 40), 0.6), gain(osc('sine', lambda t: 905 + 2600 * t, 0.6), 0.4))
    return env(mix(s, gain(bandpass(noise(0.6, 201), 4000, 10000), 0.25)), 0.08, 0.3, 0.3, 0.2)


def sfx_cast_physical():
    """Technique d'arme : un grand souffle d'air (élan, charge)."""
    s = bandpass(noise(0.4, 211), 150, lambda t: 400 + 3000 * math.sin(math.pi * min(1.0, t / 0.4)))
    return mix(env(s, 0.05, 0.35, 0, 0), gain(expdecay(osc('sine', lambda t: 90 - 40 * t, 0.4), 0.12), 0.6))


def sfx_ult_charge():
    """Ultime : l'énergie qui se rassemble (montée de plus en plus aiguë)."""
    rise = env(mix(osc('saw', lambda t: 80 + 300 * t * t, 1.1), gain(osc('saw', lambda t: 81 + 303 * t * t, 1.1), 0.8)), 0.4, 0.0, 1.0, 0.05)
    air = env(bandpass(noise(1.1, 221), lambda t: 300 + 4000 * t, lambda t: 1200 + 7000 * t), 0.6, 0.0, 1.0, 0.05)
    return mix(gain(lowpass(rise, lambda t: 400 + 3000 * t), 0.5), gain(air, 0.5))


def sfx_ult_boom():
    """Ultime : la déflagration (sous-grave, souffle et débris qui retombent)."""
    sub = expdecay(osc('sine', lambda t: 55 - 25 * t, 2.2), 0.6)
    blast = expdecay(lowpass(noise(2.2, 231), lambda t: 6000 * math.exp(-t * 2.5) + 300), 0.35)
    out = silence(2.2)
    rnd = random.Random(233)
    for i in range(22):
        place(out, expdecay(bandpass(noise(0.05, 240 + i), 1000, 6000), 0.01), rnd.uniform(0.3, 1.9), rnd.uniform(0.15, 0.4))
    return mix(gain(sub, 1.0), gain(blast, 0.9), out)


SFX = {k[4:]: v for k, v in globals().items() if k.startswith('sfx_')}
AMB = {'amb_day': amb_day, 'amb_night': amb_night, 'amb_fire': amb_fire, 'amb_rain': amb_rain, 'amb_wind': amb_wind}
MUSIC = {'day': music_day, 'night': music_night, 'combat': music_combat, 'title': music_title,
         'region_foret': music_foret, 'region_marais': music_marais, 'region_desert': music_desert,
         'region_montagnes': music_montagnes, 'region_toundra': music_toundra, 'region_bois_enchante': music_bois_enchante,
         'region_volcan': music_volcan, 'region_jungle': music_jungle, 'dungeon': music_dungeon, 'boss': music_boss}


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
        for v in range(1, VARIANTS + 1):
            write(os.path.join(a.out, 'music', '%s_%d.wav' % (name, v + 1)), fn(v), 0.8)
            n += 1
    print('%d son(s) écrit(s) dans %s' % (n, a.out))


if __name__ == '__main__':
    main()
