class_name UiTheme
extends Node
## Thème de toute l'interface : polices (Almendra pour les titres, Alegreya Sans pour le texte),
## cadres en bois sombre et dorures, boutons en planche, onglets, ascenseurs, barres, infobulles.
## Chargé en autoload (« UiStyle ») : il s'applique à la fenêtre racine, donc à tous les menus.
## Textures : tools/ui_texture_generator.py -> assets/ui/*.png

const DIR := "res://assets/ui/"
const FONT_TITLE := "res://assets/ui/fonts/Almendra-Bold.ttf"
const FONT_TITLE_REGULAR := "res://assets/ui/fonts/Almendra-Regular.ttf"
const FONT_BODY := "res://assets/ui/fonts/AlegreyaSans-Medium.ttf"
const FONT_BOLD := "res://assets/ui/fonts/AlegreyaSans-Bold.ttf"
const FONT_SIZE := 17
const TILED := ["panel_frame", "small_frame", "parchment", "card", "card_hover", "card_locked"]

static var _theme: Theme
static var _fonts := {}
static var _tex := {}


func _ready() -> void:
	install()


## Le thème est fondu dans le thème par défaut de Godot : il s'applique partout, y compris
## sous les CanvasLayer (le HUD) qui ne transmettent pas le thème de la fenêtre.
static func install() -> void:
	var t := get_theme()
	var d := ThemeDB.get_default_theme()
	if d.get_meta("royaume", false):
		return
	d.merge_with(t)
	d.default_font = t.default_font
	d.default_font_size = t.default_font_size
	ThemeDB.fallback_font = t.default_font
	ThemeDB.fallback_font_size = t.default_font_size
	d.set_meta("royaume", true)


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func font(kind := "body") -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var path: String = {"title": FONT_TITLE, "title_regular": FONT_TITLE_REGULAR, "bold": FONT_BOLD}.get(kind, FONT_BODY)
	var f := load(path) as FontFile
	var fv := FontVariation.new()
	fv.base_font = f
	# chiffres alignés (plus lisibles pour les statistiques)
	if kind == "body" or kind == "bold":
		fv.opentype_features = {"lnum": 1}
	_fonts[kind] = fv
	return fv


static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load(DIR + name + ".png")
	return _tex[name]


## Boîte texturée « 9 tranches » : `margin` en pixels de la texture, `pad` autour du contenu.
## `vmargin` (si >= 0) remplace la marge du haut et du bas.
static func box(name: String, margin: float, pad := Vector4(10, 8, 10, 8), tint := Color.WHITE, vmargin := -1.0) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = tex(name)
	s.texture_margin_left = margin
	s.texture_margin_right = margin
	s.texture_margin_top = margin if vmargin < 0.0 else vmargin
	s.texture_margin_bottom = margin if vmargin < 0.0 else vmargin
	s.content_margin_left = pad.x
	s.content_margin_top = pad.y
	s.content_margin_right = pad.z
	s.content_margin_bottom = pad.w
	# le bois des grands cadres se répète ; boutons et onglets s'étirent
	if name in TILED:
		s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	s.modulate_color = tint
	return s


static func frame(pad := 20.0) -> StyleBoxTexture:
	return box("panel_frame", 24, Vector4(pad, pad, pad, pad))


static func small_frame(pad := 8.0) -> StyleBoxTexture:
	return box("small_frame", 8, Vector4(pad, pad * 0.75, pad, pad * 0.75))


static func parchment(pad := 14.0) -> StyleBoxTexture:
	return box("parchment", 20, Vector4(pad, pad, pad, pad))


static func _build() -> Theme:
	var t := Theme.new()
	t.default_font = font("body")
	t.default_font_size = FONT_SIZE
	var text := Color("f0e6d2")
	var gold := Color("f2c86a")
	var dim := Color("a8997f")
	# textes
	t.set_color("font_color", "Label", text)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.45))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_color("default_color", "RichTextLabel", text)
	t.set_font("normal_font", "RichTextLabel", font("body"))
	t.set_font("bold_font", "RichTextLabel", font("bold"))
	t.set_font("italics_font", "RichTextLabel", font("title_regular"))
	# boutons en planche
	for type in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", type, box("button", 10, Vector4(14, 6, 14, 6)))
		t.set_stylebox("hover", type, box("button_hover", 10, Vector4(14, 6, 14, 6)))
		t.set_stylebox("pressed", type, box("button_pressed", 10, Vector4(14, 7, 14, 5)))
		t.set_stylebox("disabled", type, box("button_disabled", 10, Vector4(14, 6, 14, 6)))
		t.set_stylebox("focus", type, box("button_focus", 6))
		t.set_color("font_color", type, text)
		t.set_color("font_hover_color", type, gold)
		t.set_color("font_focus_color", type, gold)
		t.set_color("font_pressed_color", type, Color("ffe6a8"))
		t.set_color("font_disabled_color", type, Color(dim, 0.55))
		t.set_color("font_outline_color", type, Color(0.06, 0.04, 0.03))
		t.set_constant("outline_size", type, 3)
		t.set_font("font", type, font("bold"))
	# cases à cocher : pas de fond
	for type in ["CheckBox", "CheckButton"]:
		var empty := StyleBoxEmpty.new()
		empty.content_margin_left = 4
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			t.set_stylebox(st, type, empty)
		t.set_color("font_color", type, text)
		t.set_color("font_hover_color", type, gold)
		t.set_color("font_pressed_color", type, text)
		t.set_color("font_hover_pressed_color", type, gold)
		t.set_color("font_focus_color", type, gold)
	# panneaux
	t.set_stylebox("panel", "PanelContainer", frame())
	t.set_stylebox("panel", "Panel", frame())
	t.set_stylebox("panel", "PopupMenu", small_frame(6))
	t.set_stylebox("hover", "PopupMenu", box("button_hover", 10, Vector4(6, 2, 6, 2)))
	t.set_color("font_color", "PopupMenu", text)
	t.set_color("font_hover_color", "PopupMenu", gold)
	t.set_font("font", "PopupMenu", font("body"))
	t.set_stylebox("panel", "TooltipPanel", small_frame(8))
	t.set_color("font_color", "TooltipLabel", text)
	t.set_font("font", "TooltipLabel", font("body"))
	t.set_font_size("font_size", "TooltipLabel", 14)
	# onglets
	for type in ["TabContainer", "TabBar"]:
		t.set_stylebox("tab_selected", type, box("tab_selected", 10, Vector4(14, 6, 14, 6)))
		t.set_stylebox("tab_unselected", type, box("tab", 10, Vector4(14, 6, 14, 6)))
		t.set_stylebox("tab_hovered", type, box("tab_hover", 10, Vector4(14, 6, 14, 6)))
		t.set_stylebox("tab_focus", type, box("button_focus", 6))
		t.set_color("font_selected_color", type, gold)
		t.set_color("font_unselected_color", type, dim)
		t.set_color("font_hovered_color", type, text)
		t.set_font("font", type, font("bold"))
	t.set_stylebox("panel", "TabContainer", small_frame(10))
	# ascenseurs
	for type in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", type, box("scroll_track", 4, Vector4(0, 0, 0, 0)))
		t.set_stylebox("grabber", type, box("scroll_grab", 4, Vector4(0, 0, 0, 0)))
		t.set_stylebox("grabber_highlight", type, box("scroll_grab_hover", 4, Vector4(0, 0, 0, 0)))
		t.set_stylebox("grabber_pressed", type, box("scroll_grab_hover", 4, Vector4(0, 0, 0, 0)))
	# barres
	t.set_stylebox("background", "ProgressBar", box("bar_bg", 4, Vector4(2, 2, 2, 2)))
	t.set_stylebox("fill", "ProgressBar", box("bar_fill", 4, Vector4(0, 0, 0, 0), Color("6ad06a")))
	t.set_color("font_color", "ProgressBar", text)
	# champs
	for type in ["LineEdit", "SpinBox", "TextEdit"]:
		t.set_stylebox("normal", type, box("field", 6, Vector4(8, 4, 8, 4)))
		t.set_stylebox("focus", type, box("field_focus", 6, Vector4(8, 4, 8, 4)))
		t.set_color("font_color", type, text)
		t.set_color("caret_color", type, gold)
		t.set_color("selection_color", type, Color(gold, 0.35))
	t.set_stylebox("slider", "HSlider", box("bar_bg", 4, Vector4(0, 3, 0, 3)))
	t.set_stylebox("grabber_area", "HSlider", box("bar_fill", 4, Vector4(0, 3, 0, 3), Color("c9953f")))
	t.set_stylebox("grabber_area_highlight", "HSlider", box("bar_fill", 4, Vector4(0, 3, 0, 3), gold))
	t.set_icon("grabber", "HSlider", tex("icon_gem"))
	t.set_icon("grabber_highlight", "HSlider", tex("icon_gem"))
	# séparateurs
	t.set_constant("separation", "HSeparator", 10)
	var line := StyleBoxLine.new()
	line.color = Color("8a6a3a")
	line.thickness = 2
	t.set_stylebox("separator", "HSeparator", line)
	return t
