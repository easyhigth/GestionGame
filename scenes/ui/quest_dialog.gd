class_name QuestDialog
extends Control
## Parler à un habitant qui a une quête (E) : accepter, voir l'avancement, rendre la quête ou abandonner.

var player: Player
var target: Node
var _box: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box = MenuKit.panel(self, 480)


func _board() -> QuestBoard:
	return get_tree().get_first_node_in_group("quests") as QuestBoard


func open(v: Node) -> void:
	if player == null or player.ui_open:
		return
	target = v
	get_parent().move_child(self, get_parent().get_child_count() - 1)
	Sound.ui("ui_open")
	show()
	player.ui_open = true
	get_tree().paused = true
	_refresh()


func close() -> void:
	hide()
	get_tree().paused = false
	if player:
		player.ui_open = false


func _label(text: String, size := 13, col := MenuKit.C_TEXT) -> Label:
	var l := MenuKit.label(text, size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(440, 0)
	return l


func _refresh() -> void:
	for c in _box.get_children():
		c.queue_free()
	var qb := _board()
	var q := qb.quest_of(target) if qb else {}
	var v = target
	var friend := "  ·  ton ami" if int(v.friendship) >= QuestBoard.FRIEND_AT else ("  ·  quêtes réussies : %d / %d" % [v.friendship, QuestBoard.FRIEND_AT])
	_box.add_child(MenuKit.title("%s (%s)" % [v.villager_name, v.race.display_name if v.race else "?"], 18))
	_box.add_child(_label(VillageNeeds.mood_name(v.happiness) + friend, 11, VillageNeeds.mood_color(v.happiness)))
	if q.is_empty():
		_box.add_child(_label("« Merci encore pour ton aide ! »", 13, MenuKit.C_DIM))
		_buttons([["Fermer", close]])
		return
	_box.add_child(_label(q.title, 16, MenuKit.C_GOLD))
	_box.add_child(_label("« %s »" % q.text, 13))
	_box.add_child(_label("Récompense : %d pièces d'or, %d XP, et la gratitude de %s." % [int(q.gold), int(q.xp), q.giver_name], 11, MenuKit.C_DIM))
	match q.state:
		"offer":
			var full := qb.active().size() >= QuestBoard.MAX_ACTIVE
			if full:
				_box.add_child(_label("Tu as déjà %d quêtes en cours : termine-en une d'abord." % QuestBoard.MAX_ACTIVE, 11, MenuKit.C_BAD))
			_buttons([["Accepter", func():
				if qb.accept(q):
					player.notify.emit("Quête acceptée : %s." % q.title)
				close(), full], ["Plus tard", close], ["Équipement et poste", _equipment]])
		"active":
			_box.add_child(_label("En cours : %s" % qb.progress_text(q), 12, MenuKit.C_TEXT))
			_buttons([["D'accord", close], ["Abandonner", func():
				qb.abandon(q)
				player.notify.emit("Quête abandonnée.")
				close()], ["Équipement et poste", _equipment]])
		"ready":
			_box.add_child(_label("C'est fait ! %s t'attend pour te remercier." % q.giver_name, 12, MenuKit.C_OK))
			_buttons([["Rendre la quête", func():
				var txt := qb.turn_in(q)
				if txt != "":
					player.notify.emit("Quête réussie : %s. %s" % [q.title, txt])
				close()], ["Plus tard", close]])


func _buttons(list: Array) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	_box.add_child(row)
	var first: Button = null
	for b in list:
		var btn := MenuKit.button(b[0], 150, 13)
		btn.pressed.connect(b[1])
		if b.size() > 2 and b[2]:
			btn.disabled = true
		row.add_child(btn)
		if first == null and not btn.disabled:
			first = btn
	if first:
		first.grab_focus.call_deferred()


func _equipment() -> void:
	close()
	player.open_inventory.emit(target)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
