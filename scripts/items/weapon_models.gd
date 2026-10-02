class_name WeaponModels
extends RefCounted
## Modèles 3D en blocs des armes de l'arsenal (voir Arsenal), fabriqués à la demande.
## Mêmes conventions que tools/voxel_equipment_generator.py : 1 unité = 5 cm, l'arme est tenue dans la
## main gauche (nœud « HandL »), le manche vers le bas et la pointe vers +Y.
## Chaque arme : un type (épée, hache...), un matériau (couleurs) et un design (0 à 3 : forme de la garde,
## de la lame, ornements). Les maillages sont mis en cache.

const UNIT := 0.05
const WOOD := Color("8a6238")
const WOOD_D := Color("6a4428")
const LEATHER := Color("7a4a2a")
const LEATHER_D := Color("5a341c")
const GOLD := Color("d8b04a")
const CLOTH := Color("a02a2a")

static var _cache := {}
static var _mat: StandardMaterial3D
static var _glow_mats := {}

var _boxes: Array = []
## Couleurs du matériau : principale (lame, tête), sombre, claire ; accent (garde) ; gemme.
var c_main: Color
var c_dark: Color
var c_light: Color
var c_accent: Color
var c_gem: Color
var c_grip: Color
var glowing := false


## Le maillage d'une arme (type, matériau, design).
static func mesh(type: String, mat: Dictionary, design: int) -> ArrayMesh:
	var key := "%s|%s|%d" % [type, mat.id, design]
	if _cache.has(key):
		return _cache[key]
	var b := WeaponModels.new()
	b.c_main = mat.main
	b.c_dark = mat.dark
	b.c_light = mat.light
	b.c_accent = mat.get("accent", GOLD)
	b.c_gem = mat.get("gem", Color("6ad8ff"))
	b.c_grip = mat.get("grip", LEATHER_D)
	b.glowing = mat.get("glow", false)
	if b.has_method("_" + type):
		b.call("_" + type, design)
	else:
		b._epee(design)
	var m := b._build()
	_cache[key] = m
	return m


func box(w: float, h: float, d: float, c: Color, x: float, y: float, z: float, rx := 0.0, rz := 0.0, glow := false) -> void:
	_boxes.append([Vector3(w, h, d), c, Vector3(x, y, z), Vector3(rx, 0, rz), glow])


func gem(s: float, x: float, y: float, z: float) -> void:
	box(s, s, s, c_gem, x, y, z, 0.6, 0.6, true)


# ---------------------------------------------------------------- construction du maillage

const _FACES := [
	[Vector3(0, 1, 0), 1.0], [Vector3(0, -1, 0), 0.62], [Vector3(1, 0, 0), 0.86],
	[Vector3(-1, 0, 0), 0.8], [Vector3(0, 0, 1), 0.92], [Vector3(0, 0, -1), 0.74],
]


func _build() -> ArrayMesh:
	var am := ArrayMesh.new()
	for pass_glow in [false, true]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var n := 0
		for b in _boxes:
			var glow: bool = b[4] or (glowing and b[1] == c_light)
			if glow != pass_glow:
				continue
			n += 1
			var size: Vector3 = b[0] * 0.5
			var basis := Basis.from_euler(b[3])
			var center: Vector3 = b[2]
			for f in _FACES:
				var nrm: Vector3 = f[0]
				var u := Vector3(nrm.y, nrm.z, nrm.x)
				var v := nrm.cross(u)
				var col: Color = (b[1] as Color) * float(f[1]) if not glow else b[1]
				col.a = 1.0
				var corners := []
				for s in [[-1, -1], [1, -1], [1, 1], [-1, 1]]:
					var p: Vector3 = nrm + u * s[0] + v * s[1]
					corners.append((center + basis * (p * size)) * UNIT)
				var wn := (basis * nrm).normalized()
				for i in [0, 2, 1, 0, 3, 2]:
					st.set_color(col)
					st.set_normal(wn)
					st.add_vertex(corners[i])
		if n == 0:
			continue
		st.commit(am)
		var surf := am.get_surface_count() - 1
		am.surface_set_material(surf, _glow_material() if pass_glow else _base_material())
	return am


static func _base_material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.roughness = 0.75
		_mat.metallic = 0.15
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _mat


static func _glow_material() -> StandardMaterial3D:
	if not _glow_mats.has("g"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow_mats["g"] = m
	return _glow_mats["g"]


# ---------------------------------------------------------------- pièces communes

func _grip(len := 5.0, y := 0.0) -> void:
	box(1.2, len, 1.2, c_grip, 0, y, 0)
	for i in int(len / 1.6):
		box(1.3, 0.3, 1.3, c_grip.darkened(0.25), 0, y - len / 2.0 + 0.8 + i * 1.6, 0)


func _pommel(design: int, y: float) -> void:
	match design:
		0:
			box(1.8, 1.6, 1.8, c_accent, 0, y, 0)
		1:
			box(2.2, 2.2, 2.2, c_dark, 0, y, 0, 0.78, 0.78)
		2:
			box(1.4, 1.4, 1.4, c_accent, 0, y, 0)
			box(0.6, 1.2, 0.6, c_accent, 0, y - 1.1, 0)
		_:
			box(2.0, 1.8, 2.0, c_accent, 0, y, 0)
			gem(1.0, 0, y, 1.0)


func _shaft(len: float, y: float, w := 1.1, col := WOOD) -> void:
	box(w, len, w, col, 0, y, 0)


# ---------------------------------------------------------------- types

func _epee(d: int) -> void:
	_grip()
	_pommel(d, -3.2)
	var blade_w: float = [2.2, 3.0, 2.0, 2.4][d]
	var blade_l: float = [17.0, 16.0, 18.0, 19.0][d]
	match d:
		0:
			box(6.4, 1.4, 2, c_dark, 0, 3.2, 0)
		1:
			box(7.4, 1.6, 2.2, c_dark, 0, 3.2, 0)
			for s in [-1, 1]:
				box(1.4, 2.4, 1.6, c_dark, s * 3.6, 4.2, 0)
		2:
			box(5.0, 1.2, 1.8, c_accent, 0, 3.2, 0)
			for s in [-1, 1]:
				box(1.2, 1.2, 1.2, c_accent, s * 2.8, 2.4, 0)
		_:
			box(7.0, 1.4, 2.0, c_accent, 0, 3.2, 0)
			for s in [-1, 1]:
				box(1.6, 2.6, 1.6, c_accent, s * 3.8, 4.4, 0, 0, s * 0.4)
			gem(1.2, 0, 3.2, 1.1)
	var y0 := 3.9 + blade_l / 2.0
	box(blade_w, blade_l, 0.8, c_light, 0, y0, 0)
	box(0.6, blade_l - 2.0, 0.9, c_main, 0, y0 - 0.8, 0)
	if d == 2:
		for i in 4:
			box(0.7, 0.9, 0.7, c_light, blade_w / 2.0 + 0.2, 6.0 + i * 3.2, 0)
	box(blade_w * 0.6, 1.6, 0.8, c_light, 0, y0 + blade_l / 2.0 + 0.8, 0)
	box(0.6, 1.2, 0.8, c_light.lightened(0.2), 0, y0 + blade_l / 2.0 + 2.0, 0)


func _espadon(d: int) -> void:
	_grip(9.0, 1.0)
	_pommel(d, -4.0)
	var gw: float = [10.0, 12.0, 9.0, 11.0][d]
	box(gw, 1.8, 2.4, c_dark if d < 2 else c_accent, 0, 6.2, 0)
	if d == 1:
		for s in [-1, 1]:
			box(1.6, 3.0, 2.0, c_dark, s * gw / 2.0, 7.2, 0)
	if d == 3:
		gem(1.6, 0, 6.2, 1.4)
		for s in [-1, 1]:
			box(1.4, 1.4, 1.4, c_accent, s * (gw / 2.0 + 0.6), 5.4, 0, 0.78, 0.78)
	var bl: float = [26.0, 24.0, 28.0, 27.0][d]
	var bw: float = [3.0, 3.8, 2.6, 3.2][d]
	var y0 := 7.1 + bl / 2.0
	box(bw, bl, 1.0, c_light, 0, y0, 0)
	box(0.8, bl - 3.0, 1.1, c_main, 0, y0 - 1.0, 0)
	if d == 2:
		# lame flamboyante
		for i in 6:
			box(0.8, 1.6, 0.9, c_light, (bw / 2.0 + 0.3) * (1 if i % 2 == 0 else -1), 9.0 + i * 3.8, 0)
	box(bw * 0.6, 2.0, 1.0, c_light, 0, y0 + bl / 2.0 + 1.0, 0)


func _sabre(d: int) -> void:
	_grip()
	_pommel(d, -3.2)
	match d:
		1:
			# garde en coquille
			box(1.2, 5.0, 2.4, c_accent, 1.8, 0.8, 0)
			box(4.0, 1.2, 2.4, c_accent, 0.4, 3.2, 0)
		2:
			box(3.0, 1.2, 1.8, c_dark, 0, 3.2, 0)
		_:
			box(5.0, 1.2, 2.0, c_accent if d == 3 else c_dark, 0, 3.2, 0)
	# lame courbe : segments décalés
	var n := 6
	for i in n:
		var t := float(i) / n
		var x := t * t * 3.0
		box(2.6 - t * 0.6, 3.2, 0.7, c_light, x, 5.4 + i * 3.0, 0, 0, -0.1 - t * 0.15)
		box(0.5, 3.0, 0.8, c_main, x - 0.8, 5.4 + i * 3.0, 0, 0, -0.1 - t * 0.15)
	if d == 3:
		gem(1.0, 0, 3.2, 1.0)


func _katana(d: int) -> void:
	_grip(8.0, 1.0)
	box(1.6, 1.0, 1.6, c_dark, 0, -3.4, 0)
	# tsuba (garde ronde)
	var tsw: float = [3.4, 4.2, 3.0, 3.8][d]
	box(tsw, 0.7, tsw, c_accent if d >= 2 else c_dark, 0, 5.4, 0)
	if d == 1:
		box(tsw + 0.6, 0.4, 0.8, c_accent, 0, 5.4, 0)
	for i in 8:
		var t := float(i) / 8.0
		box(1.8, 3.0, 0.6, c_light, t * t * 2.2, 7.4 + i * 2.8, 0, 0, -t * 0.12)
		box(0.4, 2.8, 0.7, c_main.lightened(0.3), t * t * 2.2 - 0.6, 7.4 + i * 2.8, 0, 0, -t * 0.12)
	if d == 3:
		box(0.8, 3.0, 0.4, CLOTH, 0.9, -1.8, 0)


func _rapiere(d: int) -> void:
	_grip(4.4)
	_pommel(d, -3.0)
	# garde à anneaux
	box(5.4, 0.8, 1.2, c_accent, 0, 2.8, 0)
	box(0.8, 5.0, 0.8, c_accent, 2.6, 0.6, 0)
	if d == 1 or d == 3:
		box(0.6, 3.6, 3.6, c_accent, 0, 2.2, 0, 0, 0)
	if d == 2:
		box(3.2, 0.6, 3.2, c_dark, 0, 3.4, 0)
	box(1.0, 22.0, 0.6, c_light, 0, 14.8, 0)
	box(0.5, 2.0, 0.6, c_light, 0, 26.8, 0)
	if d == 3:
		gem(0.9, 0, 2.8, 0.8)


func _dague(d: int) -> void:
	box(1.1, 3.6, 1.1, c_grip, 0, 0, 0)
	box(1.4, 1.2, 1.4, c_accent, 0, -2.2, 0)
	match d:
		0:
			box(3.4, 1.0, 1.4, c_dark, 0, 2.2, 0)
			box(1.6, 6.0, 0.7, c_light, 0, 5.6, 0)
		1:
			# poignard large
			box(4.0, 1.2, 1.6, c_dark, 0, 2.2, 0)
			box(2.4, 5.0, 0.8, c_light, 0, 5.2, 0)
			box(1.4, 1.6, 0.8, c_light, 0, 8.4, 0)
		2:
			# lame recourbée (kriss)
			box(2.8, 0.8, 1.2, c_accent, 0, 2.2, 0)
			for i in 4:
				box(1.4, 2.0, 0.7, c_light, 0.5 * (1 if i % 2 == 0 else -1), 3.8 + i * 1.8, 0)
		_:
			box(3.0, 1.0, 1.4, c_accent, 0, 2.2, 0)
			gem(0.9, 0, 2.2, 0.8)
			box(1.2, 7.0, 0.6, c_light, 0, 6.1, 0)
	box(0.8, 1.2, 0.7, c_light, 0, 9.2 if d != 1 else 9.6, 0)


func _hache(d: int) -> void:
	_shaft(17.0, 4.5)
	box(1.6, 1.4, 1.6, c_grip, 0, 0.5, 0)
	box(1.8, 5.0, 2.0, c_dark, 0, 11.5, 0)
	match d:
		0:
			box(4.6, 6.0, 0.9, c_main, 2.8, 11.5, 0)
			box(1.2, 7.6, 1.0, c_light, 5.4, 11.5, 0)
		1:
			# barbue
			box(4.0, 5.0, 0.9, c_main, 2.6, 12.0, 0)
			box(1.4, 9.0, 1.0, c_light, 5.0, 10.6, 0)
		2:
			box(3.6, 4.6, 0.9, c_main, 2.4, 11.5, 0)
			box(1.0, 6.0, 1.0, c_light, 4.6, 11.5, 0)
			box(2.4, 1.6, 1.0, c_dark, -1.8, 11.5, 0)
			box(1.0, 1.0, 1.0, c_light, -3.2, 11.5, 0)
		_:
			box(4.8, 6.4, 0.9, c_main, 2.8, 11.5, 0)
			box(1.2, 8.0, 1.0, c_light, 5.5, 11.5, 0)
			gem(1.0, 0, 11.5, 1.1)
			box(1.0, 2.0, 1.0, c_accent, 0, 14.6, 0)


func _hache_bataille(d: int) -> void:
	_shaft(24.0, 6.0, 1.3)
	box(1.8, 2.0, 1.8, c_grip, 0, -0.5, 0)
	box(2.0, 6.0, 2.2, c_dark, 0, 15.5, 0)
	for s in [-1, 1]:
		var w: float = [5.4, 6.0, 4.6, 5.8][d]
		box(w, 7.0 if d != 1 else 8.4, 1.0, c_main, s * (w / 2.0 + 0.8), 15.5, 0)
		box(1.4, 8.6 if d != 1 else 10.0, 1.1, c_light, s * (w + 1.0), 15.5, 0)
		if d == 2:
			box(1.0, 1.0, 1.0, c_light, s * (w + 1.0), 20.4, 0)
	box(1.2, 3.0, 1.2, c_light, 0, 20.0, 0)
	if d == 3:
		gem(1.4, 0, 15.5, 1.3)


func _marteau(d: int) -> void:
	_shaft(20.0, 5.0, 1.3)
	box(1.8, 1.6, 1.8, c_grip, 0, 0, 0)
	match d:
		0:
			box(6.4, 4.0, 3.6, c_main, 0, 15.6, 0)
			for s in [-1, 1]:
				box(1.0, 4.6, 4.2, c_dark, s * 3.4, 15.6, 0)
		1:
			# masse lourde carrée
			box(7.6, 5.4, 5.0, c_main, 0, 16.0, 0)
			box(8.0, 1.0, 5.4, c_dark, 0, 16.0, 0)
		2:
			# marteau de guerre à bec
			box(4.4, 3.4, 3.2, c_main, 0.8, 15.6, 0)
			box(4.0, 1.6, 1.4, c_light, -2.6, 15.6, 0, 0, 0.25)
		_:
			box(6.8, 4.4, 4.0, c_main, 0, 15.6, 0)
			for s in [-1, 1]:
				box(1.2, 5.0, 4.6, c_accent, s * 3.6, 15.6, 0)
			gem(1.4, 0, 15.6, 2.0)
	box(1.6, 1.6, 1.6, c_accent, 0, 18.6, 0)


func _masse(d: int) -> void:
	_shaft(14.0, 3.0)
	box(1.5, 1.4, 1.5, c_grip, 0, -2.6, 0)
	match d:
		0:
			box(3.6, 4.0, 3.6, c_main, 0, 11.0, 0)
			for a in 4:
				box(1.0, 3.6, 1.0, c_light, cos(a * PI / 2) * 1.9, 11.0, sin(a * PI / 2) * 1.9)
		1:
			# masse à ailettes
			for a in 6:
				var ang := a * TAU / 6.0
				box(0.6, 4.6, 2.0, c_main, cos(ang) * 1.6, 11.0, sin(ang) * 1.6, 0, 0)
			box(1.6, 5.0, 1.6, c_dark, 0, 11.0, 0)
		2:
			box(3.2, 3.2, 3.2, c_main, 0, 11.0, 0, 0.78, 0.78)
		_:
			box(3.8, 4.2, 3.8, c_main, 0, 11.0, 0)
			gem(1.2, 0, 13.4, 0)
			box(4.2, 0.8, 4.2, c_accent, 0, 9.0, 0)


func _morgenstern(d: int) -> void:
	_shaft(15.0, 3.5)
	box(1.5, 1.4, 1.5, c_grip, 0, -2.6, 0)
	var r: float = [2.4, 2.8, 2.0, 2.6][d]
	box(r * 2.0, r * 2.0, r * 2.0, c_main, 0, 13.0, 0)
	for v in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1),
			Vector3(0.7, 0.7, 0), Vector3(-0.7, 0.7, 0), Vector3(0.7, -0.7, 0), Vector3(-0.7, -0.7, 0)]:
		box(0.8, 0.8, 0.8, c_light, v.x * (r + 0.6), 13.0 + v.y * (r + 0.6), v.z * (r + 0.6))
	if d == 1:
		box(r * 2.2, 0.8, r * 2.2, c_dark, 0, 13.0, 0)
	if d == 3:
		gem(1.2, 0, 13.0, r + 0.2)


func _lance(d: int) -> void:
	_shaft(30.0, 9.0, 1.0)
	box(1.6, 1.6, 1.6, c_grip, 0, 22.4, 0)
	match d:
		0:
			box(2.4, 1.4, 1.2, c_main, 0, 24.2, 0)
			box(1.8, 2.0, 1.0, c_light, 0, 26.0, 0)
			box(1.0, 2.0, 0.8, c_light, 0, 28.0, 0)
		1:
			# feuille large
			box(3.4, 4.0, 0.9, c_light, 0, 25.6, 0)
			box(2.0, 2.4, 0.8, c_light, 0, 28.6, 0)
			box(0.8, 1.6, 0.8, c_light, 0, 30.4, 0)
		2:
			# trident
			box(5.0, 1.0, 1.0, c_main, 0, 24.0, 0)
			for s in [-2, 0, 2]:
				box(0.8, 4.0 if s == 0 else 3.2, 0.8, c_light, s, 26.6 if s == 0 else 26.2, 0)
		_:
			box(2.6, 1.6, 1.4, c_accent, 0, 24.2, 0)
			box(2.0, 3.0, 1.0, c_light, 0, 26.6, 0)
			box(1.0, 2.4, 0.8, c_light, 0, 29.2, 0)
			gem(1.0, 0, 24.2, 1.0)
	box(0.6, 3.0, 0.4, CLOTH if d != 3 else c_accent, 0.9, 21.0, 0)


func _hallebarde(d: int) -> void:
	_shaft(32.0, 10.0, 1.2)
	box(1.6, 1.6, 1.6, c_grip, 0, -4.0, 0)
	box(1.2, 4.0, 1.0, c_light, 0, 28.0, 0)
	box(1.8, 3.0, 1.6, c_dark, 0, 24.0, 0)
	match d:
		0:
			box(4.2, 5.6, 0.9, c_main, 2.6, 24.0, 0)
			box(1.0, 6.6, 1.0, c_light, 4.8, 24.0, 0)
			box(2.6, 1.0, 0.9, c_main, -1.8, 24.0, 0)
		1:
			# guisarme : crochet
			box(3.6, 4.6, 0.9, c_main, 2.2, 24.0, 0)
			box(1.0, 3.0, 0.9, c_light, 4.0, 26.6, 0, 0, -0.4)
			box(3.0, 1.0, 0.9, c_light, -2.0, 24.6, 0, 0, 0.3)
		2:
			# fauchard : grande lame
			box(3.0, 9.0, 0.9, c_main, 1.6, 26.0, 0)
			box(0.8, 9.0, 1.0, c_light, 3.2, 26.0, 0)
		_:
			for s in [-1, 1]:
				box(3.6, 5.0, 0.9, c_main, s * 2.4, 24.0, 0)
				box(1.0, 6.0, 1.0, c_light, s * 4.4, 24.0, 0)
			gem(1.0, 0, 24.0, 1.0)


func _faux(d: int) -> void:
	_shaft(30.0, 9.0, 1.1, WOOD_D)
	box(1.4, 1.4, 1.4, c_grip, 0, 6.0, 0)
	box(2.0, 2.4, 2.0, c_dark, 0, 24.0, 0)
	var n: int = [6, 7, 5, 7][d]
	for i in n:
		var t := float(i) / n
		box(3.4, 2.4 - t * 1.2, 0.8, c_main, -2.0 - i * 2.6, 24.6 - t * t * 5.0, 0, 0, 0.1 + t * 0.4)
		box(3.4, 0.7, 0.9, c_light, -2.0 - i * 2.6, 23.5 - t * t * 5.0, 0, 0, 0.1 + t * 0.4)
	if d == 1:
		box(2.0, 1.0, 0.8, c_main, 1.8, 24.0, 0)
	if d == 3:
		gem(1.2, 0, 24.0, 1.2)
		box(1.0, 3.0, 1.0, c_accent, 0, 26.6, 0)


func _baton(d: int) -> void:
	_shaft(30.0, 9.0, 1.0, c_grip.lerp(WOOD, 0.5))
	match d:
		0:
			for s in [-1, 1]:
				box(0.8, 3.0, 0.8, c_dark, s * 1.1, 25.0, 0, 0, -s * 0.4)
			box(2.8, 2.8, 2.8, c_gem, 0, 27.0, 0, 0.6, 0.6, true)
		1:
			# crosse en spirale
			for i in 5:
				var a := i * 0.9
				box(1.0, 1.0, 1.0, c_dark, cos(a) * 1.8, 24.6 + i * 0.9, sin(a) * 1.8)
			box(2.0, 2.0, 2.0, c_gem, 0, 26.0, 0, 0.6, 0.6, true)
		2:
			# bâton noueux
			for i in 4:
				box(1.6, 1.4, 1.6, c_dark, 0, 6.0 + i * 6.0, 0)
			box(3.2, 3.2, 3.2, c_main, 0, 25.6, 0, 0.3, 0.3)
			box(1.6, 1.6, 1.6, c_gem, 0, 28.2, 0, 0.6, 0.6, true)
		_:
			box(1.4, 1.2, 1.4, c_accent, 0, 23.4, 0)
			for a in 4:
				box(0.7, 4.0, 0.7, c_accent, cos(a * PI / 2) * 1.6, 26.0, sin(a * PI / 2) * 1.6)
			box(2.6, 2.6, 2.6, c_gem, 0, 27.0, 0, 0.6, 0.6, true)
			box(1.2, 1.2, 1.2, Color.WHITE, 0, 27.0, 0, 0.6, 0.6, true)


func _sceptre(d: int) -> void:
	_shaft(14.0, 3.0, 1.0, c_main)
	box(1.4, 1.4, 1.4, c_accent, 0, -4.2, 0)
	box(2.2, 1.0, 2.2, c_accent, 0, 10.2, 0)
	match d:
		0:
			box(2.4, 2.4, 2.4, c_gem, 0, 12.4, 0, 0.6, 0.6, true)
		1:
			# couronne
			box(3.6, 1.0, 3.6, c_accent, 0, 11.4, 0)
			for a in 4:
				box(0.8, 2.0, 0.8, c_accent, cos(a * PI / 2) * 1.6, 12.8, sin(a * PI / 2) * 1.6)
			gem(1.6, 0, 12.6, 0)
		2:
			# croissant
			for i in 5:
				var a := -0.9 + i * 0.45
				box(1.0, 1.4, 1.0, c_light, sin(a) * 2.4, 12.4 + cos(a) * 2.4, 0)
			gem(1.2, 0, 12.0, 0)
		_:
			box(1.2, 4.0, 1.2, c_accent, 0, 12.6, 0)
			box(4.0, 1.2, 1.2, c_accent, 0, 13.0, 0)
			gem(1.8, 0, 15.2, 0)


func _arc(d: int) -> void:
	box(1.2, 4.0, 1.4, c_grip, 0, 0, 0)
	var segs: int = [7, 8, 6, 8][d]
	for s in [-1, 1]:
		for i in segs:
			var t := float(i + 1) / segs
			var y: float = s * (2.0 + i * 2.2)
			var z := -(t * t) * (5.0 if d != 1 else 6.4)
			box(1.0, 2.4, 1.0, c_main if i % 3 != 2 else c_dark, 0, y, z)
		if d == 2:
			box(1.6, 1.6, 1.6, c_light, 0, s * (2.0 + segs * 2.2), -5.0)
	# corde
	var tip := 2.0 + (segs - 1) * 2.2
	box(0.2, tip * 2.0, 0.2, Color("e8e0c8"), 0, 0, -((5.0 if d != 1 else 6.4)))
	if d == 3:
		gem(0.9, 0, 0, 0.9)
		for s in [-1, 1]:
			box(1.4, 1.4, 1.4, c_accent, 0, s * 2.2, 0)


static var _arrow: ArrayMesh


## Une flèche (pointe vers +Z), pour les arcs.
static func arrow_mesh() -> ArrayMesh:
	if _arrow == null:
		var b := WeaponModels.new()
		b.box(0.5, 0.5, 14, WOOD, 0, 0, 0)
		b.box(1.2, 1.2, 1.6, Color("b8bcc4"), 0, 0, 7.6, 0.0, 0.78)
		for s in [-1, 1]:
			b.box(0.2, 1.4, 2.4, Color("e8e0d0"), s * 0.4, 0, -6.2)
			b.box(1.4, 0.2, 2.4, Color("c83a3a"), 0, s * 0.4, -6.2)
		_arrow = b._build()
	return _arrow
