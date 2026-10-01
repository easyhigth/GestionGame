class_name WorldChest
extends Node3D
## Coffre posé dans le monde (trésor d'un château, cale d'une épave...). E : il s'ouvre une fois,
## son contenu tombe au sol. Les coffres ouverts sont notés par le monde (et sauvegardés).

const MODEL := preload("res://assets/furniture/coffre.glb")
## Contenu selon le lieu : [objet, minimum, maximum, chance].
const LOOT := {
	"castle": [["piece_or", 40, 90, 1.0], ["iron_ingot", 2, 5, 0.7], ["lingot_or", 1, 3, 0.5], ["gemme_rubis", 1, 1, 0.3],
		["gemme_saphir", 1, 1, 0.3], ["potion_soin", 1, 2, 0.6]],
	"castle_lord": [["piece_or", 20, 40, 1.0], ["pain", 2, 4, 0.8], ["iron_ingot", 1, 2, 0.5]],
	"wreck": [["piece_or", 25, 60, 1.0], ["perle", 1, 3, 0.7], ["lingot_or", 1, 1, 0.3], ["gemme_emeraude", 1, 1, 0.25],
		["potion_force", 1, 1, 0.4]],
}

var chest_id := ""
var kind := "castle"
var opened := false
var _label: Label3D


func _ready() -> void:
	add_to_group("world_chests")
	var m := MODEL.instantiate() as Node3D
	add_child(m)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 32
	_label.pixel_size = 0.006
	_label.outline_size = 9
	_label.position.y = 1.5
	add_child(_label)
	_refresh()


func _refresh() -> void:
	_label.text = "Vide" if opened else ("Trésor\nE : ouvrir" if kind != "wreck" else "Coffre de l'épave\nE : ouvrir")
	_label.modulate = Color(0.7, 0.7, 0.7) if opened else Color("ffd24a")


func open(p: Player) -> void:
	if opened:
		return
	opened = true
	var world := get_tree().get_first_node_in_group("world") as WorldGenerator
	if world:
		world.opened_chests[chest_id] = true
	var out := []
	for l in LOOT.get(kind, LOOT.castle):
		var it := Items.get_item(l[0]) as ItemData
		if it and randf() < float(l[3]):
			out.append([it, randi_range(int(l[1]), int(l[2]))])
	var rare := RareDrops.roll_chest("coffre")
	out.append_array(rare)
	RareDrops.announce(p, rare)
	for i in out.size():
		var a := TAU * i / maxf(1.0, out.size())
		if world:
			world.spawn_pickup(out[i][0], global_position + Vector3(cos(a), 0.2, sin(a)) * 1.2, out[i][1])
	VoxelBurst.spawn(self, global_position + Vector3(0, 0.8, 0), Color("ffd24a"), 20, 4.0, 0.1, 0.7, "up", 4.0)
	Sound.play("coins", global_position)
	if p:
		p.notify.emit("Coffre ouvert : %d trésors." % out.size())
	_refresh()


## Le coffre le plus proche du héros (à moins de 2 m), ou null.
static func nearest(p: Player) -> WorldChest:
	var best: WorldChest = null
	var bd := 2.2
	for c in p.get_tree().get_nodes_in_group("world_chests"):
		var d: float = (c as Node3D).global_position.distance_to(p.global_position)
		if d < bd and not (c as WorldChest).opened:
			bd = d
			best = c
	return best
