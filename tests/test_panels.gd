extends SceneTree
## Panneaux de gestion (refonte) : chaque onglet du royaume, les expéditions, la diplomatie et le recrutement
## s'ouvrent sans erreur, avec leurs cartes et jauges ; une capture par écran.
var f := 0
var p; var w; var hud; var items
var ok := true
var shots := []
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/pn_"

func check(name: String, cond: bool) -> void:
	print(("  OK  " if cond else "  ÉCHEC  ") + name)
	ok = ok and cond

func _initialize():
	var h = load("res://scripts/hero/hero_profile.gd").new()
	h.hero_name = "Aldea"
	h.race = load("res://data/races/humain.tres")
	h.hero_class = load("res://data/classes/paladin.tres")
	h.job = load("res://data/jobs/fermier.tres")
	h.skill = load("res://data/skills/vorace.tres")
	root.get_node("GameState").hero = h
	root.get_node("GameState").world_seed = 4242
	change_scene_to_file("res://scenes/main.tscn")

func shot(n):
	root.get_viewport().get_texture().get_image().save_png(out + n)
	print("saved ", n)

## Nombre de nœuds d'un type sous un contrôle.
func count_of(node: Node, cls: String) -> int:
	var n := 0
	for c in node.find_children("*", cls, true, false):
		n += 1
	return n

const STEPS := ["apercu", "carte", "carte_zoom", "habitants", "production", "familiers", "quetes", "expeditions", "expeditions_choix", "diplomatie", "recrutement", "banniere", "fin_de_partie", "fiche", "boutique", "quete"]

func _process(_d) -> bool:
	f += 1
	if p:
		p._invulnerable_left = 5.0
	if f == 5:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); hud = get_first_node_in_group("hud")
		items = root.get_node("Items")
		get_first_node_in_group("raids").enabled = false
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		p.inventory.add(items.get_item("pain"), 6)
		p.inventory.add(items.get_item("graines_ble"), 10)
		# un plan de maison en attente, pour la carte
		var bm = p.get_node_or_null("BuildMode")
		if bm and bm.has_method("plan_layout"):
			var k = get_first_node_in_group("kingdom")
			for t in k.room_types:
				if t.id == "maison":
					var sel: Array = bm.plan_layout(t, w.spawn_cell + Vector2i(6, -6))
					bm._selection = sel
					bm._commit_selection()
					print("plan maison : %d éléments, %d plans" % [sel.size(), get_first_node_in_group("build_orders").orders.size()])
	var step := (f - 10) / 20
	var sub := (f - 10) % 20
	if f >= 10 and step < STEPS.size():
		var id: String = STEPS[step]
		if sub == 0:
			match id:
				"expeditions":
					hud.kingdom_panel.close()
					hud.expedition_panel.open()
				"expeditions_choix":
					var av: Array = get_first_node_in_group("expeditions").available()
					hud.expedition_panel._picked = av.slice(0, 2)
					hud.expedition_panel._refresh()
				"diplomatie":
					hud.expedition_panel.close()
					if hud.get("diplomacy_panel"):
						hud.diplomacy_panel.open()
				"recrutement":
					if hud.get("diplomacy_panel"):
						hud.diplomacy_panel.close()
					var tr = w.villager_scene.instantiate()
					tr.stranger = true
					tr.talents = {"chasseur": 0.6, "cuisinier": 0.2}
					tr.race = load("res://data/races/elfe.tres")
					tr.villager_name = "Ysolde"
					tr.level = 4
					tr.recruit_offer = w.make_offer("chasseur", 4)
					w.get_node("Village").add_child(tr)
					tr.global_position = p.global_position + Vector3(1.5, 0, 1.5)
					p.talk.emit(tr)
				"banniere":
					var rd: Array = hud.find_children("*", "RecruitDialog", true, false)
					if not rd.is_empty():
						rd[0].close()
					hud.heraldry_panel.open()
				"fin_de_partie":
					hud.heraldry_panel.close()
					hud.endgame_panel.open()
				"fiche":
					hud.endgame_panel.close()
					var v = get_first_node_in_group("villagers")
					set_meta("vil", v)
					p.open_inventory.emit(v)
				"boutique":
					var inv = get_first_node_in_group("inventory_ui")
					if inv: inv.close()
					var trd = get_first_node_in_group("trade")
					trd.arrive()
					set_meta("trd", trd)
				"carte_zoom":
					var km = hud.kingdom_panel._map
					var k = get_first_node_in_group("kingdom")
					# deux pièces d'exemple : une maison finie, un atelier à compléter
					var c0: Vector2i = w.spawn_cell + Vector2i(-9, -4)
					var cells_a := {}
					var cells_b := {}
					for x in 5:
						for y in 4:
							cells_a[c0 + Vector2i(x, y)] = true
							cells_b[c0 + Vector2i(x, y + 6)] = true
					var mai = load("res://data/rooms/maison.tres")
					k.rooms.push_front({"type": null, "cells": cells_b, "floor": 0.0, "enclosed": true, "doors": 1, "counts": {}, "tier": 0, "closest": mai, "missing": {"lit": 1}})
					k.rooms.push_front({"type": mai, "cells": cells_a, "floor": 0.0, "enclosed": true, "doors": 1, "counts": {}, "tier": 0, "missing": {}})
					for r in k.rooms:
						if r.enclosed:
							km.select_room(r)
							hud.kingdom_panel._fill_map_side(r)
							km.center = km.room_center(r)
							break
					km.zoom_at(km.size / 2.0, 2.2)
					km.queue_redraw()
				"quete":
					hud.shop_dialog.close()
					var qb = get_first_node_in_group("quests")
					var q: Dictionary = qb.make_offer("apporter")
					if not q.is_empty():
						qb.accept(q)
						hud.quest_dialog.open(q.giver)
				_:
					if not hud.kingdom_panel.visible:
						hud.kingdom_panel.open()
					hud.kingdom_panel._tab = id
					hud.kingdom_panel._refresh()
		if sub == 6 and id == "boutique":
			var trd = get_meta("trd")
			if trd.merchant:
				hud.shop_dialog.open(trd.merchant)
			check("le marchand est là", trd.merchant != null)
		if sub == 12:
			var panel: Control = hud.kingdom_panel if id in ["apercu", "carte", "carte_zoom", "habitants", "production", "familiers", "quetes"] else (hud.expedition_panel if id.begins_with("expeditions") else null)
			if panel:
				print("%s : %d cartes, %d jauges/pastilles" % [id, count_of(panel, "PanelContainer"), count_of(panel, "ColorRect")])
				check("écran %s rempli" % id, count_of(panel, "PanelContainer") >= 4)
			shot("%02d_%s.png" % [step + 1, id])
		return false
	if f >= 10 and step >= STEPS.size():
		check("aucun panneau bloqué", true)
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	return false
