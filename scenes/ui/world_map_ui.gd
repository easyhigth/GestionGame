class_name WorldMapUI
extends Control
## Grande carte du monde (touche M ou croix haut) : zones découvertes, obélisques, donjons, village.
## Clic sur un obélisque activé (ou A à la manette) : voyage rapide.
## Molette / gâchettes : zoom. Glisser / stick gauche : déplacer la carte.

const C_BG := Color(0.06, 0.05, 0.07, 0.94)
const C_PAPER := Color("2a2230")
const C_TEXT := Color("fff2dc")
const C_DIM := Color("b8a890")
const C_OBELISK := Color("6ae0ff")

var world: WorldGenerator
var player: Player
var zoom := 1.0
var center := Vector2.ZERO        # case au centre de la vue
var selected := -1                # zone dont l'obélisque est sélectionné
var _dragging := false
var _hover := -1
var _font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_font = get_theme_default_font()


func open() -> void:
	if world == null or world.map_texture == null:
		return
	if player and player.global_position.y < WorldGenerator.UNDERGROUND:
		player.notify.emit("Pas de carte dans un donjon : trouve la sortie (portail) ou vaincs le gardien.")
		return
	world.map_texture.update(world.map_image)
	visible = true
	zoom = 1.0
	center = Vector2(world.world_size) / 2.0
	selected = world.current_zone if world.current_zone >= 0 and world.zones[world.current_zone].obelisk_on else _first_travel()
	if player:
		player.ui_open = true
	get_tree().paused = true
	queue_redraw()


func close() -> void:
	visible = false
	get_tree().paused = false
	if player:
		player.ui_open = false


func _first_travel() -> int:
	for z in world.zones:
		if z.obelisk_on:
			return z.id
	return -1


## Échelle : pixels à l'écran par case.
func _scale() -> float:
	var area := size - Vector2(80, 150)
	return minf(area.x / world.world_size.x, area.y / world.world_size.y) * zoom


func _map_origin() -> Vector2:
	# la vue ne sort pas de la carte
	var ws := Vector2(world.world_size)
	var view := (size - Vector2(80, 150)) / _scale()
	for a in 2:
		if view[a] >= ws[a]:
			center[a] = ws[a] / 2.0
		else:
			center[a] = clampf(center[a], view[a] / 2.0, ws[a] - view[a] / 2.0)
	# position écran de la case (0, 0)
	return size / 2.0 + Vector2(0, 10) - center * _scale()


func cell_to_screen(c: Vector2) -> Vector2:
	return _map_origin() + c * _scale()


func screen_to_cell(p: Vector2) -> Vector2:
	return (p - _map_origin()) / _scale()


func _travel_points() -> Array:
	return world.zones.filter(func(z): return z.obelisk_on)


func _process(delta: float) -> void:
	if not visible:
		return
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if stick.length() > 0.25:
		center += stick * delta * 260.0 / zoom
		queue_redraw()
	var zin := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) - Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT)
	if absf(zin) > 0.3:
		zoom = clampf(zoom * (1.0 + zin * delta * 1.5), 1.0, 6.0)
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		if event.is_action_pressed("world_map") and player and not player.ui_open and player.is_alive():
			open()
			get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("world_map") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("inventory"):
		close()
		return
	var pts := _travel_points()
	if event is InputEventJoypadButton and event.pressed and not pts.is_empty():
		var ids := pts.map(func(z): return z.id)
		var k := maxi(0, ids.find(selected))
		if event.button_index == JOY_BUTTON_RIGHT_SHOULDER or event.button_index == JOY_BUTTON_DPAD_RIGHT:
			selected = ids[(k + 1) % ids.size()]
			_focus(selected)
		elif event.button_index == JOY_BUTTON_LEFT_SHOULDER or event.button_index == JOY_BUTTON_DPAD_LEFT:
			selected = ids[(k - 1 + ids.size()) % ids.size()]
			_focus(selected)
		elif event.button_index == JOY_BUTTON_A:
			_travel(selected)
		queue_redraw()


func _focus(id: int) -> void:
	if id >= 0:
		center = Vector2(world.zones[id].obelisk) + Vector2(0.5, 0.5)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var before := screen_to_cell(mb.position)
			zoom = clampf(zoom * (1.25 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 0.8), 1.0, 6.0)
			center += before - screen_to_cell(mb.position)
			queue_redraw()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if _hover >= 0:
					_travel(_hover)
				else:
					_dragging = true
			else:
				_dragging = false
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			close()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _dragging:
			center -= mm.relative / _scale()
		_hover = -1
		for z in _travel_points():
			if cell_to_screen(Vector2(z.obelisk) + Vector2(0.5, 0.5)).distance_to(mm.position) < 12.0:
				_hover = z.id
		queue_redraw()


func _travel(id: int) -> void:
	if id < 0:
		return
	var z: Dictionary = world.zones[id]
	close()
	if world.travel_to(z):
		player.notify.emit("Voyage vers l'obélisque : %s" % z.name)


# ---------------------------------------------------------------- dessin

func _draw() -> void:
	if world == null or world.map_texture == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), C_BG)
	var s := _scale()
	var o := _map_origin()
	var map_rect := Rect2(o, Vector2(world.world_size) * s)
	draw_rect(map_rect.grow(6), C_PAPER)
	draw_rect(map_rect.grow(6), Color("8a6a40"), false, 2.0)
	draw_texture_rect(world.map_texture, map_rect, false)
	# noms des zones découvertes
	for z in world.zones:
		if not z.discovered or z.type == null:
			continue
		var p := cell_to_screen(z.site)
		var t: RegionData = z.type
		var fs := 13 if zoom < 2.0 else 16
		_text_center(z.name, p + Vector2(0, -8), fs, t.map_color.lightened(0.45))
		_text_center("%s · Nv %d-%d" % [t.display_name, z.level.x, z.level.y], p + Vector2(0, 8), 10, C_DIM)
	# donjons et obélisques
	for z in world.zones:
		if (z.gate as Vector2i).x >= 0 and world.is_revealed(z.gate):
			var g := cell_to_screen(Vector2(z.gate) + Vector2(0.5, 0.5))
			draw_rect(Rect2(g - Vector2(5, 5), Vector2(10, 10)), Color("5ac84a") if z.get("cleared", false) else Color("c84a3a"))
			draw_rect(Rect2(g - Vector2(5, 5), Vector2(10, 10)), Color.BLACK, false, 1.5)
		if (z.obelisk as Vector2i).x >= 0 and (z.obelisk_on or world.is_revealed(z.obelisk)):
			var q := cell_to_screen(Vector2(z.obelisk) + Vector2(0.5, 0.5))
			var col := C_OBELISK if z.obelisk_on else Color(0.5, 0.55, 0.6)
			var r := 9.0 if z.id == selected or z.id == _hover else 6.0
			draw_colored_polygon(PackedVector2Array([q + Vector2(0, -r), q + Vector2(r * 0.7, 0), q + Vector2(0, r), q + Vector2(-r * 0.7, 0)]), col)
			draw_polyline(PackedVector2Array([q + Vector2(0, -r), q + Vector2(r * 0.7, 0), q + Vector2(0, r), q + Vector2(-r * 0.7, 0), q + Vector2(0, -r)]), Color.BLACK, 1.5)
			if z.id == selected or z.id == _hover:
				_text_center("Voyager : %s" % z.name, q + Vector2(0, -r - 10), 12, C_OBELISK.lightened(0.4))
	# village
	var v := cell_to_screen(Vector2(world.spawn_cell) + Vector2(0.5, 0.5))
	draw_rect(Rect2(v - Vector2(7, 7), Vector2(14, 14)), Color("f2c86a"))
	draw_rect(Rect2(v - Vector2(7, 7), Vector2(14, 14)), Color.BLACK, false, 2.0)
	var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
	_text_center(k.title() if k else "Village", v + Vector2(0, 30), 11, Color("f2c86a"))
	# héros
	if player:
		var pp := cell_to_screen(Vector2(player.global_position.x, player.global_position.z))
		var f := Vector2(player.facing.x, player.facing.z).normalized()
		if f == Vector2.ZERO:
			f = Vector2(0, 1)
		var side := Vector2(-f.y, f.x)
		var tri := PackedVector2Array([pp + f * 11, pp - f * 7 + side * 7, pp - f * 3, pp - f * 7 - side * 7])
		draw_colored_polygon(tri, Color.WHITE)
		draw_polyline(tri + PackedVector2Array([tri[0]]), Color("c83a2a"), 2.0)
	# titre et aide
	var zc := world.zone_at(player.global_position) if player else {}
	var title := "Carte du monde"
	if not zc.is_empty():
		title = "Carte du monde  —  %s" % zc.name
	_text_center(title, Vector2(size.x / 2.0, 30), 22, C_TEXT)
	var found := world.zones.filter(func(z): return z.discovered).size()
	var obs := world.zones.filter(func(z): return z.obelisk_on).size()
	_text_center("Zones découvertes : %d / %d     Obélisques activés : %d / %d" % [found, world.zones.size(), obs, world.zones.size()], Vector2(size.x / 2.0, 52), 12, C_DIM)
	_text_center("Clic sur un obélisque (◆) : voyage rapide   Molette : zoom   Glisser : déplacer   M / Échap : fermer      Manette : LB/RB choisir · A voyager · gâchettes zoom", Vector2(size.x / 2.0, size.y - 18), 11, C_DIM)
	# légende
	var lx := 20.0
	var ly := size.y - 120.0
	draw_rect(Rect2(lx - 6, ly - 16, 170, 92), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(lx, ly - 5, 10, 10), Color("f2c86a"))
	draw_string(_font, Vector2(lx + 18, ly + 4), "Ton royaume", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_TEXT)
	draw_colored_polygon(PackedVector2Array([Vector2(lx + 5, ly + 14), Vector2(lx + 9, ly + 20), Vector2(lx + 5, ly + 26), Vector2(lx + 1, ly + 20)]), C_OBELISK)
	draw_string(_font, Vector2(lx + 18, ly + 24), "Obélisque (voyage)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_TEXT)
	draw_rect(Rect2(lx, ly + 35, 10, 10), Color("c84a3a"))
	draw_string(_font, Vector2(lx + 18, ly + 44), "Donjon (vert : vaincu)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_TEXT)
	draw_colored_polygon(PackedVector2Array([Vector2(lx + 5, ly + 54), Vector2(lx + 10, ly + 66), Vector2(lx, ly + 66)]), Color.WHITE)
	draw_string(_font, Vector2(lx + 18, ly + 64), "Toi", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_TEXT)


func _text_center(text: String, pos: Vector2, fs: int, col: Color) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := pos - Vector2(w / 2.0, -fs / 3.0)
	for off in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(1, 1)]:
		draw_string(_font, p + off * 1.5, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.03, 0.02, 0.04))
	draw_string(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
