class_name HeraldryPanel
extends Control
## Panneau « Bannière et trophées » (bouton du panneau du royaume) : nom du royaume, couleurs, emblème,
## et liste des statues de l'allée des trophées.

var player: Player
var _box: VBoxContainer
var _name_edit: LineEdit


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box = MenuKit.panel(self, 620)


func _her() -> Heraldry:
	return get_tree().get_first_node_in_group("heraldry") as Heraldry


func open() -> void:
	if player == null or player.building or _her() == null:
		return
	get_parent().move_child(self, get_parent().get_child_count() - 1)
	Sound.ui("ui_open")
	show()
	player.ui_open = true
	get_tree().paused = true
	_refresh()


func close() -> void:
	if _name_edit and is_instance_valid(_name_edit) and _her():
		_her().set_kingdom_name(_name_edit.text)
	hide()
	get_tree().paused = false
	if player:
		player.ui_open = false


func _row(label: String, value: String, what: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 8)
	var l := MenuKit.label(label, 13)
	l.custom_minimum_size.x = 170
	h.add_child(l)
	var prev := MenuKit.button("◀", 40, 13)
	prev.pressed.connect(func():
		_her().cycle(what, -1)
		_refresh())
	h.add_child(prev)
	var v := MenuKit.label(value, 14, MenuKit.C_GOLD)
	v.custom_minimum_size.x = 160
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(v)
	var nxt := MenuKit.button("▶", 40, 13)
	nxt.pressed.connect(func():
		_her().cycle(what, 1)
		_refresh())
	h.add_child(nxt)
	return h


func _refresh() -> void:
	var keep := _name_edit.text if _name_edit and is_instance_valid(_name_edit) else ""
	for c in _box.get_children():
		c.queue_free()
	var h := _her()
	var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
	_box.add_child(MenuKit.title("Bannière et trophées", 20))
	# aperçu de la bannière
	var center := CenterContainer.new()
	var flag := ColorRect.new()
	flag.custom_minimum_size = Vector2(120, 150)
	flag.color = h.primary_color()
	var band := ColorRect.new()
	band.color = h.secondary_color()
	band.position = Vector2(0, 118)
	band.size = Vector2(120, 14)
	flag.add_child(band)
	var top := ColorRect.new()
	top.color = h.secondary_color()
	top.size = Vector2(120, 10)
	flag.add_child(top)
	var em := MenuKit.label(h.emblem_char(), 64, h.secondary_color())
	em.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	em.size = Vector2(120, 110)
	em.position = Vector2(0, 14)
	flag.add_child(em)
	center.add_child(flag)
	_box.add_child(center)
	# nom
	var nrow := HBoxContainer.new()
	nrow.alignment = BoxContainer.ALIGNMENT_CENTER
	nrow.add_theme_constant_override("separation", 8)
	var nl := MenuKit.label("Nom du royaume", 13)
	nl.custom_minimum_size.x = 170
	nrow.add_child(nl)
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size = Vector2(300, 34)
	_name_edit.max_length = 32
	_name_edit.placeholder_text = "(nom par défaut)"
	_name_edit.text = keep if keep != "" else h.custom_name
	_name_edit.text_submitted.connect(func(t):
		h.set_kingdom_name(t)
		_refresh())
	nrow.add_child(_name_edit)
	_box.add_child(nrow)
	_box.add_child(_row("Couleur principale", Heraldry.COLORS[h.primary][0], "primary"))
	_box.add_child(_row("Couleur secondaire", Heraldry.COLORS[h.secondary][0], "secondary"))
	_box.add_child(_row("Emblème", "%s %s" % [Heraldry.EMBLEMS[h.emblem][1], Heraldry.EMBLEMS[h.emblem][0]], "emblem"))
	var tip := MenuKit.label("Titre : %s  ·  Les étendards du village et ceux que tu poses (Mobilier → Étendard) prennent ces couleurs." % (k.title() if k else ""), 10, MenuKit.C_DIM)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size.x = 580
	_box.add_child(tip)
	# trophées
	var names := []
	for id in Heraldry.TROPHY_SLOTS:
		if h.statues.has(id):
			var r := load("res://data/regions/%s.tres" % id) as RegionData
			names.append(r.boss.display_name if r and r.boss else id)
	_box.add_child(MenuKit.label("Allée des trophées : %d / %d statues" % [names.size(), Heraldry.TROPHY_SLOTS.size()], 14, MenuKit.C_GOLD))
	var tl := MenuKit.label(", ".join(PackedStringArray(names)) if not names.is_empty() else "Vaincs le boss d'un donjon : sa statue se dressera autour du feu de camp.", 10, MenuKit.C_TEXT)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.custom_minimum_size.x = 580
	_box.add_child(tl)
	var close_b := MenuKit.button("Fermer", 200, 13)
	close_b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_b.pressed.connect(close)
	_box.add_child(close_b)


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		close()
		get_viewport().set_input_as_handled()
