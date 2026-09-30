class_name MenuKit
extends RefCounted
## Style commun des menus (titre, pause, options, sauvegardes) : bois sombre et dorures.

const C_BG := Color("241d1a")
const C_PANEL := Color("2f2622")
const C_FRAME := Color("8a6a3a")
const C_TEXT := Color("f0e6d2")
const C_DIM := Color("a8997f")
const C_GOLD := Color("f2c86a")
const C_OK := Color("8ad66a")
const C_BAD := Color("e0705a")


static func style(bg: Color, border: Color = C_FRAME, width := 2, radius := 4, margin := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s


static func label(text: String, size := 13, color := C_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func title(text: String, size := 24) -> Label:
	var l := label(text, size, C_GOLD)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.03))
	l.add_theme_constant_override("outline_size", 6)
	return l


static func button(text: String, width := 260.0, size := 15) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 38)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", C_TEXT)
	b.add_theme_color_override("font_hover_color", C_GOLD)
	b.add_theme_color_override("font_focus_color", C_GOLD)
	b.add_theme_color_override("font_disabled_color", Color(C_DIM, 0.5))
	b.add_theme_stylebox_override("normal", style(Color("3a2e28"), Color("6a5030"), 2, 4, 6))
	b.add_theme_stylebox_override("hover", style(Color("4a3a30"), C_GOLD, 2, 4, 6))
	b.add_theme_stylebox_override("focus", style(Color("4a3a30"), C_GOLD, 2, 4, 6))
	b.add_theme_stylebox_override("pressed", style(Color("5a4636"), C_GOLD, 2, 4, 6))
	b.add_theme_stylebox_override("disabled", style(Color("2a221e"), Color("3a3028"), 2, 4, 6))
	b.pressed.connect(func(): Sound.ui("ui_click"))
	return b


## Panneau centré (renvoie la boîte verticale où ajouter le contenu).
static func panel(parent: Control, width := 420.0) -> VBoxContainer:
	var center := CenterContainer.new()
	parent.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", style(Color(C_BG, 0.96), C_FRAME, 2, 6, 20))
	pc.custom_minimum_size = Vector2(width, 0)
	center.add_child(pc)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	pc.add_child(box)
	return box


static func format_time(seconds: int) -> String:
	var h := seconds / 3600
	var m := (seconds / 60) % 60
	return "%dh%02d" % [h, m] if h > 0 else "%d min" % m
