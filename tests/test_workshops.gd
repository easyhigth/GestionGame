extends SceneTree
## Artisanat par ateliers : sur soi l'essentiel, chaque atelier (E devant) son propre menu ; recettes
## découvertes en ramassant les matériaux ; clic droit sur un objet : ce qu'on peut en faire ; « comment
## l'obtenir ? » ; objet épinglé avec sa liste de courses à l'écran ; blocs choisis par forme puis matière.
## Captures ws_XX_nom.png.
var f := 0
var p; var w; var items; var inv; var ws
var ok := true
var step := 0
var wait := 0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/ws_"
var notes := []

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

func it(id: String):
	return items.get_item(id)

func place(id: String, off: Vector3) -> void:
	var c: Vector2i = w.cell_at(p.global_position + off)
	w.build.place_furniture(c, w.terrain_height(c), it(id), 0)

## Textes des lignes de recettes affichées.
func shown_names() -> Array:
	var outl := []
	for c in inv._recipes.get_children():
		if c is Label:
			outl.append((c as Label).text)
		for l in c.find_children("*", "Label", true, false):
			outl.append((l as Label).text)
	return outl

func _process(_d) -> bool:
	f += 1
	if wait > 0:
		wait -= 1
		return false
	if f < 40:
		return false
	match step:
		0:
			p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
			inv = get_first_node_in_group("inventory_ui")
			ws = load("res://scripts/items/workshops.gd")
			get_first_node_in_group("raids").enabled = false
			get_first_node_in_group("day_cycle").hour = 11.0
			for e in get_nodes_in_group("enemy_units"): e.queue_free()
			for v in get_nodes_in_group("villagers"): v.queue_free()
			p.notify.connect(func(t): notes.append(t))
			# un héros neuf : il ne connaît encore rien
			p.inventory.entries.clear()
			p.seen_items = {}
			var r_etabli = null
			for r in items.recipes:
				if r.result and r.result.id == "etabli":
					r_etabli = r
			check("l'établi est inconnu sans bois", not ws.is_known(p, r_etabli))
			p.inventory.add(it("wood"), 12)
			p.inventory.add(it("stone"), 8)
			p.inventory.add(it("fiber"), 4)
			check("ramasser du bois fait découvrir l'établi", ws.is_known(p, r_etabli))
			p.open_inventory.emit(p)
			step = 1; wait = 15
		1:
			check("message « nouvelles recettes » (%s)" % str(notes), notes.any(func(t): return "nouvelle recette" in t.to_lower() or "nouvelles recettes" in t))
			var tabs: Array = inv._tab_list()
			print("   onglets sur soi : ", tabs)
			check("sur soi : l'essentiel, sans forge ni armurerie", not tabs.has("Forge") and not tabs.has("Armurerie") and tabs.has("Mobilier") and tabs.has("Carnet"))
			inv._cat = "Mobilier"
			inv._refresh()
			var names := shown_names()
			check("l'établi se fabrique sur soi", names.any(func(t): return t.begins_with("Établi")))
			check("pas d'enclume sur soi", not names.any(func(t): return t.begins_with("Enclume")))
			shot("01_sur_soi.png")
			inv.close()
			# un établi devant le héros : E ouvre son atelier
			var fwd := Vector3(-sin(p.cam_yaw), 0, -cos(p.cam_yaw))
			place("etabli", fwd * 1.4)
			check("atelier à portée : établi (%s)" % ws.station_near(p), ws.station_near(p) == "etabli")
			check("invite : %s" % p.interact_hint(), "Établi" in p.interact_hint())
			var ev := InputEventAction.new()
			ev.action = "interact"
			ev.pressed = true
			p._unhandled_input(ev)
			step = 2; wait = 15
		2:
			check("E ouvre l'atelier de l'établi", inv.visible and inv._mode == "etabli")
			var tabs2: Array = inv._tab_list()
			print("   onglets de l'établi : ", tabs2)
			check("l'établi : outils, meubles, armurerie", tabs2.has("Outils") and tabs2.has("Mobilier") and tabs2.has("Armurerie"))
			inv._cat = "Outils"
			inv._refresh()
			check("hache en pierre au menu de l'établi", shown_names().any(func(t): return t.begins_with("Hache en pierre")))
			shot("02_etabli.png")
			# fabriquer à l'atelier
			for r in items.recipes:
				if r.result and r.result.id == "pioche_pierre":
					inv._craft(r)
			check("pioche en pierre fabriquée à l'établi", p.inventory.count(it("pioche_pierre")) == 1)
			# clic droit sur le bois : que faire avec ?
			inv.show_uses(it("wood"))
			step = 3; wait = 6
		3:
			check("que faire avec du bois : des recettes (%d)" % ws.uses_of(p, it("wood")).size(), ws.uses_of(p, it("wood")).size() >= 5 and inv._recipes.get_child_count() > 3)
			shot("03_que_faire_avec.png")
			inv.show_source(it("iron_ingot"))
			step = 4; wait = 6
		4:
			var src: Array = ws.sources_of(it("iron_ingot"))
			print("   lingot de fer : ", src)
			check("comment obtenir un lingot de fer : au four", src.any(func(t): return "four" in t))
			var ore: Array = ws.sources_of(it("iron_ore"))
			print("   minerai de fer : ", ore)
			check("le minerai de fer : sur les filons", ore.any(func(t): return "filons de fer" in t))
			shot("04_comment_obtenir.png")
			# épingler la pioche en fer : liste de courses à l'écran
			p.toggle_pin("pioche_fer")
			inv.close()
			step = 5; wait = 15
		5:
			var pins = get_first_node_in_group("craft_pins")
			check("liste de courses affichée", pins and pins.is_visible_in_tree())
			var txt := ""
			for l in pins.find_children("*", "RichTextLabel", true, false):
				txt += (l as RichTextLabel).get_parsed_text()
			print("   épingle : ", txt)
			check("elle compte les lingots (%s)" % txt, "Lingot de fer 0/" in txt)
			p.inventory.add(it("iron_ingot"), 2)
			pins.refresh()
			txt = ""
			for l in pins.find_children("*", "RichTextLabel", true, false):
				txt += (l as RichTextLabel).get_parsed_text()
			check("tout réuni : elle dit où aller (%s)" % txt, "Prêt" in txt or "enclume" in txt)
			shot("05_epingle.png")
			# table du tailleur : forme puis matière
			p.inventory.add(it("granite"), 12)
			var fwd := Vector3(-sin(p.cam_yaw), 0, -cos(p.cam_yaw))
			place("table_tailleur", fwd * 1.4 + fwd.cross(Vector3.UP) * 1.2)
			inv.open_station("table_tailleur")
			inv._cat = "Construction"
			inv._shape = "escalier"
			inv._mat_id = "granite"
			inv._refresh()
			step = 6; wait = 6
		6:
			var names := shown_names()
			check("forme puis matière : escaliers de granite", names.any(func(t): return t.begins_with("Escalier") and "granite" in t.to_lower()))
			check("pas des centaines de lignes (%d)" % inv._recipes.get_child_count(), inv._recipes.get_child_count() < 30)
			shot("06_forme_matiere.png")
			# l'enclume : des recettes encore inconnues
			inv.open_station("enclume")
			inv._cat = "Légendaire"
			inv._refresh()
			step = 7; wait = 6
		7:
			print("   enclume : ", inv._mode, " ", inv._cat, " vis=", inv.visible, " n=", inv._recipes.get_child_count(), " ", ws.recipes_at("enclume").filter(func(r): return r.category == "Légendaire").size(), " ", shown_names())
			check("enclume : recettes inconnues signalées", shown_names().any(func(t): return "inconnue" in t))
			shot("07_enclume.png")
			inv.close()
			print("RÉSULTAT : ", "tout est bon" if ok else "échec")
			return true
	return false
