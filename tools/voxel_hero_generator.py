#!/usr/bin/env python3
"""
Générateur des modèles du HÉROS (personnalisables) -> .glb pour Godot 4.

Les corps sont les mêmes que les personnages nus, mais la peau, les cheveux (ou plumes, fourrure)
et les yeux sont peints avec des couleurs repères :
    peau = (200, 1, 1)   cheveux = (1, 200, 1)   yeux = (1, 1, 200)
Les nuances (ombres, reflets) sont des multiples de ces repères. Dans Godot,
scripts/hero/hero_appearance.gd remplace chaque repère par la couleur choisie par le joueur,
en gardant la nuance : on peut donc choisir n'importe quelle couleur.

Chaque race a 3 styles (coiffure, cornes, espèce, élément... selon la race), et l'humain
existe avec ou sans barbe.
Écrit aussi hero_palettes.json : couleurs proposées par race et nom des styles.

Usage :
    python voxel_hero_generator.py --out ../assets/characters/hero
"""
import argparse, json, os
from voxel_character_generator import RACES, RACE_ORDER, SK, HAIR, EYE, gen, mk, export_glb

SKIN_KEY = (200 << 16) | (1 << 8) | 1
HAIR_KEY = (1 << 16) | (200 << 8) | 1
EYE_KEY = (1 << 16) | (1 << 8) | 200

HAIR_ANY = [0x1e1a18, 0x3a2a1e, 0x6b4423, 0xa8432a, 0xd9b04a, 0xb8b8b8, 0xe8e8f0, 0x3a5a8a]
EYE_ANY = [0x2a5a8a, 0x3a6a3a, 0x5a3a20, 0xd02020, 0xf2d84a, 0x8a4ad0, 0x60ffb0, 0xffffff]

STYLE_NAMES = {
    'human': ['Cheveux courts', 'Cheveux longs', 'Crête'],
    'elf': ['Cheveux longs', 'Cheveux longs (variante)', 'Crête'],
    'goblin': ['Style 1', 'Style 2', 'Style 3'],
    'orc': ['Style 1', 'Style 2', 'Style 3'],
    'lizard': ['Style 1', 'Style 2', 'Style 3'],
    'lycan': ['Style 1', 'Style 2', 'Style 3'],
    'vampire': ['Cheveux courts', 'Cheveux longs', 'Crête'],
    'demon': ['Cornes d\'ivoire', 'Cornes noires', 'Cornes dorées'],
    'dragonoid': ['Cornes d\'ivoire', 'Cornes noires', 'Cornes dorées'],
    'fairy': ['Cheveux courts', 'Cheveux longs', 'Crête'],
    'slime': ['Style 1', 'Style 2', 'Style 3'],
    'dwarf': ['Cheveux courts', 'Cheveux longs', 'Cheveux courts (variante)'],
    'hobgoblin': ['Style 1', 'Style 2', 'Style 3'],
    'ogre': ['Une corne', 'Deux cornes', 'Trois cornes'],
    'kijin': ['Deux cornes, cheveux longs', 'Une corne', 'Deux cornes, cheveux courts'],
    'beastfolk': ['Chat', 'Loup', 'Renard'],
    'harpy': ['Style 1', 'Style 2', 'Style 3'],
    'spirit': ['Feu', 'Eau', 'Vent', 'Terre', 'Lumière'],
    'angel': ['Ange blanc', 'Ange doré', 'Ange déchu'],
    'dryad': ['Style 1', 'Style 2', 'Style 3'],
    'insectoid': ['Style 1', 'Style 2', 'Style 3'],
    'undead': ['Style 1', 'Style 2', 'Style 3'],
}
HAIR_LABEL = {'harpy': 'Plumes', 'lycan': 'Fourrure', 'beastfolk': 'Cheveux', 'fairy': 'Cheveux et ailes',
              'dryad': 'Feuillage', 'angel': 'Cheveux'}


def hero(race, style, beard=False):
    i = RACE_ORDER.index(race)
    p = gen(race, 'forgeron', mk(97 + i * 13 + 1))
    p['naked'] = True
    p['cape'] = False
    p['skin'] = SKIN_KEY
    p['hair'] = HAIR_KEY
    p['eye'] = EYE_KEY
    p['beard'] = beard
    if race == 'spirit':
        p['el'] = style
        p['hs'] = 0
    else:
        p['hs'] = style
    return RACES[race]('forgeron', p)['g']


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='../assets/characters/hero')
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    pal = {}
    n = 0
    for race in RACE_ORDER:
        styles = STYLE_NAMES[race]
        for s in range(len(styles)):
            export_glb(hero(race, s), os.path.join(a.out, '%s_s%d.glb' % (race, s)))
            n += 1
            if race == 'human':
                export_glb(hero(race, s, True), os.path.join(a.out, '%s_s%d_beard.glb' % (race, s)))
                n += 1
        hx = lambda c: '#%06x' % c
        pal[race] = {
            'skin': [hx(c) for c in SK[race]],
            'hair': [hx(c) for c in HAIR.get(race, HAIR_ANY)],
            'eye': [hx(c) for c in EYE.get(race, EYE_ANY)] + [hx(c) for c in EYE_ANY if c not in EYE.get(race, [])][:4],
            'styles': styles,
            'beard': race == 'human',
            'hair_label': HAIR_LABEL.get(race, 'Cheveux'),
        }
    with open(os.path.join(a.out, 'hero_palettes.json'), 'w') as f:
        json.dump(pal, f, ensure_ascii=False, indent=1)
    print('%d modèle(s) de héros -> %s' % (n, a.out))


if __name__ == '__main__':
    main()
