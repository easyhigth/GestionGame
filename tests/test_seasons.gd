extends SceneTree
var f := 0
var p; var w; var items; var fm; var vn; var k; var dc; var hud; var gd; var H
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/e_"
var se
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


func view(yaw, pitch, zoom) -> void:
	p.cam_yaw = deg_to_rad(yaw); p.cam_pitch = deg_to_rad(pitch); p.camera_zoom = zoom; p.snap_camera()

func set_day(d: int) -> void:
	dc.day = d
	se._process(10.0)
	se._leaf = se.LEAF[se.season()]; se._ground = se.GROUND[se.season()]; se._snow = se.SNOW[se.season()]
	se._apply_colors()

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p: p._invulnerable_left = 5.0
	if f > 10 and f % 10 == 0:
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
	if f == 10:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		vn = get_first_node_in_group("village_needs"); k = get_first_node_in_group("kingdom")
		dc = get_first_node_in_group("day_cycle"); hud = get_first_node_in_group("hud"); fm = get_first_node_in_group("farming")
		se = get_first_node_in_group("seasons"); we = get_first_node_in_group("weather")
		get_first_node_in_group("raids").enabled = false
		get_first_node_in_group("quests")._offer_timer = 9999.0
		we.set_kind("clair"); we._mix = [0.0, 0.0, 0.0]
		dc.hour = 11.0
		print("== printemps")
		check("saisons présentes : %s" % se.hud_text(), se != null and se.season() == 0 and se.day_in_season() == 1)
		check("les cultures poussent mieux au printemps (x%.2f)" % se.crop_rate(), se.crop_rate() > 1.0)
		var counts := [{}, {}]
		for i in 2:
			set_day(1 if i == 0 else 5)
			for j in 600:
				var r: String = we._roll()
				counts[i][r] = int(counts[i].get(r, 0)) + 1
		print("   printemps ", counts[0], "  été ", counts[1])
		check("plus de pluie au printemps qu'en été", int(counts[0].get("pluie", 0)) > int(counts[1].get("pluie", 0)))
		set_day(1)
		p.global_position = w.cell_center(w.spawn_cell) + Vector3(0, 0, 7)
		view(0, 30, 1.6)
		start("a")
	if later("a", 900):
		shot("01_printemps.png")
		print("== fête des semailles")
		set_day(2)
		se._festival_step()
		check("jour 2 : fête des semailles", se.is_festival() and se._decor != null)
		var gifts := 0
		for n in w.get_node("Village").get_children():
			if n.has_method("is_taken") and n.item and n.item.id in ["graines_ble", "carotte", "pomme_de_terre"] and n.global_position.distance_to(w.hearth_center()) < 4.0:
				gifts += 1
		check("cadeaux près du feu (%d)" % gifts, gifts == 3)
		var ss: int = se._gifts.size()
		se._decor.queue_free(); se._decor = null
		se._festival_step()
		check("pas deux fois les cadeaux", se._gifts.size() == ss)
		vn._update(1.0)
		print("   ", k.title(), " bonheur ", vn.average_happiness())
		dc.hour = 20.5
		for i in 5:
			se._fireworks = 0.0
			se._fireworks_step(0.1)
		view(0, 18, 1.8)
		start("b")
	if later("b", 700):
		se._fireworks = 0.0; se._fireworks_step(0.1)
		shot("02_fete.png")
		print("== automne")
		dc.hour = 11.0
		set_day(10)
		check("automne", se.season() == 2 and se.season_name() == "Automne")
		view(200, 28, 1.6)
		start("c")
	if later("c", 900):
		shot("03_automne.png")
		print("== hiver")
		set_day(14)
		check("hiver : rien ne pousse", se.is_winter() and se.crop_rate() == 0.0)
		var plot: Vector2i = fm.plots.keys()[0]
		var g0: float = fm.crops[plot].g if fm.crops.has(plot) else 0.0
		fm.grow(50.0)
		check("les cultures ne poussent pas l'hiver", not fm.crops.has(plot) or fm.crops[plot].g == g0)
		we.set_kind("pluie"); we._mix = we.LOOK["pluie"].duplicate()
		we._process(0.05)
		check("l'hiver, la pluie devient neige au village (%s)" % we.display_name(), we._precip == "neige" and we.display_name() == "Neige")
		print("   HUD : ", hud._weather_label.text)
		view(20, 30, 1.6)
		start("d")
	if later("d", 1500):
		shot("04_hiver.png")
		set_day(14)
		se._festival_step()
		check("fête des lumières en hiver", se.is_festival() and se.hud_text().begins_with("Fête des lumières"))
		hud.kingdom_panel.open()
		start("e")
	if later("e", 400):
		shot("05_royaume.png")
		hud.kingdom_panel.close()
		set_meta("gifts", se._gifts.duplicate())
		root.get_node("SaveGame").save_game("3")
		root.get_node("SaveGame").load_game("3")
		start("f")
	if later("f", 2000):
		se = get_first_node_in_group("seasons"); dc = get_first_node_in_group("day_cycle")
		print("   dbg cadeaux ", se._gifts, " avant ", get_meta("gifts"))
		check("saison et cadeaux rechargés (jour %d, %s)" % [dc.day, se.season_name()], dc.day == 14 and se.is_winter() and se._gifts == get_meta("gifts"))
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	return false
