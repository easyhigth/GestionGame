extends SceneTree
var f := 0
var p; var w; var items; var hud; var cities; var idx := 0; var cam: Camera3D
var ok := true
var game_ms := 0.0
## Le bandeau de chaque ville vu au moins une fois (les grands titres passent l'un après l'autre).
var seen_banner := {}
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/ci_"

func _initialize():
	var h = load("res://scripts/hero/hero_profile.gd").new()
	h.hero_name = "Selka"
	h.race = load("res://data/races/homme_bete.tres")
	h.style = 2
	h.skin_color = Color("d88a3a"); h.hair_color = Color("e8e0d0"); h.eye_color = Color("40e0a0")
	h.hero_class = load("res://data/classes/guerrier.tres")
	h.job = load("res://data/jobs/chasseur.tres")
	h.skill = load("res://data/skills/vorace.tres")
	root.get_node("GameState").hero = h
	root.get_node("GameState").world_seed = int(OS.get_environment("TEST_SEED")) if OS.get_environment("TEST_SEED") != "" else 4242
	change_scene_to_file("res://scenes/main.tscn")

func check(name: String, cond: bool) -> void:
	print(("  OK  " if cond else "  ÉCHEC  ") + name)
	ok = ok and cond

func shot(n):
	root.get_viewport().get_texture().get_image().save_png(out + n)
	print("saved ", n)

func later(key: String, ms: int) -> bool:
	if not has_meta(key) or has_meta(key + "_done"):
		return false
	if game_ms - float(get_meta(key)) < ms:
		return false
	set_meta(key + "_done", true)
	return true

func start(key: String) -> void:
	set_meta(key, game_ms)
	if has_meta(key + "_done"): remove_meta(key + "_done")

func gold() -> int:
	return p.inventory.count(items.get_item("piece_or"))


func view(at: Vector3, yaw: float, pitch: float, zoom: float) -> void:
	p.global_position = at
	p.cam_yaw = deg_to_rad(yaw); p.cam_pitch = deg_to_rad(pitch); p.camera_zoom = zoom; p.snap_camera()

func ctr(c) -> Vector3:
	return Vector3(c.center.x + 0.5, float(c.base), c.center.y + 0.5)

## Vue d'ensemble : une caméra libre au-dessus de la ville, qui regarde son centre.
func overview(c, dist: float, height: float, angle: float) -> void:
	var o := ctr(c)
	if cam == null:
		cam = Camera3D.new(); cam.far = 600.0
		root.add_child(cam)
	cam.global_position = o + Vector3(sin(angle) * dist, height, cos(angle) * dist)
	cam.look_at(o + Vector3(0, 6, 0))
	cam.make_current()

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p: p._invulnerable_left = 5.0
	if f == 8:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		hud = get_first_node_in_group("hud")
		get_first_node_in_group("raids").enabled = false
		get_first_node_in_group("weather").set_kind("clair")
		get_first_node_in_group("day_cycle").hour = 10.0
		cities = w.cities
		var pop := 0
		for c in cities:
			pop += int(c.population)
			print("   %s (%s) : centre %s, sol %d m, %d blocs, %d étals, %d habitants" % [c.name, c.nation, c.center, c.base, c.blocks, c.stalls.size(), c.population])
			check("%s est bâtie en blocs (%d)" % [c.name, c.blocks], int(c.blocks) > 2500)
		check("les cinq capitales existent (%d)" % cities.size(), cities.size() == 5)
		var in_pref := 0
		for c in cities:
			var z = w.zone_at(Vector3(c.center.x, 0, c.center.y))
			var rid: String = z.type.id if not z.is_empty() and z.type else "?"
			var prefs: Array = load("res://scripts/world/city_plans.gd").CITIES[c.nation].regions
			print("   %s : région %s (préférées %s)" % [c.name, rid, prefs])
			if rid in prefs: in_pref += 1
		check("les capitales dans les régions de leur peuple (%d / 5)" % in_pref, in_pref >= 4)
		check("des milliers d'habitants (%d)" % pop, pop >= 3000)
		var far := true
		for c in cities:
			if Vector2(c.center - w.spawn_cell).length() < 200.0: far = false
		check("loin du village de départ", far)
		start("go")
	# une visite de chaque ville : vue d'ensemble, puis dans les rues
	if later("go", 500):
		var c = cities[idx]
		w.load_area(ctr(c))
		view(ctr(c) + Vector3(0, 0, c.radius + 10), 0, 30, 1.0)
		overview(c, c.radius * 1.35, c.radius * 0.9, 0.5)
		start("air")
	if later("air", 4000):
		var c = cities[idx]
		shot("%02d_%s_vue.png" % [idx * 2 + 1, c.nation])
		cam.clear_current()
		# dans la rue, près du marché
		var st: Vector2i = c.stalls[0][0]
		var stf := Vector2(st) * (1.0 - 6.0 / maxf(8.0, Vector2(st).length()))
		var at := Vector3(c.center.x + stf.x + 0.5, 0, c.center.y + stf.y + 0.5)
		at.y = w.support_height(at, w.terrain_height(Vector2i(int(floor(at.x)), int(floor(at.z)))) + 0.3)
		# la caméra derrière le héros, tournée vers le marché
		view(at, rad_to_deg(atan2(-float(st.x), -float(st.y))), 22, 1.2)
		start("rue")
	if later("rue", 3000):
		var c = cities[idx]
		shot("%02d_%s_rue.png" % [idx * 2 + 2, c.nation])
		var cl = get_first_node_in_group("city_life")
		check("%s s'anime (%d habitants autour du héros)" % [c.name, cl.active_count(c.nation)], cl.active_count(c.nation) >= 40)
		start("banner")
	if has_meta("banner") and not has_meta("banner_done"):
		var c = cities[idx]
		if hud._zone_title.text == c.name:
			seen_banner[idx] = true
		# le bandeau de la ville peut attendre que celui de la région ait fini (8 s au plus)
		if seen_banner.has(idx) or game_ms - float(get_meta("banner")) > 8000.0:
			set_meta("banner_done", true)
			check("bandeau « %s »" % c.name, seen_banner.has(idx))
			idx += 1
			if idx < cities.size():
				start("go")
			else:
				start("shop")
	if later("shop", 300):
		var c = cities[cities.size() - 1]
		var m = get_nodes_in_group("townsfolk").filter(func(t): return t.role == "merchant" and t.shop != null)
		check("des marchands à leurs étals (%d)" % m.size(), m.size() >= 5)
		var trades := {}
		for t in m: trades[t.trade_name] = true
		check("des métiers variés (%s)" % ", ".join(trades.keys()), trades.size() >= 4)
		var mer = m[0]
		p.global_position = mer.global_position + Vector3(0, 0, 1.2)
		p.inventory.add(items.get_item("piece_or"), 600)
		var ev := InputEventAction.new(); ev.action = "interact"; ev.pressed = true
		p._unhandled_input(ev)
		check("F : la boutique du marchand s'ouvre", hud.shop_dialog.visible and hud.shop_dialog.city == mer.shop)
		var entry: Dictionary = mer.shop.stock[0]
		var it = items.get_item(entry.id)
		var n0: int = p.inventory.count(it)
		var g0 := gold()
		hud.shop_dialog._do_buy(entry, 1, "")
		check("achat : %s (%d -> %d or)" % [it.display_name, g0, gold()], p.inventory.count(it) == n0 + 1 and gold() < g0)
		start("shop2")
	if later("shop2", 800):
		shot("11_boutique.png")
		hud.shop_dialog.close()
		# on monte de la grande porte jusqu'à la citadelle à pied
		var mc = cities.filter(func(c): return c.nation == "cendres")
		if not mc.is_empty():
			var c = mc[0]
			# toutes les cases que l'on atteint à pied depuis la grande porte (mêmes règles de marche que le héros)
			var ctr: Vector2i = c.center
			var st: Vector2i = ctr + Vector2i(0, -c.radius - 3)
			var hg := {st: w.terrain_height(st)}
			var q := [st]
			while not q.is_empty():
				var cur: Vector2i = q.pop_front()
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = cur + d
					if hg.has(n) or Vector2(n - ctr).length() > c.radius + 6: continue
					if w.step_ok(n, hg[cur]):
						hg[n] = w.support_height(Vector3(n.x + 0.5, 0, n.y + 0.5), hg[cur])
						q.append(n)
			var top: Vector2i = ctr + Vector2i(0, 1)
			check("Minas Cendrys : on monte à pied de la grande porte jusque dans la citadelle (%d cases, %.0f m de montée)" % [hg.size(), float(hg.get(top, 0.0)) - float(hg[st])],
				hg.has(top) and float(hg[top]) - float(hg[st]) > 20.0)
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	return false
