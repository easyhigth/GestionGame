class_name CityPlans
extends RefCounted
## Plans des capitales des cinq nations, faites des mêmes blocs que le joueur, à l'échelle de vraies villes
## (une centaine à deux cents mètres de large), inspirées des cités du Seigneur des Anneaux :
## - Givre : Hrodgard, à la façon d'Edoras (colline, maisons longues, palissade, grand hall doré) ;
## - Sylvaë : Lothëlia, à la façon de Fondcombe (terrasses de pierre blanche, maisons claires, jardins) ;
## - Sables : Qasr-Ammar, ville du désert (remparts de grès, maisons à toit plat serrées, grand bazar, palais) ;
## - Karg : Gor-Karath, à la façon d'Isengard (enceinte noire hérissée, tour noire géante, forges) ;
## - Cendres : Minas Cendrys, à la façon de Minas Tirith (sept terrasses étagées, remparts, citadelle).
##
## Un plan : {"blocks": {Vector3i: id}, "relief": {Vector2i: hauteur en plus}, "stalls": [[Vector2i, métier]],
## "streets": [Vector2i], "gates": [Vector2i], "hall": Vector2i, "radius": int}
## Les clés sont relatives au centre de la ville ; y est compté depuis le sol de la ville (relief compris).

const CITIES := {
	"givre": {"name": "Hrodgard", "style": "edoras", "radius": 58, "population": 380,
		"races": ["humain", "nain", "lycan"], "regions": ["toundra", "montagnes"]},
	"sylvae": {"name": "Lothëlia", "style": "rivendell", "radius": 56, "population": 420,
		"races": ["elfe", "fee", "dryade"], "regions": ["bois_enchante", "foret"]},
	"sables": {"name": "Qasr-Ammar", "style": "harad", "radius": 60, "population": 900,
		"races": ["homme_lezard", "humain", "dragonide"], "regions": ["desert", "jungle"]},
	"karg": {"name": "Gor-Karath", "style": "isengard", "radius": 56, "population": 650,
		"races": ["orc", "gobelin", "hobgobelin", "ogre"], "regions": ["montagnes", "marais"]},
	"cendres": {"name": "Minas Cendrys", "style": "minas", "radius": 70, "population": 1200,
		"races": ["demon", "mort_vivant", "vampire", "oni"], "regions": ["volcan", "montagnes"]},
}
## Métiers des marchands et ce qu'ils vendent.
const TRADES := {
	"Forgeron": ["sword_iron", "iron_helmet", "iron_armor", "iron_ingot", "pioche_fer", "hache_fer"],
	"Épicier": ["pain", "viande_cuite", "poisson_grille", "baies", "ble"],
	"Herboriste": ["potion_soin", "potion_force", "potion_garde", "potion_celerite"],
	"Joaillier": ["gemme_rubis", "gemme_saphir", "gemme_emeraude", "gemme_topaze", "gemme_amethyste", "lingot_or"],
	"Maçon": ["bloc_pierre_polie", "bloc_briques", "bloc_tuiles", "bloc_verre", "bloc_marbre"],
	"Charpentier": ["bloc_planches", "bloc_rondins", "porte", "lit", "coffre", "lanterne"],
	"Tisserand": ["cape_red", "laine", "leather"],
}


static func _put(out: Dictionary, k: Vector3i, id: String) -> void:
	out[k] = id


## Rempart circulaire de rayon `r`, haut de `h`, avec des portes (angles en radians, ouvertures de 3 cases).
static func ring_wall(out: Dictionary, r: float, h: int, base: int, mat: String, trim: String, gates: Array, spikes := false) -> void:
	var ri := int(ceil(r)) + 1
	for z in range(-ri, ri + 1):
		for x in range(-ri, ri + 1):
			var d := Vector2(x, z).length()
			if absf(d - r) > 0.55:
				continue
			var a := atan2(float(z), float(x))
			var gate := false
			for g in gates:
				if absf(angle_difference(a, float(g))) * r < 1.6:
					gate = true
			for y in h:
				if gate and y < 3:
					continue
				_put(out, Vector3i(x, base + y, z), mat)
			if (x + z) % 2 == 0:
				_put(out, Vector3i(x, base + h, z), trim)
				if spikes:
					_put(out, Vector3i(x, base + h + 1, z), trim)


## Rempart carré (demi-côté `half`), portes au milieu des côtés choisis.
static func square_wall(out: Dictionary, half: int, h: int, base: int, mat: String, trim: String, gate_sides: Array) -> void:
	for i in range(-half, half + 1):
		for side in 4:
			var k: Vector2i = [Vector2i(i, -half), Vector2i(i, half), Vector2i(-half, i), Vector2i(half, i)][side]
			var gate: bool = side in gate_sides and absi(i) <= 1
			for y in h:
				if gate and y < 3:
					continue
				_put(out, Vector3i(k.x, base + y, k.y), mat)
			if i % 2 == 0:
				_put(out, Vector3i(k.x, base + h, k.y), trim)
	# tours d'angle
	for c in [Vector2i(-half, -half), Vector2i(half, -half), Vector2i(-half, half), Vector2i(half, half)]:
		tower(out, c, 2, h + 4, base, mat, trim)


## Tour carrée creuse (rayon `r`), couronnée de créneaux.
static func tower(out: Dictionary, c: Vector2i, r: int, h: int, base: int, mat: String, trim: String) -> void:
	for y in h:
		for x in range(-r, r + 1):
			for z in range(-r, r + 1):
				if absi(x) == r or absi(z) == r:
					_put(out, Vector3i(c.x + x, base + y, c.y + z), mat)
	for x in range(-r, r + 1):
		for z in range(-r, r + 1):
			_put(out, Vector3i(c.x + x, base + h, c.y + z), mat)
			if (absi(x) == r or absi(z) == r) and (x + z) % 2 == 0:
				_put(out, Vector3i(c.x + x, base + h + 1, c.y + z), trim)


## Maison (coin bas-gauche `o`, taille w × d, h étages de murs), porte du côté `door` (0 sud, 1 nord, 2 est, 3 ouest).
static func house(out: Dictionary, o: Vector2i, w: int, d: int, h: int, base: int, wall: String, post: String,
		roof: String, window: String, door: int, roof_kind := "pitched") -> void:
	for y in h:
		for x in w:
			for z in d:
				if x != 0 and x != w - 1 and z != 0 and z != d - 1:
					continue
				var corner := (x == 0 or x == w - 1) and (z == 0 or z == d - 1)
				var id := post if corner else wall
				var mid_x := x == w / 2
				var mid_z := z == d / 2
				if y < 2 and ((door == 0 and z == d - 1 and mid_x) or (door == 1 and z == 0 and mid_x) \
						or (door == 2 and x == w - 1 and mid_z) or (door == 3 and x == 0 and mid_z)):
					continue
				if y == 1 and not corner and window != "" and ((x == 0 or x == w - 1) and z % 3 == 1 or (z == 0 or z == d - 1) and x % 3 == 1):
					id = window
				_put(out, Vector3i(o.x + x, base + y, o.y + z), id)
	match roof_kind:
		"flat":
			for x in w:
				for z in d:
					_put(out, Vector3i(o.x + x, base + h, o.y + z), roof)
					if (x == 0 or x == w - 1 or z == 0 or z == d - 1) and (x + z) % 2 == 0:
						_put(out, Vector3i(o.x + x, base + h + 1, o.y + z), wall)
		"gable":
			# toit à deux pans le long de la plus grande longueur
			var along_x := w >= d
			var span := d if along_x else w
			for step in (span + 1) / 2:
				for i in (w if along_x else d):
					for side in [step, span - 1 - step]:
						var k := Vector3i(o.x + (i if along_x else side), base + h + step, o.y + (side if along_x else i))
						_put(out, k, roof)
		_:
			# toit en gradins
			var lx := 0
			var lz := 0
			var y := h
			while lx * 2 < w and lz * 2 < d:
				for x in range(lx, w - lx):
					for z in range(lz, d - lz):
						_put(out, Vector3i(o.x + x, base + y, o.y + z), roof)
				lx += 1
				lz += 1
				y += 1


## Étal de marché : quatre poteaux et un auvent (le marchand se tient devant).
static func stall(out: Dictionary, c: Vector2i, base: int, post: String, roof: String) -> void:
	for p in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		for y in 2:
			_put(out, Vector3i(c.x + p.x, base + y, c.y + p.y), post)
	for x in range(-1, 2):
		for z in range(-1, 2):
			_put(out, Vector3i(c.x + x, base + 2, c.y + z), roof)


## Plan complet d'une capitale.
static func plan(nation: String, rng: RandomNumberGenerator) -> Dictionary:
	var info: Dictionary = CITIES[nation]
	var out := {"blocks": {}, "relief": {}, "stalls": [], "streets": [], "gates": [], "hall": Vector2i.ZERO, "radius": int(info.radius)}
	match String(info.style):
		"edoras":
			_edoras(out, rng)
		"rivendell":
			_rivendell(out, rng)
		"harad":
			_harad(out, rng)
		"isengard":
			_isengard(out, rng)
		"minas":
			_minas(out, rng)
	return out


static func _relief_at(out: Dictionary, c: Vector2i) -> int:
	return int(out.relief.get(c, 0))


# ---------------------------------------------------------------- Hrodgard (Edoras)

static func _edoras(out: Dictionary, rng: RandomNumberGenerator) -> void:
	var R: int = out.radius
	var b: Dictionary = out.blocks
	# une colline en pente douce (marches de 0,5 m arrondies au mètre pour les blocs)
	for z in range(-R, R + 1):
		for x in range(-R, R + 1):
			var d := Vector2(x, z).length()
			if d <= R:
				out.relief[Vector2i(x, z)] = int(floor(clampf((R - 6 - d) / float(R - 6), 0.0, 1.0) * 10.0))
	# palissade de rondins pointus, porte au sud
	ring_wall(b, R - 2, 3, 0, "bloc_rondins", "bloc_rondins", [PI / 2.0], true)
	out.gates.append(Vector2i(0, R - 2))
	# grand hall doré au sommet (Meduseld)
	var top := _relief_at(out, Vector2i.ZERO)
	house(b, Vector2i(-5, -10), 11, 21, 5, top, "bloc_rondins", "bloc_planches", "bloc_marbre_dore", "", 0, "gable")
	out.hall = Vector2i(0, 12)
	# maisons longues tout autour, en anneaux, porte vers le centre
	for ring in [[20, 10], [32, 14], [44, 18]]:
		var r: int = ring[0]
		var n: int = ring[1]
		for i in n:
			var a := TAU * (i + rng.randf_range(-0.15, 0.15)) / n
			if absf(angle_difference(a, PI / 2.0)) < 0.25:
				continue
			var c := Vector2i(roundi(cos(a) * r), roundi(sin(a) * r))
			var base := _relief_at(out, c)
			var along := absf(cos(a)) > absf(sin(a))
			var w := 5 if along else 7
			var d := 7 if along else 5
			var door := (3 if cos(a) > 0 else 2) if along else (1 if sin(a) > 0 else 0)
			house(b, c - Vector2i(w / 2, d / 2), w, d, 3, base, "bloc_rondins", "bloc_rondins", "bloc_chaume", "", door, "gable")
	# une rue qui monte du portail au hall, et des points de passage
	for z in range(-10, R - 2):
		out.streets.append(Vector2i(0, z))
	for r in [14, 26, 38, 50]:
		for i in 16:
			var a := TAU * i / 16.0
			out.streets.append(Vector2i(roundi(cos(a) * r), roundi(sin(a) * r)))
	# marché devant le portail
	for i in 6:
		var c := Vector2i(-12 + i * 5, R - 12)
		stall(b, c, _relief_at(out, c), "bloc_rondins", "bloc_chaume")
		out.stalls.append([c + Vector2i(0, 2), TRADES.keys()[i % TRADES.size()]])


# ---------------------------------------------------------------- Lothëlia (Fondcombe)

static func _rivendell(out: Dictionary, rng: RandomNumberGenerator) -> void:
	var R: int = out.radius
	var b: Dictionary = out.blocks
	# trois terrasses de pierre blanche
	for z in range(-R, R + 1):
		for x in range(-R, R + 1):
			var d := Vector2(x, z).length()
			if d <= R:
				out.relief[Vector2i(x, z)] = 8 if d < 16 else (4 if d < 34 else 0)
	for rr in [16, 34]:
		var h := 8 if rr == 16 else 4
		for z in range(-rr - 1, rr + 2):
			for x in range(-rr - 1, rr + 2):
				if absf(Vector2(x, z).length() - rr) <= 0.55:
					for y in range(0, h):
						if y >= h - 4 and y < h:
							_put(b, Vector3i(x, y, z), "bloc_marbre")
					_put(b, Vector3i(x, h, z), "bloc_pierre_polie" if (x + z) % 2 == 0 else "bloc_verre")
	# escaliers : on les laisse en pentes de terrain (rampe au sud)
	for z in range(14, 37):
		for x in range(-2, 3):
			var d := float(z)
			out.relief[Vector2i(x, z)] = int(clampf(8.0 - (d - 14.0) * 8.0 / 22.0, 0.0, 8.0))
	# la maison du seigneur (grande, à toit de tuiles et grandes fenêtres)
	house(b, Vector2i(-7, -7), 15, 13, 5, 8, "bloc_marbre", "bloc_pierre_polie", "bloc_tuiles", "bloc_verre", 0, "steps")
	out.hall = Vector2i(0, 7)
	# demeures claires sur les terrasses
	for ring in [[24, 9, 4], [44, 14, 0]]:
		for i in ring[1]:
			var a := TAU * (i + 0.5) / ring[1]
			if absf(angle_difference(a, PI / 2.0)) < 0.2:
				continue
			var c := Vector2i(roundi(cos(a) * ring[0]), roundi(sin(a) * ring[0]))
			house(b, c - Vector2i(3, 2), 7, 5, 3, int(ring[2]), "bloc_marbre", "bloc_pierre_polie", "bloc_tuiles", "bloc_verre",
				[3, 2][int(cos(a) > 0)] if absf(cos(a)) > 0.7 else [1, 0][int(sin(a) < 0)], "steps")
	for r in [10, 24, 44]:
		for i in 14:
			var a := TAU * i / 14.0
			out.streets.append(Vector2i(roundi(cos(a) * r), roundi(sin(a) * r)))
	for i in 5:
		var c := Vector2i(-10 + i * 5, 40)
		stall(b, c, 0, "bloc_pierre_polie", "bloc_tuiles")
		out.stalls.append([c + Vector2i(0, 2), TRADES.keys()[(i + 2) % TRADES.size()]])
	out.gates.append(Vector2i(0, R))


# ---------------------------------------------------------------- Qasr-Ammar (ville du désert)

static func _harad(out: Dictionary, rng: RandomNumberGenerator) -> void:
	var R: int = out.radius
	var b: Dictionary = out.blocks
	var half := R - 4
	square_wall(b, half, 6, 0, "bloc_sable", "bloc_pierre_polie", [0, 1, 2, 3])
	out.gates.append_array([Vector2i(0, -half), Vector2i(0, half), Vector2i(-half, 0), Vector2i(half, 0)])
	# palais au nord, coiffé d'un dôme doré
	house(b, Vector2i(-8, -half + 4), 17, 15, 6, 0, "bloc_sable", "bloc_pierre_polie", "bloc_marbre_dore", "", 0, "steps")
	out.hall = Vector2i(0, -half + 20)
	# maisons à toit plat le long de rues en damier
	for gz in range(-half + 22, half - 4, 9):
		for gx in range(-half + 3, half - 6, 9):
			if absi(gx + 3) < 14 and absi(gz + 3) < 14:
				continue    # le grand bazar au centre
			if rng.randf() < 0.12:
				continue
			var w := rng.randi_range(5, 7)
			var d := rng.randi_range(5, 6)
			house(b, Vector2i(gx, gz), w, d, rng.randi_range(3, 4), 0, "bloc_sable", "bloc_sable", "bloc_sable", "", rng.randi() % 4, "flat")
	for gz in range(-half + 2, half, 9):
		for x in range(-half + 2, half - 1, 3):
			out.streets.append(Vector2i(x, gz - 2))
	# le bazar : une dizaine d'étals
	var trades := TRADES.keys()
	var k := 0
	for z in [-9, -3, 3, 9]:
		for x in [-9, -3, 3, 9]:
			if rng.randf() < 0.25:
				continue
			stall(b, Vector2i(x, z), 0, "bloc_rondins", "bloc_planches")
			out.stalls.append([Vector2i(x, z + 2), trades[k % trades.size()]])
			k += 1


# ---------------------------------------------------------------- Gor-Karath (Isengard)

static func _isengard(out: Dictionary, rng: RandomNumberGenerator) -> void:
	var R: int = out.radius
	var b: Dictionary = out.blocks
	ring_wall(b, R - 3, 7, 0, "bloc_marbre_noir", "bloc_marbre_noir", [PI / 2.0], true)
	out.gates.append(Vector2i(0, R - 3))
	# la tour noire : 9 × 9, haute de 34, quatre cornes au sommet
	tower(b, Vector2i.ZERO, 4, 34, 0, "bloc_marbre_noir", "bloc_marbre_noir")
	for c in [Vector2i(-4, -4), Vector2i(4, -4), Vector2i(-4, 4), Vector2i(4, 4)]:
		for y in 6:
			_put(b, Vector3i(c.x, 35 + y, c.y), "bloc_marbre_noir")
	# porte de la tour
	for y in 3:
		b.erase(Vector3i(0, y, 4))
	out.hall = Vector2i(0, 7)
	# huttes et forges autour, dans le désordre
	for i in 26:
		var a := rng.randf() * TAU
		var r := rng.randf_range(14.0, R - 9.0)
		var c := Vector2i(roundi(cos(a) * r), roundi(sin(a) * r))
		if absi(c.x) < 4 and c.y > 0:
			continue
		if rng.randf() < 0.35:
			house(b, c, 5, 5, 3, 0, "bloc_briques", "bloc_marbre_noir", "bloc_ardoise", "", rng.randi() % 4, "flat")
		else:
			house(b, c, 5, 5, 2, 0, "bloc_pierre_brute", "bloc_rondins", "bloc_chaume", "", rng.randi() % 4, "steps")
	for r in [10, 22, 34, 46]:
		for i in 16:
			var a := TAU * i / 16.0
			out.streets.append(Vector2i(roundi(cos(a) * r), roundi(sin(a) * r)))
	for i in 4:
		var c := Vector2i(-8 + i * 5, R - 12)
		stall(b, c, 0, "bloc_rondins", "bloc_ardoise")
		out.stalls.append([c + Vector2i(0, 2), ["Forgeron", "Épicier", "Charpentier", "Herboriste"][i]])


# ---------------------------------------------------------------- Minas Cendrys (Minas Tirith)

static func _minas(out: Dictionary, rng: RandomNumberGenerator) -> void:
	var R: int = out.radius
	var b: Dictionary = out.blocks
	var tiers := 7
	var step := float(R) / tiers
	# sept terrasses qui montent vers la citadelle
	for z in range(-R, R + 1):
		for x in range(-R, R + 1):
			var d := Vector2(x, z).length()
			if d <= R:
				out.relief[Vector2i(x, z)] = (tiers - 1 - mini(tiers - 1, int(d / step))) * 4
	# un rempart à chaque terrasse, la porte change de côté à chaque niveau
	for t in range(1, tiers):
		var r := t * step
		var base := (tiers - 1 - t) * 4
		var gate := PI / 2.0 if t % 2 == 1 else -PI / 2.0
		ring_wall(b, r, 4 + 2, base, "bloc_marbre_noir" if t > 3 else "bloc_pierre_polie", "bloc_pierre_polie", [gate])
		out.gates.append(Vector2i(roundi(cos(gate) * r), roundi(sin(gate) * r)))
	# rampes entre les terrasses, au droit des portes
	for t in range(1, tiers):
		var r := t * step
		var gate := 1 if t % 2 == 1 else -1
		var hi := (tiers - 1 - t + 1) * 4
		for k in int(step):
			for x in range(-1, 2):
				var c := Vector2i(x, gate * roundi(r - k))
				out.relief[c] = clampi(hi - 4 + int(4.0 * k / step), 0, 40)
	# la citadelle et sa tour blanche
	var top := (tiers - 1) * 4
	tower(b, Vector2i.ZERO, 3, 24, top, "bloc_pierre_polie", "bloc_marbre_dore")
	out.hall = Vector2i(0, 5)
	# maisons de pierre le long de chaque terrasse
	for t in range(1, tiers):
		var r := (t - 0.5) * step
		var base := (tiers - t) * 4
		var n := int(TAU * r / 9.0)
		for i in n:
			var a := TAU * (i + 0.5) / n
			if absf(angle_difference(a, PI / 2.0)) < 0.18 or absf(angle_difference(a, -PI / 2.0)) < 0.18:
				continue
			var c := Vector2i(roundi(cos(a) * r), roundi(sin(a) * r))
			house(b, c - Vector2i(2, 2), 5, 5, 3, base, "bloc_pierre_polie" if t < 4 else "bloc_marbre_noir", "bloc_briques",
				"bloc_ardoise", "bloc_verre", rng.randi() % 4, "steps")
		for i in 12:
			var a := TAU * i / 12.0
			out.streets.append(Vector2i(roundi(cos(a) * r), roundi(sin(a) * r)))
	# le marché sur la terrasse basse, près de la grande porte
	for i in 7:
		var c := Vector2i(-15 + i * 5, R - 5)
		stall(b, c, 0, "bloc_briques", "bloc_ardoise")
		out.stalls.append([c + Vector2i(0, -2), TRADES.keys()[i % TRADES.size()]])
