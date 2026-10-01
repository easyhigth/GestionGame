extends SceneTree
var f := 0
var p; var w; var items; var dip; var hud; var rm; var tr
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/jb_"

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
var k; var FG; var fam; var inv_ui

func room(id: String, i: int) -> Dictionary:
	var rt = load("res://data/rooms/%s.tres" % id)
	var r := {"type": rt, "cells": {w.spawn_cell + Vector2i(40 + i * 3, 40): true}, "floor": -30.0, "enclosed": true, "doors": 1, "counts": {}, "tier": 0, "missing": {}}
	k.rooms.append(r)
	return r

func villagers_free() -> Array:
	return get_nodes_in_group("villagers").filter(func(v): return v.get("work_room") == null and not v.get("companion"))

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p: p._invulnerable_left = 5.0
	if f == 10:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		hud = get_first_node_in_group("hud"); rm = get_first_node_in_group("raids"); k = get_first_node_in_group("kingdom")
		fam = get_first_node_in_group("familiars_mgr")
		FG = load("res://scripts/items/forge.gd")
		rm.enabled = false
		print("== pièces et production")
		var vs := villagers_free()
		var got := {}
		var i := 0
		for id in ["laboratoire", "sanctuaire_runes", "bureau_architecte"]:
			var r := room(id, i)
			var v = vs[i]
			v.work_room = r
			v.set("_at_work", true)
			var before := {}
			for e in p.inventory.entries:
				before[e.item.id] = e.count
			k._prod_timers[v] = 0.0
			k._produce(1000.0)
			var new_ids := []
			for e in p.inventory.entries:
				if e.count > int(before.get(e.item.id, 0)):
					new_ids.append(e.item.id)
			got[id] = new_ids
			v.work_room = null
			i += 1
		print("   produits : ", got)
		check("alchimiste : une potion", got.laboratoire.any(func(x): return str(x).begins_with("potion_")))
		check("enchanteur : une rune", got.sanctuaire_runes.any(func(x): return str(x).begins_with("rune_")))
		check("architecte : des blocs", got.bureau_architecte.any(func(x): return str(x).begins_with("bloc_")))
		check("métiers connus", vs[0].JOB_NAMES.has("alchimiste") and vs[0].JOBS.has("dresseur"))
		print("== potions")
		for id in ["potion_soin", "potion_force", "potion_garde", "potion_celerite"]:
			p.inventory.add(items.get_item(id), 2)
		p._invulnerable_left = 0.0
		p.health.take_damage(int(p.health.max_health * 0.6), null)
		var hp0: int = p.health.current
		var d1 = p.drink_potion()
		check("blessé : potion de soin (%d -> %d PV)" % [hp0, p.health.current], d1 != null and d1.id == "potion_soin" and p.health.current > hp0)
		p.health.heal(9999)
		var atk0: int = p.attack_power()
		var d2 = p.drink_potion()
		print("   bue : ", d2.id if d2 else "-", "  buffs ", p.skill.buffs)
		check("en forme : potion de renfort (%s)" % (d2.id if d2 else "-"), d2 != null and d2.id != "potion_soin" and not p.skill.buffs.is_empty())
		var d3 = p.drink_potion()
		check("une 2e potion de renfort différente (%s)" % (d3.id if d3 else "-"), d3 != null and d3.id != d2.id)
		check("recette : potion de soin au chaudron", load("res://data/recipes/potion_soin.tres").station == "chaudron")
		print("== runes")
		var sword = items.get_item("sword_iron")
		p.equipment.equip(sword)
		p.inventory.add(items.get_item("rune_force"), 1)
		p.inventory.add(items.get_item("rune_vie"), 1)
		var st := ["enclume"]
		var a0: int = p.attack_power()
		var it = FG.inscribe(p, sword, "rune_force", st)
		check("rune de force gravée : %s" % (it.id if it else "-"), it != null and it.rune == "rune_force" and p.weapon() == it)
		check("bonus de la rune (attaque %d -> %d)" % [a0, p.attack_power()], p.attack_power() > a0)
		p.inventory.add(items.get_item("iron_ingot"), 4)
		p.inventory.add(items.get_item("piece_or"), 100)
		var up = FG.upgrade(p, it, st)
		check("renforcé, la rune reste : %s" % (up.id if up else "-"), up != null and up.rune == "rune_force" and up.upgrade == 1)
		var it2 = FG.inscribe(p, up, "rune_vie", st)
		check("rune remplacée : %s" % (it2.id if it2 else "-"), it2 != null and it2.rune == "rune_vie" and it2.upgrade == 1)
		check("texte : %s" % it2.stats_text().replace("\n", " / "), it2.stats_text().contains("Rune : Vie"))
		print("== ménagerie et dresseurs")
		check("8 familiers au plus sans ménagerie", fam.max_total(self) == 8)
		var mr := room("menagerie", 5)
		check("10 avec une ménagerie", fam.max_total(self) == 10)
		fam.list.append({"data": "res://data/enemies/loup.tres", "level": 2, "name": "Grelot", "evo": 0, "kills": 0, "down": 0.0, "node": null, "place": "village"})
		var dv = villagers_free()[0]
		dv.work_room = mr
		set_meta("dv", dv)
		start("train")
	if f > 10 and has_meta("dv") and not has_meta("train_done"):
		get_meta("dv").set("_at_work", true)
	if later("train", 800):
		fam._train = 0.0
		start("train2")
	if later("train2", 600):
		var e = fam.list.back()
		check("le dresseur entraîne %s (%d victoire)" % [e.name, int(e.kills)], int(e.kills) >= 1)
		for c in root.find_children("*", "Control", true, false):
			if c.get_script() and c.get_script().resource_path.ends_with("inventory_ui.gd"):
				inv_ui = c
		p.inventory.add(items.get_item("rune_garde"), 2)
		p.inventory.add(items.get_item("rune_celerite"), 1)
		p.open_inventory.emit(p)
		inv_ui._stations = ["enclume"]
		inv_ui._cat = "Forge"
		inv_ui._refresh()
		start("ui")
	if later("ui", 700):
		shot("01_forge_runes.png")
		inv_ui.close()
		print("RÉSULTAT : " + ("tout est bon" if ok else "ÉCHECS"))
		return true
	return f > 30000
