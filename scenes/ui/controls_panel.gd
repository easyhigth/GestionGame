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
		["Creuser le sol devant soi (maintenir) · dans l'eau : plonger", "G", "RT"],
		["Choisir un bloc, un meuble, des graines ou la houe", "C / X", "LB + croix gauche/droite"],
		["Poser, semer ou labourer devant soi · frapper un bloc le casse", "V", "L3"],
		["Parler · équiper un habitant · recruter", "E", "Y"],
		["Dormir dans un lit (la nuit)", "E", "Y"],
		["Manger (la meilleure nourriture du sac)", "H", "LB + croix haut"],
		["Entrer dans un donjon · ouvrir un coffre", "E", "Y"],
		["Inventaire, équipement, artisanat", "I / Tab", "Back"],
		["Carte du monde · voyage rapide", "M", "Croix haut"],
		["Mode construction", "B", "Croix bas"],
		["Royaume : habitants, lits, réserve de nourriture, bonheur", "U", "Start → Royaume"],
		["Journal de l'histoire (objectif, éclats, personnages)", "O", "—"],
		["Familiers : ordre suivant (suivre, attendre, attaquer)", "P", "—"],
		["Diplomatie : nations voisines, traités, guerre", "Y", "—"],
		["Boire une potion (soin si blessé, sinon renfort)", "Z", "—"],
		["Succès et bestiaire", "F1", "—"],
		["Aide-mémoire des touches à l'écran", "F2", "—"],
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

## Lignes des onglets dont la touche suit la personnalisation : début du texte -> action.
const ROW_ACTIONS := {"Sauter": "jump", "Roulade": "dash", "Compétence unique": "skill", "Arbre de talents": "talents",
	"Creuser": "dig", "Poser, semer": "place_block", "Parler": "interact", "Dormir": "interact", "Entrer dans un donjon": "interact",
	"Manger": "eat", "Inventaire": "inventory", "Carte du monde": "world_map", "Mode construction": "build_mode",
	"Royaume": "kingdom", "Journal": "journal", "Familiers": "familiar_order", "Diplomatie": "diplomacy",
	"Boire une potion": "potion", "Succès et bestiaire": "achievements"}

var _page := 0
var _tabs: HBoxContainer
var _list: VBoxContainer
## Action qui attend sa nouvelle touche ("" sinon).
var _listening := ""
var _note: Label


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
	for i in PAGES.size() + 1:
		var b := MenuKit.button(PAGES[i][0] if i < PAGES.size() else "Personnaliser", 170 if i < PAGES.size() else 130, 12)
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
	_listening = ""
	if i >= PAGES.size():
		_show_custom()
		return
	var custom: Dictionary = SaveGame.options.get("keys", {})
	var rows: Array = PAGES[i][1]
	for r in rows.size():
		var row: Array = rows[r]
		var line := PanelContainer.new()
		line.add_theme_stylebox_override("panel", MenuKit.style(Color(1, 1, 1, 0.04 if r % 2 == 0 else 0.0), Color(0, 0, 0, 0), 0, 3, 3))
		var h := _row_box()
		line.add_child(h)
		var l := MenuKit.label(row[0], 12)
		h.add_child(_cell(l, 300))
		var keys_text: String = row[1]
		for start in ROW_ACTIONS:
			if String(row[0]).begins_with(start) and custom.has(ROW_ACTIONS[start]):
				keys_text = KeyBindings.key_text(ROW_ACTIONS[start])
		h.add_child(_keys(keys_text, C_KEY))
		h.add_child(_keys(row[2], C_PAD))
		_list.add_child(line)


## Onglet « Personnaliser » : une touche du clavier par action, à changer d'un clic.
func _show_custom() -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(740, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 3)
	scroll.add_child(grid)
	for r in KeyBindings.REBINDABLE:
		var h := _row_box()
		var l := MenuKit.label(r[1], 12)
		l.custom_minimum_size.x = 200
		h.add_child(l)
		var b := MenuKit.button(KeyBindings.key_text(r[0]), 130, 12)
		b.custom_minimum_size.y = 26
		var action: String = r[0]
		b.pressed.connect(func():
			_listening = action
			b.text = "…appuie"
			_note.text = "Appuie sur la nouvelle touche pour « %s » (Échap : annuler)." % r[1])
		h.add_child(b)
		grid.add_child(h)
	_list.add_child(scroll)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	_note = MenuKit.label("Clique sur une touche pour la changer. La souris et la manette ne changent pas.", 11, MenuKit.C_DIM)
	_note.custom_minimum_size.x = 560
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.add_child(_note)
	var reset := MenuKit.button("Touches par défaut", 170, 12)
	reset.custom_minimum_size.y = 28
	reset.pressed.connect(func():
		KeyBindings.reset()
		SaveGame.options.keys = {}
		SaveGame.save_options()
		_show_page(PAGES.size()))
	foot.add_child(reset)
	_list.add_child(foot)


func _input(event: InputEvent) -> void:
	if _listening == "" or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	var action := _listening
	_listening = ""
	var k := event as InputEventKey
	if k.keycode == KEY_ESCAPE or k.physical_keycode == KEY_ESCAPE:
		_show_page(PAGES.size())
		return
	var code: int = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
	var others := KeyBindings.conflicts(code, action)
	KeyBindings.rebind(action, code)
	var keys: Dictionary = (SaveGame.options.get("keys", {}) as Dictionary).duplicate()
	keys[action] = code
	SaveGame.options.keys = keys
	SaveGame.save_options()
	Sound.ui("ui_click")
	_show_page(PAGES.size())
	if not others.is_empty():
		_note.text = "« %s » : %s. Attention, cette touche sert aussi à : %s." % [KeyBindings.label_of(action), KeyBindings.key_text(action), ", ".join(PackedStringArray(others))]
		_note.add_theme_color_override("font_color", MenuKit.C_BAD)
	else:
		_note.text = "« %s » : %s." % [KeyBindings.label_of(action), KeyBindings.key_text(action)]
		_note.add_theme_color_override("font_color", MenuKit.C_OK)


func close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
		var d := 1 if event.button_index == JOY_BUTTON_RIGHT_SHOULDER else -1
		var i := (_page + d + PAGES.size() + 1) % (PAGES.size() + 1)
		(_tabs.get_child(i) as Button).grab_focus()
		_show_page(i)
		get_viewport().set_input_as_handled()
