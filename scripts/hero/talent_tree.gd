class_name TalentTree
extends RefCounted
## Arbre de talents du héros : trois branches (Lame, Arcanes, Ombre) de cinq rangs.
## Chaque niveau gagné donne 1 point (et chaque âme de boss absorbée 1 de plus).
## Un talent se débloque avec ses points si le héros a le niveau du rang et un talent
## précédent de la même branche relié à lui.
##   - talents passifs : bonus permanents (mêmes clés que les compétences uniques : atk_pct, crit...)
##   - talents actifs : nouvelles attaques et nouveaux sorts, placés dans les emplacements 1 à 4
##     (touches 1-4 ; manette : croix droite pour choisir, clic du joystick droit pour lancer).
## Pour ajouter un talent : une ligne dans NODES (id unique, branche, rang, colonne, prérequis...).

const BRANCHES := [
	{"id": "lame", "name": "Lame", "desc": "Attaques au corps à corps, charges et tourbillons.", "color": Color("e8703a")},
	{"id": "arcanes", "name": "Arcanes", "desc": "Sorts de feu, de foudre et de givre, protections et soins.", "color": Color("6a8aff")},
	{"id": "ombre", "name": "Ombre", "desc": "Agilité, survie, poisons et frénésie.", "color": Color("5ac870")},
]
## Niveau du héros requis pour chaque rang.
const ROW_LEVEL := [1, 3, 6, 10, 14]
const SLOTS := 4

## kind "passive" : `bonus` (clés de compétence) ; "active" : `active` + `params` + `cooldown` (secondes).
## `requires` : au moins un de ces talents doit être débloqué.
const NODES := [
	# ---------------- Lame
	{"id": "lame_force", "branch": "lame", "row": 0, "col": 1, "glyph": "⚔", "name": "Force brute", "kind": "passive",
		"bonus": {"atk_pct": 0.08}, "desc": "+8 % d'attaque."},
	{"id": "lame_tourbillon", "branch": "lame", "row": 1, "col": 0, "glyph": "◎", "name": "Tourbillon", "kind": "active",
		"requires": ["lame_force"], "active": "move", "params": {"move": "spin", "dmg": 1.5}, "cooldown": 6.0,
		"desc": "Tu tournoies sur toi-même en frappant tout autour de toi."},
	{"id": "lame_vitesse", "branch": "lame", "row": 1, "col": 2, "glyph": "»", "name": "Enchaînement", "kind": "passive",
		"requires": ["lame_force"], "bonus": {"aspd_pct": 0.12}, "desc": "+12 % de vitesse d'attaque."},
	{"id": "lame_charge", "branch": "lame", "row": 2, "col": 0, "glyph": "➹", "name": "Charge du taureau", "kind": "active",
		"requires": ["lame_tourbillon"], "active": "dash", "params": {"dist": 7.0, "dmg": 1.6}, "cooldown": 8.0,
		"desc": "Tu fonces droit devant et renverses tout sur ton passage."},
	{"id": "lame_crit", "branch": "lame", "row": 2, "col": 1, "glyph": "✦", "name": "Œil du bourreau", "kind": "passive",
		"requires": ["lame_tourbillon", "lame_vitesse"], "bonus": {"crit": 0.08, "crit_mult": 0.25}, "desc": "+8 % de coups critiques, +25 % de dégâts critiques."},
	{"id": "lame_seisme", "branch": "lame", "row": 2, "col": 2, "glyph": "▼", "name": "Frappe sismique", "kind": "active",
		"requires": ["lame_vitesse"], "active": "stun", "params": {"radius": 3.8, "dmg": 1.3, "dur": 1.6}, "cooldown": 11.0,
		"desc": "Tu frappes le sol : les ennemis proches sont blessés et étourdis."},
	{"id": "lame_execute", "branch": "lame", "row": 3, "col": 0, "glyph": "☠", "name": "Exécution", "kind": "passive",
		"requires": ["lame_charge", "lame_crit"], "bonus": {"execute": 0.5}, "desc": "+50 % de dégâts contre les ennemis sous 30 % de vie."},
	{"id": "lame_onde", "branch": "lame", "row": 3, "col": 2, "glyph": "≋", "name": "Onde tranchante", "kind": "active",
		"requires": ["lame_seisme", "lame_crit"], "active": "cone", "params": {"range": 6.5, "dmg": 1.7, "kb": 10, "angle": 70}, "cooldown": 9.0,
		"desc": "Une lame d'énergie part devant toi et repousse les ennemis."},
	{"id": "lame_tempete", "branch": "lame", "row": 4, "col": 1, "glyph": "✺", "name": "Tempête de lames", "kind": "active", "cost": 2,
		"requires": ["lame_execute", "lame_onde"], "active": "vortex", "params": {"radius": 6.5, "dmg": 2.6}, "cooldown": 30.0,
		"desc": "Ultime : un tourbillon de lames aspire les ennemis puis explose."},
	# ---------------- Arcanes
	{"id": "arc_affinite", "branch": "arcanes", "row": 0, "col": 1, "glyph": "✧", "name": "Affinité arcanique", "kind": "passive",
		"bonus": {"mag_pct": 0.12}, "desc": "+12 % de magie."},
	{"id": "arc_feu", "branch": "arcanes", "row": 1, "col": 0, "glyph": "☄", "name": "Boule de feu", "kind": "active",
		"requires": ["arc_affinite"], "active": "volley", "params": {"count": 1, "dmg": 1.8, "burn": 0.7}, "cooldown": 4.0,
		"desc": "Lance une boule de feu qui enflamme sa cible."},
	{"id": "arc_savoir", "branch": "arcanes", "row": 1, "col": 2, "glyph": "◷", "name": "Concentration", "kind": "passive",
		"requires": ["arc_affinite"], "bonus": {"cdr_pct": 0.12}, "desc": "Toutes les recharges sont 12 % plus rapides."},
	{"id": "arc_eclair", "branch": "arcanes", "row": 2, "col": 0, "glyph": "ϟ", "name": "Éclair en chaîne", "kind": "active",
		"requires": ["arc_feu"], "active": "chain", "params": {"count": 4, "dmg": 1.4, "stun": 0.35}, "cooldown": 7.0,
		"desc": "La foudre frappe l'ennemi le plus proche puis rebondit sur 3 autres."},
	{"id": "arc_givre", "branch": "arcanes", "row": 2, "col": 1, "glyph": "❄", "name": "Nova de givre", "kind": "active",
		"requires": ["arc_feu", "arc_savoir"], "active": "nova", "params": {"radius": 4.2, "dmg": 1.0, "slow": 1.0}, "cooldown": 10.0,
		"desc": "Une explosion de glace blesse et ralentit tous les ennemis autour de toi."},
	{"id": "arc_bouclier", "branch": "arcanes", "row": 2, "col": 2, "glyph": "⬡", "name": "Bouclier arcanique", "kind": "active",
		"requires": ["arc_savoir"], "active": "barrier", "params": {"dur": 5.0, "reduce": 0.6}, "cooldown": 18.0,
		"desc": "Une barrière absorbe 60 % des dégâts pendant 5 secondes."},
	{"id": "arc_soin", "branch": "arcanes", "row": 3, "col": 0, "glyph": "✚", "name": "Lumière guérisseuse", "kind": "active",
		"requires": ["arc_eclair", "arc_givre"], "active": "heal", "params": {"pct": 0.35, "allies": 1}, "cooldown": 20.0,
		"desc": "Rend 35 % de ta vie, et soigne les compagnons et habitants proches."},
	{"id": "arc_puissance", "branch": "arcanes", "row": 3, "col": 2, "glyph": "✪", "name": "Surcharge", "kind": "passive",
		"requires": ["arc_givre", "arc_bouclier"], "bonus": {"mag_pct": 0.15, "crit": 0.05}, "desc": "+15 % de magie, +5 % de coups critiques."},
	{"id": "arc_meteores", "branch": "arcanes", "row": 4, "col": 1, "glyph": "☀", "name": "Pluie de météores", "kind": "active", "cost": 2,
		"requires": ["arc_soin", "arc_puissance"], "active": "meteor", "params": {"radius": 3.2, "dmg": 2.4, "count": 5, "burn": 0.5}, "cooldown": 32.0,
		"desc": "Ultime : des météores s'écrasent sur les ennemis autour de toi."},
	# ---------------- Ombre
	{"id": "omb_reflexes", "branch": "ombre", "row": 0, "col": 1, "glyph": "↯", "name": "Réflexes", "kind": "passive",
		"bonus": {"dash_cd": 0.3, "dodge": 0.05}, "desc": "Roulade 30 % plus souvent, esquive parfaite plus facile."},
	{"id": "omb_double_saut", "branch": "ombre", "row": 1, "col": 0, "glyph": "⇈", "name": "Double saut", "kind": "passive",
		"requires": ["omb_reflexes"], "bonus": {"double_jump": 1.0}, "desc": "Tu peux sauter une seconde fois en l'air (monte sur 2 blocs)."},
	{"id": "omb_vitalite", "branch": "ombre", "row": 1, "col": 2, "glyph": "♥", "name": "Vitalité", "kind": "passive",
		"requires": ["omb_reflexes"], "bonus": {"hp_pct": 0.15}, "desc": "+15 % de vie maximale."},
	{"id": "omb_pas", "branch": "ombre", "row": 2, "col": 0, "glyph": "◌", "name": "Pas de l'ombre", "kind": "active",
		"requires": ["omb_double_saut"], "active": "blink", "params": {"dist": 7.0, "dmg": 1.2}, "cooldown": 7.0,
		"desc": "Tu te téléportes vers l'avant et blesses ceux qui t'entourent à l'arrivée."},
	{"id": "omb_poison", "branch": "ombre", "row": 2, "col": 1, "glyph": "☣", "name": "Lames empoisonnées", "kind": "active",
		"requires": ["omb_double_saut", "omb_vitalite"], "active": "buff", "params": {"burn": 0.6, "dur": 10.0}, "cooldown": 18.0,
		"desc": "Pendant 10 secondes, tes coups empoisonnent souvent leur cible."},
	{"id": "omb_regen", "branch": "ombre", "row": 2, "col": 2, "glyph": "❦", "name": "Régénération", "kind": "passive",
		"requires": ["omb_vitalite"], "bonus": {"regen": 2.0}, "desc": "+2 points de vie par seconde."},
	{"id": "omb_sang", "branch": "ombre", "row": 3, "col": 0, "glyph": "♆", "name": "Soif de sang", "kind": "passive",
		"requires": ["omb_pas", "omb_poison"], "bonus": {"lifesteal": 0.06, "kill_heal": 5.0}, "desc": "6 % de vol de vie, +5 vie par ennemi vaincu."},
	{"id": "omb_terreur", "branch": "ombre", "row": 3, "col": 2, "glyph": "☾", "name": "Terreur", "kind": "active",
		"requires": ["omb_poison", "omb_regen"], "active": "fear", "params": {"radius": 5.5, "dur": 3.0}, "cooldown": 20.0,
		"desc": "Les ennemis autour de toi s'enfuient, terrorisés."},
	{"id": "omb_frenesie", "branch": "ombre", "row": 4, "col": 1, "glyph": "✹", "name": "Frénésie", "kind": "active", "cost": 2,
		"requires": ["omb_sang", "omb_terreur"], "active": "buff", "params": {"atk": 0.35, "aspd": 0.35, "lifesteal": 0.1, "spd": 0.2, "dur": 10.0}, "cooldown": 40.0,
		"desc": "Ultime : 10 secondes de rage (+35 % d'attaque et de vitesse d'attaque, vol de vie)."},
]

## Talent offert au départ selon la classe (il ne coûte pas de point).
const CLASS_START := {"guerrier": "lame_force", "barbare": "lame_force", "paladin": "lame_force",
	"mage": "arc_affinite", "rodeur": "omb_reflexes", "assassin": "omb_reflexes"}


static var _by_id := {}


static func node(id: String) -> Dictionary:
	if _by_id.is_empty():
		for n in NODES:
			_by_id[n.id] = n
	return _by_id.get(id, {})


static func branch(id: String) -> Dictionary:
	for b in BRANCHES:
		if b.id == id:
			return b
	return {}


static func cost(id: String) -> int:
	return int(node(id).get("cost", 1))


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
	return s
