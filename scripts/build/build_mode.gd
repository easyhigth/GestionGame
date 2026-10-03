class_name BuildMode
extends Node3D
## Mode construction (touche B / croix bas), inspiré de Going Medieval :
## le héros reste sur place et une caméra libre survole le village. On choisit une catégorie
## (terrain, murs, sols, toits, portes et fenêtres, mobilier, démolir), un outil et un matériau,
## puis on clique-glisse pour tracer des plans (fantômes bleus). Les habitants libres viennent
## les construire avec les matériaux du sac ; un plan rouge attend des matériaux.
## On travaille sur un niveau (Page ↑ / Page ↓) : les murs partent de ce niveau, les sols
## sont posés dessous, et tout ce qui est au-dessus peut être caché (C) pour voir l'intérieur.
##   Caméra : ZQSD/flèches (Maj : vite) · molette : zoom · clic molette + glisser ou A/E : tourner
##   Clic gauche (glisser) : tracer · Clic droit : annuler le tracé ou le plan visé · R : tourner le meuble
##   1-8 : catégorie · [ ] : hauteur des murs · C : couper au-dessus du niveau · B / Échap : quitter
## Manette : joystick gauche : déplacer · droit : tourner / zoom · A : tracer · B : annuler · Y : tourner
##   LB/RB : catégorie · croix gauche/droite : outil · croix haut : matériau · gâchettes : niveau.

signal toggled(on: bool)

const CATEGORIES := [
	{"id": "terrain", "name": "Terrain", "glyph": "⛏", "tools": [
		{"id": "harvest", "name": "Récolter", "desc": "Zone : les habitants coupent les arbres, cassent les rochers, cueillent."},
		{"id": "flatten", "name": "Aplanir", "desc": "Zone : mettre le sol à la hauteur du niveau choisi (fondations)."},
		{"id": "dig", "name": "Creuser", "desc": "Zone : abaisser le sol de 50 cm (terre, sable, pierre récoltés)."},
		{"id": "raise", "name": "Remblayer", "desc": "Zone : monter le sol de 50 cm."}]},
	{"id": "walls", "name": "Murs", "glyph": "▥", "material": "bloc_planches", "tools": [
		{"id": "wall_room", "name": "Pièce", "desc": "Glisser : les quatre murs d'une pièce (rectangle)."},
		{"id": "wall_line", "name": "Mur", "desc": "Glisser : un mur droit."}]},
	{"id": "floors", "name": "Sols", "glyph": "▦", "material": "bloc_planches", "tools": [
		{"id": "floor", "name": "Sol", "desc": "Glisser : un plancher au niveau choisi (dessus = niveau)."}]},
	{"id": "roofs", "name": "Toits", "glyph": "⌂", "material": "bloc_chaume", "tools": [
		{"id": "roof_gable", "name": "Toit à deux pans", "desc": "Glisser sur la pièce, au niveau du haut des murs : toit en pente avec débord."},
		{"id": "roof_flat", "name": "Toit plat", "desc": "Glisser : toit plat (ou terrasse) au niveau choisi."}]},
	{"id": "openings", "name": "Portes et fenêtres", "glyph": "◫", "tools": [
		{"id": "door", "name": "Porte", "desc": "Clic sur un mur (au niveau choisi) : y percer une porte."},
		{"id": "window", "name": "Fenêtre", "desc": "Clic sur un mur : une fenêtre en verre à hauteur des yeux."}]},
	{"id": "furniture", "name": "Mobilier", "glyph": "♜", "tools": []},
	{"id": "demolish", "name": "Démolir", "glyph": "✕", "tools": [
		{"id": "demolish", "name": "Démolir", "desc": "Zone : démonter les blocs, les meubles et les décors du village (à partir du niveau choisi) ; tout revient dans le sac."},
		{"id": "cancel", "name": "Annuler les plans", "desc": "Zone : effacer les plans pas encore construits."}]},
	{"id": "plans", "name": "Plans prêts", "glyph": "★", "tools": []},
]
## Meubles sans pièce précise, montrés en premier.
const COMMON_FURNITURE := ["torche", "lanterne", "table", "chaise", "coffre", "lit", "tonneau", "bougeoir", "statue"]
const MAX_FROM_HERO := 55.0

var active := false
## catégorie au départ : les plans prêts (le plus simple pour commencer)
var cat := 7
var plan_index := 0
var tool_index := 0
var furniture_index := 0
var wall_height := 3
var layer := 0
var rotation_step := 0
var cut_on := true
var materials := {}           # catégorie -> id du matériau
var force_cut := false        # (ancien réglage, gardé pour compatibilité)

var player: Player
var world: WorldGenerator
var grid: BuildGrid
var orders: BuildOrders

# caméra libre
var _cam: Camera3D
var _focus := Vector3.ZERO
var _yaw := 0.0
var _pitch := deg_to_rad(55.0)
var _dist := 18.0
var _orbiting := false

# tracé
var _cursor := Vector2i.ZERO
var _cursor_ok := false
var _dragging := false
var _drag_from := Vector2i.ZERO
var _pad_held := false
var _trig := [false, false]
var _selection: Array = []   # [[Vector3i ou Vector2i, type]]
var _preview: MultiMeshInstance3D
var _preview_mat: StandardMaterial3D
var _ghost: Node3D
var _ghost_key := ""
var _furniture_items: Array[ItemData] = []

# interface
var _ui: CanvasLayer
var _cat_bar: HBoxContainer
var _tool_bar: HBoxContainer
var _mat_bar: HBoxContainer
var _tool_name: Label
var _tool_desc: Label
var _sel_info: Label
var _layer_label: Label
var _builders_label: Label
var _instant_cb: CheckBox
var _kpanel: RichTextLabel
var _help: Label


func _ready() -> void:
	top_level = true
	player = get_parent() as Player
	_preview_mat = StandardMaterial3D.new()
	_preview_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_preview_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_preview_mat.vertex_color_use_as_albedo = true
	_preview = MultiMeshInstance3D.new()
	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var box := BoxMesh.new()
	box.material = _preview_mat
	mm.mesh = box
	_preview.multimesh = mm
	add_child(_preview)
	_cam = Camera3D.new()
	_cam.fov = 55.0
	_cam.far = 400.0
	add_child(_cam)
	for c in CATEGORIES:
		if c.has("material"):
			materials[c.id] = c.material
	_build_ui()
	_ui.visible = false
	_connect_player.call_deferred()


func _connect_player() -> void:
	if player:
		player.inventory.changed.connect(func(): if active: _refresh_ui())
		player.health.damaged.connect(func(_a, _s):
			if active:
				toggle(false)
				player.notify.emit("Tu es attaqué ! Retour au héros."))


func _find_world() -> void:
	if world == null:
		world = get_tree().get_first_node_in_group("world") as WorldGenerator
	if world and grid == null:
		grid = world.build
	if world and orders == null:
		orders = get_tree().get_first_node_in_group("build_orders") as BuildOrders


func toggle(on: bool) -> void:
	_find_world()
	if grid == null or orders == null:
		return
	if on and player.global_position.y < WorldGenerator.UNDERGROUND:
		player.notify.emit("Impossible de construire dans un donjon.")
		return
	active = on
	_ui.visible = on
	player.building = on
	_dragging = false
	_preview.visible = on
	if _ghost:
		_ghost.visible = false
	var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
	if k:
		k.set_show_hints(on)
	if on:
		player.velocity = Vector3.ZERO
		player.set_blocking(false)
		_focus = player.global_position
		_yaw = player.cam_yaw
		layer = roundi(world.terrain_height(world.cell_at(_focus)))
		_cam.make_current()
		_update_camera(1.0)
		_refresh_ui()
		player.notify.emit("Mode construction : trace des plans ; tes habitants libres les bâtissent, ou toi-même en te tenant à côté.")
	else:
		player.camera.make_current()
		world.stream_focus = Vector3.INF
		orders.view_cut = INF
		orders.refresh()
		grid.set_cut(Vector3.ZERO, 10000.0, 0.0)
	toggled.emit(on)


# ---------------------------------------------------------------- outils

func _category() -> Dictionary:
	return CATEGORIES[cat]


func _tool() -> Dictionary:
	var c := _category()
	if c.id == "plans":
		var t := _plan_type()
		if t == null:
			return {"id": "plan", "name": "Plans prêts", "desc": ""}
		return {"id": "plan", "name": t.display_name,
			"desc": "Clic : toute la pièce d'un coup (murs, sol, porte, toit et meubles). Tes habitants la bâtissent, ou toi-même en te tenant à côté ; les meubles manquants sont à fabriquer. Matériaux : ceux choisis dans Murs, Sols et Toits."}
	if c.id == "furniture":
		var it := _furniture_item()
		return {"id": "furniture", "name": it.display_name if it else "Mobilier",
			"desc": "Clic : poser le meuble au niveau choisi (R : tourner). %s" % _furniture_use(it)}
	return c.tools[clampi(tool_index, 0, c.tools.size() - 1)]


func _material() -> ItemData:
	var id: String = materials.get(_category().id, "")
	return Items.get_item(id) if id != "" else null


func _furniture_item() -> ItemData:
	if _furniture_items.is_empty():
		return null
	return _furniture_items[clampi(furniture_index, 0, _furniture_items.size() - 1)]


## À quelles pièces sert ce meuble.
func _furniture_use(it: ItemData) -> String:
	if it == null:
		return ""
	var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
	var names := []
	if k:
		for t in k.room_types:
			if t.required.has(it.id):
				names.append(t.display_name)
	return ("Sert pour : " + ", ".join(PackedStringArray(names)) + ".") if not names.is_empty() else ""


func _list_furniture() -> void:
	_furniture_items.clear()
	var ids: Array = COMMON_FURNITURE.duplicate()
	var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
	if k:
		for t in k.room_types:
			for id in t.required:
				if not ids.has(id):
					ids.append(id)
	for id in Items.items:
		var it: ItemData = Items.get_item(id)
		if it and it.is_furniture() and not it.furniture_door and not ids.has(id):
			ids.append(id)
	for id in ids:
		var it: ItemData = Items.get_item(id)
		if it and it.is_furniture() and not it.furniture_door:
			_furniture_items.append(it)


func _set_category(i: int) -> void:
	cat = posmod(i, CATEGORIES.size())
	tool_index = 0
	_dragging = false
	_ghost_key = ""
	_refresh_ui()


## Types de pièces des plans prêts (maison, dortoir et entrepôt d'abord).
func _plan_types() -> Array:
	var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
	if k == null:
		return []
	var list: Array = k.room_types.duplicate()
	var first := ["maison", "dortoir", "entrepot"]
	list.sort_custom(func(a, b):
		var ia := first.find(a.id)
		var ib := first.find(b.id)
		if ia >= 0 or ib >= 0:
			return ia >= 0 and (ib < 0 or ia < ib)
		return a.display_name < b.display_name)
	return list


func _plan_type() -> RoomTypeData:
	var list := _plan_types()
	return list[clampi(plan_index, 0, list.size() - 1)] if not list.is_empty() else null


## Plan d'une pièce complète centrée sur `c` : [[position, sorte, objet], ...]
## (sortes : wall, floor, roof, gable, door, furniture).
func plan_layout(t: RoomTypeData, c: Vector2i) -> Array:
	var furn := []
	for id in t.required:
		for i in int(t.required[id]):
			furn.append(id)
	var area := maxi(t.min_cells, furn.size() + 3)
	var w := maxi(2, ceili(sqrt(float(area))))
	var d := maxi(2, ceili(float(area) / float(w)))
	if d > w:
		var tmp := w
		w = d
		d = tmp
	var o := Vector2i(c.x - (w + 2) / 2, c.y - (d + 2) / 2)
	var r := Rect2i(o, Vector2i(w + 2, d + 2))
	var door := Vector2i(o.x + (w + 2) / 2, o.y)
	var out := []
	for x in range(r.position.x, r.end.x):
		for z in range(r.position.y, r.end.y):
			var cell := Vector2i(x, z)
			var edge := x == r.position.x or x == r.end.x - 1 or z == r.position.y or z == r.end.y - 1
			if not edge:
				out.append([Vector3i(x, layer - 1, z), "floor"])
				continue
			for y in range(layer, layer + wall_height):
				if cell == door and y < layer + 2:
					continue
				if y + 1 <= world.terrain_height(cell) - 0.3:
					continue
				out.append([Vector3i(x, y, z), "wall"])
	# toit à deux pans, avec débord, pignons fermés
	var top := layer + wall_height
	var rr := r.grow(1)
	var span := r.size.y
	for x in range(rr.position.x, rr.end.x):
		for z in range(rr.position.y, rr.end.y):
			var i := z - rr.position.y
			var st := mini(i, span + 1 - i)
			out.append([Vector3i(x, top + st, z), "roof"])
			if (x == r.position.x or x == r.end.x - 1) and st > 0:
				for yy in range(top, top + st):
					out.append([Vector3i(x, yy, z), "gable"])
	out.append([Vector3i(door.x, layer, door.y), "door"])
	# meubles : du fond vers l'entrée, en laissant libre la case devant la porte
	var cells := []
	for z in range(r.end.y - 2, r.position.y, -1):
		for x in range(r.position.x + 1, r.end.x - 1):
			if Vector2i(x, z) != door + Vector2i(0, 1):
				cells.append(Vector2i(x, z))
	for i in mini(furn.size(), cells.size()):
		out.append([Vector3i(cells[i].x, layer, cells[i].y), "furniture", furn[i]])
	return out


## Ouvre le mode construction sur le plan prêt d'un type de pièce (depuis le panneau du royaume).
func open_plan(type_id: String) -> void:
	if not active:
		toggle(true)
	if not active:
		return
	cat = CATEGORIES.size() - 1
	var list := _plan_types()
	for i in list.size():
		if list[i].id == type_id:
			plan_index = i
	_refresh_ui()
	var t := _plan_type()
	if t:
		player.notify.emit("Plan « %s » : clique sur le sol pour le poser ; tes habitants le bâtiront." % t.display_name)


func _cycle_tool(step: int) -> void:
	if _category().id == "plans":
		plan_index = posmod(plan_index + step, maxi(1, _plan_types().size()))
		_refresh_ui()
		return
	if _category().id == "furniture":
		furniture_index = posmod(furniture_index + step, maxi(1, _furniture_items.size()))
	else:
		tool_index = posmod(tool_index + step, _category().tools.size())
	_ghost_key = ""
	_refresh_ui()


func _cycle_material(step: int) -> void:
	var list := _block_items()
	if list.is_empty() or not materials.has(_category().id):
		return
	var cur := list.find(_material())
	materials[_category().id] = (list[posmod(cur + step, list.size())] as ItemData).id
	_refresh_ui()


func _block_items() -> Array:
	var out := []
	var cur: Variant = Items.get_item(materials.get(_category().id, "")) if materials.has(_category().id) else null
	for id in Items.items:
		var it: ItemData = Items.get_item(id)
		# les blocs de base, et ceux du catalogue (BlockCatalog) que le héros possède
		if it and it.is_block() and (it.block_texture.resource_path != "" or it == cur or (player and player.inventory.count(it) > 0)):
			out.append(it)
	out.sort_custom(func(a, b): return a.block_tier < b.block_tier or (a.block_tier == b.block_tier and a.id < b.id))
	return out


func _set_layer(v: int) -> void:
	layer = clampi(v, -3, 40)
	_refresh_ui()


# ---------------------------------------------------------------- entrées

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("build_mode") and not player.ui_open and player.is_alive():
		toggle(not active)
		get_viewport().set_input_as_handled()
		return
	if not active or player.ui_open:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		if _dragging:
			_dragging = false
		else:
			toggle(false)
		get_viewport().set_input_as_handled()
		return
	var handled := true
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_MIDDLE:
				_orbiting = mb.pressed
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					var up := mb.button_index == MOUSE_BUTTON_WHEEL_UP
					if mb.ctrl_pressed:
						_set_layer(layer + (1 if up else -1))
					else:
						_dist = clampf(_dist * (0.88 if up else 1.12), 5.0, 60.0)
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_press()
			MOUSE_BUTTON_RIGHT:
				if mb.pressed:
					_cancel_action()
			_:
				handled = false
	elif event is InputEventMouseMotion:
		if _orbiting:
			var mm := event as InputEventMouseMotion
			_yaw -= mm.relative.x * 0.008
			_pitch = clampf(_pitch + mm.relative.y * 0.006, deg_to_rad(25.0), deg_to_rad(85.0))
		handled = _orbiting
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		match k.physical_keycode:
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8:
				_set_category(k.physical_keycode - KEY_1)
			KEY_PAGEUP:
				_set_layer(layer + 1)
			KEY_PAGEDOWN:
				_set_layer(layer - 1)
			KEY_R:
				rotation_step = (rotation_step + 1) % 4
				_ghost_key = ""
			KEY_BRACKETLEFT:
				wall_height = clampi(wall_height - 1, 1, 6)
				_refresh_ui()
			KEY_BRACKETRIGHT:
				wall_height = clampi(wall_height + 1, 1, 6)
				_refresh_ui()
			KEY_C:
				cut_on = not cut_on
				_refresh_ui()
			KEY_TAB:
				_cycle_tool(-1 if k.shift_pressed else 1)
			KEY_V:
				_cycle_material(-1 if k.shift_pressed else 1)
			_:
				handled = false
	elif event is InputEventJoypadButton and event.pressed:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_A:
				_press()
				_pad_held = true
			JOY_BUTTON_B:
				_cancel_action()
			JOY_BUTTON_Y:
				rotation_step = (rotation_step + 1) % 4
				_ghost_key = ""
			JOY_BUTTON_LEFT_SHOULDER:
				_set_category(cat - 1)
			JOY_BUTTON_RIGHT_SHOULDER:
				_set_category(cat + 1)
			JOY_BUTTON_DPAD_LEFT:
				_cycle_tool(-1)
			JOY_BUTTON_DPAD_RIGHT:
				_cycle_tool(1)
			JOY_BUTTON_DPAD_UP:
				_cycle_material(1)
			_:
				handled = false
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_find_world()
	if not active or grid == null:
		_update_cut()
		return
	if player.ui_open:
		_preview.visible = false
		return
	_preview.visible = true
	_update_camera(delta)
	# gâchettes de la manette : niveau
	for i in 2:
		var v := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT if i == 0 else JOY_AXIS_TRIGGER_RIGHT)
		if v > 0.6 and not _trig[i]:
			_trig[i] = true
			_set_layer(layer + (-1 if i == 0 else 1))
		elif v < 0.3:
			_trig[i] = false
	_update_cursor()
	# fin du tracé : bouton relâché (même au-dessus de l'interface)
	if _dragging:
		var held := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or (_pad_held and Input.is_joy_button_pressed(0, JOY_BUTTON_A))
		if not held:
			_commit()
	if not Input.is_joy_button_pressed(0, JOY_BUTTON_A):
		_pad_held = false
	_update_selection()
	_update_preview()
	var cut_y := (layer + wall_height + 0.02) if cut_on else INF
	grid.set_cut(_focus, cut_y if cut_on else 10000.0, 400.0 if cut_on else 0.0)
	if orders.view_cut != cut_y:
		orders.view_cut = cut_y
		orders.refresh()
	_builders_label.text = _builders_text()
	_update_kingdom_panel()


# ---------------------------------------------------------------- caméra libre

func _update_camera(delta: float) -> void:
	var pan := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var fast := Input.is_key_pressed(KEY_SHIFT)
	if pan.length() > 0.05:
		var move := Vector3(pan.x, 0, pan.y).rotated(Vector3.UP, _yaw) * (_dist * 0.9 + 6.0) * delta * (2.2 if fast else 1.0)
		_focus += move
	# rotation clavier (touches A/E en AZERTY, Q/E en QWERTY)
	if Input.is_physical_key_pressed(KEY_Q):
		_yaw += delta * 1.8
	if Input.is_physical_key_pressed(KEY_E):
		_yaw -= delta * 1.8
	var rx := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var ry := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if absf(rx) > 0.2:
		_yaw -= rx * delta * 2.2
	if absf(ry) > 0.2:
		_dist = clampf(_dist * (1.0 + ry * delta * 1.5), 5.0, 60.0)
	# on reste près du héros (le monde n'est affiché qu'autour de lui)
	var off := _focus - player.global_position
	off.y = 0.0
	if off.length() > MAX_FROM_HERO:
		_focus = player.global_position + off.normalized() * MAX_FROM_HERO
	_focus.y = lerpf(_focus.y, float(layer), clampf(delta * 6.0, 0.0, 1.0))
	world.stream_focus = _focus
	var dir := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch))
	_cam.global_position = _focus + dir * _dist
	_cam.look_at(_focus)


## Case visée : rayon de la caméra jusqu'au plan horizontal du niveau choisi.
func _update_cursor() -> void:
	var mp := get_viewport().get_mouse_position()
	if Input.get_connected_joypads().size() > 0 and _pad_recent():
		mp = get_viewport().get_visible_rect().size / 2.0
	var origin := _cam.project_ray_origin(mp)
	var dir := _cam.project_ray_normal(mp)
	_cursor_ok = false
	if absf(dir.y) < 0.001:
		return
	var t := (float(layer) - origin.y) / dir.y
	if t <= 0.0:
		return
	var p := origin + dir * t
	_cursor = world.cell_at(p)
	_cursor_ok = world._inside(_cursor)


var _last_pad := -100000
func _pad_recent() -> bool:
	var moving := Input.get_joy_axis(0, JOY_AXIS_LEFT_X) != 0.0 or Input.get_joy_axis(0, JOY_AXIS_RIGHT_X) != 0.0
	if moving:
		_last_pad = Time.get_ticks_msec()
	var mouse_moved := Input.get_last_mouse_velocity().length() > 5.0
	if mouse_moved:
		_last_pad = -100000
	return Time.get_ticks_msec() - _last_pad < 4000


# ---------------------------------------------------------------- tracé

func _is_single() -> bool:
	return _tool().id in ["door", "window", "furniture", "plan"]


func _press() -> void:
	if not _cursor_ok:
		return
	if _is_single():
		_selection_from(_cursor, _cursor)
		_commit_selection()
		return
	_dragging = true
	_drag_from = _cursor


func _commit() -> void:
	_dragging = false
	_commit_selection()


## Clic droit : annule le tracé en cours, sinon efface le plan visé.
func _cancel_action() -> void:
	if _dragging:
		_dragging = false
		return
	if _cursor_ok and orders.cancel_rect(Rect2i(_cursor, Vector2i.ONE), layer - 1.0, layer + wall_height + 6.0) > 0:
		player.notify.emit("Plan annulé.")


static func _rect(a: Vector2i, b: Vector2i) -> Rect2i:
	var p := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	return Rect2i(p, Vector2i(absi(a.x - b.x) + 1, absi(a.y - b.y) + 1))


func _update_selection() -> void:
	if not _cursor_ok:
		_selection = []
		return
	_selection_from(_drag_from if _dragging else _cursor, _cursor)


## Calcule ce que l'outil ferait entre deux cases : [[position, sorte], ...].
func _selection_from(a: Vector2i, b: Vector2i) -> void:
	_selection = []
	var t: String = _tool().id
	var r := _rect(a, b)
	match t:
		"wall_line", "wall_room":
			var cells := []
			if t == "wall_line":
				if absi(b.x - a.x) >= absi(b.y - a.y):
					for x in range(r.position.x, r.end.x):
						cells.append(Vector2i(x, a.y))
				else:
					for z in range(r.position.y, r.end.y):
						cells.append(Vector2i(a.x, z))
			else:
				for x in range(r.position.x, r.end.x):
					for z in range(r.position.y, r.end.y):
						if x == r.position.x or x == r.end.x - 1 or z == r.position.y or z == r.end.y - 1:
							cells.append(Vector2i(x, z))
			for c in cells:
				for y in range(layer, layer + wall_height):
					if y + 1 <= world.terrain_height(c) - 0.3:
						continue
					_selection.append([Vector3i(c.x, y, c.y), "block"])
		"floor", "roof_flat":
			var y := layer - 1 if t == "floor" else layer
			for x in range(r.position.x, r.end.x):
				for z in range(r.position.y, r.end.y):
					var c := Vector2i(x, z)
					if t == "floor" and world.terrain_height(c) > y + 1.3:
						continue
					_selection.append([Vector3i(x, y, z), "block"])
		"roof_gable":
			# faîtage dans le sens de la longueur, un rang plus haut à chaque pas vers le milieu, avec débord
			var along_x := r.size.x >= r.size.y
			var span := r.size.y if along_x else r.size.x
			var rr := r.grow(1)
			for x in range(rr.position.x, rr.end.x):
				for z in range(rr.position.y, rr.end.y):
					var i := (z - rr.position.y) if along_x else (x - rr.position.x)
					var n := (span + 2)
					var step := mini(i, n - 1 - i)
					_selection.append([Vector3i(x, layer + step, z), "block"])
					# on remplit sous le toit sur les pignons (fermer les triangles)
					var on_gable := (x == r.position.x or x == r.end.x - 1) if along_x else (z == r.position.y or z == r.end.y - 1)
					if on_gable and step > 0:
						for yy in range(layer, layer + step):
							_selection.append([Vector3i(x, yy, z), "gable"])
		"plan":
			var pt := _plan_type()
			if pt:
				_selection = plan_layout(pt, a)
		"door":
			_selection.append([Vector3i(a.x, layer, a.y), "door"])
		"window":
			_selection.append([Vector3i(a.x, layer + 1, a.y), "window"])
		"furniture":
			_selection.append([Vector3i(a.x, layer, a.y), "furniture"])
		"harvest", "flatten", "dig", "raise", "cancel", "demolish":
			for x in range(r.position.x, r.end.x):
				for z in range(r.position.y, r.end.y):
					_selection.append([Vector2i(x, z), t])


func _commit_selection() -> void:
	if _selection.is_empty():
		return
	var mat := _material()
	var n := 0
	var t: String = _tool().id
	orders.blocked_by_prop = 0
	match t:
		"wall_line", "wall_room", "floor", "roof_flat", "roof_gable":
			# du bas vers le haut
			var list := _selection.duplicate()
			list.sort_custom(func(p, q): return p[0].y < q[0].y)
			var wall_mat: ItemData = Items.get_item(materials.get("walls", "bloc_planches"))
			for s in list:
				var m: ItemData = wall_mat if s[1] == "gable" else mat
				if m and orders.block(s[0], m) > 0:
					n += 1
		"plan":
			var list := _selection.duplicate()
			list.sort_custom(func(p, q): return p[0].y < q[0].y)
			var mats := {"wall": materials.get("walls", "bloc_planches"), "gable": materials.get("walls", "bloc_planches"),
				"floor": materials.get("floors", "bloc_planches"), "roof": materials.get("roofs", "bloc_chaume")}
			var missing := []
			for e in list:
				var k: Vector3i = e[0]
				match e[1]:
					"wall", "gable", "floor", "roof":
						if orders.block(k, Items.get_item(mats[e[1]])) > 0:
							n += 1
					"door":
						var col := Vector2i(k.x, k.z)
						n += 1 if orders.furniture(col, float(layer), Items.get_item("porte"), 0) > 0 else 0
					"furniture":
						var it := Items.get_item(e[2]) as ItemData
						if it and orders.furniture(Vector2i(k.x, k.z), float(layer), it, 2) > 0:
							n += 1
							if player.inventory.count(it) <= 0 and not missing.has(it.display_name):
								missing.append(it.display_name)
			if not missing.is_empty():
				player.notify.emit("Meubles à fabriquer pour cette pièce : %s (Artisanat → Mobilier)." % ", ".join(PackedStringArray(missing)))
		"door":
			n += _plan_door(Vector2i(_selection[0][0].x, _selection[0][0].z))
		"window":
			var k: Vector3i = _selection[0][0]
			var glass := Items.get_item("bloc_verre")
			# un mur encore en plan : on change simplement le plan ; un mur construit : il sera remplacé
			var planned := orders.order_at_cell(Vector2i(k.x, k.z)).filter(func(o): return o.type == "block" and o.key == k)
			if not planned.is_empty():
				planned[0].upgrade = glass
				orders.refresh()
				n += 1
			elif orders.add({"type": "block", "key": k, "cell": Vector2i(k.x, k.z), "item": glass, "replace": true}) > 0:
				n += 1
		"furniture":
			var it := _furniture_item()
			var k: Vector3i = _selection[0][0]
			var col := Vector2i(k.x, k.z)
			var base := world.support_height(Vector3(col.x + 0.5, 0, col.y + 0.5), layer + 0.3)
			for o in orders.order_at_cell(col):
				if o.type == "block" and absf(o.key.y + 1 - base) < 0.3:
					base = o.key.y + 1.0
			if it and orders.furniture(col, base, it, rotation_step) > 0:
				n += 1
		"harvest":
			for s in _selection:
				n += 1 if orders.harvest(s[0]) > 0 else 0
		"flatten", "dig", "raise":
			for s in _selection:
				var c: Vector2i = s[0]
				if not grid.column(c).is_empty():
					continue
				var h := world.terrain_height(c)
				var target := float(layer) if t == "flatten" else (h - 0.5 if t == "dig" else h + 0.5)
				n += 1 if orders.terrain(c, target) > 0 else 0
		"cancel":
			n = orders.cancel_rect(_rect(_selection[0][0], _selection[_selection.size() - 1][0]))
		"demolish":
			# d'abord on efface les plans pas encore construits de la zone (sans toucher aux démolitions)
			var zone := _rect(_selection[0][0], _selection[_selection.size() - 1][0])
			n += orders.cancel_rect(zone, layer - 1.0, 1000.0, false)
			for s in _selection:
				var c: Vector2i = s[0]
				for b in grid.column(c):
					if b[0] >= layer - 1:
						n += 1 if orders.remove_block(Vector3i(c.x, b[0], c.y)) > 0 else 0
				for f in grid.furniture_in(c):
					if f.base >= layer - 1.0:
						n += 1 if orders.remove_furniture(grid.furniture_key(c, f.base)) > 0 else 0
			# décors du village de départ (cabanes, tonneaux, caisses, établi, râtelier)
			for prop in world.village_props_in(zone):
				n += 1 if orders.remove_prop(prop) > 0 else 0
	if orders.instant:
		orders.flush()
	if n > 0:
		var msg := "%d plan%s" % [n, "s" if n > 1 else ""]
		if t == "cancel":
			msg = "%d plan%s annulé%s" % [n, "s" if n > 1 else "", "s" if n > 1 else ""]
		elif orders.instant:
			msg += " réalisé%s" % ("s" if n > 1 else "")
		player.notify.emit(msg + ".")
	if orders.blocked_by_prop > 0:
		player.notify.emit("Un décor du village occupe la place : démolis-le d'abord (outil Démolir).")
	_selection = []


## Porte : on ouvre le mur sur deux blocs de haut et on pose la porte dans l'axe du mur.
func _plan_door(c: Vector2i) -> int:
	var along_x := grid.block_at(Vector3i(c.x + 1, layer, c.y)) != null or grid.block_at(Vector3i(c.x - 1, layer, c.y)) != null \
		or not orders.order_at_cell(c + Vector2i(1, 0)).is_empty() or not orders.order_at_cell(c + Vector2i(-1, 0)).is_empty()
	for y in [layer, layer + 1]:
		orders.remove_block(Vector3i(c.x, y, c.y))
	var base := float(layer)
	return 1 if orders.furniture(c, base, Items.get_item("porte"), 0 if along_x else 1) > 0 else 0


# ---------------------------------------------------------------- aperçu

func _update_preview() -> void:
	var t: String = _tool().id
	var list := []
	var col := Color(0.4, 1.0, 0.55, 0.42)
	match t:
		"demolish", "cancel":
			col = Color(1.0, 0.4, 0.3, 0.4)
		"harvest":
			col = Color(0.5, 1.0, 0.4, 0.45)
		"flatten", "dig", "raise":
			col = Color(1.0, 0.85, 0.35, 0.45)
	var mat := _material()
	var enough := true
	if mat and _selection.size() > 0 and t in ["wall_line", "wall_room", "floor", "roof_flat", "roof_gable"]:
		enough = player.inventory.count(mat) >= _selection.size()
		if not enough:
			col = Color(1.0, 0.75, 0.3, 0.42)
	for s in _selection:
		var p = s[0]
		if p is Vector3i:
			if s[1] == "furniture":
				continue
			var h := 1.0
			if mat and s[1] in ["block", "gable"]:
				h = BuildGrid.block_height(mat)
			list.append(Transform3D(Basis.from_scale(Vector3(1.02, h + 0.02, 1.02)), Vector3(p.x + 0.5, p.y + h * 0.5, p.z + 0.5)))
		else:
			var c: Vector2i = p
			var y := world.terrain_height(c)
			if t == "flatten":
				var lo := minf(y, float(layer))
				var hi := maxf(y, float(layer))
				list.append(Transform3D(Basis.from_scale(Vector3(0.98, maxf(hi - lo, 0.05), 0.98)), Vector3(c.x + 0.5, (lo + hi) * 0.5, c.y + 0.5)))
			else:
				var top := float(layer) if t in ["demolish", "cancel"] else y
				list.append(Transform3D(Basis.from_scale(Vector3(0.98, 0.08, 0.98)), Vector3(c.x + 0.5, top + 0.05, c.y + 0.5)))
	var m := _preview.multimesh
	m.instance_count = list.size()
	for i in list.size():
		m.set_instance_transform(i, list[i])
		m.set_instance_color(i, col)
	# meuble ou porte : aperçu du modèle
	var model: PackedScene = null
	var xf := Transform3D.IDENTITY
	if _cursor_ok and (t == "furniture" or t == "door"):
		var it := _furniture_item() if t == "furniture" else Items.get_item("porte")
		if it:
			model = it.furniture_model
			var base := world.support_height(Vector3(_cursor.x + 0.5, 0, _cursor.y + 0.5), layer + 0.3) if t == "furniture" else float(layer)
			xf = Transform3D(Basis(Vector3.UP, rotation_step * PI * 0.5), Vector3(_cursor.x + 0.5, base, _cursor.y + 0.5))
	var key := "%s_%d" % [model.resource_path if model else "", rotation_step]
	if key != _ghost_key:
		_ghost_key = key
		if _ghost:
			_ghost.queue_free()
			_ghost = null
		if model:
			_ghost = model.instantiate() as Node3D
			add_child(_ghost)
			for mi in _ghost.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).material_override = BuildOrders._ghost_material(Color(0.4, 1.0, 0.55, 0.5))
				(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _ghost:
		_ghost.visible = model != null
		_ghost.global_transform = xf
	# informations sur le tracé
	var info := ""
	if _selection.size() > 0:
		match t:
			"wall_line", "wall_room", "floor", "roof_flat", "roof_gable":
				info = "%d blocs de %s (tu en as %d)%s" % [_selection.size(), mat.display_name if mat else "?", player.inventory.count(mat) if mat else 0,
					"" if enough else " — les plans en trop attendront des matériaux"]
			"furniture":
				var it := _furniture_item()
				info = "%s (tu en as %d)" % [it.display_name, player.inventory.count(it)] if it else ""
			"door":
				info = "Porte (tu en as %d)" % player.inventory.count(Items.get_item("porte"))
			"plan":
				var nb := _selection.filter(func(e): return e[1] in ["wall", "gable", "floor", "roof"]).size()
				var have := []
				var miss := []
				for e in _selection:
					if e[1] == "furniture":
						var it := Items.get_item(e[2]) as ItemData
						if it:
							(have if player.inventory.count(it) > 0 else miss).append(it.display_name)
				info = "%d blocs · porte · %d meuble(s)%s" % [nb, have.size() + miss.size(), ("  —  à fabriquer : " + ", ".join(PackedStringArray(miss))) if not miss.is_empty() else "  —  tout est dans ton sac"]
			_:
				var r := _rect(_drag_from if _dragging else _cursor, _cursor)
				info = "Zone %d × %d" % [r.size.x, r.size.y]
	_sel_info.text = info


# ---------------------------------------------------------------- vue en coupe (hors mode construction)

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
	else:
		grid.set_cut(Vector3.ZERO, 10000.0, 0.0)


static func it_color(it: ItemData) -> Color:
	if it.block_texture:
		var img := it.block_texture.get_image()
		if img:
			if img.is_compressed():
				img.decompress()
			return img.get_pixel(8, 8)
	return Color(0.8, 0.7, 0.5)


# ---------------------------------------------------------------- interface

func _style(bg: Color, border: Color, width := 2) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	st.set_border_width_all(width)
	st.set_corner_radius_all(4)
	st.set_content_margin_all(5)
	return st


func _lbl(text: String, size := 11, color := Color("f0e6d2")) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	l.add_theme_constant_override("outline_size", 4)
	return l


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 2
	add_child(_ui)
	var panel_st := _style(Color(0.08, 0.06, 0.05, 0.9), Color("8a6a3a"))
	# haut : niveau, bâtisseurs, options
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", panel_st)
	_ui.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.offset_left = -420
	top.offset_right = 420
	top.offset_top = 8
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 10)
	top.add_child(th)
	var title := _lbl("CONSTRUCTION", 14, Color("f2c86a"))
	th.add_child(title)
	var down := Button.new()
	down.text = "▼"
	down.tooltip_text = "Niveau inférieur (Page ↓ ou Ctrl + molette)"
	down.focus_mode = Control.FOCUS_NONE
	down.pressed.connect(func(): _set_layer(layer - 1))
	th.add_child(down)
	_layer_label = _lbl("", 12)
	th.add_child(_layer_label)
	var up := Button.new()
	up.text = "▲"
	up.tooltip_text = "Niveau supérieur (Page ↑ ou Ctrl + molette)"
	up.focus_mode = Control.FOCUS_NONE
	up.pressed.connect(func(): _set_layer(layer + 1))
	th.add_child(up)
	var cut := CheckBox.new()
	cut.text = "Couper au-dessus (C)"
	cut.button_pressed = cut_on
	cut.add_theme_font_size_override("font_size", 10)
	cut.toggled.connect(func(on): cut_on = on)
	cut.focus_mode = Control.FOCUS_NONE
	th.add_child(cut)
	_instant_cb = CheckBox.new()
	_instant_cb.text = "Construction instantanée"
	_instant_cb.tooltip_text = "Les plans sont réalisés tout de suite (sans attendre les habitants)."
	_instant_cb.add_theme_font_size_override("font_size", 10)
	_instant_cb.focus_mode = Control.FOCUS_NONE
	_instant_cb.toggled.connect(func(on):
		orders.instant = on
		if on:
			# on réalise tout de suite ce qui attendait
			orders.flush())
	th.add_child(_instant_cb)
	# toujours un moyen visible de sortir
	var quit := Button.new()
	quit.text = "✕ Quitter (B / Échap)"
	quit.focus_mode = Control.FOCUS_NONE
	quit.add_theme_color_override("font_color", Color("ffb08a"))
	quit.pressed.connect(func(): toggle(false))
	th.add_child(quit)
	_builders_label = _lbl("", 10, Color("c8b89a"))
	_ui.add_child(_builders_label)
	_builders_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_builders_label.offset_left = -330
	_builders_label.offset_right = 330
	_builders_label.offset_top = 48
	_builders_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# bas : outils
	var bottom := PanelContainer.new()
	bottom.add_theme_stylebox_override("panel", panel_st)
	_ui.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.offset_left = -390
	bottom.offset_right = 390
	bottom.offset_top = -196
	bottom.offset_bottom = -26
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	bottom.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_tool_name = _lbl("", 14, Color("f2c86a"))
	head.add_child(_tool_name)
	_sel_info = _lbl("", 11, Color("8ad66a"))
	_sel_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sel_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_sel_info)
	_tool_desc = _lbl("", 10, Color("c8b89a"))
	v.add_child(_tool_desc)
	_tool_bar = HBoxContainer.new()
	_tool_bar.add_theme_constant_override("separation", 4)
	v.add_child(_tool_bar)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(760, 52)
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_mat_bar = HBoxContainer.new()
	_mat_bar.add_theme_constant_override("separation", 3)
	sc.add_child(_mat_bar)
	_cat_bar = HBoxContainer.new()
	_cat_bar.add_theme_constant_override("separation", 4)
	v.add_child(_cat_bar)
	_help = _lbl("", 10)
	_ui.add_child(_help)
	_help.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_help.offset_left = -520
	_help.offset_right = 520
	_help.offset_top = -22
	_help.offset_bottom = -4
	_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rot_keys := "%s/%s" % [OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(KEY_Q)),
		OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(KEY_E))]
	var move_keys := "%s%s%s%s" % [OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(KEY_W)),
		OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(KEY_A)),
		OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(KEY_S)),
		OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(KEY_D))]
	_help.text = "%s : déplacer (Maj : vite)   %s ou clic molette : tourner   Molette : zoom   Clic gauche (glisser) : tracer   Clic droit : annuler   R : tourner le meuble   [ ] : hauteur des murs   Tab : outil   V : matériau   1-8 : catégorie   B / Échap : quitter" % [move_keys, rot_keys]
	# droite : royaume
	var kp := PanelContainer.new()
	kp.add_theme_stylebox_override("panel", panel_st)
	_ui.add_child(kp)
	kp.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	kp.offset_left = -262
	kp.offset_right = -10
	kp.offset_top = 250
	_kpanel = RichTextLabel.new()
	_kpanel.bbcode_enabled = true
	_kpanel.fit_content = true
	_kpanel.scroll_active = false
	_kpanel.custom_minimum_size = Vector2(240, 0)
	_kpanel.add_theme_font_size_override("normal_font_size", 10)
	_kpanel.add_theme_color_override("default_color", Color("f0e6d2"))
	kp.add_child(_kpanel)


func _button(text: String, selected: bool, cb: Callable, width := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 11)
	b.add_theme_color_override("font_color", Color("f2c86a") if selected else Color("f0e6d2"))
	b.add_theme_stylebox_override("normal", _style(Color("4a3a2c") if selected else Color("2a211c"), Color("f2c86a") if selected else Color("5a4632"), 2 if selected else 1))
	b.add_theme_stylebox_override("hover", _style(Color("4a3a2c"), Color("f2c86a"), 1))
	b.add_theme_stylebox_override("pressed", _style(Color("5a4636"), Color("f2c86a"), 2))
	if width > 0:
		b.custom_minimum_size = Vector2(width, 0)
	b.pressed.connect(cb)
	return b


func _icon_button(it: ItemData, selected: bool, cb: Callable, tip: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(48, 48)
	b.icon = Items.get_icon(it)
	b.expand_icon = true
	b.tooltip_text = tip
	var have := player.inventory.count(it)
	b.add_theme_stylebox_override("normal", _style(Color("2a211c"), Color("f2c86a") if selected else (Color("5a4632") if have > 0 else Color("6a2a22")), 2 if selected else 1))
	b.add_theme_stylebox_override("hover", _style(Color("3a2e26"), Color("f2c86a"), 1))
	b.pressed.connect(cb)
	var n := _lbl(str(have), 9, Color("f0e6d2") if have > 0 else Color("e0705a"))
	n.position = Vector2(30, 32)
	b.add_child(n)
	return b


func _refresh_ui() -> void:
	if _cat_bar == null or player == null:
		return
	if _furniture_items.is_empty():
		_list_furniture()
	for bar in [_cat_bar, _tool_bar, _mat_bar]:
		for c in bar.get_children():
			c.queue_free()
	for i in CATEGORIES.size():
		var c: Dictionary = CATEGORIES[i]
		_cat_bar.add_child(_button("%d %s %s" % [i + 1, c.glyph, c.name], i == cat, _set_category.bind(i)))
	var category := _category()
	if category.id == "plans":
		var types := _plan_types()
		for i in types.size():
			var t: RoomTypeData = types[i]
			var need := []
			for id in t.required:
				var it := Items.get_item(id) as ItemData
				need.append("%d %s" % [int(t.required[id]), it.display_name if it else id])
			var b := _button(t.display_name, i == plan_index, func(): plan_index = i; _refresh_ui())
			b.tooltip_text = "%s\nMeubles : %s" % [t.display_name, ", ".join(PackedStringArray(need))]
			_mat_bar.add_child(b)
	elif category.id == "furniture":
		for i in _furniture_items.size():
			var it: ItemData = _furniture_items[i]
			_mat_bar.add_child(_icon_button(it, i == furniture_index, func(): furniture_index = i; _ghost_key = ""; _refresh_ui(),
				"%s\n%s" % [it.display_name, _furniture_use(it)]))
	else:
		for i in category.tools.size():
			_tool_bar.add_child(_button(category.tools[i].name, i == tool_index, func(): tool_index = i; _ghost_key = ""; _refresh_ui()))
		if category.id == "walls":
			_tool_bar.add_child(_lbl("   Hauteur : %d  " % wall_height, 11))
			_tool_bar.add_child(_button("−", false, func(): wall_height = clampi(wall_height - 1, 1, 6); _refresh_ui(), 26))
			_tool_bar.add_child(_button("+", false, func(): wall_height = clampi(wall_height + 1, 1, 6); _refresh_ui(), 26))
		if materials.has(category.id):
			var cur := _material()
			for it in _block_items():
				_mat_bar.add_child(_icon_button(it, it == cur, func(): materials[category.id] = it.id; _refresh_ui(),
					"%s · %s" % [it.display_name, ItemData.TIER_NAMES[it.block_tier]]))
	var tl := _tool()
	var mat := _material()
	_tool_name.text = tl.name + (("  ·  " + mat.display_name) if mat and materials.has(category.id) else "")
	_tool_desc.text = tl.desc
	if category.id == "roofs":
		_tool_desc.text += "  Astuce : monte au niveau du haut des murs (Page ↑)."
	_layer_label.text = "Niveau %d" % layer


func _builders_text() -> String:
	var b := orders.builders().size()
	var n := orders.orders.size()
	var waiting := orders.orders.values().filter(func(o): return not orders._has_material(o)).size()
	var txt := "Plans : %d%s   ·   Bâtisseurs libres : %d" % [n, (" (%d sans matériaux)" % waiting) if waiting > 0 else "", b]
	if n > 0 and b == 0 and not orders.instant:
		txt += "   —   aucun habitant libre : retire-en un de son poste, ou coche « Construction instantanée »"
	return txt


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
