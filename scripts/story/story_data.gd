class_name StoryData
extends RefCounted
## Données de l'histoire principale « L'Éveil du Royaume » : étapes, actes, personnages, attaques,
## duels et dialogues. Le déroulement est dans story.gd.
##
## Résumé : le héros meurt dans un autre monde et renaît ici. Seul Orvane, un esprit enchaîné dans un
## cristal, l'entend. Ensemble, ils font un Pacte. De pacte en pacte (gobelins, loups, fées, oni, nains,
## hommes-lézards, insectes, orcs, humains, vampires, dragons, anges...), un petit village devient une
## nation. Mais l'Inquisiteur Morvain trahit, Maëlle est enlevée, et la vérité éclate : le Seigneur de la
## Brume, Caël, était lui aussi un réincarné, le premier « Éveillé »... et Orvane était son ami.

## [identifiant, acte, titre, conseil, type, paramètre, {options}]
## Types : « talk » (parler ; options item/n : objets à apporter), « obelisks » (nombre), « boss_of » (boss du
## donjon près du camp d'un personnage), « pack » (meute près du camp d'un personnage ; types, n), « shards »
## (éclats, -1 = tous), « room » (type[:nombre]), « pop » (habitants), « raid » (attaque de l'histoire),
## « duel » (boss de l'histoire), « have_any » (posséder un de ces objets).
## Option « reward » : {skill, items} donnés quand l'étape est finie.
const STEPS := [
	# ---------------------------------------------------------------- I
	["intro", 1, "Écoute la voix du cristal", "Une voix t'appelle depuis un cristal, près du village (étoile sur la carte, M).", "talk", "orvane"],
	["glou", 1, "Approche la petite créature", "Quelque chose de gluant tremble près du cristal.", "talk", "glou"],
	["obelisques", 1, "Éveille 2 obélisques", "Les obélisques s'allument quand on s'en approche. Leur lumière affaiblit les chaînes d'Orvane.", "obelisks", 2],
	["orvane_2", 1, "Retourne auprès d'Orvane", "Le cristal près du village.", "talk", "orvane", {"reward": {"skill": "pac_voix"}}],
	["glou_2", 1, "Apporte 5 baies à Glou", "Les buissons du coin en portent. Glou a faim... très faim.", "talk", "glou", {"item": "baies", "n": 5, "reward": {"skill": "pac_estomac"}}],
	# ---------------------------------------------------------------- II
	["grik", 2, "Trouve le camp des gobelins", "Orvane a senti leur peur dans les bois (étoile sur la carte).", "talk", "grik"],
	["pip", 2, "Parle au jeune chasseur Pip", "Il connaît les pistes des loups. Il est au camp de Grik.", "talk", "pip"],
	["loups", 2, "Chasse la meute qui traque les gobelins", "Les loups rôdent autour du camp de Grik.", "pack", "grik", {"types": ["loup", "loup", "loup_alpha"], "n": 6}],
	["ulric", 2, "Affronte le regard du seigneur loup", "Une silhouette immense t'attend à l'orée du bois.", "talk", "ulric", {"reward": {"skill": "pac_hurlement", "items": [["croc_meute", 1]]}}],
	["grik_2", 2, "Retourne voir l'ancien Grik", "À son camp, dans les bois.", "talk", "grik"],
	["maisons", 2, "Construis 2 maisons", "Pièce fermée avec un lit et un coffre (B pour construire) : ton village doit pouvoir accueillir du monde.", "room", "maison:2"],
	# ---------------------------------------------------------------- III
	["maelle", 3, "Accueille la voyageuse elfe", "Une elfe est arrivée au feu de camp du village.", "talk", "maelle"],
	["obelisques_5", 3, "Éveille 5 obélisques", "Maëlle veut étudier leur lumière. Explore de nouvelles contrées.", "obelisks", 5],
	["liora", 3, "Rencontre la fée des obélisques", "Maëlle dit qu'une fée se souvient du temps où les pierres brillaient (étoile sur la carte).", "talk", "liora"],
	["liora_pain", 3, "Apporte 3 pains à Liora", "Les fées adorent le pain. Farine (meule), pétrin et four à pain.", "talk", "liora", {"item": "pain", "n": 3, "reward": {"skill": "pac_oeil_fees", "items": [["larme_esprit", 2]]}}],
	["maelle_2", 3, "Rapporte les paroles de Liora à Maëlle", "Elle t'attend au village.", "talk", "maelle"],
	# ---------------------------------------------------------------- IV
	["kaede", 4, "Trouve la guerrière oni", "Maëlle a croisé une survivante blessée dans les hauteurs (étoile sur la carte).", "talk", "kaede"],
	["kaede_bete", 4, "Venge le clan de Kaede", "La bête qui a dévasté son clan dort dans le donjon près de son camp (carré rouge sur la carte).", "boss_of", "kaede"],
	["duel_ren", 4, "Affronte l'oni masqué", "Quelqu'un attend près du camp de Kaede. Il porte les cornes rouges du clan.", "duel", "ren"],
	["kaede_2", 4, "Retourne auprès de Kaede", "À son camp.", "talk", "kaede"],
	["kaede_3", 4, "Rapporte 10 bûches pour le bûcher de Ren", "Chez les oni, un guerrier part dans les flammes.", "talk", "kaede", {"item": "wood", "n": 10, "reward": {"skill": "pac_ruee", "items": [["katana_cornes", 1]], "evolve": true}}],
	# ---------------------------------------------------------------- V
	["kaia", 5, "Écoute la messagère des cimes", "Une harpie s'est posée au village.", "talk", "kaia"],
	["borin", 5, "Rejoins les forgerons nains", "Borin, maître forgeron, campe dans les hauteurs (étoile sur la carte).", "talk", "borin"],
	["araignees", 5, "Libère la mine des araignées", "Les araignées géantes grouillent autour du camp de Borin.", "pack", "borin", {"types": ["araignee", "araignee", "araignee"], "n": 6}],
	["brunhild", 5, "Présente-toi à la reine Brunhild", "La reine des nains est au camp de Borin.", "talk", "brunhild"],
	["borin_fer", 5, "Apporte 10 lingots de fer à Borin", "Fonds du minerai de fer au four. Les nains ne parlent qu'à ceux qui savent travailler.", "talk", "borin", {"item": "iron_ingot", "n": 10, "reward": {"skill": "pac_acier", "items": [["marteau_borin", 1], ["mithril_brut", 4]]}}],
	["forge", 5, "Construis une forge", "Pièce fermée avec un foyer de forge, une enclume et un établi.", "room", "forge"],
	# ---------------------------------------------------------------- VI
	["lysandre", 6, "Trouve Lysandre la marchande", "Elle voyage dans une contrée lointaine (étoile sur la carte).", "talk", "lysandre"],
	["perles", 6, "Rapporte 5 perles à Lysandre", "Les perles se trouvent au fond des eaux profondes : pêche, ou coffres des grottes sous-marines.", "talk", "lysandre", {"item": "perle", "n": 5, "reward": {"items": [["cape_routes", 1]]}}],
	["zzar", 6, "Rencontre la reine de la Ruche", "Lysandre t'envoie ouvrir une route avec le peuple insecte (étoile sur la carte).", "talk", "zzar"],
	["scorpions", 6, "Chasse les scorpions qui assiègent la Ruche", "Autour du camp de Zzar.", "pack", "zzar", {"types": ["scorpion", "scorpion", "scorpion"], "n": 6}],
	["zzar_2", 6, "Retourne voir la reine Zzar", "À la Ruche.", "talk", "zzar", {"reward": {"skill": "pac_carapace", "items": [["ecaille_dragon", 2]]}}],
	["marche", 6, "Ouvre un marché", "Pièce avec des étals : les routes commerciales passeront par ton village.", "room", "marche"],
	# ---------------------------------------------------------------- VII
	["caserne", 7, "Construis un camp d'entraînement", "Pièce avec 2 mannequins et un râtelier. Donne-lui des gardes.", "room", "caserne"],
	["kaia_2", 7, "Écoute l'avertissement de Kaïa", "La harpie est revenue au village, affolée.", "talk", "kaia"],
	["horde", 7, "Repousse la Horde affamée", "Elle arrive sur le village ! Défends les habitants avec tes gardes.", "raid", "horde"],
	["gorvak", 7, "Parle au chef des survivants", "Un orc blessé attend au bord du village.", "talk", "gorvak"],
	["maelle_cristal", 7, "Montre le cristal noir à Maëlle", "Gorvak portait un étrange cristal. Maëlle est au village.", "talk", "maelle"],
	# ---------------------------------------------------------------- VIII
	["gorvak_ble", 8, "Apporte 15 bottes de blé à Gorvak", "Cultive du blé dans les champs (houe et graines) : son peuple meurt de faim.", "talk", "gorvak", {"item": "ble", "n": 15}],
	["peuple", 8, "Rassemble 10 habitants", "Recrute des voyageurs (E près d'eux) et offre-leur un toit.", "pop", 10],
	["pip_eveil", 8, "Quelque chose arrive à Pip", "Grik t'appelle : le petit Pip est tout lumineux !", "talk", "pip", {"reward": {"skill": "pac_evolution"}}],
	["grik_festin", 8, "Apporte 10 pains pour le festin des peuples", "Grik veut sceller l'amitié des peuples autour d'un grand repas.", "talk", "grik", {"item": "pain", "n": 10}],
	["sylve", 8, "Accueille la dryade", "Attirée par le festin, une dryade est venue au village.", "talk", "sylve", {"reward": {"skill": "pac_racines", "items": [["larme_esprit", 2]]}}],
	# ---------------------------------------------------------------- IX
	["alderic", 9, "Reçois l'envoyé d'Hauterive", "Un chevalier humain campe près d'un donjon (étoile sur la carte).", "talk", "alderic"],
	["bete", 9, "Prouve ta bonne foi à Aldéric", "Vaincs la bête du donjon près de son camp (carré rouge sur la carte).", "boss_of", "alderic"],
	["alderic_2", 9, "Retourne voir Aldéric", "Il t'attend à son camp.", "talk", "alderic"],
	["edmond", 9, "Rencontre le roi d'Hauterive", "Le roi Edmond a planté sa tente royale loin d'ici (étoile sur la carte).", "talk", "edmond"],
	["traite", 9, "Offre 3 lingots d'or au roi pour sceller le traité", "L'or se fond au four à partir d'or brut (filons dorés, pioche en fer).", "talk", "edmond", {"item": "lingot_or", "n": 3, "reward": {"items": [["bouclier_hauterive", 1]]}}],
	# ---------------------------------------------------------------- X
	["morvain", 10, "Reçois le Grand Inquisiteur", "Un prêtre d'Hauterive est arrivé au village.", "talk", "morvain"],
	["orvane_doute", 10, "Parle de Morvain à Orvane", "Le cristal près du village.", "talk", "orvane"],
	["eclats_4", 10, "Rassemble 4 éclats du Cœur d'Aube", "Chaque grande bête (boss de donjon) d'une région différente garde un éclat.", "shards", 4],
	["lysandre_secret", 10, "Lysandre veut te parler en secret", "Elle t'attend au village, l'air coupable.", "talk", "lysandre"],
	["maelle_3", 10, "Montre les éclats à Maëlle", "Elle est au village.", "talk", "maelle"],
	# ---------------------------------------------------------------- XI
	["trahison", 11, "Défends le village contre la Croisade", "Morvain a trahi ! Ses soldats possédés marchent sur le village.", "raid", "croisade"],
	["enlevement", 11, "Retrouve Grik après la bataille", "Quelque chose ne va pas : où est Maëlle ?", "talk", "grik"],
	["orvane_3", 11, "Demande conseil à Orvane", "Le cristal près du village.", "talk", "orvane"],
	["kaia_3", 11, "Kaïa a suivi les ravisseurs", "La harpie t'attend au village.", "talk", "kaia"],
	["selene", 11, "Rencontre la reine de la Nuit", "Sur la route de Morvain, une reine vampire t'attend (étoile sur la carte).", "talk", "selene"],
	# ---------------------------------------------------------------- XII
	["templiers", 12, "Brise la garde de Morvain", "Ses templiers morts-vivants gardent son repaire (étoile sur la carte).", "pack", "morvain", {"types": ["squelette", "squelette", "esprit_follet"], "n": 6}],
	["duel_morvain", 12, "Affronte Morvain le Parjure", "Il t'attend dans son repaire.", "duel", "morvain", {"reward": {"items": [["sceptre_parjure", 1]]}}],
	["maelle_sauvee", 12, "Libère Maëlle", "Elle est enchaînée dans le repaire de Morvain.", "talk", "maelle"],
	["selene_2", 12, "Écoute la vérité de Séléné", "La reine de la Nuit est retournée à son camp.", "talk", "selene", {"reward": {"skill": "pac_brume"}}],
	["orvane_verite", 12, "Exige la vérité d'Orvane", "Le cristal près du village. Il te doit des réponses.", "talk", "orvane", {"reward": {"evolve": true}}],
	# ---------------------------------------------------------------- XIII
	["salle_trone", 13, "Bâtis une salle du trône", "La salle où les peuples alliés tiendront conseil.", "room", "salle_trone"],
	["conseil", 13, "Réunis le conseil des pactes", "Grik, le plus ancien de tes alliés, l'a convoqué.", "talk", "grik"],
	["edmond_2", 13, "Accueille le roi Edmond au conseil", "Le roi d'Hauterive est venu en personne au village.", "talk", "edmond"],
	["vharok", 13, "Trouve le dernier des dragonides", "Vharok garde les écailles des anciens dragons (étoile sur la carte).", "talk", "vharok"],
	["vharok_bete", 13, "Vaincs la bête qui profane le nid des dragons", "Le donjon près du camp de Vharok (carré rouge sur la carte).", "boss_of", "vharok"],
	# ---------------------------------------------------------------- XIV
	["vharok_2", 14, "Reçois l'héritage des dragons", "Vharok t'attend à son camp.", "talk", "vharok", {"reward": {"skill": "pac_souffle", "items": [["ecaille_dragon", 6], ["sang_demon", 2]]}}],
	["eclats_tous", 14, "Rassemble tous les éclats du Cœur", "Il reste des grandes bêtes à vaincre, une par région.", "shards", -1],
	["temple", 14, "Construis un temple", "Pièce fermée avec un autel et 2 bougeoirs : c'est là que le Cœur pourra renaître.", "room", "temple"],
	["aurele", 14, "Un ange est descendu", "Une lumière aveuglante s'est posée non loin (étoile sur la carte).", "talk", "aurele"],
	["duel_aurele", 14, "Réussis l'épreuve du Séraphin", "Aurèle veut mesurer ta volonté, lame contre lame.", "duel", "aurele"],
	["aurele_2", 14, "Écoute le jugement d'Aurèle", "Elle t'attend là où vous vous êtes battus.", "talk", "aurele", {"reward": {"skill": "pac_seraphin", "items": [["larme_esprit", 3], ["cristal_aube", 1]]}}],
	# ---------------------------------------------------------------- XV
	["coeur", 15, "Apporte les éclats à Maëlle", "Au village, près du temple.", "talk", "maelle"],
	["orvane_libre", 15, "Brise les chaînes d'Orvane", "Porte le Cœur d'Aube au cristal.", "talk", "orvane", {"reward": {"skill": "pac_chaines", "items": [["cristal_aube", 1]]}}],
	["armee", 15, "Rassemble l'armée des pactes : 15 habitants", "Recrute, loge et nourris : chaque habitant compte.", "pop", 15],
	["forge_legende", 15, "Forge une pièce d'équipement légendaire", "Mithril, écailles de dragon, larmes d'esprit... (catégorie « Légendaire » de l'artisanat, à l'enclume ou à l'autel).", "have_any",
		["epee_mithril", "casque_mithril", "armure_mithril", "gantelets_mithril", "jambieres_mithril", "lance_draconique", "armure_draconique", "baton_larmes", "cape_brume", "lame_eveil"]],
	["selene_3", 15, "La veille de la bataille", "Séléné est venue au village.", "talk", "selene"],
	# ---------------------------------------------------------------- XVI
	["veilleurs", 16, "Brise le cercle des Veilleurs", "Des démons gardent le Sanctuaire de l'Éveil (étoile sur la carte).", "pack", "sanctuaire", {"types": ["demon", "demon", "esprit_follet"], "n": 6}],
	["sanctuaire", 16, "Affronte le Seigneur de la Brume", "Au cœur du Sanctuaire de l'Éveil.", "duel", "brume"],
	["cael", 16, "Écoute l'âme de Caël", "Une silhouette pâle flotte au milieu du Sanctuaire.", "talk", "cael", {"reward": {"skill": "pac_eveil", "evolve": true}}],
	["epilogue", 16, "Fonde ta nation", "Orvane t'attend au village.", "talk", "orvane", {"reward": {"skill": "pac_roi", "items": [["couronne_pactes", 1]]}}],
	["fondation", 16, "La fête de la fondation", "Grik a tout préparé. Tout le monde t'attend.", "talk", "grik"],
]
const ACTS := {
	1: "Acte I — Une autre vie", 2: "Acte II — Les gobelins et le loup", 3: "Acte III — L'érudite et la fée",
	4: "Acte IV — La dernière lame oni", 5: "Acte V — Le serment des nains", 6: "Acte VI — Les routes de Lysandre",
	7: "Acte VII — La Horde affamée", 8: "Acte VIII — Nourrir un peuple", 9: "Acte IX — La couronne d'Hauterive",
	10: "Acte X — Le Grand Inquisiteur", 11: "Acte XI — La trahison", 12: "Acte XII — Le Parjure",
	13: "Acte XIII — Le conseil des pactes", 14: "Acte XIV — Les dragons et l'ange", 15: "Acte XV — Le Cœur d'Aube",
	16: "Acte XVI — L'Éveil",
}

## Personnages : nom, titre, race, niveau, équipement, couleur du nom, talents, et où ils vivent :
## « camp » : [régions préférées, donjon obligatoire, personnages dont il faut une autre zone, lointain] ;
## « near » : [autre personnage, décalage] (même camp qu'un autre).
const NPCS := {
	"orvane": {"name": "Orvane", "title": "l'Ancien des Racines", "race": "res://data/races/esprit.tres", "level": 20,
		"kit": ["staff"], "color": Color("c8a8ff"), "talents": {"mage": 0.8, "pretre": 0.5}},
	"glou": {"name": "Glou", "title": "le petit slime", "race": "res://data/races/slime.tres", "level": 1,
		"kit": [], "color": Color("8ae0ff"), "talents": {"aubergiste": 0.6}, "near": ["orvane", Vector3(-2.5, 0, 2.0)]},
	"grik": {"name": "Grik", "title": "l'ancien des gobelins", "race": "res://data/races/gobelin.tres", "level": 4,
		"kit": ["staff", "leather_cap", "cape_red"], "color": Color("a8e070"), "talents": {"fermier": 0.6, "bucheron": 0.4},
		"camp": [["foret", "bois_enchante", "prairie", "marais"], false, []]},
	"pip": {"name": "Pip", "title": "le jeune chasseur", "race": "res://data/races/gobelin.tres", "race_alt": "res://data/races/hobgobelin.tres",
		"level": 2, "kit": ["dagger", "leather_cap"], "color": Color("c8f08a"), "talents": {"garde": 0.5, "bucheron": 0.3}, "near": ["grik", Vector3(3, 0, 2)]},
	"ulric": {"name": "Ulric", "title": "seigneur des loups", "race": "res://data/races/lycan.tres", "level": 9,
		"kit": ["leather_armor", "leather_bracers"], "color": Color("c8c8d8"), "talents": {"garde": 0.7}, "near": ["grik", Vector3(13, 0, -7)]},
	"maelle": {"name": "Maëlle", "title": "l'Érudite", "race": "res://data/races/elfe.tres", "level": 6,
		"kit": ["staff", "mage_hat", "mage_robe", "cape_blue"], "color": Color("9ad8ff"), "talents": {"erudit": 0.8}},
	"liora": {"name": "Liora", "title": "fée des pierres", "race": "res://data/races/fee.tres", "level": 7,
		"kit": ["staff", "cape_blue"], "color": Color("ffb8f0"), "talents": {"mage": 0.6},
		"camp": [["bois_enchante", "foret", "prairie"], false, ["grik"]]},
	"kaede": {"name": "Kaede", "title": "la lame oni", "race": "res://data/races/oni.tres", "level": 10,
		"kit": ["sword_iron", "leather_armor", "leather_bracers", "cape_red"], "color": Color("ff8a8a"), "talents": {"garde": 0.8},
		"camp": [["montagnes", "toundra", "bois_enchante", "foret"], true, []]},
	"ren": {"name": "Ren", "title": "l'oni masqué", "race": "res://data/races/oni.tres", "level": 10,
		"kit": ["katana_cornes", "leather_armor", "horned_helmet"], "color": Color("d85a5a"), "talents": {"garde": 0.5}, "near": ["kaede", Vector3(5, 0, 4)]},
	"kaia": {"name": "Kaïa", "title": "messagère des cimes", "race": "res://data/races/harpie.tres", "level": 6,
		"kit": ["spear", "leather_armor"], "color": Color("ffd88a"), "talents": {"marchand": 0.3}},
	"borin": {"name": "Borin", "title": "maître forgeron", "race": "res://data/races/nain.tres", "level": 9,
		"kit": ["war_hammer", "iron_helmet", "iron_armor"], "color": Color("e8b060"), "talents": {"forgeron": 0.9, "macon": 0.4},
		"camp": [["montagnes", "toundra", "volcan"], false, ["kaede"]]},
	"brunhild": {"name": "Brunhild", "title": "reine des nains", "race": "res://data/races/nain.tres", "level": 13,
		"kit": ["war_hammer", "iron_helmet", "iron_armor", "cape_red"], "color": Color("ffd24a"), "talents": {"forgeron": 0.6}, "near": ["borin", Vector3(3, 0, -3)]},
	"lysandre": {"name": "Lysandre", "title": "la marchande", "race": "res://data/races/homme_lezard.tres", "level": 7,
		"kit": ["dagger", "leather_cap", "leather_armor", "cape_red"], "color": Color("c8ff8a"), "talents": {"marchand": 0.8},
		"camp": [["desert", "volcan"], false, [], true]},
	"zzar": {"name": "Zzar", "title": "reine de la Ruche", "race": "res://data/races/insectoide.tres", "level": 11,
		"kit": ["spear", "iron_helmet"], "color": Color("e8e070"), "talents": {"macon": 0.5},
		"camp": [["desert", "volcan", "marais"], false, ["lysandre"]]},
	"gorvak": {"name": "Gorvak", "title": "chef de la Horde", "race": "res://data/races/orc.tres", "level": 11,
		"kit": ["axe", "leather_armor", "horned_helmet"], "color": Color("d0a070"), "talents": {"fermier": 0.5, "garde": 0.5},
		"camp": [["prairie", "foret", "marais", "toundra"], false, ["grik"]]},
	"sylve": {"name": "Sylve", "title": "la dryade", "race": "res://data/races/dryade.tres", "level": 9,
		"kit": ["staff"], "color": Color("8ae0a0"), "talents": {"fermier": 0.8}},
	"alderic": {"name": "Aldéric", "title": "chevalier d'Hauterive", "race": "res://data/races/humain.tres", "level": 12,
		"kit": ["sword_iron", "shield_iron", "iron_armor", "iron_helmet", "iron_gauntlets", "iron_greaves", "cape_blue"], "color": Color("ffb86a"),
		"talents": {"garde": 0.7, "forgeron": 0.3}, "camp": [[], true, ["kaede"]]},
	"edmond": {"name": "Edmond", "title": "roi d'Hauterive", "race": "res://data/races/humain.tres", "level": 15,
		"kit": ["sword_iron", "iron_armor", "iron_greaves", "cape_red"], "color": Color("ffe08a"), "talents": {"erudit": 0.4},
		"camp": [["prairie", "foret", "montagnes"], false, ["grik", "gorvak", "alderic"], true]},
	"morvain": {"name": "Morvain", "title": "Grand Inquisiteur", "race": "res://data/races/humain.tres", "level": 14,
		"kit": ["staff", "mage_robe", "mage_hat", "cape_blue"], "color": Color("e0d0ff"), "talents": {"pretre": 0.9},
		"camp": [["marais", "toundra", "desert", "volcan"], false, ["kaede", "alderic", "borin", "lysandre", "zzar"], true]},
	"selene": {"name": "Séléné", "title": "reine de la Nuit", "race": "res://data/races/vampire.tres", "level": 18,
		"kit": ["dagger", "mage_robe", "cape_red"], "color": Color("ff6a8a"), "talents": {"mage": 0.7},
		"camp": [["toundra", "marais", "montagnes", "bois_enchante"], false, ["morvain", "kaede", "borin"]]},
	"vharok": {"name": "Vharok", "title": "dernier des dragonides", "race": "res://data/races/dragonide.tres", "level": 17,
		"kit": ["war_hammer", "iron_armor", "iron_gauntlets"], "color": Color("ff8a4a"), "talents": {"forgeron": 0.5, "garde": 0.5},
		"camp": [["volcan", "montagnes", "desert"], true, ["kaede", "alderic"]]},
	"aurele": {"name": "Aurèle", "title": "Séraphin", "race": "res://data/races/ange.tres", "level": 20,
		"kit": ["lame_aube", "iron_armor", "iron_helmet"], "color": Color("fff4c0"), "talents": {"pretre": 0.8},
		"camp": [["prairie", "bois_enchante", "foret"], false, ["grik", "liora", "gorvak"]]},
	"cael": {"name": "Caël", "title": "le premier Éveillé", "race": "res://data/races/mort_vivant.tres", "level": 25,
		"kit": ["staff", "mage_robe", "cape_blue"], "color": Color("b8c8ff"), "talents": {"mage": 1.0}, "near": ["sanctuaire", Vector3(0, 0, 0)]},
}

## Attaques de l'histoire : nom, monstres, chef, pillards en plus.
const RAIDS := {
	"horde": {"name": "La Horde affamée", "types": ["orc_brute", "gobelin_pillard", "loup"], "leader": "ogre", "extra": 3},
	"croisade": {"name": "La Croisade de l'Aube Pure", "types": ["squelette", "demon", "esprit_follet"], "leader": "seigneur_squelette", "extra": 4},
}
## Boss de l'histoire : données, titre, pouvoirs, renforts, puissance, sous-titre.
const DUELS := {
	"ren": {"data": "res://data/enemies/ren_possede.tres", "title": "Ren le Possédé", "powers": ["charge", "onde"],
		"summons": ["loup"], "power": 1.1, "sub": "Le frère de Kaede, dévoré par la Brume."},
	"morvain": {"data": "res://data/enemies/morvain_parjure.tres", "title": "Morvain le Parjure", "powers": ["onde", "invocation", "charge"],
		"summons": ["squelette", "esprit_follet"], "power": 1.25, "sub": "L'Inquisiteur révèle son vrai visage : un serviteur de la Brume."},
	"aurele": {"data": "res://data/enemies/aurele_epreuve.tres", "title": "Aurèle, Séraphin", "powers": ["onde", "pluie", "charge"],
		"summons": [], "power": 1.3, "sub": "L'épreuve du Ciel : montre ce que vaut ta volonté."},
	"brume": {"data": "res://data/enemies/seigneur_brume.tres", "title": "Seigneur de la Brume", "powers": ["onde", "pluie", "invocation", "charge"],
		"summons": ["squelette", "demon", "esprit_follet"], "power": 1.6, "sub": "Caël, le premier Éveillé. Il a brisé le Cœur d'Aube. Il ne le brisera pas deux fois."},
}
## Noms possibles de la nation (épilogue).
const NATIONS := {"aube": "Royaume de l'Aube", "pactes": "Fédération des Pactes", "orvane": "Terres d'Orvane"}
