extends SceneTree
## Drapeau du royaume : on le reçoit au départ ; tant qu'il n'est pas planté, pas de camp ni de raids (les raids
## de l'histoire tombent sur le héros) ; planté, il devient le centre du camp (raids, habitants, cartes) ; on le
## reprend en le frappant (il revient au sac) et on le replante ailleurs. Captures fl_XX_nom.png.
var f := 0
var p; var w; var items; var rm
var ok := true
var step := 0
var wait := 0
var spot := Vector2i.ZERO
var spot2 := Vector2i.ZERO
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/fl_"

func _initialize():
	var h = load("res://scripts/hero/hero_profile.gd").new()
	h.hero_name = "Selka"
	h.race = load("res://data/races/humain.tres")
	h.hero_class = load("res://data/classes/guerrier.tres")
	h.job = load("res://data/jobs/chasseur.tres")
	h.skill = load("res://data/skills/vorace.tres")
	root.get_node("GameState").hero = h
	root.get_node("GameState").world_seed = 4242
	# départ normal (à mains nues) : le héros arrive seul, avec le drapeau dans le sac
	root.get_node("GameState").bare_start = true
	change_scene_to_file("res://scenes/main.tscn")

func check(name: String, cond: bool) -> void:
	print(("  OK  " if cond else "  ÉCHEC  ") + name)
	ok = ok and cond

func shot(n):
	root.get_viewport().get_texture().get_image().save_png(out + n)
	print("saved ", n)

## Une case d'herbe libre et plate, à `dist` cases du héros.
func meadow(dist: int) -> Vector2i:
	var home: Vector2i = w.cell_at(p.global_position)
	for r in range(dist, dist + 150, 3):
		for dx in range(-r, r + 1, 4):
			var c: Vector2i = home + Vector2i(dx, r)
			var flat := true
			for ax in range(-2, 3):
				for az in range(-2, 3):
					var n: Vector2i = c + Vector2i(ax, az)
					if w.terrain_type(n) != w.GRASS or absf(w.terrain_height(n) - w.terrain_height(c)) > 0.6 \
							or not w.build.column(n).is_empty() or not w.build.furniture_in(n).is_empty() or w.decor_at(n) != w.D_NONE:
						flat = false
			if flat:
				return c
	return home + Vector2i(0, dist)

func _process(_d) -> bool:
	f += 1
	if p:
		p._invulnerable_left = 5.0
	if wait > 0:
		wait -= 1
		return false
	if f < 40:
		return false
	match step:
		0:
			p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
			rm = get_first_node_in_group("raids")
			get_first_node_in_group("day_cycle").hour = 11.0
			for e in get_nodes_in_group("enemy_units"): e.queue_free()
			var flag = items.get_item(w.FLAG_ID)
			check("le drapeau du royaume est dans le sac au départ", p.inventory.count(flag) == 1)
			check("pas encore de camp", not w.has_home())
			# sans camp, les raids attendent
			rm._timer = 0.0
			step = 1; wait = 10
		1:
			check("pas de raid sans drapeau planté", rm.raid.is_empty())
			# un raid de l'histoire, lui, tombe sur le héros là où il est
			rm.announce({"key": "test", "name": "Bande de test", "types": ["gobelin"], "leader": "gobelin", "extra": 0})
			check("raid de l'histoire sans camp : il vise le héros (%.0f m)" % rm.village_center().distance_to(p.global_position), rm.village_center().distance_to(p.global_position) < 1.0)
			rm.raid = {}
			# planter le drapeau dans un pré
			spot = meadow(30)
			p.global_position = w.cell_center(spot + Vector2i(0, 3))
			var flag = items.get_item(w.FLAG_ID)
			w.build.place_furniture(spot, w.terrain_height(spot), flag, 0)
			p.inventory.remove(flag, 1)
			check("drapeau planté : le camp est là (%s)" % str(w.home_cell), w.has_home() and w.home_cell == spot)
			check("centre du camp = le drapeau", w.home_center().distance_to(w.cell_center(spot)) < 0.1)
			check("les pillards viseraient le camp", rm.village_center().distance_to(w.cell_center(spot)) < 0.1)
			# la zone du camp : des bornes autour du drapeau, rayon selon le rang du royaume
			var cb = get_first_node_in_group("camp_border")
			check("bornes de la zone autour du drapeau (%d)" % (cb._posts.multimesh.instance_count if cb else 0), cb != null and cb._posts.multimesh.instance_count >= 16)
			check("zone du campement : %d m" % roundi(w.home_radius()), is_equal_approx(w.home_radius(), 16.0))
			check("le drapeau est dans la zone, loin dehors non", w.in_home_zone(w.cell_center(spot)) and not w.in_home_zone(w.cell_center(spot + Vector2i(40, 0))))
			# raids : leur force vient du royaume, pas du niveau du héros
			p.level = 60
			rm.announce()
			check("raid ordinaire : niveau = menace du royaume (%d), pas celui du héros (%d)" % [int(rm.raid.level), p.power_level()], int(rm.raid.level) == rm.threat_level() and int(rm.raid.level) < 10)
			check("les pillards arrivent de l'extérieur de la zone", Vector2(rm.raid.spawn.x - w.home_center().x, rm.raid.spawn.z - w.home_center().z).length() > w.home_radius())
			rm.raid = {}
			p.level = 1
			p.set_camera_mode(1, false)
			step = 20; wait = 30
		20:
			# le royaume monte de rang : la zone s'agrandit
			var k = get_first_node_in_group("kingdom")
			k.rank = 2
			step = 21; wait = 5
		21:
			var cb = get_first_node_in_group("camp_border")
			check("rang Village : zone de %d m, bornes replacées" % roundi(w.home_radius()), is_equal_approx(w.home_radius(), 26.0) and is_equal_approx(cb._built_for.z, 26.0))
			step = 2; wait = 20
		2:
			shot("01_drapeau_plante.png")
			# reprendre le drapeau : on le frappe, il revient au sac
			var key: Vector3i = w.build.furniture_key(spot, w.terrain_height(spot))
			var hv = load("res://scripts/world/harvest.gd")
			for i in 40:
				if not w.build.furniture.has(key):
					break
				hv.hit_built(w, {"furniture": key}, 3.0, p)
			check("drapeau frappé : il revient au sac", p.inventory.count(items.get_item(w.FLAG_ID)) == 1 and not w.build.furniture.has(key))
			check("plus de camp", not w.has_home())
			check("les habitants restent au dernier camp", w.home_center().distance_to(w.cell_center(spot)) < 0.1)
			# le replanter ailleurs
			spot2 = meadow(70)
			var flag = items.get_item(w.FLAG_ID)
			w.build.place_furniture(spot2, w.terrain_height(spot2), flag, 0)
			p.inventory.remove(flag, 1)
			check("replanté ailleurs : le camp a déménagé (%s)" % str(w.home_cell), w.home_cell == spot2)
			# un deuxième drapeau (fabriqué) : l'ancien revient au sac
			w.build.place_furniture(spot, w.terrain_height(spot), flag, 0)
			check("un seul drapeau planté : l'ancien revient au sac", w.home_cell == spot and p.inventory.count(flag) == 1)
			# sauvegarde
			var st: Dictionary = w.export_state()
			check("la sauvegarde connaît le drapeau", int(st.get("flag_v", 0)) == 1)
			# ancienne sauvegarde (sans drapeau) : il est planté près de l'arrivée
			var key2: Vector3i = w.build.furniture_key(spot, w.terrain_height(spot))
			w.build.remove_furniture(key2)
			w.plant_legacy_flag()
			check("ancienne sauvegarde : drapeau planté près de l'arrivée (%.0f cases)" % Vector2(w.home_cell - w.spawn_cell).length(),
				w.has_home() and Vector2(w.home_cell - w.spawn_cell).length() < 9.0)
			# l'histoire n'oblige pas à gérer : « Construis 2 maisons » se franchit aussi en aventurier
			var sto = get_first_node_in_group("story")
			var idx := -1
			for i in sto.STEPS.size():
				if sto.STEPS[i][0] == "maisons":
					idx = i
			sto.step = idx
			sto._adv_base = sto._kills()
			print("   suivi : ", sto.tracker_text())
			check("étape de gestion : la voie de l'aventurier est proposée", "aventurier" in sto.tracker_text())
			sto._adv_base = sto._kills() - sto.adventure_need(sto.current())
			sto._check()
			check("assez de monstres vaincus : l'étape « maisons » est franchie sans bâtir", sto.step == idx + 1)
			step = 3; wait = 10
		3:
			print("RÉSULTAT : ", "tout est bon" if ok else "échec")
			return true
	return false
