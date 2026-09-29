extends CanvasLayer
## Interface de base : aide aux commandes, graine du monde, race jouée, messages.
## Touche R : changer de race pour tester les personnages.

@export var world: WorldGenerator
@export var player: Player
@export var races: Array[RaceData] = []
## Durée d'affichage d'un message (secondes).
@export var message_time: float = 3.0

@onready var info: Label = $Info
var _race_index := 0
var _messages: VBoxContainer
var _hp_fill: ColorRect
var _hp_lag: ColorRect
var _hp_text: Label
var _stats_text: Label
var _death: Control
var _death_label: Label
var _feat: Label
var _target_box: Control
var _target_name: Label
var _target_fill: ColorRect
var _slow_tint: ColorRect
var _target: Combatant
var _xp_fill: ColorRect
var _xp_text: Label
const HP_WIDTH := 220.0


func _ready() -> void:
	_messages = VBoxContainer.new()
	_messages.position = Vector2(10, 470)
	_messages.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_messages.alignment = BoxContainer.ALIGNMENT_END
	_messages.custom_minimum_size = Vector2(400, 0)
	_messages.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_messages.offset_left = 10
	_messages.offset_bottom = -10
	add_child(_messages)
	if world:
		world.world_generated.connect(func(_s): _refresh())
	_build_health_bar()
	_build_death_screen()
	_build_combat_ui()
	if player:
		player.feat.connect(show_feat)
		player.lock_changed.connect(func(t): _target = t)
		player.notify.connect(show_message)
		player.health.changed.connect(func(_c, _m): _update_health())
		player.defeated.connect(func(): _death.show())
		player.equipment.changed.connect(_update_health)
		player.xp_changed.connect(func(_x, _n, _l): _update_health())
	_refresh()
	_update_health()


func _build_health_bar() -> void:
	var box := Control.new()
	box.position = Vector2(10, 46)
	add_child(box)
	var frame := ColorRect.new()
	frame.color = Color(0.05, 0.04, 0.04, 0.85)
	frame.size = Vector2(HP_WIDTH + 4, 18)
	box.add_child(frame)
	_hp_lag = ColorRect.new()
	_hp_lag.color = Color(0.95, 0.85, 0.5)
	_hp_lag.position = Vector2(2, 2)
	_hp_lag.size = Vector2(HP_WIDTH, 14)
	box.add_child(_hp_lag)
	_hp_fill = ColorRect.new()
	_hp_fill.color = Color(0.82, 0.18, 0.14)
	_hp_fill.position = Vector2(2, 2)
	_hp_fill.size = Vector2(HP_WIDTH, 14)
	box.add_child(_hp_fill)
	var shine := ColorRect.new()
	shine.color = Color(1, 1, 1, 0.18)
	shine.position = Vector2(2, 2)
	shine.size = Vector2(HP_WIDTH, 5)
	box.add_child(shine)
	_hp_text = _outlined("", 11)
	_hp_text.position = Vector2(8, 0)
	box.add_child(_hp_text)
	_stats_text = _outlined("", 11)
	_stats_text.position = Vector2(HP_WIDTH + 12, 0)
	box.add_child(_stats_text)
	# barre d'expérience
	var xb := ColorRect.new()
	xb.color = Color(0.05, 0.04, 0.04, 0.85)
	xb.position = Vector2(0, 20)
	xb.size = Vector2(HP_WIDTH + 4, 8)
	box.add_child(xb)
	_xp_fill = ColorRect.new()
	_xp_fill.color = Color(0.45, 0.8, 1.0)
	_xp_fill.position = Vector2(2, 22)
	_xp_fill.size = Vector2(0, 4)
	box.add_child(_xp_fill)
	_xp_text = _outlined("", 10)
	_xp_text.position = Vector2(HP_WIDTH + 12, 16)
	box.add_child(_xp_text)


func _build_death_screen() -> void:
	_death = ColorRect.new()
	(_death as ColorRect).color = Color(0.25, 0.0, 0.0, 0.45)
	_death.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death.hide()
	add_child(_death)
	_death_label = _outlined("Vous êtes tombé au combat…", 26)
	_death_label.set_anchors_preset(Control.PRESET_CENTER)
	_death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_label.size = Vector2(600, 80)
	_death_label.position = Vector2(-300, -40)
	_death.add_child(_death_label)


func _build_combat_ui() -> void:
	# teinte bleutée pendant le ralenti (esquive parfaite)
	_slow_tint = ColorRect.new()
	_slow_tint.color = Color(0.3, 0.6, 1.0, 0.0)
	_slow_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_slow_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_slow_tint)
	move_child(_slow_tint, 0)
	# grand message au centre
	_feat = _outlined("", 30)
	_feat.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_feat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feat.size = Vector2(600, 50)
	_feat.position = Vector2(-300, 120)
	_feat.pivot_offset = Vector2(300, 25)
	_feat.add_theme_constant_override("outline_size", 8)
	_feat.modulate.a = 0.0
	add_child(_feat)
	# cadre de la cible verrouillée (en haut au centre)
	_target_box = Control.new()
	_target_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_target_box.position = Vector2(-160, 58)
	_target_box.size = Vector2(320, 40)
	add_child(_target_box)
	_target_name = _outlined("", 14)
	_target_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_name.size = Vector2(320, 20)
	_target_box.add_child(_target_name)
	var back := ColorRect.new()
	back.color = Color(0.05, 0.04, 0.04, 0.85)
	back.position = Vector2(0, 22)
	back.size = Vector2(320, 10)
	_target_box.add_child(back)
	_target_fill = ColorRect.new()
	_target_fill.color = Color(0.86, 0.22, 0.16)
	_target_fill.position = Vector2(2, 24)
	_target_fill.size = Vector2(316, 6)
	_target_box.add_child(_target_fill)
	_target_box.hide()


## Grand message au centre de l'écran (« Parade ! », « Esquive parfaite ! »...).
func show_feat(text: String, color: Color) -> void:
	_feat.text = text
	_feat.add_theme_color_override("font_color", color)
	_feat.modulate.a = 1.0
	_feat.scale = Vector2.ONE * 1.6
	var tw := _feat.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(_feat, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.7)
	tw.tween_property(_feat, "modulate:a", 0.0, 0.3)


func _outlined(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("fff2dc"))
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.06))
	l.add_theme_constant_override("outline_size", 4)
	return l


func _update_health() -> void:
	if player == null or _hp_fill == null:
		return
	var h := player.health
	_hp_fill.size.x = HP_WIDTH * h.ratio()
	_hp_text.text = "Vie %d / %d" % [h.current, h.max_health]
	_stats_text.text = "Attaque %d   Défense %d   Magie %d" % [player.attack_power(), player.defense_power(), player.magic_power()]
	_xp_fill.size.x = HP_WIDTH * float(player.xp) / float(player.xp_to_next())
	var who := player.profile.hero_name if player.profile else ""
	var cls := player.profile.hero_class.display_name if player.profile and player.profile.hero_class else ""
	_xp_text.text = "%s  ·  %s niveau %d  ·  XP %d / %d" % [who, cls, player.level, player.xp, player.xp_to_next()]
	if not h.is_dead():
		_death.hide()


func _process(delta: float) -> void:
	_slow_tint.color.a = move_toward(_slow_tint.color.a, 0.14 if TimeFX.is_slowed() else 0.0, 0.02)
	if _target and is_instance_valid(_target) and _target.is_alive():
		_target_box.show()
		var d := _target.get("data") as EnemyData
		_target_name.text = d.display_name if d else String(_target.name)
		_target_name.add_theme_color_override("font_color", d.color if d else Color.WHITE)
		_target_fill.size.x = 316.0 * _target.health.ratio()
	else:
		_target_box.hide()
	# la barre jaune rattrape doucement la rouge (on voit les dégâts reçus)
	if _hp_lag and _hp_fill:
		_hp_lag.size.x = move_toward(_hp_lag.size.x, _hp_fill.size.x, delta * 90.0)
		if _hp_lag.size.x < _hp_fill.size.x:
			_hp_lag.size.x = _hp_fill.size.x


func _unhandled_input(event: InputEvent) -> void:
	if player and player.ui_open:
		return
	if event.is_action_pressed("new_world") and world:
		world.generate(randi())
	elif event.is_action_pressed("next_race") and player and not races.is_empty():
		_race_index = (_race_index + 1) % races.size()
		player.apply_race(races[_race_index])
		_refresh()


func show_message(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color("fff2c8"))
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1))
	l.add_theme_constant_override("outline_size", 4)
	_messages.add_child(l)
	while _messages.get_child_count() > 5:
		_messages.get_child(0).free()
	var tw := l.create_tween()
	tw.tween_interval(message_time)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func _refresh() -> void:
	var race_name: String = player.race.display_name if player and player.race else "?"
	_update_health()
	var seed_value: int = world.world_seed if world else 0
	info.text = "ZQSD : bouger   Espace/A : roulade   Clic/J/X : frapper (maintenir = charger)   Clic droit/K/LB : garde   Clic molette/L/LT : viser   I : inventaire   E : habitant\nRace : %s     Graine du monde : %d     R : race   N : nouveau monde" % [race_name, seed_value]
