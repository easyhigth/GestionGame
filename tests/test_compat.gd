extends SceneTree
## Compatibilité : une vraie sauvegarde faite avec une ANCIENNE version du jeu (avant la forge, la diplomatie,
## les succès...) se charge sans erreur ; ce qui n'existait pas démarre avec ses valeurs par défaut.
## Puis on la ré-enregistre au format actuel et on la recharge.
var f := 0
var ok := true
var sg
var step := 0
var t0 := 0

func check(name: String, cond: bool) -> void:
	print(("  OK  " if cond else "  ÉCHEC  ") + name)
	ok = ok and cond

func _initialize():
	sg = root.get_node("SaveGame")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sg.path_of("compat").get_base_dir()))
	var src := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("tests/fixtures/partie_ancienne_version.json"))
	if src == "":
		src = FileAccess.get_file_as_string("res://tests/fixtures/partie_ancienne_version.json")
	var fo := FileAccess.open(sg.path_of("compat"), FileAccess.WRITE)
	fo.store_string(src)
	fo.close()

func items():
	return root.get_node("Items")

func _process(_d) -> bool:
	f += 1
	if f == 2:
		print("== chargement d'une sauvegarde de l'ancienne version")
		check("sauvegarde lue", sg.load_game("compat"))
	var p = get_first_node_in_group("player")
	if p == null:
		return f > 3000
	if step == 0:
		step = 1
		t0 = f
	if step == 1 and f - t0 == 60:
		check("héros : %s, niveau %d" % [p.profile.hero_name, p.level], p.profile.hero_name == "Ancienne" and p.level == 9)
		check("or : %d" % p.inventory.count(items().get_item("piece_or")), p.inventory.count(items().get_item("piece_or")) == 321)
		check("épée en fer équipée", p.weapon() != null and p.weapon().id == "sword_iron")
		check("âme du boss de la prairie", p.souls.has("prairie"))
		var w = get_first_node_in_group("world")
		check("zones rechargées (découverte, donjon vaincu)", w.zones[2].discovered and w.zones[3].get("cleared", false))
		print("== nouveaux systèmes avec leurs valeurs par défaut")
		var dip = get_first_node_in_group("diplomacy")
		check("diplomatie : Karg %d, aucune guerre" % dip.rel("karg"), dip.wars().is_empty() and dip.rel("karg") == float(dip.NATIONS.karg.start))
		var ach = get_first_node_in_group("achievements")
		ach.check_all()
		check("succès recalculés depuis la partie (niveau 5 : %s)" % ach.done.has("level_5"), ach.done.has("level_5"))
		var her = get_first_node_in_group("heraldry")
		check("bannière par défaut", her.custom_name == "" and her.primary == 0)
		var wev = get_first_node_in_group("world_events")
		check("événements du monde prêts", wev != null and not wev.is_active())
		check("Brume : palier 0 partout", w.zones.all(func(z): return int(z.get("brume", 0)) == 0))
		print("== ré-enregistrement au format actuel")
		check("sauvegarde au format actuel", sg.save_game("compat"))
		var d: Dictionary = sg.read("compat")
		check("les nouveaux systèmes y sont (%s)" % ", ".join(PackedStringArray(["diplomacy", "achievements", "heraldry", "events"].filter(func(k): return d.has(k)))), d.has("diplomacy") and d.has("achievements") and d.has("heraldry") and d.has("events"))
		step = 2
		sg.load_game("compat")
		t0 = f
	if step == 2 and f - t0 == 60:
		check("rechargée : niveau %d, %d or" % [p.level, p.inventory.count(items().get_item("piece_or"))], p.level == 9 and p.inventory.count(items().get_item("piece_or")) == 321)
		sg.delete("compat")
		print("RÉSULTAT : " + ("tout est bon" if ok else "ÉCHECS"))
		return true
	return f > 6000
