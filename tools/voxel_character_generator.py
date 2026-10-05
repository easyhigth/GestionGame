#!/usr/bin/env python3
"""
Générateur de personnages voxel sculptés -> fichiers .glb pour Godot 4.

Style : voxel adulte, formes angulaires, beaucoup de relief (blocs posés en couches).
1 unité = 1 voxel = 5 cm  (un humain fait ~1,70 m).

Usage :
    python voxel_character_generator.py --out ../models
    python voxel_character_generator.py --race orc --job garde --seed 4 --out .
    python voxel_character_generator.py --variants 3 --out ../models

Nœuds exportés (noms fixes, utilisés par les scripts Godot) :
    Root > LegL, LegR, Torso > (ArmL > HandL), (ArmR > HandR), Head
Le personnage regarde vers +Z. Le côté +X est la GAUCHE du personnage.

Pour ajouter une race : voir la fonction `def human(...)` et le dictionnaire RACES en bas.
"""
import math, struct, json, zlib, os, argparse

UNIT = 0.05  # 1 voxel = 5 cm

# ---------------------------------------------------------------- utilitaires
def R(x): return int(math.floor(x + 0.5))

def hs(x, y, s):
    n = math.sin(x * 127.1 + y * 311.7 + s * 74.7) * 43758.5453
    return n - math.floor(n)

def shade(h, f):
    r = min(255, R(((h >> 16) & 255) * f))
    g = min(255, R(((h >> 8) & 255) * f))
    b = min(255, R((h & 255) * f))
    return (r << 16) | (g << 8) | b

M32 = 0xFFFFFFFF
def mk(seed):
    s = [seed & M32]
    def f():
        s[0] = (s[0] + 0x6D2B79F5) & M32
        t = s[0]
        t = ((t ^ (t >> 15)) * (1 | t)) & M32
        t = (((t + (((t ^ (t >> 7)) * (61 | t)) & M32)) & M32) ^ t)
        return ((t ^ (t >> 14)) & M32) / 4294967296.0
    return f

class Node:
    def __init__(s, name, t=(0, 0, 0), rx=0.0):
        s.name = name; s.t = t; s.rx = rx; s.scale = 1.0
        s.boxes = []; s.kids = []
    def add(s, n):
        s.kids.append(n); return n

def V(w, h, d, c, x, y, z, pa, rx=0, ry=0, rz=0, glow=False, alpha=1.0):
    b = dict(w=w, h=h, d=d, c=c, x=x, y=y, z=z, r=(rx, ry, rz), glow=glow, alpha=alpha)
    pa.boxes.append(b); return b

def VG(w, h, d, c, x, y, z, pa, rx=0, ry=0, rz=0):
    return V(w, h, d, c, x, y, z, pa, rx, ry, rz, True)

def VA(w, h, d, c, x, y, z, pa, alpha=0.6, rx=0, ry=0, rz=0, glow=False):
    """Boîte translucide (gel, ailes...)."""
    return V(w, h, d, c, x, y, z, pa, rx, ry, rz, glow, alpha)

# ---------------------------------------------------------------- palettes
SK = {
    'human': [0xf2c9a5, 0xe0a97f, 0xc68a5f, 0x9a6440, 0x6b4429],
    'elf': [0xf6e0c8, 0xe6c9a8, 0xcfe0d8, 0xd9c8e8, 0xb08a6a],
    'goblin': [0x7fb046, 0x9ab848, 0x5f9a5a, 0x6aa08a, 0xb0a840],
    'orc': [0xe3a59b, 0xd48a80, 0xb8826a, 0xa08a80, 0xd9b0a0],
    'lizard': [0x5a9a4a, 0x3a8a7a, 0xb08a3a, 0xa8503a, 0x5a7a9a],
    'lycan': [0x6a5a4a, 0x8a8a8a, 0x3a3a3e, 0xc8c0b0, 0x8a4a2a],
    'vampire': [0xe8e0dc, 0xd8d0d8, 0xc8c8d8, 0xb8b0b0, 0xe0c8c0],
    'demon': [0xb83a30, 0x8a2a3a, 0x6a3a7a, 0x3a3a4a, 0xc85a2a],
    'dragonoid': [0xb8402a, 0x3a6ab0, 0x4a8a3a, 0xc8a02a, 0x4a3a5a],
    'fairy': [0xf6d8d0, 0xd8f0e0, 0xe0d0f4, 0xf0e0b8, 0xc8e0f4],
    'slime': [0x4ad06a, 0x4a9af0, 0xf070b0, 0xa070f0, 0xf0b040, 0x40d0c8],
    'dwarf': [0xe8b090, 0xd89a78, 0xc4805a, 0x9a6440, 0xf0c8a8],
    'hobgoblin': [0x6a9a5a, 0x7aaa6a, 0x5a8a6a, 0x8ab06a, 0x6a8a7a],
    'ogre': [0xb84a3a, 0x3a6a9a, 0x6a9a4a, 0xc8a06a, 0x8a5a8a],
    'kijin': [0xf0d8c8, 0xe8c0b0, 0xd8a898, 0xf4e0d8, 0xc8b0d0],
    'beastfolk': [0xd8a86a, 0x8a8a8a, 0xe8e0d0, 0x6a4a34, 0xd88a3a],
    'harpy': [0xf0d8c0, 0xe0b890, 0xc89870, 0xb8d0e0, 0xd8c8f0],
    'spirit': [0xff7a3a, 0x4a9af0, 0xa8e8c8, 0x9a6a4a, 0xf0e070],
    'angel': [0xf6e4d0, 0xf0d8b8, 0xe8c8a0, 0xd8b890, 0xf4ecf0],
    'dryad': [0x8a6a4a, 0x6a8a4a, 0xa8886a, 0x7a9a6a, 0xb08a6a],
    'insectoid': [0x3a5a3a, 0x2a3a5a, 0x6a2a2a, 0x5a4a2a, 0x2a5a5a],
    'undead': [0xe8e0c8, 0xd8d0b0, 0xc8c0a0, 0xb8b8b8, 0xa8b8a0]}
HAIR = {
    'human': [0x6b4423, 0x1e1a18, 0xd9b04a, 0xa8432a, 0xb8b8b8, 0x3a2a1e],
    'elf': [0xf0d36a, 0xe8e8f0, 0x2a2a3a, 0x4aa8a0, 0xc9a0e0, 0xd9704a],
    'vampire': [0x1a1a1e, 0xe8e8f0, 0x6a1a1a, 0x3a2a3a, 0x8a8a94],
    'fairy': [0xf49ac8, 0x7ae0b0, 0xf0d36a, 0xb08af0, 0x7ac8f4, 0xffffff],
    'dwarf': [0xa8432a, 0x6b4423, 0xd9b04a, 0x3a2a1e, 0xb8b8b8, 0x1e1a18],
    'hobgoblin': [0x1e1a18, 0x3a2a1e, 0xa8432a, 0xb8b8b8],
    'kijin': [0x1e1a18, 0xe8e8f0, 0xe07a9a, 0x3a5a8a, 0x8a2a2a],
    'beastfolk': [0x6a4a34, 0xe8e0d0, 0x3a3a3e, 0xd88a3a, 0xa8a8a8],
    'harpy': [0x4a8ad0, 0xd04a4a, 0xf0d040, 0x6ac86a, 0xe8e8f0, 0x8a4ad0],
    'angel': [0xf0d36a, 0xf8f8f8, 0xd0d8f0, 0xe8b0a0, 0x9a9ab0],
    'dryad': [0x4aa84a, 0xd8a02a, 0xe07a9a, 0x7ad06a, 0xc86a3a]}
EYE = {'human': [0x2a5a8a, 0x3a6a3a, 0x5a3a20],
       'elf': [0x2a7ad0, 0x2aa060, 0x8a4ad0, 0xd08a2a],
       'goblin': [0xf2d84a], 'orc': [0xc02a1c, 0xe0902a],
       'lizard': [0xf2d84a, 0xf08030, 0x9af04a, 0xe04a3a],
       'lycan': [0xf2c030, 0xe04a2a, 0xd0d0ff, 0x40e0a0],
       'vampire': [0xd02020, 0xe05020, 0xc02090, 0xd0a020],
       'demon': [0xffd030, 0xffffff, 0xff7020, 0x60ffb0],
       'dragonoid': [0xffa020, 0xffffff, 0xf0e030, 0x60e0ff],
       'fairy': [0x2a7ad0, 0xd03a8a, 0x2aa060, 0x8a4ad0],
       'slime': [0x1a1a1a],
       'dwarf': [0x3a5a8a, 0x4a3a20, 0x3a6a3a],
       'hobgoblin': [0xf2d84a, 0xe0902a, 0xc02a1c],
       'ogre': [0xff5030, 0xf0d030, 0xffffff],
       'kijin': [0xd02020, 0xe0a020, 0x7a5ad0],
       'beastfolk': [0xf2c030, 0x40e0a0, 0x60a0f0, 0xd08a2a],
       'harpy': [0xf2d84a, 0x2a7ad0, 0xd08a2a],
       'spirit': [0xffffff],
       'angel': [0x60c0ff, 0xffd050, 0xa0f0c0, 0xe0a0ff],
       'dryad': [0x60ff80, 0xf0d040, 0xff90c0],
       'insectoid': [0xff4a4a, 0x60ff60, 0xffe030, 0xff60e0],
       'undead': [0x60ffb0, 0xff5030, 0x60a0ff, 0xd060ff]}
CLOTH = {
    'forgeron': [0x7a6a58, 0x9c4a3a, 0x4a6a8a, 0x6a7a4a, 0x8a5a3a],
    'marchand': [0x8e44ad, 0xc0392b, 0x1f8a8a, 0xd98a2b, 0x2e6f4e],
    'garde': [0x8a94a6, 0x6a7a8a, 0x9a8a6a, 0x5a6a5a, 0x6a5a7a],
    'mage': [0x4b3ca8, 0x1f7a7a, 0xa0303a, 0x2a5a9a, 0x7a3a8a],
    'fermier': [0xd8c8a0, 0xa8b878, 0xc89a6a, 0x9ab0c8, 0xe0d0b0],
    'mineur': [0x6a5a4a, 0x5a5a5a, 0x7a6248, 0x4a4a52],
    'aubergiste': [0xe8dcc0, 0xb85a4a, 0x6a8a5a, 0xd0b080, 0x5a7a9a],
    'chasseur': [0x5a6a3a, 0x6a5238, 0x4a5a48, 0x7a6a48]}
PANTS = {
    'forgeron': [0x3a2e28, 0x2f3a4a, 0x4a3a2a, 0x3a4a3a],
    'marchand': [0x4a3a30, 0x2a3a5a, 0x5a2a3a, 0x3a3a3a],
    'garde': [0x3d4350, 0x4a3a30, 0x2f3a2f],
    'mage': [0x2f2a5a, 0x1a3a4a, 0x4a1f2a],
    'fermier': [0x3a5a8a, 0x5a4a32, 0x4a6a8a, 0x6a5a3a],
    'mineur': [0x3a342e, 0x2e2e34, 0x4a3a2a],
    'aubergiste': [0x4a3a30, 0x3a3a3a, 0x5a3a28],
    'chasseur': [0x4a3a28, 0x3a4a2a, 0x5a4a32]}
ACC = {
    'forgeron': [0x5a3a28, 0x3a3a3a, 0x7a4a2a, 0x2f4a5a],
    'marchand': [0x7a3f8f, 0xa8322a, 0x2a5f8a, 0xc9a13a, 0x2f7a4a],
    'garde': [0xb03a3a, 0x2a5f9a, 0x2f7a4a, 0xd4a12a],
    'mage': [0x3b2f8a, 0x145a5a, 0x7a1f2a, 0x1f3f7a],
    'fermier': [0xd8b860, 0xe0c878, 0xc8a050],
    'mineur': [0xd0a020, 0xc06a20, 0x9a9a9a],
    'aubergiste': [0xf2eee4, 0xe8e0cc, 0xf0e8d8],
    'chasseur': [0x3f5a2a, 0x5a4026, 0x2f4a3a, 0x6a3a24]}
TRIM = [0x7a1f2a, 0x1f3f7a, 0x2f5a3a, 0x5a3a28, 0x8a6a2a, 0x3a3a3a]
BOOT = [0x3a2a1e, 0x2a2a2a, 0x5a3a28, 0x6a4a2a]
ORB = [0x7fe0ff, 0xff8a5a, 0xa0ff8a, 0xff7ad0]
BELT = [0x3a2a1e, 0x5a3a28, 0x2a2a2a, 0x7a2f2a]
SACK = [0x8a6238, 0x6a4a38, 0x5a6a48, 0x7a5a7a]
FUR = [0x6a4a34, 0x8a8a8a, 0x3a2a22, 0xa88a5a]
JOBS = ['forgeron', 'marchand', 'garde', 'mage', 'fermier', 'mineur', 'aubergiste', 'chasseur']

def gen(race, k, rnd):
    P = lambda a: a[int(math.floor(rnd() * len(a)))]
    p = {}
    p['skin'] = P(SK[race])
    p['hair'] = P(HAIR[race]) if race in HAIR else 0x2a1e18
    p['eye'] = P(EYE[race]); p['cloth'] = P(CLOTH[k]); p['pants'] = P(PANTS[k])
    p['acc'] = P(ACC[k]); p['orb'] = P(ORB); p['belt'] = P(BELT); p['sack'] = P(SACK)
    p['trim'] = P(TRIM); p['boot'] = P(BOOT); p['fur'] = P(FUR)
    p['cape'] = rnd() < 0.4; p['beard'] = rnd() < 0.5
    p['hs'] = int(math.floor(rnd() * 3))
    return p

# ---------------------------------------------------------------- corps commun
def build(o, p, race):
    nk = bool(p.get('naked'))
    g = Node('Root')
    legs = []
    for s in (-1, 1):
        pv = g.add(Node('LegL' if s == 1 else 'LegR', (s * o['gap'], o['legH'], 0)))
        th = o['legH'] * 0.46; sh = o['legH'] * 0.32; bt = o['legH'] * 0.22
        lc = p['skin'] if nk else p['pants']
        V(o['lw'], th, o['ld'], lc, 0, -th / 2, 0, pv)
        V(o['lw'] + 0.8, 1.3, o['ld'] + 0.8, shade(lc, 1.06 if nk else 1.2), 0, -th - 0.2, 0, pv)
        V(o['lw'] * 0.88, sh, o['ld'] * 0.9, shade(lc, 0.97 if nk else 0.9), 0, -th - sh / 2, 0, pv)
        if nk or o.get('bare'):
            lc = p['skin']
            V(o['lw'] * 0.8, bt * 0.6, o['ld'] * 0.8, shade(lc, 0.94), 0, -o['legH'] + bt * 0.72, 0, pv)
            V(o['lw'] + 0.3, bt * 0.45, o['ld'] + 0.6, shade(lc, 0.98), 0, -o['legH'] + bt * 0.225, 0.3, pv)
            V(o['lw'] + 0.1, bt * 0.32, 2.2, shade(lc, 1.03), 0, -o['legH'] + bt * 0.16, o['ld'] / 2 + 1.2, pv)
        else:
            V(o['lw'] + 0.9, bt, o['ld'] + 1, p['boot'], 0, -o['legH'] + bt / 2, 0.2, pv)
            V(o['lw'] + 1.3, 1, o['ld'] + 1.4, shade(p['boot'], 1.3), 0, -o['legH'] + bt, 0.2, pv)
            V(o['lw'] + 0.6, bt * 0.55, 2.2, p['boot'], 0, -o['legH'] + bt * 0.3, o['ld'] / 2 + 1.2, pv)
        legs.append(pv)
    top = g.add(Node('Torso', (0, o['legH'], 0), o.get('lean', 0)))
    y = 0; T = []
    for i, t in enumerate(o['tiers']):
        if nk:
            if i == 0: col = 0x6a4a34 if race != 'slime' else shade(p['skin'], 1.0)
            else: col = shade(p['skin'], 1.04 if i % 2 else 0.96)
        elif i == 0: col = shade(p['pants'], 1.1)
        elif i % 2: col = shade(p['cloth'], 1.06)
        else: col = shade(p['cloth'], 0.94)
        V(t[1], t[0], t[2], col, 0, y + t[0] / 2, 0, top)
        T.append(dict(y0=y, h=t[0], w=t[1], d=t[2], cy=y + t[0] / 2)); y += t[0]
    o['tH'] = y
    if not nk:
        V(T[1]['w'] + 0.8, 1.5, T[1]['d'] + 0.8, p['belt'], 0, T[1]['y0'] + 0.4, 0, top)
        V(2.2, 1.7, 0.6, 0xd8b04a, 0, T[1]['y0'] + 0.4, T[1]['d'] / 2 + 0.7, top)
        V(T[2]['w'] + 0.3, 0.6, T[2]['d'] + 0.3, p['trim'], 0, T[2]['y0'] + 0.3, 0, top)
        V(T[3]['w'] + 0.4, 0.9, T[3]['d'] + 0.4, p['trim'], 0, o['tH'] - 0.45, 0, top)
        V(0.5, o['tH'] * 0.55, 0.3, shade(p['cloth'], 0.7), 0, o['tH'] * 0.55, T[2]['d'] / 2 + 0.15, top)
        for f in (0.42, 0.58, 0.74):
            V(0.8, 0.8, 0.4, 0xd8b04a, 0, o['tH'] * f, T[2]['d'] / 2 + 0.4, top)
    else:
        if race != 'slime':
            LC = 0x6a4a34
            V(T[0]['w'] + 0.5, 1.0, T[0]['d'] + 0.5, shade(LC, 0.8), 0, T[0]['h'] - 0.5, 0, top)
            V(T[0]['w'] * 0.55, 5.4, 0.8, LC, 0, -1.6, T[0]['d'] / 2 + 0.4, top)
            V(T[0]['w'] * 0.55, 5.4, 0.8, shade(LC, 0.9), 0, -1.6, -T[0]['d'] / 2 - 0.4, top)
    arms = []; hand_p = None; hand_m = None
    for s in (-1, 1):
        pv = top.add(Node('ArmL' if s == 1 else 'ArmR', (s * (T[3]['w'] / 2 + o['aw'] * 0.35), o['tH'] - 0.8, 0)))
        ul = o['al'] * 0.46; fl = o['al'] * 0.42
        ac = p['skin'] if nk else p['cloth']
        V(o['aw'] + 0.9, o['aw'] + 0.8, o['ad'] + 0.9, ac, 0, 0.1, 0, pv)
        V(o['aw'], ul, o['ad'], ac, 0, -ul / 2, 0, pv)
        V(o['aw'] + 0.7, 1, o['ad'] + 0.7, shade(p['skin'], 0.94) if nk else p['trim'], 0, -ul - 0.1, 0, pv)
        V(o['aw'] * 0.88, fl, o['ad'] * 0.9, p['skin'], 0, -ul - fl / 2 - 0.4, 0, pv)
        V(o['aw'] + 0.2, o['aw'] * 0.9, o['ad'] * 0.95, shade(p['skin'], 0.95), 0, -o['al'] + o['aw'] * 0.35, 0.2, pv)
        hd_ = pv.add(Node('HandL' if s == 1 else 'HandR', (0, -o['al'] + o['aw'] * 0.35, o['ad'] / 2 + 0.7)))
        if s == 1: hand_p = hd_
        else: hand_m = hd_
        arms.append(pv)
    S = p['skin']
    h = top.add(Node('Head', (0, o['tH'] + o['neck'] + o['hh'] / 2, o.get('hz', 0))))
    hw = o['hw']; hh = o['hh']; hd = o['hd']; jh = o['jh']
    V(hw * 0.46, o['neck'] + 1.6, hd * 0.46, shade(S, 0.88), 0, -hh / 2 - o['neck'] / 2, 0, h)
    V(hw, hh, hd, S, 0, 0, 0, h)
    V(hw * 0.78, jh, hd * 0.86, shade(S, 0.96), 0, -hh / 2 - jh / 2 + 0.7, 0.5, h)
    V(hw * 0.94, 0.9, 0.9, shade(S, 0.84), 0, hh * 0.17, hd / 2 + 0.2, h)
    ex = hw * 0.27; ey = hh * 0.02; e = o['eye']; bc = shade(p['hair'], 0.8)
    for s in (-1, 1):
        V(1.4, 1.2, 1, shade(S, 0.94), s * hw * 0.42, -hh * 0.12, hd / 2 - 0.1, h)
        if e.get('glow'):
            VG(e['w'], e['h'], 0.5, p['eye'], s * ex, ey, hd / 2 + 0.25, h)
        else:
            V(e['w'], e['h'], 0.4, 0xffffff if e.get('white') else p['eye'], s * ex, ey, hd / 2 + 0.2, h)
            if e.get('white'):
                V(e['w'] * 0.55, e['h'], 0.5, p['eye'], s * ex - s * e['w'] * 0.12, ey, hd / 2 + 0.35, h)
                V(e['w'] * 0.25, e['h'] * 0.7, 0.55, 0x111111, s * ex - s * e['w'] * 0.12, ey, hd / 2 + 0.4, h)
            else:
                V(e['w'] * 0.3, e['h'] * 0.6, 0.5, 0x111111, s * ex - s * e['w'] * 0.15, ey, hd / 2 + 0.35, h)
        V(e['w'] * 1.6, 0.6, 0.5, e.get('brow', bc), s * ex, ey + e['h'] * 0.5 + 0.9, hd / 2 + 0.35, h, rz=s * e['tilt'])
    if not o.get('noNose'):
        V(1.4, 2.2, 1.5, shade(S, 0.92), 0, -hh * 0.1, hd / 2 + 0.7, h)
        V(2.2, 0.8, 1, shade(S, 0.88), 0, -hh * 0.22, hd / 2 + 0.5, h)
    if not o.get('noMouth'):
        V(hw * 0.34, 0.5, 0.4, 0x4a1e1e, 0, -hh * 0.36, hd / 2 + 0.15, h)
    # points d'accroche pour l'équipement (nœuds vides)
    h.add(Node('Slot_Head', (0, hh / 2, 0)))
    top.add(Node('Slot_Chest', (0, T[2]['cy'], T[2]['d'] / 2)))
    top.add(Node('Slot_Back', (0, T[2]['cy'], -T[2]['d'] / 2)))
    top.add(Node('Slot_HipL', (T[1]['w'] / 2, 0.5, 0)))
    top.add(Node('Slot_HipR', (-T[1]['w'] / 2, 0.5, 0)))
    return dict(g=g, top=top, head=h, arm_dummy=None, arms=arms, hand_p=hand_p, hand_m=hand_m, legs=legs, o=o, p=p, T=T)

def hair(b, st, c, long_):
    o = b['o']; h = b['head']; hw = o['hw']; hh = o['hh']; hd = o['hd']
    if st == 2:
        for i in range(5):
            V(1.5, 2 + (0.7 if i % 2 else 0), 1.7, c, 0, hh / 2 + 1 + (0.3 if i % 2 else 0), -hd / 2 + 1 + i * 1.5, h)
        V(1.5, 1.6, 1.6, c, 0, hh / 2 - 0.5, -hd / 2 - 1.2, h)
        V(1.4, 1.5, 1.5, c, 0, hh / 2 - 2, -hd / 2 - 2, h)
        V(1.4, 3, 1.4, c, 0, hh / 2 - 4.2, -hd / 2 - 2.4, h)
        return
    V(hw + 1, 1.8, hd + 1, c, 0, hh / 2 + 0.3, 0, h)
    V(hw + 0.8, hh * 0.85, 1.7, c, 0, -hh * 0.02, -(hd / 2 + 0.5), h)
    for s in (-1, 1):
        V(1, hh * 0.55, hd * 0.7, c, s * (hw / 2 + 0.4), hh * 0.18, -0.7, h)
        V(0.9, 2.6, 0.8, c, s * (hw / 2 + 0.2), hh * 0.02, hd / 2 - 0.6, h)
    V(2.6, 1.6, 1, c, -2.4, hh / 2 - 0.4, hd / 2 + 0.5, h)
    V(2.2, 2.6, 1, c, 0, hh / 2 - 1, hd / 2 + 0.55, h)
    V(2.4, 1.4, 1, c, 2.6, hh / 2 - 0.3, hd / 2 + 0.5, h)
    if st == 1:
        V(hw + 0.6, 3.2, 2, c, 0, -hh * 0.4, -(hd / 2 + 0.8), h)
        V(hw, 3.2, 2, shade(c, 0.95), 0, -hh * 0.4 - 3, -(hd / 2 + 1), h)
        V(hw - 1.2, 3.2, 2, shade(c, 0.9), 0, -hh * 0.4 - 6, -(hd / 2 + 1.2), h)
        if long_: V(hw - 2.4, 3, 1.8, shade(c, 0.85), 0, -hh * 0.4 - 9, -(hd / 2 + 1.3), h)
        for s in (-1, 1):
            V(1.5, 5, 1.6, c, s * (hw / 2 + 0.8), -hh * 0.4, hd / 2 - 1.4, h)

def cape(b, k):
    if not b['p']['cape'] or k in ('marchand', 'fermier', 'mineur', 'aubergiste'): return
    o = b['o']; p = b['p']; tH = o['tH']; T = b['T']; cw = T[2]['w']; top = b['top']
    V(cw + 0.6, tH * 1.25, 0.9, p['trim'], 0, tH * 0.42, -(T[2]['d'] / 2 + 0.8), top, rx=0.05)
    for i in range(4):
        V(cw / 4 + 0.1, 2 + (i % 2) * 1.6, 0.9, shade(p['trim'], 0.9), -cw * 0.375 + i * cw / 4,
          tH * 0.42 - tH * 0.625 - 1 - (i % 2) * 0.8, -(T[2]['d'] / 2 + 0.9), top)
    V(cw * 0.7, 1.6, T[3]['d'] + 1.2, p['trim'], 0, tH + 0.1, 0, top)
    V(1.3, 1.3, 0.7, 0xd8b04a, 0, tH - 0.4, T[3]['d'] / 2 + 0.9, top)

# ---------------------------------------------------------------- métiers (relief)
def dress(b, k):
    if b['p'].get('naked'): return
    o = b['o']; p = b['p']; head = b['head']; top = b['top']; g = b['g']; T = b['T']
    ch = T[2]; wa = T[1]; sh = T[3]; tH = o['tH']; HT = o['hh'] / 2
    hw = o['hw']; hd = o['hd']; aw = o['aw']; ad = o['ad']; al = o['al']
    wood = 0x8a6238; metal = 0x9aa0ab; gold = 0xd8b04a
    hp = b['hand_p']; hm = b['hand_m']; arms = b['arms']; legs = b['legs']
    if k == 'forgeron':
        bh = ch['h'] + wa['h'] * 0.8
        V(ch['w'] * 0.66, bh, 0.9, p['acc'], 0, wa['y0'] + bh / 2, ch['d'] / 2 + 0.6, top)
        V(wa['w'] + 0.6, 6.5, 0.9, shade(p['acc'], 0.92), 0, -2.6, wa['d'] / 2 + 0.8, top)
        for s in (-1, 1):
            V(0.5, 6.5, 0.4, shade(p['acc'], 0.7), s * 1.9, -2.6, wa['d'] / 2 + 1.35, top)
            V(1.2, 0.7, sh['d'] + 1, p['acc'], s * sh['w'] * 0.3, tH - 0.5, 0, top)
            V(1.2, 3.4, 0.6, p['acc'], s * sh['w'] * 0.3, tH - 2, ch['d'] / 2 + 0.5, top)
        V(3.4, 2.4, 0.6, shade(p['acc'], 1.3), 0, wa['y0'] + wa['h'] + 1.4, ch['d'] / 2 + 1.2, top)
        V(0.7, 3, 0.6, 0x7d838c, -0.8, wa['y0'] + wa['h'] + 3, ch['d'] / 2 + 1.3, top)
        V(0.7, 2.6, 0.6, wood, 0.8, wa['y0'] + wa['h'] + 2.8, ch['d'] / 2 + 1.3, top)
        V(0.6, 5, 0.6, 0x7d838c, -(wa['w'] / 2 + 0.9), -0.8, 0.6, top, rx=0.2)
        V(0.6, 5, 0.6, 0x9aa0ab, -(wa['w'] / 2 + 0.9), -0.8, -0.5, top, rx=-0.2)
        for a in arms:
            V(aw + 0.9, al * 0.3, ad + 0.9, shade(p['boot'], 1.2), 0, -al * 0.72, 0, a)
            V(aw + 1.1, aw + 0.9, ad + 1.1, p['boot'], 0, -al + aw * 0.35, 0.2, a)
            V(aw + 0.9, 0.9, ad + 0.9, p['trim'], 0, -al * 0.46 - 0.4, 0, a)
        V(hw + 1.2, 1.4, hd + 1.2, p['trim'], 0, HT - 1.8, 0, head)
        for s in (-1, 1):
            V(2.4, 2.2, 0.9, 0x9fd8e0, s * 2, HT - 1.6, hd / 2 + 0.9, head)
            V(3, 2.8, 0.6, 0x555b63, s * 2, HT - 1.6, hd / 2 + 0.6, head)
        V(1, 12, 1, wood, 0, 3, 0, hp)
        V(5.4, 3.4, 3.2, 0x7d838c, 0, 9.6, 0, hp)
        for s in (-1, 1): V(1, 3.8, 3.6, 0x555b63, s * 3, 9.6, 0, hp)
        V(1.4, 1.4, 1.4, gold, 0, -3.2, 0, hp)
    if k == 'marchand':
        V(hw + 7, 1, hd + 7, p['acc'], 0, HT + 0.2, 0, head)
        V(hw + 1, 4, hd + 1, p['acc'], 0, HT + 2.6, 0, head)
        V(hw + 1.4, 1, hd + 1.4, gold, 0, HT + 1.3, 0, head)
        V(0.8, 3.2, 0.8, p['trim'], 3, HT + 3.6, 1, head, rz=-0.4)
        V(0.8, 2, 0.8, shade(p['trim'], 1.3), 4.3, HT + 5.4, 1, head)
        V(hw * 0.9, 1.8, hd * 0.9, p['trim'], 0, -HT - o['neck'] + 0.4, 0, head)
        V(1.8, 5.5, 0.7, p['trim'], -2.6, tH - 2.5, ch['d'] / 2 + 0.7, top)
        for s in (-1, 1):
            V(2.4, tH * 0.7, 0.9, p['acc'], s * ch['w'] * 0.3, tH * 0.55, ch['d'] / 2 + 0.5, top)
            V(ch['w'] * 0.4, 6.5, 0.9, p['acc'], s * 2.4, -2.6, -wa['d'] / 2 - 0.7, top)
            V(3, 3.4, 2.4, p['sack'], s * (wa['w'] / 2 + 1.6), 0.2, 0.4, top)
            V(1, 1, 0.5, gold, s * (wa['w'] / 2 + 1.6), 1.2, 1.7, top)
        bz = -(ch['d'] / 2 + 2.6)
        V(9, 10, 4, p['sack'], 0, tH * 0.5, bz, top)
        V(9.4, 3.2, 4.4, shade(p['sack'], 1.2), 0, tH * 0.5 + 3.6, bz, top)
        V(11, 3.2, 3.2, p['trim'], 0, tH + 1.4, bz, top)
        V(1, 1, 0.6, gold, 0, tH * 0.5 + 3.6, bz + 2.3, top)
        V(2.4, 2.4, 2.4, 0x6a6f78, 5.6, tH * 0.35, bz, top)
        V(0.5, 3, 0.5, 0x555b63, 5.6, tH * 0.35 + 2.6, bz, top)
        V(0.4, 2, 0.4, 0x3a3a3a, 0, -al + aw * 0.35 + 2, 0, hm)
        V(2.8, 3, 2.8, 0x3a3a3a, 0, -0.6, 0, hm)
        VG(1.8, 2, 1.8, 0xffd86a, 0, -0.6, 0, hm)
    if k == 'garde':
        V(hw + 1.6, 4, hd + 1.6, metal, 0, HT - 0.4, 0, head)
        V(hw + 2.2, 0.8, hd + 2.2, shade(metal, 1.2), 0, HT - 2.4, 0, head)
        for s in (-1, 1): V(1, 4.4, 2.6, metal, s * (hw / 2 + 0.9), -1.5, hd / 2 - 1.6, head)
        V(1, 4.4, 0.8, metal, 0, -1.2, hd / 2 + 0.7, head)
        for i in range(4): V(1.4, 2.4 - i * 0.3, 1.6, p['acc'], 0, HT + 2.4, -hd / 2 + 1.6 + i * 1.8, head)
        V(1.4, 4, 1.4, p['acc'], 0, HT, -hd / 2 - 1.2, head)
        V(hw * 0.9, 1.8, hd * 0.9, shade(metal, 1.1), 0, -HT - o['neck'] + 0.6, 0, head)
        V(ch['w'] + 0.6, ch['h'] + 0.2, ch['d'] + 0.7, metal, 0, ch['cy'], 0, top)
        V(0.8, ch['h'] * 0.9, 0.6, shade(metal, 1.25), 0, ch['cy'], ch['d'] / 2 + 0.5, top)
        V(2.4, 3, 0.6, gold, 0, ch['cy'] + 0.4, ch['d'] / 2 + 0.8, top)
        for i in range(3):
            V(wa['w'] + 0.8 + i * 0.2, 1.1, wa['d'] + 0.8, shade(metal, 1 - i * 0.06), 0, wa['y0'] + wa['h'] - 0.6 - i * 1.0, 0, top)
        V(wa['w'] * 0.9, 8, 0.7, p['acc'], 0, -2.5, wa['d'] / 2 + 1, top)
        V(wa['w'] * 0.9, 8, 0.7, shade(p['acc'], 0.85), 0, -2.5, -wa['d'] / 2 - 1, top)
        V(2.2, 2.2, 0.5, gold, 0, -1.4, wa['d'] / 2 + 1.4, top)
        for a in arms:
            V(aw + 2.6, 1.4, ad + 2.6, metal, 0, 0.9, 0, a)
            V(aw + 2.2, 1.2, ad + 2.2, shade(metal, 0.92), 0, -0.3, 0, a)
            V(aw + 1.8, 1.2, ad + 1.8, shade(metal, 0.85), 0, -1.4, 0, a)
            V(aw + 0.9, al * 0.3, ad + 0.9, metal, 0, -al * 0.72, 0, a)
            V(aw + 1.4, 1.6, ad + 1.4, shade(metal, 1.2), 0, -al * 0.46 - 0.4, 0, a)
            V(aw + 1, aw + 0.8, ad + 1, shade(metal, 0.8), 0, -al + aw * 0.35, 0.2, a)
        for l in legs:
            V(o['lw'] + 1, o['legH'] * 0.3, o['ld'] + 1, metal, 0, -o['legH'] * 0.62, 0.1, l)
            V(o['lw'] + 1.4, 1.8, o['ld'] + 1.4, shade(metal, 1.2), 0, -o['legH'] * 0.46 - 0.4, 0.2, l)
        V(1, 30, 1, wood, 0, 10, 0, hp)
        V(1.6, 1.6, 1.6, p['acc'], 0, 24, 0, hp)
        V(2.4, 1.4, 2.4, 0xd9dde3, 0, 25.8, 0, hp)
        V(1.6, 1.4, 1.6, 0xd9dde3, 0, 27.2, 0, hp)
        V(0.8, 1.4, 0.8, 0xd9dde3, 0, 28.6, 0, hp)
        A = arms[0]; sy = -al * 0.5; sz = ad / 2 + 1.6
        V(8.4, 10.6, 1.3, p['acc'], -1, sy, sz, A)
        V(9.2, 11.4, 0.8, metal, -1, sy, sz - 0.4, A)
        V(2.6, 2.6, 0.9, gold, -1, sy, sz + 0.9, A)
        V(1.2, 10.6, 0.5, gold, -1, sy, sz + 0.7, A)
    if k == 'mage':
        V(hw + 7, 0.9, hd + 7, p['acc'], 0, HT + 0.1, 0, head)
        for i in range(5):
            w = hw + 1.4 - i * 1.8
            V(w, 2.2, w * hd / hw, p['acc'], i * i * 0.18, HT + 1.5 + i * 2.1, 0, head)
        V(hw + 1.8, 0.9, hd + 1.8, gold, 0, HT + 1.2, 0, head)
        VG(1.2, 1.2, 0.6, p['orb'], 0, HT + 2.6, hd / 2 + 0.8, head)
        yb = o['legH']
        V(wa['w'] + 1.6, 4.5, wa['d'] + 1.6, p['cloth'], 0, yb * 0.82, 0, g)
        V(wa['w'] + 2.6, 4.5, wa['d'] + 2.6, shade(p['cloth'], 0.95), 0, yb * 0.82 - 4.4, 0, g)
        V(wa['w'] + 3.6, 4.6, wa['d'] + 3.6, shade(p['cloth'], 0.9), 0, yb * 0.82 - 8.8, 0, g)
        V(wa['w'] + 4, 1.1, wa['d'] + 4, p['acc'], 0, 0.9, 0, g)
        for x in (-2.4, 0, 2.4):
            VG(0.9, 1.4, 0.4, p['orb'], x, 2.6, (wa['d'] + 3.6) / 2 + 0.3, g)
        V(ch['w'] + 3, 2.4, sh['d'] + 2.4, p['acc'], 0, tH - 0.2, 0, top)
        for s in (-1, 1): VG(1.2, 1.2, 1.2, p['orb'], s * (ch['w'] / 2 + 1.4), tH - 0.2, 0, top)
        V(1.4, 1.4, 0.7, gold, 0, tH - 0.6, ch['d'] / 2 + 1.3, top)
        for a in arms:
            V(aw + 2, 5.4, ad + 2, p['cloth'], 0, -al * 0.48, 0, a)
            V(aw + 2.6, 1.2, ad + 2.6, p['acc'], 0, -al * 0.48 - 2.8, 0, a)
        V(3, 4, 1.6, 0x6a3a2a, wa['w'] / 2 + 2.2, -0.6, wa['d'] / 2 + 0.4, top)
        V(3.2, 0.6, 1.8, gold, wa['w'] / 2 + 2.2, 0.6, wa['d'] / 2 + 0.4, top)
        for q in ((-1.6, 0xff6a8a), (-0.2, 0x6ad0ff), (1.2, 0xa0ff8a)):
            V(1, 1.7, 1, q[1], q[0] - 2, -0.4, wa['d'] / 2 + 1, top)
        V(1, 30, 1, wood, 0, 10, 0, hp)
        for s in (-1, 1): V(0.8, 3, 0.8, wood, s * 1.1, 26, 0, hp, rz=-s * 0.4)
        VG(2.8, 2.8, 2.8, p['orb'], 0, 28, 0, hp, rx=0.6, rz=0.6)
        VG(1.4, 1.4, 1.4, 0xffffff, 0, 28, 0, hp, rx=0.6, rz=0.6)
        VG(1.2, 1.2, 1.2, shade(p['orb'], 0.8), 2.2, 26.6, 0, hp, rz=0.8)
    if k == 'fermier':
        # chapeau de paille, salopette, fourche
        straw = p['acc']
        V(hw + 7, 0.8, hd + 7, straw, 0, HT + 0.2, 0, head)
        V(hw + 1.2, 2.6, hd + 1.2, shade(straw, 0.95), 0, HT + 1.8, 0, head)
        V(hw + 1.4, 0.8, hd + 1.4, 0x9a3a2a, 0, HT + 0.9, 0, head)
        for i in range(6):
            V(1.2, 0.6, 0.5, shade(straw, 0.8), -hw / 2 - 3 + i * (hw + 6) / 5, HT - 0.2, hd / 2 + 3.4, head)
        V(ch['w'] * 0.62, ch['h'] + wa['h'], 0.8, p['pants'], 0, wa['y0'] + (ch['h'] + wa['h']) / 2, ch['d'] / 2 + 0.5, top)
        V(ch['w'] * 0.4, 2.6, 0.5, shade(p['pants'], 0.85), 0, ch['cy'], ch['d'] / 2 + 1, top)
        for s in (-1, 1):
            V(1.2, sh['h'] + 1, sh['d'] + 0.9, p['pants'], s * ch['w'] * 0.24, tH - 1, 0, top)
            V(1, 1, 0.6, gold, s * ch['w'] * 0.24, ch['y0'] + ch['h'] - 0.4, ch['d'] / 2 + 1, top)
        for a in arms:
            V(aw + 0.8, 1.4, ad + 0.8, shade(p['cloth'], 0.9), 0, -al * 0.42, 0, a)
        V(1, 26, 1, wood, 0, 8, 0, hp)
        V(5.4, 1, 1, 0x7d838c, 0, 21.4, 0, hp)
        for x in (-2.2, 0, 2.2):
            V(0.6, 4.2, 0.6, 0x9aa0ab, x, 24, 0, hp)
        V(2.6, 3.2, 2.6, 0xd8b860, wa['w'] / 2 + 1.6, -0.6, 0.6, top)
        V(2.8, 0.6, 2.8, 0x9a3a2a, wa['w'] / 2 + 1.6, 0.4, 0.6, top)
    if k == 'mineur':
        # casque à lampe, sac de minerai, pioche
        V(hw + 1.4, 3, hd + 1.4, p['acc'], 0, HT + 0.2, 0, head)
        V(hw + 2.4, 0.7, hd + 2.4, shade(p['acc'], 0.85), 0, HT - 1.2, 0, head)
        V(2.6, 2.4, 1, 0x3a3a3a, 0, HT + 0.2, hd / 2 + 1.2, head)
        VG(1.8, 1.6, 0.6, 0xffe08a, 0, HT + 0.2, hd / 2 + 1.8, head)
        V(hw * 0.9, 1.4, hd * 0.9, 0x3a342e, 0, -HT - o['neck'] + 0.4, 0, head)
        V(ch['w'] + 0.6, 1.4, ch['d'] + 0.6, p['belt'], 0, ch['y0'] + ch['h'] - 1.4, 0, top)
        for s in (-1, 1):
            V(1.4, tH * 0.9, 0.6, p['belt'], s * ch['w'] * 0.28, tH * 0.55, ch['d'] / 2 + 0.4, top, rz=s * 0.25)
        bz = -(ch['d'] / 2 + 2.2)
        V(7.6, 8, 3.4, p['sack'], 0, tH * 0.48, bz, top)
        V(7.8, 1.2, 3.6, shade(p['sack'], 0.8), 0, tH * 0.48 + 4, bz, top)
        for q in ((-2, 0x7d838c), (0.4, 0xd8b04a), (2.2, 0x8a6a5a)):
            V(2, 1.8, 2, q[1], q[0], tH * 0.48 + 5.2, bz, top)
        VG(1.2, 1.2, 1.2, 0x7fe0ff, 1.2, tH * 0.48 + 6, bz + 0.6, top)
        for a in arms:
            V(aw + 1, aw + 0.9, ad + 1, 0x5a4a3a, 0, -al + aw * 0.35, 0.2, a)
        for l in legs:
            V(o['lw'] + 0.8, o['legH'] * 0.18, o['ld'] + 0.8, shade(p['pants'], 0.8), 0, -o['legH'] * 0.6, 0.1, l)
        V(1, 20, 1, wood, 0, 6, 0, hp)
        V(1.6, 1.6, 1.6, 0x555b63, 0, 16, 0, hp)
        for s in (-1, 1):
            V(5, 1.4, 1.4, 0x7d838c, s * 3, 16.4, 0, hp, rz=-s * 0.25)
            V(1.6, 1, 1, 0x9aa0ab, s * 6, 15.2, 0, hp, rz=-s * 0.7)
    if k == 'aubergiste':
        # grand tablier, torchon sur l'épaule, chope de bière
        ap_ = p['acc']
        V(ch['w'] * 0.7, ch['h'] * 0.9, 0.7, ap_, 0, ch['y0'] + ch['h'] * 0.45, ch['d'] / 2 + 0.5, top)
        V(wa['w'] + 1, 10, 0.8, ap_, 0, wa['y0'] - 3.4, wa['d'] / 2 + 0.8, top)
        V(wa['w'] + 1.2, 1.2, 0.9, shade(ap_, 0.88), 0, wa['y0'] - 8, wa['d'] / 2 + 0.85, top)
        V(3, 2.4, 0.6, shade(ap_, 0.9), 1.8, wa['y0'] - 2, wa['d'] / 2 + 1.3, top)
        V(wa['w'] + 1.2, 1, wa['d'] + 1.2, ap_, 0, wa['y0'] + wa['h'] - 0.6, 0, top)
        V(3.2, 1, sh['d'] + 1.2, 0xc8b89a, -sh['w'] * 0.32, tH + 0.1, 0, top)
        V(3.2, 4, 0.7, 0xc8b89a, -sh['w'] * 0.32, tH - 2, sh['d'] / 2 + 0.7, top)
        V(3.2, 3.4, 0.7, 0xa8987a, -sh['w'] * 0.32, tH - 1.6, -sh['d'] / 2 - 0.7, top)
        for a in arms:
            V(aw + 1.2, 2, ad + 1.2, shade(p['cloth'], 0.92), 0, -al * 0.4, 0, a)
        V(hw + 1.2, 1.6, hd + 1.2, 0xa83a2a, 0, HT - 0.6, 0, head)
        V(2, 2.4, 1.6, 0xa83a2a, -hw / 2 + 0.4, HT - 1.8, -hd / 2 - 0.6, head)
        V(3.6, 4.6, 3.6, 0x8a6238, 0, 2.6, 0, hp)
        V(3.8, 0.6, 3.8, 0x7d838c, 0, 1.2, 0, hp)
        V(3.8, 0.6, 3.8, 0x7d838c, 0, 4.2, 0, hp)
        V(3.8, 1.4, 3.8, 0xf6f0de, 0, 5.4, 0, hp)
        V(1, 3, 1.2, 0x6a4a2a, 2.3, 2.8, 0, hp)
    if k == 'chasseur':
        # capuche, pelisse, carquois et arc
        hood = p['acc']; hh = o['hh']
        V(hw + 1.6, hh * 0.6, hd + 1.6, hood, 0, HT - hh * 0.2, -0.3, head)
        for s in (-1, 1):
            V(1, hh * 0.7, hd * 0.8, hood, s * (hw / 2 + 0.7), -0.4, -0.6, head)
        V(hw * 0.7, hh * 0.6, 1.6, shade(hood, 0.9), 0, -0.6, -hd / 2 - 0.6, head)
        V(2.4, 2.6, 2, shade(hood, 0.85), 0, HT - 1, -hd / 2 - 1.6, head)
        V(ch['w'] + 2.4, 2.6, sh['d'] + 2.2, p['fur'], 0, tH - 0.6, 0, top)
        for i in range(5):
            V(1.8, 1.6 + (i % 2), 1, shade(p['fur'], 0.9), -ch['w'] / 2 + i * ch['w'] / 4, tH - 2.4, sh['d'] / 2 + 1.1, top)
        V(1.4, tH * 1.1, 0.6, 0x5a3a24, 0, tH * 0.5, ch['d'] / 2 + 0.4, top, rz=0.7)
        qz = -(ch['d'] / 2 + 1.6)
        V(3.2, 10, 2.8, 0x6a4026, 2.2, tH * 0.55, qz, top, rz=-0.3)
        V(3.4, 1, 3, 0x8a6a3a, 2.2 + 1.4, tH * 0.55 + 4.6, qz, top, rz=-0.3)
        for x, c in ((2.6, 0xd04a3a), (3.8, 0xf0f0f0), (5, 0xd04a3a)):
            V(0.8, 3, 0.8, c, x + 0.6, tH * 0.55 + 6.4, qz, top, rz=-0.3)
        V(3, 3, 2, 0x8a6a4a, -(wa['w'] / 2 + 1.4), -0.4, 0.4, top)
        for a in arms:
            V(aw + 1, al * 0.32, ad + 1, 0x6a4a34, 0, -al * 0.74, 0, a)
        for i, (y, z) in enumerate(((-9, -1.6), (-6, -0.6), (-3, 0), (0, 0.2), (3, 0), (6, -0.6), (9, -1.6))):
            V(1, 3.4, 1, wood if i != 3 else 0x3a2a1e, 0, y + 6, z + 2, hp)
        V(0.3, 18, 0.3, 0xf0eee0, 0, 6, -2.2 + 2, hp)
    cape(b, k)

# ---------------------------------------------------------------- races
def human(k, p):
    o = dict(legH=13, lw=4.4, ld=4.6, gap=2.7,
             tiers=[[2.4, 8.4, 5], [3, 7.6, 4.6], [4.2, 9.6, 5.4], [2.4, 10.6, 5]],
             neck=1.2, hw=7.2, hh=6.4, hd=7, jh=2.2, aw=3.6, al=12.5, ad=3.8,
             eye=dict(w=1.6, h=1, tilt=0.3, white=True))
    b = build(o, p, 'human')
    hair(b, p['hs'], p['hair'], False)
    for s in (-1, 1): V(1, 2.4, 1.6, p['skin'], s * (o['hw'] / 2 + 0.5), -0.2, -0.2, b['head'])
    if p['beard'] and p['hs'] != 2:
        V(o['hw'] * 0.7, 2.4, 1.2, p['hair'], 0, -o['hh'] / 2 - 0.2, o['hd'] / 2 + 0.2, b['head'])
        V(o['hw'] * 0.5, 1.6, 1.4, shade(p['hair'], 0.9), 0, -o['hh'] / 2 - 1.6, o['hd'] / 2 - 0.2, b['head'])
        V(o['hw'] * 0.55, 0.9, 0.8, p['hair'], 0, -o['hh'] * 0.22, o['hd'] / 2 + 0.5, b['head'])
    dress(b, k); return b

def elf(k, p):
    st = 1 if p['hs'] == 0 else p['hs']
    o = dict(legH=16, lw=3.4, ld=3.6, gap=2.2,
             tiers=[[2, 6.4, 4], [3, 5.8, 3.8], [4, 7.6, 4.4], [2.2, 8.4, 4.2]],
             neck=1.4, hw=6, hh=6, hd=6, jh=2.4, aw=2.6, al=13.5, ad=2.8,
             eye=dict(w=1.6, h=0.7, tilt=0.2, glow=True))
    b = build(o, p, 'elf'); h = b['head']
    hair(b, st, p['hair'], True)
    for s in (-1, 1):
        V(1, 1.4, 0.8, p['skin'], s * (o['hw'] / 2 + 0.5), 0.8, -0.5, h)
        V(1, 1.2, 0.7, p['skin'], s * (o['hw'] / 2 + 1.5), 2, -0.6, h)
        V(1, 1.2, 0.6, p['skin'], s * (o['hw'] / 2 + 2.5), 3.2, -0.7, h)
        V(0.8, 1, 0.5, p['skin'], s * (o['hw'] / 2 + 3.3), 4.3, -0.8, h)
        V(0.7, 3.6, 0.5, shade(p['skin'], 0.88), s * (o['hw'] / 2 + 0.4), -1.6, -0.4, h)
    if not p.get('naked'):
        V(o['hw'] + 0.8, 0.7, o['hd'] + 0.8, 0xd8b04a, 0, o['hh'] / 2 - 1, 0, h)
        VG(1, 1.4, 0.6, p['eye'], 0, o['hh'] / 2 - 0.9, o['hd'] / 2 + 0.5, h)
    dress(b, k); b['g'].scale = 1.02; return b

def goblin(k, p):
    o = dict(legH=8.5, lw=3.4, ld=3.6, gap=2.2,
             tiers=[[2, 6.4, 4.4], [2.4, 6, 4.4], [3.2, 7.4, 5], [1.8, 8, 4.8]],
             neck=1, hw=8.6, hh=7, hd=7.6, jh=2.4, aw=3, al=14, ad=3.2, lean=0.3, hz=2.5,
             noNose=True, eye=dict(w=2.4, h=1.8, tilt=0.55, white=False, brow=0x3a4a20))
    b = build(o, p, 'goblin')
    dk = shade(p['skin'], 0.82); hh = o['hh']; hw = o['hw']; hd = o['hd']; h = b['head']
    for s in (-1, 1):
        V(2.4, 3.2, 1, p['skin'], s * (hw / 2 + 1.2), 0.4, 0, h)
        V(2.4, 2.6, 1, p['skin'], s * (hw / 2 + 3.4), 1.4, 0, h)
        V(2, 2, 1, dk, s * (hw / 2 + 5.2), 2.6, 0, h)
        V(1.2, 1.2, 1, dk, s * (hw / 2 + 6.6), 3.6, 0, h)
        V(1.6, 1.2, 0.6, dk, s * (hw / 2 + 2.8), -0.6, 0, h)
        if not p.get('naked'): VG(0.8, 0.8, 0.6, 0xd8b04a, s * (hw / 2 + 3), -1.4, 0.4, h)
        V(1, 1.8, 0.8, 0xf0ead0, s * 1.9, -hh * 0.42, hd / 2 + 0.3, h)
        V(0.8, 1.2, 0.7, 0xf0ead0, s * 0.7, -hh * 0.42 - 0.2, hd / 2 + 0.2, h)
        V(1.6, 1.6, 1.6, dk, s * 2.6, hh / 2 + 0.6, 0, h)
    V(1.6, 2.2, 1.6, dk, 0, -hh * 0.08, hd / 2 + 0.8, h)
    V(1.4, 1.6, 1.4, dk, 0, -hh * 0.22, hd / 2 + 1.7, h)
    V(1.2, 1.4, 1.2, dk, 0, -hh * 0.36, hd / 2 + 2.3, h)
    V(0.7, 0.7, 0.7, shade(p['skin'], 0.6), 1.2, -hh * 0.14, hd / 2 + 1.3, h)
    V(2.4, 0.6, 0.5, 0x3a1a1a, 0, -hh * 0.42, hd / 2 + 0.1, h)
    for i, x in enumerate((-2, 0, 2)):
        V(1.2, 2 + (i % 2) * 1.2, 1.2, p['hair'], x, hh / 2 + 1.4, -1, h)
    T = b['T']; top = b['top']
    if not p.get('naked'):
        for i, q in enumerate(((-3, 4.5), (-0.8, 6), (1.8, 3.6), (4, 5))):
            V(1.8, q[1], 0.5, shade(p['cloth'], 0.8 + i * 0.08), q[0], -1 - q[1] / 2 + 0.4, T[1]['d'] / 2 + 0.9, top)
        for i in range(7):
            a = (i / 6.0 - 0.5) * 2.4
            V(0.9, 0.9, 0.9, 0xf0ead0, math.sin(a) * 3.4, o['tH'] + 0.2 - math.cos(a) * 0.2, T[3]['d'] / 2 + 0.6, top)
        V(2.4, 2, 0.8, shade(p['cloth'], 0.75), T[3]['w'] / 2 - 1, o['tH'] - 1.6, T[3]['d'] / 2 + 0.5, top)
    dress(b, k); b['g'].scale = 0.95; return b

def orc(k, p):
    o = dict(legH=13, lw=6.4, ld=6.4, gap=3.8,
             tiers=[[2.6, 10, 7], [3.4, 9, 6.6], [5.6, 14, 8], [3.4, 16.4, 7.6]],
             neck=1.2, hw=8, hh=6.6, hd=8, jh=2.2, aw=6.4, al=14, ad=6.4, lean=0.1,
             noNose=True, noMouth=True,
             eye=dict(w=1.6, h=1, tilt=0.5, white=False, glow=True, brow=0x2a1e18))
    b = build(o, p, 'orc')
    sc = shade(p['skin'], 0.88); h = b['head']; hh = o['hh']; hw = o['hw']; hd = o['hd']
    V(hw * 0.66, 3.6, 3.4, sc, 0, -hh * 0.2, hd / 2 + 1.5, h)
    V(hw * 0.6, 1, 3.2, shade(sc, 0.92), 0, -hh * 0.2 + 2, hd / 2 + 1.3, h)
    for s in (-1, 1):
        VG(1, 0.9, 0.5, 0x3a1a18, s * 1.4, -hh * 0.2 + 0.2, hd / 2 + 3.3, h)
        V(1, 2.2, 1, 0xf2ecd8, s * 3.2, -hh * 0.42, hd / 2 + 1.4, h)
        V(0.8, 1.2, 0.8, 0xf2ecd8, s * 3.2, -hh * 0.42 + 1.4, hd / 2 + 1.4, h)
        V(1.2, 4.4, 3.6, p['skin'], s * (hw / 2 + 1.8), hh * 0.3, -0.5, h, rz=-s * 0.6)
        V(0.6, 2.6, 2, shade(p['skin'], 0.75), s * (hw / 2 + 1.7), hh * 0.3, -0.3, h, rz=-s * 0.6)
        if not p.get('naked'): VG(0.8, 0.8, 0.8, 0xd8b04a, s * (hw / 2 + 3.2), hh * 0.05, -0.5, h)
        V(1.6, 1, 0.6, shade(p['skin'], 0.5), s * 2.1, hh * 0.02 + 1.2, hd / 2 + 0.5, h)
        A = b['arms'][0 if s == -1 else 1]
        if not p.get('naked'):
            V(o['aw'] + 3, 2, o['ad'] + 2.5, p['fur'], 0, 1.3, 0, A)
            V(o['aw'] + 2, 2, o['ad'] + 1.8, shade(p['fur'], 0.85), s * 0.4, -0.6, 0.2, A)
        if k != 'garde' and not p.get('naked'):
            V(o['aw'] + 1, 1.4, o['ad'] + 1, 0x6b6f78, 0, 2.6, 0, A)
            V(4.4, 1.2, 4.4, 0xb8bcc4, 0, 3.8, 0, A)
            V(3, 1.2, 3, 0xb8bcc4, 0, 5, 0, A)
            V(1.6, 1.6, 1.6, 0xb8bcc4, 0, 6.4, 0, A)
    V(1, 3.4, 0.5, 0xf0c8c0, 3.4, -hh * 0.1, hd / 2 + 0.2, h, rz=0.5)
    for i, x in enumerate((-3, -1.5, 0, 1.5, 3)):
        V(1, 1.4 + (i % 2) * 0.9, 1.4, 0x3a2a22, x, hh / 2 + 0.9, -1, h)
    T = b['T']; top = b['top']
    if not p.get('naked'): V(1.8, 15, T[2]['d'] + 0.9, p['belt'], 0, T[2]['cy'], 0, top, rz=0.55)
    if not p.get('naked'): V(1.8, 15, T[2]['d'] + 0.9, shade(p['belt'], 0.85), 1.3, T[2]['cy'], 0, top, rz=0.55)
    if not p.get('naked'): V(5, 6, 0.9, p['belt'], 0, -1.8, T[0]['d'] / 2 + 0.6, top)
    if not p.get('naked'): V(2.4, 2.4, 1, 0xe8e0c8, 0, T[1]['y0'] + 0.4, T[1]['d'] / 2 + 1.2, top)
    if not p.get('naked'): V(0.5, 0.5, 0.4, 0x3a2a22, -0.6, T[1]['y0'] + 0.7, T[1]['d'] / 2 + 1.75, top)
    if not p.get('naked'): V(0.5, 0.5, 0.4, 0x3a2a22, 0.6, T[1]['y0'] + 0.7, T[1]['d'] / 2 + 1.75, top)
    V(0.5, 3, 0.4, 0xf0c8c0, 4, T[2]['cy'] + 1, T[2]['d'] / 2 + 0.2, top, rz=0.5)
    for q in ((-3, 2), (0, 3), (3, 2)):
        V(1.2, 1.2 + q[1], 1.2, 0xe8e0c8, q[0], T[3]['y0'] + T[3]['h'] + q[1] / 2, -T[3]['d'] / 2, top)
    dress(b, k); b['g'].scale = 0.95; return b


# ---------------------------------------------------------------- races bonus
def lizard(k, p):
    S = p['skin']; dk = shade(S, 0.72)
    o = dict(legH=13, lw=4, ld=4.4, gap=2.6,
             tiers=[[2.2, 7.6, 4.6], [3, 6.8, 4.4], [4, 8.8, 5], [2.2, 9.6, 4.6]],
             neck=1.4, hw=5.8, hh=5.4, hd=6.4, jh=1.6, aw=3, al=13, ad=3.2, lean=0.12, hz=1.2,
             noNose=True, noMouth=True, eye=dict(w=1.5, h=1.3, tilt=0.35, glow=True, brow=shade(S, 0.6)))
    b = build(o, p, 'lizard'); h = b['head']; top = b['top']; T = b['T']
    hh = o['hh']; hw = o['hw']; hd = o['hd']
    V(hw * 0.52, 2.8, 4.4, shade(S, 0.97), 0, -hh * 0.16, hd / 2 + 2.0, h)
    V(hw * 0.44, 1.2, 3.8, shade(S, 0.88), 0, -hh * 0.16 - 1.9, hd / 2 + 1.6, h)
    V(hw * 0.3, 0.4, 3.4, 0x8a2a3a, 0, -hh * 0.16 - 1.2, hd / 2 + 1.7, h)
    for s in (-1, 1):
        V(0.7, 0.7, 0.5, 0x1a2a1a, s * 0.9, -hh * 0.16 + 0.6, hd / 2 + 4.3, h)
        V(0.5, 1, 0.5, 0xf0ead0, s * 1.3, -hh * 0.16 - 0.9, hd / 2 + 3.5, h)
        V(0.5, 0.9, 0.5, 0xf0ead0, s * 1.0, -hh * 0.16 - 1.1, hd / 2 + 2.6, h)
        V(0.35, 1.4, 0.3, 0x111111, s * hw * 0.27, hh * 0.02, hd / 2 + 0.55, h)
        V(1, 1.4, 1, dk, s * 2.4, hh / 2 + 0.6, 0.5, h)
        V(0.8, 1.4, 0.8, dk, s * 2.8, hh / 2 + 1.8, -0.2, h)
        for i in range(3):
            V(0.8, 2.6 + i * 0.4, 0.8, dk, s * (hw / 2 + 0.8 + i * 0.6), 1.6 + i * 1.4, -hd / 2 + 1.4 - i * 0.3, h, rz=-s * (0.4 + i * 0.25))
        for j in range(3):
            V(0.8, 0.8, 0.6, dk, (j - 1) * 0.9, -o['al'] * 0.55 - j * 1.4, o['ad'] * 0.45 + 0.2, b['arms'][0 if s == -1 else 1])
        for x in (-1.1, 0, 1.1):
            V(0.6, 1.5, 0.6, 0xf0ead0, x, -o['al'] - 0.5, 0.6, b['arms'][0 if s == -1 else 1])
            V(0.5, 0.5, 1.3, 0xf0ead0, s * o['gap'] + x, 0.4, o['ld'] / 2 + 2.6, b['g'])
    for i in range(4):
        V(0.9, 1.6 + (1.5 - abs(i - 1.5)) * 0.6, 1.2, dk, 0, hh / 2 + 0.6, 1.2 - i * 1.5, h)
    y = 1.8; z = -(T[0]['d'] / 2 + 1.6)
    for i in range(7):
        w = 4.6 - i * 0.55
        V(w, w * 0.92, 3.4, S if i % 2 else shade(S, 0.94), 0, y, z, top)
        V(0.9, 1.2, 1.4, dk, 0, y + w * 0.46 + 0.4, z, top)
        y -= 0.45; z -= 3.1
    for j in range(4):
        V(T[2]['w'] * 0.5, 0.7, 0.4, dk, 0, T[2]['y0'] + 0.8 + j * 1.6, -T[2]['d'] / 2 - 0.3, top)
    dress(b, k); return b

def lycan(k, p):
    S = p['skin']; dk = shade(S, 0.75); lt = shade(S, 1.25); claw = 0xe8e0c8
    o = dict(legH=14, lw=5.6, ld=5.8, gap=3.4,
             tiers=[[2.6, 9, 6], [3.4, 8, 5.6], [5.6, 13, 7.2], [3.2, 14.4, 6.6]],
             neck=1, hw=7, hh=6, hd=7.4, jh=2, aw=5, al=15.5, ad=5, lean=0.32, hz=3.2,
             noNose=True, noMouth=True, eye=dict(w=1.7, h=1.1, tilt=0.5, glow=True, brow=shade(S, 0.5)))
    b = build(o, p, 'lycan'); h = b['head']; top = b['top']; T = b['T']
    hh = o['hh']; hw = o['hw']; hd = o['hd']; tH = o['tH']
    V(hw * 0.48, 3, 4.8, shade(S, 1.08), 0, -hh * 0.16, hd / 2 + 2.4, h)
    V(1.8, 1.3, 1.3, 0x1a1a1a, 0, -hh * 0.16 + 0.9, hd / 2 + 5, h)
    V(hw * 0.4, 1.4, 4.2, dk, 0, -hh * 0.16 - 2, hd / 2 + 2.1, h)
    V(hw * 0.4, 0.4, 4, 0x3a1414, 0, -hh * 0.16 - 1.3, hd / 2 + 2.2, h)
    for s in (-1, 1):
        V(0.6, 1.6, 0.6, 0xffffff, s * 1.4, -hh * 0.16 - 1.0, hd / 2 + 4, h)
        V(0.5, 1.3, 0.5, 0xffffff, s * 1.1, -hh * 0.16 - 1.1, hd / 2 + 3.2, h)
        V(2.2, 2.4, 1.2, S, s * 3, hh / 2 + 1.2, -0.8, h)
        V(1.6, 1.8, 1, S, s * 3.2, hh / 2 + 3, -0.8, h)
        V(0.9, 1.2, 0.8, dk, s * 3.3, hh / 2 + 4.3, -0.8, h)
        V(1, 2, 0.4, 0x8a5a5a, s * 3, hh / 2 + 1.6, -0.2, h)
        V(1.6, 2.6, 2.6, S, s * (hw / 2 + 0.9), -1, -0.5, h)
        V(1, 2, 1, S, s * (hw / 2 + 1.6), -2.6, -0.5, h, rz=-s * 0.5)
        A = b['arms'][0 if s == -1 else 1]
        V(o['aw'] + 1.2, 3, o['ad'] + 1.2, dk, 0, -o['al'] * 0.72, 0, A)
        V(1, 2, 1, S, s * 1.6, -o['al'] * 0.6, 1.2, A, rz=-s * 0.3)
        V(o['aw'] + 1.8, 2, o['ad'] + 1.4, lt, 0, 1.2, 0, A)
        for x in (-1.6, 0, 1.6):
            V(0.8, 2.4, 0.8, claw, x, -o['al'] - 0.4, 0.6, A)
            V(0.7, 0.7, 1.6, claw, s * o['gap'] + x, 0.4, o['ld'] / 2 + 2.4, b['g'])
        L = b['legs'][0 if s == -1 else 1]
        V(o['lw'] + 0.8, 3.4, o['ld'] + 0.8, dk, 0, -o['legH'] * 0.55, 0, L)
    V(hw + 1.8, 2.4, hd + 0.6, dk, 0, -hh / 2 - 0.2, -1, h)
    V(hw + 3, 2.4, hd * 0.7, shade(S, 0.68), 0, -hh / 2 - 2.2, -2.4, h)
    V(T[3]['w'] + 1.6, 2.2, T[3]['d'] + 1.2, dk, 0, tH + 0.2, 0, top)
    for i in range(6):
        V(1.4, 1.8 + (i % 2) * 1.2, 1.4, S, -5 + i * 2, tH + 1.6, -T[3]['d'] / 2 + 0.4, top)
    for i in range(5):
        V(1.2, 2.4 - i * 0.2, 1.2, dk, 0, tH - 1.5 - i * 2.4, -T[2]['d'] / 2 - 1.2, top)
    V(T[2]['w'] * 0.5, 4.5, 0.6, lt, 0, T[2]['cy'] + 0.5, T[2]['d'] / 2 + 0.3, top)
    y = 2.4; z = -(T[0]['d'] / 2 + 2)
    for i, w in enumerate((4.2, 5, 5.4, 4.6, 3)):
        V(w, w, 3.6, shade(S, 1.5) if i == 4 else (S if i % 2 else dk), 0, y, z, top)
        y -= 1.4; z -= 3.1
    dress(b, k); return b

def vampire(k, p):
    S = p['skin']
    p['cape'] = False
    o = dict(legH=15, lw=3.6, ld=3.8, gap=2.3,
             tiers=[[2, 6.6, 4.2], [3, 6, 4], [4, 8.2, 4.6], [2.2, 9, 4.4]],
             neck=1.4, hw=6.2, hh=6.2, hd=6.4, jh=2.4, aw=2.8, al=13.5, ad=3,
             eye=dict(w=1.6, h=0.8, tilt=0.4, glow=True))
    b = build(o, p, 'vampire'); h = b['head']; top = b['top']; T = b['T']
    hh = o['hh']; hw = o['hw']; hd = o['hd']; tH = o['tH']
    hair(b, 1, p['hair'], True)
    V(1.4, 1.2, 0.9, p['hair'], 0, hh / 2 - 0.4, hd / 2 + 0.7, h)
    ex = hw * 0.27
    for s in (-1, 1):
        V(0.6, 1.7, 0.5, 0xffffff, s * 1.3, -hh * 0.36 - 0.7, hd / 2 + 0.3, h)
        V(1.8, 0.5, 0.4, shade(S, 0.7), s * ex, hh * 0.02 - 1.1, hd / 2 + 0.3, h)
        V(0.9, 1.6, 0.8, S, s * (hw / 2 + 0.5), 0.6, -0.4, h)
        V(0.8, 1.4, 0.7, S, s * (hw / 2 + 1.3), 1.8, -0.5, h)
        if not p.get('naked'):
            V(3, 7, 0.9, p['trim'], s * 3.6, tH + 2.6, -(T[3]['d'] / 2 + 0.5), top, rz=-s * 0.25)
            V(1, 7, T[3]['d'] + 1.4, p['trim'], s * (T[3]['w'] / 2 + 0.8), tH - 3, -0.2, top)
    if not p.get('naked'):
        cw = T[2]['w']; dk = shade(p['trim'], 0.55)
        V(cw + 0.8, tH * 1.6, 0.9, p['trim'], 0, tH * 0.2, -(T[2]['d'] / 2 + 0.9), top, rx=0.06)
        V(cw * 0.85, tH * 1.5, 0.5, 0x8a1a2a, 0, tH * 0.2, -(T[2]['d'] / 2 + 0.35), top, rx=0.06)
        for i in range(5):
            V(cw / 5 + 0.2, 2.6 + (i % 2) * 2.4, 0.9, dk, -cw * 0.4 + i * cw / 5 + 0.3, tH * 0.2 - tH * 0.8 - 1 - (i % 2) * 1.2, -(T[2]['d'] / 2 + 1.0), top)
        VG(1.2, 1.2, 0.6, p['eye'], 0, tH - 2.4, T[3]['d'] / 2 + 1, top)
        V(2, 0.8, 0.6, 0xd8b04a, 0, tH - 2.4, T[3]['d'] / 2 + 0.7, top)
    dress(b, k); return b

def demon(k, p):
    S = p['skin']; bone = shade(S, 0.55); mem = shade(S, 0.8)
    horn = (0xd8cbb0, 0x2a2226, 0xb08a3a)[p['hs']]
    o = dict(legH=14, lw=5.2, ld=5.6, gap=3.2,
             tiers=[[2.6, 9.4, 6], [3.2, 8.2, 5.6], [5.4, 13.2, 7], [3, 15, 6.6]],
             neck=1.2, hw=7.4, hh=6.4, hd=7.4, jh=2.4, aw=5, al=14, ad=5, lean=0.06,
             noMouth=True, eye=dict(w=1.8, h=1, tilt=0.55, glow=True, brow=shade(S, 0.45)))
    b = build(o, p, 'demon'); h = b['head']; top = b['top']; T = b['T']
    hh = o['hh']; hw = o['hw']; hd = o['hd']; tH = o['tH']
    VG(hw * 0.42, 0.5, 0.4, 0xff9a30, 0, -hh * 0.36, hd / 2 + 0.2, h)
    for s in (-1, 1):
        V(0.6, 1.4, 0.5, 0xffffff, s * 1.4, -hh * 0.36 - 0.6, hd / 2 + 0.3, h)
        V(2.2, 2.6, 2.2, horn, s * 3.4, hh / 2 + 0.9, 0.4, h)
        V(1.8, 2.6, 1.8, shade(horn, 0.95), s * 4.4, hh / 2 + 3.2, -0.3, h, rz=-s * 0.3)
        V(1.4, 2.6, 1.4, shade(horn, 0.9), s * 5.6, hh / 2 + 5.3, -1.4, h, rz=-s * 0.55)
        V(0.9, 2, 0.9, shade(horn, 1.15), s * 6.7, hh / 2 + 7, -2.6, h, rz=-s * 0.8)
        V(0.8, 2, 0.8, horn, s * (hw / 2 + 0.6), -1.2, 0.5, h, rz=-s * 0.9)
        A = b['arms'][0 if s == -1 else 1]
        for j in (-1, 1):
            VG(0.5, 5, 0.4, 0xff8a20, j * 0.9, -o['al'] * 0.62, o['ad'] * 0.45 + 0.3, A)
        V(o['aw'] + 1.6, 1.6, o['ad'] + 1.6, bone, 0, 1.2, 0, A)
        V(1.2, 2.4, 1.2, horn, s * 1.5, 3, 0, A)
        for x in (-1.4, 0, 1.4):
            V(0.7, 2, 0.7, shade(horn, 1.1), x, -o['al'] - 0.4, 0.6, A)
        x0 = s * (T[3]['w'] / 2 - 1); y0 = tH - 1.5; z0 = -(T[3]['d'] / 2 + 1.5)
        angs = (0.45, 0.95, 1.4); lens = (12, 11, 8.5)
        for a, Lb in zip(angs, lens):
            V(1.3, Lb, 1.2, bone, x0 + s * math.sin(a) * Lb / 2, y0 + math.cos(a) * Lb / 2, z0, top, rz=-s * a)
        for i in range(2):
            a = (angs[i] + angs[i + 1]) / 2; Lm = (lens[i] + lens[i + 1]) / 2
            V(Lm * (angs[i + 1] - angs[i]) * 0.9, Lm * 0.75, 0.5, mem,
              x0 + s * math.sin(a) * Lm * 0.45, y0 + math.cos(a) * Lm * 0.45, z0 - 0.2, top, rz=-s * a)
    y = 1.6; z = -(T[0]['d'] / 2 + 1.6)
    for i in range(6):
        w = 3.6 - i * 0.3
        V(w, w, 3.2, S if i % 2 else shade(S, 0.9), 0, y, z, top)
        y += -0.8 if i < 2 else 1.1; z -= 3.0
    V(3.4, 3.4, 0.8, shade(S, 0.7), 0, y + 0.2, z + 0.4, top, rz=0.785)
    V(1.6, 1.6, 0.9, bone, 0, y + 0.2, z + 0.4, top, rz=0.785)
    dress(b, k); return b


# ---------------------------------------------------------------- races bonus 2
def bat_wings(b, bone, mem, sc=1.0):
    top = b['top']; T = b['T']; tH = b['o']['tH']
    for s in (-1, 1):
        x0 = s * (T[3]['w'] / 2 - 1); y0 = tH - 1.5; z0 = -(T[3]['d'] / 2 + 1.5)
        angs = (0.45, 0.95, 1.4); lens = (12 * sc, 11 * sc, 8.5 * sc)
        for a, Lb in zip(angs, lens):
            V(1.3, Lb, 1.2, bone, x0 + s * math.sin(a) * Lb / 2, y0 + math.cos(a) * Lb / 2, z0, top, rz=-s * a)
        for i in range(2):
            a = (angs[i] + angs[i + 1]) / 2; Lm = (lens[i] + lens[i + 1]) / 2
            V(Lm * (angs[i + 1] - angs[i]) * 0.9, Lm * 0.75, 0.5, mem,
              x0 + s * math.sin(a) * Lm * 0.45, y0 + math.cos(a) * Lm * 0.45, z0 - 0.2, top, rz=-s * a)

def dragonoid(k, p):
    S = p['skin']; dk = shade(S, 0.7); lt = shade(S, 1.25)
    horn = (0xd8cbb0, 0x2a2226, 0xb08a3a)[p['hs']]
    o = dict(legH=13.5, lw=5.6, ld=6, gap=3.4,
             tiers=[[2.6, 9.6, 6.2], [3.4, 8.8, 5.8], [5.6, 13.6, 7.4], [3.2, 15.4, 7]],
             neck=1.6, hw=7.2, hh=6.2, hd=7.6, jh=1.8, aw=5, al=14, ad=5.2, lean=0.08, hz=1.4,
             noNose=True, noMouth=True, eye=dict(w=1.6, h=1.1, tilt=0.5, glow=True, brow=shade(S, 0.5)))
    b = build(o, p, 'dragonoid'); h = b['head']; top = b['top']; T = b['T']
    hh = o['hh']; hw = o['hw']; hd = o['hd']; tH = o['tH']
    V(hw * 0.6, 3.6, 5.2, S, 0, -hh * 0.14, hd / 2 + 2.4, h)
    V(hw * 0.3, 0.8, 4.6, dk, 0, -hh * 0.14 + 2, hd / 2 + 2.2, h)
    V(hw * 0.5, 1.4, 4.6, shade(S, 0.85), 0, -hh * 0.14 - 2.3, hd / 2 + 2, h)
    VG(hw * 0.3, 0.5, 3.6, 0xff8a20, 0, -hh * 0.14 - 1.5, hd / 2 + 2.2, h)
    for s in (-1, 1):
        V(0.8, 0.8, 0.5, 0x1a1a1a, s * 1.1, -hh * 0.14 + 0.7, hd / 2 + 5.1, h)
        for i in range(3):
            V(0.5, 1, 0.5, 0xf0ead0, s * 1.5, -hh * 0.14 - 1.1, hd / 2 + 1.4 + i * 1.3, h)
        V(0.35, 1.5, 0.3, 0x111111, s * hw * 0.27, hh * 0.02, hd / 2 + 0.55, h)
        for i, (x, y, z) in enumerate(((2.6, 0.6, -0.6), (3.2, 1.8, -2.4), (3.8, 2.6, -4.2), (4.2, 3.2, -6.0))):
            V(1.9 - i * 0.2, 2.4, 1.9 - i * 0.2, horn if i < 3 else shade(horn, 1.15), s * x, hh / 2 + y, z, h, rx=-0.55, rz=-s * 0.15 * i)
        for i in range(3):
            V(0.9, 2.6 + i * 0.5, 0.9, dk, s * (hw / 2 + 0.9 + i * 0.5), 0.6 + i * 1.3, -hd / 2 + 1.6 - i * 0.4, h, rz=-s * (0.5 + i * 0.3))
        A = b['arms'][0 if s == -1 else 1]
        V(o['aw'] + 1.4, 1.8, o['ad'] + 1.4, dk, 0, 1.2, 0, A)
        for j in range(3):
            V(0.9, 0.9, 0.6, lt, (j - 1) * 1.1, -o['al'] * 0.56 - j * 1.4, o['ad'] * 0.45 + 0.2, A)
        for x in (-1.4, 0, 1.4):
            V(0.7, 1.8, 0.7, 0xe8e0c8, x, -o['al'] - 0.4, 0.6, A)
            V(0.6, 0.6, 1.4, 0xe8e0c8, s * o['gap'] + x, 0.4, o['ld'] / 2 + 2.4, b['g'])
    for i in range(7):
        V(1.3, 2.4 - i * 0.2, 1.3, dk, 0, tH - 0.6 - i * 2.2 + (1.4 if i == 0 else 0), -T[2]['d'] / 2 - 1.2, top)
    for j in range(4):
        V(T[2]['w'] * 0.55, 0.8, 0.5, lt, 0, T[2]['y0'] + 0.9 + j * 1.5, T[2]['d'] / 2 + 0.2, top)
    bat_wings(b, shade(S, 0.55), shade(S, 0.9), 0.75)
    y = 1.8; z = -(T[0]['d'] / 2 + 1.8)
    for i in range(8):
        w = 6 - i * 0.55
        V(w, w * 0.9, 3.4, S if i % 2 else shade(S, 0.92), 0, y, z, top)
        V(1, 1.6 + (i % 2) * 0.6, 1.4, horn, 0, y + w * 0.45 + 0.6, z, top)
        y -= 0.3 if i < 4 else 0.0; z -= 3.2
    V(2.4, 2.4, 3.6, horn, 0, y + 0.2, z + 0.4, top, rz=0.785)
    dress(b, k); return b

def fairy(k, p):
    S = p['skin']
    o = dict(legH=13, lw=3.2, ld=3.4, gap=2,
             tiers=[[2, 6, 3.8], [2.8, 5.4, 3.6], [3.8, 7, 4.2], [2, 7.6, 4]],
             neck=1.2, hw=6.4, hh=6.2, hd=6.4, jh=2.2, aw=2.4, al=12, ad=2.6,
             eye=dict(w=2, h=1.6, tilt=0.15, glow=True))
    b = build(o, p, 'fairy'); h = b['head']; top = b['top']; T = b['T']
    hh = o['hh']; hw = o['hw']; hd = o['hd']; tH = o['tH']
    hair(b, p['hs'], p['hair'], True)
    wing = shade(p['hair'], 1.1); vein = shade(p['orb'], 1.0)
    for s in (-1, 1):
        V(1, 1.8, 0.8, S, s * (hw / 2 + 0.5), 1, -0.5, h, rz=-s * 0.3)
        V(0.9, 1.6, 0.7, S, s * (hw / 2 + 1.4), 2.6, -0.6, h, rz=-s * 0.5)
        V(0.8, 1.4, 0.6, S, s * (hw / 2 + 2.2), 4.1, -0.7, h, rz=-s * 0.7)
        V(0.5, 4, 0.5, shade(S, 0.8), s * 1.6, hh / 2 + 2.2, 0.5, h, rz=-s * 0.3)
        VG(1, 1, 1, p['orb'], s * 2.4, hh / 2 + 4.4, 0.5, h)
        x0 = s * 3; z0 = -(T[3]['d'] / 2 + 1.6)
        VA(5, 12, 0.3, wing, x0 + s * math.sin(0.55) * 6, tH + math.cos(0.55) * 6, z0, top, 0.55, rz=-s * 0.55)
        VG(0.4, 11, 0.35, vein, x0 + s * math.sin(0.55) * 6, tH + math.cos(0.55) * 6, z0 - 0.1, top, rz=-s * 0.55)
        VA(4, 8, 0.3, shade(wing, 0.9), x0 + s * math.sin(0.5) * 4.2, tH - 1 - math.cos(0.5) * 4.2, z0 - 0.2, top, 0.55, rz=s * 0.5)
        VG(0.4, 7, 0.35, vein, x0 + s * math.sin(0.5) * 4.2, tH - 1 - math.cos(0.5) * 4.2, z0 - 0.3, top, rz=s * 0.5)
    fl = (0xff7ab0, 0xffd84a, 0xffffff, 0xb08af0, 0xff9a4a, 0x7ad0ff)
    for i in range(6):
        a = i / 6.0 * 2 * math.pi
        V(1.3, 1.3, 1.3, fl[i], math.cos(a) * hw * 0.58, hh / 2 + 0.7, math.sin(a) * hd * 0.58, h)
    for i in range(9):
        a = hs(i, 1, 5) * 6.28; r = 7 + hs(i, 2, 5) * 6
        VG(0.6, 0.6, 0.6, (0xfff4b0, 0xb0f0ff, 0xffc8f0)[i % 3], math.cos(a) * r, 4 + hs(i, 3, 5) * 26, math.sin(a) * r, top, rx=0.6, rz=0.6)
    dress(b, k); b['g'].scale = 0.62; return b

GEL_F = [round(0.6 + 0.02 * i, 2) for i in range(41)]
def set_gel(node, S, alpha=0.62):
    gel = set(shade(S, f) for f in GEL_F)
    def rec(n):
        for bx in n.boxes:
            if bx['c'] in gel and not bx['glow']: bx['alpha'] = alpha
        for kd in n.kids: rec(kd)
    rec(node)

def slime(k, p):
    S = p['skin']
    p['cloth'] = S; p['pants'] = S
    o = dict(legH=12, lw=5, ld=5.4, gap=3,
             tiers=[[2.6, 9.6, 6], [3.2, 9, 5.8], [5, 12.6, 7], [3, 13.6, 6.6]],
             neck=1, hw=8, hh=7, hd=7.6, jh=2, aw=4.6, al=12, ad=4.8, lean=0.05,
             noNose=True, noMouth=True, eye=dict(w=1.8, h=2.4, tilt=0.0, white=False, brow=shade(S, 0.7)))
    b = build(o, p, 'slime'); h = b['head']; top = b['top']; T = b['T']; g = b['g']
    hh = o['hh']; hw = o['hw']; hd = o['hd']; tH = o['tH']
    V(3.4, 0.6, 0.4, 0x1a1a1a, 0, -hh * 0.3, hd / 2 + 0.2, h)
    for s in (-1, 1): V(0.6, 0.7, 0.4, 0x1a1a1a, s * 1.9, -hh * 0.3 + 0.5, hd / 2 + 0.2, h)
    VG(3.4, 3.4, 3.4, p['orb'], 0, T[2]['cy'], 0, top, rx=0.6, rz=0.6)
    VG(1.6, 1.6, 1.6, 0xffffff, 0, T[2]['cy'], 0, top, rx=0.6, rz=0.6)
    lt = shade(S, 1.5)
    for (x, y, z) in ((2.6, 3.4, 1.2), (-2.8, 6, 0.6), (1.6, 8.6, -1.2), (-1.4, 1.4, 1.6)):
        VA(0.9, 0.9, 0.9, lt, x, y, z, top, 0.8)
    VA(1, 1, 1, lt, 2, -0.6, 1.5, h, 0.8); VA(0.8, 0.8, 0.8, lt, -2.6, 1.4, 1, h, 0.8)
    for a in b['arms']:
        VA(1, 1, 1, lt, 0.6, -o['al'] * 0.45, 0.6, a, 0.8)
        VA(1.4, 3.4, 1.4, S, 0.4, -o['al'] - 1.4, 0.4, a, 0.62)
    for l in b['legs']: VA(1, 1, 1, lt, 0.4, -o['legH'] * 0.3, 0.6, l, 0.8)
    VA(3.2, 2.4, 3, S, 0, hh / 2 + 1.0, 0.4, h, 0.62)
    VA(2, 1.6, 2, shade(S, 1.1), 0.3, hh / 2 + 2.6, 0.4, h, 0.62)
    VA(1.4, 3.4, 1.4, S, 1.8, -hh / 2 - 1.5, hd / 2 - 1, h, 0.62)
    VA(15, 1.2, 13, S, 0, 0.6, 0, g, 0.62)
    for (x, z, w) in ((-8.5, 3, 3.2), (8, -2, 3.6), (-6, -6, 3), (5, 6.4, 2.6)):
        VA(w, 1, w, S, x, 0.5, z, g, 0.62)
    dress(b, k)
    set_gel(g, S)
    return b

def dwarf(k, p):
    S = p['skin']; c = p['hair']
    o = dict(legH=8, lw=5.4, ld=5.4, gap=3.2,
             tiers=[[2.4, 10, 6.4], [3.4, 9.6, 6], [5.6, 14, 7.4], [3.2, 15.6, 7]],
             neck=0.8, hw=7.6, hh=6.2, hd=7.6, jh=2.6, aw=5.6, al=11, ad=5.6,
             noNose=True, noMouth=True, eye=dict(w=1.3, h=1, tilt=0.3, white=True))
    b = build(o, p, 'dwarf'); h = b['head']
    hh = o['hh']; hw = o['hw']; hd = o['hd']
    hair(b, p['hs'] if p['hs'] < 2 else 0, c, False)
    ex = hw * 0.27; ey = hh * 0.02
    V(2.6, 2.8, 2.4, shade(S, 1.04), 0, -hh * 0.1, hd / 2 + 1.3, h)
    V(1.6, 1, 1.6, shade(S, 0.95), 0, -hh * 0.2, hd / 2 + 2.4, h)
    # barbe : longue et tressée (par défaut), ou courte (héros nain sans l'option « Barbe »)
    short = p.get('short_beard', False)
    V(hw * 0.95, 2.6, 2.2, c, 0, -hh / 2 - 0.2, hd / 2 + 0.3, h)
    if short:
        V(hw * 0.7, 1.8, 1.8, shade(c, 0.93), 0, -hh / 2 - 2.2, hd / 2 + 0.3, h)
    else:
        V(hw * 0.9, 3.2, 2, shade(c, 0.95), 0, -hh / 2 - 2.6, hd / 2 + 0.4, h)
        V(hw * 0.75, 3.2, 1.8, shade(c, 0.9), 0, -hh / 2 - 5.4, hd / 2 + 0.5, h)
        V(hw * 0.55, 3, 1.6, shade(c, 0.86), 0, -hh / 2 - 8, hd / 2 + 0.6, h)
    for s in (-1, 1):
        if not short:
            V(1.4, 3.6, 1.4, shade(c, 0.9), s * 2.8, -hh / 2 - 5.2, hd / 2 + 1.6, h)
            V(1.9, 0.6, 1.9, 0xd8b04a, s * 2.8, -hh / 2 - 6.6, hd / 2 + 1.6, h)
        V(2.6, 1, 1.4, c, s * 2.2, -hh * 0.22, hd / 2 + 0.9, h, rz=s * 0.25)
        V(3, 1.1, 1.2, c, s * ex, ey + 1.6, hd / 2 + 0.5, h, rz=s * 0.2)
        V(2, 1.4, 0.4, 0xe89a90, s * hw * 0.36, -hh * 0.18, hd / 2 + 0.55, h)
        V(1, 2.2, 1.5, S, s * (hw / 2 + 0.5), -0.2, -0.2, h)
        if not p.get('naked'): V(1.6, 1.6, 1.6, 0x8a8f99, s * (o['tiers'][3][1] / 2 + 1.2), o['tH'] + 0.4, 0, b['top'])
    dress(b, k); return b


# ---------------------------------------------------------------- races bonus 3 (univers "Tensei Slime")
def feather_wings(b, c1, c2, sc=1.0, n=7, a0=0.25, a1=2.2):
    top = b['top']; T = b['T']; tH = b['o']['tH']
    for s in (-1, 1):
        x0 = s * (T[3]['w'] / 2 - 1); y0 = tH - 2; z0 = -(T[3]['d'] / 2 + 1.6)
        for i in range(n):
            a = a0 + i * (a1 - a0) / (n - 1)
            L = (14 - i * 0.9) * sc
            V(2.0 * sc, L, 0.6, c1 if i % 2 == 0 else c2, x0 + s * math.sin(a) * L / 2, y0 + math.cos(a) * L / 2, z0 - (i % 2) * 0.3, top, rz=-s * a)
        for i in range(5):
            a = a0 + i * 0.36; L = 6 * sc
            V(2.3 * sc, L, 0.7, shade(c1, 1.08), x0 + s * math.sin(a) * L / 2, y0 + math.cos(a) * L / 2, z0 + 0.3, top, rz=-s * a)

def hobgoblin(k, p):
    S = p['skin']; dk = shade(S, 0.78); nk = p.get('naked')
    o = dict(legH=14, lw=4.4, ld=4.8, gap=2.8,
             tiers=[[2.4, 8.6, 5.4], [3.2, 7.8, 5], [5, 11.8, 6.2], [2.8, 13, 5.8]],
             neck=1.4, hw=6.8, hh=6.2, hd=7, jh=2.2, aw=4.4, al=13.5, ad=4.4,
             eye=dict(w=1.5, h=1, tilt=0.4, white=True))
    b = build(o, p, 'hobgoblin'); h = b['head']; T = b['T']; top = b['top']
    hh = o['hh']; hw = o['hw']; hd = o['hd']
    hair(b, 0 if p['hs'] == 1 else 2, p['hair'], False)
    for s in (-1, 1):
        V(1, 1.6, 0.8, S, s * (hw / 2 + 0.5), 0.6, -0.4, h, rz=-s * 0.3)
        V(0.9, 1.4, 0.7, S, s * (hw / 2 + 1.3), 1.9, -0.5, h, rz=-s * 0.5)
        V(0.8, 1.2, 0.6, dk, s * (hw / 2 + 2.1), 3.1, -0.6, h, rz=-s * 0.7)
        V(0.6, 1.5, 0.6, 0xf0ead0, s * 1.6, -hh * 0.4, hd / 2 + 0.2, h)
        V(2, 0.5, 0.4, 0x9a2a2a, s * hw * 0.27, hh * 0.02 - 1.2, hd / 2 + 0.35, h)
    V(0.5, 3, 0.4, dk, 2.2, hh * 0.1, hd / 2 + 0.5, h, rz=0.5)
    if nk:
        for j in range(3): V(T[2]['w'] * 0.5, 0.7, 0.4, shade(S, 1.12), 0, T[2]['y0'] + 1 + j * 1.5, T[2]['d'] / 2 + 0.2, top)
        for s in (-1, 1): V(T[2]['w'] * 0.32, 1.8, 0.5, shade(S, 1.1), s * T[2]['w'] * 0.22, T[2]['y0'] + 4.4, T[2]['d'] / 2 + 0.2, top)
    dress(b, k); return b

def ogre(k, p):
    S = p['skin']; dk = shade(S, 0.72); horn = (0xd8cbb0, 0x2a2226, 0xb08a3a)[p['hs']]
    o = dict(legH=13, lw=6.4, ld=6.8, gap=3.8,
             tiers=[[3, 11.6, 7.6], [4, 12, 8], [5.4, 15.4, 8.4], [3, 17, 7.6]],
             neck=0.8, hw=8.6, hh=7, hd=8.4, jh=3, aw=6.6, al=14.5, ad=6.6, lean=0.14, hz=1.6,
             noNose=True, noMouth=True, eye=dict(w=1.4, h=1, tilt=0.55, glow=True, brow=shade(S, 0.5)))
    b = build(o, p, 'ogre'); h = b['head']
    hh = o['hh']; hw = o['hw']; hd = o['hd']
    V(3.4, 3, 2.6, shade(S, 1.05), 0, -hh * 0.12, hd / 2 + 1.6, h)
    V(hw * 0.62, 0.7, 0.6, 0x2a0a0a, 0, -hh * 0.38, hd / 2 + 0.2, h)
    V(hw * 0.7, 1.6, 2.6, shade(S, 0.9), 0, -hh / 2 - 1.6, hd / 2 - 0.2, h)
    for s in (-1, 1):
        V(1.2, 3.2, 1.2, 0xf0ead0, s * 3.2, -hh * 0.42 + 1, hd / 2 + 0.7, h)
        V(0.8, 1.4, 0.8, 0xf0ead0, s * 3.3, -hh * 0.42 + 3.2, hd / 2 + 0.7, h)
        V(1.4, 2.4, 1.2, S, s * (hw / 2 + 0.7), 0.4, -0.6, h, rz=-s * 0.3)
        V(0.7, 0.7, 0.7, dk, s * 2.4, hh * 0.18, hd / 2 + 0.5, h)
        A = b['arms'][0 if s == -1 else 1]
        for x in (-1.6, 0, 1.6): V(0.9, 1.3, 0.9, dk, x, -o['al'] + 0.6, o['ad'] / 2 + 0.6, A)
    xs = {0: (0,), 1: (-2.6, 2.6), 2: (-3.4, 0, 3.4)}[p['hs']]
    for x in xs:
        V(2.4, 2.4, 2.4, horn, x, hh / 2 + 0.9, 1.6, h)
        V(1.8, 2.6, 1.8, shade(horn, 0.95), x, hh / 2 + 3, 1.4, h)
        V(1.2, 2.2, 1.2, shade(horn, 1.15), x, hh / 2 + 5, 1.2, h)
    for i in range(5): V(1.2, 1.6 + (i % 2), 1.2, 0x2a1e18, (i - 2) * 2, hh / 2 + 0.6, -1, h)
    dress(b, k); return b

def kijin(k, p):
    S = p['skin']; horn = (0xd8cbb0, 0x2a2226, 0xb08a3a)[p['hs']]
    o = dict(legH=14.5, lw=3.8, ld=4, gap=2.4,
             tiers=[[2.2, 7, 4.4], [3, 6.4, 4.2], [4.4, 8.8, 4.8], [2.4, 9.8, 4.6]],
             neck=1.4, hw=6.4, hh=6.3, hd=6.6, jh=2.3, aw=3.2, al=13.2, ad=3.4,
             eye=dict(w=1.5, h=0.8, tilt=0.35, glow=True))
    b = build(o, p, 'kijin'); h = b['head']
    hh = o['hh']; hw = o['hw']; hd = o['hd']
    hair(b, (1, 1, 0)[p['hs']], p['hair'], True)
    if p['hs'] == 1:
        V(1.6, 2, 1.6, horn, 0, hh / 2 + 0.8, 1.4, h); V(1.2, 2.4, 1.2, shade(horn, 1.1), 0, hh / 2 + 2.6, 1.2, h)
    else:
        for s in (-1, 1):
            V(1.4, 2.4, 1.4, horn, s * 2.2, hh / 2 + 0.8, 1.2, h, rx=-0.3)
            V(1.1, 2.4, 1.1, shade(horn, 1.1), s * 2.6, hh / 2 + 2.8, 0.6, h, rx=-0.5, rz=-s * 0.15)
    V(0.8, 0.8, 0.3, 0xc02a2a, 0, hh * 0.3, hd / 2 + 0.5, h)
    for s in (-1, 1):
        V(0.5, 3, 0.3, 0xc02a2a, s * hw * 0.3, -hh * 0.14, hd / 2 + 0.55, h)
        V(0.9, 1.6, 0.7, S, s * (hw / 2 + 0.5), 0.5, -0.4, h, rz=-s * 0.3)
        V(0.5, 1.1, 0.4, 0xffffff, s * 1.2, -hh * 0.36 - 0.4, hd / 2 + 0.3, h)
    dress(b, k); return b

def beastfolk(k, p):
    S = p['skin']; kind = p['hs']; dk = shade(S, 0.72); lt = shade(S, 1.3)
    o = dict(legH=14, lw=3.8, ld=4.2, gap=2.4,
             tiers=[[2.2, 7, 4.4], [3, 6.4, 4.2], [4.4, 8.8, 4.8], [2.4, 9.6, 4.6]],
             neck=1.2, hw=6.4, hh=6.2, hd=6.6, jh=2.2, aw=3.2, al=13, ad=3.4, noNose=True,
             eye=dict(w=1.6, h=1, tilt=0.25, glow=True))
    b = build(o, p, 'beastfolk'); h = b['head']; top = b['top']; T = b['T']
    hh = o['hh']; hw = o['hw']; hd = o['hd']
    hair(b, (1, 0, 1)[kind], p['hair'], False)
    V(2.6, 1.8, 1.6, lt, 0, -hh * 0.16, hd / 2 + 0.9, h)
    V(1.2, 0.9, 0.8, 0x2a1a1a, 0, -hh * 0.1 + 0.1, hd / 2 + 1.7, h)
    for s in (-1, 1):
        for j in range(3): V(3, 0.25, 0.25, 0xf0f0f0, s * 3.4, -hh * 0.14 + (j - 1) * 0.7, hd / 2 + 0.8, h, rz=s * (j - 1) * 0.2)
        if kind == 0:
            V(2.2, 2.2, 1, S, s * 2.8, hh / 2 + 1, -0.4, h, rz=-s * 0.2)
            V(1.4, 1.6, 0.9, dk, s * 3.1, hh / 2 + 2.8, -0.4, h, rz=-s * 0.2)
            V(1, 1.6, 0.4, 0xe89aa0, s * 2.8, hh / 2 + 0.9, 0.05, h)
        elif kind == 1:
            V(2, 2.6, 1, S, s * 2.6, hh / 2 + 1.3, -0.4, h)
            V(1.4, 2.2, 0.9, dk, s * 2.8, hh / 2 + 3.4, -0.4, h)
            V(1.4, 2, 1.6, lt, s * (hw / 2 + 0.7), -1.4, 0.4, h)
        else:
            V(2.4, 3, 1, S, s * 2.8, hh / 2 + 1.5, -0.4, h)
            V(1.6, 2.6, 1, 0x2a2226, s * 3, hh / 2 + 4, -0.4, h)
            V(1.4, 2, 1.6, lt, s * (hw / 2 + 0.7), -1.4, 0.4, h)
        A = b['arms'][0 if s == -1 else 1]
        V(o['aw'] + 0.8, 3.4, o['ad'] + 0.8, lt, 0, -o['al'] * 0.6, 0, A)
        for x in (-0.9, 0.9): V(0.5, 1, 0.5, 0xf0ead0, x, -o['al'] - 0.2, 0.6, A)
        V(o['lw'] + 0.6, 3, o['ld'] + 0.6, lt, 0, -o['legH'] * 0.55, 0, b['legs'][0 if s == -1 else 1])
    z = -(T[0]['d'] / 2 + 1.5)
    if kind == 0:
        for i in range(7): V(1.8, 1.8, 3, S if i % 2 else dk, 0, 1.4 + i * i * 0.16, z - i * 2.6, top)
    elif kind == 1:
        for i, w in enumerate((3, 3.8, 3.4, 2.6)): V(w, w, 3.2, S if i % 2 == 0 else dk, 0, 1.2 - i * 0.9, z - i * 3, top)
    else:
        for i, w in enumerate((2.6, 3.8, 4.8, 5, 3.6)): V(w, w, 3.2, lt if i == 4 else S, 0, 1.6 - i * 0.6, z - i * 3, top)
    dress(b, k); return b

def harpy(k, p):
    S = p['skin']; f1 = p['hair']; f2 = shade(f1, 0.75); f3 = shade(f1, 1.25)
    o = dict(legH=14, lw=3, ld=3.4, gap=2.2, bare=True,
             tiers=[[2, 6.4, 4], [3, 5.8, 3.8], [4.2, 8, 4.4], [2.2, 8.8, 4.2]],
             neck=1.3, hw=6.2, hh=6, hd=6.4, jh=2.2, aw=2.8, al=12.5, ad=3, noNose=True,
             eye=dict(w=1.7, h=1.1, tilt=0.3, glow=True))
    b = build(o, p, 'harpy'); h = b['head']; top = b['top']; T = b['T']; g = b['g']
    hh = o['hh']; hw = o['hw']; hd = o['hd']
    for i in range(6):
        V(1.4, 2.4 + (i % 2) * 1.4, 1.2, (f1, f2, f3)[i % 3], 0, hh / 2 + 1 + (3 - abs(i - 2.5)) * 0.3, hd / 2 - 0.5 - i * 1.5, h)
    V(hw + 0.8, hh * 0.8, 1.4, f2, 0, -hh * 0.05, -(hd / 2 + 0.5), h)
    V(1.6, 1.6, 2, 0xe8c060, 0, -hh * 0.14, hd / 2 + 1.4, h)
    V(1.2, 0.7, 1.6, 0xd8a840, 0, -hh * 0.14 - 0.9, hd / 2 + 1.1, h)
    feather_wings(b, f1, f2, 1.0, 7, 0.3, 2.3)
    for s in (-1, 1):
        A = b['arms'][0 if s == -1 else 1]
        for i in range(4): V(0.8, 4, 0.5, (f1, f2)[i % 2], s * (o['aw'] / 2 + 0.5), -o['al'] * 0.35 - i * 1.6, -0.5, A)
        V(o['lw'] + 0.8, 2.4, o['ld'] + 0.8, f1, 0, -o['legH'] * 0.62, 0, b['legs'][0 if s == -1 else 1])
        for x in (-1, 0, 1): V(0.6, 0.6, 3, 0xd8c8a0, s * o['gap'] + x, 0.4, o['ld'] / 2 + 2.6, g)
        V(0.6, 0.6, 2, 0xd8c8a0, s * o['gap'], 0.4, -o['ld'] / 2 - 1.6, g)
    for i in range(5):
        a = (i - 2) * 0.28
        V(1.6, 9, 0.5, (f1, f3)[i % 2], math.sin(a) * 5, 1 - 2.8, -(T[0]['d'] / 2 + 1.4) - 3.6, top, rx=-2.3, rz=a)
    dress(b, k); return b

def spirit(k, p):
    S = p['skin']; el = p['el'] if 'el' in p else SK['spirit'].index(S)
    p['cloth'] = S; p['pants'] = S
    o = dict(legH=13, lw=3.8, ld=4, gap=2.4,
             tiers=[[2.4, 7.4, 4.6], [3, 6.8, 4.4], [4.4, 9.2, 5], [2.4, 10, 4.8]],
             neck=1.2, hw=6.6, hh=6.4, hd=6.8, jh=2.2, aw=3.4, al=13, ad=3.6,
             noNose=True, noMouth=True, eye=dict(w=1.8, h=1.3, tilt=0.1, glow=True))
    b = build(o, p, 'spirit'); h = b['head']; top = b['top']; T = b['T']; g = b['g']
    hh = o['hh']; hw = o['hw']; hd = o['hd']; tH = o['tH']
    core = (0xffe060, 0xd0f0ff, 0xffffff, 0x60ff90, 0xffffff)[el]
    VG(3.2, 3.2, 3.2, core, 0, T[2]['cy'], 0, top, rx=0.6, rz=0.6)
    if el == 0:
        for i in range(7):
            VG(1.6, 2.4 + (i % 3) * 1.4, 1.6, (0xff5a20, 0xff9a30, 0xffd040)[i % 3], (i - 3) * 1.2, hh / 2 + 1.4 + (i % 3) * 0.6, -0.5, h)
        for a in b['arms']: VG(1.8, 2.6, 1.8, 0xff9a30, 0, -o['al'] - 1.2, 0.6, a)
    elif el == 1:
        VA(hw + 1.4, 3, hd + 0.8, shade(S, 1.1), 0, hh / 2 + 0.5, 0, h, 0.7)
        for s in (-1, 1): VA(2, 5, 2, S, s * (hw / 2 + 1), -hh / 2 + 1, -0.5, h, 0.7)
        for i in range(8):
            a = hs(i, 1, 6) * 6.28; r = 7 + hs(i, 2, 6) * 4
            VA(1, 1.4, 1, 0xd0ecff, math.cos(a) * r, 4 + hs(i, 3, 6) * 26, math.sin(a) * r, top, 0.8)
    elif el == 2:
        for i in range(8):
            VA(2.6, 8, 0.3, 0xf4fff8, (1 if i % 2 else -1) * (8 + (i % 3) * 1.6), 4 + i * 3.4, 1.5 * (-1) ** i, top, 0.5, rz=0.35 * (-1) ** i)
        VA(hw + 1, 2.6, hd + 1, 0xf4fff8, 0, hh / 2 + 0.6, 0, h, 0.55)
    elif el == 3:
        for s in (-1, 1):
            V(5, 3.4, 5, 0x7a6a5a, s * (T[3]['w'] / 2 + 1), tH + 0.2, 0, top)
            V(1.6, 4, 1.6, 0x60e0a0, s * (T[3]['w'] / 2 + 1), tH + 3.4, 0, top)
        V(hw + 1, 2, hd + 1, 0x7a6a5a, 0, hh / 2 + 0.6, 0, h)
        for i in range(3): V(1.4, 3 + i % 2, 1.4, 0x60e0a0, (i - 1) * 2, hh / 2 + 2.6, 0, h)
    else:
        for i in range(8):
            a = i / 8.0 * 6.28
            VG(2.4, 0.6, 1.2, 0xfff4a0, math.cos(a) * 5, hh / 2 + 4.4, math.sin(a) * 5, h, ry=-a)
        for i in range(8):
            a = hs(i, 1, 7) * 6.28; r = 7 + hs(i, 2, 7) * 5
            VG(0.6, 0.6, 0.6, 0xfff4b0, math.cos(a) * r, 4 + hs(i, 3, 7) * 26, math.sin(a) * r, top, rx=0.6, rz=0.6)
    dress(b, k)
    if el != 3: set_gel(g, S, 0.68)
    return b

def angel(k, p):
    S = p['skin']
    wc = (0xf4f0e8, 0xf0d890, 0x3a3a44)[p['hs']]; hc = (0xfff0a0, 0xffd040, 0x8a5aff)[p['hs']]
    o = dict(legH=14.5, lw=3.8, ld=4, gap=2.4,
             tiers=[[2.2, 7, 4.4], [3, 6.4, 4.2], [4.4, 8.8, 4.8], [2.4, 9.8, 4.6]],
             neck=1.4, hw=6.2, hh=6.2, hd=6.4, jh=2.3, aw=3.2, al=13.4, ad=3.4,
             eye=dict(w=1.5, h=0.9, tilt=0.15, glow=True))
    b = build(o, p, 'angel'); h = b['head']
    hh = o['hh']
    hair(b, 1 if p['hs'] != 2 else 0, p['hair'], True)
    for i in range(8):
        a = i / 8.0 * 6.28
        VG(2.4, 0.6, 1.2, hc, math.cos(a) * 5, hh / 2 + 4.6, math.sin(a) * 5, h, ry=-a)
    for s in (-1, 1): V(0.9, 1.6, 0.7, S, s * (o['hw'] / 2 + 0.5), 0.5, -0.4, h)
    feather_wings(b, wc, shade(wc, 0.92), 1.15, 8, 0.25, 2.4)
    dress(b, k); return b

def dryad(k, p):
    S = p['skin']; lf = p['hair']; lf2 = shade(lf, 0.8); lf3 = shade(lf, 1.2); bark = shade(S, 0.7)
    o = dict(legH=15, lw=3.4, ld=3.6, gap=2.2,
             tiers=[[2, 6.4, 4], [3, 5.8, 3.8], [4, 7.8, 4.4], [2.2, 8.6, 4.2]],
             neck=1.4, hw=6, hh=6, hd=6.2, jh=2.2, aw=2.6, al=13.2, ad=2.8,
             eye=dict(w=1.6, h=0.9, tilt=0.2, glow=True))
    b = build(o, p, 'dryad'); h = b['head']; top = b['top']; T = b['T']; g = b['g']
    hh = o['hh']; hw = o['hw']; hd = o['hd']
    hair(b, 1, lf, True)
    for i in range(12):
        a = hs(i, 1, 8) * 6.28
        V(1.4, 1, 1.4, (lf, lf2, lf3)[i % 3], math.cos(a) * (hw / 2 + 1), hh / 2 - 1 + hs(i, 2, 8) * 3, math.sin(a) * (hd / 2 + 1), h)
    for s in (-1, 1):
        V(0.8, 4, 0.8, bark, s * 2, hh / 2 + 2.4, 0, h, rz=-s * 0.25)
        V(0.7, 3, 0.7, bark, s * 3.4, hh / 2 + 5, 0, h, rz=-s * 0.7)
        V(0.6, 2.4, 0.6, bark, s * 2.2, hh / 2 + 4.4, 0, h, rz=s * 0.4)
        V(1.4, 1.4, 1.4, lf3, s * 4.6, hh / 2 + 6, 0, h)
        V(1, 1.6, 0.7, S, s * (hw / 2 + 0.5), 0.6, -0.4, h, rz=-s * 0.4)
        A = b['arms'][0 if s == -1 else 1]
        V(o['aw'] + 1.2, 1.2, o['ad'] + 1.2, 0x5a8a3a, 0, 0.8, 0, A)
        for i in range(5): V(o['aw'] + 0.5, 0.5, o['ad'] + 0.5, 0x4a8a3a, 0, -2 - i * 1.9, 0, A, ry=i * 0.3)
        V(1, 0.8, 0.5, lf, s * 1.6, -5, 1.6, A)
        for x in (-1, 0, 1): V(0.9, 0.7, 3, bark, s * o['gap'] + x, 0.4, o['ld'] / 2 + 2, g, ry=x * 0.3)
        V(T[2]['w'] * 0.3, 1.6, 0.5, bark, s * T[2]['w'] * 0.2, T[2]['y0'] + 1.6, T[2]['d'] / 2 + 0.2, top)
    for i, c in enumerate((0xff7ab0, 0xffd84a, 0xffffff, 0xb08af0)):
        V(1.2, 1.2, 1.2, c, (i - 1.5) * 2, hh / 2 + 0.6, hd / 2 - 0.6, h)
    dress(b, k); return b

def insectoid(k, p):
    S = p['skin']; dk = shade(S, 0.7); lt = shade(S, 1.35); nk = p.get('naked')
    ec = p['eye']; p['eye'] = shade(S, 0.5)
    o = dict(legH=14, lw=3.4, ld=3.8, gap=2.4,
             tiers=[[2.2, 7, 4.6], [3, 6, 4.2], [4.6, 9.4, 5.2], [2.4, 10.2, 4.8]],
             neck=1, hw=6.4, hh=6, hd=6.6, jh=2, aw=3, al=13, ad=3.2, noNose=True, noMouth=True,
             eye=dict(w=0.6, h=0.6, tilt=0.0, glow=True))
    b = build(o, p, 'insectoid'); h = b['head']; top = b['top']; T = b['T']; g = b['g']
    hh = o['hh']; hw = o['hw']; hd = o['hd']
    for s in (-1, 1):
        VG(2.8, 3.2, 1.6, ec, s * hw * 0.3, hh * 0.05, hd / 2 + 0.3, h)
        for j in range(4): V(0.9, 0.9, 0.4, shade(ec, 0.5), s * hw * 0.3 + (j % 2 - 0.5) * 1.2, hh * 0.05 + (j // 2 - 0.5) * 1.4, hd / 2 + 1.1, h)
        V(0.9, 2.6, 0.9, dk, s * 0.9, -hh * 0.34, hd / 2 + 0.4, h, rz=s * 0.3)
        V(0.7, 1.4, 0.7, lt, s * 0.4, -hh * 0.34 - 1.9, hd / 2 + 0.5, h, rz=s * 0.6)
        V(0.5, 3.6, 0.5, dk, s * 1.6, hh / 2 + 1.8, 0.5, h, rz=-s * 0.3)
        V(0.5, 3.2, 0.5, dk, s * 3, hh / 2 + 4.6, 0.2, h, rz=-s * 0.7)
        VG(0.9, 0.9, 0.9, ec, s * 4.4, hh / 2 + 6, 0.2, h)
        V(2.2, 4.6, 2.2, S, s * (T[2]['w'] / 2 + 1.4), T[2]['y0'] + 2.2, 1.2, top, rx=-0.5, rz=-s * 0.2)
        V(1.8, 4, 1.8, dk, s * (T[2]['w'] / 2 + 2.2), T[2]['y0'] - 0.6, 3.2, top, rx=-0.9)
        V(0.6, 1.6, 0.6, lt, s * (T[2]['w'] / 2 + 2.2), T[2]['y0'] - 2.4, 4.4, top)
        A = b['arms'][0 if s == -1 else 1]
        V(0.7, 2, 0.7, dk, s * (o['aw'] / 2 + 0.4), -o['al'] * 0.55, 0, A, rz=-s * 0.5)
        x0 = s * 3; z0 = -(T[3]['d'] / 2 + 1.6)
        VA(4.4, 13, 0.3, shade(S, 1.7), x0 + s * math.sin(0.35) * 6.5, o['tH'] + math.cos(0.35) * 6.5, z0, top, 0.5, rz=-s * 0.35)
        VA(3.6, 9, 0.3, shade(S, 1.5), x0 + s * math.sin(0.9) * 4.6, o['tH'] - 1 + math.cos(0.9) * 4.6, z0 - 0.2, top, 0.5, rz=-s * 0.9)
    if nk:
        for j in range(4): V(T[2]['w'] + 0.6, 0.9, T[2]['d'] + 0.6, dk, 0, T[2]['y0'] + 0.8 + j * 1.1, 0, top)
    V(4, 4.6, 5.6, S, 0, 1.4, -(T[0]['d'] / 2 + 3), top, rx=0.3)
    V(4.4, 1, 5.8, dk, 0, 2.6, -(T[0]['d'] / 2 + 3), top, rx=0.3)
    dress(b, k); return b

def undead(k, p):
    S = p['skin']; naked = p.get('naked'); gc = p['eye']; p['eye'] = 0x101010
    o = dict(legH=14, lw=2.6, ld=2.8, gap=2.2,
             tiers=[[2.2, 6, 3.6], [3, 5.4, 3.4], [4.4, 7.6, 4], [2.2, 8.4, 3.8]],
             neck=1.4, hw=6, hh=5.8, hd=6.2, jh=2.4, aw=2.2, al=13.4, ad=2.4, noNose=True, noMouth=True,
             eye=dict(w=2.2, h=2.2, tilt=0.0, white=False, brow=shade(S, 0.6)))
    b = build(o, p, 'undead'); h = b['head']; top = b['top']; T = b['T']
    hh = o['hh']; hw = o['hw']; hd = o['hd']
    ex = hw * 0.27; ey = hh * 0.02
    for s in (-1, 1):
        VG(0.9, 0.9, 0.4, gc, s * ex, ey, hd / 2 + 0.55, h)
    V(1, 1.6, 0.4, 0x101010, 0, -hh * 0.14, hd / 2 + 0.3, h)
    for i in range(6):
        V(0.8, 1.1, 0.5, 0xf4f0e0, (i - 2.5) * 0.95, -hh * 0.36, hd / 2 + 0.3, h)
        V(0.8, 0.9, 0.5, 0xf4f0e0, (i - 2.5) * 0.95, -hh * 0.36 - 1.4, hd / 2 + 0.3, h)
    V(0.4, 2.4, 0.4, shade(S, 0.55), 1.4, hh * 0.3, hd / 2 + 0.3, h, rz=0.4)
    if naked:
        for j in range(5):
            V(T[2]['w'] * 0.9, 0.35, T[2]['d'] + 0.2, 0x2a2620, 0, T[2]['y0'] + 0.9 + j * 0.9, 0, top)
            V(T[2]['w'] + 0.5, 0.6, T[2]['d'] + 0.5, S, 0, T[2]['y0'] + 0.5 + j * 0.9, 0, top)
        V(0.9, o['tH'] * 0.85, 0.9, S, 0, o['tH'] * 0.5, -T[2]['d'] / 2 - 0.3, top)
        V(T[0]['w'] * 0.9, 2.4, T[0]['d'] * 0.9, shade(S, 0.9), 0, 1.2, 0, top)
    dress(b, k); return b

# Pour ajouter une race : créer sa fonction, ses entrées dans SK / EYE (et HAIR si elle a des cheveux),
# puis l'ajouter ici (l'ordre sert à décaler la graine des palettes).
RACES = {'human': human, 'elf': elf, 'goblin': goblin, 'orc': orc,
         'lizard': lizard, 'lycan': lycan, 'vampire': vampire, 'demon': demon,
         'dragonoid': dragonoid, 'fairy': fairy, 'slime': slime, 'dwarf': dwarf,
         'hobgoblin': hobgoblin, 'ogre': ogre, 'kijin': kijin, 'beastfolk': beastfolk, 'harpy': harpy,
         'spirit': spirit, 'angel': angel, 'dryad': dryad, 'insectoid': insectoid, 'undead': undead}
RACE_ORDER = ['human', 'elf', 'goblin', 'orc', 'lizard', 'lycan', 'vampire', 'demon',
              'dragonoid', 'fairy', 'slime', 'dwarf',
              'hobgoblin', 'ogre', 'kijin', 'beastfolk', 'harpy', 'spirit', 'angel', 'dryad', 'insectoid', 'undead']

def make_character(race, job, seed=1):
    """job = forgeron | marchand | garde | mage | fermier | mineur | aubergiste | chasseur | base (base = nu, sans métier ni équipement)."""
    i = RACE_ORDER.index(race)
    naked = (job == 'base')
    p = gen(race, 'forgeron' if naked else job, mk(seed * 97 + i * 13 + 1))
    if naked: p['naked'] = True; p['cape'] = False
    b = RACES[race]('forgeron' if naked else job, p)
    return b['g']

# ---------------------------------------------------------------- export GLB
def rotmat(rx, ry, rz):
    cx, sx = math.cos(rx), math.sin(rx); cy, sy = math.cos(ry), math.sin(ry); cz, sz = math.cos(rz), math.sin(rz)
    Rx = [[1, 0, 0], [0, cx, -sx], [0, sx, cx]]
    Ry = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    Rz = [[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]]
    mm = lambda A, B: [[sum(A[i][k] * B[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    return mm(mm(Rx, Ry), Rz)

def mv(M, v):
    return (M[0][0] * v[0] + M[0][1] * v[1] + M[0][2] * v[2],
            M[1][0] * v[0] + M[1][1] * v[1] + M[1][2] * v[2],
            M[2][0] * v[0] + M[2][1] * v[1] + M[2][2] * v[2])

FACES = [
    ((1, 0, 0), [(1, -1, 1), (1, -1, -1), (1, 1, -1), (1, 1, 1)], 'd', 'h'),
    ((-1, 0, 0), [(-1, -1, -1), (-1, -1, 1), (-1, 1, 1), (-1, 1, -1)], 'd', 'h'),
    ((0, 1, 0), [(-1, 1, 1), (1, 1, 1), (1, 1, -1), (-1, 1, -1)], 'w', 'd'),
    ((0, -1, 0), [(-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1)], 'w', 'd'),
    ((0, 0, 1), [(-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)], 'w', 'h'),
    ((0, 0, -1), [(1, -1, -1), (-1, -1, -1), (-1, 1, -1), (1, 1, -1)], 'w', 'h')]
CORN = [(0, 0), (1, 0), (1, 1), (0, 1)]

def srgb2lin(v):
    v = v / 255.0
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4

def noise_png():
    w = h = 16; rows = []
    for j in range(h):
        rows.append(bytes(b'\x00') + bytes(int(230 + hs(i, j, 3) * 25) for i in range(w)))
    raw = b''.join(rows)
    def chunk(t, d):
        c = struct.pack('>I', len(d)) + t + d
        return c + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 0, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))

class GLB:
    def __init__(s):
        s.bin = bytearray(); s.views = []; s.acc = []; s.mats = []; s.matidx = {}
        s.nodes = []; s.meshes = []
    def view(s, data, target=None):
        while len(s.bin) % 4: s.bin.append(0)
        off = len(s.bin); s.bin += data
        v = {'buffer': 0, 'byteOffset': off, 'byteLength': len(data)}
        if target: v['target'] = target
        s.views.append(v); return len(s.views) - 1
    def accessor(s, view, ctype, count, typ, mn=None, mx=None):
        a = {'bufferView': view, 'componentType': ctype, 'count': count, 'type': typ}
        if mn is not None: a['min'] = mn; a['max'] = mx
        s.acc.append(a); return len(s.acc) - 1
    def material(s, color, glow, alpha=1.0):
        key = (color, glow, alpha)
        if key in s.matidx: return s.matidx[key]
        r, g, b = (srgb2lin((color >> 16) & 255), srgb2lin((color >> 8) & 255), srgb2lin(color & 255))
        m = {'name': ('glow_%06x' if glow else ('gel_%06x' if alpha < 1 else 'mat_%06x')) % color,
             'pbrMetallicRoughness': {'baseColorFactor': [r, g, b, alpha], 'baseColorTexture': {'index': 0},
                                      'metallicFactor': 0.0, 'roughnessFactor': 1.0}}
        if glow: m['emissiveFactor'] = [r, g, b]
        if alpha < 1: m['alphaMode'] = 'BLEND'
        s.mats.append(m); s.matidx[key] = len(s.mats) - 1
        return s.matidx[key]
    def mesh_for(s, boxes, name):
        groups = {}
        for b in boxes:
            key = (b['c'], b['glow'], b.get('alpha', 1.0))
            gr = groups.setdefault(key, dict(pos=[], nor=[], uv=[], idx=[]))
            M = rotmat(*b['r'])
            dims = {'w': b['w'], 'h': b['h'], 'd': b['d']}
            for nrm, verts, du, dv in FACES:
                base = len(gr['pos'])
                n = mv(M, nrm)
                for (sx, sy, sz), (cu, cv) in zip(verts, CORN):
                    v = mv(M, (sx * b['w'] / 2, sy * b['h'] / 2, sz * b['d'] / 2))
                    gr['pos'].append(((v[0] + b['x']) * UNIT, (v[1] + b['y']) * UNIT, (v[2] + b['z']) * UNIT))
                    gr['nor'].append(n)
                    gr['uv'].append((cu * dims[du] / 16.0, cv * dims[dv] / 16.0))
                gr['idx'] += [base, base + 1, base + 2, base, base + 2, base + 3]
        prims = []
        for (color, glow, alpha), gr in groups.items():
            pos = gr['pos']
            mn = [min(p[i] for p in pos) for i in range(3)]; mx = [max(p[i] for p in pos) for i in range(3)]
            vp = s.view(b''.join(struct.pack('<3f', *p) for p in pos), 34962)
            vn = s.view(b''.join(struct.pack('<3f', *p) for p in gr['nor']), 34962)
            vu = s.view(b''.join(struct.pack('<2f', *p) for p in gr['uv']), 34962)
            vi = s.view(b''.join(struct.pack('<I', i) for i in gr['idx']), 34963)
            prims.append({'attributes': {'POSITION': s.accessor(vp, 5126, len(pos), 'VEC3', mn, mx),
                                         'NORMAL': s.accessor(vn, 5126, len(pos), 'VEC3'),
                                         'TEXCOORD_0': s.accessor(vu, 5126, len(pos), 'VEC2')},
                          'indices': s.accessor(vi, 5125, len(gr['idx']), 'SCALAR'),
                          'material': s.material(color, glow, alpha)})
        s.meshes.append({'name': name, 'primitives': prims})
        return len(s.meshes) - 1
    def add_node(s, n):
        d = {'name': n.name}
        if n.t != (0, 0, 0): d['translation'] = [n.t[0] * UNIT, n.t[1] * UNIT, n.t[2] * UNIT]
        if n.rx: d['rotation'] = [math.sin(n.rx / 2), 0, 0, math.cos(n.rx / 2)]
        if n.scale != 1.0: d['scale'] = [n.scale] * 3
        if n.boxes: d['mesh'] = s.mesh_for(n.boxes, n.name + '_mesh')
        idx = len(s.nodes); s.nodes.append(d)
        kids = [s.add_node(k) for k in n.kids]
        if kids: d['children'] = kids
        return idx

def export_glb(root, path):
    g = GLB()
    png = noise_png()
    img_view = g.view(png)
    ridx = g.add_node(root)
    doc = {'asset': {'version': '2.0', 'generator': 'voxel_character_generator.py'},
           'scene': 0, 'scenes': [{'nodes': [ridx]}], 'nodes': g.nodes, 'meshes': g.meshes,
           'materials': g.mats,
           'textures': [{'sampler': 0, 'source': 0}],
           'samplers': [{'magFilter': 9728, 'minFilter': 9728, 'wrapS': 10497, 'wrapT': 10497}],
           'images': [{'bufferView': img_view, 'mimeType': 'image/png'}],
           'buffers': [{'byteLength': len(g.bin)}], 'bufferViews': g.views, 'accessors': g.acc}
    js = json.dumps(doc, separators=(',', ':')).encode()
    while len(js) % 4: js += b' '
    binb = bytes(g.bin)
    while len(binb) % 4: binb += b'\x00'
    total = 12 + 8 + len(js) + 8 + len(binb)
    with open(path, 'wb') as f:
        f.write(struct.pack('<III', 0x46546C67, 2, total))
        f.write(struct.pack('<II', len(js), 0x4E4F534A)); f.write(js)
        f.write(struct.pack('<II', len(binb), 0x004E4942)); f.write(binb)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='models')
    ap.add_argument('--race', default='all')
    ap.add_argument('--job', default='all')
    ap.add_argument('--seed', type=int, default=None, help='palette précise (sinon 1)')
    ap.add_argument('--variants', type=int, default=1, help='nombre de palettes différentes par modèle')
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    races = RACE_ORDER if a.race == 'all' else [a.race]
    jobs = (JOBS + ['base']) if a.job == 'all' else [a.job]
    seeds = [a.seed] if a.seed else list(range(1, a.variants + 1))
    n = 0
    for r in races:
        for j in jobs:
            for sd in seeds:
                suffix = '' if (sd == 1 and not a.seed) else '_v%d' % sd
                sub = os.path.join(a.out, 'base') if j == 'base' else a.out
                os.makedirs(sub, exist_ok=True)
                path = os.path.join(sub, '%s_%s%s.glb' % (r, j, suffix))
                export_glb(make_character(r, j, sd), path); n += 1
    print('%d fichier(s) .glb écrit(s) dans %s' % (n, a.out))

if __name__ == '__main__':
    main()
