class_name VoxelBurst
extends MultiMeshInstance3D
## Gerbe de petits cubes (étincelles d'impact, onde de choc, éclatement d'un monstre vaincu, fumée...).
## Se détruit toute seule à la fin.
## `spawn` : la gerbe simple d'une couleur. `emit` : la version complète (palette de couleurs, éclat qui
## « brille » avec le halo de l'image, étincelles étirées dans le sens de leur vitesse, fumée qui gonfle,
## gerbe en cône, implosion vers un point...).

var _pos: Array[Vector3] = []
var _vel: Array[Vector3] = []
var _age: Array[float] = []
var _life: Array[float] = []
var _size: Array[float] = []
var _rot: Array[Vector3] = []
var _col: Array[Color] = []
var gravity := 9.0
var drag := 2.0
var color := Color.WHITE
var glow := true
## Multiplicateur de lumière (> 1,3 : la gerbe brille avec le halo de l'image).
var hdr := 1.0
## Étirement des cubes dans le sens de leur vitesse (0 : cubes ; 1 à 3 : étincelles, traits de lumière).
var streak := 0.0
## Les cubes grossissent au lieu de rétrécir (fumée, poussière).
var grow := false
## Opacité de départ.
var alpha := 1.0
## Point d'attraction (implosion, aspiration) : les cubes y convergent.
var attract := Vector3.INF
var attract_force := 0.0
var spin := 1.0
## Mélange additif (traits de lumière) ou normal (flammes, cubes pleins qui brillent sans tout blanchir).
var additive := true

## Nombre de cubes d'effets vivants (pour alléger les gerbes quand il y en a beaucoup à la fois).
static var live := 0
const BUDGET := 2600


## Crée une gerbe à `pos`. `mode` : "sphere" (toutes directions), "ring" (onde au sol), "up" (vers le haut).
static func spawn(parent: Node, pos: Vector3, col: Color, count: int, speed: float, size: float,
		life: float, mode := "sphere", grav := 9.0, emissive := true) -> VoxelBurst:
	return emit(parent, pos, {"color": col, "count": count, "speed": speed, "size": size, "life": life,
		"mode": mode, "gravity": grav, "glow": emissive})


## Gerbe complète. Options (toutes facultatives) :
##   color / palette (couleurs tirées au hasard), count, speed, size, life, mode, gravity, drag, glow,
##   hdr (éclat), streak (étincelles étirées), grow (fumée), alpha, dir + spread (degrés) pour le mode « cone »,
##   radius (rayon de départ des modes « implode », « disc », « column » et « shell »), pull, spin.
## Modes : sphere, ring, up, cone, disc (à plat vers l'extérieur), implode (du rayon vers le centre),
##   shell (sur une sphère, vers l'extérieur), column (colonne qui monte).
static func emit(parent: Node, pos: Vector3, o: Dictionary) -> VoxelBurst:
	var b := VoxelBurst.new()
	var count := int(o.get("count", 20))
	# trop de cubes à l'écran : on allège les gerbes suivantes (jamais en dessous de 2)
	if live > BUDGET:
		count = maxi(2, count / 4)
	elif live > BUDGET * 0.6:
		count = maxi(2, count / 2)
	var col: Color = o.get("color", Color.WHITE)
	var pal: Array = o.get("palette", [col])
	b.color = col
	b.gravity = float(o.get("gravity", 9.0))
	b.drag = float(o.get("drag", 2.0))
	b.glow = bool(o.get("glow", true))
	b.hdr = float(o.get("hdr", 1.0))
	b.streak = float(o.get("streak", 0.0))
	b.grow = bool(o.get("grow", false))
	b.alpha = float(o.get("alpha", 1.0))
	b.spin = float(o.get("spin", 1.0))
	b.additive = bool(o.get("add", true))
	var speed := float(o.get("speed", 4.0))
	var size := float(o.get("size", 0.1))
	var life := float(o.get("life", 0.5))
	var mode := str(o.get("mode", "sphere"))
	var radius := float(o.get("radius", 1.0))
	var fwd: Vector3 = (o.get("dir", Vector3.FORWARD) as Vector3).normalized()
	var spread := deg_to_rad(float(o.get("spread", 30.0)))
	if mode == "implode":
		b.attract = pos
		b.attract_force = float(o.get("pull", 18.0))
	for i in count:
		var dir: Vector3
		var start := pos
		var v := speed * randf_range(0.6, 1.2)
		match mode:
			"ring":
				var a := TAU * i / count + randf() * 0.2
				dir = Vector3(cos(a), randf_range(0.05, 0.25), sin(a))
			"up":
				dir = Vector3(randf_range(-0.5, 0.5), 1.0, randf_range(-0.5, 0.5)).normalized()
			"column":
				var a2 := randf() * TAU
				start = pos + Vector3(cos(a2), 0, sin(a2)) * randf() * radius
				dir = Vector3(randf_range(-0.12, 0.12), 1.0, randf_range(-0.12, 0.12)).normalized()
			"cone":
				var side := fwd.cross(Vector3.UP)
				if side.length() < 0.01:
					side = Vector3.RIGHT
				side = side.normalized()
				dir = fwd.rotated(Vector3.UP, randf_range(-spread, spread)).rotated(side, randf_range(-spread, spread) * 0.4).normalized()
			"disc":
				var a3 := randf() * TAU
				dir = Vector3(cos(a3), randf_range(0.0, 0.08), sin(a3))
				start = pos + dir * radius * randf() * 0.3
			"implode":
				var d3 := Vector3(randf_range(-1, 1), randf_range(-0.4, 1), randf_range(-1, 1)).normalized()
				start = pos + d3 * radius * randf_range(0.7, 1.1)
				# vitesse tangentielle : les cubes tournent en spirale avant d'arriver
				var tan := d3.cross(Vector3.UP)
				dir = tan.normalized() if tan.length() > 0.05 else Vector3.RIGHT
				v *= 0.6
			"shell":
				var d4 := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
				start = pos + d4 * radius
				dir = d4
			_:
				dir = Vector3(randf_range(-1, 1), randf_range(-0.3, 1), randf_range(-1, 1)).normalized()
		b._pos.append(start + dir * 0.05)
		b._vel.append(dir * v)
		b._age.append(0.0)
		b._life.append(life * randf_range(0.7, 1.2))
		b._size.append(size * randf_range(0.6, 1.3))
		b._rot.append(Vector3(randf() * TAU, randf() * TAU, 0))
		b._col.append(pal[randi() % pal.size()])
	var holder: Node = parent.get_tree().current_scene if parent.get_tree().current_scene else parent.get_tree().root
	holder.add_child(b)
	return b


## Palette « feu » d'une couleur : cœur blanc, la couleur, une teinte plus vive et une plus sombre.
static func palette_of(c: Color) -> Array:
	return [c.lightened(0.6), c.lightened(0.4), c, c, c.lightened(0.2), c.darkened(0.25)]


func _ready() -> void:
	top_level = true
	# gerbes remplies à la main (sans emit) : la couleur de la gerbe pour chaque cube
	while _col.size() < _pos.size():
		_col.append(color)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	if glow and hdr > 1.0:
		# lumière additive : la gerbe « brille » avec le halo de l'image
		box.material = SkillFX.glow_mat(hdr, additive)
	else:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if glow else BaseMaterial3D.SHADING_MODE_PER_PIXEL
		mat.vertex_color_use_as_albedo = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		box.material = mat
	mm.mesh = box
	mm.instance_count = _pos.size()
	multimesh = mm
	global_transform = Transform3D.IDENTITY
	live += _pos.size()


func _exit_tree() -> void:
	live = maxi(0, live - _pos.size())


func _process(delta: float) -> void:
	var alive := 0
	var mm := multimesh
	for i in _pos.size():
		_age[i] += delta
		var k := _age[i] / _life[i]
		if k >= 1.0:
			mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.0001), _pos[i]))
			continue
		alive += 1
		if attract != Vector3.INF:
			var to := attract - _pos[i]
			_vel[i] += to.normalized() * attract_force * delta * (1.0 + k * 3.0)
		_vel[i].y -= gravity * delta
		_vel[i] *= maxf(0.0, 1.0 - drag * delta)
		_pos[i] += _vel[i] * delta
		var s := _size[i] * ((0.5 + k * 1.5) if grow else (1.0 - k * k))
		var basis: Basis
		var sp := _vel[i].length()
		if streak > 0.0 and sp > 0.3:
			# étincelle : un cube étiré dans le sens de sa course
			var y := _vel[i] / sp
			var x := y.cross(Vector3.UP)
			if x.length() < 0.05:
				x = y.cross(Vector3.RIGHT)
			x = x.normalized()
			var z := x.cross(y)
			basis = Basis(x * s, y * s * (1.0 + streak * minf(sp, 12.0) * 0.35), z * s)
		else:
			_rot[i] += Vector3(6, 4, 0) * delta * spin
			basis = Basis.from_euler(_rot[i]).scaled(Vector3.ONE * s)
		mm.set_instance_transform(i, Transform3D(basis, _pos[i]))
		var a := (1.0 - k) if grow else (1.0 - k * 0.6)
		mm.set_instance_color(i, Color(_col[i], a * alpha))
	if alive == 0:
		queue_free()
