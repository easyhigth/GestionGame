extends SceneTree
## Visée à la souris : en 1re et 3e personne, c'est le viseur qui décide (bloc visé, face où poser,
## arbre récolté, ennemi frappé) ; en vue de dessus, c'est le curseur de la souris.
var f := 0
var p; var w; var items
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/am_"
var phase := ""
var phase_at := 0.0
var target := Vector3.ZERO
var gain := Vector2(0.003, 0.003)
var prev_err := Vector2.INF
var block_key := Vector3i.ZERO
var tree_cell := Vector2i.ZERO
var foe
var hv

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
	prev_err = Vector2.INF

## Tourne la caméra (1re ou 3e personne) jusqu'à mettre `target` sous le viseur. Vrai quand c'est fait.
func steer() -> bool:
	# 1re personne : la caméra est à l'œil du héros ; regarder vers `target`
	var eye: Vector3 = p.global_position + Vector3(0, 1.5 * p.visual.scale.y, 0)
	var d: Vector3 = (target - eye).normalized()
	p.cam_pitch = p.clamp_pitch(asin(-d.y))
	p.cam_yaw = atan2(-d.x, -d.z)
	var center := root.get_viewport().get_visible_rect().size * 0.5
	var cam: Camera3D = p.camera
	return not cam.is_position_behind(target) and (cam.unproject_position(target) - center).length() < 4.0


func flat_cell_near(from: Vector2i) -> Vector2i:
	for r in range(3, 14):
		for dz in range(-r, r + 1):
			for dx in [-r, r]:
				var c: Vector2i = from + Vector2i(dx, dz)
				if w.terrain_type(c) in [w.GRASS, w.DIRT] and w.decor_at(c) == w.D_NONE \
						and w.decor_at(c + Vector2i(1, 0)) == w.D_NONE and w.build.column(c).is_empty() \
						and absf(w.terrain_height(c) - w.terrain_height(c + Vector2i(-2, 0))) < 0.3:
					return c
	return from + Vector2i(4, 0)

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p:
		p._invulnerable_left = 5.0
	if f == 8:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		hv = load("res://scripts/world/harvest.gd")
		get_first_node_in_group("raids").enabled = false
		get_first_node_in_group("day_cycle").hour = 11.0
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		p._mouse_seen = true
		p.set_camera_mode(2, false)
		# un pilier de planches à 3 m du héros
		var c := flat_cell_near(w.spawn_cell)
		# sur le sol (une marche d'un demi-cube : le bloc commence au cube au-dessus, sa face reste visible)
		var hy := ceili(w.terrain_height(c) - 0.01)
		block_key = Vector3i(c.x, hy, c.y)
		w.build.place_block(block_key, items.get_item("bloc_planches"))
		w.build.place_block(block_key + Vector3i(0, 1, 0), items.get_item("bloc_planches"))
		var stand := Vector3(c.x - 2.5, 0, c.y + 0.5)
		stand.y = w.support_height(stand, w.terrain_height(w.cell_at(stand)) + 0.5)
		p.global_position = stand
		target = Vector3(block_key) + Vector3(0.02, 0.5, 0.5)   # milieu de la face tournée vers le héros
		print("== 1re personne : viser le bloc ", block_key)
		go("aim_block")
	if phase == "":
		return false
	if game_ms - phase_at > 12000.0:
		check("la visée « %s » aboutit" % phase, false)
		print("RÉSULTAT : échec")
		return true
	match phase:
		"aim_block":
			if steer() and game_ms - phase_at > 300.0:
				var a: Dictionary = p.aim
				check("le viseur est sur le bloc (%s %s)" % [a.get("kind"), a.get("key")], a.get("kind") == "block" and a.get("key") == block_key)
				check("face visée tournée vers le héros (%s)" % a.get("normal"), (a.get("normal", Vector3.ZERO) as Vector3).x < -0.5)
				check("contour du bloc visé affiché", p._aim_box != null and p._aim_box.visible)
				shot("01_bloc_vise.png")
				p.inventory.add(items.get_item("bloc_planches"), 10)
				p.hand.selected = "bloc_planches"
				go("place")
		"place":
			if game_ms - phase_at > 200.0:
				var spot: Dictionary = p.hand.find_spot(items.get_item("bloc_planches"))
				var want := block_key + Vector3i(-1, 0, 0)
				check("le bloc irait contre la face visée %s (%s)" % [want, spot.get("key")], spot.get("key") == want and spot.get("ok", false))
				shot("02_fantome.png")
				var mb := InputEventMouseButton.new()
				mb.button_index = MOUSE_BUTTON_RIGHT
				mb.pressed = true
				p._input(mb)
				check("clic droit : posé là où l'on vise", w.build.block_at(want) != null)
				w.build.remove_block(want)
				p.hand.selected = ""
				# un arbre : le héros se place à 2 m et le vise
				var tc := Vector2i(-99999, 0)
				for r in range(2, 40):
					for dz in range(-r, r + 1):
						for dx in range(-r, r + 1):
							var cc: Vector2i = w.spawn_cell + Vector2i(dx, dz)
							if tc.x == -99999 and w.decor_at(cc) in [w.D_OAK, w.D_PINE]:
								tc = cc
					if tc.x != -99999:
						break
				tree_cell = tc
				var at := Vector3(tc.x + 0.5 - 2.2, 0, tc.y + 0.5)
				at.y = w.support_height(at, w.terrain_height(w.cell_at(at)) + 0.5)
				p.global_position = at
				target = Vector3(tc.x + 0.5, w.terrain_height(tc) + 1.3, tc.y + 0.5)
				print("== viser un arbre ", tc)
				go("aim_tree")
		"aim_tree":
			if steer() and game_ms - phase_at > 300.0:
				var a2: Dictionary = p.aim
				check("le viseur est sur l'arbre (%s %s)" % [a2.get("kind"), a2.get("cell")], a2.get("kind") == "decor" and a2.get("cell") == tree_cell)
				var t: Dictionary = hv.find_target(p, 2.5)
				check("un coup récolterait cet arbre-là (%s)" % str(t), t.get("cell") == tree_cell)
				shot("03_arbre_vise.png")
				# viser le ciel : rien à récolter
				p.cam_pitch = p.clamp_pitch(-1.2)
				go("aim_sky")
		"aim_sky":
			if game_ms - phase_at > 200.0:
				check("viseur dans le vide : rien à frapper (%s)" % str(hv.find_target(p, 2.5)), hv.find_target(p, 2.5).is_empty())
				# un ennemi sur le côté : le héros frappe là où l'on vise, pas devant lui
				foe = load("res://scenes/enemies/enemy.tscn").instantiate()
				foe.data = load("res://data/enemies/squelette.tres")
				foe.level = 1
				foe.set_physics_process(false)
				w.add_child(foe)
				var side: Vector3 = p.global_position + Vector3(0, 0, 2.6)
				side.y = w.support_height(side, w.terrain_height(w.cell_at(side)) + 0.5)
				foe.global_position = side
				p.facing = Vector3(1, 0, 0)
				target = side + Vector3(0, 1.0, 0)
				print("== viser un ennemi sur le côté")
				go("aim_foe")
		"aim_foe":
			if steer() and game_ms - phase_at > 300.0:
				check("le viseur est sur l'ennemi (%s)" % p.aim.get("kind"), p.aim.get("kind") == "enemy")
				p._aim_with_camera()
				var to: Vector3 = (foe.global_position - p.global_position) * Vector3(1, 0, 1)
				check("le héros se tourne vers l'ennemi visé (%.2f)" % p.facing.dot(to.normalized()), p.facing.dot(to.normalized()) > 0.9)
				shot("04_ennemi_vise.png")
				print("== vue de dessus : le curseur de la souris")
				p.set_camera_mode(1, false)
				go("top")
		"top":
			if game_ms - phase_at > 600.0 and not has_meta("warped"):
				set_meta("warped", true)
				var sp: Vector2 = p.camera.unproject_position(foe.global_position + Vector3(0, 1.0, 0))
				root.get_viewport().warp_mouse(sp)
				set_meta("sp", sp)
			if has_meta("warped") and game_ms - phase_at > 900.0:
				print("   souris ", root.get_viewport().get_mouse_position(), " ennemi à l'écran ", get_meta("sp"))
				check("curseur sur l'ennemi : visé (%s)" % p.aim.get("kind"), p.aim.get("kind") == "enemy")
				p.facing = Vector3(-1, 0, 0)
				p._aim_with_camera()
				var to2: Vector3 = (foe.global_position - p.global_position) * Vector3(1, 0, 1)
				check("clic : le héros frappe vers le curseur (%.2f)" % p.facing.dot(to2.normalized()), p.facing.dot(to2.normalized()) > 0.9)
				shot("05_vue_dessus.png")
				print("RÉSULTAT : ", "tout est bon" if ok else "échec")
				return true
	return false
