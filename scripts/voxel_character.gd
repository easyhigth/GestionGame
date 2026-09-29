class_name VoxelCharacter
extends Node3D
## Affiche un personnage voxel (.glb) et l'anime sans AnimationPlayer :
## marche (bras et jambes qui balancent), respiration au repos, roulade, coup d'arme.
## Les modèles doivent avoir les nœuds Root > LegL, LegR, Torso > ArmL, ArmR, Head.
## L'équipement vient d'un fichier <race>_equipment.glb : chaque pièce est accrochée
## au nœud du même nom sur le personnage, elle suit donc ses mouvements.

## Modèle affiché (fichier .glb de assets/characters/models/base/).
@export var model: PackedScene:
	set = set_model
## Équipements de la race (fichier .glb de assets/equipment/).
@export var equipment_library: PackedScene:
	set = set_equipment_library
## Vitesse à laquelle le personnage se tourne vers sa direction.
@export var turn_speed: float = 14.0
## Amplitude du balancement des bras et des jambes (radians).
@export var walk_swing: float = 0.65
## Hauteur du centre de la roulade (le personnage tourne autour de ce point).
@export var roll_pivot_height: float = 0.8
## Durée d'un coup d'arme (secondes).
@export var attack_duration: float = 0.38

## Cache partagé : bibliothèque d'équipement -> { id_objet: [[nom_du_nœud, maillage], ...] }
static var _library_cache := {}

var _pivot: Node3D
var _instance: Node3D
var _limbs := {}
var _rest := {}
var _bones := {}
var _shown := {}          # emplacement -> id de l'objet affiché
var _equip_nodes := {}    # emplacement -> [MeshInstance3D]
var _phase := randf() * TAU
var _idle_t := randf() * TAU
var _roll_left := 0.0
var _roll_duration := 0.0
var _attack_left := 0.0
var _attack_total := 0.38
var _quadruped := false
var _flash_left := 0.0
var _flash_mat: StandardMaterial3D
var _downed := false
var _down := 0.0


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
	_bones.clear()
	_equip_nodes.clear()
	if scene == null:
		return
	_instance = scene.instantiate() as Node3D
	_instance.position.y = -roll_pivot_height
	_pivot.add_child(_instance)
	for n in _instance.find_children("*", "Node3D", true, false):
		if not _bones.has(n.name):
			_bones[n.name] = n
	for n in ["LegL", "LegR", "ArmL", "ArmR", "Head", "Torso", "Root"]:
		if _bones.has(n):
			_limbs[n] = _bones[n]
			_rest[n] = (_bones[n] as Node3D).transform
	# les créatures à quatre pattes n'ont pas de mains : elles mordent au lieu de frapper
	_quadruped = not _bones.has("HandL")
	_refresh_equipment()


func set_equipment_library(scene: PackedScene) -> void:
	equipment_library = scene
	if is_inside_tree():
		_refresh_equipment()


## Affiche l'objet `item_id` à l'emplacement `slot` (id vide = retirer).
func show_equipment(slot: int, item_id: String) -> void:
	if item_id.is_empty():
		_shown.erase(slot)
	else:
		_shown[slot] = item_id
	_apply_slot(slot)


func _refresh_equipment() -> void:
	for slot in _equip_nodes.keys():
		_clear_slot(slot)
	for slot in _shown:
		_apply_slot(slot)


func _clear_slot(slot: int) -> void:
	for mi in _equip_nodes.get(slot, []):
		if is_instance_valid(mi):
			mi.queue_free()
	_equip_nodes.erase(slot)


func _apply_slot(slot: int) -> void:
	_clear_slot(slot)
	if _instance == null or equipment_library == null or not _shown.has(slot):
		return
	var parts: Array = VoxelCharacter.library_parts(equipment_library).get(_shown[slot], [])
	var nodes := []
	for part in parts:
		var bone := _bones.get(part[0]) as Node3D
		if bone == null:
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Equip_%s" % _shown[slot]
		mi.mesh = part[1]
		bone.add_child(mi)
		nodes.append(mi)
	_equip_nodes[slot] = nodes


## Découpe une bibliothèque d'équipement en pièces : { id_objet: [[nom_du_nœud, maillage], ...] }.
static func library_parts(scene: PackedScene) -> Dictionary:
	if _library_cache.has(scene):
		return _library_cache[scene]
	var result := {}
	var inst := scene.instantiate()
	var root: Node = inst
	if root.get_child_count() == 1 and root.get_child(0).name == "Equipment":
		root = root.get_child(0)
	for holder in root.get_children():
		var parts := []
		for mi in holder.find_children("*", "MeshInstance3D", true, false):
			# les nœuds s'appellent « <os>__<objet> » (ex. HandL__sword_iron)
			parts.append([String(mi.name).get_slice("__", 0), (mi as MeshInstance3D).mesh])
		result[String(holder.name)] = parts
	inst.free()
	_library_cache[scene] = result
	return result


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
	var lunge := 0.0
	if _attack_left > 0.0:
		_attack_left = maxf(_attack_left - delta, 0.0)
		var t := 1.0 - _attack_left / _attack_total
		if _quadruped:
			# recul puis bond en avant, tête baissée
			lunge = -0.15 * sin(t / 0.42 * PI) if t < 0.42 else 0.45 * sin((t - 0.42) / 0.58 * PI)
			if _limbs.has("Head"):
				var hd := _limbs["Head"] as Node3D
				hd.transform = (_rest["Head"] as Transform3D).rotated_local(Vector3.RIGHT, 0.5 * sin(t * PI))
		else:
			# lever l'arme puis l'abattre devant soi
			var a := lerpf(0.0, -2.6, t / 0.35) if t < 0.35 else lerpf(-2.6, -0.3, ease((t - 0.35) / 0.65, 0.4))
			if t > 0.9:
				a = lerpf(-0.3, 0.0, (t - 0.9) / 0.1)
			_swing("ArmL", a)
	var breath := sin(_idle_t * 2.0) * 0.012 * (1.0 - walk)
	var bob := absf(sin(_phase)) * 0.06 * walk
	_instance.position.y = -roll_pivot_height + bob
	if _limbs.has("Torso"):
		(_limbs["Torso"] as Node3D).position = (_rest["Torso"] as Transform3D).origin + Vector3(0, breath, 0)
	if _limbs.has("Head") and not (_quadruped and _attack_left > 0.0):
		var head := _limbs["Head"] as Node3D
		head.transform = (_rest["Head"] as Transform3D).rotated_local(Vector3.UP, sin(_idle_t * 0.7) * 0.15 * (1.0 - walk))

	_pivot.position.z = lunge
	_down = move_toward(_down, 1.0 if _downed else 0.0, delta * 3.0)
	if _roll_left > 0.0:
		_roll_left = maxf(_roll_left - delta, 0.0)
		var t := 1.0 - _roll_left / _roll_duration
		_pivot.rotation.x = TAU * ease(t, -1.6)
	else:
		# personnage à terre : couché sur le dos (sur le flanc pour une créature)
		if _quadruped:
			_pivot.rotation.x = 0.0
			_pivot.rotation.z = -1.5 * ease(_down, 0.5)
		else:
			_pivot.rotation.x = -1.5 * ease(_down, 0.5)
		_pivot.position.y = lerpf(roll_pivot_height, 0.2 if not _quadruped else 0.35, ease(_down, 0.5))

	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_set_overlay(null)


## Roulade avant (un tour complet pendant `duration` secondes).
func play_roll(duration: float) -> void:
	_roll_duration = maxf(duration, 0.01)
	_roll_left = _roll_duration


## Coup d'arme (bras qui tient l'arme) ou morsure pour une créature. `duration` < 0 : durée par défaut.
func play_attack(duration: float = -1.0) -> void:
	_attack_total = duration if duration > 0.0 else attack_duration
	_attack_left = _attack_total


## Fait clignoter le personnage (coup reçu, ou avertissement avant une attaque).
func flash(color: Color = Color(1, 1, 1, 0.75), time := 0.12) -> void:
	if _instance == null:
		return
	if _flash_mat == null:
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_mat.albedo_color = color
	_set_overlay(_flash_mat)
	_flash_left = time


func _set_overlay(mat: Material) -> void:
	if _instance == null:
		return
	for mi in _instance.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = mat


## Met le personnage à terre (K.O. ou mort) ou le relève.
func set_downed(on: bool) -> void:
	_downed = on
	if on:
		_attack_left = 0.0
		_roll_left = 0.0


func is_downed() -> bool:
	return _downed


func is_attacking() -> bool:
	return _attack_left > 0.0


func _swing(limb: String, angle: float) -> void:
	if _limbs.has(limb):
		(_limbs[limb] as Node3D).transform = (_rest[limb] as Transform3D).rotated_local(Vector3.RIGHT, angle)
