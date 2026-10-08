extends SceneTree
## Mini-carte dédiée sous terre : dans un donjon, elle reste visible, dévoile les salles parcourues et montre
## la sortie, le boss et le nom du lieu.
var f := 0
var main; var world; var p; var dm; var mm
var ok := true
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/mmu_"

func check(name: String, cond: bool) -> void:
	print(("  OK  " if cond else "  ÉCHEC  ") + name)
	ok = ok and cond

func _initialize():
	var h := HeroProfile.new()
	h.hero_name = "Selka"
	h.race = load("res://data/races/humain.tres")
	h.hero_class = load("res://data/classes/guerrier.tres")
	h.job = load("res://data/jobs/chasseur.tres")
	root.get_node("GameState").hero = h
	main = load("res://scenes/main.tscn").instantiate()
	world = main.get_node("World")
	world.random_seed_on_start = false
	world.world_seed = 4242
	root.add_child(main)

func _process(_d) -> bool:
	f += 1
	if p:
		p._invulnerable_left = 5.0
	if f == 2:
		p = main.get_node("World/Player")
		dm = get_first_node_in_group("dungeons")
		var best = null
		for zz in world.zones:
			if zz.gate.x >= 0 and (best == null or zz.dist < best.dist):
				best = zz
		var g: Vector3 = world.cell_center(best.gate)
		world.load_area(g)
		p.global_position = g + Vector3(0, 0, 1.5)
		check("on entre dans le donjon", dm.try_interact(p))
	if f == 60:
		var found := root.find_children("*", "MiniMap", true, false)
		check("la mini-carte existe", not found.is_empty())
		mm = found[0] if not found.is_empty() else null
		if mm == null:
			print("RÉSULTAT : échec")
			return true
		check("sous terre, elle reste affichée", mm.visible)
		var info: Dictionary = mm._under_info()
		check("lieu reconnu : %s" % info.get("name", "?"), str(info.get("name", "")).begins_with("Donjon"))
		var seen: Dictionary = mm._seen.get(info.get("key", ""), {})
		var floors := seen.values().filter(func(k): return k == 1).size()
		var walls := seen.values().filter(func(k): return k == 2).size()
		check("salle d'entrée dévoilée (%d sols, %d murs)" % [floors, walls], floors > 10 and walls > 5)
		check("la sortie est marquée", info.marks.any(func(m): return m[1] == "exit"))
		check("le boss est connu", info.marks.any(func(m): return m[1] == "boss"))
		# on traverse jusqu'à la salle du boss : la carte s'agrandit
		var c: Vector2i = dm.boss_room.get_center()
		p.global_position = Vector3(c.x + 0.5, dm.FLOOR_Y, c.y + 3.5)
		set_meta("n0", seen.size())
	if f == 90:
		var info2: Dictionary = mm._under_info()
		var seen2: Dictionary = mm._seen.get(info2.get("key", ""), {})
		check("la salle du boss s'ajoute à la carte (%d -> %d cases)" % [int(get_meta("n0")), seen2.size()], seen2.size() > int(get_meta("n0")))
		root.get_viewport().get_texture().get_image().save_png(out + "donjon.png")
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	return false
