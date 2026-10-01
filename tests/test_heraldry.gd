extends SceneTree
var f := 0
var p; var w; var items; var dip; var hud; var rm; var tr
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/hr_"

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

var her

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p: p._invulnerable_left = 5.0
	if f == 10:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		hud = get_first_node_in_group("hud"); rm = get_first_node_in_group("raids")
		her = get_first_node_in_group("heraldry")
		rm.enabled = false
		start("a")
	if later("a", 2500):
		print("== étendards")
		var bs = get_nodes_in_group("banners")
		check("4 étendards autour du village (%d)" % bs.size(), bs.size() >= 4)
		var c0: Color = bs[0]._cloth.albedo_color
		her.cycle("primary", 1)
		her.cycle("emblem", 2)
		check("couleur changée : %s -> %s" % [c0.to_html(false), bs[0]._cloth.albedo_color.to_html(false)], bs[0]._cloth.albedo_color != c0 and bs[0]._cloth.albedo_color == her.primary_color())
		check("emblème : %s" % bs[0]._labels[0].text, bs[0]._labels[0].text == her.emblem_char())
		her.set_kingdom_name("Royaume d'Émeraude")
		var k = get_first_node_in_group("kingdom")
		check("nom du royaume : %s" % k.title(), k.title().begins_with("Royaume d'Émeraude"))
		print("== étendard posé")
		var c: Vector2i = w.spawn_cell + Vector2i(4, -4)
		var ok_place: bool = w.build.place_furniture(c, w.terrain_height(c), items.get_item("etendard"), 0)
		var n = w.build.furniture.values().filter(func(x): return x.item.id == "etendard")
		check("meuble Étendard posé aux couleurs du royaume", ok_place and not n.is_empty() and n[0].node._cloth.albedo_color == her.primary_color())
		check("recette de l'étendard", load("res://data/recipes/etendard.tres").result.id == "etendard")
		print("== trophées")
		p.souls["prairie"] = {}
		p.souls["foret"] = {}
		her._tick = 0.0
		start("b")
	if later("b", 1500):
		check("2 statues de boss (%s)" % [her.statues.keys()], her.statues.size() == 2)
		var center: Vector3 = w.cell_center(w.spawn_cell)
		var st: Node3D = her.statues.values()[0]
		var to: Vector3 = (center - st.global_position).normalized()
		p.global_position = st.global_position - to * 3.0
		p.global_position.y = w.ground_height_at(p.global_position + Vector3(0, 6, 0))
		p.cam_yaw = atan2(-to.x, -to.z) + PI
		p.cam_pitch = deg_to_rad(22.0)
		p.snap_camera()
		start("c")
	if later("c", 1500):
		shot("01_village.png")
		hud.heraldry_panel.open()
		start("d")
	if later("d", 700):
		shot("02_panneau.png")
		hud.heraldry_panel.close()
		var d = JSON.parse_string(JSON.stringify(her.export_state()))
		her.primary = 0; her.custom_name = ""
		her.import_state(d)
		check("bannière rechargée (%s, %s)" % [her.COLORS[her.primary][0], her.custom_name], her.custom_name == "Royaume d'Émeraude" and her.primary == 1)
		print("RÉSULTAT : " + ("tout est bon" if ok else "ÉCHECS"))
		return true
	return f > 30000
