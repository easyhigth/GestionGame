extends SceneTree
var f := 0
var p; var w; var items; var hud; var dip; var cs; var cl; var city; var kills := 0
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/cs_"

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

func view_at(pos: Vector3, yaw: float, pitch: float, zoom: float) -> void:
	p.cam_yaw = deg_to_rad(yaw); p.cam_pitch = deg_to_rad(pitch); p.camera_zoom = zoom; p.snap_camera()

func kill_all() -> int:
	var n := 0
	for e in cs._alive:
		if is_instance_valid(e) and e.is_alive():
			e.health.take_damage(999999, p); n += 1
	return n

## la caméra derrière le héros, tournée vers un point
func look_to(target: Vector3, pitch := 24.0, zoom := 1.4) -> void:
	var d: Vector3 = target - p.global_position
	view_at(p.global_position, rad_to_deg(atan2(-d.x, -d.z)), pitch, zoom)

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p: p._invulnerable_left = 5.0
	if f == 8:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		hud = get_first_node_in_group("hud"); dip = get_first_node_in_group("diplomacy")
		cs = get_first_node_in_group("city_siege"); cl = get_first_node_in_group("city_life")
		get_first_node_in_group("raids").enabled = false
		get_first_node_in_group("weather").set_kind("clair")
		get_first_node_in_group("day_cycle").hour = 10.0
		p.level = 12
		city = cs.city_of("karg")
		check("Gor-Karath existe", not city.is_empty())
		dip.act("karg", "war")
		check("en guerre avec Karg", dip.at_war("karg") and dip.block("karg", "siege") == "")
		# on s'approche en ennemi : des soldats gardent les portes
		get_first_node_in_group("command_console").run("/tp gor")
		start("war")
	if later("war", 2500):
		var soldiers = get_nodes_in_group("enemy_units").filter(func(e): return e.has_meta("city_guard"))
		print("   ville active : %d nœuds, ennemis : %d, état %s, joueur à %s" % [cl.active_count("karg"), get_nodes_in_group("enemy_units").size(), cl.state_of("karg"), p.global_position])
		check("en guerre : des soldats hostiles gardent les portes (%d)" % soldiers.size(), soldiers.size() >= 2)
		check("état « guerre »", cl.state_of("karg") == "guerre")
		var m = load("res://scripts/world/city_merchant.gd").new(get_first_node_in_group("trade"), city, "Forgeron", "Test", RandomNumberGenerator.new())
		check("en guerre, les marchands refusent (%s)" % m.refusal(), m.refusal() != "")
		shot("01_portes_gardees.png")
		for e in soldiers: e.queue_free()
		check("le siège commence dans la vraie ville", dip.start_siege("karg") and cs.active() and cs.nation == "karg")
		var d: float = Vector2(p.global_position.x - city.center.x, p.global_position.z - city.center.y).length()
		check("le héros arrive devant la grande porte (%.0f m du centre)" % d, d > city.radius and d < city.radius + 25)
		start("s1")
	if later("s1", 1500):
		check("les rues se vident pendant le siège (%d habitants)" % cl.active_count("karg"), cl.active_count("karg") == 0)
		cs._timer = 0.0
		start("w1")
	if later("w1", 1500):
		check("vague 1 : %d soldats sortent par la porte" % cs._alive.size(), cs.wave == 1 and cs._alive.size() == 6)
		var ctr: Vector3 = Vector3(city.center.x, p.global_position.y, city.center.y)
		look_to(ctr)
		shot("02_vague.png")
		kills += kill_all(); cs._timer = 0.0
		start("w2")
	if later("w2", 1500):
		check("vague 2 : %d soldats" % cs._alive.size(), cs.wave == 2 and cs._alive.size() == 8)
		kills += kill_all(); cs._timer = 0.0
		start("w3")
	if later("w3", 1500):
		check("vague 3 : %d soldats, dont leur chef" % cs._alive.size(), cs.wave == 3 and cs._alive.size() == 10)
		kills += kill_all(); cs._timer = 0.0
		start("sov")
	if later("sov", 1500):
		check("le souverain attend devant son palais", cs.sovereign != null and is_instance_valid(cs.sovereign))
		var b = cs.sovereign
		var hall: Vector2 = Vector2(city.center + city.hall)
		check("... au cœur de la ville", Vector2(b.global_position.x, b.global_position.z).distance_to(hall) < 4.0)
		# on traverse la ville jusqu'à lui
		p.global_position = b.global_position + Vector3(0, 0, 6)
		w.load_area(p.global_position)
		look_to(b.global_position, 18, 1.3)
		start("sov2")
	if later("sov2", 2500):
		shot("03_souverain.png")
		cs.sovereign.health.take_damage(99999999, p)
		start("won")
	if later("won", 2500):
		check("Karg annexée : %s" % dip.status("karg"), dip.annexed("karg") and not cs.active())
		check("la ville se repeuple (%d habitants)" % cl.active_count("karg"), cl.active_count("karg") > 30)
		check("état « province »", cl.state_of("karg") == "province")
		var banners = get_nodes_in_group("province_banners")
		check("ta bannière flotte sur la ville (%d étendards)" % banners.size(), banners.size() >= 4)
		var chest = get_nodes_in_group("world_chests").filter(func(c): return c.chest_id == "capital_karg")
		check("le trésor de la capitale devant le palais", chest.size() == 1 and not chest[0].opened)
		var gov = get_nodes_in_group("townsfolk").filter(func(t): return t.role == "lord" and t.display_name.begins_with("Gouverneur"))
		check("un gouverneur dirige la ville", gov.size() == 1)
		var m = load("res://scripts/world/city_merchant.gd").new(get_first_node_in_group("trade"), city, "Forgeron", "Test", RandomNumberGenerator.new())
		check("dans ta province, les marchands font -25 %%", m.refusal() == "" and is_equal_approx(m._rel_mult(true), 0.75))
		var g0: int = gold()
		p.global_position = chest[0].global_position + Vector3(1, 0, 0)
		chest[0].open(p)
		for it in w.get_node("Village").get_children():
			if it.has_method("take") and not it.is_taken() and it.global_position.distance_to(p.global_position) < 4.0:
				p.try_pickup(it)
		check("trésor récupéré (or %d -> %d)" % [g0, gold()], gold() > g0 + 300)
		p.global_position = (banners[banners.size() - 1] as Node3D).global_position + Vector3(0, 0, 7)
		look_to((banners[banners.size() - 1] as Node3D).global_position + Vector3(0, 2, 0), 12, 1.2)
		start("ban")
	if later("ban", 2000):
		shot("04_province.png")
		# un siège abandonné : on s'enfuit, la guerre continue
		dip.act("sylvae", "war")
		check("siège de Lothëlia", dip.start_siege("sylvae") and cs.nation == "sylvae")
		get_first_node_in_group("command_console").run("/tp village")
		start("flee")
	if later("flee", 1500):
		check("en s'éloignant, le siège est levé", not cs.active() and dip.at_war("sylvae") and not dip.annexed("sylvae"))
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	return false
