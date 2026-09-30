class_name PauseMenu
extends Control
## Menu pause (Échap ou Start... Échap au clavier, bouton Menu à la manette) :
## reprendre, sauvegarder, charger, options, menu principal, quitter.

var player: Player
var _box: VBoxContainer
var _info: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.6)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box = MenuKit.panel(self, 340)
	hide()


func open() -> void:
	Sound.ui("ui_open")
	get_parent().move_child(self, get_parent().get_child_count() - 1)
	for c in _box.get_children():
		c.queue_free()
	_box.add_child(MenuKit.title("Pause", 26))
	_info = MenuKit.label("", 12, MenuKit.C_DIM)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
	var w := get_tree().get_first_node_in_group("world") as WorldGenerator
	_info.text = "%s · niveau %d\n%s\nTemps de jeu : %s · %s · graine du monde %d" % [player.profile.hero_name if player.profile else "Héros", player.level,
		k.title() if k else "", MenuKit.format_time(int(SaveGame.play_time)), SaveGame.DIFFICULTY_NAMES[int(SaveGame.options.difficulty)],
		w.world_seed if w else 0]
	_box.add_child(_info)
	var items := [["Reprendre", close], ["Sauvegarder", _save], ["Charger", _load], ["Royaume", _kingdom], ["Commandes", _controls], ["Options", _options],
		["Menu principal", _to_title], ["Quitter le jeu", _quit]]
	var first: Button = null
	for it in items:
		var b := MenuKit.button(it[0], 280)
		b.pressed.connect(it[1])
		_box.add_child(b)
		if first == null:
			first = b
	show()
	player.ui_open = true
	get_tree().paused = true
	first.grab_focus.call_deferred()


func close() -> void:
	hide()
	get_tree().paused = false
	if player:
		player.ui_open = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		if event.is_action_pressed("pause") and player and not player.ui_open:
			if player.building:
				return
			open()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		# un sous-menu ouvert se ferme lui-même
		if get_children().any(func(c): return c is SaveSlotsPanel or c is OptionsPanel or c is ControlsPanel):
			return
		close()
		get_viewport().set_input_as_handled()


func _save() -> void:
	if player.global_position.y < WorldGenerator.UNDERGROUND:
		player.notify.emit("Tu reprendras devant l'entrée du donjon.")
	var panel := SaveSlotsPanel.new("save")
	panel.chosen.connect(func(s):
		var ok := SaveGame.save_game(s)
		panel.queue_free()
		close()
		player.notify.emit("Partie sauvegardée (emplacement %s)." % s if ok else "Échec de la sauvegarde.")
		player.feat.emit("Partie sauvegardée", MenuKit.C_GOLD) if ok else null)
	add_child(panel)


func _load() -> void:
	var panel := SaveSlotsPanel.new("load")
	panel.chosen.connect(func(s): SaveGame.load_game(s))
	add_child(panel)


func _kingdom() -> void:
	close()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.get("kingdom_panel"):
		hud.kingdom_panel.open()


func _controls() -> void:
	# le menu pause se cache derrière la fenêtre des commandes
	var holder := _box.get_parent().get_parent() as Control
	holder.hide()
	var panel := ControlsPanel.new()
	panel.closed.connect(func():
		holder.show()
		if visible:
			(_box.get_child(6) as Button).grab_focus())
	add_child(panel)


func _options() -> void:
	add_child(OptionsPanel.new())


func _to_title() -> void:
	SaveGame.to_title()


func _quit() -> void:
	get_tree().quit()
