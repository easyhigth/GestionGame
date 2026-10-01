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


# ---------------------------------------------------------------- animaux de la ferme
def chicken(c, comb, scale=1.0):
    """Poule : deux pattes (LegL, LegR), ailes (ArmL, ArmR), tête avec crête et bec."""
    g = Node('Root', (0, 4 * scale, 0))
    g.scale = scale
    for name, x in (('LegL', 1.4), ('LegR', -1.4)):
        n = g.add(Node(name, (x, 0, -0.5)))
        V(0.8, 4, 0.8, 0xe8a030, 0, -2, 0, n)
        V(1.6, 0.5, 2.4, 0xe8a030, 0, -3.8, 0.8, n)
    top = g.add(Node('Torso'))
    V(6, 5.6, 7.4, c, 0, 3.4, 0, top)
    V(5, 2, 5, shade(c, 0.95), 0, 1, 0.4, top)
    V(4.6, 4.4, 2.6, shade(c, 0.9), 0, 5.4, -4.6, top, rx=-0.5)     # queue
    for name, x in (('ArmL', 3.2), ('ArmR', -3.2)):
        n = top.add(Node(name, (x, 4.6, 0)))
        V(1, 3.6, 5.2, shade(c, 0.88), 0, -1.4, -0.4, n)
    h = top.add(Node('Head', (0, 6.6, 3.2)))
    V(3.8, 4.4, 3.6, c, 0, 1.4, 0, h)
    V(1.2, 2.2, 3.4, comb, 0, 4.4, -0.2, h)                         # crête
    V(1.6, 1.2, 1.8, 0xf0b030, 0, 1.2, 2.6, h)                      # bec
    V(1, 1.4, 0.8, comb, 0, -0.4, 2.2, h)                           # barbillon
    for s in (-1, 1):
        V(0.6, 0.8, 0.8, 0x1a1414, s * 1.95, 2.2, 1, h)
    return g


def sheep(wool, skin):
    """Mouton : toison bouclée, tête et pattes sombres."""
    g = Node('Root', (0, 7, 0))
    for name, x in (('LegL', 3.2), ('LegR', -3.2)):
        leg(g, name, x, -6, 0, 7, 2.6, skin, shade(skin, 0.7))
    top = g.add(Node('Torso'))
    V(13, 11, 20, wool, 0, 5, 0, top)
    for x, y, z in ((-5, 10, -6), (5, 10, 4), (0, 11, -1), (-4, 9, 7), (4, 9.5, -8), (0, 1, 8), (6, 4, -3), (-6, 5, 2)):
        V(4.4, 3.6, 4.4, shade(wool, 0.94), x, y, z, top)
    V(3, 3, 2.4, wool, 0, 7, -11, top)
    for name, x in (('ArmL', 3.2), ('ArmR', -3.2)):
        leg(top, name, x, 6.5, 0.5, 7.5, 2.6, skin, shade(skin, 0.7))
    h = top.add(Node('Head', (0, 7.5, 11)))
    V(6, 6.6, 7, skin, 0, 0, 1, h)
    V(7.4, 3.4, 5, wool, 0, 3.8, -0.6, h)
    V(4.6, 3, 2, shade(skin, 1.2), 0, -1.6, 4.4, h)
    for s in (-1, 1):
        V(0.6, 1, 0.5, 0xf0e6d2, s * 1.9, 1, 4.6, h)
        V(0.4, 0.6, 0.5, 0x1a1414, s * 1.9, 1, 4.9, h)
        V(3.4, 1.4, 1.8, skin, s * 4.2, 1.6, -0.6, h, rz=s * 0.3)
    return g


def cow(c, spot, horn):
    """Vache : grande, taches, cornes courtes, mufle rose, pis."""
    g = Node('Root', (0, 10, 0))
    for name, x in (('LegL', 4.4), ('LegR', -4.4)):
        leg(g, name, x, -9, 0, 10, 3.6, c, 0x3a2a22)
    top = g.add(Node('Torso'))
    V(14, 12, 26, c, 0, 6, 0, top)
    for x, y, z, w, d in ((7.1, 7, -4, 0.6, 8), (-7.1, 5, 5, 0.6, 7), (3, 12.1, 2, 7, 6), (-7.1, 8, -8, 0.6, 5), (7.1, 4, 7, 0.6, 5)):
        V(w if w < 1 else w, 5 if w < 1 else 0.6, d, spot, x, y, z, top)
    V(6, 3, 6, 0xf0a8a8, 0, -0.6, -5, top)                          # pis
    V(1.2, 9, 1.2, c, 0, 5, -13.4, top, rx=0.25)                      # queue
    V(2, 2.4, 2, spot, 0, 0.6, -14.6, top)
    for name, x in (('ArmL', 4.4), ('ArmR', -4.4)):
        leg(top, name, x, 9, 0.5, 10.5, 3.6, c, 0x3a2a22)
    h = top.add(Node('Head', (0, 9, 14.5)))
    V(9, 9, 8, c, 0, 0, 1, h)
    V(8, 4, 3.6, 0xf0b0a8, 0, -2.6, 5.8, h)                           # mufle
    V(4, 3, 0.6, spot, 1.5, 2.8, 5.1, h)
    for s in (-1, 1):
        V(0.8, 0.8, 0.6, 0x5a2a2a, s * 1.8, -2.2, 7.7, h)
        V(1, 1, 0.6, 0x1a1414, s * 3, 1.4, 5.1, h)
        V(3.6, 1.8, 2, c, s * 5.6, 2.4, 0.6, h)                       # oreilles
        V(1.4, 3, 1.4, horn, s * 3.6, 5.6, 0, h, rz=-s * 0.35)        # cornes
    return g


def horse(c, mane, hoof=0x2a2220, saddle=None):
    """Cheval : grand, long cou, crinière et queue ; selle en option (cheval apprivoisé)."""
    g = Node('Root', (0, 14, 0))
    for name, x in (('LegL', 3.6), ('LegR', -3.6)):
        leg(g, name, x, -10, 0, 14, 3.2, c, hoof)
    top = g.add(Node('Torso'))
    V(11, 11, 28, c, 0, 5, 0, top)
    V(10, 2, 24, shade(c, 1.08), 0, 10.4, 0, top)
    V(1.6, 12, 3, mane, 0, 3, -15, top, rx=0.35)                      # queue
    V(2.4, 5, 3.4, mane, 0, 8.5, -14.6, top)
    if saddle:
        V(11.6, 2, 9, saddle, 0, 11, 2, top)
        V(12, 5, 1, shade(saddle, 0.8), 0, 8, 2, top)
    for name, x in (('ArmL', 3.6), ('ArmR', -3.6)):
        leg(top, name, x, 10.5, 0.5, 14.5, 3.2, c, hoof)
    neck = top.add(Node('Head', (0, 10, 13)))
    V(6, 12, 6, c, 0, 4, 1, neck, rx=-0.45)
    V(1.8, 12, 4, mane, 0, 5.5, -1.6, neck, rx=-0.45)
    V(6, 6, 11, c, 0, 10, 6.5, neck)
    V(5, 4, 4, shade(c, 0.85), 0, 8.6, 11.4, neck)
    for s in (-1, 1):
        V(0.8, 0.8, 0.6, 0x1a1414, s * 3.05, 11, 7, neck)
        V(1.4, 3, 1.2, c, s * 1.8, 14.5, 3, neck)
        V(0.6, 0.6, 0.4, 0x3a2a22, s * 1.4, 8.4, 13.5, neck)
    return g


# ---------------------------------------------------------------- jungle d'émeraude

def panther(c, spot, eye, scale=1.0):
    """Panthère : un félin long et bas, longue queue, taches."""
    g = Node('Root', (0, 8 * scale, 0))
    g.scale = scale
    for name, x in (('LegL', 3), ('LegR', -3)):
        leg(g, name, x, -8, 0, 8, 2.6, c, 0xe8e0c8)
    top = g.add(Node('Torso'))
    V(9, 7, 24, c, 0, 3.6, 0, top)
    V(7.6, 2, 20, shade(c, 1.12), 0, 7.4, -0.5, top)
    V(7, 1.6, 18, shade(c, 0.85), 0, 0.2, 1, top)
    for i, (x, z) in enumerate(((2, 6), (-2.6, 2), (2.4, -3), (-2, -7), (0.4, -10), (3, -12), (-3, 9))):
        V(2, 0.6, 2, spot, x, 7.5 + (i % 2) * 0.2, z, top)
    # longue queue relevée
    for i, (y, z) in enumerate(((5, -13), (6, -15.5), (7.4, -17.8), (9.2, -19.6), (11.4, -20.6))):
        V(2.2, 2.2, 3, c if i < 4 else spot, 0, y, z, top)
    for name, x in (('ArmL', 3.1), ('ArmR', -3.1)):
        leg(top, name, x, 8.5, 0.5, 8.5, 2.6, c, 0xe8e0c8)
    h = top.add(Node('Head', (0, 7.4, 13.6)))
    V(7.4, 6, 7, c, 0, 0, 0, h)
    V(4.6, 3, 4.4, shade(c, 1.08), 0, -1.4, 5, h)
    V(1.6, 1.2, 0.8, 0x1a1414, 0, -0.4, 7.4, h)
    for s in (-1, 1):
        VG(1.6, 1.1, 0.5, eye, s * 2, 1, 3.6, h)
        V(2, 2.6, 1.2, c, s * 2.4, 4, -1.2, h)
        V(0.5, 2, 0.5, 0xf4f0e0, s * 1.2, -3, 6.2, h)
        V(3, 0.3, 0.3, 0xe8e0d0, s * 3.6, -1.2, 5.2, h)
    return g


def frog(c, belly, mark, eye, scale=1.0):
    """Grenouille venimeuse : trapue, grosses pattes arrière, gros yeux, taches vives."""
    g = Node('Root', (0, 4 * scale, 0))
    g.scale = scale
    for name, x in (('LegL', 5), ('LegR', -5)):
        n = g.add(Node(name, (x, 0, -4)))
        V(4, 4, 8, c, 0, -1, 0, n)
        V(5, 1.4, 5, shade(c, 0.85), 0, -3.4, 3, n)
    top = g.add(Node('Torso'))
    V(14, 8, 14, c, 0, 2.6, 0, top)
    V(12, 3, 12, belly, 0, -1, 1, top)
    for x, z in ((3, 2), (-3.4, -2), (0, -4.6), (4, -3), (-4, 3)):
        VG(2.4, 0.6, 2.4, mark, x, 6.8, z, top)
    for name, x in (('ArmL', 5.4), ('ArmR', -5.4)):
        n = top.add(Node(name, (x, 0, 5)))
        V(2.4, 4, 2.4, c, 0, -2, 0, n)
        V(3.4, 1, 3.4, shade(c, 0.85), 0, -4.2, 1, n)
    h = top.add(Node('Head', (0, 4.6, 7)))
    V(12, 5, 6, c, 0, 0, 0, h)
    V(11, 1, 5, 0x3a1a1a, 0, -1.6, 1.4, h)
    for s in (-1, 1):
        V(3.6, 3.6, 3.6, c, s * 3.6, 3, -0.4, h)
        VG(2.4, 2.4, 1, eye, s * 3.6, 3.2, 1.5, h)
        V(1, 1.6, 0.6, 0x141414, s * 3.6, 3.2, 2.1, h)
    return g


def snake(c, belly, pattern, eye, scale=1.0, crest=None, wings=None):
    """Serpent : un long corps qui ondule (pattes cachées). crest : plumes sur la tête ; wings : ailes de plumes."""
    g = Node('Root', (0, 3 * scale, 0))
    g.scale = scale
    for name, x in (('LegL', 1.5), ('LegR', -1.5)):
        n = g.add(Node(name, (x, 0, -6)))
        V(2, 1, 2, shade(c, 0.8), 0, -2, 0, n)
    top = g.add(Node('Torso'))
    pts = [(0, 1.4, 6), (1.6, 1.2, 2), (2.6, 1.2, -2.5), (1.4, 1.1, -7), (-1.2, 1.0, -11), (-2.8, 0.9, -15), (-1.6, 0.8, -19), (0.8, 0.7, -22.5)]
    for i, (x, y, z) in enumerate(pts):
        w = 6.4 - i * 0.55
        V(w, w * 0.8, 5, c, x, y + w * 0.4, z, top)
        V(w * 0.7, 0.6, 4.4, belly, x, y + 0.1, z, top)
        if i % 2 == 0:
            V(w * 0.5, 0.5, 2, pattern, x, y + w * 0.82, z, top)
    # le cou se dresse
    for i, (y, z) in enumerate(((5, 9), (8, 10.5), (10.6, 11.6))):
        V(5.4, 4, 4, c, 0, y, z, top)
        V(3.6, 3, 0.6, belly, 0, y, z + 2.2, top)
    if wings:
        for name, sx in (('ArmL', 1), ('ArmR', -1)):
            n = top.add(Node(name, (sx * 3, 8, 6)))
            for j in range(5):
                V(2.4, 1, 6 - j * 0.6, wings[j % len(wings)], sx * (2 + j * 2.4), 1 + j * 0.8, -1 - j * 0.8, n, rz=sx * 0.3)
    else:
        for name, sx in (('ArmL', 1), ('ArmR', -1)):
            n = top.add(Node(name, (sx * 2, 4, 6)))
            V(1, 1, 1, c, 0, 0, 0, n)
    h = top.add(Node('Head', (0, 13.4, 13)))
    V(6.4, 4.4, 7, c, 0, 0, 0, h)
    V(5.4, 2.6, 4, shade(c, 1.08), 0, -0.8, 4.4, h)
    V(0.6, 0.4, 2.4, 0xd02a3a, 0, -1.4, 7.2, h)
    for s in (-1, 1):
        VG(1.4, 1.2, 0.6, eye, s * 2.6, 1, 2.6, h)
        V(0.5, 1.8, 0.5, 0xf4f0e0, s * 1.4, -2.6, 5, h)
    if crest:
        for j, cc in enumerate(crest):
            V(1.2, 5 - j * 0.6, 1.2, cc, (j - len(crest) / 2) * 1.3, 4.4 - j * 0.1, -2 - j * 0.4, h, rx=-0.5)
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
    'chicken': lambda: chicken(0xf4f0e6, 0xd8302a),
    'chicken_brown': lambda: chicken(0xb8743a, 0xd8302a),
    'sheep': lambda: sheep(0xf2eee4, 0x3a3230),
    'cow': lambda: cow(0xf4f0e8, 0x2a2624, 0xe8dcc0),
    'cow_brown': lambda: cow(0x9a5a32, 0xf4f0e8, 0xe8dcc0),
    'horse_brown': lambda: horse(0x8a5a32, 0x3a2418),
    'horse_white': lambda: horse(0xe8e4dc, 0xb8b0a0, 0x5a5048),
    'horse_black': lambda: horse(0x2e2a2a, 0x141212),
    'horse_brown_saddle': lambda: horse(0x8a5a32, 0x3a2418, saddle=0x8a2a2a),
    'horse_white_saddle': lambda: horse(0xe8e4dc, 0xb8b0a0, 0x5a5048, saddle=0x2a4a9a),
    'horse_black_saddle': lambda: horse(0x2e2a2a, 0x141212, saddle=0xc8a040),
    'panther': lambda: panther(0x24222a, 0x14121a, 0xffd24a),
    'frog': lambda: frog(0x2ab8e0, 0xf0e070, 0x141414, 0x141414),
    'snake': lambda: snake(0x4a8a2a, 0xe0d070, 0x2a4a1a, 0xffd24a),
    'snake_king': lambda: snake(0xd0a020, 0xf4e8b0, 0x1a1a1a, 0xff3a2a, 1.3, crest=[0xd02a2a, 0xf0b020]),
    'feathered_serpent': lambda: snake(0x2ab88a, 0xf0e070, 0xd02a3a, 0xffd24a, 1.0,
                                       crest=[0xd02a3a, 0xf0b020, 0x2a8ad0, 0x2ac84a, 0xd02a3a],
                                       wings=[0x2ac84a, 0x2a8ad0, 0xf0b020, 0xd02a3a]),
}



def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='../assets/characters/creatures')
    ap.add_argument('--only', default='', help='noms séparés par des virgules (par défaut : toutes)')
    a = ap.parse_args()
    only = [n for n in a.only.split(',') if n]
    os.makedirs(a.out, exist_ok=True)
    for name, fn in CREATURES.items():
        if only and name not in only:
            continue
        export_glb(fn(), os.path.join(a.out, name + '.glb'))
    print('%d créature(s) -> %s' % (len(CREATURES), a.out))


if __name__ == '__main__':
    main()
