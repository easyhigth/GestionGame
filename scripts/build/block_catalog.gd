class_name BlockCatalog
extends RefCounted
## Le catalogue de construction, façon Minecraft : environ 270 blocs et dalles fabriqués par le code
## (textures 16×16 dessinées à la volée), avec leurs recettes et leurs ressources :
## - 12 pierres (granite, diorite, andésite, basalte, calcaire, grès, grès rouge, schiste, obsidienne,
##   quartz, prismarine, et la pierre) en pavés, polie, briques, petites briques, sculptée, briques fissurées ;
## - 9 essences de bois (chêne, bouleau, sapin, acajou, ébène, cerisier, acacia, saule, palmier) en planches,
##   rondins, bois écorcé et parquet ; chaque région a ses arbres ;
## - 16 couleurs (teintures) de laine, béton, terre cuite, terre cuite émaillée et verre teinté ;
## - blocs de métal et de gemmes, blocs naturels (gravier, argile, neige, glace, mousse, foin...) ;
## - des dalles (demi-blocs) pour les pierres et les bois.
## Chaque recette porte une « famille » (méta « family ») pour l'onglet Construction.

const FAMILIES := ["Classiques", "Pierres", "Bois", "Laine", "Béton", "Terre cuite", "Verre teinté", "Métaux et gemmes", "Nature", "Dalles"]

## Pierres : identifiant, nom, féminin, couleur, ressource brute.
const STONES := [
	["pierre", "pierre", true, "8e8c86", "stone"], ["granite", "granite", false, "b8826e", "granite"],
	["diorite", "diorite", true, "d6d4ce", "diorite"], ["andesite", "andésite", true, "8a8c88", "andesite"],
	["basalte", "basalte", false, "4a4a52", "basalte"], ["calcaire", "calcaire", false, "d8cca8", "calcaire"],
	["gres", "grès", false, "dcc48a", "bloc_sable"], ["gres_rouge", "grès rouge", false, "b8643a", "argile"],
	["schiste", "schiste", false, "5a6068", "basalte"], ["obsidienne", "obsidienne", true, "2a1e34", "obsidienne"],
	["quartz", "quartz", false, "ece6dc", "quartz"], ["prismarine", "prismarine", true, "4a9a8a", "prismarine"],
]
## Variantes de pierre : identifiant, nom (%s : la pierre), nom féminin, niveau du bloc, quantité obtenue pour 2 bruts.
const STONE_VARIANTS := [
	["paves", "Pavés de %s", "Pavés de %s", 1, 2], ["polie", "%s poli", "%s polie", 3, 2],
	["briques", "Briques de %s", "Briques de %s", 2, 2], ["petites_briques", "Petites briques de %s", "Petites briques de %s", 2, 2],
	["sculptee", "%s sculpté", "%s sculptée", 3, 1], ["fissurees", "Briques de %s fissurées", "Briques de %s fissurées", 2, 2],
]
## Essences de bois : identifiant, nom, couleur du bois, couleur de l'écorce, régions où elles poussent.
const WOODS := [
	["chene", "chêne", "a8783c", "6a4a2a", ["prairie", "foret"]], ["bouleau", "bouleau", "e0cf9a", "e8e4dc", ["prairie", "toundra"]],
	["sapin", "sapin", "7a5634", "4a3420", ["foret", "montagnes", "toundra"]], ["acajou", "acajou", "a8503a", "5a3a24", ["jungle"]],
	["ebene", "ébène", "3a2a24", "1e1612", ["volcan", "marais"]], ["cerisier", "cerisier", "e8a8a8", "4a2a2a", ["bois_enchante"]],
	["acacia", "acacia", "c8683a", "6a6058", ["desert"]], ["saule", "saule", "8a8a5a", "4a4a34", ["marais"]],
	["palmier", "palmier", "d8b070", "8a6a44", ["desert", "jungle"]],
]
## 16 couleurs : identifiant, nom (masculin), nom féminin, couleur.
const COLORS := [
	["blanc", "blanc", "blanche", "f0f0ec"], ["gris_clair", "gris clair", "gris clair", "a8a8a4"], ["gris", "gris", "grise", "5a5a5e"],
	["noir", "noir", "noire", "222226"], ["marron", "marron", "marron", "7a4e2e"], ["rouge", "rouge", "rouge", "b83a32"],
	["orange", "orange", "orange", "e8862e"], ["jaune", "jaune", "jaune", "f0cc3a"], ["citron", "vert citron", "vert citron", "8ad03a"],
	["vert", "vert", "verte", "4a7a2a"], ["cyan", "cyan", "cyan", "2a8a9a"], ["bleu_clair", "bleu clair", "bleu clair", "6ab0e8"],
	["bleu", "bleu", "bleue", "2e4aa8"], ["violet", "violet", "violette", "7a3ab0"], ["magenta", "magenta", "magenta", "c04ab0"],
	["rose", "rose", "rose", "f0a0b8"],
]
## Teintures : de quoi on les tire (ingrédients pour 2 teintures).
const DYE_SOURCES := {
	"blanc": [["os", 1]], "noir": [["charbon", 1]], "rouge": [["baies", 2]], "jaune": [["ble", 2]], "vert": [["fiber", 3]],
	"marron": [["bloc_terre", 1], ["fiber", 1]], "bleu": [["lazurite", 1]], "orange": [["teinture_rouge", 1], ["teinture_jaune", 1]],
	"gris": [["teinture_noir", 1], ["teinture_blanc", 1]], "gris_clair": [["teinture_gris", 1], ["teinture_blanc", 1]],
	"citron": [["teinture_vert", 1], ["teinture_blanc", 1]], "cyan": [["teinture_bleu", 1], ["teinture_vert", 1]],
	"bleu_clair": [["teinture_bleu", 1], ["teinture_blanc", 1]], "violet": [["teinture_bleu", 1], ["teinture_rouge", 1]],
	"magenta": [["teinture_violet", 1], ["teinture_rose", 1]], "rose": [["teinture_rouge", 1], ["teinture_blanc", 1]],
}
## Métaux et gemmes : identifiant, nom, couleur, ingrédient, nombre, motif, niveau du bloc.
const METALS := [
	["fer", "Bloc de fer", "c8ccd2", "iron_ingot", 9, "metal", 5], ["or", "Bloc d'or", "f0c840", "lingot_or", 9, "metal", 5],
	["cuivre", "Bloc de cuivre", "d07a4a", "lingot_cuivre", 9, "metal", 5], ["bronze", "Bloc de bronze", "c08a40", "lingot_bronze", 9, "metal", 5],
	["acier", "Bloc d'acier", "8a96a8", "lingot_acier", 9, "metal", 5], ["argent", "Bloc d'argent", "e4e8f0", "lingot_argent", 9, "metal", 5],
	["mithril", "Bloc de mithril", "a8d8f0", "lingot_mithril", 9, "metal", 5], ["orichalque", "Bloc d'orichalque", "f0943a", "orichalque", 4, "metal", 5],
	["charbon", "Bloc de charbon", "26262a", "charbon", 9, "lump", 1], ["os", "Bloc d'os", "e8e0c8", "os", 9, "bone", 1],
	["diamant", "Bloc de diamant", "8ae8f0", "gemme_diamant", 4, "gem", 5], ["emeraude", "Bloc d'émeraude", "3ad070", "gemme_emeraude", 4, "gem", 5],
	["rubis", "Bloc de rubis", "e03a4a", "gemme_rubis", 4, "gem", 5], ["saphir", "Bloc de saphir", "3a6ae0", "gemme_saphir", 4, "gem", 5],
	["amethyste", "Bloc d'améthyste", "a05ae0", "gemme_amethyste", 4, "gem", 5], ["topaze", "Bloc de topaze", "f0b03a", "gemme_topaze", 4, "gem", 5],
	["lazurite", "Bloc de lazurite", "2a4ab8", "lazurite", 9, "gem", 3],
]
## Blocs naturels et divers : identifiant, nom, couleur, motif, ingrédients, quantité, transparent, niveau, poste.
const NATURE := [
	["gravier", "Gravier", "8a8480", "gravel", [["gravier", 2]], 2, false, 1, ""],
	["argile", "Bloc d'argile", "a0a8b4", "noise", [["argile", 2]], 2, false, 0, ""],
	["neige", "Bloc de neige", "f4f8fc", "noise", [["bloc_sable", 1], ["teinture_blanc", 1]], 4, false, 0, ""],
	["glace", "Glace", "a8d0f0", "ice", [["bloc_verre", 2], ["teinture_bleu_clair", 1]], 2, true, 1, "four"],
	["mousse", "Bloc de mousse", "4a8a3a", "noise", [["fiber", 4], ["bloc_terre", 1]], 2, false, 0, ""],
	["herbe", "Motte d'herbe", "5aa040", "grass", [["bloc_terre", 1], ["fiber", 2]], 1, false, 0, ""],
	["terre_battue", "Terre battue", "9a7a4a", "path", [["bloc_terre", 2]], 2, false, 0, ""],
	["foin", "Botte de foin", "d8b84a", "hay", [["ble", 6]], 1, false, 0, ""],
	["feuillage", "Feuillage", "3a7a2a", "leaves", [["fiber", 3]], 2, true, 0, ""],
	["citrouille", "Citrouille", "e08a2a", "pumpkin", [["graines_ble", 2], ["carotte", 2]], 1, false, 0, ""],
	["melon", "Melon", "5a9a3a", "melon", [["graines_ble", 2], ["baies", 3]], 1, false, 0, ""],
	["bibliotheque", "Bibliothèque", "a8783c", "books", [["bloc_planches", 4], ["laine", 2]], 1, false, 0, "etabli"],
	["pierre_lumineuse", "Pierre lumineuse", "f8e08a", "glow", [["quartz", 2], ["poussiere_arcane", 1]], 2, false, 3, "table_tailleur"],
	["lanterne_marine", "Lanterne marine", "b8f0e8", "glow", [["prismarine", 2], ["poussiere_arcane", 1]], 2, false, 3, "table_tailleur"],
	["champignon_rouge", "Bloc de champignon rouge", "c03a2a", "mushroom", [["fiber", 2], ["baies", 2]], 2, false, 0, ""],
	["champignon_brun", "Bloc de champignon brun", "9a6a4a", "noise", [["fiber", 2], ["bloc_terre", 1]], 2, false, 0, ""],
]
## Ressources brutes ajoutées : identifiant -> [nom, description, couleur, forme (voir ResourceModels)].
const RAW := {
	"granite": ["Granite brut", "Pierre rose mouchetée, des prairies et des montagnes.", "b8826e", "lump"],
	"diorite": ["Diorite brute", "Pierre blanche tachetée, des forêts et des toundras.", "d6d4ce", "lump"],
	"andesite": ["Andésite brute", "Pierre grise et lisse, des prairies et des marais.", "8a8c88", "lump"],
	"basalte": ["Basalte brut", "Roche volcanique sombre.", "4a4a52", "lump"],
	"calcaire": ["Calcaire brut", "Pierre claire et tendre des déserts.", "d8cca8", "lump"],
	"quartz": ["Quartz", "Cristal laiteux des bois enchantés et des montagnes.", "ece6dc", "crystal"],
	"prismarine": ["Prismarine", "Pierre verte et bleue des marais et des côtes.", "4a9a8a", "crystal"],
	"lazurite": ["Lazurite", "Pierre d'un bleu profond : la teinture bleue.", "2a4ab8", "lump"],
	"gravier": ["Gravier", "Petits cailloux, en creusant le sol.", "8a8480", "lump"],
	"argile": ["Argile", "Terre grise et collante, en creusant près de l'eau.", "a0a8b4", "lump"],
}
## Pierre brute de chaque région (dans les rochers).
const REGION_STONE := {"prairie": ["granite", "andesite", "calcaire"], "foret": ["diorite", "andesite"], "montagnes": ["granite", "quartz", "basalte"],
	"toundra": ["diorite", "quartz"], "desert": ["calcaire", "granite"], "jungle": ["andesite", "prismarine"], "marais": ["prismarine", "andesite"],
	"volcan": ["basalte", "basalte", "quartz"], "bois_enchante": ["quartz", "diorite"]}

static var _textures := {}


# ---------------------------------------------------------------- textures

static func _hs(x: float, y: float, s: float) -> float:
	var n := sin(x * 127.1 + y * 311.7 + s * 74.7) * 43758.5453
	return n - floorf(n)


static func _c(hexc: String, f := 1.0, a := 1.0) -> Color:
	var c := Color(hexc)
	return Color(minf(1.0, c.r * f), minf(1.0, c.g * f), minf(1.0, c.b * f), a)


## Dessine un motif 16×16 et en fait une texture (avec mipmaps, pour le shader des blocs).
static func texture(pattern: String, col: String, seed: int, col2 := "") -> Texture2D:
	var key := "%s|%s|%d|%s" % [pattern, col, seed, col2]
	if _textures.has(key):
		return _textures[key]
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var s := float(seed)
	for y in 16:
		for x in 16:
			img.set_pixel(x, y, _pixel(pattern, col, col2, x, y, s))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_textures[key] = tex
	return tex


static func _pixel(p: String, col: String, col2: String, x: int, y: int, s: float) -> Color:
	match p:
		"planks":
			var board := y / 4
			var seam := y % 4 == 3 or (x + (board * 7) % 16) % 16 == 0
			return _c(col, 0.62 if seam else 0.9 + _hs(x / 3, y, s + board) * 0.18)
		"parquet":
			var cell := ((x / 4) + (y / 8)) % 2
			var along := y % 8 if cell == 0 else x % 4
			var seam := (x % 4 == 3) if cell == 0 else (y % 8 == 7)
			return _c(col, 0.65 if seam else 0.88 + 0.16 * _hs(x / 4, y / 8, s) + 0.02 * along)
		"logs":
			var v := 0.85 + 0.2 * _hs(x, y / 5, s)
			if x % 4 == 0:
				v = 0.7
			if _hs(x, y, s + 3) > 0.93:
				v = 0.6
			return _c(col2 if col2 != "" else col, v)
		"stripped":
			return _c(col, 0.95 + 0.1 * _hs(x, y / 6, s) - (0.12 if x % 5 == 0 else 0.0))
		"noise", "wool", "terracotta", "concrete":
			var amp := {"noise": 0.25, "wool": 0.22, "terracotta": 0.12, "concrete": 0.05}[p] as float
			var v := 1.0 - amp / 2 + amp * _hs(x / 2, y / 2, s) * 0.6 + amp * _hs(x, y, s + 1) * 0.4
			if p == "wool" and (x + y * 3) % 7 == 0:
				v *= 0.9
			return _c(col, v)
		"cobble":
			var d := _voronoi(x, y, s)
			return _c(col, 0.55 if d[1] - d[0] < 1.1 else 0.85 + 0.25 * _hs(floorf(d[0]), 0, s))
		"bricks", "small_bricks", "cracked":
			var bh := 4 if p != "small_bricks" else 3
			var bw := 8 if p != "small_bricks" else 4
			var row := y / bh
			var off := (bw / 2) * (row % 2)
			var mortar := y % bh == bh - 1 or (x + off) % bw == 0
			var v := 0.62 if mortar else 0.88 + 0.2 * _hs((x + off) / bw, row, s)
			if p == "cracked" and not mortar and absf(sin(x * 0.9 + y * 1.7 + s)) < 0.12:
				v = 0.45
			return _c(col, v)
		"polished":
			var border := x == 0 or y == 0 or x == 15 or y == 15
			var inner := x == 1 or y == 1
			return _c(col, 0.78 if border else (1.08 if inner else 0.97 + 0.05 * _hs(x, y, s)))
		"chiseled":
			var border := x == 0 or y == 0 or x == 15 or y == 15
			var ring := (x == 3 or x == 12) and y >= 3 and y <= 12 or (y == 3 or y == 12) and x >= 3 and x <= 12
			var center := absi(x - 7) + absi(y - 7) <= 2
			return _c(col, 0.7 if border or ring else (1.1 if center else 0.95 + 0.05 * _hs(x, y, s)))
		"glazed":
			var a := (x + y) % 8 < 2 or (x - y + 16) % 8 < 2
			var edge := x == 0 or y == 0 or x == 15 or y == 15
			return _c(col if not a else col2, 0.7 if edge else 1.0)
		"glass":
			var frame := x == 0 or y == 0 or x == 15 or y == 15
			if frame:
				return _c(col, 0.85, 1.0)
			var shine := (x - y) in [4, 5, 9]
			return _c(col, 1.1 if shine else 1.0, 0.55 if shine else 0.32)
		"ice":
			var crack := absf(sin(x * 0.7 - y * 1.1 + s)) < 0.1
			return _c(col, 1.15 if crack else 0.95 + 0.1 * _hs(x / 3, y / 3, s), 0.75)
		"metal":
			var border := x == 0 or y == 0 or x == 15 or y == 15
			var rivet := (x == 2 or x == 13) and (y == 2 or y == 13)
			var band := y == 7 or y == 8
			return _c(col, 0.72 if border else (1.25 if rivet else (0.9 if band else 1.0 + 0.06 * _hs(x, y / 4, s))))
		"gem":
			var facet := (absi(x - 7) + absi(y - 7)) % 5
			return _c(col, 0.75 + 0.1 * facet + (0.25 if (x + y) % 9 == 0 else 0.0))
		"lump":
			return _c(col, 0.75 + 0.35 * _hs(x / 2, y / 2, s))
		"bone":
			var ring := absi(x - 7) + absi(y - 7) < 4
			return _c(col, 0.8 if ring else 0.98 + 0.05 * _hs(x, y, s))
		"gravel":
			var d := _voronoi(x, y, s + 9)
			return _c(col, 0.6 if d[1] - d[0] < 0.8 else 0.75 + 0.45 * _hs(floorf(d[0] * 3), 1, s))
		"grass":
			var blade := _hs(x, 0, s) * 6.0
			return _c("5aa040" if y < 3 + blade else "7a5a3c", 0.85 + 0.25 * _hs(x, y, s))
		"path":
			return _c(col, 0.85 + 0.2 * _hs(x / 3, y / 2, s) - (0.1 if (x * 5 + y) % 11 == 0 else 0.0))
		"hay":
			var band := y == 4 or y == 11
			return _c("a83a2a" if band and x % 2 == 0 else col, 0.8 + 0.35 * _hs(x, (y + x * 3) / 2, s))
		"leaves":
			var hole := _hs(x, y, s) > 0.78
			return _c(col, 0.75 + 0.4 * _hs(x / 2, y / 2, s), 0.0 if hole else 1.0)
		"pumpkin":
			return _c(col, 0.75 if x % 4 == 0 else 0.95 + 0.1 * _hs(x, y, s))
		"melon":
			return _c("8ad04a" if (x + y / 3) % 5 == 0 else col, 0.85 + 0.2 * _hs(x, y / 3, s))
		"books":
			if y <= 1 or y >= 14 or y == 7 or y == 8:
				return _c("a8783c", 0.8 if y in [1, 8] else 1.0)
			var book := x / 2
			var hues := ["b83a32", "2e4aa8", "4a7a2a", "7a3ab0", "c08a40", "5a3a24", "a8a8a4", "2a8a9a"]
			return _c(hues[(book + (3 if y > 8 else 0)) % hues.size()], 0.75 if x % 2 == 1 else 1.0)
		"glow":
			var tile := (x / 4 + y / 4) % 2
			return _c(col, 1.0 if tile == 0 else 0.85 + 0.15 * _hs(x, y, s))
		"mushroom":
			var spot := Vector2(x % 8 - 4, y % 8 - 4).length() < 1.6
			return _c("f0ece4" if spot else col, 0.92 + 0.08 * _hs(x, y, s))
	return _c(col)


static func _voronoi(x: int, y: int, s: float) -> Array:
	var d := []
	for i in 9:
		var px := _hs(i, 0, s) * 16.0
		var py := _hs(i, 1, s) * 16.0
		var dx := minf(absf(x - px), 16.0 - absf(x - px))
		var dy := minf(absf(y - py), 16.0 - absf(y - py))
		d.append(sqrt(dx * dx + dy * dy))
	d.sort()
	return d


# ---------------------------------------------------------------- objets et recettes

static func _block(db: Node, id: String, name: String, desc: String, tex: Texture2D, tier: int, slab := false, transparent := false) -> ItemData:
	if db.items.has(id):
		return db.items[id]
	var it := ItemData.new()
	it.id = id
	it.display_name = name
	it.description = desc
	it.max_stack = 99
	it.block_texture = tex
	it.block_tier = tier
	it.block_slab = slab
	it.block_transparent = transparent
	it.rarity = ItemData.Rarity.COMMON if tier < 4 else ItemData.Rarity.UNCOMMON
	db.items[id] = it
	return it


static func _recipe(db: Node, result: ItemData, count: int, ings: Array, station: String, family: String) -> void:
	var r := RecipeData.new()
	r.result = result
	r.result_count = count
	var ing: Array[ItemData] = []
	var am := PackedInt32Array()
	for pr in ings:
		var it: ItemData = db.items.get(pr[0])
		if it == null:
			return
		ing.append(it)
		am.append(int(pr[1]))
	r.ingredients = ing
	r.amounts = am
	r.station = station
	r.category = "Construction"
	r.set_meta("family", family)
	db.recipes.append(r)


static func _raw(db: Node, id: String, name: String, desc: String) -> ItemData:
	if db.items.has(id):
		return db.items[id]
	var it := ItemData.new()
	it.id = id
	it.display_name = name
	it.description = desc
	it.max_stack = 99
	db.items[id] = it
	return it


static func _cap(s: String) -> String:
	return s.left(1).to_upper() + s.substr(1)


## Ajoute les ressources, les teintures, les blocs et leurs recettes (appelé par Items au démarrage).
static func register(db: Node) -> void:
	for id in RAW:
		_raw(db, id, RAW[id][0], RAW[id][1])
	# les recettes de construction déjà là : famille « Classiques »
	for r in db.recipes:
		if r.category == "Construction" and not r.has_meta("family"):
			r.set_meta("family", "Classiques")
	_stones(db)
	_woods(db)
	_colors(db)
	_metals(db)
	_nature(db)


static func _stones(db: Node) -> void:
	var seed := 100
	for st in STONES:
		var sid: String = st[0]
		var fem: bool = st[2]
		for v in STONE_VARIANTS:
			seed += 1
			var vid: String = v[0]
			# la pierre a déjà ses pavés, ses briques et sa pierre polie
			if sid == "pierre" and vid in ["paves", "briques", "polie"]:
				continue
			var pat: String = {"paves": "cobble", "polie": "polished", "briques": "bricks", "petites_briques": "small_bricks",
				"sculptee": "chiseled", "fissurees": "cracked"}[vid]
			var tpl: String = v[2] if fem else v[1]
			var name: String = tpl % (_cap(st[1]) if tpl.begins_with("%") else str(st[1]))
			var it := _block(db, "bloc_%s_%s" % [sid, vid], _cap(name), "Bloc de %s (%s)." % [st[1], vid.replace("_", " ")],
				texture(pat, st[3], seed), int(v[3]))
			var raw: String = st[4]
			var ings := [[raw, 2]]
			if vid == "sculptee" or vid == "fissurees":
				ings = [[raw, 2], ["stone", 1]]
			_recipe(db, it, int(v[4]), ings, "table_tailleur", "Pierres")
			# dalles : pavés, poli et briques
			if vid in ["paves", "polie", "briques"]:
				var slab := _block(db, "dalle_%s_%s" % [sid, vid], "Dalle : " + _cap(name), "Demi-bloc de %s." % st[1], it.block_texture, it.block_tier, true)
				_recipe(db, slab, 4, [[raw, 1]], "table_tailleur", "Dalles")
	# pierre moussue
	var moss := _block(db, "bloc_pierre_moussue", "Pavés moussus", "Des pavés couverts de mousse.", texture("cobble", "6a8a5a", 77), 1)
	_recipe(db, moss, 2, [["stone", 2], ["fiber", 2]], "", "Pierres")
	for pair in [["bloc_pierre_brute", "Pavés"], ["bloc_briques", "Pierre taillée"], ["bloc_pierre_polie", "Pierre polie"]]:
		var base: ItemData = db.items.get(pair[0])
		if base and not db.items.has("dalle_" + pair[0]):
			var slab := _block(db, "dalle_" + pair[0], "Dalle : " + pair[1], "Demi-bloc.", base.block_texture, base.block_tier, true)
			_recipe(db, slab, 4, [["stone", 1]], "table_tailleur", "Dalles")


static func _woods(db: Node) -> void:
	var seed := 300
	for w in WOODS:
		var wid: String = w[0]
		var raw := "wood" if wid == "chene" else "bois_" + wid
		if wid != "chene":
			_raw(db, raw, "Bois de %s" % w[1], "Bûches de %s, abattues dans %s." % [w[1], ", ".join(PackedStringArray(w[4]))])
		for v in [["planches", "Planches de %s", "planks", 4, 1], ["rondins", "Rondins de %s", "logs", 2, 1],
				["ecorce", "Bois de %s écorcé", "stripped", 2, 1], ["parquet", "Parquet de %s", "parquet", 4, 2]]:
			seed += 1
			if wid == "chene" and v[0] in ["planches", "rondins"]:
				continue
			var it := _block(db, "bloc_%s_%s" % [wid, v[0]], v[1] % w[1], "Bloc de bois de %s." % w[1], texture(v[2], w[2], seed, w[3]), 0)
			_recipe(db, it, int(v[3]), [[raw, int(v[4])]], "etabli" if v[0] == "parquet" else "", "Bois")
			if v[0] == "planches":
				var slab := _block(db, "dalle_%s" % wid, "Dalle de %s" % w[1], "Demi-bloc de planches de %s." % w[1], it.block_texture, 0, true)
				_recipe(db, slab, 6, [[raw, 1]], "", "Dalles")


static func _colors(db: Node) -> void:
	# teintures
	for c in COLORS:
		var it := _raw(db, "teinture_" + c[0], "Teinture %s" % c[2], "Pour colorer la laine, le béton, la terre cuite et le verre.")
		it.rarity = ItemData.Rarity.COMMON
	for c in COLORS:
		_recipe(db, db.items["teinture_" + c[0]], 2, DYE_SOURCES[c[0]], "", "Laine")
	var terracotta := _block(db, "bloc_terre_cuite", "Terre cuite", "Argile cuite au four.", texture("terracotta", "b87a5a", 500), 1)
	_recipe(db, terracotta, 4, [["argile", 4]], "four", "Terre cuite")
	var seed := 400
	for c in COLORS:
		seed += 1
		var cid: String = c[0]
		var dye: String = "teinture_" + cid
		var wool := _block(db, "bloc_laine_" + cid, "Laine %s" % c[2], "Laine teinte.", texture("wool", c[3], seed), 0)
		_recipe(db, wool, 4, [["laine", 4], [dye, 1]], "", "Laine")
		var conc := _block(db, "bloc_beton_" + cid, "Béton %s" % c[1], "Béton lisse et coloré.", texture("concrete", c[3], seed), 2)
		_recipe(db, conc, 8, [["bloc_sable", 4], ["gravier", 4], [dye, 1]], "", "Béton")
		var tc := _block(db, "bloc_terre_cuite_" + cid, "Terre cuite %s" % c[2], "Terre cuite teinte.", texture("terracotta", Color(c[3]).darkened(0.15).to_html(false), seed), 1)
		_recipe(db, tc, 4, [["bloc_terre_cuite", 4], [dye, 1]], "", "Terre cuite")
		var gl := _block(db, "bloc_emaille_" + cid, "Terre cuite émaillée %s" % c[2], "Carreau émaillé à motifs.",
			texture("glazed", c[3], seed, Color(c[3]).lightened(0.45).to_html(false)), 2)
		_recipe(db, gl, 1, [["bloc_terre_cuite_" + cid, 1]], "four", "Terre cuite")
		var glass := _block(db, "bloc_verre_" + cid, "Verre %s" % c[1], "Verre teinté.", texture("glass", c[3], seed), 0, false, true)
		_recipe(db, glass, 4, [["bloc_verre", 4], [dye, 1]], "", "Verre teinté")


static func _metals(db: Node) -> void:
	var seed := 600
	for m in METALS:
		seed += 1
		var it := _block(db, "bloc_m_" + m[0], m[1], "Un bloc massif, pour décorer (ou montrer sa richesse).", texture(m[5], m[2], seed), int(m[6]))
		_recipe(db, it, 1, [[m[3], int(m[4])]], "enclume" if m[5] == "metal" else "table_tailleur", "Métaux et gemmes")


static func _nature(db: Node) -> void:
	var seed := 700
	for n in NATURE:
		seed += 1
		var it := _block(db, "bloc_" + n[0], n[1], "Bloc naturel.", texture(n[3], n[2], seed), int(n[7]), false, bool(n[6]))
		_recipe(db, it, int(n[5]), n[4], n[8], "Nature")


## Nombre de blocs de construction (blocs et dalles).
static func count_blocks(db: Node) -> int:
	var n := 0
	for id in db.items:
		var it: ItemData = db.items[id]
		if it.is_block():
			n += 1
	return n


## Le bois que donne un arbre abattu dans cette région (identifiant de ressource, ou « wood »).
static func wood_for_region(region_id: String, cell: Vector2i) -> String:
	var opts := []
	for w in WOODS:
		if region_id in w[4]:
			opts.append("wood" if w[0] == "chene" else "bois_" + w[0])
	if opts.is_empty():
		return "wood"
	return opts[absi(cell.x * 73 + cell.y * 31) % opts.size()]


## Pierre brute qu'un rocher de cette région peut donner.
static func stone_for_region(region_id: String, cell: Vector2i) -> String:
	var opts: Array = REGION_STONE.get(region_id, ["granite", "andesite"])
	return opts[absi(cell.x * 31 + cell.y * 17) % opts.size()]


## Couleur et forme du modèle d'une ressource de construction ([] si ce n'en est pas une).
static func resource_spec(id: String) -> Array:
	if RAW.has(id):
		return [Color(RAW[id][2]), RAW[id][3]]
	if id.begins_with("teinture_"):
		for c in COLORS:
			if "teinture_" + c[0] == id:
				return [Color(c[3]), "dust"]
	if id.begins_with("bois_"):
		for w in WOODS:
			if "bois_" + w[0] == id:
				return [Color(w[3]), "log", Color(w[2])]
	return []
