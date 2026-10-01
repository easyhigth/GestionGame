extends SceneTree
var HEADLESS := true
var f := 0
var p; var w; var bm; var bo; var items; var t0 := 0
var s: Vector2i; var H := 0
var ok := true

func check(name: String, cond: bool) -> void:
	print(("  OK  " if cond else "  ÉCHEC  ") + name)
	ok = ok and cond
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/g_"

func _initialize():
	var h = load("res://scripts/hero/hero_profile.gd").new()
	h.hero_name = "Selka"
	h.race = load("res://data/races/homme_bete.tres")
	h.style = 2
	h.skin_color = Color("d88a3a"); h.hair_color = Color("e8e0d0"); h.eye_color = Color("40e0a0")
	h.hero_class = load("res://data/classes/rodeur.tres")
	h.job = load("res://data/jobs/chasseur.tres")
	h.skill = load("res://data/skills/vorace.tres")
	root.get_node("GameState").hero = h
	root.get_node("GameState").world_seed = int(OS.get_environment("TEST_SEED")) if OS.get_environment("TEST_SEED") != "" else 4242
	change_scene_to_file("res://scenes/main.tscn")

func shot(n):
	if HEADLESS: return
	root.get_viewport().get_texture().get_image().save_png(out + n)
	print("saved ", n)

func wait_real(ms: int, back: int) -> bool:
	if not has_meta("t%d" % back): set_meta("t%d" % back, Time.get_ticks_msec())
	if Time.get_ticks_msec() - int(get_meta("t%d" % back)) < ms:
		f = back
		OS.delay_msec(8)
		return true
	return false

func plan(cat: int, tool: int, a: Vector2i, b: Vector2i, layer: int) -> void:
	bm.cat = cat; bm.tool_index = tool; bm.layer = layer
	bm._selection_from(a, b)
	bm._commit_selection()

func _process(_d) -> bool:
	f += 1
	if p:
		p._invulnerable_left = 5.0
	if f == 5:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		bm = p.get_node("BuildMode"); bo = get_first_node_in_group("build_orders")
		get_first_node_in_group("raids").enabled = false
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		s = w.spawn_cell + Vector2i(-1, 9)
		H = roundi(w.terrain_height(s))
		for x in range(-8, 9):
			for z in range(-3, 12):
				w.set_terrain_height(s + Vector2i(x, z), float(H))
		w.refresh_cells([s, s + Vector2i(8, 8), s + Vector2i(-8, 8)])
		p.inventory.add(items.get_item("bloc_planches"), 150)
		p.inventory.add(items.get_item("bloc_rondins"), 40)
		p.inventory.add(items.get_item("bloc_chaume"), 60)
		p.inventory.add(items.get_item("bloc_tuiles"), 30)
		# caméra de jeu tournée : vue de côté
		p.global_position = Vector3(s.x + 0.5, H, s.y - 1.5)
		p.cam_yaw = deg_to_rad(120.0)
		p.cam_pitch = deg_to_rad(32.0)
		p.snap_camera()
	if f == 40: shot("01_camera_tournee.png")
	if f == 42:
		w.build.place_block(Vector3i(s.x + 2, H, s.y - 2), items.get_item("bloc_rondins"))
		p.global_position = Vector3(s.x + 0.5, H, s.y - 1.5)
		p.cam_yaw = deg_to_rad(20.0)
		p.cam_pitch = deg_to_rad(30.0)
		p.facing = Vector3(1, 0, 0)
		p.snap_camera()
	if f == 46: p.jump()
	if f > 46 and f < 80:
		p.velocity = Vector3(2.2, 0, 0)
	if f == 55: shot("02_saut.png")
	# --- mode construction ---
	if f == 82:
		bm.toggle(true)
		bm._focus = Vector3(s.x + 0.5, H, s.y + 4.5)
		bm._yaw = deg_to_rad(25.0)
		bm._pitch = deg_to_rad(52.0)
		bm._dist = 20.0
		bm.layer = H
		bm._set_category(1)
		# tracé en cours (aperçu vert)
		bm._dragging = true
		bm._drag_from = s + Vector2i(-3, 2)
	if f > 82 and f < 100:
		var target := Vector3(s.x + 3.5, H, s.y + 7.5)
		Input.warp_mouse(bm._cam.unproject_position(target))
		root.get_viewport().warp_mouse(bm._cam.unproject_position(target))
	if f == 98:
		shot("03_trace_piece.png")
		print("tracé: ", bm._selection.size(), " blocs ; curseur ", bm._cursor - s)
		bm._dragging = false
	if f == 100:
		bm._selection = []
		plan(1, 0, s + Vector2i(-3, 2), s + Vector2i(3, 7), H)
		plan(4, 0, s + Vector2i(0, 2), s + Vector2i(0, 2), H)
		plan(4, 1, s + Vector2i(-2, 2), s + Vector2i(-2, 2), H)
		plan(4, 1, s + Vector2i(2, 2), s + Vector2i(2, 2), H)
		plan(2, 0, s + Vector2i(-2, 3), s + Vector2i(2, 6), H)
		bm.cat = 5
		bm.furniture_index = bm._furniture_items.find(items.get_item("lit")); plan(5, 0, s + Vector2i(-2, 6), s + Vector2i(-2, 6), H + 1)
		bm.furniture_index = bm._furniture_items.find(items.get_item("coffre")); plan(5, 0, s + Vector2i(2, 6), s + Vector2i(2, 6), H + 1)
		bm.furniture_index = bm._furniture_items.find(items.get_item("table")); plan(5, 0, s + Vector2i(1, 4), s + Vector2i(1, 4), H + 1)
		bm.furniture_index = bm._furniture_items.find(items.get_item("torche")); plan(5, 0, s + Vector2i(-2, 3), s + Vector2i(-2, 3), H + 1)
		bm.materials["roofs"] = "bloc_chaume"
		plan(3, 0, s + Vector2i(-3, 2), s + Vector2i(3, 7), H + 3)
		# récolte autour
		plan(0, 0, w.spawn_cell + Vector2i(-18, 14), w.spawn_cell + Vector2i(18, 24), H)
		bm.layer = H
		bm._set_category(1)
		print("plans: ", bo.orders.size(), " bâtisseurs: ", bo.builders().size())
		check("plans de construction posés (%d)" % bo.orders.size(), bo.orders.size() > 20)
	if f == 110:
		shot("04_plans.png")
		if HEADLESS:
			bm._instant_cb.button_pressed = true
			var left := {}
			for o in bo.orders.values():
				if o.type != "harvest":
					var why := "matériaux" if not bo._has_material(o) else ("pas prêt" if not bo.ready_to_build(o) else "?")
					left[o.type + ":" + why] = int(left.get(o.type + ":" + why, 0)) + 1
			print("reste après instantané: ", left)
			var k = get_first_node_in_group("kingdom")
			k.recompute()
			for r in k.rooms:
				print("pièce: ", r.cells.size(), " fermée=", r.enclosed, " portes=", r.doors, " type=", r.type.display_name if r.type else "-", " meubles=", r.counts, " sol=", r.floor)
			print("H=", H, " porte meuble: ", w.build.furniture.values().map(func(x): return [x.item.id, x.col - s, x.base]))
			check("construction instantanée : blocs posés (%d)" % w.build.blocks.size(), w.build.blocks.size() > 30)
			check("une pièce fermée avec une porte reconnue", k.rooms.any(func(r): return r.enclosed and r.doors > 0))
			print("RÉSULTAT : " + ("tout est bon" if ok else "ÉCHECS"))
			return true
	if f == 112:
		t0 = Time.get_ticks_msec()
	if f == 114:
		if wait_real(28000, 113): pass
	if f == 115:
		bm._set_category(0)
		shot("05_habitants_construisent.png")
		print("après 28 s: plans restants ", bo.orders.size(), " blocs ", w.build.blocks.size())
	if f == 117:
		if wait_real(60000, 116): pass
	if f == 118:
		print("après 88 s: plans restants ", bo.orders.size(), " blocs ", w.build.blocks.size())
		shot("05b_habitants_construisent.png")
		# on finit d'un coup pour la démonstration
		bm._instant_cb.button_pressed = true
	if f == 120:
		print("construction terminée en ", (Time.get_ticks_msec() - t0) / 1000, " s ; blocs ", w.build.blocks.size(), " plans restants ", bo.orders.size())
		bm._set_category(5)
		bm.cut_on = true
		bm.layer = H + 1
		bm._refresh_ui()
	if f == 130: shot("06_interieur_coupe.png")
	if f == 132:
		bm.toggle(false)
		var k = get_first_node_in_group("kingdom")
		k.recompute()
		print("pièces: ", k.typed_rooms().map(func(r): return r.type.display_name))
		p.global_position = Vector3(s.x + 0.5, H, s.y - 2.5)
		p.cam_yaw = deg_to_rad(-35.0)
		p.cam_pitch = deg_to_rad(28.0)
		p.snap_camera()
	if f == 150:
		shot("07_maison_finie.png")
		return true
	return false
