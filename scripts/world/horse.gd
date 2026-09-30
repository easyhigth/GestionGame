class_name Horse
extends FarmAnimal
## Cheval : sauvage dans les prés, il suit le héros qui tient des carottes (C). E près de lui avec des
## carottes en main : il en mange une ; au bout de 3, il est apprivoisé (il porte une selle).
## Apprivoisé : E pour monter (on va bien plus vite), E pour descendre. Il ne va pas dans l'eau.

const INFO := {"name": "Cheval", "plural": "chevaux", "models": ["horse_brown", "horse_white", "horse_black"],
	"food": "carotte", "product": "", "every": 0.0, "feed": 0.0, "speed": 2.2, "label_y": 2.2}
## Carottes pour l'apprivoiser.
const TAME_CARROTS := 3
## Vitesse du héros à cheval (multiplicateur).
const RIDE_SPEED := 1.9
## Hauteur de la selle.
const SADDLE_Y := 1.05

var tamed := false
var trust := 0
var ridden := false


func setup(_sp: String, index := -1) -> void:
	species = "cheval"
	model_index = index if index >= 0 else randi() % 3


func info() -> Dictionary:
	return INFO


func _ready() -> void:
	super()
	remove_from_group("farm_animals")
	add_to_group("horses")
	domestic = tamed
	_refresh_model()


func _refresh_model() -> void:
	var names: Array = INFO.models
	var id: String = names[clampi(model_index, 0, names.size() - 1)] + ("_saddle" if tamed else "")
	var scene := load("res://assets/characters/creatures/%s.glb" % id) as PackedScene
	if scene:
		visual.set_model(scene)


## Une carotte donnée : il fait un peu plus confiance. Vrai s'il est apprivoisé.
func feed() -> bool:
	trust += 1
	_heart = 1.5
	if trust >= TAME_CARROTS:
		tamed = true
		domestic = true
		following = false
		home = global_position
		_refresh_model()
		return true
	return false


## Un cheval apprivoisé ne suit plus les carottes (on le monte).
func _lured_by(p: Player) -> bool:
	return not tamed and super(p)


func _process(delta: float) -> void:
	if ridden:
		# le héros le dirige : Mounts le place sous lui
		label.visible = false
		return
	if tamed:
		# apprivoisé : il attend là où on l'a laissé, en broutant
		following = false
		domestic = true
	super(delta)


func _update_label(d: float, p: Player, delta: float) -> void:
	super(d, p, delta)
	if not label.visible or _heart > 0.0 and d >= 6.0:
		return
	if tamed:
		label.text = "Cheval · à toi\n[E] Monter"
		label.modulate = Color("ffe8b0")
	elif following:
		label.text = "Cheval sauvage · confiance %d / %d\n[E] Donner une carotte" % [trust, TAME_CARROTS]
	else:
		label.text = "Cheval sauvage\nChoisis des carottes (C) pour l'approcher"


func export_state() -> Dictionary:
	return {"m": model_index, "pos": [global_position.x, global_position.y, global_position.z]}
