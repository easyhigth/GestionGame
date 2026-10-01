extends SceneTree
var f := 0
var p; var w; var items; var hud; var rl; var con; var cam: Camera3D; var hm; var car_pos := Vector3.ZERO
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/rd_"

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

func look_to(target: Vector3, pitch := 24.0, zoom := 1.4) -> void:
	var d: Vector3 = target - p.global_position
	p.cam_yaw = atan2(-d.x, -d.z); p.cam_pitch = deg_to_rad(pitch); p.camera_zoom = zoom; p.snap_camera()

func overview(at: Vector3, dist: float, height: float) -> void:
	if cam == null:
		cam = Camera3D.new(); cam.far = 500.0
		root.add_child(cam)
	cam.global_position = at + Vector3(dist * 0.6, height, dist * 0.8)
	cam.look_at(at)
	cam.make_current()

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p: p._invulnerable_left = 5.0
	if f == 8:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		hud = get_first_node_in_group("hud"); rl = get_first_node_in_group("road_life"); con = get_first_node_in_group("command_console")
		get_first_node_in_group("raids").enabled = false
		get_first_node_in_group("weather").set_kind("clair")
		get_first_node_in_group("day_cycle").hour = 10.0
		rl._timer = 9999.0   # pas de rencontre au hasard pendant le test
		var total := 0.0
		for r in w.roads:
			for i in range(1, r.size()): total += Vector2(r[i] - r[i - 1]).length()
		check("des routes relient le village et les 5 capitales (%d routes, %.0f m)" % [w.roads.size(), total], w.roads.size() == 5 and total > 1000.0)
		# on marche sur toute la route : pas de marche plus haute qu'un pas
		var steps := 0
		var bad := 0
		for r in w.roads:
			for i in range(1, r.size()):
				var a: Vector2i = r[i - 1]; var b: Vector2i = r[i]
				var n := maxi(1, int(Vector2(b - a).length()))
				var prev := -999.0
				for k in n + 1:
					var c := Vector2i(Vector2(a).lerp(Vector2(b), float(k) / n).round())
					if not w.city_at(Vector3(c.x, 0, c.y), 0.0).is_empty(): prev = -999.0; continue
					var h: float = w.support_height(Vector3(c.x + 0.5, 0, c.y + 0.5), w.terrain_height(c) + 0.3)
					if prev > -998.0:
						steps += 1
						if absf(h - prev) > w.max_step: bad += 1
					prev = h
		check("les routes sont praticables à pied (%d marches trop hautes sur %d pas)" % [bad, steps], bad <= steps * 0.03)
		check("des ponts sur les rivières (%d cases)" % w._bridges.size(), w._bridges.size() >= 0)
		var hamlets = w.structure_sites.filter(func(s): return s.kind == "hamlet")
		check("des hameaux le long des routes (%d)" % hamlets.size(), hamlets.size() >= 4)
		hm = hamlets[0]
		var houses = w.structure_sites.filter(func(s): return s.get("hamlet", "") == hm.id)
		check("le hameau de %s a %d maisons en blocs" % [hm.name, houses.size()], houses.size() >= 4)
		con.run("/tp %d %d" % [hm.cell.x, hm.cell.y + 6])
		start("ham")
	if later("ham", 3000):
		var folk = get_nodes_in_group("townsfolk").filter(func(t): return t.global_position.distance_to(p.global_position) < 20.0)
		check("des villageois au hameau (%d)" % folk.size(), folk.size() >= 5)
		var col = folk.filter(func(t): return t.role == "merchant" and t.shop != null)
		check("un colporteur (%s)" % (col[0].trade_name if not col.is_empty() else "?"), col.size() == 1)
		var chief = folk.filter(func(t): return t.quest_key.begins_with("hamlet:"))
		check("le chef du hameau a une quête (« ! »)", chief.size() == 1 and chief[0]._mark.text == "!")
		if chief.size() == 1:
			var cl = get_first_node_in_group("city_life")
			var txt: String = cl.quest_talk(p, chief[0])
			check("il la propose : « %s »" % txt, cl.quests[chief[0].quest_key].state == "active")
		overview(w.cell_center(hm.cell), 34.0, 26.0)
		start("ham2")
	if later("ham2", 1500):
		shot("01_hameau.png")
		cam.clear_current()
		# sur la route : une caravane
		var r: Array = w.roads[0]
		var c: Vector2i = r[r.size() / 2]
		con.run("/tp %d %d" % [c.x, c.y])
		start("road")
	if later("road", 2500):
		var near: Dictionary = rl.nearest_road_point(p.global_position, 25.0)
		check("le héros est sur une route", not near.is_empty())
		var hold = rl.spawn("caravane", near)
		var m = hold.get_children().filter(func(t): return t.role == "merchant") if hold else []
		check("une caravane arrive (marchand et %d gardes)" % (hold.get_child_count() - 1 if hold else 0), m.size() == 1 and m[0].shop != null and hold.get_child_count() == 3)
		car_pos = m[0].global_position if m.size() == 1 else Vector3.ZERO
		start("car")
	if later("car", 3000):
		var hold: Node3D = rl.encounter.node
		var m = hold.get_children().filter(func(t): return t.role == "merchant")[0]
		check("la caravane chemine sur la route (%.1f m)" % m.global_position.distance_to(car_pos), m.global_position.distance_to(car_pos) > 2.0)
		p.global_position = m.global_position + Vector3(0, 0, 3)
		look_to(m.global_position + Vector3(0, 1, 0), 18, 1.4)
		start("car2")
	if later("car2", 600):
		shot("02_caravane.png")
		rl.encounter.node.queue_free(); rl.encounter = {}
		var hold = rl.spawn("patrouille", rl.nearest_road_point(p.global_position, 40.0))
		check("une patrouille (%d gardes)" % (hold.get_child_count() if hold else 0), hold and hold.get_child_count() == 3)
		hold.queue_free(); rl.encounter = {}
		var b = rl.spawn("bandits", rl.nearest_road_point(p.global_position, 40.0))
		var en = b.get_children().filter(func(e): return e.has_meta("bandit")) if b else []
		check("une embuscade de bandits (%d, dont leur chef)" % en.size(), en.size() >= 4 and en.any(func(e): return e.data.display_name == "Chef des bandits"))
		p.global_position = en[0].global_position + Vector3(0, 0, 6)
		look_to(en[0].global_position + Vector3(0, 1, 0), 20, 1.4)
		start("ban")
	if later("ban", 1500):
		shot("03_bandits.png")
		var away: Vector3 = p.global_position + Vector3(300, 0, 0) if p.global_position.x < w.world_size.x / 2 else p.global_position - Vector3(300, 0, 0)
		w.teleport(away)
		start("far")
	if later("far", 1500):
		check("loin de la route, la rencontre disparaît", rl.encounter.is_empty())
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	return false
