extends SceneTree
## Animations du héros : une pose de sort par famille de classes, roulade en boule, saut (étirement à
## l'envol, écrasement à la réception) et geste d'outil quand on vise un arbre. Captures an_XX_nom.png.
var f := 0
var p; var w
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/an_"
var phase := ""
var phase_at := 0.0
const CLASSES := ["mage", "guerrier", "clerc", "rodeur", "assassin", "druide", "moine"]
var ci := 0
var ml

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

## Le héros se tourne de trois quarts vers la caméra.
func face_camera() -> void:
	var to: Vector3 = p.camera.global_position - p.global_position
	to.y = 0.0
	p.facing = to.normalized().rotated(Vector3.UP, 0.6)

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p:
		p._invulnerable_left = 5.0
	if f == 8:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world")
		ml = load("res://scripts/combat/move_library.gd")
		get_first_node_in_group("raids").enabled = false
		get_first_node_in_group("day_cycle").hour = 11.0
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		for v in get_nodes_in_group("villagers"): v.queue_free()
		p.set_camera_mode(0, false)
		p.cam_pitch = p.clamp_pitch(0.25)
		go("pose")
	if phase == "":
		return false
	if since() > 20000.0:
		check("l'étape « %s » aboutit" % phase, false)
		print("RÉSULTAT : échec")
		return true
	match phase:
		"pose":
			face_camera()
			if not has_meta("posed_%d" % ci):
				set_meta("posed_%d" % ci, true)
				var cls: String = CLASSES[ci]
				p.profile.hero_class = load("res://data/classes/%s.tres" % cls)
				p.skill._cast_pose("nova")
				var want: String = ml.cast_pose(cls)
				check("%s : pose « %s » (%s)" % [cls, want, p.visual.current_move()], p.visual.current_move() == want)
				set_meta("pose_at", since())
			elif since() - float(get_meta("pose_at")) > 260.0:
				shot("%02d_pose_%s.png" % [ci + 1, CLASSES[ci]])
				ci += 1
				if ci >= CLASSES.size():
					go("roll")
				else:
					go("pose")
		"roll":
			if not has_meta("rolled"):
				set_meta("rolled", true)
				face_camera()
				p.facing = p.facing.rotated(Vector3.UP, PI * 0.5)
				p._start_dash(p.facing)
			if since() > 150.0 and not has_meta("roll_shot"):
				set_meta("roll_shot", true)
				check("roulade en cours, corps en boule (%.2f)" % p.visual._roll_left, p.visual._roll_left > 0.0)
				shot("08_roulade.png")
			if since() > 900.0:
				p.visual.airborne = true
				p.visual.animate(0.016, Vector3.ZERO, p.facing)
				check("envol : le corps s'étire (%.3f)" % p.visual._squash_v, p.visual._squash_v > 0.0)
				p.visual.airborne = false
				p.visual.animate(0.016, Vector3.ZERO, p.facing)
				check("réception : le corps s'écrase (%.3f)" % p.visual._squash_v, p.visual._squash_v < 0.0)
				go("tree")
		"tree":
			if not has_meta("treed"):
				set_meta("treed", true)
				var tc := Vector2i(-99999, 0)
				for r in range(2, 40):
					for dz in range(-r, r + 1):
						for dx in range(-r, r + 1):
							var cc: Vector2i = w.spawn_cell + Vector2i(dx, dz)
							if tc.x == -99999 and w.decor_at(cc) in [w.D_OAK, w.D_PINE]:
								tc = cc
					if tc.x != -99999:
						break
				var at := Vector3(tc.x + 0.5 - 2.0, 0, tc.y + 0.5)
				at.y = w.support_height(at, w.terrain_height(w.cell_at(at)) + 0.5)
				p.global_position = at
				set_meta("tree_target", Vector3(tc.x + 0.5, w.terrain_height(tc) + 1.3, tc.y + 0.5))
				p._mouse_seen = true
			var tgt: Vector3 = get_meta("tree_target")
			var d: Vector3 = (tgt - p.camera.global_position).normalized()
			p.cam_yaw = atan2(-d.x, -d.z)
			p.cam_pitch = p.clamp_pitch(asin(-d.y))
			if since() > 500.0 and not has_meta("chopped"):
				set_meta("chopped", true)
				check("on vise l'arbre (%s)" % p.aim.get("kind"), p._aiming_at_harvest())
				p._combo = 0
				p._next_combo()
				check("geste d'outil (%s)" % p.move_name, p.move_name == "harvest_chop")
				set_meta("chop_at", since())
			if has_meta("chopped") and since() - float(get_meta("chop_at")) > 150.0:
				shot("09_recolte.png")
				print("RÉSULTAT : ", "tout est bon" if ok else "échec")
				return true
	return false
