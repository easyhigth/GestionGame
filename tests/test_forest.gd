extends SceneTree
var f := 0
var p; var w; var items; var zs: Array = []; var idx := 0
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/fo_"

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

## Arbres d'un carré de 40 m autour d'une case : [nombre d'arbres, cases de terre, écart minimal entre troncs].
func measure(c: Vector2i) -> Array:
	var trees := []
	var land := 0
	for y in range(c.y - 20, c.y + 20):
		for x in range(c.x - 20, c.x + 20):
			var cell := Vector2i(x, y)
			if w._type(cell) != w.GRASS: continue
			land += 1
			if w._decor[w._idx(cell)] == w.D_OAK: trees.append(cell)
	var mind := 99.0
	var set := {}
	for t in trees: set[t] = true
	for t in trees:
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				if (dx != 0 or dy != 0) and set.has(t + Vector2i(dx, dy)):
					mind = minf(mind, Vector2(dx, dy).length())
	return [trees.size(), land, mind]

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p: p._invulnerable_left = 5.0
	if f == 8:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		get_first_node_in_group("raids").enabled = false
		get_first_node_in_group("weather").set_kind("clair")
		get_first_node_in_group("day_cycle").hour = 11.0
		for rid in ["foret", "jungle", "bois_enchante"]:
			var best = null
			var best_n := -1
			for z in w.zones:
				if not (z.type and z.type.id == rid): continue
				for oy in range(-48, 49, 24):
					for ox in range(-48, 49, 24):
						var c := Vector2i(z.site) + Vector2i(ox, oy)
						var m := measure(c)
						if m[1] > 1500 and m[0] > best_n:
							best_n = m[0]; best = {"site": Vector2(c), "name": z.name, "type": z.type}
			if best == null: continue
			var m := measure(Vector2i(best.site))
			# un tronc fait 0,7 m de large (rayon 0,35) et se décale d'au plus 0,2 m : il faut au moins 2 m entre deux centres
			check("%s « %s » : %d arbres sur %d cases (%.0f %%), écart minimal entre troncs %.2f m" % [rid, best.name, m[0], m[1], 100.0 * m[0] / m[1], m[2]],
				m[2] >= 2.0 and float(m[0]) / m[1] < 0.15)
			zs.append(best)
		start("go")
	if later("go", 300):
		var z = zs[idx]
		var c := Vector2i(z.site)
		w.load_area(w.cell_center(c))
		view(w.cell_center(c), 30, 38, 1.2)
		start("shot")
	if later("shot", 3000):
		shot("%02d_%s.png" % [idx + 1, zs[idx].type.id])
		# traversée : le héros marche 16 m tout droit à travers le bois (il glisse le long des troncs)
		set_meta("walk0", p.global_position)
		Input.action_press("move_up")
		start("walk")
	if later("walk", 5000):
		Input.action_release("move_up")
		var d: float = (p.global_position - get_meta("walk0")).length()
		check("on traverse la forêt %s à pied (%.1f m en 5 s)" % [zs[idx].type.id, d], d > 8.0)
		idx += 1
		if idx < zs.size():
			start("go")
		else:
			print("RÉSULTAT : ", "tout est bon" if ok else "échec")
			return true
	return false
