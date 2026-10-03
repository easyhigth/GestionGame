extends SceneTree
## Équilibrage des classes : pour chaque classe et plusieurs niveaux, estime
##   - l'attaque : coups de base + compétences de classe sur un combat de 60 s contre un groupe de 3 ennemis ;
##   - la survie : vie (et défense), soins, barrières et invocations qui encaissent à sa place ;
##   - un score = moyenne géométrique des deux, comparé à la médiane des classes (100).
## Héros humain, tenue de départ de la classe, sans talents ni butin (la classe seule).
## Lancer : godot --headless --path . -s tools/class_balance.gd
const LEVELS := [1, 6, 15, 30, 60, 100]
const FIGHT := 60.0
const FOES := 3.0

var TT
var V


func _initialize() -> void:
	TT = load("res://scripts/hero/talent_tree.gd")
	V = load("res://scenes/npc/villager.gd")
	var race = load("res://data/races/humain.tres")
	var sk_data = load("res://data/enemies/squelette.tres")
	for lv in LEVELS:
		var rows := []
		for cid in V.CLASS_IDS:
			rows.append(evaluate(cid, lv, race, sk_data))
		var scores: Array = rows.map(func(r): return r.score)
		scores.sort()
		var med: float = scores[scores.size() / 2]
		print("\n== niveau %d (score 100 = classe médiane)" % lv)
		print("classe        | atk  | mag  | PV   | déf | attaque 60 s | survie   | score")
		rows.sort_custom(func(a, b): return a.score > b.score)
		for r in rows:
			print("%-13s | %4d | %4d | %4d | %3d | %12d | %8d | %5d" % [r.id, r.atk, r.mag, r.hp, r.def, r.off, r.surv, roundi(r.score / med * 100.0)])
	quit()


func evaluate(cid: String, lv: int, race, sk_data) -> Dictionary:
	var c = load("res://data/classes/%s.tres" % cid)
	var atk: float = race.strength + c.bonus_attack + c.attack_per_level * (lv - 1)
	var mag: float = race.magic + c.bonus_magic + c.magic_per_level * (lv - 1)
	var defe: float = c.bonus_defense + c.defense_per_level * (lv - 1)
	var hp: float = race.max_health + c.bonus_health + c.health_per_level * (lv - 1)
	var staff := false
	for it in c.starting_equipment:
		atk += it.attack
		mag += it.magic
		defe += it.defense
		if it.id == "staff":
			staff = true
	# coups de base : un coup par seconde, avec l'attaque (ou la magie pour un bâton)
	var basic: float = (mag if staff else atk) * 1.0
	var power: float = maxf(atk, mag)
	var off: float = basic * FIGHT
	var heal := 0.0
	var shield := 0.0
	for n in TT.class_skills(cid):
		if lv < int(n.level):
			continue
		var p: Dictionary = n.params
		var casts: float = floor(FIGHT / float(n.cooldown)) + 1.0
		var dmg := float(p.get("dmg", 0.0))
		var per := 0.0
		match String(n.active):
			"nova", "stun", "cone", "vortex", "drain", "fear", "move", "dash":
				per = dmg * minf(FOES, 2.0 + float(p.get("radius", p.get("range", p.get("dist", 3.0)))) / 4.0)
			"chain":
				per = dmg * minf(FOES, float(p.get("count", 3))) * 0.88
			"volley":
				per = dmg * float(p.get("count", 1)) * 0.7
			"storm", "meteor":
				per = dmg * float(p.get("count", 1)) * 0.6
			"blink", "execute":
				per = dmg * 1.3
			"aura", "dot", "slow_field":
				per = float(p.get("dps", 0.0)) * 2.0 * float(p.get("dur", 5.0)) * minf(FOES, 2.0)
			"summon":
				var sk_pow := 0.45 + 0.004 * lv + 0.002 * mag
				off += sk_data.attack * sk_pow / 1.2 * minf(float(p.get("dur", 30.0)), float(n.cooldown)) * float(p.get("count", 2)) * (FIGHT / float(n.cooldown))
				shield += sk_data.max_health * sk_pow * float(p.get("count", 2)) * casts * 0.5
		off += per * power * casts
		if p.has("atk"):
			off += basic * float(p.atk) * float(p.get("dur", 6.0)) * casts
		if p.has("aspd"):
			off += basic * float(p.aspd) * float(p.get("dur", 6.0)) * casts
		if p.has("crit"):
			off += basic * float(p.crit) * 0.5 * float(p.get("dur", 6.0)) * casts
		if p.has("def"):
			shield += float(p["def"]) * 4.0 * casts
		if n.active in ["heal"]:
			heal += hp * float(p.get("pct", 0.3)) * casts
		if n.active == "rally" or (n.active == "nova" and p.has("heal")):
			heal += hp * float(p.get("heal", 0.1)) * casts
		if n.active == "drain":
			heal += dmg * power * minf(FOES, 2.0) * float(p.get("ratio", 0.5)) * casts
		if n.active == "barrier":
			shield += hp * 0.05 * float(p.get("reduce", 0.5)) * float(p.get("dur", 4.0)) * casts
		if n.active in ["stun", "fear"]:
			shield += hp * 0.04 * float(p.get("dur", 1.5)) * casts
	var surv := (hp * (1.0 + defe / 40.0)) + heal + shield
	return {"id": cid, "atk": roundi(atk), "mag": roundi(mag), "hp": roundi(hp), "def": roundi(defe), "off": roundi(off), "surv": roundi(surv),
		"score": sqrt(off * surv)}
