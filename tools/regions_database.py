#!/usr/bin/env python3
"""
Écrit les nouveaux monstres (data/enemies/) et les types de régions (data/regions/) du monde ouvert.

Usage :
    python regions_database.py
"""
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
ENV = 'res://scenes/decor/%s.tscn'


def color(h):
    h = h.lstrip('#')
    r, g, b = int(h[0:2], 16) / 255, int(h[2:4], 16) / 255, int(h[4:6], 16) / 255
    return 'Color(%.3f, %.3f, %.3f, 1)' % (r, g, b)


class Res:
    """Petit écrivain de fichier .tres avec ressources externes."""

    def __init__(self, script_class, script_path):
        self.ext = []
        self.ids = {}
        self.script_class = script_class
        self.add('Script', script_path, '1')

    def add(self, typ, path, rid=None):
        if path in self.ids:
            return self.ids[path]
        rid = rid or 'r%d' % len(self.ext)
        self.ext.append((typ, path, rid))
        self.ids[path] = rid
        return rid

    def ref(self, typ, path):
        return 'ExtResource("%s")' % self.add(typ, path)

    def write(self, path, props):
        lines = ['[gd_resource type="Resource" script_class="%s" format=3]' % self.script_class, '']
        for typ, p, rid in self.ext:
            lines.append('[ext_resource type="%s" path="%s" id="%s"]' % (typ, p, rid))
        lines += ['', '[resource]', 'script = ExtResource("1")']
        for k, v in props:
            lines.append('%s = %s' % (k, v))
        with open(path, 'w', encoding='utf-8') as f:
            f.write('\n'.join(lines) + '\n')


# ---------------------------------------------------------------- monstres
# id: (nom, modèle, bibliothèque d'équipement, équipement, couleur, taille,
#      vie, attaque, défense, vitesse, portée, attaques, vitesse d'attaque, équilibre, recul, corps, butin[(id, chance)])
CREA = 'res://assets/characters/creatures/%s.glb'
BASE = 'res://assets/characters/models/base/%s_base.glb'
LIB = 'res://assets/equipment/%s_equipment.glb'

ENEMIES = {
    'slime_bleu': ('Slime bleu', CREA % 'slime_blue', None, [], 'ffd24a', 1.0,
                   30, 6, 0, 3.0, 1.3, ['charge_ram'], 0.9, 5, 2.5, 0.45, [('fiber', 0.5), ('leather', 0.1)]),
    'slime_acide': ('Slime acide', CREA % 'slime_acid', None, [], 'b0ff4a', 1.0,
                    70, 12, 1, 3.2, 1.5, ['charge_ram', 'bite'], 0.9, 10, 3.0, 0.55, [('fiber', 0.6), ('leather', 0.2)]),
    'slime_magma': ('Slime de magma', CREA % 'slime_magma', None, [], 'ff7a2a', 1.0,
                    150, 22, 4, 3.0, 1.7, ['charge_ram', 'bite'], 0.85, 20, 5.0, 0.65, [('or_brut', 0.3), ('stone', 0.6)]),
    'araignee': ('Araignée géante', CREA % 'spider', None, [], 'ff5a5a', 1.0,
                 75, 13, 2, 4.6, 1.6, ['bite', 'charge_ram'], 1.15, 15, 3.5, 0.6, [('fiber', 0.9), ('fiber', 0.5), ('leather', 0.3)]),
    'ours_neige': ('Ours des neiges', CREA % 'bear_snow', None, [], 'a8d8ff', 1.0,
                   190, 24, 6, 3.6, 1.9, ['bite', 'charge_ram'], 0.8, 60, 7.0, 0.8, [('leather', 0.9), ('leather', 0.6)]),
    'loup_givre': ('Loup de givre', CREA % 'wolf_frost', None, [], '8ae0ff', 1.0,
                   110, 18, 3, 4.8, 1.6, ['bite', 'bite', 'charge_ram'], 1.15, 15, 4.0, 0.5, [('leather', 0.8), ('fiber', 0.3)]),
    'scorpion': ('Scorpion géant', CREA % 'scorpion', None, [], 'ffc84a', 1.0,
                 130, 19, 7, 3.8, 1.7, ['bite', 'charge_ram'], 1.0, 35, 4.0, 0.65, [('or_brut', 0.25), ('stone', 0.5)]),
    'salamandre': ('Salamandre de feu', CREA % 'salamander', None, [], 'ff8a2a', 1.0,
                   170, 26, 5, 4.4, 1.7, ['bite', 'charge_ram'], 1.1, 25, 4.5, 0.55, [('leather', 0.6), ('or_brut', 0.2)]),
    'homme_lezard': ('Homme-lézard', BASE % 'lizard', LIB % 'lizard', ['spear', 'shield_wood', 'leather_armor'], '8aff6a', 1.0,
                     90, 11, 3, 3.6, 2.0, ['enemy_chop', 'enemy_sweep'], 1.0, 30, 4.0, 0.4,
                     [('spear', 0.15), ('shield_wood', 0.1), ('leather', 0.6)]),
    'harpie': ('Harpie', BASE % 'harpy', LIB % 'harpy', ['dagger', 'leather_cap'], 'ffb0f0', 1.0,
               85, 15, 2, 4.8, 1.6, ['enemy_chop', 'enemy_sweep'], 1.25, 15, 3.0, 0.35,
               [('dagger', 0.15), ('fiber', 0.6)]),
    'ogre': ('Ogre des cimes', BASE % 'ogre', LIB % 'ogre', ['war_hammer', 'iron_armor', 'iron_gauntlets'], 'ff6a4a', 1.2,
             320, 26, 7, 3.0, 2.3, ['enemy_chop', 'enemy_sweep'], 0.7, 90, 9.0, 0.7,
             [('war_hammer', 0.2), ('iron_armor', 0.1), ('iron_ingot', 0.8), ('marbre_brut', 0.5)]),
    'esprit_follet': ('Esprit follet', BASE % 'spirit', LIB % 'spirit', ['staff', 'mage_hat'], '8af0ff', 1.0,
                      120, 20, 3, 4.2, 1.8, ['enemy_chop', 'enemy_sweep'], 1.1, 20, 4.0, 0.35,
                      [('staff', 0.12), ('mage_hat', 0.1), ('fiber', 0.5)]),
    'fee_sauvage': ('Fée sauvage', BASE % 'fairy', LIB % 'fairy', ['dagger', 'cape_blue'], 'f0a8ff', 0.9,
                    100, 22, 2, 5.0, 1.5, ['enemy_chop', 'enemy_sweep'], 1.3, 10, 3.0, 0.3,
                    [('dagger', 0.15), ('cape_blue', 0.1), ('or_brut', 0.2)]),
    'dryade_corrompue': ('Dryade corrompue', BASE % 'dryad', LIB % 'dryad', ['staff', 'mage_robe', 'cape_red'], 'c070ff', 1.15,
                         360, 30, 8, 3.4, 2.1, ['enemy_chop', 'enemy_sweep'], 0.85, 80, 7.0, 0.5,
                         [('staff', 0.3), ('mage_robe', 0.25), ('lingot_or', 0.4)]),
    'demon': ('Démon des cendres', BASE % 'demon', LIB % 'demon', ['sword_iron', 'iron_armor', 'horned_helmet'], 'ff4a3a', 1.0,
              170, 30, 9, 3.8, 1.9, ['enemy_chop', 'enemy_sweep'], 1.0, 50, 6.0, 0.45,
              [('sword_iron', 0.2), ('horned_helmet', 0.15), ('or_brut', 0.5)]),
    'seigneur_demon': ('Seigneur démon', BASE % 'demon', LIB % 'demon',
                       ['axe', 'iron_armor', 'iron_helmet', 'iron_gauntlets', 'iron_greaves', 'cape_red'], 'ff2a2a', 1.35,
                       600, 40, 14, 3.2, 2.4, ['enemy_chop', 'enemy_sweep'], 0.75, 140, 10.0, 0.7,
                       [('axe', 0.3), ('iron_armor', 0.3), ('lingot_or', 0.8), ('piece_or', 1.0)]),
    'seigneur_squelette': ('Seigneur squelette', BASE % 'undead', LIB % 'undead',
                           ['war_hammer', 'iron_armor', 'iron_helmet', 'shield_iron'], 'd8d8ff', 1.25,
                           280, 24, 9, 3.0, 2.2, ['enemy_chop', 'enemy_sweep'], 0.8, 90, 8.0, 0.55,
                           [('war_hammer', 0.25), ('shield_iron', 0.2), ('or_brut', 0.6)]),
}

# ---------------------------------------------------------------- boss (un par région)
BOSSES = {
    'boss_roi_sanglier': ('Grondebois, le Roi Sanglier', CREA % 'boar', None, [], 'ffb04a', 2.4,
                          520, 22, 4, 3.6, 2.6, ['charge_ram', 'bite'], 0.8, 400, 9.0, 1.2,
                          [('leather', 1.0), ('leather', 1.0), ('lingot_or', 0.6)]),
    'boss_reine_araignee': ('Tissombre, la Reine Araignée', CREA % 'spider', None, [], 'ff4a8a', 2.6,
                            680, 28, 5, 4.2, 2.8, ['bite', 'charge_ram'], 0.9, 450, 8.0, 1.3,
                            [('fiber', 1.0), ('fiber', 1.0), ('lingot_or', 0.7)]),
    'boss_slime_primordial': ('Le Slime Primordial', CREA % 'slime_acid', None, [], '9aff4a', 3.2,
                              780, 30, 6, 3.2, 2.8, ['charge_ram', 'bite'], 0.75, 500, 10.0, 1.5,
                              [('lingot_or', 1.0), ('or_brut', 1.0)]),
    'boss_scorpion_empereur': ('Ankhar, le Scorpion Empereur', CREA % 'scorpion', None, [], 'ffd24a', 2.6,
                               760, 34, 10, 3.8, 3.0, ['bite', 'charge_ram'], 0.85, 550, 9.0, 1.4,
                               [('lingot_or', 1.0), ('or_brut', 1.0), ('piece_or', 1.0)]),
    'boss_ogre_roi': ('Brisemonts, Roi des Ogres', BASE % 'ogre', LIB % 'ogre',
                      ['war_hammer', 'iron_armor', 'iron_helmet', 'iron_gauntlets', 'iron_greaves', 'cape_red'], 'ff7a4a', 2.0,
                      640, 38, 12, 3.2, 3.2, ['enemy_chop', 'enemy_sweep'], 0.7, 700, 12.0, 1.1,
                      [('war_hammer', 0.6), ('iron_armor', 0.5), ('marbre_brut', 1.0), ('lingot_or', 1.0)]),
    'boss_ours_ancien': ('Givrecroc, l\'Ours Ancien', CREA % 'bear_snow', None, [], 'aee8ff', 2.2,
                         850, 40, 11, 3.8, 3.0, ['bite', 'charge_ram'], 0.8, 650, 11.0, 1.4,
                         [('leather', 1.0), ('leather', 1.0), ('lingot_or', 1.0)]),
    'boss_dryade_mere': ('Sylvaëlle, la Dryade Mère', BASE % 'dryad', LIB % 'dryad', ['staff', 'mage_robe', 'mage_hat', 'cape_blue'], 'd08aff', 1.9,
                         1100, 42, 10, 3.6, 2.8, ['enemy_chop', 'enemy_sweep'], 0.85, 600, 9.0, 1.0,
                         [('staff', 0.7), ('mage_robe', 0.6), ('lingot_or', 1.0), ('piece_or', 1.0)]),
    'boss_seigneur_ignarok': ('Ignarok, Seigneur des Cendres', BASE % 'demon', LIB % 'demon',
                              ['axe', 'iron_armor', 'horned_helmet', 'iron_gauntlets', 'iron_greaves', 'cape_red'], 'ff3a2a', 2.1,
                              900, 50, 16, 3.6, 3.2, ['enemy_chop', 'enemy_sweep'], 0.8, 900, 12.0, 1.1,
                              [('axe', 0.6), ('iron_armor', 0.6), ('lingot_or', 1.0), ('piece_or', 1.0), ('piece_or', 1.0)]),
}
# jungle d'émeraude
ENEMIES.update({
    'panthere': ("Panthère d'ombre", CREA % 'panther', None, [], 'c8a0ff', 1.0,
                 150, 24, 4, 5.4, 1.7, ['bite', 'bite', 'charge_ram'], 1.25, 20, 4.0, 0.5, [('leather', 0.9), ('leather', 0.4)]),
    'grenouille': ('Grenouille venimeuse', CREA % 'frog', None, [], '5ad8ff', 1.0,
                   90, 20, 2, 4.0, 1.5, ['charge_ram', 'bite'], 1.1, 10, 3.0, 0.5, [('fiber', 0.6), ('baies', 0.5)]),
    'serpent': ('Serpent géant', CREA % 'snake', None, [], '8ad04a', 1.0,
                170, 26, 5, 3.8, 1.9, ['bite', 'charge_ram'], 1.0, 30, 4.5, 0.55, [('leather', 0.8), ('or_brut', 0.2)]),
    'serpent_roi': ('Serpent royal', CREA % 'snake_king', None, [], 'ffd24a', 1.2,
                    420, 34, 9, 3.8, 2.3, ['bite', 'charge_ram'], 0.9, 110, 8.0, 0.8, [('leather', 1.0), ('lingot_or', 0.6), ('or_brut', 0.6)]),
    'boss_quetzal': ('Xochitl, le Serpent à Plumes', CREA % 'feathered_serpent', None, [], '4ae0a0', 2.4,
                     1000, 46, 12, 4.0, 3.0, ['bite', 'charge_ram'], 0.85, 800, 10.0, 1.4,
                     [('lingot_or', 1.0), ('or_brut', 1.0), ('piece_or', 1.0)]),
})
ENEMIES.update(BOSSES)


ONLY = []


def write_enemies():
    out = os.path.join(ROOT, 'data', 'enemies')
    for eid, (name, model, lib, equip, col, scale, hp, atk, dfn, spd, rng, moves, aspd, poise, kb, body, loot) in ENEMIES.items():
        if ONLY and eid not in ONLY:
            continue
        r = Res('EnemyData', 'res://scripts/data/enemy_data.gd')
        r.add('Script', 'res://scripts/data/item_data.gd', '2')
        props = [('display_name', '"%s"' % name), ('model', r.ref('PackedScene', model))]
        if lib:
            props.append(('equipment_library', r.ref('PackedScene', lib)))
        if equip:
            props.append(('equipment', 'Array[ExtResource("2")]([%s])' % ', '.join(
                r.ref('Resource', 'res://data/items/%s.tres' % i) for i in equip)))
        props += [('model_scale', scale), ('color', color(col)), ('max_health', hp), ('attack', atk), ('defense', dfn),
                  ('move_speed', spd), ('aggro_range', 10), ('leash_range', 20), ('attack_range', rng),
                  ('attack_moves', 'PackedStringArray(%s)' % ', '.join('"%s"' % m for m in moves)),
                  ('attack_speed', aspd), ('poise', poise), ('attack_cooldown', 1.0), ('knockback', kb), ('body_radius', body),
                  ('loot', 'Array[ExtResource("2")]([%s])' % ', '.join(r.ref('Resource', 'res://data/items/%s.tres' % i) for i, _ in loot)),
                  ('loot_chances', 'PackedFloat32Array(%s)' % ', '.join(str(c) for _, c in loot))]
        r.write(os.path.join(out, eid + '.tres'), props)
    print('%d monstres' % len(ENEMIES))


# ---------------------------------------------------------------- régions
REGIONS = [
    dict(id='prairie', races=['humain', 'homme_bete', 'elfe', 'hobgobelin'], soul={'regen': 1.0, 'attack': 2}, soulname="Vigueur du Roi Sanglier : +2 attaque, +1 vie/s", boss='boss_roi_sanglier', title='Le seigneur des plaines se réveille !', powers=['charge', 'onde', 'invocation'], dfloor='bloc_pierre_brute', dwall='bloc_briques', daccent='bloc_rondins', dlight='ffb060', damb='201a18', name='Prairie', map='7ec850', temp=0.0, moist=0.0, dist=0.0, lv=(1, 4),
         names=['Plaines de Verdoyance', 'Vallon des Brises', 'Prés de Clairval', 'Collines de Mielfleur', 'Champs de Ventdoux', 'Pâtures du Soleil'],
         desc="Des plaines douces et des bosquets : le berceau de ton royaume.",
         grass=('5e9c44', '4f8c3a'), dirt='7a5a3c', sand='e0cc8a', stone='8e8c86',
         trees=['oak_1', 'oak_2', 'oak_3', 'oak_autumn', 'pine_1'], forest=0.3, scattered=0.015,
         bushes=['bush_1', 'bush_2'], bush=0.02, rocks=['rock_1', 'rock_2', 'rock_big'], rock=0.05,
         plants=['flowers_1', 'flowers_2', 'grass_1', 'grass_1'], plant=0.12,
         enemies=['loup', 'sanglier', 'slime_bleu', 'slime_bleu', 'gobelin_pillard'], elite=['loup_alpha'], camps=0.35,
         res=['wood', 'fiber', 'leather', 'stone', 'piece_or'], resc=0.010),
    dict(id='foret', races=['elfe', 'lycan', 'dryade', 'homme_bete'], soul={'attack': 3, 'xp': 0.05}, soulname="Instinct de la Reine Araignée : +3 attaque, +5 % d'expérience", boss='boss_reine_araignee', title='Les toiles frémissent...', powers=['invocation', 'charge', 'onde'], dfloor='bloc_terre', dwall='bloc_rondins', daccent='bloc_planches', dlight='a0ff80', damb='101a10', name='Forêt profonde', map='2e7a3a', temp=0.0, moist=0.75, dist=0.1, lv=(3, 7),
         names=['Forêt de Sylvebrune', 'Bois des Murmures', 'Sombreramure', 'Forêt des Mille Troncs', 'Futaie des Loups', 'Bois de Ronceterre'],
         desc="Des arbres immenses où rôdent loups et araignées.",
         grass=('3f7a34', '356a2c'), dirt='5a4430', sand='c8b47a', stone='7a7a74',
         trees=['pine_1', 'pine_2', 'pine_3', 'oak_1', 'oak_2', 'mushroom_red'], forest=0.62, scattered=0.05,
         bushes=['bush_1', 'bush_2'], bush=0.06, rocks=['rock_1', 'rock_2'], rock=0.04,
         plants=['grass_1', 'grass_1', 'flowers_2'], plant=0.1,
         enemies=['loup', 'araignee', 'araignee', 'gobelin_pillard'], elite=['loup_alpha'], camps=0.55,
         res=['wood', 'wood', 'fiber', 'leather', 'piece_or'], resc=0.014),
    dict(id='marais', races=['homme_lezard', 'gobelin', 'slime', 'insectoide'], soul={'regen': 2.5}, soulname="Prédation du Slime Primordial : +2,5 vie/s", boss='boss_slime_primordial', title='Il a tout dévoré... et il a encore faim.', powers=['onde', 'invocation', 'pluie'], dfloor='bloc_ardoise', dwall='bloc_pierre_brute', daccent='bloc_terre', dlight='9aff6a', damb='101a10', name='Marais brumeux', map='6a7a3a', temp=0.35, moist=1.0, dist=0.45, lv=(5, 9),
         names=['Marais de Fangebrume', 'Tourbières de Vasemort', 'Les Eaux Croupies', 'Bourbier des Crapauds', 'Mangrove de Verdâtre'],
         desc="Eaux verdâtres, roseaux et slimes acides. Les hommes-lézards y chassent.",
         grass=('5a6a3a', '4a5a30'), dirt='4a3e2a', sand='8a8a5a', stone='6a6a60', water_floor='4a5a2a',
         liquid='4a6a2a', bias=-0.16, relief=0.5,
         trees=['swamp_tree_1', 'swamp_tree_2', 'dead_tree_1', 'dead_tree_2', 'mushroom_purple'], forest=0.25, scattered=0.03,
         bushes=['bush_1'], bush=0.03, rocks=['rock_1'], rock=0.02,
         plants=['reeds_1', 'reeds_2', 'reeds_1'], plant=0.18,
         enemies=['slime_acide', 'slime_acide', 'homme_lezard', 'araignee'], elite=['homme_lezard'], camps=0.6,
         res=['fiber', 'fiber', 'leather', 'piece_or'], resc=0.012),
    dict(id='desert', races=['dragonide', 'humain', 'mort_vivant', 'homme_lezard'], soul={'defense': 4}, soulname="Carapace d'Ankhar : +4 défense", boss='boss_scorpion_empereur', title='Le sable se soulève...', powers=['charge', 'onde', 'invocation'], dfloor='bloc_sable', dwall='bloc_briques', daccent='bloc_marbre_dore', dlight='ffd070', damb='201810', name='Désert', map='e8c878', temp=1.0, moist=-0.9, dist=0.5, lv=(6, 11),
         names=["Désert d'Ossebrûle", 'Dunes de Solcendre', 'Mer de Sable Doré', 'Erg des Mirages', 'Plateau Écarlate'],
         desc="Soleil écrasant, scorpions géants et ruines hantées de squelettes.",
         grass=('e4cc8c', 'd8bc78'), dirt='c8a060', sand='ecd89a', stone='b89a6a', water_floor='d8c080',
         relief=0.8,
         trees=['cactus_1', 'cactus_2', 'cactus_3', 'dead_tree_1'], forest=0.0, scattered=0.02,
         bushes=[], bush=0.0, rocks=['rock_1', 'rock_2', 'rock_big'], rock=0.03,
         plants=['dry_grass_1'], plant=0.06,
         enemies=['scorpion', 'scorpion', 'squelette', 'homme_lezard'], elite=['seigneur_squelette'], camps=0.5,
         res=['stone', 'or_brut', 'stone', 'piece_or'], resc=0.008),
    dict(id='montagnes', races=['nain', 'ogre', 'orc', 'harpie'], soul={'attack': 5}, soulname="Force de Brisemonts : +5 attaque", boss='boss_ogre_roi', title='La montagne gronde !', powers=['onde', 'charge', 'invocation'], dfloor='bloc_pierre_polie', dwall='bloc_pierre_brute', daccent='bloc_ardoise', dlight='ffc080', damb='18181c', name='Hautes montagnes', map='9a9890', temp=-0.4, moist=0.0, dist=0.45, lv=(7, 12),
         names=['Pics de Grisaille', 'Monts Ferrecime', "Crêtes de l'Aigle", 'Massif des Géants', 'Col des Tempêtes', 'Hauts de Roc-Tonnerre'],
         desc="Falaises et cols battus par le vent. Riches en fer et en marbre, gardés par les ogres.",
         grass=('6a8a50', '5a7a44'), dirt='6a5a48', sand='b0a48a', stone='9a9890',
         bias=0.34, relief=1.7,
         trees=['pine_1', 'pine_2', 'pine_3'], forest=0.25, scattered=0.02,
         bushes=['bush_2'], bush=0.01, rocks=['rock_big', 'rock_1', 'rock_2'], rock=0.12,
         plants=['grass_1'], plant=0.05,
         enemies=['orc_brute', 'harpie', 'harpie', 'gobelin_pillard'], elite=['ogre'], camps=0.55,
         res=['iron_ore', 'stone', 'marbre_brut', 'piece_or'], resc=0.016),
    dict(id='toundra', races=['humain', 'oni', 'lycan', 'nain'], soul={'defense': 3, 'regen': 1.0}, soulname="Fourrure de Givrecroc : +3 défense, +1 vie/s", boss='boss_ours_ancien', title='Un froid mortel envahit la salle...', powers=['charge', 'onde', 'pluie'], dfloor='bloc_marbre', dwall='bloc_pierre_polie', daccent='bloc_verre', dlight='a0e0ff', damb='101820', name='Toundra gelée', map='e8f0f8', temp=-1.0, moist=0.3, dist=0.55, lv=(8, 13),
         names=['Toundra de Blanchegivre', 'Steppes Hurlantes', 'Glacis du Nord', 'Plaine des Aurores', 'Fjords de Givrecœur'],
         desc="Neige éternelle, loups de givre et ours gigantesques.",
         grass=('eef2f6', 'dce4ec'), dirt='8a8a92', sand='d0d8e0', stone='b0b4bc', water_floor='a8c0d0',
         relief=1.1,
         trees=['pine_snow_1', 'pine_snow_2'], forest=0.3, scattered=0.03,
         bushes=[], bush=0.0, rocks=['snow_rock_1', 'snow_rock_2'], rock=0.05,
         plants=['dry_grass_1'], plant=0.03,
         enemies=['loup_givre', 'loup_givre', 'ours_neige'], elite=['ours_neige'], camps=0.5,
         res=['stone', 'leather', 'iron_ore', 'piece_or'], resc=0.008),
    dict(id='bois_enchante', races=['fee', 'esprit', 'dryade', 'ange'], soul={'magic': 0.15, 'xp': 0.1}, soulname="Sève de Sylvaëlle : +15 % magie, +10 % d'expérience", boss='boss_dryade_mere', title='La forêt pleure...', powers=['pluie', 'invocation', 'onde'], dfloor='bloc_marbre', dwall='bloc_marbre_noir', daccent='bloc_marbre_dore', dlight='d0a0ff', damb='18101e', name='Bois enchanté', map='5ad0c0', temp=0.3, moist=0.4, dist=0.6, lv=(10, 15),
         names=['Bois de Lunécume', 'Sylve des Fées', 'Vallée Cristalline', 'Jardins de Nacre', 'Clairière des Songes'],
         desc="Cerisiers, champignons géants et cristaux. Les fées n'aiment pas les intrus.",
         grass=('4ab08a', '3aa080'), dirt='5a4a6a', sand='d8c8e0', stone='8a80a0',
         trees=['cherry_1', 'cherry_2', 'magic_tree_1', 'magic_tree_2', 'mushroom_blue', 'mushroom_purple'], forest=0.4, scattered=0.04,
         bushes=['bush_1'], bush=0.02, rocks=['crystal_blue', 'crystal_pink'], rock=0.03,
         plants=['flowers_1', 'flowers_2', 'grass_1'], plant=0.14,
         enemies=['esprit_follet', 'fee_sauvage', 'fee_sauvage', 'slime_bleu'], elite=['dryade_corrompue'], camps=0.5,
         res=['fiber', 'or_brut', 'wood', 'piece_or'], resc=0.01),
    dict(id='volcan', races=['demon', 'oni', 'dragonide', 'vampire'], soul={'attack': 6, 'magic': 0.1}, soulname="Brasier d'Ignarok : +6 attaque, +10 % magie", boss='boss_seigneur_ignarok', title='Les flammes se lèvent pour leur seigneur !', powers=['pluie', 'onde', 'invocation', 'charge'], dfloor='bloc_marbre_noir', dwall='bloc_ardoise', daccent='bloc_marbre_dore', dlight='ff6a30', damb='200c08', name='Terres de cendres', map='6a3a30', temp=1.0, moist=-0.2, dist=0.75, lv=(12, 20),
         names=['Terres de Cendrefeu', 'Caldeira Rugissante', 'Plaine des Brasiers', 'Gorge du Dragon Endormi', 'Champs de Magma'],
         desc="Cendres, lave et démons. Le territoire le plus dangereux du monde connu.",
         grass=('4a3a36', '3e302c'), dirt='2e2422', sand='5a4a44', stone='4a4040', water_floor='3a2020',
         liquid='ff6a1a', glow=True, bias=0.12, relief=1.4,
         trees=['dead_tree_1', 'dead_tree_2'], forest=0.05, scattered=0.02,
         bushes=[], bush=0.0, rocks=['lava_rock_1', 'lava_rock_2'], rock=0.1,
         plants=[], plant=0.0,
         enemies=['slime_magma', 'salamandre', 'demon', 'salamandre'], elite=['seigneur_demon'], camps=0.6,
         res=['or_brut', 'stone', 'iron_ore', 'piece_or'], resc=0.012),
    dict(id='jungle', races=['homme_lezard', 'fee', 'homme_bete', 'insectoide'], soul={'attack': 3, 'regen': 1.5, 'xp': 0.05}, soulname="Plumes de Xochitl : +3 attaque, +1,5 vie/s, +5 % d'expérience", boss='boss_quetzal', title='Les plumes du serpent sacré bruissent...', powers=['pluie', 'charge', 'invocation', 'onde'], dfloor='bloc_pierre_polie', dwall='bloc_pierre_brute', daccent='bloc_marbre_dore', dlight='6aff9a', damb='0c1a10', name="Jungle d'émeraude", map='1e8a4a', temp=0.85, moist=0.85, dist=0.6, lv=(11, 16),
         names=["Jungle d'Émeraude", 'Canopée des Mille Cris', 'Temple Englouti', 'Rives du Fleuve Jade', 'Forêt des Brumes Chaudes'],
         desc="Une jungle étouffante : panthères d'ombre, grenouilles venimeuses et serpents géants autour d'un temple oublié.",
         grass=('2e8a3a', '247a30'), dirt='4a3a24', sand='c8b47a', stone='6a7a64', water_floor='3a6a4a',
         liquid='2a7a6a', relief=0.9,
         trees=['jungle_tree_1', 'jungle_tree_2', 'palm_1', 'palm_2'], forest=0.55, scattered=0.05,
         bushes=['bush_1', 'bush_2'], bush=0.05, rocks=['mossy_rock_1', 'mossy_rock_2'], rock=0.04,
         plants=['fern_1', 'fern_2', 'fern_1', 'flowers_2'], plant=0.18,
         enemies=['panthere', 'grenouille', 'grenouille', 'serpent', 'homme_lezard'], elite=['serpent_roi'], camps=0.55,
         res=['wood', 'fiber', 'leather', 'or_brut', 'piece_or'], resc=0.012,
         weather={'clair': 2, 'nuageux': 2, 'pluie': 5, 'orage': 2, 'brouillard': 2}, precip='pluie'),
]


def write_regions():
    out = os.path.join(ROOT, 'data', 'regions')
    os.makedirs(out, exist_ok=True)
    for d in REGIONS:
        if ONLY and d['id'] not in ONLY:
            continue
        r = Res('RegionData', 'res://scripts/data/region_data.gd')
        r.add('Script', 'res://scripts/data/enemy_data.gd', '2')
        r.add('Script', 'res://scripts/data/item_data.gd', '3')
        r.add('Script', 'res://scripts/data/race_data.gd', '4')

        def scenes(lst):
            return 'Array[PackedScene]([%s])' % ', '.join(r.ref('PackedScene', ENV % s) for s in lst)

        def enemies(lst):
            return 'Array[ExtResource("2")]([%s])' % ', '.join(r.ref('Resource', 'res://data/enemies/%s.tres' % e) for e in lst)

        props = [('id', '"%s"' % d['id']), ('display_name', '"%s"' % d['name']),
                 ('names', 'PackedStringArray(%s)' % ', '.join('"%s"' % n for n in d['names'])),
                 ('description', '"%s"' % d['desc']), ('level_range', 'Vector2i(%d, %d)' % d['lv']),
                 ('map_color', color(d['map'])), ('temperature', d['temp']), ('moisture', d['moist']),
                 ('min_distance', d['dist']), ('height_bias', d.get('bias', 0.0)), ('relief', d.get('relief', 1.0)),
                 ('grass_color', color(d['grass'][0])), ('grass_dark_color', color(d['grass'][1])),
                 ('dirt_color', color(d['dirt'])), ('sand_color', color(d['sand'])), ('stone_color', color(d['stone'])),
                 ('water_floor_color', color(d.get('water_floor', 'c8b478')))]
        if 'liquid' in d:
            props += [('liquid_color', color(d['liquid'])), ('liquid_glow', 'true' if d.get('glow') else 'false')]
        props += [('boss', r.ref('Resource', 'res://data/enemies/%s.tres' % d['boss'])), ('boss_title', '"%s"' % d['title']),
                  ('boss_powers', 'PackedStringArray(%s)' % ', '.join('"%s"' % x for x in d['powers'])),
                  ('dungeon_floor', r.ref('Resource', 'res://data/items/%s.tres' % d['dfloor'])),
                  ('dungeon_wall', r.ref('Resource', 'res://data/items/%s.tres' % d['dwall'])),
                  ('dungeon_accent', r.ref('Resource', 'res://data/items/%s.tres' % d['daccent'])),
                  ('dungeon_light', color(d['dlight'])), ('dungeon_ambient', color(d['damb'])),
                  ('boss_soul', '{%s}' % ', '.join('"%s": %s' % (k, float(v)) for k, v in d['soul'].items())),
                  ('boss_soul_name', '"%s"' % d['soulname'])]
        props += [('trees', scenes(d['trees'])), ('forest_density', d['forest']), ('scattered_tree_chance', d['scattered']),
                  ('bushes', scenes(d['bushes'])), ('bush_chance', d['bush']),
                  ('rocks', scenes(d['rocks'])), ('rock_chance', d['rock']),
                  ('small_plants', scenes(d['plants'])), ('small_plant_chance', d['plant']),
                  ('enemies', enemies(d['enemies'])), ('elite_enemies', enemies(d['elite'])), ('camp_density', d['camps']),
                  ('resources', 'Array[ExtResource("3")]([%s])' % ', '.join(r.ref('Resource', 'res://data/items/%s.tres' % i) for i in d['res'])),
                  ('resource_chance', d['resc']),
                  ('recruit_races', 'Array[ExtResource("4")]([%s])' % ', '.join(r.ref('Resource', 'res://data/races/%s.tres' % x) for x in d['races']))]
        if 'weather' in d:
            props += [('weather_weights', '{%s}' % ', '.join('"%s": %d' % (k, v) for k, v in d['weather'].items())),
                      ('precipitation', '"%s"' % d.get('precip', 'pluie'))]
        r.write(os.path.join(out, d['id'] + '.tres'), props)
    print('%d régions' % len(REGIONS))


if __name__ == '__main__':
    import sys
    # python regions_database.py jungle panthere ... : n'écrit que ces fichiers (les autres ont pu être retouchés à la main)
    ONLY.extend(sys.argv[1:])
    write_enemies()
    write_regions()
