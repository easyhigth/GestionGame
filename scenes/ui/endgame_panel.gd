class_name EndgamePanel
extends Control
## Panneau du Portail des Failles (E devant le portail, près du village) : choix du palier du monde,
## choix du rang de faille et entrée, et le point sur les titans.

var player: Player
var _box: VBoxContainer
var _rank := 1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0, 0.08, 0.6)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box = MenuKit.panel(self, 660)


func _eg() -> Endgame:
	return get_tree().get_first_node_in_group("endgame") as Endgame


func open() -> void:
	if player == null or player.building or _eg() == null:
		return
	_rank = _eg().best_rift + 1
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


func _stepper(value: String, on_prev: Callable, on_next: Callable, col := MenuKit.C_GOLD) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 8)
	var prev := MenuKit.button("◀", 40, 13)
	prev.pressed.connect(func():
		on_prev.call()
		_refresh())
	h.add_child(prev)
	var v := MenuKit.label(value, 15, col)
	v.custom_minimum_size.x = 300
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(v)
	var nxt := MenuKit.button("▶", 40, 13)
	nxt.pressed.connect(func():
		on_next.call()
		_refresh())
	h.add_child(nxt)
	return h


func _text(t: String, size := 11, col := MenuKit.C_TEXT) -> Label:
	var l := MenuKit.label(t, size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 620
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _refresh() -> void:
	for c in _box.get_children():
		c.queue_free()
	var eg := _eg()
	_box.add_child(MenuKit.title("Portail des Failles", 22))
	# palier du monde
	_box.add_child(MenuKit.section("Palier du monde : monstres plus forts, plus de butin", "skull", 14))
	var t := eg.tier
	_box.add_child(_stepper("%s  (palier %d)" % [Endgame.TIER_NAMES[t], t],
		func(): eg.set_tier(maxi(0, eg.tier - 1)),
		func(): eg.set_tier(mini(eg.max_tier(), eg.tier + 1)),
		Color("ff9ad8") if t >= 4 else MenuKit.C_GOLD))
	_box.add_child(_text("Monstres +%d niveaux  ·  expérience ×%s  ·  butin de niveau : %d %% des monstres" % [
		t * Endgame.TIER_BONUS, str(eg.xp_mult()).replace(".", ","), roundi((0.03 + 0.006 * t) * 100) if t > 0 else 0]))
	var nxt := t + 1
	if nxt < Endgame.TIER_LEVEL.size() and nxt > eg.max_tier():
		_box.add_child(_text("Prochain palier (%s) au niveau %d." % [Endgame.TIER_NAMES[nxt], Endgame.TIER_LEVEL[nxt]], 10, MenuKit.C_DIM))
	# failles
	_box.add_child(MenuKit.section("Failles : vagues de monstres et leur gardien", "magic", 14))
	_rank = clampi(_rank, 1, eg.best_rift + 1)
	_box.add_child(_stepper("Rang %d  ·  monstres niveau %d" % [_rank, eg.rift_level(_rank)],
		func(): _rank = maxi(1, _rank - 1),
		func(): _rank = mini(eg.best_rift + 1, _rank + 1)))
	_box.add_child(_text("Trois vagues de monstres, puis le gardien. Le vaincre ouvre le rang suivant et fait tomber du butin de niveau %d (jusqu'à Mystique)." % eg.rift_level(_rank)))
	var afx: Array = eg.rift_affixes(_rank)
	_box.add_child(_text("%s%s" % [eg.rift_theme(_rank)[0], ("  ·  Modificateurs : " + eg.affixes_text(afx)) if not afx.is_empty() else "  ·  aucun modificateur"], 10, Color("ff9a6a") if not afx.is_empty() else MenuKit.C_DIM))
	_box.add_child(_text("Meilleur rang vaincu : %d" % eg.best_rift, 12, MenuKit.C_GOLD))
	var enter := MenuKit.button("Entrer dans la faille", 260, 14)
	enter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	enter.pressed.connect(func():
		close()
		eg.enter_rift(_rank))
	_box.add_child(enter)
	# titans
	_box.add_child(MenuKit.section("Titans : géants qui rôdent dans le monde", "crown", 14))
	if eg.titan.is_empty():
		_box.add_child(_text("Aucun titan éveillé. Un titan s'éveille tous les deux ou trois jours (à partir du niveau 30)." if player.power_level() >= 30
			else "Les titans dorment encore : ils s'éveilleront quand tu auras atteint le niveau 30."))
	else:
		_box.add_child(_text("%s (niveau %d) rôde dans le monde : il est marqué sur la carte (M)." % [eg.titan.name, int(eg.titan.level)], 12, Color("ffb050")))
	_box.add_child(_text("Titans vaincus : %d" % eg.titans_slain, 11, MenuKit.C_DIM))
	var close_b := MenuKit.button("Fermer", 200, 13)
	close_b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_b.pressed.connect(close)
	_box.add_child(close_b)


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		close()
		get_viewport().set_input_as_handled()
