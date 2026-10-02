class_name Endgame
extends Node
## Fin de partie, pour les hauts niveaux (jusqu'au niveau 1000) :
## - Paliers du monde (0 à 10) : un palier plus haut rend tous les monstres plus forts (+30 niveaux par palier),
##   mais rapporte plus d'expérience et fait tomber du butin de niveau (voir Loot). Chaque palier se débloque à
##   un niveau du héros (60, 120, 200... 950).
## - Failles : le Portail des Failles, près du village (E), ouvre une arène hors du monde. Chaque faille a un
##   rang (sans limite) : trois vagues de monstres, puis un gardien. Vaincre le gardien ouvre le rang suivant et
##   fait tomber du butin du niveau de la faille (rareté de commune à mystique).
## - Titans : tous les deux ou trois jours, un titan géant apparaît quelque part dans le monde (sur la carte). Il
##   est bien plus fort que tout le reste ; le vaincre rapporte un butin légendaire ou mystique.

signal changed

## Niveau du héros requis pour chaque palier du monde.
const TIER_LEVEL := [0, 60, 120, 200, 300, 400, 500, 600, 700, 850, 950]
const TIER_NAMES := ["Normal", "Difficile", "Expert", "Maître", "Tourment I", "Tourment II", "Tourment III",
	"Tourment IV", "Tourment V", "Tourment VI", "Tourment VII"]
## Niveaux ajoutés aux monstres par palier.
const TIER_BONUS := 30
## L'arène des failles : sol à cette hauteur (sous le monde, entre les donjons et les grottes), rayon.
const RIFT_FLOOR := -200
const RIFT_R := 16
const WAVES := 3
const RIFT_MOBS := ["squelette", "demon", "orc_brute", "loup_givre", "araignee", "esprit_follet", "salamandre", "ogre",
	"homme_lezard", "slime_magma", "panthere", "seigneur_squelette"]
const RIFT_BOSSES := ["boss_ogre_roi", "boss_seigneur_ignarok", "boss_reine_araignee", "boss_scorpion_empereur", "boss_ours_ancien",
	"boss_slime_primordial", "seigneur_demon", "boss_quetzal"]
const TITANS := [["boss_ours_ancien", "Ursok, Titan des glaces"], ["boss_seigneur_ignarok", "Ignarok, Titan de lave"],
	["boss_ogre_roi", "Gromm, Titan des montagnes"], ["boss_dryade_mere", "Sylvara, Titan des forêts"],
	["boss_scorpion_empereur", "Kar'Zeth, Titan des sables"], ["seigneur_demon", "Azgaroth, Titan des abîmes"]]
const PORTAL_OFFSET := Vector3(-16, 0, 14)

var world: WorldGenerator
var player: Player
var tier := 0
## Meilleur rang de faille vaincu.
var best_rift := 0
## Dans une faille.
var active := false
var rift_rank := 0
var wave := 0
## Le titan du moment : {kind, name, level, x, z} ou {} ; le jour du prochain.
var titan := {}
var next_titan_day := 3
var titans_slain := 0
var _titan_node: Boss
var _alive: Array = []
var _boss: Boss
var _timer := 0.0
var _return_pos := Vector3.ZERO
var _arena: Node3D
var _portal: Node3D
var _fade: ColorRect
var _busy := false
var _saved_light := {}
var _day := -1
var _tick := 0.0
var _rng := RandomNumberGenerator.new()
var _portal_cell := Vector2i(-1, -1)


func _ready() -> void:
	add_to_group("endgame")
	_rng.randomize()
	_arena = Node3D.new()
	_arena.name = "Faille"
	add_child(_arena)
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.08, 0.0, 0.12, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not SaveGame.endgame_state.is_empty():
		import_state.call_deferred(SaveGame.endgame_state)
		SaveGame.endgame_state = {}


func today() -> int:
	var dc := get_tree().get_first_node_in_group("day_cycle") as DayCycle
	return dc.day if dc else 1


# ---------------------------------------------------------------- paliers du monde

func max_tier() -> int:
	var t := 0
	for i in TIER_LEVEL.size():
		if player and player.level >= TIER_LEVEL[i]:
			t = i
	return t


func set_tier(t: int) -> bool:
	if t < 0 or t >= TIER_LEVEL.size() or t > max_tier():
		return false
	tier = t
	if player:
		player.notify.emit("Palier du monde : %s. Les monstres gagnent %d niveaux, l'expérience est multipliée par %s." % [
			TIER_NAMES[t], t * TIER_BONUS, _num(xp_mult())])
	changed.emit()
	return true


func xp_mult() -> float:
	return 1.0 + tier * 0.5


func _num(v: float) -> String:
	return str(roundi(v)) if absf(v - roundf(v)) < 0.01 else ("%.1f" % v).replace(".", ",")


## Appelé par chaque monstre qui apparaît (Enemy._ready) : le palier du monde le renforce.
func scale_enemy(e: Enemy) -> void:
	if tier <= 0 or e.has_meta("rift") or e.has_meta("titan"):
		return
	var bonus := tier * TIER_BONUS
	e.level += bonus
	e.power += 0.06 * bonus


## Appelé à la mort d'un monstre : butin de niveau aux paliers élevés.
func on_enemy_died(e: Enemy) -> void:
	if e.has_meta("rift") or e.has_meta("titan") or world == null:
		return
	if tier > 0 and randf() < 0.03 + 0.006 * tier:
		_drop(Loot.roll(e.level, 0.0, tier), e.global_position)


func _drop(it: ItemData, pos: Vector3) -> void:
	if it == null or world == null:
		return
	world.spawn_pickup(it, pos + Vector3(randf_range(-1, 1), 0.3, randf_range(-1, 1)), 1, _arena if active else null)
	if it.rarity >= ItemData.Rarity.LEGENDARY and player:
		player.feat.emit("%s : %s" % ["Mystique" if it.rarity == ItemData.Rarity.MYTHIC else "Légendaire", it.display_name], it.rarity_color())
		VoxelBurst.spawn(world, pos + Vector3(0, 0.5, 0), it.rarity_color(), 50, 5.0, 0.12, 1.4, "up", -1.0)


# ---------------------------------------------------------------- portail des failles

func portal_pos() -> Vector3:
	if _portal_cell.x < 0:
		_portal_cell = _find_portal_cell()
	var p := world.cell_center(_portal_cell)
	p.y = world.support_height(p, world.terrain_height(_portal_cell) + 0.3)
	return p


## Un coin dégagé près du village (sans bâtiment, décor du village ni eau, à peu près plat).
func _find_portal_cell() -> Vector2i:
	var sp := world.spawn_cell
	var first := sp + Vector2i(roundi(PORTAL_OFFSET.x), roundi(PORTAL_OFFSET.z))
	for r in range(16, 40, 3):
		for k in 16:
			var a := atan2(PORTAL_OFFSET.z, PORTAL_OFFSET.x) + TAU * k / 16.0
			var c := sp + Vector2i(roundi(cos(a) * r), roundi(sin(a) * r))
			if _portal_spot_ok(c):
				return c
	return first


func _portal_spot_ok(c: Vector2i) -> bool:
	var h0 := world.terrain_height(c)
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var q := c + Vector2i(dx, dz)
			var ty := world.terrain_type(q)
			if ty == WorldGenerator.WATER or ty == WorldGenerator.DEEP or absf(world.terrain_height(q) - h0) > 1.1:
				return false
			if world.build and world.build.support(q, 1000.0) > -INF:
				return false
	# pas d'arbre trop près (leur feuillage cacherait le portail)
	for dz in range(-3, 4):
		for dx in range(-3, 4):
			if world.decor_at(c + Vector2i(dx, dz)) != WorldGenerator.D_NONE and (absi(dx) > 2 or absi(dz) > 2):
				return false
	return world.village_props_in(Rect2i(c - Vector2i(2, 2), Vector2i(5, 5))).is_empty()


func _make_portal() -> void:
	if _portal and is_instance_valid(_portal):
		return
	_portal = Node3D.new()
	_portal.name = "PortailDesFailles"
	world.add_child(_portal)
	_portal.global_position = portal_pos()
	var col := Color("b05aff")
	for i in 2:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 1.5 - i * 0.35
		tm.outer_radius = 1.85 - i * 0.35
		ring.mesh = tm
		var m := StandardMaterial3D.new()
		m.albedo_color = col if i == 0 else Color("ff6ad0")
		m.emission_enabled = true
		m.emission = m.albedo_color
		m.emission_energy_multiplier = 2.0
		ring.material_override = m
		ring.rotation.x = PI / 2.0
		ring.position.y = 2.1
		ring.name = "Anneau%d" % i
		_portal.add_child(ring)
	var core := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.4
	disc.bottom_radius = 1.4
	disc.height = 0.05
	core.mesh = disc
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.1, 0.0, 0.18, 0.9)
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core.material_override = cm
	core.rotation.x = PI / 2.0
	core.position.y = 2.1
	_portal.add_child(core)
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 2.0
	l.omni_range = 8.0
	l.position.y = 2.0
	_portal.add_child(l)
	var lab := Label3D.new()
	lab.text = "Portail des Failles\nE : entrer"
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.font_size = 36
	lab.pixel_size = 0.008
	lab.outline_size = 10
	lab.modulate = Color("e0b0ff")
	lab.position.y = 4.6
	_portal.add_child(lab)


func try_interact(p: Player) -> bool:
	player = p
	if _busy or world == null:
		return false
	if active:
		# au centre de l'arène, après la victoire : sortir
		if _boss == null and wave > WAVES and _arena_center().distance_to(p.global_position) < 3.0:
			leave(true)
			return true
		return false
	if _portal and is_instance_valid(_portal) and _portal.global_position.distance_to(p.global_position) < 3.2:
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.get("endgame_panel"):
			hud.endgame_panel.open()
		return true
	return false


# ---------------------------------------------------------------- failles

func rift_level(rank: int) -> int:
	return 10 + rank * 5


func _arena_origin() -> Vector2i:
	return world.spawn_cell + Vector2i(0, 0)


func _arena_center() -> Vector3:
	var c := _arena_origin()
	return Vector3(c.x + 0.5, RIFT_FLOOR, c.y + 0.5)


## Entre dans une faille de ce rang (au plus le meilleur rang vaincu + 1).
func enter_rift(rank: int) -> bool:
	var dm := get_tree().get_first_node_in_group("dungeons")
	var mc := get_tree().get_first_node_in_group("mountain_caves")
	var uw := get_tree().get_first_node_in_group("caves")
	if active or _busy or player == null or world.dungeon_grid == null or rank < 1 or rank > best_rift + 1:
		return false
	if (dm and dm.is_inside()) or (mc and mc.active) or (uw and uw.active) or player.global_position.y < WorldGenerator.UNDERGROUND:
		return false
	var mo := get_tree().get_first_node_in_group("mounts")
	if mo and mo.mount:
		mo.dismount()
	rift_rank = rank
	_return_pos = portal_pos() + Vector3(0, 0, 3.0)
	_busy = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.4)
	tw.tween_callback(func():
		_build_arena()
		_busy = false)
	tw.tween_property(_fade, "color:a", 0.0, 0.6)
	return true


func _build_arena() -> void:
	active = true
	wave = 0
	_alive.clear()
	_boss = null
	var grid := world.dungeon_grid
	grid.clear()
	var o := _arena_origin()
	var floor_it := Items.get_item("bloc_marbre_noir")
	var wall_it := Items.get_item("bloc_pierre_polie")
	var crystal := Items.get_item("bloc_minerai_cristal")
	for dz in range(-RIFT_R - 1, RIFT_R + 2):
		for dx in range(-RIFT_R - 1, RIFT_R + 2):
			var d := Vector2(dx, dz).length()
			if d > RIFT_R + 1.0:
				continue
			grid.place_block(Vector3i(o.x + dx, RIFT_FLOOR - 1, o.y + dz), floor_it)
			if d > RIFT_R - 0.5:
				for h in 4:
					grid.place_block(Vector3i(o.x + dx, RIFT_FLOOR + h, o.y + dz), wall_it)
	# des piliers de cristal
	for i in 8:
		var a := TAU * i / 8.0
		var c := o + Vector2i(roundi(cos(a) * (RIFT_R - 4)), roundi(sin(a) * (RIFT_R - 4)))
		for h in 3:
			grid.place_block(Vector3i(c.x, RIFT_FLOOR + h, c.y), crystal)
		var l := OmniLight3D.new()
		l.light_color = Color("b05aff") if i % 2 == 0 else Color("ff6ad0")
		l.light_energy = 2.2
		l.omni_range = 11.0
		_arena.add_child(l)
		l.global_position = Vector3(c.x + 0.5, RIFT_FLOOR + 3.5, c.y + 0.5)
	_set_lighting(true)
	player.global_position = _arena_center() + Vector3(0, 0.1, 6)
	player.snap_camera()
	_timer = 3.0
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_banner"):
		hud.show_banner("Faille — rang %d" % rift_rank, "Monstres de niveau %d : trois vagues, puis le gardien." % rift_level(rift_rank), Color("e0b0ff"))
	Sound.ui("war_drums")


func _set_lighting(on: bool) -> void:
	var scene_root: Node = world.get_parent()
	var sun := scene_root.get_node_or_null("Soleil") as DirectionalLight3D
	var env_node := scene_root.get_node_or_null("Ambiance") as WorldEnvironment
	var env: Environment = env_node.environment if env_node else null
	if on:
		if sun and not _saved_light.has("sun"):
			_saved_light["sun"] = [sun.light_energy, sun.shadow_enabled]
			sun.light_energy = 0.1
			sun.shadow_enabled = false
		if env and not _saved_light.has("env"):
			_saved_light["env"] = [env.background_color, env.ambient_light_color, env.ambient_light_energy]
			env.background_color = Color(0.06, 0.0, 0.1)
			env.ambient_light_color = Color(0.7, 0.55, 0.9)
			env.ambient_light_energy = 1.2
	else:
		if sun and _saved_light.has("sun"):
			sun.light_energy = _saved_light.sun[0]
			sun.shadow_enabled = _saved_light.sun[1]
		if env and _saved_light.has("env"):
			env.background_color = _saved_light.env[0]
			env.ambient_light_color = _saved_light.env[1]
			env.ambient_light_energy = _saved_light.env[2]
		_saved_light.clear()


func _spawn_wave() -> void:
	var lv := rift_level(rift_rank)
	var n := 5 + wave * 2 + mini(rift_rank / 10, 6)
	var scene := load("res://scenes/enemies/enemy.tscn") as PackedScene
	var c := _arena_center()
	for i in n:
		var e := scene.instantiate() as Enemy
		e.data = load("res://data/enemies/%s.tres" % RIFT_MOBS[(rift_rank * 3 + wave + i) % RIFT_MOBS.size()])
		e.level = lv
		e.power = 1.0 + 0.06 * lv
		e.set_meta("rift", true)
		_arena.add_child(e)
		var a := TAU * i / n + wave
		e.global_position = c + Vector3(cos(a), 0, sin(a)) * (RIFT_R - 3.0)
		e.home = c
		e.set("_wander_to", c)
		e.set("_returning", true)
		_alive.append(e)
	if player:
		player.notify.emit("Faille %d : vague %d / %d !" % [rift_rank, wave, WAVES])
	Sound.play("horn", Vector3.INF, 0.0, 0.0)


func _spawn_rift_boss() -> void:
	var lv := rift_level(rift_rank) + 3
	var b := (load("res://scenes/enemies/boss.tscn") as PackedScene).instantiate() as Boss
	var d := (load("res://data/enemies/%s.tres" % RIFT_BOSSES[rift_rank % RIFT_BOSSES.size()]) as EnemyData).duplicate() as EnemyData
	d.display_name = "Gardien de la Faille"
	b.data = d
	b.level = lv
	b.power = 1.3 + 0.06 * lv
	b.powers = PackedStringArray(["onde", "charge", "pluie"])
	b.title = "Faille %d · Gardien" % rift_rank
	b.set_meta("rift", true)
	_arena.add_child(b)
	b.health.set_max(roundi((400.0 + 60.0 * lv) * SaveGame.enemy_hp_mult()), true)
	b.global_position = _arena_center() + Vector3(0, 0, -6)
	b.home = b.global_position
	b.died_at.connect(_on_rift_boss_died)
	_boss = b
	_alive.append(b)
	b.wake()
	var dm := get_tree().get_first_node_in_group("dungeons") as DungeonManager
	if dm:
		dm.boss_awoken.emit(b, b.title)
	if player:
		player.notify.emit("Le gardien de la faille apparaît !")


func _on_rift_boss_died(pos: Vector3) -> void:
	_boss = null
	wave = WAVES + 1
	if rift_rank > best_rift:
		best_rift = rift_rank
	var lv := rift_level(rift_rank)
	var n := 2 + rift_rank / 15
	for i in n:
		_drop(Loot.roll(lv, 0.15, rift_rank / 6, 2 if i == 0 else 0), pos)
	if player:
		player.inventory.add(Items.get_item("piece_or"), 40 + 12 * rift_rank)
		player.inventory.add(Items.get_item("poussiere_arcane"), 2 + rift_rank / 3)
		if randf() < 0.25 + rift_rank * 0.01:
			player.inventory.add(Items.get_item("pierre_ame"), 1)
		player.gain_xp(200 + 30 * lv)
		player.feat.emit("Faille %d vaincue !" % rift_rank, Color("e0b0ff"))
		player.notify.emit("Faille %d vaincue ! Le rang %d est ouvert. Ramasse le butin, puis E au centre pour sortir." % [rift_rank, rift_rank + 1])
	Sound.ui("fanfare")
	SkillFX.pillar(self, _arena_center(), Color("e0b0ff"), 12.0, 1.2, 3.0)
	changed.emit()


## Sortir de la faille (victoire, abandon ou mort).
func leave(won := false) -> void:
	if not active:
		return
	_busy = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.35)
	tw.tween_callback(func():
		_cleanup()
		if player and player.is_alive():
			world.load_area(_return_pos)
			player.global_position = Vector3(_return_pos.x, world.ground_height_at(_return_pos + Vector3(0, 40, 0)), _return_pos.z)
			player.snap_camera()
		_busy = false)
	tw.tween_property(_fade, "color:a", 0.0, 0.5)


func _cleanup() -> void:
	active = false
	wave = 0
	_boss = null
	_alive.clear()
	for c in _arena.get_children():
		c.queue_free()
	if world.dungeon_grid:
		world.dungeon_grid.clear()
	_set_lighting(false)


# ---------------------------------------------------------------- titans

## Fait apparaître un titan quelque part (automatique ; utilisable pour tester). Renvoie sa description.
func summon_titan(near := Vector3.INF) -> Dictionary:
	if world == null or player == null:
		return {}
	var t: Array = TITANS[_rng.randi() % TITANS.size()]
	var pos := near
	if pos == Vector3.INF:
		var sp := world.cell_center(world.spawn_cell)
		for k in 40:
			var a := _rng.randf() * TAU
			var c := sp + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(220.0, 480.0)
			var cell := world.cell_at(c)
			var ty := world.terrain_type(cell)
			if ty != WorldGenerator.WATER and ty != WorldGenerator.DEEP and world.city_at(c, 40.0).is_empty() \
					and cell.x > 20 and cell.y > 20 and cell.x < world.world_size.x - 20 and cell.y < world.world_size.y - 20:
				pos = c
				break
	if pos == Vector3.INF:
		return {}
	_despawn_titan()
	titan = {"kind": t[0], "name": t[1], "level": maxi(player.power_level(), rift_level(best_rift)) + 15 + tier * TIER_BONUS / 2,
		"x": pos.x, "z": pos.z}
	var z := world.zone_at(pos)
	player.feat.emit("Un titan s'éveille !", Color("ff6a3a"))
	player.notify.emit("%s s'est éveillé dans %s (niveau %d). Il est sur la carte." % [titan.name, z.get("name", "les terres sauvages"), int(titan.level)])
	Sound.ui("war_drums")
	changed.emit()
	return titan


func titan_pos() -> Vector3:
	if titan.is_empty():
		return Vector3.INF
	return Vector3(float(titan.x), 0, float(titan.z))


func _spawn_titan_node() -> void:
	var pos := titan_pos()
	pos.y = world.support_height(pos, world.terrain_height(world.cell_at(pos)) + 0.3)
	var b := (load("res://scenes/enemies/boss.tscn") as PackedScene).instantiate() as Boss
	var d := (load("res://data/enemies/%s.tres" % titan.kind) as EnemyData).duplicate() as EnemyData
	d.display_name = titan.name
	b.data = d
	var lv: int = titan.level
	b.level = lv
	b.power = 1.6 + 0.07 * lv
	b.powers = PackedStringArray(["onde", "charge", "invocation", "pluie"])
	b.title = "Titan · " + str(titan.name)
	b.set_meta("titan", true)
	add_child(b)
	b.health.set_max(roundi((2500.0 + 260.0 * lv) * SaveGame.enemy_hp_mult()), true)
	b.visual.scale *= 2.0
	b.body_radius *= 1.8
	b.global_position = pos
	b.home = pos
	b.died_at.connect(_on_titan_died)
	_titan_node = b


func _despawn_titan() -> void:
	if _titan_node and is_instance_valid(_titan_node):
		_titan_node.queue_free()
	_titan_node = null


func _on_titan_died(pos: Vector3) -> void:
	var lv: int = titan.get("level", 50)
	titan = {}
	_titan_node = null
	titans_slain += 1
	next_titan_day = today() + 2 + _rng.randi() % 2
	for i in 3:
		_drop(Loot.roll(lv, 0.6, tier + 4, 4 if i == 0 else 2), pos)
	if player:
		player.inventory.add(Items.get_item("piece_or"), 500 + 10 * lv)
		player.inventory.add(Items.get_item("poussiere_arcane"), 12)
		player.inventory.add(Items.get_item("pierre_ame"), 2)
		player.gain_xp(1000 + 60 * lv)
		player.feat.emit("Titan vaincu !", Color("ffb050"))
		player.notify.emit("Le titan est tombé ! Son trésor est au sol.")
	SkillFX.pillar(self, pos, Color("ffb050"), 30.0, 2.0, 2.5)
	Sound.ui("fanfare")
	changed.emit()


# ---------------------------------------------------------------- le temps qui passe

func _process(delta: float) -> void:
	if world == null:
		world = get_tree().get_first_node_in_group("world") as WorldGenerator
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
		return
	if active:
		_rift_step(delta)
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 1.0
	if _portal == null or not is_instance_valid(_portal):
		_make_portal()
	elif _portal:
		for i in 2:
			var r := _portal.get_node_or_null("Anneau%d" % i) as Node3D
			if r:
				r.rotation.z += 0.4 * (1 if i == 0 else -1)
	# titan : il apparaît quand le héros approche, disparaît quand il s'éloigne
	if not titan.is_empty():
		var d := Vector2(player.global_position.x - float(titan.x), player.global_position.z - float(titan.z)).length()
		if d < 140.0 and player.global_position.y > WorldGenerator.UNDERGROUND and (_titan_node == null or not is_instance_valid(_titan_node)):
			_spawn_titan_node()
		elif d > 200.0 and _titan_node and is_instance_valid(_titan_node):
			_despawn_titan()
		elif d < 40.0 and _titan_node and is_instance_valid(_titan_node) and not _titan_node.awake:
			_titan_node.wake()
			var dm := get_tree().get_first_node_in_group("dungeons") as DungeonManager
			if dm:
				dm.boss_awoken.emit(_titan_node, _titan_node.title)
	var day := today()
	if _day < 0:
		_day = day
	elif day != _day:
		_day = day
		if titan.is_empty() and day >= next_titan_day and player.power_level() >= 30:
			summon_titan()


func _rift_step(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	# mort dans la faille : le héros s'est réveillé au village
	if not player.is_alive() or player.global_position.y > WorldGenerator.UNDERGROUND:
		_cleanup()
		return
	_alive = _alive.filter(func(e): return is_instance_valid(e) and e.is_alive())
	if wave > WAVES or not _alive.is_empty():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 2.5
	wave += 1
	if wave <= WAVES:
		_spawn_wave()
	else:
		_spawn_rift_boss()
		wave = WAVES


# ---------------------------------------------------------------- sauvegarde

func export_state() -> Dictionary:
	return {"portal": [_portal_cell.x, _portal_cell.y], "tier": tier, "best_rift": best_rift, "titan": titan.duplicate(), "next_titan_day": next_titan_day, "titans_slain": titans_slain}


func import_state(d: Dictionary) -> void:
	tier = int(d.get("tier", 0))
	best_rift = int(d.get("best_rift", 0))
	titan = (d.get("titan", {}) as Dictionary).duplicate()
	next_titan_day = int(d.get("next_titan_day", 3))
	titans_slain = int(d.get("titans_slain", 0))
	var pc: Array = d.get("portal", [])
	if pc.size() == 2 and int(pc[0]) >= 0 and Vector2i(int(pc[0]), int(pc[1])) != _portal_cell:
		_portal_cell = Vector2i(int(pc[0]), int(pc[1]))
		if _portal and is_instance_valid(_portal):
			_portal.queue_free()
			_portal = null
	_despawn_titan()
	changed.emit()
