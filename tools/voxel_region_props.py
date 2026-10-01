#!/usr/bin/env python3
"""
Décors voxel des régions du monde ouvert (cactus, sapins enneigés, champignons géants,
cerisiers, cristaux, roches volcaniques, obélisques de téléportation, portes de donjon...).

Même style et mêmes règles que voxel_props_generator.py (1 unité = 5 cm, origine au sol).

Usage :
    python voxel_region_props.py --out ../assets/environment/models
"""
import argparse, os
from voxel_character_generator import Node, V, VG, export_glb, mk, shade
import voxel_props_generator as P
from voxel_props_generator import pick, trunk, oak, pine, bush, rock


def oak_colored(seed, leaves):
    """Chêne avec un feuillage d'une autre couleur (cerisier, bois enchanté, marais...)."""
    saved = P.LEAF_AUTUMN
    P.LEAF_AUTUMN = leaves
    g = oak(seed, True)
    P.LEAF_AUTUMN = saved
    return g


def pine_snow(seed):
    g = pine(seed)
    for b in list(g.boxes):
        if b['w'] >= 14 and b['h'] in (9, 5):
            V(b['w'] - 2, 2, b['d'] - 2, 0xf2f6fa, b['x'], b['y'] + b['h'] / 2 + 1, b['z'], g)
    return g


def dead_tree(seed):
    rnd = mk(seed * 43 + 1)
    g = Node('Tree')
    bark = pick(rnd, [0x4a3a30, 0x3e3028, 0x5a4a3e])
    h = 30 + int(rnd() * 14)
    trunk(g, rnd, h, 6, bark)
    for i in range(5):
        sx = 1 if i % 2 == 0 else -1
        y = h * (0.45 + 0.12 * i)
        l = 8 + int(rnd() * 8)
        V(l, 2.4, 2.4, bark, sx * (3 + l / 2), y, (rnd() - 0.5) * 6, g, rz=sx * (0.35 + rnd() * 0.4))
        V(2, 6, 2, shade(bark, 0.9), sx * (4 + l), y + 4, 0, g)
    return g


def cactus(seed):
    rnd = mk(seed * 47 + 5)
    g = Node('Tree')
    c = pick(rnd, [0x4a8a3a, 0x3e7a34, 0x5a9a44])
    h = 26 + int(rnd() * 14)
    V(8, h, 8, c, 0, h / 2, 0, g)
    for i in range(int(h / 5)):
        V(9, 1, 1, shade(c, 1.2), 0, 3 + i * 5, 4.2, g)
        V(1, 1, 9, shade(c, 1.2), 4.2, 5 + i * 5, 0, g)
    for sx in (-1, 1):
        if rnd() < 0.8:
            y = h * (0.35 + rnd() * 0.25)
            V(6, 5, 5, c, sx * 6, y, 0, g)
            ah = 8 + int(rnd() * 8)
            V(5, ah, 5, c, sx * 8.5, y + ah / 2, 0, g)
    if rnd() < 0.6:
        V(4, 3, 4, pick(rnd, [0xf05a8a, 0xf0d040, 0xf4f4f4]), 0, h + 1.5, 0, g)
    return g


def mushroom(seed, cap=0xc83a3a):
    rnd = mk(seed * 53 + 3)
    g = Node('Tree')
    h = 22 + int(rnd() * 14)
    V(8, h, 8, 0xece0c8, 0, h / 2, 0, g)
    V(12, 3, 12, 0xd8ccb4, 0, h * 0.6, 0, g)
    V(40, 8, 40, cap, 0, h + 3, 0, g)
    V(30, 5, 30, shade(cap, 1.1), 0, h + 9, 0, g)
    V(16, 3, 16, shade(cap, 1.15), 0, h + 13, 0, g)
    V(36, 1, 36, 0xf0e4cc, 0, h - 1.4, 0, g)
    for i in range(9):
        V(5, 1.2, 5, 0xf8f4ea, (rnd() - 0.5) * 34, h + 7.8 + (5 if rnd() < 0.4 else 0), (rnd() - 0.5) * 34, g)
    return g


def reeds(seed):
    rnd = mk(seed * 59 + 7)
    g = Node('Grass')
    for i in range(9):
        h = 10 + int(rnd() * 12)
        x = (rnd() - 0.5) * 14
        z = (rnd() - 0.5) * 14
        V(1, h, 1, pick(rnd, [0x6a8a3a, 0x7a9a44, 0x5a7a34]), x, h / 2, z, g)
        if rnd() < 0.5:
            V(2, 4, 2, 0x6a4a2a, x, h + 1, z, g)
    return g


def dry_grass(seed):
    rnd = mk(seed * 71 + 3)
    g = Node('Grass')
    for i in range(6):
        h = 3 + int(rnd() * 5)
        V(1, h, 1, pick(rnd, [0xc8a860, 0xb89850, 0xd8b870]), (rnd() - 0.5) * 10, h / 2, (rnd() - 0.5) * 10, g)
    return g


def crystal(seed, c=0x8ae0ff):
    rnd = mk(seed * 61 + 1)
    g = Node('Rock')
    V(16, 5, 14, 0x6a6a74, 0, 2.5, 0, g)
    for i in range(5):
        h = 10 + int(rnd() * 16)
        w = 3 + int(rnd() * 3)
        V(w, h, w, shade(c, 0.85 + rnd() * 0.3), (rnd() - 0.5) * 12, h / 2 + 2, (rnd() - 0.5) * 10, g,
          rx=(rnd() - 0.5) * 0.5, rz=(rnd() - 0.5) * 0.5, glow=True)
    return g


def lava_rock(seed):
    rnd = mk(seed * 67 + 3)
    g = rock(seed + 40, rnd() < 0.5)
    for b in g.boxes:
        b['c'] = shade(0x3a3434, 0.8 + rnd() * 0.4)
    for i in range(4):
        V(1.4, 1.4 + rnd() * 6, 1.4 + rnd() * 6, 0xff7a20, (rnd() - 0.5) * 16, 4 + rnd() * 8, 8.4, g, glow=True)
    return g


def snow_rock(seed):
    g = rock(seed + 70)
    top = max(b['y'] + b['h'] / 2 for b in g.boxes)
    V(18, 3, 14, 0xf2f6fa, 0, top, 0, g)
    return g


def obelisk():
    g = Node('Obelisk')
    V(26, 4, 26, 0x6e6c6a, 0, 2, 0, g)
    V(22, 3, 22, 0x8a8884, 0, 5.5, 0, g)
    V(12, 40, 12, 0x5a5a66, 0, 27, 0, g)
    V(10, 8, 10, 0x6a6a78, 0, 51, 0, g)
    V(6, 6, 6, 0x7a7a88, 0, 58, 0, g)
    for sx, sz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        VG(1.2 if sx else 6, 22, 1.2 if sz else 6, 0x6ae0ff, sx * 6.1, 27, sz * 6.1, g)
    VG(5, 5, 5, 0x8af0ff, 0, 66, 0, g, rx=0.6, rz=0.6)
    return g


def dungeon_gate():
    g = Node('Gate')
    st = 0x6a6660
    V(40, 4, 22, shade(st, 0.9), 0, 2, 0, g)
    for sx in (-1, 1):
        V(8, 34, 10, st, sx * 14, 19, 0, g)
        V(10, 4, 12, shade(st, 1.1), sx * 14, 37, 0, g)
    V(40, 8, 12, shade(st, 1.05), 0, 40, 0, g)
    V(20, 28, 2, 0x0a0a0e, 0, 18, 1, g)
    V(8, 6, 2, 0xc84a3a, 0, 40, 6.2, g, glow=True)
    for i in range(5):
        V(4, 4, 4, shade(st, 0.8), -18 + i * 9, 45, 0, g)
    return g



# ---------------------------------------------------------------- jungle d'émeraude
JUNGLE = [0x1e6a2a, 0x2a7a30, 0x1a5a24, 0x2e8a3a]


def palm(seed):
    rnd = mk(seed * 53 + 3)
    g = Node('Tree')
    bark = pick(rnd, [0x8a6a44, 0x7a5a3a, 0x9a7a50])
    h = 34 + int(rnd() * 12)
    lean = (rnd() - 0.5) * 6
    for i in range(int(h / 4)):
        V(5 - (i % 2) * 0.6, 4, 5 - (i % 2) * 0.6, bark if i % 2 else shade(bark, 0.9), lean * i / (h / 4), 2 + i * 4, 0, g)
    top = (lean, h, 0)
    for k in range(6):
        a = k * 1.047 + rnd() * 0.3
        import math
        dx, dz = math.cos(a), math.sin(a)
        for j in range(4):
            V(5 - j * 0.6, 1.4, 3.2, pick(rnd, JUNGLE), top[0] + dx * (3 + j * 3.6), top[1] + 1 - j * 1.4, dz * (3 + j * 3.6), g, ry=-a)
    for d in ((1.5, 0), (-1.2, 1.2), (0, -1.5)):
        V(2.2, 2.2, 2.2, 0x6a4a2a, top[0] + d[0], top[1] - 1.5, d[1], g)
    return g


def jungle_tree(seed):
    """Grand arbre de la jungle : tronc épais, contreforts, canopée en étages et lianes."""
    rnd = mk(seed * 59 + 7)
    g = Node('Tree')
    bark = pick(rnd, [0x5a4a34, 0x4e4030, 0x6a5a40])
    h = 44 + int(rnd() * 14)
    trunk(g, rnd, h, 8, bark)
    for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        V(2 + abs(dz) * 6, 10, 2 + abs(dx) * 6, shade(bark, 0.9), dx * 5, 5, dz * 5, g)
    for lvl, (y, w) in enumerate(((h - 8, 34), (h, 28), (h + 7, 18))):
        V(w, 7, w, pick(rnd, JUNGLE), (rnd() - 0.5) * 4, y, (rnd() - 0.5) * 4, g)
        V(w - 6, 3, w - 6, shade(pick(rnd, JUNGLE), 1.15), 0, y + 4.6, 0, g)
    for k in range(5):
        x = (rnd() - 0.5) * 26
        z = (rnd() - 0.5) * 26
        l = 10 + int(rnd() * 14)
        V(1, l, 1, 0x2a5a1a, x, h - 10 - l / 2, z, g)
        if rnd() < 0.5:
            V(2, 2, 2, pick(rnd, [0xd02a5a, 0xf0b020, 0xf06a2a]), x, h - 10 - l, z, g)
    return g


def fern(seed):
    rnd = mk(seed * 61 + 11)
    g = Node('Plant')
    import math
    for k in range(7):
        a = k * 0.9 + rnd() * 0.4
        c = pick(rnd, JUNGLE)
        for j in range(3):
            V(2.6 - j * 0.5, 1, 3, shade(c, 1 + j * 0.06), math.cos(a) * (2 + j * 2.6), 2 + j * 1.6 - (j * j) * 0.4, math.sin(a) * (2 + j * 2.6), g, ry=-a)
    V(2, 3, 2, 0x2a5a1a, 0, 1.5, 0, g)
    return g


def mossy_rock(seed):
    g = rock(seed + 40)
    for b in list(g.boxes):
        if b['h'] >= 4:
            V(b['w'] * 0.9, 1.4, b['d'] * 0.9, pick(mk(seed * 7 + int(b['w'])), [0x3a7a2a, 0x2e6a24, 0x4a8a34]), b['x'], b['y'] + b['h'] / 2 + 0.6, b['z'], g)
    return g

CHERRY = [0xf0a8c8, 0xe890b8, 0xf8c0d8, 0xd87aa8]
MAGIC = [0x4ad0c0, 0x6ae0d8, 0x3ab0b0, 0x8a6ae0]
SWAMP = [0x4a5a2a, 0x3e4e24, 0x56663a, 0x5a6a30]

PROPS = {
    'pine_snow_1': lambda: pine_snow(1), 'pine_snow_2': lambda: pine_snow(2),
    'dead_tree_1': lambda: dead_tree(1), 'dead_tree_2': lambda: dead_tree(2),
    'cactus_1': lambda: cactus(1), 'cactus_2': lambda: cactus(2), 'cactus_3': lambda: cactus(3),
    'mushroom_red': lambda: mushroom(1), 'mushroom_blue': lambda: mushroom(2, 0x4a6ad8),
    'mushroom_purple': lambda: mushroom(3, 0x9a4ad0),
    'cherry_1': lambda: oak_colored(5, CHERRY), 'cherry_2': lambda: oak_colored(6, CHERRY),
    'magic_tree_1': lambda: oak_colored(7, MAGIC), 'magic_tree_2': lambda: oak_colored(9, MAGIC),
    'swamp_tree_1': lambda: oak_colored(8, SWAMP), 'swamp_tree_2': lambda: oak_colored(10, SWAMP),
    'reeds_1': lambda: reeds(1), 'reeds_2': lambda: reeds(2),
    'dry_grass_1': lambda: dry_grass(1),
    'crystal_blue': lambda: crystal(1), 'crystal_pink': lambda: crystal(2, 0xf07ad0),
    'lava_rock_1': lambda: lava_rock(1), 'lava_rock_2': lambda: lava_rock(2),
    'snow_rock_1': lambda: snow_rock(1), 'snow_rock_2': lambda: snow_rock(2),
    'obelisk': obelisk, 'dungeon_gate': dungeon_gate,
    'palm_1': lambda: palm(1), 'palm_2': lambda: palm(2),
    'jungle_tree_1': lambda: jungle_tree(1), 'jungle_tree_2': lambda: jungle_tree(2),
    'fern_1': lambda: fern(1), 'fern_2': lambda: fern(2), 'mossy_rock_1': lambda: mossy_rock(1), 'mossy_rock_2': lambda: mossy_rock(2),
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='../assets/environment/models')
    ap.add_argument('--only', default='', help='noms séparés par des virgules (par défaut : tous)')
    a = ap.parse_args()
    only = [n for n in a.only.split(',') if n]
    os.makedirs(a.out, exist_ok=True)
    for name, fn in PROPS.items():
        if only and name not in only:
            continue
        export_glb(fn(), os.path.join(a.out, name + '.glb'))
    print('%d décor(s) .glb écrit(s) dans %s' % (len(PROPS), a.out))


if __name__ == '__main__':
    main()
