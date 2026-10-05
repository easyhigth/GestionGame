extends SceneTree
## Ennemis à distance : la fée, le squelette, la harpie, la salamandre... tirent de loin quand le héros
## est hors de portée de leur coup (bande rouge au sol pendant la préparation, puis un projectile qui
## part tout droit et blesse le héros). Captures rg_XX_nom.png.
var f := 0
var p; var w
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/rg_"
var ids := ["fee_sauvage", "squelette", "harpie", "salamandre", "dryade_corrompue", "esprit_follet", "serpent", "elementaire_glace"]
var idx := -1
var e
var at := 0.0
var bolt_seen := false
var shot_done := false
var hp0 := 0

func _initialize():
	var h = load("res://scripts/hero/hero_profile.gd").new()
	h.hero_name = "Selka"
	h.race = load("res://data/races/humain.tres")
	h.hero_class = load("res://data/classes/guerrier.tres")
	h.job = load("res://data/jobs/chasseur.tres")
	h.skill = load("res://data/skills/vorace.tres")
	root.get_node("GameState").hero = h
	root.get_node("GameState").world_seed = 4242
	change_scene_to_file("res://scenes/main.tscn")

func check(name: String, cond: bool) -> void:
	print(("  OK  " if cond else "  ÉCHEC  ") + name)
	ok = ok and cond

func ground(pos: Vector3) -> Vector3:
	pos.y = w.support_height(pos, w.terrain_height(w.cell_at(pos)) + 0.5)
	return pos

func bolts() -> Array:
	var r := []
	for c in current_scene.get_children():
		if c.get_script() and c.get_script().get_global_name() == "MagicBolt":
			r.append(c)
	return r

func next_enemy() -> void:
	if e and is_instance_valid(e):
		e.queue_free()
	idx += 1
	if idx >= ids.size():
		return
	e = load("res://scenes/enemies/enemy.tscn").instantiate()
	e.data = load("res://data/enemies/%s.tres" % ids[idx])
	e.level = 5
	w.add_child(e)
	e.global_position = ground(p.global_position + Vector3(0, 0, -6.5))
	p.health.heal(p.health.max_health)
	hp0 = p.health.current
	bolt_seen = false
	shot_done = false
	at = game_ms
	print("== ", ids[idx])

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if f == 8:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world")
		get_first_node_in_group("raids").enabled = false
		get_first_node_in_group("day_cycle").hour = 11.0
		for x in get_nodes_in_group("enemy_units"): x.queue_free()
		p.set_camera_mode(0, false)
		p.cam_pitch = p.clamp_pitch(0.5)
		next_enemy()
	if idx >= ids.size():
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	if e == null:
		return false
	# près du village, les monstres ne repèrent pas le héros d'eux-mêmes : on le leur désigne
	if e._target == null:
		e._target = p
	# le héros reste sur place et garde de la vie
	p.velocity = Vector3.ZERO
	if p.health.current < p.health.max_health * 0.3:
		p.health.heal(p.health.max_health)
		hp0 = p.health.current
	if not bolt_seen and not bolts().is_empty():
		bolt_seen = true
		check("%s tire un projectile (à %.1f m)" % [ids[idx], e.global_position.distance_to(p.global_position)], true)
		if not shot_done:
			shot_done = true
			root.get_viewport().get_texture().get_image().save_png(out + "%02d_%s.png" % [idx, ids[idx]])
	if bolt_seen and p.health.current < hp0:
		check("%s : le tir blesse le héros (%d -> %d)" % [ids[idx], hp0, p.health.current], true)
		next_enemy()
	elif game_ms - at > 12000.0:
		check("%s tire et touche dans les 12 s (tir vu : %s)" % [ids[idx], bolt_seen], false)
		next_enemy()
	return false
