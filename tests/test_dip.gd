extends SceneTree
var f := 0
var p; var w; var items; var dip; var hud; var rm; var tr
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/dp_"

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

var day := 10

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p: p._invulnerable_left = 5.0
	if f == 10:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		dip = get_first_node_in_group("diplomacy"); hud = get_first_node_in_group("hud"); rm = get_first_node_in_group("raids"); tr = get_first_node_in_group("trade")
		rm.enabled = false
		p.inventory.add(items.get_item("piece_or"), 3000)
		p.inventory.add(items.get_item("baies"), 40)
		p.inventory.add(items.get_item("laine"), 20)
		print("== nations")
		check("5 nations voisines", dip.NATIONS.size() == 5)
		check("Cendres hostiles (%s)" % dip.status("cendres"), dip.status("cendres") == "Hostile")
		check("Sables neutres (%s)" % dip.status("sables"), dip.status("sables") == "Neutre")
		print("== présents")
		var r0: float = dip.rel("sylvae")
		var g0 := gold()
		check("présent d'or", dip.act("sylvae", "gift") and dip.rel("sylvae") == r0 + 6.0 and gold() == g0 - 50)
		check("un seul présent par jour : %s" % dip.block("sylvae", "like"), not dip.act("sylvae", "like"))
		dip.states.sylvae.gift_day = -1
		check("présent aimé (baies) +12", dip.act("sylvae", "like") and dip.rel("sylvae") == r0 + 18.0)
		print("== demande")
		dip.states.givre.request = ["laine", 12]
		var rg: float = dip.rel("givre")
		check("demande remplie : +15 et or", dip.act("givre", "request") and dip.rel("givre") == rg + 15.0 and p.inventory.count(items.get_item("laine")) == 8)
		print("== traités")
		var it = items.get_item("iron_ingot")
		var buy0: int = tr.buy_price(it)
		var sell0: int = tr.sell_price(it, 0)
		check("commerce refusé à relation 10 : %s" % dip.block("sables", "commerce"), not dip.act("sables", "commerce"))
		dip.states.sables.rel = 25.0
		check("traité de commerce", dip.act("sables", "commerce") and dip.has_treaty("sables", "commerce"))
		var buy1: int = tr.buy_price(it)
		var sell1: int = tr.sell_price(it, 0)
		check("prix du marchand : achat %d -> %d, vente %d -> %d" % [buy0, buy1, sell0, sell1], buy1 <= buy0 and sell1 >= sell0 and (buy1 < buy0 or sell1 > sell0))
		check("paix", dip.act("sables", "paix"))
		check("alliance refusée : %s" % dip.block("sables", "alliance"), not dip.act("sables", "alliance"))
		dip.states.sables.rel = 65.0
		check("alliance", dip.act("sables", "alliance") and dip.status("sables") == "Alliée")
		check("un pillard de moins par raid", dip.raid_reduction() == 1)
		print("== caravane et présent d'allié")
		var picks0 := get_nodes_in_group("pickups").size()
		dip.new_day(day + 5)
		day += 5
		check("caravane et présent livrés (%d objets au sol)" % (get_nodes_in_group("pickups").size() - picks0), get_nodes_in_group("pickups").size() >= picks0 + 4)
		print("== guerre")
		var rs: float = dip.rel("sylvae")
		check("déclarer la guerre à Karg", dip.act("karg", "war") and dip.at_war("karg") and dip.status("karg") == "En guerre")
		check("les autres nations désapprouvent (%d -> %d)" % [rs, dip.rel("sylvae")], dip.rel("sylvae") < rs)
		dip.states.cendres.treaties = ["paix"]   # les Cendres ne s'en mêlent pas pendant ce test
		var tries := 0
		while rm.raid.is_empty() and tries < 30:
			day += 1; tries += 1
			dip.new_day(day)
		check("l'armée de Karg marche sur le village : %s" % rm.raid.get("name", "-"), rm.raid.get("story", "") == "guerre_karg")
		start("warn")
	if later("warn", 1200):
		shot("01_guerre.png")
		rm.raid = {}
		var g1 := gold()
		for i in 3:
			rm.raid_ended.emit({"story": "guerre_karg"}, true, "")
		check("Karg capitule après 3 défaites (paix, relation %d)" % dip.rel("karg"), not dip.at_war("karg") and dip.has_treaty("karg", "paix"))
		print("== nation hostile")
		dip.states.cendres.treaties = []
		dip.states.cendres.rel = -60.0
		var tries := 0
		while not dip.at_war("cendres") and tries < 200:
			day += 1; tries += 1
			rm.raid = {"story": "x"}   # pas de raid pendant ce test
			dip.new_day(day)
		rm.raid = {}
		check("les Cendres finissent par déclarer la guerre (%d jours)" % tries, dip.at_war("cendres"))
		check("prix de la paix : %d or" % dip.peace_price("cendres"), dip.peace_price("cendres") == 300)
		check("paix achetée", dip.act("cendres", "peace") and not dip.at_war("cendres"))
		print("== panneau")
		dip.states.cendres.war = true
		dip.states.cendres.wins = 1
		hud.diplomacy_panel.open()
		start("panel")
	if later("panel", 800):
		check("panneau ouvert", hud.diplomacy_panel.visible)
		shot("02_panneau.png")
		var bx = hud.diplomacy_panel._box
		print("box ", bx.size)
		for c in bx.get_children():
			print("  ", c.get_class(), " ", c.size, " min ", c.get_combined_minimum_size())
		var row = bx.get_child(3)
		for c in row.get_child(0).get_children():
			print("    ", c.get_class(), " ", c.get_combined_minimum_size())
		hud.diplomacy_panel.close()
		print("== sauvegarde")
		var d: Dictionary = dip.export_state()
		var json = JSON.parse_string(JSON.stringify(d))
		var r_saved: float = dip.rel("sables")
		dip.states.sables.treaties = []
		dip.states.sables.rel = 0.0
		dip.import_state(json)
		check("traités rechargés : %s" % [dip.states.sables.treaties], dip.has_treaty("sables", "alliance") and is_equal_approx(dip.rel("sables"), r_saved))
		check("guerre rechargée", dip.at_war("cendres") and int(dip.states.cendres.wins) == 1)
		print("RÉSULTAT : " + ("tout est bon" if ok else "ÉCHECS"))
		return true
	return f > 20000
