class_name KeysHelp
extends PanelContainer
## Aide-mémoire des touches (F1) : un petit cadre à gauche de l'écran avec les touches principales,
## telles que le joueur les a réglées (fenêtre Commandes → Personnaliser).

## [touche ({action} ou texte), rôle] par famille ; les couleurs sont celles du plan du clavier (Commandes).
const SHOWN := [
	["Se déplacer", 0, [["{move_up} {move_left} {move_down} {move_right}", "Marcher"], ["{jump}", "Sauter"], ["{dash}", "Roulade"], ["{camera_view}", "Vue"]]],
	["Combattre", 1, [["Clic gauche", "Frapper"], ["Clic droit", "Garde"], ["1 … 0", "Sorts"], ["{skill}", "Unique"], ["{lock_on}", "Viser"], ["{potion}", "Potion"]]],
	["Agir", 2, [["{interact}", "Utiliser · parler"], ["{hand_toggle}", "Objet en main"], ["Clic droit", "Poser (en main)"], ["{dig}", "Creuser"], ["{eat}", "Manger"]]],
	["Menus", 3, [["{inventory}", "Sac"], ["{world_map}", "Carte"], ["{build_mode}", "Bâtir"], ["{kingdom}", "Royaume"], ["{journal}", "Journal"], ["{talents}", "Talents"], ["{diplomacy}", "Nations"], ["{achievements}", "Succès"]]],
]

var _grid: HBoxContainer


func _ready() -> void:
	add_to_group("keys_help")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UiTheme.small_frame(10))
	var v := VBoxContainer.new()
	add_child(v)
	v.add_child(MenuKit.label("Touches ({keys_help} : cacher · Échap → Commandes : tout)", 11, MenuKit.C_GOLD))
	_grid = HBoxContainer.new()
	_grid.add_theme_constant_override("separation", 18)
	v.add_child(_grid)
	hide()


func refresh() -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	var cols: Array[GridContainer] = []
	for n in 2:
		var g := GridContainer.new()
		g.columns = 2
		g.add_theme_constant_override("h_separation", 8)
		g.add_theme_constant_override("v_separation", -2)
		_grid.add_child(g)
		cols.append(g)
	for f in SHOWN.size():
		var fam: Array = SHOWN[f]
		var g := cols[f / 2]
		var col: Color = KeyboardMap.FAMILIES[fam[1]][1]
		g.add_child(MenuKit.label(fam[0], 10, col))
		g.add_child(Control.new())
		for r in fam[2]:
			g.add_child(MenuKit.label(r[0], 10, col.lightened(0.45)))
			g.add_child(MenuKit.label(r[1], 10, MenuKit.C_TEXT))
	reset_size()
	# à gauche, sous le guide (la droite est prise par la carte, l'horloge et l'histoire)
	size = Vector2.ZERO
	reset_size()
	# à gauche, juste sous le cadre du guide (s'il est là)
	var g := get_tree().get_first_node_in_group("guide") as Control
	var y := 160.0
	if g and g.visible and g.get_parent() == get_parent():
		y = g.position.y + g.size.y + 6.0
	position = Vector2(10, y)


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("keys_help"):
		toggle()
		get_viewport().set_input_as_handled()
