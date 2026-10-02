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
var _frame_box: StyleBox
var _paper_box: StyleBox


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_font = get_theme_default_font()
	_frame_box = UiTheme.frame(0)
	_paper_box = UiTheme.parchment(0)


func open() -> void:
	Sound.ui("ui_open")
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


## Les armées en marche (et leur chemin restant) et l'événement de saison.
func _draw_politics() -> void:
	var pol := get_tree().get_first_node_in_group("world_politics") as WorldPolitics
	if pol == null:
		return
	for ar in pol.armies:
		var col := pol._color(ar.nation)
		var at: Vector2 = pol._at(ar.path, float(ar.dist))[0]
		var q := cell_to_screen(at)
		# le chemin qu'il lui reste, en pointillés
		var idx: int = pol._at(ar.path, float(ar.dist))[1]
		var prev := q
		for i in range(idx, ar.path.size(), 3):
			var n := cell_to_screen(Vector2(ar.path[i]))
			draw_dashed_line(prev, n, Color(col, 0.55), 1.5, 4.0)
			prev = n
		# l'étendard
		draw_line(q + Vector2(0, 6), q + Vector2(0, -10), Color("2a1e14"), 2.0)
		draw_colored_polygon(PackedVector2Array([q + Vector2(0, -10), q + Vector2(10, -7), q + Vector2(0, -4)]), col)
		draw_circle(q + Vector2(0, 6), 3.0, col.darkened(0.3))
		if zoom >= 1.5:
			_text_center("%s → %s" % [pol._army_name(ar), pol._goal_name(ar)], q + Vector2(0, -16), 10, col.lightened(0.4))
	if not pol.event.is_empty() and pol.event.kind in ["foire", "moissons", "tournoi"]:
		var c := pol.city_of(pol.event.nation)
		if not c.is_empty() and world.is_revealed(c.center):
			var q := cell_to_screen(Vector2(c.center))
			_text_center("★ " + WorldPolitics.EVENT_NAMES[pol.event.kind], q + Vector2(0, 32), 12, Color("ffd24a"))


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
	# cadre de bois doré autour du parchemin de la carte
	draw_style_box(_frame_box, map_rect.grow(18))
	# terres inconnues : un vieux parchemin, les régions explorées s'y peignent par-dessus
	draw_style_box(_paper_box, map_rect.grow(3))
	var tf := UiTheme.font("title")
	var tw := tf.get_string_size("Terra incognita", HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	draw_string(tf, map_rect.get_center() + Vector2(-tw / 2.0, map_rect.size.y * 0.34), "Terra incognita", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.35, 0.24, 0.14, 0.4))
	draw_texture_rect(world.map_texture, map_rect, false)
	# rose des vents
	var rose := UiTheme.tex("icon_compass")
	var rs := 48.0
	draw_texture_rect(rose, Rect2(map_rect.end - Vector2(rs + 10, rs + 10), Vector2(rs, rs)), false)
	# noms des zones découvertes
	# (sur un monde immense, les noms n'apparaissent qu'en zoomant, pour rester lisibles)
	var names := world.zones.size() <= 40 or zoom >= 1.8
	for z in world.zones:
		if not names or not z.discovered or z.type == null:
			continue
		var p := cell_to_screen(z.site)
		var t: RegionData = z.type
		var fs := 13 if zoom < 2.0 else 16
		_text_center(z.name, p + Vector2(0, -8), fs, t.map_color.lightened(0.45))
		if world.zones.size() <= 40 or zoom >= 3.0:
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
	_draw_places()
	# village
	var v := cell_to_screen(Vector2(world.spawn_cell) + Vector2(0.5, 0.5))
	draw_rect(Rect2(v - Vector2(7, 7), Vector2(14, 14)), Color("f2c86a"))
	draw_rect(Rect2(v - Vector2(7, 7), Vector2(14, 14)), Color.BLACK, false, 2.0)
	var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
	_text_center(k.title() if k else "Village", v + Vector2(0, 30), 11, Color("f2c86a"))
	# fin de partie : le Portail des Failles et le titan éveillé
	var eg := get_tree().get_first_node_in_group("endgame") as Endgame
	if eg:
		var ppos := eg.portal_pos()
		var pc := cell_to_screen(Vector2(ppos.x, ppos.z))
		draw_arc(pc, 5.0, 0, TAU, 16, Color("b05aff"), 2.5)
		if zoom >= 2.0:
			_text_center("Portail des Failles", pc + Vector2(0, -14), 10, Color("e0b0ff"))
		var tq := eg.titan_pos()
		if tq != Vector3.INF:
			var q := cell_to_screen(Vector2(tq.x, tq.z))
			draw_circle(q, 10.0, Color(0.6, 0.1, 0.05, 0.85))
			draw_arc(q, 10.0, 0, TAU, 20, Color("ffb050"), 2.0)
			_text_center("☠", q + Vector2(0, -4), 14, Color("ffe0b0"))
			_text_center("%s · Nv %d" % [eg.titan.name, int(eg.titan.level)], q + Vector2(0, -22), 12, Color("ffb050"))
	# objectif de l'histoire
	var st := get_tree().get_first_node_in_group("story") as Story
	var tp := st.target_pos() if st else Vector3.INF
	if tp != Vector3.INF:
		var q := cell_to_screen(Vector2(tp.x, tp.z))
		var pts := PackedVector2Array()
		for i in 10:
			var a := -PI / 2.0 + TAU * i / 10.0
			pts.append(q + Vector2(cos(a), sin(a)) * (11.0 if i % 2 == 0 else 5.0))
		draw_colored_polygon(pts, Color("ffd24a"))
		pts.append(pts[0])
		draw_polyline(pts, Color.BLACK, 1.5)
		_text_center("Histoire : " + st.current()[2], q + Vector2(0, -20), 12, Color("ffe08a"))
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
	_text_center(title, Vector2(size.x / 2.0, 32), 26, MenuKit.C_GOLD, UiTheme.font("title"))
	var found := world.zones.filter(func(z): return z.discovered).size()
	var obs := world.zones.filter(func(z): return z.obelisk_on).size()
	_text_center("Zones découvertes : %d / %d     Obélisques activés : %d / %d" % [found, world.zones.size(), obs, world.zones.size()], Vector2(size.x / 2.0, 52), 12, C_DIM)
	_text_center("Clic sur un obélisque (◆) : voyage rapide   Molette : zoom   Glisser : déplacer   M / Échap : fermer      Manette : LB/RB choisir · A voyager · gâchettes zoom", Vector2(size.x / 2.0, size.y - 18), 11, C_DIM)
	# légende
	var lx := 20.0
	var ly := size.y - 120.0
	# lieux remarquables
	var lx2 := 196.0
	draw_rect(Rect2(lx2 - 6, ly - 16, 170, 92), Color(0, 0, 0, 0.45))
	_castle_icon(Vector2(lx2 + 5, ly), 5.0, Color("ffd24a"))
	draw_string(_font, Vector2(lx2 + 18, ly + 4), "Capitale", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_TEXT)
	_castle_icon(Vector2(lx2 + 5, ly + 20), 4.0, Color("d8c8a8"))
	draw_string(_font, Vector2(lx2 + 18, ly + 24), "Château (gris : abandonné)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_TEXT)
	_wreck_icon(Vector2(lx2 + 5, ly + 40))
	draw_string(_font, Vector2(lx2 + 18, ly + 44), "Épave", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_TEXT)
	draw_circle(Vector2(lx2 + 5, ly + 60), 4.0, Color("2a1e14"))
	draw_arc(Vector2(lx2 + 5, ly + 60), 4.0, 0, TAU, 12, Color("c8a070"), 1.5)
	draw_string(_font, Vector2(lx2 + 18, ly + 64), "Grotte (en zoomant)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_TEXT)
	draw_rect(Rect2(lx - 6, ly - 16, 170, 92), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(lx, ly - 5, 10, 10), Color("f2c86a"))
	draw_string(_font, Vector2(lx + 18, ly + 4), "Ton royaume", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_TEXT)
	draw_colored_polygon(PackedVector2Array([Vector2(lx + 5, ly + 14), Vector2(lx + 9, ly + 20), Vector2(lx + 5, ly + 26), Vector2(lx + 1, ly + 20)]), C_OBELISK)
	draw_string(_font, Vector2(lx + 18, ly + 24), "Obélisque (voyage)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_TEXT)
	draw_rect(Rect2(lx, ly + 35, 10, 10), Color("c84a3a"))
	draw_string(_font, Vector2(lx + 18, ly + 44), "Donjon (vert : vaincu)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_TEXT)
	draw_colored_polygon(PackedVector2Array([Vector2(lx + 5, ly + 54), Vector2(lx + 10, ly + 66), Vector2(lx, ly + 66)]), Color.WHITE)
	draw_string(_font, Vector2(lx + 18, ly + 64), "Toi", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_TEXT)


## Capitales, châteaux, épaves et entrées de grottes déjà vus (ou dévoilés par /carte).
func _draw_places() -> void:
	var mc := get_tree().get_first_node_in_group("mountain_caves")
	if mc and zoom >= 2.0:
		for e in mc._entrances.values():
			if (e as Dictionary).is_empty() or not world.is_revealed(e.cell):
				continue
			var q := cell_to_screen(Vector2(e.cell) + Vector2(0.5, 0.5))
			draw_circle(q, 3.5, Color("2a1e14"))
			draw_arc(q, 3.5, 0, TAU, 12, Color("c8a070"), 1.5)
	for st in world.structure_sites:
		if st.kind == "castle":
			var c: Vector2i = st.cell + Vector2i(10, 10)
			if world.is_revealed(c):
				var q := cell_to_screen(Vector2(c))
				_castle_icon(q, 5.0, Color(0.6, 0.6, 0.62) if st.abandoned else Color("d8c8a8"))
				if zoom >= 2.0:
					_text_center("Château abandonné" if st.abandoned else "Château", q + Vector2(0, -12), 10, C_DIM)
		elif st.kind == "wreck":
			var c: Vector2i = st.cell + Vector2i(1, 6)
			if world.is_revealed(c):
				_wreck_icon(cell_to_screen(Vector2(c)))
		elif st.kind == "sunken":
			var c: Vector2i = st.cell + Vector2i(7, 7)
			if world.is_revealed(c):
				var q := cell_to_screen(Vector2(c))
				for k in 3:
					draw_rect(Rect2(q + Vector2(-6 + k * 5, -5), Vector2(2.5, 9)), Color("bfe8ff"))
				draw_rect(Rect2(q + Vector2(-7, -7), Vector2(14, 2)), Color("bfe8ff"))
				if zoom >= 1.5:
					_text_center(str(st.get("name", "Cité engloutie")), q + Vector2(0, -13), 10, Color("8ad8ff"))
	for st in world.structure_sites:
		if st.kind == "hamlet" and world.is_revealed(st.cell):
			var q := cell_to_screen(Vector2(st.cell))
			var hcol: Color = Diplomacy.NATIONS.get(st.nation, {}).get("color", Color("e8c890"))
			if st.get("ravaged", false):
				hcol = WorldPolitics.UNDEAD.color.darkened(0.3)
			draw_colored_polygon(PackedVector2Array([q + Vector2(-4, 4), q + Vector2(-4, -1), q + Vector2(0, -5), q + Vector2(4, -1), q + Vector2(4, 4)]), hcol.lightened(0.25))
			if st.has("born") and st.born != st.nation:
				draw_arc(q, 7.0, 0, TAU, 14, hcol, 2.0)
			if zoom >= 2.0:
				_text_center(st.name + (" (ravagé)" if st.get("ravaged", false) else ""), q + Vector2(0, -12), 10, Color("f2dca0"))
	_draw_politics()
	var mcv := get_tree().get_first_node_in_group("mountain_caves")
	if mcv and zoom >= 1.5:
		for e in mcv.city_entrances():
			if world.is_revealed(e.cell):
				var q := cell_to_screen(Vector2(e.cell))
				draw_rect(Rect2(q + Vector2(-4, -4), Vector2(8, 8)), Color("2a1e14"))
				draw_rect(Rect2(q + Vector2(-4, -4), Vector2(8, 8)), Color("c8a070"), false, 1.5)
				if zoom >= 2.5:
					_text_center(str(e.name), q + Vector2(0, 14), 9, Color("c8a070"))
	for city in world.cities:
		var c: Vector2i = city.center
		if not world.is_revealed(c):
			continue
		var q := cell_to_screen(Vector2(c) + Vector2(0.5, 0.5))
		var col: Color = Diplomacy.NATIONS.get(city.nation, {}).get("color", Color("ffd24a"))
		draw_arc(q, float(city.radius) * _scale(), 0, TAU, 48, Color(col, 0.7), 2.0)
		_castle_icon(q, 8.0, Color("ffd24a"))
		_text_center(city.name, q + Vector2(0, -18), 15, col.lightened(0.4), UiTheme.font("title"))
		_text_center("%d habitants" % int(city.population), q + Vector2(0, 18), 10, C_DIM)


func _castle_icon(q: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array([q + Vector2(-r, r), q + Vector2(-r, -r), q + Vector2(-r * 0.5, -r), q + Vector2(-r * 0.5, -r * 0.5),
		q + Vector2(0, -r * 0.5), q + Vector2(0, -r), q + Vector2(r * 0.5, -r), q + Vector2(r * 0.5, -r * 0.5),
		q + Vector2(r, -r * 0.5), q + Vector2(r, r)])
	draw_colored_polygon(pts, col)
	pts.append(pts[0])
	draw_polyline(pts, Color.BLACK, 1.2)


func _wreck_icon(q: Vector2) -> void:
	var hull := PackedVector2Array([q + Vector2(-6, 0), q + Vector2(6, 0), q + Vector2(4, 4), q + Vector2(-4, 4)])
	draw_colored_polygon(hull, Color("8a5a32"))
	draw_line(q + Vector2(0, 0), q + Vector2(1, -7), Color("4a3020"), 1.5)
	hull.append(hull[0])
	draw_polyline(hull, Color.BLACK, 1.0)


func _text_center(text: String, pos: Vector2, fs: int, col: Color, fnt: Font = null) -> void:
	var ft := fnt if fnt else _font
	var w := ft.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := pos - Vector2(w / 2.0, -fs / 3.0)
	for off in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(1, 1)]:
		draw_string(ft, p + off * 1.5, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.03, 0.02, 0.04))
	draw_string(ft, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
