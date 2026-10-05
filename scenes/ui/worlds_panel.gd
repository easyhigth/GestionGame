class_name WorldsPanel
extends Control
## La liste des mondes (comme dans Minecraft) : jusqu'à 100 mondes, chacun avec son héros et ses options.
## Jouer, créer un monde, modifier ses options (nom, commandes autorisées, difficulté, raids, monstres la
## nuit, faim), supprimer un monde (avec confirmation).

signal closed

var _box: VBoxContainer
var _list: VBoxContainer
var _selected := ""
var _confirm_delete := ""
var _count: Label
var _buttons := {}
## Depuis le menu pause : on ne crée pas de monde, on en charge un autre.
var from_game := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box = MenuKit.panel(self, 640)
	_box.add_child(MenuKit.title("Mondes", 24))
	_count = MenuKit.label("", 11, MenuKit.C_DIM)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_count)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(620, 330)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box.add_child(sc)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list)
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	row1.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_child(row1)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_child(row2)
	for b in [["play", "Jouer", row1, _play], ["create", "Créer un monde", row1, _create],
			["edit", "Modifier", row2, _edit], ["delete", "Supprimer", row2, _delete], ["back", "Retour", row2, _close]]:
		var btn := MenuKit.button(b[1], 200 if b[2] == row1 else 150, 14)
		btn.pressed.connect(b[3])
		b[2].add_child(btn)
		_buttons[b[0]] = btn
	refresh()


func refresh() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var worlds := SaveGame.worlds()
	_count.text = "%d / %d mondes" % [worlds.size(), SaveGame.MAX_WORLDS]
	if worlds.is_empty():
		_list.add_child(MenuKit.label("Aucun monde pour l'instant : crée le premier !", 13, MenuKit.C_DIM))
		_selected = ""
	elif not worlds.any(func(w): return w.slot == _selected):
		_selected = worlds[0].slot
	for w in worlds:
		_list.add_child(_world_card(w))
	_buttons.play.disabled = _selected == ""
	_buttons.edit.disabled = _selected == "" or from_game
	_buttons.delete.disabled = _selected == "" or (from_game and _selected == SaveGame.current_slot)
	_buttons.create.disabled = worlds.size() >= SaveGame.MAX_WORLDS or from_game
	_buttons.create.tooltip_text = "100 mondes au plus : supprimes-en un." if worlds.size() >= SaveGame.MAX_WORLDS else ""
	_buttons.delete.text = "Confirmer ?" if _confirm_delete != "" and _confirm_delete == _selected else "Supprimer"
	_buttons.delete.add_theme_color_override("font_color", MenuKit.C_BAD if _confirm_delete == _selected and _selected != "" else MenuKit.C_TEXT)


func _world_card(w: Dictionary) -> Control:
	var info: Dictionary = w.info
	var opts: Dictionary = w.opts
	var sel: bool = w.slot == _selected
	var b := Button.new()
	b.custom_minimum_size = Vector2(600, 64)
	b.add_theme_stylebox_override("normal", MenuKit.style(Color(0.25, 0.2, 0.12, 0.95), MenuKit.C_GOLD, 2, 4, 6) if sel else MenuKit.card(false, 6.0))
	b.add_theme_stylebox_override("hover", UiTheme.box("card_hover", 6, Vector4(6, 4, 6, 4)))
	b.add_theme_stylebox_override("pressed", MenuKit.style(Color(0.25, 0.2, 0.12, 0.95), MenuKit.C_GOLD, 2, 4, 6))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10
	v.offset_top = 6
	b.add_child(v)
	var name_l := MenuKit.label(str(opts.get("name", "Monde")), 15, MenuKit.C_GOLD if sel else MenuKit.C_TEXT)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name_l)
	var line1 := "%s, %s %s · niveau %d · %s" % [info.get("hero", "Héros"), info.get("race", ""), info.get("class", ""), int(info.get("level", 1)),
		MenuKit.format_time(int(info.get("play_time", 0)))]
	var l1 := MenuKit.label(line1, 11, MenuKit.C_DIM)
	l1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l1)
	var flags := [SaveGame.DIFFICULTY_NAMES[clampi(int(opts.get("difficulty", 1)), 0, 2)],
		"commandes autorisées" if bool(opts.get("cheats", false)) else "sans commandes"]
	if not bool(opts.get("raids", true)):
		flags.append("sans raids")
	if not bool(opts.get("night_monsters", true)):
		flags.append("nuits paisibles")
	if not bool(opts.get("hunger", true)):
		flags.append("sans faim")
	if not bool(opts.get("tutorial", true)):
		flags.append("sans tutoriel")
	var l2 := MenuKit.label("%s · %s" % [str(info.get("date", "")).replace("T", " ").substr(0, 16), " · ".join(PackedStringArray(flags))], 10, MenuKit.C_DIM)
	l2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l2)
	var slot: String = w.slot
	b.pressed.connect(func():
		if _selected == slot:
			# deuxième clic : on joue
			_play()
			return
		_selected = slot
		_confirm_delete = ""
		refresh())
	return b


func _play() -> void:
	if _selected != "":
		SaveGame.load_game(_selected)


func _create() -> void:
	var p := WorldOptionsPanel.new()
	p.creating = true
	add_child(p)
	p.done.connect(func(opts: Dictionary):
		SaveGame.create_world(opts))


func _edit() -> void:
	if _selected == "":
		return
	var p := WorldOptionsPanel.new()
	p.creating = false
	var d := SaveGame.read(_selected)
	p.opts = SaveGame.world_opts_of(d, _selected)
	add_child(p)
	var slot := _selected
	p.done.connect(func(opts: Dictionary):
		SaveGame.set_world_opts(slot, opts)
		refresh())


func _delete() -> void:
	if _selected == "":
		return
	if _confirm_delete != _selected:
		_confirm_delete = _selected
		refresh()
		return
	SaveGame.delete(_selected)
	Sound.ui("ui_close")
	_confirm_delete = ""
	_selected = ""
	refresh()


func _close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and get_children().all(func(c): return not c is WorldOptionsPanel):
		get_viewport().set_input_as_handled()
		_close()
