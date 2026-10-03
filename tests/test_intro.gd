extends SceneTree
var f := 0
var p; var w; var items; var hud; var intro
var ok := true
var game_ms := 0.0
var out := (OS.get_environment("TEST_SHOTS") if OS.get_environment("TEST_SHOTS") != "" else OS.get_user_data_dir()) + "/in_"

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
	root.get_node("GameState").play_intro = true
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


func _process(_d) -> bool:
	f += 1
	game_ms += _d * 1000.0
	if f == 6:
		p = get_first_node_in_group("player"); w = get_first_node_in_group("world"); hud = get_first_node_in_group("hud")
		get_first_node_in_group("raids").enabled = false
		get_first_node_in_group("weather").set_kind("clair")
		get_first_node_in_group("day_cycle").hour = 9.0
		intro = get_first_node_in_group("intro")
		check("nouvelle partie : l'introduction démarre", intro != null and intro.visible)
		check("le reste de l'interface est caché (barres du bas, compétence)", hud._dock.modulate.a < 0.01)
		check("le héros attend (commandes bloquées)", p.ui_open)
		check("plus d'introduction en attente", not root.get_node("GameState").play_intro)
		start("a")
	if later("a", 1500):
		check("la légende s'écrit en calligraphie", intro._text.modulate.a > 0.5 and intro._text.text.begins_with("Il y a bien longtemps"))
		shot("01_legende.png")
		start("b")
	if later("b", 16500):
		check("vue du cristal d'Orvane", intro._cam != null and intro._cam.current)
		shot("02_cristal.png")
		start("c")
	if later("c", 6200):
		check("la caméra rejoint le héros (« %s »)" % intro._sub.text, intro._sub.text.contains("Selka"))
		shot("03_heros.png")
		start("d")
	if later("d", 5400):
		check("titre : « %s » / « %s »" % [intro._title.text, intro._act.text], intro._title.text == "L'Éveil du Royaume" and intro._title.modulate.a > 0.5)
		shot("04_titre.png")
		start("e")
	if later("e", 4000):
		check("l'introduction est finie", not is_instance_valid(intro) or intro.is_queued_for_deletion() or intro._done)
		check("caméra rendue au héros", p.camera.current)
		check("commandes rendues", not p.ui_open)
		check("interface de retour", hud.guide.modulate.a > 0.9 and hud._dock.modulate.a > 0.9)
		shot("05_jeu.png")
		# revoir l'introduction, puis la passer (Échap)
		intro = hud.play_intro()
		start("g")
	if later("g", 2000):
		var ev := InputEventAction.new(); ev.action = "ui_cancel"; ev.pressed = true
		intro._unhandled_input(ev)
		check("Échap : introduction passée", intro._done)
		start("h")
	if later("h", 1500):
		check("après l'avoir passée : caméra et commandes rendues", p.camera.current and not p.ui_open)
		print("RÉSULTAT : ", "tout est bon" if ok else "échec")
		return true
	return false
