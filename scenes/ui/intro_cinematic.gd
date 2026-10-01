class_name IntroCinematic
extends Control
## Introduction d'une nouvelle partie : la légende du Cœur d'Aube en calligraphie sur fond noir,
## puis la caméra survole le cristal d'Orvane et glisse jusqu'au héros, avec des bandes de cinéma.
## Espace, E, Échap ou clic : passer.

signal finished

const STORY := [
	"Il y a bien longtemps, le Cœur d'Aube veillait sur les royaumes.",
	"Puis il se brisa, et ses éclats se dispersèrent aux quatre vents.",
	"La Brume s'étendit. Les nations se divisèrent. Les villages tombèrent.",
	"Aujourd'hui, une âme venue d'ailleurs ouvre les yeux…",
]
const BAR_H := 62.0

var player: Player
## Éléments de l'interface gardés transparents pendant la cinématique.
var muted: Array = []
var _black: ColorRect
var _top: ColorRect
var _bottom: ColorRect
var _text: Label
var _sub: Label
var _title: Label
var _act: Label
var _skip: Label
var _cam: Camera3D
var _tw: Tween
var _done := false


func _ready() -> void:
	add_to_group("intro")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_black = ColorRect.new()
	_black.color = Color(0.02, 0.015, 0.02)
	add_child(_black)
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_top = _bar(true)
	_bottom = _bar(false)
	_text = _label(30, MenuKit.C_GOLD, "title")
	_text.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_text.offset_left = -400
	_text.offset_right = 400
	_text.offset_top = -60
	_text.offset_bottom = 60
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub = _label(19, Color("f0e6d2"), "title_regular")
	_sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_sub.offset_left = -440
	_sub.offset_right = 440
	_sub.offset_top = -BAR_H + 8
	_sub.offset_bottom = -8
	_title = _label(54, MenuKit.C_GOLD, "title")
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_title.offset_left = -450
	_title.offset_right = 450
	_title.offset_top = -70
	_title.offset_bottom = 10
	_title.add_theme_constant_override("outline_size", 12)
	_act = _label(20, Color("f0e6d2"), "title_regular")
	_act.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_act.offset_left = -400
	_act.offset_right = 400
	_act.offset_top = 14
	_act.offset_bottom = 50
	_skip = _label(12, MenuKit.C_DIM, "body")
	_skip.text = "Espace ou Échap : passer"
	_skip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip.offset_left = -240
	_skip.offset_right = -14
	_skip.offset_top = -28
	_skip.offset_bottom = -8
	_skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for l in [_text, _sub, _title, _act]:
		l.modulate.a = 0.0
	if player:
		player.ui_open = true
	Sound.forced_music = "title"
	_play()


func _bar(top: bool) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0, 0, 0)
	add_child(r)
	r.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
	if top:
		r.offset_bottom = BAR_H
	else:
		r.offset_top = -BAR_H
	return r


func _label(size: int, col: Color, font := "body") -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", UiTheme.font(font))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.02))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _hero_name() -> String:
	return player.profile.hero_name if player and player.profile else "Héros"


func _play() -> void:
	_tw = create_tween()
	# 1. la légende, carte après carte
	for line in STORY:
		_tw.tween_callback(func(): _text.text = line)
		_tw.tween_property(_text, "modulate:a", 1.0, 0.9)
		_tw.tween_interval(2.2)
		_tw.tween_property(_text, "modulate:a", 0.0, 0.7)
	# 2. le cristal d'Orvane, vu du ciel
	_tw.tween_callback(_shot_crystal)
	_tw.tween_property(_black, "color:a", 0.0, 1.4)
	_tw.parallel().tween_property(_sub, "modulate:a", 1.0, 1.4)
	_tw.tween_interval(3.6)
	_tw.tween_property(_sub, "modulate:a", 0.0, 0.6)
	# 3. la caméra glisse jusqu'au héros
	_tw.tween_callback(_shot_hero)
	_tw.tween_property(_sub, "modulate:a", 1.0, 0.8)
	_tw.tween_interval(4.2)
	_tw.tween_property(_sub, "modulate:a", 0.0, 0.6)
	# 4. le titre
	_tw.tween_callback(func():
		_title.text = "L'Éveil du Royaume"
		_act.text = "Acte I — Une autre vie"
		Sound.ui("event"))
	_tw.tween_property(_title, "modulate:a", 1.0, 1.0)
	_tw.parallel().tween_property(_act, "modulate:a", 1.0, 1.4)
	_tw.tween_interval(2.4)
	_tw.tween_property(_title, "modulate:a", 0.0, 0.8)
	_tw.parallel().tween_property(_act, "modulate:a", 0.0, 0.8)
	_tw.tween_callback(finish)


## Point de vue au-dessus du cristal (ou du village s'il n'y a pas d'histoire).
func _shot_crystal() -> void:
	var st := get_tree().get_first_node_in_group("story") as Story
	var w := get_tree().get_first_node_in_group("world") as WorldGenerator
	if w == null:
		return
	var target := w.cell_center(w.spawn_cell)
	if st:
		target = st.camp_center("orvane")
		w.load_area(target)
	target.y = w.ground_height_at(target + Vector3(0, 30, 0)) + 1.2
	_cam = Camera3D.new()
	_cam.fov = 50.0
	get_tree().current_scene.add_child(_cam)
	_cam.make_current()
	_sub.text = "Près des racines anciennes, un cristal murmure ton nom."
	var from := target + Vector3(16, 13, 14)
	var to := target + Vector3(-6, 10, 11)
	var orbit := create_tween()
	orbit.tween_method(func(k: float):
		if is_instance_valid(_cam):
			_cam.global_position = from.lerp(to, k)
			_cam.look_at(target), 0.0, 1.0, 6.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## La caméra rejoint le héros au village.
func _shot_hero() -> void:
	if _cam == null or player == null:
		return
	_sub.text = "%s… Écoute la voix du cristal." % _hero_name()
	var from := _cam.global_position
	var look_from := from + (-_cam.global_transform.basis.z) * 10.0
	var hero := player.global_position + Vector3(0, 1.0, 0)
	var to := hero + Vector3(7, 6, 9)
	var glide := create_tween()
	glide.tween_method(func(k: float):
		if is_instance_valid(_cam):
			_cam.global_position = from.lerp(to, k) + Vector3(0, sin(k * PI) * 6.0, 0)
			_cam.look_at(look_from.lerp(hero, k)), 0.0, 1.0, 5.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Fin (ou « passer ») : on rend la caméra et les commandes au joueur.
func finish() -> void:
	if _done:
		return
	_done = true
	if _tw:
		_tw.kill()
	Sound.forced_music = ""
	if player:
		player.ui_open = false
		if player.camera:
			player.camera.make_current()
	if is_instance_valid(_cam):
		_cam.queue_free()
	var out := create_tween().set_parallel(true)
	out.tween_property(_top, "offset_bottom", 0.0, 0.6)
	out.tween_property(_bottom, "offset_top", 0.0, 0.6)
	out.tween_property(self, "modulate:a", 0.0, 0.6)
	out.chain().tween_callback(func():
		finished.emit()
		queue_free())


func _process(_delta: float) -> void:
	if _done:
		return
	for c in muted:
		if is_instance_valid(c):
			c.modulate.a = 0.0


func _gui_input(event: InputEvent) -> void:
	if not _done and event is InputEventMouseButton and event.pressed:
		accept_event()
		finish()


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	var skip := event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("jump") \
		or event.is_action_pressed("interact")
	if skip:
		get_viewport().set_input_as_handled()
		finish()
