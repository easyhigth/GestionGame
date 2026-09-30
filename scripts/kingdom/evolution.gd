class_name Evolution
extends RefCounted
## Évolutions par le Pacte (débloquées quand le héros a fait son pacte avec Orvane, acte I) :
##  - habitants : on leur donne un nom par le Pacte, ils évoluent (2 fois) : race supérieure si elle existe
##    (gobelin → hobgobelin, ogre → oni, homme-lézard → dragonide...), plus forts, plus grands ;
##  - familiers : les monstres apprivoisés (voir Familiars) évoluent en combattant aux côtés du héros ;
##  - héros : trois évolutions données par l'histoire principale (actes IV, XII et XVI).

## Habitants : identifiant de race -> [[race d'arrivée ("" = la même), nom de l'évolution], ...]
const VILLAGER := {
	"gobelin": [["hobgobelin", "Hobgobelin"], ["", "Chef hobgobelin"]],
	"hobgobelin": [["", "Hobgobelin nommé"], ["", "Chef hobgobelin"]],
	"ogre": [["oni", "Oni"], ["", "Grand oni"]],
	"oni": [["", "Oni nommé"], ["", "Grand oni"]],
	"orc": [["", "Orc noble"], ["", "Seigneur orc"]],
	"slime": [["", "Slime éveillé"], ["", "Slime royal"]],
	"homme_lezard": [["", "Homme-lézard guerrier"], ["dragonide", "Dragonide"]],
	"lycan": [["", "Lycan alpha"], ["", "Seigneur lycan"]],
	"fee": [["", "Grande fée"], ["ange", "Fée céleste"]],
	"mort_vivant": [["", "Spectre"], ["vampire", "Vampire"]],
	"harpie": [["", "Harpie des tempêtes"], ["", "Reine des cimes"]],
	"insectoide": [["", "Insecte soldat"], ["", "Reine-guerrière"]],
	"dryade": [["", "Dryade ancienne"], ["esprit", "Esprit sylvestre"]],
	"homme_bete": [["", "Homme-bête éveillé"], ["", "Seigneur-bête"]],
	"demon": [["", "Démon supérieur"], ["", "Archidémon"]],
}
## Ce que coûte chaque évolution d'un habitant.
const COSTS := [
	{"level": 3, "items": [["piece_or", 50]]},
	{"level": 8, "items": [["piece_or", 150], ["larme_esprit", 1]]},
]
## Multiplicateur de force et taille selon l'évolution (0, 1, 2).
const POWER := [1.0, 1.25, 1.6]
const SCALE := [1.0, 1.06, 1.13]
const MAX_VILLAGER := 2

## Héros : noms des trois évolutions selon sa race (%s = nom de la race sinon).
const HERO_TITLES := {
	"humain": ["Humain éveillé", "Héros", "Saint"],
	"homme_bete": ["Homme-bête éveillé", "Seigneur-bête", "Roi des Bêtes"],
	"elfe": ["Haut-elfe", "Elfe ancien", "Elfe céleste"],
	"slime": ["Slime éveillé", "Slime primordial", "Slime divin"],
	"gobelin": ["Hobgobelin", "Chef hobgobelin", "Roi gobelin"],
	"hobgobelin": ["Hobgobelin éveillé", "Chef hobgobelin", "Roi gobelin"],
	"orc": ["Orc noble", "Seigneur orc", "Roi orc"],
	"ogre": ["Oni", "Grand oni", "Oni divin"],
	"oni": ["Oni éveillé", "Grand oni", "Oni divin"],
	"demon": ["Démon supérieur", "Archidémon", "Souverain démon"],
	"vampire": ["Vampire noble", "Seigneur vampire", "Vampire originel"],
	"nain": ["Nain runique", "Seigneur des forges", "Roi sous la montagne"],
	"dragonide": ["Dragonide éveillé", "Dragonide ancien", "Seigneur dragon"],
	"ange": ["Ange éveillé", "Archange", "Séraphin"],
	"homme_lezard": ["Homme-lézard guerrier", "Dragonide", "Seigneur dragon"],
}
const HERO_GENERIC := ["%s éveillé", "%s supérieur", "Souverain %s"]
## Bonus du héros (cumulés à chaque évolution), mêmes clés que les compétences.
const HERO_BONUS := [
	{"hp_pct": 0.1, "atk_pct": 0.08, "mag_pct": 0.08},
	{"hp_pct": 0.12, "atk_pct": 0.1, "mag_pct": 0.1, "def_flat": 3.0, "regen": 1.0},
	{"hp_pct": 0.15, "atk_pct": 0.12, "mag_pct": 0.12, "def_flat": 4.0, "spd_pct": 0.06, "crit": 0.05},
]
const HERO_COLOR := [Color("ffe08a"), Color("c8a8ff"), Color("ffffff")]


static func race_id(r: RaceData) -> String:
	return r.resource_path.get_file().get_basename() if r else ""


## Le Pacte est connu (acte I de l'histoire fini, ou pas d'histoire).
static func pact_known(tree: SceneTree) -> bool:
	var st := tree.get_first_node_in_group("story")
	return st == null or st.passed("orvane_2")


# ---------------------------------------------------------------- habitants

## La prochaine évolution d'un habitant : [race d'arrivée, nom] (vide s'il n'en a plus).
static func next_villager_evo(v: Node) -> Array:
	var evo: int = v.get("evo")
	if evo >= MAX_VILLAGER:
		return []
	var rid := race_id(v.get("race"))
	var chain: Array = VILLAGER.get(rid, [])
	if evo < chain.size():
		return chain[evo]
	var rn: String = (v.get("race") as RaceData).display_name if v.get("race") else "Habitant"
	return ["", ("%s nommé" if evo == 0 else "%s éveillé") % rn]


## Pourquoi on ne peut pas (encore) le faire évoluer ("" si c'est possible).
static func villager_block_reason(v: Node, p: Player) -> String:
	if not pact_known(v.get_tree()):
		return "Il te faut d'abord le Pacte d'Orvane (histoire, acte I)."
	if v.has_meta("story"):
		return "Les personnages de l'histoire évoluent avec l'histoire."
	var evo: int = v.get("evo")
	if evo >= MAX_VILLAGER:
		return "Il a atteint sa dernière évolution."
	var c: Dictionary = COSTS[evo]
	if int(v.get("level")) < int(c.level):
		return "Niveau %d requis (il est niveau %d)." % [c.level, v.get("level")]
	for pair in c.items:
		if p.inventory.count(Items.get_item(pair[0])) < int(pair[1]):
			return "Il te manque : %d %s." % [pair[1], Items.get_item(pair[0]).display_name]
	return ""


static func cost_text(evo: int) -> String:
	if evo >= COSTS.size():
		return ""
	var parts := []
	for pair in COSTS[evo].items:
		parts.append("%d %s" % [pair[1], Items.get_item(pair[0]).display_name])
	return "niveau %d, %s" % [COSTS[evo].level, ", ".join(parts)]


## Donne un nom à l'habitant par le Pacte : il évolue.
static func evolve_villager(v: Node, p: Player, new_name: String) -> bool:
	if villager_block_reason(v, p) != "":
		return false
	var nxt := next_villager_evo(v)
	var evo: int = v.get("evo")
	for pair in COSTS[evo].items:
		p.inventory.remove(Items.get_item(pair[0]), int(pair[1]))
	var old_name: String = v.get("villager_name")
	if new_name.strip_edges() != "":
		v.set("villager_name", new_name.strip_edges().left(18))
	if nxt[0] != "":
		var r := load("res://data/races/%s.tres" % nxt[0]) as RaceData
		if r:
			v.set_race(r)
	v.set("evo", evo + 1)
	v.set("evo_title", nxt[1])
	v.set_level(int(v.get("level")) + 3)
	v.apply_evolution(true)
	p.feat.emit("Pacte : %s devient %s !" % [v.get("villager_name"), nxt[1]], Color("d8c0ff"))
	p.notify.emit("%s reçoit le nom de %s et évolue : %s. Plus fort, plus grand, et il gagne des niveaux." % [old_name, v.get("villager_name"), nxt[1]])
	p.gain_xp(40 + 60 * evo)
	return true


# ---------------------------------------------------------------- héros

static func hero_title(r: RaceData, tier: int) -> String:
	if tier <= 0:
		return ""
	var list: Array = HERO_TITLES.get(race_id(r), [])
	if not list.is_empty():
		return list[tier - 1]
	return HERO_GENERIC[tier - 1] % (r.display_name if r else "Héros")


## Bonus cumulés des évolutions du héros.
static func hero_bonus(tier: int) -> Dictionary:
	var out := {}
	for i in mini(tier, HERO_BONUS.size()):
		for k in HERO_BONUS[i]:
			out[k] = float(out.get(k, 0.0)) + float(HERO_BONUS[i][k])
	return out
