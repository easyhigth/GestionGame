extends SceneTree
var f := 0
var p; var w; var items; var con; var dc; var idx := 0
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/vi_"

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
	if has_meta(key + "_done"): remove_meta(key + "_done")

func gold() -> int:
	return p.inventory.count(items.get_item("piece_or"))

## Vues de référence pour juger le rendu (mêmes cadrages à chaque fois).
var views := []

func look(at: Vector3, yaw: float, pitch: float, zoom: float) -> void:
	p.global_position = at
	p.global_position.y = w.support_height(at, w.terrain_height(w.cell_at(at)) + 0.3)
	p.cam_yaw = deg_to_rad(yaw); p.cam_pitch = deg_to_rad(pitch); p.camera_zoom = zoom; p.snap_camera()

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p: p._invulnerable_left = 5.0
	if f == 8:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		con = get_first_node_in_group("command_console"); dc = get_first_node_in_group("day_cycle")
		get_first_node_in_group("raids").enabled = false
		get_first_node_in_group("weather").set_kind("clair")
		var sp: Vector3 = w.cell_center(w.spawn_cell)
		# une forêt dense et une côte proches du village
		var forest: Vector3 = sp
		var coast: Vector3 = sp
		for r in range(20, 400, 6):
			for a in 24:
				var c: Vector2i = w.spawn_cell + Vector2i(roundi(cos(TAU * a / 24.0) * r), roundi(sin(TAU * a / 24.0) * r))
				if forest == sp and w.decor_at(c) == w.D_OAK and w.decor_at(c + Vector2i(2, 1)) == w.D_OAK and w.decor_at(c + Vector2i(-2, 1)) == w.D_OAK:
					forest = w.cell_center(c + Vector2i(1, 0))
				if coast == sp and w.terrain_type(c) == w.SAND and w.terrain_type(c + Vector2i(4, 0)) in [w.WATER, w.DEEP]:
					coast = w.cell_center(c)
		var minas = w.cities.filter(func(c): return c.nation == "cendres")[0]
		var hr = w.cities.filter(func(c): return c.nation == "givre")[0]
		views = [
			["01_village", sp + Vector3(2, 0, 6), 25.0, 30.0, 1.4, 10.5],
			["02_foret", forest, 40.0, 26.0, 1.2, 10.5],
			["03_cote", coast, 270.0, 22.0, 1.5, 15.0],
			["04_capitale", Vector3(hr.center.x + 0.5, 0, hr.center.y + hr.radius - 8), 0.0, 28.0, 1.8, 11.0],
			["05_minas", Vector3(minas.center.x + 0.5, 0, minas.center.y - minas.radius - 10), 180.0, 20.0, 1.8, 9.5],
			["06_village_nuit", sp + Vector3(2, 0, 6), 25.0, 30.0, 1.4, 21.5],
			["07_crepuscule", coast, 270.0, 18.0, 1.6, 18.6],
		]
		start("go")
	if later("go", 300):
		var v: Array = views[idx]
		dc.hour = float(v[5])
		w.load_area(v[1])
		look(v[1], v[2], v[3], v[4])
		start("shot")
	if later("shot", 3500):
		shot("%s.png" % views[idx][0])
		idx += 1
		if idx < views.size():
			start("go")
		else:
			print("RÉSULTAT : tout est bon")
			return true
	return false
