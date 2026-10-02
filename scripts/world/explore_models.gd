class_name ExploreModels
extends RefCounted
## Modèles en blocs (cubes colorés, comme le reste du monde) du voilier et du griffon.


static func _mat(col: Color, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.85
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	return m


static func _box(parent: Node3D, size: Vector3, pos: Vector3, col: Color, name := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(col)
	mi.position = pos
	if name != "":
		mi.name = name
	parent.add_child(mi)
	return mi


## Voilier : coque de planches, pont, mât, grande voile blanche à bande colorée, et un petit drapeau.
## Long de 5 m, la proue vers +Z.
static func sailboat(stripe := Color("c83a3a")) -> Node3D:
	var root := Node3D.new()
	root.name = "Voilier"
	var hull := Color("7a5230")
	var dark := Color("5a3a20")
	var deck := Color("b08a5a")
	# coque : de plus en plus étroite vers la proue et la poupe
	var widths := [0.9, 1.5, 1.9, 2.1, 2.1, 2.0, 1.8, 1.4, 0.8]
	for i in widths.size():
		var z := -2.0 + i * 0.5
		var w: float = widths[i]
		_box(root, Vector3(w, 0.5, 0.52), Vector3(0, 0.0, z), hull)
		_box(root, Vector3(w + 0.1, 0.18, 0.52), Vector3(0, 0.32, z), dark)
		_box(root, Vector3(maxf(0.2, w - 0.3), 0.06, 0.5), Vector3(0, 0.26, z), deck)
	# proue relevée
	_box(root, Vector3(0.4, 0.5, 0.4), Vector3(0, 0.45, 2.45), dark)
	# mât et vergue
	_box(root, Vector3(0.16, 4.2, 0.16), Vector3(0, 2.3, 0.2), dark)
	_box(root, Vector3(2.6, 0.12, 0.12), Vector3(0, 3.9, 0.1), dark)
	# la voile (légèrement gonflée : deux plans décalés)
	var sail := Node3D.new()
	sail.name = "Voile"
	root.add_child(sail)
	_box(sail, Vector3(2.4, 2.4, 0.06), Vector3(0, 2.6, 0.0), Color("f2ecdc"))
	_box(sail, Vector3(2.0, 2.0, 0.06), Vector3(0, 2.6, -0.08), Color("f8f4ea"))
	_box(sail, Vector3(2.42, 0.4, 0.08), Vector3(0, 2.4, 0.02), stripe)
	# petit drapeau en haut du mât
	_box(root, Vector3(0.06, 0.3, 0.5), Vector3(0, 4.5, 0.45), stripe)
	# une lanterne à la poupe
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.75, 0.4)
	l.light_energy = 0.8
	l.omni_range = 5.0
	l.position = Vector3(0, 1.0, -2.0)
	root.add_child(l)
	_box(root, Vector3(0.2, 0.25, 0.2), Vector3(0, 0.8, -2.0), Color("ffd27a"))
	return root


## Griffon : corps de lion fauve, tête d'aigle blanche au bec doré, grandes ailes (animées par flap()).
## Long de 3 m, la tête vers +Z.
static func griffon() -> Node3D:
	var root := Node3D.new()
	root.name = "Griffon"
	var fur := Color("c8964a")
	var fur_d := Color("9a6a30")
	var feather := Color("f2ead8")
	var beak := Color("f0b030")
	var body := Node3D.new()
	body.name = "Corps"
	root.add_child(body)
	_box(body, Vector3(1.0, 0.9, 2.0), Vector3(0, 1.2, 0), fur)
	_box(body, Vector3(1.05, 0.5, 0.9), Vector3(0, 1.35, 0.7), feather)
	# pattes
	for sx in [-0.35, 0.35]:
		_box(body, Vector3(0.26, 0.8, 0.26), Vector3(sx, 0.4, 0.7), fur_d)
		_box(body, Vector3(0.26, 0.8, 0.26), Vector3(sx, 0.4, -0.7), fur_d)
		_box(body, Vector3(0.3, 0.1, 0.36), Vector3(sx, 0.05, 0.78), beak)
	# cou et tête d'aigle
	_box(body, Vector3(0.6, 0.7, 0.5), Vector3(0, 1.75, 1.05), feather)
	_box(body, Vector3(0.62, 0.6, 0.65), Vector3(0, 2.15, 1.3), feather)
	_box(body, Vector3(0.24, 0.22, 0.4), Vector3(0, 2.05, 1.75), beak)
	_box(body, Vector3(0.16, 0.12, 0.16), Vector3(0, 1.95, 1.9), beak.darkened(0.2))
	for sx in [-0.26, 0.26]:
		_box(body, Vector3(0.08, 0.1, 0.1), Vector3(sx, 2.25, 1.55), Color("1a1410"))
	# plumes de la crête
	_box(body, Vector3(0.12, 0.35, 0.3), Vector3(0, 2.55, 1.15), feather.darkened(0.1))
	# queue de lion
	_box(body, Vector3(0.14, 0.14, 0.9), Vector3(0, 1.3, -1.4), fur_d)
	_box(body, Vector3(0.26, 0.26, 0.26), Vector3(0, 1.3, -1.9), fur_d.darkened(0.2))
	# ailes
	for side in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.name = "AileG" if side < 0 else "AileD"
		wing.position = Vector3(0.5 * side, 1.6, 0.4)
		body.add_child(wing)
		_box(wing, Vector3(1.2, 0.12, 0.9), Vector3(0.6 * side, 0, 0), feather)
		_box(wing, Vector3(1.0, 0.1, 0.7), Vector3(1.6 * side, 0, -0.1), feather.darkened(0.08))
		_box(wing, Vector3(0.7, 0.08, 0.5), Vector3(2.3 * side, 0, -0.2), fur_d.lightened(0.3))
	# selle
	_box(body, Vector3(0.8, 0.14, 0.7), Vector3(0, 1.7, 0.0), Color("8a2a2a"))
	return root


## Battement d'ailes (t : temps en secondes ; plus vite en vol).
static func flap(g: Node3D, t: float, flying: bool) -> void:
	var body := g.get_node_or_null("Corps")
	if body == null:
		return
	var a := sin(t * (7.0 if flying else 1.5)) * (0.7 if flying else 0.12) + (0.15 if flying else -0.55)
	var l := body.get_node_or_null("AileG") as Node3D
	var r := body.get_node_or_null("AileD") as Node3D
	if l:
		l.rotation.z = -a
	if r:
		r.rotation.z = a
	(body as Node3D).position.y = sin(t * 3.5) * 0.08 if flying else 0.0
