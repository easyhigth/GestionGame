extends SceneTree
## Creuser sous le niveau de la mer, sur la terre ferme : le trou reste sec (pas de plan d'eau ni de fond
## marin dedans) ; les lacs et la mer gardent leur eau. Captures dp_XX_nom.png.
var f := 0
var p; var w
var ok := true
var step := 0
var wait := 0
var cell := Vector2i(-1, -1)
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/dp_"

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
			p = get_first_node_in_group("player"); w = get_first_node_in_group("world")
			get_first_node_in_group("raids").enabled = false
			get_first_node_in_group("day_cycle").hour = 12.0
			for e in get_nodes_in_group("enemy_units"): e.queue_free()
			# une fosse de 5×5 cases, 4 m sous le niveau de la mer, sur la terre ferme
			# loin des maisons : un pré plat (5×5 cases d'herbe libres à la même hauteur)
			var home: Vector2i = w.cell_at(p.global_position)
			var c0: Vector2i = home + Vector2i(0, 30)
			var found := false
			for r in range(25, 200, 3):
				for dx in range(-r, r + 1, 5):
					if found:
						break
					var c: Vector2i = home + Vector2i(dx, r)
					var flat := true
					for ax in range(-4, 5):
						for az in range(-4, 5):
							var n: Vector2i = c + Vector2i(ax, az)
							if w.terrain_type(n) != w.GRASS or absf(w.terrain_height(n) - w.terrain_height(c)) > 0.6 or not w.build.column(n).is_empty() or w.decor_at(n) != w.D_NONE:
								flat = false
					if flat:
						c0 = c
						found = true
			var cells := []
			for dx in range(-2, 3):
				for dz in range(-2, 3):
					var c: Vector2i = c0 + Vector2i(dx, dz)
					w.set_terrain_height(c, w.water_surface - 4.0)
					cells.append(c)
			cell = c0
			w.refresh_cells(cells)
			check("la fosse est sous le niveau de la mer (%.1f m < %.1f)" % [w.terrain_height(cell), w.water_surface], w.terrain_height(cell) < w.water_surface - 3.0)
			p.global_position = Vector3(cell.x + 0.5, w.terrain_height(cell) + 0.1, cell.y + 0.5)
			step = 1; wait = 20
		1:
			check("masque de l'eau : la fosse est sèche", w._water_mask.get_pixel(cell.x, cell.y).r < 0.5)
			check("le héros ne nage pas au fond de la fosse", not p.in_water() and not p.swimming and not p.is_underwater())
			# une case d'eau, ailleurs : elle reste de l'eau
			var wc := Vector2i(-1, -1)
			for r in range(4, 300, 3):
				for dx in range(-r, r + 1, 3):
					var c: Vector2i = cell + Vector2i(dx, r)
					if wc.x < 0 and w._inside(c) and w.terrain_type(c) in [w.WATER, w.DEEP]:
						w._build_terrain_chunk(Vector2i(c.x / w.CHUNK, c.y / w.CHUNK))
						wc = c
			check("un lac garde son eau (%s)" % str(wc), wc.x >= 0 and w._water_mask.get_pixel(wc.x, wc.y).r > 0.5)
			var wm = w.get_node("Terrain/Eau").material_override
			check("le plan d'eau suit le masque", wm.get_shader_parameter("water_mask") == w._water_mask_tex)
			# vue de dessus sur la fosse
			var edge := cell + Vector2i(0, -4)
			p.global_position = Vector3(edge.x + 0.5, w.terrain_height(edge) + 0.1, edge.y + 0.5)
			p.set_camera_mode(1, false)
			step = 2; wait = 40
		2:
			shot("01_fosse_seche.png")
			p.global_position = Vector3(cell.x + 0.5, w.terrain_height(cell) + 0.1, cell.y + 0.5)
			p.set_camera_mode(2, false)
			p.cam_yaw = 0.0
			p.cam_pitch = p.clamp_pitch(0.9)
			step = 3; wait = 30
		3:
			shot("02_au_fond.png")
			print("RÉSULTAT : ", "tout est bon" if ok else "échec")
			return true
	return false
