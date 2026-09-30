class_name Familiars
extends Node3D
## Familiers : grâce au Pacte, un monstre affaibli (moins de 30 % de vie, pas un boss) peut être
## apprivoisé : E près de lui. Il reçoit un nom, suit le héros partout et combat avec lui (3 au plus).
## Chaque victoire près du héros le fait progresser : il gagne des niveaux et évolue deux fois
## (plus grand, plus fort, nouveau nom : Loup → Loup des tempêtes → Seigneur-loup...).
## K.O., il revient auprès du héros au bout de REVIVE secondes.

const MAX := 3
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
}

var world: WorldGenerator
var player: Player
## [{data, level, name, evo, kills, down, node}]
var list: Array = []


func _ready() -> void:
	add_to_group("familiars_mgr")
	if not SaveGame.familiars_state.is_empty():
		import_state(SaveGame.familiars_state)
		SaveGame.familiars_state = {}


static func can_tame(e: Enemy) -> bool:
	return e != null and not e.tamed and e.data != null and not (e is Boss) and e.is_alive() \
		and e.health.ratio() < 0.3 and not e.has_meta("raider") and not e.has_meta("story_pack") \
		and not e.has_meta("quest") and Evolution.pact_known(e.get_tree())


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
	if list.size() >= MAX:
		p.notify.emit("Tu as déjà %d familiers : le Pacte ne peut pas en lier davantage." % MAX)
		return true
	tame(best)
	return true


func tame(e: Enemy) -> Dictionary:
	var used := list.map(func(x): return x.name)
	var free := NAMES.filter(func(n): return not used.has(n))
	var entry := {"data": e.data.resource_path, "level": e.level, "name": free.pick_random() if not free.is_empty() else "Familier",
		"evo": 0, "kills": 0, "down": 0.0, "node": null}
	list.append(entry)
	var pos := e.global_position
	VoxelBurst.spawn(world, pos + Vector3(0, 0.8, 0), Color("d8c0ff"), 50, 4.5, 0.12, 1.1, "up", 2.0, false)
	SkillFX.ring(world, pos, 3.0, Color("d8c0ff"), 0.6)
	e.queue_free()
	_spawn(entry, pos)
	Sound.ui("levelup")
	if player:
		player.feat.emit("Pacte : %s devient ton familier « %s » !" % [(load(entry.data) as EnemyData).display_name, entry.name], Color("d8c0ff"))
		player.notify.emit("%s te suivra partout et combattra avec toi. Chaque victoire le fait progresser : il évoluera." % entry.name)
	return entry


func _spawn(entry: Dictionary, pos: Vector3) -> void:
	var e := (load("res://scenes/enemies/enemy.tscn") as PackedScene).instantiate() as Enemy
	e.tamed = true
	e.data = load(entry.data) as EnemyData
	e.level = int(entry.level)
	e.power = POWER[clampi(int(entry.evo), 0, 2)] * (1.0 + 0.06 * (int(entry.level) - 1))
	e.familiar_name = entry.name
	e.familiar_title = title_of(entry)
	e.familiar_slot = list.find(entry)
	e.set_meta("evo", int(entry.evo))
	add_child(e)
	e.global_position = pos
	e.home = pos
	entry.node = e


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
	for entry in list:
		var n = entry.node
		if n != null and is_instance_valid(n):
			continue
		entry.node = null
		entry.down = maxf(0.0, float(entry.down) - delta)
		if entry.down <= 0.0 and player.is_alive():
			var a := randf() * TAU
			var pos := player.global_position + Vector3(cos(a), 0.3, sin(a)) * 2.0
			_spawn(entry, pos)


## Les familiers (vivants ou non), pour le panneau du royaume.
func summary() -> String:
	var parts := []
	for entry in list:
		parts.append("%s (%s, Nv %d%s)" % [entry.name, title_of(entry), entry.level, ", K.O." if entry.node == null else ""])
	return ", ".join(PackedStringArray(parts))


func export_state() -> Dictionary:
	var out := []
	for entry in list:
		out.append({"data": entry.data, "level": entry.level, "name": entry.name, "evo": entry.evo, "kills": entry.kills})
	return {"list": out}


func import_state(d: Dictionary) -> void:
	for entry in list:
		if entry.node and is_instance_valid(entry.node):
			entry.node.queue_free()
	list.clear()
	for e in d.get("list", []):
		if ResourceLoader.exists(str(e.data)):
			list.append({"data": str(e.data), "level": int(e.level), "name": str(e.name), "evo": int(e.evo),
				"kills": int(e.kills), "down": 0.0, "node": null})
