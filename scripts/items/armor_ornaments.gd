class_name ArmorOrnaments
extends RefCounted
## Ornements en blocs propres à chaque matériau des panoplies (ArmorSets) : les pièces reprennent les modèles en
## fer et en cuir teints, et ces ornements leur donnent une identité (rivets du cuivre et de l'acier, cimier du
## bronze et de l'or, pointes d'os, cristaux d'obsidienne, runes de mithril, flammes d'orichalque, cornes et
## écailles draconiques). Ils sont placés d'après la boîte englobante de la pièce teinte : ils suivent la taille
## de chaque race.

## Matériau -> [couleur des ornements, couleur des gemmes, style, lueur].
const STYLES := {
	"cuivre": ["e8a070", "e8a070", "rivets", false],
	"bronze": ["dcb060", "c83a3a", "crest", false],
	"os": ["f4f0e4", "f4f0e4", "spikes", false],
	"acier": ["dfe6ee", "3a3a44", "rivets", false],
	"argent": ["f6f8fc", "6ad0ff", "gems", true],
	"or": ["ffe08a", "ff3a5a", "crest", false],
	"obsidienne": ["8a5ad0", "c06aff", "crystals", true],
	"mithril": ["e8f8ff", "6ae8ff", "runes", true],
	"orichalque": ["ffd08a", "ffaa3a", "flames", true],
	"draconique": ["2a1010", "ff7a3a", "horns", true],
}

static var _cache := {}


## Le maillage d'ornement d'une pièce (dans le repère de l'os `bone`), ou null.
static func mesh(mat: String, bone: String, aabb: AABB, piece := "") -> ArrayMesh:
	if not STYLES.has(mat):
		return null
	var key := "%s|%s|%s|%s" % [mat, bone, aabb, piece]
	if _cache.has(key):
		return _cache[key]
	var st: Array = STYLES[mat]
	var b := WeaponModels.new()
	var col := Color(st[0])
	var gem := Color(st[1])
	var glow: bool = st[3]
	var u := 1.0 / WeaponModels.UNIT
	var lo := aabb.position * u
	var hi := aabb.end * u
	var c := (lo + hi) * 0.5
	var w := hi.x - lo.x
	match bone:
		"Head":
			_head(b, str(st[2]), col, gem, glow, lo, hi, c, w)
		"Torso":
			_torso(b, str(st[2]), col, gem, glow, lo, hi, c, w)
		_:
			_limb(b, str(st[2]), col, gem, glow, lo, hi, c, bone.ends_with("L"))
	_silhouette(b, mat, bone, piece, lo, hi, c, w)
	var m := b._build() if not b._boxes.is_empty() else null
	_cache[key] = m
	return m


static func _head(b: WeaponModels, style: String, col: Color, gem: Color, glow: bool, lo: Vector3, hi: Vector3, c: Vector3, w: float) -> void:
	match style:
		"crest":
			for i in 5:
				b.box(0.9, 1.6 - absf(i - 2) * 0.3, 1.2, col if i % 2 == 0 else gem, c.x, hi.y + 0.6, lo.z + (hi.z - lo.z) * (0.15 + i * 0.17))
		"spikes", "horns":
			for s in [-1, 1]:
				b.box(1.2, 1.2, 1.2, col, c.x + s * (w * 0.5 + 0.2), hi.y - 0.8, c.z, 0.0, s * 0.6)
				b.box(0.9, 1.6, 0.9, col, c.x + s * (w * 0.5 + 0.9), hi.y + 0.4, c.z, 0.0, s * 0.5)
				b.box(0.6, 1.2, 0.6, col.lightened(0.3), c.x + s * (w * 0.5 + 1.3), hi.y + 1.4, c.z, 0.0, s * 0.3)
			if style == "horns":
				b.box(1.0, 1.0, 1.0, gem, c.x, hi.y - 1.2, hi.z + 0.2, 0.6, 0.6, glow)
		"crystals":
			for i in 3:
				b.box(0.9, 2.0 - i * 0.4, 0.9, gem, c.x + (i - 1) * 1.2, hi.y + 0.6, c.z, 0.0, (i - 1) * 0.3, glow)
		"gems", "runes":
			b.box(1.1, 1.1, 0.6, gem, c.x, lo.y + (hi.y - lo.y) * 0.72, hi.z + 0.1, 0.0, 0.78, glow)
		"flames":
			for i in 4:
				b.box(0.7, 1.4 + (i % 2) * 0.8, 0.7, gem if i % 2 == 0 else col, c.x + (i - 1.5) * 0.9, hi.y + 0.8, c.z, 0.0, 0.0, glow)
		_:
			for s in [-1, 1]:
				b.box(0.6, 0.6, 0.6, col, c.x + s * w * 0.35, lo.y + 0.6, hi.z + 0.1)


static func _torso(b: WeaponModels, style: String, col: Color, gem: Color, glow: bool, lo: Vector3, hi: Vector3, c: Vector3, w: float) -> void:
	var front := hi.z + 0.1
	var chest_y := lo.y + (hi.y - lo.y) * 0.62
	match style:
		"rivets":
			for i in 3:
				for s in [-1, 1]:
					b.box(0.55, 0.55, 0.4, col, c.x + s * w * 0.3, chest_y - i * 1.4, front)
		"crest", "gems":
			b.box(2.2, 2.2, 0.5, col, c.x, chest_y, front, 0.0, 0.78)
			b.box(1.2, 1.2, 0.6, gem, c.x, chest_y, front + 0.1, 0.0, 0.78, glow)
		"runes":
			for i in 3:
				b.box(0.4, 1.6, 0.4, gem, c.x + (i - 1) * 1.0, chest_y - 0.4, front, 0.0, 0.0, glow)
			b.box(2.6, 0.4, 0.4, gem, c.x, chest_y + 0.8, front, 0.0, 0.0, glow)
		"flames":
			for i in 5:
				b.box(0.6, 1.2 + (i % 2) * 0.8, 0.4, gem if i % 2 == 0 else col, c.x + (i - 2) * 0.8, chest_y, front, 0.0, 0.0, glow)
		"spikes", "horns", "crystals":
			for s in [-1, 1]:
				for i in 2:
					b.box(0.8, 1.4, 0.8, gem if style == "crystals" else col, c.x + s * (w * 0.5 - 0.4 - i * 1.1), hi.y + 0.4 - i * 0.3, c.z, 0.0, s * 0.4, glow and style != "spikes")
			if style == "horns":
				for i in 3:
					b.box(1.0, 0.8, 0.4, gem, c.x, chest_y - i * 1.0, front, 0.0, 0.78, glow)


static func _limb(b: WeaponModels, style: String, col: Color, gem: Color, glow: bool, lo: Vector3, hi: Vector3, c: Vector3, left: bool) -> void:
	var side := hi.x + 0.1 if not left else lo.x - 0.1
	var s := 1.0 if not left else -1.0
	var y := lo.y + (hi.y - lo.y) * 0.6
	match style:
		"spikes", "horns", "crystals":
			for i in 2:
				b.box(0.7, 0.7, 1.2, gem if style == "crystals" else col, side + s * 0.3, y - i * 1.2, c.z, 0.0, s * 0.5, glow and style != "spikes")
		"gems", "runes", "flames":
			b.box(0.6, 0.9, 0.6, gem, side, y, c.z, 0.0, 0.0, glow)
		_:
			b.box(0.5, 0.5, 0.5, col, side, y, c.z)
			b.box(0.5, 0.5, 0.5, col, side, y - 1.0, c.z)


## Silhouette propre au matériau : épaulières (plastron, sur les bras), tassettes (bas du plastron),
## visière (casque), genouillères (jambières). Teinte proche de la pièce (couleur du matériau, plus sombre).
const SHAPES := {
	"cuivre": {"pauldron": 0, "tassets": 0, "visor": false, "knee": false},
	"bronze": {"pauldron": 1, "tassets": 0, "visor": false, "knee": true},
	"os": {"pauldron": 1, "tassets": 1, "visor": false, "knee": false},
	"acier": {"pauldron": 2, "tassets": 2, "visor": true, "knee": true},
	"argent": {"pauldron": 1, "tassets": 1, "visor": false, "knee": true},
	"or": {"pauldron": 2, "tassets": 1, "visor": false, "knee": true},
	"obsidienne": {"pauldron": 2, "tassets": 2, "visor": true, "knee": true},
	"mithril": {"pauldron": 2, "tassets": 2, "visor": true, "knee": true},
	"orichalque": {"pauldron": 3, "tassets": 2, "visor": false, "knee": true},
	"draconique": {"pauldron": 3, "tassets": 3, "visor": true, "knee": true},
}
const MAT_COLORS := {"cuivre": "c87a4a", "bronze": "b8863a", "os": "e0d8c0", "acier": "8a96a8", "argent": "d0d6e0", "or": "e0b848",
	"obsidienne": "3a2a4a", "mithril": "a8d8f0", "orichalque": "f0943a", "draconique": "b02a2a"}


static func _silhouette(b: WeaponModels, mat: String, bone: String, piece: String, lo: Vector3, hi: Vector3, c: Vector3, w: float) -> void:
	var sh: Dictionary = SHAPES.get(mat, {})
	var col := Color(MAT_COLORS.get(mat, "888888")).darkened(0.12)
	var h := hi.y - lo.y
	var d := hi.z - lo.z
	if piece == "iron_armor" and bone.begins_with("Arm") and int(sh.get("pauldron", 0)) > 0:
		# épaulière : une plaque sur le haut du bras, plus large et étagée selon le matériau
		var n := int(sh.pauldron)
		var s := -1.0 if bone.ends_with("L") else 1.0
		var x := (lo.x if s < 0 else hi.x)
		for i in n:
			var sz := 3.4 - i * 0.7
			b.box(sz, 1.0, d + 1.2 - i * 0.3, col.lightened(0.08 * i), x + s * (0.3 + i * 0.25), hi.y - 0.4 - i * 0.9, c.z, 0.0, s * (0.25 + i * 0.12))
		if mat in ["draconique", "obsidienne", "orichalque"]:
			b.box(0.7, 1.6, 0.7, col.lightened(0.3), x + s * 1.4, hi.y + 0.6, c.z, 0.0, s * 0.5)
	elif piece == "iron_armor" and bone == "Torso" and int(sh.get("tassets", 0)) > 0:
		# tassettes : des plaques qui pendent du bas du plastron
		var n := int(sh.tassets) + 1
		for i in n:
			var x := lo.x + w * (i + 0.5) / n
			b.box(w / n - 0.2, 1.8 + 0.3 * (i % 2), 0.6, col, x, lo.y - 0.6, hi.z - 0.2)
	elif piece in ["iron_helmet", "horned_helmet"] and bone == "Head" and bool(sh.get("visor", false)):
		# visière : une grille devant le visage
		b.box(w * 0.85, h * 0.35, 0.5, col.darkened(0.15), c.x, lo.y + h * 0.42, hi.z + 0.3)
		for i in 3:
			b.box(w * 0.85, 0.25, 0.6, col.lightened(0.1), c.x, lo.y + h * (0.3 + i * 0.12), hi.z + 0.35)
	elif piece == "iron_greaves" and bone.begins_with("Leg") and bool(sh.get("knee", false)):
		# genouillère
		b.box(w * 0.9, 1.4, 0.8, col.lightened(0.1), c.x, lo.y + h * 0.5, hi.z + 0.3, 0.3, 0.0)
