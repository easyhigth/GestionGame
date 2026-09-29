class_name VoxelCharacter
extends Node3D
## Affiche un personnage voxel (.glb) et l'anime sans AnimationPlayer :
## marche (bras et jambes qui balancent), respiration au repos, roulade,
## et coups de combat décrits par des poses clés (voir MoveLibrary).
## Effets : traînée de cubes derrière l'arme, images rémanentes, étoiles d'étourdissement.
## Les modèles doivent avoir les nœuds Root > LegL, LegR, Torso > (ArmL > HandL), (ArmR > HandR), Head.
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
## Durée d'un coup simple (créatures).
@export var attack_duration: float = 0.38
## Couleur de la traînée de l'arme.
@export var trail_color: Color = Color(0.85, 0.95, 1.0)

## Cache partagé : bibliothèque d'équipement -> { id_objet: [[nom_du_nœud, maillage], ...] }
static var _library_cache := {}

const POSE_BONES := ["ArmL", "ArmR", "HandL", "HandR", "Torso", "Head", "LegL", "LegR"]
const TRAIL_MAX := 320
const TRAIL_LIFE := 0.22

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

# coup en cours (poses clés)
var _move := {}
var _move_name := ""
var _move_t := 0.0
var _move_speed := 1.0
var _move_weight := 0.0
var _last_pose := {}
var _last_root := Vector3.ZERO
var _last_spin := 0.0

# traînée de l'arme
var _trail: MultiMeshInstance3D
var _trail_pos: Array[Vector3] = []
var _trail_age: Array[float] = []
var _trail_on := false
var _trail_force := false
var _trail_prev: Array[Vector3] = []
var _weapon_len := 0.0
var _trail_col := Color.WHITE

# couleurs personnalisées (héros) : rôle -> Couleur
var _colors := {}
static var _recolor_cache := {}

# étourdissement et lueur de l'arme
var _stars: Node3D
var _glow_mat: StandardMaterial3D
var _glow := 0.0


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
	for n in POSE_BONES + ["Root"]:
		if _bones.has(n):
			_limbs[n] = _bones[n]
			_rest[n] = (_bones[n] as Node3D).transform
	# les créatures à quatre pattes n'ont pas de mains : elles mordent au lieu de frapper
	_quadruped = not _bones.has("HandL")
	if not _colors.is_empty():
		_recolor()
	_refresh_equipment()


## Couleurs du héros. Les modèles de assets/characters/hero/ ont des couleurs repères
## (peau (200,1,1), cheveux (1,200,1), yeux (1,1,200) et leurs nuances) remplacées ici.
func set_colors(skin: Color, hair: Color, eye: Color) -> void:
	_colors = {"skin": skin, "hair": hair, "eye": eye}
	_recolor()


func _recolor() -> void:
	if _instance == null:
		return
	for node in _instance.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s) as StandardMaterial3D
			if m == null:
				continue
			var key := VoxelCharacter.decode_key_color(m.albedo_color)
			if key.is_empty():
				continue
			var c: Color = _colors.get(key[0], Color.WHITE)
			var f: float = key[1]
			var cache_key := "%d|%s|%s" % [m.get_instance_id(), c.to_html(), key[0]]
			var mat: StandardMaterial3D = _recolor_cache.get(cache_key)
			if mat == null:
				mat = m.duplicate() as StandardMaterial3D
				mat.albedo_color = Color(minf(c.r * f, 1.0), minf(c.g * f, 1.0), minf(c.b * f, 1.0), m.albedo_color.a)
				if mat.emission_enabled:
					mat.emission = Color(minf(c.r * f, 1.0), minf(c.g * f, 1.0), minf(c.b * f, 1.0))
				_recolor_cache[cache_key] = mat
			mi.set_surface_override_material(s, mat)


## Reconnaît une couleur repère : renvoie [rôle, nuance] ou [] si c'est une couleur normale.
static func decode_key_color(c: Color) -> Array:
	var v := [c.r, c.g, c.b]
	var roles := ["skin", "hair", "eye"]
	for i in 3:
		var others := 0.0
		for j in 3:
			if j != i:
				others = maxf(others, v[j])
		if v[i] > 0.12 and others < 0.02:
			return [roles[i], v[i] * 255.0 / 200.0]
	return []


func is_quadruped() -> bool:
	return _quadruped


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
	if slot == ItemData.Slot.MAIN_HAND:
		_weapon_len = 0.0


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
		# longueur de l'arme (pour la traînée) : jusqu'au bout de la lame, vers +Y dans la main
		if slot == ItemData.Slot.MAIN_HAND and part[0] == "HandL":
			_weapon_len = maxf(_weapon_len, (part[1] as Mesh).get_aabb().end.y)
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


# ---------------------------------------------------------------- coups (poses clés)

## Joue un coup de MoveLibrary. `speed` > 1 : plus rapide.
func play_move(move_name: String, speed := 1.0) -> void:
	var m := MoveLibrary.get_move(move_name)
	if m.is_empty():
		return
	_move = m
	_move_name = move_name
	_move_t = 0.0
	_move_speed = speed
	_attack_left = 0.0
	_sample_move()


## Arrête le coup en cours (retour en douceur à la pose normale).
func stop_move() -> void:
	_move = {}
	_move_name = ""


func current_move() -> String:
	return _move_name


## Temps écoulé dans le coup en cours (à vitesse 1).
func move_time() -> float:
	return _move_t


func _sample_move() -> void:
	var keys: Array = _move["keys"]
	var dur: float = _move["duration"]
	var t := _move_t
	if _move.get("loop", false):
		t = fmod(t, dur)
	# pose de repos implicite à la fin (sauf poses tenues)
	var last: Array = keys[keys.size() - 1]
	var end_key: Array = [dur, {}, Vector3.ZERO, last[3]]
	if _move.get("hold", false):
		end_key = [dur + 1000.0, last[1], last[2], last[3]]
	var k0: Array = keys[0]
	var k1: Array = end_key
	for i in keys.size():
		if keys[i][0] <= t:
			k0 = keys[i]
			k1 = keys[i + 1] if i + 1 < keys.size() else end_key
	var span: float = maxf(k1[0] - k0[0], 0.0001)
	var w := clampf((t - k0[0]) / span, 0.0, 1.0)
	w = w * w * (3.0 - 2.0 * w)
	var pose := {}
	for b in POSE_BONES:
		var a: Vector3 = k0[1].get(b, Vector3.ZERO)
		var c: Vector3 = k1[1].get(b, Vector3.ZERO)
		if a != Vector3.ZERO or c != Vector3.ZERO:
			pose[b] = a.lerp(c, w)
	_last_pose = pose
	_last_root = (k0[2] as Vector3).lerp(k1[2], w)
	_last_spin = lerpf(k0[3], k1[3], w)


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
	var loco := {"LegL": s, "LegR": -s, "ArmL": -s * 0.8, "ArmR": s * 0.8}

	# avancement du coup
	if not _move.is_empty():
		_move_t += delta * _move_speed
		var dur: float = _move["duration"]
		if _move_t >= dur and not _move.get("hold", false) and not _move.get("loop", false):
			_move = {}
			_move_name = ""
		else:
			_sample_move()
	_move_weight = move_toward(_move_weight, 1.0 if not _move.is_empty() else 0.0, delta * (30.0 if not _move.is_empty() else 7.0))

	# os : pose du coup mélangée à la marche
	for b in POSE_BONES:
		if not _limbs.has(b):
			continue
		var rest: Transform3D = _rest[b]
		var loco_a: float = loco.get(b, 0.0)
		var p: Vector3 = _last_pose.get(b, Vector3.ZERO) * _move_weight
		if _last_pose.has(b) and _move_weight > 0.0:
			loco_a *= (1.0 - _move_weight)
		var basis := rest.basis * Basis.from_euler(p * (PI / 180.0)) * Basis(Vector3.RIGHT, loco_a)
		if b == "Head" and not _last_pose.has(b):
			basis = basis * Basis(Vector3.UP, sin(_idle_t * 0.7) * 0.15 * (1.0 - walk) * (1.0 - _move_weight))
		(_limbs[b] as Node3D).transform = Transform3D(basis, rest.origin)

	# anciennes animations simples (créatures)
	var lunge := 0.0
	if _attack_left > 0.0:
		_attack_left = maxf(_attack_left - delta, 0.0)
		var t := 1.0 - _attack_left / _attack_total
		if _quadruped:
			lunge = -0.15 * sin(t / 0.42 * PI) if t < 0.42 else 0.45 * sin((t - 0.42) / 0.58 * PI)
		else:
			var a := lerpf(0.0, -2.6, t / 0.35) if t < 0.35 else lerpf(-2.6, -0.3, ease((t - 0.35) / 0.65, 0.4))
			_swing("ArmL", a)

	var breath := sin(_idle_t * 2.0) * 0.012 * (1.0 - walk)
	var bob := absf(sin(_phase)) * 0.06 * walk * (1.0 - _move_weight)
	_instance.position.y = -roll_pivot_height + bob
	if _limbs.has("Torso"):
		(_limbs["Torso"] as Node3D).position = (_rest["Torso"] as Transform3D).origin + Vector3(0, breath, 0)

	var root := _last_root * _move_weight
	_pivot.position = Vector3(root.x, _pivot.position.y, lunge + root.z * 0.35)
	_pivot.rotation.y = deg_to_rad(_last_spin) * _move_weight
	_down = move_toward(_down, 1.0 if _downed else 0.0, delta * 3.0)
	if _roll_left > 0.0:
		_roll_left = maxf(_roll_left - delta, 0.0)
		var t := 1.0 - _roll_left / _roll_duration
		_pivot.rotation.x = TAU * ease(t, -1.6)
		_pivot.position.y = roll_pivot_height
	else:
		# personnage à terre : couché sur le dos (sur le flanc pour une créature)
		if _quadruped:
			_pivot.rotation.x = 0.0
			_pivot.rotation.z = -1.5 * ease(_down, 0.5)
		else:
			_pivot.rotation.x = -1.5 * ease(_down, 0.5)
		_pivot.position.y = lerpf(roll_pivot_height + root.y, 0.2 if not _quadruped else 0.35, ease(_down, 0.5))

	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_set_overlay(null)
	_update_trail(delta)
	_update_stars(delta)
	_update_glow()


# ---------------------------------------------------------------- traînée de l'arme

func _trail_active() -> bool:
	if _trail_force:
		return true
	if _move.is_empty() or not _move.has("trail"):
		return false
	var tr: Array = _move["trail"]
	return _move_t >= tr[0] and _move_t <= tr[1]


## Points de la lame (du milieu vers la pointe) en coordonnées du monde.
func _blade_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var hand := _bones.get("HandL") as Node3D
	if hand == null:
		return out
	var blade := _weapon_len if _weapon_len > 0.05 else 0.25
	for f in [0.45, 0.75, 1.0]:
		out.append(hand.global_transform * Vector3(0, blade * f, 0))
	return out


func _update_trail(delta: float) -> void:
	var active := _trail_active() and _instance != null
	if active:
		if _trail == null:
			_make_trail()
		var pts := _blade_points()
		if _trail_on and _trail_prev.size() == pts.size():
			for i in pts.size():
				for k in 4:
					_trail_pos.append(_trail_prev[i].lerp(pts[i], float(k + 1) / 4.0))
					_trail_age.append(0.0)
		_trail_prev = pts
	_trail_on = active
	if _trail == null:
		return
	var i := 0
	while i < _trail_age.size():
		_trail_age[i] += delta
		if _trail_age[i] >= TRAIL_LIFE:
			_trail_age.remove_at(i)
			_trail_pos.remove_at(i)
		else:
			i += 1
	while _trail_pos.size() > TRAIL_MAX:
		_trail_pos.remove_at(0)
		_trail_age.remove_at(0)
	var mm := _trail.multimesh
	mm.visible_instance_count = _trail_pos.size()
	for j in _trail_pos.size():
		var k := 1.0 - _trail_age[j] / TRAIL_LIFE
		var sz := 0.09 * k + 0.02
		mm.set_instance_transform(j, Transform3D(Basis().scaled(Vector3.ONE * sz), _trail_pos[j]))
		mm.set_instance_color(j, Color(_trail_col, k * 0.9))


func _make_trail() -> void:
	_trail = MultiMeshInstance3D.new()
	_trail.top_level = true
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	box.material = mat
	mm.mesh = box
	mm.instance_count = TRAIL_MAX
	mm.visible_instance_count = 0
	_trail.multimesh = mm
	add_child(_trail)
	_trail.global_transform = Transform3D.IDENTITY
	if not _trail_force:
		_trail_col = trail_color


## Force la traînée (ex. esquive parfaite) et change sa couleur.
func set_trail(on: bool, color: Color = Color(0, 0, 0, 0)) -> void:
	_trail_force = on
	_trail_col = color if color.a > 0.0 else trail_color


# ---------------------------------------------------------------- effets

## Laisse une image fantôme du personnage qui s'efface (esquive parfaite, ruée).
func spawn_afterimage(color: Color = Color(0.4, 0.8, 1.0, 0.55), life := 0.4) -> void:
	if _instance == null or not is_inside_tree():
		return
	var ghost := _instance.duplicate() as Node3D
	var holder: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
	holder.add_child(ghost)
	ghost.global_transform = _instance.global_transform
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	for mi in ghost.find_children("*", "MeshInstance3D", true, false):
		var g := mi as MeshInstance3D
		g.material_override = mat
		g.material_overlay = null
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tw := ghost.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, life)
	tw.tween_callback(ghost.queue_free)


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


## Efface un clignotement en cours.
func clear_flash() -> void:
	_flash_left = 0.0
	_set_overlay(null)


func _set_overlay(mat: Material) -> void:
	if _instance == null:
		return
	for mi in _instance.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = mat


## Fait briller l'arme (attaque chargée). 0 = éteinte, 1 = pleine charge.
func set_weapon_glow(amount: float) -> void:
	_glow = amount


func _update_glow() -> void:
	var nodes: Array = _equip_nodes.get(ItemData.Slot.MAIN_HAND, [])
	if nodes.is_empty() or _flash_left > 0.0:
		return
	if _glow <= 0.0:
		if _glow_mat:
			for mi in nodes:
				if is_instance_valid(mi) and (mi as MeshInstance3D).material_overlay == _glow_mat:
					(mi as MeshInstance3D).material_overlay = null
		return
	if _glow_mat == null:
		_glow_mat = StandardMaterial3D.new()
		_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var pulse := 0.5 + 0.5 * sin(_idle_t * (10.0 + 20.0 * _glow))
	if _glow >= 1.0:
		_glow_mat.albedo_color = Color(1.0, 0.85, 0.3, 0.3 + 0.5 * pulse)
	else:
		_glow_mat.albedo_color = Color(0.6, 0.85, 1.0, 0.15 + 0.35 * _glow * pulse)
	for mi in nodes:
		if is_instance_valid(mi):
			(mi as MeshInstance3D).material_overlay = _glow_mat


## Étoiles qui tournent au-dessus de la tête (étourdi).
func set_dizzy(on: bool) -> void:
	if on and _stars == null:
		_stars = Node3D.new()
		_stars.top_level = true
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.9, 0.3)
		for i in 5:
			var c := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3.ONE * 0.1
			c.mesh = b
			c.material_override = mat
			var a := TAU * i / 5.0
			c.position = Vector3(cos(a) * 0.35, 0.0, sin(a) * 0.35)
			c.rotation = Vector3(0.6, a, 0.6)
			_stars.add_child(c)
		add_child(_stars)
	if _stars:
		_stars.visible = on


func _update_stars(delta: float) -> void:
	if _stars == null or not _stars.visible:
		return
	var head := _bones.get("Head") as Node3D
	_stars.global_position = head.global_position + Vector3(0, 0.45, 0) if head else global_position + Vector3(0, 2.0, 0)
	_stars.rotation.y += delta * 5.0


## Met le personnage à terre (K.O. ou mort) ou le relève.
func set_downed(on: bool) -> void:
	_downed = on
	if on:
		_attack_left = 0.0
		_roll_left = 0.0
		stop_move()
		set_dizzy(false)
		set_weapon_glow(0.0)


func is_downed() -> bool:
	return _downed


## Roulade avant (un tour complet pendant `duration` secondes).
func play_roll(duration: float) -> void:
	_roll_duration = maxf(duration, 0.01)
	_roll_left = _roll_duration
	stop_move()
	_move_weight = 0.0


## Coup simple (bras qui tient l'arme) ou morsure pour une créature. `duration` < 0 : durée par défaut.
func play_attack(duration: float = -1.0) -> void:
	_attack_total = duration if duration > 0.0 else attack_duration
	_attack_left = _attack_total


func is_attacking() -> bool:
	return _attack_left > 0.0 or (not _move.is_empty() and not _move.get("hold", false))


func _swing(limb: String, angle: float) -> void:
	if _limbs.has(limb):
		(_limbs[limb] as Node3D).transform = (_rest[limb] as Transform3D).rotated_local(Vector3.RIGHT, angle)
