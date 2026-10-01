extends SceneTree
var f := 0
var p; var w; var items; var gd; var vn; var k; var bm; var bo
var ok := true
var s: Vector2i; var H := 0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/v_"

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

func later(key: String, ms: int) -> bool:
	if not has_meta(key) or has_meta(key + "_done"):
		return false
	if Time.get_ticks_msec() - int(get_meta(key)) < ms:
		return false
	set_meta(key + "_done", true)
	return true

func _process(_d) -> bool:
	f += 1
	if p: p._invulnerable_left = 5.0
	if f == 10:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		gd = get_first_node_in_group("guide"); vn = get_first_node_in_group("village_needs"); k = get_first_node_in_group("kingdom")
		bm = p.get_node("BuildMode"); bo = get_first_node_in_group("build_orders")
		get_first_node_in_group("raids").enabled = false
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		print("== départ")
		var m: Array = vn.members()
		check("besoins présents : %d habitants, %d lits (rien de construit au départ), réserve %d repas" % [m.size(), vn.total_beds(), vn.meals()], vn != null and m.size() > 0 and vn.total_beds() == 0 and vn.meals() == 5)
		print("== repas")
		var v0 = m[0]
		v0.food = 30.0
		var stock0: float = vn.food_stock
		vn._update(1.0)
		check("un habitant affamé prend un repas dans la réserve (%.0f -> %.0f)" % [stock0, vn.food_stock], v0.food > 80.0 and vn.food_stock < stock0)
		vn.food_stock = 0.0
		for v in m: v.food = 10.0
		vn._update(1.0)
		check("réserve vide : il a faim (%s)" % str(v0.mood_reasons), v0.mood_reasons.has("meurt de faim"))
		print("== bonheur")
		for i in 400: vn._update(1.0)
		check("sans nourriture : malheureux (%d %%), travaille moins vite (×%.2f)" % [roundi(v0.happiness), v0.work_mult], v0.happiness < 20.0 and v0.work_mult < 1.0)
		check("Kingdom.affinity tient compte du bonheur", k.affinity(v0, "macon") < 1.0)
		var before: int = vn.members().size()
		for i in 250: vn._update(1.0)
		set_meta("before", before)
		set_meta("t", Time.get_ticks_msec())
	if later("t", 300):
		check("trop malheureux trop longtemps : des habitants partent (%d -> %d)" % [int(get_meta("before")), vn.members().size()], vn.members().size() < int(get_meta("before")))
		# on relance un village en bonne santé
		print("== réserve et production")
		vn.food_stock = 0.0
		p.inventory.add(items.get_item("viande_cuite"), 5)
		p.inventory.add(items.get_item("baies"), 4)
		var pts: float = vn.deposit_from(p)
		check("dépôt du sac : +%d points, sac vidé de sa nourriture" % roundi(pts), pts == 5 * 32.0 + 4 * 8.0 and p.inventory.count(items.get_item("baies")) == 0)
		check("guide chapitre 3 : réserve remplie", true)
		# la production de nourriture d'une pièce va dans la réserve
		var fake_type = load("res://data/rooms/boulangerie.tres")
		var st0: float = vn.food_stock
		if fake_type.production.is_food():
			vn.add_food(fake_type.production.food * fake_type.production_count)
		check("le pain de la boulangerie va dans la réserve (+%d)" % roundi(vn.food_stock - st0), vn.food_stock > st0)
		check("la grange produit de la viande", load("res://data/rooms/grange.tres").production.id == "viande_crue")
		print("== lits")
		var m2: Array = vn.members()
		# plus d'habitants que de lits
		while vn.members().size() < 8:
			var v = w.villager_scene.instantiate()
			v.race = w.villager_races[0]
			w.get_node("Village").add_child(v)
			v.global_position = w.cell_center(w.spawn_cell) + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
		vn.food_stock = 2000.0
		vn._update(1.0)
		var no_bed: Array = vn.members().filter(func(v): return not v.has_bed)
		check("%d habitants pour %d lits : %d sans lit" % [vn.members().size(), vn.total_beds(), no_bed.size()], no_bed.size() == vn.members().size() - vn.total_beds() and no_bed[0].mood_reasons.has("pas de lit"))
		# une maison de 2 lits construite
		s = w.spawn_cell + Vector2i(-1, 10)
		H = roundi(w.terrain_height(s))
		var cells := []
		for x in range(-6, 7):
			for z in range(0, 10):
				w.set_terrain_height(s + Vector2i(x, z), float(H)); w.remove_decor(s + Vector2i(x, z)); cells.append(s + Vector2i(x, z))
		w.refresh_cells(cells)
		p.inventory.add(items.get_item("bloc_planches"), 80)
		p.inventory.add(items.get_item("bloc_chaume"), 40)
		p.inventory.add(items.get_item("lit"), 4)
		p.inventory.add(items.get_item("porte"), 1)
		p.inventory.add(items.get_item("coffre"), 1)
		bm.toggle(true)
		bo.instant = true
		plan(1, 0, s + Vector2i(-3, 2), s + Vector2i(3, 7), H)
		plan(4, 0, s + Vector2i(0, 2), s + Vector2i(0, 2), H)
		plan(2, 0, s + Vector2i(-2, 3), s + Vector2i(2, 6), H)
		bm.furniture_index = bm._furniture_items.find(items.get_item("lit")); plan(5, 0, s + Vector2i(-2, 6), s + Vector2i(-2, 6), H + 1)
		bm.furniture_index = bm._furniture_items.find(items.get_item("coffre")); plan(5, 0, s + Vector2i(2, 6), s + Vector2i(2, 6), H + 1)
		bm.materials["roofs"] = "bloc_chaume"
		plan(3, 0, s + Vector2i(-3, 2), s + Vector2i(3, 7), H + 3)
		bm.toggle(false)
		k.recompute()
		print("   pièces : ", k.typed_rooms().map(func(r): return r.type.display_name), " lits ", vn.total_beds())
		set_meta("t2", Time.get_ticks_msec())
	if later("t2", 1500):
		vn._update(1.0)
		check("maison construite : 2 lits", vn.total_beds() == 2)
		# plus de cabanes toutes faites : seuls les deux premiers restent, un lit chacun
		var keep: Array = vn.members().slice(0, vn.total_beds())
		for v in vn.members():
			if not keep.has(v):
				v.remove_from_group("villagers")
				v.queue_free()
		vn._update(1.0)
		gd.import_state({"step": 14, "progress": 0, "v": 2})
		gd._check_state()
		check("guide : un lit pour chacun -> étape bonheur", gd.step == 15)
		print("== bonheur retrouvé et voyageurs")
		for v in vn.members():
			v.food = 90.0
		for i in 150: vn._update(1.0)
		var content: float = vn.average_happiness()
		check("nourris et logés sans confort : au moins contents (%d %%)" % roundi(content), content >= 40.0)
		# un raid repoussé : le village se sent en sécurité
		vn._safety = 10.0
		vn._safety_left = 600.0
		for i in 150: vn._update(1.0)
		var avg: float = vn.average_happiness()
		check("et en sécurité (raid repoussé) : heureux (%d %%), travaillent plus vite" % roundi(avg), avg >= 70.0 and vn.members()[0].work_mult > 1.0)
		gd._check_state()
		check("guide chapitre 3 terminé (-> chapitre 4, les champs)", gd.step == 16 or gd.is_done())
		# un voyageur attiré par le village (on libère une place)
		var extra = vn.members()[0]
		extra.queue_free()
		for sv in get_nodes_in_group("strangers"):
			if sv.has_meta("attracted"):
				print("   (un voyageur était déjà arrivé pendant l'attente)")
				sv.queue_free()
		set_meta("t3", Time.get_ticks_msec())
	if later("t3", 300):
		var strangers0: int = get_nodes_in_group("strangers").filter(func(v): return v.has_meta("attracted")).size()
		vn._arrival = 0.0
		vn._update(1.0)
		var strangers1: int = get_nodes_in_group("strangers").filter(func(v): return v.has_meta("attracted")).size()
		check("village heureux : un voyageur arrive (%d -> %d)" % [strangers0, strangers1], strangers1 == strangers0 + 1)
		print("== sauvegarde")
		var sg = root.get_node("SaveGame")
		vn.food_stock = 777.0
		var v0 = vn.members()[0]
		v0.happiness = 33.0
		set_meta("name", v0.villager_name)
		sg.save_game("3")
		sg.load_game("3")
		set_meta("t4", Time.get_ticks_msec())
	if later("t4", 1800):
		vn = get_first_node_in_group("village_needs")
		var v0 = null
		for v in vn.members():
			if v.villager_name == get_meta("name"): v0 = v
		print("   rechargé : ", vn.members().map(func(v): return [v.villager_name, roundi(v.happiness)]), " cherché ", get_meta("name"))
		check("réserve rechargée (%d)" % roundi(vn.food_stock), absf(vn.food_stock - 777.0) < 5.0 and vn.members().any(func(v): return absf(v.happiness - 33.0) < 3.0))
		p = get_first_node_in_group("player")
		p.inventory.add(items.get_item("pain"), 3)
		var hud = get_first_node_in_group("hud")
		hud.kingdom_panel.open()
		set_meta("t5", Time.get_ticks_msec())
	if later("t5", 500):
		shot("01_royaume.png")
		get_first_node_in_group("hud").kingdom_panel.close()
		# étiquette d'un habitant
		var v = vn.members()[0]
		p.global_position = v.global_position + Vector3(1.5, 0, 1.5)
		p.cam_yaw = deg_to_rad(20.0); p.cam_pitch = deg_to_rad(28.0); p.camera_zoom = 0.7
		p.snap_camera()
		set_meta("t6", Time.get_ticks_msec())
	if later("t6", 600):
		shot("02_habitant.png")
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	return false
