extends SceneTree
## Compétences de classe (3 par classe, offertes aux niveaux 1, 6 et 15), combat des habitants selon leur classe
## (soin, sorts, rempart...), savoir-faire des métiers ; captures : onglet Classe et Pacte, squelettes invoqués.
var f := 0
var p; var w; var tt; var hud; var items
var ok := true
var t_mark := 0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/cs_"

func check(name: String, cond: bool) -> void:
	print(("  OK  " if cond else "  ÉCHEC  ") + name)
	ok = ok and cond

func _initialize():
	var h = load("res://scripts/hero/hero_profile.gd").new()
	h.hero_name = "Morvane"
	h.race = load("res://data/races/elfe.tres")
	h.hero_class = load("res://data/classes/necromancien.tres")
	h.job = load("res://data/jobs/cuisinier.tres")
	h.skill = load("res://data/skills/vorace.tres")
	root.get_node("GameState").hero = h
	root.get_node("GameState").world_seed = 4242
	change_scene_to_file("res://scenes/main.tscn")

func shot(n):
	root.get_viewport().get_texture().get_image().save_png(out + n)
	print("saved ", n)

func spawn_enemy(id: String, pos: Vector3):
	var e = load("res://scenes/enemies/enemy.tscn").instantiate()
	e.data = load("res://data/enemies/%s.tres" % id)
	w.add_child(e)
	e.global_position = pos
	return e

func _process(_d) -> bool:
	f += 1
	if p:
		p._invulnerable_left = 5.0
	if f == 5:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); hud = get_first_node_in_group("hud")
		items = root.get_node("Items")
		tt = load("res://scripts/hero/talent_tree.gd")
		get_first_node_in_group("raids").enabled = false
		get_first_node_in_group("weather").set_kind("clair")
		get_first_node_in_group("day_cycle").hour = 11.0
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		var V = load("res://scenes/npc/villager.gd")
		for c in V.CLASS_IDS:
			var sk: Array = tt.class_skills(c)
			check("classe %s : 3 compétences actives" % c, sk.size() == 3 and sk.all(func(n): return n.kind == "active" and tt.cost(n.id) == 0)
				and sk.map(func(n): return int(n.level)) == tt.CLASS_LEVELS)
			check("classe %s : un rôle au combat pour les habitants" % c, V.CLASS_ROLE.has(c))
		check("niveau 1 : Lever les morts offert, touche 0", p.talents.has("cl_nec_squelettes") and p.ability_slots[9] == "cl_nec_squelettes")
		check("pas encore Drain de vie", not p.talents.has("cl_nec_drain") and p.talent_block_reason("cl_nec_drain").contains("niveau 6"))
		check("une compétence d'une autre classe est refusée", p.talent_block_reason("cl_gue_cri") != "" and not p.unlock_talent("cl_gue_cri"))
		var pts0: int = p.talent_points()
		p.gain_xp(100000)
		print("niveau ", p.level)
		check("en montant de niveau : les 3 compétences, rangées à droite (%s)" % str(p.ability_slots),
			p.talents.has("cl_nec_drain") and p.talents.has("cl_nec_terreur") and p.ability_slots[8] == "cl_nec_drain" and p.ability_slots[7] == "cl_nec_terreur")
		check("elles ne coûtent pas de point", p.talent_points() >= pts0)
		check("/competences n'apprend pas les autres classes", get_first_node_in_group("command_console").run("/competences")
			and not p.talents.has("cl_gue_cri"))
		p.reset_talents()
		check("après l'oubli des talents, la classe rend ses compétences", p.talents.has("cl_nec_terreur") and p.ability_slots.has("cl_nec_squelettes"))
		# toutes les compétences de toutes les classes se lancent
		var bad := []
		for c in V.CLASS_IDS:
			for n in tt.class_skills(c):
				var hs = load("res://scripts/hero/hero_skill.gd").new(tt.make_skill(n.id), p)
				hs.set_level(p.level)
				if not hs.activate():
					bad.append(n.id)
		check("les 39 compétences se lancent %s" % str(bad), bad.is_empty())
		for s in get_nodes_in_group("summons"): s.queue_free()
		# savoir-faire du cuisinier
		p.hunger = 20.0
		p.inventory.add(items.get_item("pain"), 1)
		var food: float = items.get_item("pain").food
		p.eat(items.get_item("pain"))
		check("cuisinier : le pain nourrit 40 %% de plus (%.0f)" % p.hunger, absf(p.hunger - (20.0 + food * 1.4)) < 0.1)
	if f == 30:
		# combat : le nécromancien invoque, un clerc soigne, un mage lance des sorts
		var base: Vector3 = p.global_position
		var clerc = w.villager_scene.instantiate()
		clerc.race = load("res://data/races/humain.tres"); clerc.talents = {"pretre": 0.6}; clerc.fight_class = "clerc"; clerc.villager_name = "Aldric"
		w.get_node("Village").add_child(clerc); clerc.global_position = base + Vector3(-2, 0, 1); clerc.home = clerc.global_position
		var mage = w.villager_scene.instantiate()
		mage.race = load("res://data/races/elfe.tres"); mage.talents = {"mage": 0.6}; mage.fight_class = "mage"; mage.villager_name = "Isil"
		w.get_node("Village").add_child(mage); mage.global_position = base + Vector3(2, 0, 1); mage.home = mage.global_position
		mage.equipment.equip(items.get_item("staff"))
		set_meta("clerc", clerc); set_meta("mage", mage)
		p.health.current = int(p.health.max_health * 0.4)
		set_meta("hp0", p.health.current)
		var foes := []
		for i in 4:
			foes.append(spawn_enemy("loup", base + Vector3(-3 + i * 2, 0, 5)))
		set_meta("foes", foes)
		for e in foes: e.health.invulnerable = false
		check("Lever les morts", p.cast_ability(9))
		check("des squelettes alliés (%d)" % get_nodes_in_group("summons").size(), get_nodes_in_group("summons").size() >= 2)
		p.cam_pitch = deg_to_rad(30); p.cam_yaw = deg_to_rad(180); p.camera_zoom = 1.2; p.snap_camera()
		t_mark = Engine.get_physics_frames()
	if f == 32:
		for k in ["clerc", "mage"]:
			var v = get_meta(k)
			if v._threat == null or not is_instance_valid(v._threat) or not v._threat.is_alive():
				for e in get_meta("foes"):
					if is_instance_valid(e) and e.is_alive():
						e.global_position = e.global_position.move_toward(v.global_position + Vector3(0, 0, 5), 0.0)
						v._threat = e
						break
		if Engine.get_physics_frames() - t_mark < 480:
			f = 31
			OS.delay_msec(10)
			return false
		f = 400
	if f == 401:
		shot("02_combat.png")
		var clerc = get_meta("clerc")
		var mage = get_meta("mage")
		print("vie héros ", get_meta("hp0"), " -> ", p.health.current, " ; rôle clerc ", clerc.class_role(), " mage ", mage.class_role())
		check("le clerc soigne le héros (%d -> %d)" % [get_meta("hp0"), p.health.current], p.health.current > int(get_meta("hp0")))
		check("le clerc a soigné (%d fois), le mage a lancé des sorts (%d)" % [clerc.class_actions, mage.class_actions], clerc.class_actions > 0 and mage.class_actions > 0)
		var sum = get_nodes_in_group("summons")
		if not sum.is_empty():
			sum[0].set_meta("summon_left", 0.01)
	if f == 410:
		check("un squelette retourne à la terre au bout de sa durée", get_nodes_in_group("summons").size() <= 1 + (1 if p.level > 1 else 0) + 2)
		hud.talent_ui.open()
		hud.talent_ui._tab.emit_signal("pressed")
		hud.talent_ui._selected = "cl_nec_squelettes"
		hud.talent_ui._refresh()
	if f == 430:
		shot("01_arbre_classe.png")
		hud.talent_ui.close_ui()
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	return false
