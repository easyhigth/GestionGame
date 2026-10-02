extends SceneTree
var f := 0
var p; var w; var items; var hud; var A; var CR; var FG; var inv_ui; var grid: GridContainer; var bg: ColorRect
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

func count(id: String) -> int:
	return p.inventory.count(items.get_item(id))

func give(pairs: Array) -> void:
	for pr in pairs:
		p.inventory.add(items.get_item(pr[0]), pr[1])

func find_recipe(id: String):
	for r in items.recipes:
		if r.result and r.result.id == id:
			return r
	return null

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p:
		p._invulnerable_left = 5.0
	if f == 10:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		hud = get_first_node_in_group("hud")
		A = load("res://scripts/items/arsenal.gd"); CR = load("res://scripts/hero/crafts.gd"); FG = load("res://scripts/items/forge.gd")
		get_first_node_in_group("raids").enabled = false
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		print("== arsenal")
		var ids: Array = A.all_ids()
		var names := {}
		var types := {}
		for id in ids:
			var it = items.get_item(id)
			if it:
				names[it.display_name] = true
				types[it.attack_speed] = true
		check("%d armes, %d noms différents" % [ids.size(), names.size()], ids.size() >= 500 and names.size() == ids.size())
		check("toutes ont une recette", ids.all(func(i): return find_recipe(i) != null))
		var e0 = items.get_item("arm_epee_fer_0"); var e1 = items.get_item("arm_epee_mithril_0"); var e2 = items.get_item("arm_epee_bois_0")
		check("matériaux : bois %d < fer %d < mithril %d" % [e2.attack, e0.attack, e1.attack], e2.attack < e0.attack and e0.attack < e1.attack)
		var lourd = items.get_item("arm_epee_fer_1"); var vif = items.get_item("arm_epee_fer_2")
		check("designs : lourd %d/%.2f, vif %d/%.2f" % [lourd.attack, lourd.attack_speed, vif.attack, vif.attack_speed], lourd.attack > vif.attack and vif.attack_speed > lourd.attack_speed)
		var bow = items.get_item("arm_arc_argent_3")
		check("arc : tir à distance, attaque %d" % bow.attack, bow.projectile and bow.attack > 5 and bow.two_handed)
		p.equipment.equip(bow)
		p._cast({})
		var arrows := root.find_children("*", "MagicBolt", true, false).filter(func(b): return b.arrow)
		check("l'arc tire une flèche (dégâts %d, sur l'attaque)" % (arrows[0].damage if arrows.size() > 0 else -1), arrows.size() == 1 and arrows[0].damage >= p.attack_power() * 0.9)
		p.equipment.unequip(ItemData.Slot.MAIN_HAND)
		check("modèles différents (designs)", A.mesh_for("arm_hache_fer_0") != A.mesh_for("arm_hache_fer_1") and A.mesh_for("arm_hache_fer_0").get_surface_count() > 0)
		check("nouvelles ressources", ["minerai_cuivre", "lingot_bronze", "lingot_acier", "os", "obsidienne", "poussiere_arcane", "pierre_ame"].all(func(i): return items.get_item(i) != null))
		check("butin de niveau : l'arsenal sert de base (%d bases)" % load("res://scripts/items/loot.gd").bases().size(), load("res://scripts/items/loot.gd").bases().size() > 500)
		print("== métiers")
		check("12 métiers", CR.ORDER.size() == 12 and p.crafts.size() == 12)
		check("le métier du héros (chasseur) commence au niveau 10 : pêcheur %d, cuisinier %d" % [CR.level(p, "pecheur"), CR.level(p, "cuisinier")], CR.level(p, "pecheur") == 10 and CR.level(p, "cuisinier") == 10)
		check("niveau 100 en %d xp (courbe douce)" % CR.xp_for_level(100), CR.xp_for_level(100) < 30000 and CR.level_of_xp(CR.xp_for_level(100)) == 100)
		var r_acier = find_recipe("arm_espadon_acier_1")
		check("espadon en acier : Forgeron niveau %d requis" % CR.recipe_level(r_acier), CR.recipe_level(r_acier) == 28 and CR.craft_of_recipe(r_acier) == "forgeron")
		# fonte et forge
		give([["minerai_cuivre", 4], ["charbon", 4], ["wood", 20], ["leather", 10], ["iron_ingot", 30], ["minerai_etain", 2]])
		var r_cu = find_recipe("lingot_cuivre")
		var xp0 := int(p.crafts.mineur)
		check("fonte du cuivre au four", r_cu.craft(p.inventory, false, ["four"]) and count("lingot_cuivre") == 1)
		CR.on_crafted(p, r_cu)
		check("le mineur progresse (%d -> %d xp)" % [xp0, int(p.crafts.mineur)], int(p.crafts.mineur) > xp0)
		var r_ep = find_recipe("arm_epee_fer_0")
		check("épée en fer : Forgeron niveau 18 requis (actuel %d)" % CR.level(p, "forgeron"), CR.level(p, "forgeron") < 18)
		p.crafts["forgeron"] = CR.xp_for_level(18)
		var fx0 := int(p.crafts.forgeron)
		check("épée forgée à l'enclume", r_ep.craft(p.inventory, false, ["enclume"]))
		CR.on_crafted(p, r_ep)
		check("le forgeron progresse (+%d xp)" % (int(p.crafts.forgeron) - fx0), int(p.crafts.forgeron) > fx0)
		var lv0: int = CR.level(p, "forgeron")
		for i in 40:
			CR.gain(p, "forgeron", 300.0, 60)
		check("niveau qui monte : %d -> %d" % [lv0, CR.level(p, "forgeron")], CR.level(p, "forgeron") > lv0 + 20)
		print("== raffinage et enchantement")
		p.crafts["forgeron"] = CR.xp_for_level(100); p.crafts["enchanteur"] = CR.xp_for_level(1)
		give([["iron_ingot", 40], ["piece_or", 60000], ["lingot_or", 10], ["mithril_brut", 10], ["lingot_mithril", 40], ["larme_esprit", 40],
			["orichalque", 30], ["poussiere_arcane", 300], ["pierre_ame", 12]])
		var it = items.get_item("arm_espadon_acier_2")
		p.inventory.add(it, 1)
		p.equipment.equip(it)
		var atk0: int = p.attack_power()
		check("enchantement rang I seulement (enchanteur débutant, +0)", FG.max_rank(p, it) == 1)
		check("sans autel : impossible", FG.enchant_block(p, it, "feu", 1, ["enclume"]).contains("autel"))
		it = FG.enchant(p, it, "feu", 1, ["autel"])
		check("Embrasement I : %s" % it.display_name, it != null and it.enchants.get("feu", 0) == 1 and it.display_name.contains("de feu"))
		check("1 seul emplacement à +0", FG.enchant_block(p, it, "vampire", 1, ["autel"]).contains("emplacement"))
		for i in 15:
			var nx = FG.upgrade(p, it, ["enclume"])
			if nx == null:
				print("   bloqué : ", FG.upgrade_block(p, it, ["enclume"]))
				break
			it = nx
		check("raffiné à +15 : %s (rareté %d)" % [it.display_name, it.rarity], it.upgrade == 15 and it.rarity >= 4)
		check("enchantement conservé au raffinage", it.enchants.get("feu", 0) == 1)
		check("4 emplacements à +15, rang V possible sur l'objet", FG.ench_slots(it) == 4 and FG.item_rank_cap(it) == 5)
		check("mais l'enchanteur débutant est limité", FG.enchant_block(p, it, "feu", 2, ["autel"]).contains("Enchanteur"))
		p.crafts["enchanteur"] = CR.xp_for_level(100)
		for e in ["feu", "vampire", "brutalite", "eveil"]:
			for r in range(int(it.enchants.get(e, 0)) + 1, 6):
				var nx = FG.enchant(p, it, e, r, ["autel"])
				if nx == null:
					print("   bloqué %s %d : %s" % [e, r, FG.enchant_block(p, it, e, r, ["autel"])])
					break
				it = nx
		print("   ", it.display_name, " : ", it.stats_text().replace("\n", " | "))
		check("4 enchantements au rang V : %s" % FG.enchants_text(it), it.enchants.size() == 4 and it.enchants.values().all(func(v): return v == 5))
		check("devenue MYTHIQUE", it.rarity == 5)
		check("portée par le héros, attaque %d -> %d" % [atk0, p.attack_power()], p.weapon() == it and p.attack_power() > atk0)
		check("effets actifs (vol de vie %.3f, brûlure %.2f)" % [p.skill.talent_bonus.get("lifesteal", 0.0), p.skill.talent_bonus.get("burn", 0.0)],
			p.skill.talent_bonus.get("lifesteal", 0.0) >= 0.07 and p.skill.talent_bonus.get("burn", 0.0) >= 0.3)
		var wid: String = it.id
		items.items.erase(wid)
		var again = items.get_item(wid)
		check("refabriquée à l'identique (%s)" % wid, again != null and again.enchants == it.enchants and again.attack == it.attack)
		check("le modèle reste celui de l'arme de base", p.visual._shown.get(1, "") == "arm_espadon_acier_2" and p.visual._equip_nodes.get(1, []).size() == 1)
		set_meta("wid", wid)
		# réduire en poussière
		p.inventory.add(items.get_item("arm_dague_os_0"), 1)
		var d0 := count("poussiere_arcane")
		var got: int = FG.salvage(p, items.get_item("arm_dague_os_0"), ["autel"])
		check("dague réduite en %d poussière" % got, got >= 1 and count("poussiere_arcane") == d0 + got and count("arm_dague_os_0") == 0)
		print("== récolte")
		var cell := Vector2i(-1, -1)
		var sp: Vector2i = w.cell_at(p.global_position)
		for r in range(2, 60):
			for dz in range(-r, r + 1):
				for dx in [-r, r]:
					var c := sp + Vector2i(dx, dz)
					if cell.x < 0 and w.decor_at(c) == w.D_ROCK:
						cell = c
			if cell.x >= 0:
				break
		var m0 := int(p.crafts.mineur)
		if cell.x >= 0:
			p.inventory.add(items.get_item("pioche_fer"), 1)
			load("res://scripts/world/harvest.gd").hit_decor(w, cell, 999.0, p)
		check("rocher brisé : le mineur progresse (%d -> %d)" % [m0, int(p.crafts.mineur)], int(p.crafts.mineur) > m0)
		# galerie et fenêtres
		var layer := CanvasLayer.new(); layer.layer = 120; root.add_child(layer); set_meta("layer", layer)
		bg = ColorRect.new(); bg.color = Color(0.12, 0.1, 0.09); bg.size = Vector2(1280, 720); layer.add_child(bg)
		grid = GridContainer.new(); grid.columns = 13; layer.add_child(grid); grid.position = Vector2(10, 10)
		var pick := []
		for t in A.TYPE_ORDER:
			for d in 4:
				pick.append(A.make_id(t, A.MATERIALS[(A.TYPE_ORDER.find(t) * 3 + d * 4) % A.MATERIALS.size()].id, d))
		for i in mini(pick.size(), 65):
			var tr := TextureRect.new(); tr.custom_minimum_size = Vector2(96, 112); tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.texture = items.get_icon(items.get_item(pick[i]))
			grid.add_child(tr)
		start("gallery")
	if later("gallery", 900):
		shot("ar_01_arsenal.png")
		get_meta("layer").queue_free()
		# le héros et son espadon mythique
		p.camera_zoom = 0.6
		p.snap_camera()
		start("hero")
	if later("hero", 800):
		shot("ar_02_heros_arme.png")
		p.camera_zoom = 1.0
		for c in root.find_children("*", "Control", true, false):
			if c.get_script() and c.get_script().resource_path.ends_with("inventory_ui.gd"):
				inv_ui = c
		inv_ui._arm_type = 1; inv_ui._arm_mat = 6
		inv_ui.open_tab(p, "Armurerie")
		start("ui1")
	if later("ui1", 600):
		shot("ar_03_armurerie.png")
		inv_ui._cat = "Enchantement"
		inv_ui._refresh()
		start("ui2")
	if later("ui2", 600):
		shot("ar_04_enchantement.png")
		inv_ui._cat = "Métiers"
		inv_ui._refresh()
		start("ui3")
	if later("ui3", 600):
		shot("ar_05_metiers.png")
		inv_ui.close()
		var sg = root.get_node("SaveGame")
		set_meta("crafts", p.crafts.duplicate())
		check("sauvegarde", sg.save_game("3"))
		sg.load_game("3")
		start("load")
	if later("load", 2500):
		p = get_first_node_in_group("player")
		check("arme mythique rechargée", p.weapon() != null and p.weapon().id == get_meta("wid") and p.weapon().rarity == 5)
		check("métiers rechargés (forgeron %d)" % CR.level(p, "forgeron"), p.crafts == get_meta("crafts"))
		print("RÉSULTAT : " + ("tout est bon" if ok else "ÉCHECS"))
		return true
	return f > 20000
