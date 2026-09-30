class_name JournalPanel
extends Control
## Journal de l'histoire (touche O) : les actes, les étapes faites et l'objectif en cours,
## les éclats du Cœur d'Aube déjà rassemblés et les personnages rencontrés.

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
	_box = MenuKit.panel(self, 720)


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
	l.custom_minimum_size = Vector2(680, 0)
	return l


func _refresh() -> void:
	for c in _box.get_children():
		c.queue_free()
	var st := get_tree().get_first_node_in_group("story") as Story
	_box.add_child(MenuKit.title("Journal — L'Éveil du Royaume", 20))
	if st == null:
		return
	var cur_act: int = st.current()[1] if not st.is_done() else 4
	for act in Story.ACTS:
		if act > cur_act:
			_box.add_child(_label("%s  ·  ???" % Story.ACTS[act], 13, MenuKit.C_DIM))
			continue
		_box.add_child(_label(Story.ACTS[act], 15, MenuKit.C_GOLD))
		for i in Story.STEPS.size():
			var s: Array = Story.STEPS[i]
			if s[1] != act or i > st.step:
				continue
			if i < st.step:
				_box.add_child(_label("   ✔ " + s[2], 11, MenuKit.C_DIM))
			else:
				_box.add_child(_label("   ➤ " + st.tracker_text(), 13, Color("fff2c8")))
				_box.add_child(_label("      " + s[3], 11, Color("c8b89a")))
	if st.is_done():
		_box.add_child(_label("Épilogue : le royaume s'est éveillé. Tous les obélisques brillent et tes habitants sont plus heureux.", 13, MenuKit.C_OK))
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
	_box.add_child(_label("Éclats du Cœur d'Aube : %d / %d" % [st.shards.size(), st.shards_total()], 13, MenuKit.C_GOLD))
	_box.add_child(_label("   " + "    ".join(PackedStringArray(names)), 11, MenuKit.C_TEXT))
	# personnages
	var people := []
	for id in Story.NPCS:
		var info: Dictionary = Story.NPCS[id]
		var where: String = st.npc_state.get(id, "")
		var status := ""
		if st.choices.get(id, "") in ["blade", "map"]:
			status = "reparti sur les routes"
		elif where == "village":
			status = "au village"
		elif where == "camp":
			status = "à son camp"
		if status != "":
			people.append("%s %s (%s)" % [info.name, info.title, status])
	if not people.is_empty():
		_box.add_child(_label("Personnages : " + ", ".join(PackedStringArray(people)), 11, MenuKit.C_TEXT))
	var b := MenuKit.button("Fermer (O)", 200, 13)
	b.pressed.connect(close)
	_box.add_child(b)
	b.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		if event.is_action_pressed("journal") and player and not player.ui_open and not player.building and player.is_alive():
			open()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("journal") or event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
