class_name SkillFX
extends RefCounted
## Effets visuels des compétences, en cubes (même style que le reste du jeu).


static func _holder(from: Node) -> Node:
	var t := from.get_tree()
	return t.current_scene if t.current_scene else t.root


static func _mat(color: Color, alpha := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color, alpha)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Anneau de cubes au sol qui s'élargit (onde de choc).
static func ring(from: Node, pos: Vector3, radius: float, color: Color, time := 0.45) -> void:
	var root := Node3D.new()
	_holder(from).add_child(root)
	root.global_position = pos + Vector3(0, 0.12, 0)
	var n := int(clampf(radius * 10.0, 16, 60))
	var mat := _mat(color, 0.85)
	var mm := MultiMeshInstance3D.new()
	var m := MultiMesh.new()
	m.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = Vector3(0.22, 0.12, 0.22)
	box.material = mat
	m.mesh = box
	m.instance_count = n
	for i in n:
		var a := TAU * i / n
		m.set_instance_transform(i, Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a), 0, sin(a))))
	mm.multimesh = m
	mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mm)
	root.scale = Vector3(0.2, 1, 0.2)
	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(root, "scale", Vector3(radius, 1, radius), time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, time).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(root.queue_free)


## Disque translucide au sol (zones qui durent).
static func disc(from: Node, pos: Vector3, radius: float, color: Color, time: float) -> Node3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = 0.05
	c.radial_segments = 12
	c.rings = 1
	mi.mesh = c
	var mat := _mat(color, 0.16)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_holder(from).add_child(mi)
	mi.global_position = pos + Vector3(0, 0.08, 0)
	var tw := mi.create_tween()
	tw.tween_interval(maxf(time - 0.4, 0.0))
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tw.tween_callback(mi.queue_free)
	return mi


## Coque à facettes autour d'un personnage (barrière).
static func shell(target: Node3D, color: Color, time: float, size := 1.2) -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = size
	s.height = size * 2.0
	s.radial_segments = 8
	s.rings = 4
	mi.mesh = s
	var mat := _mat(color, 0.25)
	mat.emission_enabled = true
	mat.emission = color
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	target.add_child(mi)
	mi.position = Vector3(0, 0.9, 0)
	mi.scale = Vector3.ONE * 0.3
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "rotation:y", PI * time * 0.4, maxf(time - 0.5, 0.1))
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	tw.tween_callback(mi.queue_free)


## Cubes qui tournent autour d'un personnage (auras).
static func orbit(target: Node3D, color: Color, time: float, radius: float, count := 8) -> Node3D:
	var root := Node3D.new()
	target.add_child(root)
	root.position = Vector3(0, 0.9, 0)
	var mat := _mat(color, 0.9)
	mat.emission_enabled = true
	mat.emission = color
	for i in count:
		var c := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3.ONE * 0.2
		c.mesh = b
		c.material_override = mat
		var a := TAU * i / count
		c.position = Vector3(cos(a) * radius, sin(a * 2.0) * 0.3, sin(a) * radius)
		c.rotation = Vector3(a, a, 0)
		root.add_child(c)
	var tw := root.create_tween()
	tw.tween_property(root, "rotation:y", TAU * time * 1.5, time)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.3).set_delay(maxf(time - 0.3, 0.0))
	tw.tween_callback(root.queue_free)
	return root


## Gros cube qui tombe du ciel puis explose (la compétence gère les dégâts avec `on_impact`).
static func meteor(from: Node, pos: Vector3, color: Color, size: float, on_impact: Callable, delay := 0.55) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3.ONE * size
	mi.mesh = b
	var mat := _mat(color, 1.0)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.5
	mi.material_override = mat
	_holder(from).add_child(mi)
	mi.global_position = pos + Vector3(2.0, 9.0, -2.0)
	disc(from, pos, size * 1.6, color, delay + 0.1)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "global_position", pos + Vector3(0, size * 0.4, 0), delay).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(mi, "rotation", Vector3(4, 3, 2), delay)
	tw.chain().tween_callback(func():
		if on_impact.is_valid():
			on_impact.call()
		mi.queue_free())


## Spirale de cubes qui converge vers le centre (tourbillon).
static func spiral(from: Node, pos: Vector3, radius: float, color: Color, time := 0.9) -> void:
	var root := Node3D.new()
	_holder(from).add_child(root)
	root.global_position = pos + Vector3(0, 0.5, 0)
	var mat := _mat(color, 0.8)
	for i in 24:
		var c := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3.ONE * 0.18
		c.mesh = b
		c.material_override = mat
		var a := TAU * i / 12.0
		var r := radius * (0.4 + 0.6 * (i % 12) / 11.0)
		c.position = Vector3(cos(a) * r, (i % 3) * 0.3, sin(a) * r)
		root.add_child(c)
	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(root, "rotation:y", TAU * 2.0, time)
	tw.tween_property(root, "scale", Vector3(0.05, 1.5, 0.05), time).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(root.queue_free)


## Colonne de lumière verticale (jugements, éclairs, mystiques) : elle jaillit puis s'efface.
static func pillar(from: Node, pos: Vector3, color: Color, height := 14.0, radius := 0.7, time := 0.6) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 8
	c.rings = 1
	mi.mesh = c
	var mat := _mat(color, 0.75)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.5
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_holder(from).add_child(mi)
	mi.global_position = pos + Vector3(0, height * 0.5, 0)
	mi.scale = Vector3(0.1, 1, 0.1)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(1, 1, 1), time * 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "scale", Vector3(0.05, 1.2, 0.05), time * 0.75).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, time * 0.75)
	tw.tween_callback(mi.queue_free)


## Plusieurs ondes de choc concentriques, l'une après l'autre.
static func shockwave(from: Node, pos: Vector3, radius: float, color: Color, waves := 3, time := 0.7) -> void:
	for i in waves:
		var k := float(i + 1) / waves
		from.get_tree().create_timer(i * 0.14, false).timeout.connect(func():
			if is_instance_valid(from):
				ring(from, pos, radius * k, color.lightened(0.15 * i), time))


## Un objet qui tombe du ciel (épée géante, pic de glace, rocher) puis appelle `on_impact`.
## shape : « blade » (lame), « spike » (pic), « rock » (bloc).
static func falling(from: Node, pos: Vector3, color: Color, shape: String, size: float, on_impact: Callable, delay := 0.45) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	match shape:
		"blade":
			b.size = Vector3(0.35, 3.2, 0.9) * size
		"spike":
			b.size = Vector3(0.5, 2.6, 0.5) * size
		_:
			b.size = Vector3.ONE * 1.2 * size
	mi.mesh = b
	var mat := _mat(color, 1.0)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.8
	mi.material_override = mat
	_holder(from).add_child(mi)
	mi.global_position = pos + Vector3(0, 18.0, 0)
	mi.rotation = Vector3(0, randf() * TAU, 0.15)
	disc(from, pos, size * 1.3, color, delay + 0.1)
	var tw := mi.create_tween()
	tw.tween_property(mi, "global_position", pos + Vector3(0, b.size.y * 0.35, 0), delay).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func():
		if on_impact.is_valid():
			on_impact.call())
	tw.tween_interval(0.5)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tw.tween_callback(mi.queue_free)


## Éclair d'écran (mystiques) : tout l'écran s'illumine un instant.
static func screen_flash(from: Node, color: Color, time := 0.5, alpha := 0.55) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	_holder(from).add_child(layer)
	var r := ColorRect.new()
	r.color = Color(color, alpha)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(r)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tw := r.create_tween()
	tw.tween_property(r, "color:a", 0.0, time).set_ease(Tween.EASE_OUT)
	tw.tween_callback(layer.queue_free)
