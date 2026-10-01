class_name WorldEvents
extends Node
## Événements du monde : tous les 3 ou 4 jours (à partir du jour 3), quelque chose arrive au royaume.
##  - Pluie d'étoiles : des éclats d'étoile tombent autour du village (minerais et cristaux rares) ;
##  - Invasion de la Brume : une horde brumeuse attaque le village (fragments et gemme si elle est repoussée) ;
##  - Grand tournoi : trois champions défient le héros au feu de camp, l'un après l'autre ;
##  - Fête du royaume : les habitants sont plus heureux et le marchand vient ;
##  - Épidémie : des habitants tombent malades (moins heureux) jusqu'à ce qu'on les soigne
##    (panneau du royaume : une soupe ou une potion de soin par malade).
## Un événement dure jusqu'à la fin du jour suivant, ou jusqu'à ce qu'il soit réglé.

signal started(ev: Dictionary)
signal ended(ev: Dictionary, success: bool, text: String)

const FIRST_DAY := 3
const EVENTS := {
	"etoiles": {"name": "Pluie d'étoiles", "color": Color("bfe8ff"), "text": "Des éclats d'étoile sont tombés autour du village : va les ramasser !"},
	"invasion": {"name": "Invasion de la Brume", "color": Color("b48cff"), "text": "Une horde brumeuse marche sur le village !"},
	"tournoi": {"name": "Grand tournoi", "color": Color("ffb04a"), "text": "Trois champions te défient au feu de camp : approche-toi pour combattre."},
	"fete": {"name": "Fête du royaume", "color": Color("ffe08a"), "text": "Tout le royaume fait la fête : habitants plus heureux, et le marchand arrive."},
	"epidemie": {"name": "Épidémie", "color": Color("9ad06a"), "text": "Des habitants sont malades : soigne-les depuis le panneau du royaume (U) avec une soupe ou une potion."},
}
const STAR_LOOT := [["mithril_brut", 2], ["cristal_aube", 1], ["gemme_saphir", 1], ["gemme_topaze", 1], ["lingot_or", 2], ["orichalque", 1]]
const CHAMPIONS := [["orc_brute", "Borgak l'Invaincu"], ["homme_lezard", "Ixtli aux Mille Lames"], ["ogre", "Mâchefer le Colosse"]]
const CURES := ["potion_soin", "soupe_legumes"]

## Événement en cours : {} ou {id, day, ...}.
var current := {}
var next_day := FIRST_DAY
var history := {}   # identifiant -> nombre de fois
var player: Player
var _tick := 0.0
var _day := -1
var _stars: Array = []
var _challenger: Enemy
var _arena_label: Label3D


func _ready() -> void:
	add_to_group("world_events")
	if not SaveGame.events_state.is_empty():
		import_state(SaveGame.events_state)
		SaveGame.events_state = {}
	_connect.call_deferred()


func _connect() -> void:
	var rm := _raids()
	if rm and not rm.raid_ended.is_connected(_on_raid_ended):
		rm.raid_ended.connect(_on_raid_ended)
		rm.raid_started.connect(_on_raid_started)


func _raids() -> RaidManager:
	return get_tree().get_first_node_in_group("raids") as RaidManager


func _world() -> WorldGenerator:
	return get_tree().get_first_node_in_group("world") as WorldGenerator


func today() -> int:
	var dc := get_tree().get_first_node_in_group("day_cycle") as DayCycle
	return dc.day if dc else 1


func is_active(id := "") -> bool:
	return not current.is_empty() and (id == "" or current.id == id)


func status_text() -> String:
	if current.is_empty():
		return ""
	var ev: Dictionary = EVENTS[current.id]
	match current.id:
		"etoiles":
			return "✦ %s : %d éclat(s) à ramasser" % [ev.name, _stars.filter(func(s): return is_instance_valid(s)).size()]
		"tournoi":
			return "⚔ %s : champion %d / %d" % [ev.name, mini(int(current.get("round", 0)) + 1, CHAMPIONS.size()), CHAMPIONS.size()]
		"epidemie":
			return "✚ %s : %d malade(s)" % [ev.name, sick().size()]
	return "✦ " + ev.name


## Bonus de bonheur des habitants (fête).
func happiness_bonus() -> float:
	return 15.0 if is_active("fete") else 0.0


func sick() -> Array:
	return get_tree().get_nodes_in_group("villagers").filter(func(v): return v.get_meta("malade", false))


# ---------------------------------------------------------------- le temps passe

func _process(delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
	if is_active("tournoi"):
		_tournament_step()
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 1.0
	_stars_step()
	var d := today()
	if _day < 0:
		_day = d
	while _day < d:
		_day += 1
		new_day(_day)


func new_day(d: int) -> void:
	# fin de l'événement en cours
	if not current.is_empty() and d > int(current.day) + 1:
		_finish(current.id == "fete", "")
	if current.is_empty() and d >= next_day:
		var choices := EVENTS.keys()
		choices.erase(history.get("_last", ""))
		start(choices.pick_random())


## Lance un événement (automatique ; utilisable pour tester).
func start(id: String) -> void:
	if not current.is_empty():
		_finish(false, "")
	current = {"id": id, "day": today()}
	history[id] = int(history.get(id, 0)) + 1
	history["_last"] = id
	var ev: Dictionary = EVENTS[id]
	match id:
		"etoiles":
			_drop_stars()
		"invasion":
			var rm := _raids()
			if rm and rm.raid.is_empty():
				rm.announce({"key": "evt_brume", "name": "Horde de la Brume", "types": ["squelette", "demon", "esprit_follet"], "leader": "seigneur_squelette", "extra": 2})
			else:
				current = {}
				return
		"tournoi":
			current.round = 0
			_make_arena()
		"fete":
			var tr := get_tree().get_first_node_in_group("trade")
			if tr and not tr.is_here():
				tr.arrive()
		"epidemie":
			var vs := get_tree().get_nodes_in_group("villagers").filter(func(v): return not v.get("stranger") and not v.get("companion"))
			vs.shuffle()
			for v in vs.slice(0, clampi(vs.size() / 3, 1, 4)):
				v.set_meta("malade", true)
			if sick().is_empty():
				current = {}
				return
	if player:
		player.feat.emit(ev.name, ev.color)
		player.notify.emit(ev.text)
	started.emit(current)


func _finish(success: bool, text: String) -> void:
	if current.is_empty():
		return
	var ev := current
	current = {}
	next_day = today() + randi_range(3, 4)
	# nettoyage
	for s in _stars:
		if is_instance_valid(s):
			s.queue_free()
	_stars.clear()
	if _challenger and is_instance_valid(_challenger):
		_challenger.queue_free()
	_challenger = null
	if _arena_label and is_instance_valid(_arena_label):
		_arena_label.queue_free()
	_arena_label = null
	for v in sick():
		v.remove_meta("malade")
	if text == "":
		text = "%s : c'est terminé." % EVENTS[ev.id].name
	if player:
		player.notify.emit(text)
	ended.emit(ev, success, text)


func _give(loot: Array, title: String) -> void:
	if player == null:
		return
	var parts := []
	for pair in loot:
		var it := Items.get_item(pair[0])
		if it:
			player.inventory.add(it, int(pair[1]))
			parts.append("%d %s" % [int(pair[1]), it.display_name])
	player.feat.emit(title, Color("ffd24a"))
	player.notify.emit("%s : %s." % [title, ", ".join(PackedStringArray(parts))])


# ---------------------------------------------------------------- pluie d'étoiles

func _drop_stars() -> void:
	var w := _world()
	if w == null:
		return
	var center := w.cell_center(w.spawn_cell)
	for i in 4:
		var pos := center
		for t in 20:
			var a := randf() * TAU
			pos = center + Vector3(cos(a), 0, sin(a)) * randf_range(14.0, 34.0)
			if w.is_walkable(pos):
				break
		pos.y = w.ground_height_at(pos + Vector3(0, 4, 0))
		var pair: Array = STAR_LOOT[randi() % STAR_LOOT.size()] if randf() > 0.15 else ["orichalque", 1]
		var pk := w.spawn_pickup(Items.get_item(pair[0]), pos, int(pair[1]))
		if pk == null:
			continue
		var l := OmniLight3D.new()
		l.light_color = Color("bfe8ff")
		l.light_energy = 2.5
		l.omni_range = 6.0
		l.position.y = 1.0
		pk.add_child(l)
		VoxelBurst.spawn(pk, pos + Vector3(0, 0.5, 0), Color("bfe8ff"), 40, 7.0, 0.12, 1.0, "up", 10.0)
		_stars.append(pk)


func _stars_step() -> void:
	if is_active("etoiles") and not _stars.is_empty() and _stars.all(func(s): return not is_instance_valid(s) or s.is_taken()):
		_stars.clear()
		_finish(true, "Pluie d'étoiles : tu as ramassé tous les éclats !")


# ---------------------------------------------------------------- invasion

func _on_raid_started(r: Dictionary) -> void:
	if str(r.get("story", "")) != "evt_brume":
		return
	for e in r.raiders:
		if is_instance_valid(e):
			e.brume = true
			e.name_label.text = e._label_base()
			e.name_label.modulate = e._label_color()


func _on_raid_ended(r: Dictionary, repelled: bool, _text: String) -> void:
	if str(r.get("story", "")) != "evt_brume" or not is_active("invasion"):
		return
	if repelled:
		_give([["fragment_brume", 4], [RareDrops.GEM_IDS.pick_random(), 1], ["piece_or", 120]], "Invasion repoussée")
		_finish(true, "La Brume recule : le village est sauf.")
	else:
		_finish(false, "La horde de la Brume repart vers les ténèbres...")


# ---------------------------------------------------------------- tournoi

func arena_pos() -> Vector3:
	var w := _world()
	return w.cell_center(w.spawn_cell) + Vector3(6, 0, 6) if w else Vector3.ZERO


func _make_arena() -> void:
	var w := _world()
	if w == null:
		return
	_arena_label = Label3D.new()
	_arena_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_arena_label.font_size = 40
	_arena_label.pixel_size = 0.006
	_arena_label.outline_size = 10
	_arena_label.modulate = Color("ffb04a")
	_arena_label.no_depth_test = true
	w.add_child(_arena_label)
	var pos := arena_pos()
	pos.y = w.ground_height_at(pos + Vector3(0, 4, 0)) + 3.0
	_arena_label.global_position = pos
	_update_arena_label()


func _update_arena_label() -> void:
	if _arena_label and is_instance_valid(_arena_label):
		_arena_label.text = "⚔ Grand tournoi ⚔\nChampion %d / %d — approche-toi" % [int(current.get("round", 0)) + 1, CHAMPIONS.size()]


func _tournament_step() -> void:
	if player == null or not player.is_alive():
		return
	var w := _world()
	if _challenger and is_instance_valid(_challenger):
		if not _challenger.is_alive():
			_challenger = null
			current.round = int(current.round) + 1
			if int(current.round) >= CHAMPIONS.size():
				_give([["piece_or", 300], [RareDrops.GEM_IDS.pick_random(), 1], ["lingot_or", 2]], "Vainqueur du tournoi")
				player.absorb_soul("tournoi", {"attack": 1.0})
				_finish(true, "Tu remportes le Grand tournoi ! Le royaume acclame son champion (+1 attaque).")
			else:
				player.notify.emit("Champion vaincu ! Le suivant entre dans l'arène.")
				_update_arena_label()
		return
	var pos := arena_pos()
	if Vector2(player.global_position.x - pos.x, player.global_position.z - pos.z).length() > 6.0:
		return
	var c: Array = CHAMPIONS[int(current.round)]
	var e := (load("res://scenes/enemies/enemy.tscn") as PackedScene).instantiate() as Enemy
	var d := (load("res://data/enemies/%s.tres" % c[0]) as EnemyData).duplicate() as EnemyData
	d.display_name = c[1]
	d.loot = []
	e.data = d
	e.level = player.level + int(current.round)
	e.power = 1.2 + 0.06 * e.level
	e.set_meta("tournoi", true)
	w.add_child(e)
	var at := pos + Vector3(0, 0, -3)
	at.y = w.ground_height_at(at + Vector3(0, 4, 0))
	e.global_position = at
	e.home = at
	_challenger = e
	player.notify.emit("%s entre dans l'arène !" % c[1])


# ---------------------------------------------------------------- épidémie

## Soigne les malades avec les remèdes du sac (une soupe ou une potion chacun). Renvoie le nombre de soignés.
func cure() -> int:
	if player == null:
		return 0
	var n := 0
	for v in sick():
		var used := false
		for id in CURES:
			var it := Items.get_item(id)
			if it and player.inventory.count(it) > 0:
				player.inventory.remove(it, 1)
				used = true
				break
		if not used:
			break
		v.remove_meta("malade")
		n += 1
	if n > 0 and sick().is_empty():
		_give([["piece_or", 80 + 20 * n]], "Épidémie vaincue")
		_finish(true, "Tous les malades sont guéris. Les habitants te remercient !")
	elif n > 0:
		player.notify.emit("%d habitant(s) soigné(s). Il reste %d malade(s)." % [n, sick().size()])
	return n


func cure_block() -> String:
	if sick().is_empty():
		return "Personne n'est malade."
	for id in CURES:
		var it := Items.get_item(id)
		if it and player and player.inventory.count(it) > 0:
			return ""
	return "Il faut une soupe de légumes ou une potion de soin."


# ---------------------------------------------------------------- sauvegarde

func export_state() -> Dictionary:
	var sick_names := sick().map(func(v): return str(v.villager_name))
	var cur := current.duplicate()
	return {"current": cur if not cur.is_empty() and cur.id in ["fete", "epidemie"] else {}, "next_day": next_day,
		"history": history.duplicate(), "sick": sick_names, "day": _day}


func import_state(d: Dictionary) -> void:
	var cur: Dictionary = d.get("current", {})
	current = {"id": str(cur.id), "day": int(cur.get("day", 1))} if cur.has("id") else {}
	next_day = int(d.get("next_day", FIRST_DAY))
	history = (d.get("history", {}) as Dictionary).duplicate()
	_day = int(d.get("day", -1))
	var names: Array = d.get("sick", [])
	if not names.is_empty():
		_mark_sick.call_deferred(names)


func _mark_sick(names: Array) -> void:
	for v in get_tree().get_nodes_in_group("villagers"):
		if names.has(str(v.villager_name)):
			v.set_meta("malade", true)
