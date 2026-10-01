class_name Heraldry
extends Node3D
## Personnalisation du royaume (panneau « Bannière et trophées », depuis le panneau du royaume U) :
##  - le nom du royaume, ses deux couleurs et son emblème : ils s'affichent sur les étendards plantés
##    autour du village et sur les étendards que l'on pose (meuble « Étendard ») ;
##  - l'allée des trophées : chaque boss de donjon vaincu a sa statue de pierre autour du feu de camp.

signal changed

const COLORS := [["Pourpre", Color("8a1e2e")], ["Azur", Color("2a4a9a")], ["Sinople", Color("2a7a3a")], ["Or", Color("e0b030")],
	["Argent", Color("e8e8f0")], ["Sable", Color("24222a")], ["Orangé", Color("e07a2a")], ["Violet", Color("6a3a9a")]]
const EMBLEMS := [["Couronne", "♛"], ["Étoile", "✦"], ["Épées", "⚔"], ["Soleil", "☀"], ["Lune", "☾"], ["Fleur", "❦"],
	["Tour", "♜"], ["Croix", "✠"], ["Cavalier", "♞"], ["Flocon", "❄"]]
## Emplacements des statues (une par région à boss), en cercle autour du feu de camp.
const TROPHY_SLOTS := ["prairie", "foret", "marais", "desert", "montagnes", "toundra", "bois_enchante", "volcan", "jungle"]
const TROPHY_RADIUS := 8.5
const BANNER_SPOTS := [Vector2(11, 11), Vector2(-11, 11), Vector2(11, -11), Vector2(-11, -11)]

var primary := 0
var secondary := 3
var emblem := 0
var custom_name := ""
var statues := {}
var _tick := 1.0
var _built := false


func _ready() -> void:
	add_to_group("heraldry")
	if not SaveGame.heraldry_state.is_empty():
		import_state(SaveGame.heraldry_state)
		SaveGame.heraldry_state = {}


func primary_color() -> Color:
	return COLORS[primary][1]


func secondary_color() -> Color:
	return COLORS[secondary][1]


func emblem_char() -> String:
	return EMBLEMS[emblem][1]


func cycle(what: String, step := 1) -> void:
	match what:
		"primary":
			primary = posmod(primary + step, COLORS.size())
			if primary == secondary:
				primary = posmod(primary + step, COLORS.size())
		"secondary":
			secondary = posmod(secondary + step, COLORS.size())
			if secondary == primary:
				secondary = posmod(secondary + step, COLORS.size())
		"emblem":
			emblem = posmod(emblem + step, EMBLEMS.size())
	refresh()


func set_kingdom_name(n: String) -> void:
	custom_name = n.strip_edges().substr(0, 32)
	refresh()


func refresh() -> void:
	for b in get_tree().get_nodes_in_group("banners"):
		if b.has_method("apply"):
			b.apply(self)
	changed.emit()


func _world() -> WorldGenerator:
	return get_tree().get_first_node_in_group("world") as WorldGenerator


func _ground(w: WorldGenerator, p: Vector3) -> Vector3:
	p.y = w.ground_height_at(p + Vector3(0, 6, 0))
	return p


func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 2.0
	var w := _world()
	if w == null:
		return
	if not _built:
		_built = true
		var center := w.cell_center(w.spawn_cell)
		for s in BANNER_SPOTS:
			var b := BannerPole.new()
			b.name = "Etendard"
			add_child(b)
			b.global_position = _ground(w, center + Vector3(s.x, 0, s.y))
			b.rotation.y = atan2(-s.x, -s.y)
	_update_trophies(w)


## Une statue pour chaque boss vaincu (l'âme de sa région est absorbée).
func _update_trophies(w: WorldGenerator) -> void:
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null:
		return
	for i in TROPHY_SLOTS.size():
		var id: String = TROPHY_SLOTS[i]
		if statues.has(id) or not p.souls.has(id):
			continue
		var path := "res://data/regions/%s.tres" % id
		if not ResourceLoader.exists(path):
			continue
		var r := load(path) as RegionData
		if r == null or r.boss == null or r.boss.model == null:
			continue
		var a := TAU * float(i) / float(TROPHY_SLOTS.size()) + 0.35
		var pos := w.cell_center(w.spawn_cell) + Vector3(cos(a), 0, sin(a)) * TROPHY_RADIUS
		statues[id] = _make_statue(r, _ground(w, pos), a)


func _make_statue(r: RegionData, pos: Vector3, a: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Trophee_" + r.id
	add_child(root)
	root.global_position = pos
	root.rotation.y = -a - PI * 0.5
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.62, 0.6, 0.57)
	stone.roughness = 0.9
	var ped := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(1.5, 0.6, 1.5)
	ped.mesh = pm
	ped.position.y = 0.3
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.45, 0.43, 0.42)
	ped.material_override = pmat
	root.add_child(ped)
	var model := r.boss.model.instantiate() as Node3D
	root.add_child(model)
	model.position.y = 0.6
	model.scale = Vector3.ONE * clampf(0.75 / maxf(0.5, r.boss.model_scale * 0.5), 0.35, 0.9)
	_stone(model, stone)
	var l := Label3D.new()
	l.text = "Trophée\n%s" % r.boss.display_name
	l.font_size = 26
	l.pixel_size = 0.006
	l.outline_size = 6
	l.modulate = Color(0.95, 0.88, 0.7)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position.y = 3.0
	root.add_child(l)
	return root


static func _stone(n: Node, mat: StandardMaterial3D) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = mat
	if n is AnimationPlayer:
		(n as AnimationPlayer).stop()
	for c in n.get_children():
		_stone(c, mat)


func export_state() -> Dictionary:
	return {"primary": primary, "secondary": secondary, "emblem": emblem, "name": custom_name}


func import_state(d: Dictionary) -> void:
	primary = clampi(int(d.get("primary", 0)), 0, COLORS.size() - 1)
	secondary = clampi(int(d.get("secondary", 3)), 0, COLORS.size() - 1)
	emblem = clampi(int(d.get("emblem", 0)), 0, EMBLEMS.size() - 1)
	custom_name = str(d.get("name", ""))
	if is_inside_tree():
		refresh()
