class_name InventoryUI
extends Control
## Fenêtre d'inventaire : équipement du personnage ciblé (joueur ou habitant),
## sac du joueur et artisanat. Touche I (ou Tab) pour le joueur, E près d'un habitant.
## Cliquer sur un objet du sac l'équipe sur le personnage ciblé.

signal closed

const C_BG := Color("241d1a")
const C_PANEL := Color("2f2622")
const C_FRAME := Color("8a6a3a")
const C_SLOT := Color("1c1614")
const C_TEXT := Color("f0e6d2")
const C_DIM := Color("a8997f")
const C_OK := Color("8ad66a")
const C_BAD := Color("e0705a")

const SLOT_ORDER := [ItemData.Slot.HEAD, ItemData.Slot.CHEST, ItemData.Slot.ARMS, ItemData.Slot.LEGS,
	ItemData.Slot.MAIN_HAND, ItemData.Slot.OFF_HAND, ItemData.Slot.BACK]

var player: Player
var target: Node

var _title: Label
var _slots_box: VBoxContainer
var _stats: Label
var _bag: GridContainer
var _info_name: Label
var _info_icon: TextureRect
var _info_text: Label
var _info_bar: HFlowContainer
var _bar_row: HBoxContainer
var _recipes: VBoxContainer
var _bench: Label
var _cat := "Outils"
var _cat_buttons := {}
var _job_box: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	var hud := get_parent()
	player = hud.get("player") as Player
	if player:
		player.open_inventory.connect(open)
		player.inventory.changed.connect(_refresh)
	add_to_group("inventory_ui")
	hide()


func open(who: Node) -> void:
	Sound.ui("ui_open")
	if target and target.has_node("Equipment"):
		var old_eq := target.get_node("Equipment") as CharacterEquipment
		if old_eq.changed.is_connected(_refresh):
			old_eq.changed.disconnect(_refresh)
	target = who
	var eq := target.get_node_or_null("Equipment") as CharacterEquipment
	if eq and not eq.changed.is_connected(_refresh):
		eq.changed.connect(_refresh)
	player.ui_open = true
	_set_hud_info(false)
	# au-dessus des bandeaux et messages du HUD
	get_parent().move_child(self, get_parent().get_child_count() - 1)
	show()
	_refresh()


func close() -> void:
	hide()
	_set_hud_info(true)
	if player:
		player.ui_open = false
	closed.emit()


func _set_hud_info(on: bool) -> void:
	var info := get_parent().get_node_or_null("Info") as CanvasItem
	if info:
		info.visible = on and bool(SaveGame.options.show_help)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("inventory") or event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("crafts"):
		close()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- construction

func _style(bg: Color, border: Color = C_FRAME, width := 2, radius := 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


func _label(text: String, size := 11, color := C_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _column(title: String, width: float, parent: Control) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.small_frame(8))
	panel.custom_minimum_size = Vector2(width, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	box.add_child(MenuKit.heading(title, 13))
	return box


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var win := PanelContainer.new()
	win.add_theme_stylebox_override("panel", UiTheme.frame(14))
	MenuKit.animate_open(win)
	win.set_anchors_preset(Control.PRESET_CENTER)
	win.custom_minimum_size = Vector2(920, 470)
	win.position = Vector2(-460, -235)
	add_child(win)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	win.add_child(root)
	var head := HBoxContainer.new()
	root.add_child(head)
	_title = _label("Équipement", 15, Color("f2c86a"))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	head.add_child(_label("Clic : équiper    [I] / [Échap] : fermer", 10, C_DIM))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 8)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)

	# 1. personnage
	var c1 := _column("Équipé", 250, cols)
	_slots_box = VBoxContainer.new()
	_slots_box.add_theme_constant_override("separation", 3)
	c1.add_child(_slots_box)
	_stats = _label("", 11)
	c1.add_child(_stats)
	_job_box = VBoxContainer.new()
	_job_box.add_theme_constant_override("separation", 3)
	c1.add_child(_job_box)

	# 2. sac
	var c2 := _column("Sac", 300, cols)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	c2.add_child(scroll)
	_bag = GridContainer.new()
	_bag.columns = 5
	_bag.add_theme_constant_override("h_separation", 4)
	_bag.add_theme_constant_override("v_separation", 4)
	scroll.add_child(_bag)
	# la barre de construction : on y glisse un objet du sac (bloc, meuble, graines...)
	c2.add_child(_label("Barre de construction (glisse un objet du sac dans une case · Ctrl+chiffre en jeu)", 9, C_DIM))
	_bar_row = HBoxContainer.new()
	_bar_row.add_theme_constant_override("separation", 2)
	c2.add_child(_bar_row)
	# fiche de l'objet survolé : grande image dans sa case, nom, rareté, effets, description
	var info := PanelContainer.new()
	info.add_theme_stylebox_override("panel", MenuKit.card(false, 8))
	info.custom_minimum_size = Vector2(0, 96)
	c2.add_child(info)
	var irow := HBoxContainer.new()
	irow.add_theme_constant_override("separation", 8)
	info.add_child(irow)
	_info_icon = TextureRect.new()
	_info_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_info_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_info_icon.custom_minimum_size = Vector2(52, 52)
	var islot := PanelContainer.new()
	islot.add_theme_stylebox_override("panel", UiTheme.box("slot", 8, Vector4(4, 4, 4, 4)))
	islot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	islot.add_child(_info_icon)
	irow.add_child(islot)
	var ib := VBoxContainer.new()
	ib.add_theme_constant_override("separation", 1)
	irow.add_child(ib)
	_info_name = MenuKit.heading("Survole un objet", 12, C_TEXT)
	ib.add_child(_info_name)
	_info_text = _label("", 10, C_DIM)
	_info_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_text.custom_minimum_size = Vector2(210, 0)
	ib.add_child(_info_text)
	# objets posables : les ranger dans une case de la barre de construction (Ctrl+chiffre en jeu)
	_info_bar = HFlowContainer.new()
	_info_bar.add_theme_constant_override("h_separation", 2)
	_info_bar.custom_minimum_size = Vector2(210, 0)
	ib.add_child(_info_bar)

	# 3. artisanat
	var c3 := _column("Artisanat", 330, cols)
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 2)
	tabs.add_theme_constant_override("v_separation", 2)
	tabs.custom_minimum_size.x = 320
	for cname in ["Outils", "Cuisine", "Équipement", "Construction", "Mobilier", "Matériaux", "Légendaire", "Armurerie", "Armures", "Forge", "Enchantement", "Métiers", "★ Favoris"]:
		var tb := Button.new()
		tb.text = cname
		tb.toggle_mode = true
		tb.add_theme_font_size_override("font_size", 9)
		tb.pressed.connect(func(): _cat = cname; _refresh())
		tabs.add_child(tb)
		_cat_buttons[cname] = tb
	c3.add_child(tabs)
	_bench = _label("", 9, C_DIM)
	_bench.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bench.custom_minimum_size = Vector2(310, 0)
	c3.add_child(_bench)
	# recherche dans toutes les recettes, filtre « fabricable »
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 4)
	_search = LineEdit.new()
	_search.placeholder_text = "Rechercher (ex. épée acier, laine bleue)..."
	_search.custom_minimum_size = Vector2(210, 26)
	_search.add_theme_font_size_override("font_size", 10)
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_t): _refresh())
	srow.add_child(_search)
	_only_ok = CheckBox.new()
	_only_ok.text = "Fabricable"
	_only_ok.add_theme_font_size_override("font_size", 10)
	_only_ok.toggled.connect(func(_on): _refresh())
	srow.add_child(_only_ok)
	c3.add_child(srow)
	var rscroll := ScrollContainer.new()
	rscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	c3.add_child(rscroll)
	_recipes = VBoxContainer.new()
	_recipes.add_theme_constant_override("separation", 3)
	_recipes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rscroll.add_child(_recipes)


func _icon_box(item: ItemData, size: float) -> Control:
	var frame := PanelContainer.new()
	# case creusée ; la rareté teinte légèrement son cadre
	var tint := Color.WHITE.lerp(item.rarity_color(), 0.4) if item else Color.WHITE
	frame.add_theme_stylebox_override("panel", UiTheme.box("slot", 8, Vector4(3, 3, 3, 3), tint))
	frame.custom_minimum_size = Vector2(size, size)
	if item:
		var tr := TextureRect.new()
		tr.texture = Items.get_icon(item)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(size - 6, size - 6)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(tr)
	return frame


# ---------------------------------------------------------------- contenu

func _refresh() -> void:
	if not visible or target == null or player == null:
		return
	var eq := target.get_node("Equipment") as CharacterEquipment
	_title.text = "Équipement — %s" % target.call("display_title")

	for c in _slots_box.get_children():
		c.queue_free()
	for slot in SLOT_ORDER:
		var item := eq.get_item(slot)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(_icon_box(item, 36))
		var txt := VBoxContainer.new()
		txt.add_theme_constant_override("separation", -2)
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		txt.add_child(_label(ItemData.SLOT_NAMES[slot], 9, C_DIM))
		txt.add_child(_label(item.display_name if item else "—", 11, item.rarity_color() if item else C_DIM))
		row.add_child(txt)
		if item:
			var b := Button.new()
			b.text = "Retirer"
			b.add_theme_font_size_override("font_size", 9)
			b.pressed.connect(_unequip.bind(slot))
			row.add_child(b)
			row.mouse_entered.connect(_show_info.bind(item))
		_slots_box.add_child(row)

	var s: Dictionary = target.call("total_stats")
	_stats.text = "Vie %d    Attaque %d    Défense %d\nMagie %d    Vitesse %d %%" % [s.health, s.attack, s.defense, s.magic, roundi(s.speed * 100.0)]

	for c in _bag.get_children():
		c.queue_free()
	for e in player.inventory.entries:
		var item: ItemData = e.item
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(54, 54)
		btn.flat = true
		for st in ["normal", "hover", "pressed", "focus"]:
			btn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		var box := _icon_box(item, 54)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(box)
		if e.count > 1:
			var n := _label("×%d" % e.count, 10)
			n.add_theme_color_override("font_outline_color", Color.BLACK)
			n.add_theme_constant_override("outline_size", 3)
			n.position = Vector2(26, 36)
			btn.add_child(n)
		btn.mouse_entered.connect(_show_info.bind(item))
		btn.pressed.connect(_use_item.bind(item))
		# glisser un objet posable vers la barre de construction
		if player.hand and player.hand.choices().has(item):
			btn.gui_input.connect(func(ev):
				if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
					btn.set_meta("press_at", ev.position if ev.pressed else Vector2.INF)
				elif ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) and btn.has_meta("press_at"):
					var at: Vector2 = btn.get_meta("press_at")
					if at != Vector2.INF and at.distance_to(ev.position) > 6.0 and not btn.get_viewport().gui_is_dragging():
						btn.set_meta("press_at", Vector2.INF)
						var prev := _icon_box(item, 40)
						prev.modulate.a = 0.85
						btn.force_drag({"bar_item": item.id}, prev))
		_bag.add_child(btn)
	if player.inventory.entries.is_empty():
		_bag.add_child(_label("Sac vide", 10, C_DIM))
	_refresh_bar_row()

	var near := player.is_near_workbench()
	_stations = player.nearby_stations()
	var names := []
	for sid in _stations:
		var it: ItemData = Items.get_item(sid)
		names.append(it.display_name if it else sid)
	_bench.text = "À proximité : %s" % (", ".join(PackedStringArray(names)) if names else "aucun meuble d'artisan (approche-toi d'un établi, d'un four, d'une enclume...)")
	_bench.add_theme_color_override("font_color", C_OK if near else C_DIM)
	for cn in _cat_buttons:
		_cat_buttons[cn].set_pressed_no_signal(cn == _cat)
	for c in _recipes.get_children():
		c.queue_free()
	if _search and _search.text.strip_edges() != "":
		_search_rows(near)
		_refresh_job()
		return
	if _cat == "★ Favoris":
		var favs: Array = Items.recipes.filter(func(r): return r.result and player.craft_favs.has(r.result.id))
		if favs.is_empty():
			_recipes.add_child(_label("Aucune recette favorite : clique sur ☆ à côté d'une recette.", 10, C_DIM))
		for r: RecipeData in _filter_ok(favs, near):
			_recipes.add_child(_recipe_row(r, near))
		_refresh_job()
		return
	if _cat == "Forge":
		_forge_rows()
		_refresh_job()
		return
	if _cat == "Armures":
		_armor_rows(near)
		_refresh_job()
		return
	if _cat == "Construction":
		_construction_rows(near)
		_refresh_job()
		return
	if _cat == "Armurerie":
		_armory_rows(near)
		_refresh_job()
		return
	if _cat == "Enchantement":
		_enchant_rows()
		_refresh_job()
		return
	if _cat == "Métiers":
		_crafts_rows()
		_refresh_job()
		return
	var list: Array = Items.recipes.filter(func(r): return r.category == _cat or (_cat == "Matériaux" and r.category == "Matériaux"))
	list.sort_custom(func(a, b): return int(a.can_craft(player.inventory, near, _stations)) > int(b.can_craft(player.inventory, near, _stations)))
	for r: RecipeData in _filter_ok(list, near):
		_recipes.add_child(_recipe_row(r, near))
	_refresh_job()


var _stations: Array = []


## Poste de travail d'un habitant (affiché quand on ouvre l'équipement d'un habitant).
func _refresh_job() -> void:
	for c in _job_box.get_children():
		c.queue_free()
	if target == player or not target.has_method("is_at_work"):
		return
	var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
	if k == null:
		return
	_evolution_box()
	# compagnon d'expédition (2 au plus)
	var n_comp := get_tree().get_nodes_in_group("villagers").filter(func(v): return v.get("companion")).size()
	var comp := CheckButton.new()
	var max_comp: int = Villager.max_companions(get_tree())
	comp.text = "Compagnon d'expédition (%d/%d)" % [n_comp, max_comp]
	comp.add_theme_font_size_override("font_size", 11)
	comp.button_pressed = target.get("companion")
	comp.disabled = not target.get("companion") and n_comp >= max_comp
	comp.toggled.connect(func(on):
		if on:
			k.assign(target, null)
		target.set_companion(on)
		player.notify.emit(("%s t'accompagne : il te suit partout et combat à tes côtés." if on else "%s retourne au village.") % target.villager_name)
		_refresh())
	_job_box.add_child(comp)
	if target.get("companion"):
		_job_box.add_child(_label("Niveau %d · progresse avec toi." % target.get("level"), 9, C_DIM))
		return
	_job_box.add_child(_label("Poste de travail", 12, Color("f2c86a")))
	var cur = target.get("work_room")
	var opt := OptionButton.new()
	opt.add_theme_font_size_override("font_size", 10)
	opt.add_item("Aucun (se promène)")
	var rooms := k.workplaces()
	var sel := 0
	for i in rooms.size():
		var r: Dictionary = rooms[i]
		var t: RoomTypeData = r.type
		var a := Kingdom.affinity(target, t.job_id)
		var stars := "★".repeat(clampi(roundi((a - 0.5) * 4.0), 1, 5))
		opt.add_item("%s — %s %d/%d  %s" % [t.display_name, t.job_name, k.workers_of(r).size(), t.job_slots, stars])
		if r == cur:
			sel = i + 1
	opt.select(sel)
	opt.item_selected.connect(func(idx):
		var ok := k.assign(target, null if idx == 0 else rooms[idx - 1])
		if not ok:
			player.notify.emit("Plus de place à ce poste.")
		_refresh())
	_job_box.add_child(opt)
	if rooms.is_empty():
		var l := _label("Construis une pièce avec des postes (forge, boulangerie...) pour lui donner un métier.", 9, C_DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(230, 0)
		_job_box.add_child(l)
	else:
		var best := []
		for jid in Kingdom.RACE_AFFINITY.get((target.get("race") as RaceData).model_id, []):
			best.append(jid)
		var l2 := _label("Doué pour : %s" % ", ".join(best), 9, C_DIM)
		_job_box.add_child(l2)


## Pacte : donner un nom à l'habitant pour le faire évoluer.
func _evolution_box() -> void:
	if target.has_meta("story") or not Evolution.pact_known(get_tree()):
		return
	var nxt := Evolution.next_villager_evo(target)
	var evo: int = target.get("evo")
	if nxt.is_empty():
		_job_box.add_child(_label("✦ Évolution finale : %s" % target.call("race_title"), 11, Color("d8c0ff")))
		return
	_job_box.add_child(_label("✦ Pacte : nommer pour évoluer", 12, Color("d8c0ff")))
	var info := _label("→ %s (%s)" % [nxt[1], Evolution.cost_text(evo)], 9, C_DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(230, 0)
	_job_box.add_child(info)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var name_edit := LineEdit.new()
	name_edit.text = target.get("villager_name")
	name_edit.max_length = 18
	name_edit.custom_minimum_size = Vector2(120, 0)
	name_edit.add_theme_font_size_override("font_size", 10)
	row.add_child(name_edit)
	var why := Evolution.villager_block_reason(target, player)
	var b := MenuKit.button("Nommer", 90, 10)
	b.disabled = why != ""
	b.tooltip_text = why if why != "" else "Donne ce nom par le Pacte : il évolue en %s." % nxt[1]
	b.pressed.connect(func():
		if Evolution.evolve_villager(target, player, name_edit.text):
			_refresh())
	row.add_child(b)
	_job_box.add_child(row)
	if why != "":
		var l := _label(why, 9, MenuKit.C_BAD)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(230, 0)
		_job_box.add_child(l)


## Onglet « Forge » : renforcer (+1 à +10) et sertir des gemmes, à l'enclume.
func _forge_rows() -> void:
	var anvil := _stations.has("enclume")
	var head := _label("Renforce ton équipement (+1 à +10), sertis des gemmes et grave des runes." + ("" if anvil else "  Approche-toi d'une enclume."), 9, C_OK if anvil else C_DIM)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.custom_minimum_size = Vector2(300, 0)
	_recipes.add_child(head)
	var items := Forge.workable(player)
	if items.is_empty():
		_recipes.add_child(_label("Aucune arme ni armure à travailler.", 10, C_DIM))
	for it: ItemData in items:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _style(C_SLOT, C_FRAME.darkened(0.5), 1))
		var col := VBoxContainer.new()
		panel.add_child(col)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		col.add_child(row)
		row.add_child(_icon_box(it, 34))
		var worn: bool = player.equipment.slots.values().has(it)
		var txt := VBoxContainer.new()
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		txt.add_child(_label(it.display_name + ("  (porté)" if worn else ""), 11, it.rarity_color()))
		txt.add_child(_label("%s  ·  gemmes %d / %d" % [it.stats_text().get_slice("\n", 0), it.gems.size(), Forge.sockets(it.upgrade)], 9, C_DIM))
		row.add_child(txt)
		if it.upgrade < Forge.MAX_LEVEL:
			var why := Forge.upgrade_block(player, it, _stations)
			var b := Button.new()
			b.text = "+%d" % (it.upgrade + 1)
			b.add_theme_font_size_override("font_size", 11)
			b.custom_minimum_size = Vector2(46, 30)
			b.disabled = why != ""
			b.tooltip_text = "Renforcer : %s%s" % [Forge.cost_text(it.upgrade + 1), ("\n" + why) if why != "" else ""]
			b.pressed.connect(func():
				Forge.upgrade(player, it, _stations)
				_refresh())
			row.add_child(b)
			col.add_child(_label("Coût du +%d : %s" % [it.upgrade + 1, Forge.cost_text(it.upgrade + 1)], 8, C_DIM if why != "" else C_OK))
		# gemmes du sac que l'on peut sertir
		if it.gems.size() < Forge.sockets(it.upgrade):
			var gems := HBoxContainer.new()
			gems.add_theme_constant_override("separation", 3)
			for gid in Forge.GEMS:
				var n := player.inventory.count(Items.get_item(gid))
				if n <= 0:
					continue
				var gb := Button.new()
				gb.text = "%s (%d)" % [Forge.GEMS[gid].name, n]
				gb.add_theme_font_size_override("font_size", 9)
				gb.tooltip_text = "Sertir : %s" % Forge.GEMS[gid].text
				gb.disabled = Forge.gem_block(player, it, gid, _stations) != ""
				gb.pressed.connect(func():
					Forge.socket(player, it, gid, _stations)
					_refresh())
				gems.add_child(gb)
			if gems.get_child_count() > 0:
				col.add_child(gems)
		# runes de l'enchanteur
		var runes := HBoxContainer.new()
		runes.add_theme_constant_override("separation", 3)
		for rid in Forge.RUNES:
			var n := player.inventory.count(Items.get_item(rid))
			if n <= 0:
				continue
			var rb := Button.new()
			rb.text = "Rune %s (%d)" % [Forge.RUNES[rid].name, n]
			rb.add_theme_font_size_override("font_size", 9)
			rb.tooltip_text = "Graver : %s%s" % [Forge.RUNES[rid].text, " (remplace la rune actuelle)" if it.rune != "" else ""]
			rb.disabled = Forge.rune_block(player, it, rid, _stations) != ""
			rb.pressed.connect(func():
				Forge.inscribe(player, it, rid, _stations)
				_refresh())
			runes.add_child(rb)
		if runes.get_child_count() > 0:
			col.add_child(runes)
		_recipes.add_child(panel)


func _recipe_row(r: RecipeData, near: bool) -> Control:
	var craft := Crafts.craft_of_recipe(r)
	var need_lv := Crafts.recipe_level(r)
	var lv_ok := Crafts.level(player, craft) >= need_lv
	var ok := r.can_craft(player.inventory, near, _stations) and lv_ok
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(C_SLOT if ok else C_SLOT.darkened(0.2), C_FRAME.darkened(0.5 if ok else 0.7), 1))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)
	row.add_child(_icon_box(r.result, 34))
	var txt := VBoxContainer.new()
	txt.add_theme_constant_override("separation", -2)
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name := r.result.display_name + (" ×%d" % r.result_count if r.result_count > 1 else "")
	txt.add_child(_label(name, 11, r.result.rarity_color() if ok else r.result.rarity_color().darkened(0.35)))
	var parts := []
	for i in r.ingredients.size():
		var have := player.inventory.count(r.ingredients[i])
		var need := r.amount_of(i)
		parts.append("[color=#%s]%d %s (%d)[/color]" % [(C_OK if have >= need else C_BAD).to_html(false), need, r.ingredients[i].display_name, have])
	if r.needs_workbench:
		parts.append("[color=#%s]établi[/color]" % (C_OK if near else C_BAD).to_html(false))
	if r.station != "":
		var st_item: ItemData = Items.get_item(r.station)
		parts.append("[color=#%s]près : %s[/color]" % [(C_OK if _stations.has(r.station) else C_BAD).to_html(false), st_item.display_name if st_item else r.station])
	if need_lv > 1:
		parts.append("[color=#%s]%s niv. %d[/color]" % [(C_OK if lv_ok else C_BAD).to_html(false), Crafts.CRAFTS[craft].name, need_lv])
	var ing := RichTextLabel.new()
	ing.bbcode_enabled = true
	ing.fit_content = true
	ing.scroll_active = false
	ing.text = ", ".join(parts)
	ing.add_theme_font_size_override("normal_font_size", 9)
	ing.custom_minimum_size = Vector2(200, 0)
	ing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	txt.add_child(ing)
	row.add_child(txt)
	var fav := Button.new()
	var is_fav: bool = player.craft_favs.has(r.result.id)
	fav.text = "★" if is_fav else "☆"
	fav.flat = true
	fav.tooltip_text = "Retirer des favoris" if is_fav else "Ajouter aux favoris"
	fav.add_theme_font_size_override("font_size", 13)
	fav.add_theme_color_override("font_color", Color("ffd24a") if is_fav else C_DIM)
	fav.pressed.connect(func():
		if player.craft_favs.has(r.result.id):
			player.craft_favs.erase(r.result.id)
		else:
			player.craft_favs.append(r.result.id)
		_refresh())
	row.add_child(fav)
	# armes de l'arsenal : on peut aussi les commander au forgeron du village
	if r.category == "Armurerie" and Artisans.has_smith(get_tree()):
		var ob := Button.new()
		ob.text = "Commander"
		ob.add_theme_font_size_override("font_size", 9)
		ob.tooltip_text = "Le forgeron du village la fabrique pour toi (ingrédients + %d or), même si ton métier est trop bas." % Artisans.order_gold(r)
		ob.disabled = not r.can_craft(player.inventory, true, [r.station]) or player.inventory.count(Items.get_item("piece_or")) < Artisans.order_gold(r)
		ob.pressed.connect(func():
			if Artisans.order(player, r):
				player.notify.emit("Commande passée au forgeron : %s." % r.result.display_name)
			_refresh())
		row.add_child(ob)
	var b := Button.new()
	b.text = "Fabriquer"
	b.disabled = not ok
	b.add_theme_font_size_override("font_size", 9)
	b.pressed.connect(_craft.bind(r))
	row.add_child(b)
	panel.mouse_entered.connect(_show_info.bind(r.result))
	return panel


func _show_info(item: ItemData) -> void:
	_info_icon.texture = Items.get_icon(item)
	_info_name.text = "%s  ·  %s" % [item.display_name, item.slot_name()]
	_info_name.add_theme_color_override("font_color", item.rarity_color())
	var st := item.stats_text()
	_info_text.text = (st + "\n" if st != "" else "") + item.description + ("\nDeux mains." if item.two_handed else "") + _compare_text(item)
	_show_bar_choice(item)


## Les 10 cases de la barre de construction dans le sac : on y dépose un objet glissé ; clic droit : vider.
func _refresh_bar_row() -> void:
	if _bar_row == null or player == null or player.hand == null:
		return
	for c in _bar_row.get_children():
		c.queue_free()
	var hb: HandBuild = player.hand
	hb.sync_slots()
	for i in HandBuild.SLOTS:
		var id: String = hb.slots[i]
		var it := Items.get_item(id) as ItemData if id != "" else null
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(27, 27)
		cell.add_theme_stylebox_override("panel", UiTheme.box("slot", 6, Vector4(1, 1, 1, 1)))
		cell.tooltip_text = ("%s · Ctrl+%d (clic droit : vider)" % [it.display_name, (i + 1) % 10]) if it else "Case %d : glisse un objet du sac ici" % ((i + 1) % 10)
		if it:
			var ic := TextureRect.new()
			ic.texture = Items.get_icon(it)
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(ic)
		else:
			var n := _label(str((i + 1) % 10), 9, C_DIM)
			n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			n.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(n)
		cell.set_drag_forwarding(Callable(),
			func(_pos, data): return data is Dictionary and data.has("bar_item"),
			func(_pos, data):
				hb.assign_slot(i, str(data.bar_item))
				Sound.ui("ui_click")
				_refresh_bar_row())
		cell.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT and hb.slots[i] != "":
				hb.slots[i] = ""
				hb.selection_changed.emit()
				_refresh_bar_row())
		_bar_row.add_child(cell)


## Rangée « Barre : 1 … 0 » sous la fiche d'un objet posable (bloc, meuble, graine, outil à poser).
func _show_bar_choice(item: ItemData) -> void:
	if _info_bar == null:
		return
	for c in _info_bar.get_children():
		c.queue_free()
	var hb: HandBuild = player.hand if player else null
	if hb == null or item == null or not hb.choices().has(item):
		return
	var cur := hb.slots.find(item.id)
	_info_bar.add_child(_label("Barre de construction :", 10, C_DIM))
	for i in HandBuild.SLOTS:
		var b := Button.new()
		b.text = str((i + 1) % 10)
		b.custom_minimum_size = Vector2(20, 18)
		b.add_theme_font_size_override("font_size", 10)
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = "Ranger %s dans la case %d (Ctrl+%d en jeu)" % [item.display_name, (i + 1) % 10, (i + 1) % 10]
		if i == cur:
			b.modulate = Color("ffe08a")
		b.pressed.connect(func():
			hb.assign_slot(i, item.id)
			_refresh_bar_row()
			player.notify.emit("%s rangé dans la case %d de la barre (Ctrl+%d)." % [item.display_name, (i + 1) % 10, (i + 1) % 10])
			_show_bar_choice(item))
		_info_bar.add_child(b)


func _use_item(item: ItemData) -> void:
	if item.is_food() and target == player:
		player.eat(item)
		_refresh()
		return
	if not item.is_equipment():
		return
	var eq := target.get_node("Equipment") as CharacterEquipment
	if not player.inventory.remove(item, 1):
		return
	for old in eq.equip(item):
		player.inventory.add(old)
	player.notify.emit("%s équipe : %s" % [_who(), item.display_name])
	_refresh()


func _unequip(slot: int) -> void:
	var eq := target.get_node("Equipment") as CharacterEquipment
	var old := eq.unequip(slot)
	if old:
		player.inventory.add(old)
	_refresh()


func _craft(r: RecipeData) -> void:
	if Crafts.level(player, Crafts.craft_of_recipe(r)) < Crafts.recipe_level(r):
		return
	if r.craft(player.inventory, player.is_near_workbench(), player.nearby_stations()):
		var extra := Crafts.on_crafted(player, r)
		player.notify.emit("Fabriqué : %s%s" % [r.result.display_name, ("  ·  " + extra) if extra != "" else ""])
		player.crafted.emit(r.result.id)
		Sound.ui("craft")
	_refresh()


func _who() -> String:
	return "Vous" if target == player else String(target.get("villager_name"))


# ---------------------------------------------------------------- armurerie, enchantement, métiers

var _arm_type := 0
var _arm_mat := 5
var _ench_item: ItemData


func _stepper(text: String, on_prev: Callable, on_next: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	var a := Button.new()
	a.text = "◀"
	a.add_theme_font_size_override("font_size", 10)
	a.pressed.connect(func(): on_prev.call(); _refresh())
	h.add_child(a)
	var l := _label(text, 11, C_TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var b := Button.new()
	b.text = "▶"
	b.add_theme_font_size_override("font_size", 10)
	b.pressed.connect(func(): on_next.call(); _refresh())
	h.add_child(b)
	return h


## Onglet « Armurerie » : les 884 armes, par type et par matériau (4 designs chacun).
func _armory_rows(near: bool) -> void:
	var nt := Arsenal.TYPE_ORDER.size()
	var nm := Arsenal.MATERIALS.size()
	var type: String = Arsenal.TYPE_ORDER[_arm_type]
	var m: Dictionary = Arsenal.MATERIALS[_arm_mat]
	_recipes.add_child(_label("Arsenal : %d armes (%d types × %d matériaux × 4 designs)" % [nt * nm * 4, nt, nm], 9, C_DIM))
	_recipes.add_child(_stepper("Type : %s (%d/%d)" % [Arsenal.TYPES[type].names[0], _arm_type + 1, nt],
		func(): _arm_type = (_arm_type + nt - 1) % nt, func(): _arm_type = (_arm_type + 1) % nt))
	_recipes.add_child(_stepper("Matériau : %s" % str(m.suffix).trim_prefix("en ").trim_prefix("d'").capitalize(),
		func(): _arm_mat = (_arm_mat + nm - 1) % nm, func(): _arm_mat = (_arm_mat + 1) % nm))
	var flv := Crafts.level(player, "forgeron")
	_recipes.add_child(_label("Forgeron d'armes : niveau %d  ·  ce matériau : niveau %d" % [flv, int(m.level)], 9, C_OK if flv >= int(m.level) else C_BAD))
	var kg := get_tree().get_first_node_in_group("kingdom")
	if kg and Artisans.has_smith(get_tree()):
		_recipes.add_child(_label("Forgeron du village au travail · commandes en attente : %d" % kg.forge_orders.size(), 9, C_DIM))
	for d in 4:
		var id := Arsenal.make_id(type, m.id, d)
		for r: RecipeData in Items.recipes:
			if r.result and r.result.id == id:
				_recipes.add_child(_recipe_row(r, near))
				break


## Onglet « Enchantement » (près d'un autel) : enchanter, désenchanter, réduire en poussière.
func _enchant_rows() -> void:
	var altar := _stations.has("autel")
	var lv := Crafts.level(player, "enchanteur")
	_recipes.add_child(_label("Enchanteur niveau %d : rang max %s  ·  %s" % [lv, Forge.RANK_NAMES[Crafts.max_enchant_rank(player)],
		"autel à proximité" if altar else "approche-toi d'un autel"], 10, C_OK if altar else C_BAD))
	_recipes.add_child(_label("Poussière arcanique : %d  ·  Pierres d'âme : %d" % [player.inventory.count(Items.get_item("poussiere_arcane")),
		player.inventory.count(Items.get_item("pierre_ame"))], 9, C_DIM))
	var items := Forge.workable(player)
	if items.is_empty():
		_recipes.add_child(_label("Aucun objet à enchanter.", 10, C_DIM))
		return
	if _ench_item == null or not items.has(_ench_item):
		_ench_item = player.weapon() if items.has(player.weapon()) else items[0]
	var idx := items.find(_ench_item)
	_recipes.add_child(_stepper(_ench_item.display_name, func(): _ench_item = items[(idx + items.size() - 1) % items.size()],
		func(): _ench_item = items[(idx + 1) % items.size()]))
	var it := _ench_item
	_recipes.add_child(_label("Emplacements : %d / %d  ·  rang max sur cet objet : %s (raffinage +%d)" % [it.enchants.size(),
		Forge.ench_slots(it), Forge.RANK_NAMES[Forge.item_rank_cap(it)], it.upgrade], 9, C_TEXT))
	for e in it.enchants:
		var row := HBoxContainer.new()
		row.add_child(_label("✦ %s %s" % [Forge.ENCHANTS[e][0], Forge.RANK_NAMES[int(it.enchants[e])]], 10, Color("c8a8ff")))
		var rb := Button.new()
		rb.text = "Retirer"
		rb.add_theme_font_size_override("font_size", 9)
		rb.disabled = not altar
		rb.pressed.connect(func():
			var v := Forge.disenchant(player, it, e, _stations)
			if v:
				_ench_item = v
			_refresh())
		row.add_child(rb)
		_recipes.add_child(row)
	for e in Forge.enchants_for(it):
		var cur := int(it.enchants.get(e, 0))
		if cur >= 5:
			continue
		var rank := cur + 1
		var why := Forge.enchant_block(player, it, e, rank, _stations)
		var b := Button.new()
		b.text = "%s %s — %s" % [Forge.ENCHANTS[e][0], Forge.RANK_NAMES[rank], Forge.ENCHANTS[e][4]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 9)
		b.disabled = why != ""
		b.tooltip_text = "Coût : %s%s" % [Forge.ench_cost_text(player, e, rank), ("\n" + why) if why != "" else ""]
		b.pressed.connect(func():
			var v := Forge.enchant(player, it, e, rank, _stations)
			if v:
				_ench_item = v
				_show_info(v)
			_refresh())
		_recipes.add_child(b)
	# réduire en poussière les objets du sac
	_recipes.add_child(_label("Réduire en poussière arcanique (objets du sac) :", 10, C_TEXT))
	for en in player.inventory.entries:
		var bi: ItemData = en.item
		if not bi.is_equipment():
			continue
		var sb := Button.new()
		sb.text = "%s → %d poussière" % [bi.display_name, Forge.salvage_value(bi)]
		sb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		sb.add_theme_font_size_override("font_size", 9)
		sb.disabled = not altar
		sb.pressed.connect(func():
			Forge.salvage(player, bi, _stations)
			_refresh())
		_recipes.add_child(sb)


## Onglet « Métiers » : les 12 métiers, leur niveau et leurs bonus.
func _crafts_rows() -> void:
	_recipes.add_child(_label("Les métiers montent en pratiquant (niveau 1 à 100). Total : %d / %d" % [Crafts.total_level(player), Crafts.ORDER.size() * Crafts.MAX_LEVEL], 9, C_DIM))
	for c in Crafts.ORDER:
		var info: Dictionary = Crafts.CRAFTS[c]
		var lv := Crafts.level(player, c)
		var pr := Crafts.progress(player, c)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		box.add_child(_label("%s %s — niveau %d" % [info.icon, info.name, lv], 11, Color(info.color)))
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(300, 8)
		bar.show_percentage = false
		bar.max_value = maxi(1, int(pr[1]))
		bar.value = int(pr[0])
		box.add_child(bar)
		var t := _label("%s  ·  %s" % [info.text, Crafts.perk_text(c, lv)], 8, C_DIM)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size.x = 300
		box.add_child(t)
		_recipes.add_child(box)


## Ouvre l'inventaire sur un onglet (ex. « Métiers »).
func open_tab(who: Node, tab: String) -> void:
	_cat = tab
	open(who)


var _family := 0


## Onglet « Construction » : les blocs par famille (pierres, bois, laine, béton...), façon Minecraft.
func _construction_rows(near: bool) -> void:
	var fams := BlockCatalog.FAMILIES
	var list: Array = Items.recipes.filter(func(r): return r.category == "Construction" and r.get_meta("family", "Classiques") == fams[_family])
	_recipes.add_child(_label("%d blocs de construction en tout" % BlockCatalog.count_blocks(Items), 9, C_DIM))
	_recipes.add_child(_stepper("%s (%d)" % [fams[_family], list.size()],
		func(): _family = (_family + fams.size() - 1) % fams.size(), func(): _family = (_family + 1) % fams.size()))
	list.sort_custom(func(a, b): return int(a.can_craft(player.inventory, near, _stations)) > int(b.can_craft(player.inventory, near, _stations)))
	for r: RecipeData in _filter_ok(list, near):
		_recipes.add_child(_recipe_row(r, near))


var _armor_fam := 3


## Onglet « Armures » : les panoplies, matériau par matériau (et le cuir teint).
func _armor_rows(near: bool) -> void:
	var fams := ArmorSets.families()
	_armor_fam = posmod(_armor_fam, fams.size())
	var fam: String = fams[_armor_fam]
	var list: Array = Items.recipes.filter(func(r): return r.category == "Armures" and r.get_meta("family", "") == fam)
	_recipes.add_child(_label("%d pièces d'armure en panoplies" % ArmorSets.count(Items), 9, C_DIM))
	var title := "Cuir teint" if fam == "cuir" else str(Arsenal.material(fam).suffix).trim_prefix("en ").trim_prefix("d'").capitalize()
	_recipes.add_child(_stepper("Panoplie : %s" % title, func(): _armor_fam -= 1, func(): _armor_fam += 1))
	for r: RecipeData in _filter_ok(list, near):
		_recipes.add_child(_recipe_row(r, near))


var _search: LineEdit
var _only_ok: CheckBox


## Sans accents ni majuscules (pour la recherche).
static func _plain(t: String) -> String:
	t = t.to_lower()
	for pair in [["é", "e"], ["è", "e"], ["ê", "e"], ["ë", "e"], ["à", "a"], ["â", "a"], ["î", "i"], ["ï", "i"], ["ô", "o"], ["ù", "u"], ["û", "u"], ["ç", "c"], ["œ", "oe"]]:
		t = t.replace(pair[0], pair[1])
	return t


func _filter_ok(list: Array, near: bool) -> Array:
	if _only_ok == null or not _only_ok.button_pressed:
		return list
	return list.filter(func(r): return r.can_craft(player.inventory, near, _stations) and Crafts.level(player, Crafts.craft_of_recipe(r)) >= Crafts.recipe_level(r))


## Recherche : tous les mots doivent se trouver dans le nom de l'objet (60 résultats au plus).
func _search_rows(near: bool) -> void:
	var words := _plain(_search.text.strip_edges()).split(" ", false)
	var found: Array = Items.recipes.filter(func(r):
		if r.result == null or r.result.has_meta("hidden"):
			return false
		var n := _plain(r.result.display_name)
		for w in words:
			if not n.contains(w):
				return false
		return true)
	found = _filter_ok(found, near)
	found.sort_custom(func(a, b): return int(a.can_craft(player.inventory, near, _stations)) > int(b.can_craft(player.inventory, near, _stations)))
	_recipes.add_child(_label("%d recette(s) trouvée(s)%s" % [found.size(), " (60 premières)" if found.size() > 60 else ""], 9, C_DIM))
	for r: RecipeData in found.slice(0, 60):
		_recipes.add_child(_recipe_row(r, near))


## Comparaison avec ce que le héros porte à la même place.
func _compare_text(item: ItemData) -> String:
	if not item.is_equipment() or player == null or player.equipment == null:
		return ""
	var cur: ItemData = player.equipment.get_item(item.slot)
	if cur == null or cur == item:
		return ""
	var parts := []
	for f in [["Attaque", "attack"], ["Défense", "defense"], ["Magie", "magic"]]:
		var d: int = int(item.get(f[1])) - int(cur.get(f[1]))
		if d != 0:
			parts.append("[%s %+d]" % [f[0], d])
	if parts.is_empty():
		return "\nComme %s." % cur.display_name
	return "\nComparé à %s : %s" % [cur.display_name, " ".join(PackedStringArray(parts))]
