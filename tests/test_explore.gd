extends SceneTree
var f := 0
var p; var w; var items; var hud; var cities; var idx := 0; var cam: Camera3D
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/ci_"

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
var mo; var mc; var con
var boat; var cata := {}
var sunk := {}
var t0 := Vector3.ZERO

func look(from: Vector3, at: Vector3, pitch := 20.0, zoom := 1.3) -> void:
	var d := at - from
	p.cam_yaw = atan2(-d.x, -d.z); p.cam_pitch = deg_to_rad(pitch); p.camera_zoom = zoom; p.snap_camera()

## Une case d'eau profonde au bord de la terre, la plus proche du village.
func sea_spot() -> Vector3:
	var sp: Vector2i = w.spawn_cell
	for r in range(20, 700, 6):
		for i in 48:
			var a := TAU * i / 48.0
			var c := sp + Vector2i(roundi(cos(a) * r), roundi(sin(a) * r))
			if c.x < 10 or c.y < 10 or c.x >= w.world_size.x - 10 or c.y >= w.world_size.y - 10: continue
			if w.terrain_type(c) == w.DEEP and w.terrain_type(c + Vector2i(4, 0)) == w.DEEP and w.terrain_type(c + Vector2i(8, 0)) == w.DEEP:
				return Vector3(c.x + 0.5, w.water_surface, c.y + 0.5)
	return Vector3.INF

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p: p._invulnerable_left = 5.0
	if p and p.is_alive(): p.health.heal(99999)
	if f == 8:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		hud = get_first_node_in_group("hud"); mo = get_first_node_in_group("mounts"); mc = get_first_node_in_group("mountain_caves")
		con = get_first_node_in_group("command_console")
		get_first_node_in_group("raids").enabled = false
		get_first_node_in_group("weather").set_kind("clair")
		get_first_node_in_group("day_cycle").hour = 11.0
		print("== voilier")
		check("le voilier se fabrique", load("res://data/recipes/voilier.tres") != null and items.get_item("voilier") != null)
		var sea := sea_spot()
		check("la mer près du village", sea != Vector3.INF)
		w.teleport(sea + Vector3(0, 0, 0))
		boat = mo.spawn_boat(sea, PI / 2, "voilier")
		mo.board(boat)
		check("à bord du voilier", mo.is_sailing() and boat.get_meta("kind") == "voilier")
		var a: Vector3 = p.global_position
		p.velocity = Vector3(3, 0, 0)
		mo.sail_move(0.5)
		var d_sail: float = Vector2(p.global_position.x - a.x, p.global_position.z - a.z).length()
		check("le voilier file (%.2f m en 0,5 s)" % d_sail, d_sail > 4.0)
		look(p.global_position + Vector3(-9, 0, 6), p.global_position, 18, 2.2)
		start("sail")
	if later("sail", 2500):
		look(p.global_position + Vector3(-9, 0, 6), p.global_position, 14, 1.4)
		shot("01_voilier.png")
		mo.dismount()
		mo.mount = null
		p.visual.position.y = 0.0
		print("== cités englouties")
		var sk: Array = w.structure_sites.filter(func(s): return s.kind == "sunken")
		check("des cités englouties (%d : %s)" % [sk.size(), ", ".join(sk.map(func(s): return s.name))], sk.size() >= 2)
		if not sk.is_empty():
			sunk = sk[0]
			var c: Vector2i = sunk.cell + Vector2i(7, 7)
			w.teleport(Vector3(c.x + 0.5, 0, c.y + 14.5))
			look(p.global_position, Vector3(c.x, w.water_surface, c.y), 25, 2.6)
		start("sunk")
	if later("sunk", 3000):
		shot("02_cite_engloutie.png")
		var ch = null
		for c in get_nodes_in_group("world_chests"):
			if c.kind == "sunken" and c.chest_id == sunk.get("id", ""): ch = c
		check("un trésor englouti au fond", ch != null)
		if ch:
			check("le temple est bâti en marbre", w.build.block_at(Vector3i(sunk.cell.x + 7, int(sunk.base), sunk.cell.y + 7)) != null)
			p.global_position = ch.global_position + Vector3(0, 0.2, 1.0)
			var n0 := get_nodes_in_group("pickups").size()
			ch.open(p)
			check("ouvert : des trésors flottent", ch.opened and get_nodes_in_group("pickups").size() > n0)
			look(ch.global_position + Vector3(0, 1.5, 5), ch.global_position, 10, 1.2)
		start("sunk2")
	if later("sunk2", 1500):
		shot("03_tresor_englouti.png")
		print("== griffon")
		var st = get_first_node_in_group("story")
		var r: Dictionary = st.STEPS[st.index_of("vharok_2")][6].reward
		check("Vharok offre le sifflet du griffon", r.items.any(func(x): return x[0] == "sifflet_griffon"))
		w.teleport(w.cell_center(w.spawn_cell) + Vector3(30, 0, 30))
		p.inventory.add(items.get_item("sifflet_griffon"), 1)
		check("le sifflet appelle le griffon", mo.call_griffon(p) == "" and mo.griffon != null)
		look(mo.griffon.global_position + Vector3(4, 0, 5), mo.griffon.global_position, 15, 1.4)
		start("gr1")
	if later("gr1", 1500):
		shot("04_griffon.png")
		check("F : en selle", mo.try_interact(p) and mo.is_flying())
		t0 = p.global_position
		p.global_position.y += 30.0
		start("gr2")
	if later("gr2", 2000):
		check("en vol, à %.0f m au-dessus du sol" % (p.global_position.y - t0.y), p.global_position.y > t0.y + 20.0)
		check("le griffon vole avec le héros", mo.griffon.global_position.distance_to(p.global_position) < 0.5)
		check("plus vite à dos de griffon (x%.1f)" % mo.speed_mult(), mo.speed_mult() > 1.2)
		p.cam_pitch = deg_to_rad(28); p.camera_zoom = 2.4; p.snap_camera()
		start("gr3")
	if later("gr3", 1500):
		shot("05_vol.png")
		mo.dismount()
		check("posé au sol", not mo.is_flying() and absf(p.global_position.y - t0.y) < 3.0)
		print("== souterrains des capitales")
		var es: Array = mc.city_entrances()
		check("une entrée sous chaque capitale (%d)" % es.size(), es.size() == 5)
		for e in es:
			if e.nation == "cendres": cata = e
		w.teleport(cata.pos + Vector3(0, 0, 4.5))
		look(p.global_position, cata.pos, 15, 1.3)
		start("c0")
	if later("c0", 2500):
		shot("06_entree_catacombes.png")
		mc.enter(cata)
		start("c1")
	if later("c1", 2000):
		check("dans %s" % cata.name, mc.active and mc.cave_id == "cata_cendres")
		var walls := 0
		for c in mc._open.keys().slice(0, 400):
			for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var b = mc._grid().block_at(Vector3i(c.x + dd.x, mc.FLOOR_Y, c.y + dd.y))
				if b and b.id in ["bloc_briques", "bloc_pierre_polie"]: walls += 1
		check("des murs de briques (%d)" % walls, walls > 50)
		var foes: Array = mc._content.get_children().filter(func(n): return n.has_method("receive_hit"))
		check("des morts-vivants (%d)" % foes.size(), foes.size() >= 4 and foes.all(func(e): return e.data.resource_path.get_file().get_basename() in ["squelette", "esprit_follet", "seigneur_squelette", "demon"]))
		for e in foes: e.queue_free()
		p.cam_pitch = deg_to_rad(45); p.camera_zoom = 2.2; p.snap_camera()
		start("c2")
	if later("c2", 1500):
		shot("07_catacombes.png")
		mc._go_level(3)
		start("c3")
	if later("c3", 2000):
		var g: Array = mc._content.get_children().filter(func(n): return n.has_method("receive_hit") and n.has_meta("guardian"))
		check("au niveau 3 : le gardien des tombeaux", g.size() == 1 and g[0].data.display_name == "Gardien des tombeaux")
		if not g.is_empty():
			p.global_position = g[0].global_position + Vector3(0, 0, 5)
			look(p.global_position, g[0].global_position, 25, 1.6)
			for e in mc._content.get_children().filter(func(n): return n.has_method("receive_hit") and not n.has_meta("guardian")): e.queue_free()
		start("c4")
	if later("c4", 1200):
		shot("08_gardien.png")
		mc.leave()
		start("save")
	if later("save", 1500):
		check("ressorti dans la ville", not mc.active and p.global_position.y > w.UNDERGROUND)
		root.get_node("SaveGame").save_game("3")
		root.get_node("SaveGame").load_game("3")
		start("load")
	if later("load", 4000):
		mo = get_first_node_in_group("mounts")
		var kinds: Array = mo.boats.filter(func(b): return is_instance_valid(b)).map(func(b): return b.get_meta("kind", "barque"))
		check("rechargé : le voilier est resté à l'eau %s" % str(kinds), kinds.has("voilier"))
		check("rechargé : le griffon attend", mo.griffon != null and is_instance_valid(mo.griffon))
		print("RÉSULTAT : ", "tout est bon" if ok else "il y a des échecs")
		quit(0 if ok else 1)
	return false
