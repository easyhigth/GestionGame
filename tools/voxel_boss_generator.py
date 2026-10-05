#!/usr/bin/env python3
"""
Générateur des modèles voxel des 9 BOSS de région -> fichiers .glb pour Godot 4.

Chaque boss part du corps de son espèce (créature ou race) et garde EXACTEMENT ses nœuds
(Root > LegL, LegR, Torso > ArmL/HandL, ArmR/HandR, Head) : scripts/voxel_character.gd l'anime
comme les autres, et les boss humanoïdes portent toujours l'équipement de leur race
(<race>_equipment.glb). Ce qui change : une palette à eux et des pièces qui les rendent
reconnaissables de loin (couronnes, défenses, plaques d'or, cristaux, sacs d'œufs, ailes de feu...).
La taille de jeu reste réglée par `model_scale` dans data/enemies/boss_*.tres.

Fichiers écrits :
    bosses/<boss>.glb

Usage :
    python voxel_boss_generator.py --out ../assets/characters/bosses
    python voxel_boss_generator.py --only reine_araignee,roi_sanglier
"""
import argparse, math, os
from voxel_character_generator import Node, V, VG, VA, RACES, RACE_ORDER, gen, mk, shade, export_glb
import voxel_creature_generator as vcg
from voxel_evolution_generator import (_find, _bbox, _head, horns, crown, collar, shoulder_spikes, back_spines,
                                       face_marks, eye_glow, chest_runes, motes, aura_ring, antlers, mini_feather_wings)

GOLD = 0xd8b04a
GOLD_L = 0xf0d070
BONE = 0xe8e0c8
RUBY = 0xff2a3a


# ---------------------------------------------------------------- outils
def ground(g):
    """Hauteur du sol dans le repère de Root (les voxels sont mis à l'échelle par Root)."""
    return -g.t[1] / (g.scale or 1.0)


def ring(pa, col, r, y, n=16, w=3.2):
    for i in range(n):
        a = i / float(n) * 2 * math.pi
        VG(w * r / 10.0, 0.3, 0.9, col, math.cos(a) * r, y, math.sin(a) * r, pa, ry=-a)


def spike_crown(pa, col, cx, cy, cz, r, n=6, height=2.4, gem=None, band=True, glow=False):
    """Couronne posée en (cx, cy, cz) : un bandeau et des pointes, gemme devant."""
    f = VG if glow else V
    if band:
        for i in range(n * 2):
            a = i / float(n * 2) * 2 * math.pi
            f(r * 0.6, 1.0, 0.8, col, cx + math.sin(a) * r, cy, cz + math.cos(a) * r, pa, ry=a)
    for i in range(n):
        a = i / float(n) * 2 * math.pi
        hgt = height + (i % 2) * 1.0
        f(1.1, hgt, 1.1, shade(col, 1.08), cx + math.sin(a) * r, cy + 0.5 + hgt / 2, cz + math.cos(a) * r, pa)
    if gem is not None:
        VG(1.3, 1.3, 0.7, gem, cx, cy + 0.2, cz + r + 0.5, pa, rz=0.785)


def humanoid(race, skin, hs=None, hair=None, eye=None):
    """Corps nu de la race (mêmes mesures que <race>_base.glb), avec la palette du boss."""
    i = RACE_ORDER.index(race)
    p = gen(race, 'forgeron', mk(97 + i * 13 + 1))
    p['naked'] = True; p['cape'] = False; p['beard'] = False
    p['skin'] = skin
    if hs is not None: p['hs'] = hs
    if hair is not None: p['hair'] = hair
    if eye is not None: p['eye'] = eye
    return RACES[race]('forgeron', p), p


# ---------------------------------------------------------------- créatures
def reine_araignee():
    """Reine araignée : abdomen gonflé, sablier rouge, couronne de chitine, sacs d'œufs, crocs d'ivoire."""
    c = 0x24182e; mark = 0xff2a5a
    g = vcg.spider(c, mark, 0xff3a6a)
    top = _find(g, 'Torso'); head = _find(g, 'Head')
    # abdomen plus haut et plus long, sablier lumineux
    V(20, 6, 20, shade(c, 0.95), 0, 13, -13, top)
    V(14, 3, 14, shade(c, 1.1), 0, 17, -13, top)
    VG(6, 1, 3, mark, 0, 18.6, -10, top); VG(2, 1, 4, mark, 0, 18.6, -13, top); VG(6, 1, 3, mark, 0, 18.6, -16, top)
    for i in range(8):
        a = i / 8.0 * 2 * math.pi
        V(1.4, 3 + (i % 2) * 1.5, 1.4, shade(c, 1.4), math.cos(a) * 8, 17 + (i % 2) * 0.7, -13 + math.sin(a) * 8, top, rx=math.sin(a) * 0.4, rz=-math.cos(a) * 0.4)
    # sacs d'œufs pâles sous l'abdomen et sur les flancs
    for x, y, z in ((-7, 0, -18), (6, -0.5, -20), (0, -1, -23), (-9.5, 4, -9), (9.5, 3, -11)):
        VA(4, 4, 4, 0xf0e8d0, x, y, z, top, alpha=0.85)
        VG(1.4, 1.4, 1.4, mark, x, y, z, top)
    # pattes du milieu cerclées d'épines
    for sx in (-1, 1):
        for z in (0, 4):
            V(1.2, 2.4, 1.2, shade(c, 1.4), sx * 13.5, 3.5, z, top)
    # tête : couronne de chitine, 8 yeux, grands crocs
    spike_crown(head, 0x6a2a7a, 0, 3.6, -0.5, 3.4, n=7, height=2.6, gem=RUBY)
    for sx, sy in ((-1, 2.4), (1, 2.4)):
        VG(1, 1, 0.6, 0xff3a6a, sx, sy, 3.1, head)
    for sx in (-1, 1):
        V(1.6, 5, 1.6, BONE, sx * 1.8, -4.4, 3.4, head, rx=0.4)
        VG(0.6, 1.2, 0.6, 0x9aff4a, sx * 1.8, -7, 4.4, head)
    return g


def roi_sanglier():
    """Roi sanglier : poil noir-roux, grandes défenses recourbées, crinière dorée, couronne de bronze, cicatrices."""
    c = 0x4a2a1e
    g = vcg.boar(c, 0xff4a1a)
    top = _find(g, 'Torso'); head = _find(g, 'Head')
    # crinière de feu sur l'échine
    for i in range(9):
        V(2.4, 3.4 + (i % 3) * 1.2, 2.4, (0xc8641e, 0xe89a2a, 0x8a3a14)[i % 3], 0, 12.5 + (i % 2), 10 - i * 2.8, top, rx=-0.3)
    # caparaçon : plaques de bronze sur les flancs, cicatrices
    for s in (-1, 1):
        V(0.8, 6, 12, 0x9a6a2a, s * 6.4, 5.5, 1, top)
        V(0.9, 1, 12.6, GOLD, s * 6.5, 8.6, 1, top)
        for z in (-3, 1, 5):
            V(1, 1.4, 1.4, GOLD_L, s * 6.8, 5.5, z, top)
        V(0.4, 0.5, 6, 0xe0a8a0, s * 6.1, 3, -7, top, rx=0.3)
    # défenses recourbées (trois segments chacune)
    for s in (-1, 1):
        V(1.6, 3, 1.6, 0xf8f0dc, s * 3.6, -1, 7.4, head, rx=0.2)
        V(1.4, 3, 1.4, 0xf8f0dc, s * 4.4, 1.4, 8.6, head, rz=-s * 0.5)
        V(1.1, 2.6, 1.1, 0xfff8e8, s * 5.6, 3.4, 8.2, head, rz=-s * 0.9, rx=-0.4)
        VG(1.2, 1, 0.5, 0xff4a1a, s * 2.6, 1.6, 4.3, head)
    # couronne de bronze entre les oreilles
    spike_crown(head, GOLD, 0, 4.6, -0.6, 3.2, n=6, height=2.2, gem=RUBY)
    # anneau dans le groin
    V(2.4, 0.6, 0.6, GOLD, 0, -3.2, 8.8, head)
    return g


def slime_primordial():
    """Slime primordial : gel plus épais et lumineux, trois noyaux, os et crânes avalés, gouttes en orbite, couronne de gel."""
    from voxel_character_generator import VA as _VA
    c = 0x6ac83a
    g = vcg.slime(c, 0x2a6a14, 0xffffff, 1.2, glow=False)
    top = _find(g, 'Torso'); head = _find(g, 'Head')
    # dôme plus haut
    _VA(10, 4, 10, shade(c, 1.2), 0, 15, -1, top, alpha=0.75)
    _VA(5, 3, 5, shade(c, 1.3), 0, 18, -1, top, alpha=0.75)
    # trois noyaux lumineux et des restes avalés
    VG(4, 4, 4, 0xc8ff5a, -3.4, 7, -2, top, rx=0.5, rz=0.5)
    VG(3, 3, 3, 0xffe04a, 3.6, 9.5, -3, top, rx=0.3, ry=0.6)
    V(5, 0.9, 0.9, BONE, 2, 3, 2, top, ry=0.6)
    V(0.9, 0.9, 4, BONE, -4, 4, -5, top, rx=0.3)
    V(3, 3, 3, BONE, -5, 10, 1, top)
    for sx in (-1, 1): V(0.8, 0.8, 0.4, 0x1a1414, -5 + sx * 0.7, 10.3, 2.6, top)
    V(2.6, 1, 0.8, GOLD, 4.6, 4, 3, top, rz=0.5)
    # gouttes de gel en orbite (bosses du corps)
    for i in range(6):
        a = i / 6.0 * 2 * math.pi
        _VA(3, 3, 3, shade(c, 1.1), math.cos(a) * 11.5, 3 + (i % 2) * 4, math.sin(a) * 11.5, top, alpha=0.7)
    # couronne de gel lumineuse
    for i in range(8):
        a = i / 8.0 * 2 * math.pi
        VG(1.4, 3 + (i % 2) * 1.6, 1.4, 0xd8ff7a, math.cos(a) * 3.4, 21, -1 + math.sin(a) * 3.4, top)
    # visage : sourcils colériques, bouche pleine de dents
    for sx in (-1, 1):
        V(3.4, 0.8, 0.6, shade(c, 0.4), sx * 3, 2.4, 2.4, head, rz=sx * 0.35)
    V(6, 1.6, 0.6, 0x1a2a10, 0, -3, 2.1, head)
    for x in (-2, -0.7, 0.7, 2): V(0.6, 0.8, 0.6, 0xf4f0e0, x, -2.6, 2.4, head)
    ring(g, 0x9aff4a, 13, ground(g) + 0.3)
    return g


def ours_ancien():
    """Ours ancien : pelage de givre, dos hérissé de cristaux de glace, défenses de glace, runes bleues, cicatrice."""
    c = 0xdce6ee; belly = 0xa8b8c8; ice = 0x8ae0ff
    g = vcg.bear(c, belly, 0x4adcff, 1.1)
    top = _find(g, 'Torso'); head = _find(g, 'Head')
    # crinière épaisse sur les épaules
    for i in range(10):
        a = i / 10.0 * math.pi
        V(4, 3.4, 4, shade(c, 0.88 + (i % 3) * 0.05), math.cos(a) * 8.6, 9 + math.sin(a) * 5, 9, top)
    # cristaux de glace sur l'échine
    for i, (z, hgt) in enumerate(((8, 5), (4, 7), (0, 8.5), (-4, 7), (-8, 5.5), (-11.5, 4))):
        VA(2.4, hgt, 2.4, ice, 0, 13 + hgt / 2, z, top, alpha=0.8, rx=-0.15, glow=True)
        VA(1.6, hgt * 0.6, 1.6, shade(ice, 1.1), (1 if i % 2 else -1) * 2.6, 13 + hgt * 0.3, z - 1, top, alpha=0.8, rz=(0.4 if i % 2 else -0.4), glow=True)
    # runes lumineuses sur les flancs
    for s in (-1, 1):
        for i in range(3):
            VG(0.4, 3.6 - i * 0.6, 1.2, 0x4adcff, s * 8.2, 6, 4 - i * 4, top)
        V(0.4, 0.6, 7, 0xb0a0a8, s * 8.1, 9, -4, top, rx=-0.4)
    # tête : défenses de glace, œil balafré, front de givre
    for s in (-1, 1):
        VA(1.2, 4.4, 1.2, ice, s * 2, -3.6, 7.6, head, alpha=0.85, rx=0.3, glow=True)
        V(1.4, 1.2, 0.4, 0xffffff, s * 2.8, 1.6, 4.85, head)
    V(0.5, 4.4, 0.4, 0x8a7a80, 2.8, 1.6, 4.9, head, rz=0.3)
    for i in range(5):
        VA(1.2, 2 + (i % 2) * 1.6, 1.2, ice, (i - 2) * 2, 5.6 + (i % 2) * 0.6, -1, head, alpha=0.85, rz=(i - 2) * -0.2, glow=True)
    ring(g, 0x9ae8ff, 15, ground(g) + 0.3)
    return g


def quetzal():
    """Quetzal : serpent à plumes géant, coiffe en éventail, anneaux d'or, ailes plus grandes, gemmes de jade."""
    g = vcg.snake(0x1aa078, 0xf0e070, 0xd02a3a, 0xffd24a, 1.0,
                  crest=[0xd02a3a, 0xf0b020, 0x2a8ad0, 0x2ac84a, 0xd02a3a],
                  wings=[0x2ac84a, 0x2a8ad0, 0xf0b020, 0xd02a3a, 0x1aa078])
    top = _find(g, 'Torso'); head = _find(g, 'Head')
    # coiffe en éventail de longues plumes
    cols = (0x2ac84a, 0x2a8ad0, 0xd02a3a, 0xf0b020, 0x1aa078)
    for i in range(9):
        a = (i - 4) * 0.28
        L = 9 - abs(i - 4) * 0.8
        V(1.2, L, 0.6, cols[i % 5], math.sin(a) * L / 2, 2.4 + math.cos(a) * L / 2, -3.4, head, rz=-a)
        VG(1.0, 1.0, 0.7, 0x2ae0a0 if i % 2 else 0xffd24a, math.sin(a) * L, 2.4 + math.cos(a) * L, -3.4, head)
    # diadème d'or et gemme de jade
    V(7, 1.2, 0.8, GOLD, 0, 2.4, 3.6, head)
    VG(1.6, 1.6, 0.6, 0x2ae0a0, 0, 2.4, 4.2, head, rz=0.785)
    for s in (-1, 1):
        V(1.4, 2.4, 0.6, GOLD, s * 3.4, -0.6, 1.2, head)
    # anneaux d'or le long du corps
    pts = [(1.6, 1.2, 2), (1.4, 1.1, -7), (-2.8, 0.9, -15), (0.8, 0.7, -22.5)]
    for i, (x, y, z) in enumerate(pts):
        w = 6.4 - (i * 2 + 1) * 0.55 + 0.8
        V(w, w * 0.8 + 0.4, 1, GOLD, x, y + w * 0.4, z, top)
    # le cou dressé porte un collier de plumes
    for i in range(8):
        a = i / 8.0 * 2 * math.pi
        V(1.4, 3.6, 0.6, cols[i % 5], math.cos(a) * 3.6, 8 + math.sin(a) * 2.6, 9, top, rz=-math.cos(a) * 0.6)
    # longue queue de plumes
    for i in range(5):
        V(1, 6 - i * 0.5, 0.6, cols[i], 0.8 + (i - 2) * 1.2, 2.5, -25.5 - i * 0.3, top, rx=-1.2, rz=(i - 2) * 0.3)
    return g


def scorpion_empereur():
    """Scorpion empereur : carapace noire et or, double dard, pinces dorées, couronne et collier de gemmes."""
    c = 0x2a2018; gold = 0xc8962a
    g = vcg.scorpion(c, 0xff3a1a, 0xff4a2a)
    top = _find(g, 'Torso'); head = _find(g, 'Head')
    # plaques d'or sur le dos et rivets
    for i in range(4):
        V(13 - i, 0.8, 2.2, gold, 0, 5.3, 7 - i * 4.6, top)
        for s in (-1, 1): VG(0.8, 0.8, 0.8, 0xff3a1a, s * (5 - i * 0.5), 5.8, 7 - i * 4.6, top)
    # anneaux d'or sur la queue et second dard
    tail = [(0, 4, -12, 5), (0, 8, -15, 4.6), (0, 13, -16, 4.2), (0, 18, -14.5, 3.8)]
    for x, y, z, w in tail:
        V(w + 0.6, 1, w + 0.6, gold, x, y + w / 2 - 0.4, z, top)
    for s in (-1, 1):
        V(1.6, 1.6, 3, c, s * 2, 22, -9, top, ry=s * 0.4)
        VG(2, 2, 2, 0xff3a1a, s * 2.8, 22.4, -6.8, top)
    # pinces cerclées d'or
    for name in ('ArmL', 'ArmR'):
        A = _find(g, name); x = A.t[0]
        V(5.6, 0.8, 6.4, gold, x * 0.6, 2.2, 9, A)
        V(5.6, 0.8, 1, gold, x * 0.6, 0, 6.4, A)
        VG(1, 1, 1, 0xff3a1a, x * 0.6, 2.8, 9, A)
    # couronne et yeux rouges
    spike_crown(head, gold, 0, 2.4, 0, 2.8, n=6, height=2.2, gem=0xff3a1a)
    for s in (-1, 1):
        VG(1, 1, 0.5, 0xff4a2a, s * 3, 1.2, 2, head)
    ring(g, 0xffb030, 14, ground(g) + 0.3)
    return g


# ---------------------------------------------------------------- humanoïdes (portent l'équipement de leur race)
def dryade_mere():
    """Dryade mère : écorce argentée, grande ramure fleurie, ailes de feuilles, lianes, racines au sol, pétales."""
    b, p = humanoid('dryad', 0x9a8a72, hs=1, hair=0x5ac85a, eye=0xff90d0)
    h, hw, hh, hd = _head(b)
    antlers(b, 0x6a5a48, 0xff9ad0)
    # ramure : branches hautes de chaque côté du chapeau, feuilles et fleurs
    for s in (-1, 1):
        V(0.9, 6, 0.9, 0x6a5a48, s * 5.6, hh / 2 + 6, -0.6, h, rz=-s * 0.35)
        V(0.7, 4, 0.7, 0x6a5a48, s * 8, hh / 2 + 9.5, -0.6, h, rz=-s * 0.9)
        for (x, y, c) in ((7.4, 9.4, 0x5ac85a), (9.6, 10.6, 0xff7ab0), (6.2, 11.6, 0x7ae05a), (9.2, 8, 0xffd84a)):
            VG(1.6, 1.6, 1.6, c, s * x, hh / 2 + y, -0.6, h)
    # ailes de feuilles dans le dos (au-dessus de la cape)
    mini_feather_wings(b, 0x4aa84a, 0x8ae05a, sc=0.9, y_off=-1.0, n=6)
    # lianes autour des bras et des jambes
    for A in b['arms']:
        for i in range(3): VG(b['o']['aw'] + 0.7, 0.35, b['o']['ad'] + 0.7, 0x9af07a, 0, -3 - i * 3.4, 0, A, ry=i * 0.4)
    for L in b['legs']:
        for i in range(3): V(b['o']['lw'] + 0.6, 0.5, b['o']['ld'] + 0.6, 0x3a8a3a, 0, -2 - i * 4, 0, L, ry=i * 0.5)
    # racines qui s'étalent au sol et pétales qui flottent
    g = b['g']
    for i in range(8):
        a = i / 8.0 * 2 * math.pi
        V(1.2, 0.8, 4.4, 0x5a4a38, math.cos(a) * 5, 0.4, math.sin(a) * 5, g, ry=-a + math.pi / 2)
    motes(b, 0xff9ad0, 8, 7.0, 4.0)
    aura_ring(b, 0x9af07a)
    eye_glow(b, 0xff90d0)
    return b['g']


def ogre_roi():
    """Ogre roi : peau rouge sombre, peintures de guerre, couronne d'or sur le casque, collier de crânes, épaulières d'os."""
    b, p = humanoid('ogre', 0x8a3a2a, hs=1, eye=0xffd030)
    h, hw, hh, hd = _head(b)
    o = b['o']; top = b['top']; T = b['T']
    face_marks(b, 0xf0e0c0, False)
    # grandes défenses
    for s in (-1, 1):
        V(1.6, 4.4, 1.6, 0xf8f0dc, s * 3.4, -hh * 0.42 + 1.6, hd / 2 + 1.0, h, rz=-s * 0.15)
    # couronne d'or massive, au-dessus du casque
    spike_crown(h, GOLD, 0, hh / 2 + 2.6, 0, hw * 0.62, n=8, height=3.0, gem=RUBY)
    # collier de crânes par-dessus l'armure
    ch = T[3]
    for i in range(7):
        a = (i - 3) * 0.32
        x = math.sin(a) * (ch['w'] / 2 + 0.4); z = math.cos(a) * (ch['d'] / 2 + 1.6)
        y = o['tH'] - 1.4 - abs(i - 3) * 0.2
        V(2.2, 2.2, 2, BONE, x, y, z, top)
        for sx in (-1, 1): V(0.5, 0.5, 0.3, 0x1a1414, x + sx * 0.5, y + 0.2, z + 1.05, top)
    # épaulières d'os hérissées (par-dessus celles de fer)
    shoulder_spikes(b, BONE, 3, 1.8)
    for A in b['arms']:
        V(o['aw'] + 3.4, 1.2, o['ad'] + 3.4, 0x5a3a24, 0, 2.2, 0, A)
    aura_ring(b, 0xff6a2a)
    return b['g']


def seigneur_ignarok():
    """Ignarok : peau de cendre veinée de lave, grandes ailes de feu, couronne de flammes, braises, queue ardente."""
    b, p = humanoid('demon', 0x3a2a2e, hs=1, eye=0xffd030)
    h, hw, hh, hd = _head(b)
    o = b['o']; top = b['top']; T = b['T']; tH = o['tH']
    lava = 0xff6a1a; ember = 0xffb030
    # veines de lave sur les bras et les jambes (là où l'armure ne couvre pas)
    for A in b['arms']:
        for i in range(3): VG(0.4, 2.2, 0.3, lava, -1 + i, -o['al'] * 0.55, o['ad'] / 2 + 0.25, A)
    for L in b['legs']:
        VG(0.4, 4, 0.3, lava, 0.8, -o['legH'] * 0.5, o['ld'] / 2 + 0.3, L)
        VG(0.4, 3, 0.3, lava, -0.8, -o['legH'] * 0.3, o['ld'] / 2 + 0.3, L)
    face_marks(b, lava)
    eye_glow(b, ember)
    # grandes ailes de feu : membrane lumineuse entre trois os
    for s in (-1, 1):
        x0 = s * (T[3]['w'] / 2 - 0.5); y0 = tH - 0.5; z0 = -(T[3]['d'] / 2 + 3.2)
        angs = (0.35, 0.95, 1.55); lens = (17, 15, 11)
        for a, Lb in zip(angs, lens):
            V(1.5, Lb, 1.3, 0x2a1a1a, x0 + s * math.sin(a) * Lb / 2, y0 + math.cos(a) * Lb / 2, z0, top, rz=-s * a)
            VG(1.2, 1.6, 1.2, ember, x0 + s * math.sin(a) * Lb, y0 + math.cos(a) * Lb, z0, top)
        for i in range(2):
            a = (angs[i] + angs[i + 1]) / 2; Lm = (lens[i] + lens[i + 1]) / 2
            VA(Lm * (angs[i + 1] - angs[i]) * 0.95, Lm * 0.8, 0.5, (0xff4a1a, 0xff8a2a)[i],
               x0 + s * math.sin(a) * Lm * 0.47, y0 + math.cos(a) * Lm * 0.47, z0 - 0.2, top, alpha=0.8, rz=-s * a, glow=True)
    # couronne de flammes au-dessus du casque à cornes
    for i in range(9):
        a = i / 9.0 * 2 * math.pi
        hgt = 2.4 + (i % 3) * 1.2
        VG(1.1, hgt, 1.1, (0xff4a1a, ember, 0xffe060)[i % 3], math.sin(a) * hw * 0.5, hh / 2 + 3.4 + hgt / 2, math.cos(a) * hd * 0.5, h)
    # pointe de la queue en braise
    VG(2.4, 2.4, 2.4, ember, 0, 4.2, -(T[0]['d'] / 2 + 18.6), top, rz=0.785)
    # braises qui flottent, sol fendu de lave
    motes(b, ember, 10, 8.0, 3.0)
    g = b['g']
    for i in range(6):
        a = i / 6.0 * 2 * math.pi + 0.3
        VG(0.6, 0.3, 5, lava, math.cos(a) * 6, 0.2, math.sin(a) * 6, g, ry=-a + math.pi / 2)
    aura_ring(b, lava)
    return g


BOSSES = {
    'reine_araignee': reine_araignee,
    'roi_sanglier': roi_sanglier,
    'slime_primordial': slime_primordial,
    'ours_ancien': ours_ancien,
    'quetzal': quetzal,
    'scorpion_empereur': scorpion_empereur,
    'dryade_mere': dryade_mere,
    'ogre_roi': ogre_roi,
    'seigneur_ignarok': seigneur_ignarok,
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='../assets/characters/bosses')
    ap.add_argument('--only', default='', help='noms séparés par des virgules (par défaut : tous)')
    a = ap.parse_args()
    only = [n for n in a.only.split(',') if n]
    os.makedirs(a.out, exist_ok=True)
    n = 0
    for name, fn in BOSSES.items():
        if only and name not in only:
            continue
        export_glb(fn(), os.path.join(a.out, name + '.glb')); n += 1
    print('%d boss -> %s' % (n, a.out))


if __name__ == '__main__':
    main()
