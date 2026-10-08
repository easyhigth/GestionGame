class_name Townsfolk
extends Node3D
## Habitant d'une ville ou d'un château : léger (pas de besoins ni de combat), il flâne dans les rues,
## les gardes font leur ronde, les marchands restent à leur étal. E : il parle (un marchand ouvre sa boutique).
## Les villes n'en animent que quelques dizaines autour du héros ; les autres sont seulement comptés.

const SPEED := 1.5
const ACTIVE_DISTANCE := 70.0
const CITIZEN_JOBS := ["fermier", "fermier", "mineur", "chasseur", "forgeron", "mage"]

var race: RaceData
var kit: Array = []
var display_name := ""
## « citizen », « guard », « merchant », « lord », « innkeeper » (aubergiste).
var role := "citizen"
var lines: Array = []
var home := Vector3.ZERO
var wander := 6.0
## Marchand : sa boutique (voir CityMerchant) et son métier affiché.
var shop: CityMerchant
var trade_name := ""
## Quête de citadin (voir CityLife) : sa clé, et la marque au-dessus de lui (« ! » offre, « ? » à rendre).
var quest_key := ""
## Voyageurs des routes (voir RoadLife) : les points à suivre, dans l'ordre.
var route: Array = []
var _mark: Label3D
var color := Color(0.95, 0.9, 0.8)
var visual: VoxelCharacter
var _target := Vector3.INF
var _wait := 0.0
var _facing := Vector3(0, 0, 1)
var _label: Label3D
var _bubble: Label3D
var _bubble_left := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("townsfolk")
	_rng.seed = hash(name) ^ int(home.x * 31.0 + home.z)
	visual = VoxelCharacter.new()
	visual.name = "Visual"
	add_child(visual)
	var dressed: PackedScene = null
	if race:
		visual.set_equipment_library(race.equipment)
		var variant := _rng.randi() % maxi(race.villager_models.size(), 1)
		dressed = race.job_model(_job(), variant)
		if dressed:
			visual.set_model(dressed)
		else:
			visual.set_model(race.villager_models[variant] if not race.villager_models.is_empty() else race.model)
	for id in kit:
		var it := Items.get_item(id) as ItemData
		# la tenue de métier porte déjà son casque, son armure et son outil : seule la cape s'ajoute
		if it and (dressed == null or it.slot == ItemData.Slot.BACK):
			visual.show_equipment(it.slot, it.model_id())
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 28
	_label.pixel_size = 0.006
	_label.outline_size = 8
	_label.position.y = 2.55
	_label.text = display_name + ("\n" + trade_name if trade_name != "" else "")
	_label.modulate = color
	_label.visible = false
	add_child(_label)
	_bubble = Label3D.new()
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.font_size = 30
	_bubble.pixel_size = 0.006
	_bubble.outline_size = 8
	_bubble.position.y = 3.15
	_bubble.modulate = Color("fff2c8")
	_bubble.visible = false
	add_child(_bubble)
	_mark = Label3D.new()
	_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_mark.font_size = 64
	_mark.pixel_size = 0.01
	_mark.outline_size = 12
	_mark.position.y = 3.0
	_mark.visible = false
	add_child(_mark)
	_wait = _rng.randf_range(0.0, 3.0)


## Métier dont il porte la tenue (« » : habits de base). Un citadin sur deux exerce un métier des champs, de la mine ou de la forge.
func _job() -> String:
	match role:
		"guard": return "garde"
		"merchant": return "marchand"
		"innkeeper": return "aubergiste"
		"citizen":
			if kit.is_empty() and _rng.randf() < 0.5:
				return CITIZEN_JOBS[_rng.randi() % CITIZEN_JOBS.size()]
	return ""


## Marque au-dessus de la tête (« » : aucune).
func set_mark(text: String, col := Color("ffd24a")) -> void:
	if _mark == null:
		return
	_mark.text = text
	_mark.modulate = col
	_mark.visible = text != ""


func _world() -> WorldGenerator:
	return get_tree().get_first_node_in_group("world") as WorldGenerator


func _process(delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return
	var d := global_position.distance_to(p.global_position)
	if d > ACTIVE_DISTANCE:
		return
	_label.visible = d < 9.0
	if _bubble_left > 0.0:
		_bubble_left -= delta
		if _bubble_left <= 0.0:
			_bubble.visible = false
	var w := _world()
	if w == null:
		return
	var vel := Vector3.ZERO
	if not route.is_empty():
		# en voyage : il suit la route
		var tgt: Vector3 = route[0]
		var dir := tgt - global_position
		dir.y = 0.0
		if dir.length() < 0.6:
			route.pop_front()
			if route.is_empty():
				home = global_position
		else:
			dir = dir.normalized()
			var moved := w.constrain_move(global_position, global_position + dir * SPEED * delta)
			moved.y = w.support_height(moved, global_position.y + 0.6)
			if moved.distance_to(global_position) < SPEED * delta * 0.2:
				route.pop_front()    # bloqué : on vise le point suivant
			global_position = moved
			_facing = dir
			vel = dir * SPEED
	elif role == "merchant" or role == "lord" or role == "innkeeper" or quest_key != "":
		# il reste à sa place et regarde le héros quand il approche
		if d < 6.0:
			var to := p.global_position - global_position
			to.y = 0.0
			if to.length() > 0.1:
				_facing = to.normalized()
	elif _wait > 0.0:
		_wait -= delta
	else:
		if _target == Vector3.INF or Vector2(_target.x - global_position.x, _target.z - global_position.z).length() < 0.4:
			_pick_target(w)
		else:
			var dir := _target - global_position
			dir.y = 0.0
			dir = dir.normalized()
			var next := global_position + dir * SPEED * delta
			var moved := w.constrain_move(global_position, next)
			if moved.distance_to(global_position) < SPEED * delta * 0.3:
				# bloqué : il change d'idée
				_target = Vector3.INF
				_wait = _rng.randf_range(0.5, 1.5)
			else:
				moved.y = w.support_height(moved, global_position.y + 0.6)
				global_position = moved
				_facing = dir
				vel = dir * SPEED
	visual.animate(delta, vel, _facing)


func _pick_target(w: WorldGenerator) -> void:
	_wait = _rng.randf_range(1.5, 5.0) if role == "citizen" else _rng.randf_range(0.5, 2.0)
	for i in 6:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(1.5, wander)
		var t := home + Vector3(cos(a), 0, sin(a)) * r
		if w.is_walkable(t):
			_target = t
			return
	_target = home


## E : il parle (et un marchand montre ses marchandises).
func talk(p: Player) -> void:
	var cl := get_tree().get_first_node_in_group("city_life")
	if (role == "innkeeper" or quest_key != "") and cl:
		var to2 := p.global_position - global_position
		to2.y = 0.0
		if to2.length() > 0.1:
			_facing = to2.normalized()
		say(cl.inn(p, self) if role == "innkeeper" else cl.quest_talk(p, self))
		return
	if not lines.is_empty():
		_bubble.text = str(lines[_rng.randi() % lines.size()])
		_bubble.visible = true
		_bubble_left = 4.0
	var to := p.global_position - global_position
	to.y = 0.0
	if to.length() > 0.1:
		_facing = to.normalized()
	if role == "merchant" and shop:
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("open_city_shop"):
			hud.open_city_shop(self)


## Une bulle de paroles au-dessus de lui.
func say(text: String) -> void:
	if text == "":
		return
	_bubble.text = text
	_bubble.visible = true
	_bubble_left = 5.0


## L'habitant le plus proche du héros (à moins de 2,2 m), ou null.
static func nearest(p: Player) -> Townsfolk:
	var best: Townsfolk = null
	var bd := 2.2
	for t in p.get_tree().get_nodes_in_group("townsfolk"):
		var d: float = (t as Node3D).global_position.distance_to(p.global_position)
		if d < bd:
			bd = d
			best = t
	return best
