extends SceneTree
var f := 0
var p; var w; var items; var hud; var inv_ui
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/fo_"
var FG

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

func count(id: String) -> int:
	return p.inventory.count(items.get_item(id))

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p: p._invulnerable_left = 5.0
	if f == 10:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		hud = get_first_node_in_group("hud")
		FG = load("res://scripts/items/forge.gd")
		get_first_node_in_group("raids").enabled = false
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		for pair in [["iron_ingot", 40], ["piece_or", 8000], ["lingot_or", 8], ["mithril_brut", 8], ["lingot_mithril", 12], ["larme_esprit", 4], ["orichalque", 1],
				["gemme_rubis", 1], ["gemme_topaze", 1], ["gemme_emeraude", 1], ["gemme_diamant", 1]]:
			p.inventory.add(items.get_item(pair[0]), pair[1])
		var sword = items.get_item("sword_iron")
		var CR = load("res://scripts/hero/crafts.gd")
		check("métier débutant : raffinage limité à +%d" % CR.max_refine(p, sword), CR.max_refine(p, sword) == 5)
		p.crafts["forgeron"] = CR.xp_for_level(100); p.crafts["armurier"] = CR.xp_for_level(100)
		p.equipment.equip(sword)
		var atk0: int = p.attack_power()
		print("== renforcer")
		check("sans enclume : impossible", FG.upgrade_block(p, sword, []) == "Approche-toi d'une enclume.")
		var st := ["enclume"]
		var it = sword
		for i in 10:
			var nx = FG.upgrade(p, it, st)
			if nx == null:
				print("   bloqué à +%d : %s" % [it.upgrade, FG.upgrade_block(p, it, st)])
				break
			it = nx
		check("épée +10 : %s, attaque %d (base %d)" % [it.display_name, it.attack, sword.attack], it.upgrade == 10 and it.display_name == "Épée en fer +10" and it.attack > sword.attack * 2)
		check("portée par le héros", p.weapon() == it)
		check("attaque du héros %d -> %d" % [atk0, p.attack_power()], p.attack_power() > atk0 + 8)
		check("légendaire à +10", it.rarity == 4)
		check("modèle de l'épée de base", p.visual._shown.get(1, "") == "sword_iron")
		check("coût payé (orichalque utilisé)", count("orichalque") == 0)
		check("+11 demande de l'orichalque", FG.upgrade_block(p, it, st).begins_with("Il manque"))
		print("== gemmes")
		check("3 emplacements à +10", FG.sockets(it.upgrade) == 3)
		for g in ["gemme_rubis", "gemme_topaze", "gemme_emeraude"]:
			it = FG.socket(p, it, g, st)
		check("3 gemmes serties : %s" % it.id, it != null and it.gems.size() == 3 and p.weapon() == it)
		check("plus d'emplacement", FG.gem_block(p, it, "gemme_diamant", st) != "")
		check("effets actifs (critiques, vol de vie, brûlure)", p.skill.talent_bonus.get("crit", 0.0) >= 0.05 and p.skill.talent_bonus.get("lifesteal", 0.0) >= 0.04 and p.skill.talent_bonus.get("burn", 0.0) >= 0.12)
		check("même objet par son identifiant", items.get_item(it.id) == it)
		var tr = get_first_node_in_group("trade")
		check("prix chez le marchand %.0f > %.0f" % [tr.value_of(it), tr.value_of(sword)], tr.value_of(it) > tr.value_of(sword) * 3)
		print("   ", it.stats_text().replace("\n", " | "))
		# armure dans le sac
		p.inventory.add(items.get_item("iron_armor"), 1)
		var arm = FG.upgrade(p, items.get_item("iron_armor"), st)
		check("armure dans le sac renforcée : %s" % arm.display_name, arm != null and count(arm.id) == 1 and count("iron_armor") == 0)
		set_meta("wid", it.id)
		# fenêtre Forge
		for c in root.find_children("*", "Control", true, false):
			if c.get_script() and c.get_script().resource_path.ends_with("inventory_ui.gd"):
				inv_ui = c
		p.open_inventory.emit(p)
		inv_ui._cat = "Forge"
		inv_ui._refresh()
		start("a")
	if later("a", 700):
		shot("01_forge.png")
		inv_ui.close()
		root.get_node("SaveGame").save_game("3")
		root.get_node("SaveGame").load_game("3")
		start("b")
	if later("b", 2500):
		p = get_first_node_in_group("player")
		check("rechargé : %s" % (p.weapon().display_name if p.weapon() else "rien"), p.weapon() != null and p.weapon().id == get_meta("wid"))
		check("effets rechargés", p.skill.talent_bonus.get("crit", 0.0) >= 0.05)
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	return false
