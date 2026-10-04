extends Control
## Écran de création du héros : race, apparence (style, couleurs de peau, cheveux, yeux, taille,
## carrure), classe, métier et nom. Le héros est affiché en 3D au centre et tourne sur son socle
## (on peut le faire tourner à la souris). « Commencer l'aventure » lance la partie.

const RACES_DIR := "res://data/races/"
const CLASSES_DIR := "res://data/classes/"
const JOBS_DIR := "res://data/jobs/"
const SKILLS_DIR := "res://data/skills/"
const GAME_SCENE := "res://scenes/main.tscn"
const NAMES := ["Aldric", "Kaelen", "Sylvane", "Brannoc", "Ysolde", "Thorvald", "Mirelle", "Garrik", "Liora",
	"Oren", "Vaelis", "Rurik", "Selka", "Darion", "Nyssa", "Torben", "Elowen", "Kazimir", "Aurore", "Faelan"]
## Couleurs proposées en plus des couleurs de la race.
const EXTRA_COLORS := ["#f2c9a5", "#c68a5f", "#6b4429", "#e8e0dc", "#7fb046", "#3a6ab0", "#b83a30", "#6a3a7a",
	"#1e1a18", "#d9b04a", "#e8e8f0", "#f49ac8", "#4aa8a0", "#ff7a3a", "#60ffb0", "#8a4ad0"]

const C_BG := Color(0.1, 0.08, 0.07, 0.86)
const C_FRAME := Color("8a6a3a")
const C_TEXT := Color("f0e6d2")
const C_DIM := Color("a8997f")
const C_GOLD := Color("f2c86a")

var profile := HeroProfile.new()
var races: Array[RaceData] = []
var classes: Array[ClassData] = []
var jobs: Array[JobData] = []
var show_gear := true

var _viewport: SubViewport
var _cam: Camera3D
var _cam_target := Vector3(-0.3, 1.1, 0)
var _cam_dist := 8.0
var _hero: VoxelCharacter
var _angle := 0.0
var _auto_turn := true
var _dragging := false
var _idle_move := 3.0

# widgets
var _tabs: TabContainer
var _race_buttons := {}
var _race_info: RichTextLabel
var _style_label: Label
var _beard_box: CheckBox
var _hair_title: Label
var _skin_row: HFlowContainer
var _hair_row: HFlowContainer
var _eye_row: HFlowContainer
var _height: HSlider
var _build: HSlider
var _class_buttons := {}
var _class_info: RichTextLabel
var _job_buttons := {}
var _job_info: RichTextLabel
var skills: Array[SkillData] = []
var _skill_filter: OptionButton
var _skill_search: LineEdit
var _skill_list: VBoxContainer
var _skill_info: RichTextLabel
var _skill_buttons := {}
var _aura: MeshInstance3D
var _name_edit: LineEdit
var _summary: RichTextLabel
var _stat_bars := {}


func _ready() -> void:
	races.assign(_load_all(RACES_DIR))
	races.sort_custom(func(a, b): return a.display_name < b.display_name)
	classes.assign(_load_all(CLASSES_DIR))
	jobs.assign(_load_all(JOBS_DIR))
	skills.assign(_load_all(SKILLS_DIR))
	skills.sort_custom(func(a, b): return a.category + a.tier_names[0] < b.category + b.tier_names[0])
	var order := ["Guerrier", "Paladin", "Barbare", "Rôdeur", "Assassin", "Mage"]
	classes.sort_custom(func(a, b): return order.find(a.display_name) < order.find(b.display_name))
	jobs.sort_custom(func(a, b): return a.display_name < b.display_name)
	theme = _make_theme()
	_build_preview()
	_build_ui()
	var human := races.filter(func(r): return r.model_id == "human")
	profile.race = human[0] if not human.is_empty() else races[0]
	profile.reset_colors()
	profile.hero_class = classes[0]
	profile.job = jobs[0]
	profile.skill = skills.pick_random()
	profile.hero_name = NAMES.pick_random()
	_name_edit.text = profile.hero_name
	_refresh_all()


func _load_all(dir_path: String) -> Array:
	var out := []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f in dir.get_files():
		f = f.trim_suffix(".remap")
		if f.ends_with(".tres"):
			out.append(load(dir_path + f))
	return out


# ---------------------------------------------------------------- aperçu 3D

func _build_preview() -> void:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(container)
	container.gui_input.connect(_on_preview_input)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	container.add_child(_viewport)

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.2, 0.42, 0.78)
	sm.sky_horizon_color = Color(0.95, 0.78, 0.6)
	sm.sky_curve = 0.12
	sm.ground_horizon_color = Color(0.95, 0.78, 0.6)
	sm.ground_bottom_color = Color(0.2, 0.25, 0.15)
	sm.sun_angle_max = 20.0
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.72, 0.85)
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_light_color = Color(0.85, 0.8, 0.75)
	env.fog_density = 0.012
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	_viewport.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 35, 0)
	sun.light_color = Color(1.0, 0.9, 0.78)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	_viewport.add_child(sun)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-1.5, 2.2, -1.5)
	rim.light_color = Color(0.5, 0.7, 1.0)
	rim.light_energy = 1.2
	rim.omni_range = 5.0
	_viewport.add_child(rim)

	_viewport.add_child(_make_pedestal())
	_hero = VoxelCharacter.new()
	_viewport.add_child(_hero)
	_hero.position.y = 0.25

	_cam = Camera3D.new()
	_cam.fov = 24
	_viewport.add_child(_cam)
	_cam.look_at_from_position(Vector3(-0.3, 2.2, 8.4), Vector3(-0.3, 0.95, 0))


## Socle en blocs d'herbe et de pierre, avec un arbre et des rochers derrière (même style que le jeu).
func _make_pedestal() -> Node3D:
	var root := Node3D.new()
	var grain: Texture2D = load("res://assets/environment/voxel_grain.png")
	var mats := {}
	for key in ["grass", "grass2", "dirt", "stone", "stone2"]:
		var m := StandardMaterial3D.new()
		m.albedo_texture = grain
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.uv1_scale = Vector3(1.25, 1.25, 1.25)
		m.uv1_triplanar = true
		m.albedo_color = {"grass": Color("5e9c44"), "grass2": Color("4f8c3a"), "dirt": Color("7a5a3c"),
			"stone": Color("8e8c86"), "stone2": Color("77756f")}[key]
		mats[key] = m
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for x in range(-9, 10):
		for z in range(-9, 3):
			var d := Vector2(x, z).length()
			if d > 9.5:
				continue
			var h := 0.25 if (absi(x) <= 1 and absi(z) <= 1) else (0.0 if d < 3.6 else -0.25)
			h += rng.randi_range(0, 1) * 0.1 if d > 3.2 else 0.0
			var top := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(1, 0.5 + h, 1)
			top.mesh = box
			top.material_override = mats["grass" if (x + z) % 2 == 0 else "grass2"]
			if absi(x) <= 1 and absi(z) <= 1:
				top.material_override = mats["stone" if (x + z) % 2 == 0 else "stone2"]
			top.position = Vector3(x, (h - 0.5) / 2.0, z)
			root.add_child(top)
	# décors : arbres et rochers voxel du jeu
	var props := [["oak_1", Vector3(-4.0, 0.0, -4.5), 1.1], ["pine_2", Vector3(3.6, -0.25, -5.5), 1.2],
		["oak_autumn", Vector3(6.5, -0.25, -7.0), 1.1], ["pine_1", Vector3(-7.0, -0.25, -6.5), 1.0],
		["rock_big", Vector3(2.4, 0.0, -2.2), 0.8], ["rock_1", Vector3(-2.2, 0.0, -1.4), 1.0],
		["bush_1", Vector3(-2.3, 0.0, 1.2), 1.0], ["flowers_1", Vector3(1.8, 0.0, 1.0), 1.2], ["grass_1", Vector3(-1.1, 0.0, 1.4), 1.0],
		["flowers_2", Vector3(-3.2, 0.0, 0.2), 1.0]]
	for p in props:
		var scn: PackedScene = load("res://assets/environment/models/%s.glb" % p[0])
		if scn:
			var n := scn.instantiate() as Node3D
			n.position = p[1]
			n.scale = Vector3.ONE * p[2]
			root.add_child(n)
	var fire: PackedScene = load("res://assets/environment/models/campfire.glb")
	if fire:
		var f := fire.instantiate() as Node3D
		f.position = Vector3(-1.9, 0.0, -2.4)
		f.scale = Vector3.ONE * 0.8
		root.add_child(f)
		var light := OmniLight3D.new()
		light.position = Vector3(-1.9, 0.8, -2.4)
		light.light_color = Color(1.0, 0.6, 0.3)
		light.light_energy = 1.3
		light.omni_range = 4.0
		root.add_child(light)
	return root


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			_auto_turn = false
	elif event is InputEventMouseMotion and _dragging:
		_angle += event.relative.x * 0.012


func _process(delta: float) -> void:
	if _auto_turn:
		_angle += delta * 0.35
	var joy := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	if absf(joy) > 0.2:
		_angle += joy * delta * 3.0
		_auto_turn = false
	var facing := Vector3(sin(_angle), 0, cos(_angle))
	_hero.rotation.y = _angle
	_hero.animate(delta, Vector3.ZERO, facing)
	_hero.rotation.y = _angle
	var eye := _cam_target + Vector3(0, _cam_dist * 0.16, _cam_dist)
	_cam.global_position = _cam.global_position.lerp(eye, clampf(delta * 6.0, 0.0, 1.0))
	_cam.look_at(_cam.global_position + (_cam_target - eye))
	# de temps en temps, le héros montre ce qu'il sait faire
	_idle_move -= delta
	if _idle_move <= 0.0:
		_idle_move = randf_range(4.0, 7.0)
		_show_off()


func _show_off() -> void:
	if profile.hero_class == null or not show_gear:
		return
	var weapon: ItemData = null
	for it in profile.hero_class.starting_equipment:
		if it.slot == ItemData.Slot.MAIN_HAND:
			weapon = it
	var combo := MoveLibrary.combo_for(weapon.weapon_style if weapon else ItemData.WeaponStyle.UNARMED)
	_hero.play_move(combo[randi() % combo.size()], 0.8)


# ---------------------------------------------------------------- interface

func _style(bg: Color, border: Color = C_FRAME, width := 2, radius := 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(6)
	return s


func _make_theme() -> Theme:
	# mêmes planches et dorures que le reste de l'interface, en plus compact
	var th := Theme.new()
	th.default_font_size = 12
	th.set_color("font_color", "Label", C_TEXT)
	var pad := Vector4(8, 3, 8, 3)
	th.set_stylebox("normal", "Button", UiTheme.box("button", 10, pad))
	th.set_stylebox("hover", "Button", UiTheme.box("button_hover", 10, pad))
	th.set_stylebox("pressed", "Button", UiTheme.box("tab_selected", 10, pad))
	th.set_stylebox("hover_pressed", "Button", UiTheme.box("tab_selected", 10, pad))
	th.set_stylebox("focus", "Button", UiTheme.box("button_focus", 6))
	th.set_stylebox("disabled", "Button", UiTheme.box("button_disabled", 10, pad))
	th.set_color("font_color", "Button", Color("f0e2c8"))
	th.set_color("font_pressed_color", "Button", MenuKit.C_GOLD)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_hover_pressed_color", "Button", MenuKit.C_GOLD)
	th.set_stylebox("panel", "TabContainer", StyleBoxEmpty.new())
	th.set_stylebox("tab_selected", "TabContainer", UiTheme.box("tab_selected", 10, Vector4(10, 4, 10, 4)))
	th.set_stylebox("tab_unselected", "TabContainer", UiTheme.box("tab", 10, Vector4(10, 4, 10, 4)))
	th.set_stylebox("tab_hovered", "TabContainer", UiTheme.box("tab_hover", 10, Vector4(10, 4, 10, 4)))
	th.set_color("font_selected_color", "TabContainer", MenuKit.C_GOLD)
	th.set_color("font_unselected_color", "TabContainer", C_DIM)
	th.set_font_size("font_size", "TabContainer", 11)
	th.set_stylebox("normal", "LineEdit", UiTheme.box("field", 6, Vector4(8, 4, 8, 4)))
	th.set_stylebox("focus", "LineEdit", UiTheme.box("field_focus", 6, Vector4(8, 4, 8, 4)))
	th.set_color("font_color", "LineEdit", Color("fff4d8"))
	th.set_font_size("font_size", "LineEdit", 15)
	th.set_color("default_color", "RichTextLabel", C_TEXT)
	th.set_font_size("normal_font_size", "RichTextLabel", 11)
	th.set_font_size("bold_font_size", "RichTextLabel", 12)
	th.set_color("font_color", "CheckBox", C_TEXT)
	return th


func _label(text: String, size := 11, color := C_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _title(text: String) -> Label:
	var l := _label(text, 14, C_GOLD)
	l.add_theme_font_override("font", UiTheme.font("title"))
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	l.add_theme_constant_override("outline_size", 3)
	return l


func _rich() -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.custom_minimum_size = Vector2(290, 0)
	return r


func _panel(pos: Vector2, size: Vector2) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.frame(14))
	p.position = pos
	p.size = size
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	p.add_child(v)
	return v


func _build_ui() -> void:
	# titre
	var title := _label("Création du héros", 22, C_GOLD)
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
	title.add_theme_constant_override("outline_size", 6)
	title.position = Vector2(356, 8)
	add_child(title)
	var hint := _label("Glisser pour faire tourner le héros", 10, Color(1, 1, 1, 0.7))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	hint.add_theme_constant_override("outline_size", 3)
	hint.position = Vector2(390, 516)
	add_child(hint)

	# panneau de gauche : onglets
	var left := _panel(Vector2(10, 10), Vector2(326, 520))
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(310, 500)
	left.add_child(_tabs)
	_tabs.add_child(_build_race_tab())
	_tabs.add_child(_build_look_tab())
	_tabs.add_child(_build_class_tab())
	_tabs.add_child(_build_job_tab())
	_tabs.add_child(_build_skill_tab())

	# panneau de droite : nom, résumé, caractéristiques, boutons
	var right := _panel(Vector2(700, 10), Vector2(250, 520))
	right.add_child(_title("Nom du héros"))
	_name_edit = LineEdit.new()
	_name_edit.max_length = 20
	_name_edit.text_changed.connect(func(t): profile.hero_name = t if t.strip_edges() != "" else "Héros"; _refresh_summary())
	right.add_child(_name_edit)
	_summary = _rich()
	_summary.custom_minimum_size = Vector2(234, 0)
	right.add_child(_summary)
	right.add_child(_title("Caractéristiques"))
	for key in ["Vie", "Attaque", "Défense", "Magie", "Agilité", "Vitesse"]:
		var row := HBoxContainer.new()
		var l := _label(key, 10, C_DIM)
		l.custom_minimum_size = Vector2(56, 0)
		row.add_child(l)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(130, 10)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.show_percentage = false
		var bg := _style(Color("1c1614"), Color("3a2c22"), 1, 2)
		bg.set_content_margin_all(0)
		var fg := _style(Color("c8883a"), Color("c8883a"), 0, 2)
		fg.set_content_margin_all(0)
		bar.add_theme_stylebox_override("background", bg)
		bar.add_theme_stylebox_override("fill", fg)
		row.add_child(bar)
		var v := _label("", 10)
		v.custom_minimum_size = Vector2(34, 0)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(v)
		right.add_child(row)
		_stat_bars[key] = [bar, v]
	var gear := CheckBox.new()
	gear.text = "Montrer l'équipement de départ"
	gear.button_pressed = true
	gear.add_theme_font_size_override("font_size", 10)
	gear.toggled.connect(func(on): show_gear = on; _refresh_model())
	right.add_child(gear)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(spacer)
	var rnd := Button.new()
	rnd.text = "Héros aléatoire"
	rnd.pressed.connect(_randomize)
	right.add_child(rnd)
	var start := Button.new()
	start.text = "Commencer l'aventure"
	start.custom_minimum_size = Vector2(0, 36)
	start.add_theme_font_size_override("font_size", 15)
	start.add_theme_font_override("font", UiTheme.font("title"))
	start.add_theme_stylebox_override("normal", UiTheme.box("button_hover", 10, Vector4(12, 4, 12, 4)))
	start.add_theme_stylebox_override("hover", UiTheme.box("tab_selected", 10, Vector4(12, 4, 12, 4)))
	start.add_theme_color_override("font_color", MenuKit.C_GOLD)
	start.pressed.connect(_start)
	right.add_child(start)
	var back := Button.new()
	back.text = "Retour au menu"
	back.pressed.connect(func(): get_tree().change_scene_to_file(SaveGame.TITLE_SCENE))
	right.add_child(back)


func _scroll(content: Control, tab_name: String) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.name = tab_name
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.add_child(content)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return sc


func _build_race_tab() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(_title("Choisis ta race"))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	var group := ButtonGroup.new()
	for r in races:
		var b := Button.new()
		b.text = r.display_name
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(96, 24)
		b.add_theme_font_size_override("font_size", 10)
		b.pressed.connect(_set_race.bind(r))
		grid.add_child(b)
		_race_buttons[r] = b
	v.add_child(grid)
	_race_info = _rich()
	v.add_child(_race_info)
	return _scroll(v, "Race")


func _build_look_tab() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(_title("Style"))
	var row := HBoxContainer.new()
	var prev := Button.new()
	prev.text = "◀"
	prev.custom_minimum_size = Vector2(28, 0)
	prev.pressed.connect(_change_style.bind(-1))
	row.add_child(prev)
	_style_label = _label("", 11)
	_style_label.custom_minimum_size = Vector2(230, 0)
	_style_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_style_label)
	var nxt := Button.new()
	nxt.text = "▶"
	nxt.custom_minimum_size = Vector2(28, 0)
	nxt.pressed.connect(_change_style.bind(1))
	row.add_child(nxt)
	v.add_child(row)
	_beard_box = CheckBox.new()
	_beard_box.text = "Barbe"
	_beard_box.toggled.connect(func(on): profile.beard = on; _refresh_model())
	v.add_child(_beard_box)
	v.add_child(_title("Couleur de peau"))
	_skin_row = _swatch_row()
	v.add_child(_skin_row)
	_hair_title = _title("Cheveux")
	v.add_child(_hair_title)
	_hair_row = _swatch_row()
	v.add_child(_hair_row)
	v.add_child(_title("Yeux"))
	_eye_row = _swatch_row()
	v.add_child(_eye_row)
	v.add_child(_title("Silhouette"))
	_height = _slider(v, "Taille", 0.88, 1.12)
	_height.value_changed.connect(func(x): profile.height = x; _apply_scale())
	_build = _slider(v, "Carrure", 0.88, 1.18)
	_build.value_changed.connect(func(x): profile.build = x; _apply_scale())
	return _scroll(v, "Apparence")


func _slider(parent: Control, text: String, lo: float, hi: float) -> HSlider:
	var row := HBoxContainer.new()
	var l := _label(text, 10, C_DIM)
	l.custom_minimum_size = Vector2(60, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01
	s.value = 1.0
	s.custom_minimum_size = Vector2(220, 16)
	row.add_child(s)
	parent.add_child(row)
	return s


func _swatch_row() -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 3)
	f.add_theme_constant_override("v_separation", 3)
	return f


## Remplit une rangée de pastilles de couleur, plus un bouton « couleur libre ».
func _fill_swatches(row: HFlowContainer, colors: Array, current: Color, on_pick: Callable) -> void:
	for c in row.get_children():
		c.queue_free()
	var all: Array = colors.duplicate()
	for e in EXTRA_COLORS:
		if not all.has(e) and all.size() < 14:
			all.append(e)
	for hex in all:
		var col := Color(hex)
		var b := Button.new()
		b.custom_minimum_size = Vector2(20, 20)
		var sel := col.is_equal_approx(current)
		b.add_theme_stylebox_override("normal", _style(col, Color.WHITE if sel else Color(0, 0, 0, 0.6), 2 if sel else 1, 3))
		b.add_theme_stylebox_override("hover", _style(col.lightened(0.15), Color("f2c86a"), 2, 3))
		b.add_theme_stylebox_override("pressed", _style(col, Color.WHITE, 2, 3))
		b.pressed.connect(func(): on_pick.call(col))
		row.add_child(b)
	var picker := ColorPickerButton.new()
	picker.color = current
	picker.text = "…"
	picker.tooltip_text = "Couleur libre"
	picker.custom_minimum_size = Vector2(28, 20)
	picker.edit_alpha = false
	picker.color_changed.connect(func(col): on_pick.call(col))
	row.add_child(picker)


func _build_class_tab() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	v.add_child(_title("Choisis ta classe"))
	var group := ButtonGroup.new()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	for c in classes:
		var b := Button.new()
		b.text = c.display_name
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(146, 28)
		b.add_theme_color_override("font_color", c.color.lightened(0.2))
		b.pressed.connect(func(): profile.hero_class = c; _refresh_all(); _idle_move = 0.3)
		grid.add_child(b)
		_class_buttons[c] = b
	v.add_child(grid)
	_class_info = _rich()
	v.add_child(_class_info)
	return _scroll(v, "Classe")


func _build_job_tab() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	v.add_child(_title("Choisis ton métier"))
	var group := ButtonGroup.new()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	for j in jobs:
		var b := Button.new()
		b.text = j.display_name
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(146, 28)
		b.pressed.connect(func(): profile.job = j; _refresh_all())
		grid.add_child(b)
		_job_buttons[j] = b
	v.add_child(grid)
	_job_info = _rich()
	v.add_child(_job_info)
	return _scroll(v, "Métier")


# ---------------------------------------------------------------- choix

func _set_race(r: RaceData) -> void:
	profile.race = r
	profile.reset_colors()
	_refresh_all()


func _change_style(step: int) -> void:
	var pal := HeroProfile.palette(profile.race)
	var n: int = pal.get("styles", ["?"]).size()
	profile.style = posmod(profile.style + step, n)
	_refresh_all()


func _build_skill_tab() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	v.add_child(_title("Compétence unique (%d)" % skills.size()))
	var row := HBoxContainer.new()
	_skill_filter = OptionButton.new()
	_skill_filter.add_theme_font_size_override("font_size", 10)
	_skill_filter.add_item("Toutes les catégories")
	var cats := []
	for s in skills:
		if not cats.has(s.category):
			cats.append(s.category)
	cats.sort()
	for c in cats:
		_skill_filter.add_item(c)
	_skill_filter.item_selected.connect(func(_i): _fill_skill_list())
	_skill_filter.custom_minimum_size = Vector2(150, 0)
	row.add_child(_skill_filter)
	var dice := Button.new()
	dice.text = "Au hasard"
	dice.add_theme_font_size_override("font_size", 10)
	dice.pressed.connect(func(): _pick_skill(skills.pick_random()))
	row.add_child(dice)
	v.add_child(row)
	_skill_search = LineEdit.new()
	_skill_search.placeholder_text = "Rechercher..."
	_skill_search.add_theme_font_size_override("font_size", 10)
	_skill_search.text_changed.connect(func(_t): _fill_skill_list())
	v.add_child(_skill_search)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(300, 170)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_skill_list = VBoxContainer.new()
	_skill_list.add_theme_constant_override("separation", 2)
	_skill_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_skill_list)
	v.add_child(sc)
	_skill_info = _rich()
	v.add_child(_skill_info)
	_fill_skill_list()
	var outer := ScrollContainer.new()
	outer.name = "Compétence"
	outer.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(v)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return outer


func _fill_skill_list() -> void:
	for c in _skill_list.get_children():
		c.queue_free()
	_skill_buttons.clear()
	var cat := _skill_filter.get_item_text(_skill_filter.selected) if _skill_filter.selected > 0 else ""
	var q := _skill_search.text.strip_edges().to_lower() if _skill_search else ""
	var group := ButtonGroup.new()
	for s in skills:
		if cat != "" and s.category != cat:
			continue
		if q != "" and not ("".join(s.tier_names) + s.category + s.description).to_lower().contains(q):
			continue
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "  %s  ·  %s" % [s.tier_names[0], s.category]
		b.add_theme_font_size_override("font_size", 10)
		b.add_theme_color_override("font_color", s.color.lightened(0.3))
		b.custom_minimum_size = Vector2(0, 20)
		b.set_pressed_no_signal(s == profile.skill)
		b.pressed.connect(_pick_skill.bind(s))
		_skill_list.add_child(b)
		_skill_buttons[s] = b


func _pick_skill(s: SkillData) -> void:
	profile.skill = s
	for k in _skill_buttons:
		_skill_buttons[k].set_pressed_no_signal(k == s)
	_refresh_texts()
	_refresh_aura()


## Anneau de la couleur de la compétence sous le héros, avec une gerbe de cubes.
func _refresh_aura() -> void:
	if profile.skill == null:
		return
	if _aura == null:
		_aura = MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.9
		c.bottom_radius = 0.9
		c.height = 0.04
		c.radial_segments = 12
		c.rings = 1
		_aura.mesh = c
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_aura.material_override = m
		_aura.position = Vector3(0, 0.29, 0)
		_viewport.add_child(_aura)
	(_aura.material_override as StandardMaterial3D).albedo_color = Color(profile.skill.color, 0.45)
	var b := VoxelBurst.new()
	b.color = profile.skill.color
	b.gravity = -2.0
	for i in 26:
		var a := randf() * TAU
		b._pos.append(Vector3(cos(a) * 0.8, 0.35, sin(a) * 0.8))
		b._vel.append(Vector3(cos(a) * 0.4, randf_range(1.5, 3.0), sin(a) * 0.4))
		b._age.append(0.0)
		b._life.append(randf_range(0.6, 1.1))
		b._size.append(randf_range(0.06, 0.12))
		b._rot.append(Vector3(randf(), randf(), 0))
	_viewport.add_child(b)


func _randomize() -> void:
	profile.race = races.pick_random()
	var pal := HeroProfile.palette(profile.race)
	profile.style = randi() % pal["styles"].size()
	profile.beard = pal.get("beard", false) and randf() < 0.5
	profile.skin_color = Color(pal["skin"].pick_random())
	profile.hair_color = Color(pal["hair"].pick_random())
	profile.eye_color = Color(pal["eye"].pick_random())
	profile.height = randf_range(0.92, 1.08)
	profile.build = randf_range(0.92, 1.12)
	profile.hero_class = classes.pick_random()
	profile.job = jobs.pick_random()
	profile.skill = skills.pick_random()
	profile.hero_name = NAMES.pick_random()
	_name_edit.text = profile.hero_name
	_refresh_all()
	_idle_move = 0.5


func _start() -> void:
	profile.hero_name = _name_edit.text.strip_edges() if _name_edit.text.strip_edges() != "" else "Héros"
	GameState.hero = profile
	GameState.play_intro = true
	SaveGame.pending = {}
	SaveGame.play_time = 0.0
	# la nouvelle partie prend l'emplacement du monde créé (ou le premier libre)
	if SaveGame.current_slot == "" or SaveGame.has_save(SaveGame.current_slot):
		var free := SaveGame.free_slot()
		SaveGame.current_slot = free if free != "" else "1"
	if SaveGame.world_opts.is_empty():
		SaveGame.world_opts = SaveGame.WORLD_DEFAULTS.duplicate()
		SaveGame.world_opts.name = "Monde %s" % SaveGame.current_slot
	LoadingScreen.go(get_tree(), GAME_SCENE, "Création du monde...")


# ---------------------------------------------------------------- mise à jour

func _refresh_all() -> void:
	for r in _race_buttons:
		_race_buttons[r].set_pressed_no_signal(r == profile.race)
	for c in _class_buttons:
		_class_buttons[c].set_pressed_no_signal(c == profile.hero_class)
	for j in _job_buttons:
		_job_buttons[j].set_pressed_no_signal(j == profile.job)
	var pal := HeroProfile.palette(profile.race)
	var styles: Array = pal.get("styles", ["—"])
	_style_label.text = "%s  (%d / %d)" % [styles[profile.style % styles.size()], profile.style + 1, styles.size()]
	_beard_box.visible = pal.get("beard", false)
	_beard_box.set_pressed_no_signal(profile.beard)
	_hair_title.text = pal.get("hair_label", "Cheveux")
	_fill_swatches(_skin_row, pal.get("skin", []), profile.skin_color, func(c): profile.skin_color = c; _refresh_colors())
	_fill_swatches(_hair_row, pal.get("hair", []), profile.hair_color, func(c): profile.hair_color = c; _refresh_colors())
	_fill_swatches(_eye_row, pal.get("eye", []), profile.eye_color, func(c): profile.eye_color = c; _refresh_colors())
	_height.set_value_no_signal(profile.height)
	_build.set_value_no_signal(profile.build)
	_refresh_texts()
	_refresh_model()
	_refresh_aura()


func _refresh_colors() -> void:
	_hero.set_colors(profile.skin_color, profile.hair_color, profile.eye_color)
	var pal := HeroProfile.palette(profile.race)
	_fill_swatches(_skin_row, pal.get("skin", []), profile.skin_color, func(c): profile.skin_color = c; _refresh_colors())
	_fill_swatches(_hair_row, pal.get("hair", []), profile.hair_color, func(c): profile.hair_color = c; _refresh_colors())
	_fill_swatches(_eye_row, pal.get("eye", []), profile.eye_color, func(c): profile.eye_color = c; _refresh_colors())


func _refresh_model() -> void:
	_hero.set_equipment_library(profile.race.equipment)
	_hero.set_colors(profile.skin_color, profile.hair_color, profile.eye_color)
	_hero.set_model(profile.model())
	for s in ItemData.Slot.values():
		_hero.show_equipment(s, "")
	if show_gear and profile.hero_class:
		for it in profile.hero_class.starting_equipment:
			_hero.show_equipment(it.slot, it.id)
	_apply_scale()


func _apply_scale() -> void:
	_hero.scale = Vector3(profile.build, profile.height, profile.build)
	_frame_camera.call_deferred()


## Cadre la caméra selon la taille du héros (une fée et un ogre tiennent tous les deux dans l'image).
func _frame_camera() -> void:
	var top := 0.0
	for mi in _hero.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.is_visible_in_tree():
			continue
		var box := m.global_transform * m.get_aabb()
		top = maxf(top, box.end.y)
	var h := clampf(top - _hero.global_position.y, 1.0, 3.2)
	_cam_dist = maxf(5.6, h * 3.2 + 1.8)
	_cam_target = Vector3(-0.28 * _cam_dist / 8.0, _hero.global_position.y + h * 0.5, 0)


func _skill_text() -> String:
	var s := profile.skill
	if s == null:
		return ""
	var lines := ["[font_size=13][color=#%s]%s[/color][/font_size]  [color=#a8997f]%s[/color]\n%s" % [s.color.lightened(0.3).to_html(false), s.tier_names[0], s.category, s.description]]
	for tier in 3:
		lines.append("\n[color=#f2c86a]%s — %s[/color] [color=#a8997f](niveau %d)[/color]\n[color=#9fe0a0]Passif :[/color] %s\n[color=#7fd8ff]Actif :[/color] %s" % [
			s.tier_names[tier], SkillData.TIER_LABELS[tier].get_slice(" · ", 0), SkillData.TIER_LEVELS[tier], s.passive_text(tier), s.active_text(tier)])
	return "\n".join(lines)


func _refresh_texts() -> void:
	var r := profile.race
	_race_info.text = "[font_size=13][color=#f2c86a]%s[/color][/font_size]\n%s\n\n[color=#a8997f]Vie %d · Force %d · Agilité %d · Magie %d · Vitesse %d %%[/color]" % [
		r.display_name, r.description, r.max_health, r.strength, r.agility, r.magic, roundi(r.speed_multiplier * 100)]
	var c := profile.hero_class
	if c:
		var gear := ", ".join(c.starting_equipment.map(func(i): return i.display_name))
		var bon := []
		if c.bonus_health: bon.append("Vie %+d" % c.bonus_health)
		if c.bonus_attack: bon.append("Attaque %+d" % c.bonus_attack)
		if c.bonus_defense: bon.append("Défense %+d" % c.bonus_defense)
		if c.bonus_magic: bon.append("Magie %+d" % c.bonus_magic)
		_class_info.text = "[font_size=13][color=#%s]%s[/color][/font_size]\n%s\n\n[color=#f2c86a]Équipement :[/color] %s\n[color=#f2c86a]Bonus :[/color] %s\n[color=#f2c86a]Par niveau :[/color] Vie +%d, Attaque +%.1f, Magie +%.1f" % [
			c.color.lightened(0.2).to_html(false), c.display_name, c.description, gear, ", ".join(bon) if bon else "—",
			c.health_per_level, c.attack_per_level, c.magic_per_level]
		var cls_sk := TalentTree.class_skills(c.resource_path.get_file().get_basename())
		if not cls_sk.is_empty():
			_class_info.text += "\n\n[color=#f2c86a]Compétences de classe :[/color]"
			for n in cls_sk:
				_class_info.text += "\n%s [b]%s[/b] (niveau %d) : %s" % [n.glyph, n.name, int(n.level), n.desc]
	var j := profile.job
	if j:
		var items := []
		for i in j.starting_items.size():
			items.append("%d %s" % [j.starting_counts[i] if i < j.starting_counts.size() else 1, j.starting_items[i].display_name])
		_job_info.text = "[font_size=13][color=#f2c86a]%s[/color][/font_size]\n%s\n\n[color=#f2c86a]Au départ :[/color] %s\n[color=#f2c86a]Avantage :[/color] %s" % [
			j.display_name, j.description, ", ".join(items), j.perks_text() if j.perks_text() != "" else "—"]
		var jid := j.resource_path.get_file().get_basename()
		var crafts_txt: Array = Crafts.JOB_START.get(jid, []).map(func(x): return Crafts.CRAFTS[x].name)
		if not crafts_txt.is_empty():
			_job_info.text += "\n[color=#f2c86a]Artisanat :[/color] %s au niveau %d" % [" et ".join(PackedStringArray(crafts_txt)), Crafts.START_LEVEL]
		if Crafts.JOB_SPECIALTY.has(jid):
			_job_info.text += "\n[color=#f2c86a]Savoir-faire :[/color] %s" % Crafts.JOB_SPECIALTY[jid]
	if _skill_info:
		_skill_info.text = _skill_text()
	_refresh_summary()


func _refresh_summary() -> void:
	var r := profile.race
	var c := profile.hero_class
	var j := profile.job
	_summary.text = "[font_size=14]%s[/font_size]\n%s · [color=#%s]%s[/color] · %s" % [profile.hero_name, r.display_name,
		c.color.lightened(0.2).to_html(false) if c else "ffffff", c.display_name if c else "?", j.display_name if j else "?"]
	if profile.skill:
		_summary.text += "\n[color=#%s]✦ %s[/color]" % [profile.skill.color.lightened(0.3).to_html(false), profile.skill.tier_names[0]]
	# caractéristiques de départ (race + classe + métier + équipement)
	var hp := r.max_health + (c.bonus_health if c else 0) + (j.bonus_health if j else 0)
	var atk := r.strength + (c.bonus_attack if c else 0) + (j.bonus_attack if j else 0)
	var df := (c.bonus_defense if c else 0) + (j.bonus_defense if j else 0)
	var mg := r.magic + (c.bonus_magic if c else 0) + (j.bonus_magic if j else 0)
	var spd := r.speed_multiplier * (1.0 + (j.bonus_speed if j else 0.0))
	if c:
		for it in c.starting_equipment:
			atk += it.attack
			df += it.defense
			mg += it.magic
			spd *= 1.0 + it.speed_bonus
	var vals := {"Vie": [hp, 160], "Attaque": [atk, 36], "Défense": [df, 20], "Magie": [mg, 36], "Agilité": [r.agility, 18], "Vitesse": [roundi(spd * 100), 125]}
	for k in vals:
		var bar: ProgressBar = _stat_bars[k][0]
		bar.max_value = vals[k][1]
		bar.value = vals[k][0]
		(_stat_bars[k][1] as Label).text = str(vals[k][0]) + (" %" if k == "Vitesse" else "")
