class_name BuildMode
extends Node3D
## Mode construction (touche B / Start) : le joueur récolte, terrasse le sol, pose des blocs et
## des meubles lui-même, comme dans Minecraft.
##   Molette ou 1-9 : choisir l'outil ou l'objet · Clic gauche : utiliser / poser · Clic droit : démolir
##   R : tourner le meuble · [ et ] (ou Maj + molette) : taille du pinceau de terrassement
##   C : vue en coupe · B : quitter.
## Manette : LB/RB choisir · X utiliser · Y démolir · joystick droit : déplacer le curseur.

signal toggled(on: bool)

enum Tool { HARVEST, FLATTEN, DIG, RAISE, DEMOLISH }
const TOOLS := [
	{"id": Tool.HARVEST, "name": "Récolter", "desc": "Couper les arbres, casser les rochers, cueillir.", "color": Color("6aa84a"), "glyph": "⚒"},
	{"id": Tool.FLATTEN, "name": "Aplanir", "desc": "Mettre le sol à plat (maintenir et glisser).", "color": Color("c8a060"), "glyph": "▭"},
	{"id": Tool.DIG, "name": "Creuser", "desc": "Abaisser le sol de 50 cm (récolte terre, sable, pierre...).", "color": Color("8a6a4a"), "glyph": "▼"},
	{"id": Tool.RAISE, "name": "Remblayer", "desc": "Monter le sol de 50 cm.", "color": Color("a08a60"), "glyph": "▲"},
	{"id": Tool.DEMOLISH, "name": "Démolir", "desc": "Retirer un bloc ou un meuble (il revient dans le sac).", "color": Color("c05a4a"), "glyph": "✕"},
]
const REACH := 9.0

var active := false
var slot := 0
var brush := 1
var rotation_step := 0
var force_cut := false

var player: Player
var world: WorldGenerator
var grid: BuildGrid

var _slots: Array = []   # [{tool}, {item}]
var _target := {}
var _ghost: Node3D
var _ghost_mat_ok: StandardMaterial3D
var _ghost_mat_bad: StandardMaterial3D
var _ghost_key := ""
var _repeat := 0.0
var _flatten_level := NAN
var _dug := {}           # matériau -> quantité de sol retiré (m³)
var _gamepad_cursor := Vector3.ZERO
var _use_gamepad := false

# interface
var _ui: CanvasLayer
var _bar: HBoxContainer
var _slot_name: Label
var _slot_desc: Label
var _banner: Label
var _kpanel: RichTextLabel


func _ready() -> void:
	top_level = true
	player = get_parent() as Player
	_ghost_mat_ok = _ghost_material(Color(0.4, 1.0, 0.5, 0.45))
	_ghost_mat_bad = _ghost_material(Color(1.0, 0.35, 0.3, 0.45))
	_build_ui()
	_ui.visible = false


func _ghost_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.no_depth_test = false
	return m


func _find_world() -> void:
	if world == null:
		world = get_tree().get_first_node_in_group("world") as WorldGenerator
	if world and grid == null:
		grid = world.build


func toggle(on: bool) -> void:
	_find_world()
	if grid == null:
		return
	if on and player.global_position.y < WorldGenerator.UNDERGROUND:
		player.notify.emit("Impossible de construire dans un donjon.")
		return
	active = on
	_ui.visible = on
	player.building = on
	if _ghost:
		_ghost.visible = false
	var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
	if k:
		k.set_show_hints(on)
	if on:
		_refresh_slots()
		player.notify.emit("Mode construction : molette pour choisir, clic gauche pour poser, clic droit pour démolir.")
	toggled.emit(on)


# ---------------------------------------------------------------- barre d'objets

func _refresh_slots() -> void:
	_slots.clear()
	for t in TOOLS:
		_slots.append({"tool": t})
	var seen := {}
	for e in player.inventory.entries:
		var it: ItemData = e.item
		if it.is_placeable() and not seen.has(it):
			seen[it] = true
			_slots.append({"item": it})
	slot = clampi(slot, 0, _slots.size() - 1)
	_draw_bar()


func _selected() -> Dictionary:
	return _slots[slot] if slot < _slots.size() else {}


func _select(i: int) -> void:
	if _slots.is_empty():
		return
	slot = posmod(i, _slots.size())
	_ghost_key = ""
	_draw_bar()


# ---------------------------------------------------------------- entrées

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("build_mode") and not player.ui_open and player.is_alive():
		toggle(not active)
		get_viewport().set_input_as_handled()
		return
	if not active or player.ui_open:
		return
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		_use_gamepad = false
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var step := -1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1
			if mb.shift_pressed:
				_set_brush(brush + (2 if step < 0 else -2))
			else:
				_select(slot + step)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_repeat = 0.0
			_flatten_level = NAN
			_use()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_demolish()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		_use_gamepad = false
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.physical_keycode >= KEY_1 and k.physical_keycode <= KEY_9:
			_select(k.physical_keycode - KEY_1)
			get_viewport().set_input_as_handled()
		elif k.physical_keycode == KEY_0:
			_select(9)
			get_viewport().set_input_as_handled()
		elif k.physical_keycode == KEY_R:
			rotation_step = (rotation_step + 1) % 4
			_ghost_key = ""
			get_viewport().set_input_as_handled()
		elif k.physical_keycode == KEY_BRACKETLEFT:
			_set_brush(brush - 2)
			get_viewport().set_input_as_handled()
		elif k.physical_keycode == KEY_BRACKETRIGHT:
			_set_brush(brush + 2)
			get_viewport().set_input_as_handled()
		elif k.physical_keycode == KEY_C:
			force_cut = not force_cut
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		_use_gamepad = true
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_LEFT_SHOULDER:
				_select(slot - 1)
			JOY_BUTTON_RIGHT_SHOULDER:
				_select(slot + 1)
			JOY_BUTTON_X:
				_repeat = 0.0
				_flatten_level = NAN
				_use()
			JOY_BUTTON_Y:
				_demolish()
			JOY_BUTTON_DPAD_UP:
				_set_brush(brush + 2)
			JOY_BUTTON_DPAD_DOWN:
				_set_brush(brush - 2)
			JOY_BUTTON_DPAD_RIGHT:
				rotation_step = (rotation_step + 1) % 4
				_ghost_key = ""
			_:
				return
		get_viewport().set_input_as_handled()


func _set_brush(n: int) -> void:
	brush = clampi(n, 1, 7)
	if brush % 2 == 0:
		brush += 1
	_ghost_key = ""
	_draw_bar()


func _process(delta: float) -> void:
	_find_world()
	_update_cut()
	if not active or grid == null:
		return
	_target = _compute_target()
	_update_ghost()
	# maintenir le bouton : on continue (aplanir en glissant, poser en ligne)
	var held := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_joy_button_pressed(0, JOY_BUTTON_X)
	if held and not player.ui_open:
		_repeat -= delta
		if _repeat <= 0.0:
			_use(true)
	else:
		_flatten_level = NAN
	_update_kingdom_panel()


# ---------------------------------------------------------------- visée

func _compute_target() -> Dictionary:
	var cam := player.camera
	var origin: Vector3
	var dir: Vector3
	if _use_gamepad:
		var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
		if stick.length() > 0.2:
			_gamepad_cursor += Vector3(stick.x, 0, stick.y) * get_process_delta_time() * 6.0
		_gamepad_cursor = _gamepad_cursor.limit_length(REACH - 1.0)
		if _gamepad_cursor.length() < 0.5:
			_gamepad_cursor = Vector3(player.facing.x, 0, player.facing.z) * 2.0
		var aim := player.global_position + _gamepad_cursor
		origin = aim + Vector3(0, 6, 0)
		dir = Vector3.DOWN
	else:
		var mp := get_viewport().get_mouse_position()
		origin = cam.project_ray_origin(mp)
		dir = cam.project_ray_normal(mp)
	var prev := origin
	var t := 0.0
	while t < 80.0:
		var p := origin + dir * t
		var cell := world.cell_at(p)
		if not world._inside(cell):
			prev = p
			t += 0.04
			continue
		# bloc ?
		var key := Vector3i(cell.x, floori(p.y), cell.y)
		var b := grid.block_at(key)
		if b and p.y < key.y + BuildGrid.block_height(b):
			return _hit("block", cell, p, prev, key)
		# meuble ?
		for f in grid.furniture_in(cell):
			if p.y >= f.base and p.y <= f.base + 1.1:
				return _hit("furniture", cell, p, prev, grid.furniture_key(cell, f.base))
		# sol ?
		var ground := world.terrain_height(cell)
		var tt := world.terrain_type(cell)
		if tt == WorldGenerator.WATER or tt == WorldGenerator.DEEP:
			ground = maxf(ground, world.water_surface)
		if p.y <= ground:
			return _hit("terrain", cell, p, prev, Vector3i(cell.x, floori(ground), cell.y))
		prev = p
		t += 0.04
	return {}


func _hit(kind: String, cell: Vector2i, p: Vector3, prev: Vector3, key: Vector3i) -> Dictionary:
	var in_reach := Vector2(p.x - player.global_position.x, p.z - player.global_position.z).length() <= REACH
	return {"kind": kind, "cell": cell, "point": p, "prev": prev, "key": key, "reach": in_reach}


## Où irait un bloc posé maintenant.
func _block_key() -> Vector3i:
	var prev: Vector3 = _target.prev
	var c := world.cell_at(prev)
	var y := floori(prev.y + 0.001)
	if _target.kind == "terrain":
		y = floori(world.terrain_height(c) + 0.3)
		c = _target.cell
		# on pose au-dessus de ce qui existe déjà dans la colonne
		while grid.block_at(Vector3i(c.x, y, c.y)) != null:
			y += 1
	return Vector3i(c.x, y, c.y)


func _furniture_spot() -> Array:
	var prev: Vector3 = _target.prev
	var c: Vector2i = world.cell_at(prev) if _target.kind != "terrain" else _target.cell
	var base := world.support_height(Vector3(c.x + 0.5, 0, c.y + 0.5), prev.y)
	if _target.kind == "terrain":
		base = world.support_height(Vector3(c.x + 0.5, 0, c.y + 0.5), world.terrain_height(c) + 0.1)
	return [c, base]


func _overlaps_player(col: Vector2i, bottom: float, top: float) -> bool:
	for n in get_tree().get_nodes_in_group("combatants"):
		var cb := n as Node3D
		if world.cell_at(cb.global_position) == col and bottom < cb.global_position.y + 1.6 and top > cb.global_position.y + 0.05:
			return true
	return false


func _brush_cells(center: Vector2i) -> Array:
	var out := []
	var r := brush / 2
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			out.append(center + Vector2i(dx, dz))
	return out


# ---------------------------------------------------------------- aperçu

func _update_ghost() -> void:
	if _target.is_empty():
		if _ghost:
			_ghost.visible = false
		return
	var s := _selected()
	var key := ""
	var xf := Transform3D.IDENTITY
	var ok: bool = _target.reach
	var size := Vector3.ONE
	var model: PackedScene = null
	if s.has("tool"):
		var tid: int = s.tool.id
		if tid == Tool.DEMOLISH or tid == Tool.HARVEST:
			key = "box1"
			var c: Vector2i = _target.cell
			if _target.kind == "block":
				var k: Vector3i = _target.key
				xf.origin = Vector3(k.x + 0.5, k.y + 0.5, k.z + 0.5)
			elif _target.kind == "furniture":
				xf.origin = Vector3(c.x + 0.5, _target.point.y, c.y + 0.5)
			else:
				xf.origin = Vector3(c.x + 0.5, world.terrain_height(c) + 0.5, c.y + 0.5)
			size = Vector3(1.04, 1.04, 1.04)
			if tid == Tool.HARVEST:
				ok = ok and world.decor_at(c) != WorldGenerator.D_NONE
				if _target.kind != "terrain":
					ok = false
			else:
				ok = ok and _target.kind != "terrain"
		else:
			key = "brush%d" % brush
			var c2: Vector2i = _target.cell
			var lvl := world.terrain_height(c2)
			if tid == Tool.FLATTEN and not is_nan(_flatten_level):
				lvl = _flatten_level
			xf.origin = Vector3(c2.x + 0.5, lvl + 0.06, c2.y + 0.5)
			size = Vector3(brush, 0.12, brush)
	elif s.has("item"):
		var it: ItemData = s.item
		if it.is_block():
			var k := _block_key()
			var h := BuildGrid.block_height(it)
			key = "block%s" % h
			size = Vector3(1.02, h + 0.02, 1.02)
			xf.origin = Vector3(k.x + 0.5, k.y + h * 0.5, k.z + 0.5)
			ok = ok and grid.can_place_block(k, it) and not _overlaps_player(Vector2i(k.x, k.z), k.y, k.y + h)
		else:
			var spot := _furniture_spot()
			key = "furn_%s_%d" % [it.id, rotation_step]
			model = it.furniture_model
			xf = Transform3D(Basis(Vector3.UP, rotation_step * PI * 0.5), Vector3(spot[0].x + 0.5, spot[1], spot[0].y + 0.5))
			ok = ok and grid.can_place_furniture(spot[0], spot[1]) and world.is_walkable(Vector3(spot[0].x + 0.5, 0, spot[0].y + 0.5))
	if key != _ghost_key:
		_ghost_key = key
		if _ghost:
			_ghost.queue_free()
		if model:
			_ghost = model.instantiate() as Node3D
		else:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = size
			mi.mesh = bm
			_ghost = mi
		add_child(_ghost)
	_ghost.visible = true
	_ghost.global_transform = xf
	var mat := _ghost_mat_ok if ok else _ghost_mat_bad
	for mi in ([_ghost] + _ghost.find_children("*", "MeshInstance3D", true, false)):
		if mi is MeshInstance3D:
			(mi as MeshInstance3D).material_override = mat
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ---------------------------------------------------------------- actions

func _use(repeat := false) -> void:
	if _target.is_empty() or not _target.reach:
		return
	var s := _selected()
	if s.has("tool"):
		match int(s.tool.id):
			Tool.HARVEST:
				if not repeat:
					_harvest(_target.cell)
				_repeat = 0.35
			Tool.FLATTEN:
				if is_nan(_flatten_level):
					_flatten_level = roundf(world.terrain_height(_target.cell))
				_terraform(_brush_cells(_target.cell), func(_h): return _flatten_level)
				_repeat = 0.08
			Tool.DIG:
				_terraform(_brush_cells(_target.cell), func(h): return h - 0.5)
				_repeat = 0.3
			Tool.RAISE:
				_terraform(_brush_cells(_target.cell), func(h): return h + 0.5)
				_repeat = 0.3
			Tool.DEMOLISH:
				if not repeat:
					_demolish()
				_repeat = 0.25
	elif s.has("item"):
		_place(s.item)
		_repeat = 0.18


func _place(it: ItemData) -> void:
	if player.inventory.count(it) <= 0:
		_refresh_slots()
		return
	var ok := false
	if it.is_block():
		var k := _block_key()
		var h := BuildGrid.block_height(it)
		if _overlaps_player(Vector2i(k.x, k.z), k.y, k.y + h):
			return
		ok = grid.place_block(k, it)
		if ok:
			VoxelBurst.spawn(self, Vector3(k.x + 0.5, k.y + h, k.z + 0.5), it_color(it), 6, 1.5, 0.08, 0.3, "up", 6.0, false)
	else:
		var spot := _furniture_spot()
		if not world.is_walkable(Vector3(spot[0].x + 0.5, 0, spot[0].y + 0.5)):
			return
		ok = grid.place_furniture(spot[0], spot[1], it, rotation_step)
		if ok:
			VoxelBurst.spawn(self, Vector3(spot[0].x + 0.5, spot[1] + 0.2, spot[0].y + 0.5), Color(1, 0.95, 0.8), 12, 2.0, 0.07, 0.4, "ring", 0.0)
	if ok:
		player.inventory.remove(it, 1)
		if player.inventory.count(it) == 0:
			_refresh_slots()
		else:
			_draw_bar()


static func it_color(it: ItemData) -> Color:
	if it.block_texture:
		var img := it.block_texture.get_image()
		if img:
			if img.is_compressed():
				img.decompress()
			return img.get_pixel(8, 8)
	return Color(0.8, 0.7, 0.5)


func _demolish() -> void:
	if _target.is_empty() or not _target.reach:
		return
	var got: ItemData = null
	if _target.kind == "block":
		got = grid.remove_block(_target.key)
	elif _target.kind == "furniture":
		got = grid.remove_furniture(_target.key)
	if got:
		player.inventory.add(got, 1)
		VoxelBurst.spawn(self, _target.point, it_color(got), 14, 3.0, 0.09, 0.5, "sphere", 10.0, false)
		player.visual.play_move("punch_1", 1.3)
		_refresh_slots()


const HARVEST_LOOT := {
	WorldGenerator.D_OAK: [["wood", 3, 4]], WorldGenerator.D_PINE: [["wood", 3, 5]],
	WorldGenerator.D_BUSH: [["fiber", 2, 3]], WorldGenerator.D_FLOWERS: [["fiber", 1, 1]], WorldGenerator.D_GRASS: [["fiber", 1, 1]],
	WorldGenerator.D_ROCK: [["stone", 2, 4]],
}


func _harvest(cell: Vector2i) -> void:
	var kind := world.decor_at(cell)
	if kind == WorldGenerator.D_NONE:
		return
	# regarder la cible et frapper
	var to := Vector3(cell.x + 0.5, 0, cell.y + 0.5) - player.global_position
	to.y = 0.0
	if to.length() > 0.1:
		player.facing = to.normalized()
	player.visual.play_move("heavy_1" if kind in [WorldGenerator.D_OAK, WorldGenerator.D_PINE, WorldGenerator.D_ROCK] else "punch_1", 1.6)
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


func _give(id: String, n: int) -> void:
	var it: ItemData = Items.get_item(id)
	if it == null or n <= 0:
		return
	player.inventory.add(it, n)
	Combat.popup(player, player.global_position + Vector3(0, 2.2, 0), "+%d %s" % [n, it.display_name], Color("e8f0c0"))
	if it.is_placeable():
		_refresh_slots()


## Applique `new_height(h)` à chaque case ; le sol retiré donne de la terre, du sable ou de la pierre.
func _terraform(cells: Array, new_height: Callable) -> void:
	var changed := []
	for c in cells:
		if not world._inside(c) or grid.column(c).size() > 0 or not grid.furniture_in(c).is_empty():
			continue
		var h := world.terrain_height(c)
		var t := world.terrain_type(c)
		var nh: float = clampf(new_height.call(h), -3.0, 12.0)
		if absf(nh - h) < 0.01:
			continue
		# on ne s'enterre pas soi-même
		if nh > h and _overlaps_player(c, h, nh):
			continue
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
				if h > 2.5 and randf() < 0.05 * (h - nh):
					_give("or_brut", 1)
		var kind := world.decor_at(c)
		if kind != WorldGenerator.D_NONE:
			for l in HARVEST_LOOT.get(kind, []):
				_give(l[0], l[1])
		world.set_terrain_height(c, nh)
		changed.append(c)
	if changed.is_empty():
		return
	world.refresh_cells(changed)
	for m in _dug:
		var n := floori(_dug[m])
		if n > 0:
			_dug[m] -= n
			_give(m, n)
	var c0: Vector2i = changed[0]
	VoxelBurst.spawn(self, Vector3(c0.x + 0.5, world.terrain_height(c0) + 0.2, c0.y + 0.5), Color(0.55, 0.42, 0.28), 10, 2.5, 0.1, 0.5, "up", 9.0, false)
	if not player.visual.is_attacking():
		player.visual.play_move("heavy_2", 2.0)


# ---------------------------------------------------------------- vue en coupe

func _update_cut() -> void:
	if grid == null or player == null:
		return
	var feet := player.global_position.y
	var col := world.cell_at(player.global_position)
	var ceiling := INF
	for b in grid.column(col):
		if b[1] > feet + 1.7:
			ceiling = minf(ceiling, b[1])
	if ceiling < INF:
		grid.set_cut(player.global_position, ceiling - 0.05, 12.0)
	elif active and force_cut:
		grid.set_cut(player.global_position, feet + 2.05, 12.0)
	else:
		grid.set_cut(Vector3.ZERO, 10000.0, 0.0)


# ---------------------------------------------------------------- interface

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 2
	add_child(_ui)
	_banner = Label.new()
	_banner.text = "MODE CONSTRUCTION"
	_banner.add_theme_font_size_override("font_size", 16)
	_banner.add_theme_color_override("font_color", Color("f2c86a"))
	_banner.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	_banner.add_theme_constant_override("outline_size", 6)
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.position = Vector2(-90, 96)
	_ui.add_child(_banner)
	var help := Label.new()
	help.text = "Molette/1-9/LB-RB : choisir   Clic gauche/X : utiliser   Clic droit/Y : démolir   R : tourner   [ ] : pinceau   C : coupe   B : quitter"
	help.add_theme_font_size_override("font_size", 10)
	help.add_theme_color_override("font_color", Color("f0e6d2"))
	help.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	help.add_theme_constant_override("outline_size", 4)
	help.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	help.position = Vector2(-330, -18)
	_ui.add_child(help)
	var panel := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.06, 0.05, 0.86)
	st.border_color = Color("8a6a3a")
	st.set_border_width_all(2)
	st.set_corner_radius_all(4)
	st.set_content_margin_all(5)
	panel.add_theme_stylebox_override("panel", st)
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.position = Vector2(-330, -104)
	panel.custom_minimum_size = Vector2(660, 82)
	_ui.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_slot_name = Label.new()
	_slot_name.add_theme_font_size_override("font_size", 13)
	_slot_name.add_theme_color_override("font_color", Color("f2c86a"))
	head.add_child(_slot_name)
	_slot_desc = Label.new()
	_slot_desc.add_theme_font_size_override("font_size", 10)
	_slot_desc.add_theme_color_override("font_color", Color("c8b89a"))
	_slot_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_slot_desc)
	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 3)
	v.add_child(_bar)
	# panneau du royaume (à droite)
	var kp := PanelContainer.new()
	kp.add_theme_stylebox_override("panel", st)
	kp.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	kp.position = Vector2(-262, 90)
	kp.custom_minimum_size = Vector2(252, 0)
	_ui.add_child(kp)
	_kpanel = RichTextLabel.new()
	_kpanel.bbcode_enabled = true
	_kpanel.fit_content = true
	_kpanel.scroll_active = false
	_kpanel.custom_minimum_size = Vector2(240, 0)
	_kpanel.add_theme_font_size_override("normal_font_size", 10)
	_kpanel.add_theme_color_override("default_color", Color("f0e6d2"))
	kp.add_child(_kpanel)


func _draw_bar() -> void:
	if _bar == null:
		return
	for c in _bar.get_children():
		c.queue_free()
	var first := clampi(slot - 5, 0, maxi(0, _slots.size() - 12))
	for i in range(first, mini(first + 12, _slots.size())):
		var s: Dictionary = _slots[i]
		var box := PanelContainer.new()
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.12, 0.09, 0.07)
		st.border_color = Color("f2c86a") if i == slot else Color("4a3a2a")
		st.set_border_width_all(2 if i == slot else 1)
		st.set_corner_radius_all(3)
		st.set_content_margin_all(1)
		box.add_theme_stylebox_override("panel", st)
		box.custom_minimum_size = Vector2(50, 50)
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(46, 46)
		box.add_child(holder)
		if s.has("tool"):
			var bg := ColorRect.new()
			bg.color = (s.tool.color as Color).darkened(0.35)
			bg.position = Vector2(4, 4)
			bg.size = Vector2(38, 38)
			holder.add_child(bg)
			var g := Label.new()
			g.text = s.tool.glyph
			g.add_theme_font_size_override("font_size", 20)
			g.position = Vector2(13, 8)
			holder.add_child(g)
		else:
			var tr := TextureRect.new()
			tr.texture = Items.get_icon(s.item)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.size = Vector2(46, 46)
			holder.add_child(tr)
			var n := Label.new()
			n.text = str(player.inventory.count(s.item))
			n.add_theme_font_size_override("font_size", 10)
			n.add_theme_color_override("font_outline_color", Color.BLACK)
			n.add_theme_constant_override("outline_size", 3)
			n.position = Vector2(30, 30)
			holder.add_child(n)
		if i < 9:
			var key := Label.new()
			key.text = str(i + 1)
			key.add_theme_font_size_override("font_size", 9)
			key.add_theme_color_override("font_color", Color("c8b89a"))
			key.position = Vector2(2, 0)
			holder.add_child(key)
		_bar.add_child(box)
	var sel := _selected()
	if sel.has("tool"):
		_slot_name.text = sel.tool.name + ("  (pinceau %d×%d)" % [brush, brush] if sel.tool.id in [Tool.FLATTEN, Tool.DIG, Tool.RAISE] else "")
		_slot_desc.text = sel.tool.desc
	elif sel.has("item"):
		var it: ItemData = sel.item
		_slot_name.text = it.display_name
		_slot_desc.text = ("Bloc · %s" % ItemData.TIER_NAMES[it.block_tier]) if it.is_block() else "Meuble · R pour tourner"


func _update_kingdom_panel() -> void:
	var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
	if k == null or _kpanel == null:
		return
	var lines := ["[color=#f2c86a][font_size=13]%s[/font_size][/color]" % Kingdom.RANK_NAMES[k.rank],
		"[color=#%s]%s[/color]" % [Kingdom.AGE_COLORS[k.age].to_html(false), Kingdom.AGE_NAMES[k.age]],
		"[color=#a8997f]%s\n%s[/color]" % [k.next_goal(), k.next_age_goal()], ""]
	var typed := k.typed_rooms()
	lines.append("[color=#f2c86a]Pièces (%d) · Lits : %d[/color]" % [typed.size(), k.beds()])
	for r in typed:
		var t: RoomTypeData = r.type
		var job := ""
		if t.job_slots > 0:
			job = " · %s %d/%d" % [t.job_name, k.workers_of(r).size(), t.job_slots]
		lines.append("[color=#%s]■[/color] %s [color=#a8997f](%s%s)[/color]" % [t.color.to_html(false), t.display_name, ItemData.TIER_NAMES[r.tier], job])
	_kpanel.text = "\n".join(lines)
