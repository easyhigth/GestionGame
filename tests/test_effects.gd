extends SceneTree
## Vitrine des effets spéciaux : attaques de base (ruban de l'arme, entailles, impacts, critique),
## puis une compétence de chaque genre, de la commune à la mystique, et le Cataclysme. Une capture au
## moment le plus spectaculaire de chacune (fx_XX_nom.png) ; vérifie aussi que tout se nettoie.
var f := 0
var p; var w; var items; var tt
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/fx_"
var step := -1
var step_at := 0.0
var shot_done := false
var peak := 0
var hs  # compétence en cours

func _initialize():
	var h = load("res://scripts/hero/hero_profile.gd").new()
	h.hero_name = "Selka"
	h.race = load("res://data/races/elfe.tres")
	h.style = 1
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

## Une compétence active de l'arbre du genre `kind`, la plus rare possible parmi `rarities`.
func pick(kind: String, rarities: Array) -> String:
	for r in rarities:
		for n in tt.nodes():
			if n.get("kind") == "active" and n.get("active") == kind and n.get("rarity") == r and not n.has("cls"):
				return n.id
	return ""

func summon(n: int, dist := 4.0) -> void:
	for e in get_nodes_in_group("enemy_units"):
		e.queue_free()
	for i in n:
		var e = load("res://scenes/enemies/enemy.tscn").instantiate()
		e.data = load("res://data/enemies/squelette.tres")
		e.level = 40
		w.add_child(e)
		var a := TAU * i / n + 0.4
		var at: Vector3 = p.global_position + Vector3(cos(a), 0, sin(a)) * (dist + (i % 2) * 1.5)
		at.y = w.support_height(at, w.terrain_height(w.cell_at(at)) + 0.3)
		e.global_position = at
		e.home = at

## [nom, action, délai de la capture (ms), recul de la caméra]
var SHOWS := []

func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if p:
		p._invulnerable_left = 5.0
		p.health.heal(999999)
	peak = maxi(peak, VoxelBurst.live)
	if f == 8:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); items = root.get_node("Items")
		tt = load("res://scripts/hero/talent_tree.gd")
		get_first_node_in_group("raids").enabled = false
		get_first_node_in_group("weather").set_kind("clair")
		get_first_node_in_group("day_cycle").hour = 19.5
		p.set_level_to(300)
		var sw = items.get_item("sword_iron@1")
		if sw:
			p.equipment.equip(sw)
		p.refresh_stats()
		var kinds := [["nova", ["commune"]], ["nova", ["legendaire", "epique"]], ["chain", ["epique", "rare", "legendaire"]],
			["cone", ["legendaire", "epique", "rare"]], ["meteor", ["legendaire", "epique"]], ["vortex", ["epique", "legendaire", "rare"]],
			["heal", ["epique", "rare", "legendaire"]], ["execute", ["legendaire", "epique", "rare"]], ["volley", ["epique", "rare"]],
			["storm", ["mystique"]]]
		SHOWS = [["coup_entaille", "move:slash_2", 190, 0.7], ["tourbillon", "move:spin", 160, 0.8], ["critique", "crit", 60, 0.7]]
		for k in kinds:
			var id := pick(k[0], k[1])
			if id == "":
				print("   (pas de compétence %s)" % k[0])
				continue
			var delay: int = {"meteor": 800, "storm": 900, "vortex": 820, "volley": 260, "chain": 90, "execute": 90, "heal": 300, "cone": 160}.get(k[0], 140)
			var zoom: float = 1.5 if k[0] in ["storm", "meteor"] else (1.0 if k[0] != "nova" else 1.1)
			SHOWS.append([k[0] + "_" + tt.node(id).rarity + "_" + id, "skill:" + id, delay, zoom])
		SHOWS.append(["cataclysme", "skill:cataclysme", 1500, 1.8])
		print("== %d effets à montrer" % SHOWS.size())
		step = 0
		step_at = game_ms + 5500.0  # après les bandeaux d'arrivée
		summon(6)
	if step < 0:
		return false
	if step >= SHOWS.size():
		if game_ms > step_at + 2500.0:
			# tout s'est nettoyé : il ne reste presque plus de cubes d'effets ni de lumières
			print("   cubes d'effets au plus fort : %d ; restants : %d ; lumières : %d" % [peak, VoxelBurst.live, SkillFX.lights_live])
			check("les effets se nettoient (cubes restants : %d)" % VoxelBurst.live, VoxelBurst.live < 400)
			check("pas de lumière oubliée (%d)" % SkillFX.lights_live, SkillFX.lights_live <= 1)
			check("de la matière à l'écran au plus fort (%d cubes)" % peak, peak > 300)
			print("RÉSULTAT : ", "tout est bon" if ok else "échec")
			return true
		return false
	var sh: Array = SHOWS[step]
	if game_ms >= step_at and not has_meta("fired_%d" % step):
		set_meta("fired_%d" % step, true)
		Engine.time_scale = 1.0
		p.camera_zoom = float(sh[3])
		var act: String = sh[1]
		var foes := get_nodes_in_group("enemy_units").filter(func(e): return is_instance_valid(e) and e.is_alive())
		if foes.size() < 3:
			summon(6)
			foes = get_nodes_in_group("enemy_units")
		var near = foes[0]
		var to: Vector3 = near.global_position - p.global_position
		to.y = 0.0
		if to.length() > 0.1:
			p.facing = to.normalized()
			p.visual.rotation.y = atan2(p.facing.x, p.facing.z)
		if act.begins_with("move:"):
			p.perform(act.substr(5), 1.0, 1.0)
		elif act == "crit":
			SkillFX.impact(p, near.global_position + Vector3(0, 1.0, 0), Color("ffa640"), to, true, true)
			p.perform("heavy_1", 1.0, 1.0)
		else:
			var id := act.substr(6)
			hs = load("res://scripts/hero/hero_skill.gd").new(tt.make_skill(id), p)
			hs.set_level(p.level)
			check("%s (%s) se lance" % [tt.node(id).name, tt.node(id).rarity], hs.activate())
		step_at = game_ms + float(sh[2])
		shot_done = false
	elif has_meta("fired_%d" % step) and not shot_done and game_ms >= step_at:
		shot("%02d_%s.png" % [step + 1, sh[0]])
		shot_done = true
		step += 1
		step_at = game_ms + 900.0
	return false
