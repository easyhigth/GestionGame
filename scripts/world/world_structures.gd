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
## Matériaux des châteaux selon la région : [murs, créneaux].
const CASTLE_MATS := {"desert": ["bloc_sable", "bloc_pierre_polie"], "volcan": ["bloc_marbre_noir", "bloc_tuiles"],
	"toundra": ["bloc_pierre_brute", "bloc_pierre_polie"], "bois_enchante": ["bloc_marbre", "bloc_pierre_polie"],
	"marais": ["bloc_pierre_brute", "bloc_briques"]}
## Niveau du rez-de-chaussée de la dernière construction posée.
static var last_base := 0


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


## Pierre des piliers d'obélisque selon la région : [bas, chapiteau]. Ailleurs : pierre polie.
const OBELISK_PILLARS := {
	"foret": ["bloc_rondins", "bloc_rondins"],
	"bois_enchante": ["bloc_marbre", "bloc_marbre"],
	"marais": ["bloc_terre", "bloc_rondins"],
	"desert": ["bloc_sable", "bloc_sable"],
	"montagnes": ["bloc_pierre_brute", "bloc_ardoise"],
	"toundra": ["bloc_marbre", "bloc_verre"],
	"volcan": ["bloc_marbre_noir", "bloc_tuiles"],
	"jungle": ["bloc_planches", "bloc_chaume"],
}


## Quatre piliers aux coins d'un obélisque (repère local, centré sur l'obélisque), dans la pierre
## de la région (sable au désert, marbre et glace en toundra, marbre noir et tuiles rouges au volcan, troncs en forêt...).
static func obelisk_plan(region_id := "") -> Dictionary:
	var mats: Array = OBELISK_PILLARS.get(region_id, ["bloc_pierre_polie", "bloc_pierre_polie"])
	var out := {}
	for c in [Vector2i(-2, -2), Vector2i(2, -2), Vector2i(-2, 2), Vector2i(2, 2)]:
		out[Vector3i(c.x, 0, c.y)] = mats[0]
		out[Vector3i(c.x, 1, c.y)] = mats[1]
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
	last_base = base
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


## Château fort (repère local 0..S-1) : enceinte crénelée, quatre tours d'angle coiffées d'ardoise,
## porte au sud (z = S-1), donjon carré au centre. `mat` : murs, `trim` : créneaux et encadrements.
static func castle_plan(size := 21, wall_h := 5, mat := "bloc_briques", trim := "bloc_pierre_polie") -> Dictionary:
	var out := {}
	var s := size
	var m := s / 2
	# enceinte
	for i in s:
		for y in wall_h:
			for k in [Vector2i(i, 0), Vector2i(i, s - 1), Vector2i(0, i), Vector2i(s - 1, i)]:
				# porte : 3 de large, 3 de haut
				if k.y == s - 1 and absi(k.x - m) <= 1 and y < 3:
					continue
				out[Vector3i(k.x, y, k.y)] = mat
		# créneaux
		for k in [Vector2i(i, 0), Vector2i(i, s - 1), Vector2i(0, i), Vector2i(s - 1, i)]:
			if i % 2 == 0:
				out[Vector3i(k.x, wall_h, k.y)] = trim
	# encadrement de la porte
	for x in range(m - 2, m + 3):
		out[Vector3i(x, 3, s - 1)] = trim
	# tours d'angle 5 × 5, plus hautes, toit d'ardoise
	for c in [Vector2i(0, 0), Vector2i(s - 5, 0), Vector2i(0, s - 5), Vector2i(s - 5, s - 5)]:
		for y in wall_h + 3:
			for x in 5:
				for z in 5:
					if x == 0 or x == 4 or z == 0 or z == 4:
						if y == 1 and (x == 2 or z == 2):
							out[Vector3i(c.x + x, y, c.y + z)] = "bloc_verre"
						else:
							out[Vector3i(c.x + x, y, c.y + z)] = mat
		for x in 5:
			for z in 5:
				out[Vector3i(c.x + x, wall_h + 3, c.y + z)] = "bloc_ardoise"
		for x in range(1, 4):
			for z in range(1, 4):
				out[Vector3i(c.x + x, wall_h + 4, c.y + z)] = "bloc_ardoise"
		out[Vector3i(c.x + 2, wall_h + 5, c.y + 2)] = "bloc_ardoise"
	# donjon central 7 × 7
	var d0 := m - 3
	for y in wall_h + 4:
		for x in 7:
			for z in 7:
				if x == 0 or x == 6 or z == 0 or z == 6:
					if z == 6 and x == 3 and y < 2:
						continue
					out[Vector3i(d0 + x, y, d0 + z)] = mat if not (y % 3 == 1 and (x == 3 or z == 3)) else "bloc_verre"
	for x in 7:
		for z in 7:
			out[Vector3i(d0 + x, wall_h + 4, d0 + z)] = trim
			if (x == 0 or x == 6 or z == 0 or z == 6) and (x + z) % 2 == 0:
				out[Vector3i(d0 + x, wall_h + 5, d0 + z)] = trim
	# sol de pierre polie dans la cour, devant le donjon
	for x in range(m - 1, m + 2):
		for z in range(d0 + 7, s - 1):
			out[Vector3i(x, -1, z)] = trim
	return out


## Épave de navire échouée (repère local : x de 0 à 3, z de 0 à 11), penchée et à demi brisée.
## Cité engloutie (15 × 15, au fond de la mer) : dallage de marbre, colonnes brisées en cercle,
## et un petit temple sans toit au centre, où dort le trésor.
static func sunken_plan(rng: RandomNumberGenerator) -> Dictionary:
	var out := {}
	for z in 15:
		for x in 15:
			if Vector2(x - 7, z - 7).length() < 7.2 and rng.randf() < 0.8:
				out[Vector3i(x, 0, z)] = "bloc_marbre" if (x + z) % 2 == 0 else "bloc_pierre_polie"
	for i in 10:
		var a := TAU * i / 10.0
		var c := Vector2i(roundi(7 + cos(a) * 6.0), roundi(7 + sin(a) * 6.0))
		var h := rng.randi_range(1, 5)
		for y in range(1, h + 1):
			out[Vector3i(c.x, y, c.y)] = "bloc_marbre"
		if h >= 4:
			out[Vector3i(c.x, h + 1, c.y)] = "bloc_pierre_polie"
	# le temple : quatre murs bas percés d'une porte, des marches
	for z in range(5, 10):
		for x in range(5, 10):
			var edge := x == 5 or x == 9 or z == 5 or z == 9
			if edge and not (z == 9 and x == 7):
				for y in range(1, 3 if rng.randf() < 0.75 else 2):
					out[Vector3i(x, y, z)] = "bloc_pierre_polie"
	for z in range(6, 9):
		for x in range(6, 9):
			out[Vector3i(x, 0, z)] = "bloc_marbre"
	out[Vector3i(7, 1, 10)] = "bloc_marbre"
	return out


static func shipwreck_plan(rng: RandomNumberGenerator) -> Dictionary:
	var out := {}
	for z in 12:
		var w := 1 if z < 2 or z > 9 else 2
		for x in range(2 - w, 2 + w):
			out[Vector3i(x, 0, z)] = "bloc_rondins"
			if x == 2 - w or x == 1 + w:
				out[Vector3i(x, 1, z)] = "bloc_planches"
				if z > 2 and z < 10 and rng.randf() < 0.7:
					out[Vector3i(x, 2, z)] = "bloc_planches"
	# mât brisé et une vergue tombée
	for y in range(1, 6):
		out[Vector3i(1, y, 5)] = "bloc_rondins"
	for z in range(3, 8):
		out[Vector3i(3, 1, z)] = "bloc_rondins"
	# la proue relevée
	out[Vector3i(1, 1, 11)] = "bloc_planches"
	out[Vector3i(1, 2, 11)] = "bloc_planches"
	return out
