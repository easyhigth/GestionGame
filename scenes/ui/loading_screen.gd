class_name LoadingScreen
extends Control
## Écran de chargement, façon Minecraft : un fond de blocs sombres, l'étape en cours (« Fondation de Hrodgard... »),
## une barre de progression et son pourcentage, une astuce. Le monde (relief, capitales, routes, lieux) se calcule
## en arrière-plan pendant que l'écran reste vivant ; puis la 3D se bâtit et la partie commence.

const SCENE := "res://scenes/ui/loading_screen.tscn"
const GAME := "res://scenes/main.tscn"
const TIPS := ["Entrée ou / : le terminal de commandes (/aide).", "M : la carte du monde. Les obélisques permettent d'y voyager.",
	"Les routes pavées mènent du village aux cinq capitales.", "Une taverne dans chaque capitale : un repas le jour, une chambre la nuit.",
	"Au pied des falaises, des grottes cachent du fer, de l'or et du mithril.", "F2 : l'aide-mémoire des touches.",
	"Les châteaux abandonnés sont hantés par des morts-vivants... et gardent un trésor.", "Les épaves échouées sur les plages cachent un coffre.",
	"En guerre, tu peux assiéger une capitale depuis le panneau de la diplomatie (Y).", "Les citadins marqués « ! » ont une quête pour toi."]
const BAR_W := 620.0
const BAR_H := 22.0

static var _target := ""
static var _title := ""
## Les tests automatiques (SYNC_LOADING=1, voir tests/run_tests.sh) calculent le monde d'un bloc, comme avant ;
## test_boot force le calcul en arrière-plan pour vérifier l'écran.
static var force_background := false

var _frames := 0
var _phase := 0          # 0 : premier affichage ; 1 : calcul en arrière-plan ; 2 : la 3D se bâtit
var _task := -1
var _main: Node
var _world: WorldGenerator
var _shown := 0.0
var _wait := 0
var _dots := 0.0
var _stage := ""
var _stage_label: Label
var _pct_label: Label
var _bar: _Bar


## Affiche l'écran de chargement, puis lance la scène (la partie : le monde se calcule ici, en arrière-plan).
static func go(tree: SceneTree, target: String, title: String) -> void:
	_target = target
	_title = title
	tree.change_scene_to_file(SCENE)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := _Blocks.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(box)
	box.add_child(_label(_title if _title != "" else "Chargement...", "title", 42, Color("e8c870")))
	_stage_label = _label("Préparation...", "body", 19, Color(0.92, 0.88, 0.8))
	box.add_child(_stage_label)
	var bar_row := CenterContainer.new()
	box.add_child(bar_row)
	_bar = _Bar.new()
	_bar.custom_minimum_size = Vector2(BAR_W, BAR_H)
	bar_row.add_child(_bar)
	_pct_label = _label("0 %", "bold", 16, Color(0.95, 0.85, 0.55))
	box.add_child(_pct_label)
	box.add_child(_label("Astuce : " + TIPS[randi() % TIPS.size()], "body", 15, Color(0.7, 0.66, 0.6)))


func _label(text: String, font: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UiTheme.font(font))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _process(delta: float) -> void:
	_frames += 1
	_dots += delta
	match _phase:
		0:
			# deux images pour que l'écran soit bien affiché avant de commencer
			if _frames >= 2:
				_start()
		1:
			if _world:
				_stage = _world.gen_stage
				if WorkerThreadPool.is_task_completed(_task):
					WorkerThreadPool.wait_for_task_completion(_task)
					_task = -1
					_phase = 2
					_stage = "Construction du monde en 3D..."
					_wait = 3
		2:
			# cet écran reste affiché pendant que la 3D se bâtit (quelques secondes sans nouvelle image)
			_wait -= 1
			if _wait <= 0:
				_finish()
				return
	var goal := 0.0
	if _world:
		goal = _world.gen_progress if _phase == 1 else 0.96
	if goal > _shown:
		_shown = move_toward(_shown, goal, delta * 0.8)
	_bar.value = _shown
	_bar.queue_redraw()
	_pct_label.text = "%d %%" % roundi(_shown * 100.0)
	if _stage != "":
		var n := int(_dots * 2.5) % 4
		_stage_label.text = _stage.trim_suffix("...") + ".".repeat(n) + " ".repeat(3 - n)


## Prépare la partie : la scène du jeu est créée hors de l'arbre, son monde se calcule dans un autre fil.
func _start() -> void:
	_phase = 1
	if _target != "" and _target != GAME:
		get_tree().change_scene_to_file(_target)
		return
	_main = (load(GAME) as PackedScene).instantiate()
	_world = _main.get_node_or_null("World") as WorldGenerator
	if _world == null or not _world.generate_on_start:
		_world = null
		_finish()
		return
	var seed_value: int
	if SaveGame.pending_seed() >= 0:
		# une partie sauvegardée : son monde (les parties d'avant le monde immense : 640 × 640 m)
		var sz: Array = SaveGame.pending.world.get("size", [640, 640])
		_world.world_size = Vector2i(int(sz[0]), int(sz[1]))
		seed_value = SaveGame.pending_seed()
	else:
		var forced: int = GameState.world_seed
		seed_value = forced if forced >= 0 else (randi() if _world.random_seed_on_start else _world.world_seed)
	_world.prepare_generation(seed_value)
	if OS.get_environment("SYNC_LOADING") == "1" and not force_background:
		_world.generate_data()
		_finish()
		return
	_task = WorkerThreadPool.add_task(_world.generate_data, false, "Création du monde")


## Le monde est prêt : la scène du jeu entre dans l'arbre (la 3D se bâtit) et remplace l'écran de chargement.
func _finish() -> void:
	var tree := get_tree()
	if _main == null:
		tree.change_scene_to_file(GAME)
		return
	if _world:
		_world.pregenerated = true
	var m := _main
	_main = null
	tree.root.add_child(m)
	tree.current_scene = m
	queue_free()


func _exit_tree() -> void:
	# on ne quitte jamais en laissant le calcul tourner
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	if _main and is_instance_valid(_main) and not _main.is_inside_tree():
		_main.free()


## Fond de blocs sombres (terre et pierre), comme les écrans de chargement de Minecraft.
class _Blocks extends Control:
	func _draw() -> void:
		var s := 48.0
		var cols := ceili(size.x / s) + 1
		var rows := ceili(size.y / s) + 1
		for y in rows:
			for x in cols:
				var h := absf(fmod(sin(float(x) * 12.9898 + float(y) * 78.233) * 43758.5453, 1.0))
				var base := Color(0.16, 0.11, 0.08).lerp(Color(0.21, 0.15, 0.11), h)
				draw_rect(Rect2(x * s, y * s, s, s), base)
				# quelques grains, comme une texture de terre
				for k in 3:
					var gx := fmod(absf(sin(float(x * 7 + k) * 3.1 + float(y) * 1.7)) * 997.0, s - 8.0)
					var gy := fmod(absf(sin(float(y * 5 + k) * 2.3 + float(x) * 4.1)) * 991.0, s - 8.0)
					draw_rect(Rect2(x * s + gx, y * s + gy, 6, 6), base.darkened(0.25))
				draw_rect(Rect2(x * s, y * s, s, s), Color(0, 0, 0, 0.18), false, 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))


## Barre de progression : cadre doré, remplissage vert comme dans Minecraft.
class _Bar extends Control:
	var value := 0.0
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r.grow(3), Color(0.05, 0.03, 0.02))
		draw_rect(r, Color(0.12, 0.1, 0.08))
		var fill := Rect2(r.position, Vector2(r.size.x * clampf(value, 0.0, 1.0), r.size.y))
		draw_rect(fill, Color(0.36, 0.72, 0.28))
		draw_rect(Rect2(fill.position, Vector2(fill.size.x, fill.size.y * 0.4)), Color(0.5, 0.85, 0.4))
		draw_rect(r.grow(3), Color("c8a24a"), false, 2.0)
