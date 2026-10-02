extends SceneTree
var f := 0
var p; var w; var items; var fm; var vn; var k; var dc; var hud; var gd; var H
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/l_"
var ls
var feeder: Vector3
var pen: Vector2i
var chick
var produced := 0

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


func find_pen() -> Vector2i:
	var s: Vector2i = w.spawn_cell
	for r in range(9, 40):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r: continue
				var c: Vector2i = s + Vector2i(dx, dz)
				var good := true
				for z in range(-4, 5):
					for x in range(-4, 5):
						var n := c + Vector2i(x, z)
						if w.terrain_type(n) != 3 or w.decor_at(n) in [1, 2, 4, 7, 8] or absf(w.terrain_height(n) - w.terrain_height(c)) > 0.6 								or w.village_prop_at(n, w.terrain_height(n)) != null or fm.plots.has(n):
							good = false; break
					if not good: break
				if good: return c
	return Vector2i(-1, -1)

func view(yaw, pitch, zoom) -> void:
	p.cam_yaw = deg_to_rad(yaw); p.cam_pitch = deg_to_rad(pitch); p.camera_zoom = zoom; p.snap_camera()

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p: p._invulnerable_left = 5.0
	if f == 10:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		vn = get_first_node_in_group("village_needs"); k = get_first_node_in_group("kingdom")
		dc = get_first_node_in_group("day_cycle"); hud = get_first_node_in_group("hud"); fm = get_first_node_in_group("farming")
		gd = get_first_node_in_group("guide"); ls = get_first_node_in_group("livestock")
		get_first_node_in_group("raids").enabled = false
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		get_first_node_in_group("quests")._offer_timer = 9999.0
		get_first_node_in_group("weather").set_kind("clair")
		dc.hour = 10.0
		ls.produced.connect(func(_id): produced += 1)
		print("== départ")
		var wild: Array = ls.animals()
		check("des poules sauvages près du village (%d)" % wild.size(), wild.size() >= 3 and wild.all(func(a): return a.species == "poule" and not a.domestic))
		chick = wild[0]
		print("== attirer")
		p.inventory.add(items.get_item("graines_ble"), 10)
		p.inventory.add(items.get_item("ble"), 10)
		check("le blé se choisit avec C (nourriture des bêtes)", p.hand.choices().any(func(it): return it.id == "ble"))
		p.global_position = chick.global_position + Vector3(4, 0, 0)
		p.hand.selected = "graines_ble"
		start("a")
	if later("a", 700):
		check("graines de blé en main : la poule suit le héros", chick.following)
		p.hand.selected = "ble"
		start("a2")
	if later("a2", 500):
		check("blé en main : la poule ne suit plus (elle veut des graines)", not chick.following)
		print("== enclos")
		pen = find_pen()
		print("   enclos à ", pen)
		var base: float = w.terrain_height(pen)
		check("mangeoire posée", w.build.place_furniture(pen, base, items.get_item("mangeoire"), 0))
		feeder = w.cell_center(pen)
		# barrières autour (un carré de 11 x 11 sans porte)
		for i in range(-4, 5):
			for c in [pen + Vector2i(i, -4), pen + Vector2i(i, 4), pen + Vector2i(-4, i), pen + Vector2i(4, i)]:
				w.build.place_furniture(c, w.terrain_height(c), items.get_item("barriere"), 0 if absi(c.y - pen.y) == 4 else 1)
		check("une barrière bloque le passage", w.build.body_blocked(pen + Vector2i(0, 4), w.terrain_height(pen + Vector2i(0, 4))))
		p.hand.selected = "graines_ble"
		p.global_position = feeder + Vector3(1.5, 0, 1.5)
		chick.global_position = feeder + Vector3(2.5, 0, 0)
		chick.following = true
		ls._tame_check()
		check("menée à la mangeoire : la poule devient domestique", chick.domestic and not chick.following)
		# un mouton et une vache
		for sp in ["mouton", "vache", "poule", "mouton"]:
			var a = ls.spawn(sp, feeder + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)))
			a.following = true
		ls._tame_check()
		check("mouton, vache et poule de plus apprivoisés (%d bêtes)" % ls.domestic().size(), ls.domestic().size() == 5)
		p.hand.selected = ""
		start("b")
	if later("b", 8000):
		var far := 0.0
		for a in ls.domestic():
			far = maxf(far, Vector2(a.global_position.x - a.home.x, a.global_position.z - a.home.z).length())
		check("les bêtes restent dans l'enclos (%.1f m au plus)" % far, far < 6.0)
		print("== produits")
		vn.food_stock = 100.0
		var cow = ls.domestic().filter(func(a): return a.species == "vache")[0]
		cow.product_timer = 999.0
		var n0: int = produced
		ls._produce(0.1)
		check("vache nourrie : du lait au sol, réserve -5 (%.0f)" % vn.food_stock, produced == n0 + 1 and absf(vn.food_stock - 95.0) < 0.1 and ls._on_ground(cow.global_position, "lait") == 1)
		vn.food_stock = 0.0
		chick.product_timer = 999.0
		ls._produce(0.1)
		check("réserve vide : la poule a faim et ne pond pas", chick.hungry and produced == n0 + 1)
		vn.food_stock = 100.0
		# fermier de la grange (pièce simulée)
		var gt = load("res://data/rooms/grange.tres")
		var room := {"type": gt, "cells": {w.spawn_cell + Vector2i(40, 40): true}, "floor": -30.0, "enclosed": true, "doors": 1, "counts": {}, "tier": 0, "missing": {}}
		k.rooms.append(room)
		var v = vn.members()[0]
		v.work_room = room
		v._at_work = true
		v.set_physics_process(false)
		var sheep = ls.domestic().filter(func(a): return a.species == "mouton")[0]
		sheep.product_timer = 999.0
		var wool0 := count("laine")
		ls._produce(0.1)
		check("fermier à la grange : la laine va dans le sac", count("laine") == wool0 + 1)
		v.set_physics_process(true)
		v.work_room = null
		k.rooms.erase(room)
		print("   ", ls.summary_text())
		print("== petits")
		var hens0: int = ls.count("poule")
		vn.food_stock = 200.0
		ls._on_day(2)
		check("nouveau jour : un petit de chaque espèce en couple", ls.count("poule") == hens0 + 1 and ls.count("mouton") == 3)
		var babies: Array = ls.domestic().filter(func(a): return a.is_baby())
		check("les petits sont plus petits (%d)" % babies.size(), babies.size() == 2 and babies[0].visual.scale.x < 0.7)
		ls._on_day(3)
		check("le lendemain, ils ont grandi", babies.all(func(a): return not a.is_baby()) and ls.count("poule") <= 6)
		print("== cuisine et manteau")
		p.global_position = w.cell_center(w.spawn_cell) + Vector3(1.5, 0, 1.5)
		p.inventory.add(items.get_item("oeuf"), 4); p.inventory.add(items.get_item("lait"), 3); p.inventory.add(items.get_item("laine"), 4); p.inventory.add(items.get_item("leather"), 1)
		p.inventory.add(items.get_item("ble"), 2)
		check("omelette, fromage, gâteau (près du feu)", craft("omelette") and craft("fromage") and craft("gateau"))
		p.global_position = w.cell_center(w.spawn_cell) + Vector3(-7.5, 0, 3.0)
		check("manteau de laine (établi)", craft("manteau_laine"))
		p.equipment.equip(items.get_item("manteau_laine"))
		check("le manteau tient chaud", get_first_node_in_group("weather").is_warm())
		p.inventory.add(items.get_item("wood"), 2)
		check("barrières : 2 bois -> 3", craft("barriere"))
		print("== sauvages")
		for a in ls.animals().filter(func(a): return not a.domestic): a.queue_free()
		start("c")
	if later("c", 300):
		var tries := 0
		while ls.animals().filter(func(a): return not a.domestic).is_empty() and tries < 40:
			ls._wild_spawns(); tries += 1
		var wild: Array = ls.animals().filter(func(a): return not a.domestic)
		check("des bêtes sauvages apparaissent dans les prés (%d)" % wild.size(), not wild.is_empty())
		print("== guide")
		gd.step = 29; gd.progress = 0; gd._refresh()
		gd._check_state()
		check("guide : mangeoire posée, bête apprivoisée -> produits", gd.current_id() == "produits")
		for i in 3: ls.produced.emit("oeuf")
		check("3 produits : chapitre fini", gd.step >= 26)
		# captures
		var lure = ls.spawn("poule", feeder + Vector3(10, 0, 8))
		p.global_position = feeder + Vector3(0, 0, 6.5)
		view(0, 32, 1.1)
		start("d")
	if later("d", 1500):
		shot("01_enclos.png")
		hud.kingdom_panel.open()
		start("e")
	if later("e", 400):
		shot("02_royaume.png")
		hud.kingdom_panel.close()
		set_meta("n", ls.domestic().size())
		root.get_node("SaveGame").save_game("3")
		root.get_node("SaveGame").load_game("3")
		start("f")
	if later("f", 2000):
		ls = get_first_node_in_group("livestock")
		var sp := {}
		for a in ls.domestic(): sp[a.species] = int(sp.get(a.species, 0)) + 1
		check("bêtes rechargées (%d, %s)" % [ls.domestic().size(), sp], ls.domestic().size() == int(get_meta("n")))
		check("pas de nouvelles poules sauvages de départ au chargement", ls.animals().filter(func(a): return not a.domestic and a.global_position.distance_to(get_first_node_in_group("world").cell_center(get_first_node_in_group("world").spawn_cell)) < 25.0).size() <= 3)
		# capture : une poule qui suit le héros
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world")
		var c = ls.spawn("poule", p.global_position + Vector3(3, 0, 0))
		var c2 = ls.spawn("poule", p.global_position + Vector3(3.5, 0, 1))
		p.inventory.add(items.get_item("graines_ble"), 5)
		p.hand.selected = "graines_ble"
		p.hand.selection_changed.emit()
		view(200, 25, 0.8)
		start("g")
	if later("g", 1500):
		shot("03_attirer.png")
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	return false
