extends SceneTree
## Défi des donjons : un donjon vaincu se refait avec des modificateurs et un trésor plus riche ;
## le défi monte à chaque victoire.
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
		var best = null
		for zz in world.zones:
			if zz.gate.x >= 0 and (best == null or zz.dist < best.dist):
				best = zz
		z = best
		# nombre de modificateurs
		check("défi 0 : aucun modificateur", dm.affix_count(0, 0) == 0)
		check("défi 1 : un modificateur", dm.affix_count(1, 0) == 1)
		check("défi 4 : deux modificateurs", dm.affix_count(4, 0) == 2)
		check("défi 8 : trois modificateurs", dm.affix_count(8, 0) == 3)
		check("Brume palier 1 : aucun modificateur", dm.affix_count(0, 1) == 0)
		check("Brume palier 4 : deux modificateurs", dm.affix_count(0, 4) == 2)
		check("modificateurs toujours les mêmes", dm.pick_affixes(z, 5, 0) == dm.pick_affixes(z, 5, 0))
		check("donjon pas vaincu : pas de défi", dm.next_challenge(z) == 0)
		z["cleared"] = true
		check("donjon vaincu : défi 1", dm.next_challenge(z) == 1)
		check("étiquette de la porte : défi", str(dm.gate_text(z)[0]).contains("Défi 1"))
		var g: Vector3 = world.cell_center(z.gate)
		world.load_area(g)
		p.global_position = g + Vector3(0, 0, 1.5)
		check("on entre", dm.try_interact(p))
	if f == 40:
		check("donjon en mode défi 1", dm.active and dm.challenge == 1)
		check("un modificateur actif", dm.affixes.size() == 1)
		check("le boss porte le défi", dm.boss != null and str(dm.boss.title).contains("défi 1"))
		var lv_base: int = (z.level as Vector2i).y + 2
		check("boss plus haut niveau que normal (%d > %d)" % [dm.boss.level, lv_base], dm.boss.level > lv_base)
		dm.boss.health.take_damage(99999999, p)
	if f == 80:
		check("boss vaincu : défi mémorisé", int(z.get("challenge", 0)) == 1)
		check("défi suivant : 2", dm.next_challenge(z) == 2)
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	return false
