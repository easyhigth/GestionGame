class_name ExpeditionPanel
extends Control
## Panneau des expéditions (bouton « Expéditions » du panneau du royaume) : choisir une mission, cocher les
## habitants qui partent (chance de réussite affichée), suivre les expéditions en cours et les derniers retours.

var player: Player
var _box: VBoxContainer
var _mission := "cueillette"
var _picked: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box = MenuKit.panel(self, 760)


func _ex() -> Expeditions:
	return get_tree().get_first_node_in_group("expeditions") as Expeditions


func open() -> void:
	if player == null or player.ui_open or player.building:
		return
	get_parent().move_child(self, get_parent().get_child_count() - 1)
	Sound.ui("ui_open")
	show()
	player.ui_open = true
	get_tree().paused = true
	_picked.clear()
	_refresh()


func close() -> void:
	hide()
	get_tree().paused = false
	if player:
		player.ui_open = false


func _class_name(v: Node) -> String:
	var c := Villager.class_data(str(v.get("fight_class")))
	return c.display_name if c else "—"


func _refresh() -> void:
	for c in _box.get_children():
		c.queue_free()
	var ex := _ex()
	_box.add_child(MenuKit.title("Expéditions", 20))
	if ex == null:
		return
	_box.add_child(MenuKit.label("Envoie tes habitants en mission : leur classe et leur métier comptent. En cours : %d / %d." % [ex.active.size(), Expeditions.max_active(get_tree())], 12, MenuKit.C_DIM))
	# missions
	var tabs := GridContainer.new()
	tabs.columns = 4
	tabs.add_theme_constant_override("h_separation", 4)
	tabs.add_theme_constant_override("v_separation", 4)
	for id in Expeditions.ORDER:
		var m: Dictionary = Expeditions.MISSIONS[id]
		var b := MenuKit.tab("%s %s" % [m.icon, m.name], id == _mission, 178.0, 11)
		b.pressed.connect(func():
			_mission = id
			_refresh())
		tabs.add_child(b)
	_box.add_child(tabs)
	var m: Dictionary = Expeditions.MISSIONS[_mission]
	var cls := PackedStringArray(m.classes.map(func(c): return Villager.class_data(c).display_name if Villager.class_data(c) else c))
	var jobs := PackedStringArray(m.jobs.map(func(j): return Villager.JOB_NAMES.get(j, j)))
	var loot := PackedStringArray(m.loot.map(func(l): return Items.get_item(l[0]).display_name if Items.get_item(l[0]) else l[0]))
	var info := MenuKit.label("%s\nDurée %s  ·  difficulté %s  ·  classes conseillées : %s  ·  métiers : %s\nButin : %s%s" % [m.text,
		MenuKit.format_time(roundi(m.dur)), "★".repeat(clampi(roundi(m.diff * 1.2), 1, 5)), ", ".join(cls), ", ".join(jobs), ", ".join(loot),
		", or" if int(m.gold) > 0 else ""], 11, MenuKit.C_TEXT)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size.x = 730
	_box.add_child(info)
	# habitants
	_box.add_child(MenuKit.heading("Qui part ? (jusqu'à %d)" % Expeditions.MAX_PARTY, 14))
	var avail := ex.available()
	_picked = _picked.filter(func(v): return is_instance_valid(v) and avail.has(v))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(730, 130)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	scroll.add_child(grid)
	_box.add_child(scroll)
	if avail.is_empty():
		grid.add_child(MenuKit.label("Aucun habitant disponible (les compagnons restent avec toi).", 12, MenuKit.C_DIM))
	avail.sort_custom(func(a, b): return Expeditions.member_power(a, _mission) > Expeditions.member_power(b, _mission))
	for v in avail:
		var cb := CheckBox.new()
		var fit: bool = m.classes.has(v.get("fight_class"))
		var job: String = Villager.JOB_NAMES.get(v.call("best_job"), "?")
		cb.text = "%s · %s · %s · Nv %d%s" % [v.get("villager_name"), _class_name(v), job, int(v.get("level")), "  ✦" if fit else ""]
		cb.add_theme_font_size_override("font_size", 11)
		cb.custom_minimum_size.x = 355
		cb.button_pressed = _picked.has(v)
		cb.toggled.connect(func(on):
			if on and not _picked.has(v):
				_picked.append(v)
			elif not on:
				_picked.erase(v)
			_refresh())
		grid.add_child(cb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var ch := Expeditions.chance(_mission, _picked)
	var why := ex.can_start(_mission, _picked)
	var cl := MenuKit.bold("Chance de réussite : %d %%" % roundi(ch * 100), 14, MenuKit.C_OK if ch >= 0.7 else (MenuKit.C_GOLD if ch >= 0.4 else MenuKit.C_BAD))
	cl.custom_minimum_size.x = 260
	row.add_child(cl)
	var go := MenuKit.button("Partir", 160, 13)
	go.disabled = why != ""
	go.tooltip_text = why
	go.pressed.connect(func():
		if ex.start(_mission, _picked):
			_picked.clear()
			_refresh())
	row.add_child(go)
	if why != "" and not _picked.is_empty():
		row.add_child(MenuKit.label(why, 11, MenuKit.C_BAD))
	_box.add_child(row)
	# en cours et retours
	if not ex.active.is_empty():
		_box.add_child(MenuKit.heading("En route", 14))
		for e in ex.active:
			var em: Dictionary = Expeditions.MISSIONS[e.mission]
			_box.add_child(MenuKit.label("%s %s — %s — retour dans %s (%d %%)" % [em.icon, em.name, ", ".join(PackedStringArray(e.names)),
				MenuKit.format_time(roundi(e.left)), roundi(float(e.chance) * 100)], 11, MenuKit.C_TEXT))
	if not ex.history.is_empty():
		_box.add_child(MenuKit.heading("Derniers retours", 14))
		for t in ex.history.slice(0, 3):
			var l := MenuKit.label(t, 10, MenuKit.C_DIM)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size.x = 730
			_box.add_child(l)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 12)
	var back := MenuKit.button("Royaume (U)", 200, 13)
	back.pressed.connect(func():
		close()
		var hud := get_parent()
		if hud and hud.get("kingdom_panel"):
			hud.kingdom_panel.open())
	bottom.add_child(back)
	var close_b := MenuKit.button("Fermer", 200, 13)
	close_b.pressed.connect(close)
	bottom.add_child(close_b)
	_box.add_child(bottom)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("kingdom"):
		close()
		get_viewport().set_input_as_handled()
