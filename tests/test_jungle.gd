extends SceneTree
var f := 0
var p; var w; var items; var dip; var hud; var rm; var tr
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/jg_"

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

var dm; var jz

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p:
		p._invulnerable_left = 5.0
		p.health.heal(9999)
	if f == 10:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		rm = get_first_node_in_group("raids"); dm = get_first_node_in_group("dungeons")
		rm.enabled = false
		print("== la région")
		var counts := {}
		for z in w.zones:
			counts[z.type.id] = int(counts.get(z.type.id, 0)) + 1
		print("   zones : ", counts)
		check("9 types de régions", w.region_types.size() == 9)
		var jungles = w.zones.filter(func(z): return z.type.id == "jungle")
		check("des zones de jungle dans le monde (%d)" % jungles.size(), jungles.size() >= 1)
		jz = jungles[0] if not jungles.is_empty() else null
		for id in ["panthere", "grenouille", "serpent", "serpent_roi", "boss_quetzal"]:
			var ed = load("res://data/enemies/%s.tres" % id)
			check("%s : modèle %s" % [ed.display_name, ed.model.resource_path.get_file()], ed.model != null and ed.model.instantiate() != null)
		if jz:
			var site: Vector3 = w.cell_center(jz.site)
			# un point sur la terre ferme, dans la jungle
			var best := site
			for r in [6, 12, 20, 30, 40]:
				for k in 16:
					var a := TAU * k / 16.0
					var q: Vector3 = site + Vector3(cos(a), 0, sin(a)) * float(r)
					var c: Vector2i = w.cell_at(q)
					if w.terrain_type(c) >= 2 and w.region_at(q) != null and w.region_at(q).id == "jungle":
						best = q
						break
				if best != site:
					break
			w.load_area(best)
			best.y = w.ground_height_at(best + Vector3(0, 6, 0))
			p.global_position = best
			p.cam_pitch = deg_to_rad(18.0)
			p.snap_camera()
		start("a")
	if later("a", 3000):
		shot("01_jungle.png")
		var en = get_nodes_in_group("enemy_units").filter(func(e): return e.global_position.distance_to(p.global_position) < 90)
		var kinds := {}
		for e in en:
			kinds[e.data.resource_path.get_file().get_basename()] = true
		print("   monstres autour : ", kinds.keys())
		check("monstres de la jungle autour", kinds.has("panthere") or kinds.has("grenouille") or kinds.has("serpent") or kinds.has("serpent_roi"))
		print("== le donjon-temple")
		var g: Vector3 = w.cell_center(jz.gate)
		w.load_area(g)
		dm.enter(jz, true)
		start("b")
	if later("b", 1500):
		check("boss : %s" % (dm.boss.data.display_name if dm.boss else "-"), dm.boss != null and dm.boss.data.display_name.begins_with("Xochitl"))
		var c: Vector2i = dm.boss_room.get_center() + Vector2i(0, 3)
		p.global_position = Vector3(c.x + 0.5, -100, c.y + 0.5)
		start("c")
	if later("c", 1500):
		shot("02_xochitl.png")
		dm.boss.health.take_damage(dm.boss.health.current + 99999, p)
		start("d")
	if later("d", 800):
		check("âme de Xochitl absorbée", p.souls.has("jungle"))
		var ach = get_first_node_in_group("achievements")
		ach.check_all()
		check("succès « Tombeur de Xochitl »", ach.done.has("boss_jungle"))
		var be: Dictionary = ach.bestiary_entry("panthere")
		check("bestiaire : la panthère vit dans la jungle (%s)" % [be.regions], be.regions.has("Jungle d'émeraude"))
		check("familier : la panthère se monte", get_first_node_in_group("familiars_mgr").RIDEABLE.has("panthere"))
		dm.leave(true)
		start("e")
	if later("e", 2500):
		check("statue de Xochitl au village", get_first_node_in_group("heraldry").statues.has("jungle"))
		print("RÉSULTAT : " + ("tout est bon" if ok else "ÉCHECS"))
		return true
	return f > 30000
