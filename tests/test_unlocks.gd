extends SceneTree
## Menus débloqués au fil de la partie (départ à mains nues) : talents au niveau 2, royaume avec un abri,
## tutoriel court (14 étapes de base, puis des défis facultatifs).
var f := 0
var ok := true

func _initialize():
	var h = load("res://scripts/hero/hero_profile.gd").new()
	h.hero_name = "Selka"
	h.race = load("res://data/races/humain.tres")
	h.hero_class = load("res://data/classes/guerrier.tres")
	h.job = load("res://data/jobs/chasseur.tres")
	h.skill = load("res://data/skills/vorace.tres")
	root.get_node("GameState").hero = h
	root.get_node("GameState").world_seed = 4242
	var sg = root.get_node("SaveGame")
	sg.world_opts = sg.WORLD_DEFAULTS.duplicate()
	sg.guide_state = {}
	change_scene_to_file("res://scenes/main.tscn")

func check(name: String, cond: bool) -> void:
	print(("  OK  " if cond else "  ÉCHEC  ") + name)
	ok = ok and cond

func _process(_d) -> bool:
	f += 1
	if f < 60:
		return false
	var un = root.get_node("Unlocks")
	var gs = root.get_node("GameState")
	var p = get_first_node_in_group("player")
	var gd = get_first_node_in_group("guide")
	check("joueur et guide présents", p != null and gd != null)
	check("tutoriel de base : 14 étapes", gd.CORE_STEPS == 14 and gd.STEPS[gd.CORE_STEPS - 1][0] == "nuit")
	# départ classique : tout est ouvert
	gs.bare_start = false
	un.reset()
	check("départ classique : talents ouverts", un.allowed("talents", false))
	check("départ classique : royaume ouvert", un.allowed("kingdom", false))
	# départ à mains nues : verrouillé
	gs.bare_start = true
	un.reset()
	p.level = 1
	gd.step = 0
	check("talents verrouillés au niveau 1", not un.allowed("talents", false))
	check("royaume verrouillé sans abri", not un.allowed("kingdom", false) or get_nodes_in_group("villagers").size() > 0)
	p.level = 2
	check("talents ouverts au niveau 2", un.allowed("talents", false))
	var abri := 0
	for i in gd.STEPS.size():
		if gd.STEPS[i][0] == "abri":
			abri = i
	gd.step = abri + 1
	un.reset()
	check("royaume ouvert une fois l'abri bâti", un.allowed("kingdom", false))
	# l'option ouvre tout
	un.reset()
	p.level = 1
	gd.step = 0
	root.get_node("SaveGame").options.progressive_menus = false
	check("option désactivée : tout ouvert", un.allowed("talents", false))
	root.get_node("SaveGame").options.progressive_menus = true
	print("RÉSULTAT : ", "tout est bon" if ok else "échec")
	return true
