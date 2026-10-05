extends SceneTree
var f := 0
var p; var w; var items; var vn; var k; var dc; var hud; var st; var fam
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/ev_"
var v
var wolf
var foe
var EV

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

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p: p._invulnerable_left = 5.0
	if f == 10:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		vn = get_first_node_in_group("village_needs"); k = get_first_node_in_group("kingdom")
		dc = get_first_node_in_group("day_cycle"); hud = get_first_node_in_group("hud")
		st = get_first_node_in_group("story"); fam = get_first_node_in_group("familiars_mgr")
		EV = load("res://scripts/kingdom/evolution.gd")
		get_first_node_in_group("raids").enabled = false
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		get_first_node_in_group("quests")._offer_timer = 9999.0
		get_first_node_in_group("weather").set_kind("clair")
		dc.hour = 11.0
		print("== sans le Pacte")
		v = vn.members().filter(func(x): return not x.has_meta("story"))[0]
		check("pas de Pacte au début de l'histoire", EV.villager_block_reason(v, p).begins_with("Il te faut"))
		st.step = st.index_of("grik")
		st._spawn_npcs()
		print("== habitant nommé")
		v.set_race(load("res://data/races/gobelin.tres"))
		v.level = 2
		v._apply_level(true)
		check("niveau 3 requis : %s" % EV.villager_block_reason(v, p), EV.villager_block_reason(v, p).begins_with("Niveau"))
		v.set_level(3)
		p.inventory.add(items.get_item("piece_or"), 250)
		p.inventory.add(items.get_item("larme_esprit"), 1)
		var hp0: int = v.health.max_health
		check("1re évolution possible", EV.villager_block_reason(v, p) == "")
		check("nommé Tarok : il évolue", EV.evolve_villager(v, p, "Tarok"))
		check("hobgobelin, évolution 1, niveau 6, « Hobgobelin »", v.race.resource_path.ends_with("hobgobelin.tres") and v.evo == 1 and v.level == 6 and v.villager_name == "Tarok" and v.race_title() == "Hobgobelin")
		check("plus fort (%d -> %d PV) et plus grand" % [hp0, v.health.max_health], v.health.max_health > hp0 * 1.4 and v.visual.scale.x > 1.05)
		v.set_level(8)
		check("2e évolution : Chef hobgobelin", EV.evolve_villager(v, p, "Tarok") and v.evo == 2 and v.race_title() == "Chef hobgobelin")
		print("   modèle : ", v.visual.model.resource_path)
		check("modèle 3D de l'évolution (hobgobelin évolué)", v.visual.model.resource_path.contains("hobgoblin_base") and v.visual.model.resource_path.ends_with("_evo1.glb"))
		check("pas de 3e évolution", EV.villager_block_reason(v, p) != "" and EV.next_villager_evo(v).is_empty())
		var v2 = vn.members().filter(func(x): return x != v and not x.has_meta("story"))[0]
		v2.set_race(load("res://data/races/homme_lezard.tres")); v2.set_level(9); v2.evo = 1; v2.evo_title = "Homme-lézard guerrier"
		p.inventory.add(items.get_item("piece_or"), 150); p.inventory.add(items.get_item("larme_esprit"), 1)
		check("homme-lézard guerrier -> Dragonide", EV.evolve_villager(v2, p, "") and v2.race.resource_path.ends_with("dragonide.tres"))
		p.global_position = v.global_position + Vector3(1.2, 0, 0)
		v2.set_level(3); v2.evo = 0; v2.evo_title = ""
		p.open_inventory.emit(v2)
		start("a")
	if later("a", 700):
		shot("01_nommer.png")
		for c in root.find_children("*", "Control", true, false):
			if c.get_script() and c.get_script().resource_path.ends_with("inventory_ui.gd") and c.visible: c.close()
		print("== familier")
		var at: Vector3 = w.cell_center(w.spawn_cell) + Vector3(10, 0, 10)
		at.y = w.ground_height_at(at + Vector3(0, 20, 0))
		p.global_position = at
		wolf = spawn_enemy("loup", at + Vector3(2, 0.5, 0))
		start("b")
	if later("b", 300):
		check("loup en pleine forme : pas de Pacte", not fam.can_tame(wolf))
		wolf.health.current = roundi(wolf.health.max_health * 0.2)
		wolf._pact_hint(2.0)
		check("loup affaibli : « [F] Pacte »", fam.can_tame(wolf) and wolf.name_label.text.contains("[F] Pacte"))
		check("F : il est apprivoisé", fam.try_interact(p) and fam.list.size() == 1)
		start("c")
	if later("c", 300):
		var e = fam.list[0].node
		check("familier « %s » allié (pas un ennemi)" % fam.list[0].name, e != null and e.tamed and e.is_in_group("familiars") and not e.is_in_group("enemy_units") and e.is_in_group("allies"))
		foe = spawn_enemy("sanglier", p.global_position + Vector3(-5, 0.5, 3), 2)
		start("d")
	if later("d", 1500):
		var e = fam.list[0].node
		check("il attaque le sanglier", e._target == foe)
		view(200, 25, 0.9)
		shot("02_familier_combat.png")
		p.global_position += Vector3(12, 0, 0)
		p.global_position.y = w.ground_height_at(p.global_position + Vector3(0, 20, 0))
		foe.queue_free()
		start("e")
	if later("e", 3000):
		var e = fam.list[0].node
		check("il suit le héros (%.1f m)" % e.global_position.distance_to(p.global_position), e.global_position.distance_to(p.global_position) < 8.0)
		var lv0: int = fam.list[0].level
		for i in 12:
			var dummy = spawn_enemy("loup", p.global_position + Vector3(0, 0.5, 4), 1)
			fam.on_enemy_died(dummy)
			dummy.queue_free()
		check("12 victoires : +3 niveaux et 1re évolution « %s »" % fam.title_of(fam.list[0]), fam.list[0].level == lv0 + 3 and fam.list[0].evo == 1 and fam.title_of(fam.list[0]) == "Loup des tempêtes")
		start("f")
	if later("f", 400):
		var e = fam.list[0].node
		check("nouvelle forme plus grande", e != null and e.visual.scale.x > e.data.model_scale * 1.1 and e.name_label.text.contains("Loup des tempêtes"))
		view(200, 20, 0.7)
		shot("03_familier_evolue.png")
		e.health.take_damage(99999, null)
		start("g")
	if later("g", 300):
		check("K.O. : il reviendra", fam.list[0].node == null and fam.list[0].down > 30.0)
		fam.list[0].down = 0.0
		start("h")
	if later("h", 300):
		check("il est revenu auprès du héros", fam.list[0].node != null and is_instance_valid(fam.list[0].node))
		print("== héros")
		var hp0: int = p.health.max_health
		var atk0: int = p.attack_power()
		var sc0: float = p.visual.scale.y
		p.evolve_hero()
		check("évolution 1 : %s" % p.evo_title(), p.hero_evo == 1 and p.evo_title() == "Homme-bête éveillé")
		p.evolve_hero(); p.evolve_hero(); p.evolve_hero()
		check("évolution 3 (maximum) : %s" % p.evo_title(), p.hero_evo == 3 and p.evo_title() == "Roi des Bêtes")
		check("plus fort : vie %d -> %d, attaque %d -> %d" % [hp0, p.health.max_health, atk0, p.attack_power()], p.health.max_health > hp0 * 1.3 and p.attack_power() > atk0)
		check("un peu plus grand", p.visual.scale.y > sc0 * 1.1)
		check("modèle 3D du héros évolué : %s" % p.visual.model.resource_path.get_file(), p.visual.model.resource_path.ends_with("_evo3.glb"))
		check("titre dans l'interface", hud._xp_text.text.contains("Roi des Bêtes"))
		view(30, 15, 0.6)
		start("i")
	if later("i", 1200):
		shot("04_heros_evolue.png")
		root.get_node("SaveGame").save_game("3")
		set_meta("fam", fam.list[0].name)
		root.get_node("SaveGame").load_game("3")
		start("j")
	if later("j", 2500):
		p = get_first_node_in_group("player"); fam = get_first_node_in_group("familiars_mgr")
		check("héros rechargé : %s" % p.evo_title(), p.hero_evo == 3 and p.visual.model.resource_path.ends_with("_evo3.glb"))
		check("familier rechargé : %s" % fam.summary(), fam.list.size() == 1 and fam.list[0].name == get_meta("fam") and fam.list[0].evo == 1)
		var t = get_nodes_in_group("villagers").filter(func(x): return x.villager_name == "Tarok")
		check("Tarok rechargé (Chef hobgobelin)", t.size() == 1 and t[0].evo == 2 and t[0].race_title() == "Chef hobgobelin" and t[0].race.resource_path.ends_with("hobgobelin.tres") and t[0].visual.model.resource_path.ends_with("_evo1.glb"))
		start("k")
	if later("k", 800):
		check("le familier est revenu après le chargement", fam.list[0].node != null and is_instance_valid(fam.list[0].node))
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	return false
