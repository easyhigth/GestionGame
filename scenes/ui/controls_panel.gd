class_name ControlsPanel
extends Control
## Fenêtre « Commandes » (menu pause et écran titre) : toutes les touches, rangées par thème,
## avec le clavier-souris et la manette côte à côte.

signal closed

const C_KEY := Color("3a2e28")
const C_PAD := Color("24303a")

## Onglets : [nom, [[action, touches], ...]] ; le 1er onglet est le plan illustré du clavier (voir KeyboardMap).
## Dans les touches, {action} devient la touche choisie par le joueur, « / » sépare des touches au choix.
## Le jeu se joue au clavier et à la souris (la manette marche aussi, avec ses boutons habituels).
const PAGES := [
	["Plan du clavier", []],
	["Se déplacer", [
		["Se déplacer (dans le sens de la caméra)", "{move_up} {move_left} {move_down} {move_right} / Flèches"],
		["Sauter (double saut avec le talent) · dans l'eau : remonter", "{jump}"],
		["Roulade : un bref instant invulnérable", "{dash} / Souris côté avant"],
		["Tourner la caméra", "Souris"],
		["Zoom de la caméra (objet en main : Ctrl + molette)", "Molette"],
		["Changer de vue : 3e personne · vue de dessus · 1re personne", "{camera_view}"],
		["Tourner la caméra en vue de dessus", "Clic molette maintenu"],
		["Libérer la souris pour cliquer à l'écran", "Alt maintenu"],
		["Menu pause · fermer la fenêtre ouverte", "Échap"],
	]],
	["Combattre", [
		["Frapper · maintenir pour une attaque chargée", "Clic gauche"],
		["Garde · parade si le coup arrive juste après", "Clic droit"],
		["Viser la cible la plus proche (encore : la suivante)", "{lock_on} / Clic molette"],
		["Compétences de la barre du bas", "1 … 0"],
		["Compétence unique (celle de l'histoire)", "{skill}"],
		["Boire une potion : soin si blessé, sinon renfort", "{potion} / Souris côté arrière"],
		["Manger (la meilleure nourriture du sac)", "{eat}"],
		["Estoc : frapper juste à la fin d'une roulade", "{dash} puis Clic gauche"],
		["Ordre aux familiers : suivre · attendre · attaquer", "{familiar_order}"],
	]],
	["Récolter et bâtir", [
		["Récolter (arbres, rochers, buissons) · casser un bloc", "Clic gauche"],
		["Creuser le sol devant soi (maintenir) · dans l'eau : plonger", "{dig}"],
		["Prendre l'objet d'une case de la barre de construction", "Ctrl + 1 … 0"],
		["Reprendre le dernier objet / revenir aux mains nues", "{hand_toggle}"],
		["Changer d'objet en main", "Molette"],
		["Poser, semer, labourer, pêcher (maintenu : en continu)", "Clic droit / {place_block}"],
		["Parler · recruter · quête · fiche d'un habitant", "{interact}"],
		["Ouvrir un coffre ou une barrière · monter · dormir la nuit", "{interact}"],
		["Mode construction : plans, murs, pièces prêtes", "{build_mode}"],
	]],
	["Menus", [
		["Inventaire : sac, équipement, artisanat", "{inventory} / Tab"],
		["Métiers d'artisanat", "{crafts}"],
		["Carte du monde · voyage rapide par les obélisques", "{world_map}"],
		["Journal : histoire et quêtes", "{journal}"],
		["Arbre de talents et compétences", "{talents}"],
		["Royaume : habitants, carte, production, expéditions", "{kingdom}"],
		["Diplomatie : nations voisines, traités, guerre", "{diplomacy}"],
		["Succès et bestiaire", "{achievements}"],
		["Aide-mémoire des touches à l'écran", "{keys_help}"],
		["Terminal de commandes (/aide)", "Entrée"],
		["Menu pause : sauvegarde, options, commandes", "Échap"],
	]],
	["Construction", [
		["Déplacer la caméra libre (Maj : plus vite)", "{move_up} {move_left} {move_down} {move_right}"],
		["Tourner la caméra", "A / E / Clic molette"],
		["Zoom", "Molette"],
		["Tracer un plan (glisser)", "Clic gauche"],
		["Annuler le tracé ou le plan visé", "Clic droit"],
		["Tourner le meuble", "R"],
		["Catégorie (8 : plans prêts)", "1 … 8"],
		["Niveau de travail", "Page ↑ / Page ↓"],
		["Hauteur des murs", "[ / ]"],
		["Couper au-dessus du niveau", "C"],
		["Quitter la construction", "{build_mode} / Échap"],
	]],
]

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
	var box := MenuKit.panel(self, 880)
	box.add_child(MenuKit.title("Commandes", 22))
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_tabs)
	for i in PAGES.size() + 1:
		var b := MenuKit.button(PAGES[i][0] if i < PAGES.size() else "Personnaliser", 116, 11)
		b.custom_minimum_size.y = 30
		b.pressed.connect(_show_page.bind(i))
		b.focus_entered.connect(func(): if _page != i: _show_page(i))
		_tabs.add_child(b)
	# en-tête des colonnes
	var sep := ColorRect.new()
	sep.color = Color(MenuKit.C_FRAME, 0.6)
	sep.custom_minimum_size = Vector2(0, 1)
	box.add_child(sep)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
	_list.custom_minimum_size = Vector2(0, 340)
	box.add_child(_list)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", 16)
	box.add_child(foot)
	foot.add_child(MenuKit.label("Chaque touche de menu referme aussi son menu · « Personnaliser » pour changer une touche", 10, MenuKit.C_DIM))
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
	h.custom_minimum_size.x = 300
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
	if i == 0:
		_show_keyboard()
		return
	var rows: Array = PAGES[i][1]
	for r in rows.size():
		var row: Array = rows[r]
		var line := PanelContainer.new()
		line.add_theme_stylebox_override("panel", MenuKit.style(Color(1, 1, 1, 0.04 if r % 2 == 0 else 0.0), Color(0, 0, 0, 0), 0, 3, 3))
		var h := _row_box()
		line.add_child(h)
		h.add_child(_cell(MenuKit.label(row[0], 12), 500))
		h.add_child(_keys(KeyBindings.fmt(row[1]), C_KEY))
		_list.add_child(line)


## 1er onglet : le clavier et la souris dessinés, chaque touche dans la couleur de sa famille.
func _show_keyboard() -> void:
	var km := KeyboardMap.new()
	_list.add_child(km)
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 14)
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	for f in KeyboardMap.FAMILIES:
		var sw := ColorRect.new()
		sw.color = f[1]
		sw.custom_minimum_size = Vector2(12, 12)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		legend.add_child(sw)
		legend.add_child(MenuKit.label(f[0], 11, MenuKit.C_TEXT))
	_list.add_child(legend)
	var tip := MenuKit.label("La main gauche reste sur {move_up} {move_left} {move_down} {move_right} : tout ce qui sert en combat est autour. Les menus sont à droite, sous leur initiale (Carte, Journal, Talents...).", 10, MenuKit.C_DIM)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_list.add_child(tip)


## Onglet « Personnaliser » : une touche du clavier par action, à changer d'un clic.
func _show_custom() -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(840, 300)
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
	_note = MenuKit.label("Clique sur une touche pour la changer. La souris garde ses boutons.", 11, MenuKit.C_DIM)
	_note.custom_minimum_size.x = 660
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
