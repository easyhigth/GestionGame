extends SceneTree
## Sons du combat : chaque arme a son bruit d'impact, chaque monstre sa matière (os, gelée, armure...),
## chaque compétence le son de son genre de magie, et les ultimes une charge puis une déflagration.
var ok := true

func check(name: String, cond: bool) -> void:
	print(("  OK  " if cond else "  ÉCHEC  ") + name)
	ok = ok and cond

func _initialize():
	for n in ["hit_blade", "hit_blunt", "hit_pierce", "hit_fist", "hit_magic", "mat_bone", "mat_armor", "mat_stone",
			"mat_wood", "mat_slime", "mat_spirit", "cast_fire", "cast_ice", "cast_lightning", "cast_holy", "cast_shadow",
			"cast_nature", "cast_arcane", "cast_physical", "ult_charge", "ult_boom"]:
		var s = load("res://assets/audio/sfx/%s.wav" % n)
		check("son %s (%.2f s)" % [n, s.get_length() if s else 0.0], s != null and s.get_length() > 0.05)
	var hs = load("res://scripts/hero/hero_skill.gd")
	check("météore : feu", hs.genre_of("meteor", {}, Color.RED) == "fire")
	check("soin : lumière", hs.genre_of("heal", {}, Color.GREEN) == "holy")
	check("chaîne d'éclairs : foudre", hs.genre_of("chain", {}, Color.YELLOW) == "lightning")
	check("champ ralentissant : glace", hs.genre_of("slow_field", {}, Color.BLUE) == "ice")
	check("aspiration : ombre", hs.genre_of("drain", {}, Color.PURPLE) == "shadow")
	check("nova verte : nature", hs.genre_of("nova", {}, Color("4ac85a")) == "nature")
	check("nova violette : arcane", hs.genre_of("nova", {}, Color("a050ff")) == "arcane")
	check("ruée : arme", hs.genre_of("dash", {}, Color.WHITE) == "physical")
	var en = load("res://scenes/enemies/enemy.tscn")
	var want := {"squelette": "bone", "slime_bleu": "slime", "dryade_corrompue": "wood", "esprit_follet": "spirit", "loup": "", "orc_brute": "armor"}
	for id in want:
		var e = en.instantiate()
		e.data = load("res://data/enemies/%s.tres" % id)
		root.add_child(e)
		check("%s sonne « %s » (%s)" % [id, want[id], e.impact_material()], e.impact_material() == want[id])
		e.queue_free()
	print("RÉSULTAT : ", "tout est bon" if ok else "échec")
	quit()
