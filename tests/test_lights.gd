extends SceneTree
## Lumières : la nuit, les torches et le feu de camp éclairent les alentours avec une flamme qui vacille ;
## les monstres ont les yeux qui luisent ; les grottes sont sombres, éclairées par la lanterne du héros et
## des grappes de cristaux. Captures li_XX_nom.png.
var f := 0
var p; var w; var items; var mc
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/li_"
var phase := ""
var phase_at := 0.0
var foes := []
var torch_light
var e0 := 0.0

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

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p:
		p._invulnerable_left = 5.0
	if f == 8:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		mc = get_first_node_in_group("mountain_caves")
		get_first_node_in_group("raids").enabled = false
		get_first_node_in_group("weather").set_kind("clair")
		get_first_node_in_group("day_cycle").hour = 23.0
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		p.set_camera_mode(0, false)
		p.cam_pitch = p.clamp_pitch(0.35)
		# les habitants du campement cacheraient la scène
		for v in get_nodes_in_group("villagers"): v.queue_free()
		# deux torches de part et d'autre, devant le héros
		var fwd := Vector3(-sin(p.cam_yaw), 0, -cos(p.cam_yaw))
		var side := fwd.cross(Vector3.UP)
		for s in [-1.0, 1.0]:
			var c: Vector2i = w.cell_at(p.global_position + fwd * 4.0 + side * 2.5 * s)
			w.build.place_furniture(c, w.terrain_height(c), items.get_item("torche"), 0)
		for k in w.build.furniture:
			var fr: Dictionary = w.build.furniture[k]
			if (fr.item as ItemData).id == "torche":
				for l in (fr.node as Node).find_children("*", "OmniLight3D", true, false):
					torch_light = l
		# des monstres de la nuit
		for i in 3:
			var e = load("res://scenes/enemies/enemy.tscn").instantiate()
			e.data = load("res://data/enemies/%s.tres" % ["squelette", "loup", "slime_bleu"][i])
			e.level = 3
			e.set_meta("night", true)
			w.add_child(e)
			e.global_position = ground(p.global_position + fwd * (5.0 + i * 0.5) + side * (i - 1) * 1.8)
			e.set_physics_process(false)
			e._update_night_glow()
			e.facing = -fwd
			e.visual.rotation.y = atan2(-fwd.x, -fwd.z)
			foes.append(e)
		go("night")
	if phase == "":
		return false
	if since() > 20000.0:
		check("l'étape « %s » aboutit" % phase, false)
		print("RÉSULTAT : échec")
		return true
	match phase:
		"night":
			if since() > 300.0 and e0 == 0.0 and torch_light:
				e0 = torch_light.light_energy
			if since() > 1500.0:
				check("la torche éclaire avec une flamme qui vacille (%s)" % torch_light, torch_light is FlickerLight and torch_light.omni_range >= 7.0)
				check("son intensité varie (%.2f → %.2f)" % [e0, torch_light.light_energy], absf(e0 - torch_light.light_energy) > 0.001)
				var glows := foes.filter(func(e): return e._glow != null).size()
				check("les monstres de la nuit ont les yeux qui luisent (%d / 3)" % glows, glows == 3)
				shot("01_nuit_torches.png")
				p.cam_pitch = p.clamp_pitch(0.15)
				go("close")
		"close":
			if since() > 600.0:
				shot("02_yeux.png")
				get_first_node_in_group("day_cycle").hour = 12.0
				for e in foes:
					e.remove_meta("night")
					e._update_night_glow()
				go("day")
		"day":
			if since() > 400.0:
				var glows := foes.filter(func(e): return e._glow != null).size()
				check("en plein jour (monstres ordinaires), plus de lueur (%d)" % glows, glows == 0)
				for e in foes: e.queue_free()
				# une grotte de montagne
				var found := []
				for z in w.zones:
					if z.type == null or not (z.type.id in ["montagnes", "toundra", "volcan"]): continue
					for en in mc.entrances_near(w.cell_center(Vector2i(z.site)), 4):
						found.append(en)
					if found.size() >= 1: break
				var ent = found[0]
				w.load_area(ent.pos)
				p.global_position = ent.pos + Vector3(ent.dir.x, 0, ent.dir.y) * -1.2
				p.global_position.y = w.ground_height_at(p.global_position + Vector3(0, 30, 0))
				mc._tick = 0.0
				mc._process(0.1)
				mc.try_interact(p)
				go("cave")
		"cave":
			if since() > 1800.0:
				check("dans la grotte", mc.active)
				var env: Environment = (current_scene.get_node("Ambiance") as WorldEnvironment).environment
				check("grotte sombre (lumière ambiante %.2f)" % env.ambient_light_energy, env.ambient_light_energy < 0.5)
				check("lanterne du héros qui vacille", mc._player_light is FlickerLight)
				var crystals := 0
				for n in mc._content.get_children():
					if n is Node3D and n.get_child_count() >= 3 and n.get_child(0) is MeshInstance3D \
							and (n.get_child(0) as MeshInstance3D).material_override is StandardMaterial3D \
							and ((n.get_child(0) as MeshInstance3D).material_override as StandardMaterial3D).emission_enabled:
						crystals += 1
				check("grappes de cristaux luisants (%d)" % crystals, crystals >= 8)
				p.cam_pitch = p.clamp_pitch(0.3)
				shot("03_grotte.png")
				print("RÉSULTAT : ", "tout est bon" if ok else "échec")
				return true
	return false
