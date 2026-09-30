class_name FishingBar
extends Control
## Mini-jeu de pêche en bas de l'écran : « Ça mord ! » puis une barre où un curseur va et vient ;
## appuie sur V quand il est dans la zone verte.

const W := 320.0
const H := 18.0

var fishing: Fishing
var _title: Label
var _bar: ColorRect
var _zone: ColorRect
var _cursor: ColorRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -W / 2.0
	offset_right = W / 2.0
	offset_top = -178
	offset_bottom = -120
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 14)
	_title.add_theme_color_override("font_color", Color("fff2c8"))
	_title.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03))
	_title.add_theme_constant_override("outline_size", 4)
	_title.size = Vector2(W, 20)
	add_child(_title)
	_bar = ColorRect.new()
	_bar.color = Color(0.08, 0.1, 0.16, 0.85)
	_bar.position = Vector2(0, 26)
	_bar.size = Vector2(W, H)
	add_child(_bar)
	_zone = ColorRect.new()
	_zone.color = Color(0.4, 0.85, 0.45, 0.9)
	_bar.add_child(_zone)
	_cursor = ColorRect.new()
	_cursor.color = Color(1, 0.95, 0.7)
	_cursor.size = Vector2(4, H + 8)
	_bar.add_child(_cursor)
	hide()


func _process(_delta: float) -> void:
	if fishing == null or not is_instance_valid(fishing):
		fishing = get_tree().get_first_node_in_group("fishing") as Fishing
		if fishing == null:
			return
	match fishing.state:
		"touche":
			show()
			_title.text = "Ça mord ! Appuie sur V"
			_bar.visible = false
		"combat":
			show()
			_bar.visible = true
			var it := Items.get_item(fishing.fish)
			_title.text = "%s : V quand le curseur est dans le vert" % (it.display_name if it else "?")
			_zone.position = Vector2(fishing.zone.x * W, 0)
			_zone.size = Vector2((fishing.zone.y - fishing.zone.x) * W, H)
			_cursor.position = Vector2(fishing.cursor * W - 2.0, -4)
		"attente":
			show()
			_bar.visible = false
			_title.text = "Tu attends que ça morde..."
		_:
			hide()
