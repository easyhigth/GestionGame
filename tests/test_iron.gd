extends SceneTree
var f := 0
var p; var w; var items; var gd; var hb
var ok := true
var iron := Vector2i(-1, -1)
var gold := Vector2i(-1, -1)
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/i_"

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

func collect() -> void:
	for n in w.get_node("Village").get_children():
		if n.has_method("take") and not n.is_taken() and n.global_position.distance_to(p.global_position) < 6.0:
			p.try_pickup(n)

## Filon le plus proche du village, avec une case libre devant (côté -x).
func find_vein(kind: int) -> Vector2i:
	var s: Vector2i = w.spawn_cell
	for r in range(3, 300):
		for dz in range(-r, r + 1):
			for dx in [-r, r]:
				for c in [s + Vector2i(dx, dz), s + Vector2i(dz, dx)]:
					if c.x < 3 or c.y < 3 or c.x > 636 or c.y > 636:
						continue
					if w.decor_at(c) == kind and w.decor_at(c - Vector2i(1, 0)) == 0 and w.decor_at(c - Vector2i(2, 0)) == 0:
						return c
	return Vector2i(-1, -1)

func stand_before(cell: Vector2i) -> void:
	w.load_area(w.cell_center(cell))
	var c: Vector3 = w.cell_center(cell)
	p.global_position = Vector3(c.x - 1.3, w.ground_height_at(c - Vector3(1.3, 0, 0) + Vector3(0, 3, 0)), c.z)
	p.facing = Vector3(1, 0, 0)
	p.cam_yaw = deg_to_rad(215.0); p.cam_pitch = deg_to_rad(26.0); p.camera_zoom = 0.6
	p.snap_camera()

func mine(cell: Vector2i, n: int) -> int:
	var hits := 0
	while w.decor_at(cell) != 0 and hits < n:
		p.facing = Vector3(1, 0, 0)
		p._harvest_swing({"dmg": 1.0})
		hits += 1
	return hits

func craft(id: String) -> bool:
	for r in items.recipes:
		if r.result.id == id:
			var done: bool = r.craft(p.inventory, p.is_near_workbench(), p.nearby_stations())
			if done:
				p.crafted.emit(id)
			return done
	return false

func _process(_d) -> bool:
	f += 1
	if p: p._invulnerable_left = 5.0
	if f == 8:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		gd = get_first_node_in_group("guide"); hb = p.hand
		get_first_node_in_group("raids").enabled = false
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		gd.import_state({"step": 8, "progress": 0, "v": 2})
		iron = find_vein(7)
		gold = find_vein(8)
		print("filons : fer ", iron - w.spawn_cell, " or ", gold - w.spawn_cell)
		check("des filons de fer et d'or existent", iron.x >= 0 and gold.x >= 0)
		stand_before(iron)
		set_meta("t", Time.get_ticks_msec())
	if has_meta("t") and not has_meta("t_done") and Time.get_ticks_msec() - int(get_meta("t")) > 600:
		set_meta("t_done", true)
		shot("01_filon_fer.png")
		print("== fer")
		check("sans pioche : le filon ne s'abîme pas", mine(iron, 3) == 3 and w.decor_at(iron) == 7)
		p.inventory.add(items.get_item("pioche_bois"), 1)
		var ore := count("iron_ore")
		var hits := mine(iron, 20)
		collect()
		check("pioche en bois : filon miné en %d coups, +%d minerai de fer" % [hits, count("iron_ore") - ore], hits == 4 and count("iron_ore") - ore >= 2)
		check("guide : filon 1/2", gd.step == 8 and gd.progress == 1)
		# second filon
		var iron2 := find_vein(7)
		stand_before(iron2)
		mine(iron2, 20)
		check("guide : 2 filons -> four", gd.step == 9)
		print("== or")
		p.inventory.add(items.get_item("pioche_pierre"), 1)
		stand_before(gold)
		check("pioche en pierre : l'or résiste", mine(gold, 3) == 3 and w.decor_at(gold) == 8)
		# four et enclume près de l'établi du village
		print("== forge")
		# l'établi du campement est un meuble posé (grille de construction)
		var bench_pos := Vector3.ZERO
		for fk in w.build.furniture:
			if w.build.furniture[fk].item.id == "etabli":
				bench_pos = Vector3(fk.x + 0.5, w.build.furniture[fk].base, fk.z + 0.5)
		p.global_position = bench_pos + Vector3(0, 0, 2.2)
		p.global_position.y = w.ground_height_at(p.global_position + Vector3(0, 2, 0))
		p.facing = Vector3(0, 0, 1)
		p.inventory.add(items.get_item("stone"), 10)
		p.inventory.add(items.get_item("bloc_terre"), 4)
		p.inventory.add(items.get_item("iron_ore"), 16)
		p.inventory.add(items.get_item("wood"), 10)
		check("four fabriqué près de l'établi", craft("four"))
		check("lingot impossible sans four", not craft("iron_ingot"))
		for i in 12:
			if hb.selected == "four": break
			hb.cycle(1)
		hb._target = {}
		var spot: Dictionary = hb.find_spot(items.get_item("four"))
		print("   case du four : ", spot)
		check("four posé à la main", hb.place())
		set_meta("t2", Time.get_ticks_msec())
	if has_meta("t2") and not has_meta("t2_done") and Time.get_ticks_msec() - int(get_meta("t2")) > 1300:
		set_meta("t2_done", true)
		print("   guide: étape ", gd.step, " (", gd.current_id(), ") timer ", gd._check_timer, " hide ", gd._hide_timer, " meubles ", get_first_node_in_group("build_grid").furniture.values().map(func(x): return x.item.id))
		gd._check_state()
		check("guide : four posé -> lingots", gd.step == 10)
		var n := 0
		for i in 6:
			n += 1 if craft("iron_ingot") else 0
		check("6 lingots fondus au four (%d)" % n, n == 6 and count("iron_ingot") >= 6)
		check("guide : 2 lingots -> enclume", gd.step == 11)
		check("enclume fabriquée", craft("enclume"))
		for i in 12:
			if hb.selected == "enclume": break
			hb.cycle(1)
		p.facing = Vector3(1, 0, 0)
		hb._target = {}
		print("   case de l'enclume : ", hb.find_spot(items.get_item("enclume")))
		check("enclume posée à la main", hb.place())
		set_meta("t3", Time.get_ticks_msec())
	if has_meta("t3") and not has_meta("t3_done") and Time.get_ticks_msec() - int(get_meta("t3")) > 1300:
		set_meta("t3_done", true)
		gd._check_state()
		check("guide : enclume -> pioche en fer", gd.step == 12)
		p.inventory.add(items.get_item("iron_ingot"), 3)
		p.inventory.add(items.get_item("leather"), 1)
		check("épée en fer forgée à l'enclume", craft("sword_iron"))
		p.inventory.add(items.get_item("iron_ingot"), 3)
		check("pioche en fer forgée", craft("pioche_fer"))
		check("guide : chapitre 3 « Le village » commence", gd.step == 13)
		p.cam_yaw = deg_to_rad(160.0); p.cam_pitch = deg_to_rad(34.0); p.camera_zoom = 0.9
		p.snap_camera()
		set_meta("t4", Time.get_ticks_msec())
	if has_meta("t4") and not has_meta("t4_done") and Time.get_ticks_msec() - int(get_meta("t4")) > 500:
		set_meta("t4_done", true)
		shot("02_forge.png")
		print("== or avec la pioche en fer")
		stand_before(gold)
		var orb := count("or_brut")
		p._next_combo()
		check("pioche en fer en main devant l'or", p.tool_in_hand == "pioche_fer")
		set_meta("t5", Time.get_ticks_msec())
	if has_meta("t5") and not has_meta("t5_done") and Time.get_ticks_msec() - int(get_meta("t5")) > 150:
		set_meta("t5_done", true)
		shot("03_or_pioche_fer.png")
		var orb := count("or_brut")
		var hits := mine(gold, 20)
		collect()
		check("or miné en %d coups, +%d or brut" % [hits, count("or_brut") - orb], w.decor_at(gold) == 0 and count("or_brut") > orb)
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	return false
