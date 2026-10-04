class_name WorldOptionsPanel
extends Control
## Options d'un monde : à sa création (nom, graine, difficulté, commandes...) ou pour le modifier ensuite.

signal done(opts: Dictionary)

var creating := true
var opts: Dictionary = {}
var _name: LineEdit
var _seed: LineEdit
var _diff: OptionButton
var _checks := {}

const FLAGS := [["cheats", "Commandes autorisées (triches : /vol, /kit, /donner...)"], ["raids", "Raids sur le village"],
	["night_monsters", "Monstres la nuit"], ["hunger", "Faim"]]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	if opts.is_empty():
		opts = SaveGame.WORLD_DEFAULTS.duplicate()
		opts.name = "Monde %s" % SaveGame.free_slot()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := MenuKit.panel(self, 460)
	box.add_child(MenuKit.title("Créer un monde" if creating else "Options du monde", 22))
	box.add_child(MenuKit.label("Nom du monde", 12, MenuKit.C_DIM))
	_name = LineEdit.new()
	_name.text = str(opts.get("name", ""))
	_name.custom_minimum_size = Vector2(420, 30)
	_name.max_length = 32
	box.add_child(_name)
	if creating:
		box.add_child(MenuKit.label("Graine (vide : au hasard ; un mot ou un nombre redonne le même monde)", 11, MenuKit.C_DIM))
		_seed = LineEdit.new()
		_seed.placeholder_text = "au hasard"
		_seed.custom_minimum_size = Vector2(420, 30)
		box.add_child(_seed)
	var dr := HBoxContainer.new()
	dr.add_child(MenuKit.label("Difficulté  ", 13))
	_diff = OptionButton.new()
	for n in SaveGame.DIFFICULTY_NAMES:
		_diff.add_item(n)
	_diff.selected = clampi(int(opts.get("difficulty", 1)), 0, 2)
	dr.add_child(_diff)
	box.add_child(dr)
	for f in FLAGS:
		var cb := CheckBox.new()
		cb.text = f[1]
		cb.button_pressed = bool(opts.get(f[0], true))
		cb.add_theme_font_size_override("font_size", 13)
		box.add_child(cb)
		_checks[f[0]] = cb
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	var ok := MenuKit.button("Créer le monde" if creating else "Enregistrer", 200, 14)
	ok.pressed.connect(_ok)
	row.add_child(ok)
	var cancel := MenuKit.button("Annuler", 140, 14)
	cancel.pressed.connect(queue_free)
	row.add_child(cancel)
	box.add_child(row)
	_name.grab_focus.call_deferred()


func _ok() -> void:
	var out := opts.duplicate()
	out.name = _name.text.strip_edges() if _name.text.strip_edges() != "" else str(opts.get("name", "Monde"))
	out.difficulty = _diff.selected
	for k in _checks:
		out[k] = (_checks[k] as CheckBox).button_pressed
	if creating and _seed:
		out.seed = _seed.text.strip_edges()
	done.emit(out)
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
