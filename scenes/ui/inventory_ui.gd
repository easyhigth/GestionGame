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
var _bag_scroll: ScrollContainer
var _recipe_scroll: ScrollContainer
var _sort_buttons := {}
var _recipe_key := ""
## Grille d'artisanat façon Minecraft (2×2 sur soi, 3×3 à un atelier) : une case = null ou {item, count}.
## Les objets posés dans la grille sortent du sac ; ils y retournent quand on ferme ou qu'on change d'atelier.
var _grid: Array = []
var _grid_side := 0
var _grid_box: GridContainer
var _grid_result: PanelContainer
var _grid_note: RichTextLabel
var _grid_pick := 0
## Recette posée depuis le livre (prioritaire quand plusieurs recettes ont la même disposition).
var _grid_pref: RecipeData
## Plusieurs fabrications d'affilée : on ne rafraîchit qu'à la fin.
var _batch := false
var _scroll_hold := {"bag": 0, "recipes": 0, "frames": 0}
var _info_name: Label
var _info_icon: TextureRect
var _info_text: Label
var _info_bar: HFlowContainer
var _bar_row: HBoxContainer
var _recipes: VBoxContainer
var _bench: Label
var _cat := "Outils"
var _cat_buttons := {}
## Atelier ouvert ("" : l'artisanat de poche, depuis le sac ; sinon l'identifiant du meuble : etabli, enclume...).
var _mode := ""
## Vue de la colonne de droite : "" (les recettes), "uses" (que faire avec un objet), "source" (comment l'obtenir).
var _view := ""
var _view_item: ItemData
var _back_view := ""
var _tabs: HFlowContainer
var _craft_title: Control
var _srow: HBoxContainer
## Construction : forme choisie (bloc, dalle, escalier...) et matière choisie (identifiant de l'ingrédient).
var _shape := "bloc"
var _mat_id := ""
var _job_box: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	var hud := get_parent()
	player = hud.get("player") as Player
	if player:
		player.open_inventory.connect(open)
		player.open_workshop.connect(open_station)
		player.inventory.changed.connect(_refresh)
		player.pins_changed.connect(_refresh)
	add_to_group("inventory_ui")
	hide()


## Le sac (I) : l'artisanat de poche.
func open(who: Node) -> void:
	return_grid()
	_mode = ""
	_view = ""
	if not _cat in _tab_list():
		_cat = _tab_list()[0]
	_open(who)


## E devant un atelier : le sac à gauche, le menu de l'atelier à droite.
func open_station(station: String) -> void:
	return_grid()
	_mode = station
	_view = ""
	_mat_id = ""
	_cat = _tab_list()[0]
	_open(player)


func _open(who: Node) -> void:
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
	return_grid()
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
	win.custom_minimum_size = Vector2(920, 560)
	win.position = Vector2(-460, -280)
	add_child(win)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	win.add_child(root)
	var head := HBoxContainer.new()
	root.add_child(head)
	_title = _label("Équipement", 15, Color("f2c86a"))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	head.add_child(_label(KeyBindings.fmt("Clic : équiper · Clic droit : que faire avec ?    [{inventory}] / [Échap] : fermer"), 10, C_DIM))
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
	# trier le sac (le choix est gardé dans les options)
	var sort_row := HBoxContainer.new()
	sort_row.add_theme_constant_override("separation", 2)
	sort_row.add_child(_label("Trier :", 9, C_DIM))
	for so in Inventory.SORTS:
		var sb := Button.new()
		sb.text = so[1]
		sb.toggle_mode = true
		sb.focus_mode = Control.FOCUS_NONE
		sb.add_theme_font_size_override("font_size", 9)
		var mode: String = so[0]
		sb.pressed.connect(func(): set_bag_sort(mode))
		sort_row.add_child(sb)
		_sort_buttons[mode] = sb
	c2.add_child(sort_row)
	var scroll := ScrollContainer.new()
	_bag_scroll = scroll
	scroll.set_drag_forwarding(Callable(),
		func(_pos, data): return data is Dictionary and data.has("grid_from"),
		func(_pos, data): grid_take(int(data.grid_from)))
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
	_craft_title = c3.get_child(0) as Control
	_tabs = HFlowContainer.new()
	_tabs.add_theme_constant_override("h_separation", 2)
	_tabs.add_theme_constant_override("v_separation", 2)
	_tabs.custom_minimum_size.x = 320
	c3.add_child(_tabs)
	_bench = _label("", 9, C_DIM)
	_bench.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bench.custom_minimum_size = Vector2(310, 0)
	c3.add_child(_bench)
	# la grille d'artisanat : on y glisse les objets du sac, le résultat apparaît à droite
	var grow := HBoxContainer.new()
	grow.add_theme_constant_override("separation", 6)
	c3.add_child(grow)
	_grid_box = GridContainer.new()
	_grid_box.add_theme_constant_override("h_separation", 3)
	_grid_box.add_theme_constant_override("v_separation", 3)
	grow.add_child(_grid_box)
	var arrow := _label("➜", 20, C_DIM)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grow.add_child(arrow)
	_grid_result = PanelContainer.new()
	_grid_result.custom_minimum_size = Vector2(56, 56)
	_grid_result.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_grid_result.gui_input.connect(_on_result_input)
	_grid_result.mouse_entered.connect(func():
		var r := grid_recipe()
		if r:
			_show_info(r.result))
	grow.add_child(_grid_result)
	_grid_note = RichTextLabel.new()
	_grid_note.bbcode_enabled = true
	_grid_note.fit_content = true
	_grid_note.scroll_active = false
	_grid_note.custom_minimum_size = Vector2(110, 0)
	_grid_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_grid_note.add_theme_font_size_override("normal_font_size", 9)
	_grid_note.meta_clicked.connect(func(meta):
		_grid_pick += 1 if str(meta) == "next" else -1
		_grid_pref = null
		_refresh_grid())
	grow.add_child(_grid_note)
	# recherche dans toutes les recettes, filtre « fabricable »
	var srow := HBoxContainer.new()
	_srow = srow
	srow.add_theme_constant_override("separation", 4)
	_search = LineEdit.new()
	_search.placeholder_text = "Chercher dans le carnet (ex. épée acier)..."
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
	_recipe_scroll = rscroll
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
	if _batch or not visible or target == null or player == null:
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

	# on garde la position de défilement : rafraîchir (un objet ramassé, un clic...) ne remonte plus en haut
	# (plusieurs rafraîchissements dans la même image : on garde la position voulue, pas celle déjà rognée)
	var keep_bag: int = _scroll_hold.bag if _scroll_hold.frames > 0 else _bag_scroll.scroll_vertical
	# la liste des recettes ne repart en haut que si on change d'onglet, de vue ou de recherche
	var rkey := "%s|%s|%s|%s|%s|%s" % [_mode, _cat, _view, _shape, _mat_id, _search.text]
	var keep_recipes: int = (_scroll_hold.recipes if _scroll_hold.frames > 0 else _recipe_scroll.scroll_vertical) if rkey == _recipe_key else 0
	_recipe_key = rkey
	for c in _bag.get_children():
		_bag.remove_child(c)
		c.queue_free()
	var sort_mode := str(SaveGame.options.get("bag_sort", "arrivee"))
	for m in _sort_buttons:
		(_sort_buttons[m] as Button).set_pressed_no_signal(m == sort_mode)
	for e in player.inventory.sorted(sort_mode):
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
		btn.pressed.connect(func():
			# Maj+clic : toute la pile dans la grille d'artisanat (comme dans Minecraft)
			if Input.is_key_pressed(KEY_SHIFT):
				grid_quick_add(item, e.count)
			else:
				_use_item(item))
		# clic droit : que faire avec cet objet ?
		btn.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
				show_uses(item))
		# glisser un objet : vers la grille d'artisanat (toute la pile ; Ctrl : un seul), et vers la barre de
		# construction s'il se pose
		var placeable: bool = player.hand != null and player.hand.choices().has(item)
		var stack: int = e.count
		btn.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
				btn.set_meta("press_at", ev.position if ev.pressed else Vector2.INF)
			elif ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) and btn.has_meta("press_at"):
				var at: Vector2 = btn.get_meta("press_at")
				if at != Vector2.INF and at.distance_to(ev.position) > 6.0 and not btn.get_viewport().gui_is_dragging():
					btn.set_meta("press_at", Vector2.INF)
					var prev := _icon_box(item, 40)
					prev.modulate.a = 0.85
					var data := {"bag_item": item, "count": stack}
					if placeable:
						data.bar_item = item.id
					btn.force_drag(data, prev))
		_bag.add_child(btn)
	if player.inventory.entries.is_empty():
		_bag.add_child(_label("Sac vide", 10, C_DIM))
	_refresh_bar_row()

	_refresh_crafting()
	_refresh_grid()
	_refresh_job()
	_restore_scroll(keep_bag, keep_recipes)


## Remet les listes là où le joueur les avait laissées. Leur nouvelle taille n'est connue qu'après la mise en
## page : on réapplique la position pendant quelques images.
func _restore_scroll(bag: int, recipes: int) -> void:
	_scroll_hold = {"bag": bag, "recipes": recipes, "frames": 3}
	_apply_scroll_hold()


func _apply_scroll_hold() -> void:
	_bag_scroll.scroll_vertical = _scroll_hold.bag
	_recipe_scroll.scroll_vertical = _scroll_hold.recipes


func _process(_delta: float) -> void:
	if _scroll_hold.frames > 0:
		_scroll_hold.frames -= 1
		_apply_scroll_hold()


## Trie le sac : "arrivee", "type", "nom", "nombre" ou "rarete".
func set_bag_sort(mode: String) -> void:
	SaveGame.options.bag_sort = mode
	SaveGame.save_options()
	_scroll_hold.frames = 0
	_bag_scroll.scroll_vertical = 0
	_refresh()


var _stations: Array = []


## Onglets de l'artisanat ouvert : ceux de l'atelier (ou de la poche), plus le carnet et les métiers sur soi.
func _tab_list() -> Array:
	var out := Workshops.tabs_for(_mode)
	if _mode == "":
		out += ["Carnet", "Métiers"]
	return out


func _rebuild_tabs() -> void:
	for c in _tabs.get_children():
		_tabs.remove_child(c)
		c.queue_free()
	_cat_buttons.clear()
	for cname in _tab_list():
		var tb := Button.new()
		tb.text = cname
		tb.toggle_mode = true
		tb.add_theme_font_size_override("font_size", 10)
		tb.pressed.connect(func(): _cat = cname; _view = ""; _refresh())
		_tabs.add_child(tb)
		_cat_buttons[cname] = tb


## La colonne de droite : l'atelier ouvert (ou l'artisanat de poche), ou une fiche « que faire avec » /
## « comment l'obtenir ».
func _refresh_crafting() -> void:
	# un onglet propre à un autre atelier (ouvert par un raccourci) : on passe à cet atelier
	if not _cat in _tab_list():
		var st := Workshops.station_for_tab(_cat)
		if _cat in Workshops.tabs_for(st):
			_mode = st
	if not _cat in _tab_list():
		_cat = _tab_list()[0]
	_rebuild_tabs()
	var near := player.is_near_workbench() or _mode == "etabli"
	_stations = player.nearby_stations()
	if _mode != "" and not _stations.has(_mode):
		_stations.append(_mode)
	var title := ("Atelier : " + Workshops.station_name(_mode)) if _mode != "" else "Artisanat de poche"
	if _craft_title:
		var labels := [_craft_title] if _craft_title is Label else _craft_title.find_children("*", "Label", true, false)
		if not labels.is_empty():
			(labels[0] as Label).text = title
	if _mode != "":
		_bench.text = str(Workshops.STATIONS[_mode][2]) if Workshops.STATIONS.has(_mode) else ""
		_bench.add_theme_color_override("font_color", C_OK)
	else:
		_bench.text = KeyBindings.fmt("Sur toi, l'essentiel. Le reste se fabrique aux ateliers : {interact} devant un établi, une enclume, un four, une table du tailleur...")
		_bench.add_theme_color_override("font_color", C_DIM)
	for cn in _cat_buttons:
		_cat_buttons[cn].set_pressed_no_signal(cn == _cat and _view == "")
	_srow.visible = _cat == "Carnet" and _view == ""
	for c in _recipes.get_children():
		_recipes.remove_child(c)
		c.queue_free()
	match _view:
		"uses":
			_uses_rows(near)
			return
		"source":
			_source_rows()
			return
	match _cat:
		"Carnet":
			_carnet_rows(near)
		"Forge":
			_forge_rows()
		"Armures":
			_armor_rows(near)
		"Construction":
			_shape_rows(near)
		"Armurerie":
			_armory_rows(near)
		"Enchantement":
			_enchant_rows()
		"Métiers":
			_crafts_rows()
		_:
			var all: Array = Workshops.recipes_at(_mode).filter(func(r): return r.category == _cat)
			var list := all.filter(func(r): return Workshops.is_known(player, r))
			list.sort_custom(func(a, b): return int(_ok(a, near)) > int(_ok(b, near)))
			for r: RecipeData in _filter_ok(list, near):
				_recipes.add_child(_recipe_row(r, near))
			_unknown_note(all.size() - list.size())


## Recette faisable ici et maintenant (ingrédients, atelier, niveau de métier).
func _ok(r: RecipeData, near: bool) -> bool:
	return _here(r) and r.can_craft(player.inventory, near, _stations) and Crafts.level(player, Crafts.craft_of_recipe(r)) >= Crafts.recipe_level(r)


## La recette se fait-elle là où l'on est (l'atelier ouvert, ou sur soi) ?
func _here(r: RecipeData) -> bool:
	var st := Workshops.station_of(r)
	return st == "" or Workshops.serves(_mode, st)


func _unknown_note(n: int) -> void:
	if n <= 0:
		return
	var l := _label("%d recette%s encore inconnue%s : ramasse de nouveaux matériaux pour les découvrir." % [n, "s" if n > 1 else "", "s" if n > 1 else ""], 9, C_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(300, 0)
	_recipes.add_child(l)


func _back_button() -> Button:
	var b := Button.new()
	b.text = "← Retour"
	b.add_theme_font_size_override("font_size", 10)
	b.pressed.connect(func():
		_view = _back_view
		_back_view = ""
		_refresh())
	return b


## Clic droit sur un objet du sac : tout ce qu'on peut en faire (recettes connues, et à quel atelier).
func show_uses(item: ItemData) -> void:
	_back_view = ""
	_view = "uses"
	_view_item = item
	_refresh()


## « Comment obtenir cet objet ? » (ingrédient cliqué dans une recette)
func show_source(item: ItemData) -> void:
	_back_view = _view if _view != "source" else ""
	_view = "source"
	_view_item = item
	_refresh()


func _uses_rows(near: bool) -> void:
	var it := _view_item
	_recipes.add_child(_back_button())
	_recipes.add_child(MenuKit.heading("Avec %s, tu peux fabriquer :" % it.display_name, 12))
	var list := Workshops.uses_of(player, it)
	if list.is_empty():
		_recipes.add_child(_label("Rien pour l'instant (aucune recette connue ne l'utilise).", 10, C_DIM))
	list.sort_custom(func(a, b): return int(_ok(a, near)) > int(_ok(b, near)))
	for r: RecipeData in list.slice(0, 40):
		_recipes.add_child(_recipe_row(r, near, true))
	if list.size() > 40:
		_recipes.add_child(_label("... et %d autres." % (list.size() - 40), 9, C_DIM))
	var how := Button.new()
	how.text = "Comment obtenir %s ?" % it.display_name
	how.add_theme_font_size_override("font_size", 10)
	how.pressed.connect(show_source.bind(it))
	_recipes.add_child(how)


func _source_rows() -> void:
	var it := _view_item
	_recipes.add_child(_back_button())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_icon_box(it, 40))
	row.add_child(MenuKit.heading("Obtenir : %s" % it.display_name, 12))
	_recipes.add_child(row)
	_recipes.add_child(_label("Tu en as %d." % player.inventory.count(it), 10, C_DIM))
	for line in Workshops.sources_of(it):
		var l := _label("• " + str(line), 10, C_TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(300, 0)
		_recipes.add_child(l)
	if Items.recipes.any(func(r): return r.result == it):
		var pinb := Button.new()
		pinb.text = "📌 Désépingler" if player.pinned.has(it.id) else "📌 Épingler (liste de courses à l'écran)"
		pinb.add_theme_font_size_override("font_size", 10)
		pinb.pressed.connect(func(): player.toggle_pin(it.id))
		_recipes.add_child(pinb)


## Le carnet : toutes les recettes découvertes, de tous les ateliers (avec la recherche).
func _carnet_rows(near: bool) -> void:
	var visible_r: Array = Items.recipes.filter(func(r): return r.result and not r.result.has_meta("hidden"))
	var known := visible_r.filter(func(r): return Workshops.is_known(player, r))
	_recipes.add_child(_label("Carnet : %d recettes découvertes sur %d. Ramasse de nouveaux matériaux pour en découvrir d'autres." % [known.size(), visible_r.size()], 9, C_DIM))
	var words := _plain(_search.text.strip_edges()).split(" ", false) if _search else PackedStringArray()
	var found := known.filter(func(r):
		var n := _plain(r.result.display_name)
		for w in words:
			if not n.contains(w):
				return false
		return true)
	found = _filter_ok(found, near)
	found.sort_custom(func(a, b): return int(_ok(a, near)) > int(_ok(b, near)))
	if words.is_empty():
		_recipes.add_child(_label("Tape un nom dans la recherche, ou fais un clic droit sur un objet du sac.", 10, C_DIM))
	for r: RecipeData in found.slice(0, 50):
		_recipes.add_child(_recipe_row(r, near, true))
	if found.size() > 50:
		_recipes.add_child(_label("... %d autres : précise la recherche." % (found.size() - 50), 9, C_DIM))


## Construction : on choisit une forme (bloc, dalle, escalier...), puis une matière, puis la variante.
func _shape_rows(near: bool) -> void:
	var all: Array = Workshops.recipes_at(_mode).filter(func(r): return r.category == "Construction")
	var known: Array = all.filter(func(r): return Workshops.is_known(player, r))
	var shapes := []
	for sh in Workshops.SHAPES:
		if known.any(func(r): return Workshops.shape_of(r.result) == sh[0]):
			shapes.append(sh)
	if shapes.is_empty():
		_recipes.add_child(_label("Aucun bloc connu ici pour l'instant.", 10, C_DIM))
		_unknown_note(all.size())
		return
	if not shapes.any(func(sh): return sh[0] == _shape):
		_shape = shapes[0][0]
		_mat_id = ""
	_recipes.add_child(_label("1. La forme", 10, Color("f2c86a")))
	var srow := HFlowContainer.new()
	srow.add_theme_constant_override("h_separation", 3)
	srow.add_theme_constant_override("v_separation", 3)
	srow.custom_minimum_size.x = 310
	for sh in shapes:
		var b := Button.new()
		b.text = sh[1]
		b.toggle_mode = true
		b.button_pressed = sh[0] == _shape
		b.add_theme_font_size_override("font_size", 10)
		b.pressed.connect(func(): _shape = sh[0]; _mat_id = ""; _refresh())
		srow.add_child(b)
	_recipes.add_child(srow)
	var of_shape := known.filter(func(r): return Workshops.shape_of(r.result) == _shape)
	var mats := {}
	for r in of_shape:
		var m := Workshops.material_of(r)
		if m and not mats.has(m.id):
			mats[m.id] = m
	if not mats.has(_mat_id):
		# de préférence une matière qu'on a dans le sac
		_mat_id = ""
		for mid in mats:
			if player.inventory.count(mats[mid]) > 0:
				_mat_id = mid
				break
		if _mat_id == "" and not mats.is_empty():
			_mat_id = mats.keys()[0]
	_recipes.add_child(_label("2. La matière", 10, Color("f2c86a")))
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	for mid in mats:
		var m: ItemData = mats[mid]
		var b := Button.new()
		b.custom_minimum_size = Vector2(36, 36)
		b.tooltip_text = "%s (tu en as %d)" % [m.display_name, player.inventory.count(m)]
		b.toggle_mode = true
		b.button_pressed = mid == _mat_id
		var box := _icon_box(m, 32)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.position = Vector2(2, 2)
		if player.inventory.count(m) == 0:
			box.modulate = Color(1, 1, 1, 0.4)
		b.add_child(box)
		b.pressed.connect(func(): _mat_id = mid; _refresh())
		grid.add_child(b)
	_recipes.add_child(grid)
	if _mat_id == "":
		return
	_recipes.add_child(_label("3. Le bloc (%s)" % (mats[_mat_id] as ItemData).display_name, 10, Color("f2c86a")))
	var list := of_shape.filter(func(r):
		var m := Workshops.material_of(r)
		return m and m.id == _mat_id)
	for r: RecipeData in _filter_ok(list, near):
		_recipes.add_child(_recipe_row(r, near))
	_unknown_note(all.size() - known.size())


## Poste de travail d'un habitant (affiché quand on ouvre l'équipement d'un habitant).
func _refresh_job() -> void:
	for c in _job_box.get_children():
		c.queue_free()
	if target == player or not target.has_method("is_at_work"):
		return
	var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
	if k == null:
		return
	# carte d'identité : classe, niveau, humeur
	var idc := MenuKit.card_box(false, 6.0, 2)
	var iv: VBoxContainer = idc.get_child(0)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 4)
	var cd = Villager.class_data(str(target.get("fight_class")))
	if cd:
		chips.add_child(MenuKit.chip(cd.display_name, cd.color))
	chips.add_child(MenuKit.chip("Nv %d" % int(target.get("level")), MenuKit.C_GOLD))
	var hap: float = float(target.get("happiness"))
	chips.add_child(MenuKit.chip(VillageNeeds.mood_name(hap), VillageNeeds.mood_color(hap)))
	iv.add_child(chips)
	var mood := HBoxContainer.new()
	mood.add_theme_constant_override("separation", 4)
	mood.add_child(MenuKit.icon("heart", 12))
	mood.add_child(MenuKit.gauge(hap / 100.0, VillageNeeds.mood_color(hap), 200, 7))
	iv.add_child(mood)
	_job_box.add_child(idc)
	_evolution_box()
	# compagnon d'expédition
	var n_comp := get_tree().get_nodes_in_group("villagers").filter(func(v): return v.get("companion")).size()
	var comp := CheckButton.new()
	var max_comp: int = Villager.max_companions(get_tree())
	comp.text = "Compagnon (%d / %d)" % [n_comp, max_comp]
	comp.tooltip_text = "Il te suit partout, combat avec toi et progresse avec toi."
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
		_job_box.add_child(_label("Il progresse avec toi.", 9, C_DIM))
		return
	# poste de travail : des cartes à cliquer
	_job_box.add_child(MenuKit.icon_label("house", "Poste de travail", 11, Color("f2c86a")))
	var cur = target.get("work_room")
	var rooms := k.workplaces()
	if rooms.is_empty():
		var l := _label("Construis une pièce avec des postes (forge, boulangerie...) pour lui donner un métier.", 9, C_DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(230, 0)
		_job_box.add_child(l)
		return
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(240, 96)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	sc.add_child(list)
	_job_box.add_child(sc)
	var entries := [null] + rooms
	for r in entries:
		var is_cur: bool = (r == null and cur == null) or (r != null and r == cur)
		var b := Button.new()
		b.custom_minimum_size = Vector2(228, 30)
		b.add_theme_stylebox_override("normal", MenuKit.style(Color(0.25, 0.32, 0.15, 0.95), MenuKit.C_OK, 2, 3, 3) if is_cur else MenuKit.card(false, 3.0))
		b.add_theme_stylebox_override("hover", UiTheme.box("card_hover", 6, Vector4(3, 2, 3, 2)))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 5)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 5
		h.offset_right = -5
		b.add_child(h)
		var title := "Aucun (il se promène)"
		var info := ""
		var full := false
		if r != null:
			var t: RoomTypeData = r.type
			var w := k.workers_of(r).size()
			full = w >= t.job_slots and not is_cur
			title = "%s · %s" % [t.job_name, t.display_name]
			var a := Kingdom.affinity(target, t.job_id)
			info = "%d/%d  %s" % [w, t.job_slots, "★".repeat(clampi(roundi((a - 0.5) * 4.0), 1, 5))]
			var dot := ColorRect.new()
			dot.color = t.color
			dot.custom_minimum_size = Vector2(8, 8)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			h.add_child(dot)
		var tl := MenuKit.label(title, 10, MenuKit.C_GOLD if is_cur else (C_DIM if full else C_TEXT))
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tl.clip_text = true
		tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(tl)
		if info != "":
			var il := MenuKit.label(info, 9, MenuKit.C_BAD if full else Color("e8b84a"))
			il.mouse_filter = Control.MOUSE_FILTER_IGNORE
			il.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(il)
		b.disabled = full
		b.tooltip_text = "Poste complet." if full else ("Poste actuel." if is_cur else "Clique pour l'affecter ici. ★ : son talent pour ce métier.")
		var room = r
		b.pressed.connect(func():
			if not k.assign(target, room):
				player.notify.emit("Plus de place à ce poste.")
			_refresh())
		list.add_child(b)


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


func _recipe_row(r: RecipeData, near: bool, show_station := false) -> Control:
	var craft := Crafts.craft_of_recipe(r)
	var need_lv := Crafts.recipe_level(r)
	var lv_ok := Crafts.level(player, craft) >= need_lv
	var here := _here(r)
	var ok := here and r.can_craft(player.inventory, near, _stations) and lv_ok
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
		# chaque ingrédient est un lien : « comment l'obtenir ? »
		parts.append("[url=%s][color=#%s]%d %s (%d)[/color][/url]" % [r.ingredients[i].id, (C_OK if have >= need else C_BAD).to_html(false), need, r.ingredients[i].display_name, have])
	var st := Workshops.station_of(r)
	if st != "" and (show_station or not here):
		parts.append("[color=#%s]atelier : %s[/color]" % [(C_OK if here else Color("e8b84a")).to_html(false), Workshops.station_name(st).to_lower()])
	if need_lv > 1:
		parts.append("[color=#%s]%s niv. %d[/color]" % [(C_OK if lv_ok else C_BAD).to_html(false), Crafts.CRAFTS[craft].name, need_lv])
	var ing := RichTextLabel.new()
	ing.bbcode_enabled = true
	ing.fit_content = true
	ing.scroll_active = false
	ing.text = ", ".join(parts)
	ing.add_theme_font_size_override("normal_font_size", 9)
	ing.custom_minimum_size = Vector2(200, 0)
	ing.meta_underlined = false
	ing.tooltip_text = "Clique sur un ingrédient : comment l'obtenir ?"
	ing.meta_clicked.connect(func(meta):
		var src := Items.get_item(str(meta)) as ItemData
		if src:
			show_source(src))
	txt.add_child(ing)
	row.add_child(txt)
	var pin := Button.new()
	var pinned: bool = player.pinned.has(r.result.id)
	pin.text = "📌"
	pin.flat = true
	pin.tooltip_text = "Désépingler" if pinned else "Épingler : sa liste de courses s'affiche à l'écran"
	pin.add_theme_font_size_override("font_size", 12)
	pin.modulate = Color.WHITE if pinned else Color(1, 1, 1, 0.35)
	pin.pressed.connect(func(): player.toggle_pin(r.result.id))
	row.add_child(pin)
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
	var fits := not CraftGrid.pattern(r, CraftGrid.side_for(_mode)).is_empty()
	b.text = ("Placer" if fits else "Fabriquer") if here else Workshops.station_name(Workshops.station_of(r))
	b.tooltip_text = ("Pose la recette dans la grille (Maj+clic : de quoi la fabriquer le plus de fois possible)" if fits else "") \
		if here else "Se fabrique à l'atelier : %s" % Workshops.station_name(Workshops.station_of(r))
	b.disabled = not ok
	b.add_theme_font_size_override("font_size", 9)
	b.pressed.connect(func():
		if fits:
			grid_fill(r, Input.is_key_pressed(KEY_SHIFT))
		else:
			_craft(r))
	row.add_child(b)
	panel.mouse_entered.connect(_show_info.bind(r.result))
	return panel


func _show_info(item: ItemData) -> void:
	_info_icon.texture = Items.get_icon(item)
	_info_name.text = "%s  ·  %s" % [item.display_name, item.slot_name()]
	_info_name.add_theme_color_override("font_color", item.rarity_color())
	var st := item.stats_text()
	_info_text.text = (st + "\n" if st != "" else "") + KeyBindings.fmt(item.description) + ("\nDeux mains." if item.two_handed else "") + _compare_text(item)
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
	if not _here(r):
		return
	var sts := player.nearby_stations()
	if _mode != "":
		sts.append(_mode)
	if r.craft(player.inventory, player.is_near_workbench() or _mode == "etabli", sts):
		var extra := Crafts.on_crafted(player, r)
		player.notify.emit("Fabriqué : %s%s" % [r.result.display_name, ("  ·  " + extra) if extra != "" else ""])
		player.crafted.emit(r.result.id)
		Sound.ui("craft")
	_refresh()


# ---------------------------------------------------------------- grille d'artisanat (façon Minecraft)

## Taille de la grille selon l'atelier ouvert (2×2 sur soi, 3×3 à un atelier).
func _ensure_grid() -> void:
	var side := CraftGrid.side_for(_mode)
	if side == _grid_side and _grid.size() == side * side:
		return
	return_grid()
	_grid_side = side
	_grid.resize(side * side)
	_grid.fill(null)


## Rend au sac tout ce qui est dans la grille.
func return_grid() -> void:
	if player == null:
		return
	for i in _grid.size():
		var g = _grid[i]
		if g != null:
			_grid[i] = null
			player.inventory.add(g.item, g.count)


## Ce qu'il y a dans la grille (la sauvegarde le compte avec le sac).
func grid_items() -> Array:
	return _grid.filter(func(g): return g != null)


## Pose `count` objets du sac dans une case (ce qui y était d'autre retourne au sac).
func grid_put(slot: int, item: ItemData, count: int) -> void:
	_ensure_grid()
	if slot < 0 or slot >= _grid.size():
		return
	var g = _grid[slot]
	if g != null and g.item != item:
		_grid[slot] = null
		player.inventory.add(g.item, g.count)
		g = null
	var room: int = item.stack_size() - (g.count if g != null else 0)
	count = mini(mini(count, room), player.inventory.count(item))
	if count <= 0:
		return
	_batch = true
	player.inventory.remove(item, count)
	_batch = false
	if g == null:
		_grid[slot] = {"item": item, "count": count}
	else:
		g.count += count
	Sound.ui("ui_click")
	_refresh()


## Maj+clic dans le sac : la pile va dans la case qui a déjà cet objet, sinon dans la première case libre.
func grid_quick_add(item: ItemData, count: int) -> void:
	_ensure_grid()
	var slot := -1
	for i in _grid.size():
		if _grid[i] != null and _grid[i].item == item and _grid[i].count < item.stack_size():
			slot = i
			break
	if slot < 0:
		slot = _grid.find(null)
	if slot >= 0:
		grid_put(slot, item, count)


## Rend au sac une case de la grille (`n` objets, ou tout).
func grid_take(slot: int, n := -1) -> void:
	if slot < 0 or slot >= _grid.size() or _grid[slot] == null:
		return
	var g = _grid[slot]
	var k: int = g.count if n < 0 else mini(n, g.count)
	g.count -= k
	if g.count <= 0:
		_grid[slot] = null
	player.inventory.add(g.item, k)
	_refresh()


## Le livre de recettes : pose la recette dans la grille (comme le livre de Minecraft). `max` : de quoi la
## fabriquer le plus de fois possible.
func grid_fill(r: RecipeData, max := false) -> void:
	_ensure_grid()
	_batch = true
	return_grid()
	var pat := CraftGrid.pattern(r, _grid_side)
	var times := 1
	if max:
		times = 1 << 30
		for i in r.ingredients.size():
			times = mini(times, player.inventory.count(r.ingredients[i]) / maxi(1, r.amount_of(i)))
		for c in pat:
			times = mini(times, (c.item as ItemData).stack_size() / int(c.qty))
		times = maxi(times, 1)
	for c in pat:
		var k := mini(int(c.qty) * times, player.inventory.count(c.item))
		if k > 0:
			player.inventory.remove(c.item, k)
			_grid[c.slot] = {"item": c.item, "count": k}
	_batch = false
	_grid_pref = r
	Sound.ui("ui_click")
	_refresh()


## La recette que fait la grille (null : aucune), parmi celles qui ont cette disposition.
func grid_recipe() -> RecipeData:
	var m := CraftGrid.matches(_grid, _mode)
	if m.is_empty():
		return null
	if _grid_pref and m.has(_grid_pref):
		return _grid_pref
	return m[posmod(_grid_pick, m.size())]


## Fabrique `n` fois la recette de la grille (Maj+clic : autant que possible).
func grid_craft(n := 1) -> int:
	var r := grid_recipe()
	if r == null or Crafts.level(player, Crafts.craft_of_recipe(r)) < Crafts.recipe_level(r):
		return 0
	var made := 0
	var extra := ""
	_batch = true
	for k in n:
		if not CraftGrid.consume(_grid, r, _grid_side):
			break
		player.inventory.add(r.result, r.result_count)
		var x := Crafts.on_crafted(player, r)
		if x != "":
			extra = x
		player.crafted.emit(r.result.id)
		made += 1
	_batch = false
	if made > 0:
		player.notify.emit("Fabriqué : %s ×%d%s" % [r.result.display_name, made * r.result_count, ("  ·  " + extra) if extra != "" else ""])
		Sound.ui("craft")
	_refresh()
	return made


func _on_result_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var r := grid_recipe()
		if r:
			grid_craft(CraftGrid.times(_grid, r, _grid_side) if ev.shift_pressed else 1)


func _refresh_grid() -> void:
	_ensure_grid()
	for c in _grid_box.get_children():
		_grid_box.remove_child(c)
		c.queue_free()
	_grid_box.columns = _grid_side
	var empty := _grid.all(func(g): return g == null)
	# grille vide : la dernière recette posée s'y dessine en fantôme (pour la refaire)
	var ghost := {}
	if empty and _grid_pref:
		for c in CraftGrid.pattern(_grid_pref, _grid_side):
			ghost[c.slot] = c
	var cell_size := 46.0 if _grid_side == 3 else 54.0
	for i in _grid.size():
		var g = _grid[i]
		var item: ItemData = g.item if g != null else (ghost[i].item if ghost.has(i) else null)
		var cell := _icon_box(item, cell_size)
		if g == null and ghost.has(i):
			cell.modulate = Color(1, 1, 1, 0.3)
		var n := int(g.count) if g != null else (int(ghost[i].qty) if ghost.has(i) else 0)
		if n > 1:
			var l := _label("×%d" % n, 9)
			l.add_theme_color_override("font_outline_color", Color.BLACK)
			l.add_theme_constant_override("outline_size", 3)
			l.position = Vector2(cell_size - 28, cell_size - 17)
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(l)
		cell.tooltip_text = ("%s ×%d · clic droit : en retirer un · Maj+clic : tout retirer" % [g.item.display_name, g.count]) if g != null \
			else "Glisse un objet du sac ici (Ctrl : un seul), ou Maj+clic sur un objet du sac"
		if g != null:
			cell.mouse_entered.connect(_show_info.bind(g.item))
		var slot := i
		cell.set_drag_forwarding(
			func(_pos):
				if _grid[slot] == null:
					return null
				var prev := _icon_box(_grid[slot].item, 40)
				prev.modulate.a = 0.85
				cell.set_drag_preview(prev)
				return {"grid_from": slot},
			func(_pos, data): return data is Dictionary and (data.has("bag_item") or data.has("grid_from")),
			func(_pos, data):
				if data.has("bag_item"):
					grid_put(slot, data.bag_item, 1 if Input.is_key_pressed(KEY_CTRL) else int(data.count))
				else:
					_grid_move(int(data.grid_from), slot))
		cell.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed:
				if ev.button_index == MOUSE_BUTTON_RIGHT:
					grid_take(slot, 1)
				elif ev.button_index == MOUSE_BUTTON_LEFT and ev.shift_pressed:
					grid_take(slot))
		_grid_box.add_child(cell)
	# le résultat
	for c in _grid_result.get_children():
		c.queue_free()
	var r := grid_recipe()
	var m := CraftGrid.matches(_grid, _mode)
	var t := CraftGrid.times(_grid, r, _grid_side) if r else 0
	var lv_ok := r == null or Crafts.level(player, Crafts.craft_of_recipe(r)) >= Crafts.recipe_level(r)
	_grid_result.add_theme_stylebox_override("panel", UiTheme.box("slot", 8, Vector4(3, 3, 3, 3), Color("ffe08a") if r and t > 0 and lv_ok else Color.WHITE))
	if r:
		var ic := _icon_box(r.result, 50)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if t == 0 or not lv_ok:
			ic.modulate = Color(1, 1, 1, 0.4)
		_grid_result.add_child(ic)
		if r.result_count > 1:
			var l := _label("×%d" % r.result_count, 10)
			l.add_theme_color_override("font_outline_color", Color.BLACK)
			l.add_theme_constant_override("outline_size", 3)
			l.position = Vector2(28, 36)
			ic.add_child(l)
	var txt := ""
	if r == null:
		txt = "[color=#%s]%s[/color]" % [C_DIM.to_html(false), "Glisse des objets du sac dans la grille (ou Maj+clic dessus), ou choisis une recette plus bas : « Placer »." if empty
			else "Aucune recette avec ces objets."]
	else:
		txt = "[b]%s[/b]" % r.result.display_name
		if not lv_ok:
			txt += "\n[color=#%s]%s niv. %d requis[/color]" % [C_BAD.to_html(false), Crafts.CRAFTS[Crafts.craft_of_recipe(r)].name, Crafts.recipe_level(r)]
		elif t > 0:
			txt += "\n[color=#%s]Clic : fabriquer · Maj+clic : tout (×%d → %d)[/color]" % [C_OK.to_html(false), t, t * r.result_count]
		else:
			txt += "\n[color=#%s]Il manque des objets dans certaines cases.[/color]" % C_BAD.to_html(false)
		if CraftGrid.pattern(r, _grid_side).any(func(c): return int(c.qty) > 1):
			txt += "\n[color=#%s]Plusieurs objets par case (chiffre de la case).[/color]" % C_DIM.to_html(false)
		if m.size() > 1:
			txt += "\n[url=prev]◀[/url] %d / %d [url=next]▶[/url]  autre résultat" % [m.find(r) + 1, m.size()]
	_grid_note.text = txt


## Glisser une case de la grille sur une autre : les deux échangent leur contenu (ou s'ajoutent).
func _grid_move(from: int, to: int) -> void:
	if from == to or _grid[from] == null:
		return
	var a = _grid[from]
	var b = _grid[to]
	if b != null and b.item == a.item:
		var k: int = mini(a.count, a.item.stack_size() - b.count)
		b.count += k
		a.count -= k
		_grid[from] = a if a.count > 0 else null
	else:
		_grid[to] = a
		_grid[from] = b
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
	# les matériaux travaillés à cet atelier (bois, os et pierre à l'établi, les métaux à l'enclume)
	var mats := []
	for i in nm:
		var rid := Arsenal.make_id(Arsenal.TYPE_ORDER[0], Arsenal.MATERIALS[i].id, 0)
		for r: RecipeData in Items.recipes:
			if r.result and r.result.id == rid:
				if Workshops.station_of(r) == _mode or _mode == "":
					mats.append(i)
				break
	if mats.is_empty():
		mats = range(nm)
	if not mats.has(_arm_mat):
		_arm_mat = mats[0]
	var type: String = Arsenal.TYPE_ORDER[_arm_type]
	var m: Dictionary = Arsenal.MATERIALS[_arm_mat]
	_recipes.add_child(_label("Arsenal : %d armes (%d types × %d matériaux × 4 designs)" % [nt * nm * 4, nt, nm], 9, C_DIM))
	_recipes.add_child(_stepper("Type : %s (%d/%d)" % [Arsenal.TYPES[type].names[0], _arm_type + 1, nt],
		func(): _arm_type = (_arm_type + nt - 1) % nt, func(): _arm_type = (_arm_type + 1) % nt))
	var mi := mats.find(_arm_mat)
	_recipes.add_child(_stepper("Matériau : %s" % str(m.suffix).trim_prefix("en ").trim_prefix("d'").capitalize(),
		func(): _arm_mat = mats[(mi + mats.size() - 1) % mats.size()], func(): _arm_mat = mats[(mi + 1) % mats.size()]))
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
	_mode = Workshops.station_for_tab(tab)
	_view = ""
	_cat = tab
	_open(who)


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
	return list.filter(func(r): return _ok(r, near))


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
