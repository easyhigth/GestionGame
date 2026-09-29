extends Node
## Autoload « Items » : charge tous les objets (data/items/) et recettes (data/recipes/),
## fabrique les modèles 3D posés au sol et les icônes de l'interface.

const ITEMS_DIR := "res://data/items/"
const RECIPES_DIR := "res://data/recipes/"
## Modèles utilisés pour les objets au sol et les icônes.
const DISPLAY_EQUIPMENT := preload("res://assets/equipment/human_equipment.glb")
const DISPLAY_MATERIALS := preload("res://assets/equipment/materials.glb")
const ICON_SIZE := 96

var items := {}            # id -> ItemData
var recipes: Array[RecipeData] = []
var _icons := {}           # id -> Texture2D


func _ready() -> void:
	for res in _load_dir(ITEMS_DIR):
		if res is ItemData:
			items[res.id] = res
	for res in _load_dir(RECIPES_DIR):
		if res is RecipeData:
			recipes.append(res)
	recipes.sort_custom(func(a: RecipeData, b: RecipeData): return a.result.display_name < b.result.display_name)


func get_item(id: String) -> ItemData:
	return items.get(id)


func all_equipment() -> Array[ItemData]:
	var out: Array[ItemData] = []
	for it in items.values():
		if it.is_equipment():
			out.append(it)
	return out


func _load_dir(path: String) -> Array:
	var out := []
	var dir := DirAccess.open(path)
	if dir == null:
		return out
	for f in dir.get_files():
		f = f.trim_suffix(".remap")
		if f.ends_with(".tres") or f.ends_with(".res"):
			var r := load(path + f)
			if r:
				out.append(r)
	return out


## Modèle 3D d'un objet, centré sur l'origine et mis à l'échelle (taille max = `max_size` m).
func build_display(item: ItemData, max_size: float = 0.8) -> Node3D:
	var holder := Node3D.new()
	var inner := Node3D.new()
	holder.add_child(inner)
	var parts := []
	if item.is_equipment():
		parts = VoxelCharacter.library_parts(DISPLAY_EQUIPMENT).get(item.id, [])
		# on reconstruit les pièces à leur place sur un humain de référence
		var ref := _reference_bones()
		for p in parts:
			var mi := MeshInstance3D.new()
			mi.mesh = p[1]
			mi.transform = ref.get(p[0], Transform3D.IDENTITY)
			inner.add_child(mi)
	else:
		var inst := DISPLAY_MATERIALS.instantiate()
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			if String(mi.name) == item.id:
				var copy := MeshInstance3D.new()
				copy.mesh = (mi as MeshInstance3D).mesh
				inner.add_child(copy)
		inst.free()
	var aabb := AABB()
	var first := true
	for mi in inner.get_children():
		var box: AABB = mi.transform * (mi as MeshInstance3D).get_aabb()
		aabb = box if first else aabb.merge(box)
		first = false
	if not first:
		var s := minf(1.0, max_size / maxf(aabb.get_longest_axis_size(), 0.001))
		inner.scale = Vector3.ONE * s
		inner.position = -aabb.get_center() * s
	return holder


var _ref_bones := {}


## Position de chaque nœud du squelette de l'humain (pour les objets au sol).
func _reference_bones() -> Dictionary:
	if not _ref_bones.is_empty():
		return _ref_bones
	var inst := DISPLAY_EQUIPMENT.instantiate()
	var first_holder: Node = inst.find_child("Root__*", true, false).get_parent()
	for n in first_holder.find_children("*", "Node3D", true, false):
		var xf := Transform3D.IDENTITY
		var cur: Node = n
		while cur != first_holder:
			xf = (cur as Node3D).transform * xf
			cur = cur.get_parent()
		_ref_bones[String(n.name).get_slice("__", 0)] = xf
	inst.free()
	return _ref_bones


## Icône de l'objet (rendue une seule fois dans une petite scène 3D).
func get_icon(item: ItemData) -> Texture2D:
	if item == null:
		return null
	if _icons.has(item.id):
		return _icons[item.id]
	var vp := SubViewport.new()
	vp.size = Vector2i(ICON_SIZE, ICON_SIZE)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.9)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 35, 0)
	vp.add_child(sun)
	var model := build_display(item, 1.0)
	model.rotation_degrees = Vector3(0, -35, 0)
	vp.add_child(model)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.25
	cam.position = Vector3(0, 0.55, 1.6)
	vp.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3.ZERO)
	add_child(vp)
	var tex := vp.get_texture()
	_icons[item.id] = tex
	return tex
