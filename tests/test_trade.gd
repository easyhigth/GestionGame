extends SceneTree
var f := 0
var p; var w; var items; var fm; var vn; var k; var dc; var hud; var gd; var H
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/t_"
var tr
var m

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

func collect(r := 6.0) -> void:
	for n in w.get_node("Village").get_children():
		if n.has_method("take") and not n.is_taken() and n.global_position.distance_to(p.global_position) < r:
			p.try_pickup(n)

func craft(id: String) -> bool:
	for r in items.recipes:
		if r.result.id == id:
			var done: bool = r.craft(p.inventory, p.is_near_workbench(), p.nearby_stations())
			if done:
				p.crafted.emit(id)
			return done
	return false


func val(id: String) -> float:
	return tr.value_of(items.get_item(id))

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p: p._invulnerable_left = 5.0
	if f == 10:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		vn = get_first_node_in_group("village_needs"); k = get_first_node_in_group("kingdom")
		dc = get_first_node_in_group("day_cycle"); hud = get_first_node_in_group("hud"); gd = get_first_node_in_group("guide")
		tr = get_first_node_in_group("trade")
		get_first_node_in_group("raids").enabled = false
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		get_first_node_in_group("quests")._offer_timer = 9999.0
		print("== valeurs")
		check("commerce présent, marchand pas encore là (jour %d)" % tr.next_day, tr != null and not tr.is_here() and tr.next_day == 2)
		print("   bois %.2f  planches %.2f  lingot fer %.2f  épée bois %.1f  épée fer %.1f  pain %.1f  lit %.1f" % [val("wood"), val("bloc_planches"), val("iron_ingot"), val("sword_wood"), val("sword_iron"), val("pain"), val("lit")])
		check("un lingot vaut plus que le minerai", val("iron_ingot") > val("iron_ore"))
		check("une épée en fer vaut plus qu'une épée en bois", val("sword_iron") > val("sword_wood"))
		check("les planches ne se vendent pas (moins d'une demi-pièce)", tr.sell_price(items.get_item("bloc_planches")) == 0)
		check("l'or ne se vend pas", tr.sell_price(items.get_item("piece_or")) == 0)
		var cheap := true
		for id in ["wood", "iron_ingot", "sword_iron", "pain", "lit", "graines_ble", "houe"]:
			var it = items.get_item(id)
			if tr.buy_price(it) <= tr.sell_price(it): cheap = false
		check("on achète toujours plus cher qu'on ne vend", cheap)
		print("== arrivée")
		dc.hour = 23.0
		tr._check = 0.0; tr._process(0.1)
		check("jour 1 : pas de marchand", not tr.is_here())
		dc.day = 2; dc.hour = 8.3
		tr._check = 0.0; tr._process(0.1)
		check("jour 2 à 8 h : le marchand arrive", tr.is_here() and tr.leave_day == 3)
		m = tr.merchant
		check("marchand et charrette au village", m != null and is_instance_valid(m) and m.has_meta("merchant") and tr.cart != null)
		var cats := {}
		for s in tr.stock: cats[s.cat] = int(cats.get(s.cat, 0)) + 1
		print("   venu de ", tr.origin, " spécialité ", tr.specialty, " stock ", cats)
		check("stock varié (%d lignes, %d catégories)" % [tr.stock.size(), cats.size()], tr.stock.size() >= 12 and cats.size() >= 5)
		check("spécialité mieux fournie", int(cats.get(tr.specialty, 0)) >= 3)
		check("prix tous positifs", tr.stock.all(func(s): return s.price > 0))
		print("== boutique (E)")
		p.global_position = m.global_position + Vector3(1.0, 0, 0)
		var ev := InputEventAction.new(); ev.action = "interact"; ev.pressed = true
		p._unhandled_input(ev)
		check("E près du marchand : boutique ouverte", hud.shop_dialog.visible)
		hud.shop_dialog.close()
		print("== acheter")
		var e0: Dictionary = tr.stock[0]
		var it0 = items.get_item(e0.id)
		var n0: int = e0.n
		check("sans or : refus", tr.buy(p, e0, 1) != "" and count(e0.id) == 0 or it0.id in ["houe"])
		p.inventory.add(items.get_item("piece_or"), 500)
		var g0 := count("piece_or")
		var have0 := count(e0.id)
		check("achat : %s pour %d or" % [it0.display_name, e0.price], tr.buy(p, e0, 1) == "" and count("piece_or") == g0 - e0.price and count(e0.id) == have0 + 1)
		check("stock diminué", (n0 == 1 and not tr.stock.has(e0)) or e0.n == n0 - 1)
		print("== vendre")
		p.inventory.add(items.get_item("iron_ingot"), 12)
		var prices := []
		for i in 12:
			prices.append(tr.sell_price(items.get_item("iron_ingot")))
			tr.sell(p, items.get_item("iron_ingot"), 1)
		print("   prix du lingot : ", prices)
		check("vente : or gagné, prix en baisse", prices[0] > prices[11] and count("iron_ingot") == 0)
		p.inventory.add(items.get_item("stone"), 20)
		var g1 := count("piece_or")
		var got: int = tr.sell(p, items.get_item("stone"), 20)
		check("20 cailloux vendus (%d or)" % got, got >= 20 and count("stone") == 0 and count("piece_or") == g1 + got)
		print("== marché")
		var b_no: int = tr.buy_price(items.get_item("sword_iron"))
		var s_no: int = tr.sell_price(items.get_item("sword_iron"))
		var mt = load("res://data/rooms/marche.tres")
		k.rooms.append({"type": mt, "cells": {w.spawn_cell + Vector2i(40, 40): true}, "floor": -30.0, "enclosed": true, "doors": 1, "counts": {}, "tier": 0, "missing": {}})
		check("avec un marché : moins cher (%d -> %d), mieux payé (%d -> %d)" % [b_no, tr.buy_price(items.get_item("sword_iron")), s_no, tr.sell_price(items.get_item("sword_iron"))],
			tr.buy_price(items.get_item("sword_iron")) < b_no and tr.sell_price(items.get_item("sword_iron")) > s_no)
		print("== guide")
		gd.step = 20; gd.progress = 0; gd._refresh()
		tr.sell(p, items.get_item("wood"), 0)
		p.inventory.add(items.get_item("wood"), 10)
		tr.sell(p, items.get_item("wood"), 10)
		check("10 objets vendus -> acheter", gd.current_id() == "acheter")
		tr.buy(p, tr.stock[0], 1)
		check("achat -> marché (déjà construit : fini)", gd.current_id() == "marche" or gd.step >= 23)
		gd._check_state()
		check("marché construit : chapitre fini", gd.step >= 23)
		k.rooms.pop_back()
		# capture : le marchand et sa charrette
		p.global_position = tr.cart.global_position + (w.cell_center(w.spawn_cell) - tr.cart.global_position).normalized() * 4.0
		var look: Vector3 = tr.cart.global_position - p.global_position
		p.cam_yaw = atan2(-look.x, -look.z); p.cam_pitch = deg_to_rad(24.0); p.camera_zoom = 0.85; p.snap_camera()
		start("a")
	if later("a", 1500):
		shot("01_marchand.png")
		p.global_position = m.global_position + Vector3(1.0, 0, 0)
		p.inventory.add(items.get_item("wood"), 14); p.inventory.add(items.get_item("leather"), 5); p.inventory.add(items.get_item("carotte"), 8)
		hud.shop_dialog.open(m)
		start("b")
	if later("b", 500):
		shot("02_boutique.png")
		hud.shop_dialog.close()
		hud.kingdom_panel.open()
		start("c")
	if later("c", 400):
		shot("03_royaume.png")
		hud.kingdom_panel.close()
		set_meta("stock", tr.stock.size())
		set_meta("name", m.villager_name)
		root.get_node("SaveGame").save_game("3")
		root.get_node("SaveGame").load_game("3")
		start("d")
	if later("d", 2000):
		tr = get_first_node_in_group("trade"); dc = get_first_node_in_group("day_cycle"); w = get_first_node_in_group("world")
		check("rechargé : marchand toujours là (%d lignes)" % tr.stock.size(), tr.is_here() and tr.stock.size() == int(get_meta("stock")))
		check("rechargé : le même marchand", tr.merchant != null and is_instance_valid(tr.merchant) and tr.merchant.villager_name == get_meta("name"))
		check("un seul marchand", get_nodes_in_group("strangers").filter(func(s): return s.has_meta("merchant")).size() == 1)
		print("== départ")
		# pas d'événement du monde ce jour-là (la fête du royaume fait venir le marchand)
		get_first_node_in_group("world_events").next_day = 999
		dc.day = 3; dc.hour = 8.2
		tr._check = 0.0; tr._process(0.1)
		check("jour 3 au matin : il repart (prochain passage jour %d)" % tr.next_day, not tr.is_here() and tr.next_day == 6 and tr.stock.is_empty())
		start("e")
	if later("e", 600):
		check("marchand et charrette partis", get_nodes_in_group("strangers").filter(func(s): return s.has_meta("merchant")).is_empty())
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	return false
