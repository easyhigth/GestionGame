class_name TalentTreeUI
extends Control
## Fenêtre de l'arbre de compétences (touche T, croix gauche à la manette).
## Une grande carte en étoile : huit branches partent du centre dans toutes les directions et se rejoignent par
## des ponts. Glisser (ou stick droit) pour se déplacer, molette (ou gâchettes) pour zoomer, clic sur un
## nœud pour le voir, « Apprendre » (ou deuxième clic) pour le débloquer. Une compétence apprise se range
## dans la barre de compétences (touches 1 à 0) : choisis son emplacement à droite ou appuie sur la touche.

const C_BG := Color(0.05, 0.04, 0.05, 0.97)
const C_TEXT := Color("f0e6d2")
const C_DIM := Color("a8997f")
const C_GOLD := Color("f2c86a")
const INFO_W := 250.0
const ZOOM_MIN := 0.25
const ZOOM_MAX := 1.6

var player: Player
var _selected := ""
var _canvas: TreeCanvas
var _points: Label
var _info_name: Label
var _info_rar: Label
var _info_kind: Label
var _info_desc: Label
var _info_state: Label
var _learn: Button
var _slot_grid: GridContainer
var _bar: HBoxContainer
var _tab: Button
var _show_pacte := false
var _count: Label


## La carte de l'arbre : dessin, déplacement et zoom.
class TreeCanvas extends Control:
	var ui: TalentTreeUI
	var zoom := 0.55
	var offset := Vector2.ZERO        # décalage de la vue (pixels d'écran)
	var _drag := false
	var _drag_moved := 0.0

	func to_screen(p: Vector2) -> Vector2:
		return size / 2.0 + offset + p * zoom

	func to_tree(s: Vector2) -> Vector2:
		return (s - size / 2.0 - offset) / zoom

	## Centre la vue sur un point de l'arbre.
	func focus(p: Vector2) -> void:
		offset = -p * zoom
		queue_redraw()

	func node_pos(n: Dictionary) -> Vector2:
		if n.has("spec"):
			# spécialisations : la voie, et sa compétence ultime juste en dessous
			return Vector2(200.0 if n.spec == "a" else 400.0, -400.0 if n.kind == "passive" else -300.0)
		if n.has("cls"):
			# compétences de classe : une rangée au-dessus du Pacte
			return Vector2(-400.0 + float(n.col) * 170.0, -350.0)
		if n.get("story", false):
			# Pacte : une grille à part, centrée
			return Vector2((float(n.col) - 1.0) * 190.0, (float(n.row) - 1.5) * 100.0)
		return n.pos

	func node_size(n: Dictionary) -> float:
		if n.get("ultimate", false):
			return 30.0
		if n.get("rune", false):
			return 8.0
		if n.kind == "active":
			return 19.0 if n.get("rarity", "") != "mystique" else 25.0
		return 15.0 if not n.has("bridge") else 13.0

	func visible_nodes() -> Array:
		if ui._show_pacte:
			var cid: String = ui.player.class_id() if ui.player else ""
			return TalentTree.nodes().filter(func(n): return n.get("story", false) or n.get("cls", "-") == cid)
		return TalentTree.nodes().filter(func(n): return not n.get("story", false) and not n.has("cls"))

	func node_at(s: Vector2) -> String:
		var best := ""
		var bd := INF
		for n in visible_nodes():
			var d := to_screen(node_pos(n)).distance_to(s)
			var r := maxf(node_size(n) * zoom, 9.0) + 4.0
			if d < r and d < bd:
				bd = d
				best = n.id
		return best

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					zoom_at(mb.position, 1.15 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15)
				accept_event()
			elif mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_drag = true
					_drag_moved = 0.0
				else:
					_drag = false
					if _drag_moved < 6.0:
						var id := node_at(mb.position)
						if id != "":
							ui._on_node(id)
				accept_event()
		elif event is InputEventMouseMotion and _drag:
			var mm := event as InputEventMouseMotion
			offset += mm.relative
			_drag_moved += mm.relative.length()
			queue_redraw()
			accept_event()

	func zoom_at(screen_pos: Vector2, factor: float) -> void:
		var before := to_tree(screen_pos)
		zoom = clampf(zoom * factor, ZOOM_MIN, ZOOM_MAX)
		offset = screen_pos - size / 2.0 - before * zoom
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.025, 0.04))
		var font := get_theme_default_font()
		var p: Player = ui.player
		if p == null:
			return
		# étoiles de fond
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 160:
			var sp := Vector2(rng.randf_range(-2200, 2200), rng.randf_range(-2200, 2200))
			draw_circle(to_screen(sp), 1.2, Color(1, 1, 1, rng.randf_range(0.08, 0.3)))
		var list := visible_nodes()
		if ui._show_pacte:
			var cname: String = p.profile.hero_class.display_name if p.profile and p.profile.hero_class else "Classe"
			draw_string(font, to_screen(Vector2(-230, -455)) - Vector2(200, 0), "Compétences de classe : %s (niveaux 1, 6, 15)" % cname,
				HORIZONTAL_ALIGNMENT_CENTER, 400, 13, C_GOLD)
			draw_string(font, to_screen(Vector2(300, -455)) - Vector2(200, 0), "Spécialisation (niveau %d) : une voie au choix" % TalentTree.SPEC_LEVEL,
				HORIZONTAL_ALIGNMENT_CENTER, 400, 13, C_GOLD)
			draw_string(font, to_screen(Vector2(0, -222)) - Vector2(200, 0), "Pacte : compétences uniques de l'histoire",
				HORIZONTAL_ALIGNMENT_CENTER, 400, 13, Color("c8a8ff"))
		if not ui._show_pacte:
			# anneaux de niveaux
			for ring in [1, 4, 8, 12, 16]:
				var rd: float = TalentTree.R0 + (ring - 1) * TalentTree.RING_STEP
				draw_arc(to_screen(Vector2.ZERO), rd * zoom, 0, TAU, 96, Color(1, 1, 1, 0.05), 1.0)
				if zoom > 0.3:
					draw_string(font, to_screen(Vector2(0, -rd)) + Vector2(6, -4), "niveau %d" % TalentTree.RING_LEVEL[ring],
						HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.22))
			# le cœur
			var c0 := to_screen(Vector2.ZERO)
			draw_circle(c0, 34.0 * zoom + 6.0, Color("2a2030"))
			draw_arc(c0, 34.0 * zoom + 6.0, 0, TAU, 32, C_GOLD, 2.0)
			draw_string(font, c0 + Vector2(-40, 5), "Éveil", HORIZONTAL_ALIGNMENT_CENTER, 80, 13, C_GOLD)
			# noms des branches, près du centre et au bout
			for b in TalentTree.BRANCHES:
				if b.get("story", false):
					continue
				var d := TalentTree._dir(b.angle)
				draw_string(font, to_screen(d * 92.0) - Vector2(50, -5), b.name, HORIZONTAL_ALIGNMENT_CENTER, 100, 14, (b.color as Color).lightened(0.2))
				var ep := to_screen(d * (TalentTree.R0 + 16 * TalentTree.RING_STEP + 70.0))
				draw_string(font, ep - Vector2(60, -6), (b.name as String).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 120, 16, Color(b.color as Color, 0.6))
		# liens
		for n in list:
			var col: Color = TalentTree.branch(n.branch).color
			for r in n.get("requires", []):
				var m := TalentTree.node(r)
				if m.is_empty():
					continue
				var on: bool = p.talents.has(r) and p.talents.has(n.id)
				var open: bool = p.talents.has(r) or p.talents.has(n.id)
				draw_line(to_screen(node_pos(m)), to_screen(node_pos(n)), col if on else (Color(col.darkened(0.45), 0.8) if open else Color(0.25, 0.22, 0.2, 0.7)),
					(4.0 if on else 2.0) * clampf(zoom * 1.6, 0.6, 1.6), true)
			if not n.get("story", false) and int(n.get("ring", 0)) == 1:
				draw_line(to_screen(Vector2.ZERO), to_screen(node_pos(n)), Color(col, 0.6 if p.talents.has(n.id) else 0.25), 2.0, true)
		# nœuds
		var t := Time.get_ticks_msec() * 0.003
		for n in list:
			var sp := to_screen(node_pos(n))
			if sp.x < -60 or sp.y < -60 or sp.x > size.x + 60 or sp.y > size.y + 60:
				continue
			var learned: bool = p.talents.has(n.id)
			var can := p.talent_block_reason(n.id) == ""
			var rar: Dictionary = TalentTree.RARITIES.get(n.get("rarity", "commune"), TalentTree.RARITIES.commune)
			var rcol: Color = rar.color
			var bcol: Color = n.get("color", TalentTree.branch(n.branch).color)
			var r := maxf(node_size(n) * zoom, 5.0)
			var fill: Color = bcol.darkened(0.2) if learned else (Color("3a2e26") if can else Color("1c1816"))
			var border: Color = rcol if (learned or can) else Color(rcol, 0.45)
			var w := 2.5
			if n.id == ui._selected:
				border = Color.WHITE
				w = 4.0
			if n.get("rarity", "") == "mystique" or n.get("ultimate", false):
				# halo des mystiques
				draw_circle(sp, r * (1.7 + 0.15 * sin(t)), Color(rcol, 0.18))
				draw_circle(sp, r * 1.35, Color(rcol, 0.22))
			if n.kind == "active":
				var rect := Rect2(sp - Vector2(r, r), Vector2(r, r) * 2.0)
				draw_rect(rect, fill)
				draw_rect(rect, border, false, w)
			else:
				draw_circle(sp, r, fill)
				draw_arc(sp, r, 0, TAU, 20, border, w, true)
			if r >= 9.0:
				var gl: String = n.glyph if not (n.get("story", false) and not learned) else "?"
				var fs := int(clampf(r * 1.1, 8, 30))
				draw_string(font, sp + Vector2(-r, fs * 0.36), gl, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs,
					Color.WHITE if learned else (bcol.lightened(0.3) if can else Color(0.5, 0.45, 0.4)))
			# nom (si le zoom le permet), niveau requis pour les nœuds pas encore atteints
			if not n.get("rune", false) and (zoom >= 0.75 or (zoom >= 0.4 and n.get("rarity", "") in ["mystique", "legendaire"]) or n.get("ultimate", false) or ui._show_pacte):
				var nm: String = n.name if not (n.get("story", false) and not learned) else "???"
				draw_string(font, sp + Vector2(-70, r + 13), nm, HORIZONTAL_ALIGNMENT_CENTER, 140, 10 if zoom < 0.9 else 12,
					rcol.lightened(0.3) if learned or can else Color(0.6, 0.55, 0.5))
			if not learned and not n.get("story", false) and p.level < int(n.level) and (zoom >= 0.45 or n.get("rarity", "") == "mystique"):
				draw_string(font, sp + Vector2(r * 0.6, -r * 0.6), "N%d" % int(n.level), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("ff8a6a"))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.015, 0.02, 0.8)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", MenuKit.style(C_BG, Color("8a6a3a"), 2, 6, 8))
	margin.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	# en-tête
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	head.add_child(MenuKit.title("Arbre de compétences", 18))
	_points = MenuKit.label("", 13, C_GOLD)
	_points.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_points.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_points)
	_tab = MenuKit.button("", 170, 11)
	_tab.pressed.connect(func():
		_show_pacte = not _show_pacte
		_selected = ""
		_canvas.zoom = 0.6 if _show_pacte else 0.55
		_canvas.focus(Vector2(0, -95) if _show_pacte else Vector2.ZERO)
		_refresh())
	head.add_child(_tab)
	# milieu : la carte et les informations
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 10)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(mid)
	_canvas = TreeCanvas.new()
	_canvas.ui = self
	_canvas.clip_contents = true
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.custom_minimum_size = Vector2(200, 200)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	mid.add_child(_canvas)
	var info := PanelContainer.new()
	info.add_theme_stylebox_override("panel", MenuKit.style(Color("1e1816"), Color("5a4632"), 1, 4, 8))
	info.custom_minimum_size = Vector2(INFO_W, 0)
	mid.add_child(info)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 6)
	info.add_child(iv)
	_info_name = _wrap_label(16, C_GOLD)
	iv.add_child(_info_name)
	_info_rar = _wrap_label(12, C_DIM)
	iv.add_child(_info_rar)
	_info_kind = _wrap_label(10, C_DIM)
	iv.add_child(_info_kind)
	_info_desc = _wrap_label(12, C_TEXT)
	iv.add_child(_info_desc)
	_info_state = _wrap_label(11, C_DIM)
	iv.add_child(_info_state)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	iv.add_child(spacer)
	_learn = MenuKit.button("Apprendre", INFO_W - 16, 13)
	_learn.pressed.connect(_learn_selected)
	iv.add_child(_learn)
	_slot_grid = GridContainer.new()
	_slot_grid.columns = 5
	_slot_grid.add_theme_constant_override("h_separation", 4)
	_slot_grid.add_theme_constant_override("v_separation", 4)
	iv.add_child(_slot_grid)
	_count = _wrap_label(10, C_DIM)
	iv.add_child(_count)
	var legend := HFlowContainer.new()
	legend.add_theme_constant_override("h_separation", 8)
	legend.custom_minimum_size = Vector2(INFO_W - 16, 0)
	iv.add_child(legend)
	for k in TalentTree.RARITY_ORDER:
		var rr: Dictionary = TalentTree.RARITIES[k]
		legend.add_child(MenuKit.label("■ " + str(rr.name), 11, rr.color))
	# bas : la barre de compétences et les boutons
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	v.add_child(foot)
	foot.add_child(MenuKit.label("Barre (1-0) :", 11, C_DIM))
	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 4)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_bar)
	var center_b := MenuKit.button("Centrer", 72, 11)
	center_b.pressed.connect(func(): _canvas.focus(Vector2.ZERO))
	foot.add_child(center_b)
	var reset := MenuKit.button("Tout oublier", 100, 11)
	reset.tooltip_text = "Rend tous les points (le talent de ta classe et les compétences de l'histoire sont gardés)."
	reset.pressed.connect(func():
		player.reset_talents()
		_selected = ""
		_refresh())
	foot.add_child(reset)
	var close := MenuKit.button("Fermer (T)", 100, 11)
	close.pressed.connect(close_ui)
	foot.add_child(close)


func _wrap_label(fs: int, col: Color) -> Label:
	var l := MenuKit.label("", fs, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(INFO_W - 16, 0)
	return l


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
	_canvas.zoom = 0.55
	_canvas.focus(Vector2.ZERO)
	_refresh()


func close_ui() -> void:
	hide()
	get_tree().paused = false
	if player:
		player.ui_open = false


func _process(delta: float) -> void:
	if not visible:
		return
	# manette : déplacer la vue (stick droit), zoomer (gâchettes)
	var pan := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if pan.length() > 0.2:
		_canvas.offset -= pan * 700.0 * delta
	var zt := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) - Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT)
	if absf(zt) > 0.2:
		_canvas.zoom_at(_canvas.size / 2.0, 1.0 + zt * delta * 1.5)
	# les halos des mystiques pulsent
	_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		if event.is_action_pressed("talents") and player and not player.ui_open and not player.building and player.is_alive():
			open()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("talents") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		close_ui()
		get_viewport().set_input_as_handled()
		return
	# flèches / croix : passer au nœud voisin dans cette direction
	for dir in [["ui_left", Vector2.LEFT], ["ui_right", Vector2.RIGHT], ["ui_up", Vector2.UP], ["ui_down", Vector2.DOWN]]:
		if event.is_action_pressed(dir[0]):
			_step(dir[1])
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_accept") and _selected != "":
		_on_node(_selected)
		get_viewport().set_input_as_handled()
		return
	if _selected != "":
		for i in TalentTree.SLOTS:
			if event.is_action_pressed("ability_%d" % (i + 1)) and player.abilities.has(_selected):
				player.set_ability_slot(i, _selected)
				_refresh()
				get_viewport().set_input_as_handled()


## Sélectionne le nœud le plus proche dans une direction (clavier, manette).
func _step(dir: Vector2) -> void:
	var from := Vector2.ZERO
	if _selected != "":
		from = _canvas.node_pos(TalentTree.node(_selected))
	var best := ""
	var bs := INF
	for n in _canvas.visible_nodes():
		var d: Vector2 = _canvas.node_pos(n) - from
		if d.length() < 1.0 or d.normalized().dot(dir) < 0.5:
			continue
		var score := d.length() * (2.0 - d.normalized().dot(dir))
		if score < bs:
			bs = score
			best = n.id
	if best != "":
		_selected = best
		_canvas.focus(_canvas.node_pos(TalentTree.node(best)))
		_refresh()


## Sélectionne un nœud et centre la vue dessus.
func select(id: String) -> void:
	_selected = id
	_show_pacte = TalentTree.is_story(id) or TalentTree.is_class_skill(id)
	_canvas.focus(_canvas.node_pos(TalentTree.node(id)))
	_refresh()


func _on_node(id: String) -> void:
	# deuxième clic sur le même nœud : on l'apprend
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
	var rar := TalentTree.rarity(id)
	var hidden: bool = n.get("story", false) and not player.talents.has(id)
	_info_name.text = n.name if not hidden else "Compétence inconnue"
	_info_name.add_theme_color_override("font_color", (rar.color as Color).lightened(0.25))
	if n.has("spec"):
		_info_rar.text = "Spécialisation" + ("  ·  voie" if n.kind == "passive" else "  ·  compétence ultime")
		_info_kind.text = "%s  ·  niveau %d, sans point%s" % [player.profile.hero_class.display_name if player.profile and player.profile.hero_class else "Classe",
			int(n.level), ("\nRecharge %d s" % roundi(n.cooldown)) if n.kind == "active" else "\nBonus permanent + compétence ultime"]
	elif n.has("cls"):
		_info_rar.text = "%s  ·  Compétence de classe" % rar.name
		_info_kind.text = "%s  ·  recharge %d s\nOfferte au niveau %d, sans point" % [player.profile.hero_class.display_name if player.profile and player.profile.hero_class else "Classe",
			roundi(n.cooldown), int(n.level)]
	elif n.get("story", false):
		_info_rar.text = "Compétence unique de l'histoire"
		_info_kind.text = "Pacte  ·  offerte par l'histoire principale"
	else:
		var what := "Compétence ultime" if n.get("ultimate", false) else ("Compétence active" if n.kind == "active" else ("Rune" if n.get("rune", false) else "Talent"))
		_info_rar.text = "%s  ·  %s" % [rar.name, what]
		var kind := "recharge %d s" % roundi(n.cooldown) if n.kind == "active" else "bonus permanent"
		_info_kind.text = "%s  ·  %s\nNiveau %d  ·  coût %d point%s" % [b.name if not n.has("bridge") else "Pont", kind, int(n.level),
			TalentTree.cost(id), "s" if TalentTree.cost(id) > 1 else ""]
	_info_rar.add_theme_color_override("font_color", rar.color)
	_info_desc.text = n.desc if not hidden else "Une compétence unique t'attend quelque part dans l'histoire principale. Avance dans ta quête (O : journal) pour la découvrir."
	var reason := player.talent_block_reason(id)
	if player.talents.has(id):
		_info_state.text = "Appris" + ("  ·  offert par ta classe" if id == player.class_talent() or n.has("cls") else "")
		_info_state.add_theme_color_override("font_color", MenuKit.C_OK)
	elif reason == "":
		_info_state.text = "Disponible : « Apprendre » (ou clique une deuxième fois)."
		_info_state.add_theme_color_override("font_color", C_GOLD)
	else:
		_info_state.text = reason
		_info_state.add_theme_color_override("font_color", MenuKit.C_BAD)
	_learn.disabled = reason != ""
	_learn.visible = not player.talents.has(id)
	for c in _slot_grid.get_children():
		c.queue_free()
	if n.kind == "active" and player.talents.has(id):
		for i in TalentTree.SLOTS:
			var sb := MenuKit.button(str((i + 1) % 10), 42, 12)
			sb.custom_minimum_size = Vector2(42, 28)
			if player.ability_slots[i] == id:
				sb.add_theme_color_override("font_color", C_GOLD)
				sb.add_theme_stylebox_override("normal", MenuKit.style(Color("5a4636"), C_GOLD, 2, 4, 4))
			sb.tooltip_text = "Placer dans l'emplacement %d" % ((i + 1) % 10)
			sb.pressed.connect(func():
				player.set_ability_slot(i, id)
				_refresh())
			_slot_grid.add_child(sb)


func _refresh() -> void:
	if player == null:
		return
	var learned := player.talents.keys().filter(func(t): return not TalentTree.is_story(t) and not TalentTree.is_class_skill(t)).size()
	var total := TalentTree.nodes().filter(func(n): return not n.get("story", false) and not n.has("cls")).size()
	_points.text = "Points : %d  ·  Niveau %d  ·  %d / %d nœuds" % [player.talent_points(), player.level, learned, total]
	var known := player.talents.keys().filter(func(t): return TalentTree.is_story(t)).size()
	var ptotal := TalentTree.nodes().filter(func(n): return n.get("story", false)).size()
	_tab.text = "← Arbre de combat" if _show_pacte else "✦ Classe et Pacte (%d / %d)" % [known, ptotal]
	var actives := TalentTree.nodes().filter(func(n): return n.kind == "active" and not n.get("story", false) and not n.has("cls"))
	var by_rar := {}
	for n in actives:
		by_rar[n.rarity] = int(by_rar.get(n.rarity, 0)) + 1
	var parts := []
	for k in TalentTree.RARITY_ORDER:
		parts.append("%d %s" % [int(by_rar.get(k, 0)), (TalentTree.RARITIES[k].name as String).to_lower()])
	_count.text = "%d compétences actives : %s." % [actives.size(), ", ".join(parts)]
	_canvas.queue_redraw()
	for c in _bar.get_children():
		c.queue_free()
	for i in TalentTree.SLOTS:
		var id: String = player.ability_slots[i]
		var n := TalentTree.node(id) if id != "" else {}
		var l := MenuKit.label("%d %s" % [(i + 1) % 10, n.glyph if not n.is_empty() else "·"], 12,
			(TalentTree.rarity(id).color as Color).lightened(0.2) if not n.is_empty() else C_DIM)
		l.tooltip_text = n.get("name", "")
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		l.custom_minimum_size = Vector2(36, 0)
		_bar.add_child(l)
	if _selected != "":
		_show(_selected)
	else:
		_info_name.text = "Choisis un nœud"
		_info_name.add_theme_color_override("font_color", C_GOLD)
		_info_rar.text = ""
		_info_kind.text = "Petits ronds : runes  ·  grands ronds : talents  ·  carrés : compétences actives"
		_info_desc.text = "Huit branches partent du centre : apprends un nœud relié à ce que tu connais déjà, en partant du centre. Les ponts relient les branches voisines. Plus on s'éloigne, plus il faut de niveaux, jusqu'aux compétences mystiques et au Cataclysme (niveau 990).\nGlisser : se déplacer  ·  molette : zoomer."
		_info_state.text = ""
		_learn.visible = false
		for c in _slot_grid.get_children():
			c.queue_free()
