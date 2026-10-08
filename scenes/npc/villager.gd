class_name Villager
extends Combatant
## Habitant du village : se promène autour de sa maison, ramasse les armes et armures
## qui traînent près de lui et les équipe si elles sont meilleures que les siennes.
## Armé, il défend le village contre les monstres ; sans arme, il s'enfuit.
## À 0 point de vie il tombe K.O. puis se relève un peu plus tard.
## La race se choisit dans l'Inspecteur (ou par le générateur de monde).

const NAMES := ["Aldric", "Brunhild", "Cassian", "Dagna", "Elric", "Fenna", "Garrick", "Hilda",
	"Ivar", "Jorun", "Kael", "Liora", "Magnus", "Nessa", "Orin", "Perrine", "Quentin", "Rowena",
	"Sigrid", "Thorin", "Ulric", "Vesna", "Wendel", "Yselle", "Zora", "Anselme", "Bérénice", "Corentin"]

@export var race: RaceData
## Nom affiché (tiré au hasard si vide).
@export var villager_name: String = ""
## Vitesse de marche, en mètres par seconde.
@export var walk_speed: float = 1.4
## Distance max (en mètres) autour du point de départ.
@export var wander_radius: float = 4.0
@export var min_pause: float = 1.0
@export var max_pause: float = 3.5
## Distance (en mètres) à laquelle l'habitant repère un équipement au sol.
@export var loot_radius: float = 9.0
## Distance à laquelle il repère un monstre.
@export var alert_radius: float = 9.0
## Il ne poursuit pas un monstre à plus de cette distance de sa maison.
@export var defend_radius: float = 16.0
## Durée du K.O. (secondes).
@export var knockout_time: float = 20.0

@onready var label: Label3D = $Label

var home: Vector3
var _target := Vector3.ZERO
var _pause := 0.0
var _fetch: ItemPickup
var _scan_timer := randf()
var _threat: Combatant
var _threat_timer := randf() * 0.5
var _ko_left := 0.0
var _combo := 0
## Pièce où l'habitant travaille (voir Kingdom), ou null. Son métier lui donne sa tenue (modèle <race>_<métier>.glb).
var work_room = null:
	set(r):
		work_room = r
		_refresh_model()
## Talents personnels : métier -> bonus d'affinité.
var talents := {}
var _stuck := 0.0
var _work_for = null
var _work_spot := Vector3.INF
var _work_face := Vector3.BACK
var _path: Array[Vector3] = []
var _repath := 0.0
var _work_anim := randf() * 2.0
var _at_work := false
## Chantier en cours (voir BuildOrders) : les habitants libres construisent les plans du joueur.
var _order = null
var _order_spot := Vector3.INF
var _order_timer := randf()
var _order_stuck := 0.0
## Voyageur rencontré dans le monde (pas encore habitant) : il attend qu'on lui parle.
var stranger := false
## Ce qu'il demande pour rejoindre le village : {"item": ItemData, "count": int, "text": String}.
var recruit_offer := {}
## Compagnon d'expédition : il suit le héros partout et combat avec lui.
var companion := false
## Niveau de l'habitant (un compagnon progresse avec le héros).
var level := 1
## Évolution par le Pacte (0 à 2) et son nom (« Hobgobelin », « Orc noble »...).
var evo := 0
var evo_title := ""
## Variante de couleur du modèle (0 à 2) et modèle d'évolution affiché (0 = la race de base).
var model_variant := -1
var evo_model := 0
## Bonus d'attaque des gardes pendant un raid.
var guard_bonus := 0.0
## Besoins (voir VillageNeeds) : faim (100 = rassasié), bonheur (0 à 100), lit, raisons de mécontentement.
var food := 80.0
var happiness := 60.0
var has_bed := true
var work_mult := 1.0
var unhappy_time := 0.0
var mood_reasons: Array = []
## Vie quotidienne : lit attribué (VillageNeeds), activité du moment, bulle au-dessus de la tête.
var bed_spot := Vector3.INF
## Sens du lit (de la tête vers les pieds) : on s'y allonge dans sa longueur.
var bed_dir := Vector3.ZERO
## « lit » (maison, dortoir), « cabane » (cabane du village) ou « » (par terre, près du feu).
var bed_kind := ""
## « travail », « repas », « détente », « sommeil » ou « ronde » (gardes, la nuit).
var activity := "travail"
var _act_spot := Vector3.INF
var _act_stuck := 0.0
## Temps de marche vers le lieu de l'activité (au-delà de 9 s, on y arrive quand même).
var _act_walk := 0.0
var _act_anim := 0.0
var _sleeping := false
var _patrol_i := 0
var _bubble: Label3D
## Quêtes : nombre réussies pour lui (ami à 3), marque au-dessus de la tête (« ! », « … », « ? »).
var friendship := 0
var _mark: Label3D
var _bubble_left := 0.0
const ACTIVITY_NAMES := {"travail": "", "repas": "mange", "détente": "se détend", "sommeil": "dort", "ronde": "fait sa ronde", "abri": "s'abrite"}
## Pièces où l'on s'abrite de la pluie.
const SHELTER_ROOMS := ["taverne", "maison", "dortoir", "temple", "bibliotheque", "marche", "caserne"]
var _in_hut := false
const JOB_NAMES := {"forgeron": "Forgeron", "boulanger": "Boulanger", "garde": "Garde", "fermier": "Fermier",
	"bucheron": "Bûcheron", "macon": "Maçon", "verrier": "Verrier", "aubergiste": "Aubergiste", "marchand": "Marchand",
	"erudit": "Érudit", "pretre": "Prêtre", "mage": "Mage", "tisserand": "Tisserand",
	"alchimiste": "Alchimiste", "enchanteur": "Enchanteur", "dresseur": "Dresseur", "architecte": "Architecte",
	"chasseur": "Chasseur", "pecheur": "Pêcheur", "mineur": "Mineur", "cuisinier": "Cuisinier", "joaillier": "Joaillier"}
const JOBS := ["forgeron", "boulanger", "garde", "fermier", "bucheron", "macon", "verrier", "aubergiste",
	"marchand", "erudit", "pretre", "mage", "tisserand", "alchimiste", "enchanteur", "dresseur", "architecte",
	"chasseur", "pecheur", "mineur", "cuisinier", "joaillier"]
## Classes de combat possibles (fichiers de data/classes/), comme celles du héros : chaque habitant en a une,
## qui décide de sa tenue de départ et lui donne un petit bonus.
const CLASS_IDS := ["guerrier", "barbare", "paladin", "mage", "rodeur", "assassin", "moine", "necromancien",
	"druide", "chevalier", "barde", "clerc", "cryomancien"]
## Classes les plus probables selon le métier (sinon, au hasard).
const JOB_CLASSES := {"garde": ["guerrier", "chevalier", "paladin", "barbare"], "mage": ["mage", "cryomancien", "necromancien"],
	"pretre": ["clerc", "paladin", "moine"], "erudit": ["mage", "barde", "moine"], "enchanteur": ["mage", "necromancien", "cryomancien"],
	"alchimiste": ["druide", "necromancien", "mage"], "fermier": ["druide", "moine", "guerrier"], "chasseur": ["rodeur", "assassin", "barbare"],
	"pecheur": ["rodeur", "moine"], "bucheron": ["barbare", "rodeur"], "forgeron": ["guerrier", "barbare", "chevalier"],
	"mineur": ["barbare", "guerrier"], "macon": ["guerrier", "barbare"], "marchand": ["barde", "assassin", "rodeur"],
	"aubergiste": ["barde", "guerrier"], "dresseur": ["druide", "rodeur"], "tisserand": ["barde", "assassin"],
	"joaillier": ["assassin", "barde"], "cuisinier": ["moine", "guerrier"], "architecte": ["chevalier", "clerc"], "verrier": ["mage", "barde"]}
## Classe de combat de l'habitant (identifiant, voir CLASS_IDS).
var fight_class := ""


func _ready() -> void:
	super()
	add_to_group("strangers" if stranger else "villagers")
	# deux talents personnels au hasard (un voyageur a déjà les siens)
	if talents.is_empty():
		var pool := JOBS.duplicate()
		pool.shuffle()
		talents[pool[0]] = randf_range(0.2, 0.4)
		talents[pool[1]] = randf_range(0.1, 0.25)
	if fight_class.is_empty():
		fight_class = pick_class(best_job())
	if villager_name.is_empty():
		villager_name = NAMES.pick_random()
	home = global_position
	_target = home
	_pause = randf_range(0.0, max_pause)
	facing = Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
	set_race(race)
	if evo > 0:
		apply_evolution()
	_bubble = Label3D.new()
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.font_size = 56
	_bubble.pixel_size = 0.008
	_bubble.outline_size = 10
	_bubble.position.y = 2.6
	_bubble.visible = false
	add_child(_bubble)
	_mark = Label3D.new()
	_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_mark.font_size = 96
	_mark.pixel_size = 0.009
	_mark.outline_size = 14
	_mark.position.y = 3.15
	_mark.visible = false
	add_child(_mark)


func set_race(new_race: RaceData) -> void:
	race = new_race
	var vis := get_node_or_null("Visual") as VoxelCharacter
	if race == null or vis == null:
		return
	vis.set_equipment_library(race.equipment)
	var m := _model_scene()
	if m:
		vis.set_model(m)
	_apply_level(true)


## Le modèle de sa race (sa variante de couleur), ou de son évolution s'il existe (<race>_base_evoN.glb),
## sinon la tenue de son métier s'il travaille (<race>_<métier>.glb). Un personnage de l'histoire garde
## toujours son modèle à lui (StoryData.npc_model).
func _model_scene() -> PackedScene:
	if race == null:
		return null
	if has_meta("story"):
		var sm := StoryData.npc_model(str(get_meta("story")), race.resource_path)
		if sm:
			return sm
	if race.villager_models.is_empty():
		return race.model
	if model_variant < 0 or model_variant >= race.villager_models.size():
		model_variant = randi() % race.villager_models.size()
	var base: PackedScene = race.villager_models[model_variant]
	if evo_model > 0 and base:
		var path := base.resource_path.get_basename() + "_evo%d.glb" % evo_model
		if ResourceLoader.exists(path):
			return load(path)
	var job := work_job()
	if job != "":
		var jm := race.job_model(job, model_variant)
		if jm:
			return jm
	return base


## Métier de la pièce où il travaille (« » : aucun).
func work_job() -> String:
	if work_room == null or not (work_room is Dictionary) or not work_room.has("type"):
		return ""
	var t := work_room.type as RoomTypeData
	return t.job_id if t else ""


func _refresh_model() -> void:
	var vis := get_node_or_null("Visual") as VoxelCharacter
	if vis == null or race == null:
		return
	var m := _model_scene()
	if m and m != vis.model:
		vis.set_model(m)


## Vie selon la race et le niveau.
func _apply_level(refill := false) -> void:
	var hp := get_node_or_null("Health") as Health
	if hp and race:
		var c := _class()
		hp.set_max(roundi(race.max_health * _level_mult()) + (c.bonus_health if c else 0), refill)


## Classe de combat (chargée une fois), ou null.
var _cls: ClassData
var _cls_id := ""
func _class() -> ClassData:
	if _cls_id != fight_class:
		_cls_id = fight_class
		_cls = class_data(fight_class)
	return _cls


func _level_mult() -> float:
	return (1.0 + 0.1 * (level - 1)) * Evolution.POWER[clampi(evo, 0, 2)]


## Taille et éclat selon l'évolution ; `fx` : effet de transformation.
func apply_evolution(fx := false) -> void:
	var vis := get_node_or_null("Visual") as VoxelCharacter
	if vis:
		var m := _model_scene()
		if m and m != vis.model:
			vis.set_model(m)
		vis.scale = Vector3.ONE * Evolution.SCALE[clampi(evo, 0, 2)]
	_apply_level(true)
	if fx and is_inside_tree():
		VoxelBurst.spawn(self, global_position + Vector3(0, 1, 0), Color("c8a8ff"), 60, 5.0, 0.12, 1.2, "up", 2.0, false)
		SkillFX.ring(self, global_position, 3.5, Color("c8a8ff"), 0.7)
		Sound.play("cast", global_position + Vector3(0, 1, 0))


## Nom de sa race, ou de son évolution.
func race_title() -> String:
	if evo_title != "":
		return evo_title
	return race.display_name if race else "?"


func set_level(lv: int) -> void:
	if lv == level:
		return
	level = maxi(1, lv)
	_apply_level(false)


func base_attack() -> int:
	var c := _class()
	return roundi((race.strength if race else 10) * _level_mult() * (1.0 + guard_bonus + (0.4 if _rage_left > 0.0 else 0.0))) + (c.bonus_attack if c else 0)


func base_magic() -> int:
	var c := _class()
	return maxi(0, roundi((race.magic if race else 10) * _level_mult()) + (c.bonus_magic if c else 0))


func base_defense() -> int:
	var c := _class()
	return c.bonus_defense if c else 0


## Une classe pour un habitant doué pour `job` : souvent une classe qui va avec son métier, parfois n'importe laquelle.
static func pick_class(job: String, rng: RandomNumberGenerator = null) -> String:
	var r := rng.randf() if rng else randf()
	var pool: Array = JOB_CLASSES.get(job, []) if r < 0.7 else []
	if pool.is_empty():
		pool = CLASS_IDS
	return pool[(rng.randi() if rng else randi()) % pool.size()]


static func class_data(id: String) -> ClassData:
	var path := "res://data/classes/%s.tres" % id
	return load(path) as ClassData if id != "" and ResourceLoader.exists(path) else null


## Identifiants des objets de la tenue de départ d'une classe.
static func class_kit(id: String) -> Array:
	var out := []
	var c := class_data(id)
	if c:
		for it in c.starting_equipment:
			if it:
				out.append(it.id)
	return out


func class_name_fr() -> String:
	var c := class_data(fight_class)
	return c.display_name if c else ""


## Métier où il est le plus doué (son talent le plus fort).
func best_job() -> String:
	var best := ""
	var bv := -1.0
	for j in talents:
		if float(talents[j]) > bv:
			bv = float(talents[j])
			best = j
	return best


## Le voyageur rejoint le village : il y part tout de suite et devient un habitant.
func join_village(village_center: Vector3) -> void:
	stranger = false
	recruit_offer = {}
	remove_from_group("strangers")
	add_to_group("villagers")
	var world := get_tree().get_first_node_in_group("world") as WorldGenerator
	var dest := village_center + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
	if world:
		dest.y = world.ground_height_at(Vector3(dest.x, village_center.y + 1.0, dest.z))
		var holder := world.get_node("Village")
		if get_parent() != holder:
			reparent(holder)
	global_position = dest
	home = dest
	_target = dest
	_threat = null
	_path.clear()


## Passe en compagnon d'expédition (ou revient au village).
func set_companion(on: bool) -> void:
	companion = on
	_threat = null
	_path.clear()
	if on:
		work_room = null
	else:
		var world := get_tree().get_first_node_in_group("world") as WorldGenerator
		if world:
			var v := world.home_center()
			home = v + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
			_target = home


## Place les compagnons autour d'une position (voyage rapide, donjons, réveil au village).
static func bring_companions(tree: SceneTree, pos: Vector3) -> void:
	var i := 0
	for v in tree.get_nodes_in_group("villagers"):
		if v.get("companion"):
			var a := PI * 0.75 + i * PI * 0.5
			v.global_position = pos + Vector3(cos(a), 0, sin(a)) * 1.6
			v.set("_threat", null)
			i += 1


func companions_count(tree: SceneTree) -> int:
	return tree.get_nodes_in_group("villagers").filter(func(v): return v.get("companion")).size()


func can_be_targeted() -> bool:
	return is_alive() and _ko_left <= 0.0


# ---------------------------------------------------------------- colère (le héros l'a frappé)

## Un habitant frappé par le héros se fâche : il passe dans le camp adverse et se bat contre lui avec ses
## armes et ses compétences de classe (à mains nues s'il n'a pas d'arme). Il se calme au bout de ANGER_TIME s
## sans être frappé, quand le héros s'éloigne ou tombe, ou après avoir été mis K.O. (il ne meurt jamais).
const ANGER_TIME := 40.0
var angry_left := 0.0


func provoke(by: Combatant) -> void:
	if not is_alive() or by == null:
		return
	if angry_left <= 0.0:
		_set_hostile(true)
		_show_bubble("!", Color("ff5a4a"), 2.5)
	angry_left = ANGER_TIME
	_threat = by
	_fetch = null
	if _sleeping:
		_wake()


func is_angry() -> bool:
	return angry_left > 0.0


func calm_down() -> void:
	if angry_left <= 0.0 and team == Team.ALLIES:
		return
	angry_left = 0.0
	_set_hostile(false)
	_threat = null


func _set_hostile(on: bool) -> void:
	remove_from_group("allies" if on else "enemies")
	add_to_group("enemies" if on else "allies")
	team = Team.ENEMIES if on else Team.ALLIES


func _on_died() -> void:
	super()
	_ko_left = knockout_time
	_fetch = null
	_threat = null


func _on_hurt(_amount: int, source: Node) -> void:
	# frappé par le héros : il se fâche (et riposte, même sans arme)
	if source is Player:
		provoke(source)
		return
	# riposte si on a une arme
	if source is Combatant and weapon() != null:
		_threat = source


## Loin du héros (plus de 60 m) et sans danger, l'habitant ne se calcule qu'un pas de physique sur 3.
var _lod_far := false
var _lod_acc := 0.0
var _lod_check := randf() * 0.5
var _lod_phase := randi() % 3


func _physics_process(delta: float) -> void:
	_lod_check -= delta
	if _lod_check <= 0.0:
		_lod_check = 0.5
		var pl := get_tree().get_first_node_in_group("player") as Node3D
		_lod_far = pl != null and not companion and _threat == null and is_alive() \
				and pl.global_position.distance_squared_to(global_position) > 60.0 * 60.0
	if _lod_far:
		_lod_acc += delta
		if Engine.get_physics_frames() % 3 != _lod_phase:
			return
		delta = _lod_acc
		_lod_acc = 0.0
	elif _lod_acc > 0.0:
		_lod_acc = 0.0
	_combat_step(delta)
	if not is_alive():
		_ko_left -= delta
		velocity = Vector3.ZERO
		_move_on_ground(delta)
		visual.animate(delta, Vector3.ZERO, facing)
		label.visible = false
		if _ko_left <= 0.0:
			health.revive(0.5)
			visual.set_downed(false)
			_invulnerable_left = 2.0
			# mis K.O., il se calme
			calm_down()
		return
	if angry_left > 0.0:
		angry_left -= delta
		var hero := get_tree().get_first_node_in_group("player") as Combatant
		if angry_left <= 0.0 or hero == null or not hero.is_alive() or hero.global_position.distance_to(global_position) > 30.0:
			calm_down()
		else:
			_threat = hero
	_threat_timer -= delta
	if _threat_timer <= 0.0:
		_threat_timer = 0.4
		_update_threat()
	if _threat:
		if _sleeping:
			_wake()
		_fight_or_flee(delta)
		return
	if companion and _follow_step(delta):
		_update_label()
		return
	# vie quotidienne : repas, détente, sommeil (et rondes des gardes la nuit)
	var act := routine_activity()
	if act != activity:
		_start_activity(act)
	if act != "travail" and _routine_step(delta):
		_update_label()
		return
	if _sleeping:
		_wake()
	if work_room != null and _work_step(delta):
		_update_label()
		return
	if work_room == null and not stranger and _build_step(delta):
		_update_label()
		return
	_at_work = false
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = 1.5
		_look_for_loot()
	var speed := walk_speed * (race.speed_multiplier if race else 1.0) * equipment.speed_multiplier()
	if _fetch and (not is_instance_valid(_fetch) or _fetch.is_taken()):
		_fetch = null
		_pause = randf_range(min_pause, max_pause)
	if _fetch:
		_target = _fetch.global_position
		_pause = 0.0
		speed *= 1.6
	if _pause > 0.0:
		_pause -= delta
		velocity = Vector3.ZERO
		if _pause <= 0.0:
			var off := Vector2.from_angle(randf() * TAU) * randf_range(0.7, wander_radius)
			_target = home + Vector3(off.x, 0, off.y)
	else:
		var to_target := _target - global_position
		to_target.y = 0.0
		if to_target.length() < 0.15:
			_pause = randf_range(min_pause, max_pause)
			velocity = Vector3.ZERO
		else:
			facing = to_target.normalized()
			velocity = facing * speed
	var before := global_position
	_move_on_ground(delta)
	# bloqué contre un obstacle : on s'arrête et on repart ailleurs
	if _pause <= 0.0 and velocity.length() > 0.0 and Vector2(global_position.x - before.x, global_position.z - before.z).length() < 0.005:
		_pause = randf_range(min_pause, max_pause)
		_fetch = null
	visual.animate(delta, velocity, facing)
	_update_label()


# ---------------------------------------------------------------- vie quotidienne

## Activité selon l'heure : travail 6 h - 12 h et 13 h - 18 h, repas 12 h - 13 h, détente 18 h - 21 h,
## sommeil 21 h - 6 h (les gardes font leur ronde).
func routine_activity() -> String:
	var dc := get_tree().get_first_node_in_group("day_cycle")
	if dc == null or stranger or companion:
		return "travail"
	var h: float = dc.hour
	if h >= 21.0 or h < 6.0:
		return "ronde" if is_guard() else "sommeil"
	if h >= 12.0 and h < 13.0:
		return "repas"
	# pluie : on se détend à l'abri ; orage : ceux qui travaillent dehors rentrent aussi
	var w := get_tree().get_first_node_in_group("weather") as Weather
	if w and w.is_wet() and not is_guard():
		if h >= 18.0:
			return "abri"
		if w.is_storm() and (work_room == null or work_room.get("fields", false)):
			return "abri"
	if h >= 18.0:
		return "détente"
	return "travail"


func is_guard() -> bool:
	return work_room != null and work_room.type != null and (work_room.type as RoomTypeData).job_id == "garde"


func _start_activity(act: String) -> void:
	activity = act
	if _bubble:
		_bubble.visible = false
	_act_spot = _pick_spot(act)
	_act_stuck = 0.0
	_act_walk = 0.0
	_path.clear()
	_repath = 0.0
	if act != "sommeil" and _sleeping:
		_wake()
	if _in_hut:
		_in_hut = false
		visual.visible = true


## Où aller pour cette activité.
func _pick_spot(act: String) -> Vector3:
	if _world == null:
		_world = get_tree().get_first_node_in_group("world") as WorldGenerator
		if _world == null:
			return Vector3.INF
	var center := _world.hearth_center()
	var seed := float(hash(villager_name) % 1000) / 1000.0
	match act:
		"sommeil":
			if bed_spot != Vector3.INF:
				return bed_spot
			# pas de lit : par terre, près du feu
			var a := seed * TAU
			return _ground(center + Vector3(cos(a), 0, sin(a)) * 3.0)
		"repas":
			var r := _room_spot(["taverne"])
			if r != Vector3.INF:
				return r
			var a := seed * TAU
			return _ground(center + Vector3(cos(a), 0, sin(a)) * 2.3)
		"détente":
			var r := _room_spot(["taverne", "temple", "marche", "bibliotheque"])
			if r != Vector3.INF and randf() < 0.7:
				return r
			var a := randf() * TAU
			return _ground(center + Vector3(cos(a), 0, sin(a)) * randf_range(2.5, 4.5))
		"ronde":
			return center
		"abri":
			var r := _room_spot(SHELTER_ROOMS)
			if r != Vector3.INF:
				return r
			if bed_spot != Vector3.INF:
				return bed_spot
			# nulle part où aller : près du feu, sous la pluie
			var a := seed * TAU
			return _ground(center + Vector3(cos(a), 0, sin(a)) * 2.5)
	return Vector3.INF


## À l'abri : endormi, dans une pièce (au travail ou abrité), ou rentré dans sa cabane.
func is_sheltered() -> bool:
	if _sleeping or _in_hut or stranger or companion:
		return true
	var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
	if k == null or _world == null:
		return false
	return k.room_at(_world.cell_at(global_position), global_position.y) != null


func _ground(p: Vector3) -> Vector3:
	p.y = _world.ground_height_at(p + Vector3(0, 3, 0))
	return p


## Une case libre d'une pièce du royaume de l'un de ces types (INF s'il n'y en a pas).
func _room_spot(types: Array) -> Vector3:
	var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
	if k == null:
		return Vector3.INF
	var rooms := k.typed_rooms().filter(func(r): return (r.type as RoomTypeData).id in types)
	if rooms.is_empty():
		return Vector3.INF
	var r: Dictionary = rooms[randi() % rooms.size()]
	var cells: Array = r.cells.keys()
	for i in 6:
		var c: Vector2i = cells[randi() % cells.size()]
		if _world.build.furniture_in(c).is_empty():
			return Vector3(c.x + 0.5, float(r.floor), c.y + 0.5)
	return Vector3.INF


## Va vers le lieu de l'activité, puis la fait (mange, se détend, dort). Faux si impossible.
func _routine_step(delta: float) -> bool:
	if _act_spot == Vector3.INF:
		return false
	var dest := _act_spot
	if activity == "ronde":
		var center := _act_spot
		var a := TAU * float(_patrol_i % 4) / 4.0 + 0.4
		dest = _ground(center + Vector3(cos(a), 0, sin(a)) * 9.0)
	var to := dest - global_position
	to.y = 0.0
	# un lit (meuble plein) : on s'arrête à côté, puis on s'y couche
	var reach := 1.3 if activity == "sommeil" and bed_kind == "lit" else (1.6 if (activity == "sommeil" or activity == "abri") and bed_kind == "cabane" and _act_spot == bed_spot else 0.45)
	if _sleeping:
		velocity = Vector3.ZERO
		_bubble_tick(delta, "Zzz", Color("b8c8ff"))
		visual.animate(delta, Vector3.ZERO, facing)
		return true
	if to.length() > reach:
		if activity == "ronde" and to.length() < 1.0:
			_patrol_i += 1
		var before := global_position
		_path_move(dest, delta, walk_speed * 1.25 * (race.speed_multiplier if race else 1.0))
		_act_walk += delta
		if global_position.distance_to(before) < walk_speed * delta * 0.2:
			_act_stuck += delta
		else:
			_act_stuck = 0.0
		# coincé contre un mur ou trop long : il y arrive quand même (les habitants connaissent les raccourcis)
		if _act_stuck > 3.0 or (_act_walk > 9.0 and activity != "ronde"):
			global_position = dest
			_act_stuck = 0.0
			_act_walk = 0.0
		elif activity == "ronde" and _act_walk > 9.0:
			_patrol_i += 1
			_act_walk = 0.0
		return true
	if activity == "ronde":
		_patrol_i += 1
		_bubble.visible = false
		return true
	velocity = Vector3.ZERO
	match activity:
		"sommeil":
			# couché sur le lit : on ne retombe pas au sol dans la même image
			_sleep()
			visual.animate(delta, Vector3.ZERO, facing)
			return true
		"repas":
			_face_center()
			_act_anim -= delta
			if _act_anim <= 0.0:
				_act_anim = randf_range(2.0, 3.5)
				visual.play_move("punch_1", 0.45)
				_show_bubble("♨", Color("f0c080"), 1.2)
		"détente":
			_face_center()
			_act_anim -= delta
			if _act_anim <= 0.0:
				_act_anim = randf_range(3.0, 6.0)
				_show_bubble(["♪", "♫", "…", "!"][randi() % 4], Color("fff0a0"), 1.5)
		"abri":
			# sa place dans une cabane : il rentre à l'intérieur
			if bed_kind == "cabane" and _act_spot == bed_spot and not _in_hut:
				_in_hut = true
				visual.visible = false
	_move_on_ground(delta)
	visual.animate(delta, velocity, facing)
	_bubble_tick(delta, "", Color.WHITE)
	return true


func _face_center() -> void:
	var center := _world.hearth_center()
	var d := center - global_position
	d.y = 0.0
	if d.length() > 0.1:
		facing = d.normalized()


## S'endort : dans une cabane on disparaît à l'intérieur, sur un lit on s'allonge, sinon par terre.
func _sleep() -> void:
	_sleeping = true
	_at_work = false
	if bed_kind == "cabane":
		visual.visible = false
	else:
		if bed_kind == "lit":
			global_position = bed_spot
			if bed_dir != Vector3.ZERO:
				facing = bed_dir
		visual.set_downed(true)
	_show_bubble("Zzz", Color("b8c8ff"), 999.0)
	if _mark:
		_mark.position.y = 1.4 if bed_kind != "cabane" else 3.15


func _wake() -> void:
	_sleeping = false
	if _mark:
		_mark.position.y = 3.15
	visual.visible = true
	visual.set_downed(false)
	_bubble.visible = false
	if bed_kind == "lit" and _world:
		# on se relève à côté du lit
		global_position = _world.constrain_move(global_position, global_position + Vector3(0.9, 0, 0))


## Marque de quête au-dessus de la tête : « ! » (à prendre), « … » (en cours), « ? » (à rendre), « » (rien).
func set_quest_mark(mark: String) -> void:
	if _mark == null:
		return
	_mark.text = mark
	_mark.visible = mark != ""
	_mark.modulate = Color("f2c86a") if mark == "!" else (Color("8ad66a") if mark == "?" else Color(0.8, 0.8, 0.8, 0.8))


func is_sleeping() -> bool:
	return _sleeping


## Taille des bulles au-dessus des têtes : plus petites quand la caméra est proche (3e et 1re personne).
static var label_scale := 1.0


func _show_bubble(text: String, col: Color, seconds: float) -> void:
	_bubble.pixel_size = 0.008 * label_scale
	_mark.pixel_size = 0.009 * label_scale
	_bubble.text = text
	_bubble.modulate = col
	_bubble.visible = true
	_bubble_left = seconds


func _bubble_tick(delta: float, _text: String, _col: Color) -> void:
	if _bubble_left > 0.0 and _bubble_left < 900.0:
		_bubble_left -= delta
		if _bubble_left <= 0.0:
			_bubble.visible = false
	if _bubble.visible:
		_bubble.position.y = 2.6 + sin(Time.get_ticks_msec() * 0.003) * 0.06


## Vrai quand l'habitant est à son poste (la pièce produit).
func is_at_work() -> bool:
	return work_room != null and _at_work


## Va à son poste de travail (en passant par la porte) et y travaille. Renvoie faux s'il ne peut pas.
func _work_step(delta: float) -> bool:
	if work_room.get("fields", false):
		return _farm_step(delta)
	if _work_for != work_room:
		_work_for = work_room
		_choose_work_spot()
		_path.clear()
	if _work_spot == Vector3.INF:
		return false
	var to := _work_spot - global_position
	to.y = 0.0
	var speed := walk_speed * 1.3 * (race.speed_multiplier if race else 1.0)
	if to.length() < 0.3:
		_at_work = true
		velocity = Vector3.ZERO
		facing = _work_face
		_work_anim -= delta
		if _work_anim <= 0.0:
			_work_anim = randf_range(1.6, 2.8)
			var t: RoomTypeData = work_room.type
			var move := "heavy_1" if t.job_id in ["forgeron", "bucheron", "macon"] else ("cast_1" if t.job_id in ["mage", "pretre", "erudit"] else "punch_1")
			visual.play_move(move, 0.7)
			if t.job_id == "forgeron":
				VoxelBurst.spawn(self, global_position + _work_face * 0.8 + Vector3(0, 0.9, 0), Color(1.0, 0.7, 0.3), 8, 2.5, 0.05, 0.4)
		_move_on_ground(delta)
		visual.animate(delta, velocity, facing)
		return true
	_at_work = false
	_repath -= delta
	if _path.is_empty() and _repath <= 0.0:
		_repath = 1.5
		_path = _world.find_path(global_position, _work_spot) if _world else []
	var goal := _work_spot
	if not _path.is_empty():
		goal = _path[0]
		if Vector2(goal.x - global_position.x, goal.z - global_position.z).length() < 0.25:
			_path.pop_front()
			if not _path.is_empty():
				goal = _path[0]
	var dir := goal - global_position
	dir.y = 0.0
	if dir.length() > 0.01:
		facing = dir.normalized()
	velocity = facing * speed
	var before := global_position
	_move_on_ground(delta)
	# coincé (un autre habitant, un objet) : on recalcule le chemin
	if Vector2(global_position.x - before.x, global_position.z - before.z).length() < speed * delta * 0.2:
		_stuck += delta
		if _stuck > 0.6:
			_stuck = 0.0
			_path.clear()
			_repath = 0.0
			if _world:
				global_position = _world.constrain_move(global_position, global_position + Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2)))
	else:
		_stuck = 0.0
	visual.animate(delta, velocity, facing)
	return true


var _farm_task := {}
var _farm_timer := 0.0
var _farm_work := 0.0


## Fermier : récolte les cultures mûres et sème les cases vides (avec les graines confiées au village).
func _farm_step(delta: float) -> bool:
	var fm := get_tree().get_first_node_in_group("farming") as Farming
	if fm == null or not fm.has_fields():
		return false
	if _world == null:
		_world = get_tree().get_first_node_in_group("world") as WorldGenerator
		if _world == null:
			return false
	if not _farm_task.is_empty() and not fm.plots.has(_farm_task.cell):
		_farm_task = {}
	if _farm_task.is_empty():
		_farm_timer -= delta
		if _farm_timer <= 0.0:
			_farm_timer = 1.0
			_farm_task = fm.claim_task(self)
			_path.clear()
			_repath = 0.0
			_stuck = 0.0
			_farm_work = 0.0
	var speed := walk_speed * 1.8 * (race.speed_multiplier if race else 1.0)
	if _farm_task.is_empty():
		# rien à faire : il attend au bord du champ
		var c := fm.fields_center()
		if Vector2(c.x - global_position.x, c.z - global_position.z).length() > 4.0:
			_at_work = false
			_path_move(c, delta, speed)
			return true
		_at_work = true
		velocity = Vector3.ZERO
		_move_on_ground(delta)
		visual.animate(delta, velocity, facing)
		return true
	var cell: Vector2i = _farm_task.cell
	var dest := _world.cell_center(cell)
	var to := dest - global_position
	to.y = 0.0
	if to.length() < 0.55:
		_at_work = true
		velocity = Vector3.ZERO
		if to.length() > 0.05:
			facing = to.normalized()
		_farm_work += delta * Kingdom.affinity(self, "fermier")
		_work_anim -= delta
		if _work_anim <= 0.0:
			_work_anim = 0.9
			visual.play_move("punch_1", 0.8)
		if _farm_work >= 1.6:
			fm.do_task(self, _farm_task)
			_farm_task = {}
			_farm_timer = 0.3
		_move_on_ground(delta)
		visual.animate(delta, velocity, facing)
		return true
	_at_work = false
	var before := global_position
	_path_move(dest, delta, speed)
	if before.distance_to(global_position) < speed * delta * 0.2:
		_stuck += delta
		if _stuck > 4.0:
			# impossible d'y arriver : il laisse cette case à un autre
			fm.release(cell)
			_farm_task = {}
			_farm_timer = 2.0
			_stuck = 0.0
	else:
		_stuck = 0.0
	return true


## Bâtisseur : prend le plan le plus utile, va à côté et le réalise. Faux s'il n'a rien à faire.
func _build_step(delta: float) -> bool:
	var bo := get_tree().get_first_node_in_group("build_orders") as BuildOrders
	if bo == null or bo.orders.is_empty():
		_order = null
		return false
	if _world == null:
		_world = get_tree().get_first_node_in_group("world") as WorldGenerator
		if _world == null:
			return false
	if _order != null and (not bo.orders.has(_order.id) or _order.builder != self):
		_order = null
	if _order == null:
		_order_timer -= delta
		if _order_timer > 0.0:
			return false
		_order_timer = 0.7
		_order = bo.claim(self)
		if _order == null:
			return false
		_order_spot = _stand_spot(bo, _order)
		_path.clear()
		_repath = 0.0
		_order_stuck = 0.0
		if _order_spot == Vector3.INF:
			bo.release(_order, 15.0)
			_order = null
			return false
	var target := bo.order_position(_order)
	var to := _order_spot - global_position
	to.y = 0.0
	# presque arrivé mais bousculé (autre habitant, coin de mur) : on travaille d'ici
	if to.length() < 0.35 or (to.length() < 1.2 and _order_stuck > 0.5):
		velocity = Vector3.ZERO
		var look := target - global_position
		look.y = 0.0
		if look.length() > 0.05:
			facing = look.normalized()
		if not bo.ready_to_build(_order):
			bo.release(_order, 4.0)
			_order = null
			return true
		_work_anim -= delta
		if _work_anim <= 0.0:
			_work_anim = 0.8
			visual.play_move("heavy_1" if _order.type != "furniture" else "punch_1", 1.3)
			VoxelBurst.spawn(self, target + Vector3(0, 0.6, 0), Color(0.85, 0.75, 0.6), 6, 1.8, 0.06, 0.35, "up", 6.0, false)
		if bo.work(_order, delta * Kingdom.affinity(self, "macon")):
			_order = null
			_order_timer = 0.0
		_move_on_ground(delta)
		visual.animate(delta, velocity, facing)
		return true
	# en route vers le chantier
	var speed := walk_speed * 2.2 * (race.speed_multiplier if race else 1.0)
	var before := global_position
	_path_move(_order_spot, delta, speed)
	if before.distance_to(global_position) < speed * delta * 0.2:
		_order_stuck += delta
		if _order_stuck > 3.0:
			# impossible d'y arriver : on laisse ce plan de côté un moment
			bo.release(_order, 8.0)
			_order = null
	else:
		_order_stuck = 0.0
	return true


## Case d'où travailler sur un plan : libre, praticable, à portée de main.
func _stand_spot(bo: BuildOrders, o: Dictionary) -> Vector3:
	var target := bo.order_position(o)
	var cell: Vector2i = o.cell
	var best := Vector3.INF
	var best_d := INF
	# un décor du village (cabane...) est large : on se place autour, hors de son emprise
	var is_prop: bool = o.type == "remove" and o.get("what") == "prop"
	var props := {}
	# cases déjà prises par les autres habitants au travail
	var taken := {}
	for v in get_tree().get_nodes_in_group("villagers"):
		if v != self and v._order != null and v._order_spot != Vector3.INF:
			taken[Vector2i(floori(v._order_spot.x), floori(v._order_spot.z))] = true
	for r in ([2, 3, 4] if is_prop else [1, 2]):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var n := cell + Vector2i(dx, dz)
				var c := Vector3(n.x + 0.5, 0, n.y + 0.5)
				var h := _world.ground_height_at(Vector3(c.x, _world.terrain_height(n) + 0.1, c.z))
				c.y = h
				if not _world.is_walkable(c) or _world.build.body_blocked(n, h):
					continue
				if is_prop and _world._prop_blocked(n, h, props):
					continue
				if taken.has(n):
					continue
				if not bo.order_at_cell(n).filter(func(q): return q.type == "block" and absf(q.key.y - h) < 1.5).is_empty():
					continue
				if target.y - h > 6.0 or h - target.y > 3.0:
					continue
				var d := c.distance_to(global_position)
				if d < best_d:
					best_d = d
					best = c
		if best != Vector3.INF:
			return best
	return best


## Avance vers `dest` en suivant un chemin (portes, obstacles).
func _path_move(dest: Vector3, delta: float, speed: float) -> void:
	_repath -= delta
	if _path.is_empty() and _repath <= 0.0:
		_repath = 1.5
		_path = _world.find_path(global_position, dest) if _world else []
	var goal := dest
	if not _path.is_empty():
		goal = _path[0]
		if Vector2(goal.x - global_position.x, goal.z - global_position.z).length() < 0.25:
			_path.pop_front()
			if not _path.is_empty():
				goal = _path[0]
	var dir := goal - global_position
	dir.y = 0.0
	if dir.length() > 0.01:
		facing = dir.normalized()
	velocity = facing * speed
	_move_on_ground(delta)
	visual.animate(delta, velocity, facing)


func _choose_work_spot() -> void:
	_work_spot = Vector3.INF
	if work_room == null or _world == null:
		_world = get_tree().get_first_node_in_group("world") as WorldGenerator
		if work_room == null or _world == null:
			return
	var t: RoomTypeData = work_room.type
	var grid := _world.build
	var cells: Dictionary = work_room.cells
	var floor_y: float = work_room.floor
	var taken := []
	for v in get_tree().get_nodes_in_group("villagers"):
		if v != self and v.get("work_room") == work_room and v.get("_work_spot") != Vector3.INF:
			taken.append(_world.cell_at(v.get("_work_spot")))
	var dirs := [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	for c in cells:
		for f in grid.furniture_in(c):
			if not t.required.has(f.item.id):
				continue
			for d in dirs:
				var n: Vector2i = c + d
				if not cells.has(n) or taken.has(n) or grid.body_blocked(n, floor_y):
					continue
				_work_spot = Vector3(n.x + 0.5, floor_y, n.y + 0.5)
				_work_face = Vector3(-d.x, 0, -d.y)
				return
	# à défaut : n'importe quelle case libre de la pièce
	for c in cells:
		if not grid.body_blocked(c, floor_y) and not taken.has(c):
			_work_spot = Vector3(c.x + 0.5, floor_y, c.y + 0.5)
			return


## Choisit le monstre à combattre (ou à fuir).
func _update_threat() -> void:
	if angry_left > 0.0:
		return
	# un compagnon défend le héros, un habitant défend sa maison
	var center := home
	var radius := defend_radius
	if companion:
		var hero := get_tree().get_first_node_in_group("player") as Node3D
		if hero:
			center = hero.global_position
			radius = 14.0
	if _threat and (not is_instance_valid(_threat) or not _threat.is_alive() \
			or _threat.global_position.distance_to(center) > radius + 4.0):
		_threat = null
	if _threat == null:
		var t := nearest_hostile(alert_radius + (4.0 if companion else 0.0))
		# un voisin fâché contre le héros n'est pas un monstre : on ne s'en mêle pas
		if t is Villager and (t as Villager).is_angry():
			t = null
		if t and t.global_position.distance_to(center) <= radius:
			_threat = t
			_fetch = null


## Compagnon : suit le héros (derrière lui) et le rejoint s'il est trop loin.
func _follow_step(delta: float) -> bool:
	var hero := get_tree().get_first_node_in_group("player") as Player
	if hero == null or not hero.is_alive():
		return false
	set_level(maxi(level, hero.power_level() - 1))
	var idx := 0
	for v in get_tree().get_nodes_in_group("villagers"):
		if v == self:
			break
		if v.get("companion"):
			idx += 1
	var back := -Vector3(hero.facing.x, 0, hero.facing.z).normalized()
	if back == Vector3.ZERO:
		back = Vector3.BACK
	var side := back.cross(Vector3.UP) * (1.3 if idx % 2 == 0 else -1.3)
	var spot := hero.global_position + back * 1.8 + side
	var to := spot - global_position
	to.y = 0.0
	var dist := to.length()
	# trop loin (téléportation, chute...) : il rejoint le héros
	if dist > 28.0 or absf(hero.global_position.y - global_position.y) > 6.0:
		global_position = spot
		return true
	var speed := walk_speed * (2.8 if dist > 4.0 else 1.6) * (race.speed_multiplier if race else 1.0)
	if dist > 0.6:
		facing = to / dist
		velocity = facing * speed
	else:
		velocity = Vector3.ZERO
		facing = facing.lerp(-back, 0.1).normalized()
	_move_on_ground(delta)
	visual.animate(delta, velocity, facing)
	return true


## Rôle de combat de chaque classe : soigneur, lanceur de sorts, archer, protecteur...
const CLASS_ROLE := {"clerc": "soin", "paladin": "soin", "druide": "soin", "barde": "chant", "mage": "sort", "cryomancien": "givre",
	"necromancien": "drain", "rodeur": "tir", "chevalier": "rempart", "guerrier": "rempart", "barbare": "rage", "assassin": "ombre", "moine": "paume"}
## Recharge de l'action de classe (secondes).
const ROLE_COOLDOWN := {"soin": 9.0, "chant": 14.0, "sort": 3.5, "givre": 5.0, "drain": 6.0, "tir": 3.0, "rempart": 8.0, "rage": 12.0, "ombre": 7.0, "paume": 6.0}
var _class_cd := randf_range(1.0, 3.0)
## Rage du barbare (secondes restantes) : +40 % d'attaque.
var _rage_left := 0.0
## Actions de classe réussies (pour les tests et les statistiques).
var class_actions := 0


func class_role() -> String:
	return CLASS_ROLE.get(fight_class, "")


## Au combat, chaque habitant agit selon sa classe en plus de ses coups (voir CLASS_ROLE).
## Renvoie vrai si une action a eu lieu.
func class_action(delta: float) -> bool:
	_rage_left = maxf(0.0, _rage_left - delta)
	_class_cd -= delta
	if _class_cd > 0.0 or not is_alive() or not can_act():
		return false
	var role := class_role()
	if role == "":
		return false
	var done := false
	var col: Color = _class().color if _class() else Color.WHITE
	var target := _threat as Combatant
	var dist := target.global_position.distance_to(global_position) if target and is_instance_valid(target) and target.is_alive() else INF
	match role:
		"soin", "chant":
			# soigne l'allié le plus blessé à portée (héros, habitants, familiers) ; le barde soigne tout le monde un peu
			var best: Combatant = null
			var worst := 0.85 if role == "soin" else 0.95
			var hurt := []
			# fâché contre le héros : il ne soigne que lui-même
			for g in (["player", "villagers", "familiars"] if not is_angry() else ["villagers"]):
				for n in get_tree().get_nodes_in_group(g):
					var c := n as Combatant
					if is_angry() and c != self:
						continue
					if c and c.is_alive() and c.global_position.distance_to(global_position) < 9.0:
						var r := c.health.ratio()
						if r < 0.95:
							hurt.append(c)
						if r < worst:
							worst = r
							best = c
			if role == "soin" and best:
				best.health.heal(maxi(2, roundi(best.health.max_health * 0.2 + magic_power() * 0.5)))
				VoxelBurst.spawn(self, best.global_position + Vector3(0, 0.2, 0), col.lightened(0.3), 16, 2.0, 0.08, 0.9, "up", -2.0)
				done = true
			elif role == "chant" and not hurt.is_empty():
				for c in hurt:
					c.health.heal(maxi(1, roundi(c.health.max_health * 0.08)))
				SkillFX.ring(self, global_position, 6.0, col, 0.6)
				done = true
			if done:
				visual.play_move("cast_1", 1.0)
		"sort", "givre", "tir":
			if dist < 12.0:
				facing = (target.global_position - global_position).normalized()
				facing.y = 0.0
				facing = facing.normalized()
				var bolt := MagicBolt.new()
				bolt.shooter = self
				bolt.color = col.lightened(0.2)
				bolt.direction = facing
				bolt.damage = maxi(1, roundi((magic_power() if role != "tir" else attack_power()) * 0.8))
				bolt.range_left = 13.0
				bolt.arrow = role == "tir"
				if role == "givre":
					bolt.on_hit = func(t: Combatant): t.apply_slow(0.5, 2.0)
				get_parent().add_child(bolt)
				bolt.global_position = global_position + Vector3(0, 1.1, 0) + facing * 0.6
				visual.play_move("cast_1" if role != "tir" else "punch_1", 1.2)
				done = true
		"drain":
			if dist < 6.0:
				var dmg := maxi(1, roundi(magic_power() * 0.9))
				if target.receive_hit(dmg, self, 1.0, 0.5):
					health.heal(maxi(1, dmg / 2))
				VoxelBurst.spawn(self, target.global_position + Vector3(0, 0.8, 0), col, 14, 2.0, 0.08, 0.6, "up", 1.0)
				done = true
		"rempart", "paume":
			if dist < 2.6:
				target.receive_hit(maxi(1, roundi(attack_power() * (0.8 if role == "rempart" else 1.1))), self, 9.0 if role == "paume" else 4.0, 2.0)
				if target.is_alive():
					target.stagger(1.0 if role == "rempart" else 0.6, role == "rempart")
				visual.play_move("heavy_1" if role == "rempart" else "punch_1", 1.0)
				done = true
		"rage":
			if dist < 4.0 and health.ratio() < 0.75:
				_rage_left = 6.0
				VoxelBurst.spawn(self, global_position + Vector3(0, 0.3, 0), Color("ff5a3a"), 18, 2.5, 0.08, 0.7, "up", -1.0)
				done = true
		"ombre":
			if dist < 8.0 and dist > 2.0:
				var behind := target.global_position + (target.global_position - global_position).normalized() * 1.0
				behind.y = global_position.y
				global_position = behind
				facing = (target.global_position - global_position).normalized()
				target.receive_hit(maxi(1, roundi(attack_power() * 1.4)), self, 3.0, 1.0)
				VoxelBurst.spawn(self, global_position + Vector3(0, 0.8, 0), Color("5a4a7a"), 14, 2.0, 0.08, 0.5, "up", 0.0)
				done = true
	if done:
		class_actions += 1
		_class_cd = ROLE_COOLDOWN.get(role, 8.0) * randf_range(0.9, 1.2)
	else:
		_class_cd = 0.5
	return done


func _fight_or_flee(delta: float) -> void:
	class_action(delta)
	var to := _threat.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var speed := walk_speed * 2.2 * (race.speed_multiplier if race else 1.0) * equipment.speed_multiplier()
	var w := weapon()
	if w == null and angry_left <= 0.0:
		# pas d'arme : on court se mettre à l'abri derrière sa maison
		var away := (home - _threat.global_position)
		away.y = 0.0
		var goal := home + away.normalized() * 3.0
		var dir := goal - global_position
		dir.y = 0.0
		velocity = dir.normalized() * speed if dir.length() > 0.4 else Vector3.ZERO
		if velocity != Vector3.ZERO:
			facing = velocity.normalized()
		if dist > alert_radius + 3.0:
			_threat = null
	else:
		if dist > 0.01:
			facing = to / dist
		var reach := attack_reach()
		var wanted := minf(reach * 0.85, 6.0) if w and w.projectile else reach * 0.8
		if dist > wanted:
			velocity = facing * speed
		else:
			velocity = Vector3.ZERO
			if can_attack():
				var combo := MoveLibrary.combo_for(weapon_style())
				perform(combo[_combo % combo.size()], attack_speed())
				_combo += 1
				_attack_cooldown = 0.15 if _combo % 3 != 0 else 0.9
	if in_move() or not can_act():
		velocity = Vector3.ZERO
	_move_on_ground(delta)
	visual.animate(delta, velocity, facing)
	_update_label()


## Cherche un équipement au sol meilleur que le sien.
func _look_for_loot() -> void:
	if _fetch:
		return
	var best: ItemPickup = null
	var best_gain := 0.0
	for p in get_tree().get_nodes_in_group("pickups"):
		var pickup := p as ItemPickup
		if pickup == null or pickup.is_taken() or pickup.item == null or not pickup.item.is_equipment():
			continue
		if pickup.global_position.distance_to(global_position) > loot_radius:
			continue
		if not equipment.is_upgrade(pickup.item):
			continue
		var cur := equipment.get_item(pickup.item.slot)
		var gain := pickup.item.power() - (cur.power() if cur else 0.0)
		if gain > best_gain:
			best_gain = gain
			best = pickup
	_fetch = best


## Appelé par un objet au sol quand l'habitant marche dessus.
func try_pickup(pickup: ItemPickup) -> void:
	var item := pickup.item
	if item == null or pickup.is_taken() or not equipment.is_upgrade(item):
		return
	pickup.take()
	# l'ancien objet est reposé au sol
	for old in equipment.equip(item):
		_drop(old)
	_fetch = null
	_pause = 0.6


func _drop(item: ItemData) -> void:
	if _world:
		_world.spawn_pickup(item, global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * 1.2)


func _update_label() -> void:
	if label is Label3D:
		if not label.has_meta("px"):
			label.set_meta("px", (label as Label3D).pixel_size)
		(label as Label3D).pixel_size = float(label.get_meta("px")) * label_scale
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var d := player.global_position.distance_to(global_position) if player else 999.0
	# un voyageur se repère de loin ; un compagnon ne s'affiche que tout près (il est toujours là)
	var near := d < (7.0 if stranger else (1.3 if companion else 2.4))
	label.visible = near
	if near:
		var job := ""
		if work_room != null and work_room.type:
			job = " · " + (work_room.type as RoomTypeData).job_name
		label.modulate = Color.WHITE
		if has_meta("story") and stranger:
			var info: Dictionary = Story.NPCS.get(get_meta("story"), {})
			label.text = KeyBindings.fmt("%s %s%s" % [villager_name, info.get("title", ""), "\n[{interact}] Parler" if d < 3.0 else ""])
			label.modulate = info.get("color", Color.WHITE)
		elif stranger and has_meta("merchant"):
			label.text = KeyBindings.fmt("%s (%s)\nMarchand ambulant%s" % [villager_name, race_title(), "\n[{interact}] Commercer" if d < 3.0 else ""])
		elif stranger:
			label.text = KeyBindings.fmt("%s (%s) · Nv %d\nVoyageur · %s · %s%s" % [villager_name, race_title(), level,
				class_name_fr(), JOB_NAMES.get(best_job(), "?"), "\n[{interact}] Parler" if d < 3.0 else ""])
		elif companion:
			label.text = KeyBindings.fmt("%s (%s) · Nv %d\nCompagnon d'expédition\n[{interact}] Équipement" % [villager_name, race_title(), level])
		else:
			var mood := VillageNeeds.mood_name(happiness)
			if not mood_reasons.is_empty():
				mood += " : " + ", ".join(PackedStringArray(mood_reasons))
			var doing: String = ACTIVITY_NAMES.get(activity, "")
			if doing != "":
				mood += " · " + doing
			var friend := " · Ami" if friendship >= QuestBoard.FRIEND_AT else ""
			var talk := KeyBindings.fmt("[{interact}] Parler (quête)" if _mark and _mark.visible else "[{interact}] Équipement et poste")
			label.text = "%s (%s)%s%s\n%s\n%s" % [villager_name, race_title(), friend, job, mood, talk]
			label.modulate = VillageNeeds.mood_color(happiness).lerp(Color.WHITE, 0.35)


## Attaque, défense et magie totales (race + équipement).
func total_stats() -> Dictionary:
	var r := race if race else RaceData.new()
	return {
		"health": health.current,
		"max_health": health.max_health,
		"attack": attack_power(),
		"defense": defense_power(),
		"magic": magic_power(),
		"speed": r.speed_multiplier * equipment.speed_multiplier(),
	}


func display_title() -> String:
	return "%s (%s)" % [villager_name, race_title()]


## Compagnons d'expédition possibles : 2, 3 dès la Ville, 4 en Capitale d'empire (rang du royaume).
static func max_companions(tree: SceneTree) -> int:
	var k := tree.get_first_node_in_group("kingdom")
	var r: int = k.rank if k else 0
	return 2 + (1 if r >= 4 else 0) + (1 if r >= 6 else 0)
