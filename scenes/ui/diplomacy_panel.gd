class_name DiplomacyPanel
extends Control
## Panneau de la diplomatie (touche Y, ou bouton du panneau du royaume) : les nations voisines,
## leur relation avec le royaume, leurs demandes, les présents, les traités, la guerre et la paix.

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
	_box = MenuKit.panel(self, 880)
	_box.add_theme_constant_override("separation", 5)


func _dip() -> Diplomacy:
	return get_tree().get_first_node_in_group("diplomacy") as Diplomacy


func open() -> void:
	if player == null or player.ui_open or player.building or _dip() == null:
		return
	get_parent().move_child(self, get_parent().get_child_count() - 1)
	Sound.ui("ui_open")
	show()
	player.ui_open = true
	player.set_meta("seen_diplomacy", true)
	get_tree().paused = true
	_refresh()


func close() -> void:
	hide()
	get_tree().paused = false
	if player:
		player.ui_open = false


func _small(text: String, tip: String, disabled: bool, cb: Callable, width := 0.0) -> Button:
	var b := MenuKit.button(text, width, 11)
	b.custom_minimum_size.y = 26
	b.tooltip_text = tip
	b.disabled = disabled
	b.pressed.connect(func():
		cb.call()
		if visible:
			_refresh())
	return b


func _refresh() -> void:
	for c in _box.get_children():
		c.queue_free()
	var dip := _dip()
	var st := get_tree().get_first_node_in_group("story") as Story
	var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
	var nat := st.nation_name() if st else ""
	_box.add_child(MenuKit.title("Diplomatie", 20))
	var who := MenuKit.bold(nat if nat != "" else (k.title() if k else "Ton royaume"), 13, MenuKit.C_TEXT)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(who)
	# en-tête : or, alliés, ennemis, règles des traités
	var allies := 0
	var wars := 0
	for id in Diplomacy.NATIONS:
		if dip.has_treaty(id, "alliance"):
			allies += 1
		if dip.at_war(id):
			wars += 1
	var tiles := HBoxContainer.new()
	tiles.alignment = BoxContainer.ALIGNMENT_CENTER
	tiles.add_theme_constant_override("separation", 8)
	tiles.add_child(MenuKit.stat_tile("coin", str(player.inventory.count(Items.get_item("piece_or"))), "Pièces d'or", MenuKit.C_GOLD, -1.0, 150))
	tiles.add_child(MenuKit.stat_tile("shield", str(allies), "Alliances", MenuKit.C_OK, -1.0, 150))
	tiles.add_child(MenuKit.stat_tile("sword", str(wars), "Guerres", MenuKit.C_BAD if wars > 0 else MenuKit.C_TEXT, -1.0, 150))
	var rules := MenuKit.card_box(false, 9.0, 2)
	rules.custom_minimum_size.x = 330
	var rv: VBoxContainer = rules.get_child(0)
	rv.add_child(MenuKit.bold("Traités", 12, MenuKit.C_GOLD))
	rv.add_child(MenuKit.label("Paix dès 0 · Commerce dès +%d · Alliance dès +%d" % [roundi(Diplomacy.COMMERCE_MIN), roundi(Diplomacy.ALLIANCE_MIN)], 10, MenuKit.C_DIM))
	rv.add_child(MenuKit.label("Présents et demandes font monter la relation.", 10, MenuKit.C_DIM))
	tiles.add_child(rules)
	_box.add_child(tiles)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(850, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 5)
	list.custom_minimum_size.x = 836
	scroll.add_child(list)
	for id in Diplomacy.NATIONS:
		list.add_child(_row(dip, id))
	_box.add_child(scroll)
	_box.add_child(_world_news())
	var close_b := MenuKit.button("Fermer ({diplomacy})", 200, 13)
	close_b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_b.pressed.connect(close)
	_box.add_child(close_b)
	close_b.grab_focus.call_deferred()


## Le monde sans toi : guerres entre nations, événement de saison et dernières nouvelles (voir WorldPolitics).
func _world_news() -> Control:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", MenuKit.card(false, 6))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	pc.add_child(v)
	var pol := get_tree().get_first_node_in_group("world_politics") as WorldPolitics
	if pol == null:
		v.add_child(MenuKit.label("Le monde est calme.", 11, MenuKit.C_DIM))
		return pc
	var wars: Array = pol.wars_text()
	var head := "Le monde — " + ("guerres : " + " · ".join(wars) if not wars.is_empty() else "aucune guerre entre les nations")
	if not pol.event.is_empty():
		head += "  ·  " + WorldPolitics.EVENT_NAMES.get(pol.event.kind, "")
	v.add_child(MenuKit.heading(head, 12, MenuKit.C_GOLD))
	var last: Array = pol.news.slice(-2)
	last.reverse()
	for n in last:
		var l := MenuKit.label("Jour %d — %s" % [int(n[0]), n[1]], 10, MenuKit.C_DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	return pc


func _row(dip: Diplomacy, id: String) -> Control:
	var n: Dictionary = Diplomacy.NATIONS[id]
	var s: Dictionary = dip.states[id]
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", MenuKit.card(dip.annexed(id), 7))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	pc.add_child(row)
	var crest := TextureRect.new()
	crest.texture = UiTheme.tex("crest_" + id)
	crest.custom_minimum_size = Vector2(44, 50)
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crest.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	crest.tooltip_text = n.text
	row.add_child(crest)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	# ligne 1 : nom, attitude, peuple, relation, traités
	var h1 := HBoxContainer.new()
	h1.add_theme_constant_override("separation", 8)
	var name_l := MenuKit.heading(n.name, 14, n.color)
	name_l.custom_minimum_size.x = 190
	name_l.tooltip_text = n.text
	h1.add_child(name_l)
	var status := dip.status(id)
	h1.add_child(MenuKit.chip(status, Diplomacy.status_color(status)))
	var r := dip.rel(id)
	h1.add_child(MenuKit.center_gauge(r, Diplomacy.status_color(status), 150, 10))
	h1.add_child(MenuKit.bold("%+d" % roundi(r), 12, Diplomacy.status_color(status)))
	if dip.at_war(id):
		h1.add_child(MenuKit.chip("Armées repoussées %d / %d" % [int(s.wins), Diplomacy.WINS_TO_SURRENDER], MenuKit.C_BAD))
	elif dip.annexed(id):
		h1.add_child(MenuKit.chip("Impôts tous les %d j · colons tous les %d j" % [Diplomacy.TAX_EVERY, Diplomacy.SETTLER_EVERY], MenuKit.C_GOLD))
	else:
		for t in ["paix", "commerce", "alliance"]:
			if dip.has_treaty(id, t):
				h1.add_child(MenuKit.chip("✓ " + Diplomacy.TREATY_NAMES[t], MenuKit.C_OK))
	v.add_child(h1)
	# ligne 2 : peuple, goût, demande (icônes d'objets)
	var h2 := HBoxContainer.new()
	h2.add_theme_constant_override("separation", 6)
	var people := str(n.people)
	h2.add_child(MenuKit.label(people.left(1).to_upper() + people.substr(1), 10, MenuKit.C_DIM))
	var lk: Array = n.likes
	var rq: Array = s.request
	h2.add_child(MenuKit.label("  ·  Aime :", 10, MenuKit.C_DIM))
	h2.add_child(MenuKit.item_badge(Items.get_item(lk[0]), int(lk[1]), 26))
	if not rq.is_empty() and not dip.at_war(id) and not dip.annexed(id):
		h2.add_child(MenuKit.label("  ·  Demande :", 10, MenuKit.C_GOLD))
		h2.add_child(MenuKit.item_badge(Items.get_item(rq[0]), int(rq[1]), 26))
	v.add_child(h2)
	# ligne 3 : actions possibles (les traités pas encore accessibles sont montrés en pastilles)
	var h3 := HBoxContainer.new()
	h3.add_theme_constant_override("separation", 6)
	if dip.at_war(id):
		var why := dip.block(id, "siege")
		h3.add_child(_small("⚔ Assiéger la capitale", why if why != "" else "Mène l'assaut sur leur capitale.", why != "", func():
			close()
			dip.start_siege(id), 190))
		var whyp := dip.block(id, "peace")
		h3.add_child(_small("Acheter la paix (%d or)" % dip.peace_price(id), whyp, whyp != "", dip.act.bind(id, "peace"), 190))
	elif not dip.annexed(id):
		for a in [["gift", "Offrir %d or" % Diplomacy.GIFT_GOLD], ["like", "Offrir %d %s" % [int(lk[1]), Items.get_item(lk[0]).display_name]]]:
			var why := dip.block(id, a[0])
			h3.add_child(_small(a[1], why if why != "" else "La relation monte.", why != "", dip.act.bind(id, a[0]), 0))
		if not rq.is_empty():
			var whyr := dip.block(id, "request")
			h3.add_child(_small("Répondre à la demande", whyr if whyr != "" else "Grosse hausse de relation.", whyr != "", dip.act.bind(id, "request"), 0))
		for t in ["paix", "commerce", "alliance"]:
			if dip.has_treaty(id, t):
				continue
			var why := dip.block(id, t)
			if why == "":
				h3.add_child(_small("Signer : " + Diplomacy.TREATY_NAMES[t], "Signe le traité.", false, dip.act.bind(id, t), 0))
			else:
				var c := MenuKit.chip("🔒 " + Diplomacy.TREATY_NAMES[t], MenuKit.C_DIM)
				c.tooltip_text = why
				h3.add_child(c)
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h3.add_child(sp)
		var whyw := dip.block(id, "war")
		var wb := _small("Déclarer la guerre", whyw if whyw != "" else "Attention : la relation s'effondre et leurs armées attaqueront.", whyw != "", dip.act.bind(id, "war"), 0)
		wb.add_theme_color_override("font_color", MenuKit.C_BAD)
		h3.add_child(wb)
	if h3.get_child_count() > 0:
		v.add_child(h3)
	return pc
