extends SceneTree
var f := 0
var p; var w; var items; var vn; var k; var dc; var hud; var st; var fam; var mo
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/fa_"
var foe
var wait_at: Vector3

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

func view(yaw, pitch, zoom) -> void:
	p.cam_yaw = deg_to_rad(yaw); p.cam_pitch = deg_to_rad(pitch); p.camera_zoom = zoom; p.snap_camera()

func spawn_enemy(id: String, pos: Vector3, lv := 3):
	var e = load("res://scenes/enemies/enemy.tscn").instantiate()
	e.data = load("res://data/enemies/%s.tres" % id)
	e.level = lv
	w.get_node("Village").add_child(e)
	e.global_position = pos
	e.home = pos
	return e

func tame(id: String):
	var e = spawn_enemy(id, p.global_position + Vector3(2, 0.5, 0))
	e.health.current = roundi(e.health.max_health * 0.2)
	return fam.try_interact(p)

func ground(v: Vector3) -> Vector3:
	v.y = w.ground_height_at(v + Vector3(0, 20, 0))
	return v

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p: p._invulnerable_left = 5.0
	if f == 10:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		vn = get_first_node_in_group("village_needs"); k = get_first_node_in_group("kingdom")
		dc = get_first_node_in_group("day_cycle"); hud = get_first_node_in_group("hud")
		st = get_first_node_in_group("story"); fam = get_first_node_in_group("familiars_mgr"); mo = get_first_node_in_group("mounts")
		get_first_node_in_group("raids").enabled = false
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		get_first_node_in_group("quests")._offer_timer = 9999.0
		get_first_node_in_group("weather").set_kind("clair")
		dc.hour = 11.0
		st.step = st.index_of("grik")
		st._spawn_npcs()
		p.global_position = ground(w.cell_center(w.spawn_cell) + Vector3(12, 0, 12))
		print("== apprivoiser et évoluer")
		check("loup apprivoisé", tame("loup") and fam.list.size() == 1 and fam.list[0].place == "equipe")
		start("a")
	if later("a", 300):
		fam.list[0].evo = 1
		fam._refresh(fam.list[0])
		var n = fam.list[0].node
		print("   modèle : ", n.visual.model.resource_path)
		check("modèle 3D du familier évolué (wolf_evo1)", n.visual.model.resource_path.ends_with("wolf_evo1.glb"))
		print("== ordres")
		check("P : attendez ici", fam.cycle_order() == "attendre")
		wait_at = p.global_position
		p.global_position = ground(p.global_position + Vector3(12, 0, 0))
		start("b")
	if later("b", 2500):
		var n = fam.list[0].node
		check("il attend à sa place (%.1f m de là)" % n.global_position.distance_to(wait_at), n.global_position.distance_to(wait_at) < 4.0)
		check("P : attaquez ma cible", fam.cycle_order() == "attaquer")
		foe = spawn_enemy("sanglier", p.global_position + Vector3(-4, 0.5, 4), 2)
		p.lock_target = foe
		start("c")
	if later("c", 1500):
		var n = fam.list[0].node
		check("il attaque la cible du héros", n._target == foe)
		foe.queue_free()
		check("P : suivez-moi", fam.cycle_order() == "suivre")
		start("d")
	if later("d", 2500):
		var n = fam.list[0].node
		check("il suit à nouveau (%.1f m)" % n.global_position.distance_to(p.global_position), n.global_position.distance_to(p.global_position) < 5.0)
		print("== monture")
		p.global_position = n.global_position + Vector3(1, 0, 0)
		check("E près du loup : on le monte", mo.try_interact(p) and mo.is_riding() and mo.mount == n)
		check("plus rapide (×%.1f)" % mo.speed_mult(), mo.speed_mult() > 1.5)
		view(40, 18, 0.8)
		start("e")
	if later("e", 600):
		shot("01_monture.png")
		var n = fam.list[0].node
		p.global_position += Vector3(3, 0, 0)
		mo._process(0.05)
		check("le loup reste sous le héros", n.global_position.distance_to(p.global_position) < 0.2)
		check("E : on descend", mo.try_interact(p) and not mo.is_riding() and not n.has_meta("ridden"))
		print("== village")
		for i in 3: tame("loup")
		check("4 familiers : le 4e part au village", fam.list.size() == 4 and fam.team().size() == 3 and fam.village_list().size() == 1)
		start("f")
	if later("f", 800):
		var v = fam.village_list()[0]
		var c: Vector3 = w.cell_center(w.spawn_cell)
		check("il vit près du feu de camp (%.1f m)" % v.node.global_position.distance_to(c), v.node.global_position.distance_to(c) < 12.0 and v.node.familiar_order == "village")
		check("rappel impossible (déjà 3 avec moi)", not fam.set_place(v, "equipe"))
		var r = fam.team()[2]
		fam.release(r)
		check("libérer : 3 familiers", fam.list.size() == 3)
		check("rappel du village", fam.set_place(v, "equipe") and fam.team().size() == 3)
		hud.kingdom_panel.open()
		start("g")
	if later("g", 700):
		shot("02_panneau.png")
		hud.kingdom_panel.close()
		fam.set_place(fam.list[1], "village")
		root.get_node("SaveGame").save_game("3")
		root.get_node("SaveGame").load_game("3")
		start("h")
	if later("h", 2500):
		fam = get_first_node_in_group("familiars_mgr")
		check("rechargés : %s" % fam.summary(), fam.list.size() == 3 and fam.village_list().size() == 1 and fam.list[0].evo == 1)
		start("i")
	if later("i", 800):
		check("tous revenus", fam.list.all(func(x): return x.node != null and is_instance_valid(x.node)))
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	return false
