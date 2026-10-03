extends SceneTree
## Classes et métiers : au moins 10 de chaque, talents et métiers d'artisanat de départ, habitants et voyageurs
## avec une classe de combat (tenue, bonus, affichage, sauvegarde), nouvelles pièces de travail ;
## captures de l'écran de création (onglets Classe et Métier).
var f := 0
var p; var w; var V; var cc
var ok := true
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/cl_"

func check(name: String, cond: bool) -> void:
	print(("  OK  " if cond else "  ÉCHEC  ") + name)
	ok = ok and cond

func ids(dir: String) -> Array:
	var a := []
	for fn in DirAccess.get_files_at(dir):
		fn = fn.trim_suffix(".remap")
		if fn.ends_with(".tres"):
			a.append(fn.get_basename())
	return a

func _initialize():
	V = load("res://scenes/npc/villager.gd")
	var tt = load("res://scripts/hero/talent_tree.gd")
	var cr = load("res://scripts/hero/crafts.gd")
	var classes := ids("res://data/classes/")
	var jobs := ids("res://data/jobs/")
	print("classes : ", classes.size(), " ", classes)
	print("métiers : ", jobs.size(), " ", jobs)
	check("au moins 10 classes", classes.size() >= 10)
	check("au moins 10 métiers", jobs.size() >= 10)
	for c in classes:
		var cd = load("res://data/classes/%s.tres" % c)
		check("classe %s : nom, tenue, talent de départ" % c, cd.display_name != "" and not cd.starting_equipment.is_empty()
			and not cd.starting_equipment.has(null) and tt.CLASS_START.has(c) and not tt.node(tt.CLASS_START[c]).is_empty())
		check("classe %s connue des habitants" % c, V.CLASS_IDS.has(c))
	for j in jobs:
		var jd = load("res://data/jobs/%s.tres" % j)
		check("métier %s : objets et métiers d'artisanat" % j, jd.display_name != "" and not jd.starting_items.has(null)
			and cr.JOB_START.has(j) and cr.JOB_START[j].all(func(x): return cr.CRAFTS.has(x)))
	for job in V.JOB_CLASSES:
		check("classes du métier %s valides" % job, V.JOB_CLASSES[job].all(func(x): return classes.has(x)))
	var seen := {}
	for i in 200:
		seen[V.pick_class(V.JOBS[i % V.JOBS.size()])] = true
	check("les habitants ont des classes variées (%d)" % seen.size(), seen.size() >= 10)
	var h = load("res://scripts/hero/hero_profile.gd").new()
	h.hero_name = "Morvane"
	h.race = load("res://data/races/elfe.tres") if ResourceLoader.exists("res://data/races/elfe.tres") else load("res://data/races/homme_bete.tres")
	h.hero_class = load("res://data/classes/necromancien.tres")
	h.job = load("res://data/jobs/pecheur.tres")
	h.skill = load("res://data/skills/vorace.tres")
	root.get_node("GameState").hero = h
	root.get_node("GameState").world_seed = 4242
	change_scene_to_file("res://scenes/main.tscn")

func shot(n):
	root.get_viewport().get_texture().get_image().save_png(out + n)
	print("saved ", n)

func _process(_d) -> bool:
	f += 1
	if f == 5:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world")
		check("héros nécromancien : talent Soif offert", p.talents.has("san_soif"))
		check("héros pêcheur : métier Pêcheur niveau 10", load("res://scripts/hero/crafts.gd").level(p, "pecheur") >= 10)
		var wpn = p.weapon()
		check("tenue du nécromancien (bâton)", wpn != null and wpn.id == "staff")
		check("objets du pêcheur (canne)", p.inventory.count(root.get_node("Items").get_item("canne_peche")) >= 1)
		# un habitant doué pour la garde
		var v = w.villager_scene.instantiate()
		v.talents = {"garde": 0.7}
		v.race = load("res://data/races/homme_bete.tres")
		w.get_node("Village").add_child(v)
		v.global_position = p.global_position + Vector3(2, 0, 0)
		check("l'habitant a une classe (%s)" % v.fight_class, V.CLASS_IDS.has(v.fight_class) and v.class_name_fr() != "")
		v.fight_class = "chevalier"
		var cd = load("res://data/classes/chevalier.tres")
		check("bonus de défense de la classe", v.base_defense() == cd.bonus_defense)
		v._apply_level(true)
		check("bonus de vie de la classe", v.health.max_health == roundi(v.race.max_health * v._level_mult()) + cd.bonus_health)
		check("tenue de classe", V.class_kit("chevalier").has("spear"))
		var saved = root.get_node("SaveGame")._save_villagers()
		check("classe sauvegardée", saved.any(func(d): return d.get("fight_class", "") == "chevalier"))
		var everyone := get_nodes_in_group("villagers") + get_nodes_in_group("strangers")
		check("tous les habitants et voyageurs ont une classe (%d)" % everyone.size(), everyone.all(func(x): return x.fight_class != ""))
		var k = get_first_node_in_group("kingdom")
		var room_ids = k.room_types.map(func(t): return t.id)
		for r in ["pavillon_chasse", "cabane_peche", "carriere", "cuisine", "joaillerie"]:
			var t = k.room_types[room_ids.find(r)] if room_ids.has(r) else null
			check("pièce %s : métier d'habitant" % r, t != null and V.JOBS.has(t.job_id) and V.JOB_NAMES.has(t.job_id)
				and not t.production_pool.has(null))
		# un voyageur et sa fiche de recrutement
		var tr = w.villager_scene.instantiate()
		tr.stranger = true
		tr.talents = {"pecheur": 0.6, "cuisinier": 0.2}
		tr.race = v.race
		tr.villager_name = "Ysolde"
		tr.level = 4
		tr.recruit_offer = w.make_offer("pecheur", 4)
		w.get_node("Village").add_child(tr)
		tr.global_position = p.global_position + Vector3(1.5, 0, 1.5)
		check("offre du pêcheur", "filets" in str(tr.recruit_offer.get("text", "")))
		p.talk.emit(tr)
	if f == 60:
		shot("01_voyageur.png")
		change_scene_to_file("res://scenes/ui/character_creator.tscn")
	if f == 70:
		cc = current_scene
		cc._tabs.current_tab = 2
	if f == 90:
		shot("02_classes.png")
		cc._tabs.current_tab = 3
		for j in cc._job_buttons:
			if j.display_name == "Joaillier":
				cc._job_buttons[j].emit_signal("pressed")
				cc._job_buttons[j].button_pressed = true
	if f == 110:
		shot("03_metiers.png")
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	return false
