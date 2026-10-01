class_name BestiaryLore
extends RefCounted
## Notes du naturaliste pour chaque fiche du bestiaire (texte et conseil de combat).

const NOTES := {
	"slime_bleu": ["Petite gelée curieuse des prairies. Elle rebondit vers tout ce qui brille.", "Inoffensive seule : idéale pour apprendre à esquiver."],
	"slime_acide": ["Sa gelée verte ronge le cuir et le bois. Elle aime l'humidité des marais.", "Frappe puis recule : son contact brûle."],
	"slime_magma": ["Une coulée de lave qui a appris à ramper. Elle laisse le sol fumant derrière elle.", "Ne reste pas au corps à corps trop longtemps."],
	"gobelin_pillard": ["Voleur rusé, toujours en bande, attiré par les réserves des villages.", "Pare son premier coup : il se découvre aussitôt."],
	"loup": ["Chasseur des forêts et des plaines. Il attaque en meute à la tombée du jour.", "Garde ton dos contre un arbre ou un mur."],
	"loup_alpha": ["Le chef de meute, plus massif, au pelage sombre et aux crocs usés par les combats.", "Abats-le d'abord : la meute se disperse."],
	"loup_givre": ["Loup des toundras dont la morsure fige le sang.", "Une soupe chaude avant la chasse aide à tenir le froid."],
	"sanglier": ["Têtu et colérique. Il charge tête baissée tout ce qui bouge.", "Roule sur le côté au dernier moment, puis frappe ses flancs."],
	"araignee": ["Tisse ses toiles entre les vieux troncs de la forêt profonde.", "Méfie-toi des fils au sol : ils ralentissent."],
	"scorpion": ["Carapace dorée du désert, dard empoisonné toujours dressé.", "Vise ses pinces quand il frappe : il est lent à se relever."],
	"homme_lezard": ["Guerrier des marais, agile dans la boue, qui garde jalousement son territoire.", "Il esquive bien : enchaîne plutôt que de frapper fort."],
	"orc_brute": ["Montagne de muscles qui ne connaît qu'une tactique : frapper plus fort.", "Pare, puis contre-attaque : ses coups sont lents."],
	"ogre": ["Géant des cimes. Ses coups de massue font trembler la roche.", "Ne pare pas : esquive, et frappe pendant qu'il se relève."],
	"harpie": ["Mi-femme, mi-oiseau, elle plonge du haut des falaises sur les voyageurs.", "Attends qu'elle descende pour frapper."],
	"ours_neige": ["Seigneur des toundras, il dort sous la neige et se réveille affamé.", "Sa garde est solide : fatigue-le avant de l'achever."],
	"salamandre": ["Lézard de feu des terres de cendres, sa peau brûle au toucher.", "Une arme de givre fait des merveilles."],
	"esprit_follet": ["Lueur farceuse du bois enchanté qui égare les promeneurs.", "Il fuit la lumière : approche-le de jour."],
	"fee_sauvage": ["Fée qui a oublié les chants anciens et ne protège plus que sa clairière.", "Sa magie frappe de loin : rapproche-toi vite."],
	"dryade_corrompue": ["Gardienne d'arbre rongée par la Brume. Ses racines saisissent les chevilles.", "Ne reste pas immobile près d'elle."],
	"squelette": ["Soldat d'une guerre oubliée, il garde encore les donjons.", "Ses os se brisent sous les coups lourds."],
	"seigneur_squelette": ["Ancien capitaine couronné, il commande les morts des profondeurs.", "Abats ses soldats d'abord, puis concentre-toi sur lui."],
	"demon": ["Né des cendres du volcan, il ne craint ni le feu ni la douleur.", "Garde des potions : ses coups font mal."],
	"seigneur_demon": ["Maître des démons, aux ailes d'ombre et au regard de braise.", "Une épreuve pour héros aguerris seulement."],
	"panthere": ["Ombre silencieuse de la jungle d'émeraude, elle frappe toujours la première.", "Écoute les feuilles : elle bondit depuis les fourrés."],
	"grenouille": ["Ses couleurs vives préviennent : sa peau est un poison.", "Ne la touche pas à mains nues : vise de loin si tu peux."],
	"serpent": ["Serpent géant qui s'enroule autour de ses proies dans la jungle.", "Esquive son élan, il met du temps à se replier."],
	"serpent_roi": ["Le plus ancien des serpents, couronné d'écailles d'or.", "Sa morsure est terrible, mais il voit mal sur les côtés."],
	"boss_roi_sanglier": ["Grondebois règne sur les plaines. Sa charge renverse les arbres.", "Fais-le charger contre les murs de son antre."],
	"boss_reine_araignee": ["Tissombre, mère de toutes les araignées de la forêt profonde.", "Brûle les toiles, ou ses enfants t'enseveliront."],
	"boss_slime_primordial": ["La première gelée du monde, qui se divise quand on la frappe.", "Élimine les petits morceaux avant qu'ils ne fusionnent."],
	"boss_scorpion_empereur": ["Ankhar, empereur des sables, à la carapace d'or et de bronze.", "Son dard annonce son coup : roule quand il se lève."],
	"boss_ogre_roi": ["Brisemonts, roi des ogres, qui fend les montagnes d'un coup de poing.", "Ses ondes de choc se sautent : garde ton élan."],
	"boss_ours_ancien": ["Givrecroc, ours millénaire, souffle de blizzard et griffes de glace.", "Reste au chaud et frappe entre deux souffles."],
	"boss_dryade_mere": ["Sylvaëlle, mère des forêts, que la Brume a rendue folle de chagrin.", "Coupe ses racines pour l'atteindre."],
	"boss_seigneur_ignarok": ["Ignarok, seigneur des cendres, né dans le cœur du volcan.", "Les pluies de feu tombent en cercle : sors-en vite."],
	"boss_quetzal": ["Xochitl, serpent à plumes, gardien du temple de la jungle.", "Quand il s'envole, prépare-toi à son piqué."],
}


static func note(id: String) -> Array:
	return NOTES.get(id, ["Une créature encore mal connue.", "Observe-la avant de l'affronter."])
