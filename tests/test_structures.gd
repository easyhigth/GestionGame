extends SceneTree
var f := 0
var p; var w; var items; var hud; var site; var broken_key
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/st_"

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

func gold() -> int:
	return p.inventory.count(items.get_item("piece_or"))


func view(at: Vector3, yaw: float, pitch: float, zoom: float) -> void:
	p.global_position = at
	p.cam_yaw = deg_to_rad(yaw); p.cam_pitch = deg_to_rad(pitch); p.camera_zoom = zoom; p.snap_camera()

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
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		print("== campement de départ")
		check("plus de cabanes ni de décors préfabriqués", w._village_props.is_empty())
		var furn := []
		for k in w.build.furniture:
			if w.build.furniture[k].col.distance_to(w.spawn_cell) < 14:
				furn.append(w.build.furniture[k].item.id)
		check("meubles posés au campement : %s" % str(furn), furn.has("etabli") and furn.has("ratelier") and furn.count("tonneau") == 2 and furn.has("coffre"))
		var bench: Vector3i
		for k in w.build.furniture:
			if w.build.furniture[k].item.id == "etabli": bench = k
		p.global_position = Vector3(bench.x + 1.5, w.terrain_height(Vector2i(bench.x, bench.z)), bench.z + 0.5)
		check("l'établi posé sert d'atelier", p.is_near_workbench())
		var vn = get_first_node_in_group("village_needs")
		check("pas de place dans une cabane (%d lits)" % vn.total_beds(), vn.total_beds() == 0)
		print("== constructions du monde")
		var houses: Array = w.structure_sites.filter(func(s): return s.kind == "house")
		var ruins: Array = w.structure_sites.filter(func(s): return s.kind == "ruin")
		check("maisons (%d) et ruines (%d) dans les régions" % [houses.size(), ruins.size()], houses.size() >= 10 and ruins.size() >= 5)
		var regions := {}
		for s in houses: regions[s.region] = true
		print("   régions : ", regions.keys())
		site = houses[0]
		var n: int = 0
		for x in 5:
			for z in 5:
				for y in range(-3, 12):
					var c: Vector2i = site.cell + Vector2i(x, z)
					if w.build.block_at(Vector3i(c.x, roundi(w.terrain_height(c)) + y, c.y)) != null:
						n += 1
		check("la maison est faite de blocs (%d)" % n, n > 40)
		var gates: Array = w.zones.filter(func(z): return (z.gate as Vector2i).x >= 0)
		var g: Vector2i = gates[0].gate
		var arch := 0
		for x in range(-2, 3):
			for y in range(-2, 8):
				if w.build.block_at(Vector3i(g.x + x, roundi(w.terrain_height(g)) + y, g.y)) != null: arch += 1
		check("arche de donjon en blocs (%d)" % arch, arch >= 10)
		var ob: Vector2i = w.zones[0].obelisk
		var pil := 0
		for c in [Vector2i(-2, -2), Vector2i(2, 2)]:
			for y in range(-2, 5):
				if w.build.block_at(Vector3i(ob.x + c.x, roundi(w.terrain_height(ob)) + y, ob.y + c.y)) != null: pil += 1
		check("piliers autour de l'obélisque (%d)" % pil, pil >= 2)
		var k = get_first_node_in_group("kingdom")
		k.recompute()
		check("les constructions du monde ne comptent pas comme pièces du royaume (%d)" % k.typed_rooms().size(), k.typed_rooms().size() == 0)
		var c0: Vector2i = site.cell + Vector2i(2, 6)
		w.load_area(w.cell_center(c0))
		view(Vector3(c0.x + 0.5, w.terrain_height(c0) + 0.1, c0.y + 0.5), 20, 35, 1.4)
		start("a")
	if later("a", 2500):
		shot("01_maison_%s.png" % site.region)
		# casser un mur bloc par bloc
		var wall := Vector3i.ZERO
		for y in range(-3, 6):
			var c: Vector2i = site.cell + Vector2i(1, 4)
			var key := Vector3i(c.x, roundi(w.terrain_height(c)) + y, c.y)
			if w.build.block_at(key) != null:
				wall = key
		broken_key = wall
		var it = w.build.block_at(wall)
		check("un bloc du mur : %s" % (it.display_name if it else "rien"), it != null)
		var before: int = w.get_node("Village").get_children().size()
		for i in 12:
			load("res://scripts/world/harvest.gd").hit_built(w, {"block": wall}, 1.0, p)
		check("cassé bloc par bloc", w.build.block_at(wall) == null)
		check("le bloc tombe à ramasser", w.get_node("Village").get_children().size() > before)
		root.get_node("SaveGame").save_game("3")
		root.get_node("SaveGame").load_game("3")
		start("b")
	if later("b", 2500):
		w = get_first_node_in_group("world"); p = get_first_node_in_group("player")
		check("rechargé : le bloc cassé l'est toujours", w.build.block_at(broken_key) == null)
		var c: Vector2i = site.cell + Vector2i(0, 0)
		var still := false
		for y in range(-3, 6):
			if w.build.block_at(Vector3i(c.x, roundi(w.terrain_height(c)) + y, c.y)) != null: still = true
		check("rechargé : le reste de la maison est là", still)
		# une ruine et une arche en image
		var g: Vector2i = w.zones.filter(func(z): return (z.gate as Vector2i).x >= 0)[0].gate
		w.load_area(w.cell_center(g))
		view(Vector3(g.x + 0.5, w.terrain_height(g) + 0.1, g.y + 3.5), 0, 30, 1.3)
		start("c")
	if later("c", 2500):
		shot("02_arche_donjon.png")
		var r = w.structure_sites.filter(func(s): return s.kind == "ruin")[0]
		var rc: Vector2i = r.cell + Vector2i(2, 5)
		w.load_area(w.cell_center(rc))
		view(Vector3(rc.x + 0.5, w.terrain_height(rc) + 0.1, rc.y + 0.5), 30, 35, 1.3)
		start("d")
	if later("d", 2500):
		shot("03_ruine_%s.png" % w.structure_sites.filter(func(s): return s.kind == "ruin")[0].region)
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	return false
