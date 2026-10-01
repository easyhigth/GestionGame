class_name AchievementsPanel
extends Control
## Panneau des succès et du bestiaire (touche F1, ou bouton du journal).

var player: Player
var _box: VBoxContainer
var _list: VBoxContainer
var _scroll: ScrollContainer
var _tab := "succes"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box = MenuKit.panel(self, 860)
	_box.add_theme_constant_override("separation", 6)


func _ach() -> Achievements:
	return get_tree().get_first_node_in_group("achievements") as Achievements


func open(tab := "") -> void:
	if player == null or player.building or _ach() == null:
		return
	if tab != "":
		_tab = tab
	get_parent().move_child(self, get_parent().get_child_count() - 1)
	Sound.ui("ui_open")
	show()
	player.ui_open = true
	get_tree().paused = true
	_ach().check_all()
	_refresh()


func close() -> void:
	hide()
	get_tree().paused = false
	if player:
		player.ui_open = false


func _btn(text: String, cb: Callable, active := false, width := 0.0) -> Button:
	var b := MenuKit.button(text, width, 12)
	b.custom_minimum_size.y = 30
	if active:
		b.add_theme_color_override("font_color", MenuKit.C_GOLD)
	b.pressed.connect(func():
		cb.call()
		_refresh())
	return b


func _refresh() -> void:
	for c in _box.get_children():
		c.queue_free()
	var a := _ach()
	var n_done := a.done.size()
	_box.add_child(MenuKit.title("Succès et bestiaire", 20))
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 10)
	tabs.add_child(_btn("Succès (%d / %d · %d points)" % [n_done, a.defs().size(), a.points()], func(): _tab = "succes", _tab == "succes", 320))
	var known := Achievements.BESTIARY.filter(func(id): return int(a.kills.get(id, 0)) > 0).size()
	tabs.add_child(_btn("Bestiaire (%d / %d)" % [known, Achievements.BESTIARY.size()], func(): _tab = "bestiaire", _tab == "bestiaire", 220))
	_box.add_child(tabs)
	if _tab == "succes":
		_rewards_row(a)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(820, 320)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_box.add_child(_scroll)
	if _tab == "succes":
		_fill_achievements(a)
	else:
		_fill_bestiary(a)
	var close_b := MenuKit.button("Fermer (F1)", 200, 13)
	close_b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_b.pressed.connect(close)
	_box.add_child(close_b)


func _rewards_row(a: Achievements) -> void:
	var parts := []
	for r in Achievements.REWARDS:
		parts.append(("✔ " if a.points() >= int(r[0]) else "· ") + "%d pts : « %s »%s" % [int(r[0]), r[1], " + aura" if r[2] != null else ""])
	var l := MenuKit.label("   ".join(PackedStringArray(parts)), 10, MenuKit.C_DIM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(l)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.add_child(_btn("Titre : %s ▸" % (a.title if a.title != "" else "aucun"), a.cycle_title, false, 300))
	var an: String = "aucune" if a.aura < 0 else Achievements.REWARDS[a.aura][1]
	row.add_child(_btn("Aura : %s ▸" % an, a.cycle_aura, false, 260))
	_box.add_child(row)


func _fill_achievements(a: Achievements) -> void:
	for cat in Achievements.CATEGORIES:
		var items := a.defs().filter(func(d): return d.cat == cat)
		if items.is_empty():
			continue
		var got := items.filter(func(d): return a.done.has(d.id)).size()
		_list.add_child(MenuKit.label("%s  (%d / %d)" % [cat, got, items.size()], 14, MenuKit.C_GOLD))
		for d in items:
			var ok: bool = a.done.has(d.id)
			var v := a.value(d)
			var prog := "" if ok else "  ·  %s / %s" % [_num(minf(v, float(d.n))), _num(float(d.n))]
			var t := "%s %s — %s%s  (+%d%s)" % ["✔" if ok else "○", d.name, d.text, prog, int(d.pts), (", titre « %s »" % d.title) if str(d.title) != "" else ""]
			var l := MenuKit.label(t, 11, MenuKit.C_OK if ok else MenuKit.C_TEXT)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size.x = 790
			_list.add_child(l)


static func _num(v: float) -> String:
	return str(int(v))


func _fill_bestiary(a: Achievements) -> void:
	for id in Achievements.BESTIARY:
		var e := a.bestiary_entry(id)
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", MenuKit.style(Color("2f2622"), Color(e.color, 0.5) if e.known else Color("3a3028"), 1, 4, 5))
		var v := VBoxContainer.new()
		pc.add_child(v)
		if not e.known:
			v.add_child(MenuKit.label("???  —  monstre jamais vaincu" + ("  (vit : %s)" % ", ".join(PackedStringArray(e.regions)) if not e.regions.is_empty() else ""), 11, MenuKit.C_DIM))
		else:
			v.add_child(MenuKit.label("%s  ·  %d victoire(s)  ·  vie %d  ·  attaque %d" % [e.name, e.kills, e.hp, e.attack], 12, e.color))
			var info := "Régions : %s" % (", ".join(PackedStringArray(e.regions)) if not e.regions.is_empty() else "—")
			info += "   ·   Butin : %s" % (", ".join(PackedStringArray(e.loot)) if not e.loot.is_empty() else "—")
			if not e.rare.is_empty():
				info += "   ·   Rare : %s" % ", ".join(PackedStringArray(e.rare))
			var l := MenuKit.label(info, 10, MenuKit.C_TEXT)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size.x = 780
			v.add_child(l)
		_list.add_child(pc)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		if event.is_action_pressed("achievements") and player and not player.ui_open and not player.building and player.is_alive():
			open()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("achievements") or event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
