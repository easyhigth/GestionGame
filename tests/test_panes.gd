extends SceneTree
## Nouvelles formes de blocs : trappes (s'ouvrent avec E, on marche dessus fermées) et fenêtres (vitres fines).
var f := 0
var ok := true

func _initialize():
	var h = load("res://scripts/hero/hero_profile.gd").new()
	h.hero_name = "Selka"
	h.race = load("res://data/races/humain.tres")
	h.hero_class = load("res://data/classes/guerrier.tres")
	h.job = load("res://data/jobs/chasseur.tres")
	h.skill = load("res://data/skills/vorace.tres")
	root.get_node("GameState").hero = h
	root.get_node("GameState").world_seed = 4242
	var sg = root.get_node("SaveGame")
	sg.world_opts = sg.WORLD_DEFAULTS.duplicate()
	sg.guide_state = {}
	change_scene_to_file("res://scenes/main.tscn")

func check(name: String, cond: bool) -> void:
	print(("  OK  " if cond else "  ÉCHEC  ") + name)
	ok = ok and cond

func _process(_d) -> bool:
	f += 1
	if f < 60:
		return false
	var items = root.get_node("Items")
	var w = get_first_node_in_group("world")
	var grid = w.build
	var trap = items.get_item("trappe_chene")
	var pane = items.get_item("vitre_verre")
	var red = items.get_item("vitre_rouge")
	check("trappe, vitre et vitre rouge existent", trap != null and pane != null and red != null)
	check("ce sont des blocs", trap.is_block() and pane.is_block() and red.is_block())
	check("la vitre est transparente, pas la trappe", pane.block_transparent and not trap.block_transparent)
	check("recette de trappe", items.recipes.any(func(r): return r.result == trap))
	check("recette de vitre", items.recipes.any(func(r): return r.result == pane))
	var c: Vector3 = w.home_center() + Vector3(10, 0, 10)
	var x := int(floor(c.x))
	var z := int(floor(c.z))
	var y := int(floor(w.ground_height_at(c + Vector3(0, 3, 0)))) + 1
	var col := Vector2i(x, z)
	check("on pose la trappe", grid.place_block(Vector3i(x, y, z), trap))
	check("trappe fermée : plate (hauteur %.2f)" % grid.block_height(trap), is_equal_approx(grid.block_height(trap), 0.19))
	check("trappe fermée : on se tient dessus", is_equal_approx(grid.support(col, y + 1.0), y + 0.19))
	check("trappe fermée : bloque un corps à ses pieds", grid.body_blocked(col, float(y)))
	check("trappe fermée : pas un corps debout dessus", not grid.body_blocked(col, y + 0.19))
	grid.open_gates[Vector3i(x, y, z)] = true
	check("trappe ouverte : on passe", not grid.body_blocked(col, float(y)))
	check("la touche E trouve la trappe", grid.toggle_gate_near(Vector3(x + 0.5, y + 0.2, z + 0.5)))
	check("E referme la trappe", not grid.open_gates.has(Vector3i(x, y, z)))
	# fenêtre : trois vitres alignées et un bloc plein au bout
	for i in 3:
		check("on pose la vitre %d" % i, grid.place_block(Vector3i(x + 3 + i, y, z), pane if i < 2 else red))
	check("la vitre bloque le passage", grid.body_blocked(Vector2i(x + 3, z), float(y)))
	grid.generating = false
	grid._rebuild_chunk(Vector2i(floori(x / 16.0), floori(z / 16.0)))
	check("le morceau de construction se dessine avec trappe et vitres", grid._chunk_nodes.has(Vector2i(floori(x / 16.0), floori(z / 16.0))))
	check("une vitre n'est pas un bloc plein", not grid._opaque_full(Vector3i(x + 3, y, z)))
	print("RÉSULTAT : ", "tout est bon" if ok else "échec")
	return true
