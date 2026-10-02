class_name Arsenal
extends RefCounted
## L'arsenal : 17 types d'armes × 13 matériaux × 4 designs = 884 armes différentes, forgées à l'enclume
## (bois, os et pierre : à l'établi). Chacune a son modèle 3D en blocs (WeaponModels), ses statistiques
## (type × matériau × design) et sa recette. Elles peuvent ensuite être raffinées et enchantées (Forge).
## Identifiant : « arm_<type>_<matériau>_<design> » (ex. arm_espadon_acier_2).
## Ajoute aussi les nouvelles ressources (minerais, lingots, os, obsidienne, poussière arcanique...).

## Types : nom des 4 designs, attaque et magie (au niveau du fer), portée, vitesse, recul, style, deux mains,
## sort à distance, lingots, autres ingrédients.
const TYPES := {
	"epee": {"names": ["Épée", "Épée large", "Épée dentelée", "Épée royale"], "atk": 8, "reach": 1.85, "speed": 1.0, "kb": 0.5, "style": 0, "ingots": 3, "extra": [["leather", 1]]},
	"espadon": {"names": ["Espadon", "Claymore", "Flamberge", "Espadon du héraut"], "atk": 13, "reach": 2.2, "speed": 0.8, "kb": 2.0, "style": 2, "two": true, "ingots": 5, "extra": [["leather", 2]]},
	"sabre": {"names": ["Sabre", "Sabre de cavalerie", "Cimeterre", "Sabre d'apparat"], "atk": 7, "reach": 1.9, "speed": 1.15, "kb": 0.4, "style": 0, "ingots": 3, "extra": [["leather", 1]]},
	"katana": {"names": ["Katana", "Nodachi", "Wakizashi", "Katana du shogun"], "atk": 9, "reach": 2.0, "speed": 1.2, "kb": 0.4, "style": 0, "ingots": 4, "extra": [["fiber", 2]]},
	"rapiere": {"names": ["Rapière", "Rapière à coquille", "Estoc", "Rapière du duelliste"], "atk": 6, "reach": 2.1, "speed": 1.35, "kb": 0.2, "style": 1, "ingots": 2, "extra": [["leather", 1]], "bonus": {"crit": 0.03}},
	"dague": {"names": ["Dague", "Poignard", "Kriss", "Dague de l'assassin"], "atk": 4, "reach": 1.35, "speed": 1.55, "kb": 0.1, "style": 0, "ingots": 1, "extra": [["leather", 1]], "bonus": {"crit": 0.05}},
	"hache": {"names": ["Hache", "Hache barbue", "Hache à bec", "Hache du chef"], "atk": 10, "reach": 1.8, "speed": 0.85, "kb": 1.5, "style": 0, "ingots": 3, "extra": [["wood", 2]]},
	"hache_bataille": {"names": ["Hache de bataille", "Grande hache", "Hache bipenne", "Hache du seigneur de guerre"], "atk": 15, "reach": 2.1, "speed": 0.7, "kb": 3.0, "style": 2, "two": true, "ingots": 5, "extra": [["wood", 3]]},
	"marteau": {"names": ["Marteau de guerre", "Maillet", "Bec de corbin", "Marteau du roi"], "atk": 14, "reach": 2.0, "speed": 0.65, "kb": 4.0, "style": 2, "two": true, "ingots": 5, "extra": [["wood", 3]], "bonus": {"stun": 0.04}},
	"masse": {"names": ["Masse d'armes", "Masse à ailettes", "Casse-tête", "Masse du prêtre"], "atk": 10, "reach": 1.7, "speed": 0.9, "kb": 2.5, "style": 0, "ingots": 3, "extra": [["wood", 1]], "bonus": {"stun": 0.03}},
	"morgenstern": {"names": ["Morgenstern", "Étoile du matin", "Goupillon", "Morgenstern du croisé"], "atk": 11, "reach": 1.8, "speed": 0.8, "kb": 3.0, "style": 2, "ingots": 4, "extra": [["wood", 1]]},
	"lance": {"names": ["Lance", "Lance à feuille", "Trident", "Lance d'honneur"], "atk": 9, "reach": 2.6, "speed": 0.95, "kb": 1.0, "style": 1, "ingots": 2, "extra": [["wood", 3]]},
	"hallebarde": {"names": ["Hallebarde", "Guisarme", "Fauchard", "Hallebarde de la garde"], "atk": 13, "reach": 2.9, "speed": 0.75, "kb": 2.0, "style": 1, "two": true, "ingots": 4, "extra": [["wood", 4]]},
	"faux": {"names": ["Faux", "Faux de guerre", "Faucille longue", "Faux de la Moissonneuse"], "atk": 12, "reach": 2.6, "speed": 0.8, "kb": 1.5, "style": 2, "two": true, "ingots": 4, "extra": [["wood", 3]], "bonus": {"execute": 0.04}},
	"baton": {"names": ["Bâton", "Bâton spirale", "Bâton noueux", "Bâton de l'archimage"], "atk": 2, "mag": 12, "reach": 11.0, "speed": 0.9, "kb": 0.0, "style": 3, "two": true, "proj": true, "ingots": 2, "extra": [["wood", 4]]},
	"sceptre": {"names": ["Sceptre", "Sceptre couronné", "Sceptre lunaire", "Sceptre sacré"], "atk": 3, "mag": 10, "reach": 10.0, "speed": 1.05, "kb": 0.0, "style": 3, "proj": true, "ingots": 3, "extra": [["wood", 1]], "bonus": {"cdr_pct": 0.03}},
	"arc": {"names": ["Arc", "Arc long", "Arc de chasse", "Arc elfique"], "atk": 9, "reach": 14.0, "speed": 1.0, "kb": 0.5, "style": 3, "two": true, "proj": true, "ingots": 1, "extra": [["wood", 3], ["fiber", 3]]},
}
const TYPE_ORDER := ["epee", "espadon", "sabre", "katana", "rapiere", "dague", "hache", "hache_bataille", "marteau",
	"masse", "morgenstern", "lance", "hallebarde", "faux", "baton", "sceptre", "arc"]
## Matériaux (du plus simple au plus rare) : suffixe du nom, multiplicateur d'attaque et de magie, ressource,
## rareté, niveau de Forgeron requis, couleurs.
const MATERIALS := [
	{"id": "bois", "suffix": "en bois", "mult": 0.4, "mag": 0.6, "res": "wood", "rarity": 0, "level": 1, "main": "8a6238", "dark": "6a4428", "light": "b08a5a", "accent": "6a4428", "station": "etabli"},
	{"id": "os", "suffix": "d'os", "mult": 0.55, "mag": 0.8, "res": "os", "rarity": 0, "level": 4, "main": "e0d8c0", "dark": "a89c84", "light": "f4f0e4", "accent": "8a7a64", "station": "etabli"},
	{"id": "pierre", "suffix": "en pierre", "mult": 0.6, "mag": 0.5, "res": "stone", "rarity": 0, "level": 1, "main": "8a8a86", "dark": "6a6a66", "light": "b8b8b2", "accent": "6a6a66", "station": "etabli"},
	{"id": "cuivre", "suffix": "en cuivre", "mult": 0.8, "mag": 0.9, "res": "lingot_cuivre", "rarity": 0, "level": 6, "main": "c87a4a", "dark": "9a5a34", "light": "eaa476", "accent": "9a5a34"},
	{"id": "bronze", "suffix": "en bronze", "mult": 0.92, "mag": 0.9, "res": "lingot_bronze", "rarity": 1, "level": 12, "main": "b8863a", "dark": "8a6228", "light": "dcb060", "accent": "8a6228"},
	{"id": "fer", "suffix": "en fer", "mult": 1.0, "mag": 1.0, "res": "iron_ingot", "rarity": 1, "level": 18, "main": "9aa0ab", "dark": "6e747e", "light": "c8ced6", "accent": "d8b04a"},
	{"id": "acier", "suffix": "en acier", "mult": 1.4, "mag": 1.0, "res": "lingot_acier", "rarity": 2, "level": 28, "main": "8a96a8", "dark": "4e5866", "light": "dfe6ee", "accent": "3a3a44"},
	{"id": "argent", "suffix": "en argent", "mult": 1.25, "mag": 1.7, "res": "lingot_argent", "rarity": 2, "level": 34, "main": "d0d6e0", "dark": "9aa2b0", "light": "f6f8fc", "accent": "6a8ad8", "gem": "8ad0ff"},
	{"id": "or", "suffix": "en or", "mult": 1.15, "mag": 2.1, "res": "lingot_or", "rarity": 2, "level": 40, "main": "e0b848", "dark": "a8842a", "light": "ffe08a", "accent": "c83a3a", "gem": "ff4a6a"},
	{"id": "obsidienne", "suffix": "d'obsidienne", "mult": 1.9, "mag": 1.4, "res": "obsidienne", "rarity": 3, "level": 50, "main": "3a2a4a", "dark": "1a1022", "light": "8a5ad0", "accent": "5a3a7a", "gem": "c06aff", "glow": true},
	{"id": "mithril", "suffix": "en mithril", "mult": 3.3, "mag": 1.8, "res": "lingot_mithril", "rarity": 3, "level": 62, "main": "a8d8f0", "dark": "6a9ab8", "light": "e8f8ff", "accent": "d8f0ff", "gem": "6ad8ff"},
	{"id": "orichalque", "suffix": "en orichalque", "mult": 4.4, "mag": 2.0, "res": "orichalque", "rarity": 4, "level": 76, "main": "f0943a", "dark": "a8582a", "light": "ffd08a", "accent": "ffe0a0", "gem": "ffea6a", "glow": true, "rare": true},
	{"id": "draconique", "suffix": "draconique", "mult": 5.5, "mag": 1.8, "res": "ecaille_dragon", "rarity": 4, "level": 90, "main": "b02a2a", "dark": "5a1010", "light": "ff7a4a", "accent": "2a1010", "gem": "ffb03a", "glow": true, "rare": true},
]
## Designs : multiplicateurs [attaque, vitesse, portée, magie] et bonus.
const DESIGNS := [
	{"atk": 1.0, "speed": 1.0, "reach": 1.0, "mag": 1.0, "bonus": {}, "text": "équilibré"},
	{"atk": 1.15, "speed": 0.9, "reach": 1.05, "mag": 1.0, "bonus": {}, "text": "lourd : +15 % de dégâts, plus lent"},
	{"atk": 0.9, "speed": 1.12, "reach": 1.0, "mag": 1.0, "bonus": {"crit": 0.02}, "text": "vif : plus rapide, +2 % de critiques"},
	{"atk": 1.05, "speed": 1.0, "reach": 1.0, "mag": 1.25, "bonus": {"crit_mult": 0.06}, "text": "orné : +25 % de magie, +6 % de dégâts critiques (1 lingot d'or en plus)"},
]

## Ressources ajoutées : identifiant -> [nom, description, rareté, couleur, forme].
const RESOURCES := {
	"minerai_cuivre": ["Minerai de cuivre", "Roche veinée de cuivre. À fondre au four.", 0, "c87a4a", "ore"],
	"minerai_etain": ["Minerai d'étain", "Roche grise et tendre. Avec le cuivre, il donne le bronze.", 0, "b8bcc0", "ore"],
	"minerai_argent": ["Minerai d'argent", "Roche striée d'argent, dans les filons de fer et d'or.", 1, "e0e6f0", "ore"],
	"charbon": ["Charbon", "Brûle longtemps et fort : il faut du charbon pour l'acier.", 0, "2a2a2e", "lump"],
	"lingot_cuivre": ["Lingot de cuivre", "Un métal tendre et rougeoyant.", 0, "c87a4a", "ingot"],
	"lingot_bronze": ["Lingot de bronze", "Cuivre et étain fondus ensemble : plus dur que le cuivre.", 1, "b8863a", "ingot"],
	"lingot_acier": ["Lingot d'acier", "Du fer affiné au charbon : bien plus solide.", 2, "8a96a8", "ingot"],
	"lingot_argent": ["Lingot d'argent", "Un métal clair qui conduit la magie.", 2, "d8dce4", "ingot"],
	"os": ["Os", "Os solide, laissé par les squelettes et les bêtes.", 0, "e8e0c8", "bone"],
	"obsidienne": ["Obsidienne", "Verre volcanique noir, tranchant comme un rasoir.", 3, "3a2a4a", "crystal"],
	"poussiere_arcane": ["Poussière arcanique", "Poussière scintillante, tirée des objets désenchantés et des monstres. Sert aux enchantements.", 2, "b07aff", "dust"],
	"pierre_ame": ["Pierre d'âme", "Une gemme où dort l'âme d'un puissant ennemi. Sert aux enchantements les plus puissants.", 4, "7a3aff", "crystal"],
}
## Fontes au four : résultat, [ingrédients], quantité.
const SMELT := [
	["lingot_cuivre", [["minerai_cuivre", 2], ["charbon", 1]], 1],
	["lingot_bronze", [["lingot_cuivre", 2], ["minerai_etain", 1]], 2],
	["lingot_acier", [["iron_ingot", 2], ["charbon", 2]], 1],
	["lingot_argent", [["minerai_argent", 2], ["charbon", 1]], 1],
	["charbon", [["wood", 3]], 1],
]

static var _types_by_id := {}


static func material(id: String) -> Dictionary:
	for m in MATERIALS:
		if m.id == id:
			return m
	return MATERIALS[0]


static func colors(m: Dictionary) -> Dictionary:
	var d := {"id": m.id, "main": Color(m.main), "dark": Color(m.dark), "light": Color(m.light), "accent": Color(m.accent),
		"glow": m.get("glow", false)}
	if m.has("gem"):
		d["gem"] = Color(m.gem)
	if m.id in ["bois", "os", "pierre"]:
		d["grip"] = Color("5a341c")
	return d


static func is_arsenal(id: String) -> bool:
	return id.begins_with("arm_")


static func make_id(type: String, mat: String, design: int) -> String:
	return "arm_%s_%s_%d" % [type, mat, design]


## [type, matériau, design] d'un identifiant d'arme (de base, sans « @ »).
static func parse(id: String) -> Array:
	var rest := id.trim_prefix("arm_")
	var d := int(rest.get_slice("_", rest.get_slice_count("_") - 1))
	rest = rest.left(rest.rfind("_"))
	for m in MATERIALS:
		if rest.ends_with("_" + m.id):
			return [rest.trim_suffix("_" + m.id), m.id, d]
	return ["epee", "fer", 0]


## Le maillage de l'arme (tenu dans la main gauche).
static func mesh_for(id: String) -> ArrayMesh:
	var spec := parse(id)
	return WeaponModels.mesh(spec[0], colors(material(spec[1])), spec[2])


## Nombre de lingots (ou de ressource) d'une arme de ce type dans ce matériau.
static func res_amount(t: Dictionary, m: Dictionary) -> int:
	var n: int = t.ingots
	if m.get("rare", false):
		n = maxi(1, ceili(n / 2.0))
	if m.id in ["bois", "pierre", "os"]:
		n += 1
	return n


static func make_item(type: String, m: Dictionary, design: int) -> ItemData:
	var t: Dictionary = TYPES[type]
	var ds: Dictionary = DESIGNS[design]
	var it := ItemData.new()
	it.id = make_id(type, m.id, design)
	var tname: String = t.names[design]
	it.display_name = "%s %s" % [tname, m.suffix]
	it.slot = ItemData.Slot.MAIN_HAND
	it.rarity = mini(int(m.rarity) + (1 if design == 3 and int(m.rarity) < 4 else 0), 4) as ItemData.Rarity
	it.attack = maxi(1, roundi(float(t.atk) * float(m.mult) * float(ds.atk)))
	if t.has("mag"):
		it.magic = maxi(1, roundi(float(t.mag) * float(m.mult) * float(m.mag) / 1.4 * float(ds.mag)))
	elif design == 3:
		it.magic = maxi(1, roundi(2.0 * float(m.mag)))
	it.reach = float(t.reach) * float(ds.reach)
	it.attack_speed = clampf(float(t.speed) * float(ds.speed), 0.3, 2.0)
	it.knockback = float(t.kb)
	it.weapon_style = int(t.style) as ItemData.WeaponStyle
	it.two_handed = t.get("two", false)
	it.projectile = t.get("proj", false)
	it.speed_bonus = -0.05 if it.two_handed and int(t.style) == 2 else 0.0
	var bonus := {}
	for k in t.get("bonus", {}):
		bonus[k] = float(t.bonus[k])
	for k in ds.bonus:
		bonus[k] = float(bonus.get(k, 0.0)) + float(ds.bonus[k])
	it.bonus = bonus
	it.max_stack = 1
	it.description = "%s — %s. Forgé %s (niveau de Forgeron %d)." % [tname, ds.text, m.suffix if m.id != "draconique" else "en écailles de dragon", int(m.level)]
	return it


static func make_recipe(db: Node, it: ItemData, type: String, m: Dictionary, design: int) -> RecipeData:
	var t: Dictionary = TYPES[type]
	var r := RecipeData.new()
	r.result = it
	r.category = "Armurerie"
	r.station = m.get("station", "enclume")
	var ing: Array[ItemData] = []
	var am := PackedInt32Array()
	var pairs := [[m.res, res_amount(t, m)]]
	for e in t.extra:
		pairs.append(e)
	if design == 3 and m.id != "or":
		pairs.append(["lingot_or", 1])
	var merged := {}
	for pr in pairs:
		merged[pr[0]] = int(merged.get(pr[0], 0)) + int(pr[1])
	for k in merged:
		var ri: ItemData = db.items.get(k)
		if ri:
			ing.append(ri)
			am.append(merged[k])
	r.ingredients = ing
	r.amounts = am
	return r


## Ajoute à la base des objets les ressources, les fontes et les 884 armes (appelé par Items au démarrage).
static func register(db: Node) -> void:
	for id in RESOURCES:
		if db.items.has(id):
			continue
		var d: Array = RESOURCES[id]
		var it := ItemData.new()
		it.id = id
		it.display_name = d[0]
		it.description = d[1]
		it.rarity = int(d[2]) as ItemData.Rarity
		it.max_stack = 99
		db.items[id] = it
	for s in SMELT:
		var r := RecipeData.new()
		r.result = db.items.get(s[0])
		r.result_count = int(s[2])
		var ing: Array[ItemData] = []
		var am := PackedInt32Array()
		for pr in s[1]:
			ing.append(db.items.get(pr[0]))
			am.append(int(pr[1]))
		r.ingredients = ing
		r.amounts = am
		r.station = "four"
		r.category = "Matériaux"
		db.recipes.append(r)
	for type in TYPE_ORDER:
		for m in MATERIALS:
			for d in 4:
				var it := make_item(type, m, d)
				db.items[it.id] = it
				db.recipes.append(make_recipe(db, it, type, m, d))


## Toutes les armes de l'arsenal (identifiants), dans l'ordre type, matériau, design.
static func all_ids() -> Array:
	var out := []
	for type in TYPE_ORDER:
		for m in MATERIALS:
			for d in 4:
				out.append(make_id(type, m.id, d))
	return out


static func resource_color(id: String) -> Color:
	return Color(RESOURCES[id][3]) if RESOURCES.has(id) else Color.WHITE


static func resource_shape(id: String) -> String:
	return RESOURCES[id][4] if RESOURCES.has(id) else ""
