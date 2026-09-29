class_name OptionsPanel
extends Control
## Options : difficulté, plein écran, distance de la caméra, volume, aide à l'écran, sauvegarde automatique.

signal closed

var _box: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box = MenuKit.panel(self, 480)
	_build()


func _row(text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := MenuKit.label(text, 14)
	l.custom_minimum_size = Vector2(210, 0)
	row.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	_box.add_child(row)


func _build() -> void:
	var o: Dictionary = SaveGame.options
	_box.add_child(MenuKit.title("Options", 22))
	var diff := OptionButton.new()
	for i in SaveGame.DIFFICULTY_NAMES.size():
		diff.add_item(SaveGame.DIFFICULTY_NAMES[i])
	diff.select(int(o.difficulty))
	diff.item_selected.connect(func(i): o.difficulty = i; _save())
	_row("Difficulté", diff)
	var help := MenuKit.label("Facile : monstres moins résistants et raids plus rares.  Difficile : monstres plus forts, raids plus fréquents.", 11, MenuKit.C_DIM)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size = Vector2(430, 0)
	_box.add_child(help)
	var cam := HSlider.new()
	cam.min_value = 0.6
	cam.max_value = 1.6
	cam.step = 0.05
	cam.value = float(o.camera_distance)
	cam.value_changed.connect(func(v): o.camera_distance = v; _save())
	_row("Distance de la caméra", cam)
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = float(o.volume)
	vol.value_changed.connect(func(v): o.volume = v; _save())
	_row("Volume", vol)
	for pair in [["fullscreen", "Plein écran"], ["show_help", "Aide des touches à l'écran"], ["autosave", "Sauvegarde automatique (5 min)"]]:
		var cb := CheckButton.new()
		cb.button_pressed = bool(o[pair[0]])
		var key: String = pair[0]
		cb.toggled.connect(func(on): o[key] = on; _save())
		_row(pair[1], cb)
	var back := MenuKit.button("Retour", 200)
	back.pressed.connect(_close)
	var c := CenterContainer.new()
	c.add_child(back)
	_box.add_child(c)
	diff.grab_focus.call_deferred()


func _save() -> void:
	SaveGame.save_options()


func _close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
