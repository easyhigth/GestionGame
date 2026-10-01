extends SceneTree
var f := 0
var p; var w; var items; var dm; var st; var z
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/br_"
var normal_level := 0
var atk_before := 0

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

func brume_units() -> Array:
	return get_nodes_in_group("enemy_units").filter(func(e): return e.global_position.y < -50 and not e.is_in_group("bosses"))

func go_boss_room() -> void:
	var c: Vector2i = dm.boss_room.get_center() + Vector2i(0, 3)
	p.global_position = Vector3(c.x + 0.5, -100, c.y + 0.5)

func loot_ids() -> Array:
	return get_nodes_in_group("pickups").filter(func(q): return q.global_position.y < -50).map(func(q): return q.item.id)

func open_boss_chest() -> void:
	var ch = dm._interactables.filter(func(i): return i.kind == "boss_chest")[0]
	p.global_position = ch.pos + Vector3(0, 0, 1.2)
	dm.try_interact(p)

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p:
		p._invulnerable_left = 5.0
		p.health.heal(9999)
	if f == 10:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		dm = get_first_node_in_group("dungeons"); st = get_first_node_in_group("story")
		get_first_node_in_group("raids").enabled = false
		var best = null
		for zz in w.zones:
			if zz.gate.x >= 0 and (best == null or zz.dist < best.dist):
				best = zz
		z = best
		print("== déblocage (donjon de %s)" % z.name)
		check("pas de Brume au début", not dm.brume_unlocked())
		check("donjon non vaincu : palier 0", dm.next_tier(z) == 0)
		z.cleared = true
		check("donjon vaincu, histoire pas finie : toujours pas de Brume", dm.next_tier(z) == 0 and dm.gate_text(z)[0].contains("Vaincu"))
		st.step = st.STEPS.size()
		start("unlock")
	if later("unlock", 2600):
		check("histoire finie : la Brume s'éveille", dm.brume_unlocked() and dm._brume_known == 1)
		check("porte : %s" % dm.gate_text(z)[0].replace("\n", " / "), dm.gate_text(z)[0].contains("Brume : palier 1"))
		print("== palier 1")
		w.load_area(w.cell_center(z.gate))
		dm.enter(z, true)
		start("t1")
	if later("t1", 1500):
		check("donjon de Brume palier %d" % dm.brume_tier, dm.active and dm.brume_tier == 1)
		normal_level = (z.level as Vector2i).y + 2
		check("boss plus fort : %s Nv %d (normal %d)" % [dm.boss.title, dm.boss.level, normal_level], dm.boss.level > normal_level and dm.boss.title.begins_with("Écho de Brume"))
		var u := brume_units()
		check("%d monstres brumeux, ex. %s" % [u.size(), u[0].name_label.text if u.size() > 0 else "-"], u.size() > 0 and u[0].name_label.text.begins_with("Brumeux"))
		check("4 pouvoirs à partir du palier 4 seulement", dm.boss.powers.size() <= 4)
		go_boss_room()
		start("t1b")
	if later("t1b", 800):
		check("boss réveillé", dm.boss.awake)
		shot("01_palier.png")
		dm.boss.health.take_damage(dm.boss.health.current + 99999, p)
		start("t1c")
	if later("t1c", 600):
		check("palier 1 franchi (zone : %d)" % int(z.get("brume", 0)), int(z.get("brume", 0)) == 1)
		check("prochain palier : 2", dm.next_tier(z) == 2)
		open_boss_chest()
		start("t1d")
	if later("t1d", 400):
		var ids := loot_ids()
		print("   butin : ", ids)
		check("fragments de Brume dans le trésor", ids.has("fragment_brume"))
		check("une gemme au moins", ids.any(func(i): return str(i).begins_with("gemme_")))
		dm.leave(true)
		start("t3")
	if later("t3", 800):
		check("sorti, palier remis à 0", not dm.active and dm.brume_tier == 0)
		print("== Seigneur de Brume (palier 3)")
		z.brume = 2
		check("palier 3 = Seigneur", dm.is_lord_tier(dm.next_tier(z)) and dm.gate_text(z)[0].contains("Seigneur"))
		atk_before = p.attack_power()
		dm.enter(z, true)
		start("t3b")
	if later("t3b", 1500):
		check("seigneur : %s, Nv %d" % [dm.boss.title, dm.boss.level], dm.boss.title.begins_with("Seigneur de Brume"))
		check("plus grand (%.2f)" % dm.boss.visual.scale.x, dm.boss.visual.scale.x > dm.boss.data.model_scale * 1.2)
		check("4 pouvoirs", dm.boss.powers.size() == 4)
		go_boss_room()
		start("t3c")
	if later("t3c", 1500):
		shot("02_seigneur.png")
		dm.boss.health.take_damage(dm.boss.health.current + 99999, p)
		start("t3d")
	if later("t3d", 600):
		var lords: Array = p.souls.keys().filter(func(k): return str(k).begins_with("brume_"))
		check("âme légendaire absorbée : %s" % [lords], lords.size() == 1)
		check("attaque %d -> %d" % [atk_before, p.attack_power()], p.attack_power() > atk_before)
		check("résumé : %s" % dm.brume_summary(), dm.brume_summary().contains("palier 3") and dm.brume_summary().contains("1 Seigneur"))
		open_boss_chest()
		start("t3e")
	if later("t3e", 400):
		var ids := loot_ids()
		print("   butin : ", ids)
		check("orichalque ou arme légendaire", ids.has("orichalque") or ids.any(func(i): return items.get_item(i).rarity == 4 and items.get_item(i).is_equipment()))
		shot("03_tresor.png")
		dm.leave(true)
		start("save")
	if later("save", 800):
		print("== sauvegarde")
		var d: Dictionary = w.export_state()
		z.brume = 0
		w.import_state(d)
		check("palier rechargé : %d" % int(z.get("brume", 0)), int(z.get("brume", 0)) == 3)
		check("porte : %s" % dm.gate_text(z)[0].replace("\n", " / "), dm.gate_text(z)[0].contains("palier 4"))
		print("RÉSULTAT : " + ("tout est bon" if ok else "ÉCHECS"))
		return true
	return f > 20000
