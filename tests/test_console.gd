extends SceneTree
var f := 0
var p; var w; var items; var hud; var con; var t0 := 0
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/co_"

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
	if has_meta(key + "_done"): remove_meta(key + "_done")

func gold() -> int:
	return p.inventory.count(items.get_item("piece_or"))

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if f == 8:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		hud = get_first_node_in_group("hud"); con = get_first_node_in_group("command_console")
		get_first_node_in_group("raids").enabled = false
		get_first_node_in_group("weather").set_kind("clair")
		get_first_node_in_group("day_cycle").hour = 10.0
		check("le terminal existe", con != null)
		# Entrée ouvre la ligne de commande
		var ev := InputEventKey.new(); ev.keycode = KEY_ENTER; ev.pressed = true
		con._unhandled_input(ev)
		check("Entrée ouvre le terminal", con.is_open() and p.ui_open)
		con._on_submit("/aide")
		check("/aide liste les commandes, puis la ligne se ferme", con._lines.size() > 15 and not con.is_open() and not p.ui_open)
		var ev2 := InputEventKey.new(); ev2.keycode = KEY_SLASH; ev2.unicode = 47; ev2.pressed = true
		con._unhandled_input(ev2)
		check("« / » ouvre le terminal avec un /", con.is_open() and con._input.text == "/")
		start("aide")
	if later("aide", 400):
		shot("01_aide.png")
		con._on_submit("/donner épée en fer 2")
		var sw = items.get_item("sword_iron")
		check("/donner épée en fer 2", p.inventory.count(sw) >= 2)
		var g0: int = p.inventory.count(items.get_item("piece_or"))
		check("/or 500", con.run("/or 500") and p.inventory.count(items.get_item("piece_or")) == g0 + 500)
		check("/donner objet inconnu : refusé", not con.run("/donner licorne_magique"))
		check("commande inconnue : refusée", not con.run("/danser"))
		check("/tp 300 400", con.run("/tp 300 400") and absf(p.global_position.x - 300.5) < 1.0 and absf(p.global_position.z - 400.5) < 1.0)
		check("/tp minas", con.run("/tp minas"))
		var mc = w.cities.filter(func(c): return c.nation == "cendres")[0]
		var d := Vector2(p.global_position.x - mc.center.x, p.global_position.z - mc.center.y).length()
		check("devant Minas Cendrys (%.0f m du centre)" % d, d < mc.radius + 10 and d > mc.radius - 15)
		p.cam_pitch = deg_to_rad(28); p.camera_zoom = 1.6; p.cam_yaw = atan2(p.global_position.x - mc.center.x, p.global_position.z - mc.center.y); p.snap_camera()
		start("tp")
	if later("tp", 3000):
		shot("02_tp_minas.png")
		check("/carte", con.run("/carte") and con.revealing())
		t0 = Time.get_ticks_msec()
		start("map")
	if has_meta("map") and not has_meta("map_done") and not con.revealing():
		set_meta("map_done", true)
		var secs := (Time.get_ticks_msec() - t0) / 1000.0
		var all := true
		for c in [Vector2i(1, 1), Vector2i(w.world_size.x - 2, w.world_size.y - 2), Vector2i(w.world_size.x - 2, 3), Vector2i(700, 900)]:
			if not w.is_revealed(c): all = false
		print("   calcul : %.1f s sur %d images" % [con.reveal_usec / 1e6, con.reveal_frames])
		check("toute la carte dévoilée en %.1f s" % secs, all and w.zones.all(func(z): return z.discovered))
		var mcv = get_first_node_in_group("mountain_caves")
		var caves: int = mcv._entrances.values().filter(func(e): return not e.is_empty()).size()
		check("entrées de grottes repérées (%d)" % caves, caves > 20)
		hud.map_ui.open()
		start("map2")
	if later("map2", 800):
		shot("03_carte_entiere.png")
		var mc = w.cities.filter(func(c): return c.nation == "cendres")[0]
		hud.map_ui.zoom = 3.0
		hud.map_ui.center = Vector2(mc.center)
		hud.map_ui.queue_redraw()
		start("map3")
	if later("map3", 600):
		shot("04_carte_zoom.png")
		hud.map_ui.close()
		check("/tp grotte", con.run("/tp grotte"))
		var mcv = get_first_node_in_group("mountain_caves")
		var near: Array = mcv.entrances_near(p.global_position, 1)
		check("près d'une entrée de grotte", near.any(func(e): return (e.pos as Vector3).distance_to(p.global_position) < 4.0))
		check("/tp château", con.run("/tp château"))
		check("près d'un château", w.structure_sites.any(func(s): return s.kind == "castle" and Vector2(s.cell + Vector2i(10, 10)).distance_to(Vector2(p.global_position.x, p.global_position.z)) < 22.0))
		check("/tp épave", con.run("/tp épave"))
		check("/tp village", con.run("/tp village") and Vector2(w.spawn_cell).distance_to(Vector2(p.global_position.x, p.global_position.z)) < 10.0)
		# triches
		check("/dieu", con.run("/dieu") and p.cheat_god)
		p.health.take_damage(99999, null)
		start("god")
	if later("god", 300):
		check("invincible : toujours en vie (%d PV)" % p.health.current, p.health.current > 0)
		con.run("/dieu")
		check("/vitesse 3", con.run("/vitesse 3") and is_equal_approx(p.cheat_speed, 3.0))
		con.run("/vitesse 1")
		check("/heure 22", con.run("/heure 22") and absf(get_first_node_in_group("day_cycle").hour - 22.0) < 0.1)
		check("/meteo pluie", con.run("/météo pluie") and get_first_node_in_group("weather").kind == "pluie")
		con.run("/meteo clair"); con.run("/heure 11")
		var lv0: int = p.level
		check("/niveau %d" % (lv0 + 3), con.run("/niveau %d" % (lv0 + 3)) and p.level == lv0 + 3)
		check("/obelisques", con.run("/obelisques") and w.zones.all(func(z): return z.obelisk_on or (z.obelisk as Vector2i).x < 0))
		var y0: float = p.global_position.y
		set_meta("y0", y0)
		check("/vol", con.run("/vol") and p.cheat_fly)
		Input.action_press("jump")
		start("fly")
	if later("fly", 1000):
		Input.action_release("jump")
		check("en vol, on monte (%.1f m)" % (p.global_position.y - get_meta("y0", 0.0)), p.global_position.y - get_meta("y0", 0.0) > 4.0)
		check("/vol : on atterrit", con.run("/vol") and not p.cheat_fly)
		var n0: int = p.inventory.count(items.get_item("epee_mithril"))
		check("/kit : équipement de mithril", con.run("/kit") and p.inventory.count(items.get_item("epee_mithril")) == n0 + 1)
		var e0: int = get_nodes_in_group("enemy_units").size()
		check("/invoquer loup 3", con.run("/invoquer loup 3"))
		set_meta("e0", e0)
		start("summ")
	if later("summ", 300):
		check("3 loups sont apparus", get_nodes_in_group("enemy_units").size() >= get_meta("e0") + 3)
		check("/invoquer chef des bandits", con.run("/invoquer chef des bandits"))
		check("/invoquer monstre inconnu : refusé", not con.run("/invoquer licorne"))
		con.run("/tuer")
		check("/lieux", con.run("/lieux"))
		check("/pos", con.run("/pos"))
		con.open("")
		start("fin")
	if later("fin", 400):
		shot("05_terminal.png")
		con.close()
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	return false
