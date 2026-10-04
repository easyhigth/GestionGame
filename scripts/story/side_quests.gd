class_name SideQuests
extends Node
## Quêtes secondaires des personnages de l'histoire (données : SideQuestData). Un « ! » au-dessus
## d'un personnage : il a une quête à proposer (E pour lui parler) ; « ? » : la quête est finie,
## il attend son rapport. Une seule quête à la fois par personnage. Le journal (O) les liste.

signal changed

const QUESTS := SideQuestData.QUESTS

## identifiant -> {state: "active" | "done", progress}
var states := {}
var player: Player
var _tick := 0.0


func _ready() -> void:
	add_to_group("side_quests")
	if not SaveGame.side_quests_state.is_empty():
		import_state(SaveGame.side_quests_state)
		SaveGame.side_quests_state = {}
	_connect.call_deferred()


func _connect() -> void:
	var dm := get_tree().get_first_node_in_group("dungeons")
	if dm and not dm.boss_defeated.is_connected(_on_boss):
		dm.boss_defeated.connect(_on_boss)
	var mc := get_tree().get_first_node_in_group("mountain_caves")
	if mc and not mc.chest_opened.is_connected(_on_cave_chest):
		mc.chest_opened.connect(_on_cave_chest)


func _story() -> Story:
	return get_tree().get_first_node_in_group("story") as Story


static func quest(id: String) -> Dictionary:
	for q in QUESTS:
		if q.id == id:
			return q
	return {}


func state_of(id: String) -> String:
	return str(states.get(id, {}).get("state", ""))


## La quête que ce personnage propose ou suit en ce moment ({} s'il n'en a pas).
func current_for(npc_id: String) -> Dictionary:
	var st := _story()
	for q in QUESTS:
		if q.npc != npc_id:
			continue
		var s := state_of(q.id)
		if s == "done":
			continue
		if s == "active":
			return q
		# pas encore disponible
		var after: String = q.after
		if st == null:
			return {}
		if after == "fin" and not st.is_done():
			continue
		if after != "fin" and not st.passed(after):
			continue
		return q
	return {}


## « ! » (quête à proposer), « ? » (quête finie à rendre) ou "".
func mark_for(npc_id: String) -> String:
	var q := current_for(npc_id)
	if q.is_empty():
		return ""
	if state_of(q.id) == "":
		return "!"
	return "?" if is_complete(q) else ""


func active() -> Array:
	return QUESTS.filter(func(q): return state_of(q.id) == "active")


func done_count() -> int:
	return QUESTS.filter(func(q): return state_of(q.id) == "done").size()


# ---------------------------------------------------------------- dialogue

## E sur un personnage de l'histoire qui n'a rien à dire pour l'histoire : sa quête. Vrai si un dialogue s'ouvre.
func try_talk(npc_id: String, v: Node) -> bool:
	var q := current_for(npc_id)
	if q.is_empty():
		return false
	var dlg := get_tree().get_first_node_in_group("story_dialog")
	if dlg == null:
		return false
	var s := state_of(q.id)
	var pages: Array
	var choices: Array = []
	if s == "":
		pages = q.start.duplicate()
		pages.append([npc_id, "« %s » : %s" % [q.title, q.text]])
		choices = [["« J'accepte. »", "ok"], ["« Plus tard. »", "non"]]
	elif is_complete(q):
		pages = q.end
	else:
		pages = q.wait.duplicate()
		pages.append([npc_id, "(%s)" % progress_text(q)])
	dlg.open_custom(q.id, {"pages": pages, "choices": choices}, v, _on_dialog.bind(q))
	return true


func _on_dialog(choice: String, q: Dictionary) -> void:
	var s := state_of(q.id)
	if s == "" and choice == "ok":
		states[q.id] = {"state": "active", "progress": 0}
		if player:
			player.notify.emit("Quête de %s : %s. ({journal} : journal)" % [Story.NPCS[q.npc].name, q.title])
			Sound.ui("ui_open")
	elif s == "active" and is_complete(q):
		_complete(q)
	changed.emit()


func _complete(q: Dictionary) -> void:
	# les objets apportés sont donnés
	if q.type == "item":
		player.inventory.remove(Items.get_item(q.item), int(q.n))
		if q.has("item2"):
			player.inventory.remove(Items.get_item(q.item2), int(q.n2))
	states[q.id] = {"state": "done", "progress": 0}
	var r: Dictionary = q.reward
	for pair in r.get("items", []):
		var it := Items.get_item(pair[0])
		if it:
			player.inventory.add(it, int(pair[1]))
			if it.rarity >= ItemData.Rarity.RARE:
				player.feat.emit("Obtenu : %s%s" % [it.display_name, " ×%d" % pair[1] if int(pair[1]) > 1 else ""], it.rarity_color())
	player.gain_xp(int(r.get("xp", 50)))
	player.feat.emit("Quête terminée : %s" % q.title, Color("ffe08a"))
	Sound.ui("levelup")


# ---------------------------------------------------------------- avancement

func is_complete(q: Dictionary) -> bool:
	if state_of(q.id) != "active" or player == null:
		return false
	match q.type:
		"item":
			var ok := player.inventory.count(Items.get_item(q.item)) >= int(q.n)
			if q.has("item2"):
				ok = ok and player.inventory.count(Items.get_item(q.item2)) >= int(q.n2)
			return ok
		"kill", "boss", "tame", "evolve", "explore":
			return int(states[q.id].progress) >= int(q.n)
		"have":
			if q.has("pop"):
				var vn := get_tree().get_first_node_in_group("village_needs")
				return vn != null and vn.members().size() >= int(q.pop)
			for id in q.items:
				var it := Items.get_item(id)
				if it and (player.inventory.count(it) > 0 or player.equipment.slots.values().has(it)):
					return true
			return false
		"room":
			var st := _story()
			return st != null and st._room_count(q.room) >= int(q.get("count", 1))
		"obelisks":
			var w := get_tree().get_first_node_in_group("world") as WorldGenerator
			if w == null:
				return false
			var lit := w.zones.filter(func(z): return z.obelisk_on).size()
			var total := w.zones.filter(func(z): return (z.obelisk as Vector2i).x >= 0).size()
			return lit >= (total if int(q.n) < 0 else int(q.n))
		"level":
			return player.level >= int(q.n)
	return false


func progress_text(q: Dictionary) -> String:
	match q.type:
		"item":
			var t := "%d / %d %s" % [mini(player.inventory.count(Items.get_item(q.item)), int(q.n)), int(q.n), Items.get_item(q.item).display_name]
			if q.has("item2"):
				t += ", %d / %d %s" % [mini(player.inventory.count(Items.get_item(q.item2)), int(q.n2)), int(q.n2), Items.get_item(q.item2).display_name]
			return t
		"kill", "boss", "tame", "evolve":
			return "%d / %d" % [mini(int(states.get(q.id, {}).get("progress", 0)), int(q.n)), int(q.n)]
		"explore":
			return "%d / %d %s" % [mini(int(states.get(q.id, {}).get("progress", 0)), int(q.n)), int(q.n),
				{"cave": "coffres de grotte", "castle": "trésors de châteaux abandonnés", "wreck": "coffres d'épaves"}.get(q.what, "coffres")]
		"have":
			if q.has("pop"):
				var vn := get_tree().get_first_node_in_group("village_needs")
				return "%d / %d habitants" % [vn.members().size() if vn else 0, int(q.pop)]
			return "fini" if is_complete(q) else "pas encore"
		"room":
			var st := _story()
			return "%d / %d" % [st._room_count(q.room) if st else 0, int(q.get("count", 1))]
		"obelisks":
			var w := get_tree().get_first_node_in_group("world") as WorldGenerator
			var lit := w.zones.filter(func(z): return z.obelisk_on).size() if w else 0
			var total := w.zones.filter(func(z): return (z.obelisk as Vector2i).x >= 0).size() if w else 0
			return "%d / %d obélisques" % [lit, total]
		"level":
			return "niveau %d / %d" % [player.level, int(q.n)]
	return ""


func _bump(type: String, enemy_id := "") -> void:
	for q in active():
		if q.type != type:
			continue
		if type == "kill" and not (q.enemies as Array).has(enemy_id):
			continue
		if type == "explore" and q.what != enemy_id:
			continue
		states[q.id].progress = int(states[q.id].progress) + 1
		if int(states[q.id].progress) == int(q.n) and player:
			player.notify.emit("Quête « %s » accomplie : retourne voir %s." % [q.title, Story.NPCS[q.npc].name])
		changed.emit()


## Un monstre vaincu (appelé par Enemy).
func on_enemy_died(e: Enemy) -> void:
	if e.data and not e.tamed:
		_bump("kill", e.data.resource_path.get_file().get_basename())


func _on_boss(_z: Dictionary, _t: String) -> void:
	_bump("boss")


func _on_cave_chest(_id: String) -> void:
	_bump("explore", "cave")


## Un coffre du monde ouvert (WorldChest) : château abandonné (« castle ») ou épave (« wreck »).
func on_chest(kind: String) -> void:
	if kind in ["castle", "wreck"]:
		_bump("explore", kind)


## Un familier apprivoisé, un habitant nommé.
func on_event(kind: String) -> void:
	_bump(kind)


func _process(delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player


# ---------------------------------------------------------------- sauvegarde

func export_state() -> Dictionary:
	return {"states": states.duplicate(true)}


func import_state(d: Dictionary) -> void:
	states = {}
	var s: Dictionary = d.get("states", {})
	for id in s:
		states[str(id)] = {"state": str(s[id].get("state", "")), "progress": int(s[id].get("progress", 0))}
	changed.emit()
