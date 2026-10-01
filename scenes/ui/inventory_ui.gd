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
var _info_text: Label
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
	if event.is_action_pressed("inventory") or event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
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


func _make_theme() -> Theme:
	var th := Theme.new()
	var normal := _style(Color("6a4a26"), Color("d8a84a"), 1, 3)
	var hover := _style(Color("8a6230"), Color("f2c86a"), 1, 3)
	var pressed := _style(Color("4a3218"), Color("f2c86a"), 1, 3)
	var disabled := _style(Color("2a2220"), Color("4a3e34"), 1, 3)
	th.set_stylebox("normal", "Button", normal)
	th.set_stylebox("hover", "Button", hover)
	th.set_stylebox("pressed", "Button", pressed)
	th.set_stylebox("disabled", "Button", disabled)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", Color("fff2d0"))
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", Color("6a5e50"))
	return th


func _label(text: String, size := 11, color := C_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _column(title: String, width: float, parent: Control) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(C_PANEL, C_FRAME.darkened(0.3)))
	panel.custom_minimum_size = Vector2(width, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	box.add_child(_label(title, 13, Color("f2c86a")))
	return box


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var win := PanelContainer.new()
	win.theme = _make_theme()
	win.add_theme_stylebox_override("panel", _style(C_BG, C_FRAME, 3, 4))
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
	var info := PanelContainer.new()
	info.add_theme_stylebox_override("panel", _style(C_SLOT, C_FRAME.darkened(0.4), 1))
	info.custom_minimum_size = Vector2(0, 92)
	c2.add_child(info)
	var ib := VBoxContainer.new()
	info.add_child(ib)
	_info_name = _label("Survole un objet", 12)
	ib.add_child(_info_name)
	_info_text = _label("", 10, C_DIM)
	_info_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_text.custom_minimum_size = Vector2(270, 0)
	ib.add_child(_info_text)

	# 3. artisanat
	var c3 := _column("Artisanat", 330, cols)
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 2)
	tabs.add_theme_constant_override("v_separation", 2)
	tabs.custom_minimum_size.x = 320
	for cname in ["Outils", "Cuisine", "Équipement", "Construction", "Mobilier", "Matériaux", "Légendaire", "Forge"]:
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
	var border := item.rarity_color().darkened(0.35) if item else C_FRAME.darkened(0.5)
	var st := _style(C_SLOT, border, 2, 3)
	st.set_content_margin_all(2)
	frame.add_theme_stylebox_override("panel", st)
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
		_bag.add_child(btn)
	if player.inventory.entries.is_empty():
		_bag.add_child(_label("Sac vide", 10, C_DIM))

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
	if _cat == "Forge":
		_forge_rows()
		_refresh_job()
		return
	var list: Array = Items.recipes.filter(func(r): return r.category == _cat or (_cat == "Matériaux" and r.category == "Matériaux"))
	list.sort_custom(func(a, b): return int(a.can_craft(player.inventory, near, _stations)) > int(b.can_craft(player.inventory, near, _stations)))
	for r: RecipeData in list:
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
	comp.text = "Compagnon d'expédition (%d/2)" % n_comp
	comp.add_theme_font_size_override("font_size", 11)
	comp.button_pressed = target.get("companion")
	comp.disabled = not target.get("companion") and n_comp >= 2
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
	var ok := r.can_craft(player.inventory, near, _stations)
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
	var b := Button.new()
	b.text = "Fabriquer"
	b.disabled = not ok
	b.add_theme_font_size_override("font_size", 9)
	b.pressed.connect(_craft.bind(r))
	row.add_child(b)
	panel.mouse_entered.connect(_show_info.bind(r.result))
	return panel


func _show_info(item: ItemData) -> void:
	_info_name.text = "%s  ·  %s" % [item.display_name, item.slot_name()]
	_info_name.add_theme_color_override("font_color", item.rarity_color())
	var st := item.stats_text()
	_info_text.text = (st + "\n" if st != "" else "") + item.description + ("\nDeux mains." if item.two_handed else "")


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
	if r.craft(player.inventory, player.is_near_workbench(), player.nearby_stations()):
		player.notify.emit("Fabriqué : %s" % r.result.display_name)
		player.crafted.emit(r.result.id)
		Sound.ui("craft")
	_refresh()


func _who() -> String:
	return "Vous" if target == player else String(target.get("villager_name"))
