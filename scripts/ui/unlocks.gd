extends Node
## Autoload « Unlocks » : les menus avancés se débloquent au fil de la partie, pour ne pas noyer
## le joueur au départ. Talents (T) au niveau 2, Royaume (U), qui ouvre aussi la diplomatie et les
## expéditions, dès qu'il a un abri ou un habitant. Seul le départ à mains nues est concerné
## (GameState.bare_start), et l'option « menus progressifs » peut tout ouvrir d'emblée.
## Une partie déjà avancée a tout d'office : les conditions se lisent dans l'état du jeu.

## action -> [nom du menu, indication affichée quand il est verrouillé]
const MENUS := {
	"talents": ["Talents", "Atteins le niveau 2"],
	"kingdom": ["Royaume", "Construis un abri ou accueille un habitant"],
}

var _open := {}
var _timer := 0.0
var _age := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func active() -> bool:
	return GameState.bare_start and bool(SaveGame.options.get("progressive_menus", true))


func _player() -> Node:
	return get_tree().get_first_node_in_group("player")


func _villagers() -> int:
	return get_tree().get_nodes_in_group("villagers").size()


func _guide_past(id: String) -> bool:
	var g := get_tree().get_first_node_in_group("guide")
	if g == null:
		return false
	if g.is_done():
		return true
	for i in g.STEPS.size():
		if g.STEPS[i][0] == id:
			return g.step > i
	return false


func _condition(action: String) -> bool:
	var p := _player()
	if p == null:
		return false
	match action:
		"talents":
			return int(p.level) >= 2 or _guide_past("nuit")
		"kingdom":
			return _villagers() > 0 or _guide_past("abri")
	return true


## Le menu de cette action est-il ouvert ? Sinon, dit au joueur comment le débloquer.
func allowed(action: String, tell := true) -> bool:
	if not MENUS.has(action) or not active() or _open.get(action, false):
		return true
	if _condition(action):
		_open[action] = true
		return true
	if tell:
		var p := _player()
		if p:
			p.notify.emit("%s (%s) : se débloque bientôt. %s." % [MENUS[action][0], KeyBindings.fmt("{%s}" % action), MENUS[action][1]])
	return false


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or not active():
		return
	_timer = 1.0
	var p := _player()
	if p == null:
		_age = 0.0
		return
	_age += 1.0
	for a in MENUS:
		if _open.get(a, false):
			continue
		if _condition(a):
			_open[a] = true
			# pendant les premières secondes (chargement d'une partie), ce qui est déjà ouvert l'est en silence
			if _age > 6.0:
				p.feat.emit("Nouveau menu : %s (%s)" % [MENUS[a][0], KeyBindings.fmt("{%s}" % a)], Color("ffd24a"))
				Sound.ui("pickup")


func reset() -> void:
	_open.clear()
	_age = 0.0
