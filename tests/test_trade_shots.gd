extends SceneTree
var f := 0
var p; var w; var items; var fm; var vn; var k; var dc; var hud; var gd; var H
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/u_"
var tr
var m

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


func val(id: String) -> float:
	return tr.value_of(items.get_item(id))



var yaws := [0.0, 90.0, 180.0, 270.0]
var step := 0
var t0 := 0.0

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p: p._invulnerable_left = 5.0
	if f == 10:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		dc = get_first_node_in_group("day_cycle"); hud = get_first_node_in_group("hud"); tr = get_first_node_in_group("trade")
		get_first_node_in_group("raids").enabled = false
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		get_first_node_in_group("quests")._offer_timer = 9999.0
		dc.day = 2; dc.hour = 9.0
		tr._check = 0.0; tr._process(0.1)
		m = tr.merchant
		p.global_position = m.global_position + Vector3(1.2, 0, 0.6)
		t0 = game_ms + 800.0
	if f > 10 and game_ms >= t0:
		if step % 2 == 0:
			var i := step / 2
			if i >= yaws.size():
				print("RÉSULTAT : tout est bon (captures)")
				return true
			p.cam_yaw = deg_to_rad(yaws[i]); p.cam_pitch = deg_to_rad(26.0); p.camera_zoom = 1.0; p.snap_camera()
		else:
			shot("marchand_%d.png" % (step / 2))
		step += 1
		t0 = game_ms + 500.0
	return false
