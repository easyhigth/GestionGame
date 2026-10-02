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
var pol; var dip; var con
var ar_ok := {}
var g0 := 0

## La caméra derrière le héros, tournée vers un point.
func look(from: Vector3, at: Vector3, pitch := 20.0, zoom := 1.3) -> void:
	w.teleport(from)
	var d: Vector3 = at - p.global_position
	p.cam_yaw = atan2(-d.x, -d.z); p.cam_pitch = deg_to_rad(pitch); p.camera_zoom = zoom; p.snap_camera()

func units(ar_id: String) -> Array:
	var h = pol._units.get(ar_id)
	if h == null or not is_instance_valid(h): return []
	return h.get_children().filter(func(c): return c.has_method("receive_hit") or c.get("route") != null)

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p: p._invulnerable_left = 5.0
	if p and p.is_alive(): p.health.heal(99999)
	if f == 8:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		hud = get_first_node_in_group("hud"); pol = get_first_node_in_group("world_politics"); dip = get_first_node_in_group("diplomacy")
		con = get_first_node_in_group("command_console")
		get_first_node_in_group("raids").enabled = false
		get_first_node_in_group("weather").set_kind("clair")
		get_first_node_in_group("day_cycle").hour = 10.0
		check("le monde vivant existe", pol != null)
		print("== routes entre capitales")
		var r: Array = pol.route(pol.city_of("karg").center, pol.city_of("givre").center)
		check("une route de Gor-Karath à Hrodgard (%d points, %d m)" % [r.size(), pol._path_len(r)], r.size() > 10)
		check("elle part de Gor-Karath et arrive à Hrodgard", Vector2(r[0] - pol.city_of("karg").center).length() < 40.0 and Vector2(r[-1] - pol.city_of("givre").center).length() < 40.0)
		print("== guerre")
		# une guerre dont l'armée traverse un hameau de l'ennemi
		var pair := []
		for a in ["karg", "cendres", "givre", "sables", "sylvae"]:
			for b in ["givre", "sylvae", "sables", "karg", "cendres"]:
				if a == b or not pair.is_empty(): continue
				var test := {"kind": "army", "from": a, "goal": b, "nation": a, "target": b}
				pol._prepare(test)
				for s in test.stops:
					if pol._hamlet(s[1]).nation == b:
						pair = [a, b]
						break
		check("une paire de nations avec un hameau sur la route %s" % str(pair), not pair.is_empty())
		if pair.is_empty(): pair = ["karg", "givre"]
		check("guerre déclarée : %s contre %s" % pair, pol.start_war(pair[0], pair[1]) and pol.at_war(pair[0], pair[1]))
		check("pas deux fois la même guerre", not pol.start_war(pair[1], pair[0]))
		var ar: Dictionary = pol.armies.filter(func(x): return x.nation == pair[0])[0]
		check("une armée se met en marche (%s, %d m)" % [pol._army_name(ar), ar.len], ar.len > 50.0)
		var stop: Array = ar.stops.filter(func(s): return pol._hamlet(s[1]).nation == pair[1])[0]
		var h: Dictionary = pol._hamlet(stop[1])
		ar.dist = float(stop[0]) - 1.0
		pol._advance_armies(2.0)
		check("le hameau de %s change de camp (%s)" % [h.name, h.nation], h.nation == pair[0] and pol.owners.get(h.id, "") == pair[0])
		print("== économie")
		var m0: float = pol.price_mult(pair[0], "Forgeron", true)
		pol._economy_day()
		pol._economy_day()
		var m1: float = pol.price_mult(pair[0], "Forgeron", true)
		check("la guerre fait monter le prix des armes (%.2f -> %.2f)" % [m0, m1], m1 > m0 + 0.1)
		var trade = get_first_node_in_group("trade")
		var rng := RandomNumberGenerator.new()
		var cm = load("res://scripts/world/city_merchant.gd").new(trade, pol.city_of(pair[0]), "Forgeron", "Test", rng)
		var sw = items.get_item("sword_iron")
		var war_price: int = cm.buy_price(sw)
		pol.supply[pair[0]]["armes"] = 1.0
		var calm_price: int = cm.buy_price(sw)
		check("le forgeron vend plus cher en guerre (%d contre %d or)" % [war_price, calm_price], war_price > calm_price)
		pol.supply[pair[0]]["armes"] = 0.4
		check("le marchand l'annonce (« %s »)" % cm.market_note(), cm.market_note().contains("pénurie"))
		print("== l'armée sur la route")
		ar_ok = ar
		ar.dist = minf(float(ar.len) * 0.5, float(ar.len) - 60.0)
		var pos: Vector3 = pol.army_pos(ar)
		look(pos + pol._dir(ar) * 16.0, pos, 38.0, 2.6)
		start("army")
	if later("army", 2500):
		var u := units(ar_ok.id)
		var ap: Vector3 = pol.army_pos(ar_ok)
		var dd: Vector3 = ap - p.global_position
		p.cam_yaw = atan2(-dd.x, -dd.z); p.snap_camera()
		check("ses soldats marchent sur la route (%d)" % u.size(), u.size() >= 3 and u.all(func(c): return c.get("route") != null))
		shot("01_armee.png")
		print("== invasion des morts")
		check("événement d'hiver : les morts sortent d'un château", pol.start_event("morts"))
		var und: Array = pol.armies.filter(func(x): return x.kind == "undead")
		check("une armée de morts-vivants", und.size() == 1)
		if und.size() == 1:
			ar_ok = und[0]
			ar_ok.dist = float(ar_ok.len) * 0.5
			var pos: Vector3 = pol.army_pos(ar_ok)
			look(pos + pol._dir(ar_ok) * 12.0, pos, 34.0, 2.2)
		start("undead")
	if later("undead", 2500):
		var u := units(ar_ok.id)
		check("des morts-vivants hostiles (%d)" % u.size(), u.size() >= 3 and u.all(func(c): return c.has_method("receive_hit")))
		shot("02_morts.png")
		g0 = gold()
		for e in u: e.receive_hit(999999, p, 0.0, 0.0)
		start("undead_dead")
	if later("undead_dead", 2500):
		check("invasion repoussée", not pol.armies.has(ar_ok) and gold() > g0)
		check("la nouvelle court (%s)" % pol.news[-1][1], pol.news[-1][1].contains("poussière"))
		print("== tournoi")
		check("tournoi d'été à Qasr-Ammar", pol.start_event("tournoi", "sables") and pol._arena != null)
		var ap: Vector3 = pol.arena_pos()
		look(ap + Vector3(0, 0, 9), ap, 18, 1.6)
		g0 = gold()
		start("arena")
	if later("arena", 2500):
		shot("03_tournoi.png")
		w.teleport(pol.arena_pos())
		start("fight")
	if later("fight", 800):
		if pol._champion and is_instance_valid(pol._champion):
			pol._champion.receive_hit(999999, p, 0.0, 0.0)
		if pol.event.is_empty():
			check("tournoi gagné (+%d or)" % (gold() - g0), gold() >= g0 + 250)
			print("== foire")
			check("foire de printemps à Lothëlia", pol.start_event("foire", "sylvae"))
			check("les prix y baissent (%.2f)" % pol.price_mult("sylvae", "Épicier", true), pol.price_mult("sylvae", "Épicier", true) < 0.95)
			check("/monde", con.run("/monde"))
			hud.map_ui.open()
			hud.map_ui.zoom = 1.6
			hud.map_ui.center = Vector2(pol.army_pos(pol.armies[0]).x, pol.army_pos(pol.armies[0]).z) if not pol.armies.is_empty() else hud.map_ui.center
			con.run("/carte")
			start("map")
		else:
			start("fight")
	if later("map", 6000):
		hud.map_ui.queue_redraw()
		start("map2")
	if later("map2", 500):
		shot("04_carte.png")
		hud.map_ui.close()
		hud.diplomacy_panel.open()
		start("dip")
	if later("dip", 800):
		shot("05_diplomatie.png")
		hud.diplomacy_panel.close()
		set_meta("wars", pol.wars.size())
		set_meta("owners", pol.owners.duplicate())
		root.get_node("SaveGame").save_game("3")
		root.get_node("SaveGame").load_game("3")
		start("load")
	if later("load", 4000):
		pol = get_first_node_in_group("world_politics"); w = get_first_node_in_group("world")
		check("rechargé : %d guerre(s)" % pol.wars.size(), pol.wars.size() == int(get_meta("wars")))
		check("rechargé : les hameaux gardent leur bannière %s" % str(pol.owners), pol.owners == get_meta("owners"))
		var ok_h := true
		for hid in pol.owners:
			if pol._hamlet(hid).nation != pol.owners[hid]: ok_h = false
		check("rechargé : le monde le sait", ok_h)
		check("rechargé : des nouvelles (%d)" % pol.news.size(), pol.news.size() >= 4)
		print("RÉSULTAT : ", "tout est bon" if ok else "il y a des échecs")
		quit(0 if ok else 1)
	return false
