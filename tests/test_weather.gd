extends SceneTree
var f := 0
var p; var w; var items; var fm; var vn; var k; var dc; var hud; var gd; var H
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/w_"
var we

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


func zone_with(precip: String) -> Dictionary:
	for z in w.zones:
		if z.type and z.type.precipitation == precip and (z.obelisk as Vector2i).x >= 0:
			return z
	return {}

func go_zone(z: Dictionary) -> void:
	var c: Vector3 = w.cell_center(z.obelisk) + Vector3(3, 0, 3)
	w.load_area(c)
	c.y = w.ground_height_at(c + Vector3(0, 20, 0))
	p.global_position = c

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
		we = get_first_node_in_group("weather")
		get_first_node_in_group("raids").enabled = false
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		get_first_node_in_group("quests")._offer_timer = 9999.0
		dc.hour = 10.0
		print("== départ")
		check("météo présente : %s, demain %s" % [we.kind, we.tomorrow], we != null and we.kind == "clair" and we.tomorrow in we.KINDS)
		print("   HUD : ", we.hud_text())
		var counts := {}
		for i in 400:
			var r: String = we._roll(load("res://data/regions/desert.tres"))
			counts[r] = int(counts.get(r, 0)) + 1
		print("   désert : ", counts)
		check("climat : le désert est surtout clair, sans orage", int(counts.get("clair", 0)) > 200 and int(counts.get("orage", 0)) == 0)
		print("== pluie au village")
		var plot: Vector2i = fm.plots.keys()[0]
		var dry_rate: float = fm.growth_rate(plot)
		we.set_kind("pluie")
		we._mix = we.LOOK["pluie"].duplicate()
		we._process(0.1)
		check("il pleut : champs arrosés (x%.1f -> x%.1f)" % [dry_rate, fm.growth_rate(plot)], we.waters_fields() and fm.growth_rate(plot) > dry_rate)
		check("particules de pluie", we._particles["pluie"].emitting and not we._particles["neige"].emitting)
		check("son de la pluie", we._audio_track == "amb_rain")
		dc._apply_light()
		check("ciel assombri (%.2f)" % dc._sun.light_energy, dc._sun.light_energy < 0.8)
		print("   HUD : ", we.hud_text())
		view(200, 25, 1.2)
		start("a")
	if later("a", 1500):
		shot("01_pluie.png")
		print("== abri des habitants")
		dc.hour = 18.5
		start("b")
	if later("b", 9000):
		var acts: Array = vn.members().map(func(v): return v.activity)
		var sheltered: int = vn.members().filter(func(v): return v.is_sheltered()).size()
		print("   activités ", acts, " à l'abri ", sheltered, " / ", vn.members().size())
		check("le soir sous la pluie : ils s'abritent", acts.count("abri") == acts.size())
		check("rentrés dans les cabanes (%d)" % sheltered, sheltered >= vn.members().size() - 1)
		we.set_kind("clair"); we._mix = [0.0, 0.0, 0.0]
		start("b2")
	if later("b2", 2500):
		check("éclaircie : ils ressortent se détendre", vn.members().all(func(v): return v.activity == "détente" and v.visual.visible))
		print("== sécheresse")
		var plot: Vector2i = fm.plots.keys()[0]
		we.dry_days = 0; we._rained_today = false
		for i in 3:
			we.tomorrow = "clair"
			we._on_day(i)
		we.set_kind("clair")
		print("   jours secs ", we.dry_days, " vitesse ", fm.growth_rate(plot))
		check("3 jours sans pluie : sécheresse, les champs poussent moins vite", we.drought() and fm.growth_rate(plot) < 1.0 or w.near_water(plot))
		we.set_kind("pluie")
		we._on_day(9)
		check("un jour de pluie arrête la sécheresse", we.dry_days == 0 or not we.drought())
		print("== orage")
		dc.hour = 10.0
		we.set_kind("orage")
		we._mix = we.LOOK["orage"].duplicate()
		p.global_position = w.cell_center(w.spawn_cell) + Vector3(0, 0, 30)
		p.global_position.y = w.ground_height_at(p.global_position + Vector3(0, 20, 0))
		for i in 8:
			dc._spawn_timer = 0.0
			dc._process(0.05)
		check("orage en plein jour : des monstres apparaissent (%d)" % dc.night_monsters().size(), dc.night_monsters().size() > 0)
		var trees0 := 0
		we.lightning()
		check("éclair : flash", we.flash() > 0.5)
		for e in dc.night_monsters(): e.set_physics_process(false)
		we._process(0.05)
		dc._apply_light()
		view(30, 20, 1.3)
		start("c")
	if later("c", 200):
		we._flash = 0.9
		dc._apply_light()
		shot("02_orage.png")
		we.set_kind("clair"); we._mix = [0.0, 0.0, 0.0]
		dc._process(0.05)
		check("fin de l'orage : les monstres fuient", dc.night_monsters().is_empty())
		print("== brouillard")
		we.set_kind("brouillard"); we._mix = we.LOOK["brouillard"].duplicate()
		we._process(0.05)
		check("brouillard : fog activé", we._env.fog_enabled and we._env.fog_density > 0.03)
		p.global_position = w.cell_center(w.spawn_cell) + Vector3(0, 0, 2)
		view(20, 22, 1.2)
		start("d")
	if later("d", 800):
		shot("03_brouillard.png")
		print("== neige et froid")
		var z := zone_with("neige")
		check("une zone enneigée existe", not z.is_empty())
		go_zone(z)
		we.set_kind("pluie"); we._mix = we.LOOK["pluie"].duplicate()
		we._process(0.05)
		print("   HUD : ", we.hud_text())
		check("dans la zone froide, il neige", we._precip == "neige" and we._particles["neige"].emitting and we.display_name() == "Neige")
		for s in [ItemData.Slot.BACK, ItemData.Slot.CHEST]:
			if p.equipment.slots.has(s): p.equipment.unequip(s)
		for i in 30: we._update_cold(1.0, false)
		check("sans vêtement chaud : froid, plus lent", we.cold and we.speed_mult() < 1.0 and p._weather_speed() < 1.0)
		p.equipment.equip(items.get_item("cape_red"))
		for i in 30: we._update_cold(1.0, false)
		check("avec une cape : réchauffé", not we.cold)
		view(210, 22, 1.2)
		start("e")
	if later("e", 1800):
		shot("04_neige.png")
		var z := zone_with("sable")
		if not z.is_empty():
			go_zone(z)
			we._process(0.05)
			check("dans le désert : tempête de sable", we._precip == "sable" and we._particles["sable"].emitting and we._env.fog_enabled)
		view(120, 20, 1.2)
		start("f")
	if later("f", 1800):
		shot("05_sable.png")
		print("== sauvegarde")
		p.global_position = w.cell_center(w.spawn_cell) + Vector3(2, 0, 2)
		w.load_area(p.global_position)
		we.set_kind("orage")
		we.dry_days = 2
		set_meta("st", we.export_state())
		root.get_node("SaveGame").save_game("3")
		root.get_node("SaveGame").load_game("3")
		start("g")
	if later("g", 2000):
		we = get_first_node_in_group("weather")
		var st: Dictionary = get_meta("st")
		check("météo rechargée (%s, demain %s, %d jours secs)" % [we.kind, we.tomorrow, we.dry_days], we.kind == st.kind and we.tomorrow == st.tomorrow and we.dry_days == 2)
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	return false
