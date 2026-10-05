class_name RecruitDialog
extends Control
## Fenêtre de dialogue avec un voyageur ({interact} près de lui) : qui il est, ce qu'il sait faire,
## ce qu'il demande pour rejoindre le village. Il faut aussi un lit libre au village
## (population max = 8 + lits des maisons et dortoirs).

const C_BG := Color("241d1a")
const C_FRAME := Color("8a6a3a")
const C_TEXT := Color("f0e6d2")
const C_DIM := Color("a8997f")
const C_OK := Color("8ad66a")
const C_BAD := Color("e0705a")
const C_GOLD := Color("f2c86a")

var player: Player
var target: Villager
var _box: VBoxContainer
var _recruit_btn: Button
var _later_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.frame(16))
	MenuKit.animate_open(panel)
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(460, 0)
	panel.offset_left = -230
	panel.offset_right = 230
	panel.offset_top = -190
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	panel.add_child(_box)
	hide()


func _label(text: String, size := 12, color := C_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(428, 0)
	return l


func open(v: Villager) -> void:
	target = v
	player.ui_open = true
	get_parent().move_child(self, get_parent().get_child_count() - 1)
	show()
	_refresh()


func close() -> void:
	hide()
	target = null
	if player:
		player.ui_open = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact") or event.is_action_pressed("inventory"):
		close()
		get_viewport().set_input_as_handled()


## Population actuelle et maximale du village.
static func population(tree: SceneTree) -> Vector2i:
	var k := tree.get_first_node_in_group("kingdom") as Kingdom
	var n := tree.get_nodes_in_group("villagers").size()
	return Vector2i(n, k.population_cap() if k else 6)


func _can_pay() -> bool:
	for pair in target.recruit_offer.get("items", []):
		if player.inventory.count(pair[0]) < int(pair[1]):
			return false
	return true


func _refresh() -> void:
	for c in _box.get_children():
		c.queue_free()
	if target == null:
		return
	var v := target
	var prisoner := v.has_meta("prisoner")
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(MenuKit.portrait(MenuKit.villager_portrait_id(v), 76))
	var hv := VBoxContainer.new()
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	hv.add_theme_constant_override("separation", 4)
	hv.add_child(MenuKit.heading(v.villager_name, 18))
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 4)
	chips.add_child(MenuKit.chip(v.race.display_name if v.race else "?", C_DIM))
	var cd := Villager.class_data(str(v.get("fight_class")))
	if cd:
		chips.add_child(MenuKit.chip(cd.display_name, cd.color))
	chips.add_child(MenuKit.chip("Niveau %d" % v.level, C_GOLD))
	if prisoner:
		chips.add_child(MenuKit.chip("Prisonnier", C_BAD))
	hv.add_child(chips)
	# caractéristiques en icônes
	var s := v.total_stats()
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 10)
	for st in [["heart", s.max_health], ["sword", s.attack], ["shield", s.defense], ["magic", s.magic]]:
		stats.add_child(MenuKit.icon_label(st[0], str(st[1]), 12, C_TEXT))
	var w := v.weapon()
	stats.add_child(MenuKit.label(("· " + w.display_name) if w else "· sans arme", 10, C_DIM))
	hv.add_child(stats)
	head.add_child(hv)
	_box.add_child(head)
	# sa phrase, sur un parchemin
	var quote := PanelContainer.new()
	quote.add_theme_stylebox_override("panel", UiTheme.parchment(10))
	var ql := MenuKit.label("« %s »" % v.recruit_offer.get("text", "Je cherche un endroit où vivre."), 12, MenuKit.C_INK)
	ql.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ql.custom_minimum_size.x = 420
	quote.add_child(ql)
	_box.add_child(quote)
	# talents
	var tal := HFlowContainer.new()
	tal.add_theme_constant_override("h_separation", 4)
	tal.add_child(MenuKit.label("Talents :", 11, C_DIM))
	var keys := v.talents.keys()
	keys.sort_custom(func(a, b): return v.talents[a] > v.talents[b])
	for j in keys:
		tal.add_child(MenuKit.chip("%s %s" % [Villager.JOB_NAMES.get(j, j), "★".repeat(clampi(roundi(float(v.talents[j]) * 6.0), 1, 5))], C_GOLD))
	_box.add_child(tal)
	# ce qu'il demande
	var items: Array = v.recruit_offer.get("items", [])
	if items.is_empty():
		_box.add_child(MenuKit.icon_label("star", "Il te rejoint sans rien demander." if not prisoner else "Libéré, il te rejoint avec joie.", 12, C_OK))
	else:
		var ask := HBoxContainer.new()
		ask.add_theme_constant_override("separation", 6)
		ask.add_child(MenuKit.label("Il demande :", 12, C_TEXT))
		for pair in items:
			var have := player.inventory.count(pair[0])
			ask.add_child(MenuKit.item_badge(pair[0], int(pair[1]), 34))
			ask.add_child(MenuKit.label("%s\ntu en as %d" % [(pair[0] as ItemData).display_name, have], 10, C_OK if have >= int(pair[1]) else C_BAD))
		_box.add_child(ask)
	var pop := population(get_tree())
	var room := pop.x < pop.y
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 6)
	prow.add_child(MenuKit.icon("people", 16))
	prow.add_child(MenuKit.gauge(float(pop.x) / maxf(1.0, pop.y), C_OK if room else C_BAD, 120, 8))
	prow.add_child(MenuKit.label("Village %d / %d%s" % [pop.x, pop.y, "" if room else " : construis une maison ou un dortoir"], 11, C_OK if room else C_BAD))
	_box.add_child(prow)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_child(row)
	_recruit_btn = Button.new()
	_recruit_btn.text = "Recruter" if not prisoner else "Libérer et recruter"
	_recruit_btn.disabled = not (room and _can_pay())
	_recruit_btn.custom_minimum_size = Vector2(170, 34)
	_recruit_btn.pressed.connect(_recruit)
	row.add_child(_recruit_btn)
	_later_btn = Button.new()
	_later_btn.text = "Plus tard"
	_later_btn.custom_minimum_size = Vector2(120, 34)
	_later_btn.pressed.connect(close)
	row.add_child(_later_btn)
	(_recruit_btn if not _recruit_btn.disabled else _later_btn).grab_focus.call_deferred()


func _recruit() -> void:
	var v := target
	if v == null or not is_instance_valid(v):
		close()
		return
	var world := get_tree().get_first_node_in_group("world") as WorldGenerator
	# il faut un camp où l'accueillir : le drapeau du royaume
	if world and not world.has_home():
		player.notify.emit("Plante d'abord le drapeau du royaume : c'est là que tes habitants s'installeront.")
		close()
		return
	for pair in v.recruit_offer.get("items", []):
		player.inventory.remove(pair[0], int(pair[1]))
	if world:
		world.mark_recruited(v)
		v.join_village(world.home_center())
	VoxelBurst.spawn(player, player.global_position + Vector3(0, 1, 0), C_GOLD, 30, 4.0, 0.08, 0.8, "up", 4.0)
	player.feat.emit("%s te rejoint !" % v.villager_name, C_GOLD)
	player.notify.emit("%s part pour ton village. Donne-lui un poste ({interact} près de lui) ou emmène-le en expédition." % v.villager_name)
	close()
