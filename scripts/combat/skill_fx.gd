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
	var mat := own_glow(Color(color, 0.85), 1.6, true)
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
	tw.tween_method(func(a: float): mat.set_shader_parameter("tint", Color(color, a)), 0.85, 0.0, time).set_ease(Tween.EASE_IN)
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
	mi.material_override = own_glow(Color(color.lightened(0.3), 1.0), 2.6, false)
	_holder(from).add_child(mi)
	mi.global_position = pos + Vector3(4.0, 14.0, -3.0)
	trail(mi, color, 0.016, size * 0.3, 2.6, true)
	var halo := MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3.ONE * size * 1.3
	halo.mesh = hb
	halo.material_override = own_glow(Color(color, 0.18), 1.6, true)
	mi.add_child(halo)
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
	var mat := own_glow(Color(color, 0.5), 1.8, true)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_holder(from).add_child(mi)
	mi.global_position = pos + Vector3(0, height * 0.5, 0)
	mi.scale = Vector3(0.1, 1, 0.1)
	# cœur blanc, plus fin
	var core := MeshInstance3D.new()
	var cc := CylinderMesh.new()
	cc.top_radius = radius * 0.35
	cc.bottom_radius = radius * 0.35
	cc.height = height
	cc.radial_segments = 6
	cc.rings = 1
	core.mesh = cc
	core.material_override = own_glow(Color(1, 1, 1, 0.7), 2.2, true)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_child(core)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(1, 1, 1), time * 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "scale", Vector3(0.05, 1.2, 0.05), time * 0.75).set_ease(Tween.EASE_IN)
	tw.parallel().tween_method(func(a: float): mat.set_shader_parameter("tint", Color(color, a)), 0.5, 0.0, time * 0.75)
	tw.tween_callback(mi.queue_free)
	VoxelBurst.emit(from, pos, {"palette": VoxelBurst.palette_of(color), "count": int(clampf(height * 1.5, 10, 70)), "speed": height * 0.6,
		"size": 0.08, "life": time * 1.2, "mode": "column", "radius": radius * 1.2, "hdr": 2.4, "gravity": 0.0, "drag": 0.5, "streak": 1.5})
	light(from, pos + Vector3(0, 1.5, 0), color, 4.0, maxf(radius * 6.0, 5.0), time)


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
			b.size = Vector3(0.14, 3.4, 0.62) * size
		"spike":
			b.size = Vector3(0.5, 2.6, 0.5) * size
		_:
			b.size = Vector3.ONE * 1.2 * size
	mi.mesh = b
	var mat := _mat(color, 1.0)
	mi.material_override = own_glow(Color(color.lightened(0.15), 1.0), 1.35, false)
	# un liseré lumineux autour
	var edge := MeshInstance3D.new()
	var eb := BoxMesh.new()
	eb.size = b.size * Vector3(1.25, 1.02, 1.25)
	edge.mesh = eb
	edge.material_override = own_glow(Color(color, 0.3), 2.0, true)
	edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_child(edge)
	if shape == "blade":
		# une vraie épée : garde, poignée et pommeau sombres au-dessus de la lame
		var metal := StandardMaterial3D.new()
		metal.albedo_color = Color(0.25, 0.2, 0.18)
		metal.metallic = 0.6
		# [taille, hauteur du centre au-dessus de la lame]
		for part in [[Vector3(0.22, 0.16, 1.5), 0.08], [Vector3(0.16, 0.7, 0.16), 0.51], [Vector3(0.26, 0.22, 0.26), 0.97]]:
			var pm := MeshInstance3D.new()
			var pb := BoxMesh.new()
			pb.size = (part[0] as Vector3) * size
			pm.mesh = pb
			pm.material_override = metal
			pm.position = Vector3(0, b.size.y * 0.5 + float(part[1]) * size, 0)
			mi.add_child(pm)
	_holder(from).add_child(mi)
	mi.global_position = pos + Vector3(0, 18.0, 0)
	mi.rotation = Vector3(0, randf() * TAU, 0.15)
	trail(mi, color, 0.03, 0.12 * size, 2.4)
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


# ---------------------------------------------------------------- effets lumineux (v2)
# Matériaux « qui brillent » (voir fx_glow_add / fx_glow_mix), lumières qui s'éteignent, explosions en
# plusieurs couches, éclairs zigzag, entailles en croissant, cercles de runes, impacts des coups.

const SH_ADD := preload("res://scripts/combat/fx_glow_add.gdshader")
const SH_MIX := preload("res://scripts/combat/fx_glow_mix.gdshader")
static var _mats := {}
static var lights_live := 0
const MAX_LIGHTS := 6


## Matériau partagé qui brille (couleur prise sur les sommets ou les instances).
static func glow_mat(energy := 2.0, additive := true) -> ShaderMaterial:
	var key := "%s_%.1f" % ["a" if additive else "m", energy]
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = SH_ADD if additive else SH_MIX
		m.set_shader_parameter("energy", energy)
		m.set_shader_parameter("tint", Color.WHITE)
		_mats[key] = m
	return _mats[key]


## Matériau propre à un objet (pour le faire disparaître en fondu), couleur `color`.
static func own_glow(color: Color, energy := 2.0, additive := true) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SH_ADD if additive else SH_MIX
	m.set_shader_parameter("energy", energy)
	m.set_shader_parameter("tint", color)
	return m


static func _fade(node: Node, m: ShaderMaterial, color: Color, time: float, delay := 0.0) -> Tween:
	var tw := node.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(a: float): m.set_shader_parameter("tint", Color(color, a)), color.a, 0.0, time)
	tw.tween_callback(node.queue_free)
	return tw


## Lumière qui éclaire le décor un instant (explosions, éclairs). Au plus MAX_LIGHTS à la fois.
static func light(from: Node, pos: Vector3, color: Color, energy := 4.0, rng := 6.0, time := 0.35) -> void:
	if lights_live >= MAX_LIGHTS or not is_instance_valid(from) or not from.is_inside_tree():
		return
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	_holder(from).add_child(l)
	l.global_position = pos
	SkillFX.lights_live += 1
	l.tree_exited.connect(func(): SkillFX.lights_live -= 1)
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, time).set_ease(Tween.EASE_IN)
	tw.tween_callback(l.queue_free)


## Boule de lumière qui gonfle puis s'efface (cœur d'une explosion, éclat d'un coup).
static func flash_sphere(from: Node, pos: Vector3, color: Color, radius: float, time := 0.25, energy := 3.0) -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 10
	s.rings = 5
	mi.mesh = s
	# plus elle est grande, moins elle est opaque : elle éclaire sans effacer l'image
	var e := clampf(energy / (1.0 + radius * 0.6), 0.6, energy)
	var a := clampf(0.75 / (1.0 + radius * 0.25), 0.18, 0.75)
	var m := own_glow(Color(color.lightened(0.35), a), e, true)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_holder(from).add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * radius * 0.3
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * radius, time * 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_fade(mi, m, Color(color.lightened(0.35), a), time)


## Étoile d'impact : deux traits de lumière en croix qui jaillissent et s'effacent (coups critiques).
static func star(from: Node, pos: Vector3, color: Color, size := 1.0, time := 0.18) -> void:
	var root := Node3D.new()
	_holder(from).add_child(root)
	root.global_position = pos
	var cam := from.get_viewport().get_camera_3d() if from.get_viewport() else null
	if cam:
		root.look_at(cam.global_position, Vector3.UP, true)
	var m := own_glow(Color(color.lightened(0.5), 1.0), 3.0, true)
	for i in 2:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.06, 1.0, 0.02)
		mi.mesh = b
		mi.material_override = m
		mi.rotation.z = PI * 0.25 + i * PI * 0.5 + randf_range(-0.2, 0.2)
		root.add_child(mi)
	root.scale = Vector3(0.3, 0.3, 0.3) * size
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector3(1.6, 1.6, 1.0) * size, time * 0.4).set_ease(Tween.EASE_OUT)
	_fade(root, m, Color(color.lightened(0.5), 1.0), time)


## Entaille en croissant (coup d'arme, lame d'énergie) : un arc lumineux, épais au milieu, effilé aux
## pointes, qui s'élargit et s'efface. `dir` : direction du coup, `tilt` : inclinaison (radians).
static func slash(from: Node, pos: Vector3, dir: Vector3, color: Color, radius := 1.6, arc_deg := 150.0,
		tilt := 0.0, time := 0.28, width := 0.45) -> void:
	var im := ImmediateMesh.new()
	var seg := 18
	var half := deg_to_rad(arc_deg) * 0.5
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in seg + 1:
		var t := float(i) / seg
		var a := -half + t * half * 2.0
		var thick := sin(t * PI) * width
		var outer := Vector3(sin(a), 0, cos(a)) * radius
		var inner := Vector3(sin(a), 0, cos(a)) * (radius - thick)
		var c := Color(color.lightened(0.6), 0.0)
		im.surface_set_color(Color(1, 1, 1, 0.95 * sin(t * PI)))
		im.surface_add_vertex(outer)
		im.surface_set_color(c)
		im.surface_add_vertex(inner)
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	var m := own_glow(Color(color.lightened(0.25), 1.0), 2.6, true)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_holder(from).add_child(mi)
	var f := Vector3(dir.x, 0, dir.z).normalized() if Vector3(dir.x, 0, dir.z).length() > 0.01 else Vector3.FORWARD
	mi.global_transform = Transform3D(Basis.looking_at(-f, Vector3.UP).rotated(f, tilt), pos)
	mi.scale = Vector3.ONE * 0.75
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * 1.15, time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_fade(mi, m, Color(color.lightened(0.25), 1.0), time)


## Éclair en zigzag de `a` à `b`, avec des ramifications ; il crépite (deux éclats) puis s'éteint.
static func lightning(from: Node, a: Vector3, b: Vector3, color: Color, width := 0.08, time := 0.3, branches := 2) -> void:
	var pts: Array[Vector3] = [a]
	var len := a.distance_to(b)
	var n := clampi(int(len / 0.45), 3, 30)
	var dir := (b - a).normalized()
	var side := dir.cross(Vector3.UP)
	if side.length() < 0.05:
		side = dir.cross(Vector3.RIGHT)
	side = side.normalized()
	var up := side.cross(dir)
	for i in range(1, n):
		var t := float(i) / n
		var j := (1.0 - absf(t - 0.5) * 2.0) * len * 0.12
		pts.append(a.lerp(b, t) + side * randf_range(-j, j) + up * randf_range(-j, j))
	pts.append(b)
	var segs: Array = []
	for i in pts.size() - 1:
		segs.append([pts[i], pts[i + 1], width])
	# ramifications : de courtes fourches qui partent du trait principal
	for k in branches:
		var i0 := randi_range(1, maxi(1, pts.size() - 2))
		var p0: Vector3 = pts[i0]
		var bd := (dir + side * randf_range(-1.2, 1.2) + up * randf_range(-0.6, 0.6)).normalized()
		var cur := p0
		for s in randi_range(2, 4):
			var nxt := cur + bd * randf_range(0.3, 0.6) + side * randf_range(-0.2, 0.2)
			segs.append([cur, nxt, width * 0.55])
			cur = nxt
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	mm.mesh = box
	mm.instance_count = segs.size() * 2
	for i in segs.size():
		var p: Vector3 = segs[i][0]
		var q: Vector3 = segs[i][1]
		var w: float = segs[i][2]
		var y := q - p
		var l := y.length()
		if l < 0.001:
			continue
		var yn := y / l
		var x := yn.cross(Vector3.UP)
		if x.length() < 0.05:
			x = yn.cross(Vector3.RIGHT)
		x = x.normalized()
		var z := x.cross(yn)
		# un cœur blanc et un halo de la couleur
		mm.set_instance_transform(i * 2, Transform3D(Basis(x * w, y, z * w), (p + q) * 0.5))
		mm.set_instance_color(i * 2, Color(1, 1, 1, 1))
		mm.set_instance_transform(i * 2 + 1, Transform3D(Basis(x * w * 3.0, y, z * w * 3.0), (p + q) * 0.5))
		mm.set_instance_color(i * 2 + 1, Color(color, 0.45))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var m := own_glow(Color(color.lightened(0.3), 1.0), 3.0, true)
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_holder(from).add_child(mmi)
	mmi.global_transform = Transform3D.IDENTITY
	var tw := mmi.create_tween()
	var c := Color(color.lightened(0.3), 1.0)
	# crépitement : il s'éteint, se rallume, puis s'efface
	tw.tween_callback(func(): m.set_shader_parameter("tint", Color(c, 0.25))).set_delay(time * 0.25)
	tw.tween_callback(func(): m.set_shader_parameter("tint", c)).set_delay(time * 0.12)
	tw.tween_method(func(v: float): m.set_shader_parameter("tint", Color(c, v)), 1.0, 0.0, time * 0.6)
	tw.tween_callback(mmi.queue_free)
	light(from, b, color.lightened(0.3), 5.0, 6.0, time)


## Cercle de runes au sol : deux anneaux qui tournent en sens contraires, des glyphes et des rayons.
## Apparaît en grandissant, tourne pendant `time` puis s'efface.
static func runes(from: Node, pos: Vector3, radius: float, color: Color, time := 1.2, follow: Node3D = null) -> Node3D:
	var root := Node3D.new()
	if follow:
		follow.add_child(root)
		root.position = Vector3(0, 0.08, 0)
	else:
		_holder(from).add_child(root)
		root.global_position = pos + Vector3(0, 0.1, 0)
	var m := own_glow(Color(color.lightened(0.2), 0.9), 2.2, true)
	var parts := []
	for ring_i in 2:
		var r := radius * (1.0 if ring_i == 0 else 0.68)
		var n := int(clampf(r * 18.0, 24, 96))
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		var box := BoxMesh.new()
		box.size = Vector3.ONE
		mm.mesh = box
		var glyphs := 8 if ring_i == 0 else 6
		mm.instance_count = n + glyphs * 3
		for i in n:
			var a := TAU * i / n
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, -a).scaled(Vector3(0.05, 0.03, TAU * r / n * 1.05)), Vector3(cos(a), 0, sin(a)) * r))
			mm.set_instance_color(i, Color(1, 1, 1, 0.9))
		# glyphes : petits motifs de trois cubes entre les deux anneaux
		for g in glyphs:
			var a2 := TAU * g / glyphs
			var gr := r * (0.86 if ring_i == 0 else 0.8)
			var base := Vector3(cos(a2), 0, sin(a2)) * gr
			var tng := Vector3(-sin(a2), 0, cos(a2))
			var shapes := [[Vector3.ZERO, Vector3(0.22, 0.03, 0.06)], [tng * 0.12, Vector3(0.06, 0.03, 0.2)], [-tng * 0.12 + base.normalized() * 0.08, Vector3(0.06, 0.03, 0.12)]]
			for s in 3:
				var off: Vector3 = shapes[s][0]
				var sz: Vector3 = shapes[s][1] * clampf(radius / 3.0, 0.7, 2.0)
				mm.set_instance_transform(n + g * 3 + s, Transform3D(Basis(Vector3.UP, -a2).scaled(sz), base + off))
				mm.set_instance_color(n + g * 3 + s, Color(1, 1, 1, 1))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = m
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)
		parts.append(mmi)
	root.scale = Vector3(0.1, 1, 0.1)
	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(root, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(parts[0], "rotation:y", TAU * 0.35 * time, time)
	tw.tween_property(parts[1], "rotation:y", -TAU * 0.6 * time, time)
	_fade(root, m, Color(color.lightened(0.2), 0.9), 0.35, maxf(time - 0.35, 0.05))
	return root


## Brûlure au sol : une tache sombre qui s'efface lentement (après une explosion).
static func scorch(from: Node, pos: Vector3, radius: float, time := 3.0) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = 0.02
	c.radial_segments = 10
	c.rings = 1
	mi.mesh = c
	var mat := _mat(Color(0.08, 0.06, 0.05), 0.55)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_holder(from).add_child(mi)
	mi.global_position = pos + Vector3(0, 0.06, 0)
	mi.rotation.y = randf() * TAU
	var tw := mi.create_tween()
	tw.tween_interval(time * 0.6)
	tw.tween_property(mat, "albedo_color:a", 0.0, time * 0.4)
	tw.tween_callback(mi.queue_free)


## Explosion en couches : éclair de lumière, boule de feu, étincelles, flammèches, fumée, débris,
## onde au sol et brûlure. `size` : 1 pour une explosion moyenne (~2 m), 3 pour une énorme.
static func explosion(from: Node, pos: Vector3, color: Color, size := 1.0, smoke := true) -> void:
	if not is_instance_valid(from) or not from.is_inside_tree():
		return
	var pal := VoxelBurst.palette_of(color)
	var n := clampf(size, 0.4, 4.0)
	flash_sphere(from, pos + Vector3(0, 0.5, 0), color, minf(0.7 * size, 3.0), 0.24, 3.0)
	light(from, pos + Vector3(0, 1.0, 0), color.lightened(0.2), minf(3.0 + size, 6.0), 4.0 * size + 3.0, 0.45)
	# étincelles : des traits de lumière projetés dans tous les sens
	VoxelBurst.emit(from, pos + Vector3(0, 0.5, 0), {"palette": pal, "count": int(36 * n), "speed": 8.0 * sqrt(n) + 3.0,
		"size": 0.06, "life": 0.5, "streak": 2.2, "hdr": 1.9, "gravity": 7.0, "drag": 1.5})
	# boule de feu : de gros cubes qui gonflent et montent
	VoxelBurst.emit(from, pos + Vector3(0, 0.6, 0), {"palette": pal, "count": int(26 * n), "speed": 3.2 * sqrt(n),
		"size": 0.26 * sqrt(n), "life": 0.55, "hdr": 1.5, "gravity": -2.5, "drag": 3.5, "grow": true, "add": false})
	# onde au sol
	VoxelBurst.emit(from, pos + Vector3(0, 0.15, 0), {"palette": pal, "count": int(30 * n), "speed": 7.0 * sqrt(n),
		"size": 0.1, "life": 0.4, "mode": "disc", "hdr": 1.6, "gravity": 0.0, "drag": 3.0, "streak": 1.0})
	ring(from, pos, 2.2 * size, color.lightened(0.2), 0.4)
	if smoke:
		VoxelBurst.emit(from, pos + Vector3(0, 0.8, 0), {"color": Color(0.22, 0.2, 0.2), "palette": [Color(0.18, 0.16, 0.16), Color(0.3, 0.28, 0.27), Color(0.42, 0.38, 0.35)],
			"count": int(14 * n), "speed": 1.6 * sqrt(n), "size": 0.42 * sqrt(n), "life": 1.4, "mode": "up", "glow": false,
			"grow": true, "alpha": 0.55, "gravity": -1.2, "drag": 1.4, "spin": 0.3})
		VoxelBurst.emit(from, pos + Vector3(0, 0.3, 0), {"palette": [Color("6a5a48"), Color("4a4038"), Color("8a7a60")],
			"count": int(12 * n), "speed": 6.0, "size": 0.14, "life": 0.9, "glow": false, "gravity": 16.0, "drag": 0.6})
		scorch(from, pos, 1.2 * size, 3.5)


## Impact d'un coup : petit éclat, étincelles dans le sens du coup ; les critiques ajoutent une étoile
## de lumière, une onde et une lumière.
static func impact(from: Node, pos: Vector3, color: Color, dir := Vector3.ZERO, crit := false, heavy := false) -> void:
	if not is_instance_valid(from) or not from.is_inside_tree():
		return
	var pal := VoxelBurst.palette_of(color)
	var d := dir if dir.length() > 0.01 else Vector3.UP
	flash_sphere(from, pos, color, 0.55 if crit or heavy else 0.32, 0.14, 3.0)
	VoxelBurst.emit(from, pos, {"palette": pal, "count": 22 if crit else (16 if heavy else 10), "speed": 7.5 if crit else 5.5,
		"size": 0.05, "life": 0.3, "mode": "cone", "dir": d, "spread": 55.0, "streak": 2.5, "hdr": 2.4, "gravity": 6.0})
	if crit or heavy:
		star(from, pos, color, 1.4 if crit else 1.0, 0.2)
		VoxelBurst.emit(from, pos, {"palette": pal, "count": 18, "speed": 5.0, "size": 0.06, "life": 0.3, "mode": "ring",
			"hdr": 2.2, "gravity": 0.0, "streak": 1.5})
	if crit:
		light(from, pos, color, 3.0, 4.0, 0.2)


## Traînée de particules qui suit un nœud (projectile, météore) tant qu'il existe.
static func trail(target: Node3D, color: Color, rate := 0.03, size := 0.1, hdr := 2.2, smoke := false) -> void:
	var t := Trail.new()
	t.color = color
	t.rate = rate
	t.size = size
	t.hdr = hdr
	t.smoke = smoke
	target.add_child(t)


## Particules qui partent de `start` et volent jusqu'à `to` (vol de vie, soin d'un allié, absorption).
static func stream(from: Node, start: Vector3, to: Node3D, color: Color, count := 14, time := 0.6) -> void:
	for i in count:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3.ONE * randf_range(0.07, 0.13)
		mi.mesh = b
		var col := Color(color.lightened(randf() * 0.4), 1.0)
		mi.material_override = own_glow(col, 2.4, true)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_holder(from).add_child(mi)
		var p0 := start + Vector3(randf_range(-0.4, 0.4), randf_range(0.2, 1.2), randf_range(-0.4, 0.4))
		mi.global_position = p0
		var mid := p0 + Vector3(randf_range(-1.2, 1.2), randf_range(0.6, 1.8), randf_range(-1.2, 1.2))
		var tw := mi.create_tween()
		var dur := time * randf_range(0.7, 1.2)
		tw.tween_interval(randf() * 0.25)
		tw.tween_method(func(t: float):
			if not is_instance_valid(to):
				return
			var end := to.global_position + Vector3(0, 1.0, 0)
			mi.global_position = p0.lerp(mid, t).lerp(mid.lerp(end, t), t)
			mi.scale = Vector3.ONE * (1.0 - t * 0.6), 0.0, 1.0, dur).set_ease(Tween.EASE_IN)
		tw.tween_callback(mi.queue_free)


class Trail extends Node3D:
	var color := Color.WHITE
	var rate := 0.03
	var size := 0.1
	var hdr := 2.2
	var smoke := false
	var _t := 0.0

	func _process(delta: float) -> void:
		_t -= delta
		if _t > 0.0:
			return
		_t = rate
		VoxelBurst.emit(self, global_position, {"palette": VoxelBurst.palette_of(color), "count": 3, "speed": 0.8,
			"size": size, "life": 0.35, "hdr": hdr, "gravity": -1.0, "drag": 3.0})
		if smoke and randf() < 0.5:
			VoxelBurst.emit(self, global_position, {"color": Color(0.25, 0.22, 0.2), "count": 1, "speed": 0.4, "size": size * 2.5,
				"life": 0.8, "glow": false, "grow": true, "alpha": 0.5, "gravity": -1.0, "mode": "up"})
