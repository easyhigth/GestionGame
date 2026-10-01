extends SceneTree
## Photographie chaque créature (data/enemies/*.tres) pour le bestiaire et les fiches :
## assets/ui/portraits/<id>.png (256 × 256, fond transparent, vue de trois quarts),
## les personnages de l'histoire en buste (npc_<id>.png) et chaque race (race_<fichier>.png).
##
##   godot --path . --resolution 640x480 -s tools/render_portraits.gd   (avec un affichage, ex. xvfb-run)
##   ONLY=loup,ogre pour n'en refaire que quelques-uns.

const SIZE := 256
const OUT := "res://assets/ui/portraits/"

var _vp: SubViewport
var _cam: Camera3D
var _queue: Array = []
var _current: Node3D
var _id := ""
var _wait := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var only := OS.get_environment("ONLY").split(",", false)
	for f in DirAccess.get_files_at("res://data/enemies"):
		if f.ends_with(".tres") and (only.is_empty() or f.get_basename() in only):
			_queue.append(f.get_basename())
	var npcs: Dictionary = load("res://scripts/story/story_data.gd").NPCS
	for id in npcs:
		if only.is_empty() or "npc_" + id in only:
			_queue.append("npc_" + id)
	for f in DirAccess.get_files_at("res://data/races"):
		if f.ends_with(".tres") and (only.is_empty() or "race_" + f.get_basename() in only):
			_queue.append("race_" + f.get_basename())
	_vp = SubViewport.new()
	_vp.size = Vector2i(SIZE, SIZE)
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.86, 0.84, 0.92)
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	# lumière principale chaude, contre-jour froid pour détacher la silhouette
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, 35, 0)
	key.light_energy = 1.25
	key.light_color = Color(1.0, 0.94, 0.84)
	_vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15, 200, 0)
	rim.light_energy = 0.9
	rim.light_color = Color(0.6, 0.75, 1.0)
	_vp.add_child(rim)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_vp.add_child(_cam)
	print("portraits : ", _queue.size())


func _process(_d: float) -> bool:
	if _wait > 0:
		_wait -= 1
		if _wait == 0:
			var img := _vp.get_texture().get_image()
			img.save_png(ProjectSettings.globalize_path(OUT + _id + ".png"))
			print("  ", _id)
			_current.queue_free()
			_current = null
		return false
	if _queue.is_empty():
		return true
	_id = _queue.pop_front()
	var vc = load("res://scripts/voxel_character.gd").new()
	var bust := false
	if _id.begins_with("npc_") or _id.begins_with("race_"):
		# personnage : modèle de sa race (première palette, comme en jeu), équipement de départ
		var info: Dictionary = {}
		var race_path := "res://data/races/%s.tres" % _id.substr(5)
		if _id.begins_with("npc_"):
			info = load("res://scripts/story/story_data.gd").NPCS[_id.substr(4)]
			race_path = info.race
		var race = load(race_path)
		if race == null:
			vc.free()
			return false
		_vp.add_child(vc)
		vc.set_equipment_library(race.equipment)
		vc.set_model(race.villager_models[0] if not race.villager_models.is_empty() else race.model)
		for it_id in info.get("kit", []):
			var it = root.get_node("Items").get_item(it_id)
			if it:
				vc.show_equipment(it.slot, it.model_id())
		bust = true
	else:
		var data = load("res://data/enemies/%s.tres" % _id)
		if data == null or data.model == null:
			vc.free()
			return false
		_vp.add_child(vc)
		vc.set_equipment_library(data.equipment_library)
		vc.set_model(data.model)
		for it in data.equipment:
			vc.show_equipment(it.slot, it.id)
	_current = vc
	_frame(vc, bust)
	_wait = 4
	return false


## Cadre la créature : boîte englobante de tous ses maillages, vue de trois quarts.
func _frame(n: Node3D, bust := false) -> void:
	var box := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var center := box.get_center()
	var dir := Vector3(0.62, 0.32, 1.0).normalized()
	var reach := box.size.length()
	_cam.size = maxf(box.size.y, maxf(box.size.x, box.size.z) * 0.95) * 1.18
	if bust and box.size.y > 1.3:
		# buste : la tête et les épaules (le haut de la silhouette)
		center = Vector3(center.x, box.end.y - box.size.y * 0.27, center.z)
		dir = Vector3(0.45, 0.12, 1.0).normalized()
		_cam.size = box.size.y * 0.62
	_cam.near = 0.05
	_cam.far = reach * 6.0 + 10.0
	_cam.look_at_from_position(center + dir * (reach * 2.5 + 2.0), center)
