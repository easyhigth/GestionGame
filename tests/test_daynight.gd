extends SceneTree
var f := 0
var p; var w; var items; var dc; var gd; var bm; var bo
var s: Vector2i; var H := 0
var ok := true

func _initialize():
	var h = load("res://scripts/hero/hero_profile.gd").new()
	h.hero_name = "Test"
	h.race = load("res://data/races/homme_bete.tres")
	h.hero_class = load("res://data/classes/guerrier.tres")
	h.job = load("res://data/jobs/chasseur.tres")
	h.skill = load("res://data/skills/vorace.tres")
	root.get_node("GameState").hero = h
	root.get_node("GameState").world_seed = int(OS.get_environment("TEST_SEED")) if OS.get_environment("TEST_SEED") != "" else 4242
	change_scene_to_file("res://scenes/main.tscn")

func set_done(k: String) -> bool:
	set_meta(k + "_done", true)
	return true

func check(name: String, cond: bool) -> void:
	print(("  OK  " if cond else "  ÉCHEC  ") + name)
	if not cond:
		ok = false

func count(id: String) -> int:
	return p.inventory.count(items.get_item(id))

func find_decor(kind: int) -> Vector2i:
	var c0: Vector2i = w.spawn_cell
	for r in range(5, 60):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c: Vector2i = c0 + Vector2i(dx, dz)
				if w.decor_at(c) == kind and w.decor_at(c - Vector2i(1, 0)) == 0 and w.decor_at(c - Vector2i(2, 0)) == 0:
					return c
	return Vector2i(-1, -1)

func break_decor(kind: int) -> void:
	var c := find_decor(kind)
	var cc: Vector3 = w.cell_center(c)
	p.global_position = Vector3(cc.x - 1.3, w.ground_height_at(cc - Vector3(1.3, 0, 0)), cc.z)
	p.facing = Vector3(1, 0, 0)
	var n := 0
	while w.decor_at(c) != 0 and n < 20:
		p._harvest_swing({"dmg": 1.0})
		n += 1

func craft(id: String) -> bool:
	for r in items.recipes:
		if r.result.id == id:
			var done: bool = r.craft(p.inventory, true, ["etabli"])
			if done:
				p.crafted.emit(id)
			return done
	return false

func plan(cat: int, tool: int, a: Vector2i, b: Vector2i, layer: int) -> void:
	bm.cat = cat; bm.tool_index = tool; bm.layer = layer
	bm._selection_from(a, b)
	bm._commit_selection()

func _process(_d) -> bool:
	f += 1
	if p: p._invulnerable_left = 5.0
	if f == 8:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		dc = get_first_node_in_group("day_cycle"); gd = get_first_node_in_group("guide")
		bm = p.get_node("BuildMode"); bo = get_first_node_in_group("build_orders")
		get_first_node_in_group("raids").enabled = false
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		print("== départ")
		check("cycle présent, 8 h, jour 1", dc != null and absf(dc.hour - 8.0) < 0.2 and dc.day == 1)
		check("guide à l'étape 1", gd != null and gd.step == 0)
		print("   horloge : ", dc.clock_text(), " · soleil ", dc._sun.light_energy)
		print("== guide")
		for i in 3: break_decor(1)
		check("3 arbres -> étape 2", gd.step == 1)
		for i in 2: break_decor(4)
		check("2 rochers -> étape 3", gd.step == 2)
		p.inventory.add(items.get_item("wood"), 10)
		p.inventory.add(items.get_item("stone"), 6)
		check("pioche en bois fabriquée", craft("pioche_bois"))
		check("-> étape 4", gd.step == 3)
		check("hache en pierre fabriquée", craft("hache_pierre"))
		check("planches fabriquées", craft("bloc_planches"))
		check("-> étape 5 (abri)", gd.step == 4)
		# abri : pièce fermée + porte + lit
		s = w.spawn_cell + Vector2i(-1, 9)
		H = roundi(w.terrain_height(s))
		var cells := []
		for x in range(-6, 7):
			for z in range(0, 10):
				w.set_terrain_height(s + Vector2i(x, z), float(H)); cells.append(s + Vector2i(x, z))
		w.refresh_cells(cells)
		p.inventory.add(items.get_item("bloc_planches"), 60)
		p.inventory.add(items.get_item("bloc_chaume"), 30)
		bm.toggle(true)
		bo.instant = true
		plan(1, 0, s + Vector2i(-2, 2), s + Vector2i(2, 6), H)
		plan(4, 0, s + Vector2i(0, 2), s + Vector2i(0, 2), H)
		plan(2, 0, s + Vector2i(-1, 3), s + Vector2i(1, 5), H)
		bm.furniture_index = bm._furniture_items.find(items.get_item("lit")); plan(5, 0, s + Vector2i(-1, 5), s + Vector2i(-1, 5), H + 1)
		plan(3, 1, s + Vector2i(-2, 2), s + Vector2i(2, 6), H + 3)
		bm.toggle(false)
		get_first_node_in_group("kingdom").recompute()
		set_meta("t", Time.get_ticks_msec())
	if has_meta("t") and Time.get_ticks_msec() - int(get_meta("t")) > 1500 and not has_meta("t_done") and set_done("t"):
		for r in get_first_node_in_group("kingdom").rooms:
			print("   pièce: fermée ", r.enclosed, " portes ", r.doors, " meubles ", r.counts, " cases ", r.cells.size(), " type ", r.type.display_name if r.type else "-")
		print("   meubles posés: ", w.build.furniture.values().map(func(x): return x.item.id), " plans restants ", bo.orders.size())
		gd._check_state()
		check("abri reconnu -> étape 6 (torche)", gd.step == 5)
		bm.toggle(true)
		bm.furniture_index = bm._furniture_items.find(items.get_item("torche")); plan(5, 0, s + Vector2i(1, 4), s + Vector2i(1, 4), H + 1)
		bm.toggle(false)
		set_meta("t2", Time.get_ticks_msec())
	if has_meta("t2") and Time.get_ticks_msec() - int(get_meta("t2")) > 1500 and not has_meta("t2_done") and set_done("t2"):
		gd._check_state()
		print("   torche posée : ", w.build.furniture.values().map(func(x): return x.item.id))
		check("torche posée -> étape 7 (repas)", gd.step == 6)
		p.inventory.add(items.get_item("viande_cuite"), 1)
		p.hunger = 40.0
		p.eat()
		check("repas cuit mangé -> étape 8 (nuit)", gd.step == 7)
		print("== nuit")
		var noon_bg: Color = dc._env.background_color
		dc.hour = 20.05
		set_meta("bg", noon_bg)
		set_meta("t3", Time.get_ticks_msec())
	if has_meta("t3") and Time.get_ticks_msec() - int(get_meta("t3")) > 800 and not has_meta("t3_done") and set_done("t3"):
		check("la nuit est tombée", dc.is_night())
		var bg: Color = dc._env.background_color
		check("ciel plus sombre la nuit", bg.v < (get_meta("bg") as Color).v * 0.5)
		print("   horloge : ", dc.clock_text(), " · lune ", snappedf(dc._sun.light_energy, 0.01), " · ciel ", bg)
		# le héros loin du village et des lumières
		var far: Vector2i = w.spawn_cell + Vector2i(40, -30)
		w.load_area(w.cell_center(far))
		p.global_position = w.cell_center(far)
		for i in 10:
			dc._spawn_timer = 0.0
			dc._night_spawns(0.1)
		var mons: Array = dc.night_monsters()
		check("monstres de nuit apparus (%d, max %d)" % [mons.size(), dc.max_monsters()], mons.size() > 0 and mons.size() <= dc.max_monsters())
		var min_d := 999.0
		for e in mons:
			min_d = minf(min_d, e.global_position.distance_to(p.global_position))
		check("apparus à plus de 14 m (%.1f)" % min_d, min_d > 14.0)
		check("pas d'apparition près du feu de camp", dc.near_light(w.cell_center(w.spawn_cell) + Vector3(3, 0, 0)))
		check("dormir refusé avec des monstres tout près", true if mons.is_empty() else (func():
			mons[0].global_position = p.global_position + Vector3(2, 0, 0)
			return dc.sleep().begins_with("Impossible")).call())
		for e in mons: e.queue_free()
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		set_meta("t4", Time.get_ticks_msec())
	if has_meta("t4") and Time.get_ticks_msec() - int(get_meta("t4")) > 100 and not has_meta("t4_done") and set_done("t4"):
		# retour au lit
		var bed: Vector3 = w.cell_center(s + Vector2i(-1, 4))
		p.global_position = Vector3(bed.x, H, bed.z)
		p.health.current = 10
		var ev := InputEventAction.new(); ev.action = "interact"; ev.pressed = true
		p._unhandled_input(ev)
		set_meta("t5", Time.get_ticks_msec())
	if has_meta("t5") and Time.get_ticks_msec() - int(get_meta("t5")) > 3000 and not has_meta("t5_done") and set_done("t5"):
		check("réveil le matin (%.2f h), jour 2" % dc.hour, not dc.is_night() and dc.day == 2)
		check("vie rendue", p.health.current == p.health.max_health)
		check("chapitre 1 fini -> chapitre 2 (âge du fer)", gd.step == 8)
		var sg = root.get_node("SaveGame")
		dc.hour = 15.5
		sg.save_game("3")
		dc.hour = 3.0
		sg.load_game("3")
		set_meta("t6", Time.get_ticks_msec())
	if has_meta("t6") and Time.get_ticks_msec() - int(get_meta("t6")) > 1500 and not has_meta("t6_done") and set_done("t6"):
		dc = get_first_node_in_group("day_cycle"); gd = get_first_node_in_group("guide")
		check("heure et jour rechargés (%.2f, jour %d)" % [dc.hour, dc.day], absf(dc.hour - 15.5) < 0.3 and dc.day == 2)
		check("guide rechargé au chapitre 2", gd.step == 8 and gd.visible)
		print("RÉSULTAT : ", "tout est bon" if ok else "des vérifications ont échoué")
		return true
	OS.delay_msec(5)
	if f > 20000:
		print("délai dépassé")
		return true
	return false
