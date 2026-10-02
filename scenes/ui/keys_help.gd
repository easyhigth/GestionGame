class_name KeysHelp
extends PanelContainer
## Aide-mémoire des touches (F2) : un petit cadre à gauche de l'écran avec les touches principales,
## telles que le joueur les a réglées (fenêtre Commandes → Personnaliser).

const SHOWN := [["move_up", "Avancer"], ["jump", "Sauter"], ["dash", "Roulade"], ["attack", "Frapper"], ["block", "Garde"],
	["skill", "Compétence"], ["interact", "Parler / utiliser"], ["eat", "Manger"], ["potion", "Potion"],
	["inventory", "Inventaire"], ["world_map", "Carte"], ["build_mode", "Construire"], ["kingdom", "Royaume"],
	["journal", "Journal"], ["diplomacy", "Diplomatie"], ["familiar_order", "Familiers"], ["achievements", "Succès"], ["crafts", "Métiers"]]

var _grid: GridContainer


func _ready() -> void:
	add_to_group("keys_help")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UiTheme.small_frame(10))
	set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	position = Vector2(-10, -160)
	var v := VBoxContainer.new()
	add_child(v)
	v.add_child(MenuKit.label("Touches (F2 : cacher)", 11, MenuKit.C_GOLD))
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 10)
	v.add_child(_grid)
	hide()


func refresh() -> void:
	for c in _grid.get_children():
		c.queue_free()
	for r in SHOWN:
		_grid.add_child(MenuKit.label(KeyBindings.key_text(r[0]), 11, Color("fff2c8")))
		_grid.add_child(MenuKit.label(r[1], 11, MenuKit.C_TEXT))
	_grid.add_child(MenuKit.label("Entrée", 11, Color("fff2c8")))
	_grid.add_child(MenuKit.label("Terminal (/aide)", 11, MenuKit.C_TEXT))
	reset_size()
	# à gauche, sous le guide (la droite est prise par la carte, l'horloge et l'histoire)
	var vp := get_viewport_rect().size
	position = Vector2(10, clampf(vp.y - size.y - 130.0, 285.0, vp.y))


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("keys_help"):
		toggle()
		get_viewport().set_input_as_handled()
