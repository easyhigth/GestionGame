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
## Distance (m) jusqu'à laquelle les blocs sont dessinés.
const DRAW_DISTANCE := 150.0
## Morceaux redessinés au plus par image (pas d'à-coups quand une ville apparaît).
const REBUILDS_PER_FRAME := 6
const BODY_HEIGHT := 1.6
const SHADER_OPAQUE := """
shader_type spatial;
render_mode cull_back;
uniform sampler2DArray tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec3 cut_center = vec3(0.0);
uniform float cut_y = 10000.0;
uniform float cut_radius = 0.0;
uniform vec3 see_from = vec3(0.0);
uniform vec3 see_to = vec3(0.0);
uniform float see_radius = 0.0;
varying vec3 wpos;
varying vec3 wnorm;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}
// relief des blocs : un léger biseau sombre au bord de chaque face, et une nuance propre à chaque bloc
float bevel() {
	vec3 a = abs(wnorm);
	vec2 f = a.y > 0.5 ? fract(wpos.xz) : (a.x > 0.5 ? fract(wpos.zy) : fract(wpos.xy));
	float e = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	return mix(0.84, 1.0, smoothstep(0.0, 0.12, e));
}
float block_tint() {
	vec3 b = floor(wpos - wnorm * 0.5);
	return 0.95 + 0.08 * fract(sin(dot(b, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}
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
	vec4 c = texture(tex, vec3(UV, UV2.x));
	ALBEDO = c.rgb * COLOR.rgb * bevel() * block_tint();
	ROUGHNESS = 0.95;
	// blocs lumineux (pierre lumineuse, lanterne marine...)
	EMISSION = c.rgb * UV2.y * 1.4;
}
"""
const SHADER_GLASS := """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;
uniform sampler2DArray tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec3 cut_center = vec3(0.0);
uniform float cut_y = 10000.0;
uniform float cut_radius = 0.0;
uniform vec3 see_from = vec3(0.0);
uniform vec3 see_to = vec3(0.0);
uniform float see_radius = 0.0;
varying vec3 wpos;
varying vec3 wnorm;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}
// relief des blocs : un léger biseau sombre au bord de chaque face, et une nuance propre à chaque bloc
float bevel() {
	vec3 a = abs(wnorm);
	vec2 f = a.y > 0.5 ? fract(wpos.xz) : (a.x > 0.5 ? fract(wpos.zy) : fract(wpos.xy));
	float e = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	return mix(0.84, 1.0, smoothstep(0.0, 0.12, e));
}
float block_tint() {
	vec3 b = floor(wpos - wnorm * 0.5);
	return 0.95 + 0.08 * fract(sin(dot(b, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}
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
	vec4 c = texture(tex, vec3(UV, UV2.x));
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
var _materials := {}    # "opaque" / "glass" -> ShaderMaterial
## Portillons ouverts (clé du bloc -> vrai).
var open_gates := {}
## Couche de texture et lueur du bloc en cours de construction (voir _layer_of).
var _layer := 0
var _glow := 0.0
const MAX_LIGHTS_PER_CHUNK := 4
var _dirty := {}        # morceaux à redessiner
var _shader_opaque: Shader
var _shader_glass: Shader
var _cut := [Vector3.ZERO, 10000.0, 0.0]


## Grille du joueur (construction) ; faux pour la grille d'un donjon.
var register := true
## Blocs posés par le monde lui-même (maisons, ruines, villes...) : clé -> identifiant d'objet.
## Ils ne sont pas sauvegardés un par un (le monde les repose à chaque chargement) :
## la sauvegarde ne garde que ceux que le joueur a cassés (`removed_generated`).
var generated := {}
var removed_generated := {}
## Vrai pendant que le monde pose ses constructions (pas de signal à chaque bloc).
var generating := false


func _ready() -> void:
	if register:
		add_to_group("build_grid")
	_shader_opaque = Shader.new()
	_shader_opaque.code = SHADER_OPAQUE
	_shader_glass = Shader.new()
	_shader_glass.code = SHADER_GLASS


func clear() -> void:
	blocks.clear()
	generated.clear()
	removed_generated.clear()
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
	if generating:
		generated[key] = item.id
	var col := Vector2i(key.x, key.z)
	var arr: Array = _block_cols.get(col, [])
	arr.append(key.y)
	arr.sort()
	_block_cols[col] = arr
	_mark(col)
	if not generating:
		changed.emit()
	return true


func remove_block(key: Vector3i) -> ItemData:
	var item: ItemData = blocks.get(key)
	if item == null:
		return null
	blocks.erase(key)
	if generated.has(key):
		removed_generated[key] = true
	var col := Vector2i(key.x, key.z)
	var arr: Array = _block_cols.get(col, [])
	arr.erase(key.y)
	_mark(col)
	changed.emit()
	return item


## Retire tous les meubles (les blocs restent).
func clear_furniture() -> void:
	for k in furniture:
		var n: Node = furniture[k].node
		if is_instance_valid(n):
			n.queue_free()
	furniture.clear()
	_furn_cols.clear()
	changed.emit()


## Vrai si ce bloc est à sauvegarder : posé par le joueur (ou à la place d'un bloc du monde).
func is_player_block(key: Vector3i) -> bool:
	var it: ItemData = blocks.get(key)
	if it == null:
		return false
	return not generated.has(key) or removed_generated.has(key) or generated[key] != it.id


## Blocs d'une colonne : [[niveau, bas, haut, item], ...] du bas vers le haut.
func column(col: Vector2i) -> Array:
	var out := []
	for y in _block_cols.get(col, []):
		var it: ItemData = blocks[Vector3i(col.x, y, col.y)]
		# un portillon ouvert ne bloque rien
		if open_gates.has(Vector3i(col.x, y, col.y)):
			continue
		# un escalier ne bloque que sa moitié basse (on peut s'y tenir à mi-hauteur puis en haut)
		out.append([y, float(y), float(y) + (0.5 if is_stair(it) else block_height(it)), it])
	return out


static func is_stair(it: ItemData) -> bool:
	return it != null and it.has_meta("stair_dir")


## Plus haut dessus de bloc sur lequel on peut se tenir sans dépasser `max_y` (-INF s'il n'y en a pas).
## Un escalier offre deux marches : sa moitié (y + 0,5) puis son dessus (y + 1).
func support(col: Vector2i, max_y: float) -> float:
	var best := -INF
	for b in column(col):
		if b[2] <= max_y + 0.001:
			best = maxf(best, b[2])
		if is_stair(b[3]) and b[1] + 1.0 <= max_y + 0.001:
			best = maxf(best, b[1] + 1.0)
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
	# (un meuble qui a déjà sa propre lumière, comme le feu de camp, n'en reçoit pas d'autre)
	if item.furniture_light and node.find_children("*", "OmniLight3D", true, false).is_empty():
		# une flamme qui vacille, qui éclaire bien les alentours la nuit
		var l := FlickerLight.make(Color(1.0, 0.7, 0.38), 1.5, 8.0)
		l.position = Vector3(0, 1.3, 0)
		node.add_child(l)
	furniture[key] = {"item": item, "rot": rot, "base": base, "node": node, "col": col}
	var arr: Array = _furn_cols.get(col, [])
	arr.append(key)
	_furn_cols[col] = arr
	if item.id == WorldGenerator.FLAG_ID:
		_flag_planted(key)
	changed.emit()
	return true


## Le drapeau du royaume planté ici devient le centre du camp ; un autre drapeau déjà planté revient au sac.
func _flag_planted(key: Vector3i) -> void:
	var world := get_tree().get_first_node_in_group("world") as WorldGenerator if is_inside_tree() else null
	if world == null:
		return
	for k in furniture.keys():
		if k != key and (furniture[k].item as ItemData).id == WorldGenerator.FLAG_ID:
			var old := remove_furniture(k)
			var p := get_tree().get_first_node_in_group("player")
			if old and p:
				p.inventory.add(old, 1)
	world.set_home(furniture[key].col)


func remove_furniture(key: Vector3i) -> ItemData:
	if not furniture.has(key):
		return null
	var f: Dictionary = furniture[key]
	if is_instance_valid(f.node):
		f.node.queue_free()
	furniture.erase(key)
	(_furn_cols.get(f.col, []) as Array).erase(key)
	if (f.item as ItemData).id == WorldGenerator.FLAG_ID and is_inside_tree():
		var world := get_tree().get_first_node_in_group("world") as WorldGenerator
		if world and world.home_cell == f.col:
			world.clear_home()
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
	if _dirty.is_empty():
		return
	# les constructions lointaines (villes, ruines...) ne sont dessinées qu'en approchant :
	# on refait d'abord les morceaux proches, quelques-uns par image
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	var center := Vector2(hero.global_position.x, hero.global_position.z) / CHUNK if hero else Vector2.ZERO
	var near := []
	for c in _dirty.keys():
		var d := (Vector2(c) + Vector2(0.5, 0.5)).distance_to(center) if hero else 0.0
		if d * CHUNK <= DRAW_DISTANCE:
			near.append([d, c])
	near.sort_custom(func(a, b): return a[0] < b[0])
	for i in mini(near.size(), REBUILDS_PER_FRAME):
		_rebuild_chunk(near[i][1])
		_dirty.erase(near[i][1])


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


## Toutes les textures de blocs dans un seul tableau de textures (Texture2DArray) : chaque morceau n'a plus
## qu'un maillage opaque et un maillage de verre, au lieu d'un maillage par texture (bien moins d'appels de
## dessin avec les ~300 blocs du catalogue). Le numéro de couche voyage dans UV2.x, la lueur dans UV2.y.
static var _layers := {}          # Texture2D -> couche
static var _images: Array[Image] = []
static var _array: Texture2DArray
static var _array_dirty := true
static var _grids: Array = []      # grilles à prévenir quand le tableau change
const LAYER_SIZE := 16


static func _layer_of(tex: Texture2D) -> int:
	if tex == null:
		return 0
	if _layers.has(tex):
		return _layers[tex]
	var img := tex.get_image()
	if img == null or img.is_empty():
		img = Image.create(LAYER_SIZE, LAYER_SIZE, false, Image.FORMAT_RGBA8)
		img.fill(Color.MAGENTA)
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.clear_mipmaps()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	if img.get_size() != Vector2i(LAYER_SIZE, LAYER_SIZE):
		img.resize(LAYER_SIZE, LAYER_SIZE, Image.INTERPOLATE_NEAREST)
	img.generate_mipmaps()
	_layers[tex] = _images.size()
	_images.append(img)
	_array_dirty = true
	return _layers[tex]


## Prépare d'un coup les couches de tous les blocs connus (un seul tableau construit au démarrage).
static func _prepare_layers() -> void:
	if not _layers.is_empty():
		return
	var db := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Items")
	if db:
		for id in db.items:
			var it: ItemData = db.items[id]
			if it.is_block():
				_layer_of(it.block_texture)


static func _texture_array() -> Texture2DArray:
	if _array_dirty or _array == null:
		_array_dirty = false
		_array = Texture2DArray.new()
		if _images.is_empty():
			var img := Image.create(LAYER_SIZE, LAYER_SIZE, true, Image.FORMAT_RGBA8)
			_images.append(img)
		_array.create_from_images(_images)
		for g in _grids:
			if is_instance_valid(g):
				for m in g._materials.values():
					(m as ShaderMaterial).set_shader_parameter("tex", _array)
	return _array


## Le matériau (opaque ou verre) de cette grille.
func _material(item: ItemData) -> ShaderMaterial:
	var key := "glass" if item.block_transparent else "opaque"
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.shader = _shader_glass if item.block_transparent else _shader_opaque
	m.set_shader_parameter("tex", _texture_array())
	m.set_shader_parameter("cut_center", _cut[0])
	m.set_shader_parameter("cut_y", _cut[1])
	m.set_shader_parameter("cut_radius", _cut[2])
	_materials[key] = m
	if not _grids.has(self):
		_grids.append(self)
	return m


## Blocs qui éclairent autour d'eux.
static func is_glowing(it: ItemData) -> bool:
	return it != null and it.has_meta("glow")


func _opaque_full(key: Vector3i) -> bool:
	var it: ItemData = blocks.get(key)
	return it != null and not it.block_slab and not it.block_transparent and not is_stair(it) and shape_of(it) == ""


func _rebuild_chunk(c: Vector2i) -> void:
	if _chunk_nodes.has(c) and is_instance_valid(_chunk_nodes[c]):
		_chunk_nodes[c].queue_free()
	_chunk_nodes.erase(c)
	_prepare_layers()
	var tools := {}   # "opaque" / "glass" -> [SurfaceTool, item]
	var lights := []
	for x in range(c.x * CHUNK, (c.x + 1) * CHUNK):
		for z in range(c.y * CHUNK, (c.y + 1) * CHUNK):
			var col := Vector2i(x, z)
			if not _block_cols.has(col):
				continue
			for y in _block_cols[col]:
				var key := Vector3i(x, y, z)
				var it: ItemData = blocks[key]
				var kind := "glass" if it.block_transparent else "opaque"
				if not tools.has(kind):
					var st := SurfaceTool.new()
					st.begin(Mesh.PRIMITIVE_TRIANGLES)
					tools[kind] = [st, it]
				_layer = _layer_of(it.block_texture)
				_glow = 1.0 if is_glowing(it) else 0.0
				if _glow > 0.0 and lights.size() < MAX_LIGHTS_PER_CHUNK:
					lights.append([key, it])
				_add_block(tools[kind][0], key, it)
	if tools.is_empty():
		return
	_texture_array()
	var holder := Node3D.new()
	holder.name = "Blocs_%d_%d" % [c.x, c.y]
	for kind in tools:
		var st: SurfaceTool = tools[kind][0]
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = _material(tools[kind][1])
		mi.visibility_range_end = DRAW_DISTANCE + 20.0
		if kind == "glass":
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mi)
	# les blocs lumineux éclairent vraiment (quelques lumières par morceau au plus)
	for l in lights:
		var key: Vector3i = l[0]
		var om := OmniLight3D.new()
		om.light_color = BuildMode.it_color(l[1]).lightened(0.3)
		om.light_energy = 1.3
		om.omni_range = 7.0
		om.shadow_enabled = false
		om.distance_fade_enabled = true
		om.distance_fade_begin = 40.0
		om.distance_fade_length = 15.0
		om.position = Vector3(key.x + 0.5, key.y + 1.2, key.z + 0.5)
		holder.add_child(om)
	add_child(holder)
	_chunk_nodes[c] = holder


## Escalier : une dalle, et un demi-bloc au-dessus du côté « haut » (direction 0 : nord, 1 : est, 2 : sud, 3 : ouest).
func _add_stair(st: SurfaceTool, key: Vector3i, it: ItemData) -> void:
	var p := Vector3(key)
	_box(st, p, p + Vector3(1, 0.5, 1))
	var d := int(it.get_meta("stair_dir"))
	var lo := p + Vector3(0, 0.5, 0)
	var hi := p + Vector3(1, 1, 1)
	match d:
		0:
			hi.z = p.z + 0.5
		1:
			lo.x = p.x + 0.5
		2:
			lo.z = p.z + 0.5
		_:
			hi.x = p.x + 0.5
	_box(st, lo, hi)


## Une boîte quelconque (toutes ses faces), textures à l'échelle.
func _box(st: SurfaceTool, a: Vector3, b: Vector3) -> void:
	var h := b.y - a.y
	_face(st, [Vector3(a.x, b.y, b.z), Vector3(b.x, b.y, b.z), Vector3(b.x, b.y, a.z), Vector3(a.x, b.y, a.z)], Vector3.UP, 1.0, h, false)
	_face(st, [Vector3(a.x, a.y, a.z), Vector3(b.x, a.y, a.z), Vector3(b.x, a.y, b.z), Vector3(a.x, a.y, b.z)], Vector3.DOWN, 0.6, h, false)
	_face(st, [Vector3(b.x, a.y, b.z), Vector3(b.x, a.y, a.z), Vector3(b.x, b.y, a.z), Vector3(b.x, b.y, b.z)], Vector3.RIGHT, 0.82, h, true)
	_face(st, [Vector3(a.x, a.y, a.z), Vector3(a.x, a.y, b.z), Vector3(a.x, b.y, b.z), Vector3(a.x, b.y, a.z)], Vector3.LEFT, 0.82, h, true)
	_face(st, [Vector3(a.x, a.y, b.z), Vector3(b.x, a.y, b.z), Vector3(b.x, b.y, b.z), Vector3(a.x, b.y, b.z)], Vector3.BACK, 0.9, h, true)
	_face(st, [Vector3(b.x, a.y, a.z), Vector3(a.x, a.y, a.z), Vector3(a.x, b.y, a.z), Vector3(b.x, b.y, a.z)], Vector3.FORWARD, 0.9, h, true)


## Forme d'un bloc : « wall » (muret) ou « fence » (barrière), sinon "".
static func shape_of(it: ItemData) -> String:
	return str(it.get_meta("shape", "")) if it else ""


## Muret ou barrière : un poteau au centre, et des liaisons vers les voisins (même forme, ou bloc plein).
func _add_post(st: SurfaceTool, key: Vector3i, it: ItemData) -> void:
	var p := Vector3(key)
	var sh := shape_of(it)
	if sh == "gate":
		_add_gate(st, key, p)
		return
	var wall := sh == "wall"
	var r := 0.25 if wall else 0.125
	_box(st, p + Vector3(0.5 - r, 0, 0.5 - r), p + Vector3(0.5 + r, 1.0, 0.5 + r))
	for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		var o: ItemData = blocks.get(key + d)
		if o == null or not (shape_of(o) == sh or (sh == "fence" and shape_of(o) == "gate") or _opaque_full(key + d)):
			continue
		var a := Vector3(0.5, 0, 0.5)
		var b := Vector3(0.5, 0, 0.5) + Vector3(d) * 0.5
		var lo := Vector3(minf(a.x, b.x), 0, minf(a.z, b.z))
		var hi := Vector3(maxf(a.x, b.x), 0, maxf(a.z, b.z))
		var w := 0.19 if wall else 0.06
		if d.x != 0:
			lo.z = 0.5 - w
			hi.z = 0.5 + w
		else:
			lo.x = 0.5 - w
			hi.x = 0.5 + w
		if wall:
			_box(st, p + Vector3(lo.x, 0, lo.z), p + Vector3(hi.x, 0.8, hi.z))
		else:
			for y in [0.35, 0.72]:
				_box(st, p + Vector3(lo.x, y, lo.z), p + Vector3(hi.x, y + 0.14, hi.z))


## Portillon : deux poteaux et deux traverses ; ouvert, les traverses pivotent d'un quart de tour.
func _add_gate(st: SurfaceTool, key: Vector3i, p: Vector3) -> void:
	var along_x := blocks.has(key + Vector3i(1, 0, 0)) or blocks.has(key + Vector3i(-1, 0, 0)) or not (blocks.has(key + Vector3i(0, 0, 1)) or blocks.has(key + Vector3i(0, 0, -1)))
	var opened := open_gates.has(key)
	if along_x:
		for x in [0.0, 0.875]:
			_box(st, p + Vector3(x, 0, 0.44), p + Vector3(x + 0.125, 1.0, 0.56))
	else:
		for z in [0.0, 0.875]:
			_box(st, p + Vector3(0.44, 0, z), p + Vector3(0.56, 1.0, z + 0.125))
	for y in [0.32, 0.7]:
		if along_x != opened:
			_box(st, p + Vector3(0.125, y, 0.45), p + Vector3(0.875, y + 0.14, 0.55))
		else:
			_box(st, p + Vector3(0.45, y, 0.125), p + Vector3(0.55, y + 0.14, 0.875))


## Ouvre ou ferme le portillon le plus proche (E). Vrai si un portillon a été trouvé.
func toggle_gate_near(pos: Vector3, dist := 1.8) -> bool:
	var c := Vector2i(floori(pos.x), floori(pos.z))
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			for y in _block_cols.get(c + Vector2i(dx, dz), []):
				var key := Vector3i(c.x + dx, y, c.y + dz)
				if shape_of(blocks[key]) != "gate":
					continue
				if Vector3(key.x + 0.5, key.y + 0.5, key.z + 0.5).distance_to(pos + Vector3(0, 0.5, 0)) > dist:
					continue
				if open_gates.has(key):
					open_gates.erase(key)
				else:
					open_gates[key] = true
				_mark(Vector2i(key.x, key.z))
				return true
	return false


## Pente (toits) : un coin plein dont le dessus descend du côté « haut » (comme l'escalier) vers l'autre.
func _add_slope(st: SurfaceTool, key: Vector3i, it: ItemData) -> void:
	var p := Vector3(key)
	var d := int(it.get_meta("stair_dir"))
	var rot := func(v: Vector3) -> Vector3:
		var q := Vector2(v.x - 0.5, v.z - 0.5).rotated(-PI / 2.0 * d)
		return p + Vector3(q.x + 0.5, v.y, q.y + 0.5)
	var faces := [
		[[Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)], 0.6],
		[[Vector3(1, 0, 0), Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0)], 0.9],
		[[Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(0, 1, 0)], 0.82],
		[[Vector3(1, 0, 1), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 0)], 0.82],
		[[Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 0), Vector3(0, 1, 0)], 1.0],
	]
	for f in faces:
		var v: Array = (f[0] as Array).map(func(x): return rot.call(x))
		var n: Vector3 = (v[1] - v[0]).cross(v[2] - v[0]).normalized()
		_face(st, v, n, f[1], 1.0, false)
		# les deux côtés (la pente est vue de dessus comme de dessous)
		var r := [v[1], v[0], v[3], v[2]]
		_face(st, r, -n, f[1], 1.0, false)


func _add_block(st: SurfaceTool, key: Vector3i, it: ItemData) -> void:
	if it.has_meta("slope"):
		_add_slope(st, key, it)
		return
	if is_stair(it):
		_add_stair(st, key, it)
		return
	if shape_of(it) != "":
		_add_post(st, key, it)
		return
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
		st.set_uv2(Vector2(_layer, _glow))
		st.add_vertex(v[k])


# ---------------------------------------------------------------- sauvegarde simple (pour plus tard)

func block_count_by_tier() -> Array:
	var out := [0, 0, 0, 0, 0, 0]
	for k in blocks:
		out[clampi((blocks[k] as ItemData).block_tier, 0, 5)] += 1
	return out
