class_name JournalPanel
extends Control
## Journal de l'histoire (touche O) : les actes, les étapes faites et l'objectif en cours,
## les éclats du Cœur d'Aube déjà rassemblés et les personnages rencontrés.

var player: Player
var _box: VBoxContainer
var _list: VBoxContainer
var _scroll: ScrollContainer
var _head: Array = []
var _tab := "histoire"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box = MenuKit.panel(self, 720)
	# seize actes : la liste défile
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
	scroll.add_child(_list)
	_scroll = scroll


func open() -> void:
	if player == null or player.ui_open or player.building:
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


func _label(text: String, size := 12, col := MenuKit.C_TEXT) -> Label:
	var l := MenuKit.label(text, size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(670, 0)
	return l


func _refresh() -> void:
	for c in _head:
		if is_instance_valid(c):
			c.queue_free()
	_head.clear()
	for c in _list.get_children():
		c.queue_free()
	var st := get_tree().get_first_node_in_group("story") as Story
	var t := MenuKit.title("Journal — L'Éveil du Royaume", 20)
	_box.add_child(t)
	_box.move_child(t, 0)
	_head.append(t)
	if st == null:
		return
	# onglets : l'histoire, ou la galerie des personnages
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 10)
	for tb in [["histoire", "Histoire"], ["personnages", "Personnages"]]:
		var b := MenuKit.tab(tb[1], _tab == tb[0], 200, 12)
		var key: String = tb[0]
		b.pressed.connect(func():
			if _tab != key:
				_tab = key
				_refresh()
				MenuKit.fade_in(_scroll))
		tabs.add_child(b)
	_box.add_child(tabs)
	_box.move_child(tabs, 1)
	_head.append(tabs)
	if _tab == "personnages":
		_fill_people(st)
		var cb := MenuKit.button("Fermer (O)", 200, 13)
		cb.pressed.connect(close)
		_add_foot(cb)
		return
	var cur_act: int = st.current()[1] if not st.is_done() else Story.ACTS.size() + 1
	var cur_label: Control = null
	for act in Story.ACTS:
		if act > cur_act:
			_list.add_child(_label("%s  ·  ???" % Story.ACTS[act], 13, MenuKit.C_DIM))
			continue
		_list.add_child(_label(Story.ACTS[act], 15, MenuKit.C_GOLD))
		for i in Story.STEPS.size():
			var s: Array = Story.STEPS[i]
			if s[1] != act or i > st.step:
				continue
			if i < st.step:
				_list.add_child(_label("   ✔ " + s[2], 11, MenuKit.C_DIM))
			else:
				cur_label = _label("   ➤ " + st.tracker_text(), 13, Color("fff2c8"))
				_list.add_child(cur_label)
				_list.add_child(_label("      " + st.hint(s), 11, Color("c8b89a")))
	if st.is_done():
		var nat := st.nation_name()
		cur_label = _label("Épilogue : %s est née. Tous les obélisques brillent et tes habitants sont plus heureux." % (nat if nat != "" else "ta nation"), 13, MenuKit.C_OK)
		_list.add_child(cur_label)
	# l'étape en cours visible
	if cur_label:
		_scroll.ensure_control_visible.call_deferred(cur_label)
	# éclats
	var names := []
	var seen := {}
	var world := get_tree().get_first_node_in_group("world") as WorldGenerator
	if world:
		for z in world.zones:
			var r := z.type as RegionData
			if r == null or seen.has(r.id) or (z.gate as Vector2i).x < 0 or r.boss == null:
				continue
			seen[r.id] = true
			names.append(("✔ " if st.shards.has(r.id) else "· ") + r.display_name)
	_add_foot(_label("Éclats du Cœur d'Aube : %d / %d" % [st.shards.size(), st.shards_total()], 13, MenuKit.C_GOLD))
	_add_foot(_label("   " + "    ".join(PackedStringArray(names)), 11, MenuKit.C_TEXT))
	# quêtes des personnages
	var sq := get_tree().get_first_node_in_group("side_quests") as SideQuests
	if sq:
		var act := sq.active()
		var head := "Quêtes des personnages : %d en cours, %d / %d terminées" % [act.size(), sq.done_count(), SideQuests.QUESTS.size()]
		_add_foot(_label(head, 13, Color("b8f0a0")))
		for q in act:
			_add_foot(_label("   ➤ %s (%s) : %s  ·  %s" % [q.title, Story.NPCS[q.npc].name, q.text, sq.progress_text(q)], 10, MenuKit.C_TEXT))
	# événement du monde en cours
	var wev := get_tree().get_first_node_in_group("world_events") as WorldEvents
	if wev and wev.is_active():
		var info: Dictionary = WorldEvents.EVENTS[wev.current.id]
		_add_foot(_label("Événement : %s — %s" % [info.name, info.text], 12, info.color))
	# fin de jeu : la Brume
	var dm := get_tree().get_first_node_in_group("dungeons") as DungeonManager
	if dm and dm.brume_unlocked():
		_add_foot(_label("Fin de jeu — " + dm.brume_summary(), 13, DungeonManager.BRUME_COLOR))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var intro := MenuKit.button("Revoir l'introduction", 220, 12)
	intro.pressed.connect(func():
		close()
		var hud := get_tree().get_first_node_in_group("hud")
		if hud:
			hud.play_intro())
	row.add_child(intro)
	var b := MenuKit.button("Fermer (O)", 200, 13)
	b.pressed.connect(close)
	row.add_child(b)
	_add_foot(row)
	b.grab_focus.call_deferred()


## Où en est un personnage (texte vide : pas encore rencontré).
static func npc_status(st: Story, id: String) -> String:
	match str(st.npc_state.get(id, "")):
		"village":
			return "au village"
		"camp":
			return "à son camp" if id != "orvane" else "enchaîné dans son cristal"
		"visit":
			return "de passage au village"
		"captive":
			return "prisonnière de Morvain"
		"gone":
			if id == "morvain" and st.passed("duel_morvain"):
				return "vaincu"
			elif id == "cael":
				return "libéré" if st.choices.get("cael", "") == "liberer" else "en toi"
			elif id == "ren":
				return "parti dans les flammes"
			return "reparti sur les routes"
	return ""


## Galerie : un portrait par personnage de l'histoire (silhouette tant qu'il n'est pas rencontré).
func _fill_people(st: Story) -> void:
	var met := 0
	for id in Story.NPCS:
		if npc_status(st, id) != "":
			met += 1
	_list.add_child(_label("Personnages rencontrés : %d / %d" % [met, Story.NPCS.size()], 13, MenuKit.C_GOLD))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	_list.add_child(grid)
	for id in Story.NPCS:
		var info: Dictionary = Story.NPCS[id]
		var status := npc_status(st, id)
		var known := status != ""
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", MenuKit.card(not known, 6))
		card.custom_minimum_size = Vector2(336, 0)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		card.add_child(h)
		h.add_child(MenuKit.portrait("npc_" + id, 70, known))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(MenuKit.heading(info.name if known else "???", 14, info.color if known else MenuKit.C_DIM))
		var t := MenuKit.label(info.title if known else "pas encore rencontré", 10, MenuKit.C_TEXT if known else MenuKit.C_DIM)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size.x = 230
		v.add_child(t)
		if known:
			v.add_child(MenuKit.label(status, 10, MenuKit.C_OK if status == "au village" else MenuKit.C_DIM))
		grid.add_child(card)


func _add_foot(c: Control) -> void:
	_box.add_child(c)
	_head.append(c)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		if event.is_action_pressed("journal") and player and not player.ui_open and not player.building and player.is_alive():
			open()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("journal") or event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
