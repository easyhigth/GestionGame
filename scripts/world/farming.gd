class_name Farming
extends Node3D
## Agriculture : terre labourée (houe), cultures qui poussent en 4 stades, récolte à la main,
## et fermiers qui s'occupent des champs du village (poste « Champs »).
## Une culture pousse plus vite près de l'eau (champ arrosé) et moitié moins vite la nuit.

signal changed

## Cultures : durée de pousse (secondes de jeu, de semé à mûr), objet semé, récolte [objet, min, max],
## points de nourriture pour la réserve du village (par objet récolté par un fermier).
const CROPS := {
	"ble": {"name": "Blé", "time": 300.0, "seed": "graines_ble",
		"yield": [["ble", 2, 3], ["graines_ble", 1, 2]], "village_food": {"ble": 9.0}},
	"carotte": {"name": "Carottes", "time": 240.0, "seed": "carotte",
		"yield": [["carotte", 2, 4]], "village_food": {}},
	"pomme_de_terre": {"name": "Pommes de terre", "time": 360.0, "seed": "pomme_de_terre",
		"yield": [["pomme_de_terre", 3, 5]], "village_food": {"pomme_de_terre": 9.0}},
}
const STAGES := 4
## Pousse plus vite près de l'eau, moins vite la nuit.
const WATER_BONUS := 1.5
const NIGHT_RATE := 0.5
## Nombre de cases de champ par poste de fermier.
const PLOTS_PER_FARMER := 8
## Il faut au moins ce nombre de cases labourées pour ouvrir le poste « Champs ».
const MIN_PLOTS := 4

var world: WorldGenerator
## case -> {"c": culture, "g": pousse (s)}
var crops := {}
## Cases labourées (case -> true).
var plots := {}
## Graines confiées aux fermiers : identifiant -> nombre.
var seed_store := {}
## Poste de travail « Champs » (un faux lieu de travail partagé par les fermiers).
var fields_room := {}
var _nodes := {}          # case -> Node3D
var _models := {}         # "ble_2" -> PackedScene
var _tick := 0.0
var _claims := {}         # case -> habitant
var _pending_farmers: Array = []


func _ready() -> void:
	add_to_group("farming")
	top_level = true
	var t := RoomTypeData.new()
	t.id = "champs"
	t.display_name = "Champs"
	t.description = "Les cultures du village."
	t.color = Color("c8a040")
	t.job_id = "fermier"
	t.job_name = "Fermier"
	t.job_slots = 0
	t.effect_text = "Sème et récolte : remplit la réserve du village."
	fields_room = {"type": t, "cells": plots, "floor": 0.0, "tier": 0, "fields": true}
	if world == null:
		world = get_tree().get_first_node_in_group("world") as WorldGenerator
	if not SaveGame.farm_state.is_empty():
		import_state(SaveGame.farm_state)
		SaveGame.farm_state = {}
	else:
		_starter_field.call_deferred()


func _model(crop: String, stage: int) -> PackedScene:
	var key := "%s_%d" % [crop, stage]
	if not _models.has(key):
		_models[key] = load("res://assets/environment/models/crop_%s.glb" % key)
	return _models[key]


# ---------------------------------------------------------------- champs

## Un petit champ de blé déjà semé à côté du village (nouvelle partie).
func _starter_field() -> void:
	if world == null:
		return
	var origin := world.spawn_cell + Vector2i(3, 5)
	for dz in 2:
		for dx in 3:
			var c := origin + Vector2i(dx, dz)
			if till(c, true):
				plant(c, "ble", 0.55)
	_update_slots()


## Vrai si on peut labourer cette case (herbe ou terre, rien dessus).
func can_till(cell: Vector2i) -> bool:
	if world == null:
		return false
	var t := world.terrain_type(cell)
	if t == WorldGenerator.FARM:
		return true
	if t != WorldGenerator.GRASS and t != WorldGenerator.DIRT:
		return false
	if world.decor_at(cell) != WorldGenerator.D_NONE and world.decor_at(cell) not in [WorldGenerator.D_GRASS, WorldGenerator.D_FLOWERS]:
		return false
	var h := world.terrain_height(cell)
	if not world.build.column(cell).is_empty() or not world.build.furniture_in(cell).is_empty():
		return false
	if world.village_prop_at(cell, h) != null:
		return false
	return absf(h - world.cell_center(world.spawn_cell).y) < 30.0


## Laboure une case. Vrai si c'est fait (ou si elle l'était déjà).
func till(cell: Vector2i, quiet := false) -> bool:
	if not can_till(cell):
		return false
	if world.terrain_type(cell) != WorldGenerator.FARM:
		world.remove_decor(cell, false)
		world.set_terrain_type(cell, WorldGenerator.FARM)
		world.refresh_cells([cell])
		if not quiet:
			var at := world.cell_center(cell) + Vector3(0, 0.1, 0)
			Sound.play("dig", at)
			VoxelBurst.spawn(self, at, Color(0.45, 0.32, 0.2), 10, 2.4, 0.08, 0.4, "up", 9.0, false)
	plots[cell] = true
	_update_slots()
	changed.emit()
	return true


## Sème une culture sur une case labourée. `grown` : part déjà poussée (0 à 1).
func plant(cell: Vector2i, crop: String, grown := 0.0) -> bool:
	if not CROPS.has(crop) or crops.has(cell) or world == null or world.terrain_type(cell) != WorldGenerator.FARM:
		return false
	crops[cell] = {"c": crop, "g": float(CROPS[crop].time) * clampf(grown, 0.0, 0.99)}
	plots[cell] = true
	_show(cell)
	changed.emit()
	return true


func crop_at(cell: Vector2i) -> Dictionary:
	return crops.get(cell, {})


func stage_of(cell: Vector2i) -> int:
	var c: Dictionary = crops.get(cell, {})
	if c.is_empty():
		return -1
	var total: float = CROPS[c.c].time
	if c.g >= total:
		return STAGES - 1
	return clampi(floori(c.g / total * float(STAGES - 1)), 0, STAGES - 2)


func is_ripe(cell: Vector2i) -> bool:
	return stage_of(cell) == STAGES - 1


## Récolte une culture mûre : renvoie [[ItemData, nombre], ...] (vide si rien à récolter).
func harvest(cell: Vector2i) -> Array:
	if not is_ripe(cell):
		return []
	var c: Dictionary = crops[cell]
	var out := []
	for y in CROPS[c.c].yield:
		var it := Items.get_item(y[0])
		if it:
			out.append([it, randi_range(y[1], y[2])])
	_remove(cell)
	var at := world.cell_center(cell) + Vector3(0, 0.3, 0)
	Sound.play("step_grass", at)
	VoxelBurst.spawn(self, at, Color(0.85, 0.72, 0.3) if c.c == "ble" else Color(0.4, 0.7, 0.3), 14, 2.6, 0.08, 0.45, "up", 8.0, false)
	return out


## Arrache une culture pas encore mûre : rend la graine. Renvoie l'objet rendu (ou null).
func uproot(cell: Vector2i) -> ItemData:
	var c: Dictionary = crops.get(cell, {})
	if c.is_empty():
		return null
	_remove(cell)
	var at := world.cell_center(cell) + Vector3(0, 0.2, 0)
	Sound.play("step_grass", at)
	VoxelBurst.spawn(self, at, Color(0.4, 0.7, 0.3), 8, 2.0, 0.07, 0.35, "up", 8.0, false)
	return Items.get_item(CROPS[c.c].seed)


func _remove(cell: Vector2i) -> void:
	crops.erase(cell)
	_claims.erase(cell)
	if _nodes.has(cell):
		if is_instance_valid(_nodes[cell]):
			_nodes[cell].queue_free()
		_nodes.erase(cell)
	changed.emit()


func _show(cell: Vector2i) -> void:
	var c: Dictionary = crops.get(cell, {})
	if c.is_empty() or world == null:
		return
	var stage := stage_of(cell)
	var old: Node3D = _nodes.get(cell)
	if old and is_instance_valid(old) and int(old.get_meta("stage", -1)) == stage:
		return
	if old and is_instance_valid(old):
		old.queue_free()
	var scene := _model(c.c, stage)
	if scene == null:
		return
	var n := scene.instantiate() as Node3D
	n.set_meta("stage", stage)
	add_child(n)
	n.global_position = world.cell_center(cell)
	n.rotation.y = float(absi(hash(cell)) % 4) * PI * 0.5
	_nodes[cell] = n


## Vitesse de pousse d'une case (eau, nuit).
func growth_rate(cell: Vector2i) -> float:
	var r := 1.0
	var w := get_tree().get_first_node_in_group("weather") as Weather
	if world and (world.near_water(cell) or (w and w.waters_fields())):
		r *= WATER_BONUS
	elif w and w.drought():
		r *= Weather.DROUGHT_RATE
	var dc := get_tree().get_first_node_in_group("day_cycle") as DayCycle
	if dc and dc.is_night():
		r *= NIGHT_RATE
	var se := get_tree().get_first_node_in_group("seasons")
	if se:
		r *= se.crop_rate()
	return r


func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	var step := 1.0 - _tick
	_tick = 1.0
	grow(step)


## Fait pousser toutes les cultures de `seconds` (et nettoie les champs recouverts ou creusés).
func grow(seconds: float) -> void:
	if world == null:
		return
	var dc := get_tree().get_first_node_in_group("day_cycle") as DayCycle
	var night := dc != null and dc.is_night()
	for cell in plots.keys():
		if world.terrain_type(cell) != WorldGenerator.FARM or not world.build.column(cell).is_empty():
			plots.erase(cell)
			if crops.has(cell):
				_remove(cell)
			_update_slots()
	var water := {}
	var w := get_tree().get_first_node_in_group("weather") as Weather
	var rain := w != null and w.waters_fields()
	var dry := w != null and w.drought()
	var se := get_tree().get_first_node_in_group("seasons")
	var season_rate: float = se.crop_rate() if se else 1.0
	for cell in crops.keys():
		var c: Dictionary = crops[cell]
		var total: float = CROPS[c.c].time
		if c.g >= total:
			continue
		if not water.has(cell):
			water[cell] = rain or world.near_water(cell)
		var r := (WATER_BONUS if water[cell] else (Weather.DROUGHT_RATE if dry else 1.0)) * (NIGHT_RATE if night else 1.0) * season_rate
		var before := stage_of(cell)
		c.g = minf(total, c.g + seconds * r)
		if stage_of(cell) != before:
			_show(cell)
	# les fermiers qui se libèrent
	for cell in _claims.keys():
		var v = _claims[cell]
		if not is_instance_valid(v) or v.get("work_room") != fields_room:
			_claims.erase(cell)
	if not _pending_farmers.is_empty():
		_assign_pending()


# ---------------------------------------------------------------- fermiers

func _update_slots() -> void:
	var t: RoomTypeData = fields_room.type
	t.job_slots = 0 if plots.size() < MIN_PLOTS else maxi(1, ceili(float(plots.size()) / PLOTS_PER_FARMER))


## Le poste « Champs » est ouvert (assez de cases labourées).
func has_fields() -> bool:
	return plots.size() >= MIN_PLOTS


## Travail pour un fermier : {"cell", "kind": "harvest" | "plant", "crop"} ou {} s'il n'y a rien à faire.
func claim_task(v: Node) -> Dictionary:
	var best := {}
	var best_d := INF
	var pos: Vector3 = v.global_position
	var wanted := _wanted_crop()
	for cell in plots:
		if _claims.has(cell) and _claims[cell] != v:
			continue
		var d := pos.distance_to(world.cell_center(cell))
		var task := {}
		if is_ripe(cell):
			task = {"cell": cell, "kind": "harvest"}
			d -= 4.0   # la récolte d'abord
		elif not crops.has(cell) and wanted != "":
			task = {"cell": cell, "kind": "plant", "crop": wanted}
		if task.is_empty() or d >= best_d:
			continue
		best = task
		best_d = d
	if not best.is_empty():
		_claims[best.cell] = v
	return best


## Culture à semer sur une case vide : celle dont on a le plus de graines en réserve.
func _wanted_crop() -> String:
	var best := ""
	var n := 0
	for crop in CROPS:
		var have := int(seed_store.get(CROPS[crop].seed, 0))
		if have > n:
			n = have
			best = crop
	return best


func release(cell: Vector2i) -> void:
	_claims.erase(cell)


## Un fermier fait son travail sur la case : récolte (tout va dans la réserve du village, on ressème
## avec une graine de la récolte) ou semis (avec une graine de la réserve). Renvoie le texte à afficher.
func do_task(v: Node, task: Dictionary) -> String:
	var cell: Vector2i = task.cell
	_claims.erase(cell)
	if task.kind == "harvest":
		if not is_ripe(cell):
			return ""
		var crop: String = crops[cell].c
		var got := harvest(cell)
		var needs := get_tree().get_first_node_in_group("village_needs") as VillageNeeds
		var seed_id: String = CROPS[crop].seed
		var replanted := false
		var points := 0.0
		var names := []
		for g in got:
			var it: ItemData = g[0]
			var n: int = g[1]
			if it.id == seed_id and not replanted:
				n -= 1
				replanted = plant(cell, crop)
			if n <= 0:
				continue
			var value: float = float(CROPS[crop].village_food.get(it.id, it.food))
			if it.id == seed_id and it.food <= 0.0:
				seed_store[it.id] = int(seed_store.get(it.id, 0)) + n
				continue
			# une partie des légumes est gardée comme semence
			if it.id == seed_id and int(seed_store.get(it.id, 0)) < 6:
				seed_store[it.id] = int(seed_store.get(it.id, 0)) + 1
				n -= 1
			points += value * n
			names.append("%d %s" % [n, it.display_name.to_lower()])
		if needs and points > 0.0:
			needs.add_food(points)
		changed.emit()
		return "%s récolte : %s (réserve +%d)" % [v.get("villager_name"), ", ".join(PackedStringArray(names)), roundi(points)] if points > 0.0 else ""
	if task.kind == "plant":
		var crop2: String = task.crop
		var sid: String = CROPS[crop2].seed
		if int(seed_store.get(sid, 0)) <= 0 or crops.has(cell):
			return ""
		if plant(cell, crop2):
			seed_store[sid] = int(seed_store[sid]) - 1
			if seed_store[sid] <= 0:
				seed_store.erase(sid)
			changed.emit()
	return ""


## Confie aux fermiers toutes les graines (et légumes à planter) du sac. Renvoie le nombre donné.
func deposit_seeds(p: Player) -> int:
	var total := 0
	for e in p.inventory.entries.duplicate():
		var it := e.item as ItemData
		if it and it.is_seed():
			var n: int = e.count
			if p.inventory.remove(it, n):
				seed_store[it.id] = int(seed_store.get(it.id, 0)) + n
				total += n
	if total > 0:
		Sound.ui("craft")
		changed.emit()
	return total


func seeds_count() -> int:
	var n := 0
	for id in seed_store:
		n += int(seed_store[id])
	return n


## Résumé pour le panneau du royaume.
func summary() -> Dictionary:
	var ripe := 0
	var by_crop := {}
	for cell in crops:
		by_crop[crops[cell].c] = int(by_crop.get(crops[cell].c, 0)) + 1
		if is_ripe(cell):
			ripe += 1
	return {"plots": plots.size(), "planted": crops.size(), "ripe": ripe, "by_crop": by_crop}


## Milieu des champs (là où les fermiers attendent).
func fields_center() -> Vector3:
	if plots.is_empty() or world == null:
		return Vector3.ZERO
	var s := Vector3.ZERO
	for cell in plots:
		s += world.cell_center(cell)
	return s / float(plots.size())


func farmers() -> Array:
	return get_tree().get_nodes_in_group("villagers").filter(func(v): return v.get("work_room") == fields_room)


func _assign_pending() -> void:
	var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
	if k == null:
		return
	for v in get_tree().get_nodes_in_group("villagers"):
		if v.get("villager_name") in _pending_farmers and v.get("work_room") == null and not v.get("companion"):
			k.assign(v, fields_room)
	_pending_farmers.clear()


# ---------------------------------------------------------------- sauvegarde

func export_state() -> Dictionary:
	var cs := []
	for cell in crops:
		cs.append([cell.x, cell.y, crops[cell].c, crops[cell].g])
	var ps := []
	for cell in plots:
		ps.append([cell.x, cell.y])
	return {"crops": cs, "plots": ps, "seeds": seed_store.duplicate(),
		"farmers": farmers().map(func(v): return v.villager_name)}


func import_state(d: Dictionary) -> void:
	for n in _nodes.values():
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	crops.clear()
	plots.clear()
	for p in d.get("plots", []):
		plots[Vector2i(int(p[0]), int(p[1]))] = true
	for c in d.get("crops", []):
		var cell := Vector2i(int(c[0]), int(c[1]))
		if CROPS.has(str(c[2])):
			crops[cell] = {"c": str(c[2]), "g": float(c[3])}
			plots[cell] = true
			_show(cell)
	seed_store = {}
	var s: Dictionary = d.get("seeds", {})
	for id in s:
		seed_store[id] = int(s[id])
	_pending_farmers = d.get("farmers", []).duplicate()
	_update_slots()
	changed.emit()
