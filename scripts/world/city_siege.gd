class_name CitySiege
extends Node3D
## Siège d'une vraie capitale (voir CityPlans et Diplomacy) : l'armée du héros arrive devant la grande porte,
## les habitants se barricadent, trois vagues de soldats sortent de la ville, puis le souverain attend dans son palais.
## Il faut traverser la ville (à Minas Cendrys, monter les sept cercles) et le vaincre : la nation devient une province,
## sa capitale arbore la bannière du royaume et un trésor attend devant le palais.
## S'éloigner de la ville (ou mourir) lève le siège.

signal started(nation: String)
signal ended(nation: String, won: bool)

const WAVES := 3
## Au-delà de cette distance de l'enceinte, le siège est levé.
const RETREAT_MARGIN := 70.0
const ENEMY_SCENE := preload("res://scenes/enemies/enemy.tscn")
const BOSS_SCENE := preload("res://scenes/enemies/boss.tscn")
const SOVEREIGNS := {"givre": "Jarl Hrothgar, le Loup Blanc", "sylvae": "Dame Lothaël, Reine des Sylves",
	"sables": "Sultan Ssarak-Ammar", "karg": "Gor, Chef de guerre de Karg", "cendres": "Azhar, Prince des Cendres"}

var player: Player
var world: WorldGenerator
## Nation assiégée (« » sinon), vague en cours (0 : l'armée se déploie ; WAVES + 1 : le souverain).
var nation := ""
var wave := 0
var sovereign: Boss
var _alive: Array = []
var _timer := 0.0
var _city: Dictionary = {}
var _holder: Node3D


func _ready() -> void:
	add_to_group("city_siege")


func active() -> bool:
	return nation != ""


func _dip() -> Diplomacy:
	return get_tree().get_first_node_in_group("diplomacy") as Diplomacy


## La capitale physique d'une nation (ou {} si le monde n'en a pas).
func city_of(id: String) -> Dictionary:
	if world == null:
		return {}
	for c in world.cities:
		if c.nation == id:
			return c
	return {}


func _gate_cell(city: Dictionary) -> Vector2i:
	var gate := Vector2i(0, int(city.radius))
	for g in city.gates:
		if gate == Vector2i(0, int(city.radius)) or Vector2(g).length() > Vector2(gate).length():
			gate = g
	return gate


func _cell_pos(c: Vector2i) -> Vector3:
	var p := Vector3(c.x + 0.5, 0.0, c.y + 0.5)
	p.y = world.terrain_height(c)
	return Vector3(p.x, world.support_height(p, p.y + 0.3), p.z)


## Lance le siège : le héros et ses compagnons arrivent devant la grande porte.
func start(id: String) -> bool:
	if active() or player == null:
		return false
	var city := city_of(id)
	if city.is_empty():
		return false
	nation = id
	_city = city
	wave = 0
	_timer = 5.0
	_alive.clear()
	sovereign = null
	_holder = Node3D.new()
	_holder.name = "Siege_" + id
	add_child(_holder)
	var gate := _gate_cell(city)
	var out := Vector2(gate).normalized()
	world.teleport(_cell_pos((city.center as Vector2i) + gate + Vector2i(roundi(out.x * 12.0), roundi(out.y * 12.0))))
	var cl := get_tree().get_first_node_in_group("city_life")
	if cl:
		cl.refresh(id)
	Sound.ui("war_drums")
	started.emit(id)
	return true


func _process(delta: float) -> void:
	if not active() or player == null or not is_instance_valid(player):
		return
	var ctr: Vector2i = _city.center
	var d := Vector2(player.global_position.x - ctr.x, player.global_position.z - ctr.y).length()
	if not player.is_alive():
		_finish(false)
		return
	if d > float(_city.radius) + RETREAT_MARGIN or player.global_position.y < WorldGenerator.UNDERGROUND:
		_finish(false)
		return
	_alive = _alive.filter(func(e): return is_instance_valid(e) and e.is_alive())
	if wave > WAVES:
		return
	if not _alive.is_empty():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 5.0
	wave += 1
	if wave <= WAVES:
		_spawn_wave()
	else:
		_spawn_sovereign()


func _level() -> int:
	return maxi(5, player.level)


func _spawn_wave() -> void:
	var n: Dictionary = Diplomacy.NATIONS[nation]
	var army: Dictionary = n.army
	var lv := _level()
	var gate := _gate_cell(_city)
	var inward := -Vector2(gate).normalized()
	var side := Vector2(-inward.y, inward.x)
	var count := 4 + 2 * wave
	for i in count:
		var e := ENEMY_SCENE.instantiate() as Enemy
		var tid: String = army.leader if i == 0 and wave == WAVES else army.types[i % army.types.size()]
		e.data = load("res://data/enemies/%s.tres" % tid)
		e.level = lv + wave - 1
		e.power = 1.0 + 0.06 * e.level
		e.set_meta("siege", true)
		_holder.add_child(e)
		var off := inward * (4.0 + (i / 3) * 1.5) + side * float(i % 3 - 1) * 1.5
		e.global_position = _cell_pos((_city.center as Vector2i) + gate + Vector2i(roundi(off.x), roundi(off.y)))
		# ils sortent par la grande porte et marchent sur le héros
		e.home = player.global_position
		e.set("_wander_to", e.home)
		e.set("_returning", true)
		_alive.append(e)
	player.notify.emit("Vague %d / %d : les soldats de %s sortent par la grande porte !" % [wave, WAVES, n.name])
	Sound.play("horn", Vector3.INF, 0.0, 0.0)


func _spawn_sovereign() -> void:
	var n: Dictionary = Diplomacy.NATIONS[nation]
	var army: Dictionary = n.army
	var lv := _level()
	var b := BOSS_SCENE.instantiate() as Boss
	var d := (load("res://data/enemies/%s.tres" % army.leader) as EnemyData).duplicate() as EnemyData
	d.display_name = SOVEREIGNS.get(nation, "Souverain")
	b.data = d
	b.level = lv + 3
	b.power = 1.25 + 0.03 * lv
	b.powers = PackedStringArray(["onde", "charge", "invocation", "pluie"])
	var summons: Array[EnemyData] = []
	for t in army.types:
		summons.append(load("res://data/enemies/%s.tres" % t))
	b.summons = summons
	b.title = "Souverain · " + str(_city.name)
	_holder.add_child(b)
	b.health.set_max(roundi((600.0 + 80.0 * lv) * SaveGame.enemy_hp_mult()), true)
	b.visual.scale *= 1.6
	b.global_position = _cell_pos((_city.center as Vector2i) + (_city.hall as Vector2i))
	b.home = b.global_position
	b.died_at.connect(_on_sovereign_died)
	sovereign = b
	_alive.append(b)
	b.wake()
	player.notify.emit("Les soldats sont vaincus. %s t'attend devant son palais, au cœur de %s !" % [d.display_name, _city.name])
	var dm := get_tree().get_first_node_in_group("dungeons") as DungeonManager
	if dm:
		dm.boss_awoken.emit(b, b.title)


func _on_sovereign_died(_pos: Vector3) -> void:
	var id := nation
	for e in _alive:
		if is_instance_valid(e) and e.is_alive() and e != sovereign:
			VoxelBurst.spawn(e, e.global_position + Vector3(0, 0.8, 0), Color(0.9, 0.9, 0.8), 16, 3.0, 0.1, 0.5)
			e.queue_free()
	var dip := _dip()
	if dip:
		dip.annex(id)
	player.gain_xp(500 + 40 * _level())
	Sound.ui("fanfare")
	# la ville se repeuple à ta bannière, avec le trésor de la capitale devant le palais (voir CityLife)
	_finish(true)


func _finish(won: bool) -> void:
	var id := nation
	nation = ""
	wave = 0
	if not won:
		for e in _alive:
			if is_instance_valid(e):
				e.queue_free()
	_alive.clear()
	if _holder and is_instance_valid(_holder):
		if won:
			# le corps du souverain reste le temps de son animation
			get_tree().create_timer(6.0).timeout.connect(_holder.queue_free)
		else:
			_holder.queue_free()
	_holder = null
	var cl := get_tree().get_first_node_in_group("city_life")
	if cl:
		cl.refresh(id)
	ended.emit(id, won)
