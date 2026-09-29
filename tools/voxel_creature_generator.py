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


CREATURES = {
    'wolf': lambda: wolf(0x8a8a8e, 0xd8d4cc, 0xffd24a),
    'wolf_alpha': lambda: wolf(0x3a3a40, 0x6a6a70, 0xff5a3a, 1.25, mane=0x24242a),
    'boar': lambda: boar(0x6a4a34, 0xff8a3a),
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
