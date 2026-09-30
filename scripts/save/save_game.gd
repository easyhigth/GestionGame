extends Node
## Autoload « SaveGame » : sauvegarde et chargement des parties, options du joueur.
## Les parties sont dans user://saves/ (3 emplacements + une sauvegarde automatique),
## les options dans user://options.cfg.
## Une sauvegarde contient tout ce qui ne se recalcule pas à partir de la graine du monde :
## le héros (profil, niveau, sac, équipement, âmes), le monde (terrassement, décors récoltés,
## carte dévoilée, zones découvertes, obélisques, donjons vaincus, objets ramassés, voyageurs recrutés),
## les constructions (blocs et meubles), les habitants (race, talents, niveau, équipement, poste) et le prochain raid.

signal saved(slot: String)
signal loaded(slot: String)

const DIR := "user://saves/"
const OPTIONS := "user://options.cfg"
const SLOTS := ["1", "2", "3"]
const AUTO := "auto"
const VERSION := 1
const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"
const GAME_SCENE := "res://scenes/main.tscn"
const CREATOR_SCENE := "res://scenes/ui/character_creator.tscn"

## Difficulté : 0 facile, 1 normal, 2 difficile.
const DIFFICULTY_NAMES := ["Facile", "Normal", "Difficile"]
const ENEMY_HP := [0.75, 1.0, 1.35]
const ENEMY_DMG := [0.7, 1.0, 1.35]
const RAID_DELAY := [1.4, 1.0, 0.75]

var options := {
	"difficulty": 1,
	"fullscreen": false,
	"camera_distance": 1.0,
	"show_help": true,
	"autosave": true,
	"volume": 0.8,
	"music_volume": 0.6,
	"sfx_volume": 0.9,
}

## Partie à charger au prochain lancement de la scène de jeu (vide = nouvelle partie).
var pending := {}
## Emplacement de la partie en cours (pour « Sauvegarder » et la sauvegarde automatique).
var current_slot := "1"
## Temps de jeu de la partie en cours (secondes).
var play_time := 0.0
## Heure et jour, et avancement du guide, d'une partie chargée (repris par le cycle et le guide s'ils arrivent après).
var day_state := {}
var guide_state := {}
var village_state := {}
var quest_state := {}
var farm_state := {}
var trade_state := {}
var weather_state := {}
var livestock_state := {}
var caves_state := {}
var story_state := {}
var seasons_state := {}
var mounts_state := {}
var familiars_state := {}
var side_quests_state := {}
var _autosave_timer := 300.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(DIR)
	load_options()


func _process(delta: float) -> void:
	var world := _world()
	if world == null or get_tree().paused:
		return
	play_time += delta
	if options.autosave:
		_autosave_timer -= delta
		if _autosave_timer <= 0.0:
			_autosave_timer = 300.0
			var p := _player()
			if p and p.is_alive() and p.global_position.y > WorldGenerator.UNDERGROUND:
				save_game(AUTO)
				p.notify.emit("Sauvegarde automatique.")


func _world() -> WorldGenerator:
	# seulement dans la scène de jeu (l'écran titre a aussi un monde, en décor)
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path != GAME_SCENE:
		return null
	return get_tree().get_first_node_in_group("world") as WorldGenerator


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


# ---------------------------------------------------------------- options

func load_options() -> void:
	var cf := ConfigFile.new()
	if cf.load(OPTIONS) == OK:
		for k in options:
			options[k] = cf.get_value("options", k, options[k])
	apply_options()


func save_options() -> void:
	var cf := ConfigFile.new()
	for k in options:
		cf.set_value("options", k, options[k])
	cf.save(OPTIONS)
	apply_options()


func apply_options() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if options.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(0.001, float(options.volume))))
	Sound.set_volume("Music", float(options.get("music_volume", 0.6)))
	Sound.set_volume("Sfx", float(options.get("sfx_volume", 0.9)))
	var p := _player()
	if p:
		p.camera_zoom = float(options.camera_distance)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_help_visible"):
		hud.set_help_visible(options.show_help)


func enemy_hp_mult() -> float:
	return ENEMY_HP[clampi(int(options.difficulty), 0, 2)]


func enemy_dmg_mult() -> float:
	return ENEMY_DMG[clampi(int(options.difficulty), 0, 2)]


func raid_delay_mult() -> float:
	return RAID_DELAY[clampi(int(options.difficulty), 0, 2)]


# ---------------------------------------------------------------- emplacements

static func path_of(slot: String) -> String:
	return DIR + "partie_%s.json" % slot


func has_save(slot: String) -> bool:
	return FileAccess.file_exists(path_of(slot))


## Résumé d'une sauvegarde (pour les menus) : {} si l'emplacement est vide.
func slot_info(slot: String) -> Dictionary:
	var d := read(slot)
	return d.get("info", {}) if not d.is_empty() else {}


## Emplacement le plus récent (pour « Continuer »), ou "".
func latest_slot() -> String:
	var best := ""
	var best_t := -1
	for s in SLOTS + [AUTO]:
		var info := slot_info(s)
		if not info.is_empty() and int(info.get("time", 0)) > best_t:
			best_t = int(info.time)
			best = s
	return best


func read(slot: String) -> Dictionary:
	if not has_save(slot):
		return {}
	var f := FileAccess.open(path_of(slot), FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


func delete(slot: String) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(path_of(slot))


# ---------------------------------------------------------------- sauvegarde

func save_game(slot: String) -> bool:
	var world := _world()
	var p := _player()
	if world == null or p == null:
		return false
	var d := {"version": VERSION}
	d.player = _save_player(p, world)
	d.world = world.export_state()
	d.build = _save_build(world.build)
	d.villagers = _save_villagers()
	var bo := get_tree().get_first_node_in_group("build_orders") as BuildOrders
	d.orders = bo.export_state() if bo else []
	var rm := get_tree().get_first_node_in_group("raids") as RaidManager
	d.raid_timer = rm.next_raid_in() if rm else 600.0
	d.play_time = play_time
	var dc := get_tree().get_first_node_in_group("day_cycle") as DayCycle
	if dc:
		d.day = dc.export_state()
	var gd := get_tree().get_first_node_in_group("guide") as GuidePanel
	if gd:
		d.guide = gd.export_state()
	var vn := get_tree().get_first_node_in_group("village_needs") as VillageNeeds
	if vn:
		d.village = vn.export_state()
	var qb := get_tree().get_first_node_in_group("quests") as QuestBoard
	if qb:
		d.quests = qb.export_state()
	var fm := get_tree().get_first_node_in_group("farming") as Farming
	if fm:
		d.farm = fm.export_state()
	var tr := get_tree().get_first_node_in_group("trade") as Trade
	if tr:
		d.trade = tr.export_state()
	var we := get_tree().get_first_node_in_group("weather") as Weather
	if we:
		d.weather = we.export_state()
	var ls := get_tree().get_first_node_in_group("livestock") as Livestock
	if ls:
		d.livestock = ls.export_state()
	var cv := get_tree().get_first_node_in_group("caves") as UnderwaterCaves
	if cv:
		d.caves = cv.export_state()
	var sto := get_tree().get_first_node_in_group("story") as Story
	if sto:
		d.story = sto.export_state()
	var sea := get_tree().get_first_node_in_group("seasons") as Seasons
	if sea:
		d.seasons = sea.export_state()
	var mnt := get_tree().get_first_node_in_group("mounts") as Mounts
	if mnt:
		d.mounts = mnt.export_state()
	var fam := get_tree().get_first_node_in_group("familiars_mgr") as Familiars
	if fam:
		d.familiars = fam.export_state()
	var sq := get_tree().get_first_node_in_group("side_quests") as SideQuests
	if sq:
		d.side_quests = sq.export_state()
	var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
	var z := world.zone_at(p.global_position) if p.global_position.y > WorldGenerator.UNDERGROUND else {}
	d.info = {"hero": p.profile.hero_name if p.profile else "Héros",
		"race": p.race.display_name if p.race else "?",
		"class": p.profile.hero_class.display_name if p.profile and p.profile.hero_class else "",
		"level": p.level, "kingdom": k.title() if k else "",
		"zone": z.get("name", "Donjon"), "time": int(Time.get_unix_time_from_system()),
		"date": Time.get_datetime_string_from_system(false, true), "play_time": int(play_time),
		"difficulty": int(options.difficulty)}
	var f := FileAccess.open(path_of(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d))
	f.close()
	if slot != AUTO:
		current_slot = slot
	saved.emit(slot)
	return true


func _res(r: Resource) -> String:
	return r.resource_path if r else ""


func _save_player(p: Player, world: WorldGenerator) -> Dictionary:
	var h := p.profile
	var pos := p.global_position
	var dm := get_tree().get_first_node_in_group("dungeons") as DungeonManager
	if pos.y < WorldGenerator.UNDERGROUND and dm and dm.active:
		# sauvegarde dans un donjon : on reprendra devant son entrée
		pos = world.cell_center(dm.zone.gate) + Vector3(0, 0, 2.6)
	var mo := get_tree().get_first_node_in_group("mounts") as Mounts
	if mo and mo.is_sailing():
		pos = mo.mount.global_position + Vector3(0, 0.3, 0)
	var cv := get_tree().get_first_node_in_group("caves") as UnderwaterCaves
	if pos.y < WorldGenerator.UNDERGROUND and cv and cv.active:
		# dans une grotte sous-marine : on reprendra au-dessus de son entrée
		pos = cv._return_pos
	var inv := []
	for e in p.inventory.entries:
		inv.append([e.item.id, e.count])
	return {
		"name": h.hero_name, "race": _res(h.race), "style": h.style, "beard": h.beard,
		"skin": h.skin_color.to_html(), "hair": h.hair_color.to_html(), "eye": h.eye_color.to_html(),
		"height": h.height, "build": h.build, "class": _res(h.hero_class), "job": _res(h.job), "skill": _res(h.skill),
		"level": p.level, "xp": p.xp, "hp": p.health.current,
		"pos": [pos.x, pos.y, pos.z],
		"inventory": inv, "equipment": _equip_ids(p.equipment),
		"souls": p.souls, "absorbed": p.skill.absorbed if p.skill else {},
		"talents": p.talents.keys(), "ability_slots": p.ability_slots, "hunger": p.hunger, "hero_evo": p.hero_evo,
	}


func _equip_ids(eq: CharacterEquipment) -> Array:
	var out := []
	for s in eq.slots:
		out.append((eq.slots[s] as ItemData).id)
	return out


func _save_build(grid: BuildGrid) -> Dictionary:
	var blocks := []
	for k in grid.blocks:
		blocks.append([k.x, k.y, k.z, (grid.blocks[k] as ItemData).id])
	var furn := []
	for k in grid.furniture:
		var f: Dictionary = grid.furniture[k]
		furn.append([f.col.x, f.col.y, f.base, (f.item as ItemData).id, f.rot])
	return {"blocks": blocks, "furniture": furn}


func _save_villagers() -> Array:
	var out := []
	for v in get_tree().get_nodes_in_group("villagers"):
		var vv := v as Villager
		var work := {}
		if vv.work_room != null and vv.work_room.type and not vv.work_room.get("fields", false) and not vv.work_room.cells.is_empty():
			var cell: Vector2i = vv.work_room.cells.keys()[0]
			work = {"type": (vv.work_room.type as RoomTypeData).id, "x": cell.x, "z": cell.y, "floor": vv.work_room.floor}
		out.append({"name": vv.villager_name, "race": _res(vv.race), "talents": vv.talents, "level": vv.level,
			"equipment": _equip_ids(vv.equipment), "companion": vv.companion, "work": work,
			"pos": [vv.global_position.x, vv.global_position.y, vv.global_position.z],
			"home": [vv.home.x, vv.home.y, vv.home.z], "food": vv.food, "happiness": vv.happiness, "unhappy": vv.unhappy_time, "friend": vv.friendship,
			"evo": vv.evo, "evo_title": vv.evo_title,
			"variant": vv.model_variant, "evo_model": vv.evo_model})
	return out


# ---------------------------------------------------------------- chargement

## Lance le chargement d'une partie : on passe par la scène de jeu, qui applique `pending`.
func load_game(slot: String) -> bool:
	var d := read(slot)
	if d.is_empty():
		return false
	var pd: Dictionary = d.player
	var h := HeroProfile.new()
	h.hero_name = pd.name
	h.race = load(pd.race) if pd.race != "" else null
	h.style = int(pd.style)
	h.beard = bool(pd.beard)
	h.skin_color = Color(pd.skin)
	h.hair_color = Color(pd.hair)
	h.eye_color = Color(pd.eye)
	h.height = float(pd.height)
	h.build = float(pd.build)
	h.hero_class = load(pd["class"]) if pd["class"] != "" else null
	h.job = load(pd.job) if pd.job != "" else null
	h.skill = load(pd.skill) if pd.skill != "" else null
	GameState.hero = h
	pending = d
	pending["slot"] = slot
	current_slot = slot if slot != AUTO else current_slot
	play_time = float(d.get("play_time", 0.0))
	get_tree().paused = false
	get_tree().change_scene_to_file(GAME_SCENE)
	return true


## Nouvelle partie : écran de création du héros.
func new_game() -> void:
	pending = {}
	day_state = {}
	guide_state = {}
	village_state = {}
	quest_state = {}
	farm_state = {}
	trade_state = {}
	weather_state = {}
	livestock_state = {}
	caves_state = {}
	story_state = {}
	seasons_state = {}
	mounts_state = {}
	familiars_state = {}
	side_quests_state = {}
	play_time = 0.0
	get_tree().paused = false
	get_tree().change_scene_to_file(CREATOR_SCENE)


func to_title() -> void:
	pending = {}
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)


## Graine du monde de la partie à charger (-1 si nouvelle partie).
func pending_seed() -> int:
	return int(pending.world.seed) if not pending.is_empty() else -1


## Appelé par le monde une fois généré : restaure tout le reste.
func apply_pending(world: WorldGenerator) -> void:
	if pending.is_empty():
		return
	var d := pending
	pending = {}
	world.import_state(d.world)
	# constructions
	var grid := world.build
	grid.clear()
	for b in d.build.blocks:
		var it := Items.get_item(b[3])
		if it:
			grid.place_block(Vector3i(int(b[0]), int(b[1]), int(b[2])), it)
	for f in d.build.furniture:
		var it := Items.get_item(f[3])
		if it:
			grid.place_furniture(Vector2i(int(f[0]), int(f[1])), float(f[2]), it, int(f[4]))
	# héros
	var p := _player()
	var pd: Dictionary = d.player
	if p:
		p.level = int(pd.level)
		p.xp = int(pd.xp)
		if p.skill:
			p.skill.set_level(p.level)
			for k in pd.get("absorbed", {}):
				p.skill.absorbed[k] = int(pd.absorbed[k])
		p.inventory.entries.clear()
		for e in pd.inventory:
			var it := Items.get_item(e[0])
			if it:
				p.inventory.add(it, int(e[1]))
		for s in p.equipment.slots.keys():
			p.equipment.unequip(s, false)
		for id in pd.equipment:
			var it := Items.get_item(id)
			if it:
				p.equipment.equip(it)
		p.souls = {}
		p.soul_bonus = {}
		for id in pd.get("souls", {}):
			p.absorb_soul(id, pd.souls[id])
		# talents (une ancienne sauvegarde sans talents reçoit celui de la classe)
		p.talents = {}
		for id in pd.get("talents", []):
			if not TalentTree.node(id).is_empty():
				p.talents[id] = true
		p.hunger = float(pd.get("hunger", Player.HUNGER_MAX))
		var slots: Array = pd.get("ability_slots", ["", "", "", ""])
		p.ability_slots = ["", "", "", ""]
		for i in mini(4, slots.size()):
			p.ability_slots[i] = str(slots[i])
		p.hero_evo = int(pd.get("hero_evo", 0))
		p._apply_evo_look()
		p._give_class_talent()
		p._apply_talents()
		var pos := Vector3(pd.pos[0], pd.pos[1], pd.pos[2])
		world.load_area(pos)
		p.global_position = pos
		p.refresh_stats()
		p.health.current = clampi(int(pd.hp), 1, p.health.max_health)
		p.health.changed.emit(p.health.current, p.health.max_health)
		p.snap_camera()
	# habitants : on remplace ceux du village de départ
	for v in get_tree().get_nodes_in_group("villagers"):
		v.remove_from_group("villagers")
		v.queue_free()
	var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
	if k:
		k.recompute()
	var holder := world.get_node("Village")
	for vd in d.villagers:
		var v := world.villager_scene.instantiate() as Villager
		v.race = load(vd.race) if vd.race != "" else null
		v.villager_name = vd.name
		v.talents = vd.talents
		v.level = int(vd.level)
		v.evo = int(vd.get("evo", 0))
		v.evo_title = str(vd.get("evo_title", ""))
		v.model_variant = int(vd.get("variant", -1))
		v.evo_model = int(vd.get("evo_model", mini(int(vd.get("evo", 0)), 2)))
		holder.add_child(v)
		v.global_position = Vector3(vd.pos[0], vd.pos[1], vd.pos[2])
		v.home = Vector3(vd.home[0], vd.home[1], vd.home[2])
		v.food = float(vd.get("food", 80.0))
		v.happiness = float(vd.get("happiness", 60.0))
		v.unhappy_time = float(vd.get("unhappy", 0.0))
		v.friendship = int(vd.get("friend", 0))
		for id in vd.equipment:
			var it := Items.get_item(id)
			if it:
				v.equipment.equip(it)
		if vd.companion:
			v.set_companion(true)
		elif not vd.work.is_empty() and k:
			var room = k.room_at(Vector2i(int(vd.work.x), int(vd.work.z)), float(vd.work.floor))
			if room and room.type and (room.type as RoomTypeData).id == vd.work.type:
				k.assign(v, room)
	var bo := get_tree().get_first_node_in_group("build_orders") as BuildOrders
	if bo:
		bo.import_state(d.get("orders", []))
	var rm := get_tree().get_first_node_in_group("raids") as RaidManager
	if rm:
		rm.set_next_raid(float(d.get("raid_timer", 600.0)))
	day_state = d.get("day", {"hour": 8.0, "day": 1})
	var dc := get_tree().get_first_node_in_group("day_cycle") as DayCycle
	if dc:
		dc.import_state(day_state)
		day_state = {}
	village_state = d.get("village", {})
	var vn := get_tree().get_first_node_in_group("village_needs") as VillageNeeds
	if vn and not village_state.is_empty():
		vn.import_state(village_state)
		village_state = {}
	quest_state = d.get("quests", {})
	var qb := get_tree().get_first_node_in_group("quests") as QuestBoard
	if qb and not quest_state.is_empty():
		qb.import_state(quest_state)
		quest_state = {}
	# champs (une ancienne partie sans champs : rien, pas de champ de départ)
	farm_state = d.get("farm", {"plots": []})
	var fm := get_tree().get_first_node_in_group("farming") as Farming
	if fm:
		fm.import_state(farm_state)
		farm_state = {}
	side_quests_state = d.get("side_quests", {})
	var sq := get_tree().get_first_node_in_group("side_quests") as SideQuests
	if sq and not side_quests_state.is_empty():
		sq.import_state(side_quests_state)
		side_quests_state = {}
	familiars_state = d.get("familiars", {})
	var fam := get_tree().get_first_node_in_group("familiars_mgr") as Familiars
	if fam and not familiars_state.is_empty():
		fam.import_state(familiars_state)
		familiars_state = {}
	mounts_state = d.get("mounts", {})
	var mnt := get_tree().get_first_node_in_group("mounts") as Mounts
	if mnt and not mounts_state.is_empty():
		mnt.import_state(mounts_state)
		mounts_state = {}
	seasons_state = d.get("seasons", {})
	var sea := get_tree().get_first_node_in_group("seasons") as Seasons
	if sea and not seasons_state.is_empty():
		sea.import_state(seasons_state)
		seasons_state = {}
	story_state = d.get("story", {})
	var sto := get_tree().get_first_node_in_group("story") as Story
	if sto and not story_state.is_empty():
		sto.import_state(story_state)
		story_state = {}
	caves_state = d.get("caves", {})
	var cv := get_tree().get_first_node_in_group("caves") as UnderwaterCaves
	if cv and not caves_state.is_empty():
		cv.import_state(caves_state)
		caves_state = {}
	livestock_state = d.get("livestock", {"animals": []})
	var ls := get_tree().get_first_node_in_group("livestock") as Livestock
	if ls:
		ls.import_state(livestock_state)
		livestock_state = {}
	weather_state = d.get("weather", {})
	var we := get_tree().get_first_node_in_group("weather") as Weather
	if we and not weather_state.is_empty():
		we.import_state(weather_state)
		weather_state = {}
	trade_state = d.get("trade", {})
	var tr := get_tree().get_first_node_in_group("trade") as Trade
	if tr and not trade_state.is_empty():
		tr.import_state(trade_state)
		trade_state = {}
	# une ancienne partie sans guide : le guide est considéré comme fini
	guide_state = d.get("guide", {"step": 99})
	var gd := get_tree().get_first_node_in_group("guide") as GuidePanel
	if gd:
		gd.import_state(guide_state)
		guide_state = {}
	if k:
		k.recompute()
	loaded.emit(str(d.get("slot", "")))
	if p:
		p.notify.emit("Partie chargée.")
