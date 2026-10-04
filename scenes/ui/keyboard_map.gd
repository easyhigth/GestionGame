class_name KeyboardMap
extends Control
## Plan illustré du clavier et de la souris (fenêtre Commandes, 1er onglet) : chaque touche utilisée est
## coloriée selon sa famille (se déplacer, combattre, agir dans le monde, menus) avec son rôle écrit dessus.
## Les lettres suivent le clavier du joueur (AZERTY, QWERTY...) et ses touches personnalisées.

const U := 34.0          # largeur d'une touche simple
const GAP := 3.0
const FAMILIES := [
	["Se déplacer", Color("5fb86a")],
	["Combattre", Color("d9604a")],
	["Agir dans le monde", Color("e0b040")],
	["Menus", Color("5a8fd8")],
	["Système", Color("9a8a7a")],
]

## Action -> [nom court sur la touche, famille].
const ROLES := {
	"move_up": ["Avancer", 0], "move_down": ["Reculer", 0], "move_left": ["Gauche", 0], "move_right": ["Droite", 0],
	"jump": ["Sauter", 0], "dash": ["Roulade", 0],
	"skill": ["Unique", 1], "lock_on": ["Viser", 1], "potion": ["Potion", 1],
	"ability_1": ["Sort 1", 1], "ability_2": ["Sort 2", 1], "ability_3": ["Sort 3", 1], "ability_4": ["Sort 4", 1],
	"ability_5": ["Sort 5", 1], "ability_6": ["Sort 6", 1], "ability_7": ["Sort 7", 1], "ability_8": ["Sort 8", 1],
	"ability_9": ["Sort 9", 1], "ability_10": ["Sort 10", 1],
	"interact": ["Utiliser", 2], "dig": ["Creuser", 2], "place_block": ["Poser", 2], "hand_toggle": ["En main", 2],
	"eat": ["Manger", 2],
	"inventory": ["Sac", 3], "world_map": ["Carte", 3], "journal": ["Journal", 3], "talents": ["Talents", 3],
	"kingdom": ["Royaume", 3], "diplomacy": ["Nations", 3], "familiar_order": ["Familiers", 3], "build_mode": ["Bâtir", 3],
	"achievements": ["Succès", 3], "crafts": ["Métiers", 3],
	"pause": ["Menu", 4], "keys_help": ["Aide", 4], "camera_view": ["Vue", 4],
}

## Rangées du clavier (codes physiques) ; [code, largeur en touches].
const ROWS := [
	[[KEY_ESCAPE, 1.0], [0, 0.5], [KEY_F1, 1.0], [KEY_F2, 1.0], [KEY_F3, 1.0], [KEY_F4, 1.0], [0, 0.3], [KEY_F5, 1.0], [KEY_F6, 1.0], [KEY_F7, 1.0], [KEY_F8, 1.0]],
	[[KEY_QUOTELEFT, 1.0], [KEY_1, 1.0], [KEY_2, 1.0], [KEY_3, 1.0], [KEY_4, 1.0], [KEY_5, 1.0], [KEY_6, 1.0], [KEY_7, 1.0], [KEY_8, 1.0], [KEY_9, 1.0], [KEY_0, 1.0], [KEY_MINUS, 1.0], [KEY_EQUAL, 1.0]],
	[[KEY_TAB, 1.5], [KEY_Q, 1.0], [KEY_W, 1.0], [KEY_E, 1.0], [KEY_R, 1.0], [KEY_T, 1.0], [KEY_Y, 1.0], [KEY_U, 1.0], [KEY_I, 1.0], [KEY_O, 1.0], [KEY_P, 1.0], [KEY_BRACKETLEFT, 1.0], [KEY_BRACKETRIGHT, 1.0]],
	[[KEY_CAPSLOCK, 1.8], [KEY_A, 1.0], [KEY_S, 1.0], [KEY_D, 1.0], [KEY_F, 1.0], [KEY_G, 1.0], [KEY_H, 1.0], [KEY_J, 1.0], [KEY_K, 1.0], [KEY_L, 1.0], [KEY_SEMICOLON, 1.0], [KEY_APOSTROPHE, 1.0], [KEY_ENTER, 1.7]],
	[[KEY_SHIFT, 2.3], [KEY_Z, 1.0], [KEY_X, 1.0], [KEY_C, 1.0], [KEY_V, 1.0], [KEY_B, 1.0], [KEY_N, 1.0], [KEY_M, 1.0], [KEY_COMMA, 1.0], [KEY_PERIOD, 1.0], [KEY_SLASH, 1.0]],
	[[KEY_CTRL, 1.5], [0, 0.2], [KEY_ALT, 1.3], [KEY_SPACE, 6.0], [0, 0.3], [KEY_LEFT, 1.0], [KEY_UP, 1.0], [KEY_DOWN, 1.0], [KEY_RIGHT, 1.0]],
]

## Touches sans action de l'InputMap, mais utiles : code physique -> [nom, famille].
const EXTRA_KEYS := {KEY_CTRL: ["+chiffre : bloc", 2], KEY_ALT: ["Souris libre", 4], KEY_ENTER: ["Terminal", 4]}

var _font: Font
## code physique -> [nom, famille]
var _roles := {}


func _ready() -> void:
	_font = UiTheme.font("bold")
	custom_minimum_size = Vector2(14.6 * (U + GAP) + 290, 6 * (U + GAP) + 10)
	refresh()


## Relit les touches (après une personnalisation).
func refresh() -> void:
	_roles = {}
	for code in EXTRA_KEYS:
		_roles[code] = EXTRA_KEYS[code]
	for action in ROLES:
		if not InputMap.has_action(action):
			continue
		for e in InputMap.action_get_events(action):
			if e is InputEventKey:
				var code := _physical_of(e)
				if code != 0 and not _roles.has(code):
					_roles[code] = ROLES[action]
	queue_redraw()


## Position physique d'une touche, même si l'action est réglée sur une lettre (la carte M d'un clavier AZERTY...).
static func _physical_of(e: InputEventKey) -> int:
	if e.physical_keycode != KEY_NONE:
		return e.physical_keycode
	for row in ROWS:
		for k in row:
			var code: int = k[0]
			if code != 0 and DisplayServer.keyboard_get_keycode_from_physical(code) == e.keycode:
				return code
	return e.keycode


static func cap_text(code: int) -> String:
	var n := OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(code))
	if n.begins_with("Kp "):
		n = n.substr(3)
	if n.length() <= 1:
		return n
	return {"Escape": "Échap", "Shift": "Maj", "Ctrl": "Ctrl", "Space": "Espace", "Enter": "Entrée", "CapsLock": "Verr",
		"Up": "↑", "Down": "↓", "Left": "←", "Right": "→", "QuoteLeft": "`", "Minus": "-", "Equal": "=",
		"BracketLeft": "[", "BracketRight": "]", "Semicolon": ";", "Apostrophe": "'", "Comma": ",", "Period": ".",
		"Slash": "/", "Twosuperior": "²", "Parenright": ")", "Asciicircum": "^", "Dollar": "$", "Ugrave": "ù",
		"Colon": ":", "Exclam": "!", "Asterisk": "*", "Less": "<"}.get(n, n)


func _draw() -> void:
	var y := 0.0
	for r in ROWS.size():
		var x := 0.0
		var h := U * (0.7 if r == 0 else 1.0)
		for k in ROWS[r]:
			var code: int = k[0]
			var w: float = float(k[1]) * U + (float(k[1]) - 1.0) * GAP
			if code != 0:
				_draw_key(Rect2(x, y, w, h), code)
			x += w + GAP
		y += h + GAP + (6.0 if r == 0 else 0.0)
	_draw_mouse(Vector2(14.6 * (U + GAP) + 6, 0))


func _draw_key(rr: Rect2, code: int) -> void:
	var role: Array = _roles.get(code, [])
	var col: Color = FAMILIES[role[1]][1] if not role.is_empty() else Color("3a302a")
	var top := col if not role.is_empty() else Color("4a3e36")
	# socle et dessus de la touche (relief)
	draw_rect(Rect2(rr.position + Vector2(0, 3), rr.size), top.darkened(0.55))
	draw_rect(rr, top.darkened(0.15) if not role.is_empty() else top)
	draw_rect(Rect2(rr.position + Vector2(2, 2), rr.size - Vector2(4, 6)), top if not role.is_empty() else top.lightened(0.05))
	draw_rect(rr, Color(0, 0, 0, 0.5), false, 1.0)
	var lab := cap_text(code)
	var fs := 13 if lab.length() <= 2 else 10
	var tc := Color("1a1410") if not role.is_empty() else Color("a89880")
	draw_string(_font, rr.position + Vector2(5, 13), lab, HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 6, fs, tc)
	if not role.is_empty():
		var name: String = role[0]
		var nfs := 8 if name.length() <= 8 or rr.size.x > U * 1.5 else 7
		draw_string(_font, Vector2(rr.position.x + 2, rr.end.y - 6), name, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x - 4, nfs, Color("1a1410"))


## La souris, avec le rôle de chaque bouton (une pastille de la couleur du bouton devant chaque texte).
func _draw_mouse(o: Vector2) -> void:
	var body := Rect2(o + Vector2(0, 6), Vector2(54, 92))
	draw_rect(Rect2(body.position + Vector2(0, 3), body.size), Color("2a221c"))
	draw_rect(body, Color("4a3e36"))
	var lb := Rect2(body.position, Vector2(26, 38))
	var rb := Rect2(body.position + Vector2(28, 0), Vector2(26, 38))
	draw_rect(lb, FAMILIES[1][1])
	draw_rect(rb, FAMILIES[2][1])
	var wheel := Rect2(body.position + Vector2(23, 8), Vector2(8, 18))
	draw_rect(wheel, FAMILIES[4][1].lightened(0.3))
	draw_rect(Rect2(body.position + Vector2(-4, 46), Vector2(4, 12)), FAMILIES[0][1])
	draw_rect(Rect2(body.position + Vector2(-4, 62), Vector2(4, 12)), FAMILIES[1][1])
	draw_rect(body, Color(0, 0, 0, 0.5), false, 1.0)
	draw_string(_font, body.position + Vector2(6, 26), "G", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("1a1410"))
	draw_string(_font, body.position + Vector2(40, 26), "D", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("1a1410"))
	var x := o.x + 64
	var lines := [
		[FAMILIES[1][1], "Clic gauche : frapper, récolter,", "casser un bloc (maintenir : charger)"],
		[FAMILIES[2][1], "Clic droit : garde (parade)", "objet en main : le poser"],
		[FAMILIES[4][1], "Molette : zoom", "objet en main : changer d'objet"],
		[FAMILIES[4][1], "Clic molette : viser la cible", "maintenu : tourner la caméra"],
		[FAMILIES[0][1], "Bouton de côté avant : roulade", "arrière : boire une potion"],
	]
	for i in lines.size():
		var yy := o.y + 4 + i * 44
		draw_rect(Rect2(x, yy + 3, 8, 8), lines[i][0])
		draw_string(_font, Vector2(x + 12, yy + 11), lines[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("e8dcc0"))
		draw_string(_font, Vector2(x + 12, yy + 24), lines[i][2], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("a89880"))
