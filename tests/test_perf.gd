extends SceneTree
var f := 0
var p; var w; var items; var dip; var hud; var rm; var tr
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/gd_"

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

func later(key: String, ms: int) -> bool:
	if not has_meta(key) or has_meta(key + "_done"):
		return false
	if game_ms - float(get_meta(key)) < ms:
		return false
	set_meta(key + "_done", true)
	return true

func start(key: String) -> void:
	set_meta(key, game_ms)

func gold() -> int:
	return p.inventory.count(items.get_item("piece_or"))

## Mesures de performances : temps de calcul par image (scripts + physique, hors rendu), dans plusieurs scénarios,
## puis coût de chaque système (mesuré avec puis sans lui, l'un juste après l'autre).
## À lancer de préférence sans rendu : godot --headless --path . -s tests/test_perf.gd
## (PERF_SYSTEMS=1 : mesure aussi le coût de chaque système, système par système)
var steps: Array = []
var cur := -1
var samples: Array = []
var phys: Array = []
var t_left := 0.0
var results := {}
var systems: Array = []
var ms_on := 0.0

func spikes(a: Array) -> String:
	var mx := 0.0
	var n := 0
	for x in a:
		mx = maxf(mx, x)
		if x > 0.025:
			n += 1
	return "pic %.1f ms, %d image(s) > 25 ms" % [1000.0 * mx, n]


func avg(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var t := 0.0
	for s in a:
		t += s
	return 1000.0 * t / a.size()

func _next() -> void:
	cur += 1
	samples.clear()
	phys.clear()
	if cur < steps.size():
		var st: Array = steps[cur]
		t_left = float(st[1])
		if st[2] is Callable:
			(st[2] as Callable).call()

func step(name: String, secs: float, setup = null, done = null) -> void:
	steps.append([name, secs, setup, done])

func _process(_d) -> bool:
	f += 1
	if p:
		p._invulnerable_left = 5.0
		p.health.heal(9999)
	if f == 10:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		rm = get_first_node_in_group("raids")
		rm.enabled = false
		get_first_node_in_group("world_events").next_day = 999
		_plan()
		_next()
		return false
	if cur < 0 or cur >= steps.size():
		return cur >= steps.size()
	samples.append(Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
	phys.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
	t_left -= _d
	if t_left <= 0.0:
		var st: Array = steps[cur]
		if st[3] is Callable:
			(st[3] as Callable).call(avg(samples), avg(phys))
		_next()
		if cur >= steps.size():
			_finish()
			return true
	return false

func _plan() -> void:
	step("attente", 4.0)
	step("village", 10.0, null, func(ms, ph):
		results.village = ms
		print("   village : %.2f ms/image (physique %.2f), %d nœuds, %s" % [ms, ph, Performance.get_monitor(Performance.OBJECT_NODE_COUNT), spikes(samples)]))
	# coût de chaque système : seulement à la demande (PERF_SYSTEMS=1), c'est long
	var only_scenes := OS.get_environment("PERF_SYSTEMS") == ""
	for g in ([] if only_scenes else ["story", "side_quests", "achievements", "world_events", "diplomacy", "heraldry", "familiars_mgr", "village_needs", "kingdom", "trade", "livestock", "farming", "weather", "seasons", "day_cycle", "guide", "fishing", "caves", "mounts", "dungeons", "hud", "habitants", "monstres"]):
		step("avec " + g, 2.0, null, func(ms, _ph): ms_on = ms)
		step("sans " + g, 2.0, func(): toggle_system(g, false), func(ms, _ph):
			toggle_system(g, true)
			results["cost_" + g] = ms_on - ms
			if ms_on - ms > 0.4:
				print("   %-14s : ~%.2f ms" % [g, ms_on - ms]))
	step("raid : arrivée", 5.0, func():
		rm.announce()
		rm._start())
	step("raid", 4.0, null, func(ms, ph):
		print("   (pillards : %s)" % [rm.alive_raiders().map(func(e): return e.global_position.distance_to(p.global_position))])
		results.raid = ms
		print("   raid (%d pillards) : %.2f ms/image (physique %.2f), %s" % [rm.alive_raiders().size(), ms, ph, spikes(samples)])
		for e in rm.alive_raiders():
			e.queue_free()
		rm.raid = {})
	step("siège : arrivée", 6.0, func():
		get_first_node_in_group("diplomacy").act("karg", "war")
		p.level = 15
		get_first_node_in_group("dungeons").enter_siege("karg", true))
	step("siège", 4.0, null, func(ms, ph):
		var dm = get_first_node_in_group("dungeons")
		results.siege = ms
		print("   siège (vague %d, %d soldats) : %.2f ms/image (physique %.2f)" % [dm.siege_wave, dm._siege_alive.size(), ms, ph])
		dm.leave(true))
	step("jungle : arrivée", 5.0, func():
		var jz = w.zones.filter(func(z): return z.type.id == "jungle")
		if not jz.is_empty():
			var site: Vector3 = w.cell_center(jz[0].site)
			w.load_area(site)
			p.global_position = site + Vector3(0, 2, 0))
	step("jungle", 4.0, null, func(ms, ph):
		results.jungle = ms
		print("   jungle : %.2f ms/image (physique %.2f), %d nœuds, %s" % [ms, ph, Performance.get_monitor(Performance.OBJECT_NODE_COUNT), spikes(samples)]))

func toggle_system(g: String, on: bool) -> void:
	var mode := Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	match g:
		"habitants":
			for v in get_nodes_in_group("villagers"):
				v.process_mode = mode
		"monstres":
			for e in get_nodes_in_group("enemy_units"):
				e.process_mode = mode
		_:
			var n := get_first_node_in_group(g)
			if n:
				n.process_mode = mode

func _finish() -> void:
	print("   mémoire : %.0f Mo" % (Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0))
	var worst := 0.0
	for k in ["village", "raid", "siege", "jungle"]:
		worst = maxf(worst, float(results.get(k, 0.0)))
	# avec un écran (même virtuel), le temps mesuré inclut l'attente du rendu : on ne juge que sans rendu
	if DisplayServer.get_name() == "headless":
		check("calcul par image sous 20 ms dans tous les scénarios (pire : %.1f ms)" % worst, worst < 20.0)
	else:
		print("   (avec rendu : mesures indicatives, pire %.1f ms)" % worst)
	# la qualité graphique change bien les réglages
	w.apply_quality(0)
	var low_ok: bool = w.view_distance == 3.0 and w.small_decor_range == 25.0
	w.apply_quality(2)
	check("qualité graphique basse puis haute", low_ok and w.view_distance == 4.5)
	print("RÉSULTAT : " + ("tout est bon" if ok else "ÉCHECS"))
