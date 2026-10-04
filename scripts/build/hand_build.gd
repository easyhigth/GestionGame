class_name HandBuild
extends Node3D
## Poser des blocs et des meubles à la main, sans le mode construction (façon Minecraft).
## Molette (avec un objet en main) : objet suivant / précédent ; C : ranger / reprendre l'objet ; Ctrl + 1…0 : case de la barre.
## Clic droit ou V (L3 à la manette) : poser devant soi. Une case fantôme montre où (verte : possible, rouge : impossible).
## Les blocs se posent au niveau des pieds, puis au-dessus s'il y a déjà un bloc (jusqu'à 2 de haut),
## ou un cran plus bas devant un trou (pour faire un pont). Casser : frapper le bloc (voir Harvest).
## Graines (et légumes à planter) : V sème devant soi, sur de la terre labourée (ou sur l'herbe avec une houe
## dans le sac, qui laboure d'abord). Houe choisie : V laboure la case devant soi.

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
		if it and (it.is_placeable() or it.is_seed() or it.id in ["houe", "canne_peche", "barque", "voilier", "sifflet_griffon"] or is_lure(it)) and not out.has(it):
			out.append(it)
	return out


func selected_item() -> ItemData:
	return Items.get_item(selected) if selected != "" else null


## Barre de construction (10 cases, Ctrl+1 à Ctrl+0) : identifiants des objets posables ("" = case vide).
## Elle se remplit toute seule avec ce qui arrive dans le sac, comme la barre de Minecraft ; une case dont
## l'objet est épuisé se vide et reprend le prochain objet nouveau.
const SLOTS := 10
var slots: Array = ["", "", "", "", "", "", "", "", "", ""]


## Range les objets posables du sac dans les cases libres de la barre.
func sync_slots() -> void:
	if player == null:
		return
	for i in SLOTS:
		var id: String = slots[i]
		if id != "" and player.inventory.count(Items.get_item(id)) <= 0:
			slots[i] = ""
	for it in choices():
		if slots.has(it.id):
			continue
		var free := slots.find("")
		if free < 0:
			break
		slots[free] = it.id


## Range un objet dans une case choisie (depuis le sac) ; s'il était déjà dans une autre case, les deux s'échangent.
func assign_slot(i: int, id: String) -> void:
	if i < 0 or i >= SLOTS:
		return
	var old := slots.find(id)
	if old >= 0:
		slots[old] = slots[i]
	slots[i] = id
	selection_changed.emit()


## Ctrl + chiffre : prend en main l'objet de la case (la même touche une 2e fois : mains nues).
func select_slot(i: int) -> void:
	sync_slots()
	var id: String = slots[i] if i >= 0 and i < SLOTS else ""
	if id == "":
		selected = ""
		player.notify.emit("Case %d vide : ramasse ou fabrique des blocs, des meubles ou des graines." % ((i + 1) % 10))
	elif selected == id:
		selected = ""
	else:
		selected = id
	selection_changed.emit()


## Touche C : range l'objet tenu (mains nues), ou reprend le dernier objet tenu (sinon la 1re case de la barre).
var _last := ""


func toggle() -> void:
	sync_slots()
	if selected != "":
		_last = selected
		selected = ""
		player.notify.emit("Mains nues.")
	else:
		var id := _last
		if id == "" or player.inventory.count(Items.get_item(id)) <= 0:
			id = ""
			for sid in slots:
				if sid != "":
					id = sid
					break
		if id == "":
			player.notify.emit("Rien à prendre en main : ramasse ou fabrique des blocs, des meubles ou des graines.")
			return
		selected = id
		var it := Items.get_item(id)
		player.notify.emit("En main : %s" % (it.display_name if it else id))
	selection_changed.emit()


## Objet suivant (+1) ou précédent (-1) : d'abord les cases de la barre, puis le reste du sac ;
## après le dernier, on revient aux mains nues.
func cycle(dir: int) -> void:
	sync_slots()
	var list := choices()
	if list.is_empty():
		selected = ""
		player.notify.emit("Aucun bloc, meuble ni graine dans ton sac.")
		selection_changed.emit()
		return
	var ids: Array = [""]
	for id in slots:
		if id != "":
			ids.append(id)
	for it in list:
		if not ids.has(it.id):
			ids.append(it.id)
	var i := ids.find(selected)
	i = (maxi(i, 0) + dir + ids.size()) % ids.size()
	selected = ids[i]
	selection_changed.emit()


func _on_inventory_changed() -> void:
	sync_slots()
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
	if not it.is_placeable() and not _is_farm_item(it):
		# nourriture pour les bêtes : rien à poser
		_ghost.visible = false
		_target = {}
		return
	_target = find_spot(it)
	if _target.is_empty():
		_ghost.visible = false
		return
	_ghost.visible = true
	var h := BuildGrid.block_height(it) if it.is_block() else (0.22 if _is_farm_item(it) else 1.0)
	_ghost.scale = Vector3(1.0, h, 1.0)
	var k: Vector3i = _target.key
	var base: float = _target.get("base", float(k.y))
	_ghost.global_position = Vector3(k.x + 0.5, base + h * 0.5, k.z + 0.5)
	_ghost_mat.albedo_color = C_OK if _target.ok else C_BAD


## Nourriture qui attire les bêtes (tenue en main, elles suivent le héros).
static func is_lure(it: ItemData) -> bool:
	for sp in FarmAnimal.SPECIES:
		if FarmAnimal.SPECIES[sp].food == it.id:
			return true
	return false


static func _is_farm_item(it: ItemData) -> bool:
	return it.is_seed() or it.id == "houe"


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
	if _is_farm_item(it):
		return _farm_spot(world, col, it)
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


## Case à labourer ou à semer devant le héros.
func _farm_spot(world: WorldGenerator, col: Vector2i, it: ItemData) -> Dictionary:
	var fm := player.get_tree().get_first_node_in_group("farming") as Farming
	var ground := world.terrain_height(col)
	var key := Vector3i(col.x, floori(ground), col.y)
	var out := {"key": key, "base": ground - 0.05, "ok": false, "why": "", "farm": true}
	if fm == null or absf(ground - player.global_position.y) > 1.3:
		out.why = "Trop haut ou trop bas."
		return out
	var tilled := world.terrain_type(col) == WorldGenerator.FARM
	var has_hoe := player.inventory.count(Items.get_item("houe")) > 0
	if it.id == "houe":
		out.ok = not tilled and fm.can_till(col)
		out.why = "" if out.ok else ("Déjà labouré." if tilled else "On ne peut labourer que l'herbe ou la terre (sans rien dessus).")
		return out
	if tilled:
		out.ok = fm.crop_at(col).is_empty()
		out.why = "" if out.ok else "Il y a déjà une culture ici."
		return out
	if not has_hoe:
		out.why = "Il faut de la terre labourée : fabrique une houe (Outils) pour labourer."
		return out
	out.ok = fm.can_till(col)
	out.why = "" if out.ok else "On ne peut labourer que l'herbe ou la terre (sans rien dessus)."
	return out


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
	if it.id == "barque" or it.id == "voilier":
		var mo := player.get_tree().get_first_node_in_group("mounts") as Mounts
		if mo:
			var err := mo.place_boat(player, it.id)
			if err != "":
				player.notify.emit(err)
			else:
				player.inventory.remove(it, 1)
				player.notify.emit("%s est à l'eau : {interact} pour monter, {interact} près d'une berge pour débarquer." % ("La barque" if it.id == "barque" else "Le voilier"))
		return false
	if it.id == "sifflet_griffon":
		var mo := player.get_tree().get_first_node_in_group("mounts") as Mounts
		if mo:
			var err := mo.call_griffon(player)
			if err != "":
				player.notify.emit(err)
		return false
	if it.id == "canne_peche":
		var fi := player.get_tree().get_first_node_in_group("fishing") as Fishing
		if fi:
			var msg := fi.use()
			if msg != "":
				player.notify.emit(msg)
		return false
	if not it.is_placeable() and not _is_farm_item(it):
		player.notify.emit("Garde-le en main : les bêtes qui l'aiment te suivent. Mène-les à une mangeoire.")
		return false
	if _target.is_empty():
		_target = find_spot(it)
	if _target.is_empty() or not _target.ok:
		player.notify.emit(_target.get("why", "Impossible de poser ici.") if not _target.is_empty() else "Impossible de poser ici.")
		return false
	var world := player.get_tree().get_first_node_in_group("world") as WorldGenerator
	var k: Vector3i = _target.key
	var done := false
	if _target.get("farm", false):
		return _farm_use(it, Vector2i(k.x, k.z))
	if it.is_block():
		# un escalier monte dans le sens du regard du héros
		var placed := it
		if it.has_meta("stair_variants"):
			var f := player.facing
			var dir := (0 if f.z < 0 else 2) if absf(f.z) >= absf(f.x) else (1 if f.x > 0 else 3)
			placed = Items.get_item(it.get_meta("stair_variants")[dir])
		done = world.build.place_block(k, placed)
	else:
		var rot := _rot_from_facing()
		done = world.build.place_furniture(Vector2i(k.x, k.z), float(_target.base), it, rot)
	if not done:
		return false
	player.inventory.remove(it, 1)
	Sound.play("door" if it.furniture_door else "place", Vector3(k.x + 0.5, float(k.y) + 0.5, k.z + 0.5))
	var at := Vector3(k.x + 0.5, float(_target.get("base", k.y)) + 0.5, k.z + 0.5)
	VoxelBurst.spawn(player, at, BuildMode.it_color(it) if it.is_block() else Color(0.75, 0.6, 0.4), 8, 1.8, 0.07, 0.3, "up", 6.0, false)
	player.visual.play_move("punch_1", 1.6)
	_target = {}
	return true


## Laboure (houe) ou sème (graines) sur la case.
func _farm_use(it: ItemData, col: Vector2i) -> bool:
	var fm := player.get_tree().get_first_node_in_group("farming") as Farming
	if fm == null or not fm.till(col):
		return false
	player.visual.play_move("heavy_1" if it.id == "houe" else "punch_1", 1.4)
	if player.inventory.count(Items.get_item("houe")) > 0:
		player._show_tool("houe")
	_target = {}
	if it.id == "houe":
		player.tilled.emit()
		return true
	if not fm.plant(col, it.crop):
		return false
	player.inventory.remove(it, 1)
	player.planted.emit(it.crop)
	return true


## Un meuble posé regarde le héros.
func _rot_from_facing() -> int:
	var f := Vector2(-player.facing.x, -player.facing.z)
	if absf(f.x) > absf(f.y):
		return 1 if f.x > 0.0 else 3
	return 0 if f.y > 0.0 else 2
