class_name HandBuild
extends Node3D
## Poser des blocs et des meubles à la main, sans le mode construction (façon Minecraft).
## C / X : objet suivant / précédent du sac (blocs et meubles), « mains nues » en plus.
## V (L3 à la manette) : poser devant soi. Une case fantôme montre où (verte : possible, rouge : impossible).
## Les blocs se posent au niveau des pieds, puis au-dessus s'il y a déjà un bloc (jusqu'à 2 de haut),
## ou un cran plus bas devant un trou (pour faire un pont). Casser : frapper le bloc (voir Harvest).

signal selection_changed

const C_OK := Color(0.45, 1.0, 0.55, 0.35)
const C_BAD := Color(1.0, 0.35, 0.3, 0.35)

var player: Player
## Identifiant de l'objet choisi (« » = mains nues).
var selected := ""
var _ghost: MeshInstance3D
var _ghost_mat: StandardMaterial3D
var _target := {}


func _ready() -> void:
	top_level = true
	_ghost = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * 1.03
	_ghost.mesh = bm
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat.no_depth_test = false
	_ghost.material_override = _ghost_mat
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.visible = false
	add_child(_ghost)
	if player:
		player.inventory.changed.connect(_on_inventory_changed)


## Objets posables du sac, dans l'ordre du sac.
func choices() -> Array[ItemData]:
	var out: Array[ItemData] = []
	if player == null:
		return out
	for e in player.inventory.entries:
		var it := e.item as ItemData
		if it and it.is_placeable() and not out.has(it):
			out.append(it)
	return out


func selected_item() -> ItemData:
	return Items.get_item(selected) if selected != "" else null


## Objet suivant (+1) ou précédent (-1) ; après le dernier, on revient aux mains nues.
func cycle(dir: int) -> void:
	var list := choices()
	if list.is_empty():
		selected = ""
		player.notify.emit("Aucun bloc ni meuble dans ton sac.")
		selection_changed.emit()
		return
	var ids: Array = [""]
	for it in list:
		ids.append(it.id)
	var i := ids.find(selected)
	i = (maxi(i, 0) + dir + ids.size()) % ids.size()
	selected = ids[i]
	selection_changed.emit()


func _on_inventory_changed() -> void:
	# l'objet choisi est épuisé : mains nues
	if selected != "" and player.inventory.count(Items.get_item(selected)) <= 0:
		selected = ""
		selection_changed.emit()


func _process(_delta: float) -> void:
	var it := selected_item()
	if it == null or player == null or player.building or player.ui_open or not player.is_alive() \
			or player.global_position.y < WorldGenerator.UNDERGROUND:
		_ghost.visible = false
		_target = {}
		return
	_target = find_spot(it)
	if _target.is_empty():
		_ghost.visible = false
		return
	_ghost.visible = true
	var h := BuildGrid.block_height(it) if it.is_block() else 1.0
	_ghost.scale = Vector3(1.0, h, 1.0)
	var k: Vector3i = _target.key
	var base: float = _target.get("base", float(k.y))
	_ghost.global_position = Vector3(k.x + 0.5, base + h * 0.5, k.z + 0.5)
	_ghost_mat.albedo_color = C_OK if _target.ok else C_BAD


## Case où l'objet serait posé : {"key": Vector3i, "ok": bool, "base": float (meuble), "why": texte}.
func find_spot(it: ItemData) -> Dictionary:
	var world := player.get_tree().get_first_node_in_group("world") as WorldGenerator
	if world == null:
		return {}
	var grid := world.build
	var fwd := Vector3(player.facing.x, 0, player.facing.z).normalized()
	var here := world.cell_at(player.global_position)
	var col := world.cell_at(player.global_position + fwd * 1.1)
	if col == here:
		col = world.cell_at(player.global_position + fwd * 1.6)
	var feet := player.global_position.y
	var fy := floori(feet + 0.3)
	if it.is_furniture():
		var base := world.support_height(Vector3(col.x + 0.5, 0, col.y + 0.5), feet + 1.2)
		var key := Vector3i(col.x, floori(base), col.y)
		var ok := absf(base - feet) < 1.3 and grid.can_place_furniture(col, base) and world.village_prop_at(col, base) == null
		return {"key": key, "base": base, "ok": ok, "why": "" if ok else "Place occupée"}
	var ground := world.terrain_height(col)
	var ys: Array = []
	# devant un trou : un cran plus bas (pont), sinon aux pieds puis au-dessus
	if ground < fy - 0.6 and grid.block_at(Vector3i(col.x, fy - 1, col.y)) == null:
		ys.append(fy - 1)
	ys.append_array([fy, fy + 1, fy + 2])
	for y in ys:
		var key := Vector3i(col.x, y, col.y)
		if grid.block_at(key) != null:
			continue
		if ground > y + 0.55:
			# enterré dans le sol : on essaie plus haut
			continue
		var ok := grid.can_place_block(key, it) and _supported(world, key) and world.village_prop_at(col, float(y)) == null
		return {"key": key, "ok": ok, "why": "" if ok else "Il faut un appui (le sol ou un bloc à côté)"}
	return {"key": Vector3i(col.x, fy + 2, col.y), "ok": false, "why": "Trop haut"}


## Un bloc tient s'il touche le sol, un bloc dessous ou un bloc à côté, ou s'il prolonge le sol voisin (pont).
static func _supported(world: WorldGenerator, k: Vector3i) -> bool:
	var grid := world.build
	var col := Vector2i(k.x, k.z)
	if world.terrain_height(col) >= k.y - 0.55 or grid.block_at(k - Vector3i(0, 1, 0)) != null:
		return true
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = col + d
		if grid.block_at(Vector3i(n.x, k.y, n.y)) != null or world.terrain_height(n) >= k.y + 0.45:
			return true
	return false


## Pose l'objet choisi. Renvoie vrai si c'est fait.
func place() -> bool:
	var it := selected_item()
	if it == null:
		cycle(1)
		return false
	if _target.is_empty():
		_target = find_spot(it)
	if _target.is_empty() or not _target.ok:
		player.notify.emit(_target.get("why", "Impossible de poser ici.") if not _target.is_empty() else "Impossible de poser ici.")
		return false
	var world := player.get_tree().get_first_node_in_group("world") as WorldGenerator
	var k: Vector3i = _target.key
	var done := false
	if it.is_block():
		done = world.build.place_block(k, it)
	else:
		var rot := _rot_from_facing()
		done = world.build.place_furniture(Vector2i(k.x, k.z), float(_target.base), it, rot)
	if not done:
		return false
	player.inventory.remove(it, 1)
	var at := Vector3(k.x + 0.5, float(_target.get("base", k.y)) + 0.5, k.z + 0.5)
	VoxelBurst.spawn(player, at, BuildMode.it_color(it) if it.is_block() else Color(0.75, 0.6, 0.4), 8, 1.8, 0.07, 0.3, "up", 6.0, false)
	player.visual.play_move("punch_1", 1.6)
	_target = {}
	return true


## Un meuble posé regarde le héros.
func _rot_from_facing() -> int:
	var f := Vector2(-player.facing.x, -player.facing.z)
	if absf(f.x) > absf(f.y):
		return 1 if f.x > 0.0 else 3
	return 0 if f.y > 0.0 else 2
