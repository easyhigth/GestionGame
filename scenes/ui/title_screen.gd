extends Node3D
## Écran titre : le village de départ en fond (la caméra tourne lentement autour du feu),
## avec continuer, nouvelle partie, charger, options et quitter.

const GAME_TITLE := "L'Éveil du Royaume"
const SUBTITLE := "Bâtis ton royaume · Explore un monde sauvage · Terrasse les seigneurs des donjons"

var _main: Node3D
var _world: WorldGenerator
var _cam: Camera3D
var _angle := 0.4
var _ui: CanvasLayer
var _menu: VBoxContainer


func _ready() -> void:
	GameState.hero = null
	SaveGame.pending = {}
	get_tree().paused = false
	_main = (load(SaveGame.GAME_SCENE) as PackedScene).instantiate()
	# un petit monde suffit pour le décor de l'écran titre (le monde immense prendrait de longues secondes)
	var bw := _main.get_node_or_null("World") as WorldGenerator
	if bw:
		bw.world_size = Vector2i(320, 320)
	# pas d'interface de jeu ni de héros sur l'écran titre
	var hud := _main.get_node_or_null("HUD")
	if hud:
		_main.remove_child(hud)
		hud.free()
	add_child(_main)
	_world = _main.get_node("World") as WorldGenerator
	var p := _main.get_node_or_null("World/Player") as Node3D
	if p:
		p.visible = false
		p.process_mode = Node.PROCESS_MODE_DISABLED
		p.global_position.y = -500.0
	var rm := get_tree().get_first_node_in_group("raids") as RaidManager
	if rm:
		rm.enabled = false
	for e in get_tree().get_nodes_in_group("enemy_units"):
		e.queue_free()
	_cam = Camera3D.new()
	_cam.fov = 55.0
	add_child(_cam)
	_cam.make_current()
	_build_ui()


func _process(delta: float) -> void:
	if _world == null:
		return
	_angle += delta * 0.06
	var c := _world.cell_center(_world.spawn_cell)
	_cam.global_position = c + Vector3(cos(_angle) * 17.0, 9.5, sin(_angle) * 17.0)
	_cam.look_at(c + Vector3(0, 1.0, 0))


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(root)
	# voile sombre à gauche pour lire le menu
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.03, 0.02, 0.02, 0.85))
	grad.set_color(1, Color(0.03, 0.02, 0.02, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 620
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	root.add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	col.offset_left = 70
	col.offset_top = -250
	col.offset_right = 560
	col.offset_bottom = 250
	var t := MenuKit.title(GAME_TITLE, 50)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	t.add_theme_constant_override("outline_size", 12)
	col.add_child(t)
	var sub := MenuKit.label(SUBTITLE, 13, MenuKit.C_TEXT)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(480, 0)
	sub.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.03))
	sub.add_theme_constant_override("outline_size", 4)
	col.add_child(sub)
	var div := MenuKit.divider(440)
	div.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(div)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	col.add_child(gap)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 10)
	col.add_child(_menu)
	var ver := MenuKit.label("Godot 4.7", 11, MenuKit.C_DIM)
	root.add_child(ver)
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.offset_left = -220
	ver.offset_top = -30
	ver.offset_right = -14
	ver.offset_bottom = -10
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_refresh_menu()
	# le menu apparaît en glissant doucement
	col.modulate.a = 0.0
	var tw := col.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(col, "modulate:a", 1.0, 0.9)
	tw.tween_property(col, "offset_left", 70.0, 0.9).from(40.0)


func _refresh_menu() -> void:
	for c in _menu.get_children():
		c.queue_free()
	var latest := SaveGame.latest_slot()
	var first: Button = null
	if latest != "":
		var info := SaveGame.slot_info(latest)
		var b := MenuKit.button("Continuer", 320, 17)
		b.pressed.connect(func(): SaveGame.load_game(latest))
		_menu.add_child(b)
		var l := MenuKit.label("   %s, niveau %d · %s · %s" % [info.hero, int(info.level), info.kingdom, info.zone], 11, MenuKit.C_DIM)
		l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.03))
		l.add_theme_constant_override("outline_size", 3)
		_menu.add_child(l)
		first = b
	var items := [["Nouvelle partie", func(): SaveGame.new_game()],
		["Charger une partie", _load], ["Commandes", _controls], ["Options", _options], ["Quitter", func(): get_tree().quit()]]
	for it in items:
		var b := MenuKit.button(it[0], 320, 17)
		b.pressed.connect(it[1])
		if it[0] == "Charger une partie":
			b.disabled = latest == ""
		_menu.add_child(b)
		if first == null:
			first = b
	first.grab_focus.call_deferred()


func _load() -> void:
	var panel := SaveSlotsPanel.new("load")
	panel.chosen.connect(func(s): SaveGame.load_game(s))
	panel.cancelled.connect(_refresh_menu)
	_ui.add_child(panel)


func _controls() -> void:
	var panel := ControlsPanel.new()
	panel.closed.connect(_refresh_menu)
	_ui.add_child(panel)


func _options() -> void:
	var panel := OptionsPanel.new()
	panel.closed.connect(_refresh_menu)
	_ui.add_child(panel)
