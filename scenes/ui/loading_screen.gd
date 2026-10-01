class_name LoadingScreen
extends Control
## Écran de chargement : il s'affiche avant de lancer le jeu, puis la création du monde commence. Le monde immense
## se calcule en quelques secondes pendant lesquelles le jeu ne dessine rien : c'est cet écran qui reste visible
## (au lieu d'une fenêtre grise).

const SCENE := "res://scenes/ui/loading_screen.tscn"
const TIPS := ["Entrée ou / : le terminal de commandes (/aide).", "M : la carte du monde. Les obélisques permettent d'y voyager.",
	"Les routes pavées mènent du village aux cinq capitales.", "Une taverne dans chaque capitale : un repas le jour, une chambre la nuit.",
	"Au pied des falaises, des grottes cachent du fer, de l'or et du mithril.", "F2 : l'aide-mémoire des touches."]

static var _target := ""
static var _title := ""
var _frames := 0


## Affiche l'écran de chargement, puis change de scène.
static func go(tree: SceneTree, target: String, title: String) -> void:
	_target = target
	_title = title
	tree.change_scene_to_file(SCENE)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.05, 0.05)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	var t := Label.new()
	t.text = _title if _title != "" else "Chargement..."
	t.add_theme_font_override("font", UiTheme.font("title"))
	t.add_theme_font_size_override("font_size", 40)
	t.add_theme_color_override("font_color", Color("e8c870"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var sub := Label.new()
	sub.text = "Le royaume s'éveille : relief, capitales, routes et villages.\nCela prend quelques secondes."
	sub.add_theme_font_override("font", UiTheme.font("body"))
	sub.add_theme_font_size_override("font_size", 17)
	sub.add_theme_color_override("font_color", Color(0.85, 0.8, 0.72))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var tip := Label.new()
	tip.text = "Astuce : " + TIPS[randi() % TIPS.size()]
	tip.add_theme_font_override("font", UiTheme.font("body"))
	tip.add_theme_font_size_override("font_size", 14)
	tip.add_theme_color_override("font_color", Color(0.65, 0.6, 0.55))
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tip)
	box.position = get_viewport_rect().size / 2.0 - box.get_combined_minimum_size() / 2.0


func _process(_delta: float) -> void:
	# quelques images pour que l'écran soit bien affiché avant le long calcul du monde
	_frames += 1
	if _frames == 3:
		get_tree().change_scene_to_file(_target if _target != "" else "res://scenes/main.tscn")
