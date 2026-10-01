class_name AchievementsPanel
extends Control
## Panneau des succès et du bestiaire (touche F1, ou bouton du journal).

var player: Player
var _box: VBoxContainer
var _list: VBoxContainer
var _scroll: ScrollContainer
var _tab := "succes"
var _detail: PanelContainer
var _selected := ""


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
	player.set_meta("seen_achievements", true)
	get_tree().paused = true
	_ach().check_all()
	_refresh()


func close() -> void:
	hide()
	get_tree().paused = false
	if player:
		player.ui_open = false


func _btn(text: String, cb: Callable, active := false, width := 0.0) -> Button:
	var b := MenuKit.tab(text, active, width, 12)
	b.pressed.connect(func():
		var changed := not active
		cb.call()
		_refresh()
		if changed and _scroll:
			MenuKit.fade_in(_scroll.get_parent()))
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
	tabs.add_child(_btn("Succès (%d / %d · %d points)" % [n_done, a.defs().size(), a.points()], func(): _tab = "succes", _tab == "succes", 300))
	var known := Achievements.BESTIARY.filter(func(id): return int(a.kills.get(id, 0)) > 0).size()
	tabs.add_child(_btn("Bestiaire (%d / %d)" % [known, Achievements.BESTIARY.size()], func(): _tab = "bestiaire", _tab == "bestiaire", 220))
	_box.add_child(tabs)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 6)
	_box.add_child(page)
	if _tab == "succes":
		_rewards_row(a, page)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	page.add_child(row)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(820 if _tab == "succes" else 520, 290 if _tab == "succes" else 330)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	if _tab == "succes":
		_fill_achievements(a)
	else:
		_detail = PanelContainer.new()
		_detail.add_theme_stylebox_override("panel", UiTheme.parchment(16))
		_detail.custom_minimum_size = Vector2(290, 330)
		row.add_child(_detail)
		_fill_bestiary(a)
		_show_entry(_selected if _selected != "" else Achievements.BESTIARY[0])
	var close_b := MenuKit.button("Fermer (F1)", 200, 13)
	close_b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_b.pressed.connect(close)
	_box.add_child(close_b)


func _rewards_row(a: Achievements, page: VBoxContainer) -> void:
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 16)
	for r in Achievements.REWARDS:
		var got := a.points() >= int(r[0])
		var it := MenuKit.icon_label("star" if got else "scroll", "%d pts : « %s »%s" % [int(r[0]), r[1], " + aura" if r[2] != null else ""],
			10, MenuKit.C_GOLD if got else MenuKit.C_DIM)
		line.add_child(it)
	page.add_child(line)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var t := MenuKit.button("Titre : %s ▸" % (a.title if a.title != "" else "aucun"), 280, 12)
	t.custom_minimum_size.y = 30
	t.pressed.connect(func(): a.cycle_title(); _refresh())
	row.add_child(t)
	var an: String = "aucune" if a.aura < 0 else Achievements.REWARDS[a.aura][1]
	var au := MenuKit.button("Aura : %s ▸" % an, 260, 12)
	au.custom_minimum_size.y = 30
	au.pressed.connect(func(): a.cycle_aura(); _refresh())
	row.add_child(au)
	page.add_child(row)


const CAT_ICONS := {"Combat": "sword", "Boss": "skull", "Héros": "heart", "Royaume": "crown", "Histoire": "book",
	"Familiers": "people", "Forge": "gem", "Brume": "moon", "Diplomatie": "shield", "Événements": "sun", "Exploration": "compass"}


func _fill_achievements(a: Achievements) -> void:
	for cat in Achievements.CATEGORIES:
		var items := a.defs().filter(func(d): return d.cat == cat)
		if items.is_empty():
			continue
		var got := items.filter(func(d): return a.done.has(d.id)).size()
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		head.add_child(MenuKit.icon(CAT_ICONS.get(cat, "star"), 22))
		head.add_child(MenuKit.heading("%s" % cat, 15))
		var cnt := MenuKit.label("%d / %d" % [got, items.size()], 11, MenuKit.C_DIM)
		head.add_child(cnt)
		_list.add_child(head)
		for d in items:
			var ok: bool = a.done.has(d.id)
			var v := a.value(d)
			var card := PanelContainer.new()
			card.add_theme_stylebox_override("panel", MenuKit.card(not ok, 8))
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 8)
			card.add_child(h)
			var ic := MenuKit.icon("star" if ok else CAT_ICONS.get(cat, "star"), 20)
			if not ok:
				ic.modulate = Color(0.45, 0.42, 0.4)
			h.add_child(ic)
			var col := VBoxContainer.new()
			col.add_theme_constant_override("separation", 0)
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(col)
			col.add_child(MenuKit.bold(str(d.name), 12, MenuKit.C_GOLD if ok else MenuKit.C_TEXT))
			var l := MenuKit.label(str(d.text) + ((", titre « %s »" % d.title) if str(d.title) != "" else ""), 10, MenuKit.C_DIM)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			col.add_child(l)
			if not ok:
				var bar := ProgressBar.new()
				bar.show_percentage = false
				bar.custom_minimum_size = Vector2(120, 8)
				bar.max_value = float(d.n)
				bar.value = minf(v, float(d.n))
				bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				h.add_child(bar)
				h.add_child(MenuKit.label("%s / %s" % [_num(minf(v, float(d.n))), _num(float(d.n))], 10, MenuKit.C_DIM))
			var pts := MenuKit.bold("+%d" % int(d.pts), 12, MenuKit.C_OK if ok else MenuKit.C_DIM)
			pts.custom_minimum_size.x = 34
			pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			h.add_child(pts)
			_list.add_child(card)


static func _num(v: float) -> String:
	return str(int(v))


## Boss des donjons : [id de la fiche, région].
static func boss_entries() -> Array:
	var out := []
	for r in Achievements.BOSSES:
		var rd := load("res://data/regions/%s.tres" % r) as RegionData
		if rd and rd.boss:
			out.append([rd.boss.resource_path.get_file().get_basename(), r, rd.display_name])
	return out


func _fill_bestiary(a: Achievements) -> void:
	_list.add_child(MenuKit.heading("Créatures", 15))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_list.add_child(grid)
	for id in Achievements.BESTIARY:
		var e := a.bestiary_entry(id)
		grid.add_child(_card(id, e.name if e.known else "???", e.known, e.color))
	_list.add_child(MenuKit.heading("Seigneurs des donjons", 15))
	var g2 := GridContainer.new()
	g2.columns = 5
	g2.add_theme_constant_override("h_separation", 6)
	g2.add_theme_constant_override("v_separation", 6)
	_list.add_child(g2)
	for b in boss_entries():
		var known: bool = player != null and player.souls.has(b[1])
		var ed := load("res://data/enemies/%s.tres" % b[0]) as EnemyData
		g2.add_child(_card(b[0], (ed.display_name.split(",")[0] if ed else b[0]) if known else "???", known, ed.color if ed else Color.WHITE))


## Carte du bestiaire : portrait dans un médaillon, nom dessous. Clic : la fiche s'affiche à droite.
func _card(id: String, title: String, known: bool, color: Color) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(96, 112)
	b.focus_mode = Control.FOCUS_ALL
	var sel := id == _selected or (_selected == "" and id == Achievements.BESTIARY[0])
	b.add_theme_stylebox_override("normal", MenuKit.card(not known, 4) if not sel else UiTheme.box("card_hover", 6, Vector4(4, 3, 4, 3)))
	b.add_theme_stylebox_override("hover", UiTheme.box("card_hover", 6, Vector4(4, 3, 4, 3)))
	b.add_theme_stylebox_override("pressed", UiTheme.box("card_hover", 6, Vector4(4, 3, 4, 3)))
	b.add_theme_stylebox_override("focus", UiTheme.box("button_focus", 6))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 5
	v.offset_right = -5
	v.offset_top = 5
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var p := MenuKit.portrait(id, 72, known)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(p)
	var l := MenuKit.label(title, 9, color.lightened(0.25) if known else MenuKit.C_DIM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size.x = 84
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l)
	b.pressed.connect(func():
		Sound.ui("ui_click")
		_selected = id
		_refresh())
	b.mouse_entered.connect(func(): MenuKit._hover_pulse(b))
	return b


## Fiche détaillée sur parchemin : grand portrait, statistiques, régions, butin, notes du naturaliste.
func _show_entry(id: String) -> void:
	for c in _detail.get_children():
		c.queue_free()
	var a := _ach()
	var is_boss := id.begins_with("boss_")
	var ed := load("res://data/enemies/%s.tres" % id) as EnemyData
	var known := false
	var e := {}
	if is_boss:
		for b in boss_entries():
			if b[0] == id:
				known = player != null and player.souls.has(b[1])
				e = {"regions": [b[2]], "kills": 1 if known else 0}
	else:
		e = a.bestiary_entry(id)
		known = e.known
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	_detail.add_child(v)
	var p := MenuKit.portrait(id, 128, known)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(p)
	var name_l := MenuKit.heading(ed.display_name if known and ed else "Créature inconnue", 15, MenuKit.C_INK)
	name_l.remove_theme_color_override("font_outline_color")
	name_l.add_theme_constant_override("outline_size", 0)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.custom_minimum_size.x = 250
	v.add_child(name_l)
	var regions: Array = e.get("regions", [])
	if not known:
		v.add_child(_ink("Jamais vaincue. On la croise dans : %s." % (", ".join(PackedStringArray(regions)) if not regions.is_empty() else "des lieux inconnus"), 10, MenuKit.C_INK_DIM))
		return
	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 12)
	stats.add_child(_ink_icon("heart", str(ed.max_health)))
	stats.add_child(_ink_icon("sword", str(ed.attack)))
	stats.add_child(_ink_icon("shield", str(ed.defense)))
	if not is_boss:
		stats.add_child(_ink_icon("skull", "× %d" % int(e.kills)))
	v.add_child(stats)
	v.add_child(MenuKit.divider(230))
	v.add_child(_ink("Régions : " + (", ".join(PackedStringArray(regions)) if not regions.is_empty() else "—"), 10))
	if not is_boss:
		v.add_child(_ink("Butin : " + (", ".join(PackedStringArray(e.loot)) if not e.loot.is_empty() else "—"), 10))
		if not e.rare.is_empty():
			v.add_child(_ink("Rare : " + ", ".join(PackedStringArray(e.rare)), 10, Color("7a3a8a")))
	var note := BestiaryLore.note(id)
	var lore := _ink("« %s »" % note[0], 10, MenuKit.C_INK_DIM)
	lore.add_theme_font_override("font", UiTheme.font("title_regular"))
	v.add_child(lore)
	v.add_child(_ink("Conseil : " + str(note[1]), 10))


func _ink(text: String, size := 10, color := MenuKit.C_INK) -> Label:
	var l := MenuKit.label(text, size, color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 250
	return l


func _ink_icon(icon: String, text: String) -> HBoxContainer:
	var h := MenuKit.icon_label(icon, text, 12, MenuKit.C_INK)
	(h.get_child(1) as Label).add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	(h.get_child(1) as Label).add_theme_font_override("font", UiTheme.font("bold"))
	return h


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		if event.is_action_pressed("achievements") and player and not player.ui_open and not player.building and player.is_alive():
			open()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("achievements") or event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
