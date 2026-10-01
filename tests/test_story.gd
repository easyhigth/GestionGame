extends SceneTree
var f := 0
var p; var w; var items; var fm; var vn; var k; var dc; var hud; var gd; var H
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/s_"
var st
var dlg
var dm
var rm
var wait_until := 0.0
var phase := ""
var talked := {}
var done_bosses := {}
var shots := {}
var step_guard := 0
var last_step := -1
const CHOICE := {"grik_2": "pacte", "kaede_3": "join", "borin_fer": "join", "perles": "map", "gorvak": "accueillir",
	"alderic_2": "join", "cael": "liberer", "epilogue": "pactes"}

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

func view(yaw, pitch, zoom) -> void:
	p.cam_yaw = deg_to_rad(yaw); p.cam_pitch = deg_to_rad(pitch); p.camera_zoom = zoom; p.snap_camera()

func finish_dialog(choice := "") -> void:
	while dlg._page < dlg._pages.size() - 1:
		dlg._next()
	if dlg._choices.is_empty():
		dlg._close("")
	else:
		dlg._close(choice if choice != "" else dlg._choices[0][1])

func goto(pos: Vector3) -> void:
	w.load_area(pos)
	p.global_position = pos + Vector3(1.0, 0, 0)
	p.global_position.y = w.ground_height_at(p.global_position + Vector3(0, 30, 0))

func open_talk(id: String) -> bool:
	var n = st.npc(id)
	if n == null:
		print("   pas de ", id, " (état ", st.npc_state.get(id, "?"), ")")
		return false
	goto(n.global_position)
	if n.get("stranger"):
		p.talk.emit(n)
	else:
		st.try_talk(n)
	return dlg.visible

func beat_boss_of_region() -> bool:
	for z in w.zones:
		if (z.gate as Vector2i).x >= 0 and z.type and z.type.boss and not st.shards.has(z.type.id):
			z.cleared = true
			dm.boss_defeated.emit(z, "")
			return true
	return false

func kill(e) -> void:
	for i in 12:
		if is_instance_valid(e) and e.is_alive():
			e._invulnerable_left = 0.0
			e.receive_hit(999999, p, 0.0, 0.0)

## Une étape : ce qu'il faut faire pour l'accomplir. Renvoie le temps d'attente (ms) avant de vérifier.
func do_step() -> int:
	var s: Array = st.current()
	var id: String = s[0]
	var o: Dictionary = s[6] if s.size() > 6 else {}
	match s[4]:
		"talk":
			if o.has("item"):
				p.inventory.add(items.get_item(o.item), int(o.n))
			if id == "coeur" and not st._has_room("temple"):
				add_room("temple")
			var who: String = s[5]
			if not open_talk(who):
				check("dialogue « %s » avec %s" % [id, who], false)
				return 400
			var speaker: String = dlg._name.text
			talked[who] = true
			for pg in dlg._pages:
				if pg[0] != "hero":
					talked[pg[0]] = true
			if id in ["intro", "ulric", "duel_ren", "orvane_verite", "cael"] and not shots.has(id):
				shots[id] = true
				var n = st.npc(who)
				if n:
					n.facing = (p.global_position - n.global_position).normalized()
				view(45, 20, 0.7)
				phase = "shot_" + id
				return 700
			finish_dialog(CHOICE.get(id, ""))
			return 60
		"obelisks":
			var n := 0
			for z in w.zones:
				if (z.obelisk as Vector2i).x >= 0 and n < int(s[5]):
					z.obelisk_on = true; n += 1
			st._check()
			return 60
		"boss_of":
			var z = st.npc_zone(s[5])
			z.cleared = true
			dm.boss_defeated.emit(z, "")
			return 60
		"shards":
			while st.current_id() == id and beat_boss_of_region():
				pass
			return 60
		"room":
			var parts: PackedStringArray = str(s[5]).split(":")
			var need := int(parts[1]) if parts.size() > 1 else 1
			while st._room_count(parts[0]) < need:
				add_room(parts[0])
			st._check()
			return 60
		"pop":
			var missing: int = int(s[5]) - vn.members().size()
			if missing > 0:
				st._recruit("res://data/races/humain.tres", missing, 1, w.cell_center(w.spawn_cell))
			st._check()
			return 60
		"pack":
			goto(st.camp_center(s[5]))
			st._tick = 0.0
			st._process(0.1)
			if id == "loups" and not shots.has("pack"):
				shots["pack"] = true
				view(30, 30, 1.4)
				phase = "shot_pack"
				return 900
			for e in st._pack.duplicate():
				kill(e)
			return 200
		"raid":
			goto(w.cell_center(w.spawn_cell))
			st._raid_wait = 0.0
			st._tick = 0.0
			st._process(0.1)
			rm.raid.timer = 0.0
			rm._process(0.1)
			phase = "raid"
			return 600
		"duel":
			var key: String = s[5]
			if st.npc(key):
				check("parler à %s lance le duel" % key, open_talk(key))
				talked[key] = true
				finish_dialog()
			else:
				goto(st._duel_pos(key))
				st._tick = 0.0
				st._process(0.1)
			check("boss « %s » apparu" % key, st._boss != null and is_instance_valid(st._boss))
			if key in ["ren", "brume"] and not shots.has("duel_" + key):
				shots["duel_" + key] = true
				view(0, 20, 1.5)
				phase = "shot_duel_" + key
				return 1500
			kill(st._boss)
			return 900
		"have_any":
			p.inventory.add(items.get_item("epee_mithril"), 1)
			st._check()
			return 60
	return 200

func add_room(t: String) -> void:
	var rt = load("res://data/rooms/%s.tres" % t)
	k.rooms.append({"type": rt, "cells": {w.spawn_cell + Vector2i(40 + k.rooms.size() * 3, 40): true}, "floor": -30.0, "enclosed": true, "doors": 1, "counts": {}, "tier": 0, "missing": {}})

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p: p._invulnerable_left = 5.0
	if p and p.is_alive(): p.health.heal(99999)
	if f == 10:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		vn = get_first_node_in_group("village_needs"); k = get_first_node_in_group("kingdom")
		dc = get_first_node_in_group("day_cycle"); hud = get_first_node_in_group("hud")
		st = get_first_node_in_group("story"); dlg = get_first_node_in_group("story_dialog"); dm = get_first_node_in_group("dungeons")
		rm = get_first_node_in_group("raids")
		rm.enabled = false
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		get_first_node_in_group("quests")._offer_timer = 9999.0
		get_first_node_in_group("weather").set_kind("clair")
		dc.hour = 11.0
		print("== structure")
		var acts := {}
		for s in st.STEPS:
			acts[s[1]] = int(acts.get(s[1], 0)) + 1
		check("%d étapes" % st.STEPS.size(), st.STEPS.size() >= 75)
		check("%d actes" % acts.size(), acts.size() >= 15)
		check("au moins 5 étapes par acte %s" % str(acts.values()), acts.values().all(func(n): return n >= 5))
		check("%d personnages" % st.NPCS.size(), st.NPCS.size() >= 20)
		var missing := []
		for s in st.STEPS:
			if s[4] == "talk" and not st.DIALOGS.has(s[0]): missing.append(s[0])
			if s[4] == "duel" and s[5] != "brume" and not st.DIALOGS.has(s[0]): missing.append(s[0])
			if s[4] == "talk" and s.size() > 6 and s[6].has("item") and not st.DIALOGS.has("wait_" + s[0]): missing.append("wait_" + s[0])
			var rw: Dictionary = s[6].get("reward", {}) if s.size() > 6 else {}
			if rw.has("skill") and TalentTree.node(rw.skill).is_empty(): missing.append("talent " + rw.skill)
			for it in rw.get("items", []):
				if items.get_item(it[0]) == null: missing.append("objet " + it[0])
		for id in st.NPCS:
			if not ResourceLoader.exists(st.NPCS[id].race): missing.append("race " + id)
			for it in st.NPCS[id].kit:
				if items.get_item(it) == null: missing.append("kit %s %s" % [id, it])
		check("dialogues, compétences, objets et races présents %s" % str(missing), missing.is_empty())
		print("== ressources rares et forge légendaire")
		var b = load("res://scenes/enemies/boss.tscn").instantiate()
		b.data = load("res://data/enemies/boss_seigneur_ignarok.tres")
		var got := {}
		for i in 30:
			for pair in load("res://scripts/items/rare_drops.gd").roll_enemy(b):
				got[pair[0].id] = int(got.get(pair[0].id, 0)) + int(pair[1])
		b.free()
		print("   30 Ignarok : ", got)
		check("les boss lâchent mithril et écailles de dragon", got.get("mithril_brut", 0) > 10 and got.get("ecaille_dragon", 0) >= 90)
		var legend: Array = items.recipes.filter(func(r): return r.category == "Légendaire")
		check("%d recettes légendaires" % legend.size(), legend.size() >= 10)
		for pair in [["mithril_brut", 8], ["wood", 10], ["leather", 4], ["orichalque", 2], ["cristal_aube", 3], ["larme_esprit", 1]]:
			p.inventory.add(items.get_item(pair[0]), pair[1])
		var st_all := ["four", "enclume", "autel", "etabli"]
		var r_ingot: RecipeData = items.recipes.filter(func(r): return r.result.id == "lingot_mithril")[0]
		for i in 4: r_ingot.craft(p.inventory, true, st_all)
		check("4 lingots de mithril fondus", count("lingot_mithril") == 4)
		var r_eveil: RecipeData = items.recipes.filter(func(r): return r.result.id == "lame_eveil")[0]
		check("Lame de l'Éveil forgée (orichalque + cristaux d'aube)", r_eveil.craft(p.inventory, true, st_all) and count("lame_eveil") == 1)
		var le: ItemData = items.get_item("lame_eveil")
		check("légendaire : %s, attaque %d" % [le.display_name, le.attack], le.rarity == 4 and le.attack >= 40)
		p.inventory.remove(le, 1)
		print("== histoire")
		start_next()
	if f > 10:
		if phase.begins_with("shot_") and game_ms >= wait_until:
			var what := phase.substr(5)
			shot("%s.png" % what)
			phase = ""
			if what.begins_with("duel_"):
				kill(st._boss)
				wait_until = game_ms + 900
				phase = "wait"
			elif what == "pack":
				for e in st._pack.duplicate(): kill(e)
				wait_until = game_ms + 200
				phase = "wait"
			else:
				finish_dialog(CHOICE.get(what, ""))
				wait_until = game_ms + 60
				phase = "wait"
			return false
		if phase == "raid" and game_ms >= wait_until:
			for e in rm.alive_raiders(): kill(e)
			rm._process(0.1)
			phase = "wait"
			wait_until = game_ms + 300
			return false
		if phase == "wait" and game_ms >= wait_until:
			phase = ""
			start_next()
		if phase == "journal" and game_ms >= wait_until:
			shot("journal.png")
			hud.journal.close()
			hud.talent_ui.open()
			phase = "talents"
			wait_until = game_ms + 600
		elif phase == "talents" and game_ms >= wait_until:
			shot("talents.png")
			hud.talent_ui._show_pacte = true
			hud.talent_ui._on_node("pac_eveil")
			phase = "pacte"
			wait_until = game_ms + 500
		elif phase == "pacte" and game_ms >= wait_until:
			shot("pacte.png")
			hud.talent_ui.close_ui()
			root.get_node("SaveGame").save_game("3")
			set_meta("choices", st.choices.duplicate())
			set_meta("talents", p.talents.keys().filter(func(t): return TalentTree.is_story(t)).size())
			root.get_node("SaveGame").load_game("3")
			phase = "reload"
			wait_until = game_ms + 2500
		elif phase == "reload" and game_ms >= wait_until:
			st = get_first_node_in_group("story")
			p = get_first_node_in_group("player")
			k = get_first_node_in_group("kingdom")
			check("histoire rechargée (finie, choix %s)" % str(st.choices), st.is_done() and st.choices == get_meta("choices"))
			var nt: int = p.talents.keys().filter(func(t): return TalentTree.is_story(t)).size()
			check("compétences uniques rechargées (%d)" % nt, nt == get_meta("talents"))
			check("titre du royaume : %s" % k.title(), k.title().begins_with("Fédération des Pactes"))
			var names := {}
			for v in get_nodes_in_group("villagers"):
				if v.has_meta("story"): names[v.villager_name] = int(names.get(v.villager_name, 0)) + 1
			print("   personnages au village : ", names)
			check("pas de doublon au village", names.values().all(func(n): return n == 1))
			check("Pip est un hobgobelin", st.npc("pip") != null and st.npc("pip").race.resource_path.ends_with("hobgobelin.tres"))
			print("RÉSULTAT : ", "tout est bon" if ok else "échec")
			return true
	return false

func start_next() -> void:
	if st.is_done():
		finish_story()
		return
	if st.step == last_step:
		step_guard += 1
		if step_guard > 3:
			check("étape « %s » bloquée" % st.current_id(), false)
			print("RÉSULTAT : échec")
			quit()
			return
	else:
		step_guard = 0
		if last_step >= 0 and st.STEPS[st.step][1] != st.STEPS[last_step][1]:
			print("-- ", st.ACTS[st.STEPS[st.step][1]])
	last_step = st.step
	var ms := do_step()
	if not phase.begins_with("shot_") and phase != "raid":
		phase = "wait"
	wait_until = game_ms + ms

func finish_story() -> void:
	print("== fin")
	check("histoire terminée (%d étapes)" % st.step, st.is_done())
	var story_t: int = p.talents.keys().filter(func(t): return TalentTree.is_story(t)).size()
	check("15 compétences uniques débloquées (%d)" % story_t, story_t == 15)
	var uniques := ["croc_meute", "katana_cornes", "marteau_borin", "cape_routes", "hache_horde", "bouclier_hauterive", "sceptre_parjure", "couronne_pactes"]
	var have := uniques.filter(func(id): return count(id) > 0 or p.equipment.slots.values().has(items.get_item(id)))
	check("objets uniques reçus %d / %d %s" % [have.size(), uniques.size(), str(uniques.filter(func(id): return not have.has(id)))], have.size() == uniques.size())
	check("personnages rencontrés : %d %s" % [talked.size(), str(talked.keys())], talked.size() >= 20)
	check("nation : %s" % st.nation_name(), st.nation_name() == "Fédération des Pactes")
	check("tous les obélisques brillent", w.zones.all(func(z): return z.obelisk_on))
	hud.journal.open()
	phase = "journal"
	wait_until = game_ms + 600
