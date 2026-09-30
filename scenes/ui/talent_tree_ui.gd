class_name TalentTreeUI
extends Control
## Fenêtre de l'arbre de talents (touche T, croix gauche à la manette).
## Trois branches côte à côte ; clic sur un talent pour le voir, « Apprendre » pour le débloquer.
## Un talent actif appris se range dans un des 4 emplacements (touches 1-4 en jeu).

const C_BG := Color(0.07, 0.055, 0.05, 0.96)
const C_TEXT := Color("f0e6d2")
const C_DIM := Color("a8997f")
const C_GOLD := Color("f2c86a")
const C_LOCK := Color("4a4038")
const NODE := 42.0
const COL_W := 72.0
const ROW_H := 64.0
const INFO_W := 196.0
## Colonnes plus larges pour la branche Pacte (noms plus longs), affichée seule dans son onglet.
const PACT_COL_W := 118.0

var player: Player
var _selected := ""
var _views := []
var _buttons := {}
var _caps := {}
var _points: Label
var _info_name: Label
var _info_kind: Label
var _info_desc: Label
var _info_state: Label
var _learn: Button
var _slot_row: HBoxContainer
var _bar: HBoxContainer
var _branch_panels := {}
var _show_pacte := false
var _tab: Button


class BranchView extends Control:
	## Dessine les liens entre les talents d'une branche.
	var ui: TalentTreeUI
	var branch: Dictionary

	func _draw() -> void:
		for n in TalentTree.NODES:
			if n.branch != branch.id:
				continue
			for r in n.get("requires", []):
				var m := TalentTree.node(r)
				var a := ui.node_center(m)
				var b := ui.node_center(n)
				var on: bool = ui.player.talents.has(r) and ui.player.talents.has(n.id)
				var open: bool = ui.player.talents.has(r)
				var col: Color = (branch.color if on else (branch.color.darkened(0.35) if open else Color(0.3, 0.26, 0.22)))
				draw_line(a, b, col, 5.0 if on else 3.0, true)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.015, 0.02, 0.7)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", MenuKit.style(C_BG, Color("8a6a3a"), 2, 6, 9))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := MenuKit.title("Arbre de talents", 18)
	head.add_child(title)
	_points = MenuKit.label("", 12, C_GOLD)
	_points.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_points.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_points)
	# onglet : talents (3 branches) / compétences uniques de l'histoire (Pacte)
	_tab = MenuKit.button("", 190, 11)
	_tab.pressed.connect(func():
		_show_pacte = not _show_pacte
		_selected = ""
		_refresh())
	head.add_child(_tab)
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 10)
	v.add_child(mid)
	var branches := HBoxContainer.new()
	branches.add_theme_constant_override("separation", 8)
	mid.add_child(branches)
	for b in TalentTree.BRANCHES:
		var bp := PanelContainer.new()
		bp.add_theme_stylebox_override("panel", MenuKit.style(Color(b.color.darkened(0.8), 0.6), b.color.darkened(0.3), 1, 5, 6))
		branches.add_child(bp)
		_branch_panels[b.id] = bp
		var cw := _col_w(b.id)
		var bv := VBoxContainer.new()
		bp.add_child(bv)
		var bt := MenuKit.label(b.name, 14, b.color.lightened(0.3))
		bt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bv.add_child(bt)
		var bd := MenuKit.label(b.desc, 8, C_DIM if not b.get("story", false) else b.color)
		bd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bd.custom_minimum_size = Vector2(cw * 3, 0)
		bv.add_child(bd)
		var view := BranchView.new()
		view.ui = self
		view.branch = b
		view.custom_minimum_size = Vector2(cw * 3, ROW_H * 5)
		bv.add_child(view)
		_views.append(view)
		for n in TalentTree.NODES:
			if n.branch != b.id:
				continue
			var btn := Button.new()
			btn.text = n.glyph
			btn.custom_minimum_size = Vector2(NODE, NODE)
			btn.size = Vector2(NODE, NODE)
			btn.position = node_center(n) - Vector2(NODE, NODE) / 2.0
			btn.add_theme_font_size_override("font_size", 18)
			btn.tooltip_text = n.name
			btn.pressed.connect(_on_node.bind(n.id))
			btn.mouse_entered.connect(func(): if _selected == "": _show(n.id))
			view.add_child(btn)
			var cap := MenuKit.label(n.name, 8, C_DIM)
			cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cap.size = Vector2(cw + 8, 12)
			cap.position = node_center(n) + Vector2(-cw / 2.0 - 4, NODE / 2.0)
			view.add_child(cap)
			_caps[n.id] = cap
			var lv := MenuKit.label("", 8, C_DIM)
			lv.position = Vector2(NODE - 16, -3)
			lv.name = "Lv"
			btn.add_child(lv)
			_buttons[n.id] = btn
	# informations sur le talent choisi (colonne de droite)
	var info := PanelContainer.new()
	info.add_theme_stylebox_override("panel", MenuKit.style(Color("241d1a"), Color("5a4632"), 1, 4, 8))
	mid.add_child(info)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 6)
	info.add_child(iv)
	_info_name = MenuKit.label("", 15, C_GOLD)
	_info_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_name.custom_minimum_size = Vector2(INFO_W, 0)
	iv.add_child(_info_name)
	_info_kind = MenuKit.label("", 9, C_DIM)
	_info_kind.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_kind.custom_minimum_size = Vector2(INFO_W, 0)
	iv.add_child(_info_kind)
	_info_desc = MenuKit.label("", 11, C_TEXT)
	_info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_desc.custom_minimum_size = Vector2(INFO_W, 0)
	iv.add_child(_info_desc)
	_info_state = MenuKit.label("", 10, C_DIM)
	_info_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_state.custom_minimum_size = Vector2(INFO_W, 0)
	iv.add_child(_info_state)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	iv.add_child(spacer)
	var act := VBoxContainer.new()
	act.add_theme_constant_override("separation", 6)
	iv.add_child(act)
	_learn = MenuKit.button("Apprendre", INFO_W, 13)
	_learn.pressed.connect(_learn_selected)
	act.add_child(_learn)
	_slot_row = HBoxContainer.new()
	_slot_row.add_theme_constant_override("separation", 4)
	act.add_child(_slot_row)
	# bas : emplacements et boutons
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	v.add_child(foot)
	foot.add_child(MenuKit.label("Touches 1-4 :", 11, C_DIM))
	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 6)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_bar)
	var reset := MenuKit.button("Oublier les talents", 150, 11)
	reset.tooltip_text = "Rend tous les points (le talent de ta classe est gardé)."
	reset.pressed.connect(func():
		player.reset_talents()
		_selected = ""
		_refresh())
	foot.add_child(reset)
	var close := MenuKit.button("Fermer (T)", 100, 11)
	close.pressed.connect(close_ui)
	foot.add_child(close)


func _col_w(branch_id: String) -> float:
	return PACT_COL_W if branch_id == "pacte" else COL_W


func node_center(n: Dictionary) -> Vector2:
	return Vector2((n.col + 0.5) * _col_w(n.branch), (n.row + 0.5) * ROW_H - 8.0)


func open() -> void:
	Sound.ui("ui_open")
	if player == null or player.ui_open or player.building:
		return
	get_parent().move_child(self, get_parent().get_child_count() - 1)
	show()
	player.ui_open = true
	get_tree().paused = true
	_selected = ""
	_show_pacte = false
	_refresh()
	var first: Button = _buttons.values()[0]
	first.grab_focus.call_deferred()


func close_ui() -> void:
	hide()
	get_tree().paused = false
	if player:
		player.ui_open = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		if event.is_action_pressed("talents") and player and not player.ui_open and not player.building and player.is_alive():
			open()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("talents") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		close_ui()
		get_viewport().set_input_as_handled()
	elif _selected != "":
		for i in TalentTree.SLOTS:
			if event.is_action_pressed("ability_%d" % (i + 1)) and player.abilities.has(_selected):
				player.set_ability_slot(i, _selected)
				_refresh()
				get_viewport().set_input_as_handled()


func _on_node(id: String) -> void:
	# deuxième appui sur le même talent : on l'apprend (pratique à la manette)
	if _selected == id and player.talent_block_reason(id) == "":
		_learn_selected()
		return
	_selected = id
	_refresh()


func _learn_selected() -> void:
	if _selected != "" and player.unlock_talent(_selected):
		_refresh()


func _show(id: String) -> void:
	var n := TalentTree.node(id)
	if n.is_empty():
		return
	var b := TalentTree.branch(n.branch)
	_info_name.text = n.name
	var hidden: bool = n.get("story", false) and not player.talents.has(id)
	_info_name.add_theme_color_override("font_color", b.color.lightened(0.35))
	var kind := "Actif (recharge %d s)" % roundi(n.cooldown) if n.kind == "active" else "Passif (bonus permanent)"
	if n.get("story", false):
		_info_kind.text = "Compétence unique de l'histoire  ·  %s" % kind
	else:
		_info_kind.text = "%s  ·  %s\nRang %d (niveau %d)  ·  coût %d point%s" % [b.name, kind, n.row + 1, TalentTree.ROW_LEVEL[n.row],
			TalentTree.cost(id), "s" if TalentTree.cost(id) > 1 else ""]
	_info_desc.text = n.desc
	if hidden:
		_info_name.text = "Compétence inconnue"
		_info_desc.text = "Une compétence unique t'attend quelque part dans l'histoire principale. Avance dans ta quête (O : journal) pour la découvrir."
	var reason := player.talent_block_reason(id)
	if player.talents.has(id):
		_info_state.text = "Appris" + ("  ·  offert par ta classe" if id == player.class_talent() else "")
		_info_state.add_theme_color_override("font_color", MenuKit.C_OK)
	elif reason == "":
		_info_state.text = "Disponible : clique sur « Apprendre » (ou appuie une deuxième fois sur le talent)."
		_info_state.add_theme_color_override("font_color", C_GOLD)
	else:
		_info_state.text = reason
		_info_state.add_theme_color_override("font_color", MenuKit.C_BAD)
	_learn.disabled = reason != ""
	_learn.visible = not player.talents.has(id)
	for c in _slot_row.get_children():
		c.queue_free()
	if n.kind == "active" and player.talents.has(id):
		_slot_row.add_child(MenuKit.label("Touche :", 10, C_DIM))
		for i in TalentTree.SLOTS:
			var sb := MenuKit.button(str(i + 1), 32, 12)
			sb.custom_minimum_size = Vector2(32, 28)
			if player.ability_slots[i] == id:
				sb.add_theme_color_override("font_color", C_GOLD)
				sb.add_theme_stylebox_override("normal", MenuKit.style(Color("5a4636"), C_GOLD, 2, 4, 4))
			sb.pressed.connect(func():
				player.set_ability_slot(i, id)
				_refresh())
			_slot_row.add_child(sb)


func _refresh() -> void:
	if player == null:
		return
	_points.text = "Points de talent : %d   ·   Niveau %d" % [player.talent_points(), player.level]
	var known := player.talents.keys().filter(func(t): return TalentTree.is_story(t)).size()
	var total := TalentTree.NODES.filter(func(n): return n.get("story", false)).size()
	_tab.text = "← Talents de combat" if _show_pacte else "✦ Pacte : %d / %d" % [known, total]
	for bid in _branch_panels:
		(_branch_panels[bid] as Control).visible = (bid == "pacte") == _show_pacte
	for id in _buttons:
		var n := TalentTree.node(id)
		var b := TalentTree.branch(n.branch)
		var btn: Button = _buttons[id]
		var learned: bool = player.talents.has(id)
		var can := player.talent_block_reason(id) == ""
		var bg: Color = b.color.darkened(0.25) if learned else (Color("3a2e26") if can else Color("241e1a"))
		var border: Color = b.color.lightened(0.3) if learned else (C_GOLD if can else C_LOCK)
		var width := 3 if (id == _selected) else 2
		if id == _selected:
			border = Color.WHITE
		var st := MenuKit.style(bg, border, width, 6 if n.kind == "active" else 21, 2)
		btn.add_theme_stylebox_override("normal", st)
		btn.add_theme_stylebox_override("hover", MenuKit.style(bg.lightened(0.1), C_GOLD, width, 6 if n.kind == "active" else 21, 2))
		btn.add_theme_stylebox_override("focus", MenuKit.style(bg.lightened(0.1), Color.WHITE, 3, 6 if n.kind == "active" else 21, 2))
		btn.add_theme_color_override("font_color", Color.WHITE if learned else (b.color.lightened(0.2) if can else Color(0.45, 0.4, 0.36)))
		var lv := btn.get_node("Lv") as Label
		(_caps[id] as Label).text = "???" if n.get("story", false) and not learned else n.name
		lv.text = "" if learned or n.get("story", false) or player.level >= TalentTree.ROW_LEVEL[n.row] else "N%d" % TalentTree.ROW_LEVEL[n.row]
		if n.get("story", false) and not learned:
			btn.text = "?"
		elif n.get("story", false):
			btn.text = n.glyph
	for v in _views:
		v.queue_redraw()
	for c in _bar.get_children():
		c.queue_free()
	for i in TalentTree.SLOTS:
		var id: String = player.ability_slots[i]
		var n := TalentTree.node(id) if id != "" else {}
		var l := MenuKit.label("%d : %s" % [i + 1, n.name if not n.is_empty() else "—"], 10,
			TalentTree.branch(n.branch).color.lightened(0.3) if not n.is_empty() else C_DIM)
		l.custom_minimum_size = Vector2(118, 0)
		_bar.add_child(l)
	if _selected != "":
		_show(_selected)
	else:
		_info_name.text = "Choisis un talent"
		_info_name.add_theme_color_override("font_color", C_GOLD)
		_info_kind.text = "Ronds : talents passifs (bonus permanents)  ·  Carrés : talents actifs (nouvelles attaques et nouveaux sorts)"
		_info_desc.text = "Chaque niveau te donne 1 point, chaque âme de boss absorbée 1 de plus. Un talent se débloque quand tu as le niveau de son rang et un talent relié juste au-dessus."
		_info_state.text = ""
		_learn.visible = false
		for c in _slot_row.get_children():
			c.queue_free()
