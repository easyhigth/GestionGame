extends SceneTree
var f := 0
var p; var w; var items; var hud; var t0 := 0; var peak := Vector2i.ZERO
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/wo_"

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
	t0 = Time.get_ticks_msec()
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

func gold() -> int:
	return p.inventory.count(items.get_item("piece_or"))


func view(at: Vector3, yaw: float, pitch: float, zoom: float) -> void:
	p.global_position = at
	p.cam_yaw = deg_to_rad(yaw); p.cam_pitch = deg_to_rad(pitch); p.camera_zoom = zoom; p.snap_camera()

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p: p._invulnerable_left = 5.0
	if f == 3:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world")
		var ms := Time.get_ticks_msec() - t0
		print("   génération + chargement : %d ms" % ms)
		check("monde immense : %d × %d m, %d zones" % [w.world_size.x, w.world_size.y, w.zones.size()], w.world_size.x >= 1500 and w.zones.size() >= 100)
		check("créé en moins de 20 s (%d ms)" % ms, ms < 20000)
		get_first_node_in_group("raids").enabled = false
		get_first_node_in_group("weather").set_kind("clair")
		get_first_node_in_group("day_cycle").hour = 10.0
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		# le plus haut sommet d'une région de montagne
		var best := -INF
		for z in w.zones:
			if z.type == null or z.type.id != "montagnes": continue
			var s: Vector2i = Vector2i(z.site)
			for dy in range(-60, 61, 3):
				for dx in range(-60, 61, 3):
					var c := s + Vector2i(dx, dy)
					if c.x < 0 or c.y < 0 or c.x >= w.world_size.x or c.y >= w.world_size.y: continue
					var h: float = w.terrain_height(c)
					if h > best:
						best = h; peak = c
		print("   plus haut sommet : %.1f m en %s" % [best, peak])
		check("de très hautes montagnes (%.1f m)" % best, best >= 15.0)
		var c := peak + Vector2i(-26, 30)
		w.load_area(w.cell_center(c))
		w.load_area(w.cell_center(peak))
		view(Vector3(c.x + 0.5, w.terrain_height(c) + 0.1, c.y + 0.5), 215, 18, 3.2)
		start("a")
	if later("a", 3500):
		shot("01_montagnes.png")
		view(w.cell_center(peak) + Vector3(0, 0.2, 0), 30, 35, 2.4)
		start("b")
	if later("b", 3000):
		shot("02_sommet.png")
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	return false
