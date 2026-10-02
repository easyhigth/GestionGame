class_name ResourceModels
extends RefCounted
## Modèles 3D en blocs des ressources ajoutées par l'arsenal (minerais, lingots, os, cristaux, poussière),
## pour les objets posés au sol et les icônes.

static var _cache := {}


static func build(id: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if not _cache.has(id):
		_cache[id] = _make(id)
	mi.mesh = _cache[id]
	return mi


## Objets anciens sans modèle dans materials.glb (leur icône était vide) : couleur, forme.
const EXTRA := {"piece_or": ["f0c840", "coins"], "lingot_or": ["e8c040", "ingot"], "or_brut": ["e0b840", "ore"],
	"marbre_brut": ["ece8e0", "lump"], "barque": ["8a5a32", "boat"], "voilier": ["f2ecdc", "boat"], "sifflet_griffon": ["c8964a", "whistle"]}


## Vrai si l'objet a un modèle fabriqué ici.
static func has_model(id: String) -> bool:
	return Arsenal.RESOURCES.has(id) or EXTRA.has(id) or not BlockCatalog.resource_spec(id).is_empty()


static func _make(id: String) -> ArrayMesh:
	var b := WeaponModels.new()
	var c := Arsenal.resource_color(id)
	var shape := Arsenal.resource_shape(id)
	var spec := BlockCatalog.resource_spec(id)
	if not spec.is_empty():
		c = spec[0]
		shape = spec[1]
	elif EXTRA.has(id):
		c = Color(EXTRA[id][0])
		shape = EXTRA[id][1]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	match shape:
		"coins":
			for i in 5:
				b.box(5, 0.9, 5, c if i % 2 == 0 else c.darkened(0.12), rng.randf_range(-0.6, 0.6), 0.45 + i * 0.95, rng.randf_range(-0.6, 0.6))
			b.box(5, 0.9, 5, c, 4.5, 0.45, 1.5)
			b.box(5, 0.9, 5, c.lightened(0.15), 2.5, 1.4, 3.5)
		"boat":
			var wood := Color("8a5a32")
			b.box(12, 2.4, 5, wood, 0, 1.2, 0)
			b.box(10, 0.6, 3.6, wood.lightened(0.2), 0, 2.2, 0)
			b.box(2, 2.4, 3, wood.darkened(0.15), 6.6, 1.8, 0)
			if c != wood:
				b.box(0.6, 9, 0.6, wood.darkened(0.3), 0, 6.5, 0)
				b.box(0.3, 6, 5, c, 0.5, 7, 0)
		"whistle":
			b.box(2, 2, 7, c, 0, 1, 0)
			b.box(2.4, 2.4, 1.6, c.darkened(0.2), 0, 1, -3.6)
			b.box(1, 1, 1, Color("2a2a2a"), 0, 2.1, 1)
		"log":
			var inner: Color = spec[2] if spec.size() > 2 else c.lightened(0.3)
			for i in 2:
				b.box(4, 4, 11, c, -2.2 + i * 4.4, 2, 0)
				b.box(3, 3, 0.4, inner, -2.2 + i * 4.4, 2, 5.6)
			b.box(4, 4, 11, c.darkened(0.1), 0, 5.6, 0.5)
			b.box(3, 3, 0.4, inner, 0, 5.6, 6.1)
		"ore":
			var rock := Color("7a7a76")
			b.box(8, 6, 7, rock, 0, 3, 0)
			b.box(6, 3, 5, rock.lightened(0.1), 1, 6.5, 0)
			for i in 6:
				b.box(1.8, 1.8, 1.8, c, rng.randf_range(-3.5, 3.5), rng.randf_range(1.5, 6.5), 3.6 if i % 2 == 0 else -3.6)
		"ingot":
			b.box(9, 3, 4.4, c, 0, 1.5, 0)
			b.box(7.6, 0.8, 3.2, c.lightened(0.25), 0, 3.3, 0)
		"lump":
			b.box(6, 5, 6, c, 0, 2.5, 0, 0.3, 0.2)
			b.box(4, 3, 4, c.lightened(0.15), 2, 4, 1, 0.5, 0.4)
		"bone":
			b.box(2, 10, 2, c, 0, 5, 0, 0, 1.2)
			for s in [-1, 1]:
				b.box(3, 3, 3, c.darkened(0.08), s * 4.2, 5 + s * 2.8, 0, 0, 1.2)
		"crystal":
			b.box(4, 9, 4, c, 0, 4.5, 0, 0.0, 0.15, true)
			b.box(3, 6, 3, c.lightened(0.2), 2.6, 3, 1, 0.2, -0.4, true)
			b.box(2.4, 5, 2.4, c.darkened(0.1), -2.4, 2.5, -0.6, -0.2, 0.4, true)
		"dust":
			b.box(8, 2, 8, Color("6a4a2a"), 0, 1, 0)
			for i in 9:
				b.box(1.4, 1.4, 1.4, c, rng.randf_range(-3, 3), 2.6 + rng.randf() * 2.0, rng.randf_range(-3, 3), 0.6, 0.6, true)
		_:
			b.box(6, 6, 6, c, 0, 3, 0)
	return b._build()
