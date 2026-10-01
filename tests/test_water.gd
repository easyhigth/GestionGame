extends SceneTree
var f := 0
var p; var w; var items; var fm; var vn; var k; var dc; var hud; var gd; var H
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/n_"
var fi
var cv
var shore: Vector2i
var sea: Vector2i
var entrance := {}
var y0 := 0.0

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
				return true
	return false


func view(yaw, pitch, zoom) -> void:
	p.cam_yaw = deg_to_rad(yaw); p.cam_pitch = deg_to_rad(pitch); p.camera_zoom = zoom; p.snap_camera()

## Une case de berge (herbe ou sable) à côté d'une eau profonde, près du village.
func find_shore() -> Array:
	var s: Vector2i = w.spawn_cell
	for r in range(4, 320, 2):
		for i in 48:
			var a := TAU * i / 48.0
			var c := s + Vector2i(roundi(cos(a) * r), roundi(sin(a) * r))
			var t: int = w.terrain_type(c)
			if t != 2 and t != 3:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var ok := true
				for k in range(1, 9):
					var n: Vector2i = c + d * k
					if w.terrain_type(n) != 1 and w.terrain_type(n) != 0:
						ok = false
						break
				if ok and w.water_surface - w.terrain_height(c + d * 8) >= 2.3:
					return [c, d]
	return []

func step(dir: Vector3, n: int, dt := 0.05, until_swim := false) -> void:
	for i in n:
		p.velocity = dir * 4.0
		p.facing = dir
		p._move_on_ground(dt)
		if until_swim and p.swimming and w.terrain_type(w.cell_at(p.global_position)) == 0 and w.water_surface - w.terrain_height(w.cell_at(p.global_position)) > 2.0:
			return

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p: p._invulnerable_left = 5.0
	if f == 10:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		dc = get_first_node_in_group("day_cycle"); hud = get_first_node_in_group("hud"); gd = get_first_node_in_group("guide")
		fi = get_first_node_in_group("fishing"); cv = get_first_node_in_group("caves")
		get_first_node_in_group("raids").enabled = false
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		get_first_node_in_group("quests")._offer_timer = 9999.0
		get_first_node_in_group("weather").set_kind("clair")
		dc.hour = 11.0
		print("== eau profonde")
		var sh := find_shore()
		check("berge trouvée près d'une eau profonde", not sh.is_empty())
		shore = sh[0]
		var d: Vector2i = sh[1]
		sea = shore + d * 8
		print("   berge ", shore, " mer ", sea, " profondeur ", w.water_surface - w.terrain_height(sea))
		check("les eaux profondes sont profondes (%.1f m)" % (w.water_surface - w.terrain_height(sea)), w.water_surface - w.terrain_height(sea) >= 2.3)
		w.load_area(w.cell_center(shore))
		p.global_position = w.cell_center(shore)
		set_meta("dir", Vector3(d.x, 0, d.y))
		print("== nager")
		step(get_meta("dir"), 120, 0.05, true)
		print("   position ", p.global_position, " nage ", p.swimming)
		check("le héros entre dans l'eau et nage", p.swimming and w.cell_at(p.global_position) != shore)
		check("il flotte, la tête hors de l'eau", not p.is_underwater() and p.global_position.y < w.water_surface - 1.0)
		view(200, 28, 1.0)
		start("a")
	if later("a", 800):
		shot("01_nager.png")
		y0 = p.global_position.y
		Input.action_press("dig")
		start("b")
	if later("b", 900):
		Input.action_release("dig")
		print("   plongée : ", y0, " -> ", p.global_position.y)
		check("G : il plonge", p.global_position.y < y0 - 0.8 and p.is_underwater())
		start("c")
	if later("c", 2500):
		check("sous l'eau, le souffle baisse (%.1f)" % p.breath, p.breath < p.BREATH_MAX - 1.5)
		check("jauge de souffle et teinte bleue", hud._breath_box.visible and hud._underwater.visible)
		shot("02_sous_l_eau.png")
		p.breath = 0.0
		var hp: int = p.health.current
		p._invulnerable_left = 0.0
		p._drown_timer = 0.0
		p._update_breath(0.1, p.water_top())
		check("plus de souffle : il se noie (%d -> %d)" % [hp, p.health.current], p.health.current < hp)
		Input.action_press("jump")
		start("d")
	if later("d", 2500):
		Input.action_release("jump")
		p._invulnerable_left = 5.0
		print("   remonté à ", p.global_position.y, " souffle ", p.breath)
		check("Espace : il remonte et reprend son souffle", not p.is_underwater() and p.breath > 3.0)
		step(-get_meta("dir"), 140)
		print("   sortie : ", p.global_position, " nage ", p.swimming, " case ", w.cell_at(p.global_position))
		check("il ressort sur la berge", not p.swimming and not p.in_water())
		print("== pêche")
		p.global_position = w.cell_center(shore)
		p.facing = get_meta("dir")
		p.inventory.add(items.get_item("wood"), 3); p.inventory.add(items.get_item("fiber"), 2)
		check("canne à pêche fabriquée", craft("canne_peche"))
		p.hand.selected = "canne_peche"
		p.hand.place()
		check("V face à l'eau : ligne lancée", fi.state == "attente")
		fi._timer = 0.0
		start("e")
	if later("e", 300):
		check("ça mord (« ! »)", fi.state == "touche" and fi._mark.visible)
		shot("03_ca_mord.png")
		p.hand.place()
		check("V : le combat commence", fi.state == "combat")
		fi.cursor = (fi.zone.x + fi.zone.y) / 2.0
		fi.cursor_speed = 0.0
		start("f")
	if later("f", 300):
		shot("04_mini_jeu.png")
		var fish: String = fi.fish
		var n0 := count(fish)
		p.hand.place()
		check("V dans le vert : poisson pêché (%s)" % fish, count(fish) == n0 + 1 and fi.state == "")
		# raté
		p.hand.place(); fi._timer = 0.0; fi._process(0.01); p.hand.place()
		fi.cursor = 0.0 if fi.zone.x > 0.05 else 1.0
		fi.cursor_speed = 0.0
		p.hand.place(); p.hand.place()
		check("deux fois hors du vert : il s'échappe", fi.state == "")
		# trop tôt
		p.hand.place(); p.hand.place()
		check("V trop tôt : la ligne revient", fi.state == "")
		# poissons selon l'eau
		fi._at = w.cell_center(sea); fi._deep = true
		var seen := {}
		for i in 300: seen[fi._pick_fish()] = true
		fi._deep = false
		var shallow := {}
		for i in 300: shallow[fi._pick_fish()] = true
		print("   profond ", seen.keys(), " peu profond ", shallow.keys())
		check("perles seulement en eau profonde", seen.has("perle") and not shallow.has("perle"))
		p.inventory.add(items.get_item("gardon"), 1)
		p.global_position = w.cell_center(w.spawn_cell) + Vector3(1.5, 0, 1.5)
		check("poisson grillé au feu", craft("poisson_grille"))
		print("== grotte sous-marine")
		var best := {}
		var bd := INF
		for r in [4, 8, 12, 16, 24, 32, 48]:
			for e in cv.entrances_near(w.cell_center(w.spawn_cell), r):
				var dd: float = e.pos.distance_to(w.cell_center(w.spawn_cell))
				if dd < bd: bd = dd; best = e
			if not best.is_empty(): break
		check("une entrée de grotte existe (%.0f m du village)" % bd, not best.is_empty())
		entrance = best
		w.load_area(entrance.pos)
		p.global_position = entrance.pos + Vector3(1.0, 0.2, 0.5)
		cv._tick = 0.0
		cv._process(0.1)
		check("entrée affichée au fond de l'eau", cv._entrance_nodes.has(entrance.id))
		view(30, 30, 1.0)
		start("g")
	if later("g", 1200):
		shot("05_entree.png")
		check("E près de l'entrée : on entre", cv.try_interact(p))
		start("h")
	if later("h", 1600):
		check("dans la grotte inondée", cv.active and p.global_position.y < -100.0)
		check("tout est sous l'eau (le souffle baisse)", p.is_underwater())
		var chest: Dictionary = {}
		for it in cv._interactables:
			if it.kind == "chest": chest = it; break
		p.global_position = chest.pos + Vector3(1.0, 0, 0)
		var perls := count("perle")
		cv.try_interact(p)
		for n in cv._content.get_children():
			if n.has_method("is_taken") and n.global_position.distance_to(p.global_position) < 4.0:
				p.try_pickup(n)
		check("coffre englouti ouvert : perle et or", count("perle") > perls)
		p.breath = 2.0
		p.global_position = cv._air[0] + Vector3(0, 0.5, 0)
		p._update_breath(1.0, p.water_top())
		check("poche d'air : il reprend son souffle", p.breath > 2.0)
		p.global_position = chest.pos + Vector3(0, 0.5, 2.0)
		view(160, 40, 1.0)
		start("i")
	if later("i", 1200):
		shot("06_grotte.png")
		for it in cv._interactables:
			if it.kind == "exit":
				p.global_position = it.pos + Vector3(0.5, 0, 0)
		check("E à la sortie", cv.try_interact(p))
		start("j")
	if later("j", 1600):
		check("remonté au-dessus de l'entrée", not cv.active and p.global_position.y > -10.0 and p.global_position.distance_to(entrance.pos) < 6.0)
		print("== guide")
		gd.step = 26; gd.progress = 0; gd._refresh()
		gd._check_state()
		for i in 3: fi.caught.emit("gardon")
		cv.chest_opened.emit("x")
		check("chapitre 7 « L'eau » fini", gd.step >= 29 and gd.current_id() == "donjon")
		root.get_node("SaveGame").save_game("3")
		set_meta("opened", cv.opened.duplicate(true))
		root.get_node("SaveGame").load_game("3")
		start("k")
	if later("k", 2000):
		cv = get_first_node_in_group("caves")
		check("coffres ouverts sauvegardés", cv.opened == get_meta("opened"))
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	return false
