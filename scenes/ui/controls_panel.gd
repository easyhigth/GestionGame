class_name ControlsPanel
extends Control
## Fenêtre « Commandes » (menu pause et écran titre) : toutes les touches, rangées par thème,
## avec le clavier-souris et la manette côte à côte.

signal closed

const C_KEY := Color("3a2e28")
const C_PAD := Color("24303a")

## Onglets : [nom, [[action, touches clavier, touches manette], ...]].
## Dans les touches, « + » sépare des touches à presser ensemble, « / » des touches au choix.
const PAGES := [
	["Déplacement et combat", [
		["Se déplacer (dans le sens de la caméra)", "Z Q S D / Flèches", "Joystick gauche"],
		["Sauter (double saut avec le talent)", "Espace", "A"],
		["Roulade (invulnérable)", "Maj", "B"],
		["Frapper · maintenir pour charger", "Clic gauche / J", "X"],
		["Garde · parade au bon moment", "Clic droit / K", "LB"],
		["Viser la cible la plus proche", "F / L / Clic molette", "LT"],
		["Tourner la caméra à 360°", "Molette maintenue + glisser", "Joystick droit"],
		["Zoom de la caméra", "Molette", "—"],
	]],
	["Compétences et talents", [
		["Compétence unique", "Q", "RB"],
		["Attaques et sorts des emplacements", "1 / 2 / 3 / 4", "R3"],
		["Changer d'emplacement choisi", "—", "Croix droite"],
		["Arbre de talents", "T", "Croix gauche"],
		["Apprendre un talent", "Clic deux fois", "A deux fois"],
		["Ranger un sort dans un emplacement", "1 / 2 / 3 / 4", "Boutons 1-4"],
	]],
	["Monde et royaume", [
		["Récolter : frapper arbres, rochers, buissons, décors", "Clic gauche / J", "X"],
		["Creuser le sol devant soi (maintenir)", "G", "RT"],
		["Choisir un bloc ou un meuble à poser", "C / X", "LB + croix gauche/droite"],
		["Poser devant soi · frapper un bloc le casse", "V", "L3"],
		["Parler · équiper un habitant · recruter", "E", "Y"],
		["Dormir dans un lit (la nuit)", "E", "Y"],
		["Entrer dans un donjon · ouvrir un coffre", "E", "Y"],
		["Inventaire, équipement, artisanat", "I / Tab", "Back"],
		["Carte du monde · voyage rapide", "M", "Croix haut"],
		["Mode construction", "B", "Croix bas"],
		["Menu pause (sauvegarde, options)", "Échap", "Start"],
	]],
	["Construction", [
		["Déplacer la caméra libre (plus vite)", "Z Q S D + Maj", "Joystick gauche"],
		["Tourner la caméra", "A / E / Molette maintenue", "Joystick droit"],
		["Zoom", "Molette", "Joystick droit"],
		["Tracer un plan (glisser)", "Clic gauche", "A"],
		["Annuler le tracé ou le plan visé", "Clic droit", "B"],
		["Tourner le meuble", "R", "Y"],
		["Catégorie", "1 à 7", "LB / RB"],
		["Outil · matériau", "Clic dans la barre", "Croix gauche/droite · haut"],
		["Niveau de travail", "Page ↑ / Page ↓", "Gâchettes"],
		["Hauteur des murs", "[ / ]", "—"],
		["Couper au-dessus du niveau", "C", "—"],
		["Quitter la construction", "B / Échap", "Croix bas"],
	]],
]

var _page := 0
var _tabs: HBoxContainer
var _list: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := MenuKit.panel(self, 760)
	box.add_child(MenuKit.title("Commandes", 22))
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_tabs)
	for i in PAGES.size():
		var b := MenuKit.button(PAGES[i][0], 170, 12)
		b.custom_minimum_size.y = 30
		b.pressed.connect(_show_page.bind(i))
		b.focus_entered.connect(func(): if _page != i: _show_page(i))
		_tabs.add_child(b)
	# en-tête des colonnes
	var head := _row_box()
	head.add_child(_cell(MenuKit.label("Action", 11, MenuKit.C_DIM), 300))
	head.add_child(_cell(MenuKit.label("Clavier et souris", 11, MenuKit.C_DIM), 200))
	head.add_child(_cell(MenuKit.label("Manette", 11, MenuKit.C_DIM), 200))
	box.add_child(head)
	var sep := ColorRect.new()
	sep.color = Color(MenuKit.C_FRAME, 0.6)
	sep.custom_minimum_size = Vector2(0, 1)
	box.add_child(sep)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
	_list.custom_minimum_size = Vector2(0, 330)
	box.add_child(_list)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", 16)
	box.add_child(foot)
	foot.add_child(MenuKit.label("Manette : LB / RB pour changer d'onglet", 10, MenuKit.C_DIM))
	var back := MenuKit.button("Retour", 160, 13)
	back.pressed.connect(close)
	foot.add_child(back)
	_show_page(0)
	(_tabs.get_child(0) as Button).grab_focus.call_deferred()


func _row_box() -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 10)
	return r


func _cell(c: Control, width: float) -> Control:
	c.custom_minimum_size.x = width
	return c


## Touches sous forme de petites plaques : « Z Q S D / Flèches » → [Z][Q][S][D] ou [Flèches].
func _keys(text: String, bg: Color) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	h.custom_minimum_size.x = 200
	if text == "—":
		h.add_child(MenuKit.label("—", 12, Color(MenuKit.C_DIM, 0.6)))
		return h
	var alts := text.split(" / ")
	for a in alts.size():
		if a > 0:
			h.add_child(MenuKit.label("ou", 9, MenuKit.C_DIM))
		var parts: PackedStringArray = alts[a].split(" ") if alts[a].length() <= 7 and alts[a].split(" ").size() == 4 else PackedStringArray([alts[a]])
		for p in parts:
			var pc := PanelContainer.new()
			var st := MenuKit.style(bg, bg.lightened(0.35), 1, 4, 0)
			st.content_margin_left = 6
			st.content_margin_right = 6
			st.content_margin_top = 1
			st.content_margin_bottom = 2
			st.border_width_bottom = 3
			pc.add_theme_stylebox_override("panel", st)
			pc.add_child(MenuKit.label(p, 11, MenuKit.C_TEXT))
			h.add_child(pc)
	return h


func _show_page(i: int) -> void:
	_page = i
	var focused := get_viewport().gui_get_focus_owner()
	if focused and focused.get_parent() == _tabs and focused != _tabs.get_child(i):
		(_tabs.get_child(i) as Button).grab_focus()
	for t in _tabs.get_child_count():
		var b := _tabs.get_child(t) as Button
		b.add_theme_color_override("font_color", MenuKit.C_GOLD if t == i else MenuKit.C_TEXT)
		b.add_theme_stylebox_override("normal", MenuKit.style(Color("5a4636") if t == i else Color("3a2e28"),
			MenuKit.C_GOLD if t == i else Color("6a5030"), 2, 4, 6))
	for c in _list.get_children():
		c.queue_free()
	var rows: Array = PAGES[i][1]
	for r in rows.size():
		var row: Array = rows[r]
		var line := PanelContainer.new()
		line.add_theme_stylebox_override("panel", MenuKit.style(Color(1, 1, 1, 0.04 if r % 2 == 0 else 0.0), Color(0, 0, 0, 0), 0, 3, 3))
		var h := _row_box()
		line.add_child(h)
		var l := MenuKit.label(row[0], 12)
		h.add_child(_cell(l, 300))
		h.add_child(_keys(row[1], C_KEY))
		h.add_child(_keys(row[2], C_PAD))
		_list.add_child(line)


func close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
		var d := 1 if event.button_index == JOY_BUTTON_RIGHT_SHOULDER else -1
		var i := (_page + d + PAGES.size()) % PAGES.size()
		(_tabs.get_child(i) as Button).grab_focus()
		_show_page(i)
		get_viewport().set_input_as_handled()
