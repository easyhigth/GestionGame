extends SceneTree
## Rythme du début de partie en solo (départ à mains nues) : on joue les premières étapes en comptant
## le temps qu'elles prennent (coups portés, marche entre les ressources, fabrication, construction de l'abri
## par le héros lui-même), et on vérifie que tout reste faisable et pas trop long.
var f := 0
var p; var w; var items; var hud; var bm
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/ry_"
## Temps de jeu estimé (secondes) : marche + coups + fabrication.
var t := 0.0
var times := {}
var swings := 0
var walked := 0.0
const SWING := 0.6
const CRAFT := 3.0

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
	# ce test joue le vrai départ : seul, à mains nues
	root.get_node("GameState").bare_start = true
	change_scene_to_file("res://scenes/main.tscn")

func check(name: String, cond: bool) -> void:
	print(("  OK  " if cond else "  ÉCHEC  ") + name)
	ok = ok and cond

func shot(n):
	root.get_viewport().get_texture().get_image().save_png(out + n)
	print("saved ", n)

func later(key: String, ms: int) -> bool:
	if not has_meta(key) or has_meta(key + "_done"):
		return false
	if game_ms - float(get_meta(key)) < ms:
		return false
	set_meta(key + "_done", true)
	return true

func start(key: String) -> void:
	set_meta(key, game_ms)

func count(id: String) -> int:
	return p.inventory.count(items.get_item(id))

func speed() -> float:
	return p.stats.move_speed * (p.race.speed_multiplier if p.race else 1.0)

## Le décor de cette sorte le plus proche du héros (avec une case libre à côté pour se placer).
func nearest(kinds: Array) -> Vector2i:
	var c0: Vector2i = w.cell_at(p.global_position)
	for r in range(1, 70):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dz) != r:
					continue
				var c: Vector2i = c0 + Vector2i(dx, dz)
				if w.decor_at(c) in kinds and w.decor_at(c - Vector2i(1, 0)) == 0:
					return c
	return Vector2i(-99999, -99999)

## Va jusqu'au décor (temps de marche compté) et le frappe jusqu'à ce qu'il casse, puis ramasse.
func harvest(kinds: Array) -> bool:
	var c := nearest(kinds)
	if c.x == -99999:
		return false
	var cc: Vector3 = w.cell_center(c)
	var to := Vector3(cc.x - 1.3, w.ground_height_at(cc - Vector3(1.3, 0, 0)), cc.z)
	var d := Vector2(to.x - p.global_position.x, to.z - p.global_position.z).length()
	walked += d
	t += d / speed()
	p.global_position = to
	p.facing = Vector3(1, 0, 0)
	var n := 0
	while w.decor_at(c) != 0 and n < 30:
		p._harvest_swing({"dmg": 1.0})
		n += 1
	swings += n
	t += n * SWING + 1.0
	for node in w.get_node("Village").get_children():
		if node.has_method("take") and not node.is_taken() and node.global_position.distance_to(p.global_position) < 6.0:
			p.try_pickup(node)
	return true

func gather(id: String, n: int, kinds: Array) -> void:
	var guard := 0
	while count(id) < n and guard < 60:
		if not harvest(kinds):
			break
		guard += 1

func craft(id: String, times_n := 1) -> bool:
	var done := 0
	for r in items.recipes:
		if r.result.id == id:
			for i in times_n:
				if r.craft(p.inventory, p.is_near_workbench(), p.nearby_stations()):
					p.crafted.emit(id)
					done += 1
			break
	t += CRAFT * done
	return done == times_n

func mark(k: String) -> void:
	times[k] = t
	print("   %-28s %5.1f min   (coups : %d, marche : %d m)" % [k, t / 60.0, swings, roundi(walked)])

func place(id: String, at: Vector3) -> bool:
	var d := Vector2(at.x - p.global_position.x, at.z - p.global_position.z).length()
	t += d / speed() + 2.0
	p.global_position = at
	p.facing = Vector3(0, 0, -1)
	p.hand.selected = id
	p.hand._target = {}
	p.hand._process(0.0)
	return p.hand.place()

var spawn: Vector3
var plan_center: Vector2i
var build_start := 0.0

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p: p._invulnerable_left = 5.0
	if f == 10:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		hud = get_first_node_in_group("hud"); bm = p.find_children("*", "BuildMode", true, false)[0]
		get_first_node_in_group("raids").enabled = false
		spawn = p.global_position
		print("== départ seul, à mains nues")
		var only_flag: bool = p.inventory.entries.size() == 1 and p.inventory.entries[0].item.id == "drapeau_royaume"
		check("sac vide (seulement le drapeau du royaume), pas d'arme, aucun habitant", only_flag and p.weapon() == null and get_nodes_in_group("villagers").is_empty())
		print("== les premiers pas, chronométrés (temps de jeu estimé)")
		gather("wood", 4, [w.D_OAK, w.D_PINE])
		mark("4 bois à mains nues")
		check("établi fabriqué", craft("etabli"))
		check("établi posé", place("etabli", spawn + Vector3(2, 0, 0)))
		mark("établi posé")
		gather("stone", 6, [w.D_ROCK])
		mark("6 cailloux à mains nues")
		gather("wood", 12, [w.D_OAK, w.D_PINE])
		gather("fiber", 2, [w.D_BUSH, w.D_GRASS])
		p.global_position = spawn + Vector3(2, 0, 1.5)
		check("pioche en bois", craft("pioche_bois"))
		check("hache en pierre (à l'établi)", craft("hache_pierre"))
		var sword := ""
		for r in items.recipes:
			if r.result.id == "arm_epee_bois_0":
				sword = r.result.id
				break
		check("épée en bois (%s)" % sword, sword != "" and craft(sword))
		var eq = p.inventory.entries.filter(func(e): return e.item.id == sword)
		if not eq.is_empty():
			p.equipment.equip(eq[0].item)
			p.inventory.remove(eq[0].item, 1)
		mark("outils et arme")
		gather("wood", 3, [w.D_OAK, w.D_PINE])
		gather("stone", 3, [w.D_ROCK])
		check("feu de camp fabriqué", craft("feu_de_camp"))
		check("feu de camp posé", place("feu_de_camp", spawn + Vector3(-2, 0, 0)))
		mark("feu de camp")
		# l'abri : le plan prêt « Maison » (murs, sol, toit, porte, lit, coffre)
		plan_center = w.cell_at(spawn) + Vector2i(0, 9)
		bm.layer = roundi(w.terrain_height(plan_center))
		var lay: Array = bm.plan_layout(bm._plan_types()[0], plan_center)
		var planks := lay.filter(func(e): return e[1] in ["wall", "floor", "gable"]).size()
		var roof := lay.filter(func(e): return e[1] == "roof").size()
		var wood_need: int = ceili(planks / 4.0) + 2 + 3 + 3
		var fiber_need: int = ceili(roof / 4.0) * 2 + 3
		print("   maison : %d planches, %d chaume -> %d bois, %d fibres" % [planks, roof, wood_need, fiber_need])
		gather("wood", wood_need, [w.D_OAK, w.D_PINE])
		gather("fiber", fiber_need, [w.D_BUSH, w.D_GRASS])
		mark("bois et fibres de la maison")
		p.global_position = spawn + Vector3(2, 0, 1.5)
		craft("bloc_planches", ceili(planks / 4.0))
		craft("bloc_chaume", ceili(roof / 4.0))
		check("porte, lit, coffre", craft("porte") and craft("lit") and craft("coffre"))
		bm.open_plan("maison")
		bm.layer = roundi(w.terrain_height(plan_center))
		bm._selection_from(plan_center, plan_center)
		bm._commit_selection()
		bm.toggle(false)
		check("plan de la maison posé (%d plans)" % bm.orders.orders.size(), bm.orders.orders.size() > 50)
		mark("matériaux prêts, plan posé")
		# le héros bâtit lui-même : on le laisse travailler (temps réel mesuré, jeu accéléré)
		Engine.time_scale = 4.0
		build_start = game_ms
		start("build")
	if has_meta("build") and not has_meta("built"):
		# il se tient au centre du chantier, puis au plus près du plan le plus bas qui reste
		if f % 20 == 0:
			var o = bm.orders._hero_order
			var target: Vector3 = w.cell_center(plan_center)
			if o == null:
				for oo in bm.orders.orders.values():
					if bm.orders.ready_to_build(oo):
						target = bm.orders.order_position(oo)
						break
			if o == null:
				p.global_position = Vector3(target.x + 1.0, w.ground_height_at(target + Vector3(1, 3, 0)), target.z)
		if bm.orders.orders.is_empty() or game_ms - build_start > 600000.0:
			set_meta("built", true)
			Engine.time_scale = 1.0
			t += (game_ms - build_start) / 1000.0
			check("le héros a bâti toute la maison seul (reste %d plans)" % bm.orders.orders.size(), bm.orders.orders.is_empty())
			start("room")
	if later("room", 2500):
		var k = get_first_node_in_group("kingdom")
		var house = k.rooms.filter(func(r): return r.type and r.type.id == "maison")
		check("maison reconnue (%d pièce(s))" % house.size(), not house.is_empty())
		mark("abri bâti")
		# les voyageurs ne viennent qu'auprès d'un camp : le héros plante le drapeau du royaume près de l'arrivée
		var flag = items.get_item(w.FLAG_ID)
		w.plant_legacy_flag()
		p.inventory.remove(flag, 1)
		check("drapeau du royaume planté (%s)" % str(w.home_cell), w.has_home())
		var vn = get_first_node_in_group("village_needs")
		times["habitant"] = t + vn.ARRIVAL_EVERY
		print("   %-28s %5.1f min   (un voyageur arrive au plus tard 3 min après l'abri)" % ["1er habitant possible", times.habitant / 60.0])
		vn._arrival = 0.0
		start("arrive")
	if later("arrive", 3000):
		var st = get_nodes_in_group("strangers").filter(func(s): return s.has_meta("attracted"))
		check("un voyageur est attiré par l'abri", not st.is_empty())
		p.global_position = w.cell_center(plan_center) + Vector3(0, 0, 8)
		p.snap_camera()
		start("shot")
	if later("shot", 800):
		shot("01_abri.png")
		print("== bilan")
		check("établi en moins de 3 min (%.1f)" % (times["établi posé"] / 60.0), times["établi posé"] < 180.0)
		check("outils et arme en moins de 8 min (%.1f)" % (times["outils et arme"] / 60.0), times["outils et arme"] < 480.0)
		check("abri en moins de 25 min (%.1f)" % (times["abri bâti"] / 60.0), times["abri bâti"] < 1500.0)
		# temps d'action pur (sans chercher, sans les menus) : un vrai joueur met environ 2 à 3 fois plus
		check("abri en plus de 3 min d'action : il faut le mériter (%.1f)" % (times["abri bâti"] / 60.0), times["abri bâti"] > 180.0)
		print("RÉSULTAT : " + ("tout est bon" if ok else "des vérifications ont échoué"))
		return true
	return f > 60000
