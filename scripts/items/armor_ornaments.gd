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
static func mesh(mat: String, bone: String, aabb: AABB) -> ArrayMesh:
	if not STYLES.has(mat):
		return null
	var key := "%s|%s|%s" % [mat, bone, aabb]
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
