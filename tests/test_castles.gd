extends SceneTree
var f := 0
var p; var w; var items; var hud; var ab; var inh; var wr
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/ch_"

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


func view(at: Vector3, yaw: float, pitch: float, zoom: float) -> void:
	p.global_position = at
	p.cam_yaw = deg_to_rad(yaw); p.cam_pitch = deg_to_rad(pitch); p.camera_zoom = zoom; p.snap_camera()

func center_of(st) -> Vector3:
	var c: Vector2i = st.cell + (Vector2i(10, 10) if st.kind == "castle" else Vector2i(1, 6))
	return Vector3(c.x + 0.5, float(st.base), c.y + 0.5)

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p: p._invulnerable_left = 5.0
	if f == 8:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		get_first_node_in_group("raids").enabled = false
		get_first_node_in_group("weather").set_kind("clair")
		get_first_node_in_group("day_cycle").hour = 10.0
		var castles: Array = w.structure_sites.filter(func(s): return s.kind == "castle")
		var wrecks: Array = w.structure_sites.filter(func(s): return s.kind == "wreck")
		print("   châteaux : %d (abandonnés %d), épaves : %d" % [castles.size(), castles.filter(func(s): return s.abandoned).size(), wrecks.size()])
		check("des châteaux forts dans le monde (%d)" % castles.size(), castles.size() >= 6)
		check("certains abandonnés, d'autres habités", castles.any(func(s): return s.abandoned) and castles.any(func(s): return not s.abandoned))
		check("des épaves sur les côtes (%d)" % wrecks.size(), wrecks.size() >= 4)
		ab = castles.filter(func(s): return s.abandoned)[0]
		inh = castles.filter(func(s): return not s.abandoned)[0]
		wr = wrecks[0]
		var n: int = 0
		for k in w.build.blocks:
			if k.x >= ab.cell.x and k.x < ab.cell.x + 21 and k.z >= ab.cell.y and k.z < ab.cell.y + 21: n += 1
		check("le château est en blocs (%d)" % n, n > 600)
		var cp := center_of(ab)
		w.load_area(cp)
		view(cp + Vector3(0, 0, 14), 0, 40, 3.0)
		start("a")
	if later("a", 3000):
		shot("01_chateau_abandonne.png")
		var cp := center_of(ab)
		var undead = get_nodes_in_group("enemy_units").filter(func(e): return e.global_position.distance_to(cp) < 16.0)
		check("des morts-vivants hantent le château abandonné (%d)" % undead.size(), undead.filter(func(e): return e.data.display_name.to_lower().contains("squelette")).size() >= 3)
		for e in undead: e.queue_free()
		var chest = get_nodes_in_group("world_chests").filter(func(c): return c.chest_id == ab.id)
		check("un trésor dans le donjon", chest.size() == 1)
		p.global_position = chest[0].global_position + Vector3(1.0, 0, 0)
		var g0: int = gold()
		var ev := InputEventAction.new(); ev.action = "interact"; ev.pressed = true
		p._unhandled_input(ev)
		for it in w.get_node("Village").get_children():
			if it.has_method("take") and not it.is_taken() and it.global_position.distance_to(p.global_position) < 4.0:
				p.try_pickup(it)
		check("trésor récupéré (or %d -> %d)" % [g0, gold()], gold() > g0 and chest[0].opened)
		var ip := center_of(inh)
		w.load_area(ip)
		view(ip + Vector3(0, 0, 13), 10, 38, 3.0)
		start("b")
	if later("b", 3000):
		shot("02_chateau_habite.png")
		var ip := center_of(inh)
		var folk = get_nodes_in_group("townsfolk").filter(func(t): return t.global_position.distance_to(ip) < 20.0)
		check("une garnison et son seigneur (%d)" % folk.size(), folk.size() >= 5 and folk.any(func(t): return t.role == "lord"))
		var lord = folk.filter(func(t): return t.role == "lord")[0]
		p.global_position = lord.global_position + Vector3(1.0, 0, 0)
		lord.talk(p)
		check("le seigneur parle (« %s »)" % lord._bubble.text, lord._bubble.visible and lord._bubble.text != "")
		var wp := center_of(wr)
		w.load_area(wp)
		view(wp + Vector3(4, 0, 8), 30, 35, 1.8)
		start("c")
	if later("c", 3000):
		shot("03_epave.png")
		var chest = get_nodes_in_group("world_chests").filter(func(c): return c.chest_id == wr.id)
		check("un coffre dans l'épave", chest.size() == 1)
		root.get_node("SaveGame").save_game("3")
		root.get_node("SaveGame").load_game("3")
		start("d")
	if later("d", 3000):
		w = get_first_node_in_group("world")
		check("rechargé : le trésor du château reste vide", w.opened_chests.has(ab.id))
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	return false
