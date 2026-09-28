extends CanvasLayer
## Interface de base : aide aux commandes, graine du monde, race jouée.
## Touche R : changer de race pour tester les personnages.

@export var world: WorldGenerator
@export var player: Player
@export var races: Array[RaceData] = []

@onready var info: Label = $Info
var _race_index := 0


func _ready() -> void:
	if world:
		world.world_generated.connect(func(_s): _refresh())
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("new_world") and world:
		world.generate(randi())
	elif event.is_action_pressed("next_race") and player and not races.is_empty():
		_race_index = (_race_index + 1) % races.size()
		player.apply_race(races[_race_index])
		_refresh()


func _refresh() -> void:
	var race_name: String = player.race.display_name if player and player.race else "?"
	var seed_value: int = world.world_seed if world else 0
	info.text = "ZQSD / Flèches : bouger   Espace : roulade   R : changer de race   N : nouveau monde\nRace : %s     Graine du monde : %d" % [race_name, seed_value]
