class_name EnemyCamp
extends Node3D
## Camp de monstres : fait apparaître un groupe de monstres autour de lui,
## et le fait réapparaître quand tout le groupe a été vaincu (si le joueur est loin).

@export var enemy_scene: PackedScene = preload("res://scenes/enemies/enemy.tscn")
## Types de monstres du camp (un est tiré au hasard pour chaque monstre).
@export var enemy_types: Array[EnemyData] = []
@export var count: int = 3
## Rayon (en mètres) dans lequel les monstres apparaissent.
@export var radius: float = 2.5
## Temps avant que le camp se repeuple (secondes).
@export var respawn_time: float = 120.0
## Le camp ne se repeuple pas si le joueur est plus près que ça.
@export var min_player_distance: float = 30.0

var _alive: Array[Enemy] = []
var _timer := 0.0


func _ready() -> void:
	add_to_group("enemy_camps")
	spawn_group.call_deferred()


func spawn_group() -> void:
	if enemy_types.is_empty() or enemy_scene == null:
		return
	var world := get_tree().get_first_node_in_group("world") as WorldGenerator
	for i in count:
		var e := enemy_scene.instantiate() as Enemy
		e.data = enemy_types.pick_random()
		var a := TAU * float(i) / float(count) + randf() * 0.6
		var pos := global_position + Vector3(cos(a), 0, sin(a)) * randf_range(0.6, radius)
		if world and not world.is_walkable(pos):
			pos = global_position
		get_parent().add_child(e)
		e.global_position = Vector3(pos.x, world.ground_height_at(pos) if world else pos.y, pos.z)
		e.home = e.global_position
		_alive.append(e)
		e.tree_exited.connect(_on_enemy_gone.bind(e))


func _on_enemy_gone(e: Enemy) -> void:
	_alive.erase(e)
	if _alive.is_empty():
		_timer = respawn_time


func _process(delta: float) -> void:
	if not _alive.is_empty() or _timer <= 0.0:
		return
	_timer -= delta
	if _timer <= 0.0:
		var player := get_tree().get_first_node_in_group("player") as Node3D
		if player and player.global_position.distance_to(global_position) < min_player_distance:
			_timer = 5.0
		else:
			spawn_group()
