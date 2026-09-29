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
var _kingdom_text: Label
var _skill_box: PanelContainer
var _skill_icon: ColorRect
var _skill_cd: ColorRect
var _skill_name: Label
var _skill_rank: Label
var _skill_key: Label
var _zone_title: Label
var _zone_sub: Label
var _zone_tween: Tween
var map_ui: WorldMapUI
var _raid_label: Label
var _raid_timer := 0.0
var _boss_box: Control
var _boss_name: Label
var _boss_fill: ColorRect
var _boss_lag: ColorRect
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
	_build_skill_slot()
	_build_maps()
	if player:
		player.feat.connect(show_feat)
		player.lock_changed.connect(func(t): _target = t)
		player.notify.connect(show_message)
		player.health.changed.connect(func(_c, _m): _update_health())
		player.defeated.connect(func(): _death.show())
		player.equipment.changed.connect(_update_health)
		player.xp_changed.connect(func(_x, _n, _l): _update_health())
		player.skill_changed.connect(func(_s): _update_skill())
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
	_kingdom_text = _outlined("", 11)
	_kingdom_text.position = Vector2(0, 30)
	box.add_child(_kingdom_text)
	var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
	if k:
		k.changed.connect(_update_kingdom)
		k.age_changed.connect(func(a): show_feat("Nouvel âge : %s !" % Kingdom.AGE_NAMES[a], Kingdom.AGE_COLORS[a]))
		k.rank_changed.connect(func(r): show_feat("Votre royaume devient : %s !" % Kingdom.RANK_NAMES[r], Color("f2c86a")))
	_update_kingdom.call_deferred()


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


func _build_skill_slot() -> void:
	_skill_box = PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.06, 0.05, 0.85)
	st.border_color = Color("8a6a3a")
	st.set_border_width_all(2)
	st.set_corner_radius_all(4)
	st.set_content_margin_all(5)
	_skill_box.add_theme_stylebox_override("panel", st)
	_skill_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_skill_box.position = Vector2(-130, -58)
	_skill_box.custom_minimum_size = Vector2(260, 46)
	add_child(_skill_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_skill_box.add_child(row)
	var icon_holder := Control.new()
	icon_holder.custom_minimum_size = Vector2(36, 36)
	row.add_child(icon_holder)
	_skill_icon = ColorRect.new()
	_skill_icon.size = Vector2(36, 36)
	icon_holder.add_child(_skill_icon)
	var inner := ColorRect.new()
	inner.color = Color(1, 1, 1, 0.35)
	inner.position = Vector2(10, 10)
	inner.size = Vector2(16, 16)
	inner.rotation = 0.0
	icon_holder.add_child(inner)
	_skill_cd = ColorRect.new()
	_skill_cd.color = Color(0, 0, 0, 0.7)
	_skill_cd.size = Vector2(36, 0)
	icon_holder.add_child(_skill_cd)
	_skill_key = _outlined("Q", 10)
	_skill_key.position = Vector2(2, 20)
	icon_holder.add_child(_skill_key)
	var txt := VBoxContainer.new()
	txt.add_theme_constant_override("separation", -2)
	row.add_child(txt)
	_skill_name = _outlined("", 14)
	txt.add_child(_skill_name)
	_skill_rank = _outlined("", 9)
	_skill_rank.add_theme_color_override("font_color", Color("c8b89a"))
	txt.add_child(_skill_rank)
	_update_skill()


func _update_skill() -> void:
	if _skill_box == null:
		return
	var s: HeroSkill = player.skill if player else null
	_skill_box.visible = s != null
	if s == null:
		return
	_skill_icon.color = s.data.color.darkened(0.15)
	_skill_name.text = s.current_name()
	_skill_name.add_theme_color_override("font_color", s.data.color.lightened(0.35))
	_skill_rank.text = "%s  ·  Q / RB" % SkillData.TIER_LABELS[s.tier]


func _build_maps() -> void:
	var mini := MiniMap.new()
	mini.world = world
	mini.player = player
	add_child(mini)
	_zone_title = _outlined("", 30)
	_zone_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zone_title.add_theme_constant_override("outline_size", 8)
	_zone_title.modulate.a = 0.0
	add_child(_zone_title)
	_zone_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_zone_title.offset_left = -400
	_zone_title.offset_right = 400
	_zone_title.offset_top = 84
	_zone_title.offset_bottom = 124
	_zone_sub = _outlined("", 14)
	_zone_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zone_sub.modulate.a = 0.0
	add_child(_zone_sub)
	_zone_sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_zone_sub.offset_left = -400
	_zone_sub.offset_right = 400
	_zone_sub.offset_top = 124
	_zone_sub.offset_bottom = 184
	var recruit := RecruitDialog.new()
	recruit.player = player
	add_child(recruit)
	if player:
		player.talk.connect(func(s): recruit.open(s))
	map_ui = WorldMapUI.new()
	map_ui.world = world
	map_ui.player = player
	add_child(map_ui)
	_build_boss_bar()
	_raid_label = _outlined("", 14)
	_raid_label.position = Vector2(14, 132)
	_raid_label.add_theme_color_override("font_color", Color("ff8a6a"))
	add_child(_raid_label)
	var rm := get_tree().get_first_node_in_group("raids") as RaidManager
	if rm:
		rm.raid_warning.connect(func(r):
			show_banner("⚠ Raid imminent !", "%s arrivent %s du village. Prépare tes défenses !" % [r.name, r.dir_text], Color("ff8a6a"))
			show_message("Des pillards (%s, %d) approchent %s du village !" % [r.name, r.count, r.dir_text]))
		rm.raid_started.connect(func(r): show_feat("Les pillards attaquent !", Color("ff6a4a")))
		rm.raid_ended.connect(func(_r, ok, text):
			show_feat("Raid repoussé !" if ok else "Le village a été pillé...", Color("ffd24a") if ok else Color("c86a5a"))
			show_message(text))
	var dm := get_tree().get_first_node_in_group("dungeons") as DungeonManager
	if dm:
		dm.entered.connect(func(z):
			var t: RegionData = z.type
			show_banner("Donjon de %s" % z.name, "Niveau %d à %d  ·  Trouve et affronte le gardien du donjon." % [z.level.y, z.level.y + 2], Color("ffb0a0")))
		dm.exited.connect(func(_z): show_message("Tu remontes à la surface."))
		dm.boss_awoken.connect(func(b, title): show_banner(b.data.display_name, title, Color("ff6a4a")))
		dm.boss_defeated.connect(func(_z, soul):
			show_feat("Boss vaincu !", Color("ffd24a"))
			show_banner("Âme absorbée", soul, Color("aee8ff"))
			show_message("Ton héros absorbe l'âme du boss : " + soul))
	if world:
		world.zone_entered.connect(_on_zone_entered)
		world.obelisk_activated.connect(func(z): show_feat("Obélisque activé !", Color("8af0ff")); show_message("Obélisque de %s activé : voyage rapide depuis la carte (M)." % z.name))


## Bandeau quand on entre dans une zone : son nom, sa région et son niveau.
func _on_zone_entered(z: Dictionary) -> void:
	var t: RegionData = z.type
	if t == null or _zone_title == null:
		return
	show_banner(z.name, "%s  ·  Niveau %d à %d\n%s" % [t.display_name, z.level.x, z.level.y, t.description], t.map_color.lightened(0.55))


## Grand titre au centre-haut de l'écran, qui s'efface après quelques secondes.
func show_banner(title: String, sub: String, color: Color) -> void:
	_zone_title.text = title
	_zone_title.add_theme_color_override("font_color", color)
	_zone_sub.text = sub
	if _zone_tween:
		_zone_tween.kill()
	_zone_tween = create_tween()
	_zone_tween.tween_property(_zone_title, "modulate:a", 1.0, 0.5)
	_zone_tween.parallel().tween_property(_zone_sub, "modulate:a", 1.0, 0.5)
	_zone_tween.tween_interval(3.0)
	_zone_tween.tween_property(_zone_title, "modulate:a", 0.0, 1.0)
	_zone_tween.parallel().tween_property(_zone_sub, "modulate:a", 0.0, 1.0)


func _build_boss_bar() -> void:
	_boss_box = Control.new()
	add_child(_boss_box)
	_boss_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_boss_box.offset_left = -300
	_boss_box.offset_right = 300
	_boss_box.offset_top = -96
	_boss_box.offset_bottom = -52
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_name = _outlined("", 16)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name.size = Vector2(600, 20)
	_boss_box.add_child(_boss_name)
	var back := ColorRect.new()
	back.color = Color(0.05, 0.03, 0.04, 0.85)
	back.position = Vector2(0, 24)
	back.size = Vector2(600, 16)
	_boss_box.add_child(back)
	_boss_lag = ColorRect.new()
	_boss_lag.color = Color("f2c86a")
	_boss_lag.position = Vector2(2, 26)
	_boss_lag.size = Vector2(596, 12)
	_boss_box.add_child(_boss_lag)
	_boss_fill = ColorRect.new()
	_boss_fill.color = Color("c8302a")
	_boss_fill.position = Vector2(2, 26)
	_boss_fill.size = Vector2(596, 12)
	_boss_box.add_child(_boss_fill)
	_boss_box.hide()


func _update_boss_bar(delta: float) -> void:
	var b: Boss = null
	for n in get_tree().get_nodes_in_group("bosses"):
		if n.awake and n.is_alive():
			b = n
	if b == null:
		_boss_box.hide()
		return
	_boss_box.show()
	_boss_name.text = "☠  %s  ·  Nv %d%s  ☠" % [b.data.display_name, b.level, "  ·  ENRAGÉ" if b.phase == 2 else ""]
	_boss_name.add_theme_color_override("font_color", b.data.color.lightened(0.3))
	_boss_fill.size.x = 596.0 * b.health.ratio()
	_boss_fill.color = Color("c8302a") if b.phase == 1 else Color("ff5a1a")
	_boss_lag.size.x = maxf(_boss_fill.size.x, move_toward(_boss_lag.size.x, _boss_fill.size.x, delta * 120.0))


func _update_kingdom() -> void:
	var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
	if k == null or _kingdom_text == null:
		return
	_kingdom_text.text = "♜ %s   (B : construire)" % k.title()
	_kingdom_text.add_theme_color_override("font_color", Kingdom.AGE_COLORS[k.age].lightened(0.2))


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
	if player and player.skill and _skill_cd:
		var r := player.skill.cooldown_ratio()
		_skill_cd.size.y = 36.0 * r
		_skill_cd.position.y = 36.0 * (1.0 - r)
		_skill_key.text = "%d" % ceili(player.skill.cooldown_left) if r > 0.0 else "Q"
	_slow_tint.color.a = move_toward(_slow_tint.color.a, 0.14 if TimeFX.is_slowed() else 0.0, 0.02)
	if _target and is_instance_valid(_target) and _target.is_alive():
		_target_box.show()
		var d := _target.get("data") as EnemyData
		_target_name.text = d.display_name if d else String(_target.name)
		_target_name.add_theme_color_override("font_color", d.color if d else Color.WHITE)
		_target_fill.size.x = 316.0 * _target.health.ratio()
	else:
		_target_box.hide()
	if _boss_box:
		_update_boss_bar(delta)
	_raid_timer -= delta
	if _raid_label and _raid_timer <= 0.0:
		_raid_timer = 0.25
		var rm := get_tree().get_first_node_in_group("raids") as RaidManager
		_raid_label.text = rm.status_text() if rm else ""
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
	elif event.is_action_pressed("next_race") and player and not races.is_empty() and not player.building:
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
	info.text = "ZQSD : bouger   Espace/A : roulade   Clic/J/X : frapper (maintenir = charger)   Clic droit/K/LB : garde   Clic molette/L/LT : viser   Q/RB : compétence   B : construire   M : carte   I : inventaire   E : habitant\nRace : %s     Graine du monde : %d     R : race   N : nouveau monde" % [race_name, seed_value]
