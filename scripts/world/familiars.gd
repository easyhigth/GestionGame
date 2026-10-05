class_name Familiars
extends Node3D
## Familiers : grâce au Pacte, un monstre affaibli (moins de 30 % de vie, pas un boss) peut être
## apprivoisé : E près de lui. Il reçoit un nom, suit le héros partout et combat avec lui (3 au plus).
## Chaque victoire près du héros le fait progresser : il gagne des niveaux et évolue deux fois
## (plus grand, plus fort, nouveau nom : Loup → Loup des tempêtes → Seigneur-loup...).
## K.O., il revient auprès du héros au bout de REVIVE secondes.

## Familiers qui suivent le héros, et en tout (les autres vivent au village et le défendent).
const MAX := 3
const MAX_TOTAL := 8


## Familiers qui suivent le héros : 3, 4 au niveau 100, 5 au niveau 300.
static func max_team(tree: SceneTree) -> int:
	var p := tree.get_first_node_in_group("player")
	var lv: int = p.level if p and "level" in p else 1
	return MAX + (1 if lv >= 100 else 0) + (1 if lv >= 300 else 0)
## Ordres (touche P) : suivre, attendre ici, attaquer la cible du héros.
const ORDERS := ["suivre", "attendre", "attaquer"]
const ORDER_TEXT := {"suivre": "Suivez-moi !", "attendre": "Attendez ici !", "attaquer": "Attaquez ma cible !"}
## Familiers que l'on peut monter (E près de lui) : vitesse selon l'évolution.
const RIDEABLE := ["loup", "loup_alpha", "loup_givre", "sanglier", "ours_neige", "araignee", "scorpion", "panthere"]
const SCALE := [1.0, 1.18, 1.38]
const POWER := [1.1, 1.45, 1.95]
## Victoires pour évoluer (1re et 2e évolution) ; un niveau toutes les LEVEL_KILLS victoires.
const EVO_KILLS := [12, 35]
const LEVEL_KILLS := 4
const REVIVE := 40.0
const NAMES := ["Croc", "Brume", "Éclair", "Ombre", "Rubis", "Givre", "Tonnerre", "Plume", "Braise", "Lune",
	"Cendre", "Orage", "Sirius", "Nova", "Kaze", "Rako", "Épine", "Grelot"]
## Évolutions des familiers : identifiant du monstre -> [1re, 2e].
const TITLES := {
	"loup": ["Loup des tempêtes", "Seigneur-loup"], "loup_alpha": ["Loup des tempêtes", "Seigneur-loup"],
	"loup_givre": ["Loup du blizzard", "Seigneur des neiges"], "sanglier": ["Sanglier de guerre", "Roi sanglier"],
	"slime_bleu": ["Slime géant", "Slime royal"], "slime_acide": ["Slime corrosif", "Slime royal"], "slime_magma": ["Slime de lave", "Slime volcanique"],
	"araignee": ["Araignée tisseuse", "Reine araignée"], "scorpion": ["Scorpion d'airain", "Empereur scorpion"],
	"ours_neige": ["Ours des glaces", "Ours ancien"], "gobelin_pillard": ["Hobgobelin", "Chef hobgobelin"],
	"orc_brute": ["Orc noble", "Seigneur orc"], "ogre": ["Oni", "Grand oni"], "harpie": ["Harpie des tempêtes", "Reine des cimes"],
	"homme_lezard": ["Homme-lézard guerrier", "Dragonide"], "salamandre": ["Salamandre ardente", "Drake de feu"],
	"esprit_follet": ["Esprit lumineux", "Grand esprit"], "fee_sauvage": ["Grande fée", "Fée céleste"],
	"squelette": ["Chevalier squelette", "Seigneur squelette"], "demon": ["Démon supérieur", "Archidémon"],
	"dryade_corrompue": ["Dryade", "Dryade ancienne"],
	"panthere": ["Panthère des ombres", "Reine panthère"], "grenouille": ["Grenouille royale", "Crapaud-roi"],
	"serpent": ["Serpent ailé", "Grand naga"], "serpent_roi": ["Naga royal", "Serpent céleste"],
}

var world: WorldGenerator
var player: Player
## [{data, level, name, evo, kills, down, node, place}] ; place : « equipe » (suit le héros) ou « village ».
var list: Array = []
var order := "suivre"
var _wait_pos := Vector3.INF
var _train := 60.0
## Entraînement des dresseurs (Ménagerie) : une « victoire » toutes les TRAIN_EVERY secondes par dresseur au travail.
const TRAIN_EVERY := 60.0


func _ready() -> void:
	add_to_group("familiars_mgr")
	if not SaveGame.familiars_state.is_empty():
		import_state(SaveGame.familiars_state)
		SaveGame.familiars_state = {}


static func can_tame(e: Enemy) -> bool:
	return e != null and not e.tamed and e.data != null and not (e is Boss) and e.is_alive() \
		and e.health.ratio() < 0.3 and not e.has_meta("raider") and not e.has_meta("story_pack") \
		and not e.has_meta("quest") and Evolution.pact_known(e.get_tree())


## Familiers en tout : 2 de plus avec une Ménagerie.
static func max_total(tree: SceneTree) -> int:
	return MAX_TOTAL + (2 if has_menagerie(tree) else 0)


static func has_menagerie(tree: SceneTree) -> bool:
	var k := tree.get_first_node_in_group("kingdom") as Kingdom
	return k != null and k.rooms.any(func(r): return r.type != null and r.type.id == "menagerie")


## Dresseurs au travail en ce moment.
func trainers() -> Array:
	return get_tree().get_nodes_in_group("villagers").filter(func(v):
		var wr = v.get("work_room")
		return wr != null and wr.type != null and wr.type.job_id == "dresseur" and v.call("is_at_work"))


static func title_of(entry: Dictionary) -> String:
	var id := str(entry.data).get_file().get_basename()
	var evo := int(entry.evo)
	var d := load(entry.data) as EnemyData
	var base := d.display_name if d else "Familier"
	if evo <= 0:
		return base
	var t: Array = TITLES.get(id, ["%s éveillé" % base, "%s seigneur" % base])
	return t[mini(evo, 2) - 1]


## E près d'un monstre affaibli : on l'apprivoise. Vrai si l'appui est utilisé.
func try_interact(p: Player) -> bool:
	var best: Enemy = null
	var bd := 3.5
	for n in get_tree().get_nodes_in_group("enemy_units"):
		var e := n as Enemy
		if e and can_tame(e):
			var d := e.global_position.distance_to(p.global_position)
			if d < bd:
				bd = d
				best = e
	if best == null:
		return false
	if list.size() >= max_total(get_tree()):
		p.notify.emit("Tu as déjà %d familiers : libères-en un (panneau du royaume, U) pour en lier un autre." % max_total(get_tree()))
		return true
	tame(best)
	return true


func tame(e: Enemy) -> Dictionary:
	var used := list.map(func(x): return x.name)
	var free := NAMES.filter(func(n): return not used.has(n))
	var place := "equipe" if team().size() < max_team(get_tree()) else "village"
	var entry := {"data": e.data.resource_path, "level": e.level, "name": free.pick_random() if not free.is_empty() else "Familier",
		"evo": 0, "kills": 0, "down": 0.0, "node": null, "place": place}
	list.append(entry)
	var pos := e.global_position
	VoxelBurst.spawn(world, pos + Vector3(0, 0.8, 0), Color("d8c0ff"), 50, 4.5, 0.12, 1.1, "up", 2.0, false)
	SkillFX.ring(world, pos, 3.0, Color("d8c0ff"), 0.6)
	e.queue_free()
	_spawn(entry, pos)
	Sound.ui("levelup")
	var sq := get_tree().get_first_node_in_group("side_quests")
	if sq:
		sq.on_event("tame")
	if player:
		player.feat.emit("Pacte : %s devient ton familier « %s » !" % [(load(entry.data) as EnemyData).display_name, entry.name], Color("d8c0ff"))
		if place == "equipe":
			player.notify.emit("%s te suivra partout et combattra avec toi. Chaque victoire le fait progresser : il évoluera." % entry.name)
		else:
			player.notify.emit("Tu as déjà %d familiers avec toi : %s part vivre au village et le défendra." % [max_team(get_tree()), entry.name])
	return entry


func _spawn(entry: Dictionary, pos: Vector3) -> void:
	var e := (load("res://scenes/enemies/enemy.tscn") as PackedScene).instantiate() as Enemy
	e.tamed = true
	e.data = load(entry.data) as EnemyData
	e.level = int(entry.level)
	e.power = POWER[clampi(int(entry.evo), 0, 2)] * (1.0 + 0.06 * (int(entry.level) - 1))
	e.familiar_name = entry.name
	e.familiar_title = title_of(entry)
	e.familiar_slot = (team() if entry.get("place", "equipe") == "equipe" else village_list()).find(entry)
	e.set_meta("evo", int(entry.evo))
	_apply_order(entry, e)
	add_child(e)
	if entry.get("place", "equipe") == "village":
		pos = village_spot(e.familiar_slot)
	e.global_position = pos
	e.home = pos
	entry.node = e


# ---------------------------------------------------------------- équipe, village, ordres

## Les familiers qui suivent le héros.
func team() -> Array:
	return list.filter(func(x): return x.get("place", "equipe") == "equipe")


func village_list() -> Array:
	return list.filter(func(x): return x.get("place", "equipe") == "village")


## La place d'un familier au village (en cercle autour du feu de camp).
func village_spot(i: int) -> Vector3:
	var c := world.home_center() if world else Vector3.ZERO
	var a := TAU * i / 5.0 + 0.8
	var p := c + Vector3(cos(a), 0, sin(a)) * 7.0
	if world:
		p.y = world.ground_height_at(p + Vector3(0, 20, 0))
	return p


func _apply_order(entry: Dictionary, e: Enemy) -> void:
	if entry.get("place", "equipe") == "village":
		e.familiar_order = "village"
		e.familiar_home = village_spot(village_list().find(entry))
	else:
		e.familiar_order = order
		e.familiar_home = _wait_pos


## Touche P : l'ordre suivant pour les familiers qui suivent le héros.
func cycle_order() -> String:
	order = ORDERS[(ORDERS.find(order) + 1) % ORDERS.size()]
	_wait_pos = player.global_position if player else Vector3.INF
	for entry in team():
		var n = entry.node
		if n and is_instance_valid(n):
			_apply_order(entry, n)
			if order == "attaquer":
				n.set("_target", null)
	if player:
		var who := ", ".join(PackedStringArray(team().map(func(x): return x.name)))
		player.notify.emit("%s  (%s)" % [ORDER_TEXT[order], who if who != "" else "aucun familier"])
		Sound.ui("ui_click")
	return order


## Envoie un familier au village, ou le rappelle auprès du héros. Vrai si c'est fait.
func set_place(entry: Dictionary, place: String) -> bool:
	if place == "equipe" and team().size() >= max_team(get_tree()):
		if player:
			player.notify.emit("Déjà %d familiers avec toi." % max_team(get_tree()))
		return false
	entry.place = place
	_respawn_all()
	if player:
		player.notify.emit(("%s part vivre au village et le défendra." if place == "village" else "%s te rejoint.") % entry.name)
	return true


## Rend sa liberté à un familier.
func release(entry: Dictionary) -> void:
	var n = entry.node
	if n and is_instance_valid(n):
		VoxelBurst.spawn(world, n.global_position + Vector3(0, 1, 0), Color("b8f0a0"), 30, 4.0, 0.1, 0.9, "up", 2.0, false)
		var mo := get_tree().get_first_node_in_group("mounts")
		if mo and mo.mount == n:
			mo.dismount()
		n.queue_free()
	list.erase(entry)
	if player:
		player.notify.emit("%s retourne à la vie sauvage. Merci pour tout, %s." % [entry.name, entry.name])
	_respawn_all()


## Replace les familiers (places au village et rangs autour du héros).
func _respawn_all() -> void:
	for entry in list:
		var n = entry.node
		if n and is_instance_valid(n):
			var pos: Vector3 = n.global_position
			var mo := get_tree().get_first_node_in_group("mounts")
			if mo and mo.mount == n:
				_apply_order(entry, n)
				continue
			n.queue_free()
			entry.node = null
			_spawn(entry, pos)


func rideable(entry: Dictionary) -> bool:
	return RIDEABLE.has(str(entry.data).get_file().get_basename())


func entry_of(node: Node) -> Dictionary:
	for entry in list:
		if entry.node == node:
			return entry
	return {}


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("familiar_order") and player and not player.ui_open and not team().is_empty():
		cycle_order()
		get_viewport().set_input_as_handled()


func on_familiar_down(e: Enemy) -> void:
	for entry in list:
		if entry.node == e:
			entry.node = null
			entry.down = REVIVE
			if player:
				player.notify.emit("%s est K.O. Il te rejoindra dans %d secondes." % [entry.name, roundi(REVIVE)])


## Une victoire près du héros : les familiers présents progressent.
func on_enemy_died(dead: Enemy) -> void:
	if player == null or dead.global_position.distance_to(player.global_position) > 25.0:
		return
	for entry in list:
		var n = entry.node
		if n == null or not is_instance_valid(n) or not n.is_alive():
			continue
		_gain(entry)


## Une victoire (ou un entraînement) pour ce familier : niveaux et évolutions.
func _gain(entry: Dictionary) -> void:
	entry.kills = int(entry.kills) + 1
	var changed := false
	if int(entry.kills) % LEVEL_KILLS == 0:
		entry.level = int(entry.level) + 1
		changed = true
	var evo := int(entry.evo)
	if evo < 2 and int(entry.kills) >= EVO_KILLS[evo]:
		entry.evo = evo + 1
		changed = true
		_evolve_fx(entry)
	if changed:
		_refresh(entry)


func _evolve_fx(entry: Dictionary) -> void:
	var n = entry.node
	if n and is_instance_valid(n):
		VoxelBurst.spawn(world, n.global_position + Vector3(0, 1, 0), Color("d8c0ff"), 70, 6.0, 0.13, 1.3, "up", 1.5, false)
		SkillFX.ring(world, n.global_position, 4.0, Color("d8c0ff"), 0.8)
	Sound.ui("levelup")
	if player:
		player.feat.emit("Évolution ! %s devient %s" % [entry.name, title_of(entry)], Color("d8c0ff"))


## Niveau ou évolution changés : on remplace le familier par sa nouvelle forme.
func _refresh(entry: Dictionary) -> void:
	var n = entry.node
	if n == null or not is_instance_valid(n):
		return
	var pos: Vector3 = n.global_position
	var ratio: float = n.health.ratio()
	n.queue_free()
	entry.node = null
	_spawn(entry, pos)
	var nn: Enemy = entry.node
	nn.health.current = maxi(1, roundi(nn.health.max_health * maxf(ratio, 0.5)))


func _process(delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
		return
	if world == null:
		world = get_tree().get_first_node_in_group("world") as WorldGenerator
	# les dresseurs entraînent les familiers qui vivent au village
	_train -= delta
	if _train <= 0.0:
		_train = TRAIN_EVERY
		var tr := trainers()
		if not tr.is_empty():
			for entry in list:
				if entry.get("place", "equipe") == "village":
					for i in tr.size():
						_gain(entry)
	var heal_mult := 2.0 if has_menagerie(get_tree()) else 1.0
	for entry in list:
		var n = entry.node
		if n != null and is_instance_valid(n):
			continue
		entry.node = null
		entry.down = maxf(0.0, float(entry.down) - delta * heal_mult)
		if entry.down <= 0.0 and player.is_alive():
			var a := randf() * TAU
			var pos := player.global_position + Vector3(cos(a), 0.3, sin(a)) * 2.0
			if order == "attendre" and _wait_pos != Vector3.INF and entry.get("place", "equipe") == "equipe":
				pos = _wait_pos + Vector3(cos(a), 0.3, sin(a)) * 1.5
			_spawn(entry, pos)


## Les familiers (vivants ou non), pour le panneau du royaume.
func summary() -> String:
	var parts := []
	for entry in list:
		parts.append("%s (%s, Nv %d%s%s)" % [entry.name, title_of(entry), entry.level, ", au village" if entry.get("place", "equipe") == "village" else "", ", K.O." if entry.node == null else ""])
	return ", ".join(PackedStringArray(parts))


func export_state() -> Dictionary:
	var out := []
	for entry in list:
		out.append({"data": entry.data, "level": entry.level, "name": entry.name, "evo": entry.evo, "kills": entry.kills, "place": entry.get("place", "equipe")})
	return {"list": out, "order": order}


func import_state(d: Dictionary) -> void:
	for entry in list:
		if entry.node and is_instance_valid(entry.node):
			entry.node.queue_free()
	list.clear()
	for e in d.get("list", []):
		if ResourceLoader.exists(str(e.data)):
			list.append({"data": str(e.data), "level": int(e.level), "name": str(e.name), "evo": int(e.evo),
				"kills": int(e.kills), "down": 0.0, "node": null, "place": str(e.get("place", "equipe"))})
	order = str(d.get("order", "suivre"))
	if order == "attendre":
		order = "suivre"
