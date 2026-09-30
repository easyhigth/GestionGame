class_name StoryDialog
extends Control
## Dialogue de l'histoire : portrait de celui qui parle, son nom, le texte page par page (E, Espace ou clic),
## et parfois un choix à la fin.

var player: Player
var _id := ""
var _npc: Node3D
var _page := 0
var _pages: Array = []
var _choices: Array = []
var _box: VBoxContainer
var _name: Label
var _text: Label
var _buttons: HBoxContainer
var _portrait_rect: TextureRect
var _vp: SubViewport
var _cam: Camera3D
var _char: VoxelCharacter
var _portraits := {}
## Dialogue « libre » (quêtes secondaires) : appelé à la fermeture avec le choix, au lieu de l'histoire.
var _on_done: Callable   # qui -> [modèle, bibliothèque, objets affichés, couleurs]


func _ready() -> void:
	add_to_group("story_dialog")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", MenuKit.style(Color(MenuKit.C_BG, 0.96), MenuKit.C_FRAME, 2, 6, 16))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -400
	panel.offset_right = 400
	panel.offset_top = -230
	panel.offset_bottom = -30
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	# portrait : une petite scène 3D avec le personnage
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", MenuKit.style(Color("141018"), MenuKit.C_FRAME, 2, 4, 2))
	row.add_child(frame)
	_vp = SubViewport.new()
	_vp.size = Vector2i(150, 150)
	_vp.own_world_3d = true
	_vp.transparent_bg = false
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2a2030")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.82, 0.9)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 25, 0)
	_vp.add_child(sun)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 1.1
	_vp.add_child(_cam)
	_portrait_rect = TextureRect.new()
	_portrait_rect.texture = _vp.get_texture()
	_portrait_rect.custom_minimum_size = Vector2(150, 150)
	frame.add_child(_portrait_rect)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_box)
	_name = MenuKit.label("", 18, MenuKit.C_GOLD)
	_box.add_child(_name)
	_text = MenuKit.label("", 14, MenuKit.C_TEXT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(580, 96)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_box.add_child(_text)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_END
	_buttons.add_theme_constant_override("separation", 8)
	_box.add_child(_buttons)


func _story() -> Story:
	return get_tree().get_first_node_in_group("story") as Story


func open(id: String, npc: Node3D) -> void:
	if player == null or player.ui_open or not Story.DIALOGS.has(id):
		return
	_id = id
	_npc = npc
	_pages = Story.DIALOGS[id].pages
	_choices = Story.DIALOGS[id].get("choices", [])
	_page = 0
	get_parent().move_child(self, get_parent().get_child_count() - 1)
	Sound.ui("ui_open")
	show()
	player.ui_open = true
	get_tree().paused = true
	_show_page()


## Ouvre un dialogue qui ne vient pas de l'histoire : data = {pages, choices}.
func open_custom(id: String, data: Dictionary, npc: Node3D, on_done: Callable) -> void:
	if player == null or player.ui_open:
		return
	_id = id
	_npc = npc
	_pages = data.pages
	_choices = data.get("choices", [])
	_page = 0
	_on_done = on_done
	get_parent().move_child(self, get_parent().get_child_count() - 1)
	Sound.ui("ui_open")
	show()
	player.ui_open = true
	get_tree().paused = true
	_show_page()


func _close(choice: String) -> void:
	hide()
	get_tree().paused = false
	if player:
		player.ui_open = false
	if _on_done.is_valid():
		var cb := _on_done
		_on_done = Callable()
		cb.call(choice)
		return
	var st := _story()
	if st:
		st.dialog_done(_id, choice)


func _show_page() -> void:
	var p: Array = _pages[_page]
	var who: String = p[0]
	var hero_name: String = player.profile.hero_name if player.profile else "Héros"
	if who == "hero":
		_name.text = hero_name
		_name.add_theme_color_override("font_color", Color("fff2c8"))
		_set_portrait(player)
	else:
		var info: Dictionary = Story.NPCS.get(who, {})
		_name.text = "%s %s" % [info.get("name", who), info.get("title", "")]
		_name.add_theme_color_override("font_color", info.get("color", MenuKit.C_GOLD))
		var st := _story()
		var n: Node3D = st.npc(who) if st else null
		_set_portrait(n if n else _npc)
	_text.text = String(p[1]).replace("{hero}", hero_name)
	for c in _buttons.get_children():
		c.queue_free()
	if _page < _pages.size() - 1:
		var b := MenuKit.button("Suite (E)", 140, 13)
		b.pressed.connect(_next)
		_buttons.add_child(b)
		b.grab_focus.call_deferred()
	elif _choices.is_empty():
		var b := MenuKit.button("Fermer (E)", 140, 13)
		b.pressed.connect(_close.bind(""))
		_buttons.add_child(b)
		b.grab_focus.call_deferred()
	else:
		var first: Button = null
		for ch in _choices:
			var b := MenuKit.button(ch[0], 250, 12)
			b.pressed.connect(_close.bind(ch[1]))
			_buttons.add_child(b)
			if first == null:
				first = b
		first.grab_focus.call_deferred()


func _next() -> void:
	_page += 1
	Sound.ui("ui_click")
	_show_page()


## Le portrait : une copie du personnage (modèle, équipement, couleurs), vue de face.
func _set_portrait(src: Node3D) -> void:
	if _char:
		_char.queue_free()
		_char = null
	var vis := src.get("visual") as VoxelCharacter if src else null
	if vis == null:
		return
	_char = VoxelCharacter.new()
	_char._colors = vis._colors.duplicate()
	_vp.add_child(_char)
	_char.set_equipment_library(vis.equipment_library)
	_char.set_model(vis.model)
	for slot in vis._shown:
		if slot != ItemData.Slot.MAIN_HAND and slot != ItemData.Slot.OFF_HAND:
			_char.show_equipment(slot, vis._shown[slot])
	_char.rotation.y = 0.35
	var head := _char._bones.get("Head") as Node3D
	var hy := head.global_position.y + 0.12 if head else 1.45
	_cam.position = Vector3(0, hy, 3.0)
	_cam.look_at(Vector3(0, hy, 0))


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("jump"):
		if _page < _pages.size() - 1:
			_next()
		elif _choices.is_empty():
			_close("")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		# on ne peut pas sauter un choix
		if _choices.is_empty() or _page < _pages.size() - 1:
			_close("" if _choices.is_empty() else _choices[0][1])
		get_viewport().set_input_as_handled()
