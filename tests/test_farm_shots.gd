extends SceneTree
var f := 0
var p; var w; var items; var fm; var vn; var k; var dc; var hud; var gd; var H
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/g_"
var plot0: Vector2i
var farmer
var food0 := 0.0

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

func count(id: String) -> int:
	return p.inventory.count(items.get_item(id))

func later(key: String, ms: int) -> bool:
	if not has_meta(key) or has_meta(key + "_done"):
		return false
	if game_ms - float(get_meta(key)) < ms:
		return false
	set_meta(key + "_done", true)
	return true

func start(key: String) -> void:
	set_meta(key, game_ms)

func collect(r := 6.0) -> void:
	for n in w.get_node("Village").get_children():
		if n.has_method("take") and not n.is_taken() and n.global_position.distance_to(p.global_position) < r:
			p.try_pickup(n)

func craft(id: String) -> bool:
	for r in items.recipes:
		if r.result.id == id:
			var done: bool = r.craft(p.inventory, p.is_near_workbench(), p.nearby_stations())
			if done:
				p.crafted.emit(id)
			return done
	return false

## Une rangée de 8 cases d'herbe libres et plates (loin de l'eau).
func find_row(dry: bool) -> Vector2i:
	var s: Vector2i = w.spawn_cell
	for r in range(10, 70):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c: Vector2i = s + Vector2i(dx, dz)
				var good := true
				for i in range(-1, 8):
					var n := c + Vector2i(i, 0)
					if w.terrain_type(n) != 3 or w.decor_at(n) != 0 or absf(w.terrain_height(n) - w.terrain_height(c)) > 0.6 or w.village_prop_at(n, w.terrain_height(n)) != null:
						good = false
						break
				if good and w.near_water(c, 5) != (not dry):
					continue
				if good:
					return c
	return Vector2i(-1, -1)

func stand_before(c: Vector2i) -> void:
	var at: Vector3 = w.cell_center(c - Vector2i(1, 0))
	p.global_position = at
	p.facing = Vector3(1, 0, 0)


func find_area() -> Vector2i:
	var s: Vector2i = w.spawn_cell
	for r in range(8, 60):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c: Vector2i = s + Vector2i(dx, dz)
				var good := true
				for z in range(0, 3):
					for x in range(-1, 8):
						var n := c + Vector2i(x, z)
						if w.terrain_type(n) != 3 or w.decor_at(n) in [1, 2, 4, 7, 8] or absf(w.terrain_height(n) - w.terrain_height(c)) > 0.6 or w.village_prop_at(n, w.terrain_height(n)) != null:
							good = false
							break
					if not good: break
				if good:
					return c
	return Vector2i(-1, -1)

var area: Vector2i

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p: p._invulnerable_left = 5.0
	if f == 10:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		fm = get_first_node_in_group("farming"); vn = get_first_node_in_group("village_needs"); k = get_first_node_in_group("kingdom")
		dc = get_first_node_in_group("day_cycle"); hud = get_first_node_in_group("hud")
		get_first_node_in_group("raids").enabled = false
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		get_first_node_in_group("quests")._offer_timer = 9999.0
		dc.hour = 10.0
		area = find_area()
		print("zone ", area)
		var kinds := ["ble", "carotte", "pomme_de_terre"]
		for z in 3:
			for x in 8:
				var c := area + Vector2i(x, z)
				fm.till(c, true)
				fm.plant(c, kinds[z], [0.0, 0.2, 0.4, 0.55, 0.7, 0.85, 1.0, 1.0][x])
				if x >= 6:
					fm.crops[c].g = 9999.0
				fm._show(c)
		farmer = vn.members()[0]
		k.assign(farmer, fm.fields_room)
		farmer.global_position = w.cell_center(area + Vector2i(7, 3))
		var c0: Vector3 = w.cell_center(area + Vector2i(3, 1))
		p.global_position = w.cell_center(area + Vector2i(3, 4))
		p.facing = Vector3(0, 0, -1)
		p.inventory.add(items.get_item("houe"), 1)
		p.inventory.add(items.get_item("graines_ble"), 5)
		p.cam_yaw = deg_to_rad(20.0); p.cam_pitch = deg_to_rad(30.0); p.camera_zoom = 0.75; p.snap_camera()
		start("a")
	if later("a", 1200):
		shot("01_champ.png")
		# semer : case fantôme devant le héros
		var row := area + Vector2i(0, -2)
		p.global_position = w.cell_center(row + Vector2i(-1, 0))
		p.facing = Vector3(1, 0, 0)
		p.hand.selected = "graines_ble"
		p.hand.selection_changed.emit()
		p.cam_yaw = deg_to_rad(120.0); p.cam_pitch = deg_to_rad(34.0); p.camera_zoom = 0.62; p.snap_camera()
		start("b")
	if later("b", 900):
		print("fantôme ", p.hand._ghost.visible, " ", p.hand._ghost.global_position, " cible ", p.hand._target, " joueur ", p.global_position, " face ", p.facing)
		shot("02_semer.png")
		p.cam_yaw = deg_to_rad(300.0); p.snap_camera()
		start("c")
	if later("c", 500):
		shot("03_semer.png")
		print("RÉSULTAT : tout est bon (captures)")
		return true
	return false
