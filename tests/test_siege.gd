extends SceneTree
var f := 0
var p; var w; var items; var dip; var hud; var rm; var tr
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/sg_"

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
var dm; var atk0 := 0

func kill_all() -> void:
	for e in dm._siege_alive:
		if is_instance_valid(e) and e.is_alive():
			e.health.take_damage(e.health.current + 99999, p)

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p:
		p._invulnerable_left = 5.0
		p.health.heal(9999)
	if f == 10:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		dip = get_first_node_in_group("diplomacy"); hud = get_first_node_in_group("hud"); rm = get_first_node_in_group("raids")
		dm = get_first_node_in_group("dungeons")
		rm.enabled = false
		print("== conditions")
		check("pas de siège hors guerre : %s" % dip.block("karg", "siege"), dip.block("karg", "siege") != "")
		dip.act("karg", "war")
		check("niveau trop bas : %s" % dip.block("karg", "siege"), dip.block("karg", "siege").begins_with("Niveau"))
		p.level = 9
		check("en guerre, niveau 9 : siège possible", dip.block("karg", "siege") == "")
		atk0 = p.attack_power()
		dm.enter_siege("karg", true)
		check("place forte construite (%d blocs)" % dm.grid.blocks.size(), dm.active and dm.siege == "karg" and dm.grid.blocks.size() > 1000)
		start("w")
	if later("w", 5000):
		check("vague 1 : %d soldats" % dm._siege_alive.size(), dm.siege_wave == 1 and dm._siege_alive.size() == 5)
		shot("01_vague.png")
		kill_all()
		start("w2")
	if later("w2", 5000):
		check("vague 2 : %d soldats" % dm._siege_alive.size(), dm.siege_wave == 2 and dm._siege_alive.size() == 7)
		kill_all()
		start("w3")
	if later("w3", 5000):
		check("vague 3 : %d soldats (avec un ogre)" % dm._siege_alive.size(), dm.siege_wave == 3 and dm._siege_alive.size() == 9)
		kill_all()
		start("champ")
	if later("champ", 5000):
		var b = dm.boss
		check("champion : %s (%s), %d PV" % [b.data.display_name if b else "-", b.title if b else "-", b.health.max_health if b else 0], b != null and b.data.display_name == "Grukk le Brise-Remparts" and b.awake)
		p.global_position = b.global_position + Vector3(0, 0, 3.5)
		start("champ2")
	if later("champ2", 1500):
		shot("02_champion.png")
		dm.boss.health.take_damage(dm.boss.health.current + 99999, p)
		start("won")
	if later("won", 800):
		check("Karg annexée : %s" % dip.status("karg"), dip.annexed("karg") and dip.status("karg") == "Province" and not dip.at_war("karg"))
		check("bonus de province (attaque %d -> %d)" % [atk0, p.attack_power()], p.souls.has("province_karg") and p.attack_power() > atk0)
		var k = get_first_node_in_group("kingdom")
		check("titre : %s" % k.title(), k.title().contains("1 province"))
		check("plus de diplomatie avec une province", dip.block("karg", "gift") == "C'est ta province.")
		var ch = dm._interactables.filter(func(i): return i.kind == "siege_chest")[0]
		p.global_position = ch.pos + Vector3(0, 0, 1.2)
		dm.try_interact(p)
		start("chest")
	if later("chest", 500):
		var ids = get_nodes_in_group("pickups").filter(func(q): return q.global_position.y < -50).map(func(q): return q.item.id)
		print("   trésor : ", ids)
		check("trésor de la capitale (or, orichalque)", ids.has("piece_or") and ids.has("orichalque"))
		shot("03_tresor.png")
		dm.leave(true)
		start("prov")
	if later("prov", 800):
		print("== province")
		check("retour au royaume", not dm.active and dm.siege == "")
		var pk0 := get_nodes_in_group("pickups").size()
		var d0: int = dip.today()
		dip.new_day(d0 + 2)
		check("impôts livrés (%d objets)" % (get_nodes_in_group("pickups").size() - pk0), get_nodes_in_group("pickups").size() > pk0)
		dip.new_day(d0 + 5)
		var col = get_nodes_in_group("strangers").filter(func(v): return v.get_meta("province", "") == "karg")
		check("un colon de Karg arrive : %s" % [col.map(func(v): return v.race.display_name)], col.size() == 1)
		print("== retraite")
		dip.act("sylvae", "war")
		dm.enter_siege("sylvae", true)
		start("ret")
	if later("ret", 600):
		dm.leave(true)
		start("ret2")
	if later("ret2", 600):
		check("siège levé : Sylvaë toujours en guerre", not dm.active and dip.at_war("sylvae") and not dip.annexed("sylvae"))
		hud.diplomacy_panel.open()
		start("panel")
	if later("panel", 700):
		shot("04_panneau.png")
		hud.diplomacy_panel.close()
		var d = JSON.parse_string(JSON.stringify(dip.export_state()))
		dip.states.karg.annexed = false
		dip.import_state(d)
		check("province rechargée", dip.annexed("karg"))
		print("RÉSULTAT : " + ("tout est bon" if ok else "ÉCHECS"))
		return true
	return f > 30000
