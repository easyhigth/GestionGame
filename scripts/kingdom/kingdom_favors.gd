class_name KingdomFavors
extends RefCounted
## Les deux moitiés du jeu s'aident :
##  - royaume → héros : les FAVEURS du royaume, débloquées par son rang (cadeaux chaque matin, bonus du héros) ;
##  - héros → royaume : les TROPHÉES des boss vaincus (une statue par région nettoyée) rendent les habitants
##    plus heureux et attirent plus vite les voyageurs.
## Tout suppose un camp (drapeau du royaume planté).

## [rang minimum, nom, effet]
const FAVORS := [
	[1, "Provisions", "Chaque matin, 2 pains pour la route."],
	[2, "Herboriste", "Chaque matin, une potion de soin."],
	[3, "Pierre de rappel", "Chaque matin, une pierre de rappel (retour au camp)."],
	[4, "Garde royale", "Attaque et défense du héros +2 par rang du royaume."],
	[5, "Trésor du royaume", "Chaque matin, 40 pièces d'or par rang."],
	[6, "Gloire impériale", "Expérience gagnée +10 %."],
]


## Faveurs débloquées pour ce rang.
static func unlocked(rank: int) -> Array:
	return FAVORS.filter(func(f): return rank >= int(f[0]))


## Bonus du héros donnés par les faveurs (mêmes clés que Kingdom.hero_bonus : attack, defense, xp...).
static func hero_bonus(rank: int, key: String) -> float:
	match key:
		"attack", "defense":
			return 2.0 * rank if rank >= 4 else 0.0
		"xp":
			return 0.1 if rank >= 6 else 0.0
	return 0.0


## Cadeaux du matin (appelé au lever du jour). Renvoie le texte des cadeaux ("" s'il n'y en a pas).
static func morning(p: Node, rank: int) -> String:
	if p == null or rank < 1:
		return ""
	var got := []
	for g in [[1, "pain", 2], [2, "potion_soin", 1], [3, "pierre_rappel", 1], [5, "piece_or", 40 * rank]]:
		var it := Items.get_item(g[1]) as ItemData
		if rank >= int(g[0]) and it:
			p.inventory.add(it, int(g[2]))
			got.append("%s ×%d" % [it.display_name, int(g[2])])
	return ", ".join(PackedStringArray(got))


## Trophées : régions dont le boss a été vaincu.
static func trophies(world: WorldGenerator) -> int:
	if world == null:
		return 0
	return world.zones.filter(func(z): return z.get("cleared", false)).size()


## Bonheur des habitants apporté par les trophées (+3 par trophée, 20 au plus).
static func trophy_happiness(world: WorldGenerator) -> float:
	return minf(20.0, 3.0 * trophies(world))


## Les voyageurs arrivent plus souvent (−12 % d'attente par trophée, jusqu'à deux fois plus vite).
static func arrival_mult(world: WorldGenerator) -> float:
	return maxf(0.5, 1.0 - 0.12 * trophies(world))
