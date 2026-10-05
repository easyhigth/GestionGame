extends SceneTree
## L'équipement vient surtout des monstres vaincus : très peu au sol, des pièces de butin quand on gagne un combat.
var f := 0
var p; var w
var ok := true
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/eg_"
var RD

func _initialize():
	var h = load("res://scripts/hero/hero_profile.gd").new()
	h.hero_name = "Garen"
	h.race = load("res://data/races/humain.tres")
	h.hero_class = load("res://data/classes/guerrier.tres")
	h.job = load("res://data/jobs/chasseur.tres")
	h.skill = load("res://data/skills/vorace.tres")
	root.get_node("GameState").hero = h
	root.get_node("GameState").world_seed = int(OS.get_environment("TEST_SEED")) if OS.get_environment("TEST_SEED") != "" else 4242
	change_scene_to_file("res://scenes/main.tscn")

func check(name: String, cond: bool) -> void:
	print(("  OK  " if cond else "  ÉCHEC  ") + name)
	ok = ok and cond

func gear_pickups() -> Array:
	return get_nodes_in_group("pickups").filter(func(q): return is_instance_valid(q) and q.item and q.item.is_equipment() and str(q.item.id).contains("#"))

func _process(_d) -> bool:
	f += 1
	if p:
		p._invulnerable_left = 5.0
		p.health.heal(9999)
	if f == 10:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world")
		get_first_node_in_group("raids").enabled = false
		print("== équipement au sol")
		check("équipement sauvage très rare (%.4f)" % w.wild_loot_chance, w.wild_loot_chance <= 0.0002)
		var ground: Array = get_nodes_in_group("pickups").filter(func(q): return q.has_meta("world_loot") and q.item and q.item.is_equipment())
		print("  équipements posés dans la nature (morceaux chargés) : ", ground.size())
		print("== butin des monstres")
		RD = load("res://scripts/items/rare_drops.gd")
		var weak = load("res://scenes/enemies/enemy.tscn").instantiate()
		weak.data = load("res://data/enemies/slime_bleu.tres")
		var strong = load("res://scenes/enemies/enemy.tscn").instantiate()
		strong.data = load("res://data/enemies/ogre.tres")
		var c1: float = RD.gear_chance(weak)
		var c2: float = RD.gear_chance(strong)
		check("faible : %.3f, fort : %.3f" % [c1, c2], c1 >= 0.04 and c2 > c1 and c2 <= 0.15)
		var got := 0
		var all_loot := true
		for i in 2000:
			var it = RD.roll_gear(strong)
			if it:
				got += 1
				all_loot = all_loot and it.is_equipment() and str(it.id).contains("#")
		check("ogre : %d pièces sur 2000 combats" % got, got > 2000 * c2 * 0.6 and got < 2000 * c2 * 1.4)
		check("ce sont des pièces de butin", all_loot)
		weak.set_meta("rift", true)
		var none := true
		for i in 500:
			none = none and RD.roll_gear(weak, 50.0) == null
		check("failles : pas de doublon (leur butin à part)", none)
		weak.free(); strong.free()
		var bs = load("res://scenes/enemies/boss.gd").new()
		bs.data = load("res://data/enemies/boss_ogre_roi.tres")
		var bit = RD.roll_gear(bs)
		check("boss : toujours une pièce, au moins rare (%s)" % (bit.display_name if bit else "rien"), bit != null and bit.rarity >= 2)
		bs.free()
		# un vrai combat : on abat des ogres devant le héros jusqu'à ce que l'un lâche une pièce
		print("== combat")
		for i in 60:
			var e = load("res://scenes/enemies/enemy.tscn").instantiate()
			e.data = load("res://data/enemies/ogre.tres")
			w.add_child(e)
			var q: Vector3 = p.global_position + Vector3(4, 0, -4)
			q.y = w.ground_height_at(q + Vector3(0, 6, 0))
			e.global_position = q
			e.set_physics_process(false)
			e.health.take_damage(99999)
			if not gear_pickups().is_empty():
				break
		check("un monstre abattu a lâché de l'équipement (%d)" % gear_pickups().size(), not gear_pickups().is_empty())
	if f == 60:
		root.get_viewport().get_texture().get_image().save_png(out + "01_butin.png")
		print("RÉSULTAT : " + ("tout est bon" if ok else "ÉCHECS"))
		return true
	return f > 3000
