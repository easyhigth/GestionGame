#!/usr/bin/env python3
"""
Générateur des modèles voxel des ENNEMIS NOMMÉS (seigneurs, adversaires de l'histoire, chef bandit) -> .glb pour Godot 4.

Comme les boss (voxel_boss_generator.py), chacun part du corps nu de sa race et garde EXACTEMENT ses nœuds
(Root > LegL, LegR, Torso > ArmL/HandL, ArmR/HandR, Head) : scripts/voxel_character.gd l'anime comme les autres
et il porte toujours l'équipement de sa race (<race>_equipment.glb). Ce qui change : une palette à lui et des
pièces placées AUTOUR de l'équipement (au-dessus du casque, devant l'armure, dans le dos) pour qu'on le
reconnaisse de loin. La taille de jeu reste réglée par `model_scale` dans data/enemies/<ennemi>.tres.

Fichiers écrits :
    named/<ennemi>.glb      (même nom que data/enemies/<ennemi>.tres)

Usage :
    python voxel_named_enemy_generator.py --out ../assets/characters/named
    python voxel_named_enemy_generator.py --only morvain_parjure,ren_possede
"""
import argparse, math, os
from voxel_character_generator import V, VG, VA, shade, export_glb
from voxel_evolution_generator import (_head, horns, shoulder_spikes, back_spines, face_marks, eye_glow,
                                       collar, halo, motes, floating_crystals, aura_ring)
from voxel_boss_generator import humanoid, spike_crown, GOLD, GOLD_L, BONE, RUBY

BRUME = 0xb48cff      # DungeonManager.BRUME_COLOR
BRUME_D = 0x5a3a8a
SOUL = 0x60d0ff


# ---------------------------------------------------------------- outils
def skull(pa, x, y, z, s=1.0, eye=None, ry=0.0):
    """Petit crâne tourné vers +Z (orbites sombres, ou lumineuses si `eye`)."""
    V(2.2 * s, 2.0 * s, 2.0 * s, BONE, x, y, z, pa, ry=ry)
    V(1.6 * s, 0.8 * s, 1.6 * s, shade(BONE, 0.92), x, y - 1.2 * s, z + 0.2 * s, pa, ry=ry)
    f = VG if eye is not None else V
    for sx in (-1, 1):
        f(0.55 * s, 0.55 * s, 0.3, eye if eye is not None else 0x1a1414, x + sx * 0.5 * s, y + 0.1 * s, z + 1.05 * s, pa)


def wing(b, bone, mem, s, sc=1.0, y_off=0.0, z_off=0.0, angs=(0.35, 0.95, 1.55), glow=None, alpha=None):
    """Une aile de chauve-souris (côté `s`) : trois os, une membrane entre eux, lueur au bout des os."""
    top = b['top']; T = b['T']; tH = b['o']['tH']
    x0 = s * (T[3]['w'] / 2 - 0.5); y0 = tH - 0.5 + y_off; z0 = -(T[3]['d'] / 2 + 3.2) - z_off
    lens = (17 * sc, 15 * sc, 11 * sc)
    for a, Lb in zip(angs, lens):
        V(1.5, Lb, 1.3, bone, x0 + s * math.sin(a) * Lb / 2, y0 + math.cos(a) * Lb / 2, z0, top, rz=-s * a)
        if glow is not None:
            VG(1.2, 1.6, 1.2, glow, x0 + s * math.sin(a) * Lb, y0 + math.cos(a) * Lb, z0, top)
    for i in range(2):
        a = (angs[i] + angs[i + 1]) / 2; Lm = (lens[i] + lens[i + 1]) / 2
        args = (Lm * (angs[i + 1] - angs[i]) * 0.95, Lm * 0.8, 0.5, shade(mem, 1 - i * 0.08),
                x0 + s * math.sin(a) * Lm * 0.47, y0 + math.cos(a) * Lm * 0.47, z0 - 0.2, top)
        if alpha is not None:
            VA(*args, alpha=alpha, rz=-s * a, glow=glow is not None)
        else:
            V(*args, rz=-s * a)


def feather_wing(b, c1, c2, s, sc=1.0, y_off=0.0, z_off=0.0, a0=0.25, a1=2.2, n=7, tip=None):
    """Une aile de plumes (côté `s`), réglable en hauteur et en angle (pour les séraphins à six ailes)."""
    top = b['top']; T = b['T']; tH = b['o']['tH']
    x0 = s * (T[3]['w'] / 2 - 1); y0 = tH - 2 + y_off; z0 = -(T[3]['d'] / 2 + 2.4) - z_off
    for i in range(n):
        a = a0 + i * (a1 - a0) / (n - 1)
        L = (14 - i * 0.9) * sc
        V(2.0 * sc, L, 0.6, c1 if i % 2 == 0 else c2, x0 + s * math.sin(a) * L / 2, y0 + math.cos(a) * L / 2, z0 - (i % 2) * 0.3, top, rz=-s * a)
        if tip is not None and i % 2 == 0:
            VG(1.0 * sc, 1.4 * sc, 0.7, tip, x0 + s * math.sin(a) * L, y0 + math.cos(a) * L, z0, top, rz=-s * a)


def wisps(b, col, n=8, r=6.5, alpha=0.45):
    """Volutes de brume translucides autour des pieds."""
    g = b['g']
    for i in range(n):
        a = i / float(n) * 2 * math.pi + 0.2
        VA(3.2 + (i % 3), 1.6 + (i % 2) * 1.2, 3.2, col, math.cos(a) * r, 0.9 + (i % 2) * 0.8, math.sin(a) * r, g,
           alpha=alpha, ry=-a, glow=True)


def ragged_cape(b, col, z_extra=1.4, n=6, length=1.3):
    """Cape en lambeaux, assez loin dans le dos pour passer derrière l'armure."""
    top = b['top']; T = b['T']; tH = b['o']['tH']; cw = T[3]['w'] + 1.2
    z = -(T[2]['d'] / 2 + z_extra)
    V(cw, 1.6, T[3]['d'] + 2.0, shade(col, 1.1), 0, tH + 0.2, -0.2, top)
    for i in range(n):
        L = tH * length - (i % 3) * 2.6 - (i % 2) * 1.4
        V(cw / n + 0.1, L, 0.8, shade(col, 0.92 + (i % 2) * 0.12), -cw / 2 + (i + 0.5) * cw / n, tH - L / 2, z - (i % 2) * 0.2, top, rx=0.06)


def crystal_cluster(pa, col, x, y, z, n=4, size=1.4, tilt=0.5, alpha=0.8):
    """Grappe de cristaux qui sortent d'un point (vers le haut et l'extérieur)."""
    for i in range(n):
        a = i / float(n) * 2 * math.pi
        hgt = size * (2.2 + (i % 2) * 1.2)
        VA(size, hgt, size, shade(col, 1 + (i % 2) * 0.12), x + math.cos(a) * size * 0.6, y + hgt * 0.35, z + math.sin(a) * size * 0.6,
           pa, alpha=alpha, rx=math.sin(a) * tilt, rz=-math.cos(a) * tilt, glow=True)


# ---------------------------------------------------------------- démons
def seigneur_demon():
    """Seigneur démon : peau rouge sang, seconde paire de grandes cornes noires, ailes plus vastes,
    épaulières d'os hérissées, crânes à la ceinture, chaîne en travers du torse, queue à pointe de fer."""
    b, p = humanoid('demon', 0x8a1a1a, hs=1, eye=0xffd030)
    h, hw, hh, hd = _head(b)
    o = b['o']; top = b['top']; T = b['T']; tH = o['tH']
    ember = 0xff5a1a
    # grandes cornes noires qui sortent sur les côtés du casque
    horns(b, 0x1a1418, 4, x=hw / 2 + 1.6, z=0, size=1.9, spread=0.42, back=0.5, tip=ember)
    face_marks(b, ember)
    eye_glow(b, 0xffb030)
    # ailes plus grandes, membrane rouge sombre
    for s in (-1, 1):
        wing(b, 0x2a1414, 0x5a1414, s, sc=1.05, glow=ember)
    # épaulières d'os à trois pointes, au-dessus des spalières de fer
    shoulder_spikes(b, BONE, 3, 1.7, glow=ember)
    for A in b['arms']:
        V(o['aw'] + 3.6, 1.0, o['ad'] + 3.6, 0x3a2420, 0, 2.0, 0, A)
    # chaîne d'acier noir en travers du torse, crâne au milieu
    ch = T[2]
    for i in range(7):
        t = (i - 3) / 3.0
        V(1.4, 1.0, 0.6, 0x3a3a42 if i % 2 else 0x5a5a64, t * ch['w'] * 0.48, ch['cy'] + t * ch['h'] * 0.42, ch['d'] / 2 + 1.5, top, rz=0.7)
    skull(top, 0, ch['cy'], ch['d'] / 2 + 1.6, 0.9, eye=ember)
    # crânes pendus à la ceinture
    wa = T[1]
    for x in (-wa['w'] * 0.38, wa['w'] * 0.38):
        skull(top, x, wa['y0'] - 0.6, wa['d'] / 2 + 1.8, 0.8)
    # pointe de queue en fer
    V(1.0, 1.0, 4.4, 0x4a4a52, 0, 4.6, -(T[0]['d'] / 2 + 20.6), top)
    V(2.6, 2.6, 0.9, 0x6e747e, 0, 4.6, -(T[0]['d'] / 2 + 19.6), top, rz=0.785)
    motes(b, ember, 6, 7.0, 3.0)
    aura_ring(b, 0xc81a1a)
    return b['g']


def seigneur_brume():
    """Seigneur de la Brume (Caël, le premier Éveillé) : peau d'ombre, cornes de cristal violet, couronne de Brume,
    ailes translucides, cœur de cristal fêlé sur la poitrine, cristaux en orbite, volutes de brume au sol."""
    b, p = humanoid('demon', 0x2a2236, hs=1, eye=BRUME)
    h, hw, hh, hd = _head(b)
    o = b['o']; top = b['top']; T = b['T']; tH = o['tH']
    face_marks(b, BRUME)
    eye_glow(b, 0xe0c8ff)
    # cornes de cristal sur les côtés du casque, couronne de Brume au-dessus
    for s in (-1, 1):
        for i, (dx, dy, w, L) in enumerate(((1.4, 0.4, 1.6, 4.0), (2.6, 3.2, 1.3, 3.6), (3.6, 5.8, 1.0, 3.0))):
            VA(w, L, w, shade(BRUME, 1 + i * 0.08), s * (hw / 2 + dx), hh / 2 + dy, -0.4 - i * 0.6, h,
               alpha=0.8, rz=-s * (0.35 + i * 0.2), glow=True)
    for i in range(9):
        a = i / 9.0 * 2 * math.pi
        hgt = 2.2 + (i % 3) * 1.3
        VA(1.2, hgt, 1.2, (BRUME, 0xe0c8ff, BRUME_D)[i % 3], math.sin(a) * hw * 0.55, hh / 2 + 3.4 + hgt / 2,
           math.cos(a) * hd * 0.55, h, alpha=0.85, glow=True)
    # grandes ailes translucides
    for s in (-1, 1):
        wing(b, 0x1a1424, BRUME_D, s, sc=1.2, glow=BRUME, alpha=0.6)
    # cœur de cristal fêlé, devant l'armure
    ch = T[2]
    VA(3.4, 3.4, 1.4, BRUME, 0, ch['cy'] + 0.6, ch['d'] / 2 + 1.6, top, alpha=0.9, rz=0.785, glow=True)
    VG(1.4, 1.4, 1.6, 0xffffff, 0, ch['cy'] + 0.6, ch['d'] / 2 + 1.7, top, rz=0.785)
    V(0.3, 3.6, 0.4, 0x1a1424, 0.4, ch['cy'] + 0.6, ch['d'] / 2 + 2.4, top, rz=0.35)
    # éclats de cristal sur les épaules et les avant-bras
    for A in b['arms']:
        crystal_cluster(A, BRUME, 0, o['aw'] * 0.5 + 1.6, 0, n=3, size=1.2)
        VG(o['aw'] * 0.4, 0.4, 0.3, BRUME, 0, -o['al'] * 0.6, o['ad'] / 2 + 1.1, A)
    floating_crystals(b, BRUME, 4)
    motes(b, 0xe0c8ff, 10, 8.0, 3.0)
    wisps(b, BRUME, 10, 7.0)
    aura_ring(b, BRUME)
    return b['g']


# ---------------------------------------------------------------- morts-vivants
def seigneur_squelette():
    """Seigneur squelette : os jaunis, couronne de fer à pierres d'âme, flammes bleues dans les orbites,
    épaulières en crânes, épines d'os dans le dos, cape en lambeaux, lanterne d'âme à la ceinture."""
    b, p = humanoid('undead', 0xd8ccae, eye=SOUL)
    h, hw, hh, hd = _head(b)
    o = b['o']; top = b['top']; T = b['T']; tH = o['tH']
    # flammes bleues au-dessus des orbites (visibles sous le casque)
    for s in (-1, 1):
        VG(1.0, 2.0, 0.5, SOUL, s * hw * 0.27, hh * 0.02 + 1.2, hd / 2 + 0.6, h)
    # couronne de fer noirci et pierres d'âme, au-dessus du casque
    spike_crown(h, 0x4a4a52, 0, hh / 2 + 2.6, 0, hw * 0.62, n=7, height=2.6, gem=SOUL)
    for i in range(7):
        a = i / 7.0 * 2 * math.pi
        VG(0.7, 0.7, 0.7, SOUL, math.sin(a) * hw * 0.62, hh / 2 + 6.2 + (i % 2), math.cos(a) * hw * 0.62, h)
    # épaulières en crânes
    for A in b['arms']:
        skull(A, 0, o['aw'] * 0.5 + 2.2, 0.2, 1.1, eye=SOUL)
    shoulder_spikes(b, BONE, 2, 1.0)
    # épines d'os et cape en lambeaux dans le dos
    ragged_cape(b, 0x2a2238, z_extra=1.6)
    back_spines(b, BONE, 5, 1.2, glow=SOUL)
    # côtes lumineuses devant l'armure, lanterne d'âme à la hanche
    ch = T[2]
    for j in range(3):
        VG(ch['w'] * (0.5 - j * 0.08), 0.35, 0.3, SOUL, 0, ch['y0'] + 1.2 + j * 1.1, ch['d'] / 2 + 1.25, top)
    wa = T[1]
    x = wa['w'] / 2 + 1.6
    V(0.4, 2.0, 0.4, 0x3a3a42, x, wa['y0'] - 0.4, 0.6, top)
    V(2.2, 2.6, 2.2, 0x3a3a42, x, wa['y0'] - 2.6, 0.6, top)
    VA(1.6, 2.0, 1.6, SOUL, x, wa['y0'] - 2.6, 0.6, top, alpha=0.85, glow=True)
    wisps(b, SOUL, 6, 6.0, 0.35)
    aura_ring(b, SOUL)
    return b['g']


# ---------------------------------------------------------------- histoire
def morvain_parjure():
    """Morvain le Parjure, Grand Inquisiteur vampire : peau livide, cheveux blancs, tabard d'inquisiteur à croix rouge,
    soleil d'or brisé au cou, haut col, auréole fendue derrière la tête, chaînes de templier, gouttes de sang."""
    b, p = humanoid('vampire', 0xe4dce4, hair=0xf0eef4, eye=0xff2a4a)
    h, hw, hh, hd = _head(b)
    o = b['o']; top = b['top']; T = b['T']; tH = o['tH']; ch = T[2]
    # haut col blanc doublé de rouge, derrière la nuque
    V(ch['w'] + 1.6, 4.4, 0.9, 0xf0ece0, 0, tH + 1.8, -(T[3]['d'] / 2 + 1.0), top, rx=-0.25)
    V(ch['w'] + 0.8, 3.8, 0.5, 0x8a1a2a, 0, tH + 1.7, -(T[3]['d'] / 2 + 0.5), top, rx=-0.25)
    # tabard blanc à croix rouge par-dessus la robe
    zt = ch['d'] / 2 + 1.0
    V(ch['w'] * 0.62, tH * 0.95, 0.4, 0xf0ece0, 0, tH * 0.48, zt, top)
    V(ch['w'] * 0.62 + 0.4, 0.6, 0.5, GOLD, 0, tH * 0.48 - tH * 0.475, zt, top)
    V(1.1, tH * 0.55, 0.4, 0xa01a2a, 0, tH * 0.5, zt + 0.3, top)
    V(ch['w'] * 0.45, 1.1, 0.4, 0xa01a2a, 0, tH * 0.62, zt + 0.3, top)
    # soleil d'or brisé (le parjure) : une moitié terne et fendue
    sy = tH - 1.6; sz = zt + 0.8
    V(2.4, 2.4, 0.5, GOLD, -0.5, sy, sz, top)
    V(1.2, 2.4, 0.5, 0x8a6a2a, 1.3, sy - 0.2, sz, top, rz=-0.2)
    for i in range(8):
        a = i / 8.0 * 2 * math.pi
        if math.cos(a) > 0.3:
            continue    # les rayons du côté brisé sont tombés
        V(0.5, 1.4, 0.4, GOLD_L, -0.5 + math.cos(a) * 2.0, sy + math.sin(a) * 2.0, sz, top, rz=a - math.pi / 2)
    VG(0.8, 0.8, 0.6, RUBY, -0.5, sy, sz + 0.3, top, rz=0.785)
    # auréole fendue derrière la tête (au-delà du bord du chapeau)
    zh = -(hd / 2 + 4.2)
    for i in range(12):
        if i in (2, 3):
            continue
        a = i / 12.0 * 2 * math.pi
        VG(1.7, 0.6, 0.6, 0xc89a3a if i % 3 else 0xffd060, math.cos(a) * 5.4, hh / 2 + 0.6 + math.sin(a) * 5.4, zh, h, rz=a + math.pi / 2)
    # chaînes de templier aux poignets
    for A in b['arms']:
        for i in range(3):
            V(o['aw'] + 3.0, 0.5, o['ad'] + 3.0, 0x5a5a64 if i % 2 else 0x7a7a84, 0, -o['al'] * 0.66 - i * 0.7, 0, A, ry=i * 0.4)
        V(0.7, 2.4, 0.7, 0x5a5a64, 0, -o['al'] * 0.66 - 2.6, o['ad'] / 2 + 1.4, A)
    # gouttes de sang qui flottent
    motes(b, 0xc81a2a, 7, 6.5, 3.0)
    aura_ring(b, 0x8a1a2a)
    return b['g']


def aurele_epreuve():
    """Aurèle le Séraphin : six ailes d'or (trois paires), double auréole, plaques d'or sur l'armure,
    soleil sur la poitrine, ailerons sur le casque, cristaux de lumière et anneau doré."""
    b, p = humanoid('angel', 0xf0d8c0, hs=1, hair=0xffe08a, eye=0xfff0a0)
    h, hw, hh, hd = _head(b)
    o = b['o']; top = b['top']; T = b['T']; tH = o['tH']; ch = T[2]
    light = 0xfff0a0
    # six ailes : la paire d'origine (hs=1, dorée), une paire haute et une paire basse
    for s in (-1, 1):
        feather_wing(b, 0xf8f0d8, 0xf0d890, s, sc=0.85, y_off=4.0, z_off=0.6, a0=0.1, a1=1.2, n=6, tip=light)
        feather_wing(b, 0xf0d890, 0xe8c870, s, sc=0.8, y_off=-6.0, z_off=0.3, a0=1.7, a1=2.7, n=6, tip=light)
    # double auréole
    halo(b, 0xffd040, 7.2, 6.2, 14)
    # ailerons d'or sur les côtés du casque
    for s in (-1, 1):
        for i in range(3):
            V(0.5, 3.2 - i * 0.5, 1.2, GOLD_L if i % 2 else GOLD, s * (hw / 2 + 1.6), hh / 2 + 0.6 + i * 0.4, -0.6 - i * 1.1, h, rz=-s * 0.5, rx=-0.4 - i * 0.2)
    # plaques d'or sur l'armure, soleil sur la poitrine
    V(ch['w'] + 1.4, 0.8, ch['d'] + 1.4, GOLD, 0, ch['y0'] + 0.2, 0, top)
    V(ch['w'] + 1.0, 0.8, ch['d'] + 1.2, GOLD, 0, tH - 0.3, 0, top)
    sz = ch['d'] / 2 + 1.3
    VG(2.4, 2.4, 0.5, light, 0, ch['cy'] + 0.6, sz, top, rz=0.785)
    for i in range(8):
        a = i / 8.0 * 2 * math.pi
        V(0.5, 1.3, 0.4, GOLD_L, math.cos(a) * 2.4, ch['cy'] + 0.6 + math.sin(a) * 2.4, sz, top, rz=a - math.pi / 2)
    for A in b['arms']:
        V(o['aw'] + 3.4, 1.0, o['ad'] + 3.4, GOLD, 0, 1.8, 0, A)
        V(o['aw'] + 1.8, 0.6, o['ad'] + 1.8, GOLD_L, 0, -o['al'] * 0.58, 0, A)
    floating_crystals(b, light, 3)
    motes(b, light, 8, 7.5, 4.0)
    aura_ring(b, 0xffd040)
    return b['g']


def ren_possede():
    """Ren le Possédé : peau grise, yeux de Brume, veines violettes, cristal de Brume planté dans la poitrine,
    cristaux qui percent l'épaule et l'avant-bras, écharpe rouge en lambeaux, brume à ses pieds."""
    b, p = humanoid('kijin', 0xbfb0b4, hs=0, hair=0x1a1420, eye=BRUME)
    h, hw, hh, hd = _head(b)
    o = b['o']; top = b['top']; T = b['T']; tH = o['tH']; ch = T[2]
    face_marks(b, BRUME)
    eye_glow(b, 0xe0c8ff)
    # le cristal de Brume planté dans la poitrine, veines qui en partent
    cz = ch['d'] / 2 + 1.1
    VA(2.4, 3.6, 1.6, BRUME, -1.2, ch['cy'] + 0.4, cz, top, alpha=0.9, rz=0.3, glow=True)
    VA(1.4, 2.4, 1.2, 0xe0c8ff, -0.2, ch['cy'] + 1.4, cz + 0.2, top, alpha=0.9, rz=-0.4, glow=True)
    for (x, y, rz) in ((-3.2, ch['cy'] + 2.4, 0.9), (0.8, ch['cy'] - 1.6, -0.7), (-3.0, ch['cy'] - 1.4, -0.9), (1.4, ch['cy'] + 2.2, 0.6)):
        VG(0.4, 2.4, 0.3, BRUME, x, y, cz - 0.2, top, rz=rz)
    # l'épaule gauche et l'avant-bras droit percés de cristaux
    crystal_cluster(b['arms'][1], BRUME, 0, o['aw'] * 0.5 + 1.8, -0.4, n=4, size=1.3)
    A = b['arms'][0]
    crystal_cluster(A, BRUME, -o['aw'] / 2 - 0.6, -o['al'] * 0.55, 0, n=3, size=1.0, tilt=0.9)
    for Am in b['arms']:
        VG(o['aw'] * 0.35, o['al'] * 0.3, 0.3, BRUME, 0, -o['al'] * 0.4, o['ad'] / 2 + 0.25, Am)
    # écharpe rouge en lambeaux qui flotte derrière le cou
    V(T[3]['w'] + 1.4, 1.8, T[3]['d'] + 1.6, 0xa01a24, 0, tH + 0.4, 0, top)
    for i, (x, L) in enumerate(((-1.6, 9), (0.6, 12), (2.4, 7))):
        V(1.8, L, 0.6, shade(0xa01a24, 1 - i * 0.08), x, tH - L / 2 + 0.6, -(T[3]['d'] / 2 + 1.4 + i * 0.3), top, rx=0.35, rz=(i - 1) * 0.15)
    wisps(b, BRUME, 8, 6.0)
    motes(b, BRUME, 6, 6.0, 2.0)
    aura_ring(b, BRUME_D)
    return b['g']


def bandit_chef():
    """Chef des bandits : barbe rousse fournie, bandeau sur l'œil, balafre, anneau d'or à l'oreille,
    mantelet de fourrure, bandoulière de dagues, bourses et pièces à la ceinture, foulard rouge sous le chapeau."""
    b, p = humanoid('human', 0xc89a74, hs=0, hair=0x8a3a1a, eye=0x4a6a3a)
    h, hw, hh, hd = _head(b)
    o = b['o']; top = b['top']; T = b['T']; tH = o['tH']; ch = T[2]; wa = T[1]
    hair_c = p['hair']
    # barbe épaisse et tressée
    V(hw * 0.86, 2.8, 1.4, hair_c, 0, -hh / 2 - 0.2, hd / 2 + 0.2, h)
    V(hw * 0.66, 2.0, 1.6, shade(hair_c, 0.9), 0, -hh / 2 - 2.2, hd / 2 - 0.1, h)
    V(hw * 0.6, 1.0, 0.8, hair_c, 0, -hh * 0.22, hd / 2 + 0.5, h)
    for x in (-1.1, 1.1):
        V(1.0, 3.0, 1.0, shade(hair_c, 0.85), x, -hh / 2 - 4.4, hd / 2 - 0.2, h)
        V(1.2, 0.6, 1.2, GOLD, x, -hh / 2 - 5.8, hd / 2 - 0.2, h)
    # bandeau noir sur l'œil droit, balafre sur l'autre joue, dent en or
    ex = hw * 0.27
    V(2.4, 2.0, 0.5, 0x1a1414, -ex, hh * 0.02, hd / 2 + 0.55, h)
    V(hw + 1.2, 0.5, hd + 1.2, 0x1a1414, 0, hh * 0.26, 0, h, rz=-0.25)
    V(0.5, 3.4, 0.3, 0x9a4a3a, ex + 0.4, -hh * 0.06, hd / 2 + 0.4, h, rz=0.35)
    V(0.6, 0.6, 0.4, GOLD_L, 0.6, -hh * 0.36 + 0.3, hd / 2 + 0.6, h)
    VG(0.9, 1.4, 0.9, GOLD_L, hw / 2 + 0.9, -1.6, -0.2, h)
    # foulard rouge qui dépasse du chapeau de cuir, nœud et pans derrière
    V(hw + 1.6, 1.0, hd + 1.6, 0xa02a24, 0, hh / 2 - 2.6, 0, h)
    for i, L in enumerate((4.4, 3.4)):
        V(1.3, L, 0.5, shade(0xa02a24, 1 - i * 0.1), -0.8 + i * 1.6, hh / 2 - 3.4 - L / 2, -(hd / 2 + 1.6), h, rx=0.4, rz=(i - 0.5) * 0.4)
    # mantelet de fourrure sur les épaules
    collar(b, 0x5a4a3a, 1.9)
    for A in b['arms']:
        V(o['aw'] + 2.6, 2.2, o['ad'] + 2.6, 0x6a5a48, 0, 1.0, 0, A)
    # bandoulière de dagues en travers du torse
    zb = ch['d'] / 2 + 1.1
    V(1.6, tH * 0.95, 0.5, 0x3a2414, 0, tH * 0.5, zb, top, rz=-0.6)
    for i in range(4):
        t = (i - 1.5) / 1.5
        x = -t * tH * 0.27; y = tH * 0.5 + t * tH * 0.38
        V(0.6, 2.6, 0.4, 0xc8ced6, x, y + 1.0, zb + 0.4, top, rz=-0.6)
        V(0.8, 1.2, 0.5, 0x5a341c, x + 0.4, y - 0.4, zb + 0.4, top, rz=-0.6)
    # bourses et pièces à la ceinture
    for s, c in ((-1, 0x7a4a2a), (1, 0x8a5a2a)):
        x = s * (wa['w'] / 2 + 0.6)
        V(2.2, 2.6, 1.8, c, x, wa['y0'] - 1.4, wa['d'] / 2 - 0.4, top)
        V(1.0, 0.6, 1.0, shade(c, 0.7), x, wa['y0'] - 0.2, wa['d'] / 2 - 0.4, top)
    for i in range(3):
        V(0.9, 0.9, 0.3, GOLD_L, -wa['w'] * 0.15 + i * 0.9, wa['y0'] - 0.4, wa['d'] / 2 + 1.5, top)
    return b['g']


NAMED = {
    'seigneur_demon': seigneur_demon,
    'seigneur_brume': seigneur_brume,
    'seigneur_squelette': seigneur_squelette,
    'morvain_parjure': morvain_parjure,
    'aurele_epreuve': aurele_epreuve,
    'ren_possede': ren_possede,
    'bandit_chef': bandit_chef,
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='../assets/characters/named')
    ap.add_argument('--only', default='', help='noms séparés par des virgules (par défaut : tous)')
    a = ap.parse_args()
    only = [n for n in a.only.split(',') if n]
    os.makedirs(a.out, exist_ok=True)
    n = 0
    for name, fn in NAMED.items():
        if only and name not in only:
            continue
        export_glb(fn(), os.path.join(a.out, name + '.glb')); n += 1
    print('%d ennemis nommés -> %s' % (n, a.out))


if __name__ == '__main__':
    main()
