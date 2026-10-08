class_name MiniMap
extends Control
## Mini-carte en haut à droite : les environs du héros (carte dévoilée), les obélisques,
## les donjons et le village. Le nom de la zone actuelle est écrit dessous.
## Sous terre (donjons, grottes de montagne, grottes sous-marines, sièges), elle devient une carte dédiée :
## les salles et couloirs se dévoilent à mesure que le héros les parcourt, avec la sortie, les coffres,
## les leviers, le boss et les monstres proches.

const SIZE := 168.0
## Nombre de cases visibles d'un bord à l'autre.
const SPAN := 90.0

var world: WorldGenerator
var player: Player
var _font: Font


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE + 34)
	size = custom_minimum_size
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -SIZE - 14
	offset_right = -14
	offset_top = 40
	offset_bottom = 40 + SIZE + 34
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()


var _last_pos := Vector3.INF
var _last_facing := Vector3.ZERO
var _redraw_left := 0.0


func _process(delta: float) -> void:
	var under := player != null and player.global_position.y < WorldGenerator.UNDERGROUND
	visible = world != null and player != null and not player.ui_open and (under and _under_info().has("grid") or not under and world.map_texture != null)
	if not visible:
		return
	if under:
		_reveal_under()
	# on ne redessine que si le héros a bougé ou tourné, et au moins 5 fois par seconde (pillards, compagnons)
	_redraw_left -= delta
	var moved := player.global_position.distance_squared_to(_last_pos) > 0.04 or player.facing.distance_squared_to(_last_facing) > 0.002
	if moved or _redraw_left <= 0.0:
		_last_pos = player.global_position
		_last_facing = player.facing
		_redraw_left = 0.2
		queue_redraw()


var _near_zones: Array = []
var _near_sites: Array = []
var _near_cities: Array = []
var _near_center := Vector2(INF, INF)


## Les lieux proches du héros, recalculés seulement quand il s'est éloigné (au lieu de tout parcourir à chaque dessin).
func _refresh_near(pc: Vector2) -> void:
	if pc.distance_to(_near_center) < SPAN * 0.25 and Engine.get_process_frames() % 120 != 0:
		return
	_near_center = pc
	var r := SPAN * 1.2
	_near_zones = world.zones.filter(func(z): return Vector2(z.obelisk).distance_to(pc) < r or Vector2(z.gate).distance_to(pc) < r)
	_near_sites = world.structure_sites.filter(func(st): return Vector2(st.cell).distance_to(pc) < r + 30.0)
	_near_cities = world.cities.filter(func(c): return Vector2(c.center).distance_to(pc) < r + float(c.radius))


func _draw() -> void:
	if player.global_position.y < WorldGenerator.UNDERGROUND:
		_draw_under()
		return
	var s := SIZE / SPAN
	var pc := Vector2(player.global_position.x, player.global_position.z)
	var rect := Rect2(Vector2.ZERO, Vector2(SIZE, SIZE))
	draw_rect(rect.grow(3), Color("2a2230"))
	draw_rect(rect, Color(0.04, 0.035, 0.05))
	# morceau de carte autour du héros
	var src := Rect2(pc - Vector2(SPAN, SPAN) / 2.0, Vector2(SPAN, SPAN))
	var tex_rect := Rect2(Vector2.ZERO, Vector2(world.world_size))
	var clipped := src.intersection(tex_rect)
	if clipped.size.x > 0 and clipped.size.y > 0:
		var dst := Rect2((clipped.position - src.position) * s, clipped.size * s)
		draw_texture_rect_region(world.map_texture, dst, clipped)
	_refresh_near(pc)
	# lieux
	for z in _near_zones:
		if (z.obelisk as Vector2i).x >= 0 and (z.obelisk_on or world.is_revealed(z.obelisk)):
			var q := (Vector2(z.obelisk) + Vector2(0.5, 0.5) - src.position) * s
			if rect.has_point(q):
				var col := Color("6ae0ff") if z.obelisk_on else Color(0.6, 0.65, 0.7)
				draw_colored_polygon(PackedVector2Array([q + Vector2(0, -5), q + Vector2(4, 0), q + Vector2(0, 5), q + Vector2(-4, 0)]), col)
		if (z.gate as Vector2i).x >= 0 and world.is_revealed(z.gate):
			var g := (Vector2(z.gate) + Vector2(0.5, 0.5) - src.position) * s
			if rect.has_point(g):
				draw_rect(Rect2(g - Vector2(3, 3), Vector2(6, 6)), Color("5ac84a") if z.get("cleared", false) else Color("c84a3a"))
	# capitales, châteaux, hameaux et épaves déjà vus
	for st in _near_sites:
		var k: String = st.kind
		if k != "castle" and k != "hamlet" and k != "wreck":
			continue
		var cc: Vector2i = st.cell + (Vector2i(10, 10) if k == "castle" else (Vector2i(1, 6) if k == "wreck" else Vector2i.ZERO))
		if not world.is_revealed(cc):
			continue
		var q := (Vector2(cc) - src.position) * s
		if not rect.has_point(q):
			continue
		match k:
			"castle":
				draw_rect(Rect2(q - Vector2(4, 3), Vector2(8, 7)), Color(0.6, 0.6, 0.62) if st.abandoned else Color("d8c8a8"))
				draw_rect(Rect2(q - Vector2(4, 5), Vector2(2, 2)), Color(0.6, 0.6, 0.62) if st.abandoned else Color("d8c8a8"))
				draw_rect(Rect2(q + Vector2(2, -5), Vector2(2, 2)), Color(0.6, 0.6, 0.62) if st.abandoned else Color("d8c8a8"))
			"hamlet":
				draw_colored_polygon(PackedVector2Array([q + Vector2(-3, 3), q + Vector2(-3, -1), q + Vector2(0, -4), q + Vector2(3, -1), q + Vector2(3, 3)]), Color("e8c890"))
			"wreck":
				draw_colored_polygon(PackedVector2Array([q + Vector2(-4, 0), q + Vector2(4, 0), q + Vector2(3, 3), q + Vector2(-3, 3)]), Color("8a5a32"))
	for city in _near_cities:
		var cc: Vector2i = city.center
		if not world.is_revealed(cc):
			continue
		var q := (Vector2(cc) - src.position) * s
		var col: Color = Diplomacy.NATIONS.get(city.nation, {}).get("color", Color("ffd24a"))
		var r := float(city.radius) * s
		if rect.grow(r).has_point(q):
			draw_arc(q, r, 0, TAU, 32, Color(col, 0.8), 1.5)
			if rect.has_point(q):
				draw_rect(Rect2(q - Vector2(5, 4), Vector2(10, 8)), Color("ffd24a"))
				draw_string(UiTheme.font("body"), q + Vector2(-40, -10), city.name, HORIZONTAL_ALIGNMENT_CENTER, 80, 10, col.lightened(0.4))
	# le camp (drapeau du royaume) : rien tant qu'il n'est pas planté
	var v := (Vector2(world.home_cell) + Vector2(0.5, 0.5) - src.position) * s
	if not world.has_home():
		pass
	elif rect.has_point(v):
		draw_arc(v, world.home_radius() * s, 0, TAU, 40, Color(0.95, 0.78, 0.4, 0.7), 1.2)
		draw_rect(Rect2(v - Vector2(4, 4), Vector2(8, 8)), Color("f2c86a"))
	else:
		# flèche vers le village au bord de la mini-carte
		var dir := (v - rect.get_center()).normalized()
		var edge := rect.get_center() + dir * (SIZE / 2.0 - 8.0)
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([edge + dir * 6, edge - dir * 3 + side * 4, edge - dir * 3 - side * 4]), Color("f2c86a"))
	# pillards (rouge) et compagnons (vert)
	for e in get_tree().get_nodes_in_group("enemy_units"):
		if e.has_meta("raider") and e.is_alive():
			var q := (Vector2(e.global_position.x, e.global_position.z) - src.position) * s
			if rect.has_point(q):
				draw_rect(Rect2(q - Vector2(2.5, 2.5), Vector2(5, 5)), Color("ff3a2a"))
	for vg in get_tree().get_nodes_in_group("villagers"):
		if vg.get("companion"):
			var q := (Vector2(vg.global_position.x, vg.global_position.z) - src.position) * s
			if rect.has_point(q):
				draw_circle(q, 3.0, Color("6aff6a"))
	# objectif de l'histoire : une étoile dorée (ou une flèche au bord)
	var st := get_tree().get_first_node_in_group("story") as Story
	var tp := st.target_pos() if st else Vector3.INF
	if tp != Vector3.INF:
		var q := (Vector2(tp.x, tp.z) - src.position) * s
		if rect.has_point(q):
			_star(q, 6.0, Color("ffd24a"))
		else:
			var dir := (q - rect.get_center()).normalized()
			var edge := rect.get_center() + dir * (SIZE / 2.0 - 9.0)
			_star(edge, 4.5, Color("ffd24a"))
	# héros au centre
	var c := rect.get_center()
	var f := Vector2(player.facing.x, player.facing.z).normalized()
	if f == Vector2.ZERO:
		f = Vector2(0, 1)
	var sd := Vector2(-f.y, f.x)
	var tri := PackedVector2Array([c + f * 7, c - f * 5 + sd * 5, c - f * 2, c - f * 5 - sd * 5])
	draw_colored_polygon(tri, Color.WHITE)
	draw_polyline(tri + PackedVector2Array([tri[0]]), Color("c83a2a"), 1.5)
	draw_rect(rect, Color("8a6a40"), false, 2.0)
	draw_string(_font, Vector2(SIZE - 12, 14), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("fff2dc"))
	# nom de la zone
	var z := world.zone_at(player.global_position)
	if not z.is_empty() and z.type:
		var t: RegionData = z.type
		var danger := WorldGenerator.zone_too_strong(z, int(player.level))
		var lines := [z.name, KeyBindings.fmt("Nv %d-%d  ·  %s" % [z.level.x, z.level.y, "Trop fort pour toi !" if danger else "{world_map} : carte"])]
		# fond sombre sous les deux lignes : lisibles sur la neige ou le sable en plein midi
		var w := maxf(_font.get_string_size(lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x, _font.get_string_size(lines[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x)
		var back := MenuKit.text_backing()
		back.draw(get_canvas_item(), Rect2(SIZE / 2.0 - w / 2.0 - 7.0, SIZE + 3, w + 14.0, 30))
		# région bien plus forte que le héros : son nom passe en rouge
		_text(lines[0], Vector2(SIZE / 2.0, SIZE + 15), 12, Color("ff6a5a") if danger else t.map_color.lightened(0.6))
		_text(lines[1], Vector2(SIZE / 2.0, SIZE + 29), 11, Color("ffb0a0") if danger else Color("e0d4b8"))


func _star(p: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + TAU * i / 10.0
		pts.append(p + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, col)
	pts.append(pts[0])
	draw_polyline(pts, Color(0.1, 0.07, 0.02), 1.0)


func _text(text: String, pos: Vector2, fs: int, col: Color) -> void:
	text = KeyBindings.fmt(text)
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := pos - Vector2(w / 2.0, 0)
	for off in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_string(_font, p + off, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.03, 0.02, 0.04))
	draw_string(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


# ---------------------------------------------------------------- sous terre : donjons et grottes

## Nombre de cases visibles d'un bord à l'autre sous terre (plus serré qu'à la surface : on voit les salles).
const SPAN_UNDER := 44.0
## Rayon (cases) dévoilé autour du héros sous terre.
const REVEAL_UNDER := 7
## Cases déjà vues, par lieu souterrain (clé : nom du lieu) : la carte se souvient de ce qu'on a exploré.
var _seen := {}


## Le lieu souterrain où se trouve le héros : {grid, floor, name, key, marks: [[position, sorte]]} ou {}.
func _under_info() -> Dictionary:
	if world == null or world.dungeon_grid == null:
		return {}
	var out := {"grid": world.dungeon_grid, "floor": player.global_position.y, "marks": []}
	var dm := get_tree().get_first_node_in_group("dungeons")
	var mc := get_tree().get_first_node_in_group("mountain_caves")
	var uc := get_tree().get_first_node_in_group("caves")
	var src: Node = null
	if dm and dm.active:
		src = dm
		out.floor = float(dm.FLOOR_Y)
		var z: Dictionary = dm.zone
		out.name = ("Siège : " if dm.siege != "" else "Donjon : ") + str(z.get("name", "?"))
		if dm.brume_tier > 0:
			out.name += "  ·  Brume %d" % dm.brume_tier
		elif dm.challenge > 0:
			out.name += "  ·  Défi %d" % dm.challenge
		if dm.boss and is_instance_valid(dm.boss) and dm.boss.is_alive():
			out.marks.append([dm.boss.global_position, "boss"])
	elif mc and mc.active:
		src = mc
		out.floor = float(mc.FLOOR_Y)
		out.name = "Grotte de montagne"
	elif uc and uc.active:
		src = uc
		out.floor = float(uc.FLOOR_Y)
		out.name = "Grotte sous-marine"
	else:
		return {}
	out.key = str(out.name) + str(src.get("cave_id") if src.get("cave_id") != null else "")
	for it in src.get("_interactables"):
		if it.get("used", false) and str(it.kind) != "exit":
			continue
		out.marks.append([it.pos, str(it.kind)])
	return out


func _under_cell_kind(grid: BuildGrid, c: Vector2i, floor_y: float) -> int:
	# 0 : rien (roche), 1 : sol praticable, 2 : mur
	if grid.body_blocked(c, floor_y):
		return 2
	return 1 if grid.support(c, floor_y + 0.6) > floor_y - 1.6 else 0


## Dévoile les cases autour du héros (5 fois par seconde suffit).
func _reveal_under() -> void:
	if Engine.get_process_frames() % 12 != 0:
		return
	var info := _under_info()
	if info.is_empty():
		return
	var seen: Dictionary = _seen.get(info.key, {})
	var pc := world.cell_at(player.global_position)
	for dz in range(-REVEAL_UNDER, REVEAL_UNDER + 1):
		for dx in range(-REVEAL_UNDER, REVEAL_UNDER + 1):
			if dx * dx + dz * dz <= REVEAL_UNDER * REVEAL_UNDER:
				var c := pc + Vector2i(dx, dz)
				if not seen.has(c):
					seen[c] = _under_cell_kind(info.grid, c, info.floor)
	_seen[info.key] = seen


func _draw_under() -> void:
	var info := _under_info()
	if info.is_empty():
		return
	var s := SIZE / SPAN_UNDER
	var pc := Vector2(player.global_position.x, player.global_position.z)
	var rect := Rect2(Vector2.ZERO, Vector2(SIZE, SIZE))
	var origin := pc - Vector2(SPAN_UNDER, SPAN_UNDER) / 2.0
	draw_rect(rect.grow(3), Color("2a2230"))
	draw_rect(rect, Color(0.03, 0.025, 0.04))
	var seen: Dictionary = _seen.get(info.key, {})
	var c0 := Vector2i(floori(origin.x), floori(origin.y))
	var n := int(SPAN_UNDER) + 2
	for dz in n:
		for dx in n:
			var c := c0 + Vector2i(dx, dz)
			if not seen.has(c):
				continue
			var k: int = seen[c]
			if k == 0:
				continue
			var q := (Vector2(c) - origin) * s
			var r := Rect2(q, Vector2(s, s) + Vector2(0.6, 0.6)).intersection(rect)
			if r.size.x <= 0.0 or r.size.y <= 0.0:
				continue
			draw_rect(r, Color("6e6458") if k == 1 else Color("2e2a33"))
	# repères : sortie (vert), coffres (or), leviers (bleu), boss (rouge), seulement là où l'on est passé
	for mk in info.marks:
		var p: Vector3 = mk[0]
		var cell := world.cell_at(p)
		if not seen.has(cell) and str(mk[1]) != "boss":
			continue
		var q := (Vector2(p.x, p.z) - origin) * s
		if not rect.has_point(q):
			continue
		match str(mk[1]):
			"exit":
				draw_circle(q, 4.0, Color("5ad86a"))
				draw_arc(q, 5.5, 0, TAU, 16, Color("e0ffe0"), 1.0)
			"boss":
				if seen.has(cell):
					_star(q, 6.0, Color("ff4a3a"))
			"lever":
				draw_rect(Rect2(q - Vector2(2.5, 2.5), Vector2(5, 5)), Color("6aa8ff"))
			_:
				if str(mk[1]).contains("chest"):
					draw_rect(Rect2(q - Vector2(3, 2.5), Vector2(6, 5)), Color("f2c86a"))
					draw_rect(Rect2(q - Vector2(3, 2.5), Vector2(6, 5)), Color(0.2, 0.12, 0.04), false, 1.0)
				else:
					draw_circle(q, 2.5, Color(0.8, 0.8, 0.85))
	# monstres proches (dans ce qu'on a déjà vu) et compagnons
	for e in get_tree().get_nodes_in_group("enemy_units"):
		var en := e as Node3D
		if en == null or not e.is_alive() or absf(en.global_position.y - float(info.floor)) > 4.0:
			continue
		if not seen.has(world.cell_at(en.global_position)):
			continue
		var q := (Vector2(en.global_position.x, en.global_position.z) - origin) * s
		if rect.has_point(q):
			draw_rect(Rect2(q - Vector2(2, 2), Vector2(4, 4)), Color("ff3a2a"))
	for vg in get_tree().get_nodes_in_group("villagers"):
		if vg.get("companion"):
			var q := (Vector2(vg.global_position.x, vg.global_position.z) - origin) * s
			if rect.has_point(q):
				draw_circle(q, 3.0, Color("6aff6a"))
	# héros au centre
	var c := rect.get_center()
	var f := Vector2(player.facing.x, player.facing.z).normalized()
	if f == Vector2.ZERO:
		f = Vector2(0, 1)
	var sd := Vector2(-f.y, f.x)
	var tri := PackedVector2Array([c + f * 7, c - f * 5 + sd * 5, c - f * 2, c - f * 5 - sd * 5])
	draw_colored_polygon(tri, Color.WHITE)
	draw_polyline(tri + PackedVector2Array([tri[0]]), Color("c83a2a"), 1.5)
	draw_rect(rect, Color("8a6a40"), false, 2.0)
	draw_string(_font, Vector2(SIZE - 12, 14), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("fff2dc"))
	# nom du lieu
	var name: String = info.get("name", "Sous terre")
	var w := _font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	MenuKit.text_backing().draw(get_canvas_item(), Rect2(SIZE / 2.0 - w / 2.0 - 7.0, SIZE + 3, w + 14.0, 18))
	_text(name, Vector2(SIZE / 2.0, SIZE + 15), 12, Color("e0d4b8"))
