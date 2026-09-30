class_name Story
extends Node
## Histoire principale : « L'Éveil du Royaume », en trois actes.
## Jadis, le Cœur d'Aube nourrissait les obélisques et protégeait le royaume. Le Seigneur de la Brume
## l'a brisé en éclats, avalés par les huit grandes bêtes des régions (les boss des donjons).
## Maëlle l'Érudite attend « l'Éveillé » ; Sire Aldéric et Lysandre la marchande l'aideront.
## Les étapes sont dans STEPS ; les dialogues dans DIALOGS ; le journal (O) montre où l'on en est.

signal changed
signal step_done(index: int)
signal finished

## [identifiant, acte, titre, conseil, type, paramètre]
## Types : « talk » (parler à un personnage), « obelisks » (nombre), « boss_of » (vaincre le boss de la zone
## d'un personnage), « shards » (nombre d'éclats, -1 = tous), « room » (type de pièce), « final » (boss final).
const STEPS := [
	["intro", 1, "Parle à la voyageuse près du feu", "Une érudite t'attend au village : approche-toi et appuie sur E.", "talk", "maelle"],
	["obelisques", 1, "Éveille 3 obélisques", "Les obélisques s'allument quand on s'en approche. Explore les zones autour du village.", "obelisks", 3],
	["maelle_2", 1, "Retourne voir Maëlle", "Raconte-lui ce que tu as vu près des obélisques.", "talk", "maelle"],
	["alderic", 1, "Trouve Sire Aldéric", "Son camp est marqué d'une étoile sur la carte (M).", "talk", "alderic"],
	["bete", 1, "Vaincs la bête du donjon voisin", "Le donjon de la zone d'Aldéric (carré rouge sur la carte). Son boss garde un éclat du Cœur.", "boss_of", "alderic"],
	["alderic_2", 1, "Retourne voir Aldéric", "Il t'attend à son camp.", "talk", "alderic"],
	["eclats_4", 2, "Rassemble 4 éclats du Cœur", "Chaque grande bête (boss de donjon) d'une région différente garde un éclat.", "shards", 4],
	["maelle_3", 2, "Montre les éclats à Maëlle", "Elle est au village.", "talk", "maelle"],
	["lysandre", 2, "Trouve Lysandre la marchande", "Elle voyage dans une contrée lointaine (étoile sur la carte).", "talk", "lysandre"],
	["perles", 2, "Rapporte 5 perles à Lysandre", "Les perles se trouvent au fond des eaux profondes : pêche, ou coffres des grottes sous-marines.", "talk", "lysandre"],
	["eclats_tous", 3, "Rassemble tous les éclats du Cœur", "Il reste des grandes bêtes à vaincre, une par région.", "shards", -1],
	["temple", 3, "Construis un temple", "Pièce fermée avec un autel et 2 bougeoirs : c'est là que le Cœur pourra renaître.", "room", "temple"],
	["coeur", 3, "Apporte les éclats à Maëlle", "Au village, près du temple.", "talk", "maelle"],
	["sanctuaire", 3, "Affronte le Seigneur de la Brume", "Au Sanctuaire de l'Éveil (étoile sur la carte), avec le Cœur d'Aube.", "final", ""],
	["epilogue", 3, "Retourne voir Maëlle", "Le royaume s'éveille : elle t'attend au village.", "talk", "maelle"],
]
const ACTS := {1: "Acte I — Le réveil", 2: "Acte II — Les éclats", 3: "Acte III — Le Cœur d'Aube"}

## Personnages : nom, titre, race, niveau, équipement, couleur du nom.
const NPCS := {
	"maelle": {"name": "Maëlle", "title": "l'Érudite", "race": "res://data/races/elfe.tres", "level": 6,
		"kit": ["staff", "mage_hat", "mage_robe", "cape_blue"], "color": Color("9ad8ff")},
	"alderic": {"name": "Aldéric", "title": "chevalier déchu", "race": "res://data/races/humain.tres", "level": 9,
		"kit": ["sword_iron", "shield_iron", "iron_armor", "iron_helmet", "iron_gauntlets", "iron_greaves", "cape_red"], "color": Color("ffb86a")},
	"lysandre": {"name": "Lysandre", "title": "la marchande", "race": "res://data/races/homme_lezard.tres", "level": 7,
		"kit": ["dagger", "leather_cap", "leather_armor", "cape_red"], "color": Color("c8ff8a")},
}

## Dialogues : [[qui, texte], ...] ; « hero » = le héros. Choix : [[texte, clé], ...].
const DIALOGS := {
	"intro": {"pages": [
		["maelle", "Te voilà enfin... Pardonne-moi, je t'observe depuis ton réveil. Tu ne te souviens de rien, n'est-ce pas ?"],
		["hero", "Seulement d'une lumière... puis de ce village."],
		["maelle", "Je m'appelle Maëlle. J'étudie les obélisques, ces pierres qui veillent sur chaque contrée. Jadis, une seule source les nourrissait : le Cœur d'Aube."],
		["maelle", "Le Seigneur de la Brume l'a brisé. Ses éclats ont été avalés par les grandes bêtes des régions, et depuis, la Brume ronge le royaume."],
		["maelle", "Les anciens textes parlent d'un « Éveillé » capable de rallumer les pierres. Je crois que c'est toi. Va éveiller quelques obélisques : je veux voir s'ils te répondent."],
	], "choices": [["« Je vais essayer. »", "ok"], ["« Et si tu te trompais ? »", "doute"]]},
	"maelle_2": {"pages": [
		["hero", "Les obélisques se sont allumés à mon approche. J'ai senti... un appel, vers le nord."],
		["maelle", "Alors c'est vrai. Écoute : un chevalier, Sire Aldéric, campe non loin d'ici. Il chasse la bête qui a dévoré son ordre."],
		["maelle", "Cette bête garde sans doute un éclat. À deux, vous aurez vos chances. J'ai marqué son camp sur ta carte."],
	]},
	"alderic": {"pages": [
		["alderic", "Halte ! ... Tu n'as pas l'air d'un pillard. Qui t'envoie ?"],
		["hero", "Maëlle l'Érudite. Elle dit que la bête du donjon garde un éclat du Cœur d'Aube."],
		["alderic", "L'Érudite... Cette bête a massacré mes frères d'armes. Je n'ai plus d'ordre, plus de bannière, seulement ma lame."],
		["alderic", "Descends dans ce donjon et abats-la. Si tu en reviens, je saurai que tu es bien l'Éveillé."],
	]},
	"alderic_2": {"pages": [
		["alderic", "Tu l'as fait... Je l'ai vue tomber de loin, la Brume s'est dissipée au-dessus du donjon."],
		["alderic", "Mes frères sont vengés. Je te dois une dette que je ne pourrai jamais rendre."],
		["alderic", "Choisis : je peux te suivre et protéger ton village, ou te confier la Lame d'Aube, l'épée de mon ordre."],
	], "choices": [["« Rejoins mon village. »", "join"], ["« Garde ta liberté, confie-moi ta lame. »", "blade"]]},
	"maelle_3": {"pages": [
		["maelle", "Quatre éclats ! Regarde comme ils brillent quand on les rapproche... Le Cœur veut se reformer."],
		["maelle", "Mais la Brume s'épaissit : le Seigneur sait que tu approches. Il te faudra de l'aide pour atteindre les dernières bêtes."],
		["maelle", "Une marchande, Lysandre, parcourt les contrées lointaines. Elle connaît des routes que personne n'emprunte. Trouve-la."],
	]},
	"lysandre": {"pages": [
		["lysandre", "Un client ! ... Ah non, un héros. Ça paie moins bien, en général."],
		["hero", "On dit que tu connais toutes les routes du royaume."],
		["lysandre", "Toutes, et même celles qui n'existent plus. Mais rien n'est gratuit. Rapporte-moi cinq perles des eaux profondes, et je te dirai tout."],
	]},
	"perles": {"pages": [
		["lysandre", "Cinq perles, parfaites... Tu as plongé loin pour ça. Marché conclu."],
		["lysandre", "Voici ce que je propose : je viens m'installer dans ton village et j'y fais venir mes amis marchands, ou je te donne ma carte des anciens et une bourse pour la route."],
	], "choices": [["« Viens au village. »", "join"], ["« La carte et la bourse. »", "map"]]},
	"coeur": {"pages": [
		["maelle", "Tous les éclats... et ce temple. Pose-les sur l'autel, là. N'aie pas peur."],
		["maelle", "... Le Cœur d'Aube. Je n'aurais jamais cru le voir de mes yeux."],
		["maelle", "Il faut maintenant le porter au Sanctuaire de l'Éveil, là où il a été brisé. Le Seigneur de la Brume t'y attendra. Je l'ai marqué sur ta carte."],
		["maelle", "Reviens-nous, {hero}."],
	]},
	"epilogue": {"pages": [
		["maelle", "Regarde les obélisques : ils brillent tous, même au loin. La Brume se retire des vallées."],
		["maelle", "Le royaume s'éveille, et il porte ton nom. Les habitants parlent déjà de toi au coin du feu."],
		["hero", "Il reste tant à construire."],
		["maelle", "Alors construisons. Ce royaume est à toi, {hero}. Et moi, j'ai encore mille pierres à étudier."],
	]},
	"maelle_idle": {"pages": [["maelle", "Les textes anciens ne disent pas tout... mais je te suis. Ton journal (O) garde la trace de ta quête."]]},
	"alderic_idle": {"pages": [["alderic", "Ma lame est à ton service, Éveillé."]]},
	"lysandre_idle": {"pages": [["lysandre", "Les affaires reprennent ! Le marchand ambulant passe plus souvent depuis que je suis là."]]},
	"wait_alderic": {"pages": [["alderic", "La bête est toujours en vie. Son donjon est tout près : carré rouge sur ta carte."]]},
	"wait_perles": {"pages": [["lysandre", "Cinq perles, pas une de moins. Les eaux profondes en cachent : pêche, ou fouille les grottes englouties."]]},
	"wait_temple": {"pages": [["maelle", "Il me faut un temple pour reformer le Cœur : une pièce fermée avec un autel et deux bougeoirs."]]},
}

const FINAL_BOSS := "res://data/enemies/seigneur_brume.tres"
const BOSS_SCENE := "res://scenes/enemies/boss.tscn"
const OBELISK := preload("res://assets/environment/models/obelisk.glb")

var world: WorldGenerator
var player: Player
var step := 0
var choices := {}
## Éclats : identifiant de région -> vrai.
var shards := {}
## Où sont les personnages : « » (pas encore là), « camp », « village ».
var npc_state := {}
var npc_nodes := {}
var sanctuary := Vector3.INF
var _sanct_node: Node3D
var _boss: Boss
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


func _start() -> void:
	_sync_shards()
	_spawn_npcs()
	banner(ACTS[1], "L'Éveil du Royaume")
	changed.emit()


func current() -> Array:
	return STEPS[step] if step < STEPS.size() else []


func current_id() -> String:
	return STEPS[step][0] if step < STEPS.size() else ""


func is_done() -> bool:
	return step >= STEPS.size()


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


# ---------------------------------------------------------------- personnages

func _npc_pos(id: String) -> Vector3:
	match id:
		"maelle":
			return world.cell_center(world.spawn_cell) + Vector3(2.5, 0, -2.0)
		"alderic":
			var z := _alderic_zone()
			if z.is_empty():
				return world.cell_center(world.spawn_cell) + Vector3(12, 0, 12)
			return _free_spot(world.cell_center(z.gate), 6.0)
		"lysandre":
			var z := _lysandre_zone()
			return _free_spot(world.cell_center(z.obelisk) if (z.obelisk as Vector2i).x >= 0 else Vector3(z.site.x, 0, z.site.y), 5.0)
	return Vector3.INF


## La zone du donjon voisin (où campe Aldéric) : la plus proche du village parmi celles de niveau 3 ou plus.
func _alderic_zone() -> Dictionary:
	var best := {}
	var bd := INF
	for z in world.zones:
		if (z.gate as Vector2i).x < 0 or z.type == null or (z.level as Vector2i).x < 2:
			continue
		if float(z.dist) < bd:
			bd = z.dist
			best = z
	if best.is_empty():
		for z in world.zones:
			if (z.gate as Vector2i).x >= 0:
				return z
	return best


## Une contrée lointaine et chaude (désert, sinon volcan, sinon la plus loin).
func _lysandre_zone() -> Dictionary:
	for want in ["desert", "volcan"]:
		var best := {}
		var bd := INF
		for z in world.zones:
			if z.type and (z.type as RegionData).id == want and float(z.dist) < bd:
				bd = z.dist
				best = z
		if not best.is_empty():
			return best
	var far: Dictionary = world.zones[0]
	for z in world.zones:
		if float(z.dist) > float(far.dist):
			far = z
	return far


func _free_spot(center: Vector3, r: float) -> Vector3:
	for i in 40:
		var a := randf() * TAU
		var p := center + Vector3(cos(a), 0, sin(a)) * randf_range(r * 0.5, r)
		p.y = world.ground_height_at(p + Vector3(0, 30, 0))
		if world.is_walkable(p) and world.build.column(world.cell_at(p)).is_empty():
			return p
	center.y = world.ground_height_at(center + Vector3(0, 30, 0))
	return center


## Fait apparaître les personnages dont l'histoire a besoin (à leur camp ou au village).
func _spawn_npcs() -> void:
	var need := {"maelle": "village"}
	if step >= 3 and choices.get("alderic", "") != "blade":
		need["alderic"] = "village" if choices.get("alderic", "") == "join" else "camp"
	if step >= 8 and choices.get("lysandre", "") != "map":
		need["lysandre"] = "village" if choices.get("lysandre", "") == "join" else "camp"
	for id in need:
		var where: String = need[id]
		var n = npc_nodes.get(id)
		if n and is_instance_valid(n) and npc_state.get(id, "") == where:
			continue
		if n and is_instance_valid(n):
			n.queue_free()
		npc_state[id] = where
		npc_nodes[id] = _make_npc(id, where)


func _make_npc(id: String, where: String) -> Node3D:
	var info: Dictionary = NPCS[id]
	var v := world.villager_scene.instantiate() as Villager
	v.race = load(info.race)
	v.villager_name = info.name
	v.level = int(info.level)
	v.set_meta("story", id)
	v.talents = {"garde": 0.7, "forgeron": 0.4} if id == "alderic" else ({"marchand": 0.8} if id == "lysandre" else {"erudit": 0.8})
	var village := where == "village"
	v.stranger = not village
	v.wander_radius = 1.5 if not village else 4.0
	var pos := _npc_pos(id)
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
	if where == "camp" and world.campfire_scene:
		var fire := world.campfire_scene.instantiate() as Node3D
		world.get_node("Village").add_child(fire)
		fire.global_position = pos + Vector3(1.6, 0, 1.2)
		fire.global_position.y = world.ground_height_at(fire.global_position + Vector3(0, 3, 0))
		v.tree_exiting.connect(fire.queue_free)
	return v


## Le personnage de l'histoire (ou null).
func npc(id: String) -> Node3D:
	var n = npc_nodes.get(id)
	return n if n and is_instance_valid(n) else null


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
	if not s.is_empty() and s[4] == "talk" and s[5] == npc_id:
		if s[0] == "perles" and player.inventory.count(Items.get_item("perle")) < 5:
			return "wait_perles"
		if s[0] == "coeur" and not _has_room("temple"):
			return "wait_temple"
		return s[0]
	if npc_id == "alderic" and current_id() == "bete":
		return "wait_alderic"
	if npc_id == "lysandre" and current_id() == "perles":
		return "wait_perles"
	return npc_id + "_idle"


## Fin d'un dialogue (et choix fait).
func dialog_done(id: String, choice: String) -> void:
	if id != current_id():
		return
	match id:
		"intro":
			choices["intro"] = choice
		"alderic_2":
			choices["alderic"] = choice
			if choice == "blade":
				var blade := Items.get_item("lame_aube")
				if blade:
					player.inventory.add(blade, 1)
				player.notify.emit("Aldéric te confie la Lame d'Aube, puis s'en va sur les routes.")
				var n := npc("alderic")
				if n:
					VoxelBurst.spawn(n, n.global_position + Vector3(0, 1, 0), Color(1, 0.85, 0.5), 20, 3.0, 0.1, 0.6, "up", 5.0, false)
					n.queue_free()
				npc_nodes.erase("alderic")
			else:
				player.notify.emit("Sire Aldéric rejoint ton village : un garde (ou un compagnon) redoutable.")
		"perles":
			player.inventory.remove(Items.get_item("perle"), 5)
			choices["lysandre"] = choice
			if choice == "map":
				for z in world.zones:
					if (z.obelisk as Vector2i).x >= 0:
						world.reveal(world.cell_center(z.obelisk), 6)
					z.discovered = true
				player.inventory.add(Items.get_item("piece_or"), 300)
				player.notify.emit("La carte des anciens révèle tous les obélisques. +300 pièces d'or.")
				var n := npc("lysandre")
				if n:
					n.queue_free()
				npc_nodes.erase("lysandre")
			else:
				player.notify.emit("Lysandre s'installe au village : le marchand ambulant vient plus souvent, à meilleur prix.")
		"coeur":
			_make_sanctuary()
	_advance()


func _has_room(type_id: String) -> bool:
	var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
	if k == null:
		return false
	for r in k.typed_rooms():
		if (r.type as RoomTypeData).id == type_id:
			return true
	return false


# ---------------------------------------------------------------- avancement

func _advance() -> void:
	var before_act: int = current()[1] if not is_done() else 0
	step_done.emit(step)
	step += 1
	if player:
		var done_title: String = STEPS[step - 1][2]
		player.feat.emit("Histoire : %s ✔" % done_title, Color("ffe08a"))
	if is_done():
		banner("Épilogue", "Le royaume s'éveille")
		_finish()
	else:
		var act: int = current()[1]
		if act != before_act:
			banner(ACTS[act], current()[2])
		elif player:
			player.notify.emit("Histoire : %s" % current()[2])
	_spawn_npcs()
	_check()
	changed.emit()


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
			var z := _alderic_zone()
			ok = not z.is_empty() and z.get("cleared", false)
		"shards":
			var need: int = shards_total() if int(s[5]) < 0 else mini(int(s[5]), shards_total())
			ok = shards.size() >= need
		"room":
			ok = _has_room(str(s[5]))
	if ok:
		_advance()


func _process(delta: float) -> void:
	if world == null:
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
		return
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
			n.set_quest_mark("!" if not s.is_empty() and s[4] == "talk" and s[5] == id else "")
	# le sanctuaire : le Seigneur s'éveille quand on approche
	if current_id() == "sanctuaire" and sanctuary != Vector3.INF:
		if _sanct_node == null or not is_instance_valid(_sanct_node):
			_make_sanctuary()
		if (_boss == null or not is_instance_valid(_boss)) and player.global_position.distance_to(sanctuary) < 14.0:
			_spawn_final_boss()


# ---------------------------------------------------------------- sanctuaire et boss final

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


func _spawn_final_boss() -> void:
	# chargés ici (et non au démarrage) : la scène du boss dépend de scripts qui dépendent de l'histoire
	_boss = (load(BOSS_SCENE) as PackedScene).instantiate() as Boss
	_boss.data = load(FINAL_BOSS) as EnemyData
	var top := 1
	for z in world.zones:
		top = maxi(top, (z.level as Vector2i).y)
	_boss.level = top + 3
	_boss.power = 1.6
	_boss.powers = PackedStringArray(["onde", "pluie", "invocation", "charge"])
	var adds: Array[EnemyData] = []
	for id in ["squelette", "demon", "esprit_follet"]:
		var e := load("res://data/enemies/%s.tres" % id) as EnemyData
		if e:
			adds.append(e)
	_boss.summons = adds
	_boss.title = "Seigneur de la Brume"
	world.add_child(_boss)
	_boss.global_position = sanctuary
	_boss.home = sanctuary
	_boss.died_at.connect(_on_final_defeated)
	_boss.wake()
	banner("Le Seigneur de la Brume", "Il a brisé le Cœur d'Aube. Il ne le brisera pas deux fois.")
	var we := get_tree().get_first_node_in_group("weather") as Weather
	if we:
		we.set_kind("orage")
	var dm := get_tree().get_first_node_in_group("dungeons")
	if dm:
		dm.boss_awoken.emit(_boss, _boss.title)


func _on_final_defeated(_pos: Vector3) -> void:
	if current_id() != "sanctuaire":
		return
	var we := get_tree().get_first_node_in_group("weather") as Weather
	if we:
		we.set_kind("clair")
	for z in world.zones:
		z.obelisk_on = true
	player.gain_xp(1500)
	world.spawn_pickup(Items.get_item("lingot_or"), sanctuary + Vector3(1, 0, 0), 5)
	world.spawn_pickup(Items.get_item("piece_or"), sanctuary + Vector3(-1, 0, 0), 500)
	_advance()


func _finish() -> void:
	player.notify.emit("Fin de l'histoire principale ! Tous les obélisques brillent ; tes habitants sont plus heureux. Le royaume continue...")
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
			return _npc_pos(str(s[5]))
		"boss_of":
			var z := _alderic_zone()
			return world.cell_center(z.gate) if not z.is_empty() else Vector3.INF
		"final":
			return sanctuary
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
			t += " (%d / %d)" % [shards.size(), shards_total() if int(s[5]) < 0 else mini(int(s[5]), shards_total())]
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

func export_state() -> Dictionary:
	return {"step": step, "choices": choices.duplicate(), "shards": shards.keys(),
		"sanctuary": [sanctuary.x, sanctuary.y, sanctuary.z] if sanctuary != Vector3.INF else []}


func import_state(d: Dictionary) -> void:
	step = int(d.get("step", 0))
	choices = (d.get("choices", {}) as Dictionary).duplicate()
	shards = {}
	for id in d.get("shards", []):
		shards[str(id)] = true
	var sp: Array = d.get("sanctuary", [])
	sanctuary = Vector3(sp[0], sp[1], sp[2]) if sp.size() == 3 else Vector3.INF
	for id in npc_nodes:
		if is_instance_valid(npc_nodes[id]):
			npc_nodes[id].queue_free()
	npc_nodes.clear()
	npc_state.clear()
	# les habitants de l'histoire déjà au village ont été rechargés avec les autres habitants
	for v in get_tree().get_nodes_in_group("villagers"):
		if v.has_meta("story") or v.villager_name in ["Maëlle", "Aldéric", "Lysandre"]:
			var id := _story_id_of(v)
			if id != "":
				v.set_meta("story", id)
				npc_nodes[id] = v
				npc_state[id] = "village"
	_sync_shards()
	_spawn_npcs()
	changed.emit()


func _story_id_of(v: Node) -> String:
	for id in NPCS:
		if NPCS[id].name == v.villager_name and (v.race as RaceData).resource_path == NPCS[id].race:
			return id
	return ""
