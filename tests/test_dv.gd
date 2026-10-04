extends SceneTree
var f := 0
var p; var w; var items; var dip; var hud; var rm; var tr
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/dv_"

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
var dm; var zs := []; var zi := 0; var hp_before := 0; var protect := true

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p and protect:
		p._invulnerable_left = 5.0
		p.health.heal(9999)
	if f == 10:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		dm = get_first_node_in_group("dungeons"); rm = get_first_node_in_group("raids")
		rm.enabled = false
		for z in w.zones:
			if z.gate.x >= 0:
				zs.append(z)
		zs.sort_custom(func(a, b): return a.dist < b.dist)
		start("try")
	if later("try", 300):
		var z = zs[zi]
		w.load_area(w.cell_center(z.gate))
		dm.enter(z, true)
		print("  après enter : actif ", dm.active, " busy ", dm._busy, " pos ", p.global_position)
		start("look")
	if later("look", 1200):
		print("donjon %s : actif %s salles %d pièges %d, gardien %s, leviers %s" % [zs[zi].name, dm.active, dm.rooms.size(), dm.traps.size(), dm.miniboss != null, dm.lever_order])
		if dm.lever_order.is_empty() and zi < zs.size() - 1:
			dm.leave(true)
			zi += 1
			remove_meta("try_done"); remove_meta("look_done"); remove_meta("look")
			start("try")
			return false
		print("== donjon de %s" % zs[zi].name)
		check("pièges à piques (%d)" % dm.traps.size(), dm.traps.size() >= 2)
		check("gardien : %s" % (dm.miniboss.name_label.text if dm.miniboss else "-"), dm.miniboss != null and dm.miniboss.name_label.text.contains("Gardien"))
		check("salle secrète et leviers : %s" % [dm.lever_order], dm.lever_order.size() == 3 and dm._vault_seal.size() == 2 * dm.WALL_H)
		# mauvais ordre
		var levers = dm._interactables.filter(func(i): return i.kind == "lever")
		var wrong = levers.filter(func(i): return i.symbol != dm.lever_order[0])[0]
		dm._pull_lever(wrong)
		check("mauvais ordre : remis à zéro", dm._lever_done.is_empty() and not dm.vault_open)
		var lv = levers.filter(func(i): return i.symbol == dm.lever_order[0])[0]
		p.global_position = lv.pos + Vector3(0, 0, 1.0)
		start("pull")
	if later("pull", 900):
		shot("01_leviers.png")
		var levers = dm._interactables.filter(func(i): return i.kind == "lever")
		for sym in dm.lever_order:
			var l = levers.filter(func(i): return i.symbol == sym)[0]
			p.global_position = l.pos + Vector3(0, 0, 1.0)
			var r = dm.try_interact(p)
			print("   levier ", sym, " -> ", r, " fait ", dm._lever_done, " pos ", l.pos, " joueur ", p.global_position)
		var k0: Vector3i = dm._vault_seal[0] if not dm._vault_seal.is_empty() else Vector3i.ZERO
		check("bon ordre : la salle secrète s'ouvre", dm.vault_open and dm._vault_seal.is_empty())
		var ch = dm._interactables.filter(func(i): return i.kind == "vault_chest")[0]
		p.global_position = ch.pos + Vector3(0, 0, -1.3)
		start("vault")
	if later("vault", 900):
		shot("02_salle_secrete.png")
		var ch = dm._interactables.filter(func(i): return i.kind == "vault_chest")[0]
		p.global_position = ch.pos + Vector3(0, 0, 1.0)
		dm.try_interact(p)
		start("vault2")
	if later("vault2", 400):
		var ids = get_nodes_in_group("pickups").filter(func(q): return q.global_position.y < -50).map(func(q): return q.item.id)
		check("trésor secret (gemme, mithril)", ids.any(func(i): return str(i).begins_with("gemme_")) and ids.has("mithril_brut"))
		# gardien
		var g = dm.miniboss
		p.global_position = g.global_position + Vector3(0, 0, 3)
		start("mb")
	if later("mb", 900):
		shot("03_gardien.png")
		var g = dm.miniboss
		check("gardien plus grand et résistant (%d PV)" % g.health.max_health, g.visual.scale.x > g.data.model_scale * 1.3)
		g.health.take_damage(g.health.current + 99999, p)
		start("mb2")
	if later("mb2", 500):
		var ids = get_nodes_in_group("pickups").filter(func(q): return q.global_position.y < -50 and q.global_position.distance_to(p.global_position) < 6).map(func(q): return q.item.id)
		check("butin du gardien : %s" % [ids], ids.any(func(i): return str(i).begins_with("gemme_")))
		# piège
		var tr = dm.traps[0]
		for e in get_nodes_in_group("enemy_units"):
			if e.global_position.distance_to(tr.pos) < 12:
				e.queue_free()
		p.global_position = tr.pos
		tr.t = 0.0
		protect = false
		p._invulnerable_left = 0.0
		p.health.heal(9999)
		hp_before = p.health.current
		# on compte les coups des piques (la vie seule ne suffit pas : un passage de niveau la remonte)
		set_meta("spike_hits", 0)
		var trap_node = tr.node
		p.hurt.connect(func(_d, src): if src == trap_node: set_meta("spike_hits", int(get_meta("spike_hits")) + 1))
		start("trap")
	if has_meta("trap") and not has_meta("trap_done"):
		p.global_position = dm.traps[0].pos
		p._invulnerable_left = 0.0
	if later("trap", 3000):
		shot("04_piques.png")
		check("les piques blessent le héros (%d coup(s), vie %d -> %d)" % [int(get_meta("spike_hits")), hp_before, p.health.current], int(get_meta("spike_hits")) > 0)
		protect = true
		print("RÉSULTAT : " + ("tout est bon" if ok else "ÉCHECS"))
		return true
	return f > 40000
