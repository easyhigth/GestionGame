class_name KingdomPanel
extends Control
## Panneau du royaume (touche U, ou menu pause) : population, lits, réserve de nourriture,
## bonheur des habitants et conseils. On y dépose la nourriture du sac dans la réserve du village.

var player: Player
var _box: VBoxContainer
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
	_box = MenuKit.panel(self, 780)


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


## Onglet affiché : apercu, habitants, production, familiers, quetes.
var _tab := "apercu"
const TABS := [["apercu", "Vue d'ensemble", "crown"], ["carte", "Carte", "compass"], ["habitants", "Habitants", "people"], ["production", "Production", "food"],
	["familiers", "Familiers", "star"], ["quetes", "Quêtes", "scroll"]]
const PAGE := Vector2(740, 360)


func _refresh() -> void:
	for c in _box.get_children():
		c.queue_free()
	var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
	var n := _needs()
	_box.add_child(MenuKit.title("Royaume", 20))
	if n == null:
		return
	# bandeau : nom, rang, âge
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 8)
	if k:
		head.add_child(MenuKit.bold(k.title(), 13, MenuKit.C_TEXT))
		head.add_child(MenuKit.chip(Kingdom.RANK_NAMES[k.rank], MenuKit.C_GOLD))
		head.add_child(MenuKit.chip(Kingdom.AGE_NAMES[k.age], Kingdom.AGE_COLORS[k.age]))
	var wev := get_tree().get_first_node_in_group("world_events") as WorldEvents
	if wev and wev.status_text() != "":
		head.add_child(MenuKit.chip(wev.status_text(), Color("c8a8ff")))
	_box.add_child(head)
	_box.add_child(MenuKit.tab_bar(TABS, _tab, func(id):
		_tab = id
		_refresh(), 118))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = PAGE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box.add_child(scroll)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	page.custom_minimum_size.x = PAGE.x - 14
	scroll.add_child(page)
	match _tab:
		"carte":
			_page_map(page)
		"habitants":
			_page_people(page, n)
		"production":
			_page_production(page)
		"familiers":
			_page_familiars(page)
		"quetes":
			_page_quests(page)
		_:
			_page_overview(page, k, n)
	MenuKit.fade_in(page)
	_nav_row()


# ---------------------------------------------------------------- vue d'ensemble

func _page_overview(page: VBoxContainer, k: Kingdom, n: VillageNeeds) -> void:
	var members := n.members()
	var beds := n.total_beds()
	var avg := n.average_happiness()
	var cap: int = k.population_cap() if k else 0
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 8)
	tiles.add_child(MenuKit.stat_tile("people", "%d / %d" % [members.size(), cap], "Habitants", MenuKit.C_TEXT, float(members.size()) / maxf(1.0, cap), 175))
	tiles.add_child(MenuKit.stat_tile("house", "%d / %d" % [beds, members.size()], "Lits" + ("  ·  %d par terre" % (members.size() - beds) if beds < members.size() else ""),
		MenuKit.C_OK if beds >= members.size() else MenuKit.C_BAD, float(beds) / maxf(1.0, members.size()), 175))
	tiles.add_child(MenuKit.stat_tile("food", "%d repas" % n.meals(), "Réserve de nourriture", MenuKit.C_OK if n.meals() >= members.size() else MenuKit.C_BAD,
		float(n.meals()) / maxf(1.0, members.size() * 2.0), 175))
	tiles.add_child(MenuKit.stat_tile("heart", "%d %%" % roundi(avg), "Bonheur · " + VillageNeeds.mood_name(avg), VillageNeeds.mood_color(avg), avg / 100.0, 175))
	page.add_child(tiles)
	# progression du royaume
	if k:
		var prog := MenuKit.card_box(false, 10.0, 4)
		var pv: VBoxContainer = prog.get_child(0)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 8)
		top.add_child(MenuKit.icon("crown", 20))
		var nxt := mini(k.rank + 1, Kingdom.RANK_NAMES.size() - 1)
		top.add_child(MenuKit.bold("%s  →  %s" % [Kingdom.RANK_NAMES[k.rank], Kingdom.RANK_NAMES[nxt]], 13, MenuKit.C_GOLD))
		pv.add_child(top)
		var typed := k.typed_rooms().size()
		var need: int = Kingdom.RANK_ROOMS[nxt]
		var gr := HBoxContainer.new()
		gr.add_theme_constant_override("separation", 8)
		gr.add_child(MenuKit.gauge(float(typed) / maxf(1.0, need), MenuKit.C_GOLD, 420, 10))
		gr.add_child(MenuKit.label("%d / %d pièces reconnues" % [typed, need], 11, MenuKit.C_DIM))
		pv.add_child(gr)
		var goal := MenuKit.label(k.next_goal() + "  " + k.next_age_goal(), 10, MenuKit.C_DIM)
		goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		goal.custom_minimum_size.x = 690
		pv.add_child(goal)
		page.add_child(prog)
	# actions rapides
	var acts := HBoxContainer.new()
	acts.alignment = BoxContainer.ALIGNMENT_CENTER
	acts.add_theme_constant_override("separation", 10)
	var food_points := 0.0
	for e in player.inventory.entries:
		if (e.item as ItemData).is_food():
			food_points += (e.item as ItemData).food * e.count
	_deposit = MenuKit.nav_button("Déposer ma nourriture (%d)" % roundi(food_points), "food", 260)
	_deposit.disabled = food_points <= 0.0
	_deposit.tooltip_text = "Toute la nourriture de ton sac va dans la réserve du village."
	_deposit.pressed.connect(func():
		var got := n.deposit_from(player)
		player.notify.emit("Réserve du village : +%d points de nourriture." % roundi(got))
		_refresh())
	acts.add_child(_deposit)
	var wev := get_tree().get_first_node_in_group("world_events") as WorldEvents
	if wev and not wev.sick().is_empty():
		var why := wev.cure_block()
		var cure_b := MenuKit.nav_button("Soigner les malades (%d)" % wev.sick().size(), "heart", 250)
		cure_b.disabled = why != ""
		cure_b.tooltip_text = why if why != "" else "1 soupe ou potion par malade."
		cure_b.pressed.connect(func():
			wev.cure()
			_refresh())
		acts.add_child(cure_b)
	page.add_child(acts)
	# à faire maintenant
	page.add_child(MenuKit.section("À faire maintenant", "compass", 14))
	var tips := _tips(k, n)
	if tips.is_empty():
		page.add_child(MenuKit.empty_state("star", "Tout va bien : ton royaume prospère !"))
	for t in tips.slice(0, 3):
		var plan_id: String = t[2]
		page.add_child(MenuKit.tip_card(t[0], t[1], "Construire ▸" if plan_id != "" else "", (func(): _build(plan_id)) if plan_id != "" else Callable(), t[3]))


## Conseils : [icône, texte, plan à ouvrir ("" = aucun), urgent].
func _tips(k: Kingdom, n: VillageNeeds) -> Array:
	var members := n.members()
	var beds := n.total_beds()
	var fm := get_tree().get_first_node_in_group("farming") as Farming
	var ls := get_tree().get_first_node_in_group("livestock") as Livestock
	var tr := get_tree().get_first_node_in_group("trade") as Trade
	var tips := []
	var have := {}
	if k:
		for r in k.rooms:
			if r.type:
				have[(r.type as RoomTypeData).id] = true
	if n.average_happiness() < 25.0 and not members.is_empty():
		tips.append(["skull", "Des habitants malheureux vont partir ! Regarde leur humeur dans l'onglet Habitants.", "", true])
	if beds < members.size():
		tips.append(["house", "%d habitant(s) dorment par terre : une maison (1 lit, 1 coffre) ou un dortoir (4 lits, 1 coffre)." % (members.size() - beds), "maison", false])
	if n.meals() < members.size():
		tips.append(["food", "La réserve est presque vide : dépose de la nourriture, ou fais travailler fermiers et boulangers.", "", n.meals() == 0])
	var idle := members.filter(func(v): return v.work_room == null).size()
	if idle > 0 and k and not k.rooms.is_empty():
		tips.append(["people", "%d habitant(s) sans poste : parle-leur ({interact}) → Poste de travail." % idle, "", false])
	if fm and not fm.has_fields():
		tips.append(["sun", "Laboure au moins %d cases avec une houe : des fermiers rempliront la réserve." % Farming.MIN_PLOTS, "", false])
	elif fm and fm.farmers().is_empty():
		tips.append(["sun", "Nomme un fermier ({interact} près d'un habitant → Poste de travail → Champs).", "", false])
	if ls and ls.domestic().is_empty() and members.size() >= 3:
		tips.append(["food", "Élevage : pose une mangeoire, puis attire des poules (graines) ou des moutons et vaches (blé).", "", false])
	if tr and not have.has("marche") and members.size() >= 4:
		tips.append(["coin", "Un marché ferait venir le marchand tous les 2 jours, avec de meilleurs prix.", "marche", false])
	if not have.has("taverne") and members.size() >= 3:
		tips.append(["heart", "Une taverne rendrait les habitants plus heureux (+10).", "taverne", false])
	elif not have.has("temple") and members.size() >= 3:
		tips.append(["heart", "Un temple rendrait les habitants plus heureux (+10).", "temple", false])
	return tips


# ---------------------------------------------------------------- carte

var _map: KingdomMap
var _map_side: VBoxContainer


func _page_map(page: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	page.add_child(row)
	var info := MenuKit.label("Molette : zoom · glisser : se déplacer · clic : détails d'une pièce ou fiche d'un habitant", 10, MenuKit.C_DIM)
	_map = KingdomMap.new()
	_map.player = player
	_map.custom_minimum_size = Vector2(500, PAGE.y - 56)
	_map.hovered.connect(func(t): info.text = t if t != "" else "Molette : zoom · glisser : se déplacer · clic : détails d'une pièce ou fiche d'un habitant")
	_map.villager_clicked.connect(func(v):
		close()
		player.open_inventory.emit(v))
	_map.room_clicked.connect(func(r): _fill_map_side(r))
	row.add_child(_map)
	var side := PanelContainer.new()
	side.add_theme_stylebox_override("panel", MenuKit.card(false, 7.0))
	side.custom_minimum_size = Vector2(214, PAGE.y - 56)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(sc)
	_map_side = VBoxContainer.new()
	_map_side.add_theme_constant_override("separation", 4)
	_map_side.custom_minimum_size.x = 196
	sc.add_child(_map_side)
	row.add_child(side)
	_fill_map_side({})
	# légende
	var legend := HFlowContainer.new()
	legend.add_theme_constant_override("h_separation", 10)
	for l in [["Pièce reconnue", Color("c8a060")], ["Pièce à finir", Color(0.7, 0.7, 0.7)], ["Murs et toits", Color("8a7a66")], ["Champs", Color("6a4426")],
			["Plans", KingdomMap.PLAN], ["Arbres", Color("3c6e2a")], ["Eau", Color("3f7cb0")], ["Feu de camp", Color("ff8a3a")], ["Toi", MenuKit.C_GOLD]]:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 3)
		var sw := ColorRect.new()
		sw.color = l[1]
		sw.custom_minimum_size = Vector2(10, 10)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(sw)
		h.add_child(MenuKit.label(l[0], 9, MenuKit.C_DIM))
		legend.add_child(h)
	legend.add_child(MenuKit.label("· ● habitant (couleur de sa classe, anneau vert : au travail)", 9, MenuKit.C_DIM))
	page.add_child(legend)
	page.add_child(info)


## Panneau de côté de la carte : la pièce choisie, ou la liste des pièces (un clic pour y aller).
func _fill_map_side(r: Dictionary) -> void:
	if _map_side == null:
		return
	for c in _map_side.get_children():
		c.queue_free()
	var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
	if k == null:
		return
	if r.is_empty():
		_map_side.add_child(MenuKit.bold("Tes pièces", 13, MenuKit.C_GOLD))
		var list := k.rooms.filter(func(x): return x.get("enclosed", false))
		if list.is_empty():
			var l := MenuKit.label("Aucune pièce fermée pour l'instant. Bâtis des murs, une porte et le mobilier (B, ou un plan prêt).", 10, MenuKit.C_DIM)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size.x = 190
			_map_side.add_child(l)
		for x in list:
			var t: RoomTypeData = x.type
			var b := MenuKit.button(("%s%s" % [t.display_name, ("  %d/%d" % [k.workers_of(x).size(), t.job_slots]) if t.job_slots > 0 else ""]) if t else "Pièce à finir", 190, 10)
			b.custom_minimum_size.y = 26
			b.add_theme_color_override("font_color", t.color.lightened(0.3) if t else MenuKit.C_DIM)
			var room = x
			b.pressed.connect(func():
				_map.select_room(room)
				_fill_map_side(room))
			_map_side.add_child(b)
		var bo := get_tree().get_first_node_in_group("build_orders")
		if bo and not bo.orders.is_empty():
			_map_side.add_child(MenuKit.chip("%d plans en attente" % bo.orders.size(), KingdomMap.PLAN))
		return
	var t: RoomTypeData = r.type
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	var dot := ColorRect.new()
	dot.color = t.color if t else Color(0.7, 0.7, 0.7)
	dot.custom_minimum_size = Vector2(12, 12)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(dot)
	head.add_child(MenuKit.bold(t.display_name if t else "Pièce à finir", 13, MenuKit.C_TEXT))
	_map_side.add_child(head)
	_map_side.add_child(MenuKit.label("%d cases" % r.cells.size(), 9, MenuKit.C_DIM))
	if t == null:
		var close: RoomTypeData = r.get("closest")
		var miss: Dictionary = r.get("missing", {})
		var txt := "Il lui manque de quoi devenir une pièce."
		if close:
			txt = "Presque : %s. Il manque :" % close.display_name
		var l := MenuKit.label(txt, 10, MenuKit.C_GOLD)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 190
		_map_side.add_child(l)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 3)
		for id in miss:
			var it := Items.get_item(id)
			if it:
				flow.add_child(MenuKit.item_badge(it, int(miss[id]), 30))
		_map_side.add_child(flow)
		if r.get("too_small", false):
			_map_side.add_child(MenuKit.label("Et la pièce est trop petite.", 10, MenuKit.C_BAD))
	else:
		var d := MenuKit.label(t.effect_text if t.effect_text != "" else t.description, 10, MenuKit.C_DIM)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = 190
		_map_side.add_child(d)
		if t.job_slots > 0:
			var ws := k.workers_of(r)
			_map_side.add_child(MenuKit.label("%s : %d / %d" % [t.job_name, ws.size(), t.job_slots], 11, MenuKit.C_GOLD))
			for v in ws:
				var h := HBoxContainer.new()
				h.add_theme_constant_override("separation", 5)
				h.add_child(MenuKit.mini_portrait(MenuKit.villager_portrait_id(v), 26))
				h.add_child(MenuKit.label(str(v.get("villager_name")), 10, MenuKit.C_TEXT))
				_map_side.add_child(h)
			if ws.size() < t.job_slots:
				var l2 := MenuKit.label("Place libre : parle à un habitant ({interact}) → Poste de travail.", 9, MenuKit.C_DIM)
				l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				l2.custom_minimum_size.x = 190
				_map_side.add_child(l2)
		var prods: Array = t.production_pool if not t.production_pool.is_empty() else ([t.production] if t.production else [])
		if not prods.is_empty():
			_map_side.add_child(MenuKit.label("Produit :", 10, MenuKit.C_DIM))
			var flow := HFlowContainer.new()
			flow.add_theme_constant_override("h_separation", 3)
			var seen := {}
			for it in prods:
				if it and not seen.has(it.id):
					seen[it.id] = true
					flow.add_child(MenuKit.item_badge(it, 0, 28))
			_map_side.add_child(flow)
		if t.beds > 0:
			_map_side.add_child(MenuKit.icon_label("house", "%d lit%s" % [t.beds, "s" if t.beds > 1 else ""], 10, MenuKit.C_TEXT))
	var back := MenuKit.button("← Toutes les pièces", 190, 10)
	back.custom_minimum_size.y = 26
	back.pressed.connect(func():
		_map.select_room({})
		_fill_map_side({}))
	_map_side.add_child(back)


# ---------------------------------------------------------------- habitants

func _page_people(page: VBoxContainer, n: VillageNeeds) -> void:
	var members := n.members()
	var idle := members.filter(func(v): return v.work_room == null).size()
	var floor_n := members.filter(func(v): return v.bed_kind != "lit" and v.bed_kind != "cabane").size()
	var sum := HBoxContainer.new()
	sum.add_theme_constant_override("separation", 6)
	sum.add_child(MenuKit.chip("%d habitants" % members.size(), MenuKit.C_TEXT))
	if idle > 0:
		sum.add_child(MenuKit.chip("%d sans poste" % idle, MenuKit.C_GOLD))
	if floor_n > 0:
		sum.add_child(MenuKit.chip("%d par terre" % floor_n, MenuKit.C_BAD))
	var away := get_tree().get_nodes_in_group("away_villagers").size()
	if away > 0:
		sum.add_child(MenuKit.chip("%d en expédition" % away, Color("8ac8ff")))
	sum.add_child(MenuKit.label("  {interact} près d'un habitant : équipement et poste", 10, MenuKit.C_DIM))
	page.add_child(sum)
	if members.is_empty():
		page.add_child(MenuKit.empty_state("people", "Personne pour l'instant : recrute des voyageurs dans le monde."))
		return
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	page.add_child(grid)
	var sorted := members.duplicate()
	sorted.sort_custom(func(a, b): return a.happiness < b.happiness)
	for v in sorted:
		grid.add_child(_person_card(v))


func _person_card(v: Node) -> PanelContainer:
	var pc := MenuKit.card_box(false, 8.0, 3)
	pc.custom_minimum_size.x = 358
	var root: VBoxContainer = pc.get_child(0)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	root.add_child(h)
	h.add_child(MenuKit.mini_portrait(MenuKit.villager_portrait_id(v), 44))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(col)
	var nm := HBoxContainer.new()
	nm.add_theme_constant_override("separation", 6)
	nm.add_child(MenuKit.bold(v.villager_name, 13, MenuKit.C_TEXT))
	nm.add_child(MenuKit.label("%s · Nv %d" % [v.race_title(), v.level], 10, MenuKit.C_DIM))
	col.add_child(nm)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 4)
	var cd = Villager.class_data(v.fight_class)
	if cd:
		chips.add_child(MenuKit.chip(cd.display_name, cd.color))
	var job := "Sans poste"
	if v.work_room != null and v.work_room.type:
		job = (v.work_room.type as RoomTypeData).job_name
	chips.add_child(MenuKit.chip(job, MenuKit.C_GOLD if v.work_room != null else MenuKit.C_DIM))
	var doing: String = v.ACTIVITY_NAMES.get(v.activity, "")
	if doing != "":
		chips.add_child(MenuKit.label(doing, 10, MenuKit.C_DIM))
	col.add_child(chips)
	var mood := HBoxContainer.new()
	mood.add_theme_constant_override("separation", 6)
	mood.add_child(MenuKit.icon("heart", 13))
	mood.add_child(MenuKit.gauge(v.happiness / 100.0, VillageNeeds.mood_color(v.happiness), 110, 8))
	mood.add_child(MenuKit.label(VillageNeeds.mood_name(v.happiness), 10, VillageNeeds.mood_color(v.happiness)))
	var bed_ok: bool = v.bed_kind == "lit"
	mood.add_child(MenuKit.icon("house", 13))
	mood.add_child(MenuKit.label({"lit": "Lit", "cabane": "Cabane"}.get(v.bed_kind, "Par terre"), 10,
		MenuKit.C_OK if bed_ok else (MenuKit.C_TEXT if v.bed_kind == "cabane" else MenuKit.C_BAD)))
	col.add_child(mood)
	if not v.mood_reasons.is_empty():
		pc.tooltip_text = "Humeur : " + ", ".join(PackedStringArray(v.mood_reasons))
		var why := MenuKit.label(", ".join(PackedStringArray(v.mood_reasons)), 9, MenuKit.C_DIM)
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		why.custom_minimum_size.x = 330
		root.add_child(why)
	return pc


# ---------------------------------------------------------------- production

func _page_production(page: VBoxContainer) -> void:
	var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
	var fm := get_tree().get_first_node_in_group("farming") as Farming
	var ls := get_tree().get_first_node_in_group("livestock") as Livestock
	var tr := get_tree().get_first_node_in_group("trade") as Trade
	var sea := get_tree().get_first_node_in_group("seasons") as Seasons
	# ateliers
	page.add_child(MenuKit.section("Ateliers et pièces", "house", 14))
	if k == null or k.typed_rooms().is_empty():
		page.add_child(MenuKit.empty_state("house", "Aucune pièce reconnue : construis une pièce fermée avec son mobilier ({build_mode})."))
	else:
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		page.add_child(grid)
		for r in k.typed_rooms():
			var t: RoomTypeData = r.type
			var c := MenuKit.card_box(false, 7.0, 2)
			c.custom_minimum_size.x = 236
			var cv: VBoxContainer = c.get_child(0)
			var top := HBoxContainer.new()
			top.add_theme_constant_override("separation", 6)
			var dot := ColorRect.new()
			dot.color = t.color
			dot.custom_minimum_size = Vector2(10, 10)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			top.add_child(dot)
			top.add_child(MenuKit.bold(t.display_name, 12, MenuKit.C_TEXT))
			cv.add_child(top)
			var info := t.effect_text if t.effect_text != "" else t.description
			if t.job_slots > 0:
				var w := k.workers_of(r).size()
				var line := HBoxContainer.new()
				line.add_theme_constant_override("separation", 6)
				line.add_child(MenuKit.gauge(float(w) / t.job_slots, MenuKit.C_OK if w > 0 else MenuKit.C_BAD, 70, 7))
				line.add_child(MenuKit.label("%s %d / %d" % [t.job_name, w, t.job_slots], 10, MenuKit.C_DIM))
				cv.add_child(line)
			var il := MenuKit.label(info, 9, MenuKit.C_DIM)
			il.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			il.custom_minimum_size.x = 220
			cv.add_child(il)
			grid.add_child(c)
	# champs
	if fm and not fm.plots.is_empty():
		page.add_child(MenuKit.section("Champs", "sun", 14))
		var sm := fm.summary()
		var c := MenuKit.card_box(false, 9.0, 4)
		var cv: VBoxContainer = c.get_child(0)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(MenuKit.label("Semées", 11, MenuKit.C_DIM))
		row.add_child(MenuKit.gauge(float(sm.planted) / maxf(1.0, sm.plots), MenuKit.C_OK, 160, 8))
		row.add_child(MenuKit.label("%d / %d cases  ·  %d mûres" % [sm.planted, sm.plots, sm.ripe], 11, MenuKit.C_TEXT))
		row.add_child(MenuKit.chip("Fermiers %d / %d" % [fm.farmers().size(), (fm.fields_room.type as RoomTypeData).job_slots], MenuKit.C_GOLD))
		cv.add_child(row)
		var seeds := HBoxContainer.new()
		seeds.add_theme_constant_override("separation", 4)
		seeds.add_child(MenuKit.label("Graines :", 11, MenuKit.C_DIM))
		for id in fm.seed_store:
			var it := Items.get_item(id)
			if it:
				seeds.add_child(MenuKit.item_badge(it, int(fm.seed_store[id]), 28))
		if fm.seed_store.is_empty():
			seeds.add_child(MenuKit.label("aucune", 11, MenuKit.C_BAD))
		var n_seeds := 0
		for e in player.inventory.entries:
			if (e.item as ItemData).is_seed():
				n_seeds += e.count
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seeds.add_child(sp)
		var sb := MenuKit.nav_button("Confier mes graines (%d)" % n_seeds, "sun", 220)
		sb.disabled = n_seeds <= 0
		sb.pressed.connect(func():
			var got := fm.deposit_seeds(player)
			player.notify.emit("Les fermiers ont %d graines de plus à semer." % got)
			_refresh())
		seeds.add_child(sb)
		cv.add_child(seeds)
		page.add_child(c)
	# élevage, commerce, saison
	page.add_child(MenuKit.section("Campagne", "compass", 14))
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 8)
	page.add_child(tiles)
	if sea:
		var fest: String = Seasons.FESTIVALS[sea.season()][0]
		var txt := ("Aujourd'hui : %s ! (+12 de bonheur)" % fest) if sea.is_festival() else "Prochaine fête : %s, jour %d" % [Seasons.FESTIVALS[sea.season() if sea.day_in_season() < Seasons.FESTIVAL_DAY else (sea.season() + 1) % 4][0], sea.next_festival_day()]
		if sea.is_winter():
			txt += "\nRien ne pousse en hiver."
		tiles.add_child(_info_card("moon" if sea.is_winter() else "sun", "%s · an %d" % [sea.season_name(), sea.year()],
			"Jour %d / %d\n%s" % [sea.day_in_season(), Seasons.SEASON_DAYS, txt]))
	if ls:
		var st := ls.summary_text()
		tiles.add_child(_info_card("food", "Élevage", st.trim_prefix("Élevage : ") if st != "" else "Aucune bête : pose une mangeoire et attire des animaux."))
	if tr:
		tiles.add_child(_info_card("coin", "Commerce", tr.status_text()))


func _info_card(icon_name: String, title_text: String, body: String) -> PanelContainer:
	var c := MenuKit.card_box(false, 9.0, 3)
	c.custom_minimum_size.x = 236
	c.size_flags_vertical = Control.SIZE_FILL
	var cv: VBoxContainer = c.get_child(0)
	cv.add_child(MenuKit.icon_label(icon_name, title_text, 12, MenuKit.C_GOLD))
	var l := MenuKit.label(body, 10, MenuKit.C_TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 218
	cv.add_child(l)
	return c


# ---------------------------------------------------------------- familiers

func _page_familiars(page: VBoxContainer) -> void:
	var fam := get_tree().get_first_node_in_group("familiars_mgr") as Familiars
	if fam == null or fam.list.is_empty():
		page.add_child(MenuKit.empty_state("star", "Aucun familier : affaiblis un monstre (moins de 30 % de vie) puis {interact} pour l'apprivoiser."))
		return
	var sum := HBoxContainer.new()
	sum.add_theme_constant_override("separation", 6)
	sum.add_child(MenuKit.chip("Avec toi %d / %d" % [fam.team().size(), Familiars.max_team(get_tree())], Color("b8f0a0")))
	sum.add_child(MenuKit.chip("En tout %d / %d" % [fam.list.size(), Familiars.max_total(get_tree())], MenuKit.C_TEXT))
	sum.add_child(MenuKit.chip("Ordre : " + Familiars.ORDER_TEXT[fam.order] + " ({familiar_order})", MenuKit.C_GOLD))
	page.add_child(sum)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	page.add_child(grid)
	for entry in fam.list.duplicate():
		var c := MenuKit.card_box(entry.node == null, 8.0, 3)
		c.custom_minimum_size.x = 358
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		(c.get_child(0) as VBoxContainer).add_child(h)
		h.add_child(MenuKit.mini_portrait(str(entry.data).get_file().get_basename(), 44))
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(col)
		col.add_child(MenuKit.bold("%s · Nv %d" % [entry.name, entry.level], 13, Color("b8f0a0")))
		var chips := HBoxContainer.new()
		chips.add_theme_constant_override("separation", 4)
		chips.add_child(MenuKit.chip(Familiars.title_of(entry), MenuKit.C_TEXT))
		var at_village: bool = entry.get("place", "equipe") == "village"
		chips.add_child(MenuKit.chip("Au village" if at_village else "Avec toi", MenuKit.C_DIM if at_village else MenuKit.C_OK))
		if entry.node == null:
			chips.add_child(MenuKit.chip("K.O.", MenuKit.C_BAD))
		if fam.rideable(entry):
			chips.add_child(MenuKit.chip("Monture", MenuKit.C_GOLD))
		col.add_child(chips)
		var btns := HBoxContainer.new()
		btns.add_theme_constant_override("separation", 6)
		var bp := MenuKit.button("Avec moi" if at_village else "Au village", 110, 10)
		bp.custom_minimum_size.y = 26
		bp.pressed.connect(func():
			fam.set_place(entry, "equipe" if at_village else "village")
			_refresh())
		btns.add_child(bp)
		var br := MenuKit.button("Libérer", 90, 10)
		br.custom_minimum_size.y = 26
		br.pressed.connect(func():
			fam.release(entry)
			_refresh())
		btns.add_child(br)
		col.add_child(btns)
		grid.add_child(c)


# ---------------------------------------------------------------- quêtes

func _page_quests(page: VBoxContainer) -> void:
	var qb := get_tree().get_first_node_in_group("quests") as QuestBoard
	if qb == null or qb.quests.is_empty():
		page.add_child(MenuKit.empty_state("scroll", "Pas de quête pour l'instant : les habitants marqués « ! » en proposent."))
		return
	for q in qb.quests:
		var c := MenuKit.card_box(q.state == "offer", 9.0, 3)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		(c.get_child(0) as VBoxContainer).add_child(h)
		h.add_child(MenuKit.icon("scroll", 22))
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(col)
		col.add_child(MenuKit.bold(q.title, 13, MenuKit.C_TEXT))
		var st: String = {"offer": "Proposée : parle à %s" % q.giver_name, "active": qb.progress_text(q), "ready": "Terminée : à rendre à %s" % q.giver_name}[q.state]
		col.add_child(MenuKit.label(st, 11, MenuKit.C_DIM))
		h.add_child(MenuKit.chip({"offer": "Proposée", "active": "En cours", "ready": "À rendre"}[q.state],
			MenuKit.C_DIM if q.state == "offer" else (MenuKit.C_GOLD if q.state == "active" else MenuKit.C_OK)))
		page.add_child(c)


# ---------------------------------------------------------------- navigation

func _nav_row() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var hud := get_parent()
	for d in [["Expéditions", "compass", "expedition_panel"], ["Diplomatie ({diplomacy})", "sword", "diplomacy_panel"], ["Bannière", "shield", "heraldry_panel"]]:
		var b := MenuKit.nav_button(d[0], d[1], 170)
		var key: String = d[2]
		b.pressed.connect(func():
			close()
			if hud and hud.get(key):
				hud.get(key).open())
		row.add_child(b)
	var close_b := MenuKit.button("Fermer ({kingdom})", 140, 12)
	close_b.pressed.connect(close)
	row.add_child(close_b)
	_box.add_child(row)
	close_b.grab_focus.call_deferred()


## Ferme le panneau et ouvre le mode construction sur le plan prêt de cette pièce.
func _build(type_id: String) -> void:
	close()
	var bm := player.get_node_or_null("BuildMode")
	if bm == null:
		var found := player.find_children("*", "BuildMode", true, false)
		bm = found[0] if not found.is_empty() else null
	if bm:
		bm.open_plan(type_id)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		if event.is_action_pressed("kingdom") and player and not player.ui_open and not player.building and player.is_alive():
			open()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("kingdom") or event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
