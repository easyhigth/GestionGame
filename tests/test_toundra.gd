extends SceneTree
## Les nouveaux monstres de la toundra : yéti, élémentaire de glace, mammouth laineux.
var f := 0
var p; var w
var ok := true
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/td_"
const NEW := ["yeti", "elementaire_glace", "mammouth"]

func _initialize():
	var h = load("res://scripts/hero/hero_profile.gd").new()
	h.hero_name = "Bjorn"
	h.race = load("res://data/races/nain.tres")
	h.hero_class = load("res://data/classes/guerrier.tres")
	h.job = load("res://data/jobs/chasseur.tres")
	h.skill = load("res://data/skills/vorace.tres")
	root.get_node("GameState").hero = h
	root.get_node("GameState").world_seed = int(OS.get_environment("TEST_SEED")) if OS.get_environment("TEST_SEED") != "" else 4242
	change_scene_to_file("res://scenes/main.tscn")

func check(name: String, cond: bool) -> void:
	print(("  OK  " if cond else "  ÉCHEC  ") + name)
	ok = ok and cond

func _process(_d) -> bool:
	f += 1
	if p:
		p._invulnerable_left = 5.0
		p.health.heal(9999)
	if f == 10:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world")
		get_first_node_in_group("raids").enabled = false
		print("== les monstres")
		var region = load("res://data/regions/toundra.tres")
		var ids: Array = region.enemies.map(func(e): return e.resource_path.get_file().get_basename())
		var ordinary := {}
		for id in ids:
			ordinary[id] = true
		check("toundra : %d monstres ordinaires (%s)" % [ordinary.size(), ordinary.keys()], ordinary.size() >= 5)
		check("toundra : la neige est restée", region.precipitation == "neige")
		var ach = get_first_node_in_group("achievements")
		var fam = get_first_node_in_group("familiars_mgr")
		for id in NEW:
			var ed = load("res://data/enemies/%s.tres" % id)
			check("%s dans la toundra" % id, ids.has(id))
			var m = ed.model.instantiate() if ed and ed.model else null
			check("%s : modèle %s" % [ed.display_name, ed.model.resource_path.get_file()], m != null)
			if m:
				for bone in ["LegL", "LegR", "Torso", "Head", "ArmL", "ArmR"]:
					check("  %s : os %s" % [id, bone], m.find_child(bone, true, false) != null)
				m.free()
			for evo in [1, 2]:
				check("  %s : évolution %d" % [id, evo], ResourceLoader.exists(ed.model.resource_path.get_basename() + "_evo%d.glb" % evo))
			check("  %s : portrait" % id, ResourceLoader.exists("res://assets/ui/portraits/%s.png" % id))
			check("  %s : bestiaire" % id, ach.BESTIARY.has(id) and load("res://scripts/world/bestiary_lore.gd").NOTES.has(id))
			check("  %s : évolutions de familier" % id, fam.TITLES.has(id))
			var be = ach.bestiary_entry(id)
			check("  %s vit dans la toundra (%s)" % [id, be.regions], be.regions.has("Toundra gelée"))
		# bipèdes (mains) et quadrupède
		var i := 0
		for pair in [["yeti", false], ["elementaire_glace", false], ["mammouth", true]]:
			var e = load("res://scenes/enemies/enemy.tscn").instantiate()
			e.data = load("res://data/enemies/%s.tres" % pair[0])
			w.add_child(e)
			var q: Vector3 = p.global_position + Vector3(-5 + i * 5, 0, -6)
			q.y = w.ground_height_at(q + Vector3(0, 6, 0))
			e.global_position = q
			e.set_physics_process(false)
			check("%s : %s" % [pair[0], "quadrupède" if pair[1] else "bipède"], e.visual.is_quadruped() == pair[1])
			i += 1
	if f == 90:
		root.get_viewport().get_texture().get_image().save_png(out + "01_monstres.png")
		print("RÉSULTAT : " + ("tout est bon" if ok else "ÉCHECS"))
		return true
	return f > 3000
