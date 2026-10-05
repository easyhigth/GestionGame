class_name KingdomMap
extends Control
## Carte du royaume vue du ciel (onglet « Carte » du panneau du royaume).
## Le vrai terrain (herbe, sable, eau, roche, chemins pavés, terre labourée) avec un relief ombré, les arbres,
## rochers, buissons et filons, les blocs posés (couleur de leur matière), les meubles, les pièces (contour et
## nom dans la couleur de leur type, places de travail), les plans en attente, les habitants (couleur de leur
## classe, nom en zoomant) et le héros. Molette : zoom ; glisser : se déplacer ; clic : détails.

signal hovered(text: String)
signal villager_clicked(v: Node)
signal room_clicked(r: Dictionary)

const PLAN := Color("f2c86a")
const MIN_PX := 4.0
const MAX_PX := 26.0

var player: Node3D
## Case au centre de la vue, et pixels par case.
var center := Vector2.ZERO
var px := 10.0
var selected_room: Dictionary = {}

var _tex: ImageTexture
var _tex_origin := Vector2i.ZERO
var _hover := ""
var _dots: Array = []          # [position écran, rayon, habitant]
var _drag := false
var _moved := 0.0
var _block_cols := {}          # identifiant d'objet -> couleur moyenne de sa texture
var _buttons: HBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_build_terrain()
	resized.connect(queue_redraw)
	# boutons de zoom en surimpression
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 3)
	_buttons.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_buttons.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_buttons.offset_right = -6
	_buttons.offset_top = 6
	add_child(_buttons)
	for b in [["−", "Dézoomer"], ["+", "Zoomer"], ["⌖", "Recentrer sur le village"]]:
		var btn := MenuKit.button(b[0], 30, 12)
		btn.custom_minimum_size = Vector2(30, 26)
		btn.tooltip_text = b[1]
		var sym: String = b[0]
		btn.pressed.connect(_on_button.bind(sym))
		_buttons.add_child(btn)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fit.call_deferred()


func _on_button(sym: String) -> void:
	if sym == "+":
		zoom_at(size / 2.0, 1.35)
	elif sym == "−":
		zoom_at(size / 2.0, 1.0 / 1.35)
	else:
		fit()


func _k() -> Kingdom:
	return get_tree().get_first_node_in_group("kingdom") as Kingdom


func _w() -> WorldGenerator:
	return get_tree().get_first_node_in_group("world") as WorldGenerator


# ---------------------------------------------------------------- terrain

## Le terrain du village en image (une case = un pixel), avec un relief ombré.
func _build_terrain() -> void:
	var w := _w()
	if w == null:
		return
	var half := Vector2i(56, 40)
	_tex_origin = w.home_cell_or_spawn() - half
	var size_c := half * 2
	var img := Image.create(size_c.x, size_c.y, false, Image.FORMAT_RGB8)
	for z in size_c.y:
		for x in size_c.x:
			img.set_pixel(x, z, _cell_color(w, _tex_origin + Vector2i(x, z)))
	_tex = ImageTexture.create_from_image(img)


func _cell_color(w: WorldGenerator, c: Vector2i) -> Color:
	var r: RegionData = w.region_at(Vector3(c.x + 0.5, 0, c.y + 0.5))
	var grass: Color = r.grass_color if r else Color("5e9c44")
	var col: Color
	match w.terrain_type(c):
		WorldGenerator.DEEP:
			col = Color("2a5a8a")
		WorldGenerator.WATER:
			col = Color("3f7cb0")
		WorldGenerator.SAND:
			col = r.sand_color if r else Color("e0cc8a")
		WorldGenerator.STONE:
			col = r.stone_color if r else Color("8e8c86")
		WorldGenerator.PLAZA:
			col = Color("b0a690")
		WorldGenerator.DIRT:
			col = r.dirt_color if r else Color("7a5a3c")
		WorldGenerator.FARM:
			col = Color("6a4426") if (c.x + c.y) % 2 == 0 else Color("5a381e")
		_:
			col = grass if (hash(c) % 5) != 0 else (r.grass_dark_color if r else grass.darkened(0.1))
	# relief : la lumière vient du nord-ouest
	var h := w.terrain_height(c)
	var d := h - w.terrain_height(c - Vector2i(1, 1))
	col = col.lightened(clampf(d * 0.12, 0.0, 0.25)) if d > 0.0 else col.darkened(clampf(-d * 0.12, 0.0, 0.3))
	return col.lerp(Color.WHITE, clampf((h - 4.0) * 0.008, 0.0, 0.15))


# ---------------------------------------------------------------- vue

func _to_screen(cell: Vector2) -> Vector2:
	return size / 2.0 + (cell - center) * px


func _to_cell(s: Vector2) -> Vector2:
	return center + (s - size / 2.0) / px


## Cadre la vue sur le village (pièces fermées, habitants), avec une marge.
func fit() -> void:
	var w := _w()
	if w == null:
		return
	var mn := Vector2(w.home_cell_or_spawn()) - Vector2(10, 10)
	var mx := Vector2(w.home_cell_or_spawn()) + Vector2(10, 10)
	var k := _k()
	if k:
		for r in k.rooms:
			if not r.get("enclosed", false):
				continue
			for c in r.cells:
				mn = Vector2(minf(mn.x, c.x), minf(mn.y, c.y))
				mx = Vector2(maxf(mx.x, c.x), maxf(mx.y, c.y))
	for v in get_tree().get_nodes_in_group("villagers"):
		var c := Vector2(v.global_position.x, v.global_position.z)
		if c.distance_to(Vector2(w.home_cell_or_spawn())) < 50.0:
			mn = Vector2(minf(mn.x, c.x), minf(mn.y, c.y))
			mx = Vector2(maxf(mx.x, c.x), maxf(mx.y, c.y))
	mn -= Vector2(3, 3)
	mx += Vector2(3, 3)
	center = (mn + mx) / 2.0
	var sz := size if size.x > 10 else custom_minimum_size
	px = clampf(minf(sz.x / (mx.x - mn.x), sz.y / (mx.y - mn.y)), MIN_PX, MAX_PX)
	queue_redraw()


func zoom_at(screen: Vector2, factor: float) -> void:
	var before := _to_cell(screen)
	px = clampf(px * factor, MIN_PX, MAX_PX)
	center += before - _to_cell(screen)
	queue_redraw()


## Sélectionne une pièce et centre la vue dessus.
func select_room(r: Dictionary) -> void:
	selected_room = r
	if not r.is_empty():
		var sum := Vector2.ZERO
		for c in r.cells:
			sum += Vector2(c)
		center = sum / maxf(1.0, r.cells.size()) + Vector2(0.5, 0.5)
		px = maxf(px, 14.0)
	queue_redraw()


static func room_center(r: Dictionary) -> Vector2:
	var sum := Vector2.ZERO
	for c in r.cells:
		sum += Vector2(c)
	return sum / maxf(1.0, r.cells.size()) + Vector2(0.5, 0.5)


# ---------------------------------------------------------------- dessin

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("16200f"))
	var w := _w()
	if w == null:
		return
	var font := get_theme_default_font()
	if _tex:
		draw_texture_rect(_tex, Rect2(_to_screen(Vector2(_tex_origin)), Vector2(_tex.get_size()) * px), false)
	var lo := _to_cell(Vector2.ZERO).floor()
	var hi := _to_cell(size).ceil()
	var view := Rect2i(Vector2i(lo), Vector2i(hi - lo) + Vector2i.ONE)
	_draw_decor(w, view)
	_draw_build(w, view)
	_draw_rooms(font)
	_draw_plans(view)
	# feu de camp
	var fire := _to_screen(Vector2(w.home_cell_or_spawn()) + Vector2(0.5, 0.5))
	draw_circle(fire, maxf(6.0, px * 1.1), Color(1.0, 0.55, 0.15, 0.18))
	draw_circle(fire, maxf(4.0, px * 0.5), Color("ff8a3a"))
	draw_circle(fire, maxf(2.0, px * 0.25), Color("ffe08a"))
	_draw_people(font)
	_draw_overlay(font)


func _draw_decor(w: WorldGenerator, view: Rect2i) -> void:
	if px < 5.0:
		return
	for z in range(view.position.y, view.end.y):
		for x in range(view.position.x, view.end.x):
			var c := Vector2i(x, z)
			var d := w.decor_at(c)
			if d == WorldGenerator.D_NONE or d == WorldGenerator.D_GRASS:
				continue
			var p := _to_screen(Vector2(c) + Vector2(0.5, 0.5))
			match d:
				WorldGenerator.D_OAK, WorldGenerator.D_PINE:
					draw_circle(p + Vector2(px * 0.15, px * 0.18), px * 0.62, Color(0, 0, 0, 0.25))
					draw_circle(p, px * 0.6, Color("2f5a24") if d == WorldGenerator.D_PINE else Color("3c6e2a"))
					draw_circle(p - Vector2(px * 0.15, px * 0.15), px * 0.3, Color("5a8e3c"))
				WorldGenerator.D_BUSH:
					draw_circle(p, px * 0.35, Color("4a7a30"))
				WorldGenerator.D_ROCK:
					draw_circle(p, px * 0.42, Color("6a6862"))
					draw_circle(p - Vector2(px * 0.1, px * 0.1), px * 0.22, Color("9a9890"))
				WorldGenerator.D_IRON, WorldGenerator.D_GOLD:
					draw_circle(p, px * 0.42, Color("6a6862"))
					draw_circle(p, px * 0.18, Color("c88a5a") if d == WorldGenerator.D_IRON else Color("f2c84a"))
				WorldGenerator.D_FLOWERS:
					if px >= 9.0:
						draw_circle(p, px * 0.12, Color("f0a0c8"))


## Blocs posés (le plus haut de chaque colonne, avec une ombre) et meubles (leur icône en zoomant).
func _draw_build(w: WorldGenerator, view: Rect2i) -> void:
	if w.build == null:
		return
	var top := {}
	for key in w.build.blocks:
		var c := Vector2i(key.x, key.z)
		if not view.has_point(c):
			continue
		if not top.has(c) or int(top[c][0]) < key.y:
			top[c] = [key.y, w.build.blocks[key]]
	for c in top:
		var col := _block_color(top[c][1])
		var rr := Rect2(_to_screen(Vector2(c)), Vector2.ONE * px)
		draw_rect(Rect2(rr.position + Vector2(px * 0.15, px * 0.15), rr.size), Color(0, 0, 0, 0.3))
		draw_rect(rr, col)
		if px >= 8.0:
			draw_rect(rr, col.darkened(0.3), false, 1.0)
	for fk in w.build.furniture:
		var c := Vector2i(fk.x, fk.z)
		if not view.has_point(c):
			continue
		var it: ItemData = w.build.furniture[fk].item
		var rr := Rect2(_to_screen(Vector2(c)), Vector2.ONE * px)
		var icon := Items.get_icon(it) if px >= 12.0 else null
		if icon:
			draw_rect(rr.grow(-1), Color(0.1, 0.07, 0.05, 0.6))
			draw_texture_rect(icon, rr.grow(-1), false)
		else:
			draw_rect(rr.grow(-px * 0.25), Color("c8a070"))


func _draw_rooms(font: Font) -> void:
	var k := _k()
	if k == null:
		return
	for r in k.rooms:
		if not r.get("enclosed", false):
			continue
		var t: RoomTypeData = r.type
		var col: Color = t.color if t else Color(0.75, 0.75, 0.75)
		var sel: bool = r == selected_room
		for c in r.cells:
			draw_rect(Rect2(_to_screen(Vector2(c)), Vector2.ONE * px), Color(col, 0.42 if t else 0.18))
		# contour : les côtés de cases qui ne touchent pas la pièce
		var wdt := 3.0 if sel else 2.0
		var oc := Color.WHITE if sel else col.lightened(0.15)
		for c in r.cells:
			var p := _to_screen(Vector2(c))
			if not r.cells.has(c + Vector2i(0, -1)):
				draw_line(p, p + Vector2(px, 0), oc, wdt)
			if not r.cells.has(c + Vector2i(0, 1)):
				draw_line(p + Vector2(0, px), p + Vector2(px, px), oc, wdt)
			if not r.cells.has(c + Vector2i(-1, 0)):
				draw_line(p, p + Vector2(0, px), oc, wdt)
			if not r.cells.has(c + Vector2i(1, 0)):
				draw_line(p + Vector2(px, 0), p + Vector2(px, px), oc, wdt)
		# étiquette en pastille : nom et places de travail
		var cen := _to_screen(room_center(r))
		var txt: String = t.display_name if t else "Pièce à finir ?"
		if t and t.job_slots > 0:
			txt += "  %d/%d" % [k.workers_of(r).size(), t.job_slots]
		var fs := 11 if px >= 10.0 else 9
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if px * sqrt(r.cells.size()) > tw * 0.6 or sel:
			var box := Rect2(cen - Vector2(tw / 2.0 + 5, fs * 0.9), Vector2(tw + 10, fs + 6))
			draw_rect(box, Color(0.08, 0.06, 0.04, 0.82))
			draw_rect(box, col, false, 1.0)
			draw_string(font, box.position + Vector2(5, fs + 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE if t else Color(0.85, 0.85, 0.85))


## Plans en attente : cases dorées hachurées.
func _draw_plans(view: Rect2i) -> void:
	var bo := get_tree().get_first_node_in_group("build_orders")
	if bo == null:
		return
	var seen := {}
	for id in bo.orders:
		var c: Vector2i = bo.orders[id].get("cell", Vector2i(-99999, -99999))
		if seen.has(c) or not view.has_point(c):
			continue
		seen[c] = true
		var rr := Rect2(_to_screen(Vector2(c)), Vector2.ONE * px)
		draw_rect(rr, Color(PLAN, 0.18))
		draw_line(rr.position + Vector2(0, px), rr.position + Vector2(px, 0), Color(PLAN, 0.6), 1.0)
		draw_rect(rr, Color(PLAN, 0.55), false, 1.0)


func _draw_people(font: Font) -> void:
	_dots.clear()
	for v in get_tree().get_nodes_in_group("villagers"):
		var pos := _to_screen(Vector2(v.global_position.x, v.global_position.z))
		if not Rect2(Vector2.ZERO, size).grow(10).has_point(pos):
			continue
		var cd = Villager.class_data(str(v.get("fight_class")))
		var col: Color = cd.color if cd else Color.WHITE
		var rad := clampf(px * 0.5, 4.0, 9.0)
		draw_circle(pos + Vector2(1, 1.5), rad + 1.5, Color(0, 0, 0, 0.5))
		draw_circle(pos, rad + 1.5, Color("1a1410"))
		draw_circle(pos, rad, col)
		if v.call("is_at_work"):
			draw_arc(pos, rad + 3.0, 0, TAU, 20, Color("8ad66a"), 2.0)
		if px >= 13.0:
			_outlined(font, pos + Vector2(0, rad + 12), str(v.get("villager_name")), 10, Color.WHITE, true)
		_dots.append([pos, rad + 4.0, v])
	if player:
		var hp := _to_screen(Vector2(player.global_position.x, player.global_position.z))
		var f: Vector3 = player.get("facing") if player.get("facing") != null else Vector3.FORWARD
		var a := atan2(f.x, f.z)
		var s := clampf(px * 0.9, 8.0, 14.0)
		var pts := PackedVector2Array([hp + Vector2(sin(a), cos(a)) * s, hp + Vector2(sin(a + 2.4), cos(a + 2.4)) * s * 0.75,
			hp, hp + Vector2(sin(a - 2.4), cos(a - 2.4)) * s * 0.75])
		draw_colored_polygon(pts, MenuKit.C_GOLD)
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.15, 0.08, 0.02), 1.5)
		_outlined(font, hp + Vector2(0, -s - 3), "Toi", 10, MenuKit.C_GOLD, true)


## Rose des vents, échelle et cadre.
func _draw_overlay(font: Font) -> void:
	var nc := Vector2(22, 24)
	draw_circle(nc, 15, Color(0.08, 0.06, 0.04, 0.8))
	draw_arc(nc, 15, 0, TAU, 24, MenuKit.C_FRAME, 1.5)
	draw_colored_polygon(PackedVector2Array([nc + Vector2(0, -12), nc + Vector2(5, 2), nc + Vector2(-5, 2)]), Color("e0705a"))
	draw_colored_polygon(PackedVector2Array([nc + Vector2(0, 12), nc + Vector2(5, -2), nc + Vector2(-5, -2)]), Color("d0c8b8"))
	_outlined(font, nc + Vector2(0, -16), "N", 10, MenuKit.C_GOLD, true)
	var bar := 8.0 * px
	var bp := Vector2(12, size.y - 14)
	draw_line(bp, bp + Vector2(bar, 0), Color.WHITE, 2.0)
	draw_line(bp - Vector2(0, 4), bp + Vector2(0, 4), Color.WHITE, 2.0)
	draw_line(bp + Vector2(bar, -4), bp + Vector2(bar, 4), Color.WHITE, 2.0)
	_outlined(font, bp + Vector2(bar + 6, 4), "8 m", 10, Color.WHITE, false)
	draw_rect(Rect2(Vector2.ZERO, size), Color(MenuKit.C_FRAME, 0.9), false, 2.0)


func _outlined(font: Font, pos: Vector2, text: String, fs: int, col: Color, centered: bool) -> void:
	var p := pos
	if centered:
		p.x -= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x / 2.0
	draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.85))
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Couleur moyenne de la texture d'un bloc (gardée en mémoire).
func _block_color(it: ItemData) -> Color:
	if it == null:
		return Color("6e6a62")
	if _block_cols.has(it.id):
		return _block_cols[it.id]
	var col := Color("8a7a66")
	if it.tint.a > 0.0:
		col = Color(it.tint, 1.0)
	elif it.block_texture:
		var img := it.block_texture.get_image()
		if img:
			if img.is_compressed():
				img = img.duplicate()
				img.decompress()
			var acc := Color(0, 0, 0, 0)
			var n := 0
			var sx := maxi(1, img.get_width() / 6)
			var sy := maxi(1, img.get_height() / 6)
			for y in range(0, img.get_height(), sy):
				for x in range(0, img.get_width(), sx):
					acc += img.get_pixel(x, y)
					n += 1
			if n > 0:
				col = Color(acc.r / n, acc.g / n, acc.b / n)
	_block_cols[it.id] = col
	return col


# ---------------------------------------------------------------- souris

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_at(event.position, 1.15)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_at(event.position, 1.0 / 1.15)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_drag = true
				_moved = 0.0
			else:
				_drag = false
				if _moved < 5.0:
					_click(event.position)
			accept_event()
	elif event is InputEventMouseMotion:
		if _drag:
			center -= event.relative / px
			_moved += event.relative.length()
			queue_redraw()
		var txt := _describe(event.position)
		if txt != _hover:
			_hover = txt
			hovered.emit(txt)


func _click(p: Vector2) -> void:
	var v = _villager_at(p)
	if v:
		villager_clicked.emit(v)
		return
	selected_room = _room_at(p)
	room_clicked.emit(selected_room)
	queue_redraw()


func _villager_at(p: Vector2) -> Node:
	for d in _dots:
		if (d[0] as Vector2).distance_to(p) <= float(d[1]):
			return d[2]
	return null


func _room_at(p: Vector2) -> Dictionary:
	var k := _k()
	if k:
		var c := Vector2i(_to_cell(p).floor())
		for r in k.rooms:
			if r.get("enclosed", false) and r.cells.has(c):
				return r
	return {}


func _describe(p: Vector2) -> String:
	var v = _villager_at(p)
	if v:
		var cd = Villager.class_data(str(v.get("fight_class")))
		var job := "sans poste"
		if v.get("work_room") != null and v.work_room.type:
			job = (v.work_room.type as RoomTypeData).job_name
		return "%s · %s · %s · %s  (clic : sa fiche)" % [v.get("villager_name"), cd.display_name if cd else "?", job, VillageNeeds.mood_name(v.get("happiness"))]
	var r := _room_at(p)
	if not r.is_empty():
		var t: RoomTypeData = r.type
		if t == null:
			return "Pièce pas encore reconnue  (clic : ce qu'il manque)"
		return t.display_name + "  (clic : détails)"
	var w := _w()
	if w == null:
		return ""
	var c := Vector2i(_to_cell(p).floor())
	var fm := get_tree().get_first_node_in_group("farming")
	if fm and fm.plots.has(c):
		return "Champ"
	var bo := get_tree().get_first_node_in_group("build_orders")
	if bo:
		for id in bo.orders:
			if bo.orders[id].get("cell", Vector2i(-99999, -99999)) == c:
				return "Plan en attente : tes habitants sans poste viendront le construire"
	if w.build and w.build._furn_cols.has(c):
		for fk in w.build._furn_cols[c]:
			if w.build.furniture.has(fk):
				return "Meuble : " + (w.build.furniture[fk].item as ItemData).display_name
	match w.decor_at(c):
		WorldGenerator.D_OAK, WorldGenerator.D_PINE:
			return "Arbre"
		WorldGenerator.D_ROCK:
			return "Rocher"
		WorldGenerator.D_IRON:
			return "Filon de fer"
		WorldGenerator.D_GOLD:
			return "Filon d'or"
		WorldGenerator.D_BUSH:
			return "Buisson (baies)"
	match w.terrain_type(c):
		WorldGenerator.WATER, WorldGenerator.DEEP:
			return "Eau"
		WorldGenerator.PLAZA:
			return "Place pavée"
	return ""
