class_name ShopDialog
extends Control
## Boutique du marchand ambulant (E près de lui) : à gauche ce qu'il vend, à droite ce que tu peux lui vendre.
## Sert aussi aux marchands des capitales (open_city), avec leur propre stock (CityMerchant).

var player: Player
var target: Node
## Marchand de capitale en cours (sinon c'est le marchand ambulant).
var city: CityMerchant
var _box: VBoxContainer
var _msg: Label
var _buy_scroll := 0.0
var _sell_scroll := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box = MenuKit.panel(self, 880)


func _trade() -> Trade:
	return get_tree().get_first_node_in_group("trade") as Trade


## La boutique en cours : le marchand de capitale ou le marchand ambulant.
func _src():
	return city if city else _trade()


func open_city(m: CityMerchant, v: Node) -> void:
	if player == null or player.ui_open:
		return
	city = m
	open(v)


func open(v: Node) -> void:
	if player == null or player.ui_open:
		return
	if not (v is Townsfolk):
		city = null
	target = v
	get_parent().move_child(self, get_parent().get_child_count() - 1)
	Sound.ui("ui_open")
	show()
	player.ui_open = true
	get_tree().paused = true
	_buy_scroll = 0.0
	_sell_scroll = 0.0
	_refresh("")


func close() -> void:
	hide()
	get_tree().paused = false
	if player:
		player.ui_open = false


func _refresh(message: String, focus := "") -> void:
	for c in _box.get_children():
		c.queue_free()
	var tr = _src()
	if tr == null or not tr.is_here():
		close()
		return
	var sub: Label
	if city:
		city.reprice()
		_box.add_child(MenuKit.title("%s — %s" % [city.trade_name, city.seller_name], 20))
		var nat: Dictionary = Diplomacy.NATIONS.get(city.nation, {})
		var no := city.refusal()
		var market := city.market_note()
		sub = MenuKit.label("Marchand de %s (%s)%s%s" % [city.city_name, nat.get("name", ""),
			"  ·  " + no if no != "" else "  ·  prix selon tes relations avec sa nation", ("  ·  " + market) if market != "" else ""],
			11, MenuKit.C_BAD if no != "" else MenuKit.C_DIM)
	else:
		_box.add_child(MenuKit.title("Marchand ambulant — %s" % target.get("villager_name"), 20))
		sub = MenuKit.label("Venu de %s  ·  spécialité : %s  ·  repart le jour %d au matin%s" % [
			tr.origin, tr.specialty.to_lower(), tr.leave_day, "  ·  marché : meilleurs prix" if tr.has_market() else ""], 11, MenuKit.C_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(sub)
	var purse := MenuKit.label("Ta bourse : %d pièces d'or" % tr.gold(player), 15, MenuKit.C_GOLD)
	purse.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(purse)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	_box.add_child(cols)
	var focus_btn: Button = null
	# --- ce qu'il vend
	var left := VBoxContainer.new()
	cols.add_child(left)
	left.add_child(MenuKit.label("Il vend", 14, MenuKit.C_GOLD))
	var ls := _scroll(left)
	var lbox: VBoxContainer = ls.get_child(0)
	if tr.stock.is_empty():
		lbox.add_child(MenuKit.label("Tout est vendu !", 12, MenuKit.C_DIM))
	for s in tr.stock:
		var it := Items.get_item(s.id)
		if it == null:
			continue
		var afford: bool = tr.gold(player) >= int(s.price)
		var row := _row(it, "%s  ×%d" % [it.display_name, s.n], "%s · %d or" % [s.get("cat", ""), s.price], afford)
		var b := MenuKit.button("Acheter", 84, 11)
		b.custom_minimum_size.y = 28
		b.disabled = not afford
		b.pressed.connect(_do_buy.bind(s, 1, "b:" + s.id))
		row.add_child(b)
		if int(s.n) >= 5 and it.max_stack > 1:
			var b5 := MenuKit.button("×5", 44, 11)
			b5.custom_minimum_size.y = 28
			b5.disabled = tr.gold(player) < int(s.price) * 5
			b5.pressed.connect(_do_buy.bind(s, 5, "b:" + s.id))
			row.add_child(b5)
		else:
			row.add_child(_gap(44))
		lbox.add_child(row)
		if focus == "b:" + s.id and not b.disabled:
			focus_btn = b
	# --- ce qu'on peut lui vendre
	var right := VBoxContainer.new()
	cols.add_child(right)
	right.add_child(MenuKit.label("Tu vends", 14, MenuKit.C_GOLD))
	var rs := _scroll(right)
	var rbox: VBoxContainer = rs.get_child(0)
	var seen := {}
	for e in player.inventory.entries:
		var it := e.item as ItemData
		if it == null or seen.has(it.id):
			continue
		seen[it.id] = true
		var price: int = tr.sell_price(it)
		if price <= 0:
			continue
		var n := player.inventory.count(it)
		var drop := int(tr.sold_count.get(it.id, 0)) > 0
		var row := _row(it, "%s  ×%d" % [it.display_name, n], "%d or pièce%s" % [price, "  (il en a déjà : prix en baisse)" if drop else ""], true)
		var b := MenuKit.button("Vendre", 76, 11)
		b.custom_minimum_size.y = 28
		b.pressed.connect(_do_sell.bind(it, 1, "s:" + it.id))
		row.add_child(b)
		if n > 1:
			var ball := MenuKit.button("Tout", 52, 11)
			ball.custom_minimum_size.y = 28
			ball.pressed.connect(_do_sell.bind(it, n, "s:" + it.id))
			row.add_child(ball)
		else:
			row.add_child(_gap(52))
		rbox.add_child(row)
		if focus == "s:" + it.id:
			focus_btn = b
	if rbox.get_child_count() == 0:
		rbox.add_child(MenuKit.label("Rien qui l'intéresse dans ton sac.", 12, MenuKit.C_DIM))
	_msg = MenuKit.label(message, 12, MenuKit.C_BAD if message.begins_with("Pas") else MenuKit.C_OK)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_msg)
	var tip := MenuKit.label("Vendre beaucoup du même objet fait baisser son prix." + (" Chaque marchand de la ville a son métier : cherche les étals." if city else
		" Un marché (2 étals, un comptoir) le fait venir plus souvent, avec de meilleurs prix."), 10, MenuKit.C_DIM)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(840, 0)
	_box.add_child(tip)
	var close_b := MenuKit.button("Fermer (Échap)", 200, 13)
	close_b.pressed.connect(close)
	_box.add_child(close_b)
	# garder la position des listes après un achat ou une vente
	(func():
		ls.scroll_vertical = int(_buy_scroll)
		rs.scroll_vertical = int(_sell_scroll)).call_deferred()
	ls.get_v_scroll_bar().value_changed.connect(func(v): _buy_scroll = v)
	rs.get_v_scroll_bar().value_changed.connect(func(v): _sell_scroll = v)
	(focus_btn if focus_btn else close_b).grab_focus.call_deferred()


func _scroll(parent: Control) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(420, 300)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(sc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	return sc


func _gap(w: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, 0)
	return c


func _row(it: ItemData, name: String, detail: String, ok: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var icon := TextureRect.new()
	icon.texture = Items.get_icon(it)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(30, 30)
	row.add_child(icon)
	var txt := VBoxContainer.new()
	txt.add_theme_constant_override("separation", -3)
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.add_child(MenuKit.label(name, 12, it.rarity_color() if ok else it.rarity_color().darkened(0.4)))
	txt.add_child(MenuKit.label(detail, 10, MenuKit.C_DIM))
	row.add_child(txt)
	return row


func _do_buy(entry: Dictionary, n: int, focus: String) -> void:
	var tr = _src()
	if tr == null:
		return
	var it := Items.get_item(entry.id)
	var err: String = tr.buy(player, entry, n)
	_refresh(err if err != "" else "Acheté : %d %s." % [n, it.display_name], focus)


func _do_sell(it: ItemData, n: int, focus: String) -> void:
	var tr = _src()
	if tr == null:
		return
	var got: int = tr.sell(player, it, n)
	_refresh("Vendu : +%d pièces d'or." % got if got > 0 else "Le marchand n'en veut plus.", focus)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
