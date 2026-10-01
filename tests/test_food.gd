extends SceneTree
var f := 0
var p; var w; var items; var gd
var ok := true
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/q_"

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

func find_decor(kind: int) -> Vector2i:
	var s: Vector2i = w.spawn_cell
	for r in range(5, 80):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c: Vector2i = s + Vector2i(dx, dz)
				if w.decor_at(c) == kind and w.decor_at(c - Vector2i(1, 0)) == 0 and w.decor_at(c - Vector2i(2, 0)) == 0:
					return c
	return Vector2i(-1, -1)

func _process(_d) -> bool:
	f += 1
	if p: p._invulnerable_left = 5.0
	if f == 8:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		gd = get_first_node_in_group("guide")
		get_first_node_in_group("raids").enabled = false
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		print("== faim")
		check("départ rassasié (100)", absf(p.hunger - 100.0) < 0.5 and p.hunger_state() == 2)
		var regen_full: float = p.health.regen_per_second
		p._update_hunger(60.0)
		check("baisse avec le temps (%.1f après 60 s)" % p.hunger, p.hunger < 94.0 and p.hunger > 90.0)
		p.hunger = 20.0
		p._on_hunger_state()
		check("affamé : plus de régénération (%.1f -> %.1f)" % [regen_full, p.health.regen_per_second], p.health.regen_per_second == 0.0 and p.hunger_state() == 0)
		p.hunger = 0.0
		p._on_hunger_state()
		p.health.current = p.health.max_health
		for i in 4:
			p._starve_timer = 0.0
			p._update_hunger(0.01)
		check("meurt de faim : perd de la vie (%d/%d)" % [p.health.current, p.health.max_health], p.health.current < p.health.max_health and p.hunger_state() == -1)
		print("== nourriture")
		var bush := find_decor(3)
		var bc: Vector3 = w.cell_center(bush)
		p.global_position = Vector3(bc.x - 1.3, w.ground_height_at(bc - Vector3(1.3, 0, 0)), bc.z)
		p.facing = Vector3(1, 0, 0)
		while w.decor_at(bush) != 0:
			p._harvest_swing({"dmg": 1.0})
		collect()
		check("buisson : des baies (%d)" % count("baies"), count("baies") >= 1)
		# un sanglier vaincu donne de la viande
		var scene := load("res://scenes/enemies/enemy.tscn") as PackedScene
		var meat := 0
		for i in 4:
			var e = scene.instantiate()
			e.data = load("res://data/enemies/sanglier.tres")
			w.get_node("Village").add_child(e)
			e.global_position = p.global_position + Vector3(2, 0, 0)
			e.health.take_damage(99999, p)
		set_meta("t", Time.get_ticks_msec())
	if has_meta("t") and not has_meta("t_done") and Time.get_ticks_msec() - int(get_meta("t")) > 2500:
		set_meta("t_done", true)
		collect(10.0)
		check("sangliers : de la viande crue (%d)" % count("viande_crue"), count("viande_crue") >= 2)
		print("== cuisine")
		p.inventory.add(items.get_item("baies"), 3)
		p.global_position = w.cell_center(w.spawn_cell + Vector2i(18, 18))
		check("loin du feu : pas de cuisine", not craft("viande_cuite"))
		p.global_position = w.cell_center(w.spawn_cell) + Vector3(0, 0, 2.5)
		check("près du feu de camp : station « feu »", p.nearby_stations().has("feu"))
		check("viande cuite", craft("viande_cuite"))
		check("ragoût", craft("ragout"))
		print("== manger")
		gd.import_state({"step": 6, "progress": 0, "v": 2})
		p.hunger = 30.0
		p.health.current = 20
		var eaten = p.eat()
		print("   mangé : ", eaten.id if eaten else "rien", " -> faim %.0f, vie %d" % [p.hunger, p.health.current])
		check("H : choisit un plat qui ne gaspille pas (ragoût pour 70 de faim)", eaten and eaten.id == "ragout" and p.hunger > 80.0 and p.health.current == 60)
		check("guide : repas cuit -> étape suivante", gd.step == 7)
		p.hunger = 99.5
		check("rassasié : refuse de manger", p.eat() == null)
		check("rassasié : régénération bonus", p.hunger_regen_bonus() > 0.0)
		# conversion d'un ancien guide (v1, étape « nuit » = 6)
		gd.import_state({"step": 6, "progress": 0})
		check("ancienne sauvegarde du guide convertie (6 -> 7)", gd.step == 7)
		gd.import_state({"step": 3, "progress": 0})
		check("ancienne sauvegarde, étape avant : inchangée", gd.step == 3)
		var sg = root.get_node("SaveGame")
		p.hunger = 42.0
		sg.save_game("3")
		p.hunger = 90.0
		sg.load_game("3")
		set_meta("t2", Time.get_ticks_msec())
	if has_meta("t2") and not has_meta("t2_done") and Time.get_ticks_msec() - int(get_meta("t2")) > 1500:
		set_meta("t2_done", true)
		p = get_first_node_in_group("player")
		check("faim sauvegardée (%.0f)" % p.hunger, absf(p.hunger - 42.0) < 1.5)
		p.hunger = 18.0
		p._on_hunger_state()
		p.inventory.add(items.get_item("viande_cuite"), 2)
		p.inventory.add(items.get_item("baies"), 5)
		p.inventory.add(items.get_item("pain"), 3)
		p.cam_pitch = deg_to_rad(36.0); p.camera_zoom = 1.0; p.snap_camera()
		p.open_inventory.emit(p)
		set_meta("t3", Time.get_ticks_msec())
	if has_meta("t3") and not has_meta("t3_done") and Time.get_ticks_msec() - int(get_meta("t3")) > 600:
		set_meta("t3_done", true)
		for c in get_first_node_in_group("hud").get_children():
			if c.get("_cat") != null:
				c._cat = "Cuisine"
				c._refresh()
		set_meta("t4", Time.get_ticks_msec())
	if has_meta("t4") and not has_meta("t4_done") and Time.get_ticks_msec() - int(get_meta("t4")) > 400:
		set_meta("t4_done", true)
		shot("01_cuisine.png")
		for c in get_first_node_in_group("hud").get_children():
			if c.has_method("close") and c.get("_cat") != null:
				c.close()
		set_meta("t5", Time.get_ticks_msec())
	if has_meta("t5") and not has_meta("t5_done") and Time.get_ticks_msec() - int(get_meta("t5")) > 400:
		set_meta("t5_done", true)
		shot("02_affame.png")
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	return false
