extends SceneTree
## Défense du camp (murets, tours, torches, gardes) qui réduit les raids, et événement « Bête rôdeuse »
## qui pousse le héros à sortir du village.
var f := 0
var CD
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
	if killed_at > 0:
		return finish() if f > killed_at + 30 else false
	if f < 60:
		return false
	CD = load("res://scripts/kingdom/camp_defense.gd")
	var w = get_first_node_in_group("world")
	var rm = get_first_node_in_group("raids")
	var p = get_first_node_in_group("player")
	var we = get_first_node_in_group("world_events")
	check("monde, raids, joueur et événements présents", w != null and rm != null and p != null and we != null)
	var grid = w.build
	var center: Vector3 = w.home_center()
	var base = CD.compute(w, center, 30.0, 0)
	check("camp nu : 0 point de défense", int(base.points) == 0)
	# 25 murets de pierre autour du camp
	var muret = root.get_node("Items").get_item("muret_pierre")
	check("l'objet muret_pierre existe", muret != null)
	var cx := int(floor(center.x))
	var cz := int(floor(center.z))
	var y := int(floor(w.ground_height_at(center + Vector3(8, 3, 0))))
	var placed := 0
	for i in 25:
		if grid.place_block(Vector3i(cx + 6, y, cz - 12 + i), muret):
			placed += 1
	check("murets posés", placed >= 20)
	var d1 = CD.compute(w, center, 30.0, 0)
	check("20 murets ou plus : au moins 2 points (%d)" % int(d1.points), int(d1.points) >= 2)
	var d2 = CD.compute(w, center, 30.0, 2)
	check("2 gardes ajoutent 4 points", int(d2.points) == int(d1.points) + 4)
	var dfar = CD.compute(w, center + Vector3(500, 0, 500), 30.0, 0)
	check("murets loin du camp ne comptent pas", int(dfar.points) == 0)
	check("texte de défense", CD.describe(d2).contains("point"))
	check("le raid manager sait calculer la défense", rm.defense().has("points"))
	# événement bête rôdeuse
	we.start("bete")
	check("événement bête rôdeuse lancé", we.is_active("bete"))
	check("la bête existe", we._beast != null and is_instance_valid(we._beast))
	var dist: float = we._beast.global_position.distance_to(center)
	check("la bête est loin du village (%d m)" % int(dist), dist > 40.0)
	check("indication de direction", we.status_text().contains(" m "))
	var xp0: int = p.xp
	we._beast.health.take_damage(999999, p)
	killed_at = f
	return false

var killed_at := 0

func finish() -> bool:
	var we = get_first_node_in_group("world_events")
	check("bête abattue : l'événement est terminé", not we.is_active("bete"))
	print("RÉSULTAT : ", "tout est bon" if ok else "échec")
	return true
