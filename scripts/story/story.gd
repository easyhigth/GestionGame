class_name Story
extends Node
## Histoire principale : « L'Éveil du Royaume », seize actes et vingt-trois personnages.
## Les données (étapes, personnages, attaques, duels) sont dans StoryData, les dialogues dans StoryDialogs.
## Ici : où sont les personnages, ce qui fait avancer l'histoire, les récompenses (compétences uniques de
## la branche Pacte, armes et équipements uniques, ressources ultra-rares), le suivi et la sauvegarde.

signal changed
signal step_done(index: int)
signal finished

const STEPS := StoryData.STEPS
const ACTS := StoryData.ACTS
const NPCS := StoryData.NPCS
const RAIDS := StoryData.RAIDS
const DUELS := StoryData.DUELS
const NATIONS := StoryData.NATIONS
const DIALOGS := StoryDialogs.DIALOGS
const OBELISK := preload("res://assets/environment/models/obelisk.glb")
const BOSS_SCENE := "res://scenes/enemies/boss.tscn"
## Où se placent les personnages de passage au village (autour du feu de camp).
const VISIT_SPOTS := {"morvain": Vector3(-3.0, 0, 2.5), "kaia": Vector3(3.5, 0, 3.0), "gorvak": Vector3(8, 0, 8),
	"lysandre": Vector3(-4, 0, -3), "edmond": Vector3(0, 0, 5), "selene": Vector3(-5, 0, 1)}

var world: WorldGenerator
var player: Player
var step := 0
var choices := {}
## Éclats : identifiant de région -> vrai.
var shards := {}
## Où sont les personnages : « camp », « village », « visit » (de passage), « captive », « gone » (partis).
var npc_state := {}
var npc_nodes := {}
var sanctuary := Vector3.INF
## Monstres de la meute encore à chasser (étape « pack »).
var pack_left := -1
var _pack: Array = []
var _raid_wait := 0.0
var _sanct_node: Node3D
var _boss: Boss
var _duel := ""
var _zones := {}
var _camps := {}
var _props := {}
var _tick := 0.0
var _banner: Label
var _banner_sub: Label
var _banner_layer: CanvasLayer


func _ready() -> void:
	add_to_group("story")
	if world == null:
		world = get_tree().get_first_node_in_group("world") as WorldGenerator
	_build_banner()
	_connect.call_deferred()
	if not SaveGame.story_state.is_empty():
		import_state.call_deferred(SaveGame.story_state)
		SaveGame.story_state = {}
	else:
		_start.call_deferred()


func _connect() -> void:
	var dm := get_tree().get_first_node_in_group("dungeons")
	if dm and not dm.boss_defeated.is_connected(_on_boss_defeated):
		dm.boss_defeated.connect(_on_boss_defeated)
	var rm := get_tree().get_first_node_in_group("raids")
	if rm and not rm.raid_ended.is_connected(_on_raid_ended):
		rm.raid_ended.connect(_on_raid_ended)


func _start() -> void:
	_sync_shards()
	_enter_step()
	_spawn_npcs()
	banner(ACTS[1], "L'Éveil du Royaume")
	changed.emit()


func current() -> Array:
	return STEPS[step] if step < STEPS.size() else []


func current_id() -> String:
	return STEPS[step][0] if step < STEPS.size() else ""


func is_done() -> bool:
	return step >= STEPS.size()


static func index_of(id: String) -> int:
	for i in STEPS.size():
		if STEPS[i][0] == id:
			return i
	return -1


## L'étape `id` est atteinte (en cours ou faite).
func reached(id: String) -> bool:
	return step >= index_of(id)


## L'étape `id` est faite.
func passed(id: String) -> bool:
	return step > index_of(id)


func _opts(s: Array) -> Dictionary:
	return s[6] if s.size() > 6 else {}


## Nombre d'éclats qu'il faut en tout (une grande bête par région qui a un donjon).
func shards_total() -> int:
	var regions := {}
	for z in world.zones:
		if (z.gate as Vector2i).x >= 0 and z.type and (z.type as RegionData).boss:
			regions[(z.type as RegionData).id] = true
	return maxi(1, regions.size())


func _sync_shards() -> void:
	for z in world.zones:
		if z.get("cleared", false) and z.type:
			shards[(z.type as RegionData).id] = true


func _on_boss_defeated(z: Dictionary, _text: String) -> void:
	if z.type == null:
		return
	var id: String = (z.type as RegionData).id
	if not shards.has(id):
		shards[id] = true
		if player:
			player.feat.emit("Éclat du Cœur d'Aube (%d / %d)" % [shards.size(), shards_total()], Color("ffe08a"))
	_check()
	changed.emit()


# ---------------------------------------------------------------- lieux

## La zone où campe un personnage (calculée une fois ; le monde est le même à chaque chargement).
func npc_zone(id: String) -> Dictionary:
	if _zones.has(id):
		return _zones[id]
	var z := {}
	var info: Dictionary = NPCS.get(id, {})
	if info.has("near"):
		z = npc_zone(str(info.near[0])) if NPCS.has(info.near[0]) else {}
	elif info.has("camp"):
		var c: Array = info.camp
		var exclude := []
		for other in c[2]:
			var oz := npc_zone(other)
			if not oz.is_empty():
				exclude.append(oz)
		z = _far_zone(c[0], exclude) if c.size() > 3 and c[3] else _pick_zone(c[0], c[1], exclude)
	_zones[id] = z
	return z


## La zone la plus proche du village parmi les régions préférées (sinon n'importe laquelle).
func _pick_zone(prefs: Array, need_gate: bool, exclude: Array) -> Dictionary:
	for pass_i in 2:
		var best := {}
		var bd := INF
		for z in world.zones:
			if z.type == null or float(z.dist) <= 0.0 or exclude.has(z):
				continue
			if need_gate and ((z.gate as Vector2i).x < 0 or (z.level as Vector2i).x < 2):
				continue
			if pass_i == 0 and not prefs.is_empty() and not prefs.has((z.type as RegionData).id):
				continue
			if float(z.dist) < bd:
				bd = z.dist
				best = z
		if not best.is_empty():
			return best
	if need_gate:
		for z in world.zones:
			if (z.gate as Vector2i).x >= 0 and not exclude.has(z):
				return z
	return {}


## Une contrée lointaine (les deux tiers du chemin vers la plus lointaine des régions préférées).
func _far_zone(prefs: Array, exclude := []) -> Dictionary:
	var zs := world.zones.filter(func(z): return z.type and float(z.dist) > 0.0 and not exclude.has(z) and prefs.has((z.type as RegionData).id))
	if zs.is_empty():
		zs = world.zones.filter(func(z): return z.type and float(z.dist) > 0.0 and not exclude.has(z))
	if zs.is_empty():
		return world.zones[0]
	zs.sort_custom(func(a, b): return float(a.dist) < float(b.dist))
	return zs[mini(zs.size() - 1, zs.size() * 2 / 3)]


## Le centre du camp d'un personnage (« sanctuaire » : le Sanctuaire de l'Éveil).
func camp_center(id: String) -> Vector3:
	if id == "sanctuaire":
		if sanctuary == Vector3.INF:
			sanctuary = _sanctuary_pos()
		return sanctuary
	if _camps.has(id):
		return _camps[id]
	var c := Vector3.INF
	var info: Dictionary = NPCS.get(id, {})
	if id == "orvane":
		c = _free_spot(world.cell_center(world.spawn_cell) + Vector3(14, 0, -10), 3.0)
	elif info.has("near"):
		var base := camp_center(str(info.near[0]))
		c = base + (info.near[1] as Vector3)
		if (info.near[1] as Vector3).length() > 0.1:
			c = _free_spot(c, 1.5)
	else:
		var z := npc_zone(id)
		if not z.is_empty():
			var camp: Array = info.get("camp", [[], false])
			if (z.gate as Vector2i).x >= 0 and camp[1]:
				c = world.cell_center(z.gate)
			elif (z.obelisk as Vector2i).x >= 0:
				c = world.cell_center(z.obelisk)
			else:
				c = Vector3(z.site.x, 0, z.site.y)
			c = _free_spot(c, 7.0)
	if c == Vector3.INF:
		c = _free_spot(world.cell_center(world.spawn_cell) + Vector3(20, 0, 20), 6.0)
	if id != "cael":
		_camps[id] = c
	return c


func _npc_pos(id: String, where: String) -> Vector3:
	var c := world.cell_center(world.spawn_cell)
	match where:
		"village":
			return c + Vector3(2.5, 0, -2.0)
		"visit":
			return _free_spot(c + VISIT_SPOTS.get(id, Vector3(6, 0, -6)), 1.5)
		"captive":
			return _free_spot(camp_center("morvain") + Vector3(3, 0, 3), 1.5)
	if id == "orvane":
		return camp_center(id) + Vector3(1.4, 0, 0)
	if NPCS.get(id, {}).has("near"):
		return camp_center(id)
	return _free_spot(camp_center(id), 3.0)


func _free_spot(center: Vector3, r: float) -> Vector3:
	for i in 40:
		var a := randf() * TAU
		var p := center + Vector3(cos(a), 0, sin(a)) * randf_range(r * 0.5, r)
		p.y = world.ground_height_at(p + Vector3(0, 30, 0))
		if world.is_walkable(p) and world.build.column(world.cell_at(p)).is_empty():
			return p
	center.y = world.ground_height_at(center + Vector3(0, 30, 0))
	return center


# ---------------------------------------------------------------- personnages

## Où chaque personnage doit être à cette étape (absent = pas là).
func _npc_need() -> Dictionary:
	var need := {}
	var cur := current_id()
	need["orvane"] = "village" if passed("orvane_libre") else "camp"
	if reached("glou"):
		need["glou"] = "village" if passed("glou_2") else "camp"
	if reached("grik"):
		need["grik"] = "village" if choices.get("grik", "") == "pacte" else "camp"
	if reached("pip"):
		need["pip"] = "village" if choices.get("grik", "") == "pacte" else "camp"
	if reached("ulric"):
		need["ulric"] = "camp"
	# Maëlle : au village, sauf quand Morvain la retient
	if reached("maelle") and not (reached("trahison") and not reached("maelle_sauvee")):
		need["maelle"] = "captive" if cur == "maelle_sauvee" else "village"
	if reached("liora"):
		need["liora"] = "camp"
	if reached("kaede") and choices.get("kaede", "") != "voyage":
		need["kaede"] = "village" if choices.get("kaede", "") == "join" else "camp"
	if cur == "duel_ren" and _duel != "ren":
		need["ren"] = "camp"
	if cur in ["kaia", "kaia_2", "kaia_3"]:
		need["kaia"] = "visit"
	if reached("borin"):
		need["borin"] = "village" if choices.get("borin", "") == "join" else "camp"
	if reached("brunhild"):
		need["brunhild"] = "camp"
	if reached("lysandre"):
		var l: String = choices.get("lysandre", "")
		if l == "join":
			need["lysandre"] = "village"
		elif cur == "lysandre_secret":
			need["lysandre"] = "visit"
		elif l != "map":
			need["lysandre"] = "camp"
	if reached("zzar"):
		need["zzar"] = "camp"
	if reached("gorvak"):
		var g: String = choices.get("gorvak", "")
		need["gorvak"] = "visit" if g == "" else ("village" if g == "accueillir" else "camp")
	if reached("sylve"):
		need["sylve"] = "village" if passed("sylve") else "visit"
	if reached("alderic") and choices.get("alderic", "") != "blade":
		need["alderic"] = "village" if choices.get("alderic", "") == "join" else "camp"
	if reached("edmond"):
		need["edmond"] = "visit" if cur == "edmond_2" else "camp"
	if reached("morvain") and not reached("trahison"):
		need["morvain"] = "visit"
	elif cur == "templiers" or (cur == "duel_morvain" and _duel != "morvain"):
		need["morvain"] = "camp"
	if reached("selene"):
		need["selene"] = "visit" if reached("selene_3") else "camp"
	if reached("vharok"):
		need["vharok"] = "camp"
	if cur in ["aurele", "aurele_2"] or (cur == "duel_aurele" and _duel != "aurele"):
		need["aurele"] = "camp"
	if cur == "cael":
		need["cael"] = "camp"
	return need


## Fait apparaître (ou partir) les personnages dont l'histoire a besoin.
func _spawn_npcs() -> void:
	var need := _npc_need()
	for id in npc_nodes.keys():
		var n = npc_nodes[id]
		var ok: bool = n != null and is_instance_valid(n)
		# un personnage installé au village y reste (sauf Maëlle, enlevée par Morvain)
		if ok and npc_state.get(id, "") == "village" and (need.has(id) or id != "maelle"):
			continue
		if not need.has(id) or not ok:
			if ok:
				n.queue_free()
			npc_nodes.erase(id)
			if not need.has(id) and npc_state.has(id):
				npc_state[id] = "gone"
	for id in need:
		var where: String = need[id]
		var n = npc_nodes.get(id)
		if n and is_instance_valid(n) and (npc_state.get(id, "") == where or npc_state.get(id, "") == "village"):
			continue
		if n and is_instance_valid(n):
			n.queue_free()
		npc_state[id] = where
		npc_nodes[id] = _make_npc(id, where)
	_update_props()


func _npc_race(id: String) -> String:
	var info: Dictionary = NPCS[id]
	if id == "pip" and passed("pip_eveil"):
		return info.race_alt
	return info.race


func _make_npc(id: String, where: String) -> Node3D:
	var info: Dictionary = NPCS[id]
	var v := world.villager_scene.instantiate() as Villager
	v.race = load(_npc_race(id))
	v.villager_name = info.name
	v.level = int(info.level) + (6 if id == "pip" and passed("pip_eveil") else 0)
	v.set_meta("story", id)
	v.talents = (info.talents as Dictionary).duplicate()
	var village := where == "village"
	v.stranger = not village
	v.wander_radius = 4.0 if village else (0.3 if id in ["orvane", "cael", "maelle"] else 1.5)
	var pos := _npc_pos(id, where)
	world.load_area(pos)
	world.get_node("Village").add_child(v)
	if village and id != "maelle":
		v.join_village(world.cell_center(world.spawn_cell))
	else:
		v.global_position = pos
		v.home = pos
		if village:
			v.stranger = false
	for it_id in info.kit:
		var it := Items.get_item(it_id)
		if it:
			v.equipment.equip(it)
	if where == "camp" and not (id in ["orvane", "cael"]) and not info.has("near") and world.campfire_scene:
		var fire := world.campfire_scene.instantiate() as Node3D
		world.get_node("Village").add_child(fire)
		fire.global_position = pos + Vector3(1.6, 0, 1.2)
		fire.global_position.y = world.ground_height_at(fire.global_position + Vector3(0, 3, 0))
		v.tree_exiting.connect(fire.queue_free)
	return v


## Le cristal d'Orvane (tant qu'il est enchaîné).
func _update_props() -> void:
	var want := not passed("orvane_libre")
	var n = _props.get("crystal")
	if want and (n == null or not is_instance_valid(n)):
		var c := Node3D.new()
		c.name = "CristalOrvane"
		world.get_node("Village").add_child(c)
		c.global_position = camp_center("orvane")
		var o := OBELISK.instantiate() as Node3D
		c.add_child(o)
		o.scale = Vector3.ONE * 0.7
		var l := OmniLight3D.new()
		l.light_color = Color("b08aff")
		l.light_energy = 1.4
		l.omni_range = 7.0
		l.position.y = 2.5
		c.add_child(l)
		var lab := Label3D.new()
		lab.text = "Cristal enchaîné"
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.font_size = 36
		lab.pixel_size = 0.01
		lab.outline_size = 8
		lab.modulate = Color("d8c0ff")
		lab.position.y = 4.4
		c.add_child(lab)
		_props["crystal"] = c
	elif not want and n and is_instance_valid(n):
		VoxelBurst.spawn(world, n.global_position + Vector3(0, 2, 0), Color("c8a8ff"), 60, 6.0, 0.14, 1.2, "sphere", 2.0, false)
		n.queue_free()
		_props.erase("crystal")


## Le personnage de l'histoire (ou null).
func npc(id: String) -> Node3D:
	var n = npc_nodes.get(id)
	return n if n and is_instance_valid(n) else null


## Des habitants de plus au village (gobelins de Grik, orcs de Gorvak...).
func _recruit(race_path: String, n: int, level: int, near: Vector3) -> void:
	var race := load(race_path) as RaceData
	for i in n:
		var v := world.villager_scene.instantiate() as Villager
		v.race = race
		v.level = level
		world.get_node("Village").add_child(v)
		v.global_position = near
		v.join_village(world.cell_center(world.spawn_cell))


# ---------------------------------------------------------------- dialogues

## Appelé quand le héros parle (E) à un personnage de l'histoire. Vrai si un dialogue s'ouvre.
func try_talk(v: Node) -> bool:
	if v == null or not v.has_meta("story"):
		return false
	var id: String = v.get_meta("story")
	var d := _dialog_for(id)
	# au village, sans rien à dire : E ouvre son équipement comme pour les autres habitants
	if d == "" or (d.ends_with("_idle") and not v.get("stranger")):
		return false
	var dlg := get_tree().get_first_node_in_group("story_dialog")
	if dlg == null:
		return false
	dlg.open(d, v)
	return true


func _dialog_for(npc_id: String) -> String:
	var s := current()
	if not s.is_empty() and s[5] is String and s[5] == npc_id:
		match s[4]:
			"talk":
				var o := _opts(s)
				if o.has("item") and player.inventory.count(Items.get_item(o.item)) < int(o.n):
					return "wait_" + s[0]
				if s[0] == "coeur" and not _has_room("temple"):
					return "wait_coeur"
				return s[0]
			"duel":
				return s[0] if _duel == "" else ""
			_:
				if DIALOGS.has("wait_" + s[0]):
					return "wait_" + s[0]
	# les étapes « pack » d'un autre camp : celui qui y vit en parle
	if not s.is_empty() and s[4] == "pack" and DIALOGS.has("wait_" + s[0]):
		var near: Array = NPCS.get(npc_id, {}).get("near", [])
		if not near.is_empty() and near[0] == s[5]:
			return "wait_" + s[0]
	var idle: String = npc_id + "_idle"
	return idle if DIALOGS.has(idle) else ""


## Fin d'un dialogue (et choix fait).
func dialog_done(id: String, choice: String) -> void:
	if id != current_id():
		return
	var s := current()
	if s[4] == "duel":
		_spawn_duel(str(s[5]))
		return
	var o := _opts(s)
	if o.has("item"):
		player.inventory.remove(Items.get_item(o.item), int(o.n))
	if choice != "":
		choices[id] = choice
	match id:
		"grik_2":
			choices["grik"] = choice
			if choice == "pacte":
				_recruit("res://data/races/gobelin.tres", 3, 2, camp_center("grik"))
				player.notify.emit("Pacte des gobelins : Grik, Pip et trois gobelins partent pour ton village.")
			else:
				_give([["baies", 12], ["leather", 6], ["viande_cuite", 4]])
				player.notify.emit("Les gobelins restent dans leurs bois, alliés pour toujours. Ils t'offrent des provisions.")
		"kaede_3":
			choices["kaede"] = choice
			if choice == "join":
				player.notify.emit("Kaede rejoint ton village : une lame redoutable pour tes gardes.")
			else:
				_give([["horned_helmet", 1], ["piece_or", 150]])
				player.notify.emit("Kaede te confie le casque de son père et part sur les traces de l'homme au soleil brodé.")
				_leave("kaede")
		"borin_fer":
			choices["borin"] = choice
			if choice == "join":
				player.notify.emit("Borin rejoint ton village : ton meilleur forgeron.")
			else:
				_give([["pioche_fer", 1], ["lingot_or", 3], ["mithril_brut", 2]])
				player.notify.emit("Borin reste dans ses montagnes et t'offre une pioche de fer, de l'or et du mithril.")
		"perles":
			choices["lysandre"] = choice
			if choice == "map":
				for z in world.zones:
					if (z.obelisk as Vector2i).x >= 0:
						world.reveal(world.cell_center(z.obelisk), 6)
					z.discovered = true
				player.inventory.add(Items.get_item("piece_or"), 300)
				player.notify.emit("La carte des anciens révèle tous les obélisques. +300 pièces d'or.")
				_leave("lysandre")
			else:
				player.notify.emit("Lysandre s'installe au village : le marchand ambulant vient plus souvent, à meilleur prix.")
		"gorvak":
			choices["gorvak"] = choice
			_give([["hache_horde", 1]])
			if choice == "accueillir":
				var at: Vector3 = npc("gorvak").global_position if npc("gorvak") else world.cell_center(world.spawn_cell)
				_recruit("res://data/races/orc.tres", 3, 5, at)
				player.notify.emit("Gorvak et trois orcs s'installent au village.")
			else:
				player.notify.emit("Les orcs s'installent dans une prairie voisine, en paix avec ton village.")
		"gorvak_ble":
			_give([["graines_ble", 10]])
			player.notify.emit("Les orcs apprennent à cultiver. Ils te rendent des graines de leur première récolte.")
		"pip_eveil":
			# Pip devient un hobgobelin
			var n := npc("pip")
			if n:
				VoxelBurst.spawn(world, n.global_position + Vector3(0, 1, 0), Color("c8f08a"), 50, 5.0, 0.12, 1.0, "up", 3.0, false)
				n.queue_free()
			npc_nodes.erase("pip")
			npc_state.erase("pip")
		"alderic_2":
			choices["alderic"] = choice
			if choice == "blade":
				_give([["lame_aube", 1]])
				player.notify.emit("Aldéric te confie la Lame d'Aube, puis repart plaider ta cause à la cour.")
				_leave("alderic")
			else:
				player.notify.emit("Sire Aldéric rejoint ton village : un garde (ou un compagnon) redoutable.")
		"coeur":
			_make_sanctuary()
		"cael":
			choices["cael"] = choice
			if choice == "liberer":
				_give([["cristal_aube", 2], ["larme_esprit", 2]])
				player.notify.emit("L'âme de Caël s'envole, apaisée. Là où elle est passée, deux cristaux d'aube sont tombés.")
			else:
				_give([["orichalque", 2], ["fragment_brume", 4]])
				player.notify.emit("Tu portes désormais l'âme de Caël. Son pouvoir est tien, et un peu de sa Brume aussi.")
			var n := npc("cael")
			if n:
				VoxelBurst.spawn(world, n.global_position + Vector3(0, 1, 0), Color("b8c8ff"), 70, 6.0, 0.12, 1.4, "up", 1.0, false)
		"epilogue":
			choices["nation"] = choice
	_advance()


func _give(list: Array) -> void:
	for pair in list:
		var it := Items.get_item(pair[0])
		if it:
			player.inventory.add(it, int(pair[1]))
			if it.rarity >= ItemData.Rarity.RARE:
				player.feat.emit("Obtenu : %s%s" % [it.display_name, " ×%d" % pair[1] if int(pair[1]) > 1 else ""], it.rarity_color())


## Un personnage s'en va (petite gerbe de lumière).
func _leave(id: String) -> void:
	var n := npc(id)
	if n:
		VoxelBurst.spawn(n, n.global_position + Vector3(0, 1, 0), Color(1, 0.85, 0.5), 20, 3.0, 0.1, 0.6, "up", 5.0, false)
		n.queue_free()
	npc_nodes.erase(id)
	npc_state[id] = "gone"


func _has_room(type_id: String) -> bool:
	return _room_count(type_id) > 0


func _room_count(type_id: String) -> int:
	var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
	if k == null:
		return 0
	var n := 0
	for r in k.typed_rooms():
		if (r.type as RoomTypeData).id == type_id:
			n += 1
	return n


## Le héros possède (sac ou équipement) un de ces objets.
func _has_any(ids: Array) -> bool:
	for id in ids:
		var it := Items.get_item(id)
		if it and (player.inventory.count(it) > 0 or player.equipment.slots.values().has(it)):
			return true
	return false


## Nom de la nation (après l'épilogue).
func nation_name() -> String:
	return NATIONS.get(choices.get("nation", ""), "")


# ---------------------------------------------------------------- avancement

func _advance() -> void:
	var before_act: int = current()[1] if not is_done() else 0
	var reward: Dictionary = _opts(current()).get("reward", {})
	step_done.emit(step)
	step += 1
	if player:
		var done_title: String = STEPS[step - 1][2]
		player.feat.emit("Histoire : %s ✔" % done_title, Color("ffe08a"))
		player.gain_xp(30 + 12 * before_act)
		_give(reward.get("items", []))
		if reward.has("skill"):
			player.grant_story_talent(reward.skill)
		if reward.get("evolve", false):
			player.evolve_hero()
	if is_done():
		banner("Épilogue", nation_name() if nation_name() != "" else "Le royaume s'éveille")
		_finish()
	else:
		_enter_step()
		var act: int = current()[1]
		if act != before_act:
			banner(ACTS[act], current()[2])
		elif player:
			player.notify.emit("Histoire : %s" % current()[2])
	_spawn_npcs()
	_check()
	changed.emit()


## Préparation d'une nouvelle étape.
func _enter_step() -> void:
	var s := current()
	if s.is_empty():
		return
	match s[4]:
		"pack":
			pack_left = int(_opts(s).get("n", 5))
			_pack.clear()
			if s[5] == "sanctuaire":
				_make_sanctuary()
		"raid":
			_raid_wait = 4.0
			if s[0] == "trahison":
				_leave("morvain")
		"duel":
			_duel = ""


## Objectifs vérifiés d'après l'état du jeu.
func _check() -> void:
	if is_done() or world == null:
		return
	var s := current()
	var ok := false
	match s[4]:
		"obelisks":
			ok = world.zones.filter(func(z): return z.obelisk_on).size() >= int(s[5])
		"boss_of":
			var z := npc_zone(str(s[5]))
			ok = z.is_empty() or z.get("cleared", false)
		"shards":
			ok = shards.size() >= _shards_needed(s)
		"room":
			var parts := str(s[5]).split(":")
			ok = _room_count(parts[0]) >= (int(parts[1]) if parts.size() > 1 else 1)
		"pop":
			var vn := get_tree().get_first_node_in_group("village_needs")
			ok = vn != null and vn.members().size() >= int(s[5])
		"pack":
			ok = pack_left == 0
		"have_any":
			ok = player != null and _has_any(s[5])
	if ok:
		_advance()


func _shards_needed(s: Array) -> int:
	return shards_total() if int(s[5]) < 0 else mini(int(s[5]), shards_total())


func _process(delta: float) -> void:
	if world == null:
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
		return
	_raid_wait -= delta
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 1.0
	_check()
	# « ! » au-dessus du personnage à qui parler
	var s := current()
	for id in npc_nodes:
		var n = npc_nodes[id]
		if n and is_instance_valid(n) and n.has_method("set_quest_mark"):
			var mark: bool = not s.is_empty() and s[5] is String and s[5] == id and s[4] in ["talk", "duel"]
			n.set_quest_mark("!" if mark else "")
	if s.is_empty():
		return
	match s[4]:
		"pack":
			_pack_step()
		"raid":
			_raid_step(str(s[5]))
		"duel":
			_duel_step(str(s[5]))


# ---------------------------------------------------------------- meute, attaques, duels

## La meute apparaît quand le héros approche du camp ; chaque bête vaincue compte.
func _pack_step() -> void:
	_pack = _pack.filter(func(e): return is_instance_valid(e) and e.is_alive())
	var s := current()
	var c := camp_center(str(s[5]))
	if pack_left <= 0 or not _pack.is_empty() or player.global_position.distance_to(c) > 60.0:
		return
	world.load_area(c)
	var types: Array = _opts(s).get("types", ["loup"])
	var lv := _pack_level(str(s[5]))
	var scene := load("res://scenes/enemies/enemy.tscn") as PackedScene
	for i in pack_left:
		var e := scene.instantiate() as Enemy
		e.data = load("res://data/enemies/%s.tres" % types[i % types.size()])
		e.level = maxi(1, lv + randi() % 2)
		e.set_meta("story_pack", true)
		add_child(e)
		var a := TAU * i / float(pack_left)
		var p := c + Vector3(cos(a), 0, sin(a)) * randf_range(7.0, 11.0)
		p.y = world.ground_height_at(p + Vector3(0, 30, 0))
		e.global_position = p
		e.home = c
		e.defeated.connect(_on_pack_kill)
		_pack.append(e)


func _pack_level(at: String) -> int:
	if at == "sanctuaire":
		return maxi(player.level, 8)
	var z := npc_zone(at)
	var lv: Vector2i = z.get("level", Vector2i(1, 2)) if not z.is_empty() else Vector2i(1, 2)
	return maxi(lv.x, mini(player.level - 1, lv.y))


func _on_pack_kill() -> void:
	if current_id() == "" or current()[4] != "pack":
		return
	pack_left = maxi(0, pack_left - 1)
	changed.emit()
	if pack_left == 0:
		_check()


func _raid_step(key: String) -> void:
	var rm := get_tree().get_first_node_in_group("raids")
	if rm == null or not rm.raid.is_empty() or _raid_wait > 0.0:
		return
	var r: Dictionary = RAIDS[key].duplicate()
	r["key"] = key
	rm.announce(r)


func _on_raid_ended(r: Dictionary, repelled: bool, _text: String) -> void:
	var s := current()
	if s.is_empty() or s[4] != "raid" or r.get("story", "") != s[5]:
		return
	if repelled:
		_advance()
	else:
		_raid_wait = 60.0
		if player:
			player.notify.emit("%s s'est retirée... mais elle reviendra dans une minute. Prépare tes défenses !" % r.name)


func _duel_pos(key: String) -> Vector3:
	return sanctuary if key == "brume" else camp_center(key)


func _duel_step(key: String) -> void:
	if key == "brume" and (_sanct_node == null or not is_instance_valid(_sanct_node)):
		_make_sanctuary()
	if _duel == key and _boss and is_instance_valid(_boss):
		return
	# le boss disparu (chargement) : il reviendra
	if _duel == key:
		_duel = ""
		_spawn_npcs()
	var d := player.global_position.distance_to(_duel_pos(key))
	if d < (14.0 if key == "brume" else 4.0):
		_spawn_duel(key)


## Niveau d'un boss de l'histoire : il suit le héros (le Seigneur de la Brume dépasse le monde entier).
func _duel_level(key: String) -> int:
	var top := 1
	for z in world.zones:
		top = maxi(top, (z.level as Vector2i).y)
	match key:
		"ren":
			var z := npc_zone("kaede")
			return maxi(player.level, (z.get("level", Vector2i(3, 4)) as Vector2i).y) + 1
		"morvain":
			return player.level + 2
		"aurele":
			return player.level + 3
	return maxi(top + 3, player.level + 4)


func _spawn_duel(key: String) -> void:
	if _duel == key and _boss and is_instance_valid(_boss):
		return
	var info: Dictionary = DUELS[key]
	var at := _duel_pos(key)
	var n := npc(key)
	if n:
		at = n.global_position
		VoxelBurst.spawn(world, at + Vector3(0, 1, 0), Color("8a60c0"), 40, 5.0, 0.12, 1.0, "sphere", 2.0, false)
		n.queue_free()
		npc_nodes.erase(key)
	world.load_area(at)
	# chargés ici (et non au démarrage) : la scène du boss dépend de scripts qui dépendent de l'histoire
	_boss = (load(BOSS_SCENE) as PackedScene).instantiate() as Boss
	_boss.data = load(info.data) as EnemyData
	_boss.level = _duel_level(key)
	_boss.power = float(info.power)
	_boss.powers = PackedStringArray(info.powers)
	var adds: Array[EnemyData] = []
	for id in info.summons:
		var e := load("res://data/enemies/%s.tres" % id) as EnemyData
		if e:
			adds.append(e)
	_boss.summons = adds
	_boss.title = info.title
	world.add_child(_boss)
	_boss.global_position = at
	_boss.home = at
	_boss.died_at.connect(_on_duel_won.bind(key))
	_boss.wake()
	_duel = key
	banner(info.title, info.sub)
	var we := get_tree().get_first_node_in_group("weather") as Weather
	if we:
		we.set_kind("orage")
	var dm := get_tree().get_first_node_in_group("dungeons")
	if dm:
		dm.boss_awoken.emit(_boss, _boss.title)


func _on_duel_won(pos: Vector3, key: String) -> void:
	if current_id() == "" or current()[4] != "duel" or current()[5] != key:
		return
	var we := get_tree().get_first_node_in_group("weather") as Weather
	if we:
		we.set_kind("clair")
	match key:
		"brume":
			for z in world.zones:
				z.obelisk_on = true
			player.gain_xp(1500)
			world.spawn_pickup(Items.get_item("lingot_or"), pos + Vector3(1, 0, 0), 5)
			world.spawn_pickup(Items.get_item("piece_or"), pos + Vector3(-1, 0, 0), 500)
		"morvain":
			player.gain_xp(600)
			world.spawn_pickup(Items.get_item("piece_or"), pos + Vector3(-1, 0, 0), 250)
		_:
			player.gain_xp(300)
	_advance()


# ---------------------------------------------------------------- sanctuaire

## Le sanctuaire : sur la terre ferme, dans une zone lointaine, là où le cercle d'obélisques tient hors de l'eau.
func _sanctuary_pos() -> Vector3:
	var zs := world.zones.filter(func(z): return z.type and (z.type as RegionData).id != "volcan" and float(z.dist) > 0.0)
	zs.sort_custom(func(a, b): return float(a.dist) > float(b.dist))
	var best := Vector3.INF
	var best_score := -1
	for z in zs.slice(0, 5):
		var site := Vector3(z.site.x, 0, z.site.y)
		for i in 40:
			var a := randf() * TAU
			var c := site + Vector3(cos(a), 0, sin(a)) * randf_range(0.0, 30.0)
			var score := 0
			for j in 12:
				var b := TAU * j / 12.0
				for r in [0.0, 5.0, 9.0, 11.0]:
					var p: Vector3 = c + Vector3(cos(b), 0, sin(b)) * r
					var t := world.terrain_type(world.cell_at(p))
					if t != WorldGenerator.WATER and t != WorldGenerator.DEEP:
						score += 1
			if score > best_score:
				best_score = score
				best = c
		if best_score >= 46:
			break
	best.y = world.ground_height_at(best + Vector3(0, 30, 0))
	return best


func _make_sanctuary() -> void:
	if sanctuary == Vector3.INF:
		sanctuary = _sanctuary_pos()
	if _sanct_node and is_instance_valid(_sanct_node):
		return
	world.load_area(sanctuary)
	_sanct_node = Node3D.new()
	_sanct_node.name = "SanctuaireEveil"
	world.add_child(_sanct_node)
	_sanct_node.global_position = sanctuary
	for i in 8:
		var a := TAU * i / 8.0
		var o := OBELISK.instantiate() as Node3D
		_sanct_node.add_child(o)
		var p := sanctuary + Vector3(cos(a), 0, sin(a)) * 9.0
		p.y = world.ground_height_at(p + Vector3(0, 30, 0))
		o.global_position = p
		o.scale = Vector3.ONE * 0.8
	var l := OmniLight3D.new()
	l.light_color = Color("b08aff")
	l.light_energy = 2.0
	l.omni_range = 16.0
	l.position.y = 4.0
	_sanct_node.add_child(l)
	var lab := Label3D.new()
	lab.text = "Sanctuaire de l'Éveil"
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.font_size = 48
	lab.pixel_size = 0.01
	lab.outline_size = 10
	lab.modulate = Color("d8c0ff")
	lab.position.y = 6.0
	_sanct_node.add_child(lab)


func _finish() -> void:
	player.notify.emit("Fin de l'histoire principale ! %s est née. Tous les obélisques brillent ; tes habitants sont plus heureux." % (nation_name() if nation_name() != "" else "Ta nation"))
	finished.emit()


## Le royaume est « éveillé » (bonus de bonheur).
func awakened() -> bool:
	return is_done()


# ---------------------------------------------------------------- journal, carte, suivi

## Où aller pour l'objectif en cours (INF si rien de précis).
func target_pos() -> Vector3:
	var s := current()
	if s.is_empty():
		return Vector3.INF
	match s[4]:
		"talk":
			var n := npc(str(s[5]))
			if n:
				return n.global_position
			return _npc_pos(str(s[5]), npc_state.get(str(s[5]), "camp"))
		"boss_of":
			var z := npc_zone(str(s[5]))
			return world.cell_center(z.gate) if not z.is_empty() and (z.gate as Vector2i).x >= 0 else Vector3.INF
		"pack":
			return camp_center(str(s[5]))
		"raid":
			var rm := get_tree().get_first_node_in_group("raids")
			if rm and not rm.raid.is_empty():
				return rm.raid.spawn
			return world.cell_center(world.spawn_cell)
		"duel":
			if _boss and is_instance_valid(_boss):
				return _boss.global_position
			var n := npc(str(s[5]))
			return n.global_position if n else _duel_pos(str(s[5]))
	return Vector3.INF


## Ligne de suivi à l'écran.
func tracker_text() -> String:
	if is_done():
		return ""
	var s := current()
	var t: String = s[2]
	match s[4]:
		"obelisks":
			t += " (%d / %d)" % [world.zones.filter(func(z): return z.obelisk_on).size(), int(s[5])]
		"shards":
			t += " (%d / %d)" % [shards.size(), _shards_needed(s)]
		"pack":
			var n := int(_opts(s).get("n", 5))
			t += " (%d / %d)" % [n - maxi(pack_left, 0), n]
		"pop":
			var vn := get_tree().get_first_node_in_group("village_needs")
			t += " (%d / %d)" % [vn.members().size() if vn else 0, int(s[5])]
		"talk":
			var o := _opts(s)
			if o.has("item") and player:
				t += " (%d / %d)" % [mini(player.inventory.count(Items.get_item(o.item)), int(o.n)), int(o.n)]
	var tp := target_pos()
	if tp != Vector3.INF and player:
		var d := Vector2(tp.x - player.global_position.x, tp.z - player.global_position.z)
		if d.length() > 6.0:
			t += "  ·  %d m %s" % [roundi(d.length()), QuestBoard._direction(player.global_position, tp)]
	return t


# ---------------------------------------------------------------- bannière (titres d'acte)

func _build_banner() -> void:
	_banner_layer = CanvasLayer.new()
	# sous les fenêtres (journal, carte...), au-dessus du monde
	_banner_layer.layer = 0
	add_child(_banner_layer)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.offset_left = -400
	box.offset_right = 400
	box.offset_top = 178
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_layer.add_child(box)
	_banner = Label.new()
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 34)
	_banner.add_theme_color_override("font_color", Color("ffe08a"))
	_banner.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.08))
	_banner.add_theme_constant_override("outline_size", 10)
	box.add_child(_banner)
	_banner_sub = Label.new()
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_sub.add_theme_font_size_override("font_size", 16)
	_banner_sub.add_theme_color_override("font_color", Color("f0e6d2"))
	_banner_sub.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.08))
	_banner_sub.add_theme_constant_override("outline_size", 6)
	box.add_child(_banner_sub)
	box.modulate.a = 0.0


## Grand titre au milieu de l'écran, qui apparaît puis s'efface.
func banner(title: String, sub: String) -> void:
	_banner.text = title
	_banner_sub.text = sub
	var box := _banner.get_parent() as Control
	var tw := create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.8)
	tw.tween_interval(3.5)
	tw.tween_property(box, "modulate:a", 0.0, 1.2)
	Sound.ui("talent")


# ---------------------------------------------------------------- sauvegarde

const VERSION := 3


func export_state() -> Dictionary:
	return {"v": VERSION, "step": step, "choices": choices.duplicate(), "shards": shards.keys(), "pack_left": pack_left,
		"gone": npc_state.keys().filter(func(id): return npc_state[id] == "gone"),
		"sanctuary": [sanctuary.x, sanctuary.y, sanctuary.z] if sanctuary != Vector3.INF else []}


func import_state(d: Dictionary) -> void:
	var old := int(d.get("v", 1)) < VERSION
	# une sauvegarde d'une ancienne version de l'histoire : on recommence la nouvelle depuis le début
	step = 0 if old else int(d.get("step", 0))
	choices = {} if old else (d.get("choices", {}) as Dictionary).duplicate()
	pack_left = -1 if old else int(d.get("pack_left", -1))
	shards = {}
	for id in d.get("shards", []):
		shards[str(id)] = true
	var sp: Array = [] if old else d.get("sanctuary", [])
	sanctuary = Vector3(sp[0], sp[1], sp[2]) if sp.size() == 3 else Vector3.INF
	for id in npc_nodes:
		if is_instance_valid(npc_nodes[id]):
			npc_nodes[id].queue_free()
	npc_nodes.clear()
	npc_state.clear()
	if not old:
		for id in d.get("gone", []):
			npc_state[str(id)] = "gone"
	# les habitants de l'histoire déjà au village ont été rechargés avec les autres habitants
	for v in get_tree().get_nodes_in_group("villagers"):
		var id := _story_id_of(v)
		if id != "":
			v.set_meta("story", id)
			npc_nodes[id] = v
			npc_state[id] = "village"
	_sync_shards()
	var s := current()
	if not s.is_empty() and s[4] == "pack" and pack_left < 0:
		pack_left = int(_opts(s).get("n", 5))
	if not s.is_empty() and s[4] == "raid":
		_raid_wait = 10.0
	if not s.is_empty() and s[4] == "pack" and s[5] == "sanctuaire" or current_id() in ["sanctuaire", "cael"]:
		_make_sanctuary()
	_spawn_npcs()
	if old and player:
		player.notify.emit("L'histoire principale a été réécrite : elle recommence au premier acte (tes éclats sont conservés).")
	changed.emit()


func _story_id_of(v: Node) -> String:
	for id in NPCS:
		var info: Dictionary = NPCS[id]
		if info.name == v.villager_name and v.race:
			var rp := (v.race as RaceData).resource_path
			if rp == info.race or rp == info.get("race_alt", ""):
				return id
	return ""
