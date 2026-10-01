extends SceneTree
var t0 := 0
var f := 0
var main; var world; var p; var dm; var z
var ok := true

func check(name: String, cond: bool) -> void:
	print(("  OK  " if cond else "  ÉCHEC  ") + name)
	ok = ok and cond
func _initialize():
	var h := HeroProfile.new()
	h.hero_name = "Selka"
	h.race = load("res://data/races/homme_bete.tres")
	h.hero_class = load("res://data/classes/rodeur.tres")
	h.job = load("res://data/jobs/chasseur.tres")
	root.get_node("GameState").hero = h
	main = load("res://scenes/main.tscn").instantiate()
	world = main.get_node("World")
	world.random_seed_on_start = false
	world.world_seed = 4242
	root.add_child(main)
func _process(_d) -> bool:
	f += 1
	if p:
		p._invulnerable_left = 5.0
	if f == 2:
		p = main.get_node("World/Player")
		dm = get_first_node_in_group("dungeons")
		# zone la plus proche avec un donjon
		var best = null
		for zz in world.zones:
			if zz.gate.x >= 0 and (best == null or zz.dist < best.dist):
				best = zz
		z = best
		var g: Vector3 = world.cell_center(z.gate)
		world.load_area(g)
		p.global_position = g + Vector3(0, 0, 1.5)
		var entered: bool = dm.try_interact(p)
		print("porte de ", z.name, " (", z.type.display_name, ")")
		check("E devant la porte : on descend", entered)
	if f == 30:
		print("actif=", dm.active, " salles=", dm.rooms.size(), " blocs=", dm.grid.blocks.size(), " pos héros=", p.global_position, " sol=", world.ground_height_at(p.global_position))
		print("boss: ", dm.boss.data.display_name, " Nv ", dm.boss.level, " pv ", dm.boss.health.max_health, " pouvoirs ", dm.boss.powers)
		print("camps: ", get_nodes_in_group("enemy_camps").filter(func(c): return c.global_position.y < -50).size())
		check("donjon généré (%d salles, %d blocs)" % [dm.rooms.size(), dm.grid.blocks.size()], dm.active and dm.rooms.size() >= 5 and dm.grid.blocks.size() > 500)
		check("héros au sol du donjon", absf(p.global_position.y - dm.FLOOR_Y) < 1.5)
		check("boss présent : %s" % dm.boss.data.display_name, dm.boss != null and not dm.boss.awake)
	if f == 40:
		var n := get_nodes_in_group("enemy_units").filter(func(e): return e.global_position.y < -50)
		check("monstres du donjon (%d)" % n.size(), n.size() >= 4)
		print("monstres du donjon: ", n.size(), " ex: ", n.slice(0, 4).map(func(e): return e.name_label.text + " y=" + str(snappedf(e.global_position.y, 0.1))))
		# test de marche : le héros avance vers l'est
		set_meta("start", p.global_position)
	if f > 40 and f < 70:
		p.velocity = Vector3(3, 0, 0)
		p._move_on_ground(1.0 / 60.0)
	if f == 70:
		print("marche: ", get_meta("start"), " -> ", p.global_position)
		check("on marche dans le donjon", absf(p.global_position.y - dm.FLOOR_Y) < 1.5)
		# on entre dans la salle du boss
		var c: Vector2i = dm.boss_room.get_center() + Vector2i(0, 3)
		p.global_position = Vector3(c.x + 0.5, -100, c.y + 0.5)
	if f == 75:
		check("salle du boss : il se réveille, la salle se ferme (%d cases)" % dm._sealed.size(), dm.boss.awake and dm._sealed.size() > 0)
	if f == 80:
		dm.boss.health.take_damage(int(dm.boss.health.max_health * 0.55), p)
	if f == 200:
		check("sous la moitié : phase 2", dm.boss.phase == 2)
	if f == 200: t0 = Time.get_ticks_msec()
	if f > 200 and f < 420 and Time.get_ticks_msec() - t0 < 14000:
		f = 300
		OS.delay_msec(16)
	if f == 420:
		print("renforts: ", dm.boss._adds.size())
		dm.boss.health.take_damage(dm.boss.health.current, p)
	if f == 430:
		print("vaincu=", z.get("cleared"), " scellées=", dm._sealed.size(), " âmes=", p.souls.keys(), " bonus=", p.soul_bonus, " attaque=", p.attack_power())
		var ch = dm._interactables.filter(func(i): return i.kind == "boss_chest")[0]
		p.global_position = ch.pos + Vector3(0, 0, 1.2)
		check("boss vaincu : donjon vaincu, salle rouverte, âme absorbée", z.get("cleared", false) and dm._sealed.is_empty() and p.souls.has(z.type.id))
		check("trésor du boss ouvert", dm.try_interact(p))
	if f == 440:
		var picks := get_nodes_in_group("pickups").filter(func(q): return q.global_position.y < -50)
		print("butin au sol: ", picks.map(func(q): return q.item.id + " x" + str(q.count)))
		var ex = dm._interactables.filter(func(i): return i.kind == "exit")[1]
		p.global_position = ex.pos + Vector3(0, 0, 1.2)
		check("butin au sol (%d objets)" % picks.size(), picks.size() >= 4)
		dm.try_interact(p)
	if f > 441 and f < 480 and dm.active:
		f = 445
		OS.delay_msec(16)
	if f == 480:
		check("retour à la surface, donjon effacé", not dm.active and p.global_position.y > -50 and dm.grid.blocks.size() == 0)
		print("RÉSULTAT : " + ("tout est bon" if ok else "ÉCHECS"))
		return true
	return false
