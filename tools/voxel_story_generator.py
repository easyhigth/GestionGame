#!/usr/bin/env python3
"""
Générateur des modèles voxel des PERSONNAGES DE L'HISTOIRE (scripts/story/story_data.gd, NPCS) -> .glb pour Godot 4.

Dans la lignée des boss (voxel_boss_generator.py) et des ennemis nommés, mais en plus discret : chacun garde
EXACTEMENT le corps de sa race, première palette (<race>_base.glb, celle de son portrait), avec ses nœuds
(Root > LegL, LegR, Torso > ArmL/HandL, ArmR/HandR, Head). scripts/voxel_character.gd l'anime comme les autres
habitants et il porte toujours son équipement (le « kit » de story_data.gd, accroché par <race>_equipment.glb).
Ce qui s'ajoute : UN trait à lui, posé AUTOUR de son équipement (au-dessus du casque, devant l'armure, dans
le dos derrière la cape), pour qu'on le reconnaisse de loin : la couronne d'Edmond, le masque de Ren,
la bannière de Gorvak, les lunettes de Maëlle...

Fichiers écrits :
    story/<id>.glb          (même identifiant que dans NPCS)
    story/<id>_alt.glb      (quand le personnage change de race : Pip devenu hobgobelin)

Usage :
    python voxel_story_generator.py --out ../assets/characters/story
    python voxel_story_generator.py --only edmond,ren
"""
import argparse, math, os
from voxel_character_generator import V, VG, VA, RACES, RACE_ORDER, gen, mk, shade, export_glb
from voxel_evolution_generator import _head, horns, face_marks, eye_glow, collar, crown, halo, motes, floating_crystals, antlers
from voxel_boss_generator import spike_crown, GOLD, GOLD_L, BONE, RUBY

SILVER = 0xd8dce8
LEATHER = 0x7a4a2a
LEATHER_D = 0x5a341c
BRUME = 0xb48cff


# ---------------------------------------------------------------- corps
def body(race):
    """Le corps nu de la race, première palette : exactement <race>_base.glb (voir make_character)."""
    i = RACE_ORDER.index(race)
    p = gen(race, 'forgeron', mk(97 + i * 13 + 1))
    p['naked'] = True; p['cape'] = False
    return RACES[race]('forgeron', p)


def back_z(b, extra=0.0):
    """Profondeur juste derrière une cape (capes à -(d/2 + 0.8), épaisseur 0.9)."""
    return -(b['T'][2]['d'] / 2 + 1.9 + extra)


# ---------------------------------------------------------------- pièces
def beard(b, col, length=6.0, braids=False, width=None):
    """Barbe sous le menton ; `braids` : deux nattes à anneaux d'or."""
    h, hw, hh, hd = _head(b)
    w = width or hw * 0.8
    jaw = -hh / 2 - b['o']['jh'] * 0.5
    V(w, 2.4, 1.6, col, 0, -hh * 0.3, hd / 2 + 0.5, h)
    V(w * 0.9, length * 0.5, 1.8, shade(col, 0.95), 0, jaw - length * 0.15, hd / 2 + 0.3, h)
    V(w * 0.65, length * 0.5, 1.6, shade(col, 0.9), 0, jaw - length * 0.55, hd / 2 + 0.4, h)
    if braids:
        for s in (-1, 1):
            V(1.3, length * 0.7, 1.3, shade(col, 0.88), s * w * 0.28, jaw - length * 0.95, hd / 2 + 0.5, h)
            V(1.7, 0.8, 1.7, GOLD, s * w * 0.28, jaw - length * 1.1, hd / 2 + 0.5, h)
    else:
        V(w * 0.35, length * 0.3, 1.4, shade(col, 0.85), 0, jaw - length * 0.85, hd / 2 + 0.5, h)


def plume(pa, cols, x, y, z, n=4, L=4.0, lean=-0.5):
    """Panache de plumes qui part vers l'arrière."""
    for i in range(n):
        V(1.0, L - i * 0.4, 0.6, cols[i % len(cols)], x + (i - (n - 1) / 2) * 0.5, y + (L - i * 0.4) / 2, z - i * 0.6, pa, rx=lean - i * 0.12)


def satchel(b, col, side=1, flap=None, scroll=None):
    """Sacoche à la hanche, bandoulière en travers du torse."""
    top = b['top']; T = b['T']; tH = b['o']['tH']; ch = T[2]; wa = T[1]
    x = side * (wa['w'] / 2 + 1.6)
    V(3.4, 3.2, 3.6, col, x, wa['y0'] + 0.4, 0.8, top)
    V(3.6, 1.4, 3.8, flap if flap is not None else shade(col, 1.15), x, wa['y0'] + 1.8, 0.8, top)
    V(0.6, 0.6, 0.4, GOLD, x, wa['y0'] + 1.3, 2.8, top)
    for i in range(6):
        t = i / 5.0
        V(1.2, 1.4, 0.5, shade(col, 0.85), side * (ch['w'] * 0.5 - t * ch['w']) * 0.95, tH - 0.6 - t * (tH - wa['y0'] - 2), ch['d'] / 2 + 1.25, top, rz=side * 0.75)
    if scroll is not None:
        V(1.0, 4.2, 1.0, scroll, x - side * 0.6, wa['y0'] + 3.4, 1.4, top, rz=side * 0.3)
        V(1.2, 0.5, 1.2, 0xa02a2a, x - side * 0.6, wa['y0'] + 3.4, 1.4, top, rz=side * 0.3)


def necklace(b, col, charm=None, charm_glow=False, n=7, drop=2.6, z_extra=0.6):
    """Collier en V sur le haut du torse, breloque au milieu."""
    top = b['top']; T = b['T']; tH = b['o']['tH']
    z = T[2]['d'] / 2 + z_extra
    w = T[3]['w'] * 0.6
    for i in range(n):
        t = (i - (n - 1) / 2.0) / ((n - 1) / 2.0)
        V(0.8, 0.8, 0.6, col, t * w / 2, tH - 0.4 - (1 - abs(t)) * drop, z, top)
    if charm is not None:
        (VG if charm_glow else V)(1.4, 1.8, 0.6, charm, 0, tH - 0.6 - drop - 1.2, z + 0.1, top)


def tabard(b, col, trim=GOLD, z_extra=1.3):
    """Tabard devant l'armure (l'emblème se pose à la profondeur renvoyée)."""
    top = b['top']; T = b['T']; tH = b['o']['tH']; ch = T[2]
    z = ch['d'] / 2 + z_extra
    V(ch['w'] * 0.62, tH * 0.88, 0.4, col, 0, tH * 0.5, z, top)
    V(ch['w'] * 0.62 + 0.4, 0.6, 0.5, trim, 0, tH * 0.06, z, top)
    V(ch['w'] * 0.62 + 0.4, 0.6, 0.5, trim, 0, tH * 0.94, z, top)
    return z


def banner(b, pole, cloth, height=34.0):
    """Hampe dans le dos, bannière en haut : se voit de très loin."""
    top = b['top']; T = b['T']; tH = b['o']['tH']
    z = back_z(b, 0.6); x = T[3]['w'] * 0.25
    V(1.0, height, 1.0, pole, x, height / 2 - 4, z, top, rz=-0.08)
    xt = x - math.sin(0.08) * (height - 4)
    V(9, 0.8, 0.8, pole, xt - 4.2, height - 5.5, z, top)
    V(8, 10, 0.5, cloth, xt - 4.2, height - 11, z, top)
    for i in range(3):
        V(8 / 3 - 0.2, 2.2, 0.5, shade(cloth, 0.9), xt - 4.2 - 8 / 3 + i * 8 / 3, height - 17 + (i % 2) * 0.8, z, top)
    return xt - 4.2, height - 11, z + 0.35


def flower_crown(b, leaf, flowers, y_off=0.0, r=None):
    h, hw, hh, hd = _head(b)
    r = r or hw * 0.62
    for i in range(12):
        a = i / 12.0 * 2 * math.pi
        x, z = math.sin(a) * r, math.cos(a) * r * hd / hw
        V(1.6, 0.9, 1.6, shade(leaf, 0.9 + (i % 3) * 0.08), x, hh / 2 + 0.2 + y_off, z, h, ry=a)
        if i % 2 == 0:
            V(1.4, 1.4, 1.4, flowers[(i // 2) % len(flowers)], x, hh / 2 + 1.1 + y_off, z, h, ry=a + 0.4)
            V(0.6, 0.6, 0.6, 0xffe060, x * 1.04, hh / 2 + 1.5 + y_off, z * 1.04, h)


def vines(b, col, flowers):
    """Lianes en spirale autour des bras."""
    o = b['o']
    for A in b['arms']:
        for i in range(6):
            a = i * 1.1
            V(1.0, 1.8, 0.7, shade(col, 1 + (i % 2) * 0.1), math.cos(a) * (o['aw'] / 2 + 0.4), -1.5 - i * 1.8,
              math.sin(a) * (o['ad'] / 2 + 0.4), A, rz=0.5, ry=a)
        V(1.2, 1.2, 1.2, flowers[0], o['aw'] / 2 + 0.6, -o['al'] * 0.45, 0.4, A)


# ---------------------------------------------------------------- les personnages
def orvane():
    """Orvane, l'Ancien des Racines : bois de racines feuillues, barbe de mousse, lueurs violettes du cristal."""
    b = body('spirit')
    root = 0x6a4a30
    antlers(b, root, leaf=0x7ad06a)
    h, hw, hh, hd = _head(b)
    # racines qui pendent en barbe, mousse
    for i, x in enumerate((-2.0, -0.7, 0.7, 2.0)):
        L = 4.0 + (i % 2) * 2.2
        V(0.9, L, 0.9, shade(root, 1 + (i % 2) * 0.1), x, -hh / 2 - L / 2 + 0.6, hd / 2 + 0.6, h)
    V(hw * 0.75, 1.4, 1.2, 0x5aa04a, 0, -hh / 2 + 0.2, hd / 2 + 0.7, h)
    motes(b, 0xb08aff, 6, 6.0, 1.5)
    return b['g']


def glou():
    """Glou, le petit slime : une pousse à deux feuilles sur la tête et des joues roses."""
    b = body('slime')
    h, hw, hh, hd = _head(b)
    V(0.7, 3.4, 0.7, 0x4a8a2a, 0.3, hh / 2 + 4.6, 0.4, h)
    for s in (-1, 1):
        V(2.6, 0.6, 1.6, 0x7ad04a, 0.3 + s * 1.5, hh / 2 + 6.4, 0.4, h, rz=s * 0.35)
        V(1.2, 0.6, 0.9, 0xa8f070, 0.3 + s * 2.4, hh / 2 + 6.9, 0.4, h, rz=s * 0.35)
        V(1.6, 0.9, 0.3, 0xff8ab0, s * hw * 0.34, -hh * 0.2, hd / 2 + 0.25, h)
    return b['g']


def grik():
    """Grik, l'ancien des gobelins : longue barbe blanche, plumes à la casquette, collier de dents et d'os."""
    b = body('goblin')
    h, hw, hh, hd = _head(b)
    beard(b, 0xe8e4dc, length=7.0, width=hw * 0.55)
    plume(h, (0x3a8ac8, 0xd84a2a, 0xe8c040), hw / 2 - 0.6, hh / 2 + 0.6, -1.0, n=3, L=4.6)
    necklace(b, BONE, charm=0x9ad8ff, charm_glow=True, z_extra=0.9)
    return b['g']


def _pip(b):
    h, hw, hh, hd = _head(b)
    # grande plume verte à la casquette, collier de crocs, carquois dans le dos
    plume(h, (0x5ac83a, 0x8ae05a), -(hw / 2 - 0.8), hh / 2 + 0.8, -0.4, n=2, L=5.0, lean=-0.35)
    necklace(b, 0xf0ecd8, n=5, drop=1.6, z_extra=0.6)
    top = b['top']; T = b['T']; tH = b['o']['tH']
    z = -(T[2]['d'] / 2 + 1.6)
    V(2.6, tH * 0.75, 2.6, LEATHER, 1.2, tH * 0.55, z, top, rz=-0.45)
    for i in range(3):
        V(0.4, 3.0, 0.4, 0x8a6238, 1.2 + 3.0 + i * 0.6 - 0.6, tH * 0.55 + tH * 0.38 + 0.6, z - 0.3 + i * 0.4, top, rz=-0.45)
        V(1.0, 1.0, 0.3, (0xe8e0c8, 0x5ac83a, 0xe8e0c8)[i], 1.2 + 3.7 + i * 0.6 - 0.6, tH * 0.55 + tH * 0.38 + 2.0, z - 0.3 + i * 0.4, top, rz=-0.45)
    return b['g']


def pip():
    """Pip, le jeune chasseur : plume verte à la casquette, collier de crocs, carquois dans le dos."""
    return _pip(body('goblin'))


def pip_alt():
    """Pip devenu hobgobelin : les mêmes trophées de chasseur."""
    return _pip(body('hobgoblin'))


def ulric():
    """Ulric, seigneur des loups : peau de loup sur les épaules (tête de loup sur la droite), cicatrice à l'œil."""
    b = body('lycan')
    h, hw, hh, hd = _head(b)
    o = b['o']; top = b['top']; T = b['T']; tH = o['tH']
    fur = 0x8a8a96
    collar(b, fur, 2.0)
    # mantelet de fourrure dans le dos
    V(T[3]['w'] + 1.4, tH * 0.55, 1.0, shade(fur, 0.9), 0, tH * 0.72, back_z(b, -0.6), top)
    # tête de loup sur l'épaule droite
    A = b['arms'][0]
    V(4.2, 3.4, 5.0, fur, 0, o['aw'] * 0.5 + 2.2, 0.4, A)
    V(2.6, 2.0, 2.8, shade(fur, 0.9), 0, o['aw'] * 0.5 + 1.6, 3.6, A)
    for s in (-1, 1):
        V(1.0, 1.8, 1.0, shade(fur, 0.8), s * 1.4, o['aw'] * 0.5 + 4.4, -0.6, A)
        VG(0.5, 0.5, 0.4, 0xffd04a, s * 1.0, o['aw'] * 0.5 + 2.8, 2.9, A)
    V(1.0, 0.8, 0.8, 0x1a1414, 0, o['aw'] * 0.5 + 2.0, 5.1, A)
    # trois griffures sur l'œil gauche
    for i in range(3):
        V(0.35, 3.4, 0.3, 0x8a3a3a, hw * 0.2 + i * 0.6, 0.2, hd / 2 + 0.55, h, rz=0.25)
    return b['g']


def maelle():
    """Maëlle, l'Érudite : lunettes rondes d'or, gros livre à la hanche, plume à l'oreille."""
    b = body('elf')
    h, hw, hh, hd = _head(b)
    ex = hw * 0.27
    for s in (-1, 1):
        for (dx, dy, w, hgt) in ((0, 1.0, 2.0, 0.4), (0, -0.9, 2.0, 0.4), (1.0, 0, 0.4, 2.2), (-1.0, 0, 0.4, 2.2)):
            V(w, hgt, 0.3, GOLD, s * ex + dx, dy, hd / 2 + 0.75, h)
        VA(1.6, 1.6, 0.2, 0xd8f0ff, s * ex, 0, hd / 2 + 0.7, h, alpha=0.35)
        V(0.4, 0.4, hd * 0.55, GOLD, s * (hw / 2 + 0.2), 0, hd * 0.2, h)
    V(1.2, 0.4, 0.3, GOLD, 0, 0.3, hd / 2 + 0.8, h)
    # gros livre relié à la hanche
    top = b['top']; T = b['T']; wa = T[1]
    x = wa['w'] / 2 + 1.9
    V(1.8, 4.6, 3.8, 0x7a1f2a, x, wa['y0'] + 0.6, 0.4, top)
    V(1.4, 4.2, 3.4, 0xf0e8d0, x - 0.3, wa['y0'] + 0.6, 0.4, top)
    V(2.0, 0.6, 3.9, GOLD, x, wa['y0'] + 1.6, 0.4, top)
    VG(0.5, 0.8, 0.8, 0x9ad8ff, x + 0.95, wa['y0'] + 0.6, 0.4, top)
    # plume d'écriture derrière l'oreille droite
    V(0.6, 4.0, 0.4, 0xf4f0e8, -(hw / 2 + 0.9), 0.8, -0.6, h, rz=0.5)
    return b['g']


def liora():
    """Liora, fée des pierres : diadème de cristal et pierres précieuses en orbite."""
    b = body('fairy')
    h, hw, hh, hd = _head(b)
    gems = (0xff8ad8, 0x8ae0ff, 0xb08aff, 0x8affc0)
    V(hw + 0.6, 0.6, hd + 0.6, SILVER, 0, hh / 2 - 0.4, 0, h)
    for i, (x, hgt) in enumerate(((-2.2, 1.6), (0, 2.8), (2.2, 1.6))):
        VA(1.2, hgt, 1.0, gems[i], x, hh / 2 + hgt / 2, hd / 2 - 0.2, h, alpha=0.85, glow=True)
    for i in range(5):
        a = i / 5.0 * 2 * math.pi
        VA(1.3, 1.6, 1.3, gems[i % 4], math.cos(a) * 6.5, hh / 2 + 1.0 + (i % 2) * 1.6, math.sin(a) * 6.5, h,
           alpha=0.85, rx=0.5, rz=0.5, glow=True)
    return b['g']


def kaede():
    """Kaede, la lame oni : bandeau rouge aux longs pans, fourreau du second sabre dans le dos."""
    b = body('kijin')
    h, hw, hh, hd = _head(b)
    red = 0xd82a2a
    # par-dessus les cheveux (qui débordent de la tête de 0.5 à 1 voxel)
    V(hw + 2.2, 1.4, hd + 2.6, red, 0, hh * 0.28, 0, h)
    VG(1.4, 1.4, 0.4, 0xffffff, 0, hh * 0.28, hd / 2 + 1.5, h, rz=0.785)
    V(2.0, 2.0, 1.4, shade(red, 0.85), 0, hh * 0.28, -(hd / 2 + 1.8), h)
    for s, L in ((-1, 8.0), (1, 6.4)):
        V(1.4, L, 0.5, shade(red, 0.9), s * 1.0, hh * 0.28 - L / 2, -(hd / 2 + 2.4), h, rx=0.4, rz=s * 0.2)
    top = b['top']; T = b['T']; tH = b['o']['tH']
    z = back_z(b)
    V(1.4, tH * 1.1, 1.0, 0x1a1414, 0, tH * 0.55, z, top, rz=0.7)
    V(1.0, 4.0, 1.0, 0xe8e0c8, -math.sin(0.7) * tH * 0.62, tH * 0.55 + math.cos(0.7) * tH * 0.62, z, top, rz=0.7)
    V(2.0, 0.5, 1.6, GOLD, -math.sin(0.7) * tH * 0.53, tH * 0.55 + math.cos(0.7) * tH * 0.53, z, top, rz=0.7)
    return b['g']


def ren():
    """Ren, l'oni masqué : masque d'oni blanc et rouge sur le visage, sous le casque à cornes."""
    b = body('kijin')
    h, hw, hh, hd = _head(b)
    z = hd / 2 + 1.0
    V(hw * 0.92, hh * 0.95, 0.6, 0xf0ece4, 0, -hh * 0.05, z, h)
    V(hw * 0.6, 1.4, 0.7, 0xf0ece4, 0, -hh * 0.55, z, h)
    for s in (-1, 1):
        V(1.8, 0.8, 0.3, 0x1a1414, s * hw * 0.24, hh * 0.05, z + 0.35, h, rz=s * 0.3)
        V(0.5, 2.6, 0.3, 0xc81a1a, s * hw * 0.32, -hh * 0.18, z + 0.35, h)
        V(0.9, 1.4, 0.3, 0xffffff, s * 0.8, -hh * 0.42, z + 0.4, h)
        V(0.6, 1.8, 0.8, 0xc81a1a, s * 1.2, hh * 0.38, z + 0.2, h, rz=-s * 0.3)
    V(hw * 0.4, 0.6, 0.3, 0x1a1414, 0, -hh * 0.32, z + 0.35, h)
    return b['g']


def kaia():
    """Kaïa, messagère des cimes : grande crête de plumes de couleur, sacoche de messages à rouleaux."""
    b = body('harpy')
    h, hw, hh, hd = _head(b)
    cols = (0xe84a2a, 0xffc040, 0x3aa8e8)
    for i in range(5):
        L = 5.0 - abs(i - 2) * 0.8
        V(1.0, L, 0.8, cols[i % 3], 0, hh / 2 + L / 2, hd / 2 - 1.2 - i * 1.3, h, rx=-0.35 - i * 0.12)
    satchel(b, LEATHER, side=-1, scroll=0xf0e8d0)
    return b['g']


def borin():
    """Borin, maître forgeron : barbe à nattes cerclées d'or, lunettes de forge sur le casque, tablier de cuir."""
    b = body('dwarf')
    h, hw, hh, hd = _head(b)
    beard(b, 0x8a4a2a, length=7.5, braids=True)
    # lunettes de forge relevées sur le casque
    V(hw + 2.2, 0.6, hd + 2.2, LEATHER_D, 0, hh / 2 + 0.8, 0, h)
    for s in (-1, 1):
        V(2.2, 2.2, 1.0, 0x4a4a52, s * 1.7, hh / 2 + 1.2, hd / 2 + 1.4, h)
        VG(1.4, 1.4, 0.4, 0xffa040, s * 1.7, hh / 2 + 1.2, hd / 2 + 1.9, h)
    # tablier de cuir devant l'armure, outils à la poche
    top = b['top']; T = b['T']; tH = b['o']['tH']; ch = T[2]; g = b['g']; o = b['o']
    z = ch['d'] / 2 + 1.5
    V(ch['w'] * 0.75, tH * 0.85, 0.5, 0x6a3a1e, 0, tH * 0.5, z, top)
    V(ch['w'] * 0.6, 3.0, 0.6, 0x5a2e16, 0, tH * 0.3, z + 0.3, top)
    V(0.6, 3.4, 0.6, 0x9aa0ab, -1.6, tH * 0.3 + 2.0, z + 0.4, top)
    V(0.8, 2.6, 0.6, 0x8a6238, 1.4, tH * 0.3 + 1.6, z + 0.4, top)
    V(ch['w'] * 0.7, 5.0, 0.5, 0x6a3a1e, 0, o['legH'] - 2.4, z - 0.2, g)
    return b['g']


def brunhild():
    """Brunhild, reine des nains : couronne d'or au-dessus du casque, nattes blondes cerclées d'or, torque d'or."""
    b = body('dwarf')
    h, hw, hh, hd = _head(b)
    spike_crown(h, GOLD, 0, hh / 2 + 2.2, 0, hw * 0.62, n=8, height=2.0, gem=RUBY)
    blond = 0xe8c060
    for s in (-1, 1):
        for i in range(4):
            V(1.8, 2.4, 1.8, shade(blond, 1 - i * 0.04), s * (hw / 2 + 1.8), -hh * 0.2 - i * 2.4, 0.4, h)
        V(2.2, 0.9, 2.2, GOLD, s * (hw / 2 + 1.8), -hh * 0.2 - 3.6, 0.4, h)
        V(2.2, 0.9, 2.2, GOLD, s * (hw / 2 + 1.8), -hh * 0.2 - 8.4, 0.4, h)
    top = b['top']; T = b['T']; tH = b['o']['tH']
    for i in range(9):
        a = i / 8.0 * math.pi
        V(1.4, 1.2, 1.2, GOLD_L if i % 2 else GOLD, math.cos(a) * T[3]['w'] * 0.32, tH + 0.2, T[3]['d'] / 2 + 0.6 + math.sin(a) * 0.8, top)
    VG(1.4, 1.4, 0.8, RUBY, 0, tH - 0.2, T[3]['d'] / 2 + 1.6, top, rz=0.785)
    return b['g']


def lysandre():
    """Lysandre, la marchande : gros sac à dos chargé (tapis roulé, marmite), bourse et anneaux d'or."""
    b = body('lizard')
    h, hw, hh, hd = _head(b)
    top = b['top']; T = b['T']; tH = b['o']['tH']
    z = back_z(b, 1.6)
    V(T[3]['w'] * 0.85, tH * 0.85, 4.4, 0x9a6a3a, 0, tH * 0.55, z, top)
    V(T[3]['w'] * 0.85 + 0.4, 1.2, 4.8, LEATHER_D, 0, tH * 0.85, z, top)
    V(T[3]['w'] * 1.3, 2.4, 2.4, 0xa02a5a, 0, tH * 1.05, z, top)
    for x in (-T[3]['w'] * 0.55, T[3]['w'] * 0.55):
        V(0.6, 2.5, 2.5, 0xe8c040, x, tH * 1.05, z, top)
    V(3.4, 2.6, 3.4, 0x4a4a52, 0, tH * 0.45, z - 3.0, top)
    V(3.8, 0.6, 3.8, 0x6e747e, 0, tH * 0.45 + 1.4, z - 3.0, top)
    # bourse dodue et anneaux d'or aux oreilles
    wa = T[1]
    V(2.4, 2.6, 2.4, 0x7a3f8f, -(wa['w'] / 2 + 1.4), wa['y0'] - 0.6, 1.4, top)
    V(1.2, 0.7, 1.2, GOLD, -(wa['w'] / 2 + 1.4), wa['y0'] + 0.9, 1.4, top)
    for s in (-1, 1):
        V(0.5, 1.4, 1.4, GOLD, s * (hw / 2 + 0.3), -hh * 0.2, -0.5, h)
    return b['g']


def zzar():
    """Zzar, reine de la Ruche : haute couronne de chitine ambrée au-dessus du casque, longues antennes lumineuses."""
    b = body('insectoid')
    h, hw, hh, hd = _head(b)
    amber = 0xffb030
    spike_crown(h, 0x6a4a1a, 0, hh / 2 + 2.2, 0, hw * 0.58, n=6, height=2.8, gem=None)
    for i in range(6):
        a = i / 6.0 * 2 * math.pi
        VG(0.9, 0.9, 0.9, amber, math.sin(a) * hw * 0.58, hh / 2 + 6.2 + (i % 2), math.cos(a) * hw * 0.58, h)
    VG(1.6, 1.6, 0.8, amber, 0, hh / 2 + 2.4, hw * 0.58 + 0.6, h, rz=0.785)
    for s in (-1, 1):
        V(0.6, 7.0, 0.6, 0x3a2a1a, s * 1.8, hh / 2 + 7.0, hd / 2 - 1.0, h, rx=0.45, rz=-s * 0.25)
        VG(1.2, 1.2, 1.2, amber, s * 2.7, hh / 2 + 10.2, hd / 2 + 0.6, h)
    return b['g']


def gorvak():
    """Gorvak, chef de la Horde : peintures de guerre, collier de crânes, étendard de la Horde dans le dos."""
    b = body('orc')
    h, hw, hh, hd = _head(b)
    face_marks(b, 0xd83a2a, glow=False)
    V(hw * 0.7, 0.6, 0.3, 0xd83a2a, 0, hh * 0.32, hd / 2 + 0.45, h)
    top = b['top']; T = b['T']; tH = b['o']['tH']
    z = T[2]['d'] / 2 + 1.0
    for i, x in enumerate((-3.6, 0, 3.6)):
        y = tH - 1.6 - (2.0 if i == 1 else 0.8)
        V(2.2, 2.0, 1.4, BONE, x, y, z + 0.4, top)
        for s in (-1, 1):
            V(0.5, 0.5, 0.3, 0x1a1414, x + s * 0.5, y + 0.1, z + 1.15, top)
    cx, cy, cz = banner(b, 0x5a3a28, 0x8a1a1a)
    # crâne d'ogre blanc sur l'étendard
    V(3.6, 3.2, 0.4, BONE, cx, cy + 0.6, cz - 0.95, top)
    for s in (-1, 1):
        V(0.9, 0.9, 0.3, 0x1a1414, cx + s * 0.8, cy + 0.9, cz - 1.25, top)
        V(0.7, 2.0, 0.3, BONE, cx + s * 1.4, cy - 1.6, cz - 0.95, top, rz=s * 0.4)
    return b['g']


def sylve():
    """Sylve, la dryade : couronne de fleurs, lianes fleuries autour des bras."""
    b = body('dryad')
    flowers = (0xff8ab0, 0xfff0f4, 0xffd04a, 0xc08aff)
    flower_crown(b, 0x4a9a3a, flowers, y_off=1.6)
    vines(b, 0x3a8a2a, flowers)
    return b['g']


def alderic():
    """Aldéric, chevalier d'Hauterive : panache bleu et or au casque, tabard bleu aux armes d'Hauterive."""
    b = body('human')
    h, hw, hh, hd = _head(b)
    blue = 0x2a4a9a
    plume(h, (blue, GOLD_L, blue, 0xf0f0f0), 0, hh / 2 + 3.2, -1.0, n=4, L=5.2, lean=-0.7)
    top = b['top']; tH = b['o']['tH']
    z = tabard(b, blue)
    # tour d'or d'Hauterive
    V(2.6, 3.2, 0.4, GOLD, 0, tH * 0.55, z + 0.3, top)
    for x in (-1.0, 0, 1.0):
        V(0.7, 0.8, 0.4, GOLD, x, tH * 0.55 + 2.0, z + 0.3, top)
    V(0.9, 1.4, 0.3, 0x1a2a5a, 0, tH * 0.55 - 0.9, z + 0.55, top)
    return b['g']


def edmond():
    """Edmond, roi d'Hauterive : couronne d'or aux rubis, col d'hermine, barbe grise."""
    b = body('human')
    h, hw, hh, hd = _head(b)
    crown(b, GOLD, n=8, height=2.2, gem=RUBY)
    for i in range(4):
        a = i / 4.0 * 2 * math.pi + 0.4
        VG(0.7, 0.7, 0.7, RUBY, math.sin(a) * hw * 0.52, hh / 2 + 2.6, math.cos(a) * hw * 0.52 * hd / hw, h)
    beard(b, 0xb8b4b0, length=5.0)
    # col d'hermine (blanc moucheté de noir) par-dessus l'armure
    top = b['top']; T = b['T']; tH = b['o']['tH']
    w = T[3]['w']; d = T[3]['d']
    for i in range(12):
        a = i / 12.0 * 2 * math.pi
        x, z = math.cos(a) * w * 0.5, math.sin(a) * d * 0.62
        V(2.6, 2.2, 2.6, 0xf4f0ec, x, tH + 0.6, z, top)
        if i % 2 == 0:
            V(0.5, 1.0, 0.5, 0x1a1414, x, tH + 0.6, z + (1.35 if z >= 0 else -1.35), top)
    return b['g']


def morvain():
    """Morvain, Grand Inquisiteur : haut col blanc doublé de rouge, grand soleil d'or au cou (encore intact)."""
    b = body('human')
    h, hw, hh, hd = _head(b)
    top = b['top']; T = b['T']; tH = b['o']['tH']; ch = T[2]
    V(ch['w'] + 1.6, 4.4, 0.9, 0xf0ece0, 0, tH + 1.8, -(T[3]['d'] / 2 + 1.2), top, rx=-0.25)
    V(ch['w'] + 0.8, 3.8, 0.5, 0x8a1a2a, 0, tH + 1.7, -(T[3]['d'] / 2 + 0.7), top, rx=-0.25)
    # écharpe rouge d'inquisiteur
    z = ch['d'] / 2 + 0.9
    for s in (-1, 1):
        V(1.4, tH * 0.8, 0.4, 0xa01a2a, s * 1.6, tH * 0.55, z, top)
    sy = tH - 2.0; sz = z + 0.5
    V(2.6, 2.6, 0.5, GOLD, 0, sy, sz, top)
    for i in range(8):
        a = i / 8.0 * 2 * math.pi
        V(0.5, 1.4, 0.4, GOLD_L, math.cos(a) * 2.2, sy + math.sin(a) * 2.2, sz, top, rz=a - math.pi / 2)
    VG(0.9, 0.9, 0.6, 0xfff0a0, 0, sy, sz + 0.3, top, rz=0.785)
    return b['g']


def selene():
    """Séléné, reine de la Nuit : croissant de lune d'argent derrière la tête, diadème, petites chauves-souris."""
    b = body('vampire')
    h, hw, hh, hd = _head(b)
    zh = -(hd / 2 + 1.4)
    for i in range(9):
        a = math.pi * 0.15 + i / 8.0 * math.pi * 1.2
        VG(1.6, 1.2 - abs(i - 4) * 0.1, 0.6, 0xe0e8ff, math.cos(a + 1.2) * 5.0, hh / 2 + 1.6 + math.sin(a + 1.2) * 5.0, zh, h, rz=a + 1.2 + math.pi / 2)
    V(hw + 0.6, 0.5, hd + 0.6, SILVER, 0, hh * 0.3, 0, h)
    VG(1.0, 1.0, 0.5, 0xff2a5a, 0, hh * 0.3, hd / 2 + 0.6, h, rz=0.785)
    # chauves-souris qui volettent
    for i, (x, y, z) in enumerate(((6.5, 3.0, 2.0), (-6.0, 5.0, -1.0), (4.5, 7.0, -4.0))):
        V(1.0, 1.0, 1.0, 0x2a1a2a, x, hh / 2 + y, z, h)
        for s in (-1, 1):
            V(1.8, 0.4, 0.8, 0x3a2232, x + s * 1.3, hh / 2 + y + 0.3, z, h, rz=s * 0.4)
    return b['g']


def vharok():
    """Vharok, dernier des dragonides : une corne brisée, écailles de braise sur le poitrail, croc de dragon au cou."""
    b = body('dragonoid')
    h, hw, hh, hd = _head(b)
    ember = 0xff6a1a
    # corne gauche entière (au-delà de celles de la race), corne droite cassée net
    for i, (dx, dy, w, L) in enumerate(((1.0, 0.8, 1.8, 3.6), (2.0, 3.6, 1.5, 3.4), (2.6, 6.2, 1.1, 3.0))):
        V(w, L, w, shade(0x3a2a24, 1 + i * 0.08), hw / 2 + dx, hh / 2 + dy, -1.6 - i * 0.6, h, rx=-0.3, rz=-0.35 - i * 0.2)
    VG(0.8, 1.0, 0.8, ember, hw / 2 + 3.2, hh / 2 + 8.2, -3.4, h)
    V(1.8, 2.0, 1.8, 0x3a2a24, -(hw / 2 + 1.0), hh / 2 + 0.6, -1.6, h, rz=0.35)
    V(1.9, 0.5, 1.9, 0xc8b8a0, -(hw / 2 + 1.25), hh / 2 + 1.6, -1.6, h, rz=0.35)
    # croc de dragon au cou, écailles de braise devant l'armure
    necklace(b, 0x3a2a24, n=7, drop=2.0, z_extra=1.4)
    top = b['top']; T = b['T']; tH = b['o']['tH']; ch = T[2]
    V(1.4, 3.6, 1.0, BONE, 0, tH - 5.0, ch['d'] / 2 + 1.6, top)
    for i, (x, y) in enumerate(((-3.6, 0.0), (3.6, 0.6), (-2.6, -2.4), (3.0, -2.2))):
        VG(1.4, 1.0, 0.4, ember, x, ch['cy'] + y, ch['d'] / 2 + 1.4, top, rz=0.785)
    return b['g']


def aurele():
    """Aurèle, le Séraphin : auréole d'or au-dessus du casque et une seconde paire d'ailes, plus petite."""
    b = body('angel')
    halo(b, 0xffe08a, r=4.4, y=6.2, n=10)
    from voxel_evolution_generator import mini_feather_wings
    mini_feather_wings(b, 0xfff4e0, 0xf0d8a0, sc=0.6, y_off=-7.0, n=5)
    motes(b, 0xfff0a0, 5, 6.0, 2.0)
    return b['g']


def cael():
    """Caël, le premier Éveillé : yeux et cœur de Brume, diadème de cristal, éclats qui flottent."""
    b = body('undead')
    h, hw, hh, hd = _head(b)
    eye_glow(b, BRUME)
    V(hw + 0.6, 0.6, hd + 0.6, 0x3a2a5a, 0, hh * 0.32, 0, h)
    for i, (x, L) in enumerate(((-1.8, 2.0), (0, 3.2), (1.8, 2.0))):
        VA(1.0, L, 0.8, BRUME, x, hh * 0.32 + L / 2 + 0.3, hd / 2 + 0.1, h, alpha=0.85, glow=True)
    top = b['top']; T = b['T']; ch = T[2]
    VA(2.4, 2.4, 1.0, BRUME, 0, ch['cy'] + 0.6, ch['d'] / 2 + 1.0, top, alpha=0.9, rz=0.785, glow=True)
    VG(1.0, 1.0, 1.2, 0xffffff, 0, ch['cy'] + 0.6, ch['d'] / 2 + 1.1, top, rz=0.785)
    floating_crystals(b, BRUME, 3)
    return b['g']


CHARS = {
    'orvane': orvane, 'glou': glou, 'grik': grik, 'pip': pip, 'pip_alt': pip_alt, 'ulric': ulric,
    'maelle': maelle, 'liora': liora, 'kaede': kaede, 'ren': ren, 'kaia': kaia, 'borin': borin,
    'brunhild': brunhild, 'lysandre': lysandre, 'zzar': zzar, 'gorvak': gorvak, 'sylve': sylve,
    'alderic': alderic, 'edmond': edmond, 'morvain': morvain, 'selene': selene, 'vharok': vharok,
    'aurele': aurele, 'cael': cael,
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='../assets/characters/story')
    ap.add_argument('--only', default='')
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    only = [s for s in a.only.split(',') if s]
    n = 0
    for name, f in CHARS.items():
        if only and name not in only:
            continue
        export_glb(f(), os.path.join(a.out, name + '.glb')); n += 1
    print('%d fichier(s) .glb écrit(s) dans %s' % (n, a.out))


if __name__ == '__main__':
    main()
