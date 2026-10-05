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

var g; var steps_log := []

func at(id: String) -> bool:
	return g.current_id() == id

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p: p._invulnerable_left = 5.0
	if f == 10:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		hud = get_first_node_in_group("hud"); rm = get_first_node_in_group("raids"); dip = get_first_node_in_group("diplomacy")
		g = get_first_node_in_group("guide")
		rm.enabled = false
		print("== chapitres de l'aventure et des voisins")
		check("%d étapes, %d chapitres" % [g.STEPS.size(), g.CHAPTERS.size()], g.STEPS.size() == 52 and g.CHAPTERS.size() == 12)
		check("le guide commence par les bases (%s)" % g.current_id(), g.current_id() == "bouger" or g.step > 0)
		check("touches du joueur dans les conseils : %s" % g.with_keys("{inventory} / {attack}"), g.with_keys("{inventory} / {attack}") == "E / clic gauche")
		g.step = 36
		g.progress = 0
		g._refresh()
		check("chapitre « L'AVENTURE » : %s" % g._title.text, g._title.text.begins_with("L'AVENTURE"))
		var z = w.zones.filter(func(zz): return zz.gate.x >= 0)[0]
		z.cleared = true
		start("a")
	if later("a", 1300):
		check("boss de donjon vaincu -> forge", at("forge"))
		p.equipment.equip(items.get_item("sword_iron@1"))
		start("b")
	if later("b", 1300):
		check("objet +1 -> potion", at("potion"))
		p.inventory.add(items.get_item("potion_force"), 1)
		p.drink_potion()
		start("c")
	if later("c", 1300):
		check("potion bue -> succès", at("succes"))
		hud.achievements_panel.open()
		start("d")
	if later("d", 600):
		hud.achievements_panel.close()
		start("d2")
	if later("d2", 1300):
		check("succès ouverts -> diplomatie (chapitre LES VOISINS : %s)" % g._title.text, at("diplomatie") and g._title.text.begins_with("LES VOISINS"))
		shot("01_guide_voisins.png")
		hud.diplomacy_panel.open()
		start("e")
	if later("e", 600):
		hud.diplomacy_panel.close()
		start("e2")
	if later("e2", 1300):
		check("diplomatie ouverte -> présent", at("cadeau"))
		p.inventory.add(items.get_item("piece_or"), 200)
		dip.act("givre", "gift")
		start("f")
	if later("f", 1300):
		check("présent -> traité", at("traite"))
		dip.states.sables.rel = 30.0
		dip.act("sables", "commerce")
		start("g")
	if later("g", 1300):
		check("traité -> métier avancé", at("metier"))
		var k = get_first_node_in_group("kingdom")
		k.rooms.append({"type": load("res://data/rooms/laboratoire.tres"), "cells": {w.spawn_cell + Vector2i(40, 40): true}, "floor": -30.0, "enclosed": true, "doors": 1, "counts": {}, "tier": 0, "missing": {}})
		start("h")
	if later("h", 1300):
		check("laboratoire -> événement", at("evenement"))
		get_first_node_in_group("achievements").note("event_fete")
		start("i")
	if later("i", 1300):
		check("événement -> arsenal (chapitre L'ARTISAN : %s)" % g._title.text, at("arsenal") and g._title.text.begins_with("L'ARTISAN"))
		p.inventory.add(items.get_item("arm_epee_cuivre_0"), 1)
		start("j")
	if later("j", 1300):
		check("arme d'arsenal -> métier niveau 10", at("metier10"))
		p.crafts["mineur"] = 2000
		start("k")
	if later("k", 1300):
		check("métier 12 -> enchantement", at("enchanter"))
		p.equipment.equip(items.get_item("sword_iron@0^tranchant:1"))
		start("l")
	if later("l", 1300):
		check("enchantement -> catalogue", at("catalogue"))
		var blk = null
		for it in items.items.values():
			if it.is_block() and it.block_texture and it.block_texture.resource_path == "":
				blk = it
				break
		p.inventory.add(blk, 1)
		start("m")
	if later("m", 1300):
		check("bloc du catalogue -> palier (chapitre FIN DE PARTIE : %s)" % g._title.text, at("palier") and g._title.text.begins_with("LA FIN"))
		var eg = get_first_node_in_group("endgame")
		eg.tier = 1
		start("n")
	if later("n", 1300):
		check("palier -> faille", at("faille"))
		get_first_node_in_group("endgame").best_rift = 1
		start("o")
	if later("o", 1300):
		check("faille -> titan", at("titan"))
		get_first_node_in_group("endgame").titans_slain = 1
		start("q")
	if later("q", 1300):
		check("guide terminé", g.is_done())
		print("== astuces")
		p.inventory.add(items.get_item("gemme_rubis"), 1)
		start("t")
	if later("t", 2500):
		check("astuce de la première gemme", g.tips_seen.has("gemme"))
		var d = JSON.parse_string(JSON.stringify(g.export_state()))
		g.tips_seen = {}
		g.import_state(d)
		check("astuces vues sauvegardées", g.tips_seen.has("gemme"))
		print("RÉSULTAT : " + ("tout est bon" if ok else "ÉCHECS"))
		return true
	return f > 30000
