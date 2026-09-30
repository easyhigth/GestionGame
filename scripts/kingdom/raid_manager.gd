class_name RaidManager
extends Node3D
## Menaces sur la ville : de temps en temps, une bande de pillards attaque le village.
## Le raid est annoncé à l'avance (d'où ils arrivent, dans combien de temps). Les pillards
## s'en prennent aux habitants et au héros, et cassent les murs construits qui les gênent.
## Les gardes (habitants au camp d'entraînement) défendent tout le village avec un bonus.
## Tous les pillards vaincus : butin et expérience. Sinon, au bout du temps, ils repartent
## en volant une partie des ressources du sac.

signal raid_warning(raid: Dictionary)
signal raid_started(raid: Dictionary)
signal raid_ended(raid: Dictionary, repelled: bool, text: String)

## Premier raid après ce temps de jeu (secondes), puis entre `interval.x` et `interval.y`.
@export var first_delay: float = 480.0
@export var interval := Vector2(600.0, 840.0)
## Temps entre l'annonce et l'arrivée des pillards.
@export var warning_time: float = 45.0
## Durée maximale du raid avant que les pillards repartent avec leur butin.
@export var raid_duration: float = 210.0
## Distance du village où les pillards apparaissent.
@export var spawn_distance: float = 34.0
@export var enabled := true

## Bandes de pillards selon le niveau du héros : [niveau min, nom, monstres, chef, niveau de base].
const TIERS := [
	[1, "Gobelins pillards", ["gobelin_pillard", "gobelin_pillard", "loup"], "loup_alpha", 1],
	[5, "Horde d'orcs", ["gobelin_pillard", "orc_brute", "homme_lezard"], "orc_brute", 4],
	[9, "Clan des ogres", ["orc_brute", "harpie", "homme_lezard"], "ogre", 8],
	[13, "Légion des cendres", ["demon", "salamandre", "slime_magma"], "seigneur_demon", 12],
]
const DIRECTIONS := ["de l'est", "du sud-est", "du sud", "du sud-ouest", "de l'ouest", "du nord-ouest", "du nord", "du nord-est"]

var world: WorldGenerator
## Raid en cours : {} ou {state, name, count, dir_text, spawn, timer, raiders, broken}.
var raid := {}
var _timer := 0.0
var _siege_timer := 0.0
var _raids_done := 0


func _ready() -> void:
	add_to_group("raids")
	world = get_parent() as WorldGenerator
	_timer = first_delay * SaveGame.raid_delay_mult()


func village_center() -> Vector3:
	return world.cell_center(world.spawn_cell)


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func _process(delta: float) -> void:
	if world == null or Engine.is_editor_hint():
		return
	if raid.is_empty():
		if not enabled:
			return
		_timer -= delta
		if _timer <= 0.0:
			var p := _player()
			# pas de raid pendant que le héros est dans un donjon : on attend qu'il en sorte
			if p and p.global_position.y < WorldGenerator.UNDERGROUND:
				_timer = 20.0
			else:
				announce()
		return
	raid.timer -= delta
	match raid.state:
		"warning":
			if raid.timer <= 0.0:
				_start()
		"active":
			_update_active(delta)


## Annonce un raid (appelé automatiquement ; utilisable pour tester).
func announce() -> void:
	var p := _player()
	var lv := p.level if p else 1
	var tier: Array = TIERS[0]
	for t in TIERS:
		if lv >= int(t[0]):
			tier = t
	var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
	var rank := k.rank if k else 0
	var count := clampi(3 + rank + lv / 4, 3, 10)
	var angle := randf() * TAU
	var dir_i := posmod(roundi(angle / (TAU / 8.0)), 8)
	var center := village_center()
	var spot := center + Vector3(cos(angle), 0, sin(angle)) * spawn_distance
	var cell := world._find_site(world.cell_at(spot), -1, 14)
	if cell.x >= 0:
		spot = world.cell_center(cell)
	else:
		spot = center + Vector3(cos(angle), 0, sin(angle)) * 14.0
		spot.y = world.ground_height_at(spot + Vector3(0, 3, 0))
	raid = {"state": "warning", "name": tier[1], "types": tier[2], "leader": tier[3], "base": tier[4],
		"count": count, "level": lv, "dir_text": DIRECTIONS[dir_i], "spawn": spot, "timer": warning_time,
		"raiders": [], "broken": 0, "angle": angle}
	raid_warning.emit(raid)


func _start() -> void:
	raid.state = "active"
	Sound.play("horn", Vector3.INF, 0.0, 0.0)
	raid.timer = raid_duration
	var scene := load("res://scenes/enemies/enemy.tscn") as PackedScene
	var center := village_center()
	var spot: Vector3 = raid.spawn
	world.load_area(spot)
	for i in raid.count:
		var e := scene.instantiate() as Enemy
		var id: String = raid.leader if i == 0 else raid.types[i % raid.types.size()]
		e.data = load("res://data/enemies/%s.tres" % id)
		e.level = maxi(1, int(raid.level) + (1 if i == 0 else randi_range(-1, 0)))
		e.power = 1.0 + 0.07 * maxi(0, e.level - int(raid.base))
		e.set_meta("raider", true)
		add_child(e)
		var off := Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
		var pos: Vector3 = spot + off
		pos.y = world.ground_height_at(pos + Vector3(0, 2, 0))
		e.global_position = pos
		# ils marchent sur le village
		e.home = center
		e.set("_wander_to", center)
		e.set("_returning", true)
		raid.raiders.append(e)
	# les gardes défendent tout le village
	for v in get_tree().get_nodes_in_group("villagers"):
		if _is_guard(v):
			v.set("defend_radius", 45.0)
			v.set("alert_radius", 16.0)
			v.set("guard_bonus", 0.35)
	raid_started.emit(raid)


static func _is_guard(v: Node) -> bool:
	var wr = v.get("work_room")
	return wr != null and wr.type != null and (wr.type as RoomTypeData).job_id == "garde"


func alive_raiders() -> Array:
	if raid.is_empty():
		return []
	return raid.raiders.filter(func(e): return is_instance_valid(e) and e.is_alive())


func _update_active(delta: float) -> void:
	var alive := alive_raiders()
	if alive.is_empty():
		_end(true)
		return
	if raid.timer <= 0.0:
		_end(false)
		return
	# sans cible, un pillard retourne vers le village ; bloqué par un mur, il le casse
	_siege_timer -= delta
	var siege := _siege_timer <= 0.0
	if siege:
		_siege_timer = 0.9
	var center := village_center()
	for e in alive:
		var tgt = e.get("_target")
		if tgt == null:
			if Vector2(e.global_position.x - center.x, e.global_position.z - center.z).length() > 4.0:
				e.set("_wander_to", _next_waypoint(e, center, delta))
				e.set("_returning", true)
		if siege and (tgt == null or e.global_position.distance_to(tgt.global_position) > 3.0):
			_break_near(e)


## Prochain point du chemin vers le village (contourne arbres et rochers ; tout droit si des murs bloquent).
func _next_waypoint(e: Enemy, center: Vector3, delta: float) -> Vector3:
	# on vise le bord de la place, pas le feu de camp lui-même
	var away := e.global_position - center
	away.y = 0.0
	center += away.normalized() * 3.0 if away.length() > 0.1 else Vector3(3, 0, 0)
	var path: Array = e.get_meta("raid_path", [])
	var t: float = e.get_meta("raid_repath", 0.0) - delta
	if path.is_empty() and t <= 0.0:
		t = randf_range(5.0, 7.0)
		path = world.find_path(e.global_position, center, 900, true)
		# les obstacles du décor sont évités par la recherche de chemin (cabanes, arbres...)
	e.set_meta("raid_repath", t)
	while not path.is_empty() and Vector2(path[0].x - e.global_position.x, path[0].z - e.global_position.z).length() < 0.7:
		path.pop_front()
	e.set_meta("raid_path", path)
	return path[0] if not path.is_empty() else center


## Casse un bloc construit juste devant (ou autour) du pillard.
func _break_near(e: Enemy) -> void:
	var grid := world.build
	if grid == null:
		return
	var feet := e.global_position.y
	var to := village_center() - e.global_position
	to.y = 0.0
	var fwd := to.normalized()
	var perp := fwd.cross(Vector3.UP)
	# devant lui, puis de chaque côté (brèche assez large pour passer), puis autour
	var spots := [fwd * 0.9, fwd * 0.9 + perp * 0.8, fwd * 0.9 - perp * 0.8,
		Vector3(0.9, 0, 0), Vector3(-0.9, 0, 0), Vector3(0, 0, 0.9), Vector3(0, 0, -0.9)]
	for d in spots:
		var cell := world.cell_at(e.global_position + d)
		for b in grid.column(cell):
			if b[1] < feet + 1.9 and b[2] > feet + 0.1:
				var key := Vector3i(cell.x, b[0], cell.y)
				var item: ItemData = grid.remove_block(key)
				if item:
					raid.broken += 1
					e.visual.play_move("heavy_1", 1.0)
					VoxelBurst.spawn(e, Vector3(cell.x + 0.5, b[1] + 0.5, cell.y + 0.5), Color(0.7, 0.55, 0.4), 18, 4.0, 0.12, 0.6)
					return


func _end(repelled: bool) -> void:
	var text := ""
	var p := _player()
	var center := village_center()
	if repelled:
		var gold := Items.get_item("piece_or")
		var n: int = 3 + int(raid.level) + int(raid.count)
		if gold:
			world.spawn_pickup(gold, center + Vector3(1.5, 0, 1.5), n)
		for i in 3:
			var it: ItemData = [Items.get_item("iron_ingot"), Items.get_item("leather"), Items.get_item("wood")][i]
			if it:
				world.spawn_pickup(it, center + Vector3(-1.5 + i * 1.5, 0, -1.5), 2 + int(raid.level) / 3)
		if p:
			p.gain_xp(20 * int(raid.count) + 10 * int(raid.level))
		text = "Raid repoussé ! Les pillards ont laissé leur butin au feu de camp (%d pièces d'or)." % n
	else:
		# ils repartent avec une partie des ressources
		var stolen := []
		if p:
			var stacks := p.inventory.entries.filter(func(e): return not (e.item as ItemData).is_equipment() and e.count >= 4)
			stacks.shuffle()
			for e in stacks.slice(0, 3):
				var take := maxi(1, roundi(e.count * 0.25))
				stolen.append("%d %s" % [take, e.item.display_name])
				p.inventory.remove(e.item, take)
		for e in alive_raiders():
			VoxelBurst.spawn(e, e.global_position + Vector3(0, 0.8, 0), Color(0.3, 0.3, 0.3), 20, 3.0, 0.1, 0.5)
			e.queue_free()
		text = "Les pillards repartent avec leur butin : %s." % (", ".join(PackedStringArray(stolen)) if not stolen.is_empty() else "rien du tout")
	if int(raid.broken) > 0:
		text += " (%d blocs détruits)" % raid.broken
	for v in get_tree().get_nodes_in_group("villagers"):
		if _is_guard(v):
			v.set("defend_radius", 16.0)
			v.set("alert_radius", 9.0)
			v.set("guard_bonus", 0.0)
	var done := raid
	raid = {}
	_raids_done += 1
	_timer = randf_range(interval.x, interval.y) * SaveGame.raid_delay_mult()
	raid_ended.emit(done, repelled, text)


## Temps avant le prochain raid (pour la sauvegarde ; un raid en cours reprendra plus tard).
func next_raid_in() -> float:
	return _timer if raid.is_empty() else 90.0


func set_next_raid(t: float) -> void:
	_timer = maxf(t, 30.0)


## Texte d'état pour le HUD ("" s'il n'y a pas de raid).
func status_text() -> String:
	if raid.is_empty():
		return ""
	var t := maxi(0, ceili(raid.timer))
	if raid.state == "warning":
		return "⚠ %s arrivent %s du village : %d:%02d" % [raid.name, raid.dir_text, t / 60, t % 60]
	return "⚔ Raid : %d pillards restants  ·  %d:%02d" % [alive_raiders().size(), t / 60, t % 60]
