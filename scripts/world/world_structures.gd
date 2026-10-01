class_name WorldStructures
extends RefCounted
## Constructions du monde faites avec les mêmes blocs que ceux du joueur (comme les villages de Minecraft) :
## maisons abandonnées et ruines dans chaque région, arche de pierre des entrées de donjon,
## piliers autour des obélisques. Tout se casse bloc par bloc et rend ses blocs.
## Posées une seule fois, à la création du monde ; ensuite elles sont sauvegardées avec les constructions.

## Matériaux de chaque région : murs, poteaux d'angle, toit, fenêtres, toit plat ?, pilotis ?
const STYLES := {
	"prairie": {"wall": "bloc_planches", "post": "bloc_rondins", "roof": "bloc_chaume", "window": "bloc_verre"},
	"foret": {"wall": "bloc_rondins", "post": "bloc_planches", "roof": "bloc_chaume", "window": ""},
	"bois_enchante": {"wall": "bloc_planches", "post": "bloc_pierre_polie", "roof": "bloc_tuiles", "window": "bloc_verre"},
	"marais": {"wall": "bloc_rondins", "post": "bloc_rondins", "roof": "bloc_chaume", "window": "", "stilts": true},
	"desert": {"wall": "bloc_sable", "post": "bloc_sable", "roof": "bloc_sable", "window": "", "flat": true},
	"montagnes": {"wall": "bloc_pierre_brute", "post": "bloc_briques", "roof": "bloc_ardoise", "window": "bloc_verre"},
	"toundra": {"wall": "bloc_pierre_brute", "post": "bloc_rondins", "roof": "bloc_ardoise", "window": ""},
	"volcan": {"wall": "bloc_marbre_noir", "post": "bloc_briques", "roof": "bloc_marbre_noir", "window": "", "flat": true},
	"jungle": {"wall": "bloc_planches", "post": "bloc_rondins", "roof": "bloc_chaume", "window": "", "stilts": true},
}
const FOUNDATION := "bloc_pierre_brute"


## Plan d'une maison 5 × 5 (repère local : x, z de 0 à 4, porte au milieu du côté z = 4).
## Renvoie {Vector3i: identifiant de bloc}.
static func house_plan(style: Dictionary) -> Dictionary:
	var out := {}
	for y in 3:
		for x in 5:
			for z in 5:
				if x != 0 and x != 4 and z != 0 and z != 4:
					continue
				var corner := (x == 0 or x == 4) and (z == 0 or z == 4)
				var id: String = style.post if corner else style.wall
				# porte (2 de haut) devant, fenêtres sur les côtés
				if z == 4 and x == 2 and y < 2:
					continue
				if y == 1 and not corner and ((x == 0 or x == 4) and z == 2 or z == 0 and x == 2):
					if style.window == "":
						continue
					id = style.window
				out[Vector3i(x, y, z)] = id
	if style.get("flat", false):
		for x in 5:
			for z in 5:
				out[Vector3i(x, 3, z)] = style.roof
				if (x == 0 or x == 4 or z == 0 or z == 4) and (x + z) % 2 == 0:
					out[Vector3i(x, 4, z)] = style.roof
	else:
		# toit en gradins : 5 × 5, puis 3 × 3, puis le faîte
		for x in 5:
			for z in 5:
				out[Vector3i(x, 3, z)] = style.roof
		for x in range(1, 4):
			for z in range(1, 4):
				out[Vector3i(x, 4, z)] = style.roof
		out[Vector3i(2, 5, 2)] = style.roof
	return out


## Plan d'une ruine : un coin de murs effondrés et quelques pierres (repère local 0..4).
static func ruin_plan(style: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var out := {}
	for x in 5:
		for y in 3:
			if y <= 2 - absi(x - 1) / 2 and rng.randf() < 0.85:
				out[Vector3i(x, y, 0)] = style.wall if (x + y) % 3 != 0 else style.post
	for z in range(1, 4):
		for y in 2:
			if y <= 1 - z / 3 and rng.randf() < 0.8:
				out[Vector3i(0, y, z)] = style.wall
	out[Vector3i(0, 0, 0)] = style.post
	out[Vector3i(0, 1, 0)] = style.post
	out[Vector3i(3, 0, 3)] = FOUNDATION
	return out


## Arche de pierre d'une entrée de donjon, centrée sur la case de la porte (repère local : x de -2 à 2, z = 0).
static func gate_plan() -> Dictionary:
	var out := {}
	for y in 3:
		out[Vector3i(-1, y, 0)] = "bloc_briques"
		out[Vector3i(1, y, 0)] = "bloc_briques"
	for x in range(-2, 3):
		out[Vector3i(x, 3, 0)] = "bloc_pierre_polie" if x == 0 else "bloc_briques"
	out[Vector3i(0, 4, 0)] = "bloc_pierre_polie"
	for y in 2:
		out[Vector3i(-2, y, 0)] = "bloc_pierre_brute"
		out[Vector3i(2, y, 0)] = "bloc_pierre_brute"
	return out


## Quatre piliers de pierre polie aux coins d'un obélisque (repère local, centré sur l'obélisque).
static func obelisk_plan() -> Dictionary:
	var out := {}
	for c in [Vector2i(-2, -2), Vector2i(2, -2), Vector2i(-2, 2), Vector2i(2, 2)]:
		out[Vector3i(c.x, 0, c.y)] = "bloc_pierre_polie"
		out[Vector3i(c.x, 1, c.y)] = "bloc_pierre_polie"
	return out


## Pose un plan dans la grille de construction : chaque colonne repose sur le sol (fondations
## de pierre si le terrain descend), `broken` = part de blocs tombés (ruines). Renvoie le nombre de blocs posés.
static func build(world: WorldGenerator, plan: Dictionary, origin: Vector2i, rng: RandomNumberGenerator,
		broken := 0.0, style := {}) -> int:
	var grid := world.build
	if grid == null:
		return 0
	# niveau du rez-de-chaussée : le plus haut sol sous l'emprise
	var cols := {}
	for k in plan:
		cols[Vector2i(origin.x + k.x, origin.y + k.z)] = true
	var base := -100000
	for c in cols:
		base = maxi(base, roundi(world.terrain_height(c)))
	var n := 0
	var stilts: bool = style.get("stilts", false)
	if stilts:
		base += 1
	var lo := Vector2i(100000, 100000)
	var hi := Vector2i(-100000, -100000)
	for c in cols:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	for c in cols:
		var ground := roundi(world.terrain_height(c))
		var corner: bool = (c.x == lo.x or c.x == hi.x) and (c.y == lo.y or c.y == hi.y)
		for y in range(ground, base):
			var id := FOUNDATION
			if stilts:
				# sur pilotis : poteaux aux angles, plancher juste sous la maison
				if corner:
					id = style.get("post", FOUNDATION)
				elif y == base - 1:
					id = "bloc_planches"
				else:
					continue
			if grid.block_at(Vector3i(c.x, y, c.y)) == null and grid.place_block(Vector3i(c.x, y, c.y), Items.get_item(id)):
				n += 1
	var keys := plan.keys()
	keys.sort_custom(func(a, b): return a.y < b.y)
	for k in keys:
		if broken > 0.0 and k.y > 0 and rng.randf() < broken:
			continue
		var it := Items.get_item(plan[k]) as ItemData
		var key := Vector3i(origin.x + k.x, base + k.y, origin.y + k.z)
		if it and grid.place_block(key, it):
			n += 1
	return n
