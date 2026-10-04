class_name FarmAnimal
extends Node3D
## Un animal de la ferme : poule, mouton ou vache.
## Sauvage, il broute près de chez lui ; il suit le héros qui tient sa nourriture en main (C pour la choisir).
## Mené près d'une mangeoire, il devient domestique : il reste dans l'enclos (autour de la mangeoire,
## les barrières l'arrêtent) et donne œufs, laine ou lait s'il est nourri (réserve du village).

## Espèces : nom, modèles, nourriture qui l'attire, produit, tous les combien de secondes, nourriture
## prise dans la réserve à chaque produit, vitesse, hauteur de l'étiquette.
const SPECIES := {
	"poule": {"name": "Poule", "plural": "poules", "models": ["chicken", "chicken_brown"], "food": "graines_ble",
		"product": "oeuf", "every": 150.0, "feed": 2.0, "speed": 1.6, "label_y": 0.95,
		"hp": 4, "loot": [["viande_crue", 1, 1], ["graines_ble", 0, 2]]},
	"mouton": {"name": "Mouton", "plural": "moutons", "models": ["sheep"], "food": "ble",
		"product": "laine", "every": 300.0, "feed": 4.0, "speed": 1.3, "label_y": 1.55,
		"hp": 10, "loot": [["viande_crue", 1, 2], ["laine", 1, 2]]},
	"vache": {"name": "Vache", "plural": "vaches", "models": ["cow", "cow_brown"], "food": "ble",
		"product": "lait", "every": 240.0, "feed": 5.0, "speed": 1.2, "label_y": 2.0,
		"hp": 14, "loot": [["viande_crue", 2, 3], ["leather", 1, 2]]},
}
## Rayon de l'enclos autour de la mangeoire, et de la promenade d'un animal sauvage.
const PEN_RADIUS := 5.0
const WILD_RADIUS := 6.0
## Distance à laquelle il remarque la nourriture, et à laquelle il abandonne.
const LURE_DISTANCE := 9.0
const LOSE_DISTANCE := 16.0

var species := "poule"
var model_index := 0
var domestic := false
var home := Vector3.ZERO
var following := false
## Jours avant d'être adulte (0 = adulte).
var baby_days := 0
var product_timer := 0.0
var hungry := false
var world: WorldGenerator
var visual: VoxelCharacter
var label: Label3D
var facing := Vector3.BACK
var _target := Vector3.INF
var _pause := 0.0
var _heart := 0.0
## Points de vie (0 : selon l'espèce) ; un animal frappé s'enfuit un moment.
var hp := 0
var _flee_left := 0.0
var _flee_from := Vector3.ZERO
var _knock := Vector3.ZERO


func setup(sp: String, index := -1) -> void:
	species = sp
	var models: Array = SPECIES[sp].models
	model_index = index if index >= 0 else randi() % models.size()


func info() -> Dictionary:
	return SPECIES[species]


func _ready() -> void:
	add_to_group("farm_animals")
	if world == null:
		world = get_tree().get_first_node_in_group("world") as WorldGenerator
	visual = VoxelCharacter.new()
	visual.name = "Visual"
	add_child(visual)
	var models: Array = info().models
	var scene := load("res://assets/characters/creatures/%s.glb" % models[clampi(model_index, 0, models.size() - 1)]) as PackedScene
	visual.set_model(scene)
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 26
	label.pixel_size = 0.006
	label.outline_size = 8
	label.visible = false
	add_child(label)
	_apply_age()
	if hp <= 0:
		hp = max_hp()
	facing = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	if home == Vector3.ZERO:
		home = global_position


# ---------------------------------------------------------------- chasse

func max_hp() -> int:
	return maxi(1, int(info().get("hp", 6)) / (2 if is_baby() else 1))


func is_alive() -> bool:
	return hp > 0 and is_inside_tree() and not is_queued_for_deletion()


## Frappé (par le héros) : il a mal, recule, s'enfuit ; à 0 point de vie, il tombe et laisse viande,
## laine ou cuir. Renvoie vrai si le coup a porté.
func take_hit(dmg: int, from: Node3D) -> bool:
	if not is_alive():
		return false
	dmg = maxi(1, dmg)
	hp = maxi(0, hp - dmg)
	following = false
	var away := global_position - from.global_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else -facing
	_knock = away * 5.0
	_flee_from = from.global_position
	_flee_left = 4.0
	visual.flash(Color(1, 0.3, 0.3, 0.7), 0.15)
	visual.play_move("flinch", 1.4)
	var top := global_position + Vector3(0, float(info().label_y), 0)
	Combat.popup(self, top, str(dmg), Color("ffe070"))
	VoxelBurst.emit(self, global_position + Vector3(0, float(info().label_y) * 0.5, 0), {"color": Color(0.75, 0.12, 0.1), "count": 8,
		"speed": 3.0, "size": 0.07, "life": 0.4, "glow": false, "gravity": 9.0})
	Sound.play("hit_fist", global_position + Vector3(0, 0.6, 0), -2.0)
	if hp <= 0:
		_die(from)
	return true


func _die(from: Node3D) -> void:
	var inf := info()
	var n := 0
	for l in inf.get("loot", []):
		var it := Items.get_item(str(l[0]))
		var k := randi_range(int(l[1]), int(l[2]))
		if is_baby():
			k = mini(k, 1)
		if it and k > 0:
			var a := TAU * n / 4.0 + randf() * 0.5
			world.spawn_pickup(it, global_position + Vector3(cos(a), 0, sin(a)) * 0.6, k, get_parent())
			n += 1
	VoxelBurst.emit(self, global_position + Vector3(0, 0.5, 0), {"color": Color(0.95, 0.92, 0.85), "count": 14, "speed": 2.5,
		"size": 0.12, "life": 0.6, "glow": false, "grow": true, "alpha": 0.7, "gravity": -0.5})
	Sound.play("enemy_die", global_position, -6.0)
	var p := from as Player
	if p:
		p.notify.emit("%s abattu%s." % [inf.name, "e" if species in ["poule", "vache"] else ""])
	queue_free()


func _apply_age() -> void:
	var s := 0.55 if baby_days > 0 else 1.0
	visual.scale = Vector3.ONE * s
	label.position.y = float(info().label_y) * s + 0.25


func is_baby() -> bool:
	return baby_days > 0


func grow_up() -> void:
	if baby_days > 0:
		baby_days -= 1
		_apply_age()


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


## Le héros tient la nourriture de cet animal en main.
func _lured_by(p: Player) -> bool:
	return p != null and p.is_alive() and p.hand != null and p.hand.selected == info().food


func _process(delta: float) -> void:
	if world == null:
		return
	var p := _player()
	var d := global_position.distance_to(p.global_position) if p else 999.0
	# attiré par sa nourriture
	if not following and _lured_by(p) and d < LURE_DISTANCE and not is_baby():
		following = true
		_heart = 1.2
	elif following and (not _lured_by(p) or d > LOSE_DISTANCE):
		following = false
		if not domestic:
			home = global_position
	var speed: float = float(info().speed) * (1.6 if following else 1.0)
	var velocity := Vector3.ZERO
	_knock = _knock.move_toward(Vector3.ZERO, 14.0 * delta)
	if _flee_left > 0.0:
		# effrayé : il détale loin de celui qui l'a frappé
		_flee_left -= delta
		var away := global_position - _flee_from
		away.y = 0.0
		if away.length() > 0.01:
			facing = away.normalized()
		velocity = facing * speed * 2.2 + _knock
		_target = Vector3.INF
	elif following:
		var to := p.global_position - global_position
		to.y = 0.0
		if to.length() > 1.8:
			facing = to.normalized()
			velocity = facing * speed * 1.4
	else:
		if _pause > 0.0:
			_pause -= delta
		else:
			if _target == Vector3.INF:
				var r := PEN_RADIUS if domestic else WILD_RADIUS
				var a := randf() * TAU
				_target = home + Vector3(cos(a), 0, sin(a)) * randf_range(0.5, r)
			var to := _target - global_position
			to.y = 0.0
			if to.length() < 0.2:
				_target = Vector3.INF
				_pause = randf_range(1.5, 5.0)
			else:
				facing = to.normalized()
				velocity = facing * speed
	if velocity != Vector3.ZERO:
		var from := global_position
		var next := from + velocity * delta
		var cell := world.cell_at(next)
		var blocked := world.build.body_blocked(cell, from.y) or not world.is_walkable(next)
		# domestique : il ne quitte pas l'enclos (sauf s'il suit le héros)
		if domestic and not following and Vector2(next.x - home.x, next.z - home.z).length() > PEN_RADIUS + 0.5:
			blocked = true
		if blocked:
			_target = Vector3.INF
			_pause = randf_range(0.5, 1.5)
			velocity = Vector3.ZERO
		else:
			next.y = world.support_height(next, from.y + 0.6)
			if absf(next.y - from.y) > 1.1:
				_target = Vector3.INF
				velocity = Vector3.ZERO
			else:
				global_position = next
	visual.animate(delta, velocity, facing)
	_update_label(d, p, delta)


func _update_label(d: float, p: Player, delta: float) -> void:
	_heart = maxf(0.0, _heart - delta)
	# une bête de l'enclos ne s'affiche que tout près (elles sont souvent nombreuses)
	var near := d < (3.0 if domestic else 6.0)
	label.visible = near or _heart > 0.0
	if not label.visible:
		return
	if _heart > 0.0 and not near:
		label.text = "♥"
		label.modulate = Color("ff8aa0")
		return
	var inf := info()
	var food_it := Items.get_item(inf.food)
	var t: String = inf.name + (" (petit)" if is_baby() else "")
	if domestic:
		t += " · à toi" + (" · a faim" if hungry else "")
		label.modulate = Color("ffe8b0") if not hungry else Color("ffb08a")
	else:
		label.modulate = Color("e8f0d8")
		if following:
			t += "\n♥ te suit : mène-le à une mangeoire"
		elif food_it:
			t += "\n%s en main pour l'attirer" % food_it.display_name.to_lower()
	label.text = t


# ---------------------------------------------------------------- sauvegarde

func export_state() -> Dictionary:
	return {"sp": species, "m": model_index, "pos": [global_position.x, global_position.y, global_position.z],
		"home": [home.x, home.y, home.z], "baby": baby_days, "t": product_timer}
