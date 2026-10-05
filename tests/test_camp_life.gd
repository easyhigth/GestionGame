extends SceneTree
## Le camp et l'aventure s'aident : étape « drapeau » du guide (et « Passer »), retour au camp (carte, pierre de
## rappel), zone refuge (pas de monstres la nuit, vie +3/s), faveurs du royaume et trophées des boss.
## Captures cl_XX_nom.png.
var f := 0
var p; var w; var items; var gd; var k
var ok := true
var step := 0
var wait := 0
var spot := Vector2i.ZERO
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/cl_"

func _initialize():
	var h = load("res://scripts/hero/hero_profile.gd").new()
	h.hero_name = "Selka"
	h.race = load("res://data/races/humain.tres")
	h.hero_class = load("res://data/classes/guerrier.tres")
	h.job = load("res://data/jobs/chasseur.tres")
	h.skill = load("res://data/skills/vorace.tres")
	root.get_node("GameState").hero = h
	root.get_node("GameState").world_seed = 4242
	root.get_node("GameState").bare_start = true
	change_scene_to_file("res://scenes/main.tscn")

func check(name: String, cond: bool) -> void:
	print(("  OK  " if cond else "  ÉCHEC  ") + name)
	ok = ok and cond

func shot(n):
	root.get_viewport().get_texture().get_image().save_png(out + n)
	print("saved ", n)

func it(id: String):
	return items.get_item(id)

func _process(_d) -> bool:
	f += 1
	if p:
		p._invulnerable_left = 5.0
	if wait > 0:
		wait -= 1
		return false
	if f < 40:
		return false
	match step:
		0:
			p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
			gd = get_first_node_in_group("guide"); k = get_first_node_in_group("kingdom")
			get_first_node_in_group("raids").enabled = false
			for e in get_nodes_in_group("enemy_units"): e.queue_free()
			# le guide : « passer » ne bloque jamais, et l'étape du drapeau est en tête du village
			var s0: int = gd.step
			gd.skip_step()
			check("« Passer cette étape » : objectif suivant (%d -> %d)" % [s0, gd.step], gd.step == s0 + 1)
			gd.step = gd.STEPS.map(func(s): return s[0]).find("drapeau")
			gd.progress = 0
			gd._refresh()
			check("étape du guide : %s" % gd.STEPS[gd.step][1], gd.current_id() == "drapeau")
			# planter le drapeau près d'ici
			spot = w.cell_at(p.global_position) + Vector2i(0, 6)
			w.build.place_furniture(spot, w.terrain_height(spot), it(w.FLAG_ID), 0)
			p.inventory.remove(it(w.FLAG_ID), 1)
			gd._check_state()
			check("drapeau planté : l'étape du guide est validée (%s)" % gd.current_id(), gd.current_id() == "reserve")
			step = 1; wait = 5
		1:
			# zone refuge : pas de monstres la nuit, et on récupère plus vite
			var dc = get_first_node_in_group("day_cycle")
			check("la zone du camp est un refuge la nuit", dc.near_light(w.cell_center(spot + Vector2i(3, 3))))
			p.global_position = w.cell_center(spot + Vector2i(0, 2))
			step = 2; wait = 40
		2:
			check("le héros est au camp", p.in_camp)
			var regen_in: float = p.health.regen_per_second
			# loin du camp
			p.global_position = w.cell_center(spot + Vector2i(0, 120))
			step = 3; wait = 40
			set_meta("regen_in", regen_in)
		3:
			check("hors du camp", not p.in_camp)
			var regen_in: float = get_meta("regen_in")
			check("au camp on récupère plus vite (%.1f contre %.1f /s)" % [regen_in, p.health.regen_per_second], regen_in >= p.health.regen_per_second + 2.9)
			# pierre de rappel depuis le bout du monde
			p.inventory.add(it("pierre_rappel"), 1)
			var inv = get_first_node_in_group("inventory_ui")
			p.open_inventory.emit(p)
			inv._use_item(it("pierre_rappel"))
			step = 4; wait = 20
		4:
			var d: float = p.global_position.distance_to(w.home_center())
			check("pierre de rappel : retour au camp (%.0f m du drapeau)" % d, d < 6.0)
			check("la pierre se brise", p.inventory.count(it("pierre_rappel")) == 0)
			# voyage au camp depuis la carte
			p.global_position = w.cell_center(spot + Vector2i(80, 0))
			var wm = null
			for n in root.find_children("*", "Control", true, false):
				if n.has_method("_travel") and n.has_method("_travel_points"):
					wm = n
			wm._travel(-2)
			step = 5; wait = 20
		5:
			check("carte : voyage au camp", p.global_position.distance_to(w.home_center()) < 6.0)
			# faveurs du royaume : cadeaux du matin selon le rang
			k.rank = 3
			var pain0: int = p.inventory.count(it("pain"))
			k._on_morning(2)
			check("faveurs (Bourg) : pain, potion de soin, pierre de rappel", p.inventory.count(it("pain")) == pain0 + 2 and p.inventory.count(it("potion_soin")) >= 1 and p.inventory.count(it("pierre_rappel")) == 1)
			k.rank = 4
			check("Garde royale (Ville) : attaque +%d" % roundi(k.hero_bonus("attack")), k.hero_bonus("attack") >= 8.0)
			# trophées : un boss vaincu rend le village fier et attire les voyageurs
			var fav = load("res://scripts/kingdom/kingdom_favors.gd")
			var t0: int = fav.trophies(w)
			for z in w.zones:
				if not z.get("cleared", false):
					z.cleared = true
					break
			check("trophée : %d → %d, bonheur +%d" % [t0, fav.trophies(w), roundi(fav.trophy_happiness(w))], fav.trophies(w) == t0 + 1 and fav.trophy_happiness(w) >= 3.0)
			check("les voyageurs viennent plus souvent (×%.2f)" % fav.arrival_mult(w), fav.arrival_mult(w) < 1.0)
			var kp = null
			for n in root.find_children("*", "Control", true, false):
				if n.has_method("_page_overview"):
					kp = n
			if kp and kp.has_method("open"):
				kp.open()
			step = 6; wait = 20
		6:
			shot("01_faveurs.png")
			# passer tout le tutoriel
			gd._on_skip_all()
			check("« Passer tout le tutoriel » demande confirmation", not gd.is_done())
			gd._on_skip_all()
			check("deuxième clic : tutoriel passé", gd.is_done())
			# à la création d'un monde : la case « Tutoriel »
			var opt = load("res://scenes/ui/world_options_panel.gd").new()
			opt.creating = true
			root.add_child(opt)
			check("création du monde : case « Tutoriel » (cochée par défaut)", opt._checks.has("tutorial") and opt._checks.tutorial.button_pressed)
			opt.queue_free()
			print("RÉSULTAT : ", "tout est bon" if ok else "échec")
			return true
	return false
