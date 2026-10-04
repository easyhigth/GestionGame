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


const TYPE_ICONS := {"apporter": "food", "chasser": "sword", "explorer": "compass", "défendre": "shield", "construire": "house"}
const TYPE_NAMES := {"apporter": "Livraison", "chasser": "Chasse", "explorer": "Exploration", "défendre": "Défense", "construire": "Construction"}


func _refresh() -> void:
	for c in _box.get_children():
		c.queue_free()
	var qb := _board()
	var q := qb.quest_of(target) if qb else {}
	var v = target
	# en-tête : portrait, nom, humeur, amitié
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(MenuKit.portrait(MenuKit.villager_portrait_id(v), 70))
	var hv := VBoxContainer.new()
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	hv.add_theme_constant_override("separation", 4)
	hv.add_child(MenuKit.heading(v.villager_name, 17))
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 4)
	chips.add_child(MenuKit.chip(v.race.display_name if v.race else "?", MenuKit.C_DIM))
	chips.add_child(MenuKit.chip(VillageNeeds.mood_name(v.happiness), VillageNeeds.mood_color(v.happiness)))
	hv.add_child(chips)
	var fr := HBoxContainer.new()
	fr.add_theme_constant_override("separation", 6)
	fr.add_child(MenuKit.icon("heart", 14))
	var fv := mini(int(v.friendship), QuestBoard.FRIEND_AT)
	fr.add_child(MenuKit.gauge(float(fv) / QuestBoard.FRIEND_AT, Color("ff8ab0"), 110, 8))
	fr.add_child(MenuKit.label("Ami !" if int(v.friendship) >= QuestBoard.FRIEND_AT else "Amitié %d / %d" % [fv, QuestBoard.FRIEND_AT], 10, Color("ff8ab0")))
	hv.add_child(fr)
	head.add_child(hv)
	_box.add_child(head)
	if q.is_empty():
		_box.add_child(_label("« Merci encore pour ton aide ! »", 13, MenuKit.C_DIM))
		_buttons([["Fermer", close]])
		return
	# la quête, sur un parchemin
	var sheet := PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", UiTheme.parchment(12))
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 5)
	sheet.add_child(sv)
	var tl := HBoxContainer.new()
	tl.add_theme_constant_override("separation", 6)
	tl.add_child(MenuKit.icon(TYPE_ICONS.get(q.type, "scroll"), 20))
	var tt := MenuKit.heading(q.title, 15, MenuKit.C_INK)
	tt.add_theme_constant_override("outline_size", 0)
	tl.add_child(tt)
	tl.add_child(MenuKit.chip(TYPE_NAMES.get(q.type, "Quête"), Color("8a5a2a")))
	sv.add_child(tl)
	var txt := _label("« %s »" % q.text, 12, MenuKit.C_INK)
	txt.custom_minimum_size.x = 420
	sv.add_child(txt)
	# objectif : objet à apporter, monstre à chasser, progression
	var goal := HBoxContainer.new()
	goal.add_theme_constant_override("separation", 8)
	var need_item := Items.get_item(str(q.need)) if q.type == "apporter" else null
	if need_item:
		goal.add_child(MenuKit.item_badge(need_item, int(q.count), 38))
		var have := player.inventory.count(need_item)
		goal.add_child(MenuKit.label("Tu en as %d" % have, 11, MenuKit.C_OK if have >= int(q.count) else Color("9a3a2a")))
	elif q.type == "chasser" and str(q.need) != "":
		goal.add_child(MenuKit.mini_portrait(str(q.need).get_file().get_basename(), 38))
	if q.state == "active" or q.state == "ready":
		var ratio := 1.0 if q.state == "ready" else float(q.progress) / maxf(1.0, float(q.count))
		var gv := VBoxContainer.new()
		gv.add_theme_constant_override("separation", 1)
		gv.add_child(MenuKit.label(qb.progress_text(q), 10, MenuKit.C_INK_DIM))
		gv.add_child(MenuKit.gauge(ratio, MenuKit.C_OK if ratio >= 1.0 else Color("c89a3a"), 200, 9))
		goal.add_child(gv)
	if goal.get_child_count() > 0:
		sv.add_child(goal)
	# récompense
	var rw := HBoxContainer.new()
	rw.add_theme_constant_override("separation", 6)
	rw.add_child(MenuKit.label("Récompense :", 11, MenuKit.C_INK_DIM))
	var gold := Items.get_item("piece_or")
	if gold:
		rw.add_child(MenuKit.item_badge(gold, int(q.gold), 30))
	rw.add_child(MenuKit.chip("+%d XP" % int(q.xp), Color("4a8ac8")))
	rw.add_child(MenuKit.chip("+1 amitié", Color("c85a8a")))
	sv.add_child(rw)
	_box.add_child(sheet)
	match q.state:
		"offer":
			var full := qb.active().size() >= QuestBoard.max_active(get_tree())
			if full:
				_box.add_child(_label("Tu as déjà %d quêtes en cours : termine-en une d'abord." % QuestBoard.max_active(get_tree()), 11, MenuKit.C_BAD))
			_buttons([["Accepter", func():
				if qb.accept(q):
					player.notify.emit("Quête acceptée : %s." % q.title)
				close(), full], ["Plus tard", close], ["Équipement et poste", _equipment]])
		"active":
			_buttons([["D'accord", close], ["Abandonner", func():
				qb.abandon(q)
				player.notify.emit("Quête abandonnée.")
				close()], ["Équipement et poste", _equipment]])
		"ready":
			_box.add_child(MenuKit.icon_label("star", "C'est fait ! %s t'attend pour te remercier." % q.giver_name, 12, MenuKit.C_OK))
			_buttons([["Rendre la quête", func():
				var txt2 := qb.turn_in(q)
				if txt2 != "":
					player.notify.emit("Quête réussie : %s. %s" % [q.title, txt2])
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
