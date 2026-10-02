extends SceneTree
var f := 0
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/ci_"

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

## Profileur : temps de _process / _physics_process de chaque script (somme sur ses instances), par image.
## Lancer : SYNC_LOADING=1 godot --headless --path . -s tools/profile_systems.gd
var stage := 0
var p
func _process(_d) -> bool:
	f += 1
	if f == 10:
		p = get_first_node_in_group("player")
		get_first_node_in_group("raids").enabled = false
	if f == 400:
		var cost := {}
		var count := {}
		var nodes := root.find_children("*", "", true, false)
		for n in nodes:
			var sc = n.get_script()
			if sc == null or not is_instance_valid(n) or not n.is_inside_tree() or not n.can_process():
				continue
			var path: String = sc.resource_path.get_file()
			for m in ["_process", "_physics_process"]:
				if n.has_method(m) and sc.get_script_method_list().any(func(x): return x.name == m):
					var t0 := Time.get_ticks_usec()
					for i in 20:
						n.call(m, 1.0 / 60.0)
					var dt := (Time.get_ticks_usec() - t0) / 20.0
					cost[path] = float(cost.get(path, 0.0)) + dt
			count[path] = int(count.get(path, 0)) + 1
		var keys := cost.keys()
		keys.sort_custom(func(a, b): return cost[a] > cost[b])
		var total := 0.0
		for k in keys:
			total += cost[k]
		print("== profil (µs par image, toutes instances) — total %.0f µs" % total)
		for k in keys.slice(0, 30):
			print("   %-28s %8.0f µs  (%d instances)" % [k, cost[k], count.get(k, 0)])
		var pk := {}
		for q in get_nodes_in_group("pickups"):
			var k2: String = q.item.id if q.item else "?"
			pk[k2] = int(pk.get(k2, 0)) + 1
		print("== objets au sol : ", pk)
		var types := {}
		for n in nodes:
			var k: String = n.get_class() + (" [" + n.get_script().resource_path.get_file() + "]" if n.get_script() else "")
			types[k] = int(types.get(k, 0)) + 1
		var tk := types.keys()
		tk.sort_custom(func(a, b): return types[a] > types[b])
		print("== nœuds par type (%d)" % nodes.size())
		for k in tk.slice(0, 25):
			print("   %-50s %d" % [k, types[k]])
		print("== physique : objets actifs %d, paires %d, îlots %d ; temps physique %.2f ms, process %.2f ms" % [
			Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS), Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS),
			Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT), Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
		print("RÉSULTAT : tout est bon")
		return true
	return false
