class_name RoadLife
extends Node3D
## La vie des routes (voir WorldGenerator.roads) : quand le héros chemine sur une route pavée, il croise de temps
## en temps une caravane marchande (un marchand et ses gardes, E pour commercer), une patrouille de la nation
## voisine, ou tombe dans une embuscade de bandits (plus fréquente la nuit). Les rencontres naissent devant lui,
## hors de vue, et disparaissent quand il s'éloigne.

const CHECK_EVERY := 14.0
const CHANCE := 0.55
const SPAWN_MIN := 40.0
const SPAWN_MAX := 70.0
const DESPAWN := 120.0
## Pas de rencontre à moins de cette distance du village de départ.
const VILLAGE_CALM := 160.0

var world: WorldGenerator
var player: Player
## La rencontre en cours : {"kind", "node"} ou {}.
var encounter := {}
var _timer := 6.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("road_life")
	_rng.randomize()


func _process(delta: float) -> void:
	if world == null or player == null or not is_instance_valid(player):
		return
	if not encounter.is_empty():
		var n: Node3D = encounter.node
		if not is_instance_valid(n) or _farthest(n) > DESPAWN:
			if is_instance_valid(n):
				n.queue_free()
			encounter = {}
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = CHECK_EVERY
	if player.global_position.y < WorldGenerator.UNDERGROUND or _rng.randf() > CHANCE:
		return
	# pas de rencontre aux portes du village (le début de partie reste tranquille)
	var sp := world.cell_center(world.spawn_cell)
	if Vector2(player.global_position.x - sp.x, player.global_position.z - sp.z).length() < VILLAGE_CALM:
		return
	var near := nearest_road_point(player.global_position, 25.0)
	if near.is_empty():
		return
	var night := _night()
	var r := _rng.randf()
	var kind := "caravane" if r < (0.25 if night else 0.42) else ("patrouille" if r < (0.45 if night else 0.72) else "bandits")
	spawn(kind, near)


func _night() -> bool:
	var dc := get_tree().get_first_node_in_group("day_cycle")
	return dc != null and dc.is_night()


func _farthest(n: Node3D) -> float:
	var best := INF
	for c in n.get_children():
		if c is Node3D:
			best = minf(best, (c as Node3D).global_position.distance_to(player.global_position))
	return best if best < INF else 0.0


## Le point de route le plus proche (à moins de `radius` m) : {"road": i, "index": j} ou {}.
func nearest_road_point(pos: Vector3, radius: float) -> Dictionary:
	var best := {}
	var bd := radius
	for i in world.roads.size():
		var path: Array = world.roads[i]
		for j in path.size():
			var c: Vector2i = path[j]
			var d := Vector2(c.x + 0.5 - pos.x, c.y + 0.5 - pos.z).length()
			if d < bd:
				bd = d
				best = {"road": i, "index": j}
	return best


func _point(road: int, idx: int) -> Vector3:
	var path: Array = world.roads[road]
	var c: Vector2i = path[clampi(idx, 0, path.size() - 1)]
	var p := Vector3(c.x + 0.5, 0.0, c.y + 0.5)
	p.y = world.terrain_height(c)
	return Vector3(p.x, world.support_height(p, p.y + 0.3), p.z)


## Fait naître une rencontre sur la route, à 40-70 m du héros, dans un sens ou dans l'autre.
## `near` : {"road", "index"} (le point de route le plus proche du héros).
func spawn(kind: String, near: Dictionary) -> Node3D:
	var road: int = near.road
	var path: Array = world.roads[road]
	var sgn := 1 if _rng.randf() < 0.5 else -1
	var idx: int = near.index
	var from := idx
	var walked := 0.0
	while walked < SPAWN_MIN + _rng.randf() * (SPAWN_MAX - SPAWN_MIN):
		var nxt := from + sgn
		if nxt < 0 or nxt >= path.size():
			sgn = -sgn
			nxt = from + sgn
			if nxt < 0 or nxt >= path.size():
				break
		walked += Vector2(path[nxt] - path[from]).length()
		from = nxt
	var at := _point(road, from)
	if not world.city_at(at, 20.0).is_empty():
		return null
	var holder := Node3D.new()
	holder.name = "Rencontre_" + kind
	add_child(holder)
	encounter = {"kind": kind, "node": holder}
	# ils marchent vers le héros (puis au-delà, le long de la route)
	var route: Array = []
	var k := from
	for s in 40:
		k -= sgn
		if k < 0 or k >= path.size():
			break
		route.append(_point(road, k))
	var nation := _nearest_nation(at)
	match kind:
		"caravane":
			var m := _folk(holder, at, "merchant", nation, route, 0.0)
			m.display_name = CityLife.random_name(nation, _rng)
			var trade := get_tree().get_first_node_in_group("trade") as Trade
			if trade:
				var tname: String = ["Joaillier", "Herboriste", "Forgeron", "Tisserand"][_rng.randi() % 4]
				m.shop = CityMerchant.new(trade, {"name": "la route", "nation": nation}, tname, m.display_name, _rng)
				m.trade_name = "Caravane (%s)" % tname.to_lower()
			m.color = Color("ffe08a")
			m.lines = ["Une caravane de passage ! Profites-en, je repars demain."]
			for g in 2:
				var gd := _folk(holder, at, "guard", nation, route, 1.6 * (g + 1))
				gd.kit = ["sword_iron", "iron_helmet", "leather_armor"]
				gd.display_name = "Garde de caravane"
				gd.lines = ["On escorte la caravane jusqu'à la prochaine ville.", "Les bandits n'oseront pas, avec nous."]
		"patrouille":
			for g in 3:
				var gd := _folk(holder, at, "guard", nation, route, 1.4 * g)
				gd.kit = ["sword_iron", "iron_helmet", "iron_armor"]
				gd.display_name = "Patrouille de " + str(Diplomacy.NATIONS.get(nation, {}).get("name", "la route"))
				gd.lines = ["On surveille la route. Rien à signaler.", "Des bandits ont été vus plus loin, sois prudent."]
		"bandits":
			var scene := load("res://scenes/enemies/enemy.tscn") as PackedScene
			var n := _rng.randi_range(3, 4)
			for b in n + 1:
				var e := scene.instantiate() as Enemy
				e.data = load("res://data/enemies/%s.tres" % ("bandit_chef" if b == 0 else "bandit"))
				e.level = maxi(2, player.level)
				e.power = 1.0 + 0.05 * e.level
				e.set_meta("bandit", true)
				holder.add_child(e)
				var a := TAU * b / (n + 1)
				e.global_position = at + Vector3(cos(a), 0, sin(a)) * (0.0 if b == 0 else 2.5)
				e.global_position.y = world.support_height(e.global_position, at.y + 0.6)
				e.home = e.global_position
			player.notify.emit("Embuscade ! Des bandits barrent la route.")
	return holder


func _folk(holder: Node3D, at: Vector3, role: String, nation: String, route: Array, back: float) -> Townsfolk:
	var t := Townsfolk.new()
	var races: Array = CityPlans.CITIES.get(nation, {}).get("races", ["humain"])
	t.race = load("res://data/races/%s.tres" % races[_rng.randi() % races.size()]) as RaceData
	t.role = role
	t.name = "%s_%d" % [role, holder.get_child_count()]
	t.home = at
	t.route = route.duplicate()
	holder.add_child(t)
	var dir: Vector3 = (route[0] - at).normalized() if not route.is_empty() else Vector3.FORWARD
	t.global_position = at - dir * back
	return t


func _nearest_nation(at: Vector3) -> String:
	var best := "givre"
	var bd := INF
	for c in world.cities:
		var d := Vector2(at.x - (c.center as Vector2i).x, at.z - (c.center as Vector2i).y).length()
		if d < bd:
			bd = d
			best = c.nation
	return best
