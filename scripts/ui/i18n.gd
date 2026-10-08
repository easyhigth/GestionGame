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


## Traduit un texte écrit en français (le texte lui-même si la langue est le français ou s'il n'est pas connu).
func t(text: String) -> String:
	return TranslationServer.translate(text)
