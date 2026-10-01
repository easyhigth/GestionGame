extends SceneTree
var f := 0
var p; var w; var items; var hud; var cl; var city; var con; var dc; var stock0 := 0; var mid := ""
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/cv_"

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

func look_to(target: Vector3, pitch := 24.0, zoom := 1.4) -> void:
	var d: Vector3 = target - p.global_position
	p.cam_yaw = atan2(-d.x, -d.z); p.cam_pitch = deg_to_rad(pitch); p.camera_zoom = zoom; p.snap_camera()

func folk(role: String) -> Array:
	return get_nodes_in_group("townsfolk").filter(func(t): return t.role == role and is_instance_valid(t) and not t.is_queued_for_deletion() and not t.get_parent().is_queued_for_deletion())

func talk_to(t) -> void:
	p.global_position = t.global_position + Vector3(0, 0, 1.2)
	var ev := InputEventAction.new(); ev.action = "interact"; ev.pressed = true
	p._unhandled_input(ev)

func lights() -> int:
	return cl.find_children("*", "OmniLight3D", true, false).size()

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p: p._invulnerable_left = 5.0
	if f == 8:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		hud = get_first_node_in_group("hud"); cl = get_first_node_in_group("city_life"); con = get_first_node_in_group("command_console")
		dc = get_first_node_in_group("day_cycle")
		get_first_node_in_group("raids").enabled = false
		get_first_node_in_group("weather").set_kind("clair")
		dc.hour = 10.0
		city = w.cities.filter(func(c): return c.nation == "givre")[0]
		check("Hrodgard a %d maisons" % city.houses.size(), city.houses.size() > 30)
		var tv: Dictionary = cl.tavern_of(city)
		check("une taverne « %s »" % tv.get("name", ""), not tv.is_empty())
		con.run("/tp hrodgard")
		# on entre dans la ville, près de la taverne
		var door: Vector2i = city.center + tv.door
		p.global_position = Vector3(door.x + 0.5, 0, door.y + 2.5)
		p.global_position.y = w.support_height(p.global_position, w.terrain_height(Vector2i(door.x, door.y + 2)) + 0.3)
		w.load_area(p.global_position)
		start("day")
	if later("day", 3000):
		check("des maisons meublées autour du héros (%d)" % cl.furnished_count("givre"), cl.furnished_count("givre") >= 4)
		var furn: Array = cl.find_children("*", "", true, false).filter(func(n): return n.has_meta("furniture"))
		var kinds := {}
		for n in furn: kinds[n.get_meta("furniture")] = true
		check("lits, tables, tonneaux... (%d meubles : %s)" % [furn.size(), ", ".join(kinds.keys())], furn.size() >= 15 and kinds.has("lit") and kinds.has("table"))
		check("le jour, pas de lumière allumée", lights() == 0)
		var inn: Array = folk("innkeeper")
		check("un aubergiste", inn.size() == 1)
		var qg = get_nodes_in_group("townsfolk").filter(func(t): return t.quest_key != "")
		check("deux citadins ont une quête (« ! »)", qg.size() == 2 and qg.all(func(t): return t._mark.visible and t._mark.text == "!"))
		check("des marchands le jour (%d)" % folk("merchant").size(), folk("merchant").size() == city.stalls.size())
		look_to(inn[0].global_position + Vector3(0, 1.5, 0), 20, 1.2)
		shot("01_taverne_jour.png")
		# un repas à la taverne
		p.inventory.add(items.get_item("piece_or"), 200)
		p.hunger = 20.0
		var g0: int = gold()
		talk_to(inn[0])
		check("repas à la taverne : -%d or, faim rassasiée" % (g0 - gold()), g0 - gold() == 5 and p.hunger >= 99.0)
		# une quête
		var q = qg[0]
		talk_to(q)
		var qd: Dictionary = cl.quests[q.quest_key]
		check("quête acceptée : %s %d %s" % [qd.type, qd.count, qd.need], qd.state == "active")
		if qd.type == "apporter":
			p.inventory.add(items.get_item(qd.need), qd.count)
			cl._refresh_mark(q)
		else:
			for i in qd.count: cl._on_enemy_died(Vector3(city.center.x + 40, 0, city.center.y + 40))
		check("la quête est prête (« ? »)", q._mark.text == "?")
		var rel0: float = get_first_node_in_group("diplomacy").rel("givre")
		g0 = gold()
		talk_to(q)
		check("quête rendue : +%d or, amitié %d -> %d" % [gold() - g0, rel0, get_first_node_in_group("diplomacy").rel("givre")],
			gold() > g0 and get_first_node_in_group("diplomacy").rel("givre") > rel0 and cl.quests[q.quest_key].state == "done")
		# acheter chez un marchand (le stock est sauvegardé)
		var m = folk("merchant")[0]
		var e: Dictionary = m.shop.stock[0]
		mid = e.id
		stock0 = int(e.n)
		m.shop.buy(p, e, 1)
		check("achat chez %s (%s : %d -> %d)" % [m.trade_name, mid, stock0, int(m.shop.stock[0].n) if not m.shop.stock.is_empty() else 0], int(e.n) == stock0 - 1)
		root.get_node("SaveGame").save_game("3")
		dc.hour = 22.5
		start("night")
	if later("night", 2500):
		check("la nuit, le marché est fermé", folk("merchant").size() == 0)
		check("la nuit, les rues se vident (%d citadins)" % folk("citizen").size(), folk("citizen").size() <= 12)
		check("torches et lanternes s'allument (%d lumières)" % lights(), lights() >= 4 and lights() <= 10)
		var inn: Array = folk("innkeeper")
		look_to(inn[0].global_position + Vector3(0, 1.5, 0), 20, 1.6)
		shot("02_rue_nuit.png")
		var g0: int = gold()
		talk_to(inn[0])
		check("une nuit à la taverne : -%d or" % (g0 - gold()), g0 - gold() == 12)
		start("morning")
	if later("morning", 2500):
		check("réveil au matin (%.1f h)" % dc.hour, not dc.is_night())
		root.get_node("SaveGame").load_game("3")
		start("load")
	if later("load", 3500):
		cl = get_first_node_in_group("city_life"); w = get_first_node_in_group("world"); dc = get_first_node_in_group("day_cycle")
		city = w.cities.filter(func(c): return c.nation == "givre")[0]
		var m = folk("merchant")
		check("rechargé : la ville est animée (%d marchands)" % m.size(), m.size() > 0)
		if m.size() > 0:
			var e = m[0].shop.stock.filter(func(x): return x.id == mid)
			check("rechargé : le stock du marchand est resté (%d)" % (int(e[0].n) if not e.is_empty() else -1), not e.is_empty() and int(e[0].n) == stock0 - 1)
		var qd = cl.quests.get("givre:0", cl.quests.get("givre:1", {}))
		check("rechargé : la quête rendue est notée", not qd.is_empty() and qd.state == "done")
		# une semaine plus tard : réassort
		dc.day += 7
		cl.refresh("givre")
		var m2 = folk("merchant")
		print("   marchands %d, jours des boutiques %s, aujourd'hui %d" % [m2.size(), m2.map(func(x): return x.shop.day), dc.day])
		check("une semaine plus tard, les marchands ont refait leur stock", m2.all(func(x): return x.shop.day == dc.day))
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	return false
