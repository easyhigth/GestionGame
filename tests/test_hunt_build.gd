extends SceneTree
## Chasse : on frappe les animaux (poules, moutons, vaches) ; frappés, ils s'enfuient ; abattus, ils
## laissent viande, laine ou cuir. Mode construction : la caméra descend jusqu'au ras du sol (Maj+molette,
## T / G) pour voir si une base touche bien le sol. Captures hb_XX_nom.png.
var f := 0
var p; var w; var items
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/hb_"
var phase := ""
var phase_at := 0.0
var hen; var cow
var bm
var meat0 := 0

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

func ground(at: Vector3) -> Vector3:
	at.y = w.support_height(at, w.terrain_height(w.cell_at(at)) + 0.5)
	return at

## Viande de la poule posée au sol près du héros (ou déjà ramassée) ; on ne compte pas tous les objets
## du monde : d'autres tas peuvent se regrouper ou disparaître au même moment.
func meat_near() -> int:
	var n := 0
	for q in get_nodes_in_group("pickups"):
		if not q.is_taken() and q.item and q.item.id == "viande_crue" and q.global_position.distance_to(p.global_position) < 5.0:
			n += q.count
	return n + p.inventory.count(items.get_item("viande_crue"))

func swing() -> void:
	p._on_attack_landed(0, {"arc": 150, "dmg": 1.0})

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p:
		p._invulnerable_left = 5.0
	if f == 8:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		get_first_node_in_group("raids").enabled = false
		get_first_node_in_group("day_cycle").hour = 11.0
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		for v in get_nodes_in_group("villagers"): v.queue_free()
		p.set_camera_mode(0, false)
		p.cam_pitch = p.clamp_pitch(0.3)
		var ls = get_first_node_in_group("livestock")
		var fwd := Vector3(-sin(p.cam_yaw), 0, -cos(p.cam_yaw))
		hen = ls.spawn("poule", ground(p.global_position + fwd * 1.6))
		cow = ls.spawn("vache", ground(p.global_position + fwd * 3.5 + fwd.cross(Vector3.UP) * 1.5))
		p.facing = fwd
		print("== chasse")
		go("hunt")
	if phase == "":
		return false
	if since() > 20000.0:
		check("l'étape « %s » aboutit" % phase, false)
		print("RÉSULTAT : échec")
		return true
	match phase:
		"hunt":
			if since() > 500.0 and not has_meta("hit1"):
				set_meta("hit1", true)
				meat0 = meat_near()
				# la poule a pu picorer plus loin : on la remet juste devant le héros
				hen._flee_left = 0.0
				hen.global_position = ground(p.global_position + p.facing * 1.2)
				var hp0: int = hen.hp
				var to: Vector3 = hen.global_position - p.global_position
				to.y = 0.0
				p.facing = to.normalized()
				swing()
				check("la poule est touchée (%d → %d PV)" % [hp0, hen.hp if is_instance_valid(hen) else 0], not is_instance_valid(hen) or hen.hp < hp0)
				shot("01_poule_touchee.png")
			if has_meta("hit1") and since() > 700.0 and not has_meta("dead1"):
				# on l'achève
				for i in 6:
					if is_instance_valid(hen) and hen.is_alive():
						hen._flee_left = 0.0
						var to2: Vector3 = hen.global_position - p.global_position
						to2.y = 0.0
						if to2.length() > 2.0:
							hen.global_position = ground(p.global_position + to2.normalized() * 1.5)
						p.facing = (hen.global_position - p.global_position).normalized()
						swing()
				set_meta("dead1", true)
			if has_meta("dead1") and since() > 1100.0 and not has_meta("checked1"):
				set_meta("checked1", true)
				check("poule abattue", not is_instance_valid(hen) or not hen.is_alive())
				check("elle laisse de la viande (%d)" % (meat_near() - meat0), meat_near() > meat0)
				# la vache frappée s'enfuit
				var to3: Vector3 = cow.global_position - p.global_position
				to3.y = 0.0
				if to3.length() > 2.0:
					cow.global_position = ground(p.global_position + to3.normalized() * 1.8)
				p.facing = (cow.global_position - p.global_position).normalized()
				set_meta("cow_from", cow.global_position)
				swing()
				check("la vache est touchée et s'enfuit", cow.hp < cow.max_hp() and cow._flee_left > 0.0)
			if has_meta("checked1") and since() > 2200.0:
				var moved: float = cow.global_position.distance_to(get_meta("cow_from"))
				check("la vache a détalé (%.1f m)" % moved, moved > 1.5)
				shot("02_vache_fuit.png")
				# visée : le viseur accroche l'animal
				var d: Vector3 = (cow.global_position + Vector3(0, 0.8, 0) - p.camera.global_position).normalized()
				p._mouse_seen = true
				cow._flee_left = 0.0
				cow.set_process(false)
				p.cam_yaw = atan2(-d.x, -d.z)
				p.cam_pitch = p.clamp_pitch(asin(-d.y))
				go("aim")
		"aim":
			# la caméra glisse vers sa place : on la repointe sur la vache jusqu'à ce que le viseur l'accroche
			if since() > 300.0 and p.aim.get("kind") != "animal" and since() < 3000.0:
				var d2: Vector3 = (cow.global_position + Vector3(0, 0.8, 0) - p.camera.global_position).normalized()
				p.cam_yaw = atan2(-d2.x, -d2.z)
				p.cam_pitch = p.clamp_pitch(asin(-d2.y))
			elif since() > 300.0:
				check("le viseur accroche la vache (%s)" % p.aim.get("kind"), p.aim.get("kind") == "animal")
				# mode construction : une base au sol, vue d'en haut puis au ras du sol
				var c: Vector2i = w.cell_at(p.global_position + Vector3(3, 0, 0))
				var hy := floori(w.terrain_height(c) + 0.45)
				for dx in 3:
					for dz in 3:
						w.build.place_block(Vector3i(c.x + dx, hy, c.y + dz), items.get_item("bloc_planches"))
				bm = p.get_node_or_null("BuildMode")
				bm.toggle(true)
				bm._focus = Vector3(c.x + 1.5, hy, c.y + 1.5)
				go("high")
		"high":
			if since() > 800.0:
				shot("03_construction_haut.png")
				var hi: float = bm.camera_pitch_deg()
				# Maj + molette vers le haut : la caméra descend
				for i in 12:
					var mb := InputEventMouseButton.new()
					mb.button_index = MOUSE_BUTTON_WHEEL_UP
					mb.pressed = true
					mb.shift_pressed = true
					bm._unhandled_input(mb)
				check("Maj+molette : la caméra descend (%.0f° → %.0f°)" % [hi, bm.camera_pitch_deg()], bm.camera_pitch_deg() < 10.0)
				go("low")
		"low":
			if since() > 800.0:
				var cam: Camera3D = bm._cam
				var gy: float = w.ground_height_at(cam.global_position)
				check("caméra au ras du sol, sans passer dessous (%.2f m au-dessus)" % (cam.global_position.y - gy), cam.global_position.y - gy >= 0.5 and cam.global_position.y - gy < 4.0)
				shot("04_construction_ras_du_sol.png")
				bm._tilt(1.0, 2.0)
				check("et elle remonte (%.0f°)" % bm.camera_pitch_deg(), bm.camera_pitch_deg() > 80.0)
				bm.toggle(false)
				print("RÉSULTAT : ", "tout est bon" if ok else "échec")
				return true
	return false
