extends SceneTree
var f := 0
var sg; var before := {}
var ok := true

func check(name: String, cond: bool) -> void:
	print(("  OK  " if cond else "  ÉCHEC  ") + name)
	ok = ok and cond
func _initialize():
	var h = load("res://scripts/hero/hero_profile.gd").new()
	h.hero_name = "Selka"
	h.race = load("res://data/races/homme_bete.tres")
	h.hero_class = load("res://data/classes/rodeur.tres")
	h.job = load("res://data/jobs/chasseur.tres")
	h.skill = load("res://data/skills/vorace.tres")
	h.skin_color = Color("d88a3a")
	root.get_node("GameState").hero = h
	root.get_node("GameState").world_seed = int(OS.get_environment("TEST_SEED")) if OS.get_environment("TEST_SEED") != "" else 4242
	sg = root.get_node("SaveGame")
	change_scene_to_file("res://scenes/main.tscn")
func W(): return get_first_node_in_group("world")
func P(): return get_first_node_in_group("player")
func snapshot() -> Dictionary:
	var w = W(); var p = P(); var k = get_first_node_in_group("kingdom")
	var c: Vector2i = w.spawn_cell + Vector2i(12, 12)
	return {"seed": w.world_seed, "lvl": p.level, "xp": p.xp, "inv": p.inventory.entries.size(), "bois": p.inventory.count(root.get_node("Items").get_item("wood")),
		"eq": p.equipment.slots.size(), "souls": p.souls.keys(), "atk": p.attack_power(), "h": w.terrain_height(c), "decor": w.decor_at(c + Vector2i(3, 0)),
		"blocks": w.build.blocks.size(), "furn": w.build.furniture.size(), "rooms": k.typed_rooms().map(func(r): return r.type.id),
		"villagers": get_nodes_in_group("villagers").size(), "comp": get_nodes_in_group("villagers").filter(func(v): return v.companion).size(),
		"workers": get_nodes_in_group("villagers").filter(func(v): return v.work_room != null).size(),
		"zones_disc": w.zones.filter(func(z): return z.discovered).size(), "ob": w.zones.filter(func(z): return z.obelisk_on).size(),
		"cleared": w.zones.filter(func(z): return z.get("cleared", false)).size(), "revealed": w._revealed.count(1), "taken": w._taken.size(),
		"pos": p.global_position.round(), "plans": get_first_node_in_group("build_orders").orders.size(), "skin": p.profile.skin_color.to_html(), "title": k.title(),
		"weapon": p.weapon().id if p.weapon() else "", "dip": JSON.stringify(get_first_node_in_group("diplomacy").export_state().states),
		"ach": _sorted(get_first_node_in_group("achievements").done.keys()), "ach_c": get_first_node_in_group("achievements").counters,
		"brume": w.zones.map(func(z): return int(z.get("brume", 0))), "side": get_first_node_in_group("side_quests").states.keys(),
		"story": get_first_node_in_group("story").step}
func _sorted(a: Array) -> Array:
	var b := a.duplicate()
	b.sort()
	return b


func _process(_d) -> bool:
	f += 1
	if f == 5:
		var w = W(); var p = P(); var items = root.get_node("Items")
		print("scène: ", current_scene.scene_file_path, " nouvelle partie, sac=", p.inventory.entries.size(), " équipement=", p.equipment.slots.size())
		p.gain_xp(900)
		p.inventory.add(items.get_item("wood"), 33)
		p.absorb_soul("marais", {"regen": 2.5})
		# terrassement + décor récolté
		var c: Vector2i = w.spawn_cell + Vector2i(12, 12)
		w.set_terrain_height(c, 3.0)
		for dx in 20:
			if w.decor_at(c + Vector2i(3 + dx, 0)) != 0:
				w.remove_decor(c + Vector2i(3 + dx, 0))
		w.refresh_cells([c])
		# une maison
		var s: Vector2i = w.spawn_cell + Vector2i(-4, 8)
		var H := roundi(w.terrain_height(s))
		for x in range(-4, 1):
			for z in range(8, 12):
				w.set_terrain_height(w.spawn_cell + Vector2i(x, z), float(H))
		for x in range(-4, 1):
			for z in range(8, 12):
				if x == -4 or x == 0 or z == 8 or z == 11:
					for y in 3:
						if not (x == -2 and z == 8 and y < 2):
							w.build.place_block(Vector3i(w.spawn_cell.x + x, H + y, w.spawn_cell.y + z), items.get_item("bloc_planches"))
		w.build.place_furniture(w.spawn_cell + Vector2i(-2, 8), float(H), items.get_item("porte"), 0)
		w.build.place_furniture(w.spawn_cell + Vector2i(-3, 10), float(H), items.get_item("lit"), 2)
		w.build.place_furniture(w.spawn_cell + Vector2i(-1, 10), float(H), items.get_item("coffre"), 2)
		var k = get_first_node_in_group("kingdom")
		k.recompute()
		var vs = get_nodes_in_group("villagers")
		vs[0].set_companion(true)
		# zones
		w.zones[3].discovered = true; w.zones[3].obelisk_on = true; w.zones[4].cleared = true
		w.reveal(w.cell_center(w.spawn_cell) + Vector3(60, 0, 0), 20)
		p.equipment.equip(items.get_item("iron_armor"))
		var bo = get_first_node_in_group("build_orders")
		for i in 5: bo.block(Vector3i(w.spawn_cell.x + 10 + i, H + 5, w.spawn_cell.y), items.get_item("bloc_pierre_brute"))
		bo.terrain(w.spawn_cell + Vector2i(12, 3), 5.0)
		# systèmes plus récents : forge, diplomatie, Brume, succès
		p.equipment.equip(items.get_item("sword_iron@3~gemme_rubis!rune_force"))
		var dip = get_first_node_in_group("diplomacy")
		dip.act("karg", "war")
		dip.states.sables.rel = 30.0
		dip.act("sables", "commerce")
		w.zones[4].brume = 2
		var ach = get_first_node_in_group("achievements")
		ach.note("vault", 2)
		ach.check_all()
	if f == 10:
		before = snapshot()
		print("AVANT : ", before)
		print("sauvegarde: ", sg.save_game("3"), " taille=", FileAccess.get_file_as_bytes(sg.path_of("3")).size(), " octets")
		print("info: ", sg.slot_info("3"))
		sg.load_game("3")
	if f == 30:
		var after := snapshot()
		print("APRÈS: ", after)
		var diff := []
		for key in before:
			if str(before[key]) != str(after[key]): diff.append("%s: %s -> %s" % [key, before[key], after[key]])
		print("DIFFÉRENCES: ", diff)
		check("tout est rechargé à l'identique (%d valeurs comparées)" % before.size(), diff.is_empty())
		check("épée renforcée rechargée : %s" % after.weapon, after.weapon == "sword_iron@3~gemme_rubis!rune_force")
		print("latest=", sg.latest_slot())
		sg.delete("3")
		print("RÉSULTAT : " + ("tout est bon" if ok else "ÉCHECS"))
		return true
	return false
