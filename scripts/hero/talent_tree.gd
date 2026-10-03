class_name TalentTree
extends RefCounted
## Arbre de compétences du héros : une grande étoile à huit branches qui partent du centre dans toutes
## les directions (Lame, Feu, Foudre, Givre, Lumière, Terre, Sang, Ombre), reliées entre elles par des ponts.
## Tout l'arbre est ouvert dès le début : chaque nœud demande un niveau (de 1 à 990), des points, et un
## nœud voisin déjà appris (plus près du centre, sur sa branche ou sur un pont).
##   - runes (petits ronds) : petits bonus de la branche ;
##   - talents (grands ronds) : bonus importants ;
##   - compétences (carrés) : attaques et sorts à placer dans la barre de compétences (touches 1 à 0).
## Raretés : commune, rare, épique, légendaire, mystique (zones immenses, dégâts colossaux, effets
## spectaculaires). Tout au bout de la branche Terre, au niveau 990 : le Cataclysme.
## La branche Pacte (compétences uniques de l'histoire) est à part : offerte par l'histoire, sans points.

const BRANCHES := [
	{"id": "lame", "name": "Lame", "desc": "Épées, charges, tourbillons et coups critiques.", "color": Color("e8703a"), "angle": 0.0,
		"rune": "Rune de l'acier", "stats": {"atk_pct": 0.025, "aspd_pct": 0.02, "crit": 0.008}},
	{"id": "feu", "name": "Feu", "desc": "Boules de feu, brasiers, météores : brûler tout ce qui bouge.", "color": Color("ff5a2a"), "angle": 45.0,
		"rune": "Rune de braise", "stats": {"mag_pct": 0.03, "burn": 0.012}},
	{"id": "foudre", "name": "Foudre", "desc": "Éclairs en chaîne, orages et vitesse.", "color": Color("ffd23a"), "angle": 90.0,
		"rune": "Rune d'orage", "stats": {"mag_pct": 0.02, "cdr_pct": 0.012, "spd_pct": 0.01}},
	{"id": "givre", "name": "Givre", "desc": "Glace, ralentissements, prisons et armures de givre.", "color": Color("7ad0ff"), "angle": 135.0,
		"rune": "Rune de givre", "stats": {"mag_pct": 0.02, "slow": 0.015, "def_flat": 1.0}},
	{"id": "sacre", "name": "Lumière", "desc": "Soins, protections et jugements divins.", "color": Color("fff0a0"), "angle": 180.0,
		"rune": "Rune de lumière", "stats": {"hp_pct": 0.03, "regen": 0.4}},
	{"id": "terre", "name": "Terre", "desc": "Rocs, séismes, ronces ; tout au bout, le Cataclysme.", "color": Color("c8955a"), "angle": 225.0,
		"rune": "Rune de pierre", "stats": {"def_flat": 1.5, "hp_pct": 0.02, "poise": 0.04}},
	{"id": "sang", "name": "Sang", "desc": "Vol de vie, drains, rage et exécutions.", "color": Color("d83a5a"), "angle": 270.0,
		"rune": "Rune de sang", "stats": {"lifesteal": 0.008, "kill_heal": 1.0, "berserk": 0.03}},
	{"id": "ombre", "name": "Ombre", "desc": "Agilité, poisons, terreur et assassinats.", "color": Color("5ac870"), "angle": 315.0,
		"rune": "Rune d'ombre", "stats": {"spd_pct": 0.015, "dodge": 0.008, "crit_mult": 0.04}},
	{"id": "pacte", "name": "Pacte", "desc": "Compétences uniques de l'Éveillé : offertes par l'histoire, sans points.", "color": Color("c8a8ff"), "story": true},
]
const COMBAT_BRANCHES := ["lame", "feu", "foudre", "givre", "sacre", "terre", "sang", "ombre"]

## Raretés : nom, couleur, coût des compétences et des talents.
const RARITIES := {
	"commune": {"name": "Commune", "color": Color("c8c0b0"), "cost": 1},
	"rare": {"name": "Rare", "color": Color("4a9aff"), "cost": 2},
	"epique": {"name": "Épique", "color": Color("b45aff"), "cost": 3},
	"legendaire": {"name": "Légendaire", "color": Color("ff9a2a"), "cost": 5},
	"mystique": {"name": "Mystique", "color": Color("ff3a7a"), "cost": 12},
}
const RARITY_ORDER := ["commune", "rare", "epique", "legendaire", "mystique"]

## Niveau du héros requis pour chaque anneau (1 = près du centre, 16 = compétences mystiques, 18 = Cataclysme).
const RING_LEVEL := [1, 1, 3, 6, 10, 15, 22, 32, 45, 65, 90, 130, 190, 280, 400, 560, 700, 850, 990]
const RINGS := 16
## Distance du centre (pixels de l'arbre) : premier anneau, écart entre anneaux, écart entre voies.
const R0 := 170.0
const RING_STEP := 100.0
const LANE_W := 78.0
## Ponts entre deux branches voisines, à ces anneaux.
const BRIDGE_RINGS := [5, 9, 13]
## Emplacements de la barre de compétences (touches 1 à 9 et 0).
const SLOTS := 10

## Forme de chaque branche, anneau par anneau : [voie -1, voie 0, voie +1] ; « S » : rune, « A1 »... : compétence,
## « N1 »... : talent, « P » : talent de départ, « B1 » : talent passif voisin du départ, « M » : compétence mystique.
const SHAPE := [
	["", "P", ""],
	["A1", "S", "B1"],
	["S", "A2", "S"],
	["A3", "S", "N1"],
	["S", "S", "A4"],
	["N2", "A5", "S"],
	["S", "S", "S"],
	["A6", "N3", "S"],
	["S", "A7", "S"],
	["N4", "S", "A8"],
	["S", "S", "S"],
	["A9", "N5", "S"],
	["S", "S", "S"],
	["S", "A10", "N6"],
	["S", "S", "S"],
	["", "M", ""],
]
## Rareté de chaque compétence et talent de la forme.
const SHAPE_RARITY := {"P": "commune", "B1": "commune", "A1": "commune", "A2": "commune", "A3": "rare", "A4": "rare",
	"A5": "rare", "N1": "rare", "N2": "rare", "A6": "epique", "A7": "epique", "N3": "epique", "N4": "epique",
	"A8": "legendaire", "A9": "legendaire", "A10": "legendaire", "N5": "legendaire", "N6": "legendaire", "M": "mystique"}

## Contenu de chaque branche : clé de la forme -> talent ou compétence.
## Compétences : `active` (effet de HeroSkill), `params` (dmg : multiple de la puissance du héros), `cooldown`.
const CONTENT := {
	"lame": {
		"P": {"id": "lame_force", "glyph": "⚔", "name": "Force brute", "kind": "passive", "bonus": {"atk_pct": 0.08}, "desc": "+8 % d'attaque."},
		"B1": {"id": "lame_vitesse", "glyph": "»", "name": "Enchaînement", "kind": "passive", "bonus": {"aspd_pct": 0.12}, "desc": "+12 % de vitesse d'attaque."},
		"A1": {"id": "lame_tourbillon", "glyph": "◎", "name": "Tourbillon", "active": "move", "params": {"move": "spin", "dmg": 1.6}, "cooldown": 6.0,
			"desc": "Tu tournoies sur toi-même en frappant tout autour de toi."},
		"A2": {"id": "lame_charge", "glyph": "➹", "name": "Charge du taureau", "active": "dash", "params": {"dist": 7.0, "dmg": 1.8}, "cooldown": 8.0,
			"desc": "Tu fonces droit devant et renverses tout sur ton passage."},
		"A3": {"id": "lame_seisme", "glyph": "▼", "name": "Frappe sismique", "active": "stun", "params": {"radius": 3.8, "dmg": 2.0, "dur": 1.6}, "cooldown": 11.0,
			"desc": "Tu frappes le sol : les ennemis proches sont blessés et étourdis."},
		"N1": {"id": "lame_crit", "glyph": "✦", "name": "Œil du bourreau", "bonus": {"crit": 0.08, "crit_mult": 0.25}, "desc": "+8 % de coups critiques, +25 % de dégâts critiques."},
		"A4": {"id": "lame_onde", "glyph": "≋", "name": "Onde tranchante", "active": "cone", "params": {"range": 7.0, "dmg": 2.4, "kb": 10, "angle": 70}, "cooldown": 9.0,
			"desc": "Une lame d'énergie part devant toi et repousse les ennemis."},
		"N2": {"id": "lame_execute", "glyph": "☠", "name": "Exécution", "bonus": {"execute": 0.5}, "desc": "+50 % de dégâts contre les ennemis sous 30 % de vie."},
		"A5": {"id": "lame_croix", "glyph": "✚", "name": "Croix d'acier", "active": "nova", "params": {"radius": 3.8, "dmg": 2.6}, "cooldown": 10.0,
			"desc": "Deux coups en croix libèrent une onde d'acier tout autour de toi."},
		"A6": {"id": "lame_tempete", "glyph": "✺", "name": "Tempête de lames", "active": "vortex", "params": {"radius": 6.5, "dmg": 3.4}, "cooldown": 20.0,
			"desc": "Un tourbillon de lames aspire les ennemis puis explose."},
		"N3": {"id": "lame_maitre", "glyph": "♜", "name": "Maître d'armes", "bonus": {"atk_pct": 0.15, "aspd_pct": 0.1}, "desc": "+15 % d'attaque, +10 % de vitesse d'attaque."},
		"A7": {"id": "lame_titan", "glyph": "▲", "name": "Frappe du titan", "active": "stun", "params": {"radius": 5.5, "dmg": 3.4, "dur": 2.2}, "cooldown": 16.0,
			"desc": "Un coup d'une telle force que le sol se fend : tous les ennemis proches sont sonnés."},
		"N4": {"id": "lame_fureur", "glyph": "♨", "name": "Fureur du guerrier", "bonus": {"berserk": 0.3, "crit_mult": 0.3}, "desc": "+30 % de dégâts sous 35 % de vie, +30 % de dégâts critiques."},
		"A8": {"id": "lame_mille", "glyph": "✶", "name": "Mille coupures", "active": "aura", "params": {"radius": 3.4, "dps": 1.4, "dur": 6}, "cooldown": 22.0,
			"desc": "Pendant 6 secondes, des lames invisibles tailladent tout ce qui t'approche."},
		"A9": {"id": "lame_dechirure", "glyph": "⟋", "name": "Déchirure du ciel", "active": "cone", "params": {"range": 14.0, "dmg": 4.8, "kb": 16, "angle": 50}, "cooldown": 20.0,
			"desc": "Une entaille d'énergie fend l'air sur 14 mètres."},
		"N5": {"id": "lame_invaincue", "glyph": "♛", "name": "Lame invaincue", "bonus": {"atk_pct": 0.25, "crit": 0.08}, "desc": "+25 % d'attaque, +8 % de coups critiques."},
		"A10": {"id": "lame_jugement", "glyph": "⚡", "name": "Jugement d'acier", "active": "storm", "params": {"radius": 10.0, "dmg": 4.6, "count": 8, "fx": "blade"}, "cooldown": 28.0,
			"desc": "Huit épées géantes tombent du ciel sur les ennemis autour de toi."},
		"N6": {"id": "lame_legende", "glyph": "★", "name": "Légende vivante", "bonus": {"atk_pct": 0.2, "hp_pct": 0.15, "def_flat": 8.0}, "desc": "+20 % d'attaque, +15 % de vie, +8 défense."},
		"M": {"id": "lame_myth", "glyph": "☼", "name": "Mille Soleils d'Acier", "active": "storm", "params": {"radius": 18.0, "dmg": 12.0, "count": 24, "fx": "blade", "kb": 14}, "cooldown": 60.0,
			"desc": "MYSTIQUE : le ciel se déchire et une pluie de vingt-quatre épées de lumière s'abat sur tout ce qui vit à 18 mètres à la ronde."},
	},
	"feu": {
		"P": {"id": "arc_affinite", "glyph": "✧", "name": "Affinité arcanique", "kind": "passive", "bonus": {"mag_pct": 0.12}, "desc": "+12 % de magie."},
		"B1": {"id": "feu_braise", "glyph": "◦", "name": "Braises", "kind": "passive", "bonus": {"burn": 0.08, "mag_pct": 0.05}, "desc": "8 % de chances d'enflammer, +5 % de magie."},
		"A1": {"id": "arc_feu", "glyph": "☄", "name": "Boule de feu", "active": "volley", "params": {"count": 1, "dmg": 2.0, "burn": 0.7}, "cooldown": 4.0,
			"desc": "Lance une boule de feu qui enflamme sa cible."},
		"A2": {"id": "feu_jet", "glyph": "♒", "name": "Jet de flammes", "active": "cone", "params": {"range": 6.0, "dmg": 1.8, "angle": 60, "burn": 0.6, "kb": 4}, "cooldown": 7.0,
			"desc": "Un jet de flammes embrase les ennemis devant toi."},
		"A3": {"id": "feu_anneau", "glyph": "◯", "name": "Anneau de feu", "active": "nova", "params": {"radius": 4.0, "dmg": 2.2, "burn": 0.5}, "cooldown": 10.0,
			"desc": "Un cercle de flammes jaillit autour de toi."},
		"N1": {"id": "feu_combustion", "glyph": "♨", "name": "Combustion", "bonus": {"mag_pct": 0.1, "burn": 0.1}, "desc": "+10 % de magie, 10 % de chances d'enflammer."},
		"A4": {"id": "feu_brasier", "glyph": "♆", "name": "Brasier", "active": "dot", "params": {"radius": 4.2, "dps": 0.8, "dur": 6}, "cooldown": 12.0,
			"desc": "Le sol s'embrase : les ennemis qui restent dedans brûlent."},
		"N2": {"id": "feu_coeur", "glyph": "♥", "name": "Cœur ardent", "bonus": {"mag_pct": 0.12, "berserk": 0.15}, "desc": "+12 % de magie, +15 % de dégâts sous 35 % de vie."},
		"A5": {"id": "feu_salve", "glyph": "⁂", "name": "Salve incandescente", "active": "volley", "params": {"count": 5, "dmg": 1.6, "spread": 0.9, "burn": 0.5}, "cooldown": 9.0,
			"desc": "Cinq projectiles de feu en éventail."},
		"A6": {"id": "arc_meteores", "glyph": "☀", "name": "Pluie de météores", "active": "meteor", "params": {"radius": 3.4, "dmg": 3.2, "count": 5, "burn": 0.5}, "cooldown": 24.0,
			"desc": "Des météores s'écrasent sur les ennemis autour de toi."},
		"N3": {"id": "feu_phenix", "glyph": "♅", "name": "Âme de phénix", "bonus": {"last_stand": 1.0, "regen": 1.0}, "desc": "Tu renais de tes cendres (survit à un coup mortel toutes les 60 s), +1 vie par seconde."},
		"A7": {"id": "feu_explosion", "glyph": "✹", "name": "Explosion solaire", "active": "nova", "params": {"radius": 6.0, "dmg": 3.6, "burn": 0.6}, "cooldown": 16.0,
			"desc": "Tu deviens un petit soleil qui explose et brûle tout autour de toi."},
		"N4": {"id": "feu_pyromancien", "glyph": "♔", "name": "Pyromancien", "bonus": {"mag_pct": 0.2, "crit_mult": 0.25}, "desc": "+20 % de magie, +25 % de dégâts critiques."},
		"A8": {"id": "feu_souffle", "glyph": "♈", "name": "Souffle infernal", "active": "cone", "params": {"range": 11.0, "dmg": 4.2, "angle": 80, "burn": 0.9, "kb": 12}, "cooldown": 18.0,
			"desc": "Un torrent de flammes infernales sur 11 mètres."},
		"A9": {"id": "feu_colonnes", "glyph": "‖", "name": "Colonnes de feu", "active": "storm", "params": {"radius": 9.0, "dmg": 4.6, "count": 8, "burn": 0.8, "fx": "fire"}, "cooldown": 24.0,
			"desc": "Des colonnes de feu jaillissent sous huit ennemis."},
		"N5": {"id": "feu_avatar", "glyph": "♚", "name": "Avatar des flammes", "bonus": {"mag_pct": 0.25, "burn": 0.15}, "desc": "+25 % de magie, 15 % de chances d'enflammer."},
		"A10": {"id": "feu_supernova", "glyph": "✺", "name": "Supernova", "active": "nova", "params": {"radius": 9.0, "dmg": 5.2, "burn": 1.0}, "cooldown": 30.0,
			"desc": "Une explosion stellaire de 9 mètres."},
		"N6": {"id": "feu_eternel", "glyph": "∞", "name": "Feu éternel", "bonus": {"mag_pct": 0.2, "cdr_pct": 0.1}, "desc": "+20 % de magie, recharges -10 %."},
		"M": {"id": "feu_myth", "glyph": "☄", "name": "Apocalypse", "active": "meteor", "params": {"radius": 5.0, "dmg": 11.0, "count": 18, "burn": 1.0, "area": 18.0}, "cooldown": 70.0,
			"desc": "MYSTIQUE : le ciel s'embrase et dix-huit météores géants pilonnent tout à 18 mètres à la ronde."},
	},
	"foudre": {
		"P": {"id": "fou_etincelle", "glyph": "ϟ", "name": "Étincelle", "kind": "passive", "bonus": {"mag_pct": 0.08, "aspd_pct": 0.05}, "desc": "+8 % de magie, +5 % de vitesse d'attaque."},
		"B1": {"id": "fou_vivacite", "glyph": "»", "name": "Vivacité", "kind": "passive", "bonus": {"spd_pct": 0.05, "aspd_pct": 0.05}, "desc": "+5 % de vitesse, +5 % de vitesse d'attaque."},
		"A1": {"id": "arc_eclair", "glyph": "ϟ", "name": "Éclair en chaîne", "active": "chain", "params": {"count": 4, "dmg": 1.6, "stun": 0.35}, "cooldown": 6.0,
			"desc": "La foudre frappe l'ennemi le plus proche puis rebondit sur 3 autres."},
		"A2": {"id": "fou_decharge", "glyph": "✳", "name": "Décharge", "active": "nova", "params": {"radius": 3.2, "dmg": 1.7, "stun": 0.3}, "cooldown": 7.0,
			"desc": "Une décharge électrique autour de toi."},
		"A3": {"id": "fou_celeste", "glyph": "↯", "name": "Foudre céleste", "active": "storm", "params": {"radius": 7.0, "dmg": 2.4, "count": 3, "stun": 0.5, "fx": "bolt"}, "cooldown": 10.0,
			"desc": "Trois éclairs tombent du ciel sur les ennemis proches."},
		"N1": {"id": "arc_savoir", "glyph": "◷", "name": "Concentration", "bonus": {"cdr_pct": 0.12}, "desc": "Toutes les recharges sont 12 % plus rapides."},
		"A4": {"id": "fou_boules", "glyph": "◉", "name": "Boules de foudre", "active": "volley", "params": {"count": 3, "dmg": 2.0, "stun": 0.4, "spread": 0.7}, "cooldown": 8.0,
			"desc": "Trois sphères de foudre qui sonnent leurs cibles."},
		"N2": {"id": "arc_puissance", "glyph": "✪", "name": "Surcharge", "bonus": {"mag_pct": 0.15, "crit": 0.05}, "desc": "+15 % de magie, +5 % de coups critiques."},
		"A5": {"id": "fou_saut", "glyph": "⇢", "name": "Saut foudroyant", "active": "blink", "params": {"dist": 9.0, "dmg": 2.6}, "cooldown": 8.0,
			"desc": "Tu deviens éclair : téléportation et décharge à l'arrivée."},
		"A6": {"id": "fou_cage", "glyph": "▦", "name": "Cage électrique", "active": "slow_field", "params": {"radius": 6.0, "dps": 1.3, "factor": 0.3, "dur": 6}, "cooldown": 16.0,
			"desc": "Un champ électrique ralentit et électrocute les ennemis."},
		"N3": {"id": "fou_conducteur", "glyph": "⌁", "name": "Conducteur", "bonus": {"stun": 0.08, "aspd_pct": 0.12}, "desc": "8 % de chances d'étourdir, +12 % de vitesse d'attaque."},
		"A7": {"id": "fou_arc", "glyph": "⌇", "name": "Arc électrique géant", "active": "chain", "params": {"count": 8, "dmg": 3.2, "stun": 0.5}, "cooldown": 14.0,
			"desc": "Un éclair qui rebondit sur huit ennemis."},
		"N4": {"id": "fou_oeil", "glyph": "◎", "name": "Œil de la tempête", "bonus": {"cdr_pct": 0.12, "spd_pct": 0.08}, "desc": "Recharges -12 %, +8 % de vitesse."},
		"A8": {"id": "fou_tonnerre", "glyph": "✸", "name": "Coup de tonnerre", "active": "stun", "params": {"radius": 8.0, "dmg": 4.0, "dur": 2.5}, "cooldown": 20.0,
			"desc": "Un coup de tonnerre assourdissant sonne tout à 8 mètres."},
		"A9": {"id": "fou_orage", "glyph": "☈", "name": "Orage", "active": "storm", "params": {"radius": 12.0, "dmg": 3.8, "count": 12, "stun": 0.6, "fx": "bolt"}, "cooldown": 26.0,
			"desc": "Douze éclairs frappent les ennemis autour de toi."},
		"N5": {"id": "fou_seigneur", "glyph": "♛", "name": "Seigneur de l'orage", "bonus": {"mag_pct": 0.2, "crit": 0.08}, "desc": "+20 % de magie, +8 % de coups critiques."},
		"A10": {"id": "fou_lance", "glyph": "↟", "name": "Lance de Zeus", "active": "cone", "params": {"range": 16.0, "dmg": 5.8, "angle": 30, "kb": 20, "stun": 0.8}, "cooldown": 26.0,
			"desc": "Une lance de foudre traverse tout sur 16 mètres."},
		"N6": {"id": "fou_surtension", "glyph": "⌬", "name": "Surtension", "bonus": {"cdr_pct": 0.15, "mag_pct": 0.1}, "desc": "Recharges -15 %, +10 % de magie."},
		"M": {"id": "fou_myth", "glyph": "☇", "name": "Colère du Ciel", "active": "storm", "params": {"radius": 20.0, "dmg": 11.0, "count": 40, "stun": 1.0, "fx": "bolt"}, "cooldown": 60.0,
			"desc": "MYSTIQUE : quarante éclairs géants foudroient tout à 20 mètres à la ronde."},
	},
	"givre": {
		"P": {"id": "giv_froid", "glyph": "❄", "name": "Sang-froid", "kind": "passive", "bonus": {"def_flat": 2.0, "mag_pct": 0.06}, "desc": "+2 défense, +6 % de magie."},
		"B1": {"id": "giv_peau", "glyph": "◇", "name": "Peau de glace", "kind": "passive", "bonus": {"def_flat": 3.0}, "desc": "+3 défense."},
		"A1": {"id": "arc_givre", "glyph": "❄", "name": "Nova de givre", "active": "nova", "params": {"radius": 4.2, "dmg": 1.3, "slow": 1.0}, "cooldown": 9.0,
			"desc": "Une explosion de glace blesse et ralentit tous les ennemis autour de toi."},
		"A2": {"id": "giv_eclats", "glyph": "✧", "name": "Éclats de glace", "active": "volley", "params": {"count": 4, "dmg": 1.4, "spread": 1.0, "slow": 1.0}, "cooldown": 6.0,
			"desc": "Quatre éclats de glace qui ralentissent."},
		"A3": {"id": "giv_prison", "glyph": "▣", "name": "Prison de glace", "active": "stun", "params": {"radius": 4.0, "dmg": 1.6, "dur": 2.5}, "cooldown": 12.0,
			"desc": "La glace emprisonne les ennemis proches."},
		"N1": {"id": "giv_hiver", "glyph": "✻", "name": "Cœur d'hiver", "bonus": {"slow": 0.1, "mag_pct": 0.1}, "desc": "10 % de chances de ralentir, +10 % de magie."},
		"A4": {"id": "giv_rafale", "glyph": "≈", "name": "Rafale glaciale", "active": "cone", "params": {"range": 7.0, "dmg": 2.4, "angle": 90, "slow": 1.0, "kb": 6}, "cooldown": 9.0,
			"desc": "Un souffle glacé devant toi."},
		"N2": {"id": "giv_carapace", "glyph": "⬢", "name": "Carapace de givre", "bonus": {"def_flat": 6.0, "hp_pct": 0.06}, "desc": "+6 défense, +6 % de vie."},
		"A5": {"id": "giv_miroir", "glyph": "◈", "name": "Miroir de glace", "active": "barrier", "params": {"dur": 5.0, "reduce": 0.6, "reflect": 1}, "cooldown": 18.0,
			"desc": "Un miroir de glace absorbe 60 % des dégâts et les renvoie."},
		"A6": {"id": "giv_tempete", "glyph": "❅", "name": "Tempête de neige", "active": "slow_field", "params": {"radius": 7.0, "dps": 1.1, "factor": 0.35, "dur": 8}, "cooldown": 18.0,
			"desc": "Une tempête de neige gèle les ennemis sur 7 mètres."},
		"N3": {"id": "giv_zero", "glyph": "0", "name": "Zéro absolu", "bonus": {"slow": 0.15, "execute": 0.25}, "desc": "15 % de chances de ralentir, +25 % contre les ennemis affaiblis."},
		"A7": {"id": "giv_lances", "glyph": "↡", "name": "Lances de glace", "active": "storm", "params": {"radius": 9.0, "dmg": 3.4, "count": 6, "slow": 1.0, "fx": "ice"}, "cooldown": 16.0,
			"desc": "Six lances de glace tombent du ciel."},
		"N4": {"id": "giv_glacier", "glyph": "▲", "name": "Glacier", "bonus": {"def_flat": 10.0, "hp_pct": 0.1}, "desc": "+10 défense, +10 % de vie."},
		"A8": {"id": "giv_comete", "glyph": "☄", "name": "Comète gelée", "active": "meteor", "params": {"radius": 4.0, "dmg": 4.2, "count": 3, "slow": 1.0}, "cooldown": 22.0,
			"desc": "Trois comètes de glace s'écrasent sur les ennemis."},
		"A9": {"id": "giv_ere", "glyph": "✺", "name": "Ère glaciaire", "active": "nova", "params": {"radius": 10.0, "dmg": 4.4, "slow": 1.0}, "cooldown": 26.0,
			"desc": "Le froid se répand sur 10 mètres et fige tout."},
		"N5": {"id": "giv_souverain", "glyph": "♕", "name": "Souverain des glaces", "bonus": {"mag_pct": 0.2, "def_flat": 8.0}, "desc": "+20 % de magie, +8 défense."},
		"A10": {"id": "giv_tombeau", "glyph": "⛫", "name": "Tombeau de cristal", "active": "stun", "params": {"radius": 9.0, "dmg": 4.8, "dur": 4.0}, "cooldown": 30.0,
			"desc": "Tous les ennemis à 9 mètres sont pris dans le cristal 4 secondes."},
		"N6": {"id": "giv_eternel", "glyph": "∞", "name": "Hiver éternel", "bonus": {"slow": 0.2, "mag_pct": 0.15}, "desc": "20 % de chances de ralentir, +15 % de magie."},
		"M": {"id": "giv_myth", "glyph": "❆", "name": "Fimbulvetr", "active": "nova", "params": {"radius": 20.0, "dmg": 10.0, "slow": 1.0, "field": 1}, "cooldown": 65.0,
			"desc": "MYSTIQUE : l'hiver de la fin du monde. Une vague de glace de 20 mètres broie tout, puis un blizzard reste sur place."},
	},
	"sacre": {
		"P": {"id": "sac_foi", "glyph": "✝", "name": "Foi", "kind": "passive", "bonus": {"hp_pct": 0.06, "regen": 0.5}, "desc": "+6 % de vie, +0,5 vie par seconde."},
		"B1": {"id": "sac_benediction", "glyph": "✧", "name": "Bénédiction", "kind": "passive", "bonus": {"regen": 1.0}, "desc": "+1 vie par seconde."},
		"A1": {"id": "arc_soin", "glyph": "✚", "name": "Lumière guérisseuse", "active": "heal", "params": {"pct": 0.3, "allies": 1}, "cooldown": 18.0,
			"desc": "Rend 30 % de ta vie, et soigne les compagnons et habitants proches."},
		"A2": {"id": "arc_bouclier", "glyph": "⬡", "name": "Bouclier arcanique", "active": "barrier", "params": {"dur": 5.0, "reduce": 0.6}, "cooldown": 16.0,
			"desc": "Une barrière absorbe 60 % des dégâts pendant 5 secondes."},
		"A3": {"id": "sac_marteau", "glyph": "⚒", "name": "Marteau sacré", "active": "meteor", "params": {"radius": 3.0, "dmg": 2.6, "count": 1}, "cooldown": 9.0,
			"desc": "Un marteau de lumière s'abat sur un ennemi."},
		"N1": {"id": "sac_aura", "glyph": "☼", "name": "Aura de vie", "bonus": {"hp_pct": 0.1, "regen": 1.0}, "desc": "+10 % de vie, +1 vie par seconde."},
		"A4": {"id": "sac_consecration", "glyph": "◌", "name": "Consécration", "active": "dot", "params": {"radius": 4.5, "dps": 0.9, "dur": 6}, "cooldown": 14.0,
			"desc": "Le sol consacré brûle les ennemis qui s'y trouvent."},
		"N2": {"id": "sac_gardien", "glyph": "⛨", "name": "Gardien", "bonus": {"def_flat": 5.0, "thorns": 0.1}, "desc": "+5 défense, renvoie 10 % des dégâts reçus."},
		"A5": {"id": "sac_purification", "glyph": "✺", "name": "Purification", "active": "nova", "params": {"radius": 5.0, "dmg": 2.4, "heal": 0.1}, "cooldown": 12.0,
			"desc": "Une onde de lumière blesse les ennemis et te soigne de 10 %."},
		"A6": {"id": "sac_sanctuaire", "glyph": "⌂", "name": "Sanctuaire", "active": "barrier", "params": {"dur": 8.0, "reduce": 0.75, "heal": 0.25}, "cooldown": 28.0,
			"desc": "Un sanctuaire absorbe 75 % des dégâts pendant 8 s et te soigne de 25 %."},
		"N3": {"id": "sac_martyr", "glyph": "♰", "name": "Martyr", "bonus": {"last_stand": 1.0, "hp_pct": 0.1}, "desc": "Survit à un coup mortel toutes les 60 s, +10 % de vie."},
		"A7": {"id": "sac_rayons", "glyph": "⇣", "name": "Rayons divins", "active": "storm", "params": {"radius": 10.0, "dmg": 3.4, "count": 7, "fx": "holy"}, "cooldown": 16.0,
			"desc": "Sept rayons de lumière frappent les ennemis."},
		"N4": {"id": "sac_saintete", "glyph": "☩", "name": "Sainteté", "bonus": {"regen": 3.0, "cdr_pct": 0.08}, "desc": "+3 vie par seconde, recharges -8 %."},
		"A8": {"id": "sac_grace", "glyph": "♱", "name": "Grâce céleste", "active": "heal", "params": {"pct": 0.8, "allies": 1}, "cooldown": 40.0,
			"desc": "Rend 80 % de la vie, à toi et à tes alliés proches (relève ceux qui sont à terre)."},
		"A9": {"id": "sac_ailes", "glyph": "⇮", "name": "Ailes de lumière", "active": "blink", "params": {"dist": 12.0, "dmg": 4.2}, "cooldown": 14.0,
			"desc": "Des ailes de lumière te portent 12 mètres plus loin ; l'atterrissage foudroie les ennemis."},
		"N5": {"id": "sac_champion", "glyph": "♔", "name": "Champion de l'aube", "bonus": {"hp_pct": 0.2, "def_flat": 10.0}, "desc": "+20 % de vie, +10 défense."},
		"A10": {"id": "sac_jugement", "glyph": "⚖", "name": "Jugement", "active": "storm", "params": {"radius": 13.0, "dmg": 4.8, "count": 14, "fx": "holy"}, "cooldown": 28.0,
			"desc": "Quatorze colonnes de lumière jugent les ennemis autour de toi."},
		"N6": {"id": "sac_eternite", "glyph": "∞", "name": "Éternité", "bonus": {"regen": 5.0, "last_stand": 1.0}, "desc": "+5 vie par seconde, survit à un coup mortel."},
		"M": {"id": "sac_myth", "glyph": "☀", "name": "Aube Éternelle", "active": "storm", "params": {"radius": 18.0, "dmg": 10.0, "count": 30, "fx": "holy", "heal": 1.0}, "cooldown": 70.0,
			"desc": "MYSTIQUE : un soleil se lève au-dessus de toi. Trente colonnes de lumière anéantissent tes ennemis à 18 mètres, et ta vie est entièrement rendue."},
	},
	"terre": {
		"P": {"id": "ter_racine", "glyph": "⏚", "name": "Enraciné", "kind": "passive", "bonus": {"def_flat": 2.0, "hp_pct": 0.05}, "desc": "+2 défense, +5 % de vie."},
		"B1": {"id": "ter_roc", "glyph": "◆", "name": "Peau de roc", "kind": "passive", "bonus": {"def_flat": 3.0, "poise": 0.1}, "desc": "+3 défense, coups plus lourds."},
		"A1": {"id": "ter_poing", "glyph": "✊", "name": "Poing de pierre", "active": "nova", "params": {"radius": 2.8, "dmg": 1.8}, "cooldown": 5.0,
			"desc": "Un coup de poing qui fait trembler le sol autour de toi."},
		"A2": {"id": "ter_secousse", "glyph": "≋", "name": "Secousse", "active": "stun", "params": {"radius": 4.0, "dmg": 1.4, "dur": 1.4}, "cooldown": 10.0,
			"desc": "Le sol tremble et sonne les ennemis proches."},
		"A3": {"id": "ter_rochers", "glyph": "●", "name": "Pluie de rochers", "active": "meteor", "params": {"radius": 2.6, "dmg": 2.2, "count": 3}, "cooldown": 12.0,
			"desc": "Trois rochers tombent sur les ennemis."},
		"N1": {"id": "ter_montagne", "glyph": "▲", "name": "Force de la montagne", "bonus": {"hp_pct": 0.1, "atk_pct": 0.06}, "desc": "+10 % de vie, +6 % d'attaque."},
		"A4": {"id": "ter_ronces", "glyph": "❦", "name": "Ronces", "active": "slow_field", "params": {"radius": 5.0, "dps": 0.9, "factor": 0.4, "dur": 6}, "cooldown": 14.0,
			"desc": "Des ronces sortent du sol, retiennent et lacèrent les ennemis."},
		"N2": {"id": "ter_epines", "glyph": "✶", "name": "Épines", "bonus": {"thorns": 0.2}, "desc": "Renvoie 20 % des dégâts reçus."},
		"A5": {"id": "ter_avalanche", "glyph": "➹", "name": "Avalanche", "active": "dash", "params": {"dist": 9.0, "dmg": 2.8}, "cooldown": 9.0,
			"desc": "Tu dévales comme un éboulement et écrases tout sur ton passage."},
		"A6": {"id": "ter_faille", "glyph": "⟋", "name": "Faille", "active": "cone", "params": {"range": 10.0, "dmg": 3.4, "angle": 40, "stun": 0.6, "kb": 14}, "cooldown": 16.0,
			"desc": "Le sol se fend sur 10 mètres devant toi."},
		"N3": {"id": "ter_golem", "glyph": "⬛", "name": "Cœur de golem", "bonus": {"def_flat": 10.0, "hp_pct": 0.12}, "desc": "+10 défense, +12 % de vie."},
		"A7": {"id": "ter_etreinte", "glyph": "§", "name": "Étreinte des racines", "active": "vortex", "params": {"radius": 7.0, "dmg": 3.2}, "cooldown": 18.0,
			"desc": "Des racines géantes attirent et broient les ennemis."},
		"N4": {"id": "ter_tellurique", "glyph": "⊕", "name": "Tellurique", "bonus": {"poise": 0.3, "stun": 0.05}, "desc": "Coups bien plus lourds, 5 % de chances d'étourdir."},
		"A8": {"id": "ter_eruption", "glyph": "♨", "name": "Éruption", "active": "dot", "params": {"radius": 6.0, "dps": 1.7, "dur": 7, "burn": 0.5}, "cooldown": 22.0,
			"desc": "La lave jaillit du sol sur 6 mètres."},
		"A9": {"id": "ter_titan", "glyph": "✊", "name": "Poing du titan", "active": "meteor", "params": {"radius": 7.0, "dmg": 6.2, "count": 1}, "cooldown": 22.0,
			"desc": "Un poing de pierre géant s'abat du ciel."},
		"N5": {"id": "ter_gardien", "glyph": "⛰", "name": "Gardien de la terre", "bonus": {"def_flat": 14.0, "hp_pct": 0.15}, "desc": "+14 défense, +15 % de vie."},
		"A10": {"id": "ter_tremblement", "glyph": "≣", "name": "Grand tremblement", "active": "stun", "params": {"radius": 12.0, "dmg": 4.8, "dur": 3.0}, "cooldown": 30.0,
			"desc": "Un tremblement de terre sonne tout à 12 mètres."},
		"N6": {"id": "ter_immuable", "glyph": "▣", "name": "Immuable", "bonus": {"hp_pct": 0.2, "thorns": 0.2}, "desc": "+20 % de vie, renvoie 20 % des dégâts."},
		"M": {"id": "ter_myth", "glyph": "⛰", "name": "Fureur de Gaïa", "active": "stun", "params": {"radius": 18.0, "dmg": 11.0, "dur": 4.0, "fx": "rocks"}, "cooldown": 60.0,
			"desc": "MYSTIQUE : la terre entière se soulève. Des pics de roche jaillissent à 18 mètres à la ronde et pétrifient tes ennemis."},
	},
	"sang": {
		"P": {"id": "san_soif", "glyph": "♥", "name": "Soif", "kind": "passive", "bonus": {"lifesteal": 0.02, "kill_heal": 2.0}, "desc": "2 % de vol de vie, +2 vie par ennemi vaincu."},
		"B1": {"id": "san_rage", "glyph": "♨", "name": "Rage", "kind": "passive", "bonus": {"berserk": 0.1}, "desc": "+10 % de dégâts sous 35 % de vie."},
		"A1": {"id": "san_drain", "glyph": "♆", "name": "Drain", "active": "drain", "params": {"radius": 4.0, "dmg": 1.6, "ratio": 0.5}, "cooldown": 9.0,
			"desc": "Aspire la vie des ennemis proches."},
		"A2": {"id": "san_lame", "glyph": "⟋", "name": "Lame sanglante", "active": "cone", "params": {"range": 5.0, "dmg": 2.0, "angle": 70, "kb": 5}, "cooldown": 6.0,
			"desc": "Une lame de sang devant toi."},
		"A3": {"id": "san_saignee", "glyph": "◍", "name": "Saignée", "active": "dot", "params": {"radius": 4.0, "dps": 0.7, "dur": 6}, "cooldown": 12.0,
			"desc": "Les ennemis proches saignent pendant 6 secondes."},
		"N1": {"id": "san_vampire", "glyph": "♅", "name": "Vampirisme", "bonus": {"lifesteal": 0.04}, "desc": "4 % de vol de vie."},
		"A4": {"id": "san_furie", "glyph": "✹", "name": "Furie sanguine", "active": "buff", "params": {"atk": 0.25, "lifesteal": 0.1, "dur": 8.0, "cost": 0.1}, "cooldown": 18.0,
			"desc": "Tu sacrifies 10 % de ta vie : +25 % d'attaque et 10 % de vol de vie pendant 8 s."},
		"N2": {"id": "san_carnage", "glyph": "☠", "name": "Carnage", "bonus": {"kill_heal": 6.0, "execute": 0.2}, "desc": "+6 vie par ennemi vaincu, +20 % contre les ennemis affaiblis."},
		"A5": {"id": "san_explosion", "glyph": "✺", "name": "Explosion de sang", "active": "nova", "params": {"radius": 5.0, "dmg": 2.6}, "cooldown": 11.0,
			"desc": "Le sang des ennemis explose autour de toi."},
		"A6": {"id": "san_lune", "glyph": "☾", "name": "Lune de sang", "active": "drain", "params": {"radius": 8.0, "dmg": 3.0, "ratio": 0.6}, "cooldown": 18.0,
			"desc": "Une lune rouge aspire la vie de tout à 8 mètres."},
		"N3": {"id": "san_berserker", "glyph": "♞", "name": "Berserker", "bonus": {"berserk": 0.3, "aspd_pct": 0.1}, "desc": "+30 % de dégâts sous 35 % de vie, +10 % de vitesse d'attaque."},
		"A7": {"id": "san_terreur", "glyph": "☽", "name": "Terreur sanglante", "active": "fear", "params": {"radius": 8.0, "dmg": 2.6, "dur": 4.0}, "cooldown": 18.0,
			"desc": "Les ennemis à 8 mètres saignent et s'enfuient, terrorisés."},
		"N4": {"id": "san_immortel", "glyph": "♾", "name": "Immortel", "bonus": {"last_stand": 1.0, "lifesteal": 0.03}, "desc": "Survit à un coup mortel toutes les 60 s, 3 % de vol de vie."},
		"A8": {"id": "san_tempete", "glyph": "✽", "name": "Tempête écarlate", "active": "vortex", "params": {"radius": 8.0, "dmg": 4.4}, "cooldown": 22.0,
			"desc": "Un tourbillon de sang aspire les ennemis puis éclate."},
		"A9": {"id": "san_execution", "glyph": "†", "name": "Exécution sanglante", "active": "execute", "params": {"range": 9.0, "dmg": 5.2, "threshold": 0.4}, "cooldown": 12.0,
			"desc": "Tu bondis sur l'ennemi le plus faible : triples dégâts s'il est sous 40 % de vie."},
		"N5": {"id": "san_seigneur", "glyph": "♛", "name": "Seigneur vampire", "bonus": {"lifesteal": 0.06, "hp_pct": 0.1}, "desc": "6 % de vol de vie, +10 % de vie."},
		"A10": {"id": "san_ocean", "glyph": "≋", "name": "Océan de sang", "active": "dot", "params": {"radius": 10.0, "dps": 2.0, "dur": 6}, "cooldown": 28.0,
			"desc": "Une mer de sang de 10 mètres dévore les ennemis."},
		"N6": {"id": "san_eternel", "glyph": "∞", "name": "Sang éternel", "bonus": {"kill_heal": 15.0, "regen": 3.0}, "desc": "+15 vie par ennemi vaincu, +3 vie par seconde."},
		"M": {"id": "san_myth", "glyph": "☾", "name": "Nuit Pourpre", "active": "drain", "params": {"radius": 20.0, "dmg": 10.0, "ratio": 0.3, "fx": "blood"}, "cooldown": 60.0,
			"desc": "MYSTIQUE : la lune devient pourpre. Tout ce qui vit à 20 mètres se vide de son sang, qui afflue vers toi."},
	},
	"ombre": {
		"P": {"id": "omb_reflexes", "glyph": "↯", "name": "Réflexes", "kind": "passive", "bonus": {"dash_cd": 0.3, "dodge": 0.05}, "desc": "Roulade 30 % plus souvent, esquive parfaite plus facile."},
		"B1": {"id": "omb_double_saut", "glyph": "⇈", "name": "Double saut", "kind": "passive", "bonus": {"double_jump": 1.0}, "desc": "Tu peux sauter une seconde fois en l'air (monte sur 2 blocs)."},
		"A1": {"id": "omb_pas", "glyph": "◌", "name": "Pas de l'ombre", "active": "blink", "params": {"dist": 7.0, "dmg": 1.5}, "cooldown": 7.0,
			"desc": "Tu te téléportes vers l'avant et blesses ceux qui t'entourent à l'arrivée."},
		"A2": {"id": "omb_poison", "glyph": "☣", "name": "Lames empoisonnées", "active": "buff", "params": {"burn": 0.6, "dur": 10.0}, "cooldown": 16.0,
			"desc": "Pendant 10 secondes, tes coups empoisonnent souvent leur cible."},
		"A3": {"id": "omb_dagues", "glyph": "⁑", "name": "Dagues de l'ombre", "active": "volley", "params": {"count": 5, "dmg": 1.4, "spread": 1.1}, "cooldown": 7.0,
			"desc": "Cinq dagues lancées en éventail."},
		"N1": {"id": "omb_vitalite", "glyph": "♥", "name": "Vitalité", "bonus": {"hp_pct": 0.15}, "desc": "+15 % de vie maximale."},
		"A4": {"id": "omb_terreur", "glyph": "☾", "name": "Terreur", "active": "fear", "params": {"radius": 5.5, "dur": 3.0, "dmg": 1.0}, "cooldown": 18.0,
			"desc": "Les ennemis autour de toi s'enfuient, terrorisés."},
		"N2": {"id": "omb_regen", "glyph": "❦", "name": "Régénération", "bonus": {"regen": 2.0}, "desc": "+2 points de vie par seconde."},
		"A5": {"id": "omb_assassinat", "glyph": "†", "name": "Assassinat", "active": "execute", "params": {"range": 8.0, "dmg": 2.8, "threshold": 0.3}, "cooldown": 10.0,
			"desc": "Tu surgis derrière l'ennemi le plus faible : triples dégâts s'il est sous 30 % de vie."},
		"A6": {"id": "omb_frenesie", "glyph": "✹", "name": "Frénésie", "active": "buff", "params": {"atk": 0.35, "aspd": 0.35, "lifesteal": 0.1, "spd": 0.2, "dur": 10.0}, "cooldown": 36.0,
			"desc": "10 secondes de rage (+35 % d'attaque et de vitesse d'attaque, vol de vie)."},
		"N3": {"id": "omb_sang", "glyph": "♆", "name": "Soif de sang", "bonus": {"lifesteal": 0.06, "kill_heal": 5.0}, "desc": "6 % de vol de vie, +5 vie par ennemi vaincu."},
		"A7": {"id": "omb_nuee", "glyph": "⁂", "name": "Nuée d'ombres", "active": "aura", "params": {"radius": 4.0, "dps": 1.5, "dur": 6}, "cooldown": 18.0,
			"desc": "Une nuée d'ombres te suit et dévore les ennemis proches."},
		"N4": {"id": "omb_fantome", "glyph": "◌", "name": "Fantôme", "bonus": {"dodge": 0.08, "spd_pct": 0.1}, "desc": "Esquive parfaite bien plus facile, +10 % de vitesse."},
		"A8": {"id": "omb_eclipse", "glyph": "◐", "name": "Éclipse", "active": "fear", "params": {"radius": 10.0, "dmg": 3.8, "dur": 4.0}, "cooldown": 24.0,
			"desc": "Le jour s'éteint : les ennemis à 10 mètres sont blessés et fuient."},
		"A9": {"id": "omb_danse", "glyph": "✕", "name": "Danse des mille lames", "active": "chain", "params": {"count": 10, "dmg": 4.2}, "cooldown": 18.0,
			"desc": "Tu frappes dix ennemis l'un après l'autre à la vitesse de l'éclair."},
		"N5": {"id": "omb_maitre", "glyph": "♛", "name": "Maître des ombres", "bonus": {"crit": 0.1, "crit_mult": 0.4}, "desc": "+10 % de coups critiques, +40 % de dégâts critiques."},
		"A10": {"id": "omb_neant", "glyph": "●", "name": "Néant", "active": "vortex", "params": {"radius": 9.0, "dmg": 5.2}, "cooldown": 28.0,
			"desc": "Un trou noir de 9 mètres aspire et broie les ennemis."},
		"N6": {"id": "omb_insaisissable", "glyph": "≈", "name": "Insaisissable", "bonus": {"dodge": 0.1, "spd_pct": 0.12, "aspd_pct": 0.1}, "desc": "Esquive parfaite très facile, +12 % de vitesse, +10 % de vitesse d'attaque."},
		"M": {"id": "omb_myth", "glyph": "◉", "name": "Nuit sans fin", "active": "storm", "params": {"radius": 18.0, "dmg": 10.0, "count": 30, "fx": "shadow", "fear": 4.0}, "cooldown": 60.0,
			"desc": "MYSTIQUE : la nuit tombe d'un coup. Trente lames d'ombre transpercent tout à 18 mètres, et les survivants fuient, terrorisés."},
	},
}
## Tout au bout de la branche Terre, au niveau 990 : la compétence ultime.
const CATACLYSM := {"id": "cataclysme", "branch": "terre", "glyph": "☢", "name": "Cataclysme", "kind": "active", "rarity": "mystique", "ultimate": true,
	"active": "crater", "params": {"radius": 26.0, "dmg": 40.0, "depth": 9.0}, "cooldown": 150.0, "cost": 30, "level": 990,
	"desc": "ULTIME (niveau 990) : tu frappes le monde lui-même. Tout explose à 26 mètres à la ronde, le sol se creuse en un cratère géant, arbres et ruines volent en éclats, et les ennemis pris dedans subissent des dégâts colossaux."}

## Compétences uniques de l'histoire (branche Pacte, débloquées par l'histoire principale).
const PACTE := [
	{"id": "pac_voix", "branch": "pacte", "row": 0, "col": 0, "glyph": "✺", "name": "Voix d'Outre-Monde", "kind": "passive", "story": true,
		"bonus": {"xp": 0.15, "loot": 0.1}, "desc": "Ton âme venue d'ailleurs apprend plus vite : +15 % d'expérience, +10 % de butin. (Pacte avec Orvane)"},
	{"id": "pac_estomac", "branch": "pacte", "row": 0, "col": 1, "glyph": "◉", "name": "Estomac sans fond", "kind": "passive", "story": true,
		"bonus": {"absorb": 0.1, "kill_heal": 4.0}, "desc": "Comme Glou, tu dévores la force des vaincus : 10 % de chances d'absorber de la force, +4 vie par ennemi vaincu. (Glou)"},
	{"id": "pac_hurlement", "branch": "pacte", "row": 0, "col": 2, "glyph": "☾", "name": "Hurlement de la Meute", "kind": "active", "story": true,
		"active": "fear", "params": {"radius": 7.0, "dur": 3.5, "dmg": 0.8}, "cooldown": 16.0,
		"desc": "Un hurlement de loup blesse et terrifie les ennemis autour de toi. (Ulric)"},
	{"id": "pac_oeil_fees", "branch": "pacte", "row": 1, "col": 0, "glyph": "✧", "name": "Œil des Fées", "kind": "passive", "story": true,
		"bonus": {"crit": 0.07, "dodge": 0.05, "crit_mult": 0.2}, "desc": "Tu vois les failles : +7 % de coups critiques, +20 % de dégâts critiques, esquive plus facile. (Liora)"},
	{"id": "pac_ruee", "branch": "pacte", "row": 1, "col": 1, "glyph": "➹", "name": "Ruée écarlate", "kind": "active", "story": true,
		"active": "dash", "params": {"dist": 8.0, "dmg": 2.0, "burn": 0.6}, "cooldown": 9.0,
		"desc": "L'art des Cornes-Rouges : tu traverses les ennemis dans une traînée de feu. (Kaede)"},
	{"id": "pac_acier", "branch": "pacte", "row": 1, "col": 2, "glyph": "⬢", "name": "Peau d'acier", "kind": "passive", "story": true,
		"bonus": {"def_flat": 6.0, "poise": 0.25, "hp_pct": 0.08}, "desc": "Le serment des nains : +6 défense, +8 % de vie, coups plus lourds. (Borin)"},
	{"id": "pac_carapace", "branch": "pacte", "row": 2, "col": 0, "glyph": "⬡", "name": "Carapace de la Ruche", "kind": "active", "story": true,
		"active": "barrier", "params": {"dur": 6.0, "reduce": 0.6, "reflect": 1}, "cooldown": 20.0,
		"desc": "Une carapace de chitine absorbe 60 % des dégâts et renvoie les coups. (Zzar)"},
	{"id": "pac_evolution", "branch": "pacte", "row": 2, "col": 1, "glyph": "⇮", "name": "Lien d'évolution", "kind": "passive", "story": true,
		"bonus": {"atk_pct": 0.1, "mag_pct": 0.1, "hp_pct": 0.1}, "desc": "Tes pactes font évoluer tes alliés, et toi avec eux : +10 % d'attaque, de magie et de vie. (Pip)"},
	{"id": "pac_racines", "branch": "pacte", "row": 2, "col": 2, "glyph": "❦", "name": "Pacte des Racines", "kind": "active", "story": true,
		"active": "heal", "params": {"pct": 0.45, "allies": 1}, "cooldown": 22.0,
		"desc": "Les racines du monde te soignent de 45 %, toi et tes alliés proches. (Sylve)"},
	{"id": "pac_brume", "branch": "pacte", "row": 3, "col": 0, "glyph": "♆", "name": "Brume inversée", "kind": "active", "story": true,
		"active": "drain", "params": {"radius": 5.5, "dmg": 1.8, "ratio": 0.6}, "cooldown": 14.0,
		"desc": "Tu retournes la Brume contre tes ennemis : elle aspire leur vie pour te la rendre. (Séléné)"},
	{"id": "pac_souffle", "branch": "pacte", "row": 3, "col": 1, "glyph": "☄", "name": "Souffle du dragon", "kind": "active", "story": true,
		"active": "cone", "params": {"range": 8.0, "dmg": 2.4, "kb": 12, "angle": 80, "burn": 0.8}, "cooldown": 12.0,
		"desc": "Un torrent de flammes draconiques embrase tout devant toi. (Vharok)"},
	{"id": "pac_seraphin", "branch": "pacte", "row": 3, "col": 2, "glyph": "✚", "name": "Ailes du Séraphin", "kind": "passive", "story": true,
		"bonus": {"last_stand": 1.0, "regen": 2.5}, "desc": "Tu refuses de tomber (survit à un coup mortel toutes les 60 s), +2,5 vie par seconde. (Aurèle)"},
	{"id": "pac_chaines", "branch": "pacte", "row": 4, "col": 0, "glyph": "⛓", "name": "Chaînes brisées", "kind": "active", "story": true,
		"active": "vortex", "params": {"radius": 7.0, "dmg": 2.6}, "cooldown": 24.0,
		"desc": "Les chaînes d'Orvane, brisées, deviennent tiennes : elles attirent et broient les ennemis. (Orvane libéré)"},
	{"id": "pac_eveil", "branch": "pacte", "row": 4, "col": 1, "glyph": "☀", "name": "Éveil", "kind": "active", "story": true,
		"active": "meteor", "params": {"radius": 3.6, "dmg": 3.0, "count": 6, "burn": 0.6}, "cooldown": 30.0,
		"desc": "Ultime : la lumière du Cœur d'Aube s'abat du ciel sur tous tes ennemis. (Caël)"},
	{"id": "pac_roi", "branch": "pacte", "row": 4, "col": 2, "glyph": "♛", "name": "Roi des Pactes", "kind": "passive", "story": true,
		"bonus": {"atk_pct": 0.15, "mag_pct": 0.15, "def_flat": 5.0, "cdr_pct": 0.15, "spd_pct": 0.08},
		"desc": "Tous les peuples te prêtent leur force : +15 % d'attaque et de magie, +5 défense, recharges -15 %, +8 % de vitesse. (Fondation de la nation)"},]

## Talents offerts au départ selon la classe (ils ne coûtent pas de point).
const CLASS_START := {"guerrier": "lame_force", "barbare": "lame_force", "paladin": "sac_foi",
	"mage": "arc_affinite", "rodeur": "omb_reflexes", "assassin": "omb_reflexes", "moine": "fou_etincelle",
	"necromancien": "san_soif", "druide": "ter_racine", "chevalier": "ter_racine", "barde": "fou_etincelle",
	"clerc": "sac_foi", "cryomancien": "giv_froid"}

## Tous les nœuds (générés au premier appel) : id, branch, name, glyph, kind, rarity, level, cost, requires,
## pos (position dans l'arbre), bonus | active + params + cooldown, desc. Les nœuds Pacte gardent row / col.
static var NODES: Array = []
static var _by_id := {}


static func _ensure() -> void:
	if not NODES.is_empty():
		return
	_build()


static func nodes() -> Array:
	_ensure()
	return NODES


static func node(id: String) -> Dictionary:
	_ensure()
	return _by_id.get(id, {})


static func branch(id: String) -> Dictionary:
	for b in BRANCHES:
		if b.id == id:
			return b
	return {}


static func _dir(angle_deg: float) -> Vector2:
	var a := deg_to_rad(angle_deg)
	return Vector2(sin(a), -cos(a))


## Position (pixels de l'arbre, centre = 0) d'une case de branche.
static func slot_pos(angle_deg: float, ring: int, lane: int) -> Vector2:
	var d := _dir(angle_deg)
	var perp := Vector2(-d.y, d.x)
	return d * (R0 + (ring - 1) * RING_STEP) + perp * lane * LANE_W


static func _bonus_text(bonus: Dictionary) -> String:
	var parts := []
	for k in bonus:
		var lab: Array = SkillData.PASSIVE_LABELS.get(k, [k, "flat"])
		var v := float(bonus[k])
		match lab[1]:
			"pct", "chance":
				parts.append("+%s %% %s" % [_num(v * 100.0), lab[0].to_lower()])
			"pct_minus":
				parts.append("%s -%s %%" % [lab[0], _num(v * 100.0)])
			"regen":
				parts.append("+%s vie par seconde" % _num(v))
			_:
				if k == "def_flat":
					parts.append("+%s défense" % _num(v))
				elif k == "kill_heal":
					parts.append("+%s vie par ennemi vaincu" % _num(v))
				else:
					parts.append("%s +%s" % [lab[0], _num(v)])
	return ", ".join(parts) + "."


static func _num(v: float) -> String:
	return str(roundi(v)) if absf(v - roundf(v)) < 0.05 else ("%.1f" % v).replace(".", ",")


static func _add(n: Dictionary) -> void:
	NODES.append(n)
	_by_id[n.id] = n


static func _build() -> void:
	NODES = []
	_by_id = {}
	var grid := {}       # "branche:anneau:voie" -> id
	for b in BRANCHES:
		if b.get("story", false):
			continue
		var content: Dictionary = CONTENT[b.id]
		for ri in SHAPE.size():
			var ring := ri + 1
			for li in 3:
				var key: String = SHAPE[ri][li]
				if key == "":
					continue
				var lane := li - 1
				var n: Dictionary
				if key == "S":
					var mult := 1.0 + (ring - 1) * 0.15
					var bonus := {}
					var stats: Dictionary = b.stats
					# chaque rune ne donne qu'un ou deux des bonus de la branche (en alternance)
					var keys := stats.keys()
					var k1: String = keys[(ring + li) % keys.size()]
					bonus[k1] = snappedf(float(stats[k1]) * mult, 0.001)
					if ring >= 9:
						var k2: String = keys[(ring + li + 1) % keys.size()]
						bonus[k2] = snappedf(float(stats[k2]) * mult * 0.6, 0.001)
					n = {"id": "%s_r%d_%d" % [b.id, ring, li], "glyph": "•", "name": b.rune, "kind": "passive", "rune": true,
						"rarity": "commune" if ring <= 6 else ("rare" if ring <= 11 else "epique"), "cost": 1 if ring <= 11 else 2,
						"bonus": bonus, "desc": _bonus_text(bonus)}
				else:
					n = (content[key] as Dictionary).duplicate(true)
					n["rarity"] = SHAPE_RARITY[key]
					if not n.has("kind"):
						n["kind"] = "active" if n.has("active") else "passive"
					n["cost"] = RARITIES[n.rarity].cost if n.kind == "active" or key.begins_with("N") else 1
					if key == "P":
						n["cost"] = 1
					if n.kind == "passive" and not n.has("desc"):
						n["desc"] = _bonus_text(n.bonus)
				n["branch"] = b.id
				n["ring"] = ring
				n["lane"] = lane
				n["level"] = RING_LEVEL[ring]
				n["pos"] = slot_pos(b.angle, ring, lane)
				_add(n)
				grid["%s:%d:%d" % [b.id, ring, lane]] = n.id
	# ponts entre deux branches voisines
	var bridges := {}    # "branche:anneau:côté" -> id du pont (côté +1 : vers la branche suivante)
	for i in COMBAT_BRANCHES.size():
		var a: Dictionary = branch(COMBAT_BRANCHES[i])
		var c: Dictionary = branch(COMBAT_BRANCHES[(i + 1) % COMBAT_BRANCHES.size()])
		for bi in BRIDGE_RINGS.size():
			var ring: int = BRIDGE_RINGS[bi]
			var rar: String = ["rare", "epique", "legendaire"][bi]
			var bonus := {}
			var ka: String = a.stats.keys()[0]
			var kc: String = c.stats.keys()[0]
			bonus[ka] = snappedf(float(a.stats[ka]) * (2.0 + bi * 1.5), 0.001)
			bonus[kc] = float(bonus.get(kc, 0.0)) + snappedf(float(c.stats[kc]) * (2.0 + bi * 1.5), 0.001)
			var mid := (slot_pos(a.angle, ring, 1) + slot_pos(c.angle if c.angle > a.angle else c.angle + 360.0, ring, -1)) / 2.0
			var n := {"id": "pont_%s_%s_%d" % [a.id, c.id, ring], "glyph": "⬗", "name": "Voie %s-%s" % [a.name, c.name],
				"kind": "passive", "bridge": [a.id, c.id], "rarity": rar, "cost": RARITIES[rar].cost, "branch": a.id,
				"ring": ring, "lane": 2, "level": RING_LEVEL[ring], "pos": mid, "bonus": bonus,
				"desc": "Un pont entre la %s et la %s : %s" % [a.name, c.name, _bonus_text(bonus)]}
			_add(n)
			bridges["%s:%d:1" % [a.id, ring]] = n.id
			bridges["%s:%d:-1" % [c.id, ring]] = n.id
	# le Cataclysme, tout au bout de la branche Terre
	var cat := CATACLYSM.duplicate(true)
	cat["ring"] = 18
	cat["lane"] = 0
	cat["pos"] = slot_pos(branch("terre").angle, 18, 0)
	_add(cat)
	grid["terre:18:0"] = cat.id
	# liens : chaque nœud demande un voisin de l'anneau précédent (même branche, voie voisine) ou un pont
	for n in NODES:
		if n.has("requires") or n.get("story", false):
			continue
		var req := []
		if n.has("bridge"):
			for side in [[n.bridge[0], 1], [n.bridge[1], -1]]:
				var id = grid.get("%s:%d:%d" % [side[0], n.ring, side[1]])
				if id:
					req.append(id)
		elif n.id == "cataclysme":
			req = [grid["terre:16:0"]]
		elif n.ring > 1:
			# tout droit vers le centre ; on change de voie tous les trois anneaux (ou s'il n'y a rien tout droit)
			var straight = grid.get("%s:%d:%d" % [n.branch, n.ring - 1, n.lane])
			if straight:
				req.append(straight)
			if straight == null or n.ring % 3 == 0:
				for dl in [-1, 1]:
					var id = grid.get("%s:%d:%d" % [n.branch, n.ring - 1, n.lane + dl])
					if id:
						req.append(id)
			var br = bridges.get("%s:%d:%d" % [n.branch, n.ring - 1, n.lane])
			if br and n.lane != 0:
				req.append(br)
		n["requires"] = req
	# les compétences uniques de l'histoire (branche Pacte)
	for n in PACTE:
		var m: Dictionary = n.duplicate(true)
		m["rarity"] = "legendaire"
		m["level"] = 1
		_add(m)


static func cost(id: String) -> int:
	# les compétences de l'histoire ne coûtent pas de points
	if node(id).get("story", false):
		return 0
	return int(node(id).get("cost", 1))


static func is_story(id: String) -> bool:
	return node(id).get("story", false)


static func level_of(id: String) -> int:
	return int(node(id).get("level", 1))


static func rarity(id: String) -> Dictionary:
	return RARITIES.get(node(id).get("rarity", "commune"), RARITIES.commune)


## Points de compétence gagnés en passant au niveau `lv` : 2 jusqu'au niveau 50, puis 1.
static func points_for_level(lv: int) -> int:
	return 2 if lv <= 50 else 1


## Points gagnés du niveau 1 au niveau `lv`.
static func points_until(lv: int) -> int:
	return (mini(lv, 50) - 1) * 2 + maxi(0, lv - 50)


## Somme des bonus des talents passifs débloqués.
static func passive_bonus(unlocked: Dictionary) -> Dictionary:
	var out := {}
	for id in unlocked:
		var n := node(id)
		if n.get("kind") == "passive":
			for k in n.bonus:
				out[k] = float(out.get(k, 0.0)) + float(n.bonus[k])
	return out


## Compétence (SkillData) d'un talent actif, lancée par une HeroSkill comme la compétence unique.
static func make_skill(id: String) -> SkillData:
	var n := node(id)
	var s := SkillData.new()
	s.id = id
	s.tier_names = PackedStringArray([n.name, n.name, n.name])
	s.color = branch(n.branch).color.lightened(0.15)
	s.active = n.active
	s.active_params = n.params
	s.cooldown = n.cooldown
	s.description = n.desc
	s.category = n.get("rarity", "commune")
	return s
