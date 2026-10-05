extends SceneTree
var f := 0
var p; var w; var items; var vn; var k; var dc; var bm; var bo
var ok := true
var s: Vector2i; var H := 0
var guard
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/r_"

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

func plan(cat: int, tool: int, a: Vector2i, b: Vector2i, layer: int) -> void:
	bm.cat = cat; bm.tool_index = tool; bm.layer = layer
	bm._selection_from(a, b)
	bm._commit_selection()

var game_ms := 0.0

## Attente en temps de jeu (le rendu logiciel ralentit le jeu par rapport au temps réel).
func later(key: String, ms: int) -> bool:
	if not has_meta(key) or has_meta(key + "_done"):
		return false
	if game_ms - float(get_meta(key)) < ms:
		return false
	set_meta(key + "_done", true)
	return true

## Habitants (hors garde) à moins de 4 m du feu de camp.
func near_fire() -> int:
	return villagers().filter(func(v): return v != guard and v.global_position.distance_to(w.hearth_center()) < 4.0).size()

func start(key: String) -> void:
	set_meta(key, game_ms)

func villagers() -> Array:
	return vn.members()

func view(pos: Vector3, yaw: float, pitch: float, zoom: float) -> void:
	p.global_position = pos
	p.cam_yaw = deg_to_rad(yaw); p.cam_pitch = deg_to_rad(pitch); p.camera_zoom = zoom
	p.snap_camera()

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p: p._invulnerable_left = 5.0
	# pas de monstres de la nuit : on teste la vie quotidienne, pas la défense
	if f > 10 and f % 10 == 0:
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
	if f == 10:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		vn = get_first_node_in_group("village_needs"); k = get_first_node_in_group("kingdom"); dc = get_first_node_in_group("day_cycle")
		bm = p.get_node("BuildMode"); bo = get_first_node_in_group("build_orders")
		get_first_node_in_group("raids").enabled = false
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		# une maison sans toit (pour voir les lits) à côté du village : 2 lits
		s = w.spawn_cell + Vector2i(-1, 9)
		H = roundi(w.terrain_height(s))
		var cells := []
		for x in range(-6, 7):
			for z in range(0, 10):
				w.set_terrain_height(s + Vector2i(x, z), float(H)); w.remove_decor(s + Vector2i(x, z)); cells.append(s + Vector2i(x, z))
		w.refresh_cells(cells)
		for id in [["bloc_planches", 80], ["lit", 2], ["coffre", 1], ["porte", 1], ["torche", 2]]:
			p.inventory.add(items.get_item(id[0]), id[1])
		bm.toggle(true)
		bo.instant = true
		plan(1, 0, s + Vector2i(-3, 2), s + Vector2i(3, 6), H)
		plan(4, 0, s + Vector2i(0, 2), s + Vector2i(0, 2), H)
		plan(2, 0, s + Vector2i(-2, 3), s + Vector2i(2, 5), H)
		bm.furniture_index = bm._furniture_items.find(items.get_item("lit")); plan(5, 0, s + Vector2i(-2, 5), s + Vector2i(-2, 5), H + 1)
		bm.furniture_index = bm._furniture_items.find(items.get_item("lit")); plan(5, 0, s + Vector2i(2, 5), s + Vector2i(2, 5), H + 1)
		bm.furniture_index = bm._furniture_items.find(items.get_item("coffre")); plan(5, 0, s + Vector2i(0, 4), s + Vector2i(0, 4), H + 1)
		bm.furniture_index = bm._furniture_items.find(items.get_item("torche")); plan(5, 0, s + Vector2i(-1, 1), s + Vector2i(-1, 1), H)
		bm.toggle(false)
		k.recompute()
		# plus d'habitants que de lits : les autres dormiront par terre
		while villagers().size() < 9:
			var v = w.villager_scene.instantiate()
			v.race = w.villager_races[randi() % w.villager_races.size()]
			w.get_node("Village").add_child(v)
			v.global_position = w.cell_center(w.spawn_cell) + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
		vn.food_stock = 3000.0
		# un garde (poste au camp d'entraînement, simulé)
		guard = villagers()[0]
		guard.work_room = {"type": load("res://data/rooms/caserne.tres"), "cells": {}, "floor": 0.0, "tier": 0}
		vn._update(1.0)
		var spots: Array = vn.bed_spots()
		var kinds := {}
		for sp in spots: kinds[sp[1]] = int(kinds.get(sp[1], 0)) + 1
		print("   pièces : ", k.typed_rooms().map(func(r): return r.type.display_name), " places : ", kinds)
		check("places pour dormir : 2 lits (maison), plus de cabanes toutes faites", kinds.get("lit", 0) == 2 and kinds.get("cabane", 0) == 0)
		var in_bed := villagers().filter(func(v): return v.bed_kind == "lit").size()
		var none := villagers().filter(func(v): return v.bed_kind == "").size()
		check("lits attribués : 2 dans la maison, %d sans lit" % none, in_bed == 2 and none == villagers().size() - 2)
		print("== repas (12 h)")
		dc.hour = 12.1
		start("a")
	# sur une machine lente (CI), les habitants marchent moins vite que l'horloge du test : on attend qu'ils arrivent
	# (avant 13 h, fin du repas)
	if has_meta("a") and not has_meta("a_done") and game_ms - float(get_meta("a")) >= 9000.0 \
			and (near_fire() >= villagers().size() - 3 or game_ms - float(get_meta("a")) >= 25000.0):
		set_meta("a_done", true)
		var acts := villagers().map(func(v): return v.activity)
		var near := near_fire()
		check("à midi, tout le monde mange (%s)" % str(acts.slice(0, 4)), acts.count("repas") == acts.size())
		check("autour du feu de camp (%d / %d)" % [near, villagers().size() - 1], near >= villagers().size() - 3)
		check("pas de production pendant le repas", villagers().all(func(v): return not v.is_at_work()))
		view(w.cell_center(w.spawn_cell) + Vector3(0, 0, 5), 0.0, 34.0, 1.0)
		start("a2")
	if later("a2", 400):
		shot("01_repas.png")
		print("== détente (19 h)")
		dc.hour = 19.0
		start("b")
	if later("b", 7000):
		check("le soir : détente", villagers().all(func(v): return v.activity == "détente"))
		var bubbles := villagers().filter(func(v): return v._bubble.visible).size()
		print("   bulles visibles : ", bubbles)
		shot("02_detente.png")
		print("== nuit (22 h)")
		guard.work_room = {"type": load("res://data/rooms/caserne.tres"), "cells": {}, "floor": 0.0, "tier": 0}
		dc.hour = 22.0
		start("c")
	if later("c", 12000):
		for v in villagers():
			print("   ", v.villager_name, " lit=", v.bed_kind, " dort=", v.is_sleeping(), " dist=", snappedf(Vector2(v.global_position.x - v.bed_spot.x, v.global_position.z - v.bed_spot.z).length() if v.bed_spot != Vector3.INF else -1.0, 0.1), " dy=", snappedf(v.global_position.y - v.bed_spot.y if v.bed_spot != Vector3.INF else 0.0, 0.01), " couché=", v.visual.is_downed(), " spot=", v._act_spot == v.bed_spot, " marche=", snappedf(v._act_walk, 0.1), " coincé=", snappedf(v._act_stuck, 0.1), " menace=", v._threat != null, " vivant=", v.is_alive(), " ordre=", v._order != null)
		var sleepers := villagers().filter(func(v): return v.is_sleeping())
		print("   endormis : ", sleepers.size(), " / ", villagers().size(), " activités ", villagers().map(func(v): return v.activity))
		check("la nuit, tous dorment sauf le garde (%d)" % sleepers.size(), sleepers.size() == villagers().size() - 1 and not guard.is_sleeping())
		check("le garde fait sa ronde", guard.activity == "ronde")
		var lit_ok := villagers().filter(func(v): return v.bed_kind == "lit" and v.is_sleeping() and v.visual.is_downed() and v.global_position.distance_to(v.bed_spot) < 0.3)
		var lit_n := villagers().filter(func(v): return v.bed_kind == "lit" and v != guard).size()
		check("dans la maison : couchés sur leur lit (%d / %d)" % [lit_ok.size(), lit_n], lit_ok.size() == lit_n and lit_n >= 1)
		var ground := villagers().filter(func(v): return v.bed_kind == "" and v.is_sleeping() and v.visual.is_downed())
		var no_bed := villagers().filter(func(v): return v.bed_kind == "" and v != guard).size()
		check("sans lit : par terre près du feu (%d)" % ground.size(), ground.size() == no_bed)
		dc.hour = 23.0
		view(w.cell_center(s + Vector2i(0, 4)) + Vector3(0, 0, -2.5), 180.0, 68.0, 0.75)
		start("c2")
	if later("c2", 500):
		shot("03_nuit_lits.png")
		view(w.cell_center(w.spawn_cell) + Vector3(0, 0, 5), 0.0, 38.0, 1.3)
		start("c3")
	if later("c3", 500):
		shot("04_nuit_village.png")
		print("== matin (7 h)")
		dc.hour = 7.0
		start("d0")
	if later("d0", 400):
		# beau temps (le lever du jour a pu tirer une nouvelle météo) : sous l'orage, ils s'abritent au lieu de travailler
		get_first_node_in_group("weather").set_kind("clair")
		start("d")
	if later("d", 1500):
		check("au matin : tout le monde est réveillé et visible", villagers().all(func(v): return not v.is_sleeping() and v.visual.visible and not v.visual.is_downed()))
		for v in villagers(): if v.activity != "travail": print("   pas au travail : ", v.villager_name, " ", v.activity, " meta story ", v.has_meta("story"))
		check("retour au travail", villagers().all(func(v): return v.activity == "travail"))
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	return false
