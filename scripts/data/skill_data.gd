class_name SkillData
extends Resource
## Une compétence unique du héros. Chaque compétence est un fichier .tres dans data/skills/
## (générés par tools/skills_database.py). Elle évolue en 3 rangs selon le niveau du héros.
##
## passive : effets permanents (voir PASSIVE_LABELS), multipliés à chaque rang.
## active + active_params : effet déclenché avec la touche Q / RB (voir HeroSkill), puis recharge.

## Niveau du héros pour atteindre chaque rang.
const TIER_LEVELS := [1, 6, 12]
const TIER_LABELS := ["Rang I · Compétence unique", "Rang II · Compétence supérieure", "Rang III · Compétence ultime"]
const PASSIVE_SCALE := [1.0, 1.6, 2.4]
const DMG_SCALE := [1.0, 1.5, 2.2]
const RADIUS_SCALE := [1.0, 1.2, 1.4]
const DUR_SCALE := [1.0, 1.3, 1.6]
const CD_SCALE := [1.0, 0.85, 0.7]
const HEAL_SCALE := [1.0, 1.35, 1.7]

## [texte, format (pct = pourcentage, flat = nombre, sec = secondes, bool)]
const PASSIVE_LABELS := {
	"atk_pct": ["Attaque", "pct"], "mag_pct": ["Magie", "pct"], "hp_pct": ["Vie max", "pct"],
	"spd_pct": ["Vitesse", "pct"], "aspd_pct": ["Vitesse d'attaque", "pct"], "cdr_pct": ["Recharge", "pct_minus"],
	"def_flat": ["Défense", "flat"], "regen": ["Régénération", "regen"], "crit": ["Coup critique", "chance"],
	"crit_mult": ["Dégâts critiques", "pct"], "lifesteal": ["Vol de vie", "pct"], "loot": ["Butin", "pct"],
	"xp": ["Expérience", "pct"], "thorns": ["Renvoi des dégâts", "pct"], "kill_heal": ["Vie par ennemi vaincu", "flat"],
	"absorb": ["Absorption (force gagnée par ennemi vaincu)", "chance"], "burn": ["Brûlure / poison au contact", "chance"],
	"stun": ["Étourdit au contact", "chance"], "slow": ["Ralentit au contact", "chance"],
	"berserk": ["Dégâts sous 35 % de vie", "pct"], "last_stand": ["Survit à un coup mortel (1 fois / 60 s)", "bool"],
	"execute": ["Dégâts contre les ennemis affaiblis", "pct"], "poise": ["Dégâts d'équilibre", "pct"],
	"dodge": ["Esquive parfaite plus facile", "sec"], "parry": ["Parade plus facile", "sec"],
}
const ACTIVE_LABELS := {
	"nova": "Explosion autour de toi", "volley": "Salve de projectiles", "dash": "Ruée foudroyante",
	"heal": "Soin", "buff": "Renforcement", "barrier": "Barrière protectrice", "stun": "Étourdissement de zone",
	"vortex": "Tourbillon qui attire les ennemis", "cone": "Souffle devant toi", "drain": "Drain de vie",
	"meteor": "Frappe venue du ciel", "dot": "Zone de dégâts continus", "fear": "Terreur (les ennemis fuient)",
	"execute": "Exécution d'un ennemi", "blink": "Téléportation", "aura": "Aura destructrice",
	"slow_field": "Zone de ralentissement", "random": "Effet imprévisible",
}

@export var id: String = ""
## Noms des 3 rangs (la compétence change de nom en évoluant).
@export var tier_names: PackedStringArray = PackedStringArray(["Compétence", "Compétence +", "Compétence ++"])
@export var category: String = ""
@export var color: Color = Color.WHITE
@export_multiline var description: String = ""
@export var passive: Dictionary = {}
@export var active: String = "nova"
@export var active_params: Dictionary = {}
## Temps de recharge de l'effet actif (secondes, au rang I).
@export var cooldown: float = 10.0


static func tier_for_level(level: int) -> int:
	var t := 0
	for i in TIER_LEVELS.size():
		if level >= TIER_LEVELS[i]:
			t = i
	return t


func tier_name(tier: int) -> String:
	return tier_names[clampi(tier, 0, tier_names.size() - 1)]


## Valeur d'un effet passif au rang donné.
func passive_value(key: String, tier: int) -> float:
	if not passive.has(key):
		return 0.0
	var v := float(passive[key])
	if key == "last_stand":
		return v
	return v * PASSIVE_SCALE[tier]


func passive_text(tier: int) -> String:
	var parts := []
	for k in passive:
		var lab: Array = PASSIVE_LABELS.get(k, [k, "flat"])
		var v := passive_value(k, tier)
		match lab[1]:
			"pct":
				parts.append("%s %+d %%" % [lab[0], roundi(v * 100)])
			"pct_minus":
				parts.append("%s -%d %%" % [lab[0], roundi(v * 100)])
			"chance":
				parts.append("%s %d %%" % [lab[0], roundi(minf(v, 1.0) * 100)])
			"regen":
				parts.append("%s +%.1f PV/s" % [lab[0], v])
			"sec":
				parts.append("%s (+%.2f s)" % [lab[0], v])
			"bool":
				parts.append(lab[0])
			_:
				parts.append("%s %+d" % [lab[0], roundi(v)])
	return ", ".join(parts)


func active_text(tier: int) -> String:
	var t: String = ACTIVE_LABELS.get(active, active)
	var p := active_params
	var extra := []
	if p.has("dmg"):
		extra.append("puissance ×%.1f" % (float(p["dmg"]) * DMG_SCALE[tier]))
	if p.has("dps"):
		extra.append("dégâts continus")
	if p.has("radius"):
		extra.append("rayon %.1f m" % (float(p["radius"]) * RADIUS_SCALE[tier]))
	if p.has("count"):
		extra.append("%d projectiles" % _count(tier))
	if p.has("pct"):
		extra.append("rend %d %% de la vie" % roundi(float(p["pct"]) * HEAL_SCALE[tier] * 100))
	if p.has("dur"):
		extra.append("%.1f s" % (float(p["dur"]) * DUR_SCALE[tier]))
	if p.has("allies"):
		extra.append("soigne aussi les habitants proches")
	if p.has("cost"):
		extra.append("coûte %d %% de la vie" % roundi(float(p["cost"]) * 100))
	return "%s (%s) · recharge %d s" % [t, ", ".join(extra), roundi(cooldown * CD_SCALE[tier])] if extra else "%s · recharge %d s" % [t, roundi(cooldown * CD_SCALE[tier])]


func _count(tier: int) -> int:
	var c := int(active_params.get("count", 1))
	return c + tier * maxi(1, c / 3)
