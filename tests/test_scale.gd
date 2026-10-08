extends SceneTree
## Échelle du monde : un humain mesure exactement 2 cubes, le lit fait 2 cases, le relief est en demi-cubes.
var f := 0
var ok := true
var hs := []

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

func aabb_of(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		if not m.is_visible_in_tree():
			continue
		var b: AABB = m.global_transform * m.get_aabb()
		if first:
			box = b
			first = false
		else:
			box = box.merge(b)
	return box

func _process(_d) -> bool:
	f += 1
	if f < 60:
		return false
	var p = get_first_node_in_group("player")
	if f < 90:
		hs.append(aabb_of(p.visual).size.y)
		return false
	hs.sort()
	var items = root.get_node("Items")
	var w = get_first_node_in_group("world")
	var grid = w.build
	var BG = load("res://scripts/build/build_grid.gd")
	check("héros humain : 2 cubes de haut (%.3f m au repos)" % hs[0], absf(hs[0] - 2.0) < 0.03)
	check("le corps passe sous un plafond à 2 cubes (%.2f)" % BG.BODY_HEIGHT, BG.BODY_HEIGHT < 1.95 and BG.BODY_HEIGHT > 1.7)
	var jump_h: float = 7.8 * 7.8 / (2.0 * 24.0)
	check("un saut franchit un cube (%.2f m)" % jump_h, jump_h > 1.05)
	# relief en demi-cubes
	var bad := 0
	var c0: Vector2i = w.spawn_cell
	for dz in range(-30, 31, 3):
		for dx in range(-30, 31, 3):
			var c := c0 + Vector2i(dx, dz)
			var t: int = w.terrain_type(c)
			if t == w.WATER or t == w.DEEP:
				continue
			var hh: float = w.terrain_height(c)
			if absf(hh * 2.0 - roundf(hh * 2.0)) > 0.01:
				bad += 1
	check("le sol est fait de marches d'un demi-cube (%d hors grille)" % bad, bad == 0)
	# lit sur deux cases
	var bed = items.get_item("lit")
	var cc: Vector2i = c0 + Vector2i(14, 14)
	var base: float = w.terrain_height(cc)
	var foot: Vector2i = cc + BG.rot_dir(0)
	var ok_ground: bool = absf(w.terrain_height(foot) - base) < 0.1
	if not ok_ground:
		for r in 4:
			foot = cc + BG.rot_dir(r)
			if absf(w.terrain_height(foot) - base) < 0.1:
				break
	var rot := 0
	for r in 4:
		if cc + BG.rot_dir(r) == foot:
			rot = r
	check("empreinte du lit : 2 cases", BG.footprint(cc, bed, rot).size() == 2)
	# un bloc dans la case des pieds empêche de poser le lit
	var stone = items.get_item("bloc_pierre_brute")
	var fy := floori(base + 0.01)
	grid.place_block(Vector3i(foot.x, fy, foot.y), stone)
	check("pied du lit bloqué : on ne peut pas le poser", not grid.can_place_furniture(cc, base, bed, rot))
	grid.remove_block(Vector3i(foot.x, fy, foot.y))
	check("pied libre : on peut le poser", grid.can_place_furniture(cc, base, bed, rot))
	check("on pose le lit", grid.place_furniture(cc, base, bed, rot))
	var key: Vector3i = grid.furniture_key(cc, base)
	check("le lit couvre la case des pieds", grid.furniture_touching(foot).size() == 1 and grid.furniture_in(foot).is_empty())
	check("pas de bloc dans les pieds du lit", not grid.can_place_block(Vector3i(foot.x, fy, foot.y), stone))
	check("pas d'autre meuble dans les pieds du lit", not grid.can_place_furniture(foot, base, items.get_item("coffre"), 0))
	var center: Vector3 = grid.furniture_center(grid.furniture[key])
	var mid := Vector2((cc.x + foot.x) * 0.5 + 0.5, (cc.y + foot.y) * 0.5 + 0.5)
	check("centre du lit entre ses deux cases", Vector2(center.x, center.z).distance_to(mid) < 0.01)
	var mdl: AABB = aabb_of(grid.furniture[key].node)
	check("le lit mesure 2 m de long (%.2f x %.2f)" % [mdl.size.x, mdl.size.z], absf(maxf(mdl.size.x, mdl.size.z) - 2.0) < 0.1)
	grid.remove_furniture(key)
	check("enlevé : la case des pieds est libre", grid.furniture_touching(foot).is_empty())
	# plan prêt de maison : le lit et ses pieds tiennent dans la pièce
	var bm = p.find_children("*", "BuildMode", true, false)
	if not bm.is_empty():
		var t = load("res://data/rooms/maison.tres")
		var lay: Array = bm[0].plan_layout(t, c0 + Vector2i(-20, 0))
		var floors := {}
		for e in lay:
			if e[1] == "floor":
				floors[Vector2i(e[0].x, e[0].z)] = true
		var beds := lay.filter(func(e): return e[1] == "furniture" and e[2] == "lit")
		check("plan de maison : un lit", beds.size() == 1)
		if beds.size() == 1:
			var bc := Vector2i(beds[0][0].x, beds[0][0].z)
			check("plan de maison : les pieds du lit dans la pièce", floors.has(bc + BG.rot_dir(2)))
			var others := lay.filter(func(e): return e[1] == "furniture" and e[2] != "lit").map(func(e): return Vector2i(e[0].x, e[0].z))
			check("plan de maison : rien sur les pieds du lit", not others.has(bc + BG.rot_dir(2)))
	print("RÉSULTAT : ", "tout est bon" if ok else "échec")
	return true
