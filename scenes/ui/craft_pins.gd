class_name CraftPins
extends PanelContainer
## Objets épinglés depuis l'artisanat : leur liste de courses, à gauche de l'écran (« Bois 2/4 · Fer 1/2 »).
## Quand tout est réuni, elle dit où aller le fabriquer (« Prêt : enclume, 23 m au nord »).

var player: Player
var _box: VBoxContainer
var _tick := 0.0


func _ready() -> void:
	add_to_group("craft_pins")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UiTheme.small_frame(8))
	modulate.a = 0.94
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 1)
	add_child(_box)
	if player:
		player.pins_changed.connect(refresh)
	refresh()


func _process(delta: float) -> void:
	# la distance à l'atelier change quand on marche
	_tick -= delta
	if _tick <= 0.0 and visible:
		_tick = 1.0
		refresh()


## Recette de l'objet épinglé (la première trouvée).
static func recipe_of(id: String) -> RecipeData:
	for r: RecipeData in Items.recipes:
		if r.result and r.result.id == id:
			return r
	return null


## Lignes de la liste de courses d'un objet : [texte, prêt ?].
static func shopping(p: Player, r: RecipeData) -> Array:
	var parts := []
	var ready := true
	for i in r.ingredients.size():
		var it: ItemData = r.ingredients[i]
		var have := p.inventory.count(it)
		var need := r.amount_of(i)
		if have < need:
			ready = false
		parts.append("[color=#%s]%s %d/%d[/color]" % ["8ad66a" if have >= need else "e0a070", it.display_name, mini(have, need), need])
	return [" · ".join(PackedStringArray(parts)), ready]


func refresh() -> void:
	if player == null or _box == null:
		return
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	var shown := 0
	for id in player.pinned:
		var r := recipe_of(str(id))
		if r == null:
			continue
		shown += 1
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 4)
		var ic := TextureRect.new()
		ic.texture = Items.get_icon(r.result)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(16, 16)
		head.add_child(ic)
		head.add_child(MenuKit.label("📌 " + r.result.display_name, 11, Color("fff2c8")))
		_box.add_child(head)
		var sh := shopping(player, r)
		var line := RichTextLabel.new()
		line.bbcode_enabled = true
		line.fit_content = true
		line.scroll_active = false
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.custom_minimum_size = Vector2(236, 0)
		line.add_theme_font_size_override("normal_font_size", 10)
		var st := Workshops.station_of(r)
		var where := ""
		if bool(sh[1]):
			if st == "":
				where = "\n[color=#8ad66a]Prêt : à fabriquer sur toi ({inventory})[/color]"
			else:
				var pos := Workshops.nearest_station_pos(player, st)
				if pos.is_empty():
					where = "\n[color=#e8b84a]Prêt : il te faut un(e) %s[/color]" % Workshops.station_name(st).to_lower()
				else:
					where = "\n[color=#8ad66a]Prêt : %s, %d m %s[/color]" % [Workshops.station_name(st).to_lower(), roundi(pos[1]),
						Workshops.direction_text(player.global_position, pos[0])]
		elif st != "":
			where = "\n[color=#a8997f]à l'atelier : %s[/color]" % Workshops.station_name(st).to_lower()
		line.text = str(sh[0]) + KeyBindings.fmt(where)
		_box.add_child(line)
	visible = shown > 0
	size = Vector2.ZERO
	reset_size()
	# à gauche, sous le guide (et sous l'aide-mémoire des touches s'il est ouvert)
	var y := 118.0
	for g in [get_tree().get_first_node_in_group("guide"), get_tree().get_first_node_in_group("keys_help")]:
		var c := g as Control
		if c and c.is_visible_in_tree() and c != self:
			y = maxf(y, c.global_position.y + c.size.y + 6.0)
	global_position = Vector2(10, y)
