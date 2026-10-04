extends SceneTree
## Le sac : E l'ouvre (F ne sert qu'à agir), tri (type, nom, nombre, rareté), 999 au plus par case,
## et la liste ne remonte plus toute seule quand le sac change. Captures bg_XX_nom.png.
var f := 0
var p; var items; var inv
var ok := true
var step := 0
var wait := 0
var keep := 0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/bg_"

func _initialize():
	var h = load("res://scripts/hero/hero_profile.gd").new()
	h.hero_name = "Selka"
	h.race = load("res://data/races/humain.tres")
	h.hero_class = load("res://data/classes/guerrier.tres")
	h.job = load("res://data/jobs/chasseur.tres")
	h.skill = load("res://data/skills/vorace.tres")
	root.get_node("GameState").hero = h
	root.get_node("GameState").world_seed = 4242
	change_scene_to_file("res://scenes/main.tscn")

func check(name: String, cond: bool) -> void:
	print(("  OK  " if cond else "  ÉCHEC  ") + name)
	ok = ok and cond

func shot(n):
	root.get_viewport().get_texture().get_image().save_png(out + n)
	print("saved ", n)

func press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	p._unhandled_input(ev)

func _process(_d) -> bool:
	f += 1
	if wait > 0:
		wait -= 1
		return false
	if f < 40:
		return false
	match step:
		0:
			p = get_first_node_in_group("player"); items = root.get_node("Items")
			inv = get_first_node_in_group("inventory_ui")
			get_first_node_in_group("raids").enabled = false
			for e in get_nodes_in_group("enemy_units"): e.queue_free()
			for v in get_nodes_in_group("villagers"): v.queue_free()
			for t in get_nodes_in_group("townsfolk"): t.queue_free()
			root.get_node("SaveGame").options.bag_sort = "arrivee"
			# 999 au plus par case
			p.inventory.entries.clear()
			var wood = items.get_item("wood")
			p.inventory.add(wood, 1500)
			var counts: Array = p.inventory.entries.map(func(e): return e.count)
			check("1500 bois : 999 + 501 (%s)" % str(counts), counts == [999, 501])
			check("le bois s'empilait par %d, maintenant par %d" % [wood.max_stack, wood.stack_size()], wood.stack_size() == 999)
			var sword = items.get_item("sword_wood")
			p.inventory.add(sword, 2)
			check("une arme ne s'empile pas", p.inventory.entries.filter(func(e): return e.item == sword).size() == 2)
			# un sac bien rempli
			var n: int = 0
			for id in items.items:
				var it = items.items[id]
				if n < 70 and it.base_id == "":
					p.inventory.add(it, 1 + (n * 37) % 300 if it.stack_size() > 1 else 1)
					n += 1
			# F sans rien autour : ne fait rien ; E : l'équipement
			press("interact")
			step = 1; wait = 5
		1:
			check("F sans rien autour n'ouvre pas le sac", not inv.visible)
			press("inventory")
			step = 2; wait = 15
		2:
			check("E ouvre l'équipement", inv.visible)
			# trier
			inv.set_bag_sort("nom")
			var names: Array = p.inventory.sorted("nom").map(func(e): return e.item.display_name.to_lower())
			var sorted_names := names.duplicate(); sorted_names.sort()
			check("tri par nom", names == sorted_names)
			var fam: Array = p.inventory.sorted("type").map(func(e): return e.item.family())
			var sf := fam.duplicate(); sf.sort()
			check("tri par type : équipement d'abord (%d familles)" % fam.size(), fam == sf and fam[0] == 0)
			var cnt: Array = p.inventory.sorted("nombre").map(func(e): return e.count)
			check("tri par nombre : %d en tête" % cnt[0], cnt[0] == 999)
			var rar: Array = p.inventory.sorted("rarete").map(func(e): return e.item.rarity)
			check("tri par rareté", rar[0] >= rar[rar.size() - 1])
			check("tri gardé dans les options", root.get_node("SaveGame").options.bag_sort == "nom")
			check("l'affichage suit le tri", inv._sort_buttons["nom"].button_pressed and not inv._sort_buttons["arrivee"].button_pressed)
			step = 3; wait = 10
		3:
			shot("01_tri_nom.png")
			inv.set_bag_sort("type")
			step = 4; wait = 10
		4:
			shot("02_tri_type.png")
			# on descend dans le sac...
			var sb: ScrollContainer = inv._bag_scroll
			sb.scroll_vertical = 10000
			step = 5; wait = 5
		5:
			keep = inv._bag_scroll.scroll_vertical
			check("le sac défile (%d px)" % keep, keep > 100)
			# ...un objet arrive, on survole, on équipe : la liste reste où elle est
			p.inventory.add(items.get_item("stone"), 3)
			inv._show_info(items.get_item("wood"))
			step = 6; wait = 10
		6:
			check("objet ramassé : le sac ne remonte pas (%d -> %d)" % [keep, inv._bag_scroll.scroll_vertical], absi(inv._bag_scroll.scroll_vertical - keep) < 60)
			inv._use_item(items.get_item("sword_wood"))
			step = 7; wait = 10
		7:
			check("arme équipée : le sac ne remonte pas (%d -> %d)" % [keep, inv._bag_scroll.scroll_vertical], absi(inv._bag_scroll.scroll_vertical - keep) < 60)
			shot("03_bas_du_sac.png")
			press("inventory")
			step = 8; wait = 5
		8:
			inv._unhandled_input(_ev("inventory"))
			check("E referme", not inv.visible)
			root.get_node("SaveGame").options.bag_sort = "arrivee"
			root.get_node("SaveGame").save_options()
			print("RÉSULTAT : ", "tout est bon" if ok else "échec")
			return true
	return false

func _ev(action: String) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	return ev
