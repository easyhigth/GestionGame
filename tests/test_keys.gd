extends SceneTree
var f := 0
var p; var w; var items; var dip; var hud; var rm; var tr
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/ky_"

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

var cp

func key_event(physical: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = physical as Key
	e.keycode = physical as Key
	e.pressed = true
	return e

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p: p._invulnerable_left = 5.0
	if f == 10:
		p = get_first_node_in_group("player"); hud = get_first_node_in_group("hud")
		get_first_node_in_group("raids").enabled = false
		var sg = root.get_node("SaveGame")
		print("== touches")
		check("potion : Z par défaut (%s)" % root.get_node("SaveGame").options.keys, KeyBindings.key_text("potion") == "Z" or KeyBindings.key_text("potion") == "W")
		cp = load("res://scenes/ui/controls_panel.gd").new()
		hud.add_child(cp)
		start("a0")
	if later("a0", 300):
		cp._show_page(cp.PAGES.size())
		start("a")
	if later("a", 600):
		shot("01_personnaliser.png")
		cp._listening = "potion"
		cp._input(key_event(KEY_N))
		var sg = root.get_node("SaveGame")
		check("potion -> N (gardé dans les options : %s)" % sg.options.keys, int(sg.options.keys.get("potion", 0)) == KEY_N)
		check("la touche N déclenche « potion »", key_event(KEY_N).is_action("potion") and not key_event(KEY_Z).is_action("potion"))
		check("conflit signalé (N sert aussi aux cartes ? %s)" % cp._note.text, cp._note.text.contains("N"))
		cp._listening = "eat"
		cp._input(key_event(KEY_ESCAPE))
		check("Échap annule", not sg.options.keys.has("eat") and KeyBindings.key_text("eat") == "H")
		cp._listening = "journal"
		cp._input(key_event(KEY_I))
		check("conflit : I est aussi l'inventaire (%s)" % cp._note.text, cp._note.text.contains("Inventaire"))
		print("== les touches restent après un redémarrage")
		sg.save_options()
		KeyBindings.reset()
		check("remis à zéro en mémoire", KeyBindings.key_text("potion") != "N")
		sg.load_options()
		check("rechargées depuis les options : potion %s, journal %s" % [KeyBindings.key_text("potion"), KeyBindings.key_text("journal")], KeyBindings.key_text("potion") == "N" and KeyBindings.key_text("journal") == "I")
		cp._show_page(2)
		var found := false
		for line in cp._list.get_children():
			for c in line.find_children("*", "Label", true, false):
				if c.text == "N":
					found = true
		check("l'onglet « Monde et royaume » montre la touche choisie (N)", found)
		cp.close()
		print("== aide-mémoire F2")
		hud.keys_help.toggle()
		start("b")
	if later("b", 500):
		check("aide-mémoire affiché", hud.keys_help.visible)
		shot("02_aide_memoire.png")
		hud.keys_help.toggle()
		print("== options")
		var sg = root.get_node("SaveGame")
		sg.options.show_fps = true
		sg.options.graphics = 0
		sg.apply_options()
		start("c")
	if later("c", 600):
		check("images par seconde affichées : %s" % hud._fps_label.text, hud._fps_label.visible and hud._fps_label.text.ends_with("IPS"))
		check("qualité basse appliquée", get_first_node_in_group("world").view_distance == 3.0)
		var sg = root.get_node("SaveGame")
		sg.options.show_fps = false
		sg.options.graphics = 2
		KeyBindings.reset()
		sg.options.keys = {}
		sg.save_options()
		sg.apply_options()
		check("touches par défaut remises", KeyBindings.key_text("potion") != "N")
		print("RÉSULTAT : " + ("tout est bon" if ok else "ÉCHECS"))
		return true
	return f > 30000
