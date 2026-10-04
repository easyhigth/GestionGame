extends SceneTree
## Session de jeu automatique en 3e personne, visée à la souris : marcher, combattre deux monstres au
## viseur, lancer une compétence, poser des blocs, ouvrir le sac, passer la nuit près d'une torche.
## Une capture à chaque moment (se_XX_nom.png) pour repérer les défauts visuels ; vérifie aussi le guide
## réduit à une ligne et l'aide qui s'efface après les premières minutes.
var f := 0
var p; var w; var items; var hud; var guide
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/se_"
var phase := ""
var phase_at := 0.0
var foes := []
var start_pos := Vector3.ZERO
var hp0 := 0
var blocks0 := 0

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

func shot(n):
	root.get_viewport().get_texture().get_image().save_png(out + n)
	print("saved ", n)

func go(ph: String) -> void:
	phase = ph
	phase_at = game_ms

func since() -> float:
	return game_ms - phase_at

## Oriente la caméra (3e personne) vers `target`.
func look_at_point(target: Vector3) -> void:
	var cam: Camera3D = p.camera
	var d: Vector3 = (target - cam.global_position).normalized()
	p.cam_yaw = atan2(-d.x, -d.z)
	p.cam_pitch = p.clamp_pitch(asin(-d.y))

func ground(at: Vector3) -> Vector3:
	at.y = w.support_height(at, w.terrain_height(w.cell_at(at)) + 0.5)
	return at

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p:
		p._invulnerable_left = 5.0
	if f == 8:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		hud = get_first_node_in_group("hud"); guide = get_first_node_in_group("guide")
		get_first_node_in_group("raids").enabled = false
		get_first_node_in_group("day_cycle").hour = 10.0
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		p._mouse_seen = true
		p.set_camera_mode(0, false)
		start_pos = p.global_position
		check("guide : conseil détaillé visible au début", guide and not guide.is_collapsed())
		Input.action_press("move_up")
		print("== marcher")
		go("walk")
	if phase == "":
		return false
	if since() > 20000.0:
		check("l'étape « %s » aboutit" % phase, false)
		print("RÉSULTAT : échec")
		return true
	match phase:
		"walk":
			if since() > 1500.0:
				shot("01_marche.png")
				Input.action_release("move_up")
				check("le héros avance (%.1f m)" % p.global_position.distance_to(start_pos), p.global_position.distance_to(start_pos) > 2.0)
				# deux squelettes devant le héros
				var fwd: Vector3 = (Vector3(-sin(p.cam_yaw), 0, -cos(p.cam_yaw))).normalized()
				for i in 2:
					var foe = load("res://scenes/enemies/enemy.tscn").instantiate()
					foe.data = load("res://data/enemies/squelette.tres")
					foe.level = 1
					foe.set_physics_process(false)   # cibles immobiles
					w.add_child(foe)
					foe.global_position = ground(p.global_position + fwd * (1.7 + i * 0.8) + fwd.cross(Vector3.UP) * (i * 1.4 - 0.7))
					foes.append(foe)
				hp0 = foes[0].health.current + foes[1].health.current
				print("== combattre au viseur")
				go("fight")
		"fight":
			var alive := foes.filter(func(e): return is_instance_valid(e) and e.is_alive())
			for e in alive:
				# mannequins : immobiles et sans garde (sinon les squelettes parent les coups)
				e.set_physics_process(false)
				e.blocking = false
			if not alive.is_empty():
				look_at_point(alive[0].global_position + Vector3(0, 0.6, 0))
			if since() > 250.0 and not has_meta("aimed"):
				set_meta("aimed", true)
				check("le viseur accroche un ennemi (%s%s)" % [p.aim.get("kind"), " assisté" if p.aim.get("assist", false) else ""], p.aim.get("kind") == "enemy")
			if int(since() / 220.0) % 2 == 0:
				Input.action_press("attack")
			else:
				Input.action_release("attack")
			if since() > 1200.0 and not has_meta("shot_fight"):
				set_meta("shot_fight", true)
				shot("02_combat.png")
			if since() > 3500.0:
				Input.action_release("attack")
				var hp1 := 0
				for e in foes:
					if is_instance_valid(e) and e.is_alive():
						hp1 += e.health.current
				check("les coups portent (%d → %d PV)" % [hp0, hp1], hp1 < hp0)
				p.cast_ability(0)
				go("skill")
		"skill":
			if since() > 350.0:
				shot("03_competence.png")
				for e in foes:
					if is_instance_valid(e): e.queue_free()
				# poser des blocs : viser le sol devant soi
				p.inventory.add(items.get_item("bloc_planches"), 20)
				p.hand.selected = "bloc_planches"
				blocks0 = w.build.blocks.size()
				print("== poser des blocs")
				go("place")
		"place":
			var fwd2: Vector3 = (Vector3(-sin(p.cam_yaw), 0, -cos(p.cam_yaw))).normalized()
			var spot := ground(p.global_position + fwd2 * 2.5)
			look_at_point(spot + Vector3(0, 0.05, 0))
			if since() > 300.0 and since() < 1400.0 and int(since()) % 300 < 40:
				var mb := InputEventMouseButton.new()
				mb.button_index = MOUSE_BUTTON_RIGHT
				mb.pressed = true
				p._input(mb)
			if since() > 1600.0:
				shot("04_blocs.png")
				var n: int = w.build.blocks.size()
				check("des blocs posés au viseur (%d → %d)" % [blocks0, n], n > blocks0)
				p.hand.selected = ""
				p.open_inventory.emit(p)
				go("inventory")
		"inventory":
			if since() > 400.0:
				shot("05_sac.png")
				var inv = get_first_node_in_group("inventory_ui")
				if inv: inv.close()
				# la nuit, une torche à côté
				get_first_node_in_group("day_cycle").hour = 22.5
				var fwd3: Vector3 = (Vector3(-sin(p.cam_yaw), 0, -cos(p.cam_yaw))).normalized()
				var tc: Vector2i = w.cell_at(p.global_position + fwd3 * 2.0 + fwd3.cross(Vector3.UP) * 1.5)
				var torch = items.get_item("torche")
				if torch:
					w.build.place_furniture(tc, w.terrain_height(tc), torch, 0)
				p.cam_pitch = p.clamp_pitch(0.25)
				go("night")
		"night":
			if since() > 1500.0:
				shot("06_nuit.png")
				# le guide se réduit à une ligne, l'aide s'efface après quelques minutes
				guide._hint_left = 0.01
				hud._help_age = hud.HELP_TIME + 1.0
				go("calm")
		"calm":
			if since() > 300.0:
				check("guide réduit à une ligne", guide.is_collapsed())
				check("rappel des touches effacé", not hud.info.visible)
				shot("07_epure.png")
				print("RÉSULTAT : ", "tout est bon" if ok else "échec")
				return true
	return false
