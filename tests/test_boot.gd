extends SceneTree
## Le vrai démarrage du jeu : écran titre -> « Nouvelle partie » -> création du héros -> écran de chargement -> jeu,
## puis « Continuer » sur une sauvegarde d'avant le monde immense (640 × 640 m). Mesures en temps réel.
var f := 0
var ok := true
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/bo_"
var step := 0
var t0 := 0
var t_title := 0
var saw_loading := false
var old_pos := Vector3.ZERO
var load_frames := 0
var load_values := {}
var load_stages := {}

func _initialize():
	t0 = Time.get_ticks_msec()
	load("res://scenes/ui/loading_screen.gd").force_background = true
	# une sauvegarde « ancienne » : sans taille de monde, comme avant le monde immense
	change_scene_to_file("res://scenes/ui/title_screen.tscn")

func check(name: String, cond: bool) -> void:
	print(("  OK  " if cond else "  ÉCHEC  ") + name)
	ok = ok and cond

func shot(n):
	root.get_viewport().get_texture().get_image().save_png(out + n)

func now() -> float:
	return (Time.get_ticks_msec() - t0) / 1000.0

func press(text: String) -> bool:
	for b in root.find_children("*", "Button", true, false):
		if (b as Button).text == text and b.is_visible_in_tree():
			(b as Button).pressed.emit()
			return true
	return false

func scene() -> String:
	return current_scene.scene_file_path if current_scene else ""

var wait := 0.0
func _process(d) -> bool:
	f += 1
	wait += d
	if scene().ends_with("loading_screen.tscn"):
		saw_loading = true
		load_frames += 1
		load_values[snappedf(current_scene._shown, 0.05)] = true
		load_stages[current_scene._stage] = true
		if load_frames == 40:
			shot("02_chargement.png")
	match step:
		0:
			if scene().ends_with("title_screen.tscn") and f > 3:
				t_title = Time.get_ticks_msec()
				check("l'écran titre s'affiche vite (%.1f s)" % now(), now() < 20.0)
				var w = get_first_node_in_group("world")
				check("décor de l'écran titre : un petit monde (%s)" % w.world_size, w.world_size.x <= 400)
				step = 1; wait = 0.0
		1:
			if wait > 1.5:
				shot("01_titre.png")
				check("bouton « Nouvelle partie »", press("Nouvelle partie"))
				step = 2; wait = 0.0
		2:
			if wait > 1.0 and current_scene and current_scene.has_method("_start"):
				current_scene._start()
				t0 = Time.get_ticks_msec()
				step = 3; wait = 0.0
		3:
			var p = get_first_node_in_group("player")
			if scene().ends_with("main.tscn") and p and f > 0:
				check("un écran de chargement pendant la création du monde", saw_loading)
				check("l'écran de chargement reste vivant (%d images)" % load_frames, load_frames >= 20)
				check("la barre de progression avance (%d paliers)" % load_values.size(), load_values.size() >= 8)
				check("les étapes s'affichent : %s" % ", ".join(load_stages.keys().slice(0, 6)), load_stages.size() >= 4)
				check("la partie commence (%.1f s après « Commencer l'aventure »)" % now(), true)
				check("monde immense", get_first_node_in_group("world").world_size.x >= 1500)
				step = 4; wait = 0.0
		4:
			if wait > 3.0:
				shot("03_jeu.png")
				# une sauvegarde de l'ancienne version : sans taille de monde
				var sg = root.get_node("SaveGame")
				sg.save_game("3")
				var txt := FileAccess.get_file_as_string(sg.path_of("3"))
				var js = JSON.parse_string(txt)
				js.world.erase("size")
				var fa := FileAccess.open(sg.path_of("3"), FileAccess.WRITE)
				fa.store_string(JSON.stringify(js))
				fa.close()
				old_pos = get_first_node_in_group("player").global_position
				saw_loading = false
				sg.load_game("3")
				step = 5; wait = 0.0
		5:
			var w = get_first_node_in_group("world")
			if scene().ends_with("main.tscn") and w and wait > 2.0:
				check("ancienne sauvegarde : écran de chargement aussi", saw_loading)
				check("ancienne sauvegarde : son monde de 640 m est recréé (%s)" % w.world_size, w.world_size == Vector2i(640, 640))
				step = 6; wait = 0.0
		6:
			if wait > 2.0:
				shot("04_ancienne_partie.png")
				print("RÉSULTAT : ", "tout est bon" if ok else "échec")
				return true
	if now() > 280.0:
		check("le jeu a démarré à temps (étape %d)" % step, false)
		print("RÉSULTAT : échec")
		return true
	return false
