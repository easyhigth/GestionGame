class_name SaveSlotsPanel
extends Control
## Liste des emplacements de sauvegarde (3 + automatique), pour sauvegarder ou charger.

signal chosen(slot: String)
signal cancelled

## "save" ou "load".
var mode := "load"
var _box: VBoxContainer
var _confirm := ""


func _init(m := "load") -> void:
	mode = m


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box = MenuKit.panel(self, 560)
	refresh()


func refresh() -> void:
	for c in _box.get_children():
		c.queue_free()
	_box.add_child(MenuKit.title("Sauvegarder la partie" if mode == "save" else "Charger une partie", 22))
	var slots: Array = SaveGame.SLOTS.duplicate()
	if mode == "load":
		slots.append(SaveGame.AUTO)
	var first: Button = null
	for s in slots:
		var info := SaveGame.slot_info(s)
		var b := MenuKit.button("", 520, 13)
		b.custom_minimum_size = Vector2(520, 58)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var name := "Sauvegarde automatique" if s == SaveGame.AUTO else "Emplacement %s" % s
		if info.is_empty():
			b.text = "  %s  —  vide" % name
			b.disabled = mode == "load"
		else:
			b.text = "  %s  —  %s, %s %s niv. %d\n  %s  ·  %s  ·  %s de jeu  ·  %s" % [name, info.hero, info.race, info.get("class", ""),
				int(info.level), info.kingdom, info.zone, MenuKit.format_time(int(info.play_time)), str(info.date).replace("T", " ").substr(0, 16)]
		if mode == "save" and _confirm == s:
			b.text = "  Écraser « %s » ? Clique encore pour confirmer." % name
			b.add_theme_color_override("font_color", MenuKit.C_BAD)
		b.pressed.connect(_on_slot.bind(s, info.is_empty()))
		_box.add_child(b)
		if first == null and not b.disabled:
			first = b
	var back := MenuKit.button("Retour", 200)
	back.pressed.connect(func(): cancelled.emit(); queue_free())
	_box.add_child(back)
	(first if first else back).grab_focus.call_deferred()


func _on_slot(s: String, empty: bool) -> void:
	if mode == "save" and not empty and _confirm != s:
		_confirm = s
		refresh()
		return
	chosen.emit(s)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancelled.emit()
		queue_free()
