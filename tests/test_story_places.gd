extends SceneTree
var f := 0
var p; var w; var items; var hud; var cities; var idx := 0; var cam: Camera3D
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/ci_"

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
	if has_meta(key + "_done"): remove_meta(key + "_done")

func gold() -> int:
	return p.inventory.count(items.get_item("piece_or"))
var st; var sq; var dip
var shots := []   # [id, étape, fichier]
var si := 0

## La caméra derrière le héros, à côté d'un personnage de l'histoire, tournée vers lui.
func look_at_npc(n: Node3D, out := Vector2.ZERO) -> void:
	var at: Vector3 = n.global_position + (Vector3(out.x, 0, out.y) * 4.5 if out != Vector2.ZERO else Vector3(2.5, 0, 3.5))
	w.teleport(at)
	var d: Vector3 = n.global_position - p.global_position
	p.cam_yaw = atan2(-d.x, -d.z); p.cam_pitch = deg_to_rad(18); p.camera_zoom = 1.1; p.snap_camera()

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p: p._invulnerable_left = 5.0
	if f == 8:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		hud = get_first_node_in_group("hud"); st = get_first_node_in_group("story"); sq = get_first_node_in_group("side_quests")
		dip = get_first_node_in_group("diplomacy")
		get_first_node_in_group("raids").enabled = false
		get_first_node_in_group("weather").set_kind("clair")
		get_first_node_in_group("day_cycle").hour = 10.0
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		print("== les lieux de l'histoire")
		var kinds := {"borin": "cave", "liora": "city", "lysandre": "city", "edmond": "castle", "morvain": "castle", "selene": "cave", "cendres": "city"}
		for id in kinds:
			var pl: Dictionary = st.place_of(id)
			print("   %s : %s" % [id, str(pl)])
			check("%s vit dans un vrai lieu (%s)" % [id, kinds[id]], not pl.is_empty() and pl.kind == kinds[id])
		var lo: Dictionary = st.city_of("sylvae")
		var lp: Vector3 = st.place_of("liora").pos
		check("Liora est dans les murs de Lothëlia", Vector2(lp.x - lo.center.x, lp.z - lo.center.y).length() < float(lo.radius))
		var qa: Dictionary = st.city_of("sables")
		var yp: Vector3 = st.place_of("lysandre").pos
		check("Lysandre est au bazar de Qasr-Ammar", Vector2(yp.x - qa.center.x, yp.z - qa.center.y).length() < float(qa.radius))
		var hr: Dictionary = st.city_of("givre")
		var bp: Vector3 = st.place_of("borin").pos
		var bd := Vector2(bp.x - hr.center.x, bp.z - hr.center.y).length()
		check("la grotte de Borin est près de Hrodgard (%d m)" % bd, bd < float(hr.radius) + 260.0)
		var mp: Vector3 = st.place_of("morvain").pos
		var sp: Vector3 = st.place_of("selene").pos
		check("la grotte de Séléné est près du repaire de Morvain (%d m)" % mp.distance_to(sp), Vector2(mp.x - sp.x, mp.z - sp.z).length() < 260.0)
		check("Edmond et Morvain dans deux châteaux différents", st.place_of("edmond").site != st.place_of("morvain").site)
		for id in ["edmond", "morvain"]:
			var cp: Vector3 = st.place_of(id).pos
			check("le château de %s est loin des capitales" % id, w.cities.all(func(c): return Vector2(cp.x - c.center.x, cp.z - c.center.y).length() > float(c.radius) + 25.0))
		var steps := ["borin", "liora", "lysandre", "perles", "edmond", "templiers", "selene", "veilleurs"]
		for sid in steps:
			var s: Array = st.STEPS[st.index_of(sid)]
			print("   journal « %s » : %s" % [sid, st.hint(s)])
		check("le journal nomme Hrodgard", st.hint(st.STEPS[st.index_of("borin")]).contains("Hrodgard"))
		check("le journal nomme Lothëlia", st.hint(st.STEPS[st.index_of("liora")]).contains("Lothëlia"))
		check("le journal parle des épaves pour les perles", st.hint(st.STEPS[st.index_of("perles")]).contains("épave"))
		var mn: Dictionary = st.city_of("cendres")
		var sa: Vector3 = st._sanctuary_pos()
		var sd := Vector2(sa.x - mn.center.x, sa.z - mn.center.y).length()
		check("le Sanctuaire aux portes de Minas Cendrys (%d m du centre)" % sd, sd > float(mn.radius) and sd < float(mn.radius) + 75.0)
		print("== sauvegardes")
		var fi: int = st.index_of("forge")
		check("ancienne sauvegarde (rang d'origine) -> même étape", st._step_index({"step": fi - 1}) == fi)
		check("sauvegarde par identifiant", st._step_index({"step": 0, "step_id": "hrodgard"}) == st.index_of("hrodgard"))
		check("histoire finie", st._step_index({"step": 3, "step_id": ""}) == st.STEPS.size())
		print("== les personnages dans leurs lieux")
		st.choices = {"grik": "pacte", "kaede": "join", "alderic": "join"}
		shots = [["liora", "liora", "01_liora_lothelia.png"], ["borin", "borin", "02_borin_grotte.png"], ["lysandre", "lysandre", "03_lysandre_bazar.png"],
			["edmond", "edmond", "04_edmond_chateau.png"], ["morvain", "templiers", "05_morvain_repaire.png"], ["selene", "selene", "06_selene_grotte.png"]]
		start("npc")
	if later("npc", 300):
		var sh: Array = shots[si]
		st.step = st.index_of(sh[1])
		st._enter_step()
		st._spawn_npcs()
		var n = st.npc(sh[0])
		check("%s est là (%s)" % [sh[0], st.hint(st.current())], n != null)
		if n:
			var d: float = n.global_position.distance_to(st.place_of(sh[0]).pos)
			check("%s à son lieu (%.1f m)" % [sh[0], d], d < 4.0)
			look_at_npc(n, st.place_of(sh[0]).get("out", Vector2.ZERO))
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		start("npc_shot")
	if later("npc_shot", 3500):
		shot(shots[si][2])
		si += 1
		if si < shots.size():
			start("npc")
		else:
			start("visit")
	if later("visit", 300):
		print("== visite d'une capitale")
		st.step = st.index_of("hrodgard")
		st._enter_step()
		var hr: Dictionary = st.city_of("givre")
		var r0: float = dip.rel("givre")
		var g0 := gold()
		check("le suivi montre la route (%s)" % st.tracker_text(), st.target_pos() != Vector3.INF)
		st._check()
		check("pas encore dans les murs", st.current_id() == "hrodgard")
		w.teleport(Vector3(hr.center.x + 0.5, 0, hr.center.y + hr.radius * 0.5))
		st._check()
		check("dans Hrodgard : étape suivante (%s)" % st.current_id(), st.current_id() == "forge")
		check("le Jarl apprécie (%d -> %d)" % [r0, dip.rel("givre")], dip.rel("givre") > r0)
		check("récompense (+%d or)" % (gold() - g0), gold() >= g0 + 60)
		start("visit_shot")
	if later("visit_shot", 1200):
		shot("07_hrodgard_jarl.png")
		print("== quêtes d'exploration")
		st.step = st.STEPS.size() - 1
		for qid in ["borin_c", "lysandre_c", "alderic_c", "selene_c"]:
			var q: Dictionary = sq.quest(qid)
			sq.states[qid] = {"state": "active", "progress": 0}
			check("%s : « %s » (%s)" % [qid, q.title, sq.progress_text(q)], not sq.is_complete(q))
		var mc = get_first_node_in_group("mountain_caves")
		for i in 3: mc.chest_opened.emit("m_test")
		for i in 3: sq.on_chest("wreck")
		sq.on_chest("castle_lord")
		check("coffre d'un château habité : ne compte pas", int(sq.states.alderic_c.progress) == 0)
		for i in 2: sq.on_chest("castle")
		for qid in ["borin_c", "lysandre_c", "alderic_c", "selene_c"]:
			check("%s accomplie (%s)" % [qid, sq.progress_text(sq.quest(qid))], sq.is_complete(sq.quest(qid)))
		# un vrai coffre d'épave
		var wr = w.structure_sites.filter(func(s): return s.kind == "wreck")
		sq.states["lysandre_c"] = {"state": "active", "progress": 0}
		if not wr.is_empty():
			var c = load("res://scripts/world/world_chest.gd").new()
			c.chest_id = "test_wreck"; c.kind = "wreck"
			w.add_child(c)
			c.global_position = p.global_position + Vector3(1, 0, 0)
			c.open(p)
			check("ouvrir un coffre d'épave fait avancer la quête", int(sq.states.lysandre_c.progress) == 1)
		print("RÉSULTAT : ", "tout est bon" if ok else "il y a des échecs")
		quit(0 if ok else 1)
	return false
