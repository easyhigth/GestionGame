extends SceneTree
var f := 0
var p; var w; var items; var qb; var vn; var k; var dc; var hud
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/k_"
var qs := {}

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

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p: p._invulnerable_left = 5.0
	if f == 10:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		qb = get_first_node_in_group("quests"); vn = get_first_node_in_group("village_needs"); k = get_first_node_in_group("kingdom")
		dc = get_first_node_in_group("day_cycle"); hud = get_first_node_in_group("hud")
		get_first_node_in_group("raids").enabled = false
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		dc.hour = 9.0
		qb._offer_timer = 9999.0
		print("== propositions")
		for t in ["apporter", "chasser", "explorer", "défendre", "construire"]:
			var q: Dictionary = qb.make_offer(t)
			qs[t] = q
			print("   %s : %s — « %s » (%s)" % [t, q.get("title", "?"), q.get("text", ""), q.get("giver_name", "")])
		check("5 quêtes proposées, une par type", qs.values().all(func(q): return not q.is_empty() and q.state == "offer"))
		check("marque « ! » au-dessus des habitants", qs.values().all(func(q): return q.giver._mark.visible and q.giver._mark.text == "!"))
		print("== dialogue (E)")
		var g = qs["apporter"].giver
		p.global_position = g.global_position + Vector3(1.2, 0, 0)
		var ev := InputEventAction.new(); ev.action = "interact"; ev.pressed = true
		p._unhandled_input(ev)
		check("E près de l'habitant : dialogue de quête", hud.quest_dialog.visible and not qb.quest_of(hud.quest_dialog.target).is_empty())
		p.cam_yaw = deg_to_rad(200.0); p.cam_pitch = deg_to_rad(28.0); p.camera_zoom = 0.8; p.snap_camera()
		start("a")
	if later("a", 300):
		shot("01_dialogue.png")
		hud.quest_dialog.close()
		for t in qs:
			qb.accept(qs[t])
		check("4 quêtes acceptées au plus (%d)" % qb.active().size(), qb.active().size() == 4)
		check("la 5e reste proposée", qb.offers().size() == 1)
		check("marque « … » pendant la quête", qs["apporter"].giver._mark.text == "…")
		print("== chasser")
		var tgt = qs["chasser"].target
		check("bête marquée apparue à %d m du village" % roundi(tgt.global_position.distance_to(w.cell_center(w.spawn_cell))) if tgt else "bête marquée apparue", tgt != null and is_instance_valid(tgt))
		# capture de la bête
		p.global_position = tgt.global_position + Vector3(0, 0, 4)
		p.cam_yaw = deg_to_rad(0.0); p.cam_pitch = deg_to_rad(30.0); p.camera_zoom = 1.0; p.snap_camera()
		tgt.set_physics_process(false)
		start("b")
	if later("b", 700):
		shot("02_cible.png")
		var tgt = qs["chasser"].target
		tgt.receive_hit(99999, p, 0.0, 0.0)
		start("c")
	if later("c", 400):
		check("bête vaincue : quête prête (« ? »)", qs["chasser"].state == "ready" and qs["chasser"].giver._mark.text == "?")
		print("== apporter")
		var q: Dictionary = qs["apporter"]
		p.inventory.add(items.get_item(q.need), q.count)
		qb._update()
		check("objets dans le sac : prête", q.state == "ready")
		var gold0 := count("piece_or")
		var xp0: int = p.xp + p.level * 1000
		var n0 := count(q.need)
		var hap0: float = q.giver.happiness
		var txt: String = qb.turn_in(q)
		print("   ", txt)
		check("rendue : objets pris, or et XP donnés, habitant plus heureux", count(q.need) == n0 - q.count and count("piece_or") > gold0 and p.xp + p.level * 1000 > xp0 and q.giver.happiness > hap0 and q.giver.friendship == 1)
		print("== explorer / défendre / construire")
		var qe: Dictionary = qs["explorer"]
		for z in w.zones:
			if z.name == qe.need: z.obelisk_on = true
		qb._update()
		check("obélisque éveillé : prête", qe.state == "ready")
		var qd: Dictionary = qs["défendre"]
		for i in 3: dc.night_monster_killed.emit()
		check("3 créatures de la nuit vaincues : prête", qd.state == "ready")
		# l'offre restante (construire) passe en cours
		var qc: Dictionary = qs["construire"]
		qb.turn_in(qs["chasser"])
		check("une place libérée : la 5e peut être acceptée", qb.accept(qc))
		var rt := load("res://data/rooms/%s.tres" % qc.need)
		k.rooms.append({"type": rt, "cells": {w.spawn_cell + Vector2i(40, 40): true}, "floor": -30.0, "enclosed": true, "doors": 1, "counts": {}, "tier": 0, "missing": {}})
		qb._update()
		check("pièce construite (%s) : prête" % qc.need, qc.state == "ready")
		k.rooms.pop_back()
		print("== amitié")
		var friend = qs["apporter"].giver
		friend.friendship = 2
		var q2: Dictionary = {}
		for i in 5:
			q2 = qb.make_offer("défendre")
			if not q2.is_empty() and q2.giver == friend: break
			if not q2.is_empty(): qb.quests.erase(q2); qb._mark(q2.giver); q2 = {}
		if q2.is_empty():
			q2 = qb._generate("défendre", friend); qb.quests.append(q2)
		qb.accept(q2)
		for i in 3: dc.night_monster_killed.emit()
		var inv0: int = p.inventory.entries.size()
		var t2: String = qb.turn_in(q2)
		print("   ", t2)
		check("3e quête : devient ami, cadeau rare", friend.friendship == 3 and t2.contains("cadeau"))
		print("== suivi et sauvegarde")
		hud._update_quests()
		check("suivi à l'écran : %d lignes pour %d quêtes" % [hud._quest_box.get_child_count(), qb.active().size()], hud._quest_box.get_child_count() == qb.active().size() * 2 + 2)  # + 2 lignes pour l'histoire
		var remaining: int = qb.quests.size()
		var sg = root.get_node("SaveGame")
		set_meta("friend", friend.villager_name)
		set_meta("remaining", remaining)
		sg.save_game("3")
		sg.load_game("3")
		start("d")
	if later("d", 1800):
		qb = get_first_node_in_group("quests"); vn = get_first_node_in_group("village_needs"); p = get_first_node_in_group("player")
		hud = get_first_node_in_group("hud"); w = get_first_node_in_group("world")
		check("quêtes rechargées (%d / %d)" % [qb.quests.size(), int(get_meta("remaining"))], qb.quests.size() == int(get_meta("remaining")))
		check("amitié rechargée", vn.members().any(func(v): return v.villager_name == get_meta("friend") and v.friendship == 3))
		# un habitant qui part : sa quête disparaît
		var q3: Dictionary = qb.make_offer("apporter")
		if not q3.is_empty():
			q3.giver.queue_free()
		start("e")
	if later("e", 1300):
		check("habitant parti : sa quête disparaît", not qb.quests.any(func(q): return not is_instance_valid(q.giver)))
		# capture : suivi à l'écran avec une chasse en cours
		var qh: Dictionary = qb.make_offer("chasser")
		if not qh.is_empty():
			qb.accept(qh)
		var qa: Dictionary = qb.make_offer("apporter")
		if not qa.is_empty():
			qb.accept(qa)
		qb.make_offer("explorer")
		var g = qb.offers()[0].giver if not qb.offers().is_empty() else null
		if g:
			p.global_position = g.global_position + Vector3(2.0, 0, 2.0)
		p.cam_yaw = deg_to_rad(30.0); p.cam_pitch = deg_to_rad(30.0); p.camera_zoom = 1.0; p.snap_camera()
		start("f")
	if later("f", 1200):
		hud._update_quests()
		shot("03_marques_suivi.png")
		hud.kingdom_panel.open()
		start("g")
	if later("g", 400):
		shot("04_royaume_quetes.png")
		hud.kingdom_panel.close()
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	return false
