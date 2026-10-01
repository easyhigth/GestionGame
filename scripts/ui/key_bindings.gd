class_name KeyBindings
extends RefCounted
## Touches du clavier configurables (fenêtre Commandes → « Personnaliser »).
## Seule la touche du clavier d'une action change : la souris et la manette gardent les leurs.
## Les touches choisies sont gardées dans les options (user://options.cfg, clé « keys » : action -> code physique).

## Actions modifiables : [action, nom affiché].
const REBINDABLE := [
	["move_up", "Avancer"], ["move_down", "Reculer"], ["move_left", "Aller à gauche"], ["move_right", "Aller à droite"],
	["jump", "Sauter"], ["dash", "Roulade"], ["attack", "Frapper"], ["block", "Garde"], ["lock_on", "Viser"],
	["skill", "Compétence unique"], ["ability_1", "Emplacement 1"], ["ability_2", "Emplacement 2"],
	["ability_3", "Emplacement 3"], ["ability_4", "Emplacement 4"],
	["interact", "Parler / utiliser"], ["dig", "Creuser · plonger"], ["place_block", "Poser · semer"],
	["hotbar_next", "Objet en main suivant"], ["eat", "Manger"], ["potion", "Boire une potion"],
	["inventory", "Inventaire"], ["world_map", "Carte"], ["build_mode", "Construction"], ["kingdom", "Royaume"],
	["talents", "Talents"], ["journal", "Journal"], ["familiar_order", "Ordre aux familiers"],
	["diplomacy", "Diplomatie"], ["achievements", "Succès et bestiaire"], ["keys_help", "Aide-mémoire des touches"],
]


static func label_of(action: String) -> String:
	for r in REBINDABLE:
		if r[0] == action:
			return r[1]
	return action


## Nom de la première touche du clavier de l'action (ou du bouton de souris s'il n'y en a pas).
static func key_text(action: String) -> String:
	if not InputMap.has_action(action):
		return "—"
	var mouse := ""
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			return key_name(e)
		if e is InputEventMouseButton and mouse == "":
			mouse = {MOUSE_BUTTON_LEFT: "Clic gauche", MOUSE_BUTTON_RIGHT: "Clic droit", MOUSE_BUTTON_MIDDLE: "Clic molette"}.get(e.button_index, "Souris")
	return mouse if mouse != "" else "—"


static func key_name(e: InputEventKey) -> String:
	var code: int = e.physical_keycode if e.physical_keycode != KEY_NONE else e.keycode
	# la touche affichée selon la disposition du clavier du joueur (AZERTY, QWERTY...)
	var shown: int = DisplayServer.keyboard_get_keycode_from_physical(code) if e.physical_keycode != KEY_NONE else code
	var n := OS.get_keycode_string(shown)
	return {"Space": "Espace", "Shift": "Maj", "Escape": "Échap", "Enter": "Entrée", "Up": "↑", "Down": "↓",
		"Left": "←", "Right": "→", "BackSpace": "Retour arrière"}.get(n, n)


## Actions qui utilisent déjà cette touche physique (sauf `except`).
static func conflicts(physical: int, except := "") -> Array:
	var out := []
	for r in REBINDABLE:
		if r[0] == except or not InputMap.has_action(r[0]):
			continue
		for e in InputMap.action_get_events(r[0]):
			if e is InputEventKey and (e.physical_keycode == physical or (e.physical_keycode == KEY_NONE and e.keycode == physical)):
				out.append(r[1])
	return out


## Donne une nouvelle touche (code physique) à l'action ; ses autres touches du clavier sont retirées.
static func rebind(action: String, physical: int) -> void:
	if not InputMap.has_action(action):
		return
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			InputMap.action_erase_event(action, e)
	var k := InputEventKey.new()
	k.physical_keycode = physical as Key
	InputMap.action_add_event(action, k)


## Applique les touches gardées dans les options.
static func apply(saved: Dictionary) -> void:
	for action in saved:
		var code := int(saved[action])
		if code > 0 and InputMap.has_action(str(action)):
			rebind(str(action), code)


## Remet toutes les touches par défaut.
static func reset() -> void:
	InputMap.load_from_project_settings()
