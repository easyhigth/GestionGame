class_name KingdomMap
extends Control
## Carte du royaume vue du ciel (onglet « Carte » du panneau du royaume) : murs posés, champs, pièces reconnues
## (couleur de leur type), plans en attente, habitants (couleur de leur classe ; anneau : au travail) et le héros.
## Survoler un élément l'explique ; cliquer sur un habitant ouvre sa fiche.

signal hovered(text: String)
signal villager_clicked(v: Node)

const BG := Color("1e2a18")
const GRID := Color(1, 1, 1, 0.04)
const WALL := Color("6e6a62")
const FIELD := Color("7a5430")
const PLAN := Color("f2c86a")

var player: Node3D
var _origin := Vector2i.ZERO      # case en haut à gauche
var _span := Vector2i(48, 24)     # cases affichées
var _px := 10.0                   # pixels par case
var _hover := ""
var _dots: Array = []             # [position écran, rayon, habitant]
var _rooms: Array = []            # [Rect2 écran approximatif, texte]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(_fit)


func _k() -> Kingdom:
	return get_tree().get_first_node_in_group("kingdom") as Kingdom


func _w() -> WorldGenerator:
	return get_tree().get_first_node_in_group("world") as WorldGenerator


## Cadre la carte sur le village (pièces, habitants, plans), avec une marge.
func _fit() -> void:
	var w := _w()
	if w == null:
		return
	var mn := w.spawn_cell - Vector2i(12, 12)
	var mx := w.spawn_cell + Vector2i(12, 12)
	var k := _k()
	if k:
		for r in k.rooms:
			if not r.get("enclosed", false):
				continue
			for c in r.cells:
				mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
				mx = Vector2i(maxi(mx.x, c.x), maxi(mx.y, c.y))
	for v in get_tree().get_nodes_in_group("villagers"):
		var c: Vector2i = w.cell_at(v.global_position)
		if c.distance_to(w.spawn_cell) < 60:
			mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
			mx = Vector2i(maxi(mx.x, c.x), maxi(mx.y, c.y))
	mn -= Vector2i(3, 3)
	mx += Vector2i(3, 3)
	var span := mx - mn + Vector2i.ONE
	_px = maxf(3.0, minf(size.x / span.x, size.y / span.y))
	# on centre ce cadre dans le contrôle
	var cells := Vector2i(ceili(size.x / _px), ceili(size.y / _px))
	_origin = mn - (cells - span) / 2
	_span = cells
	queue_redraw()


func _to_screen(cell: Vector2) -> Vector2:
	return (cell - Vector2(_origin)) * _px


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	var w := _w()
	var k := _k()
	if w == null:
		return
	# quadrillage léger tous les 8 m
	for x in range(_origin.x - posmod(_origin.x, 8), _origin.x + _span.x, 8):
		draw_line(_to_screen(Vector2(x, _origin.y)), _to_screen(Vector2(x, _origin.y + _span.y)), GRID)
	for y in range(_origin.y - posmod(_origin.y, 8), _origin.y + _span.y, 8):
		draw_line(_to_screen(Vector2(_origin.x, y)), _to_screen(Vector2(_origin.x + _span.x, y)), GRID)
	var rect := Rect2i(_origin, _span)
	# champs
	var fm := get_tree().get_first_node_in_group("farming")
	if fm:
		for c in fm.plots:
			if rect.has_point(c):
				draw_rect(Rect2(_to_screen(Vector2(c)), Vector2.ONE * _px), FIELD)
	# murs et blocs posés (vus de dessus)
	if w.build:
		var seen := {}
		for key in w.build.blocks:
			var c := Vector2i(key.x, key.z)
			if seen.has(c) or not rect.has_point(c):
				continue
			seen[c] = true
			draw_rect(Rect2(_to_screen(Vector2(c)), Vector2.ONE * _px), WALL)
	# pièces
	_rooms.clear()
	if k:
		for r in k.rooms:
			# seulement les vraies pièces (fermées, avec une porte), pas les espaces ouverts
			if not r.get("enclosed", false):
				continue
			var t: RoomTypeData = r.type
			var col: Color = t.color if t else Color(0.6, 0.6, 0.6)
			var sum := Vector2.ZERO
			for c in r.cells:
				sum += Vector2(c)
				draw_rect(Rect2(_to_screen(Vector2(c)), Vector2.ONE * _px), Color(col, 0.55 if t else 0.25))
			var center := _to_screen(sum / maxf(1.0, r.cells.size()) + Vector2(0.5, 0.5))
			var name: String = t.display_name if t else "Pièce non reconnue"
			var workers := ""
			if t and t.job_slots > 0:
				workers = "  ·  %s %d / %d" % [t.job_name, k.workers_of(r).size(), t.job_slots]
			var miss := ""
			if not t and r.get("closest"):
				miss = "  ·  presque : %s" % (r.closest as RoomTypeData).display_name
			_rooms.append([center, sqrt(r.cells.size()) * _px * 0.6, name + workers + miss])
			if t and _px * sqrt(r.cells.size()) > 34.0:
				var f := get_theme_default_font()
				var lab := name if name.length() < 14 else name.left(12) + "."
				draw_string_outline(f, center + Vector2(-50, 4), lab, HORIZONTAL_ALIGNMENT_CENTER, 100, 10, 3, Color(0, 0, 0, 0.8))
				draw_string(f, center + Vector2(-50, 4), lab, HORIZONTAL_ALIGNMENT_CENTER, 100, 10, Color.WHITE)
	# plans en attente
	var bo := get_tree().get_first_node_in_group("build_orders")
	if bo:
		for id in bo.orders:
			var o: Dictionary = bo.orders[id]
			var c: Vector2i = o.get("cell", Vector2i(-99999, -99999))
			if rect.has_point(c):
				var p := _to_screen(Vector2(c))
				draw_rect(Rect2(p + Vector2.ONE * _px * 0.25, Vector2.ONE * _px * 0.5), Color(PLAN, 0.7), false, 1.0)
	# feu de camp (centre du village)
	draw_circle(_to_screen(Vector2(w.spawn_cell) + Vector2(0.5, 0.5)), maxf(3.0, _px * 0.45), Color("ff8a3a"))
	# habitants
	_dots.clear()
	for v in get_tree().get_nodes_in_group("villagers"):
		var pos := _to_screen(Vector2(v.global_position.x, v.global_position.z))
		if not Rect2(Vector2.ZERO, size).has_point(pos):
			continue
		var cd = Villager.class_data(str(v.get("fight_class")))
		var col: Color = cd.color if cd else Color.WHITE
		var r := maxf(3.5, _px * 0.42)
		draw_circle(pos, r + 1.5, Color(0, 0, 0, 0.7))
		draw_circle(pos, r, col)
		if v.call("is_at_work"):
			draw_arc(pos, r + 3.0, 0, TAU, 16, Color("8ad66a"), 1.5)
		_dots.append([pos, r + 3.0, v])
	# le héros
	if player:
		var hp := _to_screen(Vector2(player.global_position.x, player.global_position.z))
		var f: Vector3 = player.get("facing") if player.get("facing") != null else Vector3.FORWARD
		var a := atan2(f.x, f.z)
		var s := maxf(6.0, _px * 0.8)
		var pts := PackedVector2Array([hp + Vector2(sin(a), cos(a)) * s, hp + Vector2(sin(a + 2.5), cos(a + 2.5)) * s * 0.7, hp + Vector2(sin(a - 2.5), cos(a - 2.5)) * s * 0.7])
		draw_colored_polygon(pts, MenuKit.C_GOLD)
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0, 0.8), 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(MenuKit.C_FRAME, 0.9), false, 2.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var txt := _describe(event.position)
		if txt != _hover:
			_hover = txt
			hovered.emit(txt)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var v = _villager_at(event.position)
		if v:
			villager_clicked.emit(v)
			accept_event()


func _villager_at(p: Vector2) -> Node:
	for d in _dots:
		if (d[0] as Vector2).distance_to(p) <= float(d[1]):
			return d[2]
	return null


func _describe(p: Vector2) -> String:
	var v = _villager_at(p)
	if v:
		var cd = Villager.class_data(str(v.get("fight_class")))
		var job := "sans poste"
		if v.get("work_room") != null and v.work_room.type:
			job = (v.work_room.type as RoomTypeData).job_name
		return "%s · %s · %s · %s  (clic : sa fiche)" % [v.get("villager_name"), cd.display_name if cd else "?", job, VillageNeeds.mood_name(v.get("happiness"))]
	var best := ""
	var bd := INF
	for r in _rooms:
		var d := (r[0] as Vector2).distance_to(p)
		if d < float(r[1]) + 4.0 and d < bd:
			bd = d
			best = r[2]
	return best
