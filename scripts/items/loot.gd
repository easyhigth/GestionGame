class_name Loot
extends RefCounted
## Butin de niveau (failles, titans, monstres des paliers du monde) : une pièce d'équipement de base avec un
## niveau d'objet (1 à 1000), une rareté (commune à mystique) et des bonus tirés au sort.
## Identifiant : « base#niveau.rareté.graine » (ex. « sword_iron#240.5.81723 ») ; l'objet est refabriqué
## à la demande à partir de son identifiant, comme les objets améliorés à la forge (sauvegarde comprise).

## Multiplicateur des statistiques et nombre de bonus selon la rareté (0 commune ... 5 mystique).
const RARITY_MULT := [1.0, 1.15, 1.35, 1.65, 2.1, 3.0]
const AFFIXES := [0, 1, 2, 3, 4, 5]
const TITLES := ["", "solide", "de maître", "de la Faille", "des Titans", "de l'Éveil"]
## Bonus possibles : [clé, valeur au niveau 100 pour une rareté commune].
const BONUS_POOL := [["atk_pct", 0.06], ["mag_pct", 0.06], ["hp_pct", 0.06], ["crit", 0.03], ["crit_mult", 0.1],
	["lifesteal", 0.015], ["cdr_pct", 0.03], ["spd_pct", 0.03], ["regen", 1.5], ["def_flat", 4.0], ["aspd_pct", 0.04]]

static var _bases: Array = []


## Les pièces d'équipement qui peuvent servir de base (armes, armures, bijoux ordinaires : pas les objets uniques).
static func bases() -> Array:
	if _bases.is_empty():
		for it in Items.all_equipment():
			if it.base_id == "" and not it.id.contains("@") and not it.id.contains("#") and it.rarity <= ItemData.Rarity.RARE \
					and (it.attack > 0 or it.defense > 0 or it.magic > 0):
				_bases.append(it.id)
		_bases.sort()
	return _bases


static func make_id(base: String, ilvl: int, rarity: int, seed_value: int) -> String:
	return "%s#%d.%d.%d" % [base, clampi(ilvl, 1, 1000), clampi(rarity, 0, 5), absi(seed_value) % 1000000]


static func parse(id: String) -> Array:
	var base := id.get_slice("#", 0)
	var p := id.get_slice("#", 1).split(".")
	return [base, int(p[0]) if p.size() > 0 else 1, int(p[1]) if p.size() > 1 else 0, int(p[2]) if p.size() > 2 else 0]


## Fabrique l'objet à partir de son identifiant.
static func make(id: String, base: ItemData) -> ItemData:
	var spec := parse(id)
	var ilvl: int = spec[1]
	var rar: int = spec[2]
	var v := base.duplicate() as ItemData
	v.base_id = base.id
	v.id = id
	# courbe réglée avec tools/balance_sim.gd : un butin épique vaut un peu moins que l'arme forgée et raffinée
	# du même niveau, un mystique à peu près autant (avant : linéaire, il écrasait toute arme forgée)
	var scale := (1.0 + 0.03 * pow(float(ilvl), 0.95)) * float(RARITY_MULT[rar])
	if base.attack > 0:
		v.attack = roundi(base.attack * scale)
	if base.defense > 0:
		v.defense = roundi(base.defense * scale)
	if base.magic > 0:
		v.magic = roundi(base.magic * scale)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([id])
	var pool := BONUS_POOL.duplicate()
	var bonus := {}
	for i in AFFIXES[rar]:
		var pick: Array = pool.pop_at(rng.randi() % pool.size())
		var k: String = pick[0]
		var val := float(pick[1]) * (0.5 + ilvl / 200.0) * (0.8 + rar * 0.25) * rng.randf_range(0.8, 1.2)
		bonus[k] = snappedf(val, 0.001 if k not in ["regen", "def_flat"] else 0.1)
	v.bonus = bonus
	v.rarity = rar as ItemData.Rarity
	v.max_stack = 1
	var title: String = TITLES[rar]
	v.display_name = ("✦ " if rar == 5 else "") + base.display_name + (" " + title if title != "" else "") + " (niv. %d)" % ilvl
	v.description = "Butin de niveau %d. Ne s'améliore pas à la forge." % ilvl
	return v


## Tire au sort une rareté : `luck` de 0 (monstre ordinaire) à 1 (titan).
static func roll_rarity(rng: RandomNumberGenerator, luck: float, tier := 0) -> int:
	var r := rng.randf()
	var mythic := clampf(0.004 + tier * 0.002 + luck * 0.2, 0.0, 0.3)
	var legendary := clampf(0.02 + tier * 0.004 + luck * 0.35, 0.0, 0.5)
	var epic := 0.08 + luck * 0.25
	var rare := 0.2 + luck * 0.1
	if r < mythic:
		return 5
	if r < mythic + legendary:
		return 4
	if r < mythic + legendary + epic:
		return 3
	if r < mythic + legendary + epic + rare:
		return 2
	return 1 if r < 0.8 else 0


## Un objet de butin au hasard.
static func roll(ilvl: int, luck: float, tier := 0, min_rarity := 0) -> ItemData:
	var bs := bases()
	if bs.is_empty():
		return null
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var rar := maxi(min_rarity, roll_rarity(rng, luck, tier))
	return Items.get_item(make_id(bs[rng.randi() % bs.size()], ilvl, rar, rng.randi()))
