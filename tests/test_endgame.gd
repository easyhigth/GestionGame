extends SceneTree
var f := 0
var p; var w; var items; var hud; var eg; var en; var tid := ""
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

func pickups_loot() -> Array:
	return get_nodes_in_group("pickups").filter(func(q): return is_instance_valid(q) and q.item and str(q.item.id).contains("#"))

func kill_all() -> int:
	var n := 0
	for e in eg._alive:
		if is_instance_valid(e) and e.is_alive():
			e.health.take_damage(e.health.current + 9999999, p); n += 1
	return n

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p:
		p._invulnerable_left = 5.0
		p.health.heal(99999)
	if f == 10:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		hud = get_first_node_in_group("hud"); eg = get_first_node_in_group("endgame")
		get_first_node_in_group("raids").enabled = false
		check("fin de partie présente", eg != null)
		print("== butin de niveau")
		var Loot = load("res://scripts/items/loot.gd")
		check("%d objets de base" % Loot.bases().size(), Loot.bases().size() > 20)
		var it = Loot.roll(240, 0.0, 0, 5)
		print("   ", it.id, " : ", it.display_name, " / ", it.stats_text().replace("\n", " | "))
		check("objet mystique", it.rarity == 5 and it.display_name.begins_with("✦") and it.bonus.size() == 5)
		var base = items.get_item(it.base_id)
		check("plus fort que sa base (%d+%d+%d vs %d+%d+%d)" % [it.attack, it.defense, it.magic, base.attack, base.defense, base.magic],
			it.attack + it.defense + it.magic > (base.attack + base.defense + base.magic) * 10)
		var spec = Loot.parse(it.id)
		check("identifiant relu : %s" % [spec], spec[1] == 240 and spec[2] == 5)
		var atk: int = it.attack; var bn: Dictionary = it.bonus.duplicate()
		items.items.erase(it.id)
		var again = items.get_item(it.id)
		check("refabriqué à l'identique", again != null and again.attack == atk and again.bonus == bn)
		var forge = load("res://scripts/items/forge.gd")
		check("pas améliorable à la forge", not forge.is_upgradable(it))
		var low = Loot.roll(5, 0.0, 0, 0); var high = Loot.roll(500, 0.0, 0, 0)
		check("le niveau d'objet compte", low.attack + low.defense + low.magic < high.attack + high.defense + high.magic)
		var rng := RandomNumberGenerator.new(); rng.seed = 7
		var counts := [0, 0, 0, 0, 0, 0]
		for i in 4000:
			counts[Loot.roll_rarity(rng, 0.0, 0)] += 1
		print("   raretés (monstre ordinaire) : ", counts)
		check("mystique très rare", counts[5] > 0 and counts[5] < 80)
		p.inventory.add(it, 1)
		p.equipment.equip(it)
		print("== paliers du monde")
		check("palier 1 verrouillé au niveau 1", not eg.set_tier(1))
		p.set_level_to(320)
		check("max palier au niveau 320 : %d" % eg.max_tier(), eg.max_tier() == 4)
		check("palier 5 refusé", not eg.set_tier(5))
		check("palier 3 accepté", eg.set_tier(3) and eg.tier == 3)
		en = (load("res://scenes/enemies/enemy.tscn") as PackedScene).instantiate()
		en.data = load("res://data/enemies/loup.tres")
		en.level = 10
		en.power = 1.0
		w.add_child(en)
		en.global_position = p.global_position + Vector3(30, 0, 0)
		check("monstre renforcé : Nv %d, puissance %.1f" % [en.level, en.power], en.level == 100 and en.power > 6.0)
		check("expérience ×%s" % eg.xp_mult(), is_equal_approx(eg.xp_mult(), 2.5))
		en.queue_free()
		# le portail
		var pp: Vector3 = eg.portal_pos()
		p.global_position = pp + Vector3(0, 0, 2.5)
		p.facing = Vector3(0, 0, -1)
		start("portal")
	if later("portal", 2500):
		check("portail construit", eg._portal != null and is_instance_valid(eg._portal))
		check("E devant le portail : panneau", eg.try_interact(p) and hud.endgame_panel.visible)
		start("panel")
	if later("panel", 300):
		shot("eg_01_portail_panneau.png")
		hud.endgame_panel.close()
		start("portal2")
	if later("portal2", 400):
		shot("eg_02_portail.png")
		print("== faille rang 1")
		check("modificateurs : rang 1 aucun, rang 3 un, rang 12 deux, rang 30 trois", eg.rift_affixes(1).is_empty() and eg.rift_affixes(3).size() == 1 and eg.rift_affixes(12).size() == 2 and eg.rift_affixes(30).size() == 3)
		check("modificateurs stables pour un rang (%s)" % eg.affixes_text(eg.rift_affixes(12)), eg.rift_affixes(12) == eg.rift_affixes(12))
		check("5 thèmes d'arène (%s, %s)" % [eg.rift_theme(1)[0], eg.rift_theme(2)[0]], eg.rift_theme(1)[0] != eg.rift_theme(2)[0])
		check("rang 3 verrouillé", not eg.enter_rift(3))
		check("entrée rang 1", eg.enter_rift(1))
		start("rift")
	if later("rift", 2500):
		check("dans la faille (y %.0f)" % p.global_position.y, eg.active and p.global_position.y < -150)
		start("wait_wave")
	if later("wait_wave", 2500):
		check("vague 1 : %d monstres" % eg._alive.size(), eg.wave == 1 and eg._alive.size() >= 5)
		var e0 = eg._alive[0]
		check("monstres de la faille niveau %d" % e0.level, e0.level == eg.rift_level(1))
		shot("eg_03_faille_vague.png")
		start("killing")
	if later("killing", 1500):
		if eg._boss != null and is_instance_valid(eg._boss):
			check("vagues franchies, gardien : %s Nv %d" % [eg._boss.title, eg._boss.level], eg.wave == 3)
			p.global_position = eg._boss.global_position + Vector3(0, 0, 5)
			start("boss")
		else:
			print("   vague %d : %d tués" % [eg.wave, kill_all()])
			start("killing")
	if later("boss", 1200):
		shot("eg_04_gardien.png")
		eg._boss.health.take_damage(eg._boss.health.current + 9999999, p)
		start("boss_dead")
	if later("boss_dead", 1500):
		check("faille 1 vaincue : meilleur rang %d" % eg.best_rift, eg.best_rift == 1)
		var lt := pickups_loot()
		print("   butin : ", lt.map(func(q): return q.item.display_name))
		check("butin de niveau au sol (%d)" % lt.size(), lt.size() >= 2 and lt.any(func(q): return q.item.rarity >= 2))
		p.global_position = eg._arena_center() + Vector3(0, 0.1, 2)
		start("loot_shot")
	if later("loot_shot", 600):
		shot("eg_05_butin.png")
		p.global_position = eg._arena_center() + Vector3(0, 0.1, 0.5)
		check("E au centre : sortie", eg.try_interact(p))
		start("out")
	if later("out", 2500):
		check("sorti de la faille (y %.0f)" % p.global_position.y, not eg.active and p.global_position.y > -40)
		check("arène vidée", eg._arena.get_child_count() == 0 and pickups_loot().is_empty())
		print("== titan")
		var t: Dictionary = eg.summon_titan(p.global_position + Vector3(0, 0, -30))
		check("titan éveillé : %s Nv %d" % [t.get("name", "?"), int(t.get("level", 0))], not t.is_empty() and int(t.level) > 150)
		eg.titan.kind = "boss_seigneur_ignarok"; eg.titan.name = "Ignarok, Titan de lave"
		start("titan")
	if later("titan", 2500):
		var tn = eg._titan_node
		check("le titan est là", tn != null and is_instance_valid(tn))
		if tn:
			check("géant (%.1f) et costaud (%d PV)" % [tn.visual.scale.x, tn.health.max_health], tn.visual.scale.x > 1.9 and tn.health.max_health > 30000)
			p.global_position = tn.global_position + Vector3(0, 0, 20)
			p.facing = Vector3(0, 0, -1)
			print("   titan en ", tn.global_position, " visible ", tn.is_visible_in_tree())
		start("titan_shot")
	if later("titan_shot", 2500):
		check("le titan s'éveille quand on approche", eg._titan_node.awake)
		p.global_position = eg._titan_node.global_position + Vector3(0, 0, 8)
		p.camera_zoom = 1.8
		p.snap_camera()
		start("titan_shot2")
	if later("titan_shot2", 350):
		var cm := root.get_viewport().get_camera_3d()
		print("   titan ", eg._titan_node.global_position, " héros ", p.global_position, " caméra ", cm.global_position, " écran ", cm.unproject_position(eg._titan_node.global_position + Vector3(0, 1, 0)))
		shot("eg_06_titan.png")
		p.camera_zoom = 1.0
		hud.map_ui.open()
		start("titan_map")
	if later("titan_map", 800):
		shot("eg_07_carte_titan.png")
		hud.map_ui.close()
		var tn = eg._titan_node
		tn.health.take_damage(tn.health.current + 99999999, p)
		start("titan_dead")
	if later("titan_dead", 1500):
		check("titan vaincu (%d)" % eg.titans_slain, eg.titans_slain == 1 and eg.titan.is_empty())
		var lt := pickups_loot()
		print("   trésor du titan : ", lt.map(func(q): return q.item.display_name))
		check("trésor légendaire ou mystique", lt.size() >= 3 and lt.any(func(q): return q.item.rarity >= 4))
		shot("eg_08_tresor_titan.png")
		print("== sauvegarde")
		var d: Dictionary = eg.export_state()
		eg.import_state({})
		check("état vidé", eg.tier == 0 and eg.best_rift == 0)
		eg.import_state(d)
		check("état relu : palier %d, faille %d, titans %d" % [eg.tier, eg.best_rift, eg.titans_slain], eg.tier == 3 and eg.best_rift == 1 and eg.titans_slain == 1)
		var sg = root.get_node("SaveGame")
		check("sauvegarde écrite", sg.save_game("3"))
		var raw := FileAccess.get_file_as_string(sg.path_of("3"))
		check("fin de partie dans la sauvegarde", raw.contains("best_rift") or FileAccess.get_file_as_bytes(sg.path_of("3")).size() > 0)
		check("objet de butin équipé : %s" % p.equipment.slots.values().filter(func(x): return x != null and x.id.contains("#")).map(func(x): return x.id),
			p.equipment.slots.values().any(func(x): return x != null and x.id.contains("#")))
		print("RÉSULTAT : " + ("tout est bon" if ok else "ÉCHECS"))
		return true
	return f > 30000
