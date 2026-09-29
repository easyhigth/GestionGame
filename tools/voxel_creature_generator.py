#!/usr/bin/env python3
"""
Générateur des créatures voxel (loups, sangliers...) -> fichiers .glb pour Godot 4.

Même style que les personnages : uniquement des boîtes, 1 unité = 1 voxel = 5 cm.
Les créatures à quatre pattes gardent les noms du squelette des personnages pour être animées
par le même script (scripts/voxel_character.gd) :
    Root > LegL, LegR (pattes arrière), Torso > (ArmL, ArmR = pattes avant), Head
La créature regarde vers +Z.

Usage :
    python voxel_creature_generator.py --out ../assets/characters/creatures
"""
import argparse, os
from voxel_character_generator import Node, V, VG, export_glb, shade


def leg(pa, name, x, z, top, h, w, c, claw):
    n = pa.add(Node(name, (x, top, z)))
    V(w + 0.6, h * 0.5, w + 0.8, c, 0, -h * 0.25, 0, n)
    V(w, h * 0.5, w, shade(c, 0.92), 0, -h * 0.75, 0.2, n)
    V(w + 0.4, 1.4, w + 1.6, shade(c, 0.8), 0, -h + 0.7, 0.8, n)
    for dx in (-0.8, 0.8):
        V(0.6, 0.6, 0.8, claw, dx, -h + 0.3, w / 2 + 1.4, n)
    return n


def wolf(c, belly, eye, scale=1.0, mane=None):
    g = Node('Root', (0, 9 * scale, 0))
    g.scale = scale
    for name, x in (('LegL', 3.2), ('LegR', -3.2)):
        leg(g, name, x, -7.5, 0, 9, 3, c, 0xe8e0c8)
    top = g.add(Node('Torso'))
    V(10, 8, 22, c, 0, 4, 0, top)
    V(8.6, 2.2, 18, shade(c, 1.1), 0, 8.6, -0.5, top)
    V(8, 2, 16, belly, 0, 0.2, 1, top)
    V(11.4, 9.6, 8, mane or shade(c, 0.9), 0, 5, 7, top)
    for i in range(5):
        V(2, 1.6 + (i % 2), 2, shade(c, 0.8), 0, 9.4 + (i % 2) * 0.4, 8 - i * 3.6, top)
    # queue touffue
    for i, (y, z, w) in enumerate(((6, -12, 3), (5, -14.5, 3.6), (3.4, -16.8, 3.4), (1.6, -18.6, 2.6))):
        V(w, w, 3, c if i < 3 else belly, 0, y, z, top)
    for name, x in (('ArmL', 3.4), ('ArmR', -3.4)):
        leg(top, name, x, 7.5, 0.5, 9.5, 3, c, 0xe8e0c8)
    h = top.add(Node('Head', (0, 8.5, 12.5)))
    V(8, 7, 8, c, 0, 0, 0, h)
    V(8.8, 3, 6, mane or shade(c, 0.9), 0, -2.4, -2, h)
    V(4.6, 3.6, 6, shade(c, 1.05), 0, -1.4, 6.4, h)
    V(4, 1.4, 5.4, belly, 0, -3.2, 6, h)
    V(1.8, 1.4, 1, 0x1a1414, 0, -0.2, 9.5, h)
    for s in (-1, 1):
        VG(1.4, 1, 0.5, eye, s * 2.2, 1.2, 4.1, h)
        V(2, 0.6, 0.6, shade(c, 0.6), s * 2.2, 2.2, 4.1, h)
        V(2.2, 3.6, 1.4, c, s * 2.4, 5, -1.6, h)
        V(1.2, 2, 0.8, 0xc89090, s * 2.4, 4.8, -0.9, h)
        V(0.6, 1.4, 0.6, 0xf4f0e0, s * 1.4, -3, 8.2, h)
    return g


def boar(c, eye):
    g = Node('Root', (0, 7, 0))
    for name, x in (('LegL', 3.6), ('LegR', -3.6)):
        leg(g, name, x, -7, 0, 7, 3.4, shade(c, 0.9), 0x2a2220)
    top = g.add(Node('Torso'))
    V(12, 10, 22, c, 0, 5, 0, top)
    V(13, 11, 9, shade(c, 0.85), 0, 5.6, 5.5, top)
    V(10, 2, 18, shade(c, 1.1), 0, 0.4, 0, top)
    for i in range(7):
        V(2, 2.2 + (i % 2) * 1.2, 2.2, 0x2a2220, 0, 11 + (i % 2) * 0.5, 9 - i * 3, top)
    V(1.2, 1.2, 4, 0x3a2a22, 0, 7, -12.5, top, rx=0.6)
    for name, x in (('ArmL', 3.8), ('ArmR', -3.8)):
        leg(top, name, x, 7.5, 0.5, 7.5, 3.4, shade(c, 0.9), 0x2a2220)
    h = top.add(Node('Head', (0, 5.5, 12.5)))
    V(9, 8, 8, c, 0, 0, 0, h)
    V(6, 4.6, 4, shade(c, 1.1), 0, -1.4, 5.8, h)
    V(5, 3.4, 1, 0xc88a7a, 0, -1.4, 8.2, h)
    for s in (-1, 1):
        V(0.9, 1.2, 0.5, 0x3a2220, s * 1.2, -1.4, 8.8, h)
        VG(1.2, 1, 0.5, eye, s * 2.6, 1.6, 4.1, h)
        V(2.2, 2.6, 1.2, shade(c, 0.8), s * 3.4, 4.4, -1, h, rz=-s * 0.4)
        V(1, 3.6, 1, 0xf4ecd8, s * 3.4, -1.2, 6.8, h, rx=0.3)
        V(0.8, 1.6, 0.8, 0xf4ecd8, s * 3.4, 1.4, 7.4, h)
    return g


def slime(c, core, eye, scale=1.0, glow=False):
    """Slime : une goutte de gel translucide avec un noyau. Pattes et bras cachés dans le corps."""
    from voxel_character_generator import VA
    g = Node('Root', (0, 2 * scale, 0))
    g.scale = scale
    for name, x in (('LegL', 3), ('LegR', -3)):
        n = g.add(Node(name, (x, 0, -2)))
        V(3, 2, 4, shade(c, 0.8), 0, -1, 0, n)
    top = g.add(Node('Torso'))
    VA(18, 6, 18, c, 0, 1, 0, top, alpha=0.78, glow=glow)
    VA(16, 5, 16, shade(c, 1.08), 0, 6, 0, top, alpha=0.78, glow=glow)
    VA(12, 4, 12, shade(c, 1.15), 0, 10, 0, top, alpha=0.78, glow=glow)
    VA(6, 3, 6, shade(c, 1.25), 0, 13, -1, top, alpha=0.8, glow=glow)
    V(6, 6, 6, core, 0, 5, -1, top, glow=glow)
    V(3, 2, 3, 0xffffff, -4, 11, 3, top)
    for name, x in (('ArmL', 7), ('ArmR', -7)):
        n = top.add(Node(name, (x, 4, 2)))
        VA(4, 4, 4, c, 0, -1, 0, n, alpha=0.78, glow=glow)
    h = top.add(Node('Head', (0, 7, 7)))
    for sx in (-1, 1):
        V(2.6, 3.4, 1, 0x141418, sx * 3, 0, 2.1, h)
        V(1, 1, 0.6, 0xffffff, sx * 3 + 0.5, 1, 2.6, h)
    V(3, 0.8, 0.6, shade(c, 0.5), 0, -2.6, 2.1, h)
    return g


def spider(c, mark, eye):
    g = Node('Root', (0, 8, 0))
    for name, x in (('LegL', 5), ('LegR', -5)):
        n = g.add(Node(name, (x, 0, -3)))
        V(1.8, 1.8, 8, c, x * 0.3, 2, -2, n, rx=-0.5)
        V(1.6, 9, 1.6, shade(c, 0.85), x * 0.5, -4, -6, n)
    top = g.add(Node('Torso'))
    V(12, 8, 10, c, 0, 2, 3, top)
    V(18, 13, 18, shade(c, 0.9), 0, 5, -12, top)
    V(8, 1, 8, mark, 0, 11.6, -12, top, glow=True)
    V(4, 1, 10, mark, 0, 11.4, -12, top, glow=True)
    for i in range(10):
        V(1, 2, 1, shade(c, 1.3), (i % 5 - 2) * 3.4, 12, -6 - (i // 5) * 10, top)
    # pattes du milieu (fixes)
    for sx in (-1, 1):
        for z in (0, 4):
            V(9, 1.6, 1.6, c, sx * 9, 5, z, top, rz=sx * 0.5)
            V(1.6, 9, 1.6, shade(c, 0.85), sx * 13.5, -1, z, top)
    for name, x in (('ArmL', 5), ('ArmR', -5)):
        n = top.add(Node(name, (x, 3, 6)))
        V(1.8, 1.8, 8, c, x * 0.3, 2, 3, n, rx=0.5)
        V(1.6, 9, 1.6, shade(c, 0.85), x * 0.5, -4, 7, n)
    h = top.add(Node('Head', (0, 3, 9)))
    V(8, 6, 6, shade(c, 1.05), 0, 0, 0, h)
    for sx, sy in ((-1.6, 1.2), (1.6, 1.2), (-2.8, 0), (2.8, 0), (-1, -0.8), (1, -0.8)):
        VG(1.2, 1.2, 0.6, eye, sx, sy, 3.1, h)
    for sx in (-1, 1):
        V(1.4, 4, 1.4, 0x201818, sx * 1.6, -3.6, 3, h, rx=0.3)
    return g


def bear(c, belly, eye, scale=1.0):
    g = Node('Root', (0, 10 * scale, 0))
    g.scale = scale
    for name, x in (('LegL', 4.6), ('LegR', -4.6)):
        leg(g, name, x, -8, 0, 10, 5, shade(c, 0.92), 0x302824)
    top = g.add(Node('Torso'))
    V(16, 14, 26, c, 0, 6, 0, top)
    V(17, 15, 11, shade(c, 1.05), 0, 7.6, 6, top)
    V(12, 2, 20, belly, 0, -1.2, 0, top)
    for i in range(8):
        V(4, 2, 4, shade(c, 0.9 + (i % 3) * 0.08), ((i * 37) % 11) - 5, 13.4, ((i * 53) % 22) - 11, top)
    V(4, 4, 3, c, 0, 8, -14, top)
    for name, x in (('ArmL', 5), ('ArmR', -5)):
        leg(top, name, x, 8.5, 0.5, 10.5, 5, shade(c, 0.92), 0x302824)
    h = top.add(Node('Head', (0, 9, 15)))
    V(11, 10, 9, c, 0, 0, 0, h)
    V(6, 5, 5, belly, 0, -2, 6, h)
    V(2.6, 1.8, 1, 0x1a1414, 0, -0.6, 8.7, h)
    for s in (-1, 1):
        VG(1.4, 1.2, 0.5, eye, s * 2.8, 1.6, 4.6, h)
        V(3, 3, 2, c, s * 4.4, 5.6, -1, h)
        V(1.6, 1.6, 0.6, shade(belly, 0.8), s * 4.4, 5.6, 0.1, h)
    return g


def scorpion(c, tip, eye):
    g = Node('Root', (0, 5, 0))
    for name, x in (('LegL', 5), ('LegR', -5)):
        n = g.add(Node(name, (x, 0, -3)))
        V(7, 1.6, 1.6, c, x * 0.6, 1, 0, n, rz=(0.5 if x > 0 else -0.5))
        V(1.6, 5, 1.6, shade(c, 0.85), x * 1.2, -2.5, 0, n)
    top = g.add(Node('Torso'))
    V(14, 5, 20, c, 0, 1, 0, top)
    for i in range(4):
        V(15 - i, 1.4, 3.6, shade(c, 1.12), 0, 4.2, 7 - i * 4.6, top)
    for sx in (-1, 1):
        for z in (-6, -1, 4):
            V(7, 1.4, 1.4, c, sx * 9, 1, z, top, rz=sx * 0.5)
            V(1.4, 5, 1.4, shade(c, 0.85), sx * 12.5, -2, z, top)
    # queue qui se recourbe au-dessus du dos
    tail = [(0, 4, -12, 5), (0, 8, -15, 4.6), (0, 13, -16, 4.2), (0, 18, -14.5, 3.8), (0, 21.5, -11, 3.4)]
    for i, (x, y, z, w) in enumerate(tail):
        V(w, w, w, shade(c, 1.0 + 0.04 * i), x, y, z, top)
    V(3, 3, 3, tip, 0, 22, -7.5, top, glow=True)
    V(1.2, 1.2, 3, 0x1a1414, 0, 20.6, -5, top, rx=0.6)
    for name, x in (('ArmL', 5), ('ArmR', -5)):
        n = top.add(Node(name, (x, 2, 9)))
        V(2.4, 2.4, 7, c, x * 0.4, 0, 3, n)
        V(5, 4, 6, shade(c, 1.1), x * 0.6, 0, 9, n)
        V(1.6, 3, 4, shade(c, 0.9), x * 0.6 + (1.8 if x > 0 else -1.8), 0, 13, n)
        V(1.6, 3, 4, shade(c, 0.9), x * 0.6 - (1.2 if x > 0 else -1.2), 0, 12.4, n)
    h = top.add(Node('Head', (0, 2, 10)))
    V(8, 4, 4, shade(c, 0.95), 0, 0, 0, h)
    for s in (-1, 1):
        VG(1.2, 1.2, 0.5, eye, s * 1.6, 1.6, 2, h)
    return g


def salamander(c, belly, glow_c, eye):
    g = Node('Root', (0, 4, 0))
    for name, x in (('LegL', 5), ('LegR', -5)):
        leg(g, name, x, -6, 0, 4.5, 2.6, c, 0x2a1a14)
    top = g.add(Node('Torso'))
    V(10, 6, 20, c, 0, 2, 0, top)
    V(8, 1.4, 16, belly, 0, -1, 0, top)
    for i in range(6):
        V(2, 2.6 - (i % 2), 2, glow_c, 0, 6 - (i % 2) * 0.3, 8 - i * 3.4, top, glow=True)
    for i, (y, z, w) in enumerate(((2, -12, 6), (1.6, -16, 5), (1.2, -19.5, 4), (1, -22.5, 3), (1, -25, 2))):
        V(w, w * 0.8, 4, c, 0, y, z, top)
        V(1.6, 1.4, 1.6, glow_c, 0, y + w * 0.4 + 0.5, z, top, glow=True)
    for name, x in (('ArmL', 5), ('ArmR', -5)):
        leg(top, name, x, 6.5, 0.5, 5, 2.6, c, 0x2a1a14)
    h = top.add(Node('Head', (0, 3, 12)))
    V(8, 5, 8, c, 0, 0, 0, h)
    V(6, 2, 4, belly, 0, -2, 4, h)
    for s in (-1, 1):
        VG(1.6, 1.4, 1.4, eye, s * 3.6, 1.6, 2, h)
        V(1, 3, 1, glow_c, s * 2, 3.4, -2, h, glow=True)
    return g


CREATURES = {
    'wolf': lambda: wolf(0x8a8a8e, 0xd8d4cc, 0xffd24a),
    'wolf_alpha': lambda: wolf(0x3a3a40, 0x6a6a70, 0xff5a3a, 1.25, mane=0x24242a),
    'boar': lambda: boar(0x6a4a34, 0xff8a3a),
    'wolf_frost': lambda: wolf(0xc8dcec, 0xf4f8fc, 0x5ad8ff, 1.1, mane=0xeaf4fc),
    'slime_blue': lambda: slime(0x4aa8f0, 0x2a6ad0, 0xffffff),
    'slime_acid': lambda: slime(0x8ad040, 0x4a8a20, 0xffffff, 1.2),
    'slime_magma': lambda: slime(0xf06a2a, 0xffd040, 0xffffff, 1.35, glow=True),
    'spider': lambda: spider(0x2a2430, 0xd03a3a, 0xff3a3a),
    'bear_snow': lambda: bear(0xeef0f2, 0xc8ccd0, 0x3a8aff, 1.1),
    'scorpion': lambda: scorpion(0xc8963a, 0x8aff4a, 0x1a1a1a),
    'salamander': lambda: salamander(0x3a2220, 0x6a3a28, 0xff7a20, 0xffd040),
}



def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='../assets/characters/creatures')
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    for name, fn in CREATURES.items():
        export_glb(fn(), os.path.join(a.out, name + '.glb'))
    print('%d créature(s) -> %s' % (len(CREATURES), a.out))


if __name__ == '__main__':
    main()
