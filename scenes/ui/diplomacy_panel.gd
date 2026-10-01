class_name DiplomacyPanel
extends Control
## Panneau de la diplomatie (touche Y, ou bouton du panneau du royaume) : les nations voisines,
## leur relation avec le royaume, leurs demandes, les présents, les traités, la guerre et la paix.

var player: Player
var _box: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box = MenuKit.panel(self, 880)
	_box.add_theme_constant_override("separation", 5)


func _dip() -> Diplomacy:
	return get_tree().get_first_node_in_group("diplomacy") as Diplomacy


func open() -> void:
	if player == null or player.ui_open or player.building or _dip() == null:
		return
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


func _small(text: String, tip: String, disabled: bool, cb: Callable, width := 0.0) -> Button:
	var b := MenuKit.button(text, width, 11)
	b.custom_minimum_size.y = 26
	b.tooltip_text = tip
	b.disabled = disabled
	b.pressed.connect(func():
		cb.call()
		if visible:
			_refresh())
	return b


func _refresh() -> void:
	for c in _box.get_children():
		c.queue_free()
	var dip := _dip()
	var st := get_tree().get_first_node_in_group("story") as Story
	var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
	var nat := st.nation_name() if st else ""
	_box.add_child(MenuKit.title("Diplomatie — %s" % (nat if nat != "" else (k.title() if k else "ton royaume")), 20))
	var sub := MenuKit.label("Présents et demandes font monter la relation. Traités : paix (0), commerce (20), alliance (60). Or : %d" % player.inventory.count(Items.get_item("piece_or")), 11, MenuKit.C_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(sub)
	for id in Diplomacy.NATIONS:
		_box.add_child(_row(dip, id))
	var close_b := MenuKit.button("Fermer (Y)", 200, 13)
	close_b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_b.pressed.connect(close)
	_box.add_child(close_b)
	close_b.grab_focus.call_deferred()


func _row(dip: Diplomacy, id: String) -> Control:
	var n: Dictionary = Diplomacy.NATIONS[id]
	var s: Dictionary = dip.states[id]
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", MenuKit.style(Color("2f2622"), Color(n.color, 0.6), 1, 4, 6))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	pc.add_child(v)
	# ligne 1 : nom, peuple, statut, relation, traités
	var h1 := HBoxContainer.new()
	h1.add_theme_constant_override("separation", 10)
	var name_l := MenuKit.label(n.name, 14, n.color)
	name_l.custom_minimum_size.x = 190
	h1.add_child(name_l)
	var status := dip.status(id)
	var st_l := MenuKit.label(status, 12, Diplomacy.status_color(status))
	st_l.custom_minimum_size.x = 80
	h1.add_child(st_l)
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.15, 0.12, 0.1)
	bar_bg.custom_minimum_size = Vector2(160, 10)
	bar_bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bar := ColorRect.new()
	var r := dip.rel(id)
	bar.color = Diplomacy.status_color(status)
	bar.position = Vector2(80 if r >= 0 else 80 + 80 * r / 100.0, 0)
	bar.size = Vector2(absf(80 * r / 100.0), 10)
	bar_bg.add_child(bar)
	var mid := ColorRect.new()
	mid.color = Color(1, 1, 1, 0.4)
	mid.position = Vector2(79, 0)
	mid.size = Vector2(2, 10)
	bar_bg.add_child(mid)
	h1.add_child(bar_bg)
	h1.add_child(MenuKit.label("%+d" % roundi(r), 12))
	var tr := []
	for t in s.treaties:
		tr.append(Diplomacy.TREATY_NAMES[t])
	var info := "Traités : " + (", ".join(PackedStringArray(tr)) if not tr.is_empty() else "aucun")
	if dip.at_war(id):
		info = "Armées repoussées : %d / %d" % [int(s.wins), Diplomacy.WINS_TO_SURRENDER]
	if dip.annexed(id):
		info = "Province : impôts tous les %d jours, colons tous les %d jours" % [Diplomacy.TAX_EVERY, Diplomacy.SETTLER_EVERY]
	h1.add_child(MenuKit.label(info, 11, MenuKit.C_TEXT))
	v.add_child(h1)
	# ligne 2 : description, goûts, demande
	var lk: Array = n.likes
	var rq: Array = s.request
	var line := "%s (%s). Aime : %s." % [n.text, n.people, Items.get_item(lk[0]).display_name]
	if not rq.is_empty() and not dip.at_war(id) and not dip.annexed(id):
		line += "  Demande : %d %s." % [int(rq[1]), Items.get_item(rq[0]).display_name]
	var l2 := MenuKit.label(line, 10, MenuKit.C_DIM)
	l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l2.custom_minimum_size.x = 840
	v.add_child(l2)
	# ligne 3 : actions
	var h3 := HBoxContainer.new()
	h3.add_theme_constant_override("separation", 6)
	var acts := []
	if dip.annexed(id):
		pass
	elif dip.at_war(id):
		acts.append(["siege", "⚔ Assiéger la capitale"])
		acts.append(["peace", "Acheter la paix (%d or)" % dip.peace_price(id)])
	else:
		acts.append(["gift", "Présent : %d or" % Diplomacy.GIFT_GOLD])
		acts.append(["like", "Offrir %d %s" % [int(lk[1]), Items.get_item(lk[0]).display_name]])
		if not rq.is_empty():
			acts.append(["request", "Répondre à la demande"])
		for t in ["paix", "commerce", "alliance"]:
			if not dip.has_treaty(id, t):
				acts.append([t, Diplomacy.TREATY_NAMES[t]])
		acts.append(["war", "Guerre !"])
	for a in acts:
		var why := dip.block(id, a[0])
		var cb := dip.act.bind(id, a[0])
		if a[0] == "siege":
			cb = func():
				close()
				dip.start_siege(id)
		h3.add_child(_small(a[1], why if why != "" else a[1], why != "", cb))
	if not acts.is_empty():
		v.add_child(h3)
	return pc


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		if event.is_action_pressed("diplomacy") and player and not player.ui_open and not player.building and player.is_alive():
			open()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("diplomacy") or event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
