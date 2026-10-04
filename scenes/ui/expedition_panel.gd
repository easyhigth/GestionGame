class_name ExpeditionPanel
extends Control
## Panneau des expéditions (bouton « Expéditions » du panneau du royaume) : des cartes de missions, la fiche
## de la mission choisie (classes conseillées, butin), l'équipe (4 places, chance de réussite), les habitants
## disponibles (un clic pour les ajouter), puis les expéditions en route et les derniers retours.

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
	_box = MenuKit.panel(self, 800)
	_box.add_theme_constant_override("separation", 5)


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


static func _stars(diff: float) -> String:
	var n := clampi(roundi(diff * 1.2), 1, 5)
	return "★".repeat(n) + "☆".repeat(5 - n)


func _refresh() -> void:
	for c in _box.get_children():
		c.queue_free()
	var ex := _ex()
	_box.add_child(MenuKit.title("Expéditions", 20))
	if ex == null:
		return
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 8)
	head.add_child(MenuKit.label("Envoie tes habitants en mission : leur classe et leur métier comptent.", 11, MenuKit.C_DIM))
	var full := ex.active.size() >= Expeditions.max_active(get_tree())
	head.add_child(MenuKit.chip("En route %d / %d" % [ex.active.size(), Expeditions.max_active(get_tree())], MenuKit.C_BAD if full else MenuKit.C_OK))
	_box.add_child(head)
	# en route et dernier retour : une ligne de pastilles
	if not ex.active.is_empty() or not ex.history.is_empty():
		var st := HFlowContainer.new()
		st.add_theme_constant_override("h_separation", 6)
		st.alignment = FlowContainer.ALIGNMENT_CENTER
		for e in ex.active:
			var em: Dictionary = Expeditions.MISSIONS[e.mission]
			var c := MenuKit.chip("%s %s · %s · retour dans %s" % [em.icon, em.name, ", ".join(PackedStringArray(e.names)), MenuKit.format_time(roundi(e.left))], Color("8ac8ff"))
			st.add_child(c)
		if not ex.history.is_empty():
			var last: String = ex.history[0]
			var c2 := MenuKit.chip("Dernier retour : " + last.left(90), MenuKit.C_OK if "réussite" in last else MenuKit.C_BAD)
			c2.tooltip_text = "\n".join(PackedStringArray(ex.history))
			st.add_child(c2)
		_box.add_child(st)
	# événements en attente : un choix à faire
	for e in ex.active:
		if not e.has("event"):
			continue
		var ev: Dictionary = Expeditions.EVENTS[e.event]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", MenuKit.style(Color(0.3, 0.2, 0.08, 0.95), MenuKit.C_GOLD, 2, 4, 7))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		card.add_child(row)
		row.add_child(MenuKit.label(ev.icon, 22))
		var txt := MenuKit.label("%s — %s" % [", ".join(PackedStringArray(e.names)), ev.text], 11, MenuKit.C_TEXT)
		txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		txt.custom_minimum_size.x = 240
		row.add_child(txt)
		for i in ev.options.size():
			var b := MenuKit.button(ev.options[i][0], 200, 10)
			b.custom_minimum_size.y = 30
			var idx: int = i
			var exp_e: Dictionary = e
			b.pressed.connect(func():
				ex.choose(exp_e, idx)
				player.notify.emit("Expédition : « %s »." % exp_e.get("choice", ""))
				_refresh())
			row.add_child(b)
		_box.add_child(card)
	# les missions
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for id in Expeditions.ORDER:
		grid.add_child(_mission_card(id))
	_box.add_child(grid)
	# fiche de la mission + équipe
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 8)
	_box.add_child(mid)
	mid.add_child(_mission_sheet())
	mid.add_child(_team_box(ex))
	# habitants disponibles
	_box.add_child(MenuKit.icon_label("people", "Habitants disponibles · un clic pour l'ajouter ou le retirer (✦ : classe conseillée)", 11, MenuKit.C_GOLD))
	var avail := ex.available()
	_picked = _picked.filter(func(v): return is_instance_valid(v) and avail.has(v))
	var scroll := ScrollContainer.new()
	var n_events := ex.active.filter(func(e): return e.has("event")).size()
	scroll.custom_minimum_size = Vector2(770, maxf(48.0, 96.0 - 50.0 * n_events))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var roster := GridContainer.new()
	roster.columns = 3
	roster.add_theme_constant_override("h_separation", 6)
	roster.add_theme_constant_override("v_separation", 6)
	scroll.add_child(roster)
	_box.add_child(scroll)
	if avail.is_empty():
		roster.add_child(MenuKit.empty_state("people", "Aucun habitant disponible (les compagnons restent avec toi)."))
	avail.sort_custom(func(a, b): return Expeditions.member_power(a, _mission) > Expeditions.member_power(b, _mission))
	for v in avail:
		roster.add_child(_villager_button(v))
	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 12)
	var back := MenuKit.nav_button("Royaume ({kingdom})", "crown", 200)
	back.pressed.connect(func():
		close()
		var hud := get_parent()
		if hud and hud.get("kingdom_panel"):
			hud.kingdom_panel.open())
	nav.add_child(back)
	var close_b := MenuKit.button("Fermer", 160, 12)
	close_b.pressed.connect(close)
	nav.add_child(close_b)
	_box.add_child(nav)


## Carte d'une mission (cliquable) : icône, nom, durée, difficulté.
func _mission_card(id: String) -> Button:
	var m: Dictionary = Expeditions.MISSIONS[id]
	var sel := id == _mission
	var b := Button.new()
	b.custom_minimum_size = Vector2(190, 44)
	b.focus_mode = Control.FOCUS_ALL
	var st := MenuKit.card(false, 6.0)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", UiTheme.box("card_hover", 6, Vector4(6, 4, 6, 4)))
	b.add_theme_stylebox_override("pressed", st)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if sel:
		var sb := MenuKit.style(Color(0.3, 0.22, 0.1, 0.95), MenuKit.C_GOLD, 2, 4, 6)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
	b.pressed.connect(func():
		Sound.ui("ui_page")
		_mission = id
		_refresh())
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 8
	h.offset_right = -4
	b.add_child(h)
	var ic := MenuKit.label(m.icon, 20)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(v)
	var nm := MenuKit.bold(m.name, 11, MenuKit.C_GOLD if sel else MenuKit.C_TEXT)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(nm)
	var info := MenuKit.label("%s  ·  %s" % [MenuKit.format_time(roundi(m.dur)), _stars(m.diff)], 10, Color("e8b84a"))
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(info)
	return b


## Fiche de la mission choisie : texte, classes et métiers conseillés, butin.
func _mission_sheet() -> PanelContainer:
	var m: Dictionary = Expeditions.MISSIONS[_mission]
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiTheme.parchment(12))
	pc.custom_minimum_size = Vector2(390, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	pc.add_child(v)
	var t := MenuKit.heading("%s %s" % [m.icon, m.name], 15, MenuKit.C_INK)
	t.add_theme_constant_override("outline_size", 0)
	v.add_child(t)
	var d := MenuKit.label(m.text, 11, MenuKit.C_INK)
	d.custom_minimum_size.y = 0
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.x = 360
	v.add_child(d)
	v.add_child(MenuKit.label("Classes et métiers conseillés", 10, MenuKit.C_INK_DIM))
	var cls := HFlowContainer.new()
	cls.add_theme_constant_override("h_separation", 4)
	cls.add_theme_constant_override("v_separation", 3)
	for c in m.classes:
		var cd := Villager.class_data(c)
		if cd:
			cls.add_child(MenuKit.chip(cd.display_name, cd.color.darkened(0.15)))
	for j in m.jobs:
		cls.add_child(MenuKit.chip(Villager.JOB_NAMES.get(j, j), Color("b08a50")))
	v.add_child(cls)
	v.add_child(MenuKit.label("Butin (plus avec une grande équipe)", 10, MenuKit.C_INK_DIM))
	var loot := HBoxContainer.new()
	loot.add_theme_constant_override("separation", 4)
	for l in m.loot:
		var it := Items.get_item(l[0])
		if it:
			loot.add_child(MenuKit.item_badge(it, int(l[1]), 34))
	if int(m.gold) > 0:
		var g := Items.get_item("piece_or")
		if g:
			loot.add_child(MenuKit.item_badge(g, int(m.gold), 34))
	v.add_child(loot)
	return pc


## L'équipe : 4 places, rôles présents, chance de réussite, bouton Partir.
func _team_box(ex: Expeditions) -> PanelContainer:
	var pc := MenuKit.card_box(false, 8.0, 4)
	pc.custom_minimum_size = Vector2(372, 0)
	var v: VBoxContainer = pc.get_child(0)
	v.add_child(MenuKit.bold("Équipe (%d / %d)" % [_picked.size(), Expeditions.MAX_PARTY], 13, MenuKit.C_GOLD))
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 6)
	v.add_child(slots)
	var has_heal := false
	var has_tank := false
	for i in Expeditions.MAX_PARTY:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 1)
		cell.custom_minimum_size.x = 82
		if i < _picked.size():
			var who: Node = _picked[i]
			var b := Button.new()
			b.flat = true
			b.custom_minimum_size = Vector2(48, 48)
			b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			b.tooltip_text = "Retirer %s" % who.get("villager_name")
			b.pressed.connect(func():
				_picked.erase(who)
				_refresh())
			var por := MenuKit.portrait(MenuKit.villager_portrait_id(who), 48)
			por.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(por)
			cell.add_child(b)
			var nm := MenuKit.label(str(who.get("villager_name")), 10, MenuKit.C_TEXT)
			nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_child(nm)
			var role: String = who.call("class_role")
			has_heal = has_heal or role in ["soin", "chant"]
			has_tank = has_tank or role == "rempart"
		else:
			var empty := PanelContainer.new()
			empty.add_theme_stylebox_override("panel", UiTheme.box("slot", 6, Vector4(2, 2, 2, 2)))
			empty.custom_minimum_size = Vector2(48, 48)
			empty.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			var plus := MenuKit.label("+", 22, Color(MenuKit.C_DIM, 0.6))
			plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			empty.add_child(plus)
			cell.add_child(empty)
			var fr := MenuKit.label("libre", 9, MenuKit.C_DIM)
			fr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_child(fr)
		slots.add_child(cell)
	var roles := HBoxContainer.new()
	roles.add_theme_constant_override("separation", 4)
	roles.add_child(MenuKit.chip(("✓ " if has_heal else "✗ ") + "Soigneur", MenuKit.C_OK if has_heal else MenuKit.C_DIM))
	roles.add_child(MenuKit.chip(("✓ " if has_tank else "✗ ") + "Protecteur", MenuKit.C_OK if has_tank else MenuKit.C_DIM))
	v.add_child(roles)
	var ch := Expeditions.chance(_mission, _picked)
	var col := MenuKit.C_OK if ch >= 0.7 else (MenuKit.C_GOLD if ch >= 0.4 else MenuKit.C_BAD)
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 8)
	crow.add_child(MenuKit.bold("%d %%" % roundi(ch * 100), 20, col))
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 1)
	cv.add_child(MenuKit.label("Chance de réussite", 10, MenuKit.C_DIM))
	cv.add_child(MenuKit.gauge(ch, col, 250, 10))
	crow.add_child(cv)
	v.add_child(crow)
	var why := ex.can_start(_mission, _picked)
	var go := MenuKit.nav_button("Partir en expédition", "compass", 300)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.disabled = why != ""
	go.tooltip_text = why
	go.pressed.connect(func():
		if ex.start(_mission, _picked):
			_picked.clear()
			_refresh())
	v.add_child(go)
	if why != "" and not _picked.is_empty():
		v.add_child(MenuKit.label(why, 10, MenuKit.C_BAD))
	return pc


## Un habitant disponible : portrait, nom, classe, métier ; ✦ si sa classe est conseillée.
func _villager_button(v: Node) -> Button:
	var m: Dictionary = Expeditions.MISSIONS[_mission]
	var picked := _picked.has(v)
	var fit: bool = m.classes.has(v.get("fight_class"))
	var b := Button.new()
	b.custom_minimum_size = Vector2(252, 46)
	b.toggle_mode = true
	b.button_pressed = picked
	var normal := MenuKit.card(false, 4.0)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", UiTheme.box("card_hover", 6, Vector4(4, 3, 4, 3)))
	var on := MenuKit.style(Color(0.18, 0.3, 0.14, 0.95), MenuKit.C_OK, 2, 4, 4)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.tooltip_text = "Force pour cette mission : %.1f" % Expeditions.member_power(v, _mission)
	b.toggled.connect(func(pressed):
		Sound.ui("ui_click")
		if pressed and not _picked.has(v) and _picked.size() < Expeditions.MAX_PARTY:
			_picked.append(v)
		elif not pressed:
			_picked.erase(v)
		_refresh())
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 5
	b.add_child(h)
	var mp := MenuKit.mini_portrait(MenuKit.villager_portrait_id(v), 36)
	mp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(mp)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(col)
	var nm := MenuKit.bold("%s%s · Nv %d" % ["✦ " if fit else "", v.get("villager_name"), int(v.get("level"))], 11, MenuKit.C_GOLD if fit else MenuKit.C_TEXT)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(nm)
	var cd := Villager.class_data(str(v.get("fight_class")))
	var sub := MenuKit.label("%s · %s" % [cd.display_name if cd else "—", Villager.JOB_NAMES.get(v.call("best_job"), "?")], 10, cd.color.lightened(0.3) if cd else MenuKit.C_DIM)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(sub)
	return b


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("kingdom"):
		close()
		get_viewport().set_input_as_handled()
