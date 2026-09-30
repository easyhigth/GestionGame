#!/usr/bin/env python3
"""
Meubles voxel pour la construction (1 case = 1 m = 20 voxels). Origine au sol, au centre de la case,
façade vers +Z. Même style que les personnages et les décors.

Usage :
    python voxel_furniture_generator.py --out ../assets/furniture
"""
import argparse, math, os
from voxel_character_generator import Node, V, VG, VA, export_glb, shade

WOOD = 0x9a6a3a
WOOD_D = 0x6a4428
WOOD_L = 0xb88a50
IRON = 0x8a9098
IRON_D = 0x4e5258
STONE = 0x8e8c86
STONE_D = 0x6e6c68
FIRE = 0xff7a20
CLOTH_R = 0xa02a2a
CLOTH_B = 0x2a4a9a
STRAW = 0xd8b060
GOLD = 0xd8b04a


def leg4(g, w, d, h, c, t=2):
    for sx in (-1, 1):
        for sz in (-1, 1):
            V(t, h, t, c, sx * (w / 2 - t / 2), h / 2, sz * (d / 2 - t / 2), g)


def porte():
    g = Node('Porte')
    V(16, 38, 2, WOOD, 0, 19, 0, g)
    for x in (-5, 0, 5):
        V(1, 36, 2.4, WOOD_D, x, 19, 0, g)
    for y in (8, 30):
        V(16, 2, 2.6, IRON_D, 0, y, 0, g)
    V(2, 2, 2, GOLD, 5.5, 19, 1.6, g)
    # encadrement
    V(2, 40, 3, WOOD_D, -9, 20, 0, g)
    V(2, 40, 3, WOOD_D, 9, 20, 0, g)
    V(20, 2, 3, WOOD_D, 0, 39, 0, g)
    return g


def lit():
    g = Node('Lit')
    V(16, 5, 19, WOOD, 0, 5, 0, g)
    leg4(g, 16, 19, 4, WOOD_D)
    V(15, 3, 14, 0xe8e0d0, 0, 9, 2, g)
    V(15.4, 2, 11, CLOTH_R, 0, 10.5, 3.5, g)
    V(10, 2.5, 4, 0xf4f0e8, 0, 11, -6.5, g)
    V(16, 10, 2, WOOD_D, 0, 9, -9, g)
    return g


def coffre():
    g = Node('Coffre')
    V(16, 9, 11, WOOD, 0, 4.5, 0, g)
    V(16.4, 4, 11.4, WOOD_L, 0, 11, 0, g)
    for x in (-7, 7):
        V(1.4, 13, 11.8, IRON_D, x, 6.5, 0, g)
    V(3, 3, 1, GOLD, 0, 9, 6, g)
    return g


def table():
    g = Node('Table')
    V(18, 2, 14, WOOD_L, 0, 15, 0, g)
    leg4(g, 16, 12, 14, WOOD_D)
    V(3, 3, 3, 0xd8d0c0, -4, 17.5, 1, g)
    V(2, 4, 2, 0x8a4a2a, 4, 18, -2, g)
    return g


def chaise():
    g = Node('Chaise')
    V(9, 2, 9, WOOD_L, 0, 9, 0, g)
    leg4(g, 9, 9, 8, WOOD_D, 1.6)
    V(9, 10, 1.6, WOOD, 0, 15, -3.8, g)
    return g


def tonneau():
    g = Node('Tonneau')
    for w, y in ((12, 0), (14, 4), (15, 8), (15, 12), (14, 16), (12, 20)):
        V(w, 4, w, WOOD if (y // 4) % 2 else shade(WOOD, 0.9), 0, y + 2, 0, g)
    for y in (3, 21):
        V(15.5, 1.5, 15.5, IRON_D, 0, y, 0, g)
    V(3, 3, 2, WOOD_D, 0, 8, 7.8, g)
    return g


def torche():
    g = Node('Torche')
    V(2.4, 26, 2.4, WOOD_D, 0, 13, 0, g)
    V(5, 3, 5, IRON_D, 0, 26, 0, g)
    flame = g.add(Node('Flame', (0, 28, 0)))
    VG(3.5, 4, 3.5, FIRE, 0, 2, 0, flame)
    VG(2, 3, 2, 0xffd860, 0, 5, 0, flame)
    V(8, 2, 8, STONE_D, 0, 1, 0, g)
    return g


def enclume():
    g = Node('Enclume')
    V(10, 7, 10, WOOD_D, 0, 3.5, 0, g)
    V(6, 4, 5, IRON_D, 0, 9, 0, g)
    V(14, 4, 6, 0x4a4e56, 0, 13, 0, g)
    V(5, 3, 4, 0x4a4e56, 9, 13.5, 0, g)
    V(2, 1, 8, 0xc0c4cc, -3, 15.5, 0, g, ry=0.5)
    V(1.2, 7, 1.2, WOOD, -3, 17, 2, g, rz=0.9)
    return g


def foyer_forge():
    g = Node('FoyerForge')
    V(18, 12, 16, STONE, 0, 6, 0, g)
    V(14, 2, 12, 0x2a2420, 0, 12.5, 1, g)
    VG(10, 2, 8, FIRE, 0, 13.2, 1, g)
    VG(6, 2, 4, 0xffc040, 0, 14.5, 1, g)
    V(12, 22, 8, STONE_D, 0, 24, -4, g)
    V(8, 8, 6, STONE_D, 0, 38, -4, g)
    V(6, 4, 6, 0x5a3a2a, 11, 4, 4, g)  # soufflet
    for i in range(4):
        V(18.4, 1, 16.4, shade(STONE, 0.85), 0, 2 + i * 3, 0, g)
    return g


def etabli():
    g = Node('Etabli')
    V(19, 3, 12, WOOD_L, 0, 15, 0, g)
    leg4(g, 18, 11, 14, WOOD_D, 2.4)
    V(16, 2, 10, WOOD_D, 0, 4, 0, g)
    V(8, 1.2, 1.5, IRON, -4, 17, 2, g)
    V(2, 2, 3, IRON_D, -1, 17.2, 2, g)
    V(1.2, 1.2, 7, WOOD_D, 4, 17, -1, g, ry=0.4)
    V(4, 2.5, 3, IRON_D, 6, 17.4, 2, g)
    return g


def table_tailleur():
    g = Node('TableTailleur')
    V(18, 3, 14, STONE_D, 0, 14, 0, g)
    leg4(g, 17, 13, 13, WOOD_D, 2.4)
    V(8, 5, 6, STONE, -3, 18, 0, g)
    V(4, 4, 4, shade(STONE, 1.1), 5, 17.5, 2, g)
    V(1, 6, 1, WOOD, 5, 20, -3, g, rz=0.6)
    V(3, 2, 2, IRON_D, 7, 22, -3, g)
    return g


def meule():
    g = Node('Meule')
    V(14, 8, 10, WOOD_D, 0, 4, 0, g)
    V(4, 16, 16, STONE, 0, 16, 0, g)
    V(4.4, 12, 12, shade(STONE, 1.1), 0, 16, 0, g)
    V(18, 2, 2, WOOD, 0, 16, 0, g)
    V(2, 6, 2, WOOD, 9, 13, 0, g)
    return g


def four():
    g = Node('Four')
    V(18, 18, 18, 0xa05a3a, 0, 9, 0, g)
    V(16, 6, 16, shade(0xa05a3a, 0.9), 0, 21, 0, g)
    V(10, 4, 12, shade(0xa05a3a, 0.8), 0, 26, 0, g)
    V(8, 8, 2, 0x2a1a14, 0, 8, 9, g)
    VG(6, 4, 1, FIRE, 0, 6, 9.2, g)
    V(4, 10, 4, STONE_D, 4, 32, -4, g)
    return g


def four_pain():
    g = Node('FourPain')
    V(18, 10, 18, STONE, 0, 5, 0, g)
    for i, w in enumerate((18, 16, 12, 7)):
        V(w, 4, w, 0xb86a44 if i % 2 else 0xa85a38, 0, 12 + i * 4, 0, g)
    V(8, 6, 2, 0x2a1a14, 0, 14, 9, g)
    VG(6, 3, 1, FIRE, 0, 13, 9.3, g)
    V(5, 2, 4, 0xd8a050, -5, 10.5, 8, g)
    return g


def petrin():
    g = Node('Petrin')
    V(18, 7, 11, WOOD, 0, 11, 0, g)
    V(16, 2, 9, 0xe8dcc0, 0, 14.6, 0, g)
    leg4(g, 16, 10, 8, WOOD_D)
    V(4, 3, 4, 0xe8dcc0, 3, 16, 0, g)
    V(1.2, 1.2, 8, WOOD_L, -4, 15.8, 0, g, ry=0.5)
    return g


def mannequin():
    g = Node('Mannequin')
    V(10, 2, 10, WOOD_D, 0, 1, 0, g)
    V(2.4, 22, 2.4, WOOD, 0, 12, 0, g)
    V(10, 12, 6, STRAW, 0, 26, 0, g)
    V(20, 2.4, 2.4, WOOD, 0, 30, 0, g)
    V(7, 7, 7, STRAW, 0, 36, 0, g)
    V(8, 3, 7.4, CLOTH_R, 0, 24, 0, g)
    V(3, 3, 0.6, 0xf0f0f0, 0, 26, 3.3, g)
    V(1.6, 1.6, 0.6, CLOTH_R, 0, 26, 3.7, g)
    return g


def ratelier():
    g = Node('Ratelier')
    for sx in (-1, 1):
        V(2.4, 28, 2.4, WOOD_D, sx * 8, 14, 0, g)
    V(18, 2.4, 2.4, WOOD, 0, 24, 0, g)
    V(18, 2.4, 3, WOOD, 0, 6, 1, g)
    for i, x in enumerate((-5, 0, 5)):
        V(1, 26, 1, WOOD_L, x, 14, 1, g, rz=0.06)
        V(2.4, 4, 1, 0xd9dde3, x + 0.8, 27.5, 1, g, rz=0.06)
    V(6, 7, 1.4, CLOTH_B, 0, 15, -1.6, g)
    return g


def cible():
    g = Node('Cible')
    V(2, 26, 2, WOOD_D, -4, 13, -3, g, rx=0.2)
    V(2, 26, 2, WOOD_D, 4, 13, -3, g, rx=0.2)
    for r, c in ((16, 0xf0e8d8), (12, CLOTH_R), (8, 0xf0e8d8), (4, CLOTH_R)):
        V(r, r, 1.5 + (16 - r) * 0.05, c, 0, 20, 0, g)
    V(1, 1, 8, WOOD_L, 2, 21, 3, g, ry=0.2)
    return g


def etal():
    g = Node('Etal')
    V(19, 3, 12, WOOD, 0, 12, 0, g)
    leg4(g, 18, 11, 11, WOOD_D)
    for sx in (-1, 1):
        V(1.6, 30, 1.6, WOOD_D, sx * 9, 15, -5, g)
    for i in range(5):
        V(4, 1.4, 14, (CLOTH_R, 0xf0e8d8)[i % 2], -8 + i * 4, 30 - 0.6 * (i % 2), 0, g)
    for i, c in enumerate((0xd84a2a, 0xe8c030, 0x6aa84a, 0xa04ad0)):
        V(3, 3, 3, c, -6 + i * 4, 15, 1, g)
    return g


def comptoir():
    g = Node('Comptoir')
    V(20, 16, 10, WOOD, 0, 8, 0, g)
    V(20.6, 2, 11, WOOD_L, 0, 17, 0, g)
    for x in (-5, 5):
        V(6, 10, 0.6, WOOD_D, x, 8, 5.2, g)
    V(3, 1, 3, GOLD, 4, 18.5, 0, g)
    V(2, 4, 2, 0x6a8ab0, -5, 20, 0, g)
    return g


def bibliotheque():
    g = Node('Bibliotheque')
    V(18, 36, 8, WOOD_D, 0, 18, -2, g)
    cols = [0xa02a2a, 0x2a4a9a, 0x2a7a3a, 0xc8a040, 0x6a3a8a, 0x8a5a2a]
    for shelf in range(4):
        y = 4 + shelf * 8.5
        V(16, 1.2, 7, WOOD, 0, y, -1.6, g)
        x = -7
        i = shelf
        while x < 7:
            w = 1.4 + (i % 3) * 0.4
            h = 5 + (i % 2)
            V(w, h, 5, cols[i % len(cols)], x + w / 2, y + 0.6 + h / 2, -1, g)
            x += w + 0.2
            i += 1
    return g


def pupitre():
    g = Node('Pupitre')
    V(3, 18, 3, WOOD_D, 0, 9, 0, g)
    V(12, 2, 9, WOOD, 0, 19, 0, g, rx=-0.35)
    V(9, 1, 6, 0xf0e8d0, 0, 20.6, 0.3, g, rx=-0.35)
    V(8, 2, 8, WOOD_D, 0, 1, 0, g)
    VG(1.2, 2, 1.2, 0xffd860, 5, 22, -2, g)
    return g


def autel():
    g = Node('Autel')
    V(18, 4, 12, STONE, 0, 2, 0, g)
    V(14, 12, 9, 0xe8e4dc, 0, 10, 0, g)
    V(18, 2, 12, 0xf4f0e8, 0, 17, 0, g)
    V(10, 1, 7, CLOTH_R, 0, 18.5, 0, g)
    VG(3, 5, 3, 0xfff0a0, 0, 21.5, 0, g)
    for sx in (-1, 1):
        V(2, 4, 2, GOLD, sx * 6, 20, 0, g)
    return g


def bougeoir():
    g = Node('Bougeoir')
    V(8, 2, 8, IRON_D, 0, 1, 0, g)
    V(1.6, 16, 1.6, IRON_D, 0, 9, 0, g)
    V(10, 1.4, 1.4, IRON_D, 0, 16, 0, g)
    for x in (-4.5, 0, 4.5):
        V(1.6, 4, 1.6, 0xf4f0e0, x, 19, 0, g)
        VG(1, 1.6, 1, 0xffc040, x, 22, 0, g)
    return g


def chaudron():
    g = Node('Chaudron')
    for w, y in ((10, 1), (14, 4), (15, 8), (14, 12)):
        V(w, 4, w, 0x2a2a30, 0, y + 2, 0, g)
    VG(12, 1, 12, 0x6aff8a, 0, 15.5, 0, g)
    for i in range(3):
        a = i * 2.1
        V(1.6, 4, 1.6, 0x2a2a30, math.cos(a) * 5, 1, math.sin(a) * 5, g)
    VG(2, 2, 2, 0xa0ffb0, 2, 18, 1, g)
    VG(1.4, 1.4, 1.4, 0xa0ffb0, -2, 20, -1, g)
    return g


def metier_tisser():
    g = Node('MetierTisser')
    for sx in (-1, 1):
        V(2, 26, 2, WOOD_D, sx * 8, 13, -3, g)
        V(2, 14, 2, WOOD_D, sx * 8, 7, 5, g)
        V(2, 2, 10, WOOD, sx * 8, 14, 1, g)
    V(18, 2, 2, WOOD, 0, 25, -3, g)
    V(18, 2, 2, WOOD, 0, 14, 5, g)
    for i in range(8):
        V(1, 11, 0.4, (CLOTH_B, 0xf0e8d8)[i % 2], -7 + i * 2, 19.5, -3, g)
    V(14, 8, 0.6, CLOTH_B, 0, 18, 1, g, rx=0.7)
    return g


def auge():
    g = Node('Auge')
    V(19, 7, 9, WOOD, 0, 3.5, 0, g)
    V(17, 2, 7, 0x3a7ab0, 0, 6.4, 0, g)
    for x in (-8, 8):
        V(2, 8, 10, WOOD_D, x, 4, 0, g)
    return g


def mangeoire():
    g = Node('Mangeoire')
    V(16, 10, 10, WOOD, 0, 5, 0, g)
    V(14, 5, 8, STRAW, 0, 11, 0, g)
    for i in range(8):
        V(1, 4 + i % 3, 1, shade(STRAW, 1.1), -6 + i * 1.8, 14, (i % 3 - 1) * 2, g, rz=(i - 4) * 0.1)
    V(16.4, 2, 10.4, WOOD_D, 0, 9, 0, g)
    return g


def barriere():
    """Barrière d'enclos : deux poteaux et deux lisses sur toute la largeur de la case."""
    g = Node('Barriere')
    for x in (-9, 9):
        V(2.4, 18, 2.4, WOOD_D, x, 9, 0, g)
        V(3, 1.4, 3, shade(WOOD_D, 0.85), x, 18.4, 0, g)
    for y in (7, 14):
        V(20, 2, 1.4, WOOD, 0, y, 0, g)
    V(1.6, 12, 1.2, WOOD_L, 0, 9.5, 0.2, g, rz=0.9)
    return g


def billot():
    g = Node('Billot')
    V(12, 10, 12, 0x8a6038, 0, 5, 0, g)
    V(10, 1, 10, 0xc8a070, 0, 10.5, 0, g)
    V(1.4, 10, 1.4, WOOD, 2, 14, 0, g, rz=0.5)
    V(5, 4, 1.2, IRON, 4.5, 18, 0, g, rz=0.5)
    V(16, 5, 5, 0x7a5530, -2, 2.5, 8, g, ry=0.3)
    return g


def lanterne():
    g = Node('Lanterne')
    V(2, 30, 2, IRON_D, 0, 15, 0, g)
    V(6, 1.4, 1.4, IRON_D, 3, 30, 0, g)
    V(5, 6, 5, IRON_D, 6, 25, 0, g)
    VG(3.6, 4.4, 3.6, 0xffd070, 6, 25, 0, g)
    V(8, 2, 8, STONE_D, 0, 1, 0, g)
    return g


def statue():
    g = Node('Statue')
    V(14, 6, 14, 0xe8e4dc, 0, 3, 0, g)
    V(8, 12, 6, 0xf0ece4, 0, 14, 0, g)
    V(6, 6, 6, 0xf0ece4, 0, 23, 0, g)
    for sx in (-1, 1):
        V(3, 10, 3, 0xf0ece4, sx * 5.5, 15, 0, g, rz=-sx * 0.2)
    V(1.4, 18, 1.4, GOLD, 6.5, 22, 1, g)
    V(7, 3, 7, GOLD, 0, 27, 0, g)
    return g


FURNITURE = {
    'porte': porte, 'lit': lit, 'coffre': coffre, 'table': table, 'chaise': chaise, 'tonneau': tonneau,
    'torche': torche, 'lanterne': lanterne, 'enclume': enclume, 'foyer_forge': foyer_forge, 'etabli': etabli,
    'table_tailleur': table_tailleur, 'meule': meule, 'four': four, 'four_pain': four_pain, 'petrin': petrin,
    'mannequin': mannequin, 'ratelier': ratelier, 'cible': cible, 'etal': etal, 'comptoir': comptoir,
    'bibliotheque': bibliotheque, 'pupitre': pupitre, 'autel': autel, 'bougeoir': bougeoir, 'chaudron': chaudron,
    'metier_tisser': metier_tisser, 'auge': auge, 'mangeoire': mangeoire, 'billot': billot, 'statue': statue,
    'barriere': barriere,
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='../assets/furniture')
    ap.add_argument('--only', default='', help='noms séparés par des virgules (par défaut : tous)')
    a = ap.parse_args()
    only = [n for n in a.only.split(',') if n]
    os.makedirs(a.out, exist_ok=True)
    for name, fn in FURNITURE.items():
        if only and name not in only:
            continue
        export_glb(fn(), os.path.join(a.out, name + '.glb'))
    print('%d meubles -> %s' % (len(FURNITURE), a.out))


if __name__ == '__main__':
    main()
