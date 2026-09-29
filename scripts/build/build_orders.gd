class_name BuildOrders
extends Node3D
## Chantiers (comme dans Going Medieval) : en mode construction, le joueur pose des plans
## (murs, sols, toits, portes, meubles, terrassement, récolte, démolition). Ils apparaissent
## en fantômes bleus, et les habitants libres (sans poste ni expédition) viennent les réaliser
## un par un, en prenant les matériaux dans le sac du héros (le stock du village).
## Un plan sans matériaux reste en attente (fantôme rouge) jusqu'à ce qu'on en ait.
## Option « construction instantanée » : les plans sont réalisés tout de suite.

signal orders_changed

## Temps de travail (secondes, pour un habitant moyen).
const WORK := {"block": 1.2, "furniture": 2.5, "remove": 0.7, "terrain": 0.8, "harvest": 2.5}
const HARVEST_LOOT := {
	WorldGenerator.D_OAK: [["wood", 3, 4]], WorldGenerator.D_PINE: [["wood", 3, 5]],
	WorldGenerator.D_BUSH: [["fiber", 2, 3]], WorldGenerator.D_FLOWERS: [["fiber", 1, 1]], WorldGenerator.D_GRASS: [["fiber", 1, 1]],
	WorldGenerator.D_ROCK: [["stone", 2, 4]],
}
const C_PLAN := Color(0.35, 0.7, 1.0, 0.2)
const C_MISSING := Color(1.0, 0.35, 0.3, 0.3)
const C_REMOVE := Color(1.0, 0.55, 0.15, 0.45)
const C_TERRAIN := Color(1.0, 0.85, 0.3, 0.5)
const C_HARVEST := Color(0.45, 1.0, 0.4, 0.5)

var world: WorldGenerator
var grid: BuildGrid
## id -> ordre : {id, type, cell, key, item, rot, base, h, progress, builder, wait_until}
var orders := {}
var instant := false
## Les plans au-dessus de cette hauteur sont cachés (vue en coupe du mode construction).
var view_cut := INF
var _next_id := 1
var _index := {}          # clé unique (type+position) -> id
var _dirty := true
var _mm: MultiMeshInstance3D
var _mat: StandardMaterial3D
var _furn_ghosts := {}    # id -> Node3D
var _ghost_mat_plan: StandardMaterial3D
var _ghost_mat_missing: StandardMaterial3D
var _dug := {}


## Plans refusés parce qu'un décor du village occupe la place (remis à zéro par le mode construction).
var blocked_by_prop := 0


func _ready() -> void:
	add_to_group("build_orders")
	var p := _player()
	if p:
		p.inventory.changed.connect(refresh)
	world = get_parent() as WorldGenerator
	grid = world.build if world else null
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.vertex_color_use_as_albedo = true
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mm = MultiMeshInstance3D.new()
	_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := MultiMesh.new()
	m.transform_format = MultiMesh.TRANSFORM_3D
	m.use_colors = true
	var box := BoxMesh.new()
	box.material = _mat
	m.mesh = box
	_mm.multimesh = m
	add_child(_mm)
	_ghost_mat_plan = _ghost_material(C_PLAN)
	_ghost_mat_missing = _ghost_material(C_MISSING)


static func _ghost_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	return m


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


# ---------------------------------------------------------------- ajout / annulation

static func _ukey(o: Dictionary) -> String:
	match o.type:
		"block":
			return "b%s" % o.key
		"furniture":
			return "f%s" % o.key
		"remove":
			if o.get("what") == "prop":
				return "rprop%s" % o.prop
			return "r%s%s" % [o.get("what", "block"), o.key]
		_:
			return "t%s" % o.cell


## Ajoute un plan. Renvoie son id (0 si refusé : déjà prévu, place prise...).
func add(o: Dictionary) -> int:
	var uk := _ukey(o)
	if _index.has(uk):
		return 0
	# un plan de bloc remplace une démolition prévue au même endroit, et inversement
	if o.type == "block":
		var rk := "rblock%s" % o.key
		if _index.has(rk):
			cancel(_index[rk])
		# « remplacer » (fenêtre dans un mur) : le bloc existant sera changé une fois le nouveau disponible
		var cur: ItemData = grid.block_at(o.key)
		if cur != null and (not o.get("replace", false) or cur == o.item):
			return 0
	# un décor du village de départ (cabane, tonneau...) occupe la place : il faut d'abord le démolir
	if (o.type == "block" or o.type == "furniture") and world.village_prop_at(o.cell, float(o.key.y) if o.type == "block" else float(o.base)) != null:
		blocked_by_prop += 1
		return 0
	o.id = _next_id
	_next_id += 1
	o.progress = 0.0
	o.builder = null
	o.wait_until = 0
	orders[o.id] = o
	_index[uk] = o.id
	_dirty = true
	if instant:
		if ready_to_build(o):
			_complete(o)
	orders_changed.emit()
	return o.id


func block(key: Vector3i, item: ItemData) -> int:
	return add({"type": "block", "key": key, "cell": Vector2i(key.x, key.z), "item": item})


func furniture(col: Vector2i, base: float, item: ItemData, rot: int) -> int:
	return add({"type": "furniture", "key": grid.furniture_key(col, base), "cell": col, "base": base, "item": item, "rot": rot})


func remove_block(key: Vector3i) -> int:
	# un plan pas encore construit : on l'annule simplement
	var bk := "b%s" % key
	if _index.has(bk):
		cancel(_index[bk])
		return 0
	if grid.block_at(key) == null:
		return 0
	return add({"type": "remove", "what": "block", "key": key, "cell": Vector2i(key.x, key.z)})


func remove_furniture(key: Vector3i) -> int:
	var fk := "f%s" % key
	if _index.has(fk):
		cancel(_index[fk])
		return 0
	if not grid.furniture.has(key):
		return 0
	return add({"type": "remove", "what": "furniture", "key": key, "cell": Vector2i(key.x, key.z)})


## Démolir un décor du village de départ (cabane, tonneau...).
func remove_prop(prop: Node3D) -> int:
	var id: String = prop.get_meta("prop_id", "")
	if id == "":
		return 0
	var c := Vector2i(floori(prop.global_position.x), floori(prop.global_position.z))
	return add({"type": "remove", "what": "prop", "prop": id, "key": Vector3i(c.x, floori(prop.global_position.y), c.y), "cell": c})


func terrain(cell: Vector2i, target: float) -> int:
	if absf(world.terrain_height(cell) - target) < 0.01:
		return 0
	var tk := "t%s" % cell
	if _index.has(tk):
		cancel(_index[tk])
	return add({"type": "terrain", "cell": cell, "h": target})


func harvest(cell: Vector2i) -> int:
	if world.decor_at(cell) == WorldGenerator.D_NONE:
		return 0
	return add({"type": "harvest", "cell": cell})


func cancel(id: int) -> void:
	if not orders.has(id):
		return
	var o: Dictionary = orders[id]
	orders.erase(id)
	_index.erase(_ukey(o))
	if _furn_ghosts.has(id):
		_furn_ghosts[id].queue_free()
		_furn_ghosts.erase(id)
	_dirty = true
	orders_changed.emit()


## Annule tous les plans dans un rectangle de cases (niveaux entre y0 et y1).
func cancel_rect(r: Rect2i, y0 := -1000.0, y1 := 1000.0, with_removals := true) -> int:
	var n := 0
	for id in orders.keys():
		var o: Dictionary = orders[id]
		if o.type == "remove" and not with_removals:
			continue
		var y := float(o.key.y) if o.has("key") and o.key is Vector3i else 0.0
		if o.type == "furniture":
			y = float(o.base)
		if r.has_point(o.cell) and (o.type == "terrain" or o.type == "harvest" or (y >= y0 - 0.01 and y < y1)):
			cancel(id)
			n += 1
	return n


func order_at_cell(cell: Vector2i) -> Array:
	return orders.values().filter(func(o): return o.cell == cell)


# ---------------------------------------------------------------- matériaux

func _has_material(o: Dictionary) -> bool:
	if o.type != "block" and o.type != "furniture":
		return true
	var p := _player()
	return p != null and p.inventory.count(o.item) > 0


## Vrai si le plan peut être commencé maintenant (matériaux, support, place libre).
func ready_to_build(o: Dictionary) -> bool:
	match o.type:
		"block":
			if o.get("replace", false) and grid.block_at(o.key) != null:
				return _has_material(o) and grid.block_at(o.key) != o.item
			if grid.block_at(o.key) != null or not grid.can_place_block(o.key, o.item):
				return false
			return _has_material(o) and _supported(o.key)
		"furniture":
			return _has_material(o) and grid.can_place_furniture(o.cell, o.base)
		"remove":
			if o.what == "block":
				# on démolit de haut en bas
				return grid.block_at(o.key) != null and not _index.has("rblock%s" % (o.key + Vector3i(0, 1, 0)))
			if o.what == "prop":
				return world.village_prop(o.prop) != null
			return grid.furniture.has(o.key)
		"terrain":
			return grid.column(o.cell).is_empty() and grid.furniture_in(o.cell).is_empty()
		"harvest":
			return world.decor_at(o.cell) != WorldGenerator.D_NONE
	return false


## Un bloc tient s'il y a un bloc ou le sol dessous, ou un bloc à côté (toits en surplomb).
func _supported(k: Vector3i) -> bool:
	var col := Vector2i(k.x, k.z)
	if world.terrain_height(col) >= k.y - 0.55:
		return true
	if grid.block_at(k - Vector3i(0, 1, 0)) != null:
		return true
	for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		if grid.block_at(k + d) != null:
			return true
	return false


# ---------------------------------------------------------------- réalisation

## Fait avancer un plan ; renvoie vrai quand il est terminé (ou devenu impossible).
func work(o: Dictionary, amount: float) -> bool:
	if not orders.has(o.id):
		return true
	o.progress += amount
	var need: float = WORK.get(o.type, 1.0)
	if o.type == "harvest":
		need = 1.0 if world.decor_at(o.cell) in [WorldGenerator.D_BUSH, WorldGenerator.D_FLOWERS, WorldGenerator.D_GRASS] else need
	if o.type == "terrain":
		need = WORK.terrain * maxf(1.0, absf(world.terrain_height(o.cell) - o.h) / 0.5)
	if o.progress < need:
		return false
	_complete(o)
	return true


## Termine un plan : pose le bloc, retire le meuble, creuse... Faux si impossible pour l'instant.
func _complete(o: Dictionary) -> bool:
	var p := _player()
	var done := false
	match o.type:
		"block":
			if ready_to_build(o) and p and p.inventory.remove(o.item, 1):
				if o.get("replace", false):
					var old: ItemData = grid.remove_block(o.key)
					if old:
						p.inventory.add(old, 1)
				done = grid.place_block(o.key, o.item)
				if done:
					# le bloc remplace la terre dans laquelle il est posé
					var th := world.terrain_height(o.cell)
					if th > o.key.y + 0.01 and th <= o.key.y + 1.05 and grid.furniture_in(o.cell).is_empty():
						world.set_terrain_height(o.cell, float(o.key.y))
						world.refresh_cells([o.cell])
					VoxelBurst.spawn(self, Vector3(o.key.x + 0.5, o.key.y + 1.0, o.key.z + 0.5), BuildMode.it_color(o.item), 6, 1.5, 0.08, 0.3, "up", 6.0, false)
				else:
					p.inventory.add(o.item, 1)
		"furniture":
			if ready_to_build(o) and p and p.inventory.remove(o.item, 1):
				done = grid.place_furniture(o.cell, o.base, o.item, o.rot)
				if not done:
					p.inventory.add(o.item, 1)
		"remove":
			if o.what == "prop":
				for it in world.remove_village_prop(o.prop):
					if p:
						p.inventory.add(it[0], it[1])
			else:
				var got: ItemData = grid.remove_block(o.key) if o.what == "block" else grid.remove_furniture(o.key)
				if got and p:
					p.inventory.add(got, 1)
			done = true
		"terrain":
			if ready_to_build(o):
				_set_height(o.cell, o.h)
			done = true
		"harvest":
			_harvest(o.cell)
			done = true
	if done:
		cancel(o.id)
		# mur avec fenêtre prévue : on prévoit le remplacement par du verre
		if o.type == "block" and o.has("upgrade"):
			add({"type": "block", "key": o.key, "cell": o.cell, "item": o.upgrade, "replace": true})
	return done


func _give(id: String, n: int) -> void:
	var it: ItemData = Items.get_item(id)
	var p := _player()
	if it == null or n <= 0 or p == null:
		return
	p.inventory.add(it, n)


func _harvest(cell: Vector2i) -> void:
	var kind := world.decor_at(cell)
	if kind == WorldGenerator.D_NONE:
		return
	world.remove_decor(cell)
	var col := Color(0.45, 0.7, 0.3) if kind != WorldGenerator.D_ROCK else Color(0.6, 0.6, 0.58)
	VoxelBurst.spawn(self, Vector3(cell.x + 0.5, world.terrain_height(cell) + 1.0, cell.y + 0.5), col, 26, 4.0, 0.14, 0.8, "sphere", 10.0, false)
	for l in HARVEST_LOOT.get(kind, []):
		_give(l[0], randi_range(l[1], l[2]))
	if kind == WorldGenerator.D_ROCK:
		if randf() < 0.3:
			_give("iron_ore", 1)
		if randf() < 0.1:
			_give("marbre_brut", 1)
		if randf() < 0.05:
			_give("or_brut", 1)
	if kind in [WorldGenerator.D_OAK, WorldGenerator.D_PINE] and randf() < 0.3:
		_give("fiber", 1)


## Terrassement : le sol retiré donne de la terre, du sable ou de la pierre (et parfois du minerai).
func _set_height(c: Vector2i, nh: float) -> void:
	var h := world.terrain_height(c)
	var t := world.terrain_type(c)
	nh = clampf(nh, -3.0, 12.0)
	if nh < h:
		var mat := "bloc_terre"
		if t == WorldGenerator.SAND:
			mat = "bloc_sable"
		elif t == WorldGenerator.STONE:
			mat = "stone"
		_dug[mat] = float(_dug.get(mat, 0.0)) + (h - nh)
		if t == WorldGenerator.STONE:
			if randf() < 0.1 * (h - nh):
				_give("iron_ore", 1)
			if h > 1.5 and randf() < 0.12 * (h - nh):
				_give("marbre_brut", 1)
	var kind := world.decor_at(c)
	if kind != WorldGenerator.D_NONE:
		for l in HARVEST_LOOT.get(kind, []):
			_give(l[0], l[1])
	world.set_terrain_height(c, nh)
	world.refresh_cells([c])
	for m in _dug:
		var n := floori(_dug[m])
		if n > 0:
			_dug[m] -= n
			_give(m, n)
	VoxelBurst.spawn(self, Vector3(c.x + 0.5, nh + 0.2, c.y + 0.5), Color(0.55, 0.42, 0.28), 10, 2.5, 0.1, 0.5, "up", 9.0, false)


# ---------------------------------------------------------------- bâtisseurs

## Habitants libres : pas de poste, pas en expédition, pas voyageurs, debout.
func builders() -> Array:
	return get_tree().get_nodes_in_group("villagers").filter(func(v):
		return v.work_room == null and not v.companion and v.is_alive())


## Le plan le plus utile pour cet habitant (le plus bas d'abord, puis le plus proche).
func claim(v: Node3D) -> Variant:
	var best = null
	var best_score := INF
	var now := Time.get_ticks_msec()
	for o in orders.values():
		# déjà pris par un autre habitant qui y travaille encore
		if o.builder != null and is_instance_valid(o.builder) and o.builder != v and is_same(o.builder.get("_order"), o):
			continue
		if int(o.wait_until) > now or not ready_to_build(o):
			continue
		var pos := order_position(o)
		var d := Vector2(pos.x - v.global_position.x, pos.z - v.global_position.z).length()
		if d > 90.0:
			continue
		# on bâtit d'abord (du bas vers le haut), on récolte et on terrasse ensuite
		var score := d + pos.y * 3.0
		if o.type == "remove":
			score -= pos.y * 6.0
		elif o.type == "harvest" or o.type == "terrain":
			score += 80.0
		if score < best_score:
			best_score = score
			best = o
	if best:
		best.builder = v
	return best


func release(o: Dictionary, wait_seconds := 0.0) -> void:
	if orders.has(o.id):
		o.builder = null
		if wait_seconds > 0.0:
			o.wait_until = Time.get_ticks_msec() + int(wait_seconds * 1000.0)


func order_position(o: Dictionary) -> Vector3:
	match o.type:
		"block":
			return Vector3(o.key.x + 0.5, float(o.key.y), o.key.z + 0.5)
		"remove":
			if o.what == "prop":
				return Vector3(o.key.x + 0.5, float(o.key.y), o.key.z + 0.5)
			return Vector3(o.key.x + 0.5, float(o.key.y) if o.what == "block" else float(o.key.y) * 0.5, o.key.z + 0.5)
		"furniture":
			return Vector3(o.cell.x + 0.5, float(o.base), o.cell.y + 0.5)
	return Vector3(o.cell.x + 0.5, world.terrain_height(o.cell), o.cell.y + 0.5)


# ---------------------------------------------------------------- affichage des plans

func _process(_delta: float) -> void:
	if not _dirty:
		return
	_dirty = false
	var list := []
	for o in orders.values():
		if order_position(o).y >= view_cut - 0.01:
			if _furn_ghosts.has(o.id):
				_furn_ghosts[o.id].visible = false
			continue
		if _furn_ghosts.has(o.id):
			_furn_ghosts[o.id].visible = true
		match o.type:
			"block":
				var h := BuildGrid.block_height(o.item)
				list.append([Transform3D(Basis.from_scale(Vector3(1.0, h, 1.0) * 1.01), Vector3(o.key.x + 0.5, o.key.y + h * 0.5, o.key.z + 0.5)),
					C_PLAN if _has_material(o) else C_MISSING])
			"remove":
				if o.what == "block":
					list.append([Transform3D(Basis.from_scale(Vector3.ONE * 1.06), Vector3(o.key.x + 0.5, o.key.y + 0.5, o.key.z + 0.5)), C_REMOVE])
				elif o.what == "prop":
					var pr := world.village_prop(o.prop)
					if pr:
						var box := WorldGenerator.prop_box(pr)
						var rot := Basis(Vector3.UP, pr.rotation.y)
						list.append([Transform3D(rot * Basis.from_scale(box.size * 1.05), pr.global_position + rot * box.position), C_REMOVE])
				else:
					list.append([Transform3D(Basis.from_scale(Vector3(0.9, 1.1, 0.9)), Vector3(o.cell.x + 0.5, o.key.y * 0.5 + 0.55, o.cell.y + 0.5)), C_REMOVE])
			"terrain":
				var h0 := world.terrain_height(o.cell)
				var lo := minf(h0, o.h)
				var hi := maxf(h0, o.h)
				list.append([Transform3D(Basis.from_scale(Vector3(0.96, maxf(hi - lo, 0.06), 0.96)), Vector3(o.cell.x + 0.5, (lo + hi) * 0.5, o.cell.y + 0.5)), C_TERRAIN])
			"harvest":
				list.append([Transform3D(Basis.from_scale(Vector3(0.7, 0.08, 0.7)), Vector3(o.cell.x + 0.5, world.terrain_height(o.cell) + 0.1, o.cell.y + 0.5)), C_HARVEST])
			"furniture":
				if not _furn_ghosts.has(o.id) and o.item.furniture_model:
					var g := o.item.furniture_model.instantiate() as Node3D
					add_child(g)
					g.global_position = Vector3(o.cell.x + 0.5, o.base, o.cell.y + 0.5)
					g.rotation.y = o.rot * PI * 0.5
					_furn_ghosts[o.id] = g
				if _furn_ghosts.has(o.id):
					var mat := _ghost_mat_plan if _has_material(o) else _ghost_mat_missing
					for mi in _furn_ghosts[o.id].find_children("*", "MeshInstance3D", true, false):
						(mi as MeshInstance3D).material_override = mat
						(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := _mm.multimesh
	m.instance_count = list.size()
	for i in list.size():
		m.set_instance_transform(i, list[i][0])
		m.set_instance_color(i, list[i][1])


## Construction instantanée : réalise tout ce qui peut l'être, en plusieurs passes
## (un bloc de toit ne tient qu'une fois son voisin posé).
func flush() -> int:
	var done := 0
	for pass_i in 40:
		var list: Array = orders.values().filter(func(o): return o.type != "harvest" or true)
		list.sort_custom(func(p, q): return order_position(p).y < order_position(q).y)
		var n := 0
		for o in list:
			if orders.has(o.id) and ready_to_build(o) and _complete(o):
				n += 1
		done += n
		if n == 0:
			break
	return done


## À appeler quand le sac change (les plans rouges peuvent redevenir bleus).
func refresh() -> void:
	_dirty = true


# ---------------------------------------------------------------- sauvegarde

func export_state() -> Array:
	var out := []
	for o in orders.values():
		var d := {"type": o.type, "cx": o.cell.x, "cz": o.cell.y}
		if o.has("key"):
			d.k = [o.key.x, o.key.y, o.key.z]
		if o.has("item"):
			d.item = o.item.id
		for f in ["rot", "base", "h", "what", "replace", "prop"]:
			if o.has(f):
				d[f] = o[f]
		if o.has("upgrade"):
			d.upgrade = o.upgrade.id
		out.append(d)
	return out


func import_state(list: Array) -> void:
	for id in orders.keys():
		cancel(id)
	for d in list:
		var o := {"type": d.type, "cell": Vector2i(int(d.cx), int(d.cz))}
		if d.has("k"):
			o.key = Vector3i(int(d.k[0]), int(d.k[1]), int(d.k[2]))
		if d.has("item"):
			o.item = Items.get_item(d.item)
			if o.item == null:
				continue
		for f in ["base", "h"]:
			if d.has(f):
				o[f] = float(d[f])
		if d.has("rot"):
			o.rot = int(d.rot)
		if d.has("what"):
			o.what = str(d.what)
		if d.has("prop"):
			o.prop = str(d.prop)
		if d.has("replace"):
			o.replace = bool(d.replace)
		if d.has("upgrade") and Items.get_item(d.upgrade):
			o.upgrade = Items.get_item(d.upgrade)
		add(o)
