#!/usr/bin/env python3
"""
Générateur des décors voxel (arbres, rochers, cabane, feu de camp...) -> fichiers .glb pour Godot 4.

Même style que les personnages (voxel_character_generator.py) : uniquement des boîtes,
couleurs unies avec le même grain de bruit, 1 unité = 1 voxel = 5 cm.
L'origine de chaque objet est au sol, au centre de sa base.

Usage :
    python voxel_props_generator.py --out ../assets/environment/models
"""
import argparse, os
from voxel_character_generator import Node, V, VG, VA, export_glb, mk, shade, R


def pick(rnd, lst):
    return lst[int(rnd() * len(lst)) % len(lst)]


# ---------------------------------------------------------------- végétation
LEAF = [0x4f8a3a, 0x5c9a40, 0x46803a, 0x6aa84a, 0x3f7434]
LEAF_AUTUMN = [0xc07a2a, 0xd49a34, 0xb05a28, 0xe0b040]
PINE = [0x2f5e3a, 0x356a40, 0x2a5234, 0x3d7446]
BARK = [0x6a4a30, 0x5a3e28, 0x76543a]


def trunk(pa, rnd, h, w, bark):
    V(w, h, w, bark, 0, h / 2, 0, pa)
    # racines
    for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        l = 3 + int(rnd() * 3)
        V(4 if dx else 3, 3 + int(rnd() * 3), 3 if dx else 4, shade(bark, 0.85), dx * (w / 2 + l / 2 - 1), 1.5, dz * (w / 2 + l / 2 - 1), pa)
    # écorce en relief
    for i in range(6):
        y = 6 + rnd() * (h - 12)
        side = int(rnd() * 4)
        dx, dz = ((1, 0), (-1, 0), (0, 1), (0, -1))[side]
        V(2 if dx else 3, 4 + int(rnd() * 5), 3 if dx else 2, shade(bark, 0.8), dx * w / 2, y, dz * w / 2, pa)


def oak(seed, autumn=False):
    rnd = mk(seed * 31 + 7)
    g = Node('Tree')
    bark = pick(rnd, BARK)
    leaves = LEAF_AUTUMN if autumn else LEAF
    h = 38 + int(rnd() * 16)
    trunk(g, rnd, h, 8, bark)
    # branches
    for sx in (-1, 1):
        V(10, 3, 3, bark, sx * 7, h - 10 + rnd() * 4, 0, g, rz=sx * 0.5)
    # houppier : grappes de blocs
    cy = h + 14
    V(44, 22, 44, leaves[0], 0, cy, 0, g)
    V(34, 12, 34, leaves[1], 0, cy + 16, 0, g)
    V(20, 6, 20, leaves[3], 2, cy + 24, -2, g)
    for i in range(14):
        c = pick(rnd, leaves)
        w = 10 + int(rnd() * 12); hh = 8 + int(rnd() * 10); d = 10 + int(rnd() * 12)
        x = (rnd() - 0.5) * 44; z = (rnd() - 0.5) * 44; y = cy - 8 + rnd() * 22
        V(w, hh, d, c, x, y, z, g)
    # dessous plus sombre
    V(40, 3, 40, shade(leaves[0], 0.7), 0, cy - 12, 0, g)
    if not autumn and rnd() < 0.6:
        for i in range(4):
            V(3, 3, 3, pick(rnd, [0xd8402a, 0xe8c040]), (rnd() - 0.5) * 44, cy - 4 + rnd() * 14, 23 * (1 if rnd() < 0.5 else -1), g)
    return g


def pine(seed):
    rnd = mk(seed * 17 + 3)
    g = Node('Tree')
    bark = pick(rnd, BARK)
    h = 20 + int(rnd() * 8)
    trunk(g, rnd, h, 7, bark)
    tiers = 5 + int(rnd() * 2)
    y = h - 6
    w = 46
    for t in range(tiers):
        c = pick(rnd, PINE)
        V(w, 9, w, c, 0, y, 0, g)
        V(w - 8, 5, w - 8, shade(c, 1.08), 0, y + 7, 0, g)
        # pointes qui dépassent
        for s in range(4):
            dx, dz = ((1, 0), (-1, 0), (0, 1), (0, -1))[s]
            V(6, 4, 6, shade(c, 0.9), dx * (w / 2 + 1), y - 3, dz * (w / 2 + 1), g)
        if rnd() < 0.5:
            V(6, 2, 6, 0xeef2f4, (rnd() - 0.5) * (w - 10), y + 5, (rnd() - 0.5) * (w - 10), g)
        y += 12
        w = max(10, w - 8)
    V(6, 10, 6, pick(rnd, PINE), 0, y + 2, 0, g)
    return g


def bush(seed):
    rnd = mk(seed * 13 + 5)
    g = Node('Bush')
    c = pick(rnd, LEAF)
    V(22, 12, 20, c, 0, 6, 0, g)
    for i in range(6):
        V(8 + int(rnd() * 8), 6 + int(rnd() * 6), 8 + int(rnd() * 8), pick(rnd, LEAF), (rnd() - 0.5) * 20, 6 + rnd() * 8, (rnd() - 0.5) * 18, g)
    if rnd() < 0.7:
        berry = pick(rnd, [0xc8302a, 0x5a3a9a, 0xe8e0f0])
        for i in range(6):
            V(2, 2, 2, berry, (rnd() - 0.5) * 22, 4 + rnd() * 10, 10 * (1 if rnd() < 0.5 else -1), g)
    return g


ROCK = [0x8a8a86, 0x7a7a78, 0x96948c, 0x6e6e6c]


def rock(seed, big=False):
    rnd = mk(seed * 23 + 11)
    g = Node('Rock')
    s = 1.8 if big else 1.0
    c = pick(rnd, ROCK)
    V(R(20 * s), R(12 * s), R(16 * s), c, 0, 6 * s, 0, g)
    V(R(14 * s), R(8 * s), R(12 * s), shade(c, 1.08), 2 * s, 14 * s, -1 * s, g)
    for i in range(4):
        V(R((6 + rnd() * 8) * s), R((4 + rnd() * 6) * s), R((6 + rnd() * 8) * s), shade(c, 0.85 + rnd() * 0.25),
          (rnd() - 0.5) * 20 * s, (2 + rnd() * 6) * s, (rnd() - 0.5) * 16 * s, g)
    # mousse
    if rnd() < 0.6:
        V(R(10 * s), 2, R(8 * s), 0x5c8a3c, 0, 18 * s + 1, 0, g)
    return g


def vein(seed, ore, ore_l):
    """Rocher parcouru de pépites de minerai (filon de fer ou d'or)."""
    rnd = mk(seed * 31 + 7)
    g = Node('Vein')
    c = 0x7a7874
    V(22, 14, 18, c, 0, 7, 0, g)
    V(15, 9, 13, shade(c, 1.1), 2, 16, -1, g)
    for i in range(3):
        V(R(6 + rnd() * 6), R(4 + rnd() * 4), R(6 + rnd() * 6), shade(c, 0.85 + rnd() * 0.2),
          (rnd() - 0.5) * 22, 2 + rnd() * 5, (rnd() - 0.5) * 18, g)
    # pépites qui dépassent des faces
    for i in range(14):
        face = i % 4
        y = 3 + rnd() * 16
        a = (rnd() - 0.5) * 16
        col = ore_l if rnd() < 0.35 else ore
        if face == 0:
            V(3, 3, 1.4, col, a * 0.9, y, 9.3, g)
        elif face == 1:
            V(3, 3, 1.4, col, a * 0.9, y, -9.3, g)
        elif face == 2:
            V(1.4, 3, 3, col, 11.3, y, a * 0.7, g)
        else:
            V(1.4, 3, 3, col, -11.3, y, a * 0.7, g)
    for i in range(3):
        V(3, 1.4, 3, ore_l, (rnd() - 0.5) * 10, 20.8, (rnd() - 0.5) * 8, g)
    return g


def flowers(seed):
    rnd = mk(seed * 19 + 1)
    g = Node('Flowers')
    cols = [0xf0e040, 0xe85a6a, 0xf4f4f4, 0x8a6ae0, 0xf09a30]
    for i in range(5):
        x = (rnd() - 0.5) * 16; z = (rnd() - 0.5) * 16
        h = 3 + int(rnd() * 4)
        V(1, h, 1, 0x4a8a34, x, h / 2, z, g)
        c = pick(rnd, cols)
        V(3, 2, 3, c, x, h + 1, z, g)
        V(1, 1, 1, 0xf8e070, x, h + 2.2, z, g)
    return g


def grass(seed):
    rnd = mk(seed * 29 + 3)
    g = Node('Grass')
    for i in range(7):
        h = 3 + int(rnd() * 5)
        V(1, h, 1, pick(rnd, [0x5a9a3a, 0x6aaa44, 0x4a8a32]), (rnd() - 0.5) * 10, h / 2, (rnd() - 0.5) * 10, g)
    return g


# ---------------------------------------------------------------- cultures (4 stades : 0 semé ... 3 mûr)
CROP_SPOTS = [(-5, -5), (5, -5), (-5, 5), (5, 5), (0, 0)]


def crop(kind, stage, seed=1):
    rnd = mk(seed * 31 + stage * 7 + len(kind))
    g = Node('Crop')
    for i, (x, z) in enumerate(CROP_SPOTS):
        x += (rnd() - 0.5) * 2; z += (rnd() - 0.5) * 2
        if stage == 0:
            # graines dans la terre, deux petites pousses
            V(1.2, 1.5, 1.2, 0x6aaa44, x, 0.75, z, g)
            V(1, 0.6, 1, 0xd0b070, x + 1.5, 0.3, z - 1, g)
            continue
        if kind == 'ble':
            h = (0, 5, 11, 15)[stage] + int(rnd() * 3)
            stem = 0x6aaa44 if stage < 3 else pick(rnd, [0xd8b848, 0xc8a840, 0xe0c858])
            for dx in (-1.2, 0, 1.2):
                V(0.8, h, 0.8, stem, x + dx, h / 2, z + dx * 0.5, g, rz=dx * 0.06)
                if stage >= 2:
                    V(1.4, 3.4, 1.4, 0x9ac858 if stage == 2 else 0xf0d060, x + dx * 1.2, h + 1.5, z + dx * 0.5, g, rz=dx * 0.06)
        elif kind == 'carotte':
            h = (0, 3, 5, 7)[stage]
            for dx, dz in ((-1, 0), (1, 0), (0, 1), (0, -1)):
                V(1, h, 1, pick(rnd, [0x4a9a3a, 0x5aaa44]), x + dx * 0.9, h / 2, z + dz * 0.9, g, rx=dz * 0.35, rz=-dx * 0.35)
            if stage == 3:
                V(3, 2.4, 3, 0xe8802a, x, 0.9, z, g)
        else:  # pomme de terre
            s = (0, 3, 5, 6.5)[stage]
            V(s, s * 0.8, s, pick(rnd, [0x3f7a34, 0x4a8a3a]), x, s * 0.4, z, g)
            V(s * 0.6, s * 0.5, s * 0.6, 0x5a9a44, x + 0.5, s * 0.8 + s * 0.2, z, g)
            if stage == 3:
                V(1.2, 1.2, 1.2, 0xf4f0e0, x + 1.5, s + 0.6, z + 1, g)
                V(2.4, 1.6, 2.2, 0xb8905a, x - 2.4, 0.5, z + 1.8, g)
    return g


# ---------------------------------------------------------------- village
WOOD = 0x8a6038
WOOD_D = 0x6a4428
THATCH = [0xc8a050, 0xb89040, 0xd8b060]


def hut(seed=1):
    rnd = mk(seed * 7 + 1)
    g = Node('Hut')
    W, D, H = 80, 64, 44          # 4 m x 3,2 m, murs de 2,2 m
    # socle de pierre
    V(W + 6, 4, D + 6, 0x7a7872, 0, 2, 0, g)
    for i in range(16):
        V(8 + int(rnd() * 6), 5, 6, shade(0x86847c, 0.9 + rnd() * 0.2), (rnd() - 0.5) * (W + 2), 2.5, (D / 2 + 2) * (1 if rnd() < 0.5 else -1), g)
    # murs en planches (bandes horizontales alternées)
    for y in range(4, 4 + H, 4):
        c = WOOD if (y // 4) % 2 else shade(WOOD, 0.92)
        V(W, 4, D, c, 0, y + 2, 0, g)
    # poteaux d'angle
    for sx in (-1, 1):
        for sz in (-1, 1):
            V(6, H + 2, 6, WOOD_D, sx * W / 2, 4 + (H + 2) / 2, sz * D / 2, g)
    # poutres
    V(W + 4, 4, 4, WOOD_D, 0, 4 + H, D / 2, g)
    V(W + 4, 4, 4, WOOD_D, 0, 4 + H, -D / 2, g)
    # porte (face +Z)
    V(18, 32, 2, 0x5a3a22, 0, 4 + 16, D / 2 + 1, g)
    V(22, 3, 3, WOOD_D, 0, 4 + 33, D / 2 + 1.5, g)
    for x in (-5, 0, 5):
        V(1, 30, 2.4, 0x4a2e1a, x, 4 + 16, D / 2 + 1.2, g)
    V(2, 2, 2, 0xc8a040, 6, 4 + 16, D / 2 + 2.5, g)
    # fenêtres éclairées
    for sx in (-1, 1):
        V(12, 10, 2, 0x3a2a1e, sx * 26, 4 + 24, D / 2 + 1, g)
        VG(8, 7, 2.2, 0xffc860, sx * 26, 4 + 24, D / 2 + 1, g)
        V(14, 2, 4, WOOD_D, sx * 26, 4 + 18, D / 2 + 2, g)
    VG(8, 7, 2.2, 0xffc860, W / 2 + 1, 4 + 24, 0, g, ry=1.5708)
    V(2, 10, 12, 0x3a2a1e, W / 2 + 0.5, 4 + 24, 0, g)
    # toit de chaume en escalier (le faîte suit l'axe X)
    base = 4 + H + 2
    steps = 11
    for i in range(steps):
        d = D + 20 - i * 7
        if d <= 4:
            break
        c = THATCH[i % len(THATCH)]
        V(W + 16 - (i % 2) * 2, 5, d, c, 0, base + i * 5, 0, g)
        # franges
        for sz in (-1, 1):
            V(W + 16, 2, 2, shade(c, 0.8), 0, base + i * 5 - 2, sz * (d / 2), g)
    V(W + 20, 5, 8, shade(THATCH[0], 0.75), 0, base + steps * 5 - 12, 0, g)
    # pignons
    for sx in (-1, 1):
        for i in range(8):
            d = D - i * 8
            if d <= 0:
                break
            V(3, 5, d, shade(WOOD, 0.85), sx * (W / 2 - 1), base + i * 5, 0, g)
    # cheminée
    V(10, 26, 10, 0x6a6862, -W / 4, base + 34, -10, g)
    V(12, 3, 12, 0x55534e, -W / 4, base + 47, -10, g)
    # tonneau d'eau et bois coupé
    for i in range(3):
        V(20, 5, 5, shade(WOOD_D, 1 + 0.1 * i), -W / 2 - 4, 6.5 + i * 5, D / 2 - 10 - (i % 2) * 2, g, ry=1.5708)
    return g


def campfire(seed=1):
    rnd = mk(seed * 3 + 2)
    g = Node('Campfire')
    # cercle de pierres
    for i in range(10):
        import math
        a = i / 10 * math.tau
        V(7, 5 + int(rnd() * 3), 6, shade(pick(rnd, ROCK), 0.9 + rnd() * 0.2), math.cos(a) * 15, 2.5, math.sin(a) * 15, g, ry=-a)
    V(24, 1, 24, 0x2a2420, 0, 0.5, 0, g)
    # bûches croisées
    for a in (0.0, 1.05, 2.1):
        V(26, 4, 4, pick(rnd, BARK), 0, 3, 0, g, ry=a, rz=0.15)
    VG(10, 2, 10, 0xff6a20, 0, 5, 0, g)
    flame = g.add(Node('Flame', (0, 5, 0)))
    VG(10, 8, 10, 0xff7a20, 0, 4, 0, flame)
    VG(7, 8, 7, 0xffa030, 1, 10, -1, flame)
    VG(4, 7, 4, 0xffd860, 0, 16, 0, flame)
    VG(3, 4, 3, 0xffa030, -4, 9, 3, flame)
    VG(2, 3, 2, 0xffe890, 2, 21, 1, flame)
    return g


def barrel(seed=1):
    g = Node('Barrel')
    rows = [(14, 0), (16, 4), (17, 8), (17, 12), (16, 16), (14, 20)]
    for w, y in rows:
        V(w, 4, w, WOOD if (y // 4) % 2 else shade(WOOD, 0.9), 0, y + 2, 0, g)
        V(w - 4, 4, w + 1, shade(WOOD, 0.95), 0, y + 2, 0, g)
        V(w + 1, 4, w - 4, shade(WOOD, 0.95), 0, y + 2, 0, g)
    for y in (3, 20):
        V(18, 2, 18, 0x4a4a50, 0, y, 0, g)
    V(12, 1, 12, WOOD_D, 0, 24.5, 0, g)
    return g


def crate(seed=1):
    g = Node('Crate')
    S = 20
    V(S, S, S, 0xa87844, 0, S / 2, 0, g)
    for sx in (-1, 1):
        for sz in (-1, 1):
            V(3, S + 1, 3, 0x7a522c, sx * S / 2, S / 2, sz * S / 2, g)
    for sy in (0, 1):
        V(S + 1, 3, 3, 0x7a522c, 0, sy * S, S / 2, g)
        V(S + 1, 3, 3, 0x7a522c, 0, sy * S, -S / 2, g)
        V(3, 3, S + 1, 0x7a522c, S / 2, sy * S, 0, g)
        V(3, 3, S + 1, 0x7a522c, -S / 2, sy * S, 0, g)
    V(S * 1.3, 2, 2.4, 0x8a5e32, 0, S / 2, S / 2 + 0.6, g, rz=0.78)
    V(2.4, 2, S * 1.3, 0x8a5e32, S / 2 + 0.6, S / 2, 0, g, rx=0.78)
    return g


def workbench(seed=1):
    """Établi d'artisan : table, enclume, outils et petite forge."""
    g = Node('Workbench')
    # table
    V(44, 4, 22, WOOD, 0, 18, 0, g)
    V(46, 1.5, 24, shade(WOOD, 1.1), 0, 20.5, 0, g)
    for sx in (-1, 1):
        for sz in (-1, 1):
            V(4, 16, 4, WOOD_D, sx * 19, 8, sz * 8, g)
    V(40, 3, 3, WOOD_D, 0, 5, 8, g)
    # outils posés
    V(10, 1.5, 2, 0x8a8e96, -12, 22, 2, g)
    V(3, 2, 4, 0x6e747e, -8, 22.2, 2, g)
    V(1.5, 1.5, 12, WOOD_D, 6, 22, -3, g, ry=0.4)
    V(4, 2.5, 3, 0x6e747e, 8, 22.5, 1, g)
    V(12, 2, 8, 0x7a4a2a, 14, 22, -4, g)
    # enclume
    V(8, 8, 8, 0x5a5a60, 34, 4, 0, g)
    V(6, 4, 5, 0x3e3e44, 34, 10, 0, g)
    V(14, 4, 7, 0x4e4e56, 35, 14, 0, g)
    V(5, 3, 4, 0x4e4e56, 43, 14.5, 0, g)
    # petite forge
    V(16, 12, 14, 0x7a7872, -34, 6, 0, g)
    V(12, 2, 10, 0x2a2420, -34, 12.5, 0, g)
    VG(8, 2, 6, 0xff7a20, -34, 13.2, 0, g)
    VG(4, 2, 3, 0xffc040, -33, 14.4, 1, g)
    V(6, 20, 6, 0x6a6862, -38, 22, -4, g)
    # tonneau d'eau
    V(9, 12, 9, WOOD, 26, 6, 13, g)
    V(10, 1.5, 10, 0x4a4a50, 26, 3, 13, g)
    V(10, 1.5, 10, 0x4a4a50, 26, 10, 13, g)
    V(7, 1, 7, 0x3a6a9a, 26, 12.2, 13, g)
    return g


def weapon_rack(seed=1):
    """Râtelier d'armes (décor)."""
    g = Node('WeaponRack')
    for sx in (-1, 1):
        V(3, 30, 3, WOOD_D, sx * 16, 15, 0, g)
        V(8, 2, 6, WOOD_D, sx * 16, 1, 0, g)
    V(36, 3, 3, WOOD, 0, 26, 0, g)
    V(36, 3, 3, WOOD, 0, 8, 2, g)
    for i, x in enumerate((-10, -3, 4, 11)):
        V(1, 28, 1, WOOD, x, 15, 1, g, rz=0.08)
        V(2.4, 3, 1, 0xd9dde3, x + 1.1, 29, 1, g, rz=0.08)
    return g


PROPS = {
    'workbench': workbench, 'weapon_rack': weapon_rack,
    'oak_1': lambda: oak(1), 'oak_2': lambda: oak(2), 'oak_3': lambda: oak(3), 'oak_autumn': lambda: oak(4, True),
    'pine_1': lambda: pine(1), 'pine_2': lambda: pine(2), 'pine_3': lambda: pine(3),
    'bush_1': lambda: bush(1), 'bush_2': lambda: bush(2),
    'rock_1': lambda: rock(1), 'rock_2': lambda: rock(2), 'rock_big': lambda: rock(3, True),
    'flowers_1': lambda: flowers(1), 'flowers_2': lambda: flowers(2), 'grass_1': lambda: grass(1),
    'hut': hut, 'campfire': campfire, 'barrel': barrel, 'crate': crate,
    'iron_vein_1': lambda: vein(1, 0xc8743a, 0xe89a5a), 'iron_vein_2': lambda: vein(2, 0xc8743a, 0xe89a5a),
    'gold_vein_1': lambda: vein(3, 0xe0b030, 0xfff080),
}
for _k in ('ble', 'carotte', 'pomme_de_terre'):
    for _s in range(4):
        PROPS['crop_%s_%d' % (_k, _s)] = (lambda k, st: (lambda: crop(k, st)))(_k, _s)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='../assets/environment/models')
    ap.add_argument('--only', default='', help='noms séparés par des virgules (par défaut : tous)')
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    only = [n for n in a.only.split(',') if n]
    for name, fn in PROPS.items():
        if only and name not in only:
            continue
        export_glb(fn(), os.path.join(a.out, name + '.glb'))
    print('%d décor(s) .glb écrit(s) dans %s' % (len(PROPS), a.out))


if __name__ == '__main__':
    main()
