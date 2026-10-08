extends SceneTree
## PNJ : le héros ne les traverse pas ; frappé, un habitant se fâche et riposte, puis se calme (K.O. ou temps) ;
## un citadin frappé se bat aussi (combattant à son image) et reprend sa place ensuite.
var f := 0
var ok := true
var p; var w; var v

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
	change_scene_to_file("res://scenes/main.tscn")

func check(name: String, cond: bool) -> void:
	print(("  OK  " if cond else "  ÉCHEC  ") + name)
	ok = ok and cond

func _process(_d) -> bool:
	f += 1
	if p:
		p._invulnerable_left = 5.0
	if f == 60:
		p = get_first_node_in_group("player")
		w = get_first_node_in_group("world")
		get_first_node_in_group("raids").enabled = false
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		v = get_nodes_in_group("villagers").filter(func(x): return not x.companion)[0]
		v.set_physics_process(false)
		# le héros fonce sur l'habitant : il ne le traverse pas
		p.global_position = v.global_position + Vector3(-2.0, 0, 0)
		p.facing = Vector3(1, 0, 0)
		set_meta("walk", f)
	if has_meta("walk") and f < 100:
		p.velocity = Vector3(4, 0, 0)
		p._move_on_ground(1.0 / 60.0)
	if f == 100:
		var d: float = Vector2(p.global_position.x - v.global_position.x, p.global_position.z - v.global_position.z).length()
		check("le héros ne traverse pas l'habitant (écart %.2f m)" % d, d > 0.5)
		check("il reste du même côté", p.global_position.x < v.global_position.x)
		# frapper l'habitant
		v.set_physics_process(true)
		p.global_position = v.global_position + Vector3(-1.0, 0, 0)
		p.facing = Vector3(1, 0, 0)
		var hits: int = load("res://scripts/combat/combat.gd").melee(p, 1.6, 90.0, 5, 1.0)
		check("le coup touche l'habitant", hits == 1)
		check("il se fâche", v.is_angry() and v.team == 1 and v.is_in_group("enemies"))
		check("il vise le héros", v._threat == p)
		check("les autres habitants ne s'en mêlent pas", get_nodes_in_group("villagers").filter(func(x): return x != v and x._threat == v).is_empty())
	if f == 101:
		v._update_threat()
		check("il garde le héros pour cible", v._threat == p)
		# mis K.O. : il se calme au réveil
		v.health.take_damage(99999, p)
	if f == 105:
		v._ko_left = 0.01
	if f == 110:
		check("relevé : il s'est calmé", not v.is_angry() and v.team == 0 and v.is_in_group("allies"))
		# un citadin
		var tf = load("res://scripts/world/townsfolk.gd").new()
		tf.display_name = "Bertrand"
		tf.race = load("res://data/races/humain.tres")
		tf.role = "guard"
		tf.home = p.global_position + Vector3(1, 0, 0)
		w.add_child(tf)
		tf.global_position = tf.home
		set_meta("tf", tf)
	if f == 115:
		var tf = get_meta("tf")
		p.global_position = tf.global_position + Vector3(-1.0, 0, 0)
		p.facing = Vector3(1, 0, 0)
		var hits: int = load("res://scripts/combat/combat.gd").melee(p, 1.6, 90.0, 5, 1.0)
		check("le coup touche le citadin", hits == 1)
		check("un combattant prend sa place", tf.is_fighting() and not tf.visible)
		check("le combattant porte son nom", tf._fighter.data.display_name == "Bertrand")
		check("le combattant s'en prend au héros", tf._fighter.team == 1)
		tf._fight_left = 0.0
	if f == 120:
		var tf = get_meta("tf")
		check("calmé : le citadin reprend sa place", not tf.is_fighting() and tf.visible)
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	return false
