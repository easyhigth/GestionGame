extends SceneTree
var f := 0
var p; var w; var items; var hud; var BC; var inv_ui; var s: Vector2i; var H := 0
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
		BC = load("res://scripts/build/block_catalog.gd")
		get_first_node_in_group("raids").enabled = false
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		print("== catalogue")
		var blocks := []
		for id in items.items:
			var it = items.items[id]
			if it.is_block():
				blocks.append(it)
		var slabs := blocks.filter(func(b): return b.block_slab)
		check("%d blocs de construction (%d dalles)" % [blocks.size(), slabs.size()], blocks.size() >= 250 and slabs.size() >= 40)
		var fam := {}
		for r in items.recipes:
			if r.category == "Construction":
				fam[r.get_meta("family", "?")] = int(fam.get(r.get_meta("family", "?"), 0)) + 1
		print("   familles : ", fam)
		check("toutes les familles ont des recettes", BC.FAMILIES.all(func(x): return int(fam.get(x, 0)) > 0))
		var t1 = items.get_item("bloc_granite_briques").block_texture; var t2 = items.get_item("bloc_laine_rouge").block_texture
		check("textures générées (16×16) et différentes", t1 != null and t2 != null and t1 != t2 and t1.get_width() == 16)
		check("16 teintures, laine, béton, terre cuite, verre", ["teinture_cyan", "bloc_laine_cyan", "bloc_beton_cyan", "bloc_terre_cuite_cyan", "bloc_emaille_cyan", "bloc_verre_cyan"].all(func(i): return items.get_item(i) != null))
		check("verre teinté transparent", items.get_item("bloc_verre_bleu").block_transparent)
		check("9 essences de bois", ["bloc_bouleau_planches", "bloc_ebene_parquet", "bloc_cerisier_rondins", "bloc_palmier_ecorce", "bloc_chene_parquet"].all(func(i): return items.get_item(i) != null))
		check("bois des régions", BC.wood_for_region("jungle", Vector2i(3, 4)) == "bois_acajou" or BC.wood_for_region("jungle", Vector2i(3, 4)) == "bois_palmier")
		print("== panoplies")
		var AS = load("res://scripts/items/armor_sets.gd")
		check("%d pièces d'armure" % AS.count(items), AS.count(items) >= 80)
		var pl = items.get_item("pan_plastron_acier")
		check("plastron en acier : défense %d > fer 8, modèle teint %s" % [pl.defense, pl.model_id()], pl.defense > 8 and pl.model_id().begins_with("iron_armor*"))
		print("== fabriquer")
		for pr in [["granite", 10], ["laine", 8], ["os", 2], ["bois_bouleau", 4], ["argile", 8], ["leather", 6], ["lingot_acier", 6]]:
			p.inventory.add(items.get_item(pr[0]), pr[1])
		var r1 = find_recipe("bloc_granite_briques")
		check("briques de granite à la table du tailleur", r1.station == "table_tailleur" and r1.craft(p.inventory, false, ["table_tailleur"]) and count("bloc_granite_briques") == 2)
		var rd = find_recipe("teinture_blanc")
		check("teinture blanche avec de l'os", rd.craft(p.inventory, false, []) and count("teinture_blanc") == 2)
		var rw = find_recipe("bloc_laine_blanc")
		check("laine blanche", rw.craft(p.inventory, false, []) and count("bloc_laine_blanc") == 4)
		var bx0: int = int(p.crafts.get("batisseur", 0))
		load("res://scripts/hero/crafts.gd").on_crafted(p, rw)
		check("le bâtisseur progresse", int(p.crafts.batisseur) > bx0)
		var rp = find_recipe("pan_plastron_acier")
		check("plastron en acier : Armurier niveau %d requis" % load("res://scripts/hero/crafts.gd").recipe_level(rp), load("res://scripts/hero/crafts.gd").recipe_level(rp) == 28)
		check("plastron forgé", rp.craft(p.inventory, false, ["enclume"]) and count("pan_plastron_acier") == 1)
		p.equipment.equip(pl)
		check("porté et affiché (teinté)", p.visual._shown.get(ItemData.Slot.CHEST, "").begins_with("iron_armor*") and p.visual._equip_nodes.get(ItemData.Slot.CHEST, []).size() > 0)
		p.equipment.equip(items.get_item("pan_casque_draconique"))
		p.equipment.equip(items.get_item("pan_bouclier_or"))
		# la vitrine : tous les blocs posés en damier
		s = w.cell_at(p.global_position) + Vector2i(6, -6)
		H = roundi(w.terrain_height(s)) + 3
		var n := 0
		var side := ceili(sqrt(blocks.size()))
		for b in blocks:
			w.build.place_block(Vector3i(s.x + n % side, H, s.y + n / side), b)
			n += 1
		set_meta("side", side)
		p.global_position = Vector3(s.x + side / 2.0, H + 1.05, s.y + side / 2.0 + 2.0)
		p.camera_zoom = 1.8
		p.cam_pitch = deg_to_rad(72.0)
		p.snap_camera()
		start("show")
	if later("show", 1500):
		shot("co_01_vitrine.png")
		var side: int = get_meta("side")
		p.global_position = Vector3(s.x + side / 2.0, H + 1.05, s.y + side / 2.0)
		p.camera_zoom = 0.7
		p.cam_pitch = deg_to_rad(25.0)
		p.snap_camera()
		start("hero")
	if later("hero", 900):
		shot("co_02_heros_panoplie.png")
		p.camera_zoom = 1.0
		for c in root.find_children("*", "Control", true, false):
			if c.get_script() and c.get_script().resource_path.ends_with("inventory_ui.gd"):
				inv_ui = c
		inv_ui._family = 3
		inv_ui.open_tab(p, "Construction")
		start("ui1")
	if later("ui1", 700):
		shot("co_03_construction.png")
		inv_ui._cat = "Armures"
		inv_ui._refresh()
		start("ui2")
	if later("ui2", 700):
		shot("co_04_armures.png")
		inv_ui.close()
		var sg = root.get_node("SaveGame")
		check("sauvegarde", sg.save_game("3"))
		sg.load_game("3")
		start("load")
	if later("load", 2500):
		w = get_first_node_in_group("world")
		var it = w.build.blocks.get(Vector3i(s.x, H, s.y))
		check("blocs du catalogue rechargés (%s)" % (it.id if it else "rien"), it != null and it.id != "")
		p = get_first_node_in_group("player")
		check("panoplie rechargée", p.equipment.slots.get(ItemData.Slot.CHEST) != null and p.equipment.slots[ItemData.Slot.CHEST].id == "pan_plastron_acier")
		print("RÉSULTAT : " + ("tout est bon" if ok else "ÉCHECS"))
		return true
	return f > 20000
