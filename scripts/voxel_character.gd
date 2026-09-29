class_name VoxelCharacter
extends Node3D
## Affiche un personnage voxel (.glb) et l'anime sans AnimationPlayer :
## marche (bras et jambes qui balancent), respiration au repos, roulade.
## Les modèles doivent avoir les nœuds Root > LegL, LegR, Torso > ArmL, ArmR, Head.

## Modèle affiché (fichier .glb de assets/characters/models/).
@export var model: PackedScene:
	set = set_model
## Vitesse à laquelle le personnage se tourne vers sa direction.
@export var turn_speed: float = 14.0
## Amplitude du balancement des bras et des jambes (radians).
@export var walk_swing: float = 0.65
## Hauteur du centre de la roulade (le personnage tourne autour de ce point).
@export var roll_pivot_height: float = 0.8

var _pivot: Node3D
var _instance: Node3D
var _limbs := {}
var _rest := {}
var _phase := randf() * TAU
var _idle_t := randf() * TAU
var _roll_left := 0.0
var _roll_duration := 0.0


func _ready() -> void:
	_ensure_pivot()
	if model and _instance == null:
		set_model(model)


func _ensure_pivot() -> void:
	if _pivot == null:
		_pivot = Node3D.new()
		_pivot.name = "Pivot"
		_pivot.position.y = roll_pivot_height
		add_child(_pivot)


func set_model(scene: PackedScene) -> void:
	model = scene
	if not is_inside_tree():
		return
	_ensure_pivot()
	if _instance:
		_instance.queue_free()
		_instance = null
	_limbs.clear()
	_rest.clear()
	if scene == null:
		return
	_instance = scene.instantiate() as Node3D
	_instance.position.y = -roll_pivot_height
	_pivot.add_child(_instance)
	for n in ["LegL", "LegR", "ArmL", "ArmR", "Head", "Torso", "Root"]:
		var node := _instance.find_child(n, true, false) as Node3D
		if node:
			_limbs[n] = node
			_rest[n] = node.transform


## À appeler chaque image. `velocity` : déplacement actuel, `facing` : direction regardée.
func animate(delta: float, velocity: Vector3, facing: Vector3) -> void:
	if _instance == null:
		return
	var flat := Vector2(facing.x, facing.z)
	if flat.length_squared() > 0.0001:
		rotation.y = lerp_angle(rotation.y, atan2(flat.x, flat.y), clampf(turn_speed * delta, 0.0, 1.0))

	var speed := Vector2(velocity.x, velocity.z).length()
	var walk := clampf(speed / 3.0, 0.0, 1.0)
	_phase += delta * (3.0 + speed * 2.2)
	_idle_t += delta
	var s := sin(_phase) * walk_swing * walk
	_swing("LegL", s)
	_swing("LegR", -s)
	_swing("ArmL", -s * 0.8)
	_swing("ArmR", s * 0.8)
	var breath := sin(_idle_t * 2.0) * 0.012 * (1.0 - walk)
	var bob := absf(sin(_phase)) * 0.06 * walk
	_instance.position.y = -roll_pivot_height + bob
	if _limbs.has("Torso"):
		(_limbs["Torso"] as Node3D).position = (_rest["Torso"] as Transform3D).origin + Vector3(0, breath, 0)
	if _limbs.has("Head"):
		var head := _limbs["Head"] as Node3D
		head.transform = (_rest["Head"] as Transform3D).rotated_local(Vector3.UP, sin(_idle_t * 0.7) * 0.15 * (1.0 - walk))

	if _roll_left > 0.0:
		_roll_left = maxf(_roll_left - delta, 0.0)
		var t := 1.0 - _roll_left / _roll_duration
		_pivot.rotation.x = TAU * ease(t, -1.6)
	else:
		_pivot.rotation.x = 0.0


## Roulade avant (un tour complet pendant `duration` secondes).
func play_roll(duration: float) -> void:
	_roll_duration = maxf(duration, 0.01)
	_roll_left = _roll_duration


func _swing(limb: String, angle: float) -> void:
	if _limbs.has(limb):
		(_limbs[limb] as Node3D).transform = (_rest[limb] as Transform3D).rotated_local(Vector3.RIGHT, angle)
