extends Node
## Autoload « I18n » : langues du jeu. Le français est la langue d'origine : les textes sont écrits en
## français dans le code et servent de clés. Pour une autre langue, on ajoute ici leurs traductions ;
## les boutons, étiquettes et listes de l'interface (Control) se traduisent alors tout seuls.
## Pour traduire un texte composé en code (messages, formats), appeler `I18n.t("texte")`.
## Ajouter une langue : un nouveau dictionnaire dans LANGS, et son nom dans NAMES.

const NAMES := {"fr": "Français", "en": "English"}

const LANGS := {
	"en": {
		# écran titre et menus
		"Continuer": "Continue", "Jouer (mondes)": "Play (worlds)", "Commandes": "Controls",
		"Options": "Options", "Quitter": "Quit", "Pause": "Pause", "Reprendre": "Resume",
		"Sauvegarder": "Save", "Changer de monde": "Change world", "Royaume": "Kingdom",
		"Succès et bestiaire": "Achievements and bestiary", "Menu principal": "Main menu",
		"Quitter le jeu": "Quit game", "Retour": "Back",
		"Bâtis ton royaume · Explore un monde sauvage · Terrasse les seigneurs des donjons":
			"Build your kingdom · Explore a wild world · Slay the lords of the dungeons",
		# options
		"Difficulté": "Difficulty", "Qualité graphique": "Graphics quality",
		"Point de vue (F5 en jeu)": "Point of view (F5 in game)", "Distance de la caméra": "Camera distance",
		"Taille de l'interface": "Interface size", "Volume général": "Master volume", "Musique": "Music",
		"Bruitages": "Sound effects", "Plein écran": "Fullscreen",
		"Rappel du menu des commandes": "Controls reminder", "Sauvegarde automatique (5 min)": "Autosave (5 min)",
		"Afficher les images par seconde": "Show frames per second",
		"Viser à la souris (sinon : devant le héros)": "Aim with the mouse (otherwise: in front of the hero)",
		"Menus débloqués au fil de la partie": "Menus unlocked as you play",
		"Langue": "Language", "Filtre pour daltoniens": "Colorblind filter",
		"Mouvement réduit (moins de secousses et de ralentis)": "Reduced motion (less shake and slow-motion)",
		"Facile": "Easy", "Normal": "Normal", "Difficile": "Hard",
		"Basse": "Low", "Moyenne": "Medium", "Haute": "High",
		"3e personne": "Third person", "Vue de dessus": "Top view", "1re personne": "First person",
		"Aucun": "None", "Protanopie (rouge)": "Protanopia (red)", "Deutéranopie (vert)": "Deuteranopia (green)",
		"Tritanopie (bleu)": "Tritanopia (blue)",
		"Facile : monstres moins résistants, plus lents à attaquer, raids plus rares.  Difficile : monstres plus forts, plus agressifs et plus rapides, raids plus fréquents.":
			"Easy: weaker monsters that attack more slowly, rarer raids.  Hard: stronger, more aggressive and faster monsters, more frequent raids.",
		# jeu
		"Sac": "Bag", "Équipement": "Equipment", "Artisanat": "Crafting", "Journal": "Journal",
		"Talents": "Talents", "Carte": "Map", "Niveau": "Level", "Vie": "Health",
	},
}

## Messages composés (avec des nombres ou des noms) : modèle français -> modèle anglais. %s et %d sont
## repris dans l'ordre ($1, $2...). Servent aux notifications et aux bandeaux du HUD (voir `msg`).
const PATTERNS := {
	"en": {
		"Niveau %d : vie, attaque et magie augmentent.": "Level $1: health, attack and magic increase.",
		"+%d point de compétence ({talents} : arbre de compétences).": "+$1 skill point ({talents}: skill tree).",
		"+%d points de compétence ({talents} : arbre de compétences).": "+$1 skill points ({talents}: skill tree).",
		"Niveau %d !": "Level $1!",
		"Tu manges : %s.": "You eat: $1.",
		"Tu bois : %s.": "You drink: $1.",
		"%s équipé(e) !": "$1 equipped!",
		"Vue : %s (F5 pour changer)": "View: $1 (F5 to change)",
		"Tu as faim : mange quelque chose ({eat}). Plus de régénération de vie.": "You are hungry: eat something ({eat}). No more health regeneration.",
		"Tu meurs de faim ! Mange vite ({eat}).": "You are starving! Eat quickly ({eat}).",
		"Tu n'as pas faim.": "You are not hungry.",
		"Tu n'as rien à manger. Cueille des baies (buissons) ou chasse des animaux.": "You have nothing to eat. Pick berries (bushes) or hunt animals.",
		"Aucune potion à boire.": "No potion to drink.",
		"Tu te noies ! Remonte respirer.": "You are drowning! Swim up for air.",
		"Vous êtes tombé au combat…": "You have fallen in battle...",
		"Vous vous réveillez au village.": "You wake up in the village.",
		"Raid repoussé ! Les pillards ont laissé leur butin au feu de camp (%d pièces d'or).": "Raid repelled! The raiders left their loot by the campfire ($1 gold coins).",
		"Défense du camp : %d point(s).": "Camp defense: $1 point(s).",
		"%s (%s) : se débloque bientôt. %s.": "$1 ($2): unlocks soon. $3.",
		"Nouveau menu : %s (%s)": "New menu: $1 ($2)",
		"Objectif : %s ✔": "Objective: $1 ✔",
		"Objectif passé : %s. Tu pourras le faire quand tu voudras.": "Objective skipped: $1. You can do it whenever you like.",
		"Chapitre terminé ! Nouveau chapitre : %s.": "Chapter complete! New chapter: $1.",
		"Les bases sont acquises ! Les chapitres suivants sont des défis facultatifs : ils te guident, sans rien t'imposer.": "You have the basics! The following chapters are optional challenges: they guide you without forcing anything.",
		"Une grande bête rôde loin du village et terrorise les voyageurs. Pars à sa recherche : plus tu tardes, plus les habitants s'inquiètent.": "A great beast prowls far from the village and terrifies travelers. Go and find it: the longer you wait, the more worried the villagers get.",
		"La bête est abattue : les routes sont sûres et les habitants soulagés.": "The beast is slain: the roads are safe and the villagers relieved.",
		"Bête rôdeuse": "Prowling beast",
		"Défi %d relevé (%s)": "Challenge $1 completed ($2)",
		"Coffre ouvert : %d objets.": "Chest opened: $1 items.",
		"Monde sauvegardé : %s.": "World saved: $1.",
		"Échec de la sauvegarde.": "Save failed.",
	},
}
## Modèles compilés : langue -> [[RegEx, modèle de sortie]].
var _compiled := {}

var language := "fr"


func _ready() -> void:
	for code in LANGS:
		var tr_res := Translation.new()
		tr_res.locale = code
		for k in LANGS[code]:
			tr_res.add_message(k, LANGS[code][k])
		TranslationServer.add_translation(tr_res)
	set_language(language)


func set_language(code: String) -> void:
	if code != "fr" and not LANGS.has(code):
		code = "fr"
	language = code
	TranslationServer.set_locale(code)


## Traduit un message composé (déjà rempli de ses nombres et noms) : cherche d'abord le texte tel quel,
## puis un modèle de PATTERNS qui lui correspond. Sans traduction, le texte est rendu tel quel.
func msg(text: String) -> String:
	if language == "fr":
		return text
	var direct := TranslationServer.translate(text)
	if direct != text:
		return direct
	if not _compiled.has(language):
		var list := []
		for k in PATTERNS.get(language, {}):
			var rx := RegEx.new()
			var esc := RegEx.create_from_string("[.\\+*?^$()\\[\\]{}|]").sub(k, "\\$0", true)
			esc = esc.replace("%s", "(.+?)").replace("%d", "(-?\\d+)")
			rx.compile("^" + esc + "$")
			list.append([rx, PATTERNS[language][k]])
		_compiled[language] = list
	for entry in _compiled[language]:
		var m: RegExMatch = entry[0].search(text)
		if m == null:
			continue
		var out: String = entry[1]
		for g in range(m.get_group_count(), 0, -1):
			out = out.replace("$%d" % g, TranslationServer.translate(m.get_string(g)))
		return out
	return text


## Traduit un texte écrit en français (le texte lui-même si la langue est le français ou s'il n'est pas connu).
func t(text: String) -> String:
	return TranslationServer.translate(text)
