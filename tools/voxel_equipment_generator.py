#!/usr/bin/env python3
"""
Générateur des équipements voxel (armes, armures, casques...) -> un fichier .glb par race pour Godot 4.

Chaque pièce est construite sur les mesures exactes du corps NU de la race (tailles des étages
du torse, des bras, des jambes, de la tête), pour épouser la silhouette de chaque race.

Structure d'un fichier `<race>_equipment.glb` :
    Equipment > <id_objet> > Root__<id> > LegL__<id>, LegR__<id>, Torso__<id> > (ArmL__<id> > HandL__<id>), ...
Les nœuds reprennent les noms (avant « __ ») et positions du squelette du personnage : dans Godot,
chaque maillage est accroché au nœud du même nom sur le personnage et suit donc ses mouvements.

Le fichier `items_ground.glb` contient les objets simples (matériaux) posés au sol.

Usage :
    python voxel_equipment_generator.py --out ../assets/equipment
"""
import argparse, json, os, struct
from voxel_character_generator import (Node, V, VG, VA, GLB, mk, gen, shade, RACES, RACE_ORDER, UNIT)

WOOD = 0x8a6238
WOOD_D = 0x6a4428
IRON = 0x9aa0ab
IRON_D = 0x6e747e
IRON_L = 0xc8ced6
STEEL = 0xd9dde3
GOLD = 0xd8b04a
LEATHER = 0x7a4a2a
LEATHER_D = 0x5a341c
LEATHER_L = 0x9a6438
CLOTH_R = 0xa02a2a
CLOTH_B = 0x2a4a9a
ROBE = 0x4a3a8a
ROBE_L = 0x6a5ab0
ORB = 0x7fe0ff


# ---------------------------------------------------------------- corps de référence
def body(race):
    i = RACE_ORDER.index(race)
    p = gen(race, 'forgeron', mk(97 + i * 13 + 1))
    p['naked'] = True
    p['cape'] = False
    return RACES[race]('forgeron', p)


def mirror(b, tag):
    """Copie vide du squelette (mêmes positions, rotations, échelle).
    Les nœuds s'appellent `<os>__<objet>` (ex. HandL__sword_iron) : des noms uniques dans le fichier,
    sinon l'import de Godot les renumérote (HandL2...)."""
    mp = {}

    def cp(n):
        m = Node('%s__%s' % (n.name, tag), n.t, n.rx)
        m.scale = n.scale
        mp[id(n)] = m
        for k in n.kids:
            if not k.name.startswith('Slot_'):
                m.kids.append(cp(k))
        return m

    g = cp(b['g'])
    e = dict(o=b['o'], T=b['T'], g=g, top=mp[id(b['top'])], head=mp[id(b['head'])],
             arms=[mp[id(a)] for a in b['arms']], legs=[mp[id(l)] for l in b['legs']],
             hand_l=mp[id(b['hand_p'])], hand_r=mp[id(b['hand_m'])])
    return e


# ---------------------------------------------------------------- armes (tenues dans HandL, pointe vers +Y)
def sword_wood(e):
    h = e['hand_l']
    V(1.2, 5, 1.2, LEATHER_D, 0, 0, 0, h)
    V(1.6, 1.4, 1.6, WOOD_D, 0, -3, 0, h)
    V(5, 1.2, 1.8, WOOD_D, 0, 3, 0, h)
    V(2, 13, 0.9, WOOD, 0, 10.2, 0, h)
    V(1.4, 1.4, 0.9, WOOD, 0, 17.2, 0, h)


def sword_iron(e):
    h = e['hand_l']
    V(1.2, 5, 1.2, LEATHER_D, 0, 0, 0, h)
    V(1.8, 1.6, 1.8, GOLD, 0, -3.2, 0, h)
    V(6.4, 1.4, 2, IRON_D, 0, 3.2, 0, h)
    V(1.2, 1.2, 1.2, GOLD, 0, 3.2, 1.2, h)
    V(2.2, 17, 0.8, IRON_L, 0, 12.4, 0, h)
    V(0.6, 15, 0.9, IRON, 0, 11.6, 0, h)
    V(1.4, 1.6, 0.8, IRON_L, 0, 21.6, 0, h)
    V(0.6, 1.2, 0.8, STEEL, 0, 22.8, 0, h)


def axe(e):
    h = e['hand_l']
    V(1.2, 17, 1.2, WOOD, 0, 4.5, 0, h)
    V(1.6, 1.4, 1.6, LEATHER_D, 0, 0.5, 0, h)
    V(1.8, 5, 2, IRON_D, 0, 11.5, 0, h)
    V(4.6, 6, 0.9, IRON, 2.8, 11.5, 0, h)
    V(1.2, 7.6, 1, STEEL, 5.4, 11.5, 0, h)
    V(2, 2.4, 0.9, IRON_D, -1.8, 11.5, 0, h)


def war_hammer(e):
    h = e['hand_l']
    V(1.2, 16, 1.2, WOOD, 0, 4, 0, h)
    V(1.6, 1.4, 1.6, LEATHER_D, 0, 0, 0, h)
    V(6.4, 4, 3.6, IRON, 0, 12.6, 0, h)
    for s in (-1, 1):
        V(1, 4.6, 4.2, IRON_D, s * 3.4, 12.6, 0, h)
    V(1.6, 1.6, 1.6, GOLD, 0, 15.2, 0, h)


def _hand_axe(e, head, edge):
    """Hache d'outil (plus petite que la hache de guerre), tenue dans HandL."""
    h = e['hand_l']
    V(1.1, 14, 1.1, WOOD, 0, 4, 0, h)
    V(1.5, 1.3, 1.5, WOOD_D, 0, -2.6, 0, h)
    V(1.8, 4, 1.9, head, 1.2, 9.5, 0, h)
    V(2.8, 5, 1.6, head, 3, 9.5, 0, h)
    V(0.8, 6, 1.7, edge, 4.7, 9.5, 0, h)


def _hand_pick(e, head, tip):
    """Pioche d'outil, tenue dans HandL : fer horizontal au bout du manche."""
    h = e['hand_l']
    V(1.1, 14, 1.1, WOOD, 0, 4, 0, h)
    V(1.5, 1.3, 1.5, WOOD_D, 0, -2.6, 0, h)
    V(2.4, 2.4, 2, head, 0, 11, 0, h)
    for s in (-1, 1):
        V(3, 1.8, 1.7, head, s * 2.6, 10.6, 0, h)
        V(2, 1.4, 1.4, tip, s * 4.8, 9.8, 0, h)


def _hand_hoe(e, head):
    """Houe, tenue dans HandL : lame plate d'un seul côté, au bout du manche."""
    h = e['hand_l']
    V(1.1, 15, 1.1, WOOD, 0, 4.5, 0, h)
    V(1.5, 1.3, 1.5, WOOD_D, 0, -2.6, 0, h)
    V(1.8, 1.8, 1.8, head, 0, 11.4, 0, h)
    V(3.4, 1.2, 3.2, head, 2.2, 11.2, 0, h)
    V(1.2, 3.4, 3.4, shade(head, 1.15), 4.3, 10, 0, h)


def houe(e): _hand_hoe(e, 0x8a8a86)
def hache_bois(e): _hand_axe(e, 0xa87848, 0xc89868)
def hache_pierre(e): _hand_axe(e, 0x8a8a86, 0xb8b8b2)
def pioche_bois(e): _hand_pick(e, 0xa87848, 0xc89868)
def pioche_pierre(e): _hand_pick(e, 0x8a8a86, 0xb8b8b2)
def hache_fer(e): _hand_axe(e, IRON_D, STEEL)
def pioche_fer(e): _hand_pick(e, IRON_D, STEEL)


def spear(e):
    h = e['hand_l']
    V(1, 30, 1, WOOD, 0, 9, 0, h)
    V(1.6, 1.6, 1.6, LEATHER, 0, 22.4, 0, h)
    V(2.4, 1.4, 1.2, STEEL, 0, 24.2, 0, h)
    V(1.8, 2, 1, STEEL, 0, 26, 0, h)
    V(1, 2, 0.8, IRON_L, 0, 28, 0, h)
    V(0.6, 3, 0.4, CLOTH_R, 0.9, 21, 0, h)


def dagger(e):
    h = e['hand_l']
    V(1.1, 3.6, 1.1, LEATHER_D, 0, 0, 0, h)
    V(3.4, 1, 1.4, IRON_D, 0, 2.2, 0, h)
    V(1.6, 6, 0.7, STEEL, 0, 5.6, 0, h)
    V(0.8, 1.2, 0.7, STEEL, 0, 9.2, 0, h)


def staff(e):
    h = e['hand_l']
    V(1, 30, 1, WOOD, 0, 9, 0, h)
    for s in (-1, 1):
        V(0.8, 3, 0.8, WOOD, s * 1.1, 25, 0, h, rz=-s * 0.4)
    VG(2.8, 2.8, 2.8, ORB, 0, 27, 0, h, rx=0.6, rz=0.6)
    VG(1.4, 1.4, 1.4, 0xffffff, 0, 27, 0, h, rx=0.6, rz=0.6)
    V(1.4, 1.2, 1.4, GOLD, 0, 23.4, 0, h)


def shield_parts(e):
    o = e['o']
    A = e['arms'][0]  # ArmR
    return A, -o['al'] * 0.5, o['ad'] / 2 + 1.6


def shield_wood(e):
    A, sy, sz = shield_parts(e)
    for i, x in enumerate((-3, -1, 1, 3)):
        V(2, 10 - abs(x) * 0.6, 1.2, WOOD if i % 2 else shade(WOOD, 0.9), x - 1, sy, sz, A)
    V(9, 1.2, 1.5, WOOD_D, -1, sy + 3, sz, A)
    V(9, 1.2, 1.5, WOOD_D, -1, sy - 3, sz, A)
    V(2.4, 2.4, 0.9, IRON, -1, sy, sz + 0.9, A)


def shield_iron(e):
    A, sy, sz = shield_parts(e)
    V(9.2, 11, 1.3, CLOTH_B, -1, sy, sz, A)
    V(10, 11.8, 0.8, IRON, -1, sy, sz - 0.4, A)
    V(7, 2.4, 1.3, CLOTH_B, -1, sy - 6.6, sz, A)
    V(7.8, 2.4, 0.8, IRON, -1, sy - 6.6, sz - 0.4, A)
    V(3.8, 2, 1.3, CLOTH_B, -1, sy - 8.6, sz, A)
    V(2.6, 2.6, 0.9, GOLD, -1, sy + 1, sz + 0.9, A)
    V(1.2, 12, 0.5, GOLD, -1, sy - 1, sz + 0.7, A)
    V(8, 1.2, 0.5, GOLD, -1, sy + 1, sz + 0.7, A)


# ---------------------------------------------------------------- tête
def leather_cap(e):
    o = e['o']; h = e['head']; hw = o['hw']; hh = o['hh']; hd = o['hd']; HT = hh / 2
    V(hw + 1.4, 2.6, hd + 1.4, LEATHER, 0, HT - 0.2, 0, h)
    V(hw + 1.8, 0.9, hd + 1.8, LEATHER_D, 0, HT - 1.6, 0, h)
    V(hw + 1.2, hh * 0.7, 1.2, LEATHER, 0, -0.4, -(hd / 2 + 0.5), h)
    for s in (-1, 1):
        V(1, hh * 0.55, hd * 0.6, LEATHER, s * (hw / 2 + 0.6), -0.2, -hd * 0.15, h)
    V(1.2, 1.2, 0.5, GOLD, 0, HT - 1.6, hd / 2 + 0.9, h)


def iron_helmet(e):
    o = e['o']; h = e['head']; hw = o['hw']; hh = o['hh']; hd = o['hd']; HT = hh / 2
    V(hw + 1.6, 4, hd + 1.6, IRON, 0, HT - 0.4, 0, h)
    V(hw + 2.2, 0.8, hd + 2.2, IRON_L, 0, HT - 2.4, 0, h)
    for s in (-1, 1):
        V(1, 4.4, 2.6, IRON, s * (hw / 2 + 0.9), -1.5, hd / 2 - 1.6, h)
    V(1, 4.4, 0.8, IRON, 0, -1.2, hd / 2 + 0.7, h)
    V(hw + 1.2, hh * 0.6, 1.2, IRON_D, 0, -0.6, -(hd / 2 + 0.5), h)
    for i in range(4):
        V(1.4, 2.4 - i * 0.3, 1.6, CLOTH_R, 0, HT + 2.4, -hd / 2 + 1.6 + i * 1.8, h)
    V(1.4, 4, 1.4, CLOTH_R, 0, HT, -hd / 2 - 1.2, h)


def horned_helmet(e):
    o = e['o']; h = e['head']; hw = o['hw']; hh = o['hh']; hd = o['hd']; HT = hh / 2
    V(hw + 1.6, 3.4, hd + 1.6, IRON_D, 0, HT - 0.2, 0, h)
    V(hw - 1, 1.4, hd - 1, IRON, 0, HT + 2, 0, h)
    V(hw + 2.2, 1, hd + 2.2, GOLD, 0, HT - 2, 0, h)
    V(1.2, 4, 0.8, IRON_D, 0, -0.8, hd / 2 + 0.8, h)
    for s in (-1, 1):
        V(2, 2, 2, 0xe8e0c8, s * (hw / 2 + 1.6), HT, 0, h)
        V(1.6, 2.6, 1.6, 0xe8e0c8, s * (hw / 2 + 2.8), HT + 1.8, 0, h, rz=-s * 0.3)
        V(1.2, 2.4, 1.2, 0xf4f0e0, s * (hw / 2 + 3.4), HT + 3.8, 0, h, rz=-s * 0.1)


def mage_hat(e):
    o = e['o']; h = e['head']; hw = o['hw']; hh = o['hh']; hd = o['hd']; HT = hh / 2
    V(hw + 7, 0.9, hd + 7, ROBE, 0, HT + 0.1, 0, h)
    for i in range(5):
        w = hw + 1.4 - i * 1.8
        V(w, 2.2, w * hd / hw, ROBE, i * i * 0.18, HT + 1.5 + i * 2.1, 0, h)
    V(hw + 1.8, 0.9, hd + 1.8, GOLD, 0, HT + 1.2, 0, h)
    VG(1.2, 1.2, 0.6, ORB, 0, HT + 2.6, hd / 2 + 0.8, h)


# ---------------------------------------------------------------- torse
def leather_armor(e):
    o = e['o']; T = e['T']; top = e['top']; tH = o['tH']
    ch = T[2]; wa = T[1]; sh = T[3]
    V(ch['w'] + 0.6, ch['h'] + 0.2, ch['d'] + 0.6, LEATHER, 0, ch['cy'], 0, top)
    V(wa['w'] + 0.6, wa['h'], wa['d'] + 0.6, LEATHER_D, 0, wa['cy'], 0, top)
    V(sh['w'] + 0.4, sh['h'], sh['d'] + 0.6, LEATHER_L, 0, sh['cy'], 0, top)
    V(wa['w'] + 1, 1.4, wa['d'] + 1, LEATHER_D, 0, wa['y0'] + 0.4, 0, top)
    V(2, 1.8, 0.6, GOLD, 0, wa['y0'] + 0.4, wa['d'] / 2 + 0.8, top)
    V(1.4, tH * 0.9, 0.6, LEATHER_D, 0, tH * 0.5, ch['d'] / 2 + 0.5, top, rz=0.6)
    for i in range(3):
        V(0.8, 0.8, 0.5, GOLD, -1.8 + i * 1.8, ch['cy'] + 1.4 - i * 1.4, ch['d'] / 2 + 0.6, top)
    for a in e['arms']:
        V(o['aw'] + 1.4, 2.4, o['ad'] + 1.4, LEATHER_L, 0, 0.4, 0, a)


WOOL = 0xf0e8d6
WOOL_D = 0xd8ccb4


def manteau_laine(e):
    """Manteau de laine : épais, col de laine bouclée, boutons de bois."""
    o = e['o']; T = e['T']; top = e['top']; tH = o['tH']
    ch = T[2]; wa = T[1]; sh = T[3]
    V(ch['w'] + 1.2, ch['h'] + 0.4, ch['d'] + 1.2, 0x8a5a3a, 0, ch['cy'], 0, top)
    V(wa['w'] + 1.2, wa['h'] + 0.4, wa['d'] + 1.2, 0x7a4a2e, 0, wa['cy'], 0, top)
    V(sh['w'] + 1.4, sh['h'] + 0.6, sh['d'] + 1.4, WOOL, 0, sh['cy'] + 0.4, 0, top)
    for x in (-2.4, 0, 2.4):
        V(2.2, 2, 2.2, WOOL_D, x, sh['cy'] + sh['h'] / 2 + 0.8, 0, top)
    V(wa['w'] + 1.6, 1.4, wa['d'] + 1.6, WOOL, 0, wa['y0'] + 0.2, 0, top)
    for i in range(3):
        V(0.9, 0.9, 0.5, WOOD_D, 0, ch['cy'] + 1.6 - i * 1.6, ch['d'] / 2 + 0.9, top)
    for a in e['arms']:
        V(o['aw'] + 1.6, 3, o['ad'] + 1.6, WOOL, 0, 0.2, 0, a)


def iron_armor(e):
    o = e['o']; T = e['T']; top = e['top']; tH = o['tH']
    ch = T[2]; wa = T[1]; sh = T[3]
    V(ch['w'] + 0.8, ch['h'] + 0.2, ch['d'] + 0.8, IRON, 0, ch['cy'], 0, top)
    V(sh['w'] + 0.6, sh['h'] + 0.2, sh['d'] + 0.8, IRON_D, 0, sh['cy'], 0, top)
    V(0.8, ch['h'] * 0.9, 0.6, IRON_L, 0, ch['cy'], ch['d'] / 2 + 0.6, top)
    V(2.4, 3, 0.6, GOLD, 0, ch['cy'] + 0.4, ch['d'] / 2 + 0.9, top)
    for i in range(3):
        V(wa['w'] + 0.8 + i * 0.2, 1.1, wa['d'] + 0.8, shade(IRON, 1 - i * 0.06), 0, wa['y0'] + wa['h'] - 0.6 - i * 1.0, 0, top)
    V(wa['w'] * 0.9, 6, 0.7, CLOTH_R, 0, -1.8, wa['d'] / 2 + 1, top)
    V(wa['w'] * 0.9, 6, 0.7, shade(CLOTH_R, 0.85), 0, -1.8, -wa['d'] / 2 - 1, top)
    for a in e['arms']:
        V(o['aw'] + 2.6, 1.4, o['ad'] + 2.6, IRON, 0, 0.9, 0, a)
        V(o['aw'] + 2.2, 1.2, o['ad'] + 2.2, IRON_D, 0, -0.3, 0, a)
        V(o['aw'] + 1.8, 1.2, o['ad'] + 1.8, shade(IRON, 0.85), 0, -1.4, 0, a)


def mage_robe(e):
    o = e['o']; T = e['T']; top = e['top']; g = e['g']; tH = o['tH']
    ch = T[2]; wa = T[1]; sh = T[3]
    for t, c in ((ch, ROBE), (wa, shade(ROBE, 0.9)), (sh, ROBE)):
        V(t['w'] + 0.5, t['h'] + 0.1, t['d'] + 0.5, c, 0, t['cy'], 0, top)
    V(ch['w'] + 3, 2.4, sh['d'] + 2.4, ROBE_L, 0, tH - 0.2, 0, top)
    for s in (-1, 1):
        VG(1.2, 1.2, 1.2, ORB, s * (ch['w'] / 2 + 1.4), tH - 0.2, 0, top)
    V(1.4, 1.4, 0.7, GOLD, 0, tH - 0.6, ch['d'] / 2 + 1.3, top)
    V(1.2, tH * 0.8, 0.5, GOLD, 0, tH * 0.45, ch['d'] / 2 + 0.4, top)
    yb = o['legH']
    V(wa['w'] + 1.6, 4.5, wa['d'] + 1.6, ROBE, 0, yb * 0.82, 0, g)
    V(wa['w'] + 2.6, 4.5, wa['d'] + 2.6, shade(ROBE, 0.95), 0, yb * 0.82 - 4.4, 0, g)
    V(wa['w'] + 3.6, 4.6, wa['d'] + 3.6, shade(ROBE, 0.9), 0, yb * 0.82 - 8.8, 0, g)
    V(wa['w'] + 4, 1.1, wa['d'] + 4, ROBE_L, 0, max(0.9, yb * 0.82 - 11.4), 0, g)
    for a in e['arms']:
        V(o['aw'] + 1.2, o['al'] * 0.46, o['ad'] + 1.2, ROBE, 0, -o['al'] * 0.23, 0, a)
        V(o['aw'] + 2, 5.4, o['ad'] + 2, ROBE, 0, -o['al'] * 0.48, 0, a)
        V(o['aw'] + 2.6, 1.2, o['ad'] + 2.6, ROBE_L, 0, -o['al'] * 0.48 - 2.8, 0, a)


# ---------------------------------------------------------------- bras
def leather_bracers(e):
    o = e['o']
    for a in e['arms']:
        V(o['aw'] + 0.9, o['al'] * 0.3, o['ad'] + 0.9, LEATHER, 0, -o['al'] * 0.72, 0, a)
        V(o['aw'] + 1.1, 0.8, o['ad'] + 1.1, LEATHER_D, 0, -o['al'] * 0.62, 0, a)
        V(o['aw'] + 1.1, o['aw'] + 0.9, o['ad'] + 1.1, LEATHER_D, 0, -o['al'] + o['aw'] * 0.35, 0.2, a)


def iron_gauntlets(e):
    o = e['o']
    for a in e['arms']:
        V(o['aw'] + 0.9, o['al'] * 0.3, o['ad'] + 0.9, IRON, 0, -o['al'] * 0.72, 0, a)
        V(o['aw'] + 1.4, 1.6, o['ad'] + 1.4, IRON_L, 0, -o['al'] * 0.46 - 0.4, 0, a)
        V(o['aw'] + 1, o['aw'] + 0.8, o['ad'] + 1, IRON_D, 0, -o['al'] + o['aw'] * 0.35, 0.2, a)
        V(o['aw'] + 1.2, 0.6, o['ad'] + 1.2, GOLD, 0, -o['al'] * 0.58, 0, a)


# ---------------------------------------------------------------- jambes (pantalon + bottes)
def legs_common(e, c1, c2, boot, knee=None):
    o = e['o']; T = e['T']; top = e['top']
    th = o['legH'] * 0.46; sh = o['legH'] * 0.32; bt = o['legH'] * 0.22
    lw = o['lw']; ld = o['ld']
    V(T[0]['w'] + 0.6, T[0]['h'] + 0.4, T[0]['d'] + 0.6, c2, 0, T[0]['cy'] - 0.1, 0, top)
    for l in e['legs']:
        V(lw + 0.6, th, ld + 0.6, c1, 0, -th / 2, 0, l)
        V(lw * 0.88 + 0.6, sh, ld * 0.9 + 0.6, shade(c1, 0.93), 0, -th - sh / 2, 0, l)
        V(lw + 1, bt, ld + 1.1, boot, 0, -o['legH'] + bt / 2, 0.2, l)
        V(lw + 1.4, 1, ld + 1.5, shade(boot, 1.3), 0, -o['legH'] + bt, 0.2, l)
        V(lw + 0.7, bt * 0.55, 2.4, boot, 0, -o['legH'] + bt * 0.3, ld / 2 + 1.3, l)
        if knee:
            V(lw + 1.2, 2.2, ld + 1.2, knee, 0, -th - 0.2, 0.3, l)
            V(lw + 0.9, sh * 0.8, ld + 0.9, shade(knee, 0.9), 0, -th - sh / 2 - 0.4, 0.2, l)


def leather_pants(e):
    legs_common(e, 0x6a5a48, LEATHER_D, LEATHER_D)


def iron_greaves(e):
    legs_common(e, 0x4a4a52, IRON_D, IRON_D, knee=IRON)


# ---------------------------------------------------------------- dos
def cape(e, col):
    o = e['o']; T = e['T']; top = e['top']; tH = o['tH']; cw = T[2]['w']
    V(cw + 0.6, tH * 1.25, 0.9, col, 0, tH * 0.42, -(T[2]['d'] / 2 + 0.8), top, rx=0.05)
    for i in range(4):
        V(cw / 4 + 0.1, 2 + (i % 2) * 1.6, 0.9, shade(col, 0.9), -cw * 0.375 + i * cw / 4,
          tH * 0.42 - tH * 0.625 - 1 - (i % 2) * 0.8, -(T[2]['d'] / 2 + 0.9), top)
    V(cw * 0.7, 1.6, T[3]['d'] + 1.2, col, 0, tH + 0.1, 0, top)
    V(1.3, 1.3, 0.7, GOLD, 0, tH - 0.4, T[3]['d'] / 2 + 0.9, top)


ITEMS = {
    'sword_wood': sword_wood, 'sword_iron': sword_iron, 'axe': axe, 'war_hammer': war_hammer,
    'spear': spear, 'dagger': dagger, 'staff': staff,
    'shield_wood': shield_wood, 'shield_iron': shield_iron,
    'leather_cap': leather_cap, 'iron_helmet': iron_helmet, 'horned_helmet': horned_helmet, 'mage_hat': mage_hat,
    'leather_armor': leather_armor, 'iron_armor': iron_armor, 'mage_robe': mage_robe,
    'leather_bracers': leather_bracers, 'iron_gauntlets': iron_gauntlets,
    'leather_pants': leather_pants, 'iron_greaves': iron_greaves,
    'cape_red': lambda e: cape(e, CLOTH_R), 'cape_blue': lambda e: cape(e, CLOTH_B),
    # outils (tenus en main quand le héros récolte)
    'hache_bois': hache_bois, 'hache_pierre': hache_pierre, 'pioche_bois': pioche_bois, 'pioche_pierre': pioche_pierre,
    'hache_fer': hache_fer, 'pioche_fer': pioche_fer, 'houe': houe, 'manteau_laine': manteau_laine,
}


# ---------------------------------------------------------------- matériaux (objets au sol)
def m_wood():
    g = Node('wood')
    for i, (x, z) in enumerate(((-3, 0), (3, 0), (0, 0))):
        V(5, 5, 22, WOOD if i % 2 else shade(WOOD, 0.9), x, 2.5 + (5 if i == 2 else 0), z, g)
        V(4, 4, 0.4, 0xc8a070, x, 2.5 + (5 if i == 2 else 0), 11.1, g)
    return g


def m_stone():
    g = Node('stone')
    V(9, 6, 8, 0x8a8a86, 0, 3, 0, g)
    V(6, 4, 6, 0x9a9890, 1, 7, -1, g)
    V(4, 3, 4, 0x7a7a78, -4, 1.5, 3, g)
    return g


def m_iron_ore():
    g = Node('iron_ore')
    V(10, 7, 9, 0x6e6e6c, 0, 3.5, 0, g)
    V(6, 4, 6, 0x7a7a78, 1, 8, -1, g)
    for x, y, z in ((-3, 5, 4.6), (2, 3, 4.6), (5.1, 5, 0), (0, 10.1, -1), (-5.1, 2, -2)):
        V(2.4, 2.4, 2.4, 0xc88a5a, x, y, z, g)
    return g


def m_iron_ingot():
    g = Node('iron_ingot')
    for i, (x, y) in enumerate(((-3, 1.5), (3, 1.5), (0, 4.5))):
        V(5, 3, 12, IRON_L if i == 2 else IRON, x, y, 0, g)
        V(3.6, 0.6, 10, STEEL, x, y + 1.7, 0, g)
    return g


def m_leather():
    g = Node('leather')
    V(14, 1.2, 10, LEATHER, 0, 0.6, 0, g)
    V(12, 1.2, 8, LEATHER_L, 1, 1.8, 0.5, g)
    V(3, 2.6, 1, LEATHER_D, 0, 2, 5, g)
    return g


def m_fiber():
    g = Node('fiber')
    for i in range(7):
        V(1, 12, 1, (0xc8b060, 0xb8a050, 0xd8c070)[i % 3], -3 + i, 6, 0, g, rz=(i - 3) * 0.08)
    V(8, 1.6, 1.8, 0x8a6a3a, 0, 5, 0, g)
    return g


def _tool_handle(g):
    V(1.6, 16, 1.6, WOOD, 0, 8, 0, g)
    V(2, 1.2, 2, WOOD_D, 0, 0.6, 0, g)


def _axe(name, head, edge):
    g = Node(name)
    _tool_handle(g)
    V(2.2, 5, 2.4, head, 1.8, 13.5, 0, g)      # tête collée au manche
    V(1.4, 7, 2.4, head, 3.6, 13.5, 0, g)
    V(0.8, 8, 2.6, edge, 4.7, 13.5, 0, g)      # tranchant
    return g


def _pick(name, head, tip):
    g = Node(name)
    _tool_handle(g)
    V(3, 2.6, 2.4, head, 0, 15, 0, g)
    for s in (-1, 1):
        V(3.2, 2, 2, head, s * 3, 14.6, 0, g)
        V(2.2, 1.6, 1.6, tip, s * 5.4, 13.8, 0, g)
    return g


def m_hache_bois(): return _axe('hache_bois', 0xa87848, 0xc89868)
def m_hache_pierre(): return _axe('hache_pierre', 0x8a8a86, 0xb8b8b2)
def m_pioche_bois(): return _pick('pioche_bois', 0xa87848, 0xc89868)
def m_pioche_pierre(): return _pick('pioche_pierre', 0x8a8a86, 0xb8b8b2)
def m_hache_fer(): return _axe('hache_fer', IRON_D, STEEL)
def m_pioche_fer(): return _pick('pioche_fer', IRON_D, STEEL)


def m_baies():
    g = Node('baies')
    for i, (x, z) in enumerate(((-3, -2), (2, -3), (0, 2), (4, 2), (-4, 3), (1, -0.5))):
        V(3.4, 3.4, 3.4, 0xc8283c if i % 2 else 0x8a1a5a, x, 1.7 + (2.2 if i == 5 else 0), z, g)
    V(1, 2, 1, 0x3a7a2a, 1, 6.2, -0.5, g)
    V(4, 0.6, 2, 0x4a9a3a, 2.5, 6.8, -0.5, g)
    return g


def m_viande_crue():
    g = Node('viande_crue')
    V(12, 5, 8, 0xc8505a, 0, 2.5, 0, g)
    V(8, 4, 6, 0xe07078, 1, 5.5, 0, g)
    V(3, 3, 3, 0xf0e6d2, -7, 2.5, 0, g)
    V(2, 1, 6, 0xf0c8c8, 2, 4.6, 0, g)
    return g


def m_viande_cuite():
    g = Node('viande_cuite')
    V(12, 5, 8, 0x8a4a22, 0, 2.5, 0, g)
    V(8, 4, 6, 0xa85a2a, 1, 5.5, 0, g)
    V(3, 3, 3, 0xf0e6d2, -7, 2.5, 0, g)
    V(6, 1, 1, 0x5a2a12, 1, 7.6, -1.5, g)
    V(6, 1, 1, 0x5a2a12, 1, 7.6, 1.5, g)
    return g


def m_ragout():
    g = Node('ragout')
    V(14, 5, 14, 0x6a4428, 0, 2.5, 0, g)
    V(16, 1.5, 16, 0x8a6238, 0, 5.6, 0, g)
    V(11, 1, 11, 0xa85a2a, 0, 5.4, 0, g)
    for x, z, c in ((-2, -2, 0xc8283c), (3, 1, 0x8a1a5a), (0, 3, 0xe0a060), (-3, 2, 0x5a8a3a)):
        V(2.4, 1.4, 2.4, c, x, 6.2, z, g)
    return g


def m_pain():
    g = Node('pain')
    V(14, 6, 8, 0xc88a3a, 0, 3, 0, g)
    V(12, 2, 6, 0xe0a860, 0, 6.6, 0, g)
    for x in (-4, 0, 4):
        V(1.2, 0.8, 5, 0xf0d090, x, 7.8, 0, g)
    return g


def m_houe():
    g = Node('houe')
    _tool_handle(g)
    V(2.4, 2.4, 2.4, 0x8a8a86, 0, 15, 0, g)
    V(4, 1.6, 3.6, 0x8a8a86, 2.6, 15, 0, g)
    V(1.4, 4.4, 4, 0xa8a8a2, 5, 13.4, 0, g)
    return g


def m_graines_ble():
    g = Node('graines_ble')
    V(10, 7, 8, 0xc8b088, 0, 3.5, 0, g)          # petit sac de toile
    V(8, 2, 6, 0xb89c74, 0, 7.6, 0, g)
    V(3, 2, 3, 0x8a6a3a, 0, 9.4, 0, g)
    for x, z in ((-7, 3), (-6, -2), (7, 2), (6.5, -3), (-8, 0)):
        V(1.4, 1, 1.4, 0xe0c060, x, 0.5, z, g)
    return g


def m_ble():
    g = Node('ble')
    for i in range(7):
        x = -3 + i
        V(1, 14, 1, (0xd8b848, 0xc8a840, 0xe0c858)[i % 3], x, 7, 0, g, rz=(i - 3) * 0.07)
        V(1.8, 4, 1.8, 0xf0d060, x + (i - 3) * 0.5, 15.5, 0, g, rz=(i - 3) * 0.07)
    V(9, 1.6, 2, 0x8a6a3a, 0, 6, 0, g)
    return g


def m_carotte():
    g = Node('carotte')
    for i, (w, y) in enumerate(((4, 6), (3.4, 3.2), (2.6, 0.9), (1.6, -1.1))):
        V(w, 2.6, w, 0xe8802a if i % 2 == 0 else 0xf09038, 0, y + 2.4, 0, g, rz=1.2)
    for dx, dz in ((-1, 0), (0, 1), (1, -1)):
        V(1, 6, 1, 0x4a9a3a, 6 + dx * 0.4, 5.5 + abs(dx) * 0.5, dz, g, rz=1.2 + dx * 0.25)
    return g


def m_pomme_de_terre():
    g = Node('pomme_de_terre')
    V(9, 6, 7, 0xb8905a, 0, 3, 0, g)
    V(7, 2, 5, 0xc8a068, 0.5, 6.4, 0, g)
    for x, y, z in ((-3, 4, 3.6), (2, 2, 3.6), (4.6, 4, -1)):
        V(1, 1, 0.4, 0x7a5a32, x, y, z, g)
    return g


def m_pomme_de_terre_cuite():
    g = Node('pomme_de_terre_cuite')
    V(9, 6, 7, 0x8a5a2a, 0, 3, 0, g)
    V(6, 1, 5, 0xf0d890, 0, 6.2, 0, g)
    V(3, 1, 3, 0xfff0b0, 0, 6.9, 0, g)
    return g


def m_soupe_legumes():
    g = Node('soupe_legumes')
    V(14, 5, 14, 0x6a4428, 0, 2.5, 0, g)
    V(16, 1.5, 16, 0x8a6238, 0, 5.6, 0, g)
    V(11, 1, 11, 0xd8a040, 0, 5.4, 0, g)
    for x, z, c in ((-2, -2, 0xe8802a), (3, 1, 0xf0d890), (0, 3, 0xe8802a), (-3, 2, 0x5a9a3a), (2, -3, 0xf0d890)):
        V(2.4, 1.4, 2.4, c, x, 6.2, z, g)
    return g


def m_oeuf():
    g = Node('oeuf')
    for i, (x, z) in enumerate(((-3, 0), (3, 1), (0, -3))):
        V(4, 5, 4, 0xf4ecd8 if i != 1 else 0xd8a878, x, 2.5, z, g)
        V(3, 1, 3, 0xfff8ec if i != 1 else 0xe8bc90, x, 5.4, z, g)
    return g


def m_lait():
    g = Node('lait')
    V(10, 12, 10, 0x9a6a3a, 0, 6, 0, g)          # seau
    V(10.6, 1.4, 10.6, 0x6a4428, 0, 3, 0, g)
    V(10.6, 1.4, 10.6, 0x6a4428, 0, 10, 0, g)
    V(8.4, 1, 8.4, 0xfaf6ee, 0, 12, 0, g)          # lait
    V(1, 8, 1, 0x4e5258, -5.4, 14, 0, g, rz=-0.5)
    V(1, 8, 1, 0x4e5258, 5.4, 14, 0, g, rz=0.5)
    return g


def m_laine():
    g = Node('laine')
    for x, y, z, s in ((-3, 3, 0, 7), (3, 3.5, 1, 7.4), (0, 7, -0.5, 6.6), (0, 3, -4, 5.4)):
        V(s, s * 0.8, s, 0xf2eee4, x, y, z, g)
        V(s * 0.5, s * 0.4, s * 0.5, 0xe0d8c8, x + 1, y + s * 0.4, z + 1, g)
    return g


def m_omelette():
    g = Node('omelette')
    V(16, 1.4, 16, 0xe8e0d0, 0, 0.7, 0, g)         # assiette
    V(12, 2.4, 8, 0xf0d050, 0, 2.4, 0, g)
    V(9, 1, 6, 0xf8e070, 0, 3.8, 0, g)
    V(2, 0.6, 1, 0x4a9a3a, -2, 4.4, 1, g)
    return g


def m_fromage():
    g = Node('fromage')
    V(14, 7, 10, 0xf0c850, 0, 3.5, 0, g)
    V(14.4, 1.2, 10.4, 0xd8a838, 0, 7.2, 0, g)
    for x, y in ((-4, 4), (2, 2.4), (4, 5)):
        V(2, 2, 0.6, 0xc89830, x, y, 5.2, g)
    return g


def m_gateau():
    g = Node('gateau')
    V(16, 1.2, 16, 0xe8e0d0, 0, 0.6, 0, g)
    V(13, 6, 13, 0xd89a58, 0, 4, 0, g)
    V(13.6, 2, 13.6, 0xfaf4ec, 0, 7.8, 0, g)
    for x, z in ((-4, -4), (4, 4), (4, -4), (-4, 4), (0, 0)):
        V(2, 2, 2, 0xd8283c, x, 9.6, z, g)
    return g


FARM = [m_houe, m_graines_ble, m_ble, m_carotte, m_pomme_de_terre, m_pomme_de_terre_cuite, m_soupe_legumes,
        m_oeuf, m_lait, m_laine, m_omelette, m_fromage, m_gateau]


MATERIALS = [m_baies, m_viande_crue, m_viande_cuite, m_ragout, m_pain, m_wood, m_stone, m_iron_ore, m_iron_ingot, m_leather, m_fiber,
             m_hache_bois, m_hache_pierre, m_pioche_bois, m_pioche_pierre, m_hache_fer, m_pioche_fer] + FARM


# ---------------------------------------------------------------- export
def export(root, path, image_uri):
    """Comme export_glb, mais la texture de grain est un fichier partagé (pas de copie par fichier)."""
    g = GLB()
    ridx = g.add_node(root)
    doc = {'asset': {'version': '2.0', 'generator': 'voxel_equipment_generator.py'},
           'scene': 0, 'scenes': [{'nodes': [ridx]}], 'nodes': g.nodes, 'meshes': g.meshes,
           'materials': g.mats,
           'textures': [{'sampler': 0, 'source': 0}],
           'samplers': [{'magFilter': 9728, 'minFilter': 9728, 'wrapS': 10497, 'wrapT': 10497}],
           'images': [{'uri': image_uri}],
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
    ap.add_argument('--out', default='../assets/equipment')
    ap.add_argument('--race', default='all')
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    grain = '../environment/voxel_grain.png'
    races = RACE_ORDER if a.race == 'all' else [a.race]
    for race in races:
        b = body(race)
        root = Node('Equipment')
        for item_id, fn in ITEMS.items():
            e = mirror(b, item_id)
            fn(e)
            holder = Node(item_id)
            holder.kids.append(e['g'])
            root.kids.append(holder)
        export(root, os.path.join(a.out, '%s_equipment.glb' % race), grain)
    ground = Node('Materials')
    ground.kids = [f() for f in MATERIALS]
    export(ground, os.path.join(a.out, 'materials.glb'), grain)
    print('%d race(s) x %d objets, %d matériaux -> %s' % (len(races), len(ITEMS), len(MATERIALS), a.out))


if __name__ == '__main__':
    main()
