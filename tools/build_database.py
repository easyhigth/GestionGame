#!/usr/bin/env python3
"""
Données de construction -> fichiers .tres :
  data/items/   blocs, meubles, nouvelles ressources (marbre brut, or, pain, pièces d'or)
  data/recipes/ recettes des blocs et meubles (avec le meuble nécessaire à proximité)
  data/rooms/   types de pièces (mobilier demandé, métier, production, effets)

Usage :
    python build_database.py
"""
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')


def q(s):
    return '"%s"' % s.replace('"', '\\"')


def col(h):
    return 'Color(%.3f, %.3f, %.3f, 1)' % tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


# ---------------------------------------------------------------- objets
# (id, nom, description, tier, dalle, transparent)
BLOCKS = [
    ('bloc_planches', 'Planches', "Des planches de bois : le matériau de base de toute construction.", 0, False, False),
    ('bloc_rondins', 'Rondins', "Des troncs empilés, solides et rustiques.", 0, False, False),
    ('bloc_chaume', 'Chaume', "De la paille serrée, parfaite pour les toits.", 0, False, False),
    ('bloc_terre', 'Terre', "De la terre tassée. On en récolte en creusant.", 0, False, False),
    ('bloc_sable', 'Sable', "Du sable des plages. Il sert à faire du verre.", 0, False, False),
    ('dalle_planches', 'Plancher', "Une dalle de planches de 50 cm : pour les sols et les étages.", 0, True, False),
    ('bloc_pierre_brute', 'Pierre brute', "Des pierres grossièrement assemblées. L'âge de la pierre commence.", 1, False, False),
    ('dalle_pierre', 'Dallage de pierre', "Une dalle de pierre de 50 cm pour les sols.", 1, True, False),
    ('bloc_briques', 'Pierre taillée', "Des blocs taillés au burin, bien alignés.", 2, False, False),
    ('bloc_tuiles', 'Tuiles', "Des tuiles de terre cuite pour de beaux toits.", 2, False, False),
    ('bloc_verre', 'Verre', "Du verre soufflé pour les fenêtres.", 2, False, True),
    ('bloc_pierre_polie', 'Pierre polie', "De la pierre polie à la meule, lisse et claire.", 3, False, False),
    ('bloc_ardoise', 'Ardoise', "Des ardoises sombres pour les toits nobles.", 3, False, False),
    ('bloc_marbre', 'Marbre', "Du marbre blanc veiné, digne des palais.", 4, False, False),
    ('bloc_marbre_noir', 'Marbre noir', "Un marbre sombre veiné d'or.", 4, False, False),
    ('bloc_marbre_dore', 'Marbre doré', "Du marbre incrusté d'or : la marque d'un empire.", 5, False, False),
]
TEX = {'dalle_planches': 'bloc_planches', 'dalle_pierre': 'bloc_pierre_brute'}

# (id, nom, description, solide, porte, lumière)
FURN = [
    ('porte', 'Porte', "Ferme une pièce. Obligatoire pour qu'une pièce soit reconnue.", False, True, False),
    ('lit', 'Lit', "Un lit pour dormir. Chaque lit loge un habitant.", True, False, False),
    ('coffre', 'Coffre', "Pour ranger ses affaires.", True, False, False),
    ('table', 'Table', "Une table en bois.", True, False, False),
    ('chaise', 'Chaise', "Une chaise en bois.", True, False, False),
    ('tonneau', 'Tonneau', "Un tonneau de bière ou d'eau.", True, False, False),
    ('torche', 'Torche', "Éclaire les alentours.", False, False, True),
    ('lanterne', 'Lanterne', "Une lanterne sur pied.", False, False, True),
    ('etabli', 'Établi', "Pour travailler le bois et fabriquer des objets en fer.", True, False, False),
    ('enclume', 'Enclume', "Le cœur d'une forge.", True, False, False),
    ('foyer_forge', 'Foyer de forge', "Un foyer brûlant pour fondre le métal.", True, False, True),
    ('table_tailleur', 'Table de tailleur', "Pour tailler la pierre.", True, False, False),
    ('meule', 'Meule', "Pour polir la pierre et le marbre.", True, False, False),
    ('four', 'Four', "Un grand four pour cuire les tuiles et souffler le verre.", True, False, True),
    ('four_pain', 'Four à pain', "Un four en briques pour le pain.", True, False, True),
    ('petrin', 'Pétrin', "Pour pétrir la pâte.", True, False, False),
    ('mannequin', "Mannequin d'entraînement", "Pour s'entraîner au combat.", True, False, False),
    ('ratelier', "Râtelier d'armes", "Pour ranger les armes des gardes.", True, False, False),
    ('cible', 'Cible', "Une cible pour s'entraîner.", True, False, False),
    ('etal', 'Étal de marché', "Un étal couvert pour vendre ses marchandises.", True, False, False),
    ('comptoir', 'Comptoir', "Un comptoir de boutique ou de taverne.", True, False, False),
    ('bibliotheque', 'Bibliothèque', "Des étagères remplies de livres.", True, False, False),
    ('pupitre', 'Pupitre', "Pour lire et écrire.", True, False, False),
    ('autel', 'Autel', "Un autel sacré.", True, False, True),
    ('bougeoir', 'Bougeoir', "Trois bougies sur un pied de fer.", False, False, True),
    ('chaudron', 'Chaudron', "Un chaudron bouillonnant pour les potions.", True, False, True),
    ('metier_tisser', 'Métier à tisser', "Pour tisser le tissu.", True, False, False),
    ('auge', 'Auge', "Un abreuvoir pour les bêtes.", True, False, False),
    ('mangeoire', 'Mangeoire', "Du foin pour les bêtes.", True, False, False),
    ('billot', 'Billot', "Pour fendre le bois.", True, False, False),
    ('statue', 'Statue', "Une statue de marbre à la gloire du royaume.", True, False, False),
]

RAW = [
    ('marbre_brut', 'Marbre brut', "Un bloc de marbre extrait de la montagne. À polir à la meule.", 50, 2),
    ('or_brut', "Minerai d'or", "Une pépite dans sa gangue. À fondre au foyer de forge.", 50, 2),
    ('lingot_or', "Lingot d'or", "De l'or pur.", 50, 2),
    ('pain', 'Pain', "Du bon pain frais. Nourrit la population.", 50, 0),
    ('piece_or', "Pièce d'or", "La monnaie du royaume.", 999, 1),
]


def write_item(iid, name, desc, fields, ext=None):
    ext = ext or []
    L = ['[gd_resource type="Resource" script_class="ItemData" format=3]', '',
         '[ext_resource type="Script" path="res://scripts/data/item_data.gd" id="1"]']
    for eid, typ, path in ext:
        L.append('[ext_resource type="%s" path="%s" id="%s"]' % (typ, path, eid))
    L += ['', '[resource]', 'script = ExtResource("1")', 'id = %s' % q(iid), 'display_name = %s' % q(name),
          'description = %s' % q(desc)]
    for k, v in fields.items():
        L.append('%s = %s' % (k, v))
    with open(os.path.join(ROOT, 'data/items/%s.tres' % iid), 'w') as f:
        f.write('\n'.join(L) + '\n')


def items():
    for iid, name, desc, tier, slab, transp in BLOCKS:
        fields = {'max_stack': 99, 'block_texture': 'ExtResource("t")', 'block_tier': tier}
        if tier:
            fields['rarity'] = min(3, (tier + 1) // 2)
        if slab:
            fields['block_slab'] = 'true'
        if transp:
            fields['block_transparent'] = 'true'
        write_item(iid, name, desc, fields, [('t', 'Texture2D', 'res://assets/blocks/%s.png' % TEX.get(iid, iid))])
    for iid, name, desc, solid, door, light in FURN:
        fields = {'max_stack': 20, 'furniture_model': 'ExtResource("m")'}
        if not solid:
            fields['furniture_solid'] = 'false'
        if door:
            fields['furniture_door'] = 'true'
        if light:
            fields['furniture_light'] = 'true'
        write_item(iid, name, desc, fields, [('m', 'PackedScene', 'res://assets/furniture/%s.glb' % iid)])
    for iid, name, desc, stack, rar in RAW:
        f = {'max_stack': stack}
        if rar:
            f['rarity'] = rar
        write_item(iid, name, desc, f)


# ---------------------------------------------------------------- recettes
# (résultat, nombre, [(ingrédient, nb)], meuble nécessaire, catégorie)
RECIPES = [
    ('bloc_planches', 4, [('wood', 1)], '', 'Construction'),
    ('bloc_rondins', 2, [('wood', 1)], '', 'Construction'),
    ('dalle_planches', 4, [('wood', 1)], '', 'Construction'),
    ('bloc_chaume', 4, [('fiber', 2)], '', 'Construction'),
    ('bloc_pierre_brute', 2, [('stone', 1)], '', 'Construction'),
    ('dalle_pierre', 4, [('stone', 1)], '', 'Construction'),
    ('bloc_briques', 2, [('stone', 2)], 'table_tailleur', 'Construction'),
    ('bloc_tuiles', 4, [('bloc_terre', 2), ('wood', 1)], 'four', 'Construction'),
    ('bloc_verre', 2, [('bloc_sable', 2)], 'four', 'Construction'),
    ('bloc_pierre_polie', 2, [('stone', 2), ('bloc_sable', 1)], 'meule', 'Construction'),
    ('bloc_ardoise', 4, [('stone', 2)], 'meule', 'Construction'),
    ('bloc_marbre', 2, [('marbre_brut', 1)], 'meule', 'Construction'),
    ('bloc_marbre_noir', 2, [('marbre_brut', 1), ('iron_ore', 1)], 'meule', 'Construction'),
    ('bloc_marbre_dore', 2, [('bloc_marbre', 2), ('lingot_or', 1)], 'enclume', 'Construction'),
    ('lingot_or', 1, [('or_brut', 2), ('wood', 1)], 'foyer_forge', 'Matériaux'),
    ('porte', 1, [('wood', 2)], '', 'Mobilier'),
    ('etabli', 1, [('wood', 4)], '', 'Mobilier'),
    ('torche', 2, [('wood', 1), ('fiber', 1)], '', 'Mobilier'),
    ('lit', 1, [('wood', 3), ('fiber', 3)], 'etabli', 'Mobilier'),
    ('coffre', 1, [('wood', 3)], 'etabli', 'Mobilier'),
    ('table', 1, [('wood', 2)], 'etabli', 'Mobilier'),
    ('chaise', 1, [('wood', 1)], 'etabli', 'Mobilier'),
    ('tonneau', 1, [('wood', 3)], 'etabli', 'Mobilier'),
    ('lanterne', 1, [('iron_ingot', 1), ('wood', 1)], 'etabli', 'Mobilier'),
    ('billot', 1, [('wood', 2)], 'etabli', 'Mobilier'),
    ('enclume', 1, [('iron_ingot', 4)], 'etabli', 'Mobilier'),
    ('foyer_forge', 1, [('stone', 6), ('iron_ingot', 1)], 'etabli', 'Mobilier'),
    ('table_tailleur', 1, [('wood', 2), ('stone', 2)], 'etabli', 'Mobilier'),
    ('meule', 1, [('stone', 4), ('wood', 1)], 'etabli', 'Mobilier'),
    ('four', 1, [('stone', 6), ('bloc_terre', 2)], 'etabli', 'Mobilier'),
    ('four_pain', 1, [('stone', 4), ('bloc_terre', 2)], 'etabli', 'Mobilier'),
    ('petrin', 1, [('wood', 3)], 'etabli', 'Mobilier'),
    ('mannequin', 1, [('wood', 2), ('fiber', 2)], 'etabli', 'Mobilier'),
    ('ratelier', 1, [('wood', 3), ('iron_ingot', 1)], 'etabli', 'Mobilier'),
    ('cible', 1, [('wood', 2), ('fiber', 1)], 'etabli', 'Mobilier'),
    ('etal', 1, [('wood', 3), ('fiber', 2)], 'etabli', 'Mobilier'),
    ('comptoir', 1, [('wood', 3)], 'etabli', 'Mobilier'),
    ('bibliotheque', 1, [('wood', 4), ('leather', 1)], 'etabli', 'Mobilier'),
    ('pupitre', 1, [('wood', 2)], 'etabli', 'Mobilier'),
    ('autel', 1, [('bloc_pierre_polie', 4)], 'table_tailleur', 'Mobilier'),
    ('bougeoir', 1, [('iron_ingot', 1), ('fiber', 1)], 'etabli', 'Mobilier'),
    ('chaudron', 1, [('iron_ingot', 3)], 'enclume', 'Mobilier'),
    ('metier_tisser', 1, [('wood', 3), ('fiber', 2)], 'etabli', 'Mobilier'),
    ('auge', 1, [('wood', 2)], 'etabli', 'Mobilier'),
    ('mangeoire', 1, [('wood', 2), ('fiber', 2)], 'etabli', 'Mobilier'),
    ('statue', 1, [('bloc_marbre', 4), ('lingot_or', 1)], 'table_tailleur', 'Mobilier'),
]


def recipes():
    for res, n, ings, station, cat in RECIPES:
        ids = [res] + [i for i, _ in ings]
        uniq = list(dict.fromkeys(ids))
        L = ['[gd_resource type="Resource" script_class="RecipeData" format=3]', '',
             '[ext_resource type="Script" path="res://scripts/data/recipe_data.gd" id="1"]',
             '[ext_resource type="Script" path="res://scripts/data/item_data.gd" id="2"]']
        for i in uniq:
            L.append('[ext_resource type="Resource" path="res://data/items/%s.tres" id="it_%s"]' % (i, i))
        L += ['', '[resource]', 'script = ExtResource("1")', 'result = ExtResource("it_%s")' % res]
        if n != 1:
            L.append('result_count = %d' % n)
        L.append('ingredients = Array[ExtResource("2")]([%s])' % ', '.join('ExtResource("it_%s")' % i for i, _ in ings))
        L.append('amounts = PackedInt32Array(%s)' % ', '.join(str(a) for _, a in ings))
        if station:
            L.append('station = %s' % q(station))
        L.append('category = %s' % q(cat))
        with open(os.path.join(ROOT, 'data/recipes/%s.tres' % res), 'w') as f:
            f.write('\n'.join(L) + '\n')


# ---------------------------------------------------------------- pièces
# (id, nom, description, couleur, mobilier, taille min, métier, nom du métier, postes, production, nb, intervalle, lits, bonus héros, texte)
ROOMS = [
    ('maison', 'Maison', "Un foyer pour les habitants.", 'e8c080', {'lit': 1, 'coffre': 1}, 4, '', '', 0, '', 0, 0, 2, {}, "Loge 2 habitants."),
    ('dortoir', 'Dortoir', "Beaucoup de lits pour loger la population.", 'd0b080', {'lit': 4, 'coffre': 1}, 12, '', '', 0, '', 0, 0, 6, {}, "Loge 6 habitants."),
    ('forge', 'Forge', "On y fond le métal et on y forge les armes.", 'ff8a4a', {'enclume': 1, 'foyer_forge': 1, 'etabli': 1}, 6, 'forgeron', 'Forgeron', 2, 'iron_ingot', 1, 75, 0, {}, "Produit des lingots de fer."),
    ('boulangerie', 'Boulangerie', "L'odeur du pain chaud attire tout le village.", 'f0c070', {'four_pain': 1, 'petrin': 1, 'table': 1}, 6, 'boulanger', 'Boulanger', 2, 'pain', 2, 60, 0, {'regen': 1.0}, "Produit du pain. Héros : +1 PV/s."),
    ('caserne', "Camp d'entraînement", "Les gardes s'y entraînent au combat.", 'd05a4a', {'mannequin': 2, 'ratelier': 1}, 8, 'garde', 'Garde', 3, '', 0, 0, 0, {'attack': 2}, "Entraîne les gardes. Héros : +2 attaque."),
    ('grange', 'Grange', "Les bêtes de la ferme y sont nourries.", 'c8a060', {'auge': 1, 'mangeoire': 1, 'coffre': 1}, 8, 'fermier', 'Fermier', 2, 'leather', 1, 70, 0, {}, "Produit du cuir."),
    ('scierie', 'Scierie', "On y débite les troncs en planches.", 'b08a50', {'billot': 1, 'etabli': 1}, 6, 'bucheron', 'Bûcheron', 2, 'wood', 3, 60, 0, {}, "Produit du bois."),
    ('maconnerie', 'Maçonnerie', "Les maçons y taillent la pierre.", 'a8a8a0', {'table_tailleur': 1, 'meule': 1}, 6, 'macon', 'Maçon', 2, 'stone', 3, 60, 0, {}, "Produit de la pierre."),
    ('verrerie', 'Verrerie', "Les verriers y soufflent le verre.", '9ad8f0', {'four': 1, 'table': 1}, 6, 'verrier', 'Verrier', 1, 'bloc_verre', 2, 80, 0, {}, "Produit du verre."),
    ('taverne', 'Taverne', "On y boit, on y chante, on y échange les nouvelles.", 'd09040', {'tonneau': 2, 'table': 2, 'comptoir': 1}, 12, 'aubergiste', 'Aubergiste', 1, 'piece_or', 3, 60, 0, {'regen': 1.5}, "Rapporte des pièces d'or. Héros : +1,5 PV/s."),
    ('marche', 'Marché', "Les marchands y vendent leurs produits.", 'e0c040', {'etal': 2, 'comptoir': 1}, 9, 'marchand', 'Marchand', 2, 'piece_or', 4, 60, 0, {}, "Rapporte des pièces d'or."),
    ('bibliotheque', 'Bibliothèque', "Le savoir du royaume y est conservé.", '8a7ad0', {'bibliotheque': 2, 'pupitre': 1}, 6, 'erudit', 'Érudit', 2, '', 0, 0, 0, {'xp': 0.15}, "Héros : +15 % d'expérience."),
    ('temple', 'Temple', "Un lieu de prière et de guérison.", 'fff0b0', {'autel': 1, 'bougeoir': 2}, 9, 'pretre', 'Prêtre', 1, '', 0, 0, 0, {'regen': 2.0, 'defense': 2}, "Héros : +2 PV/s, +2 défense."),
    ('tour_mage', 'Tour de mage', "Un repaire de savants et de sorciers.", 'a060ff', {'chaudron': 1, 'bibliotheque': 1, 'pupitre': 1}, 6, 'mage', 'Mage', 2, '', 0, 0, 0, {'magic': 0.1}, "Héros : +10 % de magie."),
    ('atelier_tissage', 'Atelier de tissage', "Les tisserands y fabriquent le tissu.", '6a9ae0', {'metier_tisser': 1, 'coffre': 1}, 6, 'tisserand', 'Tisserand', 2, 'fiber', 3, 60, 0, {}, "Produit de la fibre."),
    ('entrepot', 'Entrepôt', "Les réserves du royaume.", '9a8a70', {'coffre': 3}, 9, '', '', 0, '', 0, 0, 0, {}, "Stockage."),
    ('salle_trone', 'Salle du trône', "Le cœur du pouvoir. Réservée aux grands royaumes.", 'ffd040', {'statue': 2, 'table': 1, 'lanterne': 2}, 20, '', '', 0, '', 0, 0, 0, {'attack': 3, 'defense': 3, 'xp': 0.1}, "Héros : +3 attaque, +3 défense, +10 % d'expérience."),
]


def rooms():
    os.makedirs(os.path.join(ROOT, 'data/rooms'), exist_ok=True)
    for (rid, name, desc, c, req, minc, job, jobn, slots, prod, pn, pi, beds, bonus, eff) in ROOMS:
        L = ['[gd_resource type="Resource" script_class="RoomTypeData" format=3]', '',
             '[ext_resource type="Script" path="res://scripts/data/room_type_data.gd" id="1"]']
        if prod:
            L.append('[ext_resource type="Resource" path="res://data/items/%s.tres" id="p"]' % prod)
        L += ['', '[resource]', 'script = ExtResource("1")', 'id = %s' % q(rid), 'display_name = %s' % q(name),
              'description = %s' % q(desc), 'color = %s' % col(c),
              'required = {%s}' % ', '.join('%s: %d' % (q(k), v) for k, v in req.items()),
              'min_cells = %d' % minc]
        if job:
            L += ['job_id = %s' % q(job), 'job_name = %s' % q(jobn), 'job_slots = %d' % slots]
        if prod:
            L += ['production = ExtResource("p")', 'production_count = %d' % pn, 'production_interval = %.1f' % pi]
        if beds:
            L.append('beds = %d' % beds)
        if bonus:
            L.append('hero_bonus = {%s}' % ', '.join('%s: %s' % (q(k), float(v)) for k, v in bonus.items()))
        L.append('effect_text = %s' % q(eff))
        with open(os.path.join(ROOT, 'data/rooms/%s.tres' % rid), 'w') as f:
            f.write('\n'.join(L) + '\n')


if __name__ == '__main__':
    items()
    recipes()
    rooms()
    print('%d blocs, %d meubles, %d ressources, %d recettes, %d pièces' % (len(BLOCKS), len(FURN), len(RAW), len(RECIPES), len(ROOMS)))
