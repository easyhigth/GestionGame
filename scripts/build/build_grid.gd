class_name BuildGrid
extends Node3D
## Les constructions du joueur : blocs de 1 m (ou dalles de 50 cm) posés sur une grille,
## et meubles posés sur une case. Affiche les blocs par morceaux de 16 x 16 cases
## (seules les faces visibles sont dessinées) et répond aux questions de déplacement :
## « sur quoi peut-on marcher ici ? », « un mur bloque-t-il le passage ? ».
## Vue en coupe : les blocs au-dessus d'une hauteur sont cachés autour du joueur
## (pour voir l'intérieur des maisons).

signal changed

const CHUNK := 16
const BODY_HEIGHT := 1.6
const SHADER_OPAQUE := """
shader_type spatial;
render_mode cull_back;
uniform sampler2D tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec3 cut_center = vec3(0.0);
uniform float cut_y = 10000.0;
uniform float cut_radius = 0.0;
uniform vec3 see_from = vec3(0.0);
uniform vec3 see_to = vec3(0.0);
uniform float see_radius = 0.0;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
bool hidden(vec2 frag) {
	if (wpos.y > cut_y && distance(wpos.xz, cut_center.xz) < cut_radius) { return true; }
	// fenêtre de vision : on perce les blocs entre la caméra et le héros
	vec3 d = see_to - see_from;
	float t = dot(wpos - see_from, d) / max(dot(d, d), 0.001);
	if (see_radius > 0.0 && t > 0.0 && t < 0.985 && wpos.y > see_to.y - 0.75) {
		float r = distance(wpos, see_from + d * t) / see_radius;
		float dither = fract(sin(dot(floor(frag), vec2(12.9898, 78.233))) * 43758.5453);
		if (r < 0.75 + 0.25 * dither) { return true; }
	}
	return false;
}
void fragment() {
	if (hidden(FRAGCOORD.xy)) { discard; }
	vec4 c = texture(tex, UV);
	ALBEDO = c.rgb * COLOR.rgb;
	ROUGHNESS = 0.95;
}
"""
const SHADER_GLASS := """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;
uniform sampler2D tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec3 cut_center = vec3(0.0);
uniform float cut_y = 10000.0;
uniform float cut_radius = 0.0;
uniform vec3 see_from = vec3(0.0);
uniform vec3 see_to = vec3(0.0);
uniform float see_radius = 0.0;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
bool hidden(vec2 frag) {
	if (wpos.y > cut_y && distance(wpos.xz, cut_center.xz) < cut_radius) { return true; }
	// fenêtre de vision : on perce les blocs entre la caméra et le héros
	vec3 d = see_to - see_from;
	float t = dot(wpos - see_from, d) / max(dot(d, d), 0.001);
	if (see_radius > 0.0 && t > 0.0 && t < 0.985 && wpos.y > see_to.y - 0.75) {
		float r = distance(wpos, see_from + d * t) / see_radius;
		float dither = fract(sin(dot(floor(frag), vec2(12.9898, 78.233))) * 43758.5453);
		if (r < 0.75 + 0.25 * dither) { return true; }
	}
	return false;
}
void fragment() {
	if (hidden(FRAGCOORD.xy)) { discard; }
	vec4 c = texture(tex, UV);
	ALBEDO = c.rgb * COLOR.rgb;
	ALPHA = c.a;
	ROUGHNESS = 0.1;
	SPECULAR = 0.8;
}
"""

## Blocs : Vector3i(x, niveau, z) -> ItemData. Un bloc de niveau y occupe la hauteur [y, y + 1]
## (ou [y, y + 0.5] pour une dalle).
var blocks := {}
## Meubles : Vector3i(x, round(base * 2), z) -> { item, rot, base, node }
var furniture := {}
var _block_cols := {}   # Vector2i -> Array[int] (niveaux)
var _furn_cols := {}    # Vector2i -> Array[Vector3i]
var _chunk_nodes := {}  # Vector2i -> Node3D
var _materials := {}    # texture -> ShaderMaterial
var _dirty := {}        # morceaux à redessiner
var _shader_opaque: Shader
var _shader_glass: Shader
var _cut := [Vector3.ZERO, 10000.0, 0.0]


## Grille du joueur (construction) ; faux pour la grille d'un donjon.
var register := true


func _ready() -> void:
	if register:
		add_to_group("build_grid")
	_shader_opaque = Shader.new()
	_shader_opaque.code = SHADER_OPAQUE
	_shader_glass = Shader.new()
	_shader_glass.code = SHADER_GLASS


func clear() -> void:
	blocks.clear()
	for k in furniture:
		var n: Node = furniture[k].node
		if is_instance_valid(n):
			n.queue_free()
	furniture.clear()
	_block_cols.clear()
	_furn_cols.clear()
	for c in _chunk_nodes:
		if is_instance_valid(_chunk_nodes[c]):
			_chunk_nodes[c].queue_free()
	_chunk_nodes.clear()
	changed.emit()


# ---------------------------------------------------------------- blocs

static func block_height(item: ItemData) -> float:
	return 0.5 if item.block_slab else 1.0


func block_at(key: Vector3i) -> ItemData:
	return blocks.get(key)


## Vrai si la place est libre pour un bloc (pas de bloc ni de meuble à cet endroit).
func can_place_block(key: Vector3i, item: ItemData) -> bool:
	if blocks.has(key):
		return false
	var col := Vector2i(key.x, key.z)
	var bottom := float(key.y)
	var top := bottom + block_height(item)
	for fk in _furn_cols.get(col, []):
		var f: Dictionary = furniture[fk]
		if f.base < top - 0.05 and f.base + 1.2 > bottom + 0.05:
			return false
	return true


func place_block(key: Vector3i, item: ItemData) -> bool:
	if item == null or not item.is_block() or not can_place_block(key, item):
		return false
	blocks[key] = item
	var col := Vector2i(key.x, key.z)
	var arr: Array = _block_cols.get(col, [])
	arr.append(key.y)
	arr.sort()
	_block_cols[col] = arr
	_mark(col)
	changed.emit()
	return true


func remove_block(key: Vector3i) -> ItemData:
	var item: ItemData = blocks.get(key)
	if item == null:
		return null
	blocks.erase(key)
	var col := Vector2i(key.x, key.z)
	var arr: Array = _block_cols.get(col, [])
	arr.erase(key.y)
	_mark(col)
	changed.emit()
	return item


## Blocs d'une colonne : [[niveau, bas, haut, item], ...] du bas vers le haut.
func column(col: Vector2i) -> Array:
	var out := []
	for y in _block_cols.get(col, []):
		var it: ItemData = blocks[Vector3i(col.x, y, col.y)]
		out.append([y, float(y), float(y) + block_height(it), it])
	return out


## Plus haut dessus de bloc sur lequel on peut se tenir sans dépasser `max_y` (-INF s'il n'y en a pas).
func support(col: Vector2i, max_y: float) -> float:
	var best := -INF
	for b in column(col):
		if b[2] <= max_y + 0.001:
			best = maxf(best, b[2])
	return best


## Vrai si un bloc ou un meuble solide occupe la place d'un corps debout à la hauteur `feet`.
func body_blocked(col: Vector2i, feet: float) -> bool:
	var lo := feet + 0.05
	var hi := feet + BODY_HEIGHT
	for b in column(col):
		if b[1] < hi and b[2] > lo:
			return true
	for fk in _furn_cols.get(col, []):
		var f: Dictionary = furniture[fk]
		if (f.item as ItemData).furniture_solid and f.base < hi and f.base + 1.0 > lo:
			return true
	return false


# ---------------------------------------------------------------- meubles

func furniture_key(col: Vector2i, base: float) -> Vector3i:
	return Vector3i(col.x, roundi(base * 2.0), col.y)


func can_place_furniture(col: Vector2i, base: float) -> bool:
	if furniture.has(furniture_key(col, base)):
		return false
	for b in column(col):
		if b[1] < base + 1.2 and b[2] > base + 0.05:
			return false
	for fk in _furn_cols.get(col, []):
		if absf(furniture[fk].base - base) < 0.9:
			return false
	return true


func place_furniture(col: Vector2i, base: float, item: ItemData, rot: int) -> bool:
	if item == null or not item.is_furniture() or not can_place_furniture(col, base):
		return false
	var key := furniture_key(col, base)
	var node := item.furniture_model.instantiate() as Node3D
	node.position = Vector3(col.x + 0.5, base, col.y + 0.5)
	node.rotation.y = rot * PI * 0.5
	add_child(node)
	if item.furniture_light:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.72, 0.4)
		l.light_energy = 1.1
		l.omni_range = 6.0
		l.position = Vector3(0, 1.3, 0)
		node.add_child(l)
	furniture[key] = {"item": item, "rot": rot, "base": base, "node": node, "col": col}
	var arr: Array = _furn_cols.get(col, [])
	arr.append(key)
	_furn_cols[col] = arr
	changed.emit()
	return true


func remove_furniture(key: Vector3i) -> ItemData:
	if not furniture.has(key):
		return null
	var f: Dictionary = furniture[key]
	if is_instance_valid(f.node):
		f.node.queue_free()
	furniture.erase(key)
	(_furn_cols.get(f.col, []) as Array).erase(key)
	changed.emit()
	return f.item


## Meubles d'une colonne.
func furniture_in(col: Vector2i) -> Array:
	var out := []
	for fk in _furn_cols.get(col, []):
		out.append(furniture[fk])
	return out


## Identifiants des meubles à moins de `radius` mètres (pour l'artisanat).
func furniture_near(pos: Vector3, radius: float) -> Array:
	var out := []
	for k in furniture:
		var f: Dictionary = furniture[k]
		var p := Vector3(f.col.x + 0.5, f.base, f.col.y + 0.5)
		if p.distance_to(pos) <= radius and not out.has(f.item.id):
			out.append(f.item.id)
	return out


# ---------------------------------------------------------------- affichage

func _mark(col: Vector2i) -> void:
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			var c := Vector2i(floori(float(col.x + dx) / CHUNK), floori(float(col.y + dz) / CHUNK))
			_dirty[c] = true


func _process(_delta: float) -> void:
	_update_see_through()
	if not _dirty.is_empty():
		for c in _dirty.keys():
			_rebuild_chunk(c)
		_dirty.clear()


## Cache les blocs au-dessus de `height` à moins de `radius` mètres de `center` (0 = pas de coupe).
## Fenêtre de vision : les blocs entre la caméra et le héros deviennent transparents.
func _update_see_through() -> void:
	var cam := get_viewport().get_camera_3d()
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	var on := cam != null and hero != null and not blocks.is_empty()
	var from := cam.global_position if on else Vector3.ZERO
	var to := hero.global_position + Vector3(0, 0.9, 0) if on else Vector3.ZERO
	for m in _materials.values():
		(m as ShaderMaterial).set_shader_parameter("see_from", from)
		(m as ShaderMaterial).set_shader_parameter("see_to", to)
		(m as ShaderMaterial).set_shader_parameter("see_radius", 1.9 if on else 0.0)


func set_cut(center: Vector3, height: float, radius: float) -> void:
	_cut = [center, height, radius]
	for m in _materials.values():
		(m as ShaderMaterial).set_shader_parameter("cut_center", center)
		(m as ShaderMaterial).set_shader_parameter("cut_y", height)
		(m as ShaderMaterial).set_shader_parameter("cut_radius", radius)


func _material(item: ItemData) -> ShaderMaterial:
	if _materials.has(item.block_texture):
		return _materials[item.block_texture]
	var m := ShaderMaterial.new()
	m.shader = _shader_glass if item.block_transparent else _shader_opaque
	m.set_shader_parameter("tex", item.block_texture)
	m.set_shader_parameter("cut_center", _cut[0])
	m.set_shader_parameter("cut_y", _cut[1])
	m.set_shader_parameter("cut_radius", _cut[2])
	_materials[item.block_texture] = m
	return m


func _opaque_full(key: Vector3i) -> bool:
	var it: ItemData = blocks.get(key)
	return it != null and not it.block_slab and not it.block_transparent


func _rebuild_chunk(c: Vector2i) -> void:
	if _chunk_nodes.has(c) and is_instance_valid(_chunk_nodes[c]):
		_chunk_nodes[c].queue_free()
	_chunk_nodes.erase(c)
	var tools := {}   # texture -> [SurfaceTool, item]
	for x in range(c.x * CHUNK, (c.x + 1) * CHUNK):
		for z in range(c.y * CHUNK, (c.y + 1) * CHUNK):
			var col := Vector2i(x, z)
			if not _block_cols.has(col):
				continue
			for y in _block_cols[col]:
				var key := Vector3i(x, y, z)
				var it: ItemData = blocks[key]
				if not tools.has(it.block_texture):
					var st := SurfaceTool.new()
					st.begin(Mesh.PRIMITIVE_TRIANGLES)
					tools[it.block_texture] = [st, it]
				_add_block(tools[it.block_texture][0], key, it)
	if tools.is_empty():
		return
	var holder := Node3D.new()
	holder.name = "Blocs_%d_%d" % [c.x, c.y]
	for tex in tools:
		var st: SurfaceTool = tools[tex][0]
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = _material(tools[tex][1])
		if (tools[tex][1] as ItemData).block_transparent:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mi)
	add_child(holder)
	_chunk_nodes[c] = holder


func _add_block(st: SurfaceTool, key: Vector3i, it: ItemData) -> void:
	var x := float(key.x)
	var y := float(key.y)
	var z := float(key.z)
	var h := block_height(it)
	var same_glass := func(k: Vector3i) -> bool:
		var o: ItemData = blocks.get(k)
		return o != null and o.block_transparent and it.block_transparent and not o.block_slab
	var hidden := func(k: Vector3i) -> bool:
		return _opaque_full(k) or same_glass.call(k)
	# dessus
	if it.block_slab or not hidden.call(key + Vector3i(0, 1, 0)):
		_face(st, [Vector3(x, y + h, z + 1), Vector3(x + 1, y + h, z + 1), Vector3(x + 1, y + h, z), Vector3(x, y + h, z)], Vector3.UP, 1.0, h, false)
	# dessous
	if not hidden.call(key + Vector3i(0, -1, 0)):
		_face(st, [Vector3(x, y, z), Vector3(x + 1, y, z), Vector3(x + 1, y, z + 1), Vector3(x, y, z + 1)], Vector3.DOWN, 0.6, h, false)
	var sides := [
		[Vector3i(1, 0, 0), [Vector3(x + 1, y, z + 1), Vector3(x + 1, y, z), Vector3(x + 1, y + h, z), Vector3(x + 1, y + h, z + 1)], 0.82],
		[Vector3i(-1, 0, 0), [Vector3(x, y, z), Vector3(x, y, z + 1), Vector3(x, y + h, z + 1), Vector3(x, y + h, z)], 0.82],
		[Vector3i(0, 0, 1), [Vector3(x, y, z + 1), Vector3(x + 1, y, z + 1), Vector3(x + 1, y + h, z + 1), Vector3(x, y + h, z + 1)], 0.9],
		[Vector3i(0, 0, -1), [Vector3(x + 1, y, z), Vector3(x, y, z), Vector3(x, y + h, z), Vector3(x + 1, y + h, z)], 0.9],
	]
	for s in sides:
		if it.block_slab or not hidden.call(key + (s[0] as Vector3i)):
			_face(st, s[1], Vector3(s[0]), s[2], h, true)


func _face(st: SurfaceTool, v: Array, n: Vector3, shade: float, h: float, side: bool) -> void:
	var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	if side:
		uvs = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 1.0 - h), Vector2(0, 1.0 - h)]
	# les coins du bas des côtés sont un peu plus sombres (ombre au sol)
	var cols := [shade, shade, shade, shade]
	if side:
		cols = [shade * 0.82, shade * 0.82, shade, shade]
	for k in [0, 2, 1, 0, 3, 2]:
		st.set_normal(n)
		st.set_color(Color(cols[k], cols[k], cols[k]))
		st.set_uv(uvs[k])
		st.add_vertex(v[k])


# ---------------------------------------------------------------- sauvegarde simple (pour plus tard)

func block_count_by_tier() -> Array:
	var out := [0, 0, 0, 0, 0, 0]
	for k in blocks:
		out[clampi((blocks[k] as ItemData).block_tier, 0, 5)] += 1
	return out
