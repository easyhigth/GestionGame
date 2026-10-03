extends SceneTree
var f := 0
var p; var w; var items; var hud; var cities; var idx := 0; var cam: Camera3D
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/ci_"

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
var con; var tt; var foes0 := 0
var h0 := 0.0
var c0 := Vector2i.ZERO

func foes_near(r: float) -> Array:
	return get_nodes_in_group("enemy_units").filter(func(e): return is_instance_valid(e) and e.is_alive() and e.global_position.distance_to(p.global_position) < r)

func summon(n: int) -> void:
	for i in n:
		var e = load("res://scenes/enemies/enemy.tscn").instantiate()
		e.data = load("res://data/enemies/squelette.tres")
		e.level = 5
		w.add_child(e)
		var a := TAU * i / n
		var at: Vector3 = p.global_position + Vector3(cos(a), 0, sin(a)) * (4.0 + (i % 3) * 2.5)
		at.y = w.support_height(at, w.terrain_height(w.cell_at(at)) + 0.3)
		e.global_position = at
		e.home = at

func cast(id: String) -> bool:
	var slot: int = p.ability_slots.find(id)
	if slot < 0: return false
	p.abilities[id].cooldown_left = 0.0
	return p.cast_ability(slot)

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p: p._invulnerable_left = 5.0
	if p and p.is_alive(): p.health.heal(999999)
	if f == 8:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		hud = get_first_node_in_group("hud"); con = get_first_node_in_group("command_console")
		get_first_node_in_group("raids").enabled = false
		get_first_node_in_group("weather").set_kind("clair")
		get_first_node_in_group("day_cycle").hour = 11.0
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		tt = load("res://scripts/hero/talent_tree.gd")
		print("== l'arbre")
		var all: Array = tt.nodes()
		var combat := all.filter(func(n): return not n.get("story", false))
		var actives := combat.filter(func(n): return n.kind == "active")
		var by := {}
		for n in actives: by[n.rarity] = int(by.get(n.rarity, 0)) + 1
		print("   %d nœuds, %d compétences actives %s" % [combat.size(), actives.size(), str(by)])
		check("un arbre géant (%d nœuds)" % combat.size(), combat.size() >= 300)
		check("des dizaines de compétences (%d)" % actives.size(), actives.size() >= 80)
		check("toutes les raretés, dont 9 mystiques", by.get("commune", 0) > 0 and by.get("rare", 0) > 0 and by.get("epique", 0) > 0 and by.get("legendaire", 0) > 0 and by.get("mystique", 0) == 9)
		var ids := {}
		var dup := false
		for n in all:
			if ids.has(n.id): dup = true
			ids[n.id] = true
		check("identifiants uniques", not dup)
		var bad := []
		for n in combat:
			for r in n.get("requires", []):
				if not ids.has(r): bad.append(n.id + "->" + r)
		check("liens valides %s" % str(bad.slice(0, 3)), bad.is_empty())
		# tout est atteignable depuis le premier anneau
		var reach := {}
		var changed := true
		while changed:
			changed = false
			for n in combat:
				if reach.has(n.id): continue
				var req: Array = n.get("requires", [])
				if req.is_empty() or req.any(func(r): return reach.has(r)):
					reach[n.id] = true
					changed = true
		check("tout l'arbre est atteignable (%d / %d)" % [reach.size(), combat.size()], reach.size() == combat.size())
		var old := ["lame_force", "lame_tourbillon", "lame_vitesse", "lame_charge", "lame_crit", "lame_seisme", "lame_execute", "lame_onde", "lame_tempete",
			"arc_affinite", "arc_feu", "arc_savoir", "arc_eclair", "arc_givre", "arc_bouclier", "arc_soin", "arc_puissance", "arc_meteores",
			"omb_reflexes", "omb_double_saut", "omb_vitalite", "omb_pas", "omb_poison", "omb_regen", "omb_sang", "omb_terreur", "omb_frenesie", "pac_eveil", "pac_roi"]
		check("les anciens talents existent toujours (sauvegardes)", old.all(func(id): return ids.has(id)))
		var cat: Dictionary = tt.node("cataclysme")
		check("le Cataclysme demande le niveau 990", int(cat.level) == 990 and cat.rarity == "mystique")
		var cost := 0
		for n in combat: cost += tt.cost(n.id)
		print("   coût total %d points ; points au niveau 1000 : %d" % [cost, tt.points_until(1000)])
		check("tout l'arbre s'apprend vers la fin (coût %d, %d points au niveau 1000)" % [cost, tt.points_until(1000)], cost <= tt.points_until(1000) + 40 and cost > tt.points_until(400))
		var ms: Array = combat.filter(func(n): return n.get("rarity", "") == "mystique" and n.kind == "active").map(func(n): return float(n.params.get("dmg", 0)))
		var cs: Array = combat.filter(func(n): return n.get("rarity", "") == "commune" and n.kind == "active").map(func(n): return float(n.params.get("dmg", 0)))
		check("une mystique frappe bien plus fort qu'une commune (%.1f contre %.1f)" % [ms.min(), cs.max()], ms.min() >= cs.max() * 4.0)
		print("== les niveaux")
		check("XP du niveau 1 inchangée (%d)" % p.xp_to_next(), p.xp_to_next() == 40)
		check("niveau de puissance : 1000 -> %d" % p.power_level_of(1000), p.power_level_of(1000) == 325 and p.power_level_of(80) == 80)
		print("== au niveau 3")
		check("le talent de la classe est offert", p.talents.has("lame_force"))
		check("pas de point au niveau 1", p.talent_points() == 0)
		p.set_level_to(3)
		check("2 points par niveau au début (%d)" % p.talent_points(), p.talent_points() == 4)
		check("les débuts de toutes les branches sont ouverts", ["arc_affinite", "fou_etincelle", "giv_froid", "sac_foi", "ter_racine", "san_soif", "omb_reflexes"].all(func(id): return p.talent_block_reason(id) == ""))
		check("une compétence lointaine demande du niveau (%s)" % p.talent_block_reason("lame_titan"), p.talent_block_reason("lame_titan").begins_with("Niveau"))
		check("apprendre Tourbillon", p.unlock_talent("lame_tourbillon") and p.ability_slots[0] == "lame_tourbillon")
		print("== au niveau 1000")
		p.set_level_to(1000)
		check("niveau 1000 (%d points)" % p.talent_points(), p.level == 1000 and p.talent_points() > 900)
		var a0: int = p.attack_power()
		check("/competences", con.run("/competences"))
		check("tout l'arbre est appris (%d)" % p.talents.keys().filter(func(t): return not tt.is_story(t)).size(), p.talents.keys().filter(func(t): return not tt.is_story(t)).size() == combat.size())
		check("bien plus fort (attaque %d -> %d)" % [a0, p.attack_power()], p.attack_power() > a0 * 2)
		var bar := ["lame_myth", "feu_myth", "fou_myth", "giv_myth", "sac_myth", "ter_myth", "san_myth", "omb_myth", "lame_jugement", "cataclysme"]
		for i in bar.size(): p.set_ability_slot(i, bar[i])
		check("une barre de 10 compétences", p.ability_slots == bar and hud._ability_cells.size() == 10)
		hud._update_abilities()
		w.teleport(w.cell_center(w.spawn_cell) + Vector3(60, 0, 40))
		start("bar")
	if later("bar", 1500):
		p.cam_pitch = deg_to_rad(30); p.camera_zoom = 1.6; p.snap_camera()
		shot("01_barre.png")
		summon(12)
		start("myth")
	if later("myth", 1200):
		foes0 = foes_near(20.0).size()
		# les ennemis visés : on vérifie à la fin qu'eux sont anéantis (d'autres peuvent arriver entre-temps)
		set_meta("cata_foes", foes_near(26.0))
		check("Mille Soleils d'Acier lancée (%d ennemis autour)" % foes0, cast("lame_myth"))
		p.cam_pitch = deg_to_rad(45); p.camera_zoom = 3.2; p.snap_camera()
		start("myth_shot")
	if later("myth_shot", 900):
		shot("02_mystique_lames.png")
		start("myth_end")
	if later("myth_end", 2500):
		check("les ennemis sont balayés (%d -> %d)" % [foes0, foes_near(20.0).size()], foes_near(20.0).size() == 0)
		summon(10)
		start("fire")
	if later("fire", 1000):
		check("Apocalypse lancée", cast("feu_myth"))
		start("fire_shot")
	if later("fire_shot", 1300):
		shot("03_mystique_feu.png")
		start("bolt")
	if later("bolt", 2500):
		summon(10)
		check("Colère du Ciel lancée", cast("fou_myth"))
		start("bolt_shot")
	if later("bolt_shot", 700):
		shot("04_mystique_foudre.png")
		start("cata")
	if later("cata", 2500):
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		w.teleport(w.cell_center(w.spawn_cell) + Vector3(-70, 0, -60))
		start("cata2")
	if later("cata2", 1200):
		summon(12)
		c0 = w.cell_at(p.global_position)
		h0 = w.terrain_height(c0 + Vector2i(3, 3))
		check("CATACLYSME lancé", cast("cataclysme"))
		p.cam_pitch = deg_to_rad(50); p.camera_zoom = 4.0; p.snap_camera()
		start("cata_shot")
	if later("cata_shot", 1100):
		shot("05_cataclysme.png")
		start("cata_end")
	if later("cata_end", 7000):
		# machine chargée (CI, suite complète) : les dernières frappes peuvent tomber un peu plus tard
		var targets: Array = (get_meta("cata_foes") as Array).filter(func(e): return is_instance_valid(e) and e.is_alive())
		if targets.size() > 0 and not has_meta("cata_retry"):
			set_meta("cata_retry", true)
			start("cata_end")
			return false
		var h1: float = w.terrain_height(c0 + Vector2i(3, 3))
		var rim: float = w.terrain_height(c0 + Vector2i(24, 0))
		check("un cratère géant (centre %.1f -> %.1f m, rebord %.1f m)" % [h0, h1, rim], (h1 < h0 - 5.0 or h1 <= w.water_surface + 0.6) and rim > h1 + 3.0)
		check("les ennemis visés sont anéantis (%d restent)" % targets.size(), targets.is_empty())
		p.global_position = w.cell_center(c0) + Vector3(0, 0, 30)
		p.global_position.y = w.ground_height_at(p.global_position + Vector3(0, 40, 0))
		p.cam_pitch = deg_to_rad(40); p.camera_zoom = 4.5; p.cam_yaw = 0.0; p.snap_camera()
		start("crater_view")
	if later("crater_view", 2500):
		shot("06_cratere.png")
		hud.talent_ui.open()
		start("tree")
	if later("tree", 800):
		shot("07_arbre.png")
		hud.talent_ui._canvas.zoom = 0.26
		hud.talent_ui._canvas.focus(Vector2.ZERO)
		start("tree2")
	if later("tree2", 600):
		shot("08_arbre_entier.png")
		hud.talent_ui._canvas.zoom = 0.9
		hud.talent_ui.select("fou_myth")
		start("tree3")
	if later("tree3", 600):
		shot("09_arbre_mystique.png")
		hud.talent_ui.close_ui()
		set_meta("n", p.talents.size())
		root.get_node("SaveGame").save_game("3")
		root.get_node("SaveGame").load_game("3")
		start("load")
	if later("load", 4000):
		p = get_first_node_in_group("player")
		check("rechargé : niveau %d" % p.level, p.level == 1000)
		check("rechargé : %d nœuds" % p.talents.size(), p.talents.size() == int(get_meta("n")))
		check("rechargé : la barre de 10 (%s)" % p.ability_slots[9], p.ability_slots[9] == "cataclysme" and p.ability_slots[0] == "lame_myth")
		print("RÉSULTAT : ", "tout est bon" if ok else "il y a des échecs")
		quit(0 if ok else 1)
	return false
