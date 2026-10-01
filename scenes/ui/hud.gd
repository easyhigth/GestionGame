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
var _stat_labels: Array[Label] = []
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
var _hunger_fill: ColorRect
var _hunger_text: Label
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
var _ability_bar: HBoxContainer
var _ability_cells: Array = []
var talent_ui: TalentTreeUI
var day_cycle: DayCycle
var guide: GuidePanel
var _clock: Label
var kingdom_panel: KingdomPanel
var diplomacy_panel: DiplomacyPanel
var achievements_panel: AchievementsPanel
var heraldry_panel: HeraldryPanel
var keys_help: KeysHelp
var quest_dialog: QuestDialog
var shop_dialog: ShopDialog
var trade: Trade
var weather: Weather
var livestock: Livestock
var story: Story
var seasons: Seasons
var mounts: Mounts
var familiars: Familiars
var story_dialog: StoryDialog
var journal: JournalPanel
var mountain_caves: MountainCaves
var city_life: CityLife
var fishing: Fishing
var caves: UnderwaterCaves
var _breath_box: Control
var _breath_fill: ColorRect
var _underwater: ColorRect
var _weather_label: Label
var _quest_box: VBoxContainer
var _quest_refresh := 0.0
var _hotbar: VBoxContainer
var _hotbar_row: HBoxContainer
var _hotbar_name: Label
const HP_WIDTH := 220.0
const BAR_X := 22.0


func _ready() -> void:
	add_to_group("hud")
	_messages = VBoxContainer.new()
	_messages.position = Vector2(10, 470)
	_messages.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_messages.alignment = BoxContainer.ALIGNMENT_END
	_messages.custom_minimum_size = Vector2(330, 0)
	_messages.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_messages.offset_left = 10
	_messages.offset_bottom = -10
	add_child(_messages)
	if world:
		world.world_generated.connect(func(_s): _refresh())
	_place_help()
	_build_health_bar()
	_build_death_screen()
	_build_combat_ui()
	_build_skill_slot()
	_build_maps()
	_build_ability_bar()
	_build_day_and_guide()
	_build_hotbar()
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
	var pause := PauseMenu.new()
	pause.player = player
	add_child(pause)
	set_help_visible(bool(SaveGame.options.show_help))
	SaveGame.saved.connect(func(s): if s != SaveGame.AUTO: show_message("Partie sauvegardée."))
	if GameState.play_intro:
		GameState.play_intro = false
		play_intro.call_deferred()


## Lance l'introduction : le reste de l'interface se cache le temps de la cinématique.
func play_intro() -> IntroCinematic:
	# transparents plutôt que cachés : certains éléments se réaffichent d'eux-mêmes
	var hidden := {}
	for c in get_children():
		if c is CanvasItem:
			hidden[c] = c.modulate.a
			c.modulate.a = 0.0
	var intro := IntroCinematic.new()
	intro.player = player
	intro.muted = hidden.keys()
	add_child(intro)
	intro.finished.connect(func():
		for c in hidden:
			if is_instance_valid(c):
				c.modulate.a = hidden[c]
		_update_health())
	return intro


func _build_health_bar() -> void:
	var box := Control.new()
	box.position = Vector2(8, 8)
	add_child(box)
	# plaque du héros : cadre de bois doré derrière les jauges
	var plate := NinePatchRect.new()
	plate.texture = UiTheme.tex("small_frame")
	plate.patch_margin_left = 8
	plate.patch_margin_right = 8
	plate.patch_margin_top = 8
	plate.patch_margin_bottom = 8
	plate.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	plate.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	plate.position = Vector2(-4, -4)
	plate.size = Vector2(BAR_X + HP_WIDTH + 12, 54)
	plate.modulate = Color(1, 1, 1, 0.92)
	box.add_child(plate)
	box.add_child(_hud_icon("heart", Vector2(2, 0), 18))
	box.add_child(_hud_icon("star", Vector2(4, 21), 13))
	box.add_child(_hud_icon("food", Vector2(4, 33), 13))
	var frame := ColorRect.new()
	frame.color = Color(0.05, 0.04, 0.04, 0.85)
	frame.position = Vector2(BAR_X, 0)
	frame.size = Vector2(HP_WIDTH + 4, 18)
	box.add_child(frame)
	_hp_lag = ColorRect.new()
	_hp_lag.color = Color(0.95, 0.85, 0.5)
	_hp_lag.position = Vector2(BAR_X + 2, 2)
	_hp_lag.size = Vector2(HP_WIDTH, 14)
	box.add_child(_hp_lag)
	_hp_fill = ColorRect.new()
	_hp_fill.color = Color(0.82, 0.18, 0.14)
	_hp_fill.position = Vector2(BAR_X + 2, 2)
	_hp_fill.size = Vector2(HP_WIDTH, 14)
	box.add_child(_hp_fill)
	var shine := ColorRect.new()
	shine.color = Color(1, 1, 1, 0.18)
	shine.position = Vector2(BAR_X + 2, 2)
	shine.size = Vector2(HP_WIDTH, 5)
	box.add_child(shine)
	box.add_child(_bar_frame(Vector2(BAR_X - 1, -1), Vector2(HP_WIDTH + 6, 20)))
	_hp_text = _outlined("", 11)
	_hp_text.position = Vector2(BAR_X + 8, -1)
	box.add_child(_hp_text)
	# attaque, défense, magie : des icônes plutôt que des mots
	_stats_text = _outlined("", 11)
	_stats_text.visible = false
	box.add_child(_stats_text)
	var stats := HBoxContainer.new()
	stats.position = Vector2(BAR_X + HP_WIDTH + 18, -1)
	stats.add_theme_constant_override("separation", 4)
	box.add_child(stats)
	for k in ["sword", "shield", "magic"]:
		stats.add_child(MenuKit.icon(k, 16))
		var l := _outlined("", 12)
		l.custom_minimum_size.x = 26
		stats.add_child(l)
		_stat_labels.append(l)
	# barre d'expérience
	var xb := ColorRect.new()
	xb.color = Color(0.05, 0.04, 0.04, 0.85)
	xb.position = Vector2(BAR_X, 22)
	xb.size = Vector2(HP_WIDTH + 4, 8)
	box.add_child(xb)
	_xp_fill = ColorRect.new()
	_xp_fill.color = Color(0.45, 0.8, 1.0)
	_xp_fill.position = Vector2(BAR_X + 2, 24)
	_xp_fill.size = Vector2(0, 4)
	box.add_child(_xp_fill)
	box.add_child(_bar_frame(Vector2(BAR_X - 1, 21), Vector2(HP_WIDTH + 6, 10)))
	_xp_text = _outlined("", 10)
	_xp_text.position = Vector2(BAR_X + HP_WIDTH + 14, 17)
	box.add_child(_xp_text)
	# jauge de faim
	var hb := ColorRect.new()
	hb.color = Color(0.05, 0.04, 0.04, 0.85)
	hb.position = Vector2(BAR_X, 34)
	hb.size = Vector2(HP_WIDTH * 0.6 + 4, 8)
	box.add_child(hb)
	_hunger_fill = ColorRect.new()
	_hunger_fill.color = Color(0.9, 0.6, 0.25)
	_hunger_fill.position = Vector2(BAR_X + 2, 36)
	_hunger_fill.size = Vector2(HP_WIDTH * 0.6, 4)
	box.add_child(_hunger_fill)
	box.add_child(_bar_frame(Vector2(BAR_X - 1, 33), Vector2(HP_WIDTH * 0.6 + 6, 10)))
	_hunger_text = _outlined("", 9)
	_hunger_text.position = Vector2(BAR_X + HP_WIDTH * 0.6 + 12, 29)
	box.add_child(_hunger_text)
	if player:
		player.hunger_changed.connect(func(_v): _update_hunger())
	_update_hunger.call_deferred()
	box.add_child(_hud_icon("crown", Vector2(2, 52), 14))
	_kingdom_text = _outlined("", 11)
	_kingdom_text.position = Vector2(20, 50)
	box.add_child(_kingdom_text)
	var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
	if k:
		k.changed.connect(_update_kingdom)
		k.age_changed.connect(func(a): show_feat("Nouvel âge : %s !" % Kingdom.AGE_NAMES[a], Kingdom.AGE_COLORS[a]))
		k.rank_changed.connect(func(r): show_feat("Votre royaume devient : %s !" % Kingdom.RANK_NAMES[r], Color("f2c86a")))
	_update_kingdom.call_deferred()


func _update_hunger() -> void:
	if player == null or _hunger_fill == null:
		return
	var r := player.hunger / Player.HUNGER_MAX
	_hunger_fill.size.x = HP_WIDTH * 0.6 * r
	var st: int = player.hunger_state()
	_hunger_fill.color = [Color(0.85, 0.2, 0.15), Color(0.95, 0.45, 0.2), Color(0.9, 0.6, 0.25), Color(0.55, 0.85, 0.35)][st + 1]
	_hunger_text.text = ["Meurt de faim ! (H : manger)", "Affamé (H : manger)", "Faim %d %%" % roundi(player.hunger), "Rassasié · vie +1,5/s"][st + 1]
	_hunger_text.add_theme_color_override("font_color", _hunger_fill.color.lightened(0.3))


## Souffle (sous l'eau) au milieu de l'écran, et teinte bleue quand la tête est sous l'eau.
func _build_breath() -> void:
	_underwater = ColorRect.new()
	_underwater.color = Color(0.1, 0.35, 0.6, 0.3)
	_underwater.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_underwater.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_underwater.hide()
	add_child(_underwater)
	move_child(_underwater, 0)
	_breath_box = Control.new()
	_breath_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_breath_box.offset_left = -80
	_breath_box.offset_right = 80
	_breath_box.offset_top = -214
	_breath_box.offset_bottom = -190
	_breath_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_breath_box)
	var t := _outlined("Souffle", 10)
	t.position = Vector2(0, -2)
	_breath_box.add_child(t)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.06, 0.12, 0.85)
	bg.position = Vector2(0, 14)
	bg.size = Vector2(160, 8)
	_breath_box.add_child(bg)
	_breath_fill = ColorRect.new()
	_breath_fill.color = Color(0.55, 0.85, 1.0)
	_breath_fill.position = Vector2(2, 16)
	_breath_fill.size = Vector2(156, 4)
	_breath_box.add_child(_breath_fill)
	_breath_box.hide()


func _update_breath() -> void:
	if player == null or _breath_box == null:
		return
	var r := player.breath / Player.BREATH_MAX
	_breath_box.visible = r < 0.999
	_breath_fill.size.x = 156.0 * r
	_breath_fill.color = Color(0.55, 0.85, 1.0) if r > 0.3 else Color(1.0, 0.45, 0.35)
	_underwater.visible = player.is_underwater()


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
	_feat.add_theme_font_override("font", UiTheme.font("title"))
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
	_skill_box.add_theme_stylebox_override("panel", UiTheme.small_frame(6))
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


## Barre des 4 attaques / sorts débloqués dans l'arbre de talents (touches 1-4, R3 / croix droite).
func _build_ability_bar() -> void:
	_ability_bar = HBoxContainer.new()
	_ability_bar.add_theme_constant_override("separation", 6)
	_ability_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_ability_bar.position = Vector2(140, -54)
	add_child(_ability_bar)
	for i in TalentTree.SLOTS:
		var cell := Panel.new()
		cell.custom_minimum_size = Vector2(40, 40)
		_ability_bar.add_child(cell)
		var glyph := _outlined("", 20)
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		glyph.size = Vector2(40, 40)
		cell.add_child(glyph)
		var cd := ColorRect.new()
		cd.color = Color(0, 0, 0, 0.7)
		cd.size = Vector2(40, 0)
		cell.add_child(cd)
		var key := _outlined("%d" % (i + 1), 10)
		key.position = Vector2(3, 24)
		cell.add_child(key)
		var timer := _outlined("", 14)
		timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		timer.size = Vector2(40, 40)
		timer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.add_child(timer)
		_ability_cells.append({"cell": cell, "glyph": glyph, "cd": cd, "timer": timer})
	talent_ui = TalentTreeUI.new()
	talent_ui.player = player
	add_child(talent_ui)
	if player:
		player.talents_changed.connect(_update_abilities)
	_update_abilities()


func _update_abilities() -> void:
	if player == null:
		return
	for i in _ability_cells.size():
		var c: Dictionary = _ability_cells[i]
		var id: String = player.ability_slots[i]
		var n := TalentTree.node(id) if id != "" else {}
		var col: Color = TalentTree.branch(n.branch).color if not n.is_empty() else Color(0.4, 0.35, 0.3)
		var st := StyleBoxFlat.new()
		st.bg_color = col.darkened(0.55) if not n.is_empty() else Color(0.08, 0.06, 0.05, 0.6)
		st.border_color = Color("f0d890") if i == player.selected_slot else col.darkened(0.2)
		st.set_border_width_all(3 if i == player.selected_slot else 2)
		st.set_corner_radius_all(4)
		c.cell.add_theme_stylebox_override("panel", st)
		c.glyph.text = n.get("glyph", "")
		c.glyph.add_theme_color_override("font_color", col.lightened(0.4))
		c.cell.tooltip_text = n.get("name", "")


func _build_maps() -> void:
	var mini := MiniMap.new()
	mini.world = world
	mini.player = player
	add_child(mini)
	_zone_title = _outlined("", 32)
	_zone_title.add_theme_font_override("font", UiTheme.font("title"))
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
	shop_dialog = ShopDialog.new()
	shop_dialog.player = player
	add_child(shop_dialog)
	if player:
		# le marchand ambulant ouvre sa boutique, les autres voyageurs se présentent
		player.talk.connect(func(s):
			if s.has_meta("merchant"):
				shop_dialog.open(s)
			elif s.has_meta("story"):
				var st := get_tree().get_first_node_in_group("story") as Story
				if st:
					st.try_talk(s)
			else:
				recruit.open(s))
	map_ui = WorldMapUI.new()
	map_ui.world = world
	map_ui.player = player
	add_child(map_ui)
	_build_boss_bar()
	_raid_label = _outlined("", 14)
	_raid_label.position = Vector2(14, 100)
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
		dm.siege_started.connect(func(id):
			var n: Dictionary = Diplomacy.NATIONS[id]
			show_banner("Siège : capitale de %s" % n.name, "Repousse %d vagues de soldats, puis bats leur champion." % DungeonManager.SIEGE_WAVES, n.color))
		dm.siege_ended.connect(func(id, won):
			var n: Dictionary = Diplomacy.NATIONS[id]
			if won:
				show_banner("Victoire !", "%s devient une province de ton royaume." % n.name, Color("ffd24a"))
			else:
				show_message("Le siège de la capitale de %s est levé. Reviens plus fort !" % n.name))
		dm.boss_awoken.connect(func(b, title): show_banner(b.data.display_name, title, Color("ff6a4a")))
		dm.boss_defeated.connect(func(_z, soul):
			show_feat("Boss vaincu !", Color("ffd24a"))
			if dm.brume_tier > 0:
				show_banner("La Brume se dissipe", soul, DungeonManager.BRUME_COLOR)
				show_message(soul + ". Le palier suivant t'attend à l'entrée du donjon.")
				return
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


## E près d'un marchand de capitale : sa boutique.
func open_city_shop(t: Node) -> void:
	if shop_dialog and t.get("shop"):
		shop_dialog.open_city(t.shop, t)


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
	var n := get_tree().get_first_node_in_group("village_needs") as VillageNeeds
	if n:
		var m := n.members().size()
		_kingdom_text.text = "%s · %d hab. · bonheur %d %% · %d repas   (U : royaume · B : construire)" % [k.title(), m, roundi(n.average_happiness()), n.meals()]
	else:
		_kingdom_text.text = "%s   (B : construire)" % k.title()
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


func _hud_icon(name: String, pos: Vector2, px: float) -> TextureRect:
	var r := MenuKit.icon(name, px)
	r.position = pos
	r.size = Vector2(px, px)
	return r


## Liseré doré autour d'une jauge.
func _bar_frame(pos: Vector2, size: Vector2) -> NinePatchRect:
	var f := NinePatchRect.new()
	f.texture = UiTheme.tex("bar_frame")
	f.patch_margin_left = 4
	f.patch_margin_right = 4
	f.patch_margin_top = 4
	f.patch_margin_bottom = 4
	f.draw_center = false
	f.position = pos
	f.size = size
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return f


func _outlined(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size + 1)
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
	var vals := [player.attack_power(), player.defense_power(), player.magic_power()]
	for i in mini(_stat_labels.size(), 3):
		_stat_labels[i].text = str(vals[i])
	_xp_fill.size.x = HP_WIDTH * float(player.xp) / float(player.xp_to_next())
	var who := player.profile.hero_name if player.profile else ""
	var cls := player.profile.hero_class.display_name if player.profile and player.profile.hero_class else ""
	if player.hero_evo > 0:
		who += " (%s)" % player.evo_title()
	var ach := get_tree().get_first_node_in_group("achievements") as Achievements
	if ach and ach.title != "":
		who += " « %s »" % ach.title
	_xp_text.text = "%s  ·  %s niveau %d  ·  XP %d / %d" % [who, cls, player.level, player.xp, player.xp_to_next()]
	if not h.is_dead():
		_death.hide()


func _process(delta: float) -> void:
	if _fps_label and _fps_label.visible:
		_fps_label.text = "%d IPS" % Engine.get_frames_per_second()
	# en construction, l'interface de construction remplace l'aide et la compétence
	if player:
		var b := player.building
		info.visible = bool(SaveGame.options.show_help) and not b and not player.ui_open
		if _skill_box:
			_skill_box.visible = not b
		if _hotbar:
			_hotbar.visible = not b and player.hand.selected != ""
		if _ability_bar:
			_ability_bar.visible = not b and player.ability_slots.any(func(x): return x != "")
			_process_abilities()
		_messages.offset_bottom = -210.0 if b else -10.0
	_quest_refresh -= delta
	if _quest_refresh <= 0.0:
		_quest_refresh = 1.0
		_update_quests()
		if _quest_box and player:
			_quest_box.visible = not player.building
	if _clock and day_cycle and day_cycle.is_inside_tree():
		_clock.text = day_cycle.clock_text()
		if _weather_label:
			_weather_label.text = (seasons.hud_text() + "  ·  " if seasons and seasons.is_inside_tree() else "") + (weather.hud_text() if weather and weather.is_inside_tree() else "") + ("\nMarchand au village" if trade and trade.is_here() else "")
		_clock.add_theme_color_override("font_color", Color("b8c8ff") if day_cycle.is_night() else Color("fff2c8"))
	if guide:
		guide.modulate.a = 0.35 if player and player.ui_open else 1.0
	_update_breath()
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
		var wev := get_tree().get_first_node_in_group("world_events") as WorldEvents
		if _raid_label.text == "" and wev:
			_raid_label.text = wev.status_text()
	# la barre jaune rattrape doucement la rouge (on voit les dégâts reçus)
	if _hp_lag and _hp_fill:
		_hp_lag.size.x = move_toward(_hp_lag.size.x, _hp_fill.size.x, delta * 90.0)
		if _hp_lag.size.x < _hp_fill.size.x:
			_hp_lag.size.x = _hp_fill.size.x


var _shown_slot := -1

func _process_abilities() -> void:
	if _shown_slot != player.selected_slot:
		_shown_slot = player.selected_slot
		_update_abilities()
	for i in _ability_cells.size():
		var c: Dictionary = _ability_cells[i]
		var hs: HeroSkill = player.abilities.get(player.ability_slots[i])
		var r := hs.cooldown_ratio() if hs else 0.0
		c.cd.size.y = 40.0 * r
		c.cd.position.y = 40.0 * (1.0 - r)
		c.timer.text = "%d" % ceili(hs.cooldown_left) if r > 0.0 else ""


func _unhandled_input(event: InputEvent) -> void:
	if player and player.ui_open:
		return
	# touches de test (uniquement quand on lance le jeu depuis l'éditeur Godot)
	if not OS.has_feature("editor"):
		return
	if event.is_action_pressed("new_world") and world:
		world.generate(randi())
	elif event.is_action_pressed("next_race") and player and not races.is_empty() and not player.building:
		_race_index = (_race_index + 1) % races.size()
		player.apply_race(races[_race_index])
		_refresh()


## Affiche ou cache l'aide des touches (option).
var _fps_label: Label


func set_fps_visible(on: bool) -> void:
	if _fps_label == null and on:
		_fps_label = Label.new()
		_fps_label.add_theme_font_size_override("font_size", 12)
		_fps_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		_fps_label.add_theme_constant_override("outline_size", 4)
		_fps_label.position = Vector2(8, 2)
		_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_fps_label)
	if _fps_label:
		_fps_label.visible = on


func set_help_visible(on: bool) -> void:
	if info:
		info.visible = on


## Petit rappel discret sous la mini-carte (la liste complète des touches est dans le menu « Commandes »).
## Cycle jour/nuit (ajouté à la scène principale), horloge sous la mini-carte et guide des premiers pas.
func _build_day_and_guide() -> void:
	if player == null or world == null:
		return
	day_cycle = DayCycle.new()
	day_cycle.name = "DayCycle"
	day_cycle.world = world
	day_cycle.player = player
	get_parent().add_child.call_deferred(day_cycle)
	var needs := VillageNeeds.new()
	needs.name = "VillageNeeds"
	get_parent().add_child.call_deferred(needs)
	needs.changed.connect(_update_kingdom)
	var farming := Farming.new()
	farming.name = "Farming"
	farming.world = world
	get_parent().add_child.call_deferred(farming)
	weather = Weather.new()
	weather.name = "Weather"
	weather.world = world
	weather.player = player
	get_parent().add_child.call_deferred(weather)
	familiars = Familiars.new()
	familiars.name = "Familiars"
	familiars.world = world
	familiars.player = player
	get_parent().add_child.call_deferred(familiars)
	mounts = Mounts.new()
	mounts.name = "Mounts"
	mounts.world = world
	mounts.player = player
	get_parent().add_child.call_deferred(mounts)
	seasons = Seasons.new()
	seasons.name = "Seasons"
	seasons.world = world
	seasons.player = player
	get_parent().add_child.call_deferred(seasons)
	story = Story.new()
	story.name = "Story"
	story.world = world
	story.player = player
	get_parent().add_child.call_deferred(story)
	var side := SideQuests.new()
	side.name = "SideQuests"
	get_parent().add_child.call_deferred(side)
	story_dialog = StoryDialog.new()
	story_dialog.player = player
	add_child(story_dialog)
	journal = JournalPanel.new()
	journal.player = player
	add_child(journal)
	fishing = Fishing.new()
	fishing.name = "Fishing"
	fishing.world = world
	fishing.player = player
	get_parent().add_child.call_deferred(fishing)
	caves = UnderwaterCaves.new()
	caves.name = "UnderwaterCaves"
	caves.world = world
	caves.player = player
	get_parent().add_child.call_deferred(caves)
	mountain_caves = MountainCaves.new()
	mountain_caves.name = "MountainCaves"
	mountain_caves.world = world
	mountain_caves.player = player
	get_parent().add_child.call_deferred(mountain_caves)
	city_life = CityLife.new()
	city_life.name = "CityLife"
	city_life.world = world
	city_life.player = player
	get_parent().add_child.call_deferred(city_life)
	add_child(FishingBar.new())
	_build_breath()
	livestock = Livestock.new()
	livestock.name = "Livestock"
	livestock.world = world
	livestock.player = player
	get_parent().add_child.call_deferred(livestock)
	trade = Trade.new()
	trade.name = "Trade"
	trade.world = world
	get_parent().add_child.call_deferred(trade)
	var board := QuestBoard.new()
	board.name = "QuestBoard"
	get_parent().add_child.call_deferred(board)
	board.changed.connect(_update_quests)
	_clock = _outlined("", 12)
	_clock.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_clock.offset_left = -300
	_clock.offset_right = -12
	_clock.offset_top = 244
	_clock.offset_bottom = 262
	add_child(_clock)
	# météo (et marchand au village) sous l'horloge
	_weather_label = _outlined("", 11)
	_weather_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_weather_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_weather_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_weather_label.offset_left = -420
	_weather_label.offset_right = -12
	_weather_label.offset_top = 261
	_weather_label.offset_bottom = 295
	_weather_label.add_theme_color_override("font_color", Color("d8e4f0"))
	add_child(_weather_label)
	guide = GuidePanel.new()
	guide.player = player
	add_child(guide)
	kingdom_panel = KingdomPanel.new()
	kingdom_panel.player = player
	add_child(kingdom_panel)
	var dip := Diplomacy.new()
	dip.name = "Diplomacy"
	get_parent().add_child.call_deferred(dip)
	var wev := WorldEvents.new()
	wev.name = "WorldEvents"
	wev.started.connect(func(ev):
		var info: Dictionary = WorldEvents.EVENTS[ev.id]
		show_banner(info.name, info.text, info.color))
	wev.ended.connect(func(ev, ok, _t):
		if ok:
			show_feat("%s : réussi !" % WorldEvents.EVENTS[ev.id].name, Color("ffd24a")))
	get_parent().add_child.call_deferred(wev)
	set_fps_visible.call_deferred(bool(SaveGame.options.get("show_fps", false)))
	var ach := Achievements.new()
	ach.name = "Achievements"
	ach.changed.connect(_update_health)
	get_parent().add_child.call_deferred(ach)
	achievements_panel = AchievementsPanel.new()
	achievements_panel.player = player
	add_child(achievements_panel)
	var her := Heraldry.new()
	her.name = "Heraldry"
	her.changed.connect(_update_health)
	get_parent().add_child.call_deferred(her)
	keys_help = KeysHelp.new()
	add_child(keys_help)
	heraldry_panel = HeraldryPanel.new()
	heraldry_panel.player = player
	add_child(heraldry_panel)
	diplomacy_panel = DiplomacyPanel.new()
	diplomacy_panel.player = player
	add_child(diplomacy_panel)
	quest_dialog = QuestDialog.new()
	quest_dialog.player = player
	add_child(quest_dialog)
	player.quest_talk.connect(func(v): quest_dialog.open(v))
	# suivi des quêtes en cours, sous l'horloge
	_quest_box = VBoxContainer.new()
	_quest_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_quest_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_quest_box.offset_left = -300
	_quest_box.offset_right = -12
	_quest_box.offset_top = 314
	_quest_box.add_theme_constant_override("separation", 1)
	_quest_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_quest_box)


## Barre des objets à poser à la main (C / X pour choisir, V pour poser), au-dessus de la compétence.
func _build_hotbar() -> void:
	if player == null or player.hand == null:
		return
	_hotbar = VBoxContainer.new()
	_hotbar.alignment = BoxContainer.ALIGNMENT_END
	_hotbar.add_theme_constant_override("separation", 2)
	_hotbar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hotbar.position = Vector2(-240, -112)
	_hotbar.custom_minimum_size = Vector2(480, 50)
	_hotbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hotbar)
	_hotbar_name = _outlined("", 12)
	_hotbar_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hotbar.add_child(_hotbar_name)
	_hotbar_row = HBoxContainer.new()
	_hotbar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_hotbar_row.add_theme_constant_override("separation", 3)
	_hotbar.add_child(_hotbar_row)
	player.hand.selection_changed.connect(_update_hotbar)
	player.inventory.changed.connect(_update_hotbar)
	_update_hotbar()


func _update_hotbar() -> void:
	if _hotbar == null:
		return
	var sel := player.hand.selected
	_hotbar.visible = sel != ""
	for c in _hotbar_row.get_children():
		c.queue_free()
	if sel == "":
		return
	var list := player.hand.choices()
	# on montre au plus 9 objets, centrés sur celui qui est choisi
	var i0 := 0
	for i in list.size():
		if list[i].id == sel:
			i0 = clampi(i - 4, 0, maxi(0, list.size() - 9))
	for i in range(i0, mini(list.size(), i0 + 9)):
		var it: ItemData = list[i]
		var on := it.id == sel
		var cell := Panel.new()
		cell.custom_minimum_size = Vector2(36, 36)
		cell.add_theme_stylebox_override("panel", UiTheme.box("slot_selected" if on else "slot", 8, Vector4.ZERO))
		var icon := TextureRect.new()
		icon.texture = Items.get_icon(it)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(3, 3)
		icon.size = Vector2(30, 30)
		cell.add_child(icon)
		var n := _outlined(str(player.inventory.count(it)), 9)
		n.position = Vector2(20, 22)
		cell.add_child(n)
		_hotbar_row.add_child(cell)
	var cur := Items.get_item(sel)
	var verb := "poser"
	if cur and cur.id == "houe":
		verb = "labourer"
	elif cur and cur.is_seed():
		verb = "semer (les poules te suivent)" if HandBuild.is_lure(cur) else "semer"
	elif cur and cur.id == "barque":
		verb = "mettre à l'eau (face à l'eau)"
	elif cur and cur.id == "canne_peche":
		verb = "pêcher (face à l'eau)"
	elif cur and HandBuild.is_lure(cur):
		verb = "rien (les bêtes te suivent)"
	_hotbar_name.text = "%s  ·  V / L3 : %s   C / X : changer   (après le dernier : mains nues)" % [cur.display_name if cur else "", verb]


## Suivi des quêtes en cours (en haut à droite) : titre et avancement.
func _update_quests() -> void:
	if _quest_box == null:
		return
	for c in _quest_box.get_children():
		_quest_box.remove_child(c)
		c.queue_free()
	# l'histoire principale en premier
	var st := get_tree().get_first_node_in_group("story") as Story
	if st and not st.is_done():
		var h := _outlined("✦ Histoire", 11)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.custom_minimum_size.x = 288
		h.add_theme_color_override("font_color", Color("ffe08a"))
		_quest_box.add_child(h)
		var sl := _outlined(st.tracker_text() + "  (O : journal)", 9)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.custom_minimum_size.x = 288
		sl.add_theme_color_override("font_color", Color("f0e6c8"))
		_quest_box.add_child(sl)
	var qb := get_tree().get_first_node_in_group("quests") as QuestBoard
	if qb == null:
		return
	for q in qb.active():
		var t := _outlined("★ " + String(q.title), 11)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		t.custom_minimum_size.x = 288
		t.add_theme_color_override("font_color", Color("8ad66a") if q.state == "ready" else Color("f2c86a"))
		_quest_box.add_child(t)
		var p := _outlined(qb.progress_text(q), 9)
		p.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		p.custom_minimum_size.x = 288
		p.add_theme_color_override("font_color", Color("d8ccb0"))
		_quest_box.add_child(p)


func _place_help() -> void:
	# sous la mini-carte, en haut à droite
	info.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	info.offset_left = -300
	info.offset_right = -12
	info.offset_top = 294
	info.offset_bottom = 310
	info.add_theme_font_size_override("font_size", 10)
	info.modulate = Color(1, 1, 1, 0.7)


func show_message(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color("fff2c8"))
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1))
	l.add_theme_constant_override("outline_size", 4)
	# les longs messages passent à la ligne au lieu de glisser sous la compétence
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(330, 0)
	_messages.add_child(l)
	while _messages.get_child_count() > 5:
		_messages.get_child(0).free()
	var tw := l.create_tween()
	tw.tween_interval(message_time)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func _refresh() -> void:
	_update_health()
	info.text = "Échap / Start : menu et commandes  ·  F2 : aide-mémoire des touches"
