class_name DungeonManager
extends Node3D
## Donjons : chaque zone du monde (sauf celle du village) a une entrée de donjon.
## E devant l'entrée : on descend dans un donjon généré sous la surface (salles, couloirs, torches,
## coffres, monstres de la région) avec, au fond, le boss de la région.
## Quand le héros entre dans la salle du boss, elle se ferme derrière lui jusqu'à la fin du combat.
## Boss vaincu : coffre au trésor, portail de sortie, et le héros absorbe l'âme du boss (bonus permanent).
## Le sol du donjon est une grille de blocs (BuildGrid) posée à FLOOR_Y, bien sous le terrain.
##
## Fin de jeu, la Brume : une fois l'histoire finie (ou tous les donjons vaincus), les donjons déjà vaincus
## sont envahis par la Brume. On peut y redescendre, palier après palier (1 à 10) : monstres « brumeux »
## plus forts, boss « Écho de Brume » et, aux paliers 3, 6, 9 et 10, un Seigneur de Brume légendaire
## (plus grand, tous les pouvoirs) dont l'âme donne un bonus permanent. Trésors : fragments de Brume,
## gemmes, larmes d'esprit, orichalque et, sur les Seigneurs, une pièce d'équipement légendaire.

signal entered(zone: Dictionary)
signal exited(zone: Dictionary)
signal boss_awoken(boss: Boss, title: String)
signal boss_defeated(zone: Dictionary, soul_text: String)
signal siege_started(nation: String)
signal siege_ended(nation: String, won: bool)

## Hauteur du sol des donjons.
const FLOOR_Y := -100
## Taille du donjon (cases).
const SIZE := 58
const WALL_H := 3
const CHEST_MODEL := preload("res://assets/furniture/coffre.glb")
const TORCH_MODEL := preload("res://assets/furniture/torche.glb")
const BARREL_MODEL := preload("res://assets/furniture/tonneau.glb")
const STATUE_MODEL := preload("res://assets/furniture/statue.glb")
const PORTAL_MODEL := preload("res://assets/environment/models/obelisk.glb")
const BOSS_SCENE := preload("res://scenes/enemies/boss.tscn")
const BRUME_MAX := 10
const BRUME_LORD_TIERS := [3, 6, 9, 10]
const BRUME_COLOR := Color("b48cff")
## Âme d'un Seigneur de Brume (une par région et par palier).
const BRUME_LORD_SOUL := {"attack": 3.0, "defense": 2.0}
## Siège d'une capitale ennemie (voir Diplomacy) : une place forte générée sous terre, comme un donjon.
## Trois vagues de soldats sortent du donjon, puis le champion de la nation ; sa défaite annexe la nation.
const SIEGE_WAVES := 3
const SIEGE_W := 34
const SIEGE_H := 28
const SIEGE_KEEP_Y := 8
const CHAMPIONS := {"karg": "Grukk le Brise-Remparts", "sylvae": "Ysolde, la Dryade-Reine", "sables": "Ssarak, Sultan des Sables",
	"givre": "Fenrök, le Loup du Jarl", "cendres": "Azhar, Prince des Cendres"}
const SIEGE_STONE := {"karg": "bloc_rondins", "sylvae": "bloc_planches", "sables": "bloc_sable", "givre": "bloc_ardoise", "cendres": "bloc_marbre_noir"}
## Équipement légendaire que peut laisser un Seigneur de Brume.
const BRUME_LORD_LOOT := ["lame_eveil", "lance_draconique", "armure_draconique", "baton_larmes", "cape_brume", "couronne_pactes"]

var world: WorldGenerator
var player: Player
var active := false
var zone: Dictionary = {}
var grid: BuildGrid
var boss: Boss
## Salles du donjon (en cases du monde) ; la première est l'entrée, la dernière celle du boss.
var rooms: Array[Rect2i] = []
var entrance_room: Rect2i
var boss_room: Rect2i
var _content: Node3D
var _return_pos := Vector3.ZERO
var _sealed: Array[Vector3i] = []
var _interactables: Array = []   # [{node, pos, kind, used}]
var _boss_state := 0             # 0 endormi, 1 combat, 2 vaincu
var _saved := {}
var _player_light: OmniLight3D
var _fade: ColorRect
var _busy := false
## Palier de Brume du donjon en cours (0 : donjon normal).
var brume_tier := 0
var _brume_known := -1
var _brume_check := 0.0
## Siège en cours : identifiant de la nation ("" sinon).
var siege := ""
var siege_wave := 0
var _siege_alive: Array = []
var _siege_timer := 0.0
var _siege_won := false
var _siege_throne := Vector2i.ZERO
var _siege_gate := Vector2i.ZERO
var _siege_spawn := Vector2i.ZERO


func _ready() -> void:
	add_to_group("dungeons")
	world = get_parent() as WorldGenerator
	grid = BuildGrid.new()
	grid.name = "GrilleDonjon"
	grid.register = false
	add_child(grid)
	_content = Node3D.new()
	_content.name = "Contenu"
	add_child(_content)
	if world:
		world.dungeon_grid = grid
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _find_player() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player


func is_inside() -> bool:
	return active


# ---------------------------------------------------------------- la Brume (fin de jeu)

## La Brume est éveillée : histoire finie, ou tous les donjons vaincus.
func brume_unlocked() -> bool:
	var st := get_tree().get_first_node_in_group("story") as Story
	if st and st.is_done():
		return true
	if world == null:
		return false
	var gates := 0
	for z in world.zones:
		if (z.gate as Vector2i).x < 0:
			continue
		gates += 1
		if not z.get("cleared", false):
			return false
	return gates > 0


## Palier de Brume qui attend dans ce donjon (0 : donjon normal).
func next_tier(z: Dictionary) -> int:
	if not z.get("cleared", false) or not brume_unlocked():
		return 0
	return mini(int(z.get("brume", 0)) + 1, BRUME_MAX)


static func is_lord_tier(t: int) -> bool:
	return BRUME_LORD_TIERS.has(t)


## Texte et couleur de l'étiquette au-dessus de l'entrée.
func gate_text(z: Dictionary) -> Array:
	if not z.get("cleared", false):
		return ["Donjon de %s\nE : entrer" % z.name, Color("ffb0a0")]
	var t := next_tier(z)
	if t > 0:
		return ["Donjon de %s\nBrume : palier %d%s\nE : entrer" % [z.name, t, "  ★ Seigneur" if is_lord_tier(t) else ""], BRUME_COLOR]
	return ["Donjon de %s\nVaincu ✔" % z.name, Color("b0ffb0")]


## Résumé pour le journal.
func brume_summary() -> String:
	var best := 0
	if world:
		for z in world.zones:
			best = maxi(best, int(z.get("brume", 0)))
	var lords := 0
	if player:
		lords = player.souls.keys().filter(func(k): return str(k).begins_with("brume_")).size()
	return "La Brume : palier %d / %d franchi au plus haut  ·  %d Seigneur%s de Brume vaincu%s" % [best, BRUME_MAX, lords, "s" if lords > 1 else "", "s" if lords > 1 else ""]


func _check_brume() -> void:
	_find_player()
	var u := brume_unlocked()
	if _brume_known == 0 and u:
		if player:
			player.feat.emit("La Brume s'éveille !", BRUME_COLOR)
			player.notify.emit("Les donjons vaincus sont envahis par la Brume : redescends-y pour des paliers plus durs et des Seigneurs légendaires.")
		if world:
			for z in world.zones:
				if z.get("cleared", false) and (z.gate as Vector2i).x >= 0:
					world.refresh_content(z.gate)
	_brume_known = 1 if u else 0


## Un monstre du donjon devient « brumeux ».
func _brumify(n: Node) -> void:
	if n is Enemy:
		(n as Enemy).brume = true


# ---------------------------------------------------------------- interaction (E)

## Appelé par le héros quand il appuie sur E. Vrai si quelque chose a été fait.
func try_interact(p: Player) -> bool:
	player = p
	if _busy or world == null:
		return false
	if not active:
		for z in world.zones:
			if (z.gate as Vector2i).x < 0:
				continue
			var g := world.cell_center(z.gate)
			if _flat_dist(g, p.global_position) < 2.8 and absf(g.y - p.global_position.y) < 3.0:
				enter(z)
				return true
		return false
	for it in _interactables:
		if it.used or not is_instance_valid(it.node):
			continue
		if _flat_dist(it.pos, p.global_position) < 2.2:
			match it.kind:
				"exit":
					leave()
				"chest":
					_open_chest(it, false)
				"boss_chest":
					_open_chest(it, true)
				"siege_chest":
					_open_siege_chest(it)
			return true
	return false


static func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# ---------------------------------------------------------------- entrée / sortie

func enter(z: Dictionary, instant := false) -> void:
	_find_player()
	if active or player == null:
		return
	_busy = true
	var go := func():
		_build(z)
		_busy = false
	if instant:
		go.call()
		return
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.35)
	tw.tween_callback(go)
	tw.tween_property(_fade, "color:a", 0.0, 0.5)


func leave(instant := false) -> void:
	if not active:
		return
	_busy = true
	var go := func():
		var z := zone
		_cleanup()
		if player:
			world.load_area(_return_pos)
			player.global_position = _return_pos
			player.snap_camera()
			Villager.bring_companions(get_tree(), _return_pos)
		exited.emit(z)
		_busy = false
	if instant:
		go.call()
		return
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.35)
	tw.tween_callback(go)
	tw.tween_property(_fade, "color:a", 0.0, 0.5)


func _process(delta: float) -> void:
	_brume_check -= delta
	if _brume_check <= 0.0:
		_brume_check = 2.0
		_check_brume()
	if not active or player == null:
		return
	if siege != "" and player.global_position.y <= WorldGenerator.UNDERGROUND:
		_siege_process(delta)
	# mort dans le donjon : le héros s'est réveillé au village
	if player.global_position.y > WorldGenerator.UNDERGROUND:
		var z := zone
		_cleanup()
		exited.emit(z)
		return
	if _boss_state == 0 and boss and is_instance_valid(boss):
		var inner := boss_room.grow(-2)
		var c := world.cell_at(player.global_position)
		if inner.has_point(c):
			_start_boss_fight()


# ---------------------------------------------------------------- génération

func _build(z: Dictionary) -> void:
	zone = z
	brume_tier = next_tier(z)
	active = true
	_boss_state = 0
	_sealed.clear()
	_interactables.clear()
	var r: RegionData = z.type
	_return_pos = world.cell_center(z.gate) + Vector3(0, 0, 2.6)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(world.world_seed, z.id, 77))
	var origin := Vector2i(clampi(z.gate.x - SIZE / 2, 0, world.world_size.x - SIZE), clampi(z.gate.y - SIZE / 2, 0, world.world_size.y - SIZE))
	var floor_cells := _layout(rng, origin)
	var floor_item: ItemData = r.dungeon_floor if r and r.dungeon_floor else Items.get_item("bloc_pierre_brute")
	var wall_item: ItemData = r.dungeon_wall if r and r.dungeon_wall else Items.get_item("bloc_briques")
	var accent: ItemData = r.dungeon_accent if r and r.dungeon_accent else wall_item
	# sol et murs
	for c in floor_cells:
		grid.place_block(Vector3i(c.x, FLOOR_Y - 1, c.y), floor_item)
	var walls := {}
	for c in floor_cells:
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var n: Vector2i = c + Vector2i(dx, dy)
				if not floor_cells.has(n):
					walls[n] = true
	for w in walls:
		grid.place_block(Vector3i(w.x, FLOOR_Y - 1, w.y), wall_item)
		for h in WALL_H:
			grid.place_block(Vector3i(w.x, FLOOR_Y + h, w.y), accent if h == WALL_H - 1 and (w.x + w.y) % 4 == 0 else wall_item)
	# piliers dans les grandes salles
	for room in rooms:
		if room.size.x >= 9 and room.size.y >= 9:
			for p in [Vector2i(2, 2), Vector2i(room.size.x - 3, 2), Vector2i(2, room.size.y - 3), Vector2i(room.size.x - 3, room.size.y - 3)]:
				var pc: Vector2i = room.position + p
				for h in WALL_H:
					grid.place_block(Vector3i(pc.x, FLOOR_Y + h, pc.y), accent)
	_decorate(rng, r)
	_populate(rng, z, r)
	_set_lighting(true, r)
	player.global_position = _floor_pos(entrance_room.get_center() + Vector2i(0, 1))
	player.snap_camera()
	Villager.bring_companions(get_tree(), player.global_position)
	entered.emit(z)


## Salles et couloirs. Renvoie les cases du sol.
func _layout(rng: RandomNumberGenerator, origin: Vector2i) -> Dictionary:
	rooms.clear()
	var local: Array[Rect2i] = []
	# salle du boss dans un coin, entrée dans le coin opposé
	var corner := rng.randi() % 4
	var bx := 3 if corner % 2 == 0 else SIZE - 3 - 14
	var by := 3 if corner < 2 else SIZE - 3 - 14
	var boss_r := Rect2i(bx, by, 14, 14)
	var ex := SIZE - 3 - 8 if corner % 2 == 0 else 3
	var ey := SIZE - 3 - 8 if corner < 2 else 3
	var entrance_r := Rect2i(ex, ey, 8, 8)
	local.append(entrance_r)
	var tries := 0
	while local.size() < 8 and tries < 300:
		tries += 1
		var w := rng.randi_range(7, 11)
		var h := rng.randi_range(7, 11)
		var rr := Rect2i(rng.randi_range(2, SIZE - w - 2), rng.randi_range(2, SIZE - h - 2), w, h)
		var ok := not rr.grow(3).intersects(boss_r)
		for o in local:
			if rr.grow(3).intersects(o):
				ok = false
		if ok:
			local.append(rr)
	local.append(boss_r)
	var cells := {}
	for rr in local:
		for y in range(rr.position.y, rr.end.y):
			for x in range(rr.position.x, rr.end.x):
				cells[Vector2i(x, y)] = true
	# couloirs : arbre couvrant minimal (Prim) + un couloir en plus ; la salle du boss n'a qu'une porte
	var connected := [0]
	var edges := []
	var normal := range(local.size() - 1)
	while connected.size() < normal.size():
		var best := [-1, -1]
		var bd := INF
		for a in connected:
			for b in normal:
				if connected.has(b):
					continue
				var d := Vector2(local[a].get_center()).distance_to(Vector2(local[b].get_center()))
				if d < bd:
					bd = d
					best = [a, b]
		connected.append(best[1])
		edges.append(best)
	if normal.size() > 3:
		edges.append([normal[rng.randi_range(1, normal.size() - 1)], normal[rng.randi_range(1, normal.size() - 1)]])
	# la salle la plus éloignée de l'entrée mène au boss
	var far := 0
	var fd := -1.0
	for i in normal:
		var d := Vector2(local[i].get_center()).distance_to(Vector2(boss_r.get_center()))
		if i != 0 and (fd < 0 or d < fd):
			fd = d
			far = i
	edges.append([far, local.size() - 1])
	for e in edges:
		if e[0] == e[1]:
			continue
		_corridor(cells, local[e[0]].get_center(), local[e[1]].get_center(), rng.randf() < 0.5)
	rooms.clear()
	for rr in local:
		rooms.append(Rect2i(rr.position + origin, rr.size))
	entrance_room = rooms[0]
	boss_room = rooms[rooms.size() - 1]
	var out := {}
	for c in cells:
		out[c + origin] = true
	return out


func _corridor(cells: Dictionary, a: Vector2i, b: Vector2i, x_first: bool) -> void:
	var p := a
	var steps := [Vector2i(signi(b.x - a.x), 0), Vector2i(0, signi(b.y - a.y))]
	if not x_first:
		steps.reverse()
	for st in steps:
		if st == Vector2i.ZERO:
			continue
		while (st.x != 0 and p.x != b.x) or (st.y != 0 and p.y != b.y):
			for k in [0, 1]:
				cells[p + (Vector2i(0, k) if st.x != 0 else Vector2i(k, 0))] = true
			p += st
	for k in [0, 1]:
		cells[p + Vector2i(k, 0)] = true
		cells[p + Vector2i(0, k)] = true


func _floor_pos(c: Vector2i) -> Vector3:
	return Vector3(c.x + 0.5, FLOOR_Y, c.y + 0.5)


func _add_model(scene: PackedScene, c: Vector2i, rot := 0.0, sc := 1.0) -> Node3D:
	var n := scene.instantiate() as Node3D
	_content.add_child(n)
	n.global_position = _floor_pos(c)
	n.rotation.y = rot
	n.scale = Vector3.ONE * sc
	return n


func _label(parent: Node3D, text: String, y: float, col: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 34
	l.pixel_size = 0.006
	l.outline_size = 9
	l.modulate = col
	l.no_depth_test = true
	l.position.y = y
	parent.add_child(l)
	return l


func _decorate(rng: RandomNumberGenerator, r: RegionData) -> void:
	var light_col := r.dungeon_light if r else Color(1, 0.7, 0.4)
	if brume_tier > 0:
		light_col = BRUME_COLOR
	for room in rooms:
		# torches dans deux coins opposés
		for corner in [room.position + Vector2i(1, 1), room.end - Vector2i(2, 2)]:
			var t := _add_model(TORCH_MODEL, corner)
			var l := OmniLight3D.new()
			l.light_color = light_col
			l.light_energy = 1.6
			l.omni_range = 8.0
			l.position.y = 1.3
			t.add_child(l)
		# quelques tonneaux
		if room != boss_room and rng.randf() < 0.6:
			_add_model(BARREL_MODEL, Vector2i(room.end.x - 2, room.position.y + 1), rng.randf() * TAU)
	# statues à l'entrée de la salle du boss
	for p in [Vector2i(1, boss_room.size.y / 2 - 2), Vector2i(boss_room.size.x - 2, boss_room.size.y / 2 - 2)]:
		_add_model(STATUE_MODEL, boss_room.position + p, PI)
	# portail de sortie
	_add_portal(entrance_room.get_center() + Vector2i(0, -2))


func _add_portal(c: Vector2i, text := "Sortie\nE : remonter") -> void:
	var n := _add_model(PORTAL_MODEL, c, 0.0, 0.8)
	var l := OmniLight3D.new()
	l.light_color = Color("8af0ff")
	l.light_energy = 1.4
	l.omni_range = 5.0
	l.position.y = 2.2
	n.add_child(l)
	_label(n, text, 4.2, Color("bff6ff"))
	_interactables.append({"node": n, "pos": n.global_position, "kind": "exit", "used": false})


func _add_chest(c: Vector2i, boss_chest := false) -> void:
	var n := _add_model(CHEST_MODEL, c, PI, 1.6 if boss_chest else 1.0)
	var lab := _label(n, ("Trésor du boss" if boss_chest else "Coffre") + "\nE : ouvrir", 1.6, Color("ffd24a"))
	_interactables.append({"node": n, "pos": n.global_position, "kind": "boss_chest" if boss_chest else "chest", "used": false, "label": lab})


func _populate(rng: RandomNumberGenerator, z: Dictionary, r: RegionData) -> void:
	var lv: Vector2i = z.level
	# la Brume : +4 niveaux par palier (+4 de plus dès le premier)
	var up := 4 * brume_tier + (4 if brume_tier > 0 else 0)
	var lord := is_lord_tier(brume_tier)
	var middle := rooms.slice(1, rooms.size() - 1)
	middle.shuffle()
	var elite_done := false
	for i in middle.size():
		var room: Rect2i = middle[i]
		var camp := EnemyCamp.new()
		camp.respawn_time = 1.0e9
		camp.radius = minf(room.size.x, room.size.y) * 0.3
		camp.levels = Vector2i(lv.y + up, lv.y + 1 + up)
		if brume_tier > 0:
			camp.child_entered_tree.connect(_brumify)
		camp.base_level = r.level_range.x if r else 1
		var pool: Array[EnemyData] = []
		if r and not elite_done and not r.elite_enemies.is_empty() and i == 0:
			elite_done = true
			pool.append(r.elite_enemies[rng.randi() % r.elite_enemies.size()])
			camp.count = 1
		elif r and not r.enemies.is_empty():
			pool.append(r.enemies[rng.randi() % r.enemies.size()])
			pool.append(r.enemies[rng.randi() % r.enemies.size()])
			camp.count = rng.randi_range(2, 4)
		camp.enemy_types = pool
		_content.add_child(camp)
		camp.global_position = _floor_pos(room.get_center())
		# un coffre dans une salle sur deux
		if i % 2 == 1:
			_add_chest(room.position + Vector2i(1, room.size.y - 2))
		# un prisonnier à libérer (il rejoint le village sans rien demander)
		if i == middle.size() - 1:
			_add_prisoner(rng, room, z, r)
	# le boss
	if r and r.boss:
		boss = BOSS_SCENE.instantiate() as Boss
		boss.data = r.boss
		boss.level = lv.y + 2 + up
		boss.power = 1.0 + 0.09 * maxi(0, boss.level - r.level_range.x)
		boss.powers = r.boss_powers
		boss.summons = r.enemies
		boss.title = r.boss_title
		if brume_tier > 0:
			boss.brume = true
			boss.title = ("Seigneur de Brume" if lord else "Écho de Brume") + " — palier %d" % brume_tier
			if lord or brume_tier >= 4:
				var pw := PackedStringArray(r.boss_powers)
				for p in ["onde", "pluie", "invocation", "charge"]:
					if not pw.has(p):
						pw.append(p)
				boss.powers = pw
			if lord:
				boss.power *= 1.5
		_content.add_child(boss)
		if lord:
			boss.visual.scale *= 1.3
			var aura := OmniLight3D.new()
			aura.light_color = BRUME_COLOR
			aura.light_energy = 2.2
			aura.omni_range = 7.0
			aura.position.y = 2.0
			boss.add_child(aura)
		boss.global_position = _floor_pos(boss_room.get_center())
		boss.home = boss.global_position
		boss.facing = Vector3(0, 0, 1)
		boss.died_at.connect(_on_boss_died)


func _add_prisoner(rng: RandomNumberGenerator, room: Rect2i, z: Dictionary, r: RegionData) -> void:
	var key := "donjon_%d" % z.id
	if world._recruited.has(key) or world.villager_scene == null:
		return
	var races: Array = r.recruit_races if r and not r.recruit_races.is_empty() else world.villager_races
	if races.is_empty():
		return
	var v := world.villager_scene.instantiate() as Villager
	v.stranger = true
	v.race = races[rng.randi() % races.size()]
	v.villager_name = Villager.NAMES[rng.randi() % Villager.NAMES.size()]
	v.level = (z.level as Vector2i).y
	var jobs := Villager.JOBS.duplicate()
	var j1: String = jobs[rng.randi() % jobs.size()]
	jobs.erase(j1)
	v.talents = {j1: rng.randf_range(0.55, 0.8), jobs[rng.randi() % jobs.size()]: rng.randf_range(0.2, 0.35)}
	v.recruit_offer = {"items": [], "text": "Les monstres m'ont enfermé ici depuis des jours... Sors-moi de là et je te servirai fidèlement !"}
	v.set_meta("recruit_key", key)
	v.set_meta("prisoner", true)
	v.wander_radius = 0.6
	_content.add_child(v)
	var c := room.end - Vector2i(3, 3)
	v.global_position = _floor_pos(c)
	v.home = v.global_position
	# une petite cage de barreaux autour de lui
	var bars: ItemData = Items.get_item("bloc_verre")
	for off in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		var b: Vector2i = c + off
		if grid.block_at(Vector3i(b.x, FLOOR_Y, b.y)) == null:
			grid.place_block(Vector3i(b.x, FLOOR_Y, b.y), bars)


# ---------------------------------------------------------------- combat de boss

func _start_boss_fight() -> void:
	_boss_state = 1
	# on ferme la salle : les cases de couloir qui touchent la salle deviennent des murs
	var wall_item: ItemData = (zone.type as RegionData).dungeon_wall if zone.type else Items.get_item("bloc_briques")
	var ring := boss_room.grow(1)
	for y in range(ring.position.y, ring.end.y):
		for x in range(ring.position.x, ring.end.x):
			var c := Vector2i(x, y)
			if boss_room.has_point(c):
				continue
			if grid.block_at(Vector3i(c.x, FLOOR_Y - 1, c.y)) and grid.block_at(Vector3i(c.x, FLOOR_Y, c.y)) == null:
				for h in WALL_H:
					var k := Vector3i(c.x, FLOOR_Y + h, c.y)
					if grid.place_block(k, wall_item):
						_sealed.append(k)
				VoxelBurst.spawn(self, _floor_pos(c) + Vector3(0, 1, 0), Color(0.6, 0.5, 0.45), 14, 3.0, 0.1, 0.5)
	boss.wake()
	boss_awoken.emit(boss, boss.title)


func _on_boss_died(_pos: Vector3) -> void:
	_boss_state = 2
	for k in _sealed:
		grid.remove_block(k)
	_sealed.clear()
	var center := boss_room.get_center()
	_add_chest(center + Vector2i(0, -1), true)
	_add_portal(center + Vector2i(0, -4))
	zone["cleared"] = true
	world.refresh_content(zone.gate)
	var r: RegionData = zone.type
	var text := ""
	if brume_tier > 0:
		zone["brume"] = maxi(int(zone.get("brume", 0)), brume_tier)
		text = "Palier %d de la Brume dissipé" % brume_tier
		if r and player:
			if is_lord_tier(brume_tier):
				var id := "brume_%s_%d" % [r.id, brume_tier]
				if not player.souls.has(id):
					player.absorb_soul(id, BRUME_LORD_SOUL)
					text = "Âme légendaire du Seigneur de Brume : +3 attaque, +2 défense"
			player.gain_xp(150 + 40 * (zone.level as Vector2i).y + 120 * brume_tier)
	elif r and player:
		text = r.boss_soul_name
		player.absorb_soul(r.id, r.boss_soul)
		player.gain_xp(150 + 40 * (zone.level as Vector2i).y)
	boss_defeated.emit(zone, text)


func _open_chest(it: Dictionary, boss_chest: bool) -> void:
	it.used = true
	var r: RegionData = zone.type
	var pos: Vector3 = it.pos
	var loot := []
	var n := 4 if boss_chest else 2
	for i in n:
		if r and not r.resources.is_empty():
			loot.append([r.resources.pick_random(), randi_range(1, 3)])
	loot.append([Items.get_item("piece_or"), randi_range(2, 5) * (3 if boss_chest else 1)])
	if boss_chest:
		loot.append([Items.get_item("lingot_or"), 2])
		var rare_boss := RareDrops.roll_chest("donjon_boss")
		loot.append_array(rare_boss)
		RareDrops.announce(get_tree().get_first_node_in_group("player") as Player, rare_boss)
		if brume_tier > 0:
			var bl := _brume_loot()
			loot.append_array(bl)
			RareDrops.announce(get_tree().get_first_node_in_group("player") as Player, bl)
	var rare: int = 2 if boss_chest else (1 if randf() < 0.5 else 0)
	for i in rare:
		if not world.wild_loot.is_empty():
			loot.append([world.wild_loot.pick_random(), 1])
	for i in loot.size():
		var a := TAU * i / loot.size()
		if loot[i][0]:
			world.spawn_pickup(loot[i][0], pos + Vector3(cos(a), 0, sin(a)) * 1.3, loot[i][1], _content)
	VoxelBurst.spawn(self, pos + Vector3(0, 0.8, 0), Color("ffd24a"), 40 if boss_chest else 20, 5.0, 0.1, 0.8, "up", 6.0)
	if it.has("label") and is_instance_valid(it.label):
		it.label.text = "Vide"
		it.label.modulate = Color(0.7, 0.7, 0.7)
	if player:
		player.notify.emit("Coffre ouvert : %d objets." % loot.size())


## Trésor d'un boss de la Brume : [[ItemData, nombre], ...].
func _brume_loot() -> Array:
	var t := brume_tier
	var out := [[Items.get_item("fragment_brume"), 2 + t]]
	for i in 1 + t / 3:
		out.append([Items.get_item(RareDrops.GEM_IDS.pick_random()), 1])
	if randf() < 0.3 + 0.05 * t:
		out.append([Items.get_item("larme_esprit"), 1])
	if randf() < 0.1 + 0.06 * t:
		out.append([Items.get_item("orichalque"), 1])
	if is_lord_tier(t):
		out.append([Items.get_item("orichalque"), 1])
		out.append([Items.get_item(RareDrops.GEM_IDS.pick_random()), 2])
		if randf() < 0.5:
			out.append([Items.get_item(BRUME_LORD_LOOT.pick_random()), 1])
	return out.filter(func(p): return p[0] != null)


# ---------------------------------------------------------------- ambiance

func _set_lighting(dark: bool, r: RegionData) -> void:
	# le soleil et l'ambiance sont à côté du monde dans la scène principale
	var scene_root: Node = world.get_parent() if world and world.get_parent() else get_tree().current_scene
	var sun := scene_root.get_node_or_null("Soleil") as DirectionalLight3D if scene_root else null
	var env_node := scene_root.get_node_or_null("Ambiance") as WorldEnvironment if scene_root else null
	var env: Environment = env_node.environment if env_node else null
	if dark:
		if sun and not _saved.has("sun"):
			_saved["sun"] = [sun.light_energy, sun.shadow_enabled]
			sun.light_energy = 0.12
			sun.shadow_enabled = false
		if env and not _saved.has("env"):
			_saved["env"] = [env.background_color, env.ambient_light_color, env.ambient_light_energy]
			env.background_color = Color(0.02, 0.015, 0.03)
			env.ambient_light_color = (r.dungeon_ambient if r else Color(0.12, 0.1, 0.14)).lightened(0.25)
			if brume_tier > 0:
				env.ambient_light_color = env.ambient_light_color.lerp(BRUME_COLOR, 0.45)
			env.ambient_light_energy = 0.9
		if player and _player_light == null:
			_player_light = OmniLight3D.new()
			_player_light.light_color = Color(1.0, 0.92, 0.8)
			_player_light.light_energy = 0.9
			_player_light.omni_range = 7.0
			_player_light.position.y = 2.2
			player.add_child(_player_light)
	else:
		if sun and _saved.has("sun"):
			sun.light_energy = _saved.sun[0]
			sun.shadow_enabled = _saved.sun[1]
		if env and _saved.has("env"):
			env.background_color = _saved.env[0]
			env.ambient_light_color = _saved.env[1]
			env.ambient_light_energy = _saved.env[2]
		_saved.clear()
		if _player_light and is_instance_valid(_player_light):
			_player_light.queue_free()
		_player_light = null


func _cleanup() -> void:
	active = false
	if siege != "":
		var s := siege
		var won := _siege_won
		siege = ""
		siege_wave = 0
		_siege_alive.clear()
		if not won:
			siege_ended.emit(s, false)
	brume_tier = 0
	_set_lighting(false, null)
	grid.clear()
	for c in _content.get_children():
		c.queue_free()
	boss = null
	_interactables.clear()
	_sealed.clear()
	rooms.clear()


# ---------------------------------------------------------------- siège d'une capitale

## Lance le siège de la capitale d'une nation en guerre (appelé par la diplomatie).
func enter_siege(id: String, instant := false) -> void:
	_find_player()
	if active or player == null or _busy or not Diplomacy.NATIONS.has(id):
		return
	_busy = true
	var go := func():
		_build_siege(id)
		_busy = false
	if instant:
		go.call()
		return
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.35)
	tw.tween_callback(go)
	tw.tween_property(_fade, "color:a", 0.0, 0.5)


func _build_siege(id: String) -> void:
	var n: Dictionary = Diplomacy.NATIONS[id]
	siege = id
	siege_wave = 0
	_siege_won = false
	_siege_alive.clear()
	_siege_timer = 4.0
	zone = {"name": "Capitale de " + n.name, "siege": id}
	active = true
	brume_tier = 0
	_boss_state = 2
	boss = null
	_sealed.clear()
	_interactables.clear()
	rooms.clear()
	_return_pos = player.global_position
	var pc := world.cell_at(player.global_position)
	var o := Vector2i(clampi(pc.x - SIEGE_W / 2, 1, world.world_size.x - SIEGE_W - 1), clampi(pc.y - SIEGE_H / 2, 1, world.world_size.y - SIEGE_H - 1))
	var floor_item: ItemData = Items.get_item("bloc_pierre_polie")
	var wall: ItemData = Items.get_item("bloc_briques")
	var accent: ItemData = Items.get_item(SIEGE_STONE.get(id, "bloc_marbre"))
	var put := func(x: int, y: int, h: int, it: ItemData) -> void:
		grid.place_block(Vector3i(o.x + x, FLOOR_Y + h, o.y + y), it)
	for y in SIEGE_H:
		for x in SIEGE_W:
			put.call(x, y, -1, floor_item)
	# l'enceinte, crénelée aux couleurs de la nation
	for y in range(-1, SIEGE_H + 1):
		for x in range(-1, SIEGE_W + 1):
			if x >= 0 and x < SIEGE_W and y >= 0 and y < SIEGE_H:
				continue
			put.call(x, y, -1, wall)
			for h in 5:
				if h == 4 and (x + y) % 2 == 1:
					continue
				put.call(x, y, h, accent if h >= 3 else wall)
	# quatre tours
	for corner in [Vector2i(0, 0), Vector2i(SIEGE_W - 3, 0), Vector2i(0, SIEGE_H - 3), Vector2i(SIEGE_W - 3, SIEGE_H - 3)]:
		for dy in 3:
			for dx in 3:
				for h in 7:
					put.call(corner.x + dx, corner.y + dy, h, accent if h >= 5 else wall)
	# le rempart du donjon (au nord), percé d'une porte
	for x in range(3, SIEGE_W - 3):
		if absi(x - SIEGE_W / 2) <= 2:
			continue
		for h in 3:
			put.call(x, SIEGE_KEEP_Y, h, accent if h == 2 else wall)
	_siege_throne = o + Vector2i(SIEGE_W / 2, 3)
	_siege_gate = o + Vector2i(SIEGE_W / 2, SIEGE_KEEP_Y)
	_siege_spawn = o + Vector2i(SIEGE_W / 2, SIEGE_H - 4)
	rooms.append(Rect2i(o, Vector2i(SIEGE_W, SIEGE_H)))
	# trône, statues, torches et bannière
	_add_model(STATUE_MODEL, _siege_throne + Vector2i(-3, 0), 0.0)
	_add_model(STATUE_MODEL, _siege_throne + Vector2i(3, 0), 0.0)
	var banner := _add_model(TORCH_MODEL, _siege_throne + Vector2i(0, -1))
	_label(banner, n.name, 3.6, n.color)
	for p in [Vector2i(4, 4), Vector2i(SIEGE_W - 5, 4), Vector2i(4, SIEGE_H - 5), Vector2i(SIEGE_W - 5, SIEGE_H - 5),
			Vector2i(SIEGE_W / 2 - 4, SIEGE_KEEP_Y + 1), Vector2i(SIEGE_W / 2 + 4, SIEGE_KEEP_Y + 1)]:
		var t := _add_model(TORCH_MODEL, o + p)
		var l := OmniLight3D.new()
		l.light_color = Color(n.color).lightened(0.3)
		l.light_energy = 1.8
		l.omni_range = 10.0
		l.position.y = 1.3
		t.add_child(l)
	_add_portal(_siege_spawn + Vector2i(0, 2), "Retraite\nE : lever le siège")
	# lumière de plein jour
	_set_lighting(true, null)
	var scene_root: Node = world.get_parent() if world.get_parent() else get_tree().current_scene
	var env_node := scene_root.get_node_or_null("Ambiance") as WorldEnvironment
	if env_node and env_node.environment:
		env_node.environment.background_color = Color(0.42, 0.55, 0.72)
		env_node.environment.ambient_light_color = Color(0.95, 0.88, 0.78)
		env_node.environment.ambient_light_energy = 0.95
	player.global_position = _floor_pos(_siege_spawn)
	player.snap_camera()
	Villager.bring_companions(get_tree(), player.global_position)
	siege_started.emit(id)


func _siege_process(delta: float) -> void:
	if _siege_won:
		return
	_siege_alive = _siege_alive.filter(func(e): return is_instance_valid(e) and e.is_alive())
	if not _siege_alive.is_empty() or siege_wave > SIEGE_WAVES:
		return
	_siege_timer -= delta
	if _siege_timer > 0.0:
		return
	_siege_timer = 4.0
	siege_wave += 1
	if siege_wave <= SIEGE_WAVES:
		_spawn_siege_wave()
	else:
		_spawn_champion()


func _siege_level() -> int:
	return maxi(3, player.level if player else 5)


func _spawn_siege_wave() -> void:
	var n: Dictionary = Diplomacy.NATIONS[siege]
	var army: Dictionary = n.army
	var scene := load("res://scenes/enemies/enemy.tscn") as PackedScene
	var lv := _siege_level()
	var count := 3 + 2 * siege_wave
	for i in count:
		var e := scene.instantiate() as Enemy
		var tid: String = army.leader if i == 0 and siege_wave == SIEGE_WAVES else army.types[i % army.types.size()]
		e.data = load("res://data/enemies/%s.tres" % tid)
		e.level = lv + siege_wave - 1
		e.power = 1.0 + 0.06 * e.level
		e.set_meta("siege", true)
		_content.add_child(e)
		var c: Vector2i = _siege_gate + Vector2i(randi_range(-2, 2), randi_range(-3, 0))
		e.global_position = _floor_pos(c)
		# ils marchent sur le héros
		e.home = _floor_pos(_siege_spawn)
		e.set("_wander_to", e.home)
		e.set("_returning", true)
		_siege_alive.append(e)
	if player:
		player.notify.emit("Vague %d / %d : les soldats de %s sortent du donjon !" % [siege_wave, SIEGE_WAVES, n.name])
		Sound.play("horn", Vector3.INF, 0.0, 0.0)


func _spawn_champion() -> void:
	var n: Dictionary = Diplomacy.NATIONS[siege]
	var army: Dictionary = n.army
	var lv := _siege_level()
	var b := BOSS_SCENE.instantiate() as Boss
	var d := (load("res://data/enemies/%s.tres" % army.leader) as EnemyData).duplicate() as EnemyData
	d.display_name = CHAMPIONS.get(siege, "Champion")
	b.data = d
	b.level = lv + 3
	b.power = 1.2 + 0.03 * lv
	b.powers = PackedStringArray(["onde", "charge", "invocation", "pluie"])
	var summons: Array[EnemyData] = []
	for t in army.types:
		summons.append(load("res://data/enemies/%s.tres" % t))
	b.summons = summons
	b.title = "Champion · " + n.name
	_content.add_child(b)
	b.health.set_max(roundi((500.0 + 70.0 * lv) * SaveGame.enemy_hp_mult()), true)
	b.visual.scale *= 1.5
	b.global_position = _floor_pos(_siege_throne + Vector2i(0, 2))
	b.home = b.global_position
	b.facing = Vector3(0, 0, 1)
	b.died_at.connect(_on_champion_died)
	boss = b
	_siege_alive.append(b)
	b.wake()
	boss_awoken.emit(b, b.title)


func _on_champion_died(_pos: Vector3) -> void:
	_siege_won = true
	var id := siege
	var dip := get_tree().get_first_node_in_group("diplomacy") as Diplomacy
	if dip:
		dip.annex(id)
	# les derniers soldats se rendent
	for e in _siege_alive:
		if is_instance_valid(e) and e.is_alive() and e != boss:
			VoxelBurst.spawn(e, e.global_position + Vector3(0, 0.8, 0), Color(0.9, 0.9, 0.8), 16, 3.0, 0.1, 0.5)
			e.queue_free()
	var n := _add_model(CHEST_MODEL, _siege_throne, PI, 1.6)
	var lab := _label(n, "Trésor de la capitale\nE : ouvrir", 1.6, Color("ffd24a"))
	_interactables.append({"node": n, "pos": n.global_position, "kind": "siege_chest", "used": false, "label": lab})
	_add_portal(_siege_throne + Vector2i(0, -2) + Vector2i(4, 0), "Retour au royaume\nE : remonter")
	if player:
		player.gain_xp(400 + 30 * _siege_level())
	siege_ended.emit(id, true)


func _open_siege_chest(it: Dictionary) -> void:
	it.used = true
	var n: Dictionary = Diplomacy.NATIONS.get(zone.get("siege", ""), {})
	var loot := [[Items.get_item("piece_or"), 500], [Items.get_item("orichalque"), 1]]
	for pair in n.get("goods", []):
		loot.append([Items.get_item(pair[0]), int(pair[1]) * 2])
	for i in 2:
		loot.append([Items.get_item(RareDrops.GEM_IDS.pick_random()), 1])
	var pos: Vector3 = it.pos
	for i in loot.size():
		var a := TAU * i / loot.size()
		if loot[i][0]:
			world.spawn_pickup(loot[i][0], pos + Vector3(cos(a), 0, sin(a)) * 1.4, loot[i][1], _content)
	VoxelBurst.spawn(self, pos + Vector3(0, 0.8, 0), Color("ffd24a"), 40, 5.0, 0.1, 0.8, "up", 6.0)
	if it.has("label") and is_instance_valid(it.label):
		it.label.text = "Vide"
	if player:
		player.notify.emit("Le trésor de la capitale est à toi : %d objets." % loot.size())
