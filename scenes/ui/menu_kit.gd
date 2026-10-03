class_name MenuKit
extends RefCounted
## Style commun des menus : bois sombre et dorures, titres calligraphiés sur ruban,
## boutons en planche, ouverture en douceur. Les textures et polices viennent d'UiTheme.

const C_BG := Color("241d1a")
const C_PANEL := Color("2f2622")
const C_FRAME := Color("8a6a3a")
const C_TEXT := Color("f0e6d2")
const C_DIM := Color("a8997f")
const C_GOLD := Color("f2c86a")
const C_OK := Color("8ad66a")
const C_BAD := Color("e0705a")
const C_INK := Color("3a2614")
const C_INK_DIM := Color("6e5236")
const PORTRAIT_DIR := "res://assets/ui/portraits/"


static func style(bg: Color, border: Color = C_FRAME, width := 2, radius := 4, margin := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(mini(radius, 3))
	s.set_content_margin_all(margin)
	# liseré clair en haut, ombre en bas : un léger relief
	if width > 0 and bg.a > 0.3:
		s.border_width_bottom = width + 1
		s.shadow_color = Color(0, 0, 0, 0.25)
		s.shadow_size = 2
		s.shadow_offset = Vector2(0, 1)
	return s


static func label(text: String, size := 13, color := C_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size + 1)
	l.add_theme_color_override("font_color", color)
	return l


## Texte en gras (Alegreya Sans Bold).
static func bold(text: String, size := 13, color := C_TEXT) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", UiTheme.font("bold"))
	return l


## Titre calligraphié (Almendra), doré, sur un ruban rouge pour les titres de panneau.
static func title(text: String, size := 24) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", UiTheme.font("title"))
	l.add_theme_font_size_override("font_size", size + 4)
	l.add_theme_color_override("font_color", C_GOLD)
	l.add_theme_color_override("font_outline_color", Color(0.12, 0.04, 0.03))
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 2)
	if size <= 30:
		l.add_theme_stylebox_override("normal", UiTheme.box("ribbon", 20, Vector4(44, 3, 44, 7), Color.WHITE, 8))
		l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return l


## Sous-titre de section : calligraphié, sans ruban.
static func heading(text: String, size := 16, color := C_GOLD) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UiTheme.font("title"))
	l.add_theme_font_size_override("font_size", size + 2)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03))
	l.add_theme_constant_override("outline_size", 3)
	return l


static func button(text: String, width := 260.0, size := 15, sfx := "ui_click") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 34)
	b.add_theme_font_size_override("font_size", size + 2)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func(): Sound.ui(sfx))
	b.mouse_entered.connect(func(): _hover_pulse(b))
	return b


## Bouton d'onglet (actif : planche claire et texte doré).
static func tab(text: String, active: bool, width := 0.0, size := 13) -> Button:
	# changer d'onglet : bruit de page tournée
	var b := button(text, width, size, "ui_hover" if active else "ui_page")
	b.custom_minimum_size.y = 32
	if active:
		b.add_theme_stylebox_override("normal", UiTheme.box("tab_selected", 10, Vector4(14, 6, 14, 6)))
		b.add_theme_stylebox_override("hover", UiTheme.box("tab_selected", 10, Vector4(14, 6, 14, 6)))
		b.add_theme_color_override("font_color", C_GOLD)
	else:
		b.add_theme_stylebox_override("normal", UiTheme.box("tab", 10, Vector4(14, 6, 14, 6)))
		b.add_theme_stylebox_override("hover", UiTheme.box("tab_hover", 10, Vector4(14, 6, 14, 6)))
		b.add_theme_color_override("font_color", C_DIM)
	return b


static func _hover_pulse(c: Control) -> void:
	if not c.is_inside_tree() or (c is BaseButton and c.disabled):
		return
	Sound.play("ui_hover", Vector3.INF, -16.0, 0.03)
	c.pivot_offset = c.size / 2.0
	var tw := c.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(c, "scale", Vector2(1.03, 1.03), 0.06)
	tw.tween_property(c, "scale", Vector2.ONE, 0.10)


## Panneau centré (renvoie la boîte verticale où ajouter le contenu). Il s'ouvre en fondu.
static func panel(parent: Control, width := 420.0) -> VBoxContainer:
	var center := CenterContainer.new()
	parent.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiTheme.frame(18))
	pc.custom_minimum_size = Vector2(width, 0)
	center.add_child(pc)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	pc.add_child(box)
	animate_open(pc)
	return box


## Fondu et léger zoom à chaque fois que le contrôle redevient visible.
static func animate_open(c: Control) -> void:
	c.visibility_changed.connect(func():
		if c.is_visible_in_tree():
			pop_in(c)
		elif c.has_meta("opened") and c.is_inside_tree() and not c.is_queued_for_deletion():
			# le parchemin se roule à la fermeture
			c.remove_meta("opened")
			Sound.ui("ui_close"))
	# un panneau trop haut pour l'écran est réduit plutôt que coupé
	c.resized.connect(func():
		if not c.has_meta("popping"):
			c.pivot_offset = c.size / 2.0
			c.scale = Vector2.ONE * fit_scale(c))


## Échelle pour que le contrôle tienne dans la fenêtre (1 s'il tient déjà).
static func fit_scale(c: Control) -> float:
	if not c.is_inside_tree():
		return 1.0
	var vs := c.get_viewport_rect().size
	var k := minf((vs.y - 10.0) / maxf(c.size.y, 1.0), (vs.x - 10.0) / maxf(c.size.x, 1.0))
	return clampf(k, 0.6, 1.0)


static func pop_in(c: Control, dur := 0.16) -> void:
	if not c.is_inside_tree():
		return
	var target := fit_scale(c)
	c.set_meta("opened", true)
	c.modulate.a = 0.0
	c.scale = Vector2.ONE * target * 0.97
	c.pivot_offset = c.size / 2.0
	c.set_meta("popping", true)
	var tw := c.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, dur)
	tw.tween_property(c, "scale", Vector2.ONE * target, dur)
	tw.chain().tween_callback(func():
		c.remove_meta("popping")
		c.pivot_offset = c.size / 2.0
		c.scale = Vector2.ONE * fit_scale(c))


## Fondu du contenu quand on change de page (onglets).
static func fade_in(c: Control, dur := 0.14) -> void:
	if not c.is_inside_tree():
		return
	c.modulate.a = 0.0
	var tw := c.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(c, "modulate:a", 1.0, dur)


## Filet doré orné d'un losange.
static func divider(width := 320.0) -> TextureRect:
	var r := TextureRect.new()
	r.texture = UiTheme.tex("divider")
	r.custom_minimum_size = Vector2(width, 10)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Petite icône pixel (heart, sword, shield, magic, food, coin, crown, skull, scroll, house,
## people, star, moon, sun, gem, book, compass).
static func icon(name: String, px := 18.0) -> TextureRect:
	var r := TextureRect.new()
	r.texture = UiTheme.tex("icon_" + name)
	r.custom_minimum_size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Une icône suivie d'un texte.
static func icon_label(icon_name: String, text: String, size := 13, color := C_TEXT) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	h.add_child(icon(icon_name, size + 5))
	h.add_child(label(text, size, color))
	return h


## Image rendue d'une créature (assets/ui/portraits/<id>.png), null si absente.
static func portrait_texture(id: String) -> Texture2D:
	var p := PORTRAIT_DIR + id + ".png"
	return load(p) as Texture2D if ResourceLoader.exists(p) else null


## Portrait d'un habitant : celui du personnage de l'histoire, sinon celui de sa race.
static func villager_portrait_id(v: Node) -> String:
	if v == null:
		return ""
	if v.has_meta("story"):
		return "npc_" + str(v.get_meta("story"))
	var race = v.get("race")
	return "race_" + race.resource_path.get_file().get_basename() if race else ""


## Portrait dans un médaillon doré. `known` faux : silhouette sombre (créature jamais vaincue).
static func portrait(id: String, px := 96.0, known := true) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiTheme.box("portrait_frame", 14, Vector4(5, 5, 5, 5)))
	pc.custom_minimum_size = Vector2(px, px)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := TextureRect.new()
	r.texture = portrait_texture(id)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(px - 10, px - 10)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not known:
		r.modulate = Color(0.05, 0.04, 0.06, 0.92)
	pc.add_child(r)
	if r.texture == null or not known:
		var q := label("?", int(px * 0.32), Color(C_GOLD, 0.7))
		q.add_theme_font_override("font", UiTheme.font("title"))
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pc.add_child(q)
	return pc


## Carte d'une liste : bois clair, filet doré (verrouillée : plus sombre).
static func card(locked := false, pad := 8.0) -> StyleBoxTexture:
	return UiTheme.box("card_locked" if locked else "card", 6, Vector4(pad, pad * 0.75, pad, pad * 0.75))


static func format_time(seconds: int) -> String:
	var h := seconds / 3600
	var m := (seconds / 60) % 60
	return "%dh%02d" % [h, m] if h > 0 else "%d min" % m


# ---------------------------------------------------------------- composants (tableaux de bord)

## Jauge horizontale (fond sombre, remplissage coloré, liseré). `ratio` de 0 à 1.
static func gauge(ratio: float, color: Color, width := 120.0, height := 9.0) -> Control:
	var bg := Control.new()
	bg.custom_minimum_size = Vector2(width, height)
	bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.04, 0.03, 0.85)
	sb.border_color = Color(C_FRAME, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	frame.add_theme_stylebox_override("panel", sb)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var r := clampf(ratio, 0.0, 1.0)
	var fill := ColorRect.new()
	fill.color = color
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.anchor_bottom = 1.0
	fill.anchor_right = r
	fill.offset_left = 1
	fill.offset_top = 1
	fill.offset_right = -1 if r > 0.0 else 0
	fill.offset_bottom = -1
	bg.add_child(fill)
	var shine := ColorRect.new()
	shine.color = Color(1, 1, 1, 0.18)
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shine.anchor_right = r
	shine.anchor_bottom = 0.45
	shine.offset_left = 1
	shine.offset_top = 1
	bg.add_child(shine)
	return bg


## Pastille arrondie (étiquette colorée : classe, métier, état...).
static func chip(text: String, color: Color, size := 10) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color.darkened(0.55), 0.9)
	sb.border_color = color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	pc.add_theme_stylebox_override("panel", sb)
	pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pc.mouse_filter = Control.MOUSE_FILTER_PASS
	var l := label(text, size, color.lightened(0.35))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pc.add_child(l)
	return pc


## Carte en bois clair (renvoie la carte ; son contenu va dans `card.get_child(0)`, une VBox).
static func card_box(locked := false, pad := 8.0, sep := 4) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", card(locked, pad))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	pc.add_child(v)
	return pc


## Tuile de chiffre clé : icône, grande valeur, légende, et une jauge si `ratio` >= 0.
static func stat_tile(icon_name: String, value: String, caption: String, color := C_TEXT, ratio := -1.0, width := 150.0) -> PanelContainer:
	var pc := card_box(false, 9.0, 2)
	pc.custom_minimum_size.x = width
	var v: VBoxContainer = pc.get_child(0)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	top.add_child(icon(icon_name, 22))
	var val := bold(value, 17, color)
	top.add_child(val)
	v.add_child(top)
	v.add_child(label(caption, 10, C_DIM))
	if ratio >= 0.0:
		v.add_child(gauge(ratio, color, width - 20.0, 7.0))
	return pc


## En-tête de section : icône, titre calligraphié et filet.
static func section(title_text: String, icon_name := "", size := 15) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	if icon_name != "":
		h.add_child(icon(icon_name, size + 4))
	h.add_child(heading(title_text, size))
	v.add_child(h)
	var line := ColorRect.new()
	line.color = Color(C_GOLD, 0.35)
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(line)
	return v


## Barre d'onglets : [[id, texte, icône]...] ; `on_pick(id)` au clic.
static func tab_bar(tabs: Array, active: String, on_pick: Callable, width := 0.0) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	for t in tabs:
		var b := tab(str(t[1]), t[0] == active, width, 12)
		if t.size() > 2 and str(t[2]) != "":
			b.icon = UiTheme.tex("icon_" + str(t[2]))
			b.expand_icon = false
			b.add_theme_constant_override("icon_max_width", 16)
		var id: String = t[0]
		b.pressed.connect(func(): on_pick.call(id))
		h.add_child(b)
	return h


## Carte de conseil : icône, texte et un bouton d'action facultatif.
static func tip_card(icon_name: String, text: String, button_text := "", on_press: Callable = Callable(), urgent := false) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", style(Color(0.35, 0.1, 0.06, 0.85) if urgent else Color(0.17, 0.13, 0.08, 0.9),
		C_BAD if urgent else Color(C_GOLD, 0.6), 1, 4, 7))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	pc.add_child(h)
	h.add_child(icon(icon_name, 20))
	var l := label(text, 11, C_TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 200
	h.add_child(l)
	if button_text != "" and on_press.is_valid():
		var b := button(button_text, 120, 11)
		b.custom_minimum_size.y = 28
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(on_press)
		h.add_child(b)
	return pc


## Message quand une liste est vide.
static func empty_state(icon_name: String, text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 8)
	var ic := icon(icon_name, 22)
	ic.modulate = Color(1, 1, 1, 0.5)
	h.add_child(ic)
	h.add_child(label(text, 12, C_DIM))
	return h


## Petit portrait carré (sans cadre doré) pour les listes.
static func mini_portrait(id: String, px := 34.0) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", style(Color(0.08, 0.06, 0.05), Color(C_FRAME, 0.9), 1, 3, 1))
	pc.custom_minimum_size = Vector2(px, px)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := TextureRect.new()
	r.texture = portrait_texture(id)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(px - 2, px - 2)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(r)
	return pc


## Icône d'objet (rendue par la base d'objets) avec son nombre.
static func item_badge(item: ItemData, count := 0, px := 30.0) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiTheme.box("slot", 6, Vector4(2, 2, 2, 2)))
	pc.custom_minimum_size = Vector2(px, px)
	pc.tooltip_text = item.display_name if item else ""
	var r := TextureRect.new()
	r.texture = Items.get_icon(item) if item else null
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(px - 6, px - 6)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(r)
	if count > 0:
		var l := bold(str(count), 9, Color.WHITE)
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 3)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		pc.add_child(l)
	return pc


## Bouton de navigation avec icône (bas des panneaux).
static func nav_button(text: String, icon_name: String, width := 150.0) -> Button:
	var b := button(text, width, 12)
	if icon_name != "":
		b.icon = UiTheme.tex("icon_" + icon_name)
		b.add_theme_constant_override("icon_max_width", 16)
	return b


## Jauge centrée sur zéro (relation de -100 à +100) : la barre part du milieu vers la gauche ou la droite.
static func center_gauge(value: float, color: Color, width := 160.0, height := 10.0) -> Control:
	var bg := Control.new()
	bg.custom_minimum_size = Vector2(width, height)
	bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.04, 0.03, 0.85)
	sb.border_color = Color(C_FRAME, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	frame.add_theme_stylebox_override("panel", sb)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var r := clampf(value / 100.0, -1.0, 1.0)
	var fill := ColorRect.new()
	fill.color = color
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.anchor_left = 0.5 + minf(r, 0.0) * 0.5
	fill.anchor_right = 0.5 + maxf(r, 0.0) * 0.5
	fill.anchor_bottom = 1.0
	fill.offset_top = 1
	fill.offset_bottom = -1
	bg.add_child(fill)
	var mid := ColorRect.new()
	mid.color = Color(1, 1, 1, 0.55)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.anchor_left = 0.5
	mid.anchor_right = 0.5
	mid.anchor_bottom = 1.0
	mid.offset_left = -1
	mid.offset_right = 1
	bg.add_child(mid)
	return bg
