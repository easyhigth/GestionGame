class_name MagicBolt
extends Node3D
## Projectile magique (tiré par le bâton de mage) : file tout droit et touche le premier adversaire.

var direction := Vector3.FORWARD
var speed := 13.0
var range_left := 12.0
var damage := 10
var knockback := 3.0
var shooter: Combatant
var color := Color(0.5, 0.9, 1.0)
## Appelé avec la cible touchée (effets des compétences).
var on_hit: Callable
var _t := 0.0
var _core: MeshInstance3D
## Flèche (arcs de l'arsenal) : un trait de bois empenné, plus rapide, sans lueur.
var arrow := false


func _ready() -> void:
	if arrow:
		_build_arrow()
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.5
	_core = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.22, 0.22, 0.22)
	_core.mesh = box
	_core.material_override = mat
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_core)
	var inner := MeshInstance3D.new()
	var b2 := BoxMesh.new()
	b2.size = Vector3(0.12, 0.12, 0.12)
	inner.mesh = b2
	var m2 := StandardMaterial3D.new()
	m2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m2.albedo_color = Color.WHITE
	inner.material_override = m2
	add_child(inner)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.2
	light.omni_range = 2.5
	add_child(light)


func _physics_process(delta: float) -> void:
	_t += delta
	var step := direction * speed * delta
	global_position += step
	range_left -= step.length()
	if not arrow:
		_core.rotation = Vector3(_t * 9.0, _t * 7.0, 0)
	if shooter and is_instance_valid(shooter):
		for n in get_tree().get_nodes_in_group(shooter.hostile_group()):
			var target := n as Combatant
			if target == null or not target.is_alive():
				continue
			var tp := target.global_position + Vector3(0, 0.9, 0)
			if Vector2(tp.x - global_position.x, tp.z - global_position.z).length() < target.body_radius + 0.25 \
					and absf(tp.y - global_position.y) < 1.2:
				if target.receive_hit(damage, self, knockback) and on_hit.is_valid():
					on_hit.call(target)
				_burst()
				return
	if range_left <= 0.0:
		_burst()


func _build_arrow() -> void:
	speed = 24.0
	knockback = 1.5
	_core = MeshInstance3D.new()
	_core.mesh = WeaponModels.arrow_mesh()
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_core)
	# la flèche regarde dans sa direction (pointe vers +Z du maillage)
	_core.basis = Basis.looking_at(-direction, Vector3.UP)


func _burst() -> void:
	if arrow:
		set_physics_process(false)
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.08)
		tw.tween_callback(queue_free)
		return
	set_physics_process(false)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 2.2, 0.12)
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.1)
	tw.tween_callback(queue_free)
