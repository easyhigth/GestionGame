extends SceneTree
var f := 0
var p; var w; var items; var hud; var inv_ui; var pause; var steps := []; var idx := 0
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/ui_"

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


func close_all() -> void:
	for c in [hud.kingdom_panel, hud.achievements_panel, hud.journal, hud.map_ui, hud.talent_ui, hud.diplomacy_panel, hud.heraldry_panel]:
		if c and c.visible and c.has_method("close"):
			c.close()
	if inv_ui and inv_ui.visible:
		inv_ui.close()
	if pause and pause.visible:
		pause.close()
	if hud.story_dialog.visible:
		hud.story_dialog._close("")
	get_root_paused_off()

func get_root_paused_off() -> void:
	paused = false
	p.ui_open = false

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p: p._invulnerable_left = 5.0
	if f == 10:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		hud = get_first_node_in_group("hud")
		get_first_node_in_group("raids").enabled = false
		get_first_node_in_group("weather").set_kind("clair")
		get_first_node_in_group("day_cycle").hour = 10.0
		var ev = get_first_node_in_group("world_events")
		if ev: ev.next_day = 999
		for c in root.find_children("*", "Control", true, false):
			if c.get_script() and c.get_script().resource_path.ends_with("inventory_ui.gd"):
				inv_ui = c
			if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"):
				pause = c
		check("le thème du royaume est installé", ThemeDB.get_default_theme().get_meta("royaume", false))
		check("police des titres : Almendra", UiTheme.font("title").base_font.resource_path.ends_with("Almendra-Bold.ttf"))
		check("police du texte : Alegreya Sans", ThemeDB.get_default_theme().default_font.base_font.resource_path.ends_with("AlegreyaSans-Medium.ttf"))
		var MK = load("res://scenes/ui/menu_kit.gd")
		var ACH = load("res://scripts/world/achievements.gd")
		var AP = load("res://scenes/ui/achievements_panel.gd")
		var missing := []
		for id in ACH.BESTIARY:
			if MK.portrait_texture(id) == null: missing.append(id)
		for b in AP.boss_entries():
			if MK.portrait_texture(b[0]) == null: missing.append(b[0])
		check("un portrait pour chaque créature et chaque boss %s" % str(missing), missing.is_empty())
		for n in ["heart", "sword", "shield", "magic", "food", "coin", "crown", "skull", "scroll", "star", "book", "compass"]:
			if UiTheme.tex("icon_" + n) == null: missing.append(n)
		check("icônes présentes", missing.is_empty())
		p.inventory.add(items.get_item("iron_sword"), 1)
		p.inventory.add(items.get_item("wood"), 24)
		p.inventory.add(items.get_item("piece_or"), 120)
		var ach = get_first_node_in_group("achievements")
		for id in ["loup", "slime_bleu", "gobelin_pillard", "sanglier", "araignee", "squelette"]:
			ach.kills[id] = 3
		steps = [
			["hud", func(): pass],
			["pause", func(): pause.open()],
			["inventaire", func(): p.open_inventory.emit(p)],
			["royaume", func(): hud.kingdom_panel.open()],
			["bestiaire", func():
				hud.achievements_panel._tab = "bestiaire"
				hud.achievements_panel._selected = "gobelin_pillard"
				hud.achievements_panel.open()],
			["succes", func(): hud.achievements_panel.open("succes")],
			["journal", func(): hud.journal.open()],
			["carte", func(): hud.map_ui.open()],
			["talents", func(): hud.talent_ui.open()],
			["dialogue", func(): hud.story_dialog.open_custom("test", {"pages": [["hero", "Le royaume s'éveille. Les voix du cristal murmurent au loin…"]], "choices": []}, null, func(_c): pass)],
		]
		start("s")
	if has_meta("t"):
		return _end_shots()
	if later("s", 900):
		var st: Array = steps[idx]
		var panel_open: bool = idx == 0 or p.ui_open or get_root_paused()
		if idx > 0:
			check("%s : ouvert" % st[0], panel_open)
		shot("%02d_%s.png" % [idx + 1, st[0]])
		close_all()
		idx += 1
		if idx >= steps.size():
			p = null
			change_scene_to_file("res://scenes/ui/title_screen.tscn")
			start("t")
			return false
		remove_meta("s"); remove_meta("s_done")
		steps[idx][1].call()
		start("s")
	return false

func get_root_paused() -> bool:
	return paused


func _end_shots() -> bool:
	if later("t", 3000):
		shot("11_titre.png")
		change_scene_to_file("res://scenes/ui/character_creator.tscn")
		start("c")
	if later("c", 2500):
		shot("12_creation.png")
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	return false

