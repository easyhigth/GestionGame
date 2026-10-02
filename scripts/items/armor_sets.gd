class_name ArmorSets
extends RefCounted
## Panoplies d'armures : chaque matériau de l'arsenal (cuivre, bronze, os, acier, argent, or, obsidienne,
## mithril, orichalque, écailles de dragon) a son casque, son heaume, son plastron, ses gantelets, ses jambières
## et son bouclier (Armurier) ; le cuir se teint en 8 couleurs (Tailleur). Les modèles sont ceux des pièces en
## fer ou en cuir, teints de la couleur du matériau (ItemData.tint).
## Identifiant : « pan_<pièce>_<matériau> » (ex. pan_plastron_acier).

## Pièces de métal : identifiant, nom, nom pluriel ?, modèle, défense (au fer), attaque, lingots, vitesse.
const METAL_PIECES := [
	["casque", "Casque", false, "iron_helmet", 4, 0, 3, 0.0],
	["heaume", "Heaume à cornes", false, "horned_helmet", 5, 1, 4, 0.0],
	["plastron", "Plastron", false, "iron_armor", 8, 0, 6, -0.06],
	["gantelets", "Gantelets", true, "iron_gauntlets", 2, 1, 2, 0.0],
	["jambieres", "Jambières", true, "iron_greaves", 4, 0, 4, -0.03],
	["bouclier", "Bouclier", false, "shield_iron", 7, 0, 4, -0.03],
]
const METALS := ["cuivre", "bronze", "os", "acier", "argent", "or", "obsidienne", "mithril", "orichalque", "draconique"]
## Défense par matériau (fer = 1) et magie.
const DEF_MULT := {"cuivre": 0.8, "bronze": 0.92, "os": 0.7, "acier": 1.4, "argent": 1.25, "or": 1.15, "obsidienne": 1.9,
	"mithril": 3.0, "orichalque": 4.0, "draconique": 5.0}
const MAGIC := {"argent": 2, "or": 3, "mithril": 2, "orichalque": 3, "obsidienne": 1}
## Pièces de cuir : identifiant, nom, modèle, défense, cuir, vitesse.
const LEATHER_PIECES := [
	["capuche", "Capuche de cuir", "leather_cap", 1, 2, 0.0], ["veste", "Armure de cuir", "leather_armor", 3, 5, 0.0],
	["brassards", "Brassards de cuir", "leather_bracers", 1, 2, 0.0], ["pantalon", "Pantalon de cuir", "leather_pants", 2, 3, 0.03],
]
const LEATHER_COLORS := ["rouge", "bleu", "vert", "noir", "blanc", "violet", "jaune", "cyan"]


static func register(db: Node) -> void:
	for mid in METALS:
		var m := Arsenal.material(mid)
		for pc in METAL_PIECES:
			var model: ItemData = db.items.get(pc[3])
			if model == null:
				continue
			var it := ItemData.new()
			it.id = "pan_%s_%s" % [pc[0], mid]
			var suffix: String = m.suffix
			if mid == "draconique" and pc[2]:
				suffix = "draconiques"
			it.display_name = "%s %s" % [pc[1], suffix]
			it.slot = model.slot
			it.model_ref = pc[3]
			it.tint = Color(m.main)
			it.set_meta("ornament", mid)
			it.defense = maxi(1, roundi(float(pc[4]) * float(DEF_MULT[mid])))
			it.attack = int(pc[5]) * (1 + int(DEF_MULT[mid]))
			it.magic = int(MAGIC.get(mid, 0))
			it.speed_bonus = float(pc[7])
			it.rarity = int(m.rarity) as ItemData.Rarity
			it.max_stack = 1
			it.description = "%s de la panoplie %s. Armurier niveau %d." % [pc[1], suffix, int(m.level)]
			db.items[it.id] = it
			var n := int(pc[6])
			if m.get("rare", false):
				n = maxi(1, ceili(n / 2.0))
			var ings := [[m.res, n], ["leather", 1]]
			_recipe(db, it, ings, "enclume", mid, "armurier", int(m.level))
	for col in LEATHER_COLORS:
		var dye: String = "teinture_" + col
		var tint := Color(_dye_color(col))
		for pc in LEATHER_PIECES:
			var model: ItemData = db.items.get(pc[2])
			if model == null:
				continue
			var it := ItemData.new()
			it.id = "pan_%s_cuir_%s" % [pc[0], col]
			it.display_name = "%s %s" % [pc[1], col]
			it.slot = model.slot
			it.model_ref = pc[2]
			it.tint = tint
			it.defense = int(pc[3]) + 1
			it.speed_bonus = float(pc[5])
			it.rarity = ItemData.Rarity.COMMON
			it.max_stack = 1
			it.description = "Cuir teint en %s, cousu par un tailleur." % col
			db.items[it.id] = it
			_recipe(db, it, [["leather", int(pc[4])], [dye, 1]], "", "cuir", "tailleur", 8)


static func _dye_color(col: String) -> String:
	for c in BlockCatalog.COLORS:
		if c[0] == col:
			return c[3]
	return "ffffff"


static func _recipe(db: Node, it: ItemData, ings: Array, station: String, family: String, craft: String, level: int) -> void:
	var r := RecipeData.new()
	r.result = it
	var ing: Array[ItemData] = []
	var am := PackedInt32Array()
	for pr in ings:
		var x: ItemData = db.items.get(pr[0])
		if x == null:
			return
		ing.append(x)
		am.append(int(pr[1]))
	r.ingredients = ing
	r.amounts = am
	r.station = station
	r.category = "Armures"
	r.set_meta("family", family)
	r.set_meta("craft", craft)
	r.set_meta("level", level)
	db.recipes.append(r)


## Familles de l'onglet « Armures » : les matériaux, puis le cuir.
static func families() -> Array:
	var out := METALS.duplicate()
	out.append("cuir")
	return out


static func count(db: Node) -> int:
	var n := 0
	for id in db.items:
		if str(id).begins_with("pan_"):
			n += 1
	return n
