extends SceneTree
var f := 0
var p; var w; var items; var hb
var s: Vector2i; var H := 0
var ok := true
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/m_"

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

func select(id: String) -> void:
	for i in 40:
		if hb.selected == id:
			return
		hb.cycle(1)

func collect() -> void:
	for n in w.get_node("Village").get_children():
		if n.has_method("take") and not n.is_taken() and n.global_position.distance_to(p.global_position) < 6.0:
			p.try_pickup(n)

func stand(cell: Vector2i, face: Vector3) -> void:
	var c: Vector3 = w.cell_center(cell)
	p.global_position = Vector3(c.x, float(H), c.z)
	p.facing = face
	p.velocity = Vector3.ZERO

func _process(_d) -> bool:
	f += 1
	if p: p._invulnerable_left = 5.0
	if f == 8:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		hb = p.hand
		get_first_node_in_group("raids").enabled = false
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		# un terrain plat et dégagé à côté du village
		s = w.spawn_cell + Vector2i(-1, 10)
		H = roundi(w.terrain_height(s))
		var cells := []
		for x in range(-6, 7):
			for z in range(-2, 9):
				w.set_terrain_height(s + Vector2i(x, z), float(H)); w.remove_decor(s + Vector2i(x, z)); cells.append(s + Vector2i(x, z))
		w.refresh_cells(cells)
		# une fosse devant pour tester le pont
		for z in range(4, 7):
			w.set_terrain_height(s + Vector2i(3, z), float(H) - 2.0)
		w.refresh_cells([s + Vector2i(3, 4), s + Vector2i(3, 5), s + Vector2i(3, 6)])
		print("== choix")
		check("mains nues au départ", hb.selected == "")
		hb.cycle(1)
		check("C choisit un objet posable (%s)" % hb.selected, hb.selected != "" and items.get_item(hb.selected).is_placeable())
		select("bloc_planches")
		check("planches choisies", hb.selected == "bloc_planches")
		print("== pose")
		stand(s, Vector3(1, 0, 0))
		var n0 := count("bloc_planches")
		var placed := []
		for i in 4:
			hb._target = {}
			var t: Dictionary = hb.find_spot(items.get_item("bloc_planches"))
			var done: bool = hb.place()
			placed.append([done, t.key - Vector3i(s.x, H, s.y) if not t.is_empty() else null])
		print("   poses : ", placed)
		check("3 planches empilées devant (pieds, +1, +2)", placed[0][0] and placed[1][0] and placed[2][0] and placed[0][1] == Vector3i(1, 0, 0) and placed[2][1] == Vector3i(1, 2, 0))
		check("4e refusée (trop haut)", not placed[3][0])
		check("planches retirées du sac (-3)", n0 - count("bloc_planches") == 3)
		# pont au-dessus de la fosse
		stand(s + Vector2i(2, 5), Vector3(1, 0, 0))
		hb._target = {}
		var tb: Dictionary = hb.find_spot(items.get_item("bloc_planches"))
		check("devant une fosse : un cran plus bas (pont) %s" % str(tb.key - Vector3i(s.x, H, s.y)), tb.ok and tb.key.y == H - 1)
		hb.place()
		# meuble : une torche
		select("torche")
		stand(s + Vector2i(0, 2), Vector3(0, 0, 1))
		hb._target = {}
		check("torche posée à la main", hb.place() and w.build.furniture_in(s + Vector2i(0, 3)).size() == 1)
		print("== casse")
		stand(s, Vector3(1, 0, 0))
		var pl := count("bloc_planches")
		# un coup d'arme ne casse plus un bloc posé (en combat, on ne démolit rien par erreur)
		for i in 3:
			p._harvest_swing({"dmg": 1.0})
		check("trois coups d'arme : le bloc tient", w.build.block_at(Vector3i(s.x + 1, H, s.y)) != null)
		# attaque maintenue dessus : il se casse au bout du temps de minage, comme dans Minecraft
		var held_t := 0.0
		while w.build.block_at(Vector3i(s.x + 1, H, s.y)) != null and held_t < 6.0:
			p.mine_step(0.05, true)
			held_t += 0.05
		p.mine_step(0.05, false)
		collect()
		check("bloc miné en %.2f s (attaque maintenue) et rendu" % held_t, held_t > 0.3 and held_t < 2.0 and count("bloc_planches") == pl + 1)
		# un ennemi tout près : pas de casse
		var scene := load("res://scenes/enemies/enemy.tscn") as PackedScene
		var e = scene.instantiate()
		e.data = load("res://data/enemies/%s" % DirAccess.get_files_at("res://data/enemies/")[0].trim_suffix(".remap"))
		w.add_child(e)
		e.global_position = p.global_position + Vector3(0, 0, -3)
		set_meta("e", e)
		set_meta("t", Time.get_ticks_msec())
	if has_meta("t") and not has_meta("t_done") and Time.get_ticks_msec() - int(get_meta("t")) > 300:
		set_meta("t_done", true)
		p.global_position = w.cell_center(s) + Vector3(0, float(H) - w.cell_center(s).y, 0)
		p.facing = Vector3(1, 0, 0)
		for i in 4:
			p._harvest_swing({"dmg": 1.0})
		for i in 60:
			p.mine_step(0.05, true)
		p.mine_step(0.05, false)
		check("avec un ennemi tout près, le mur ne casse pas", w.build.block_at(Vector3i(s.x + 1, H + 1, s.y)) != null)
		(get_meta("e") as Node).queue_free()
		# pose pour la capture
		select("bloc_planches")
		stand(s + Vector2i(-2, 1), Vector3(0, 0, 1))
		p.cam_yaw = deg_to_rad(150.0); p.cam_pitch = deg_to_rad(32.0); p.camera_zoom = 0.9
		p.snap_camera()
		set_meta("t2", Time.get_ticks_msec())
	if has_meta("t2") and not has_meta("t2_done") and Time.get_ticks_msec() - int(get_meta("t2")) > 400:
		set_meta("t2_done", true)
		shot("01_pose_a_la_main.png")
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	return false
