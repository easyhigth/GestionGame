class_name Fishing
extends Node3D
## Pêche : canne à pêche en main (C), V face à l'eau pour lancer le bouchon. Quand ça mord (« ! »),
## appuie sur V : un curseur va et vient sur une barre, appuie encore sur V quand il est dans la zone verte.
## Les poissons dépendent de la région et de la profondeur de l'eau ; la pluie les fait mordre plus vite.

signal caught(item_id: String)
signal state_changed

## Poissons : identifiant -> [régions (vide = partout), eau (« peu », « profond » ou « »), rareté (poids),
## difficulté 0 (facile) à 1 (très dur)].
const FISH := {
	"gardon": [["prairie", "foret", "bois_enchante", "marais", "jungle"], "", 10, 0.1],
	"truite": [["prairie", "foret", "montagnes"], "peu", 5, 0.35],
	"brochet": [["prairie", "foret", "marais"], "profond", 3, 0.6],
	"carpe": [["marais", "prairie", "jungle"], "", 6, 0.3],
	"anguille": [["marais", "jungle"], "profond", 3, 0.65],
	"saumon": [["montagnes", "toundra"], "", 6, 0.45],
	"omble": [["toundra"], "profond", 3, 0.6],
	"poisson_scorpion": [["desert"], "", 5, 0.5],
	"poisson_lave": [["volcan"], "", 3, 0.8],
	"poisson_lune": [["bois_enchante"], "profond", 2, 0.75],
	"perle": [[], "profond", 1, 0.9],
	"vieille_botte": [[], "", 1, 0.0],
}
const CAST_DISTANCE := 3.2
const WAIT_MIN := 3.0
const WAIT_MAX := 9.0
## Temps pour réagir quand ça mord.
const BITE_TIME := 1.3

var world: WorldGenerator
var player: Player
## « », « attente », « touche », « combat »
var state := ""
var fish := ""
var _bobber: MeshInstance3D
var _line: MeshInstance3D
var _line_mesh: ImmediateMesh
var _mark: Label3D
var _at := Vector3.ZERO
var _deep := false
var _timer := 0.0
var _from := Vector3.ZERO
## Mini-jeu : curseur (0-1), vitesse, zone verte [début, fin].
var cursor := 0.0
var _dir := 1.0
var cursor_speed := 1.0
var zone := Vector2(0.4, 0.6)
var _tries := 0


func _ready() -> void:
	add_to_group("fishing")
	top_level = true
	_bobber = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.09
	sm.height = 0.18
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.2, 0.15)
	sm.material = m
	_bobber.mesh = sm
	_bobber.visible = false
	add_child(_bobber)
	var top := MeshInstance3D.new()
	var tm := SphereMesh.new()
	tm.radius = 0.06
	tm.height = 0.1
	var m2 := StandardMaterial3D.new()
	m2.albedo_color = Color(0.95, 0.95, 0.9)
	tm.material = m2
	top.mesh = tm
	top.position.y = 0.07
	_bobber.add_child(top)
	_line_mesh = ImmediateMesh.new()
	_line = MeshInstance3D.new()
	_line.mesh = _line_mesh
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(0.9, 0.9, 0.85)
	_line.material_override = lm
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_line)
	_mark = Label3D.new()
	_mark.text = "!"
	_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_mark.font_size = 64
	_mark.pixel_size = 0.01
	_mark.outline_size = 12
	_mark.modulate = Color("ffd24a")
	_mark.visible = false
	add_child(_mark)


func is_busy() -> bool:
	return state != ""


## Où tomberait le bouchon (INF s'il n'y a pas d'eau devant).
func water_spot() -> Vector3:
	if world == null or player == null:
		return Vector3.INF
	var fwd := Vector3(player.facing.x, 0, player.facing.z).normalized()
	for d in [CAST_DISTANCE, 2.4, 4.0, 1.6]:
		var p: Vector3 = player.global_position + fwd * d
		var t := world.terrain_type(world.cell_at(p))
		if t == WorldGenerator.WATER or t == WorldGenerator.DEEP:
			return Vector3(p.x, world.water_surface + 0.02, p.z)
	return Vector3.INF


## V avec la canne : lancer, ferrer, ou arrêter le curseur du mini-jeu. Renvoie le texte à afficher.
func use() -> String:
	match state:
		"":
			return cast()
		"attente":
			reel_in()
			return "Trop tôt ! Le poisson n'avait pas mordu."
		"touche":
			_start_fight()
			return ""
		"combat":
			return _strike()
	return ""


func cast() -> String:
	var spot := water_spot()
	if spot == Vector3.INF:
		return "Il faut être face à l'eau pour pêcher."
	if player.global_position.y < WorldGenerator.UNDERGROUND:
		return ""
	_at = spot
	_deep = world.terrain_type(world.cell_at(spot)) == WorldGenerator.DEEP
	_from = player.global_position
	state = "attente"
	var wait := randf_range(WAIT_MIN, WAIT_MAX)
	if Crafts.hero_job(player) == "pecheur":
		wait *= 0.6
	var we := get_tree().get_first_node_in_group("weather") as Weather
	if we and we.is_wet():
		wait *= 0.7
	_timer = wait
	_bobber.global_position = _at
	_bobber.visible = true
	player.visual.play_move("heavy_1", 1.2)
	Sound.play("swing", player.global_position)
	get_tree().create_timer(0.25).timeout.connect(func(): if state == "attente": Sound.play("dig", _at))
	state_changed.emit()
	return ""


## Range la canne (bouchon et ligne disparaissent).
func reel_in() -> void:
	state = ""
	fish = ""
	_bobber.visible = false
	_mark.visible = false
	_line_mesh.clear_surfaces()
	state_changed.emit()


func _pick_fish() -> String:
	var r := world.region_at(_at)
	var rid: String = r.id if r else "prairie"
	var total := 0.0
	var pool := []
	for id in FISH:
		var f: Array = FISH[id]
		if not (f[0] as Array).is_empty() and not (f[0] as Array).has(rid):
			continue
		if f[1] == "profond" and not _deep:
			continue
		if f[1] == "peu" and _deep:
			continue
		pool.append(id)
		total += float(f[2])
	var x := randf() * total
	for id in pool:
		x -= float(FISH[id][2])
		if x <= 0.0:
			return id
	return "gardon"


func _start_fight() -> void:
	state = "combat"
	_mark.visible = false
	var diff: float = FISH[fish][3]
	cursor = 0.0
	_dir = 1.0
	cursor_speed = lerpf(0.7, 1.9, diff)
	var width := lerpf(0.34, 0.12, diff)
	var start := randf_range(0.15, 0.85 - width)
	zone = Vector2(start, start + width)
	_tries = 2
	state_changed.emit()


func _strike() -> String:
	if cursor >= zone.x and cursor <= zone.y:
		var it := Items.get_item(fish)
		var id := fish
		reel_in()
		if it:
			player.inventory.add(it, 1)
			Crafts.gain(player, "pecheur", 10.0 + 8.0 * int(it.rarity))
			if randf() < Crafts.double_chance(player, "pecheur"):
				player.inventory.add(it, 1)
			Sound.ui("pickup")
			VoxelBurst.spawn(self, _at + Vector3(0, 0.3, 0), Color(0.6, 0.85, 1.0), 16, 3.0, 0.07, 0.5, "up", 8.0, false)
			caught.emit(id)
			return "Tu as pêché : %s !" % it.display_name
		return ""
	_tries -= 1
	if _tries <= 0:
		reel_in()
		return "Raté ! Le poisson s'est échappé."
	Sound.play("block", _at)
	return "Presque ! Encore une chance."


func _process(delta: float) -> void:
	if state == "" or player == null:
		return
	# on bouge ou on range la canne : fin de la pêche
	if player.global_position.distance_to(_from) > 1.2 or player.hand.selected != "canne_peche" or not player.is_alive():
		reel_in()
		return
	player._show_tool("canne_peche")
	var tip := player.global_position + Vector3(0, 1.9, 0) + Vector3(player.facing.x, 0, player.facing.z).normalized() * 0.9
	_draw_line(tip, _bobber.global_position + Vector3(0, 0.05, 0))
	match state:
		"attente":
			_bobber.global_position.y = _at.y + sin(Time.get_ticks_msec() * 0.004) * 0.02
			_timer -= delta
			if _timer <= 0.0:
				fish = _pick_fish()
				state = "touche"
				_timer = BITE_TIME
				_mark.visible = true
				_mark.global_position = _at + Vector3(0, 0.9, 0)
				Sound.play("dig", _at)
				state_changed.emit()
		"touche":
			_bobber.global_position.y = _at.y - 0.08 + sin(Time.get_ticks_msec() * 0.03) * 0.05
			_timer -= delta
			if _timer <= 0.0:
				reel_in()
				player.notify.emit("Le poisson s'est décroché... ({place_click} dès qu'il mord)")
		"combat":
			_bobber.global_position.y = _at.y - 0.05 + sin(Time.get_ticks_msec() * 0.02) * 0.06
			cursor += _dir * cursor_speed * delta
			if cursor >= 1.0:
				cursor = 1.0
				_dir = -1.0
			elif cursor <= 0.0:
				cursor = 0.0
				_dir = 1.0


func _draw_line(a: Vector3, b: Vector3) -> void:
	_line_mesh.clear_surfaces()
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var sag := (a + b) * 0.5 - Vector3(0, 0.35, 0)
	var prev := a
	for i in range(1, 9):
		var t := i / 8.0
		var p := a.lerp(sag, t).lerp(sag.lerp(b, t), t)
		_line_mesh.surface_add_vertex(prev)
		_line_mesh.surface_add_vertex(p)
		prev = p
	_line_mesh.surface_end()
