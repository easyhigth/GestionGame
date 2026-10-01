extends SceneTree
var f := 0
var p; var w; var items; var hud; var mc; var ent; var ore_key; var got0 := 0
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/cv_"

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


func count(id: String) -> int:
	return p.inventory.count(items.get_item(id))

func view(yaw: float, pitch: float, zoom: float) -> void:
	p.cam_yaw = deg_to_rad(yaw); p.cam_pitch = deg_to_rad(pitch); p.camera_zoom = zoom; p.snap_camera()

func collect() -> void:
	for n in mc._content.get_children():
		if n.has_method("take") and not n.is_taken() and n.global_position.distance_to(p.global_position) < 5.0:
			p.try_pickup(n)

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p: p._invulnerable_left = 5.0
	if f == 8:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		hud = get_first_node_in_group("hud"); mc = get_first_node_in_group("mountain_caves")
		get_first_node_in_group("raids").enabled = false
		get_first_node_in_group("weather").set_kind("clair")
		get_first_node_in_group("day_cycle").hour = 10.0
		print("== entrées de grottes")
		check("système des grottes de montagne présent", mc != null)
		# une entrée dans une région de montagne
		var found := []
		for z in w.zones:
			if z.type == null or not (z.type.id in ["montagnes", "toundra", "volcan"]): continue
			for e in mc.entrances_near(w.cell_center(Vector2i(z.site)), 4):
				found.append(e)
			if found.size() >= 3: break
		print("   entrées trouvées : ", found.size())
		check("des grottes au pied des falaises (%d)" % found.size(), found.size() >= 2)
		ent = found[0]
		w.load_area(ent.pos)
		p.global_position = ent.pos + Vector3(ent.dir.x, 0, ent.dir.y) * -1.2
		p.global_position.y = w.ground_height_at(p.global_position + Vector3(0, 30, 0))
		mc._tick = 0.0
		mc._process(0.1)
		view(rad_to_deg(atan2(-ent.dir.x, -ent.dir.y)) + 180.0, 28, 1.3)
		start("a")
	if later("a", 2000):
		check("bouche de grotte affichée", mc._entrance_nodes.has(ent.id))
		shot("01_entree.png")
		check("E : on entre", mc.try_interact(p))
		start("b")
	if later("b", 1500):
		check("dans la grotte (niveau 1)", mc.active and mc.level == 1 and p.global_position.y < -200.0)
		var g = w.dungeon_grid
		check("parois en blocs (%d)" % g.blocks.size(), g.blocks.size() > 400)
		var monsters = mc._content.get_children().filter(func(n): return n.is_in_group("enemy_units"))
		check("des monstres rôdent (%d)" % monsters.size(), monsters.size() >= 4)
		for m in monsters: m.queue_free()
		var kinds: Dictionary = {}
		for k in g.blocks: kinds[g.blocks[k].id] = int(kinds.get(g.blocks[k].id, 0)) + 1
		print("   blocs : ", kinds)
		check("filons de fer dans les parois", kinds.get("bloc_minerai_fer", 0) > 5)
		# le filon de fer le plus proche
		var best: float = INF
		for k in g.blocks:
			if g.blocks[k].id == "bloc_minerai_fer" and k.y == mc.FLOOR_Y:
				var d: float = Vector2(k.x + 0.5 - p.global_position.x, k.z + 0.5 - p.global_position.z).length()
				if d < best: best = d; ore_key = k
		# on se place devant, face au filon
		var c := Vector2i(ore_key.x, ore_key.z)
		var stand := c
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if mc._open.has(c + dd): stand = c + dd
		p.global_position = mc.floor_pos(stand)
		p.facing = Vector3(c.x - stand.x, 0, c.y - stand.y)
		p.inventory.add(items.get_item("pioche_pierre"), 1)
		got0 = count("iron_ore")
		var H = load("res://scripts/world/harvest.gd")
		var t: Dictionary = H.find_target(p, 1.6, true)
		check("la paroi devant est visée (%s)" % str(t), t.has("block"))
		for i in 15:
			if g.block_at(ore_key) == null: break
			H.hit_built(w, {"block": ore_key}, 1.0, p)
		check("filon creusé à la pioche", g.block_at(ore_key) == null and mc._open.has(c))
		collect()
		check("minerai de fer récupéré (%d -> %d)" % [got0, count("iron_ore")], count("iron_ore") > got0)
		var behind := c + (c - stand)
		check("la roche continue derrière (on peut percer des galeries)", g.block_at(Vector3i(behind.x, mc.FLOOR_Y, behind.y)) != null)
		view(30, 55, 1.6)
		start("c")
	if later("c", 1500):
		shot("02_grotte.png")
		# descendre
		var down = mc._interactables.filter(func(i): return i.kind == "down")[0]
		p.global_position = down.pos
		check("E : descendre", mc.try_interact(p))
		start("d")
	if later("d", 1500):
		check("niveau 2", mc.active and mc.level == 2)
		var kinds: Dictionary = {}
		var g = w.dungeon_grid
		for k in g.blocks: kinds[g.blocks[k].id] = 1
		check("plus profond : or et cristaux", kinds.has("bloc_minerai_or") and kinds.has("bloc_minerai_cristal"))
		for m in mc._content.get_children().filter(func(n): return n.is_in_group("enemy_units")): m.queue_free()
		var chest = mc._interactables.filter(func(i): return i.kind == "chest")[0]
		p.global_position = chest.pos + Vector3(1.0, 0, 0)
		var gold0: int = count("piece_or")
		mc.try_interact(p)
		collect()
		check("coffre oublié ouvert (or %d -> %d)" % [gold0, count("piece_or")], count("piece_or") > gold0)
		view(30, 50, 1.4)
		start("e")
	if later("e", 1500):
		shot("03_niveau2.png")
		root.get_node("SaveGame").save_game("3")
		root.get_node("SaveGame").load_game("3")
		start("f")
	if later("f", 2500):
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); mc = get_first_node_in_group("mountain_caves")
		check("rechargé : devant l'entrée de la grotte", p.global_position.y > -50.0 and p.global_position.distance_to(ent.pos) < 5.0)
		check("rechargé : le filon creusé et le coffre ouvert sont notés", mc.mined.get("%s:1" % ent.id, []).size() >= 1 and mc.opened.get("%s:2" % ent.id, []).size() >= 1)
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	return false
