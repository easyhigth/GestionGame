extends SceneTree
## Objets lâchés contre un mur (donjon) : ils atterrissent sur la case libre la plus proche, jamais dans le mur.
var f := 0
var main; var world; var p; var dm; var z
var ok := true

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
		z = best
		var g: Vector3 = world.cell_center(z.gate)
		world.load_area(g)
		p.global_position = g + Vector3(0, 0, 1.5)
		check("on entre dans le donjon", dm.try_interact(p))
	if f == 40:
		var grid = dm.grid
		# une case de mur à côté d'une case de sol de la salle d'entrée
		var room: Rect2i = dm.entrance_room
		var floor_y: float = dm.FLOOR_Y
		var wall := Vector2i(room.position.x - 1, room.get_center().y)
		for y in range(room.position.y, room.end.y):
			var cand := Vector2i(room.position.x - 1, y)
			if grid.body_blocked(cand, floor_y):
				wall = cand
				break
		check("la case choisie est un mur", grid.body_blocked(wall, floor_y))
		var items = root.get_node("Items")
		var pk = world.spawn_pickup(items.get_item("wood"), Vector3(wall.x + 0.5, floor_y, wall.y + 0.5), 3, dm._content)
		var c: Vector2i = world.cell_at(pk.global_position)
		check("l'objet n'est pas dans le mur (case %s)" % [c], not grid.body_blocked(c, pk.global_position.y))
		check("posé sur le sol du donjon (%.2f)" % pk.global_position.y, absf(pk.global_position.y - floor_y) < 0.6)
		check("tout près du point de chute", Vector2(c.x - wall.x, c.y - wall.y).length() <= 2.5)
		# dehors : contre un mur de blocs
		var s: Vector2i = world.spawn_cell + Vector2i(6, 6)
		var hgt: float = world.terrain_height(s)
		var free = world.free_drop_position(Vector3(s.x + 0.5, hgt, s.y + 0.5))
		check("dehors, sur un sol libre : rien ne bouge", world.cell_at(free) == s)
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	return false
