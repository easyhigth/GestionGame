class_name WorldPolitics
extends Node3D
## Le monde vit sans le héros :
## - les nations voisines se font la guerre entre elles ; leurs armées marchent d'une capitale à l'autre sur les routes
##   pavées et prennent au passage les hameaux de l'ennemi (qui changent de camp) ;
## - les caravanes vont de capitale en capitale : les prix montent avec les guerres, les pillages et les pénuries,
##   et baissent quand les marchandises arrivent ;
## - chaque saison apporte son événement dans une capitale : foire au printemps, tournoi en été, foire des moissons
##   à l'automne ; l'hiver, les morts-vivants sortent d'un château abandonné et marchent sur un hameau.
## Quand le héros approche d'une armée, ses soldats apparaissent sur la route ; une armée ennemie (ou les morts)
## peut être arrêtée en la battant.

signal news_posted(text: String)
signal changed

## Chance chaque jour qu'une nouvelle guerre éclate (au plus MAX_WARS en même temps).
const WAR_CHANCE := 0.3
const MAX_WARS := 2
const WAR_DAYS := Vector2i(4, 7)
## Vitesse de marche d'une armée (mètres par seconde de jeu).
const ARMY_SPEED := 1.3
## Distance à laquelle les soldats d'une armée apparaissent.
const VISIBLE := 140.0
const HAMLET_REACH := 30.0
const CAPITAL_DEFENSE := 7
const MAX_NEWS := 14
## Métiers des marchands -> catégorie de marchandises.
const CATS := {"Forgeron": "armes", "Épicier": "vivres", "Herboriste": "vivres", "Joaillier": "luxe", "Maçon": "materiaux",
	"Charpentier": "materiaux", "Tisserand": "materiaux"}
const CAT_NAMES := {"armes": "armes", "vivres": "vivres", "luxe": "bijoux", "materiaux": "matériaux"}
const UNDEAD := {"name": "Les morts-vivants", "types": ["squelette", "squelette", "esprit_follet"], "leader": "seigneur_squelette",
	"color": Color("b8a8d8")}
const SEASON_EVENTS := ["foire", "tournoi", "moissons", "morts"]
const EVENT_NAMES := {"foire": "Foire de printemps", "tournoi": "Grand tournoi", "moissons": "Foire des moissons", "morts": "Invasion des morts"}
const CHAMPIONS := 3

var world: WorldGenerator
var player: Player
## [{a, b, until}] : guerres entre deux nations.
var wars: Array = []
## Armées en marche : {id, kind (« army » | « undead »), nation, target, from, goal, dist, strength}
## (+ en mémoire : path, len, stops : [[distance, hameau]]).
var armies: Array = []
## nation -> {catégorie: 0.2 .. 1.6} (1 : normal ; moins : pénurie, les prix montent).
var supply := {}
## hameau -> nation, quand il a changé de camp.
var owners := {}
## hameau -> jour où il se relève du pillage des morts.
var ravaged := {}
## L'événement de saison en cours : {kind, nation, until, key, round}.
var event := {}
var news: Array = []
var _day := -1
var _tick := 0.0
var _seq := 0
var _seasons_done := {}
var _rng := RandomNumberGenerator.new()
var _units := {}           # id d'armée -> Node3D (ses soldats visibles)
var _sync := 0.0
var _arena: Node3D
var _champion: Enemy
var _graph := {}


func _ready() -> void:
	add_to_group("world_politics")
	_rng.randomize()
	if not SaveGame.politics_state.is_empty():
		import_state.call_deferred(SaveGame.politics_state)
		SaveGame.politics_state = {}


func today() -> int:
	var dc := get_tree().get_first_node_in_group("day_cycle") as DayCycle
	return dc.day if dc else 1


func _dip() -> Diplomacy:
	return get_tree().get_first_node_in_group("diplomacy") as Diplomacy


func _nation_name(id: String) -> String:
	if id == "morts":
		return UNDEAD.name
	return str(Diplomacy.NATIONS.get(id, {}).get("name", id))


func _color(id: String) -> Color:
	if id == "morts":
		return UNDEAD.color
	return Diplomacy.NATIONS.get(id, {}).get("color", Color.WHITE)


func city_of(nation: String) -> Dictionary:
	if world:
		for c in world.cities:
			if c.nation == nation:
				return c
	return {}


## Les nations qui ont une capitale dans ce monde (et ne sont pas des provinces du héros).
func _free_nations() -> Array:
	var dip := _dip()
	var out := []
	if world == null:
		return out
	for c in world.cities:
		if dip == null or not dip.annexed(c.nation):
			out.append(c.nation)
	return out


func _hamlet(id: String) -> Dictionary:
	if world:
		for st in world.structure_sites:
			if st.kind == "hamlet" and st.id == id:
				return st
	return {}


func hamlets() -> Array:
	return world.structure_sites.filter(func(st): return st.kind == "hamlet") if world else []


# ---------------------------------------------------------------- nouvelles

func post(text: String, important := true) -> void:
	news.append([today(), text])
	if news.size() > MAX_NEWS:
		news = news.slice(-MAX_NEWS)
	news_posted.emit(text)
	if important and player:
		player.notify.emit("Nouvelles du monde : " + text)
	changed.emit()


# ---------------------------------------------------------------- guerres

func at_war(a: String, b: String) -> bool:
	for w in wars:
		if (w.a == a and w.b == b) or (w.a == b and w.b == a):
			return true
	return false


func enemies_of(n: String) -> Array:
	var out := []
	for w in wars:
		if w.a == n:
			out.append(w.b)
		elif w.b == n:
			out.append(w.a)
	return out


## Déclare une guerre entre deux nations (automatique ; utilisable pour tester). L'agresseur lève une armée.
func start_war(a: String, b: String) -> bool:
	if a == b or at_war(a, b) or city_of(a).is_empty() or city_of(b).is_empty():
		return false
	wars.append({"a": a, "b": b, "until": today() + _rng.randi_range(WAR_DAYS.x, WAR_DAYS.y)})
	post("%s déclare la guerre à %s !" % [_nation_name(a), _nation_name(b)])
	raise_army(a, b)
	Sound.ui("war_drums")
	return true


func _end_war(w: Dictionary) -> void:
	wars.erase(w)
	for ar in armies.duplicate():
		if ar.kind == "army" and ((ar.nation == w.a and ar.target == w.b) or (ar.nation == w.b and ar.target == w.a)):
			_remove_army(ar)
	var taken := owners.keys().filter(func(h): return owners[h] in [w.a, w.b] and _hamlet(h).get("nation", "") != _hamlet(h).get("born", ""))
	post("Paix entre %s et %s.%s" % [_nation_name(w.a), _nation_name(w.b),
		(" %d hameau%s garde%s sa nouvelle bannière." % [taken.size(), "x" if taken.size() > 1 else "", "nt" if taken.size() > 1 else ""]) if not taken.is_empty() else ""])


# ---------------------------------------------------------------- routes

## Les nœuds du réseau de routes : le village (0) et les capitales (1..).
func _nodes() -> Array:
	var out: Array = [world.spawn_cell]
	for c in world.cities:
		out.append(c.center)
	return out


func _node_of(cell: Vector2i) -> int:
	var ns := _nodes()
	var best := -1
	var bd := 60.0
	for i in ns.size():
		var d := Vector2(cell - (ns[i] as Vector2i)).length()
		if d < bd:
			bd = d
			best = i
	return best


func _build_graph() -> void:
	_graph = {}
	for r in world.roads.size():
		var path: Array = world.roads[r]
		if path.size() < 2:
			continue
		var a := _node_of(path[0])
		var b := _node_of(path[-1])
		if a < 0 or b < 0:
			continue
		if not _graph.has(a):
			_graph[a] = []
		if not _graph.has(b):
			_graph[b] = []
		_graph[a].append([b, r, false])
		_graph[b].append([a, r, true])


## Le chemin (cases) d'une capitale à l'autre par les routes pavées (en ligne droite s'il n'y en a pas).
func route(from: Vector2i, to: Vector2i) -> Array:
	if _graph.is_empty():
		_build_graph()
	var na := _node_of(from)
	var nb := _node_of(to)
	var out: Array = []
	if na >= 0 and nb >= 0 and na != nb:
		var came := {na: null}
		var queue := [na]
		while not queue.is_empty():
			var cur: int = queue.pop_front()
			if cur == nb:
				break
			for e in _graph.get(cur, []):
				if not came.has(e[0]):
					came[e[0]] = [cur, e[1], e[2]]
					queue.append(e[0])
		if came.has(nb):
			var legs: Array = []
			var cur: int = nb
			while came[cur] != null:
				legs.push_front(came[cur])
				cur = came[cur][0]
			for leg in legs:
				var path: Array = (world.roads[leg[1]] as Array).duplicate()
				# leg[2] : la route est parcourue à l'envers quand on part de sa fin
				if leg[2]:
					path.reverse()
				if not out.is_empty():
					path = path.slice(1)
				out.append_array(path)
	if out.size() < 2:
		out = _line(from, to)
	return out


func _line(from: Vector2i, to: Vector2i) -> Array:
	var out: Array = []
	var n := maxi(1, ceili(Vector2(to - from).length() / 6.0))
	for i in n + 1:
		out.append(Vector2i(Vector2(from).lerp(Vector2(to), float(i) / n).round()))
	return out


func _path_len(path: Array) -> float:
	var l := 0.0
	for i in range(1, path.size()):
		l += Vector2(path[i] - path[i - 1]).length()
	return l


## La position (case) à une distance donnée le long d'un chemin, et l'index du segment.
func _at(path: Array, dist: float) -> Array:
	var walked := 0.0
	for i in range(1, path.size()):
		var seg := Vector2(path[i] - path[i - 1]).length()
		if walked + seg >= dist:
			var t := (dist - walked) / maxf(seg, 0.001)
			return [Vector2(path[i - 1]).lerp(Vector2(path[i]), t), i]
		walked += seg
	return [Vector2(path[-1]), path.size() - 1]


func army_pos(ar: Dictionary) -> Vector3:
	var at: Vector2 = _at(ar.path, float(ar.dist))[0]
	var c := Vector2i(at.round())
	var p := Vector3(at.x + 0.5, 0.0, at.y + 0.5)
	p.y = world.terrain_height(c)
	return Vector3(p.x, world.support_height(p, p.y + 0.3), p.z)


# ---------------------------------------------------------------- armées

## Une armée part de la capitale de `nation` vers celle de `target`.
func raise_army(nation: String, target: String) -> Dictionary:
	var a := city_of(nation)
	var b := city_of(target)
	if a.is_empty() or b.is_empty():
		return {}
	_seq += 1
	var ar := {"id": "armee_%d" % _seq, "kind": "army", "nation": nation, "target": target, "from": nation, "goal": target,
		"dist": float(a.radius) + 4.0, "strength": _rng.randi_range(8, 12)}
	_prepare(ar)
	armies.append(ar)
	post("%s se met en marche vers %s." % [_army_name(ar), b.name], false)
	return ar


## Les morts-vivants sortent d'un château abandonné et marchent sur le hameau le plus proche.
func raise_undead() -> Dictionary:
	var best := []
	var bd := 420.0
	for st in world.structure_sites:
		if st.kind != "castle" or not st.abandoned:
			continue
		var mid: Vector2i = (st.cell as Vector2i) + Vector2i(10, 10)
		for h in hamlets():
			if ravaged.has(h.id):
				continue
			var d := Vector2(mid - (h.cell as Vector2i)).length()
			if d < bd:
				bd = d
				best = [st, h]
	if best.is_empty():
		return {}
	_seq += 1
	var ar := {"id": "morts_%d" % _seq, "kind": "undead", "nation": "morts", "target": best[1].id, "from": best[0].id, "goal": best[1].id,
		"dist": 14.0, "strength": _rng.randi_range(6, 9)}
	_prepare(ar)
	armies.append(ar)
	post("Les morts-vivants sortent du château abandonné de %s et marchent sur le hameau de %s !" % [
		world.zones[int(best[0].zone)].name, best[1].name])
	Sound.ui("war_drums")
	return ar


func _army_name(ar: Dictionary) -> String:
	if ar.kind == "undead":
		return UNDEAD.name
	return str(Diplomacy.NATIONS.get(ar.nation, {}).get("army", {}).get("name", "L'armée de " + _nation_name(ar.nation)))


## Le chemin d'une armée et les hameaux qu'elle traversera.
func _prepare(ar: Dictionary) -> void:
	if ar.kind == "undead":
		var st: Dictionary = {}
		for s in world.structure_sites:
			if s.kind == "castle" and s.id == ar.from:
				st = s
		var h := _hamlet(ar.goal)
		var from: Vector2i = (st.cell as Vector2i) + Vector2i(10, 22) if not st.is_empty() else h.get("cell", world.spawn_cell)
		ar.path = _line(from, h.get("cell", from))
	else:
		ar.path = route(city_of(ar.from).center, city_of(ar.goal).center)
	ar.len = _path_len(ar.path)
	var stops := []
	if ar.kind == "army":
		for h in hamlets():
			var best := INF
			var at := 0.0
			var walked := 0.0
			for i in range(1, ar.path.size()):
				walked += Vector2(ar.path[i] - ar.path[i - 1]).length()
				var d := Vector2(ar.path[i] - (h.cell as Vector2i)).length()
				if d < best:
					best = d
					at = walked
			if best < HAMLET_REACH:
				stops.append([at, h.id])
		stops.sort_custom(func(x, y): return x[0] < y[0])
	ar.stops = stops


func _remove_army(ar: Dictionary) -> void:
	armies.erase(ar)
	_despawn(ar.id)
	changed.emit()


func _advance_armies(dt: float) -> void:
	for ar in armies.duplicate():
		# le combat arrête la marche
		var u: Node3D = _units.get(ar.id)
		if u and player and army_pos(ar).distance_to(player.global_position) < 30.0 and _hostile(ar):
			continue
		var before := float(ar.dist)
		ar.dist = minf(float(ar.len), before + ARMY_SPEED * dt)
		for s in ar.stops:
			if float(s[0]) > before and float(s[0]) <= float(ar.dist):
				_pass_hamlet(ar, str(s[1]))
		if float(ar.dist) >= float(ar.len):
			_arrive(ar)


func _pass_hamlet(ar: Dictionary, hid: String) -> void:
	var h := _hamlet(hid)
	if h.is_empty() or h.nation != ar.target:
		return
	ar.strength = maxi(1, int(ar.strength) - 1)
	set_hamlet_owner(hid, ar.nation)
	post("Le hameau de %s tombe aux mains de %s." % [h.name, _nation_name(ar.nation)], _near(h.cell, 300.0))


## Un hameau change de camp (sa bannière, ses habitants et ses prix).
func set_hamlet_owner(hid: String, nation: String) -> void:
	var h := _hamlet(hid)
	if h.is_empty():
		return
	if not h.has("born"):
		h["born"] = h.nation
	h.nation = nation
	if nation == h.born:
		owners.erase(hid)
	else:
		owners[hid] = nation
	changed.emit()


func _arrive(ar: Dictionary) -> void:
	_remove_army(ar)
	if ar.kind == "undead":
		var h := _hamlet(ar.goal)
		if h.is_empty():
			return
		ravaged[h.id] = today() + 3
		h["ravaged"] = true
		post("Les morts-vivants ont ravagé le hameau de %s. Ses habitants ont fui." % h.name)
		return
	var city := city_of(ar.goal)
	var win := _rng.randf() < float(ar.strength) / float(int(ar.strength) + CAPITAL_DEFENSE)
	if win:
		_add_supply(ar.goal, -0.5)
		# la ville paie tribut : la guerre s'arrête là
		for w in wars.duplicate():
			if (w.a == ar.nation and w.b == ar.goal) or (w.b == ar.nation and w.a == ar.goal):
				w.until = today()
		post("%s a pillé les faubourgs de %s ! La ville paie tribut ; les prix y flambent." % [_army_name(ar), city.get("name", "")])
	else:
		post("%s est repoussée devant les murs de %s." % [_army_name(ar), city.get("name", "")], _near(city.get("center", Vector2i.ZERO), 400.0))


func _near(cell: Vector2i, d: float) -> bool:
	return player != null and Vector2(player.global_position.x - cell.x, player.global_position.z - cell.y).length() < d


# ---------------------------------------------------------------- soldats visibles

func _hostile(ar: Dictionary) -> bool:
	if ar.kind == "undead":
		return true
	var dip := _dip()
	return dip != null and dip.states.has(ar.nation) and dip.at_war(ar.nation)


func _sync_units() -> void:
	if player == null or world == null:
		return
	var pp := player.global_position
	var under := pp.y < WorldGenerator.UNDERGROUND
	for ar in armies:
		var pos := army_pos(ar)
		var d := pos.distance_to(pp)
		var u: Node3D = _units.get(ar.id)
		if (d > VISIBLE + 30.0 or under) and u:
			_despawn(ar.id)
		elif d < VISIBLE and not under and u == null and world.city_at(pos, 10.0).is_empty():
			_spawn_units(ar)
		elif u and is_instance_valid(u):
			_steer(ar, u)


func _spawn_units(ar: Dictionary) -> void:
	var holder := Node3D.new()
	holder.name = "Armee_" + str(ar.id)
	add_child(holder)
	_units[ar.id] = holder
	var pos := army_pos(ar)
	var n := clampi(int(ar.strength) / 2 + 2, 3, 7)
	var lv := maxi(3, player.level if player else 3)
	var types: Array = UNDEAD.types if ar.kind == "undead" else Diplomacy.NATIONS[ar.nation].army.types
	var leader: String = UNDEAD.leader if ar.kind == "undead" else Diplomacy.NATIONS[ar.nation].army.leader
	var hostile := _hostile(ar)
	var dir := _dir(ar)
	var side := Vector3(-dir.z, 0, dir.x)
	for i in n:
		var off := -dir * (1.6 * (i / 2)) + side * (1.2 if i % 2 == 0 else -1.2)
		var at := pos + off
		at.y = world.support_height(at, world.terrain_height(world.cell_at(at)) + 0.3)
		if hostile:
			var e := (load("res://scenes/enemies/enemy.tscn") as PackedScene).instantiate() as Enemy
			e.data = load("res://data/enemies/%s.tres" % (leader if i == 0 else types[i % types.size()]))
			e.level = lv
			e.power = 1.0 + 0.05 * lv
			e.set_meta("army", ar.id)
			holder.add_child(e)
			e.global_position = at
			e.home = at
		else:
			var t := Townsfolk.new()
			var races: Array = CityPlans.CITIES.get(ar.nation, {}).get("races", ["humain"])
			t.race = load("res://data/races/%s.tres" % races[i % races.size()]) as RaceData
			t.role = "guard"
			t.kit = ["sword_iron", "iron_helmet", "iron_armor"] if i > 0 else ["sword_iron", "iron_helmet", "iron_armor", "cape_red"]
			t.display_name = ("Capitaine — " if i == 0 else "Soldat — ") + _army_name(ar)
			t.lines = ["Nous marchons sur %s. Écarte-toi de la route." % city_of(ar.target).get("name", "l'ennemi"),
				"La guerre est l'affaire des nations, voyageur.", "Gloire à %s !" % _nation_name(ar.nation)]
			t.color = _color(ar.nation).lightened(0.3)
			t.home = at
			holder.add_child(t)
			t.global_position = at
	# le drapeau de l'armée
	var flag := Label3D.new()
	flag.name = "Drapeau"
	flag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	flag.text = "⚑ %s\n→ %s" % [_army_name(ar), _goal_name(ar)]
	flag.font_size = 40
	flag.pixel_size = 0.008
	flag.outline_size = 10
	flag.modulate = _color(ar.nation).lightened(0.25)
	holder.add_child(flag)
	flag.global_position = pos + Vector3(0, 4.2, 0)
	holder.set_meta("count", n)
	_steer(ar, holder)


func _goal_name(ar: Dictionary) -> String:
	if ar.kind == "undead":
		return "hameau de " + str(_hamlet(ar.goal).get("name", "?"))
	return str(city_of(ar.goal).get("name", "?"))


func _dir(ar: Dictionary) -> Vector3:
	var a: Vector2 = _at(ar.path, float(ar.dist))[0]
	var b: Vector2 = _at(ar.path, minf(float(ar.len), float(ar.dist) + 6.0))[0]
	var d := Vector3(b.x - a.x, 0, b.y - a.y)
	return d.normalized() if d.length() > 0.01 else Vector3.FORWARD


## Les soldats suivent la position de leur armée ; une armée dont tous les soldats sont tombés est détruite.
func _steer(ar: Dictionary, holder: Node3D) -> void:
	var pos := army_pos(ar)
	var flag := holder.get_node_or_null("Drapeau") as Node3D
	if flag:
		flag.global_position = pos + Vector3(0, 4.2, 0)
	var alive := 0
	var i := 0
	var dir := _dir(ar)
	var side := Vector3(-dir.z, 0, dir.x)
	for c in holder.get_children():
		var off := -dir * (1.6 * (i / 2)) + side * (1.2 if i % 2 == 0 else -1.2)
		if c is Enemy:
			var e := c as Enemy
			if not e.is_alive():
				continue
			alive += 1
			i += 1
			e.home = pos + off
			if e.global_position.distance_to(player.global_position) > 14.0:
				e.set("_wander_to", e.home)
				e.set("_returning", true)
		elif c is Townsfolk:
			alive += 1
			i += 1
			var t := c as Townsfolk
			t.home = pos + off
			if t.route.is_empty() and t.global_position.distance_to(t.home) > 2.5:
				t.route = [t.home]
			elif t.global_position.distance_to(t.home) > 25.0:
				t.global_position = t.home
	if alive == 0 and holder.get_meta("count", 0) > 0:
		_defeated(ar)


func _defeated(ar: Dictionary) -> void:
	_remove_army(ar)
	if player:
		player.gain_xp(150 + 15 * player.level)
		player.inventory.add(Items.get_item("piece_or"), 120 if ar.kind == "undead" else 200)
		player.feat.emit("Armée vaincue : %s" % _army_name(ar), Color("ffd24a"))
	if ar.kind == "undead":
		post("Le héros a renvoyé les morts-vivants à la poussière : le hameau de %s est sauvé !" % _hamlet(ar.goal).get("name", ""))
	else:
		post("Le héros a mis en déroute %s." % _army_name(ar))
		var dip := _dip()
		for other in enemies_of(ar.nation):
			if dip and dip.states.has(other):
				dip._add_rel(other, 8.0)
	Sound.ui("fanfare")


func _despawn(id: String) -> void:
	var u: Node3D = _units.get(id)
	_units.erase(id)
	if u and is_instance_valid(u):
		u.queue_free()


# ---------------------------------------------------------------- économie

func _ensure_supply() -> void:
	for n in _free_nations():
		if not supply.has(n):
			supply[n] = {"armes": 1.0, "vivres": 1.0, "luxe": 1.0, "materiaux": 1.0}


func _add_supply(n: String, v: float, cat := "") -> void:
	_ensure_supply()
	if not supply.has(n):
		return
	for c in supply[n]:
		if cat == "" or c == cat:
			supply[n][c] = clampf(float(supply[n][c]) + v, 0.2, 1.6)


func category(trade_name: String) -> String:
	for k in CATS:
		if trade_name.contains(k):
			return CATS[k]
	return "materiaux"


## Multiplicateur des prix d'un marchand de cette nation (achats du héros si `buying`, sinon ses ventes).
func price_mult(nation: String, trade_name: String, buying: bool) -> float:
	if not supply.has(nation):
		return 1.0
	var s := float(supply[nation].get(category(trade_name), 1.0))
	var m := clampf(1.0 + (1.0 - s) * 0.6, 0.65, 1.5)
	if not event.is_empty() and event.nation == nation and event.kind in ["foire", "moissons"]:
		m *= 0.8 if buying else 1.15
	return m


## Ce qu'il faut savoir des prix d'une ville (pour le marchand) : « pénurie d'armes (+30 %) »...
func market_note(nation: String, trade_name: String) -> String:
	var m := price_mult(nation, trade_name, true)
	var cat: String = CAT_NAMES.get(category(trade_name), "marchandises")
	var t := ""
	if m > 1.08:
		t = "pénurie de %s (+%d %%)" % [cat, roundi((m - 1.0) * 100.0)]
	elif m < 0.92:
		t = "%s en abondance (%d %%)" % [cat, roundi((m - 1.0) * 100.0)]
	if not event.is_empty() and event.nation == nation and event.kind in ["foire", "moissons"]:
		t += ("  ·  " if t != "" else "") + EVENT_NAMES[event.kind]
	return t


func _economy_day() -> void:
	_ensure_supply()
	# les prix reviennent doucement à la normale
	for n in supply:
		for c in supply[n]:
			var v := float(supply[n][c])
			supply[n][c] = v + clampf(1.0 - v, -0.1, 0.1)
	# la guerre vide les arsenaux et les greniers
	for w in wars:
		for n in [w.a, w.b]:
			_add_supply(n, -0.28, "armes")
			_add_supply(n, -0.14, "vivres")
	# les caravanes vont de capitale en capitale
	var ns := _free_nations()
	var told := false
	for a in ns:
		for b in ns:
			if a >= b or at_war(a, b) or _rng.randf() > 0.45:
				continue
			var dest: String = [a, b].pick_random()
			var src: String = b if dest == a else a
			var cat: String = ["armes", "vivres", "luxe", "materiaux"].pick_random()
			if _rng.randf() < 0.18:
				_add_supply(dest, -0.15, cat)
				if not told:
					told = true
					post("Des bandits ont pillé une caravane de %s en route vers %s : les %s s'y font rares." % [
						city_of(src).get("name", ""), city_of(dest).get("name", ""), CAT_NAMES[cat]], false)
			else:
				_add_supply(dest, 0.3, cat)
				if not told and _rng.randf() < 0.3:
					told = true
					post("Une caravane de %s est arrivée à %s : les %s y sont moins chers." % [
						city_of(src).get("name", ""), city_of(dest).get("name", ""), CAT_NAMES[cat]], false)


# ---------------------------------------------------------------- saisons

func _season_day() -> void:
	var sea := get_tree().get_first_node_in_group("seasons") as Seasons
	if sea == null:
		return
	if not event.is_empty() and today() > int(event.until):
		_end_event()
	var key := "%d_%d" % [sea.year(), sea.season()]
	if event.is_empty() and not _seasons_done.has(key) and sea.day_in_season() >= 1:
		_seasons_done[key] = true
		start_event(SEASON_EVENTS[sea.season()])
	elif event.is_empty() and _rng.randf() < 0.06:
		raise_undead()


## Lance l'événement de saison (automatique ; utilisable pour tester).
func start_event(kind: String, nation := "") -> bool:
	if not event.is_empty():
		_end_event()
	if kind == "morts":
		var ar := raise_undead()
		if ar.is_empty():
			return false
		event = {"kind": kind, "nation": "morts", "until": today() + 2, "army": ar.id}
		changed.emit()
		return true
	var ns := _free_nations()
	var dip := _dip()
	if dip:
		ns = ns.filter(func(n): return not dip.at_war(n))
	if nation == "":
		if ns.is_empty():
			return false
		nation = ns.pick_random()
	var city := city_of(nation)
	if city.is_empty():
		return false
	event = {"kind": kind, "nation": nation, "until": today() + 2, "round": 0}
	match kind:
		"foire":
			post("%s : grande foire de printemps à %s ! Ses marchands baissent leurs prix." % [EVENT_NAMES[kind], city.name])
		"moissons":
			for n in _free_nations():
				_add_supply(n, 0.4, "vivres")
			post("Foire des moissons à %s : les greniers débordent, les vivres sont bon marché partout." % city.name)
		"tournoi":
			_make_arena()
			post("Grand tournoi à %s ! Trois champions attendent les audacieux devant la grande porte." % city.name)
	if player:
		player.feat.emit(EVENT_NAMES[kind], _color(nation).lightened(0.3))
	Sound.ui("fanfare" if kind == "tournoi" else "event")
	changed.emit()
	return true


func _end_event() -> void:
	if _arena and is_instance_valid(_arena):
		_arena.queue_free()
	_arena = null
	if _champion and is_instance_valid(_champion):
		_champion.queue_free()
	_champion = null
	event = {}
	changed.emit()


## L'arène du tournoi : devant la grande porte de la capitale.
func arena_pos() -> Vector3:
	var city := city_of(str(event.get("nation", "")))
	if city.is_empty():
		return Vector3.INF
	var gate := Vector2i(0, int(city.radius))
	for g in city.gates:
		if gate == Vector2i(0, int(city.radius)) or Vector2(g).length() > Vector2(gate).length():
			gate = g
	var out := Vector2(gate).normalized()
	var c := (city.center as Vector2i) + gate + Vector2i(roundi(out.x * 16.0), roundi(out.y * 16.0))
	var p := Vector3(c.x + 0.5, 0.0, c.y + 0.5)
	p.y = world.terrain_height(c)
	return Vector3(p.x, world.support_height(p, p.y + 0.3), p.z)


func _make_arena() -> void:
	var pos := arena_pos()
	if pos == Vector3.INF:
		return
	_arena = Node3D.new()
	_arena.name = "Tournoi"
	add_child(_arena)
	_arena.global_position = pos
	var lab := Label3D.new()
	lab.name = "Titre"
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.font_size = 44
	lab.pixel_size = 0.008
	lab.outline_size = 10
	lab.modulate = Color("ffb04a")
	lab.position.y = 4.5
	_arena.add_child(lab)
	# la lice : une palissade de poteaux, deux mâts aux couleurs de la ville
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("7a5230")
	for i in 16:
		var a := TAU * i / 16.0
		var post := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.25, 1.2, 0.25)
		post.mesh = bm
		post.material_override = wood
		post.position = Vector3(cos(a) * 7.5, 0.6, sin(a) * 7.5)
		_arena.add_child(post)
	var flag_col := _color(str(event.nation))
	for sx in [-1.0, 1.0]:
		var pole := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.18, 5.0, 0.18)
		pole.mesh = pm
		pole.material_override = wood
		pole.position = Vector3(8.5 * sx, 2.5, 0)
		_arena.add_child(pole)
		var flag := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(0.06, 1.4, 1.0)
		flag.mesh = fm
		var m := StandardMaterial3D.new()
		m.albedo_color = flag_col
		flag.material_override = m
		flag.position = Vector3(8.5 * sx, 4.2, 0.55)
		_arena.add_child(flag)
	# des braseros autour de la lice
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0
		var l := OmniLight3D.new()
		l.light_color = Color("ffb060")
		l.omni_range = 6.0
		l.light_energy = 1.2
		l.position = Vector3(cos(a) * 6.0, 1.5, sin(a) * 6.0)
		_arena.add_child(l)
	_update_arena()


func _update_arena() -> void:
	var lab := _arena.get_node_or_null("Titre") as Label3D if _arena else null
	if lab:
		lab.text = "⚔ Grand tournoi de %s ⚔\nChampion %d / %d — approche-toi" % [city_of(event.nation).get("name", ""), int(event.get("round", 0)) + 1, CHAMPIONS]


func _tournament_step() -> void:
	if event.get("kind", "") != "tournoi" or player == null or not player.is_alive():
		return
	if _arena == null or not is_instance_valid(_arena):
		_make_arena()
		if _arena == null:
			return
	if _champion and is_instance_valid(_champion):
		if not _champion.is_alive():
			_champion = null
			event.round = int(event.round) + 1
			if int(event.round) >= CHAMPIONS:
				var city := city_of(event.nation)
				player.inventory.add(Items.get_item("piece_or"), 250)
				player.inventory.add(Items.get_item(RareDrops.GEM_IDS.pick_random()), 1)
				player.gain_xp(200 + 20 * player.level)
				var dip := _dip()
				if dip and dip.states.has(event.nation):
					dip._add_rel(event.nation, 10.0)
				player.feat.emit("Vainqueur du tournoi de %s" % city.get("name", ""), Color("ffd24a"))
				Sound.ui("fanfare")
				post("Le héros remporte le Grand tournoi de %s ! (250 or, une gemme, +10 de relations)" % city.get("name", ""))
				_end_event()
			else:
				player.notify.emit("Champion vaincu ! Le suivant entre dans la lice.")
				_update_arena()
		return
	var pos := _arena.global_position
	if Vector2(player.global_position.x - pos.x, player.global_position.z - pos.z).length() > 7.0:
		return
	var types: Array = Diplomacy.NATIONS[event.nation].army.types
	var kinds: Array = [types[0], types[1 % types.size()], Diplomacy.NATIONS[event.nation].army.leader]
	var e := (load("res://scenes/enemies/enemy.tscn") as PackedScene).instantiate() as Enemy
	var d := (load("res://data/enemies/%s.tres" % kinds[int(event.round)]) as EnemyData).duplicate() as EnemyData
	d.display_name = "Champion de %s" % city_of(event.nation).get("name", "")
	d.loot = []
	e.data = d
	e.level = player.level + int(event.round)
	e.power = 1.15 + 0.05 * e.level
	e.set_meta("tournoi", true)
	_arena.add_child(e)
	var at := pos + Vector3(0, 0, -3)
	at.y = world.support_height(at, pos.y + 0.6)
	e.global_position = at
	e.home = at
	_champion = e
	player.notify.emit("%s entre dans la lice !" % d.display_name)


# ---------------------------------------------------------------- le temps qui passe

func new_day(d: int) -> void:
	if world == null or world.cities.is_empty():
		return
	# fin des guerres
	for w in wars.duplicate():
		if d >= int(w.until):
			_end_war(w)
	# une nouvelle guerre ?
	var ns := _free_nations()
	if wars.size() < MAX_WARS and ns.size() >= 2 and _rng.randf() < WAR_CHANCE:
		var a: String = ns.pick_random()
		var b: String = ns.filter(func(n): return n != a and not at_war(a, n)).pick_random() if ns.size() > 1 else ""
		if b != "":
			start_war(a, b)
	# les nations en guerre lèvent une nouvelle armée de temps en temps
	for w in wars:
		var busy := armies.any(func(ar): return ar.kind == "army" and ar.nation in [w.a, w.b])
		if not busy and _rng.randf() < 0.6:
			if _rng.randf() < 0.5:
				raise_army(w.a, w.b)
			else:
				raise_army(w.b, w.a)
	# les hameaux ravagés se relèvent
	for h in ravaged.keys():
		if d >= int(ravaged[h]):
			ravaged.erase(h)
			var st := _hamlet(h)
			st.erase("ravaged")
			post("Les habitants du hameau de %s sont revenus et rebâtissent." % st.get("name", ""), false)
	_economy_day()
	_season_day()
	changed.emit()


func _process(delta: float) -> void:
	if world == null:
		world = get_tree().get_first_node_in_group("world") as WorldGenerator
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
		return
	if world.cities.is_empty():
		return
	_advance_armies(delta)
	_sync -= delta
	if _sync <= 0.0:
		_sync = 0.5
		_sync_units()
		_tournament_step()
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 1.0
	var d := today()
	if _day < 0:
		_day = d
		_ensure_supply()
		return
	while _day < d:
		_day += 1
		new_day(_day)


## Une ligne pour le terminal et le panneau : les guerres en cours.
func wars_text() -> Array:
	var out := []
	for w in wars:
		out.append("%s contre %s (jusqu'au jour %d)" % [_nation_name(w.a), _nation_name(w.b), int(w.until)])
	return out


# ---------------------------------------------------------------- sauvegarde

func export_state() -> Dictionary:
	var ars := []
	for ar in armies:
		ars.append({"id": ar.id, "kind": ar.kind, "nation": ar.nation, "target": ar.target, "from": ar.from, "goal": ar.goal,
			"dist": ar.dist, "strength": ar.strength})
	return {"day": _day, "seq": _seq, "wars": wars.duplicate(true), "armies": ars, "supply": supply.duplicate(true),
		"owners": owners.duplicate(), "ravaged": ravaged.duplicate(), "event": event.duplicate(), "news": news.duplicate(true),
		"seasons_done": _seasons_done.keys()}


func import_state(d: Dictionary) -> void:
	if world == null:
		world = get_tree().get_first_node_in_group("world") as WorldGenerator
	for id in _units.keys():
		_despawn(id)
	_day = int(d.get("day", -1))
	_seq = int(d.get("seq", 0))
	wars = []
	for w in d.get("wars", []):
		wars.append({"a": str(w.a), "b": str(w.b), "until": int(w.until)})
	supply = {}
	var sp: Dictionary = d.get("supply", {})
	for n in sp:
		supply[str(n)] = {}
		for c in sp[n]:
			supply[str(n)][str(c)] = float(sp[n][c])
	owners = {}
	var ow: Dictionary = d.get("owners", {})
	for h in ow:
		set_hamlet_owner(str(h), str(ow[h]))
	ravaged = {}
	var rv: Dictionary = d.get("ravaged", {})
	for h in rv:
		ravaged[str(h)] = int(rv[h])
		var st := _hamlet(str(h))
		if not st.is_empty():
			st["ravaged"] = true
	news = (d.get("news", []) as Array).duplicate(true)
	_seasons_done = {}
	for k in d.get("seasons_done", []):
		_seasons_done[str(k)] = true
	armies = []
	if world:
		for a in d.get("armies", []):
			var ar := {"id": str(a.id), "kind": str(a.kind), "nation": str(a.nation), "target": str(a.target), "from": str(a.from),
				"goal": str(a.goal), "dist": float(a.dist), "strength": int(a.strength)}
			_prepare(ar)
			if ar.path.size() >= 2:
				armies.append(ar)
	event = (d.get("event", {}) as Dictionary).duplicate()
	if event.has("until"):
		event.until = int(event.until)
		event.round = int(event.get("round", 0))
	changed.emit()
