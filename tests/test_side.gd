extends SceneTree
var f := 0
var p; var w; var items; var vn; var k; var dc; var hud; var st; var sq; var dlg; var dm
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/sq_"
var done_all := 0

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

func finish_dialog(choice := "") -> void:
	while dlg._page < dlg._pages.size() - 1:
		dlg._next()
	if dlg._choices.is_empty():
		dlg._close("")
	else:
		dlg._close(choice if choice != "" else dlg._choices[0][1])

func talk(id: String) -> bool:
	var n = st.npc(id)
	if n == null:
		print("   pas de ", id)
		return false
	p.global_position = n.global_position + Vector3(1, 0, 0)
	st.try_talk(n)
	return dlg.visible

func add_room(t: String) -> void:
	var rt = load("res://data/rooms/%s.tres" % t)
	k.rooms.append({"type": rt, "cells": {w.spawn_cell + Vector2i(40 + k.rooms.size() * 3, 40): true}, "floor": -30.0, "enclosed": true, "doors": 1, "counts": {}, "tier": 0, "missing": {}})

func fulfil(q: Dictionary) -> void:
	match q.type:
		"item":
			p.inventory.add(items.get_item(q.item), int(q.n))
			if q.has("item2"):
				p.inventory.add(items.get_item(q.item2), int(q.n2))
		"kill":
			for i in int(q.n):
				var e = load("res://scenes/enemies/enemy.tscn").instantiate()
				e.data = load("res://data/enemies/%s.tres" % q.enemies[i % q.enemies.size()])
				sq.on_enemy_died(e)
				e.free()
		"boss":
			for i in int(q.n):
				dm.boss_defeated.emit({"type": null}, "")
		"tame", "evolve":
			for i in int(q.n):
				sq.on_event(q.type)
		"explore":
			for i in int(q.n):
				if q.what == "cave":
					get_first_node_in_group("mountain_caves").chest_opened.emit("test")
				else:
					sq.on_chest(q.what)
		"have":
			if q.has("pop"):
				var missing: int = int(q.pop) - vn.members().size()
				if missing > 0:
					st._recruit("res://data/races/humain.tres", missing, 1, w.cell_center(w.spawn_cell))
			else:
				p.inventory.add(items.get_item(q.items[0]), 1)
		"room":
			while st._room_count(q.room) < int(q.get("count", 1)):
				add_room(q.room)
		"obelisks":
			for z in w.zones:
				z.obelisk_on = true
		"level":
			while p.level < int(q.n):
				p.gain_xp(p.xp_to_next())

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p: p._invulnerable_left = 5.0
	if f == 10:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		vn = get_first_node_in_group("village_needs"); k = get_first_node_in_group("kingdom")
		dc = get_first_node_in_group("day_cycle"); hud = get_first_node_in_group("hud")
		st = get_first_node_in_group("story"); sq = get_first_node_in_group("side_quests"); dlg = get_first_node_in_group("story_dialog"); dm = get_first_node_in_group("dungeons")
		get_first_node_in_group("raids").enabled = false
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		get_first_node_in_group("quests")._offer_timer = 9999.0
		dc.hour = 11.0
		check("44 quêtes secondaires", sq.QUESTS.size() == 44)
		var npcs := {}
		for q in sq.QUESTS: npcs[q.npc] = true
		check("%d personnages en ont" % npcs.size(), npcs.size() >= 20)
		var bad := []
		for q in sq.QUESTS:
			for pair in q.reward.get("items", []):
				if items.get_item(pair[0]) == null: bad.append(pair[0])
			if q.type == "item" and items.get_item(q.item) == null: bad.append(q.item)
			if q.has("item2") and items.get_item(q.item2) == null: bad.append(q.item2)
			if q.type == "room" and not ResourceLoader.exists("res://data/rooms/%s.tres" % q.room): bad.append(q.room)
			if q.after != "fin" and st.index_of(q.after) < 0: bad.append(q.after)
		check("objets, pièces et étapes valides %s" % str(bad), bad.is_empty())
		print("== pendant l'histoire")
		st.choices = {"grik": "pacte", "kaede": "join", "borin": "join", "lysandre": "join", "gorvak": "accueillir", "alderic": "join"}
		st.step = st.index_of("grik_2") + 1
		st._spawn_npcs()
		st._tick = 0.0
		st._process(0.1)
		check("Grik a une quête (« ! »)", sq.mark_for("grik") == "!" and st.npc("grik")._mark.text == "!")
		check("pas encore de quête de fin de jeu", sq.current_for("orvane").id == "orvane_a")
		check("parler à Grik : sa quête", talk("grik") and dlg._pages.size() >= 2)
		start("a")
	if later("a", 600):
		shot("01_offre.png")
		finish_dialog("ok")
		check("quête acceptée", sq.state_of("grik_a") == "active")
		fulfil(sq.quest("grik_a"))
		check("objectif atteint : « ? »", sq.mark_for("grik") == "?")
		var g0: int = p.inventory.count(items.get_item("graines_ble"))
		check("rendre la quête", talk("grik"))
		finish_dialog()
		check("récompense et quête finie", sq.state_of("grik_a") == "done" and p.inventory.count(items.get_item("graines_ble")) >= g0 + 20)
		print("== toutes les quêtes (histoire finie)")
		st.step = st.STEPS.size()
		st._spawn_npcs()
		start("b")
	if later("b", 400):
		var missing := []
		var guard := 0
		while guard < 120:
			guard += 1
			var any := false
			for id in st.NPCS:
				var q: Dictionary = sq.current_for(id)
				if q.is_empty(): continue
				any = true
				if not talk(id):
					missing.append(id)
					continue
				finish_dialog("ok")
				fulfil(q)
				if not talk(id):
					missing.append(id); continue
				finish_dialog()
				if sq.state_of(q.id) != "done":
					missing.append(q.id)
			if not any or not missing.is_empty(): break
		check("toutes finies (%d / 44) %s" % [sq.done_count(), str(missing)], sq.done_count() == 44 and missing.is_empty())
		check("plus aucune marque", st.NPCS.keys().all(func(id): return sq.mark_for(id) == ""))
		hud.journal.open()
		start("c")
	if later("c", 600):
		shot("02_journal.png")
		hud.journal.close()
		root.get_node("SaveGame").save_game("3")
		root.get_node("SaveGame").load_game("3")
		start("d")
	if later("d", 2500):
		sq = get_first_node_in_group("side_quests")
		check("rechargées : %d terminées" % sq.done_count(), sq.done_count() == 44)
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	return false
