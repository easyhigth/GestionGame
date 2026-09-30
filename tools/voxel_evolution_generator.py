#!/usr/bin/env python3
"""
Générateur des modèles d'ÉVOLUTION des races (toutes sauf l'humain) -> .glb pour Godot 4.

Chaque race a 3 évolutions (paliers cumulatifs). Le corps garde EXACTEMENT le squelette et les
proportions de la race de base : tous les équipements (fichiers <race>_equipment.glb) s'y accrochent
comme d'habitude. Seuls des détails s'ajoutent, légers mais reconnaissables : cornes, crêtes, marques
lumineuses, épines, auréoles, couronnes, ailes supplémentaires, noyau lumineux... et au 3e palier un
anneau de lumière au sol.

Fichiers écrits :
    models/base/<race>_base[_v2|_v3]_evo<N>.glb   personnages nus (habitants), 3 palettes
    hero/<race>_s<style>_evo<N>.glb               héros (couleurs repères, recolorées dans Godot)

Usage :
    python voxel_evolution_generator.py --out ../assets/characters
"""
import argparse, math, os
from voxel_character_generator import (Node, V, VG, VA, RACES, RACE_ORDER, gen, mk, shade, export_glb, hs)
from voxel_hero_generator import SKIN_KEY, HAIR_KEY, EYE_KEY, STYLE_NAMES

BONE = 0xe8e0c8
GOLD = 0xd8b04a
IRON = 0x6e747e
DARK = 0x2a2226


# ---------------------------------------------------------------- outils
def _head(b):
    o = b['o']
    return b['head'], o['hw'], o['hh'], o['hd']


def horns(b, col, segs=3, x=2.6, z=0.4, size=1.5, spread=0.3, back=0.0, tip=None):
    """Une paire de cornes : des segments qui se suivent en se courbant vers l'extérieur (et l'arrière)."""
    h, hw, hh, hd = _head(b)
    L = size * 1.5
    for s in (-1, 1):
        px, py, pz = s * x, hh / 2, z
        for i in range(segs):
            th = spread * (i + 0.5)
            w = size * (1 - i * 0.18)
            dx, dy, dz = s * math.sin(th) * L, math.cos(th) * L, -back * L * 0.5
            V(w, L * 1.15, w, shade(col, 1 + i * 0.07), px + dx / 2, py + dy / 2, pz + dz / 2, h,
              rx=-back * 0.5, rz=-s * th)
            px += dx; py += dy; pz += dz
        if tip is not None:
            VG(size * 0.6, size * 0.9, size * 0.6, tip, px, py, pz, h, rz=-s * spread * segs)


def crest(b, col, n=5, size=1.2, glow=None):
    """Une crête d'épines du front à la nuque."""
    h, hw, hh, hd = _head(b)
    for i in range(n):
        ht = size * (1.6 + (1.5 - abs(i - (n - 1) / 2.0)) * 0.5)
        z = hd / 2 - 0.8 - i * (hd / max(1, n - 1)) * 0.9
        V(size * 0.8, ht, size, col, 0, hh / 2 + ht / 2 + 0.2, z, h)
        if glow is not None:
            VG(size * 0.5, size * 0.6, size * 0.6, glow, 0, hh / 2 + ht + 0.3, z, h)


def back_spines(b, col, n=5, size=1.2, glow=None):
    """Épines le long du dos."""
    top = b['top']; T = b['T']; tH = b['o']['tH']
    for i in range(n):
        y = tH - 1 - i * (tH - 2) / max(1, n - 1)
        L = size * (2.4 - abs(i - (n - 1) / 2.0) * 0.25)
        V(size, L, size, col, 0, y, -T[2]['d'] / 2 - L * 0.35, top, rx=0.9)
        if glow is not None:
            VG(size * 0.5, size * 0.5, size * 0.5, glow, 0, y + 0.3, -T[2]['d'] / 2 - L * 0.8, top)


def shoulder_spikes(b, col, n=2, size=1.2, glow=None):
    """Épines sur les épaules (au-dessus des bras)."""
    o = b['o']
    for s, A in zip((-1, 1), b['arms']):
        for i in range(n):
            x = (i - (n - 1) / 2.0) * 1.6
            V(size, size * 2.6, size, col, x, o['aw'] * 0.5 + size * 1.2, 0, A, rz=-s * 0.35)
            if glow is not None:
                VG(size * 0.45, size * 0.7, size * 0.45, glow, x - s * 0.6, o['aw'] * 0.5 + size * 2.6, 0, A)


def face_marks(b, col, glow=True):
    """Deux traits sur les joues."""
    h, hw, hh, hd = _head(b)
    f = VG if glow else V
    for s in (-1, 1):
        f(0.45, 2.2, 0.3, col, s * hw * 0.3, -hh * 0.18, hd / 2 + 0.45, h)
        f(1.2, 0.35, 0.3, col, s * hw * 0.34, -hh * 0.02 + 1.3, hd / 2 + 0.45, h)


def forehead_gem(b, col, size=1.2):
    h, hw, hh, hd = _head(b)
    VG(size, size, 0.6, col, 0, hh * 0.3, hd / 2 + 0.4, h, rz=0.785)


def eye_glow(b, col):
    """Lueur par-dessus les yeux."""
    h, hw, hh, hd = _head(b)
    for s in (-1, 1):
        VG(1.6, 0.6, 0.35, col, s * hw * 0.27, hh * 0.02 + 0.55, hd / 2 + 0.6, h)


def chest_runes(b, col, n=3):
    """Marques lumineuses sur le torse (devant) et les avant-bras."""
    top = b['top']; T = b['T']; o = b['o']
    ch = T[2]
    VG(0.5, ch['h'] * 0.8, 0.3, col, 0, ch['cy'], ch['d'] / 2 + 0.25, top)
    for i in range(n):
        y = ch['y0'] + 0.8 + i * (ch['h'] - 1.2) / max(1, n - 1)
        VG(ch['w'] * (0.55 - i * 0.1), 0.35, 0.3, col, 0, y, ch['d'] / 2 + 0.25, top)
    arm_runes(b, col)


def arm_runes(b, col):
    o = b['o']
    for A in b['arms']:
        for i in range(2):
            VG(o['aw'] * 0.5, 0.35, 0.3, col, 0, -o['al'] * (0.58 + i * 0.12), o['ad'] / 2 + 0.2, A)


def claws_glow(b, col):
    o = b['o']
    for A in b['arms']:
        for x in (-0.9, 0.9):
            VG(0.45, 1.0, 0.45, col, x, -o['al'] - 0.6, 0.6, A)


def collar(b, col, puff=1.6):
    """Collier de fourrure ou de plumes autour du cou."""
    top = b['top']; T = b['T']; tH = b['o']['tH']
    w = T[3]['w']; d = T[3]['d']
    for i in range(10):
        a = i / 10.0 * 2 * math.pi
        V(puff * 1.6, puff * 1.3, puff * 1.6, shade(col, 1 + (i % 3 - 1) * 0.07),
          math.cos(a) * w * 0.42, tH + puff * 0.3, math.sin(a) * d * 0.55, top)


def crown(b, col, n=6, height=2.0, gem=None, radius=None):
    """Couronne de pointes autour du haut de la tête."""
    h, hw, hh, hd = _head(b)
    r = radius if radius else hw * 0.52
    # bandeau (quatre côtés, le dessus de la tête reste libre)
    V(hw + 0.8, 0.9, 0.6, col, 0, hh / 2 - 0.2, hd / 2 + 0.2, h)
    V(hw + 0.8, 0.9, 0.6, col, 0, hh / 2 - 0.2, -hd / 2 - 0.2, h)
    for s in (-1, 1):
        V(0.6, 0.9, hd + 0.8, col, s * (hw / 2 + 0.2), hh / 2 - 0.2, 0, h)
    for i in range(n):
        a = i / float(n) * 2 * math.pi
        V(1.0, height + (i % 2) * 0.8, 1.0, col, math.sin(a) * r, hh / 2 + 0.6 + height / 2, math.cos(a) * r * hd / hw, h)
    if gem is not None:
        VG(1.1, 1.1, 0.6, gem, 0, hh / 2 + 0.6, hd / 2 + 0.5, h, rz=0.785)


def halo(b, col, r=5.0, y=4.8, n=8):
    h, hw, hh, hd = _head(b)
    for i in range(n):
        a = i / float(n) * 2 * math.pi
        VG(2.4 * r / 5.0, 0.6, 1.1, col, math.cos(a) * r, hh / 2 + y, math.sin(a) * r, h, ry=-a)


def motes(b, col, n=6, r=6.0, y=2.0):
    """Petites lueurs qui flottent autour de la tête."""
    h, hw, hh, hd = _head(b)
    for i in range(n):
        a = i / float(n) * 2 * math.pi
        VG(0.8, 0.8, 0.8, col, math.cos(a) * r, hh / 2 + y + (i % 2) * 1.2, math.sin(a) * r, h, rx=0.6, rz=0.6)


def floating_crystals(b, col, n=3):
    """Cristaux qui flottent au-dessus des épaules."""
    top = b['top']; T = b['T']; tH = b['o']['tH']
    for i in range(n):
        a = (i / float(n) - 0.5) * 2.6
        VG(1.4, 2.6, 1.4, col, math.sin(a) * (T[3]['w'] / 2 + 3.5), tH + 3 + (i % 2) * 1.5, -math.cos(a) * 3 - 1, top, rx=0.5, rz=0.5)


def aura_ring(b, col):
    """Anneau de lumière au sol (3e évolution)."""
    g = b['g']
    for i in range(16):
        a = i / 16.0 * 2 * math.pi
        VG(3.2, 0.3, 0.9, col, math.cos(a) * 10, 0.25, math.sin(a) * 10, g, ry=-a)


def mini_bat_wings(b, bone, mem, sc=0.6, y_off=0.0):
    top = b['top']; T = b['T']; tH = b['o']['tH']
    for s in (-1, 1):
        x0 = s * (T[3]['w'] / 2 - 1); y0 = tH - 1.5 + y_off; z0 = -(T[3]['d'] / 2 + 1.5)
        angs = (0.45, 0.95, 1.4); lens = (12 * sc, 11 * sc, 8.5 * sc)
        for a, Lb in zip(angs, lens):
            V(1.3, Lb, 1.2, bone, x0 + s * math.sin(a) * Lb / 2, y0 + math.cos(a) * Lb / 2, z0, top, rz=-s * a)
        for i in range(2):
            a = (angs[i] + angs[i + 1]) / 2; Lm = (lens[i] + lens[i + 1]) / 2
            V(Lm * (angs[i + 1] - angs[i]) * 0.9, Lm * 0.75, 0.5, mem,
              x0 + s * math.sin(a) * Lm * 0.45, y0 + math.cos(a) * Lm * 0.45, z0 - 0.2, top, rz=-s * a)


def mini_feather_wings(b, c1, c2, sc=0.55, y_off=-4.0, n=5):
    top = b['top']; T = b['T']; tH = b['o']['tH']
    for s in (-1, 1):
        x0 = s * (T[3]['w'] / 2 - 1); y0 = tH - 2 + y_off; z0 = -(T[3]['d'] / 2 + 2.2)
        for i in range(n):
            a = 0.9 + i * 1.3 / (n - 1)
            L = (12 - i * 0.9) * sc
            V(2.0 * sc, L, 0.6, c1 if i % 2 == 0 else c2, x0 + s * math.sin(a) * L / 2, y0 + math.cos(a) * L / 2, z0, top, rz=-s * a)


def pauldron_feathers(b, c1, c2):
    o = b['o']
    for s, A in zip((-1, 1), b['arms']):
        for i in range(4):
            V(1.2, 3.4, 0.5, c1 if i % 2 else c2, s * (i - 1.5) * 0.4, o['aw'] * 0.5 + 1.4, (i - 1.5) * 1.1, A, rz=-s * (0.4 + i * 0.12))


def antlers(b, col, leaf=None):
    h, hw, hh, hd = _head(b)
    for s in (-1, 1):
        V(0.9, 5, 0.9, col, s * 2.4, hh / 2 + 3, -0.6, h, rz=-s * 0.35)
        V(0.8, 3.6, 0.8, col, s * 4.4, hh / 2 + 6.2, -0.6, h, rz=-s * 0.9)
        V(0.7, 3, 0.7, col, s * 2.6, hh / 2 + 6.4, -0.6, h, rz=s * 0.3)
        V(0.6, 2.4, 0.6, col, s * 6.2, hh / 2 + 7.4, -0.6, h, rz=-s * 1.2)
        if leaf is not None:
            for (x, y) in ((5.6, 8.2), (3, 8.6), (6.8, 6.8)):
                VG(1.2, 1.2, 1.2, leaf, s * x, hh / 2 + y, -0.6, h)


def gel_spikes(b, col, n=5):
    h, hw, hh, hd = _head(b)
    for i in range(n):
        a = i / float(n) * 2 * math.pi
        VA(1.4, 3 + (i % 2), 1.4, col, math.cos(a) * hw * 0.35, hh / 2 + 1.8, math.sin(a) * hd * 0.35, h, 0.62, rz=math.cos(a) * 0.4, rx=-math.sin(a) * 0.4)


# ---------------------------------------------------------------- évolutions par race
# Chaque recette reçoit le personnage construit (b), sa palette (p) et le palier (1 à 3) ; les paliers
# s'additionnent. `S` = peau (repère de couleur chez le héros), `G` = couleur de lueur de la race.

def evo_elf(b, p, t):
    G = 0x9affc8
    h, hw, hh, hd = _head(b)
    if t >= 1:
        forehead_gem(b, G, 1.5); face_marks(b, G)
        for s in (-1, 1): VG(1.0, 1.4, 0.8, G, s * (hw / 2 + 3.3), 4.6, -0.8, h)
    if t >= 2: arm_runes(b, G); crown(b, GOLD, 5, 1.6, G)
    if t >= 3: motes(b, 0x7ae05a, 8, 5.5, 3.0); eye_glow(b, G); aura_ring(b, G)

def evo_goblin(b, p, t):
    S = p['skin']
    if t >= 1: horns(b, BONE, 2, 2.4, 0.2, 1.1, 0.25); face_marks(b, 0xc02a2a, False)
    if t >= 2: horns(b, BONE, 3, 2.4, 0.2, 1.2, 0.3); shoulder_spikes(b, BONE, 2, 1.0)
    if t >= 3: crown(b, BONE, 7, 2.4, 0xffd040); eye_glow(b, 0xffd040); back_spines(b, shade(S, 0.7), 5, 1.0); aura_ring(b, 0xffd040)

def evo_orc(b, p, t):
    S = p['skin']
    if t >= 1: face_marks(b, 0xb02020, False)
    if t >= 1:
        top = b['top']; T = b['T']
        for i in range(3): V(T[2]['w'] * 0.6 - i, 0.6, 0.3, 0xb02020, 0, T[2]['y0'] + 1.2 + i * 1.6, T[2]['d'] / 2 + 0.25, top)
    if t >= 2: shoulder_spikes(b, IRON, 3, 1.3); back_spines(b, BONE, 4, 1.3)
    if t >= 3: horns(b, 0x5a4a3a, 3, 3.4, -0.8, 2.4, 0.4, tip=0xff4a2a); chest_runes(b, 0xff4a2a); aura_ring(b, 0xff4a2a)

def evo_lizard(b, p, t):
    S = p['skin']; G = 0xffc040
    if t >= 1: horns(b, 0xd8cbb0, 2, 2.0, -0.6, 1.1, 0.35, back=0.8); crest(b, shade(S, 0.7), 4, 0.9, G)
    if t >= 2: horns(b, 0xd8cbb0, 3, 2.0, -0.6, 1.2, 0.3, back=0.8, tip=G); chest_runes(b, G, 3)
    if t >= 3: mini_bat_wings(b, shade(S, 0.55), shade(S, 0.9), 0.5); eye_glow(b, G); aura_ring(b, G)

def evo_lycan(b, p, t):
    S = p['skin']; G = 0x9ad8ff
    if t >= 1: collar(b, 0xe8e8f0, 2.3)
    if t >= 2: arm_runes(b, G); claws_glow(b, G)
    if t >= 3:
        h, hw, hh, hd = _head(b)
        VG(2.2, 0.6, 0.4, G, 0, hh * 0.32, hd / 2 + 0.5, h, rz=0.4); VG(0.6, 1.6, 0.4, G, -0.9, hh * 0.3, hd / 2 + 0.5, h)
        back_spines(b, shade(S, 0.75), 5, 1.2); aura_ring(b, G)

def evo_vampire(b, p, t):
    G = 0xff2a4a
    if t >= 1:
        top = b['top']; T = b['T']; tH = b['o']['tH']
        VG(1.6, 1.6, 0.5, G, 0, T[2]['cy'] + 1, T[2]['d'] / 2 + 0.3, top, rz=0.785)
        for s in (-1, 1): V(2.4, 4, 5, 0x2a1a24, s * (T[3]['w'] / 2 - 1), tH + 1.5, -1.2, top, rz=-s * 0.3)
    if t >= 2: mini_bat_wings(b, 0x2a1a24, 0x5a1a2a, 0.6)
    if t >= 3: crown(b, DARK, 8, 2.6, G); aura_ring(b, G)

def evo_demon(b, p, t):
    S = p['skin']; G = 0xff8a20
    h, hw, hh, hd = _head(b)
    if t >= 1:
        for s in (-1, 1): VG(0.9, 1.4, 0.9, G, s * 7.2, hh / 2 + 8.4, -3.2, h)
    if t >= 2: horns(b, shade(S, 0.55), 2, 1.3, hd / 2 - 1.4, 0.9, 0.2); chest_runes(b, G)
    if t >= 3:
        for i in range(7):
            a = i / 7.0 * 2 * math.pi
            VG(1, 2.2 + (i % 2) * 1.2, 1, (0xff5a20, 0xffb040)[i % 2], math.cos(a) * 3.4, hh / 2 + 1.8, math.sin(a) * 3.4, h)
        aura_ring(b, G)

def evo_dragonoid(b, p, t):
    S = p['skin']; G = 0xffb040
    h, hw, hh, hd = _head(b)
    if t >= 1:
        chest_runes(b, G, 3); eye_glow(b, G)
    if t >= 2: horns(b, 0xd8cbb0, 2, 1.6, 2.6, 1.4, 0.3, tip=G); shoulder_spikes(b, shade(S, 0.6), 2, 1.4, G)
    if t >= 3: mini_bat_wings(b, shade(S, 0.5), shade(S, 0.85), 1.05, 1.5); eye_glow(b, G); aura_ring(b, G)

def evo_fairy(b, p, t):
    G = 0xfff4b0
    if t >= 1: face_marks(b, G); crown(b, 0xfff0f8, 6, 1.8, p['orb']); chest_runes(b, G, 2)
    if t >= 2:
        top = b['top']; T = b['T']; tH = b['o']['tH']
        for s in (-1, 1):
            VA(5, 10, 0.3, shade(p['hair'], 1.25), s * 7, tH - 6, -(T[3]['d'] / 2 + 2), top, 0.6, rz=s * 1.1)
            VG(0.5, 9, 0.35, G, s * 7, tH - 6, -(T[3]['d'] / 2 + 2.1), top, rz=s * 1.1)
    if t >= 3: halo(b, G, 4.6, 5.6); aura_ring(b, G)

def evo_slime(b, p, t):
    S = p['skin']; G = p['orb']
    top = b['top']; T = b['T']
    if t >= 1:
        VG(1.6, 1.6, 1.6, 0xffffff, 3, T[2]['cy'] + 3, 0.4, top, rx=0.6, rz=0.6)
        gel_spikes(b, S, 4)
    if t >= 2: gel_spikes(b, shade(S, 1.2), 7); motes(b, G, 5, 7.0, -2.0)
    if t >= 3: crown(b, GOLD, 6, 2.0, 0xff4a6a); aura_ring(b, G)

def evo_dwarf(b, p, t):
    G = 0x6ad8ff
    if t >= 1: arm_runes(b, G); forehead_gem(b, G, 1.3); face_marks(b, G)
    if t >= 2:
        h, hw, hh, hd = _head(b)
        for y in (-hh / 2 - 1.6, -hh / 2 - 3.2): V(2.6, 1.0, 1.6, GOLD, 0, y, hd / 2 + 1.4, h)
        o = b['o']
        for A in b['arms']:
            V(o['aw'] + 2.2, 1.8, o['ad'] + 2.2, 0x8a8a86, 0, 1.2, 0, A)
            VG(o['aw'] * 0.6, 0.5, 0.3, G, 0, 1.2, o['ad'] / 2 + 1.15, A)
    if t >= 3: crown(b, 0x8a8a86, 6, 2.0, G); eye_glow(b, G); aura_ring(b, G)

def evo_hobgoblin(b, p, t):
    S = p['skin']; G = 0xff6a3a
    if t >= 1: horns(b, BONE, 2, 2.0, 0.4, 1.0, 0.2); face_marks(b, 0xa02020, False)
    if t >= 2:
        shoulder_spikes(b, BONE, 2, 1.0)
        top = b['top']; T = b['T']
        for i in range(2): V(T[2]['w'] * 0.5, 0.6, 0.3, 0xa02020, 0, T[2]['y0'] + 1.6 + i * 1.8, T[2]['d'] / 2 + 0.25, top)
    if t >= 3: horns(b, BONE, 3, 2.0, 0.4, 1.2, 0.3, tip=G); crown(b, BONE, 6, 1.6, G); aura_ring(b, G)

def evo_ogre(b, p, t):
    S = p['skin']; G = 0xff5a2a
    if t >= 1:
        top = b['top']; T = b['T']
        for i in range(3): V(T[2]['w'] * 0.7 - i * 1.5, 0.7, 0.3, 0x5a1a1a, 0, T[2]['y0'] + 1 + i * 1.7, T[2]['d'] / 2 + 0.25, top)
        face_marks(b, 0x5a1a1a, False)
    if t >= 2:
        shoulder_spikes(b, BONE, 3, 1.5)
        h, hw, hh, hd = _head(b)
        for x in {0: (0,), 1: (-2.6, 2.6), 2: (-3.4, 0, 3.4)}[p['hs']]: VG(1.2, 1.4, 1.2, G, x, hh / 2 + 6.4, 1.2, h)
    if t >= 3: chest_runes(b, G); crown(b, BONE, 8, 2.2); aura_ring(b, G)

def evo_kijin(b, p, t):
    G = 0xff3a3a
    h, hw, hh, hd = _head(b)
    one = p['hs'] == 1
    if t >= 1:
        if one:
            VG(1.0, 1.4, 1.0, G, 0, hh / 2 + 4.2, 1.2, h)
        else:
            for s in (-1, 1): VG(0.9, 1.3, 0.9, G, s * 2.7, hh / 2 + 4.2, 0.4, h)
        o = b['o']
        for A in b['arms']:
            for i in range(3): V(o['aw'] + 0.3, 0.5, o['ad'] + 0.3, 0xc02a2a, 0, -2 - i * 1.3, 0, A)
    if t >= 2:
        if one:
            horns(b, 0xd8cbb0, 2, 2.2, 1.0, 1.0, 0.3)
        else:
            V(1.3, 2.6, 1.3, 0xd8cbb0, 0, hh / 2 + 1.2, 2.2, h); VG(0.8, 1.2, 0.8, G, 0, hh / 2 + 3.1, 2.2, h)
        arm_runes(b, G)
    if t >= 3: halo(b, G, 4.6, 3.8, 10); eye_glow(b, G); aura_ring(b, G)

def evo_beastfolk(b, p, t):
    S = p['skin']; G = 0xffa040
    fur = 0x8a5a3a
    if t >= 1: collar(b, fur, 1.8)
    if t >= 2: arm_runes(b, G); claws_glow(b, G); face_marks(b, G)
    if t >= 3: forehead_gem(b, G, 1.4); collar(b, shade(fur, 1.1), 2.4); back_spines(b, fur, 5, 1.3); aura_ring(b, G)

def evo_harpy(b, p, t):
    f1 = p['hair']; f2 = shade(f1, 0.75); G = 0x8ae0ff
    h, hw, hh, hd = _head(b)
    if t >= 1:
        for i in range(4): V(1.1, 4 + i * 0.6, 0.6, (f1, f2)[i % 2], (i - 1.5) * 1.2, hh / 2 + 3.4, -hd / 2 + 0.5, h, rx=-0.4)
    if t >= 2: pauldron_feathers(b, f1, f2); face_marks(b, G); chest_runes(b, G, 2)
    if t >= 3:
        top = b['top']; T = b['T']; tH = b['o']['tH']
        for s in (-1, 1):
            for i in range(4):
                a = 0.3 + i * 0.6; L = 14 - i * 0.9
                VG(0.8, 0.8, 0.8, G, s * (T[3]['w'] / 2 - 1 + math.sin(a) * L), tH - 2 + math.cos(a) * L, -(T[3]['d'] / 2 + 1.8), top)
        halo(b, G, 4.4, 5.2); aura_ring(b, G)

def evo_spirit(b, p, t):
    G = 0xffffff
    if t >= 1: motes(b, 0xfff4b0, 6, 5.5, 1.5)
    if t >= 2:
        h, hw, hh, hd = _head(b)
        for i in range(5): VG(0.9, 2.4 + (i % 2) * 1.2, 0.9, 0xd0f0ff, (i - 2) * 1.5, hh / 2 + 3.6, 0.6, h)
    if t >= 3: halo(b, G, 5.6, 6.4, 10); floating_crystals(b, 0xd0f0ff, 3); aura_ring(b, G)

def evo_angel(b, p, t):
    G = 0xfff0a0
    if t >= 1:
        h, hw, hh, hd = _head(b)
        V(hw + 0.8, 0.7, hd + 0.8, GOLD, 0, hh * 0.3, 0, h)
        top = b['top']; T = b['T']
        VG(1.4, 1.4, 0.5, G, 0, T[2]['cy'] + 0.6, T[2]['d'] / 2 + 0.3, top, rz=0.785)
    if t >= 2: halo(b, 0xffd040, 6.6, 5.4, 12); arm_runes(b, 0xffd040)
    if t >= 3: crown(b, G, 8, 2.4); floating_crystals(b, G, 3); aura_ring(b, G)

def evo_dryad(b, p, t):
    S = p['skin']; G = 0xffa0e0
    h, hw, hh, hd = _head(b)
    if t >= 1:
        for i, c in enumerate((0xff7ab0, 0xffd84a, 0xb08af0, 0xffffff, 0xff9a4a)):
            a = i / 5.0 * 2 * math.pi
            VG(1.2, 1.2, 1.2, c, math.cos(a) * (hw / 2 + 1.2), hh / 2 - 0.4, math.sin(a) * (hd / 2 + 1.2), h)
    if t >= 2: antlers(b, shade(S, 0.7), 0x7ae05a)
    if t >= 3:
        motes(b, 0x9af07a, 8, 6.0, 5.0)
        for A in b['arms']:
            for i in range(3): VG(b['o']['aw'] + 0.6, 0.35, b['o']['ad'] + 0.6, 0x9af07a, 0, -3 - i * 3.4, 0, A, ry=i * 0.4)
        aura_ring(b, G)

def evo_insectoid(b, p, t):
    S = p['skin']; G = 0x7aff5a
    if t >= 1: chest_runes(b, G, 3)
    if t >= 2:
        h, hw, hh, hd = _head(b)
        V(2.2, 4.4, 2.2, shade(S, 0.55), 0, hh / 2 + 1.6, hd / 2 - 0.2, h, rx=0.5)
        V(1.6, 3, 1.6, shade(S, 0.65), 0, hh / 2 + 4.4, hd / 2 + 1.2, h, rx=0.9)
        VG(0.9, 0.9, 0.9, G, 0, hh / 2 + 5.8, hd / 2 + 2.4, h)
        o = b['o']
        for A in b['arms']: V(o['aw'] + 2.2, 1.6, o['ad'] + 2.2, shade(S, 0.65), 0, 1.2, 0, A)
    if t >= 3: crown(b, shade(S, 0.6), 6, 2.0, G); eye_glow(b, G); aura_ring(b, G)

def evo_undead(b, p, t):
    S = p['skin']; G = 0x60d0ff
    if t >= 1:
        top = b['top']; T = b['T']
        for j in range(4): VG(T[2]['w'] * 0.6, 0.3, 0.3, G, 0, T[2]['y0'] + 1.0 + j * 0.9, T[2]['d'] / 2 + 0.35, top)
    if t >= 2:
        shoulder_spikes(b, 0xf4f0e0, 2, 1.1)
        h, hw, hh, hd = _head(b)
        for s in (-1, 1): VG(1.2, 2.4, 0.5, G, s * hw * 0.27, hh * 0.02 + 1.4, hd / 2 + 0.5, h)
    if t >= 3:
        h, hw, hh, hd = _head(b)
        for i in range(7):
            a = i / 7.0 * 2 * math.pi
            VG(1, 2.4 + (i % 2) * 1.4, 1, (0x60d0ff, 0xb0f0ff)[i % 2], math.cos(a) * 3.2, hh / 2 + 1.6, math.sin(a) * 3.2, h)
        crown(b, 0xf4f0e0, 6, 1.6); aura_ring(b, G)

EVOS = {'elf': evo_elf, 'goblin': evo_goblin, 'orc': evo_orc, 'lizard': evo_lizard, 'lycan': evo_lycan,
        'vampire': evo_vampire, 'demon': evo_demon, 'dragonoid': evo_dragonoid, 'fairy': evo_fairy,
        'slime': evo_slime, 'dwarf': evo_dwarf, 'hobgoblin': evo_hobgoblin, 'ogre': evo_ogre, 'kijin': evo_kijin,
        'beastfolk': evo_beastfolk, 'harpy': evo_harpy, 'spirit': evo_spirit, 'angel': evo_angel,
        'dryad': evo_dryad, 'insectoid': evo_insectoid, 'undead': evo_undead}
TIERS = 3


# ---------------------------------------------------------------- construction
def evolved_base(race, seed, tier):
    """Personnage nu (habitant), palette `seed` (1 à 3), évolution `tier`."""
    i = RACE_ORDER.index(race)
    p = gen(race, 'forgeron', mk(seed * 97 + i * 13 + 1))
    p['naked'] = True; p['cape'] = False
    b = RACES[race]('forgeron', p)
    EVOS[race](b, p, tier)
    return b['g']


def evolved_hero(race, style, tier):
    """Héros (couleurs repères), style `style`, évolution `tier`."""
    i = RACE_ORDER.index(race)
    p = gen(race, 'forgeron', mk(97 + i * 13 + 1))
    p['naked'] = True; p['cape'] = False
    p['skin'] = SKIN_KEY; p['hair'] = HAIR_KEY; p['eye'] = EYE_KEY; p['beard'] = False
    if race == 'spirit':
        p['el'] = style; p['hs'] = 0
    else:
        p['hs'] = style
    b = RACES[race]('forgeron', p)
    EVOS[race](b, p, tier)
    return b['g']


# ---------------------------------------------------------------- créatures (familiers)
# Les monstres apprivoisés évoluent deux fois (voir scripts/world/familiars.gd) : mêmes os, mêmes pattes,
# avec des cornes, des marques lumineuses, des épines de cristal et (2e évolution) un anneau au sol.
import voxel_creature_generator as vcg

CREATURE_ACCENT = {
    'wolf': 0x8ad8ff, 'wolf_alpha': 0xff5a3a, 'wolf_frost': 0x9ae8ff, 'boar': 0xff8a3a, 'bear_snow': 0x7ac8ff,
    'slime_blue': 0x9ad8ff, 'slime_acid': 0xc8ff5a, 'slime_magma': 0xffd040, 'spider': 0xff3a3a,
    'scorpion': 0x8aff4a, 'salamander': 0xffb040,
}
CREATURE_HORN = {'wolf': 0xd8d8e0, 'wolf_alpha': 0x2a2226, 'wolf_frost': 0xeaf4fc, 'boar': 0xe8e0c8, 'bear_snow': 0xd8cbb0,
                 'spider': 0x1a1418, 'scorpion': 0x8a6a2a, 'salamander': 0x3a2220}


def _find(node, name):
    if node.name == name:
        return node
    for k in node.kids:
        r = _find(k, name)
        if r:
            return r
    return None


def _bbox(node):
    """Boîte englobante des voxels d'un nœud (dans son repère) : (x0, x1, y0, y1, z0, z1)."""
    xs = []; ys = []; zs = []
    for b in node.boxes:
        xs += [b['x'] - b['w'] / 2, b['x'] + b['w'] / 2]
        ys += [b['y'] - b['h'] / 2, b['y'] + b['h'] / 2]
        zs += [b['z'] - b['d'] / 2, b['z'] + b['d'] / 2]
    if not xs:
        return (-2, 2, -2, 2, -2, 2)
    return (min(xs), max(xs), min(ys), max(ys), min(zs), max(zs))


def creature_evo(name, tier):
    g = vcg.CREATURES[name]()
    A = CREATURE_ACCENT[name]
    horn = CREATURE_HORN.get(name, 0xe8e0c8)
    head = _find(g, 'Head'); top = _find(g, 'Torso')
    slime = name.startswith('slime')
    if head is not None and not slime:
        x0, x1, y0, y1, z0, z1 = _bbox(head)
        w = x1 - x0
        # cornes (plus grandes à la 2e évolution)
        sz = 1.2 + tier * 0.5
        for s in (-1, 1):
            px, py, pz = s * w * 0.28, y1, (z0 + z1) / 2 - 0.5
            for i in range(tier + 1):
                th = 0.35 * (i + 0.5)
                L = sz * 1.4
                dx, dy = s * math.sin(th) * L, math.cos(th) * L
                V(sz * (1 - i * 0.2), L * 1.15, sz * (1 - i * 0.2), shade(horn, 1 + i * 0.08), px + dx / 2, py + dy / 2, pz - i * 0.6, head, rx=-0.4, rz=-s * th)
                px += dx; py += dy
            if tier >= 2:
                VG(sz * 0.6, sz * 0.8, sz * 0.6, A, px, py + 0.4, pz - (tier) * 0.6, head)
    if top is not None:
        x0, x1, y0, y1, z0, z1 = _bbox(top)
        w = x1 - x0; L = z1 - z0
        # marques lumineuses sur les flancs
        for s in (-1, 1):
            for i in range(3):
                VG(0.35, min((y1 - y0) * 0.5, 3.4), 1.2, A, s * (w / 2 + 0.2), y0 + min((y1 - y0) * 0.5, 4.5), z0 + L * (0.3 + i * 0.18), top)
        if tier >= 2:
            # épines de cristal sur le dos, anneau au sol
            n = 5
            for i in range(n):
                z = z0 + L * (0.2 + i * 0.6 / (n - 1))
                VG(1.2, 2.4 + (i % 2) * 1.2, 1.2, A if i % 2 else shade(A, 0.8), 0, y1 + 1.2, z, top, rx=-0.3)
            for i in range(16):
                a = i / 16.0 * 2 * math.pi
                VG(3.2, 0.3, 0.9, A, math.cos(a) * max(w, L) * 0.7, -g.t[1] / (g.scale or 1) + 0.3 if hasattr(g, 't') else 0.3, math.sin(a) * max(w, L) * 0.7, g, ry=-a)
    if slime:
        # slime : couronne de gel et second noyau
        x0, x1, y0, y1, z0, z1 = _bbox(g)
        for i in range(5 + tier):
            a = i / float(5 + tier) * 2 * math.pi
            VG(1.2, 2 + tier, 1.2, A, math.cos(a) * 3, y1 + 1, math.sin(a) * 3, g)
        VG(2.2, 2.2, 2.2, 0xffffff, 2, (y0 + y1) / 2, 1, g, rx=0.6, rz=0.6)
        if tier >= 2:
            V(7, 1, 7, GOLD, 0, y1 + 0.4, 0, g)
    return g


def creature_main(out):
    n = 0
    for name in CREATURE_ACCENT:
        for t in (1, 2):
            export_glb(creature_evo(name, t), os.path.join(out, 'creatures', '%s_evo%d.glb' % (name, t))); n += 1
    return n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='../assets/characters')
    ap.add_argument('--race', default='all')
    ap.add_argument('--no-hero', action='store_true')
    a = ap.parse_args()
    races = [r for r in RACE_ORDER if r != 'human'] if a.race == 'all' else [a.race]
    base_dir = os.path.join(a.out, 'models', 'base'); hero_dir = os.path.join(a.out, 'hero')
    os.makedirs(base_dir, exist_ok=True); os.makedirs(hero_dir, exist_ok=True)
    n = 0
    for r in races:
        for t in range(1, TIERS + 1):
            for sd in (1, 2, 3):
                suffix = '' if sd == 1 else '_v%d' % sd
                export_glb(evolved_base(r, sd, t), os.path.join(base_dir, '%s_base%s_evo%d.glb' % (r, suffix, t))); n += 1
            if not a.no_hero:
                for s in range(len(STYLE_NAMES[r])):
                    export_glb(evolved_hero(r, s, t), os.path.join(hero_dir, '%s_s%d_evo%d.glb' % (r, s, t))); n += 1
    if a.race == 'all':
        n += creature_main(a.out)
    print('%d modèle(s) d\'évolution écrit(s) dans %s' % (n, a.out))


if __name__ == '__main__':
    main()
