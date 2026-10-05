extends SceneTree
## Monde créé avec la case « Tutoriel » décochée : le guide des premiers pas est passé d'office, sans message,
## et disparaît dès le lancement.
var f := 0
var gd
var ok := true
var notes := []

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
	sg.world_opts.tutorial = false
	sg.guide_state = {}
	change_scene_to_file("res://scenes/main.tscn")

func check(name: String, cond: bool) -> void:
	print(("  OK  " if cond else "  ÉCHEC  ") + name)
	ok = ok and cond

func _process(_d) -> bool:
	f += 1
	if f == 2:
		var p = get_first_node_in_group("player")
		if p:
			p.notify.connect(func(m): notes.append(m))
	if f < 60:
		return false
	gd = get_first_node_in_group("guide")
	check("option du monde : tutoriel décoché", not root.get_node("SaveGame").world_flag("tutorial"))
	check("le guide existe", gd != null)
	if gd:
		check("guide terminé d'office (étape %d/%d)" % [gd.step, gd.STEPS.size()], gd.is_done())
		check("le guide a disparu", not gd.visible)
	check("pas de message « Tutoriel passé »", not notes.any(func(m): return str(m).begins_with("Tutoriel passé")))
	print("RÉSULTAT : ", "tout est bon" if ok else "échec")
	return true
