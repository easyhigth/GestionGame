extends SceneTree
var f := 0
var p; var w; var items; var dip; var hud; var rm; var tr
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/ev_"

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

func later(key: String, ms: int) -> bool:
	if not has_meta(key) or has_meta(key + "_done"):
		return false
	if game_ms - float(get_meta(key)) < ms:
		return false
	set_meta(key + "_done", true)
	return true

func start(key: String) -> void:
	set_meta(key, game_ms)

func gold() -> int:
	return p.inventory.count(items.get_item("piece_or"))
var wev; var kp

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p:
		p._invulnerable_left = 5.0
		p.health.heal(9999)
	if f == 10:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		hud = get_first_node_in_group("hud"); rm = get_first_node_in_group("raids"); tr = get_first_node_in_group("trade")
		wev = get_first_node_in_group("world_events")
		rm.enabled = false
		print("== pluie d'étoiles")
		check("pas d'événement au début", not wev.is_active())
		wev.start("etoiles")
		check("4 éclats tombés : %s" % wev.status_text(), wev._stars.size() == 4)
		start("st")
	if later("st", 1500):
		shot("01_etoiles.png")
		for s in wev._stars:
			if is_instance_valid(s):
				p.try_pickup(s)
		start("st2")
	if later("st2", 1500):
		check("tous ramassés : événement réussi", not wev.is_active())
		print("== fête")
		wev.start("fete")
		check("fête : +15 de bonheur, marchand là", wev.happiness_bonus() == 15.0 and tr.is_here())
		wev.new_day(wev.today() + 2)
		check("fin de la fête le surlendemain", not wev.is_active())
		print("== épidémie")
		wev.start("epidemie")
		check("%d malade(s)" % wev.sick().size(), wev.sick().size() >= 1)
		check("sans remède : %s" % wev.cure_block(), wev.cure_block() != "")
		start("ep")
	if later("ep", 2500):
		var v = wev.sick()[0]
		check("%s est malade : %s" % [v.villager_name, v.mood_reasons], v.mood_reasons.has("malade"))
		p.inventory.add(items.get_item("soupe_legumes"), 6)
		hud.kingdom_panel.open()
		start("kp")
	if later("kp", 600):
		shot("02_epidemie.png")
		hud.kingdom_panel.close()
		var d = JSON.parse_string(JSON.stringify(wev.export_state()))
		var n0: int = wev.sick().size()
		for vv in wev.sick():
			vv.remove_meta("malade")
		wev.import_state(d)
		start("ep2")
	if later("ep2", 300):
		check("malades rechargés", wev.sick().size() >= 1)
		var g0 := gold()
		wev.cure()
		check("tous soignés, récompense", wev.sick().is_empty() and not wev.is_active() and gold() > g0)
		print("== tournoi")
		wev.start("tournoi")
		var a: Vector3 = wev.arena_pos()
		p.global_position = Vector3(a.x, w.ground_height_at(a + Vector3(0, 4, 0)), a.z + 2)
		start("t1")
	if later("t1", 1500):
		var c = wev._challenger
		check("1er champion : %s" % (c.data.display_name if c else "-"), c != null and c.data.display_name == "Borgak l'Invaincu")
		shot("03_tournoi.png")
		c.health.take_damage(c.health.current + 9999, p)
		start("t2")
	if later("t2", 1500):
		var c = wev._challenger
		check("2e champion : %s" % (c.data.display_name if c else "-"), c != null and int(wev.current.round) == 1)
		c.health.take_damage(c.health.current + 9999, p)
		start("t3")
	if later("t3", 1500):
		var c = wev._challenger
		check("3e champion : %s" % (c.data.display_name if c else "-"), c != null and int(wev.current.round) == 2)
		c.health.take_damage(c.health.current + 9999, p)
		start("t4")
	if later("t4", 800):
		check("tournoi gagné (+1 attaque)", not wev.is_active() and p.souls.has("tournoi"))
		print("== invasion")
		wev.start("invasion")
		check("la horde de la Brume arrive : %s" % rm.raid.get("name", "-"), rm.raid.get("story", "") == "evt_brume")
		rm._start()
		start("inv")
	if later("inv", 800):
		var rs: Array = rm.raid.raiders
		check("pillards brumeux : %s" % rs[0].name_label.text, rs[0].name_label.text.begins_with("Brumeux"))
		shot("04_invasion.png")
		for e in rs:
			if is_instance_valid(e):
				e.health.take_damage(e.health.current + 9999, p)
		start("inv2")
	if later("inv2", 2500):
		check("invasion repoussée : fragments de Brume", not wev.is_active() and p.inventory.count(items.get_item("fragment_brume")) >= 4)
		print("RÉSULTAT : " + ("tout est bon" if ok else "ÉCHECS"))
		return true
	return f > 30000
