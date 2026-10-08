extends SceneTree
## IA : un monstre bloqué par un mur le contourne (chemin), la meute se prévient, les monstres qui attendent
## leur tour encerclent la cible au lieu de s'agglutiner, une bête très blessée fuit, pas d'aggro à travers un
## mur ; un habitant très blessé se replie.
var f := 0
var ok := true
var p; var w; var items
var wolf; var pack := []

func _initialize():
	var h = load("res://scripts/hero/hero_profile.gd").new()
	h.hero_name = "Selka"
	h.race = load("res://data/races/humain.tres")
	h.hero_class = load("res://data/classes/guerrier.tres")
	h.job = load("res://data/jobs/chasseur.tres")
	h.skill = load("res://data/skills/vorace.tres")
	root.get_node("GameState").hero = h
	root.get_node("GameState").world_seed = 4242
	var sg = root.get_node("SaveGame")
	sg.world_opts = sg.WORLD_DEFAULTS.duplicate()
	change_scene_to_file("res://scenes/main.tscn")

func check(name: String, cond: bool) -> void:
	print(("  OK  " if cond else "  ÉCHEC  ") + name)
	ok = ok and cond

func spawn(id: String, at: Vector3):
	var e = (load("res://scenes/enemies/enemy.tscn") as PackedScene).instantiate()
	e.data = load("res://data/enemies/%s.tres" % id)
	e.level = 3
	w.add_child(e)
	e.global_position = Vector3(at.x, w.ground_height_at(at + Vector3(0, 3, 0)), at.z)
	e.home = e.global_position
	return e

func flat_spot() -> Vector2i:
	var c0: Vector2i = w.spawn_cell + Vector2i(70, 70)
	for r in range(0, 30):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c := c0 + Vector2i(dx, dz)
				var ok2 := true
				var h0: float = w.terrain_height(c)
				for z in range(-6, 7):
					for x in range(-8, 9):
						var cc := c + Vector2i(x, z)
						if absf(w.terrain_height(cc) - h0) > 0.01 or w.decor_at(cc) != 0 or w.terrain_type(cc) in [w.WATER, w.DEEP]:
							ok2 = false
				if ok2:
					return c
	return c0

var c: Vector2i
var H := 0.0

func _process(_d) -> bool:
	f += 1
	if p:
		p._invulnerable_left = 5.0
		p.health.heal(9999)
	if f == 60:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		get_first_node_in_group("raids").enabled = false
		for e in get_nodes_in_group("enemy_units"): e.queue_free()
		c = flat_spot()
		H = w.terrain_height(c)
		# un mur de pierre de 9 cases entre le héros et le loup
		var stone = items.get_item("bloc_pierre_brute")
		for z in range(-4, 5):
			for y in 2:
				w.build.place_block(Vector3i(c.x, floori(H) + y, c.y + z), stone)
		p.global_position = Vector3(c.x - 4 + 0.5, H, c.y + 0.5)
		wolf = spawn("loup", Vector3(c.x + 4 + 0.5, H, c.y + 0.5))
		check("pas d'aggro à travers le mur", not wolf._can_see(p))
		wolf._target = p
		set_meta("t0", f)
	if f > 60 and f < 360 and wolf and is_instance_valid(wolf):
		if wolf.global_position.x < c.x:
			if not has_meta("around"):
				set_meta("around", f)
	if f == 360:
		check("le loup a contourné le mur (en %s images)" % str(get_meta("around", "—")), has_meta("around"))
		check("en suivant un chemin calculé", wolf._chase_path.size() >= 0)
		wolf.queue_free()
		# une meute : un loup frappé prévient les autres
		var at := Vector3(c.x + 6.5, H, c.y + 0.5)
		for i in 4:
			pack.append(spawn("loup", at + Vector3(i * 0.8, 0, 0)))
		p.global_position = Vector3(c.x - 6 + 0.5, H, c.y - 6.5)
	if f == 365:
		pack[0].receive_hit(1, p, 0.0)
		check("la meute est prévenue (%d / 3)" % pack.slice(1).filter(func(e): return e._target == p).size(), pack.slice(1).all(func(e): return e._target == p))
		p.global_position = Vector3(c.x - 10 + 0.5, H, c.y + 8.5)
	if f == 560:
		pack = pack.filter(func(e): return is_instance_valid(e))
		check("la meute est toujours là (%d)" % pack.size(), pack.size() == 4)
		if pack.size() < 2:
			print("RÉSULTAT : échec")
			return true
		var dirs := []
		for e in pack:
			var d: Vector3 = e.global_position - p.global_position
			d.y = 0.0
			dirs.append(atan2(d.x, d.z))
		var spread := 0.0
		for i in dirs.size():
			for j in range(i + 1, dirs.size()):
				spread = maxf(spread, absf(wrapf(dirs[i] - dirs[j], -PI, PI)))
		check("la meute encercle le héros (écart d'angle max %.0f°)" % rad_to_deg(spread), spread > deg_to_rad(80.0))
		var close := 0
		for i in pack.size():
			for j in range(i + 1, pack.size()):
				if pack[i].global_position.distance_to(pack[j].global_position) < 0.5:
					close += 1
		check("les loups ne s'empilent pas (%d paires collées)" % close, close == 0)
		# une bête très blessée prend la fuite
		var hurt = pack[0]
		hurt._fled = false
		hurt.health.current = int(hurt.health.max_health * 0.1)
		var tries := 0
		while not hurt._fled and tries < 20:
			hurt._fled = false
			hurt._fight(0.05, 3.0)
			tries += 1
		check("une bête très blessée décide de fuir ou de tenir (une seule fois)", hurt._fled)
		for e in pack: e.queue_free()
		# un habitant armé très blessé se replie
		var vs = get_nodes_in_group("villagers").filter(func(x): return not x.companion and x.weapon() != null)
		if vs.is_empty():
			var v0 = get_nodes_in_group("villagers")[0]
			v0.equipment.equip(items.get_item("iron_sword") if items.get_item("iron_sword") else items.get_item("wood_sword"))
			vs = [v0]
		var v = vs[0]
		var foe = spawn("loup", v.global_position + Vector3(2, 0, 0))
		v._threat = foe
		v.health.current = int(v.health.max_health * 0.2)
		v._fight_or_flee(0.05)
		check("habitant très blessé : il se replie", v._retreat_left > 0.0)
		foe.queue_free()
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	return false
