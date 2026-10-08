extends SceneTree
## Creuser : on vise le sol et on frappe (comme dans Minecraft) ; la terre vient d'abord, puis la roche (il
## faut une pioche) ; assez profond, on perce la voûte d'une galerie souterraine à explorer.
## Et la touche d'interaction est F. Captures dg_XX_nom.png.
var f := 0
var p; var w; var items; var mc; var hv
var ok := true
var step := 0
var wait := 0
var cell := Vector2i.ZERO
var h0 := 0.0
var hits := 0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/dg_"

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

## Regarder le centre de la case creusée (1re personne).
func look_down() -> void:
	var target := Vector3(cell.x + 0.5, w.terrain_height(cell), cell.y + 0.5)
	var eye: Vector3 = p.global_position + Vector3(0, 1.5 * p.visual.height_scale(), 0)
	var d: Vector3 = (target - eye).normalized()
	p.cam_pitch = p.clamp_pitch(asin(-d.y))
	p.cam_yaw = atan2(-d.x, -d.z)

func _process(_d) -> bool:
	f += 1
	if p:
		p._invulnerable_left = 5.0
	if wait > 0:
		wait -= 1
		return false
	if f < 30:
		return false
	match step:
		0:
			p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
			mc = get_first_node_in_group("mountain_caves")
			hv = load("res://scripts/world/harvest.gd")
			get_first_node_in_group("raids").enabled = false
			for e in get_nodes_in_group("enemy_units"): e.queue_free()
			# la touche d'interaction : F
			var keys := []
			for e in InputMap.action_get_events("interact"):
				if e is InputEventKey:
					keys.append((e as InputEventKey).physical_keycode)
			check("interagir : touche F (%s)" % str(keys), keys.has(KEY_F))
			# une case de terre libre à côté du héros
			for r in range(2, 12):
				for dx in range(-r, r + 1):
					var c: Vector2i = w.cell_at(p.global_position) + Vector2i(dx, r)
					if cell == Vector2i.ZERO and w.terrain_type(c) in [w.GRASS, w.DIRT] and w.decor_at(c) == w.D_NONE \
							and w.build.column(c).is_empty() and w.build.furniture_in(c).is_empty() and w.village_prop_at(c, w.terrain_height(c) - 0.5) == null:
						cell = c
			var stand := Vector3(cell.x + 0.5, 0, cell.y - 1.0)
			stand.y = w.support_height(stand, w.terrain_height(w.cell_at(stand)) + 0.5)
			p.global_position = stand
			p.set_camera_mode(2, false)
			p._mouse_seen = true
			h0 = w.terrain_height(cell)
			for t in ["pioche_bois", "pioche_pierre", "pioche_fer"]:
				while p.inventory.count(items.get_item(t)) > 0:
					p.inventory.remove(items.get_item(t), 1)
			step = 1; wait = 5
		1:
			look_down()
			if p.aim.get("kind") == "terrain" and p.aim.get("cell") == cell:
				# à mains nues : la terre
				for i in 4:
					look_down()
					hv.strike(p, 2.5, 1.0)
				var dug: float = h0 - w.terrain_height(cell)
				check("clic sur le sol : on creuse la terre (%.1f m)" % dug, dug >= 1.0)
				check("la terre tombe au sol (bloc de terre)", get_nodes_in_group("pickups").size() > 0)
				# plus bas : la roche, il faut une pioche
				for i in 4:
					hv.strike(p, 2.5, 1.0)
				var before: float = w.terrain_height(cell)
				hv.strike(p, 2.5, 1.0)
				check("sans pioche, la roche résiste (%.1f m)" % (h0 - w.terrain_height(cell)), is_equal_approx(before, w.terrain_height(cell)) and h0 - before >= 1.9)
				shot("01_trou.png")
				p.inventory.add(items.get_item("pioche_pierre"), 1)
				step = 2; wait = 3
			elif f > 600:
				check("le viseur trouve le sol (%s)" % str(p.aim.get("kind")), false)
				print("RÉSULTAT : échec")
				return true
		2:
			look_down()
			hv.strike(p, 2.5, 1.0)
			hits += 1
			if mc.active or hits > 40:
				check("assez profond : une galerie souterraine s'ouvre (%d coups, %.1f m)" % [hits, h0 - w.terrain_height(cell)], mc.active)
				step = 3; wait = 150
		3:
			p.cam_pitch = p.clamp_pitch(0.1)
			p.set_camera_mode(0, false)
			check("dans la galerie, sous terre", p.global_position.y < -100.0)
			var env: Environment = (current_scene.get_node("Ambiance") as WorldEnvironment).environment
			step = 4; wait = 30
		4:
			shot("02_galerie.png")
			print("RÉSULTAT : ", "tout est bon" if ok else "échec")
			return true
	return false
