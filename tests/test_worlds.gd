extends SceneTree
## Mondes : jusqu'à 100 mondes, chacun avec ses options (nom, commandes autorisées, difficulté, raids,
## monstres la nuit, faim) ; on les modifie et on les supprime depuis la liste des mondes.
## Et la sauvegarde depuis le menu pause ne fait plus rien planter. Captures wo_XX_nom.png.
var f := 0
var ok := true
var sg
var step := 0
var wait := 0
var panel
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/wo_"
var backup := {}

func check(name: String, cond: bool) -> void:
	print(("  OK  " if cond else "  ÉCHEC  ") + name)
	ok = ok and cond

func shot(n):
	root.get_viewport().get_texture().get_image().save_png(out + n)
	print("saved ", n)

## Un faux monde sauvegardé (sans passer par une partie).
func fake_world(slot: String, name: String, opts: Dictionary, t: int) -> void:
	var o: Dictionary = sg.WORLD_DEFAULTS.duplicate()
	for k in opts:
		o[k] = opts[k]
	o.name = name
	var d := {"version": 1, "world_opts": o, "info": {"hero": "Selka", "race": "Humain", "class": "Guerrier", "level": 7, "kingdom": "Hameau",
		"zone": "Prairie", "time": t, "date": "2026-10-04T14:%02d:00" % (t % 60), "play_time": 3600 + t, "difficulty": int(o.difficulty), "name": name}}
	DirAccess.make_dir_recursive_absolute(sg.DIR)
	var fa := FileAccess.open(sg.path_of(slot), FileAccess.WRITE)
	fa.store_string(JSON.stringify(d))
	fa.close()

func _initialize():
	pass

func _process(_d) -> bool:
	f += 1
	if wait > 0:
		wait -= 1
		return false
	match step:
		0:
			if f < 5:
				return false
			sg = root.get_node("SaveGame")
			# on met de côté les vraies sauvegardes de cette machine
			for s in Array(range(1, 101)).map(func(i): return str(i)) + ["auto"]:
				if sg.has_save(s):
					backup[s] = FileAccess.get_file_as_string(sg.path_of(s))
					sg.delete(s)
			fake_world("1", "Royaume du Nord", {"cheats": true}, 1000)
			fake_world("2", "Île paisible", {"raids": false, "night_monsters": false, "hunger": false, "difficulty": 0}, 2000)
			fake_world("5", "Défi", {"difficulty": 2}, 3000)
			var ws: Array = sg.worlds()
			check("3 mondes listés (%d)" % ws.size(), ws.size() == 3)
			check("le plus récent d'abord (%s)" % ws[0].opts.name, ws[0].opts.name == "Défi")
			check("premier emplacement libre : 3 (%s)" % sg.free_slot(), sg.free_slot() == "3")
			check("Continuer : le plus récent (%s)" % sg.latest_slot(), sg.latest_slot() == "5")
			sg.set_world_opts("2", {"name": "Île des fleurs", "cheats": true})
			var d2: Dictionary = sg.world_opts_of(sg.read("2"), "2")
			check("options modifiées (%s, commandes %s)" % [d2.name, str(d2.cheats)], d2.name == "Île des fleurs" and d2.cheats and not d2.raids)
			# options du monde en cours
			sg.world_opts = {"cheats": false, "raids": false, "hunger": false, "night_monsters": true}
			check("commandes interdites dans ce monde", not sg.cheats_allowed())
			check("raids coupés, faim coupée", not sg.world_flag("raids") and not sg.world_flag("hunger") and sg.world_flag("night_monsters"))
			sg.world_opts = {}
			check("partie sans monde (tests) : tout est permis", sg.cheats_allowed() and sg.world_flag("raids"))
			change_scene_to_file("res://scenes/ui/title_screen.tscn")
			step = 1; wait = 40
		1:
			current_scene._load()
			for n in current_scene.find_children("*", "Control", true, false):
				if n.has_method("_world_card"):
					panel = n
			step = 2; wait = 10
		2:
			shot("01_liste.png")
			var opt = load("res://scenes/ui/world_options_panel.gd").new()
			opt.creating = true
			panel.add_child(opt)
			step = 3; wait = 10
		3:
			shot("02_creer.png")
			for c in panel.get_children():
				if c is Control and c.has_signal("done"):
					c.queue_free()
			# supprimer : il faut confirmer
			panel._selected = "5"
			panel._delete()
			check("premier clic : on demande confirmation", sg.has_save("5") and panel._confirm_delete == "5")
			step = 4; wait = 5
		4:
			shot("03_confirmer.png")
			panel._delete()
			check("monde supprimé", not sg.has_save("5") and sg.worlds().size() == 2)
			# 100 mondes au plus
			for i in range(1, 101):
				if not sg.has_save(str(i)):
					fake_world(str(i), "M%d" % i, {}, i)
			check("100 mondes : plus d'emplacement libre", sg.free_slot() == "" and not sg.create_world({}))
			panel.refresh()
			check("bouton Créer grisé à 100 mondes", panel._buttons.create.disabled)
			for i in range(1, 101):
				sg.delete(str(i))
			for s in backup:
				var fa := FileAccess.open(sg.path_of(s), FileAccess.WRITE)
				fa.store_string(backup[s])
				fa.close()
			print("RÉSULTAT : ", "tout est bon" if ok else "échec")
			return true
	return false
