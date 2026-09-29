extends CanvasLayer
## Interface de base : aide aux commandes, graine du monde, race jouée, messages.
## Touche R : changer de race pour tester les personnages.

@export var world: WorldGenerator
@export var player: Player
@export var races: Array[RaceData] = []
## Durée d'affichage d'un message (secondes).
@export var message_time: float = 3.0

@onready var info: Label = $Info
var _race_index := 0
var _messages: VBoxContainer


func _ready() -> void:
	_messages = VBoxContainer.new()
	_messages.position = Vector2(10, 470)
	_messages.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_messages.alignment = BoxContainer.ALIGNMENT_END
	_messages.custom_minimum_size = Vector2(400, 0)
	_messages.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_messages.offset_left = 10
	_messages.offset_bottom = -10
	add_child(_messages)
	if world:
		world.world_generated.connect(func(_s): _refresh())
	if player:
		player.notify.connect(show_message)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if player and player.ui_open:
		return
	if event.is_action_pressed("new_world") and world:
		world.generate(randi())
	elif event.is_action_pressed("next_race") and player and not races.is_empty():
		_race_index = (_race_index + 1) % races.size()
		player.apply_race(races[_race_index])
		_refresh()


func show_message(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color("fff2c8"))
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1))
	l.add_theme_constant_override("outline_size", 4)
	_messages.add_child(l)
	while _messages.get_child_count() > 5:
		_messages.get_child(0).free()
	var tw := l.create_tween()
	tw.tween_interval(message_time)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func _refresh() -> void:
	var race_name: String = player.race.display_name if player and player.race else "?"
	var seed_value: int = world.world_seed if world else 0
	info.text = "ZQSD : bouger   Espace : roulade   Clic / J : frapper   I : inventaire   E : équiper un habitant   R : race   N : nouveau monde\nRace : %s     Graine du monde : %d" % [race_name, seed_value]
