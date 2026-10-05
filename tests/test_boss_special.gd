extends SceneTree
## Attaques spéciales des boss : chacun des neuf boss de région lance la sienne (ronces, éboulement,
## blizzard...), annoncée au sol, et elle blesse le héros resté sur place. Captures bs_XX_nom.png.
var f := 0
var p; var w
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/bs_"
var ids := ["boss_dryade_mere", "boss_ogre_roi", "boss_ours_ancien", "boss_quetzal", "boss_reine_araignee",
	"boss_roi_sanglier", "boss_scorpion_empereur", "boss_seigneur_ignarok", "boss_slime_primordial"]
var idx := -1
var b
var at := 0.0
var cast := false
var used := ""
var shot_done := false
var hit := false
var hp0 := 0
var kinds := {}

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

func next_boss() -> void:
	if b and is_instance_valid(b):
		b.queue_free()
	idx += 1
	if idx >= ids.size():
		return
	var data = load("res://data/enemies/%s.tres" % ids[idx])
	check("%s a une attaque spéciale (%s)" % [ids[idx], data.special_attack], data.special_attack != "" and data.special_name != "")
	check("%s : attaque différente des autres boss" % ids[idx], not kinds.has(data.special_attack))
	kinds[data.special_attack] = true
	b = load("res://scenes/enemies/boss.tscn").instantiate()
	b.data = data
	b.level = 8
	b.powers = PackedStringArray(["onde"])
	w.add_child(b)
	b.global_position = ground(p.global_position + Vector3(0, 0, -9.0))
	b.home = b.global_position
	b.special_used.connect(func(k): used = k)
	b.wake()
	p.health.heal(p.health.max_health)
	hp0 = p.health.current
	cast = false
	used = ""
	shot_done = false
	hit = false
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
		# les habitants s'interposeraient entre le boss et le héros
		for x in get_nodes_in_group("villagers"): x.queue_free()
		p.set_camera_mode(0, false)
		p.cam_pitch = p.clamp_pitch(0.5)
		next_boss()
	if idx >= ids.size():
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	if b == null:
		return false
	# le boss ne fait que son attaque spéciale (pas de coups ni d'autres pouvoirs pendant le test)
	b._target = p
	b._power_timer = 999.0
	b._attack_cooldown = 999.0
	p.velocity = Vector3.ZERO
	var t := game_ms - at
	if not cast and t > 300.0:
		cast = true
		b._special(b.data.special_attack)
		check("%s lance « %s »" % [ids[idx], b.data.special_name], used == b.data.special_attack)
	if cast and not shot_done and t > 1150.0:
		shot_done = true
		root.get_viewport().get_texture().get_image().save_png(out + "%02d_%s.png" % [idx, b.data.special_attack])
	if cast and not hit and p.health.current < hp0:
		hit = true
		check("%s : l'attaque spéciale blesse le héros (%d -> %d)" % [ids[idx], hp0, p.health.current], true)
	if (hit and shot_done and t > 2500.0) or t > 9000.0:
		if not hit:
			check("%s : l'attaque spéciale touche le héros dans les 9 s" % ids[idx], false)
		check("%s : le boss est toujours debout" % ids[idx], b.is_alive())
		next_boss()
	return false
