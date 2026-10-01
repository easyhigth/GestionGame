extends SceneTree
var f := 0
var p; var w; var items; var fm; var vn; var k; var dc; var hud; var gd; var H
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/f_"
var plot0: Vector2i
var farmer
var food0 := 0.0

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

## Une rangée de 8 cases d'herbe libres et plates (loin de l'eau).
func find_row(dry: bool) -> Vector2i:
	var s: Vector2i = w.spawn_cell
	for r in range(10, 70):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c: Vector2i = s + Vector2i(dx, dz)
				var good := true
				for i in range(-1, 8):
					var n := c + Vector2i(i, 0)
					if w.terrain_type(n) != 3 or w.decor_at(n) != 0 or absf(w.terrain_height(n) - w.terrain_height(c)) > 0.01 or w.village_prop_at(n, w.terrain_height(n)) != null:
						good = false
						break
				if good and w.near_water(c, 4) != (not dry):
					continue
				if good:
					return c
	return Vector2i(-1, -1)

func stand_before(c: Vector2i) -> void:
	var at: Vector3 = w.cell_center(c - Vector2i(1, 0))
	p.global_position = at
	p.facing = Vector3(1, 0, 0)

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p: p._invulnerable_left = 5.0
	if f == 10:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		fm = get_first_node_in_group("farming"); vn = get_first_node_in_group("village_needs"); k = get_first_node_in_group("kingdom")
		dc = get_first_node_in_group("day_cycle"); hud = get_first_node_in_group("hud"); gd = get_first_node_in_group("guide")
		H = load("res://scripts/world/harvest.gd")
		get_first_node_in_group("raids").enabled = false
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		get_first_node_in_group("quests")._offer_timer = 9999.0
		dc.hour = 9.0
		print("== champ de départ")
		check("système des champs présent", fm != null)
		var sm: Dictionary = fm.summary()
		print("   ", sm)
		check("petit champ de blé au village (6 cases, semées)", sm.plots == 6 and sm.planted == 6)
		check("sol labouré (type FARM)", fm.plots.keys().all(func(c): return w.terrain_type(c) == 7))
		check("modèles des cultures affichés", fm._nodes.size() == 6)
		print("== graines et houe")
		var got := 0
		for i in 200:
			for l in H.loot(6):
				if l[0].id == "graines_ble": got += 1
		check("les hautes herbes donnent des graines de blé (%d / 200)" % got, got > 50 and got < 140)
		var veg := 0
		for i in 200:
			for l in H.loot(3):
				if l[0].id in ["carotte", "pomme_de_terre"]: veg += 1
		check("les buissons donnent parfois carottes et pommes de terre (%d / 200)" % veg, veg > 30)
		p.inventory.add(items.get_item("graines_ble"), 8)
		p.inventory.add(items.get_item("carotte"), 2)
		p.inventory.add(items.get_item("pomme_de_terre"), 2)
		var row := find_row(true)
		plot0 = row
		print("   rangée à ", row, " (village ", w.spawn_cell, ")")
		stand_before(row)
		p.hand.selected = "graines_ble"
		var sp: Dictionary = p.hand.find_spot(items.get_item("graines_ble"))
		check("sans houe : semer sur l'herbe impossible (%s)" % sp.get("why", ""), not sp.ok and not p.hand.place())
		p.inventory.add(items.get_item("wood"), 2); p.inventory.add(items.get_item("stone"), 2)
		check("houe fabriquée (2 bois, 2 cailloux)", craft("houe") and count("houe") == 1)
		check("houe et graines choisissables (C)", p.hand.choices().any(func(it): return it.id == "houe") and p.hand.choices().any(func(it): return it.id == "carotte"))
		p.hand._target = {}
		check("avec la houe : laboure et sème (V)", p.hand.place() and w.terrain_type(row) == 7 and fm.crop_at(row).get("c", "") == "ble" and count("graines_ble") == 7)
		check("houe en main", p.tool_in_hand == "houe")
		p.hand._target = {}
		check("semer deux fois au même endroit : non", not p.hand.find_spot(items.get_item("graines_ble")).ok)
		# houe seule : laboure la case suivante
		stand_before(row + Vector2i(1, 0))
		p.hand.selected = "houe"; p.hand._target = {}
		check("houe choisie : laboure seulement", p.hand.place() and w.terrain_type(row + Vector2i(1, 0)) == 7 and fm.crop_at(row + Vector2i(1, 0)).is_empty())
		p.hand.selected = "carotte"; p.hand._target = {}
		check("une carotte se plante", p.hand.place() and fm.crop_at(row + Vector2i(1, 0)).get("c", "") == "carotte")
		stand_before(row + Vector2i(2, 0))
		p.hand.selected = "pomme_de_terre"; p.hand._target = {}
		check("une pomme de terre se plante", p.hand.place() and fm.crop_at(row + Vector2i(2, 0)).get("c", "") == "pomme_de_terre")
		for i in range(3, 6):
			stand_before(row + Vector2i(i, 0))
			p.hand.selected = "graines_ble"; p.hand._target = {}
			p.hand.place()
		print("== pousse")
		check("stade 0 juste semé", fm.stage_of(row) == 0 and not fm.is_ripe(row))
		var wet := find_row(false)
		print("   rangée arrosée : ", wet)
		if wet.x < 0:
			# pas d'eau près du village dans ce monde : on en creuse une case à côté d'une case labourée
			wet = row + Vector2i(0, 12)
			w.set_terrain_height(wet + Vector2i(1, 0), -1.0)
			w._types[w._idx(wet + Vector2i(1, 0))] = 1
		fm.till(wet, true)
		check("champ près de l'eau : arrosé (x%.1f), champ sec (x%.1f)" % [fm.growth_rate(wet), fm.growth_rate(row)], fm.growth_rate(wet) > fm.growth_rate(row))
		fm.grow(110.0)
		check("pousse : stade %d après 110 s" % fm.stage_of(row), fm.stage_of(row) == 1)
		dc.hour = 23.0
		var g0: float = fm.crop_at(row).g
		fm.grow(10.0)
		check("la nuit, pousse moitié moins vite (%.1f s)" % (fm.crop_at(row).g - g0), absf(fm.crop_at(row).g - g0 - 5.0 * get_first_node_in_group("seasons").crop_rate()) < 0.01)
		dc.hour = 9.0
		fm.grow(100.0)
		check("stade 2", fm.stage_of(row) == 2)
		check("modèle du stade 2", int(fm._nodes[row].get_meta("stage")) == 2)
		fm.grow(200.0)
		check("mûr (stade 3) : blé, carotte, pomme de terre", fm.is_ripe(row) and fm.is_ripe(row + Vector2i(1, 0)) and fm.is_ripe(row + Vector2i(2, 0)))
		# capture : les cultures mûres
		p.global_position = w.cell_center(row + Vector2i(2, 3))
		p.cam_yaw = deg_to_rad(180.0); p.cam_pitch = deg_to_rad(40.0); p.camera_zoom = 0.7; p.snap_camera()
		p.hand.selected = "graines_ble"
		start("a")
	if later("a", 600):
		shot("01_cultures.png")
		print("== récolte")
		stand_before(plot0)
		var t: Dictionary = H.find_target(p, 1.8, true)
		print("   dbg cible ", t, " mûr ", fm.is_ripe(plot0), " joueur ", w.cell_at(p.global_position), " face ", p.facing, " décor ", [w.decor_at(plot0), w.decor_at(plot0 + Vector2i(0, 1)), w.decor_at(plot0 - Vector2i(0, 1))])
		check("culture mûre devant soi : cible de récolte", t.get("crop", Vector2i(-1, -1)) == plot0)
		var ble0 := count("ble")
		H.strike(p, 1.8, 1.0)
		collect()
		check("récolte à la main : blé (%d) et graines" % (count("ble") - ble0), count("ble") - ble0 >= 2 and fm.crop_at(plot0).is_empty())
		stand_before(plot0 + Vector2i(1, 0))
		var car0 := count("carotte")
		H.strike(p, 1.8, 1.0)
		collect()
		check("carottes récoltées (%d)" % (count("carotte") - car0), count("carotte") - car0 >= 2)
		stand_before(plot0 + Vector2i(3, 0))
		if fm.crop_at(plot0 + Vector2i(3, 0)).is_empty():
			fm.plant(plot0 + Vector2i(3, 0), "ble")
		fm.crops[plot0 + Vector2i(3, 0)].g = 10.0
		var s0 := count("graines_ble")
		p.dig()
		collect()
		check("creuser une culture pas mûre : la graine revient", fm.crop_at(plot0 + Vector2i(3, 0)).is_empty() and count("graines_ble") == s0 + 1)
		print("== cuisine")
		p.global_position = w.cell_center(w.spawn_cell) + Vector3(1.5, 0, 1.5)
		p.inventory.add(items.get_item("ble"), 3); p.inventory.add(items.get_item("pomme_de_terre"), 3); p.inventory.add(items.get_item("carotte"), 2)
		check("pain (3 blé, près du feu)", craft("pain"))
		check("pomme de terre cuite", craft("pomme_de_terre_cuite"))
		check("soupe de légumes", craft("soupe_legumes") and items.get_item("soupe_legumes").food_cooked)
		check("graines de blé battues (1 blé -> 2 graines)", craft("graines_ble"))
		print("== fermiers")
		check("poste « Champs » proposé", k.workplaces().has(fm.fields_room))
		var sm: Dictionary = fm.summary()
		print("   ", sm, " postes ", fm.fields_room.type.job_slots)
		farmer = vn.members()[0]
		check("habitant nommé fermier", k.assign(farmer, fm.fields_room) and farmer.work_room == fm.fields_room)
		k.recompute()
		check("il garde son poste quand les pièces changent", farmer.work_room == fm.fields_room)
		# le champ de départ mûrit
		for c in fm.crops.keys():
			if c.distance_to(w.spawn_cell) < 12:
				fm.crops[c].g = 999.0
				fm._show(c)
		# on vide la rangée du héros pour ne garder que le champ du village
		for c in fm.plots.keys():
			var o: Vector2i = c - w.spawn_cell
			if not (o.x >= 3 and o.x <= 5 and o.y >= 5 and o.y <= 6):
				fm.plots.erase(c)
				if fm.crops.has(c): fm._remove(c)
		fm._update_slots()
		food0 = vn.food_stock
		print("   réserve avant : ", food0, " mûres : ", fm.summary().ripe)
		farmer.global_position = fm.fields_center() + Vector3(0, 0, 3)
		start("b")
	if later("b", 14000):
		var sm: Dictionary = fm.summary()
		print("   après : ", sm, " réserve ", vn.food_stock, " graines ", fm.seed_store, " tâche ", farmer._farm_task, " au travail ", farmer.is_at_work(), " activité ", farmer.activity)
		check("le fermier récolte : réserve %d -> %d" % [roundi(food0), roundi(vn.food_stock)], vn.food_stock > food0 + 20.0)
		check("il ressème (%d semées sur %d)" % [sm.planted, sm.plots], sm.planted >= sm.plots - 1)
		check("graines en trop gardées pour semer", fm.seeds_count() > 0)
		# des cases vides : il sème avec les graines confiées
		for c in fm.crops.keys().slice(0, 3):
			fm._remove(c)
		p.inventory.add(items.get_item("carotte"), 5)
		var n: int = fm.deposit_seeds(p)
		check("graines confiées aux fermiers (%d)" % n, n > 0 and count("carotte") == 0)
		p.global_position = fm.fields_center() + Vector3(-2.5, 0, 3.5)
		p.cam_yaw = deg_to_rad(160.0); p.cam_pitch = deg_to_rad(32.0); p.camera_zoom = 0.9; p.snap_camera()
		start("c")
	if has_meta("c") and not has_meta("c_done") and f % 30 == 0:
		print("   dbg t=", roundi(game_ms - float(get_meta("c"))), " tâche ", farmer._farm_task, " pos ", w.cell_at(farmer.global_position), " act ", farmer.activity, " vivant ", farmer.is_alive(), " plantées ", fm.summary().planted)
	if later("c", 16000):
		var sm: Dictionary = fm.summary()
		print("   ", sm, " graines ", fm.seed_store)
		check("il sème les cases vides (%d / %d)" % [sm.planted, sm.plots], sm.planted == sm.plots)
		shot("02_fermier.png")
		print("== guide")
		gd.step = 16; gd.progress = 0; gd._refresh()
		gd._check_state()
		check("guide chapitre 4 : houe -> semer", gd.current_id() == "semer")
		for i in 6: p.planted.emit("ble")
		print("   dbg guide ", gd.step, " ", gd.progress, " ", p.planted.get_connections().size())
		for i in 3: p.crop_harvested.emit("ble")
		print("   dbg guide2 ", gd.step, " ", gd.progress, " ", p.crop_harvested.get_connections().size())
		check("6 graines semées, 3 récoltes -> fermier (déjà nommé : fini)", gd.current_id() == "fermier" or gd.step >= 20)
		gd._check_state()
		check("fermier nommé : chapitre 4 fini", gd.step >= 20)
		print("== panneau et sauvegarde")
		hud.kingdom_panel.open()
		start("d")
	if later("d", 400):
		shot("03_royaume_champs.png")
		hud.kingdom_panel.close()
		set_meta("state", fm.export_state())
		set_meta("farmer", farmer.villager_name)
		root.get_node("SaveGame").save_game("3")
		root.get_node("SaveGame").load_game("3")
		start("e")
	if later("e", 1800):
		fm = get_first_node_in_group("farming"); w = get_first_node_in_group("world"); p = get_first_node_in_group("player")
		var st: Dictionary = get_meta("state")
		var now: Dictionary = fm.export_state()
		check("cultures rechargées (%d / %d)" % [now.crops.size(), st.crops.size()], now.crops.size() == st.crops.size() and now.plots.size() == st.plots.size())
		check("graines des fermiers rechargées", now.seeds == st.seeds)
		check("sol labouré rechargé", fm.plots.keys().all(func(c): return w.terrain_type(c) == 7))
		check("pas de nouveau champ de départ au chargement", fm.plots.size() == st.plots.size())
		start("f")
	if later("f", 1500):
		check("fermier rechargé (%s)" % str(fm.farmers().map(func(v): return v.villager_name)), fm.farmers().any(func(v): return v.villager_name == get_meta("farmer")))
		# capture : semer à la main (case fantôme)
		var row := find_row(true)
		stand_before(row)
		p.inventory.add(items.get_item("houe"), 1)
		p.inventory.add(items.get_item("graines_ble"), 5)
		p.hand.selected = "graines_ble"
		for i in 3:
			stand_before(row + Vector2i(i, 0)); p.hand._target = {}; p.hand.place()
		stand_before(row + Vector2i(3, 0))
		p.facing = Vector3(1, 0, 0)
		p.cam_yaw = deg_to_rad(250.0); p.cam_pitch = deg_to_rad(30.0); p.camera_zoom = 0.6; p.snap_camera()
		start("g")
	if later("g", 700):
		shot("04_semer.png")
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	return false
