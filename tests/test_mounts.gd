extends SceneTree
var f := 0
var p; var w; var items; var fm; var vn; var k; var dc; var hud; var gd; var H
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/m_"
var mo
var horse
var boat
var isl := {}

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

func count(id: String) -> int:
	return p.inventory.count(items.get_item(id))

func later(key: String, ms: int) -> bool:
	if not has_meta(key) or has_meta(key + "_done"):
		return false
	if game_ms - float(get_meta(key)) < ms:
		return false
	set_meta(key + "_done", true)
	return true

func start(key: String) -> void:
	set_meta(key, game_ms)

func collect(r := 6.0) -> void:
	for n in w.get_node("Village").get_children():
		if n.has_method("take") and not n.is_taken() and n.global_position.distance_to(p.global_position) < r:
			p.try_pickup(n)

func craft(id: String) -> bool:
	for r in items.recipes:
		if r.result.id == id:
			var done: bool = r.craft(p.inventory, p.is_near_workbench(), p.nearby_stations())
			if done:
				p.crafted.emit(id)
			return done
	return false

## Une case de berge (herbe ou sable) à côté d'une eau profonde, près du village.
func find_shore() -> Array:
	var s: Vector2i = w.spawn_cell
	for r in range(4, 320, 2):
		for i in 48:
			var a := TAU * i / 48.0
			var c := s + Vector2i(roundi(cos(a) * r), roundi(sin(a) * r))
			var t: int = w.terrain_type(c)
			if t != 2 and t != 3:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var ok := true
				for k in range(1, 9):
					var n: Vector2i = c + d * k
					if w.terrain_type(n) != 1 and w.terrain_type(n) != 0:
						ok = false
						break
				if ok and w.water_surface - w.terrain_height(c + d * 8) >= 2.3:
					return [c, d]
	return []


func view(yaw, pitch, zoom) -> void:
	p.cam_yaw = deg_to_rad(yaw); p.cam_pitch = deg_to_rad(pitch); p.camera_zoom = zoom; p.snap_camera()

func move(dir: Vector3, n: int, dt := 0.05) -> void:
	for i in n:
		p.velocity = dir * 4.0 * mo.speed_mult()
		p.facing = dir
		p._move_on_ground(dt)
		mo._process(dt)

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p: p._invulnerable_left = 5.0
	if f > 10 and f % 10 == 0:
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
	if f == 10:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		dc = get_first_node_in_group("day_cycle"); hud = get_first_node_in_group("hud"); mo = get_first_node_in_group("mounts")
		get_first_node_in_group("raids").enabled = false
		get_first_node_in_group("quests")._offer_timer = 9999.0
		get_first_node_in_group("weather").set_kind("clair")
		dc.hour = 11.0
		print("== cheval")
		check("montures présentes", mo != null)
		horse = mo.spawn_horse(w.cell_center(w.spawn_cell) + Vector3(8, 0, 8))
		p.global_position = horse.global_position + Vector3(3, 0, 0)
		p.inventory.add(items.get_item("carotte"), 5)
		p.hand.selected = "carotte"
		start("a")
	if later("a", 700):
		check("carottes en main : le cheval suit", horse.following and not horse.tamed)
		p.global_position = horse.global_position + Vector3(1.2, 0, 0)
		for i in 3:
			mo.try_interact(p)
		check("3 carottes : apprivoisé (selle)", horse.tamed and count("carotte") == 2)
		p.hand.selected = ""
		mo.try_interact(p)
		check("E : à cheval", mo.is_riding() and p.is_mounted() and p.visual.position.y > 0.9)
		check("plus rapide à cheval (x%.1f)" % mo.speed_mult(), mo.speed_mult() > 1.5)
		var a: Vector3 = p.global_position
		move(Vector3(1, 0, 0), 20)
		print("   dbg cheval ", horse.global_position.distance_to(p.global_position), " parcouru ", p.global_position.distance_to(a))
		check("le cheval suit le héros", horse.global_position.distance_to(p.global_position) < 0.1 and p.global_position.distance_to(a) > 2.0)
		check("à cheval, pas d'eau", not p._can_swim())
		view(250, 22, 0.9)
		start("b")
	if later("b", 700):
		shot("01_cheval.png")
		mo.try_interact(p)
		check("E : on descend, le cheval reste", not mo.is_riding() and horse.global_position.distance_to(p.global_position) < 2.0 and p.visual.position.y == 0.0)
		print("== barque")
		var sh := find_shore()
		check("berge trouvée", not sh.is_empty())
		var c: Vector2i = sh[0]
		var d: Vector2i = sh[1]
		w.load_area(w.cell_center(c))
		p.global_position = w.cell_center(c)
		p.facing = Vector3(d.x, 0, d.y)
		p.inventory.add(items.get_item("bloc_planches"), 12); p.inventory.add(items.get_item("fiber"), 4)
		var pg: Vector3 = p.global_position
		p.global_position = w.cell_center(w.spawn_cell) + Vector3(-7.5, 0, 3.0)
		check("barque fabriquée (établi)", craft("barque"))
		p.global_position = pg
		p.hand.selected = "barque"
		p.hand.place()
		boat = mo.boats[mo.boats.size() - 1] if not mo.boats.is_empty() else null
		check("V face à l'eau : la barque est à l'eau", boat != null and count("barque") == 0)
		mo.try_interact(p)
		check("E : dans la barque", mo.is_sailing())
		move(Vector3(d.x, 0, d.y), 40)
		var cell: Vector2i = w.cell_at(p.global_position)
		print("   barque à ", cell, " type ", w.terrain_type(cell), " y ", p.global_position.y)
		check("elle avance sur l'eau (pas de nage)", w.terrain_type(cell) in [0, 1] and not p.swimming and absf(p.global_position.y - w.water_surface) < 0.1)
		view(200, 25, 1.1)
		set_meta("dir", Vector3(d.x, 0, d.y))
		start("c")
	if later("c", 700):
		shot("02_barque.png")
		move(-get_meta("dir"), 80)
		var cell: Vector2i = w.cell_at(p.global_position)
		check("elle ne va pas sur la terre", w.terrain_type(cell) in [0, 1])
		mo.try_interact(p)
		check("E près de la berge : on débarque", not mo.is_sailing() and w.terrain_type(w.cell_at(p.global_position)) not in [0, 1])
		print("== îles")
		var found := []
		for r in [3, 5, 7, 12, 20, 32]:
			found = w.islands_near(w.cell_center(w.spawn_cell), r)
			if not found.is_empty(): break
		check("des îles au large (%d)" % found.size(), not found.is_empty())
		if not found.is_empty():
			isl = found[0]
			var ic: Vector2i = w.cell_at(isl.pos)
			w.load_area(isl.pos)
			print("   île ", isl.id, " type centre ", w.terrain_type(ic), " hauteur ", w.terrain_height(ic), " eau autour ", w.terrain_type(ic + Vector2i(12, 0)))
			check("l'île est de la terre ferme entourée d'eau", w.terrain_type(ic) in [2, 3] and w.terrain_type(ic + Vector2i(12, 0)) in [0, 1])
			p.global_position = isl.pos + Vector3(1.2, 0, 0.5)
			p.global_position.y = w.ground_height_at(p.global_position + Vector3(0, 5, 0))
			mo._update_islands()
			check("coffre sur l'île", mo._island_nodes.has(isl.id))
			view(210, 30, 1.3)
		start("d")
	if later("d", 1000):
		shot("03_ile.png")
		if not isl.is_empty():
			var pr := count("perle")
			var cn = mo._island_nodes.get(isl.id)
			print("   dbg coffre ", cn.global_position if cn else null, " joueur ", p.global_position, " monté ", mo.mount, " res ", mo.try_interact(p), " ouvert ", mo.opened)
			for n in w.get_children() + w.get_node("Village").get_children():
				if n.has_method("is_taken") and n.global_position.distance_to(p.global_position) < 4.0:
					p.try_pickup(n)
			check("trésor de l'île ouvert (perles)", mo.opened.has(isl.id) and count("perle") > pr)
		root.get_node("SaveGame").save_game("3")
		root.get_node("SaveGame").load_game("3")
		start("e")
	if later("e", 2200):
		mo = get_first_node_in_group("mounts")
		check("cheval apprivoisé rechargé", mo.horses().filter(func(h): return h.tamed).size() == 1)
		check("barque rechargée", mo.boats.size() == 1)
		check("îles ouvertes rechargées", isl.is_empty() or mo.opened.has(isl.id))
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	return false
