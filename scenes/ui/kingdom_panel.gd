class_name KingdomPanel
extends Control
## Panneau du royaume (touche U, ou menu pause) : population, lits, réserve de nourriture,
## bonheur des habitants et conseils. On y dépose la nourriture du sac dans la réserve du village.

var player: Player
var _box: VBoxContainer
var _list: VBoxContainer
var _deposit: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box = MenuKit.panel(self, 700)


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


func _needs() -> VillageNeeds:
	return get_tree().get_first_node_in_group("village_needs") as VillageNeeds


func _refresh() -> void:
	for c in _box.get_children():
		c.queue_free()
	var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
	var n := _needs()
	_box.add_child(MenuKit.title("Royaume : %s" % (k.title() if k else ""), 20))
	if n == null:
		return
	var members := n.members()
	var beds := n.total_beds()
	var avg := n.average_happiness()
	# chiffres
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 3)
	_box.add_child(grid)
	var rows := [
		["Habitants", "%d  (au plus %d)" % [members.size(), k.population_cap() if k else 0], MenuKit.C_TEXT],
		["Lits", "%d  pour %d habitants%s" % [beds, members.size(), ("  ·  %d sans lit" % (members.size() - beds)) if beds < members.size() else ""],
			MenuKit.C_OK if beds >= members.size() else MenuKit.C_BAD],
		["Réserve de nourriture", "%d repas  (%d points)" % [n.meals(), roundi(n.food_stock)],
			MenuKit.C_OK if n.meals() >= members.size() else MenuKit.C_BAD],
		["Bonheur moyen", "%d %%  ·  %s" % [roundi(avg), VillageNeeds.mood_name(avg)], VillageNeeds.mood_color(avg)],
	]
	for r in rows:
		grid.add_child(MenuKit.label(r[0], 13, MenuKit.C_DIM))
		grid.add_child(MenuKit.label(r[1], 13, r[2]))
	# dépôt
	var food_points := 0.0
	for e in player.inventory.entries:
		if (e.item as ItemData).is_food():
			food_points += (e.item as ItemData).food * e.count
	_deposit = MenuKit.button("Déposer la nourriture de mon sac (%d points)" % roundi(food_points), 420, 13)
	_deposit.disabled = food_points <= 0.0
	_deposit.pressed.connect(func():
		var got := n.deposit_from(player)
		player.notify.emit("Réserve du village : +%d points de nourriture." % roundi(got))
		_refresh())
	_box.add_child(_deposit)
	# habitants
	var sep := MenuKit.label("Habitants", 14, MenuKit.C_GOLD)
	_box.add_child(sep)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(660, 170)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_list)
	var sorted := members.duplicate()
	sorted.sort_custom(func(a, b): return a.happiness < b.happiness)
	for v in sorted:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		var job := "Sans poste"
		if v.work_room != null and v.work_room.type:
			job = (v.work_room.type as RoomTypeData).job_name
		var name_l := MenuKit.label("%s (%s)" % [v.villager_name, v.race.display_name if v.race else "?"], 12)
		name_l.custom_minimum_size.x = 165
		h.add_child(name_l)
		var doing: String = v.ACTIVITY_NAMES.get(v.activity, "")
		var job_l := MenuKit.label(job + ((" · " + doing) if doing != "" else ""), 11, MenuKit.C_DIM)
		job_l.custom_minimum_size.x = 140
		h.add_child(job_l)
		var bed_l := MenuKit.label({"lit": "Lit", "cabane": "Cabane"}.get(v.bed_kind, "Par terre"), 11,
			MenuKit.C_OK if v.bed_kind == "lit" else (MenuKit.C_TEXT if v.bed_kind == "cabane" else MenuKit.C_BAD))
		bed_l.custom_minimum_size.x = 64
		h.add_child(bed_l)
		var bar_bg := ColorRect.new()
		bar_bg.color = Color(0, 0, 0, 0.5)
		bar_bg.custom_minimum_size = Vector2(60, 8)
		bar_bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(bar_bg)
		var bar := ColorRect.new()
		bar.color = VillageNeeds.mood_color(v.happiness)
		bar.size = Vector2(60.0 * v.happiness / 100.0, 8)
		bar_bg.add_child(bar)
		var mood := VillageNeeds.mood_name(v.happiness)
		if not v.mood_reasons.is_empty():
			mood += " : " + ", ".join(PackedStringArray(v.mood_reasons))
		h.add_child(MenuKit.label(mood, 11, VillageNeeds.mood_color(v.happiness)))
		_list.add_child(h)
	# quêtes
	var qb := get_tree().get_first_node_in_group("quests") as QuestBoard
	if qb and not qb.quests.is_empty():
		_box.add_child(MenuKit.label("Quêtes", 14, MenuKit.C_GOLD))
		for q in qb.quests:
			var st: String = {"offer": "proposée (parle à %s)" % q.giver_name, "active": qb.progress_text(q), "ready": "à rendre à %s" % q.giver_name}[q.state]
			var l := MenuKit.label("%s  —  %s" % [q.title, st], 11, Color("8ad66a") if q.state == "ready" else (MenuKit.C_TEXT if q.state == "active" else MenuKit.C_DIM))
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(660, 0)
			_box.add_child(l)
	# conseils
	var tips := []
	if beds < members.size():
		tips.append("Construis une maison (pièce fermée, porte, un lit et un coffre : 2 lits) ou un dortoir (4 lits et un coffre : 6 lits).")
	if n.meals() < members.size():
		tips.append("Remplis la réserve : dépose de la nourriture, ou fais travailler une boulangerie ou une grange.")
	var have := {}
	if k:
		for r in k.rooms:
			if r.type:
				have[(r.type as RoomTypeData).id] = true
	if not have.has("taverne"):
		tips.append("Une taverne rendrait les habitants plus heureux (+10).")
	elif not have.has("temple"):
		tips.append("Un temple rendrait les habitants plus heureux (+10).")
	if avg >= 65.0:
		tips.append("Ton village est heureux : des voyageurs viendront s'y installer.")
	elif avg < 25.0 and not members.is_empty():
		tips.append("Attention : des habitants malheureux finiront par partir.")
	for t in tips:
		var l := MenuKit.label("• " + t, 11, MenuKit.C_DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(600, 0)
		_box.add_child(l)
	var close_b := MenuKit.button("Fermer (U)", 200, 13)
	close_b.pressed.connect(close)
	_box.add_child(close_b)
	close_b.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		if event.is_action_pressed("kingdom") and player and not player.ui_open and not player.building and player.is_alive():
			open()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("kingdom") or event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
