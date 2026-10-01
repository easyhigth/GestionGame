extends SceneTree
var f := 0
var p; var w; var items; var dip; var hud; var rm; var tr
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/ac_"

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
var ach

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p: p._invulnerable_left = 5.0
	if f == 10:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		hud = get_first_node_in_group("hud"); rm = get_first_node_in_group("raids")
		ach = get_first_node_in_group("achievements")
		rm.enabled = false
		print("== succès")
		print("   %d succès" % ach.defs().size())
		check("plus de 100 succès", ach.defs().size() >= 100)
		var ids := {}
		for d in ach.defs():
			ids[d.id] = true
		check("identifiants uniques", ids.size() == ach.defs().size())
		ach.check_all()
		var start_done: int = ach.done.size()
		var e = load("res://scenes/enemies/enemy.tscn").instantiate()
		e.data = load("res://data/enemies/loup.tres")
		for i in 12:
			ach.on_kill(e)
		e.free()
		p.level = 10
		p.inventory.add(items.get_item("piece_or"), 1200)
		var news: Array = ach.check_all()
		print("   débloqués : ", news)
		check("10 victoires, niveau 10, 1 000 or", news.has("kills_10") and news.has("level_10") and news.has("gold_1000"))
		check("bestiaire : loup connu (12 victoires)", ach.bestiary_entry("loup").known and ach.bestiary_entry("loup").kills == 12)
		var be: Dictionary = ach.bestiary_entry("loup")
		print("   fiche : ", be)
		check("fiche avec régions et butin", not be.regions.is_empty() and not be.loot.is_empty())
		for r in ach.BOSSES:
			p.souls[r] = {}
		ach.note("vault", 5)
		ach.note("gardien")
		ach.note("event_tournoi")
		news = ach.check_all()
		check("8 boss : « Fléau des boss » (%d points)" % ach.points(), news.has("boss_all") and ach.done.has("vault_5"))
		check("titres : %s" % [ach.titles()], ach.titles().has("Aventurier") and ach.titles().has("Tueur de boss"))
		ach.cycle_title()
		check("titre choisi : %s" % ach.title, ach.title == "Aventurier")
		check("aura bleue débloquée (%d points)" % ach.points(), ach.auras().size() >= 1)
		ach.cycle_aura()
		check("aura active", p.get_node_or_null("Aura") != null)
		start("hud")
	if later("hud", 800):
		check("titre dans l'interface : %s" % hud._xp_text.text, hud._xp_text.text.contains("Aventurier"))
		shot("01_aura.png")
		hud.achievements_panel.open("succes")
		start("p1")
	if later("p1", 700):
		shot("02_succes.png")
		hud.achievements_panel._tab = "bestiaire"
		hud.achievements_panel._selected = "loup"
		hud.achievements_panel._refresh()
		start("p2")
	if later("p2", 700):
		shot("03_bestiaire.png")
		hud.achievements_panel.close()
		var d = JSON.parse_string(JSON.stringify(ach.export_state()))
		var n: int = ach.done.size()
		ach.done = {}
		ach.kills = {}
		ach.import_state(d)
		check("rechargé : %d succès, loups %d" % [ach.done.size(), int(ach.kills.get("loup", 0))], ach.done.size() == n and int(ach.kills.get("loup", 0)) == 12 and ach.title == "Aventurier")
		print("RÉSULTAT : " + ("tout est bon" if ok else "ÉCHECS"))
		return true
	return f > 20000
