class_name Kingdom
extends Node
## Le royaume : repère les pièces construites par le joueur (espace fermé par des murs, avec
## au moins une porte), leur donne un type selon le mobilier posé dedans (forge, boulangerie...),
## calcule l'âge de l'empire (matériaux des murs) et le rang de la cité (nombre de pièces),
## fait produire les pièces où travaillent des habitants, et donne des bonus au héros.

signal changed
signal age_changed(age: int)
signal rank_changed(rank: int)

const ROOMS_DIR := "res://data/rooms/"
## Taille maximum d'une pièce (au-delà, on considère que l'espace n'est pas fermé).
const MAX_ROOM_CELLS := 400
const AGE_NAMES := ["Âge du Bois", "Âge de la Pierre", "Âge de la Pierre taillée", "Âge de la Pierre polie", "Âge du Marbre", "Âge d'Or"]
const AGE_COLORS := [Color("c8a060"), Color("a8a8a0"), Color("c0c8d0"), Color("e0e4ec"), Color("f4f0e8"), Color("ffd24a")]
const RANK_NAMES := ["Campement", "Hameau", "Village", "Bourg", "Ville", "Cité", "Capitale d'empire"]
## Pièces reconnues nécessaires pour chaque rang, et âge minimum.
const RANK_ROOMS := [0, 1, 3, 6, 10, 15, 22]
const RANK_AGE := [0, 0, 0, 1, 2, 3, 4]
## Affinités des races pour les métiers (identifiant du modèle -> métiers préférés).
const RACE_AFFINITY := {
	"dwarf": ["forgeron", "macon", "architecte"], "human": ["marchand", "fermier", "boulanger", "architecte"], "elf": ["erudit", "mage", "tisserand", "alchimiste"],
	"orc": ["garde", "bucheron"], "ogre": ["garde", "macon"], "goblin": ["marchand", "bucheron", "dresseur"],
	"hobgoblin": ["forgeron", "garde"], "kijin": ["garde", "forgeron"], "lizard": ["fermier", "garde"],
	"lycan": ["garde", "bucheron", "dresseur"], "beastfolk": ["fermier", "bucheron", "dresseur"], "dryad": ["fermier", "tisserand", "alchimiste"],
	"fairy": ["tisserand", "mage", "alchimiste"], "slime": ["aubergiste", "verrier"], "vampire": ["erudit", "marchand", "alchimiste"],
	"demon": ["mage", "forgeron", "enchanteur"], "dragonoid": ["forgeron", "garde"], "harpy": ["marchand", "tisserand"],
	"spirit": ["mage", "pretre", "enchanteur"], "angel": ["pretre", "erudit", "enchanteur"], "insectoid": ["macon", "tisserand", "architecte"],
	"undead": ["macon", "erudit"],
}

@export var build: BuildGrid
@export var world: WorldGenerator

var room_types: Array[RoomTypeData] = []
## Pièces : { cells (Dictionary Vector2i -> true), floor, center (Vector3), doors, enclosed,
##   type (RoomTypeData ou null), counts, tier, anchor (Vector2i), label }
var rooms: Array = []
var age := 0
var rank := 0
var _dirty := true
var _timer := 0.0
var _labels_root: Node3D
var _show_hints := false
var _prod_timers := {}   # habitant -> temps


func _ready() -> void:
	add_to_group("kingdom")
	if build == null:
		build = get_parent().get_node_or_null("Build") as BuildGrid
	if world == null:
		world = get_parent() as WorldGenerator
	if build:
		build.changed.connect(func(): _dirty = true)
	var dir := DirAccess.open(ROOMS_DIR)
	if dir:
		for f in dir.get_files():
			f = f.trim_suffix(".remap")
			if f.ends_with(".tres"):
				room_types.append(load(ROOMS_DIR + f))
	_labels_root = Node3D.new()
	_labels_root.name = "Etiquettes"
	add_child(_labels_root)


## Montre aussi les pièces non terminées (en mode construction).
func set_show_hints(on: bool) -> void:
	_show_hints = on
	_refresh_labels()


func _process(delta: float) -> void:
	_timer -= delta
	if _dirty and _timer <= 0.0:
		_dirty = false
		_timer = 0.25
		recompute()
	_produce(delta)


# ---------------------------------------------------------------- détection des pièces

func _wall_at(cell: Vector2i, floor_y: float) -> int:
	# 0 = libre, 1 = mur, 2 = porte, -1 = hors du monde
	if world and not world._inside(cell):
		return -1
	var probe := floor_y + 1.2
	for f in build.furniture_in(cell):
		if (f.item as ItemData).furniture_door and absf(f.base - floor_y) < 0.6:
			return 2
	for b in build.column(cell):
		if b[1] <= probe and b[2] > probe:
			return 1
	if world and world.terrain_height(cell) >= probe:
		return 1
	return 0


func recompute() -> void:
	rooms = []
	var assigned := {}   # clé de meuble -> true
	for fk in build.furniture:
		var f: Dictionary = build.furniture[fk]
		if assigned.has(fk) or (f.item as ItemData).furniture_door:
			continue
		var room := _flood(f.col, f.base)
		for c in room.cells:
			for g in build.furniture_in(c):
				if absf(g.base - room.floor) < 0.6:
					assigned[build.furniture_key(c, g.base)] = true
		rooms.append(room)
	for r in rooms:
		_classify(r)
	# les habitants gardent leur poste si leur pièce existe toujours
	for v in get_tree().get_nodes_in_group("villagers"):
		var wr = v.get("work_room")
		if wr == null or wr.get("fields", false):
			continue
		var found = null
		for r in rooms:
			if r.type and wr.type and r.type.id == wr.type.id:
				for c in wr.cells:
					if r.cells.has(c):
						found = r
						break
			if found:
				break
		v.set("work_room", found)
	_update_age_rank()
	_refresh_labels()
	changed.emit()


func _flood(start: Vector2i, floor_y: float) -> Dictionary:
	var cells := {start: true}
	var queue := [start]
	var walls := {}
	var doors := {}
	var enclosed := true
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if cells.has(n) or walls.has(n):
				continue
			var w := _wall_at(n, floor_y)
			if w == -1:
				enclosed = false
				continue
			if w > 0:
				walls[n] = true
				if w == 2:
					doors[n] = true
				continue
			cells[n] = true
			if cells.size() > MAX_ROOM_CELLS:
				enclosed = false
				queue.clear()
				break
			queue.append(n)
	var room := {"cells": cells, "floor": floor_y, "walls": walls, "doors": doors.size(), "enclosed": enclosed,
		"type": null, "counts": {}, "tier": 0, "anchor": start, "label": null, "missing": {}, "closest": null}
	# mobilier de la pièce
	var counts := {}
	var sum := Vector3.ZERO
	for c in cells:
		sum += Vector3(c.x + 0.5, 0, c.y + 0.5)
		for f in build.furniture_in(c):
			if absf(f.base - floor_y) < 0.6:
				var id: String = f.item.id
				counts[id] = int(counts.get(id, 0)) + 1
	room.counts = counts
	room.center = sum / maxf(cells.size(), 1.0) + Vector3(0, floor_y, 0)
	# âge des murs : matériau de la plupart des blocs (on tolère quelques blocs plus simples)
	var tiers := []
	for w in walls:
		for b in build.column(w):
			if b[1] < floor_y + 3.0 and b[2] > floor_y:
				tiers.append((b[3] as ItemData).block_tier)
	tiers.sort()
	room.tier = tiers[int(tiers.size() * 0.25)] if not tiers.is_empty() else 0
	return room


func _classify(r: Dictionary) -> void:
	if not r.enclosed or r.doors == 0:
		return
	var best: RoomTypeData = null
	var best_score := -1
	var closest: RoomTypeData = null
	var closest_missing := 99
	for t in room_types:
		var miss := t.missing(r.counts)
		var n_miss := 0
		for k in miss:
			n_miss += int(miss[k])
		var size_ok: bool = r.cells.size() >= t.min_cells
		if n_miss == 0 and size_ok:
			var score := 0
			for k in t.required:
				score += int(t.required[k])
			if score > best_score:
				best_score = score
				best = t
		else:
			var shared := false
			for k in t.required:
				if r.counts.has(k):
					shared = true
			if shared and n_miss < closest_missing:
				closest_missing = n_miss
				closest = t
				r.missing = miss
				r["too_small"] = not size_ok
	r.type = best
	r.closest = closest if best == null else null
	if best:
		r.missing = {}


func _update_age_rank() -> void:
	var typed := rooms.filter(func(r): return r.type != null)
	var new_age := 0
	for t in range(1, 6):
		var n := typed.filter(func(r): return r.tier >= t).size()
		if n >= (3 if t == 5 else 2):
			new_age = t
	var new_rank := 0
	for i in RANK_NAMES.size():
		if typed.size() >= RANK_ROOMS[i] and new_age >= RANK_AGE[i]:
			new_rank = i
	if new_age != age:
		var up := new_age > age
		age = new_age
		if up:
			age_changed.emit(age)
	if new_rank != rank:
		var up2 := new_rank > rank
		rank = new_rank
		if up2:
			rank_changed.emit(rank)


func title() -> String:
	# la nation nommée à la fin de l'histoire
	var st := get_tree().get_first_node_in_group("story") if is_inside_tree() else null
	var t := "%s · %s" % [RANK_NAMES[rank], AGE_NAMES[age]]
	if st and st.nation_name() != "":
		t = "%s · %s" % [st.nation_name(), AGE_NAMES[age]]
	# le nom choisi par le joueur (Bannière et trophées)
	var her := get_tree().get_first_node_in_group("heraldry") if is_inside_tree() else null
	if her and str(her.custom_name) != "":
		t = "%s · %s" % [her.custom_name, AGE_NAMES[age]]
	# provinces conquises (voir Diplomacy)
	var dip := get_tree().get_first_node_in_group("diplomacy") if is_inside_tree() else null
	var np: int = dip.provinces().size() if dip else 0
	if np >= 3:
		t = "Empire · " + t
	if np > 0:
		t += " · %d province%s" % [np, "s" if np > 1 else ""]
	return t


## Ce qu'il faut pour le rang suivant (texte).
func next_goal() -> String:
	if rank >= RANK_NAMES.size() - 1:
		return "Votre empire est à son apogée."
	var typed := rooms.filter(func(r): return r.type != null).size()
	var i := rank + 1
	var parts := []
	if typed < RANK_ROOMS[i]:
		parts.append("%d pièces reconnues (%d/%d)" % [RANK_ROOMS[i], typed, RANK_ROOMS[i]])
	if age < RANK_AGE[i]:
		parts.append("atteindre l'%s" % AGE_NAMES[RANK_AGE[i]])
	return "Pour devenir %s : %s." % [RANK_NAMES[i], ", ".join(parts)]


func next_age_goal() -> String:
	if age >= 5:
		return "Vous avez atteint l'âge d'Or."
	return "Pour l'%s : %d pièces reconnues aux murs en %s (ou mieux)." % [AGE_NAMES[age + 1], 3 if age + 1 == 5 else 2, ItemData.TIER_NAMES[age + 1].to_lower()]


# ---------------------------------------------------------------- étiquettes

func _refresh_labels() -> void:
	for c in _labels_root.get_children():
		c.queue_free()
	for r in rooms:
		var text := ""
		var color := Color.WHITE
		var sub := ""
		if r.type:
			var t: RoomTypeData = r.type
			text = t.display_name
			color = t.color.lightened(0.2)
			sub = ItemData.TIER_NAMES[r.tier]
			if t.job_slots > 0:
				sub += " · %s %d/%d" % [t.job_name, workers_of(r).size(), t.job_slots]
			if t.beds > 0:
				sub += " · %d lits" % t.beds
		elif _show_hints:
			color = Color("c8c0b0")
			if not r.enclosed:
				text = "Pas fermé"
				sub = "Entoure de murs (2 blocs de haut) avec une porte"
			elif r.doors == 0:
				text = "Pièce sans porte"
				sub = "Pose une porte dans un mur"
			elif r.closest:
				text = "%s ?" % r.closest.display_name
				var parts := []
				for k in r.missing:
					var it: ItemData = Items.get_item(k)
					parts.append("%d %s" % [r.missing[k], it.display_name if it else k])
				sub = "Il manque : " + ", ".join(parts) if parts else ""
				if r.get("too_small", false):
					sub += (" · " if sub != "" else "") + "pièce trop petite (%d cases min.)" % r.closest.min_cells
			else:
				text = "Pièce"
				sub = "Pose le mobilier d'un type de pièce"
		if text == "":
			continue
		var l := Label3D.new()
		l.text = text + ("\n" + sub if sub != "" else "")
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.modulate = color
		l.outline_modulate = Color(0.06, 0.04, 0.03)
		l.font_size = 40 if r.type else 30
		l.outline_size = 10
		l.pixel_size = 0.006
		l.render_priority = 6
		l.outline_render_priority = 5
		_labels_root.add_child(l)
		l.global_position = r.center + Vector3(0, 2.6, 0)
		r.label = l


# ---------------------------------------------------------------- travail et production

## La pièce qui contient cette case (au bon étage), ou null.
func room_at(cell: Vector2i, floor_y: float) -> Variant:
	for r in rooms:
		if r.cells.has(cell) and absf(r.floor - floor_y) < 1.0:
			return r
	return null


func typed_rooms() -> Array:
	return rooms.filter(func(r): return r.type != null)


## Pièces qui proposent des postes de travail.
func workplaces() -> Array:
	var out := rooms.filter(func(r): return r.type != null and (r.type as RoomTypeData).job_slots > 0)
	# les champs du village (poste « Champs » des fermiers)
	var fm := get_tree().get_first_node_in_group("farming") as Farming
	if fm and fm.has_fields():
		out.append(fm.fields_room)
	return out


func workers_of(room: Dictionary) -> Array:
	var out := []
	for v in get_tree().get_nodes_in_group("villagers"):
		if v.get("work_room") == room:
			out.append(v)
	return out


## Affinité d'un habitant pour un métier (0.6 à 1.6) : race + talent personnel.
static func affinity(villager: Node, job_id: String) -> float:
	var a := 1.0
	var race: RaceData = villager.get("race")
	if race and RACE_AFFINITY.get(race.model_id, []).has(job_id):
		a += 0.4
	var talents: Dictionary = villager.get("talents") if villager.get("talents") != null else {}
	a += float(talents.get(job_id, 0.0))
	# un habitant heureux travaille plus vite, un malheureux plus lentement
	var mood = villager.get("work_mult")
	return clampf(a, 0.5, 1.8) * (float(mood) if mood != null else 1.0)


func assign(villager: Node, room: Variant) -> bool:
	if room == null:
		villager.set("work_room", null)
		changed.emit()
		_refresh_labels()
		return true
	var t: RoomTypeData = room.type
	if t == null or workers_of(room).size() >= t.job_slots:
		return false
	if villager.get("companion"):
		villager.call("set_companion", false)
	villager.set("work_room", room)
	changed.emit()
	_refresh_labels()
	return true


func _produce(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	for v in get_tree().get_nodes_in_group("villagers"):
		var room = v.get("work_room")
		if room == null or not rooms.has(room) or room.type == null:
			continue
		var t: RoomTypeData = room.type
		if (t.production == null and t.production_pool.is_empty()) or not v.call("is_at_work"):
			continue
		var speed: float = affinity(v, t.job_id) * (1.0 + 0.15 * room.tier)
		_prod_timers[v] = float(_prod_timers.get(v, 0.0)) + delta * speed
		if _prod_timers[v] >= t.production_interval:
			_prod_timers[v] = 0.0
			var prod: ItemData = t.production_pool.pick_random() if not t.production_pool.is_empty() else t.production
			var needs := get_tree().get_first_node_in_group("village_needs") as VillageNeeds
			if prod.is_food() and needs:
				# la nourriture va dans la réserve du village
				needs.add_food(prod.food * t.production_count)
				if player:
					player.notify.emit("%s (%s) : réserve du village +%d %s" % [t.display_name, v.get("villager_name"), t.production_count, prod.display_name])
			elif player:
				player.inventory.add(prod, t.production_count)
				player.notify.emit("%s (%s) : +%d %s" % [t.display_name, v.get("villager_name"), t.production_count, prod.display_name])


## Bonus des pièces pour le héros (un seul par type de pièce).
func hero_bonus(key: String) -> float:
	var seen := {}
	var total := 0.0
	for r in rooms:
		if r.type and not seen.has(r.type.id):
			seen[r.type.id] = true
			total += float((r.type as RoomTypeData).hero_bonus.get(key, 0.0))
	return total


## Habitants au départ, sans lit construit.
const BASE_POPULATION := 8


## Nombre maximal d'habitants : la population de départ + les lits des maisons et dortoirs.
func population_cap() -> int:
	return BASE_POPULATION + beds()


func beds() -> int:
	var n := 0
	for r in rooms:
		if r.type:
			n += (r.type as RoomTypeData).beds
	return n

