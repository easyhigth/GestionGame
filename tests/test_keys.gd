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
		check("potion : R par défaut (%s)" % root.get_node("SaveGame").options.keys, KeyBindings.key_text("potion") == "R")
		check("manger : X, carte : M, journal : J, diplomatie : N", KeyBindings.key_text("eat") == "X" and KeyBindings.key_text("world_map") == "M"
			and KeyBindings.key_text("journal") == "J" and KeyBindings.key_text("diplomacy") == "N")
		check("texte avec touches : %s" % KeyBindings.fmt("Se mange ({eat}) · {place_click} : poser, puis {place_click}"),
			KeyBindings.fmt("Se mange ({eat}) · {place_click} : poser, puis {place_click}") == "Se mange (X) · Clic droit : poser, puis clic droit")
		check("équipement : E, agir : F, viser : Tab (%s / %s / %s)" % [KeyBindings.key_text("inventory"), KeyBindings.key_text("interact"), KeyBindings.key_text("lock_on")],
			KeyBindings.key_text("inventory") == "E" and KeyBindings.key_text("interact") == "F" and KeyBindings.key_text("lock_on") == "Tab")
		# aucune touche du clavier en double (hors déplacements et chiffres)
		var seen := {}
		var dup := []
		for r in KeyBindings.REBINDABLE:
			for e in InputMap.action_get_events(r[0]):
				if e is InputEventKey:
					var code: int = e.physical_keycode if e.physical_keycode != KEY_NONE else e.keycode
					if seen.has(code):
						dup.append("%s/%s" % [seen[code], r[0]])
					seen[code] = r[0]
		check("aucune touche en double %s" % str(dup), dup.is_empty())
		cp = load("res://scenes/ui/controls_panel.gd").new()
		hud.add_child(cp)
		start("a0")
	if later("a0", 300):
		cp._show_page(0)
		start("a1")
	if later("a1", 500):
		shot("00_plan_clavier.png")
		check("plan du clavier affiché", not cp._list.find_children("*", "KeyboardMap", true, false).is_empty())
		cp._show_page(2)
		start("a2")
	if later("a2", 400):
		shot("00b_combat.png")
		cp._show_page(3)
		start("a3")
	if later("a3", 400):
		shot("00c_recolter.png")
		cp._show_page(4)
		start("a4")
	if later("a4", 400):
		shot("00d_menus.png")
		cp._show_page(cp.PAGES.size())
		start("a")
	if later("a", 600):
		shot("01_personnaliser.png")
		cp._listening = "potion"
		cp._input(key_event(KEY_N))
		var sg = root.get_node("SaveGame")
		check("potion -> N (gardé dans les options : %s)" % sg.options.keys, int(sg.options.keys.get("potion", 0)) == KEY_N)
		check("la touche N déclenche « potion »", key_event(KEY_N).is_action("potion") and not key_event(KEY_R).is_action("potion"))
		check("conflit signalé (N sert aussi à la diplomatie : %s)" % cp._note.text, cp._note.text.contains("Diplomatie"))
		cp._listening = "eat"
		cp._input(key_event(KEY_ESCAPE))
		check("Échap annule", not sg.options.keys.has("eat") and KeyBindings.key_text("eat") == "X")
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
		check("l'onglet « Combattre » montre la touche choisie (N)", found)
		cp.close()
		print("== aide-mémoire F1")
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
		print("== objet en main : C, clic droit, molette")
		w = get_first_node_in_group("world"); items = root.get_node("Items")
		p.inventory.add(items.get_item("bloc_planches"), 6)
		p.inventory.add(items.get_item("bloc_rondins"), 3)
		p.hand.selected = ""
		p.hand.toggle()
		check("C : un objet en main (%s)" % p.hand.selected, p.hand.selected != "")
		p.hand.selected = "bloc_planches"
		var n0: int = p.inventory.count(items.get_item("bloc_planches"))
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_RIGHT
		mb.pressed = true
		p._input(mb)
		check("clic droit avec un bloc en main : posé (%d -> %d)" % [n0, p.inventory.count(items.get_item("bloc_planches"))], p.inventory.count(items.get_item("bloc_planches")) == n0 - 1)
		check("pas de garde pendant ce temps", not p.blocking)
		var before: String = p.hand.selected
		var wh := InputEventMouseButton.new()
		wh.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wh.pressed = true
		var z0: float = p.camera_zoom
		p._camera_input(wh)
		check("molette avec un objet en main : objet suivant (%s -> %s), pas de zoom" % [before, p.hand.selected], p.hand.selected != before and is_equal_approx(z0, p.camera_zoom))
		p.hand.toggle()
		check("C encore : mains nues", p.hand.selected == "")
		p._camera_input(wh)
		check("molette à mains nues : zoom (%.2f -> %.2f)" % [z0, p.camera_zoom], not is_equal_approx(z0, p.camera_zoom))
		print("== invite à l'écran près d'un habitant")
		var v = get_first_node_in_group("villagers")
		p.global_position = v.global_position + Vector3(1.0, 0, 0)
		start("d")
	if later("d", 500):
		var hint: String = p.interact_hint()
		check("invite : %s" % hint, hint != "")
		check("invite affichée à l'écran : [%s] %s" % [hud._prompt_key.text, hud._prompt_text.text], hud._prompt.visible and hud._prompt_key.text == "F")
		hud.keys_help.toggle()
		start("e")
	if later("e", 400):
		shot("03_invite.png")
		hud.keys_help.toggle()
		print("RÉSULTAT : " + ("tout est bon" if ok else "ÉCHECS"))
		return true
	return f > 30000
