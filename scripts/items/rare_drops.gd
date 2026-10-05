class_name RareDrops
extends RefCounted
## Ressources ultra-rares : ce que les monstres, les boss et les trésors lâchent (très) rarement.
## Elles servent à forger l'équipement légendaire (catégorie « Légendaire » de l'artisanat) :
## mithril (lingots au four), écailles de dragon, larmes d'esprit, sang de démon, fragments de Brume,
## cristaux d'aube et orichalque.

## Monstres : identifiant (nom du fichier) -> [[objet, chance], ...]
const ENEMY := {
	"esprit_follet": [["larme_esprit", 0.03]], "fee_sauvage": [["larme_esprit", 0.04]],
	"dryade_corrompue": [["larme_esprit", 0.05]], "harpie": [["larme_esprit", 0.015]],
	"salamandre": [["ecaille_dragon", 0.025]], "slime_magma": [["ecaille_dragon", 0.015]],
	"demon": [["sang_demon", 0.04], ["fragment_brume", 0.03]], "seigneur_demon": [["sang_demon", 0.25], ["fragment_brume", 0.15]],
	"squelette": [["fragment_brume", 0.02], ["os", 0.6]], "seigneur_squelette": [["fragment_brume", 0.2], ["mithril_brut", 0.1], ["os", 1.0]],
	"loup": [["os", 0.3]], "loup_givre": [["os", 0.3]], "ours_neige": [["os", 0.4]], "sanglier": [["os", 0.3]],
	"ogre": [["mithril_brut", 0.05]], "orc_brute": [["mithril_brut", 0.02]], "loup_alpha": [["mithril_brut", 0.02]],
	"grenouille": [["larme_esprit", 0.03]], "serpent": [["ecaille_dragon", 0.02]], "panthere": [["mithril_brut", 0.02]],
	"serpent_roi": [["ecaille_dragon", 0.15], ["gemme_emeraude", 0.1]],
	"yeti": [["os", 0.4], ["mithril_brut", 0.02]], "mammouth": [["os", 0.6]], "elementaire_glace": [["larme_esprit", 0.03]],
}
## Tous les boss : [objet, chance, minimum, maximum].
const BOSS := [["mithril_brut", 0.7, 2, 3], ["fragment_brume", 0.4, 1, 2], ["orichalque", 0.06, 1, 1],
	["poussiere_arcane", 1.0, 3, 6], ["pierre_ame", 0.5, 1, 1]]
## Tous les monstres : poussière arcanique (pour les enchantements).
const ANY := [["poussiere_arcane", 0.06]]
## Boss particuliers.
const BOSS_EXTRA := {
	"boss_seigneur_ignarok": [["ecaille_dragon", 1.0, 3, 5], ["sang_demon", 0.5, 1, 2]],
	"boss_dryade_mere": [["larme_esprit", 1.0, 2, 3]], "boss_slime_primordial": [["larme_esprit", 0.5, 1, 2]],
	"boss_ogre_roi": [["mithril_brut", 1.0, 2, 3]], "boss_scorpion_empereur": [["ecaille_dragon", 0.5, 1, 2]],
	"seigneur_brume": [["orichalque", 1.0, 2, 2], ["cristal_aube", 1.0, 3, 3]],
	"morvain_parjure": [["fragment_brume", 1.0, 3, 4], ["sang_demon", 0.6, 1, 2]],
	"ren_possede": [["ecaille_dragon", 0.5, 1, 2], ["fragment_brume", 1.0, 2, 3]],
	"aurele_epreuve": [["larme_esprit", 1.0, 3, 3], ["cristal_aube", 1.0, 1, 1]],
	"boss_quetzal": [["cristal_aube", 1.0, 1, 1], ["gemme_emeraude", 1.0, 2, 3], ["ecaille_dragon", 0.5, 1, 2]],
}
## Gemmes (serties à l'enclume, voir Forge) : une au hasard, avec cette chance.
const GEM_IDS := ["gemme_rubis", "gemme_saphir", "gemme_emeraude", "gemme_topaze", "gemme_amethyste", "gemme_diamant"]
const GEM_CHANCE := {"boss": 0.45, "ile": 0.3, "grotte": 0.15, "donjon_boss": 0.4}

## Coffres : sorte -> [objet, chance, minimum, maximum].
const CHESTS := {
	"ile": [["orichalque", 0.08, 1, 1], ["mithril_brut", 0.3, 1, 2], ["ecaille_dragon", 0.12, 1, 1]],
	"grotte": [["mithril_brut", 0.15, 1, 1], ["larme_esprit", 0.1, 1, 1]],
	"donjon_boss": [["mithril_brut", 0.5, 1, 2], ["orichalque", 0.08, 1, 1], ["sang_demon", 0.15, 1, 1], ["poussiere_arcane", 1.0, 2, 4], ["pierre_ame", 0.3, 1, 1]],
}


## La base des objets (autoload « Items »), cherchée à l'exécution.
static func _item(id: String) -> ItemData:
	var db := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Items")
	return db.get_item(id) if db else null


## Butin rare d'un monstre (ou d'un boss) : [[ItemData, nombre], ...].
static func roll_enemy(e: Enemy, mult := 1.0) -> Array:
	var out := []
	if e.data == null:
		return out
	var id := e.data.resource_path.get_file().get_basename()
	for pair in ENEMY.get(id, []) + ANY:
		if randf() < float(pair[1]) * mult:
			out.append([_item(pair[0]), 1])
	var table: Array = []
	if e is Boss:
		table.append_array(BOSS)
	table.append_array(BOSS_EXTRA.get(id, []))
	for r in table:
		if randf() < minf(1.0, float(r[1]) * mult):
			out.append([_item(r[0]), randi_range(int(r[2]), int(r[3]))])
	if e is Boss and randf() < GEM_CHANCE.boss * mult:
		out.append([_item(GEM_IDS.pick_random()), 1])
	return out.filter(func(x): return x[0] != null)


## Pièce d'équipement lâchée par un monstre vaincu (butin de niveau, voir Loot) : c'est la principale façon
## d'en trouver, l'équipement posé au sol étant devenu très rare. Chance selon la robustesse du monstre
## (5 % pour les plus faibles, 14 % au plus) ; un boss en lâche toujours une, au moins rare.
const GEAR_CHANCE_MIN := 0.05
const GEAR_CHANCE_MAX := 0.14
const GEAR_BOSS_LUCK := 0.25


static func gear_chance(e: Enemy) -> float:
	if e.data == null:
		return 0.0
	if e is Boss:
		return 1.0
	return clampf(GEAR_CHANCE_MIN + e.data.max_health / 4000.0, GEAR_CHANCE_MIN, GEAR_CHANCE_MAX)


## [ItemData] ou null. Les monstres des failles et les titans ont leur propre butin (Endgame).
static func roll_gear(e: Enemy, mult := 1.0) -> ItemData:
	if e.data == null or e.has_meta("rift") or e.has_meta("titan"):
		return null
	if randf() >= minf(1.0, gear_chance(e) * mult):
		return null
	var boss := e is Boss
	return Loot.roll(maxi(1, e.level), GEAR_BOSS_LUCK if boss else 0.0, 0, ItemData.Rarity.RARE if boss else 0)


## Butin rare d'un coffre.
static func roll_chest(kind: String) -> Array:
	var out := []
	for r in CHESTS.get(kind, []):
		if randf() < float(r[1]):
			out.append([_item(r[0]), randi_range(int(r[2]), int(r[3]))])
	if randf() < float(GEM_CHANCE.get(kind, 0.0)):
		out.append([_item(GEM_IDS.pick_random()), 1])
	return out.filter(func(x): return x[0] != null)


## Annonce une trouvaille rare au héros.
static func announce(p: Player, items: Array) -> void:
	if p == null:
		return
	for pair in items:
		var it: ItemData = pair[0]
		if it.rarity >= ItemData.Rarity.EPIC:
			p.feat.emit("Ressource ultra-rare : %s !" % it.display_name, it.rarity_color())
			p.get_tree().root.get_node("Sound").ui("levelup")
