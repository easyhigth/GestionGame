# L'Éveil du Royaume

(Nom provisoire : il se change dans Projet > Paramètres du projet > Application > Nom, et dans `scenes/ui/title_screen.gd`.)

## Ouvrir le projet
Godot 4.7 > Importer > `project.godot`, puis F5 pour lancer. Le jeu commence par l'écran titre (`scenes/ui/title_screen.tscn`) : Continuer, Nouvelle partie (création du héros), Charger, Options, Quitter. `scenes/main.tscn` se lance aussi seul (F6) avec un héros par défaut.

## Commandes
Toutes les touches sont aussi dans le jeu : menu pause (Échap / Start) ou écran titre → **Commandes** (4 onglets, clavier-souris et manette côte à côte). En jeu, seul un petit rappel s'affiche sous la mini-carte (désactivable dans les options).

- ZQSD ou flèches (joystick gauche) : se déplacer, dans le sens de la caméra
- Espace (A à la manette) : sauter (assez haut pour monter sur un bloc de 1 m)
- Maj (B à la manette) : roulade (esquive : invulnérable pendant la roulade)
- Clic molette maintenu + glisser (joystick droit) : tourner la caméra à 360° autour du héros et changer sa hauteur ; molette : zoom
- Clic molette simple, F, L ou gâchette gauche : viser la cible la plus proche
- Clic gauche / J (maintenu) : frapper avec son arme, ou lancer un sort avec un bâton de mage ; frapper un arbre, un rocher, un buisson ou un décor du village le récolte
- G (maintenu, gâchette droite à la manette) : creuser le sol devant soi (terre, sable ou cailloux) ; dans l'eau : plonger (Espace : remonter)
- H (LB + croix haut à la manette) : manger ; cliquer sur une nourriture dans le sac la mange aussi
- C / X (LB + croix gauche/droite à la manette) : choisir un bloc, un meuble, des graines ou la houe du sac ; V (L3) : le poser, semer ou labourer devant soi
- Q (RB) : compétence unique ; 1 à 4 : attaques et sorts de l'arbre de talents (manette : croix droite pour choisir l'emplacement, R3 pour lancer)
- T (ou croix gauche à la manette) : arbre de talents
- I (ou Tab) : inventaire, équipement et artisanat
- E près d'un habitant : ouvrir son équipement pour lui donner des armes et armures (s'il a une quête « ! » ou « ? », c'est d'abord la quête qui s'ouvre)
- E près d'un voyageur : lui parler pour le recruter ; E près du marchand ambulant : acheter et vendre
- E devant une entrée de donjon : y descendre ; E dans un donjon : ouvrir un coffre, remonter par le portail
- E près d'un cheval apprivoisé ou d'une barque : monter / descendre (carottes en main près d'un cheval sauvage : l'apprivoiser)
- B (ou croix bas à la manette) : mode construction (voir plus bas)
- U : panneau du royaume (habitants, lits, réserve de nourriture, bonheur)
- O : journal de l'histoire (16 actes, objectif en cours, éclats, personnages)
- M (ou croix haut à la manette) : carte du monde et voyage rapide
- Échap (ou Start à la manette) : pause (sauvegarder, charger, options, menu principal)
- Touches de test, seulement quand le jeu est lancé depuis l'éditeur Godot : R (changer de race), N (nouveau monde)

## Ce que tu peux modifier sans code
- `data/races/*.tres` : les 22 races (nom, description, stats, modèle 3D nu du joueur, modèles des habitants, équipements de la race). Duplique un fichier pour créer une race.
- `data/items/*.tres` : les 28 objets (matériaux, armes, boucliers, casques, armures, brassards, jambières, capes) : nom, description, emplacement, rareté, bonus d'attaque / défense / magie / vitesse.
- `data/regions/*.tres` : les 8 types de régions du monde ouvert (prairie, forêt profonde, marais brumeux, désert, hautes montagnes, toundra gelée, bois enchanté, terres de cendres) : noms des zones, niveaux, climat, distance minimale au village, relief, couleurs du sol, liquide (marais, lave), arbres, buissons, rochers, plantes, monstres et monstres d'élite, densité des camps, ressources au sol.
- `data/enemies/*.tres` : les 31 monstres, dont les 8 boss (`boss_*.tres`) (loup, loup alpha, sanglier, gobelin pillard, squelette, orc brutal) : modèle, équipement porté, vie, attaque, défense, vitesse, distance de repérage, portée et durée de leurs coups, butin et chances de le lâcher.
- `data/recipes/*.tres` : les 69 recettes d'artisanat (objet fabriqué, ingrédients et quantités, établi obligatoire ou non, meuble d'artisan à avoir à côté (**Station**), onglet (**Category**)).
- `data/rooms/*.tres` : les 17 types de pièces (maison, dortoir, forge, boulangerie, camp d'entraînement, grange, scierie, maçonnerie, verrerie, taverne, marché, bibliothèque, temple, tour de mage, atelier de tissage, entrepôt, salle du trône) : mobilier obligatoire, taille minimale, métier et nombre de postes, production, lits, bonus pour le héros.
- `data/player/player_stats.tres` : vitesse (en m/s), roulade, vie du joueur.
- `scenes/player/player.tscn` > propriété **Race** : la race du joueur au démarrage. **Camera Offset** : position de la caméra par rapport au joueur.
- `scenes/main.tscn` > nœud **World** : taille du monde, niveaux d'eau/sable/roche, relief 3D (hauteur des marches), couleurs du sol, forêts et modèles des décors, village de départ (scènes des huttes, feu, habitants, liste des races des habitants, nombre d'habitants).
  - Bouton **Générer un aperçu** : voir le terrain dans l'éditeur. **Effacer l'aperçu** avant d'enregistrer.
- `scenes/main.tscn` > nœud **Ambiance** (WorldEnvironment) : couleur du ciel et de la lumière ambiante. Nœud **Soleil** : direction, couleur et puissance du soleil (plus sombre = plus nocturne).
- `scenes/props/campfire.tscn` : lumière du feu (couleur, puissance, vacillement).
- `scenes/npc/villager.tscn` : vitesse et rayon de promenade des habitants (en mètres), distance à laquelle ils repèrent un équipement au sol (**Loot Radius**).
- `scenes/main.tscn` > nœud **World** > groupe **Monstres** : nombre de camps, distance au village, monstres des forêts / plaines / roches et monstres dangereux (loin du village).
- `scenes/player/player.tscn` > nœud **Health** : régénération de la vie ; propriété **Respawn Delay** du joueur. `scenes/npc/villager.tscn` : distance d'alerte, rayon de défense et durée du K.O. des habitants.
- `scenes/main.tscn` > nœud **World** > groupe **Objets à ramasser** : objets posés autour du feu au départ, équipements rares dans la nature, fréquence des matériaux (bois, pierre, minerai de fer, cuir, fibre).

## Création du héros
- **Race** : 22 races, chacune avec ses caractéristiques (vie, force, agilité, magie, vitesse) dans `data/races/*.tres`. L'agilité accélère les coups.
- **Apparence** : style propre à la race (coiffure, cornes, espèce de l'homme-bête, élément de l'esprit, type d'ange...), barbe (humain), couleurs de peau, de cheveux (ou plumes, fourrure, feuillage) et d'yeux (pastilles de la race ou couleur libre), taille et carrure.
- **Classe** (`data/classes/`) : Guerrier, Paladin, Barbare, Rôdeur, Assassin, Mage. Donne l'équipement de départ, des bonus et le gain de caractéristiques à chaque niveau.
- **Métier** (`data/jobs/`) : Forgeron, Chasseur, Bûcheron, Mineur, Herboriste, Marchand, Tisserand. Donne des matériaux de départ et un avantage (vie, défense, vitesse, régénération, butin...).
- **Niveaux** : les monstres vaincus donnent de l'expérience ; chaque niveau augmente la vie, l'attaque, la défense et la magie selon la classe (barre bleue sous la vie).
- Les modèles du héros sont dans `assets/characters/hero/` (outil `tools/voxel_hero_generator.py`) : la peau, les cheveux et les yeux y sont peints avec des couleurs repères, remplacées en jeu par les couleurs choisies (`VoxelCharacter.set_colors`).

## Compétences uniques
- **151 compétences** réparties en 26 catégories (Péchés, Vertus, Sagesse, Feu, Eau, Glace, Vent, Foudre, Terre, Lumière, Ténèbres, Poison, Sang, Espace, Temps, Son, Métal, Nature, Cristal, Martiale, Bête, Survie, Ombre, Esprit, Chaos, Commandement). On en choisit une à la création (onglet « Compétence », avec filtre, recherche et tirage au hasard).
- Chaque compétence **évolue** et change de nom : Rang I (compétence unique) au niveau 1, Rang II (supérieure) au niveau 6, Rang III (ultime) au niveau 12. Ex. : Vorace → Dévoreur → Seigneur de la Faim ; Éclair → Foudre vivante → Dieu du Tonnerre.
- **Passif** permanent (attaque, magie, vie, critiques, vol de vie, brûlure, étourdissement, ralentissement, absorption de force sur les ennemis vaincus, survie à un coup mortel, parade et esquive facilitées...), renforcé à chaque rang.
- **Actif** (Q / RB), avec recharge (compteur en bas de l'écran) : explosion, salve de projectiles, ruée, météores, tourbillon, souffle, drain de vie, zones de poison ou de gel, aura, barrière, soin (aussi des habitants), terreur, exécution, téléportation...
- Les compétences sont décrites dans `tools/skills_database.py` (qui génère `data/skills/*.tres`) : pour en ajouter une, écris une ligne `S(...)` et relance le script. Leur fonctionnement est dans `scripts/hero/hero_skill.gd`.

## Arbre de talents
- Touche **T** : trois branches de 9 talents, sur 5 rangs (niveaux 1, 3, 6, 10, 14), plus l'onglet **✦ Pacte** (compétences uniques données par l'histoire, voir plus bas).
  - **Lame** (corps à corps) : Tourbillon, Charge du taureau, Frappe sismique, Onde tranchante, ultime Tempête de lames ; passifs d'attaque, de vitesse, de critiques, d'exécution.
  - **Arcanes** (sorts) : Boule de feu, Éclair en chaîne, Nova de givre, Bouclier arcanique, Lumière guérisseuse, ultime Pluie de météores ; passifs de magie et de recharge.
  - **Ombre** (agilité et survie) : Double saut, Pas de l'ombre (téléportation), Lames empoisonnées, Terreur, ultime Frénésie ; passifs de roulade, de vie, de régénération, de vol de vie.
- **Points** : 1 par niveau gagné et 1 par âme de boss absorbée (les ultimes coûtent 2). Un talent s'apprend quand on a le niveau de son rang et un talent relié juste au-dessus. Le premier talent de la branche de ta classe est offert.
- Ronds = passifs (bonus permanents), carrés = actifs (nouvelles attaques et nouveaux sorts). Un actif appris se range dans un des **4 emplacements** (touches 1-4), visibles à droite de la compétence en bas de l'écran avec leur recharge.
- « Oublier les talents » rend tous les points. Les talents et les emplacements sont sauvegardés.
- Les talents sont décrits dans `scripts/hero/talent_tree.gd` (liste `NODES` : ajoute une ligne pour créer un talent ; les actifs réutilisent les effets des compétences de `scripts/hero/hero_skill.gd`).

## Début de partie et récolte (façon Minecraft)
- On commence avec peu de choses, de quoi se faire un premier abri : 24 planches, 12 blocs de chaume, 1 porte, 1 lit, 3 torches, 4 bois (plus l'équipement de sa classe, les objets de son métier, et une épée en bois, du bois, de la fibre et du cuir près du feu).
- Tout le reste se récolte. Chaque coup d'arme frappe aussi le décor devant le héros ; il se brise après quelques coups et lâche des ressources à ramasser en marchant dessus :
  - arbre (5 coups) : 3 à 5 bois, parfois de la fibre ; rocher (6 coups) : 2 à 4 cailloux, parfois du minerai de fer, du marbre ou de l'or ; buisson (2 coups) : fibre ; herbes et fleurs (1 coup) : fibre ;
  - décors du village : cabane (14 coups : planches, rondins, chaume), tonneau, caisse, établi, râtelier.
  - Une hache coupe les arbres deux fois plus vite, un marteau de guerre casse les rochers deux fois plus vite, et un coup chargé compte double.
- **Creuser** (G / gâchette droite) : chaque coup de pelle abaisse le sol de 50 cm devant soi et donne 1 bloc de terre (sable sur la plage, cailloux dans la roche, parfois du minerai).
- Ensuite on fabrique (inventaire, I) : bois → planches, rondins, portes, torches ; fibre → chaume ; cailloux → blocs de pierre...
- **Outils** (inventaire → Artisanat → Outils) : hache et pioche en bois (3 bois), en pierre (2 bois + 3 cailloux, près d'un établi), en fer (voir « L'âge du fer »). Il suffit de les avoir dans son sac, le meilleur est utilisé tout seul : ×2 en bois, ×3 en pierre, ×4 en fer. Le héros le sort et le tient en main quand il récolte (la hache pour un arbre, un buisson ou un décor du village, la pioche pour un rocher ou pour creuser), puis reprend son arme 3 secondes après, ou tout de suite si un ennemi approche. Sans pioche, un rocher ne donne que des cailloux (pas de minerai) et on ne peut pas creuser la roche.
- Les réglages sont dans `scripts/world/harvest.gd` (points de vie des décors, butin, outils).

## Poser et casser à la main
- Sans passer par le mode construction : **C** (ou X pour revenir en arrière) choisit un bloc ou un meuble du sac, **V** le pose devant soi. Une barre d'objets s'affiche au-dessus de la compétence ; après le dernier objet, on revient aux mains nues (plus rien ne s'affiche).
- Une case fantôme montre où l'objet ira : verte si c'est possible, rouge sinon. Un bloc se pose au niveau des pieds, puis au-dessus s'il y en a déjà un (jusqu'à 3 de haut) ; devant un trou ou de l'eau, il se pose un cran plus bas pour faire un pont. Il lui faut un appui : le sol, un bloc dessous ou à côté.
- Les meubles (porte, lit, torche, coffre...) se posent pareil et regardent le héros.
- **Casser** : frapper un bloc ou un meuble posé devant soi (quand aucun arbre, rocher ou décor n'est plus proche). Bois : 2 coups, pierre 3,5 coups, marbre 8, verre 1 ; la hache aide pour le bois et les meubles, la pioche pour la pierre. L'objet revient à ramasser. Les blocs ne se cassent pas si un ennemi est tout près (on ne démolit pas sa maison en se battant).
- Code : `scripts/build/hand_build.gd` (pose), `scripts/world/harvest.gd` (casse).

## L'âge du fer
- **Filons** : dans la roche des collines et des montagnes, des rochers piquetés d'orange (fer, 8 coups) ou de jaune (or, plus rares, sur les hauteurs, 10 coups). Il faut une pioche pour le fer et une **pioche en fer** pour l'or. Un filon de fer donne 2 à 3 minerais de fer.
- **Pioches** : sans pioche, un rocher ne donne que des cailloux ; avec une pioche en bois ou en pierre, parfois du minerai de fer ; avec une pioche en fer, aussi du marbre et de l'or.
- **Chaîne du fer** : four (6 cailloux + 2 terre, près d'un établi) → lingot de fer (2 minerais + 1 bois, près du four) → enclume (4 lingots, près d'un établi) → à côté de l'enclume : hache et pioche en fer (2 lingots + 2 bois, ×4), épée, hache de guerre, marteau, lance, dague, bouclier, casques, armure, gantelets et jambières en fer.
- Le guide continue avec un 2e chapitre, « L'âge du fer » : miner 2 filons, poser un four, fondre 2 lingots, poser une enclume, forger une pioche en fer.

## Faim et nourriture
- **Jauge de faim** sous l'expérience : elle se vide en 15 minutes environ (plus vite en courant, en frappant, en roulant). **Rassasié** (70 et plus) : +1,5 vie par seconde. **Affamé** (moins de 25) : plus de régénération de vie. **À 0** : on perd de la vie peu à peu (jamais sous 10 %) et on marche 15 % moins vite. On se réveille au village à moitié rassasié.
- **Manger** : H choisit tout seul le plat le plus nourrissant qui ne gaspille pas (ou clic sur la nourriture dans le sac).
- **Nourriture** : baies (buissons, 8), viande crue (sangliers, loups, ours, 10), viande cuite (32, +15 vie), pain (boulangerie du village, 26, +8 vie), ragoût (viande + 3 baies, 55, +40 vie).
- **Cuisine** (inventaire → Artisanat → Cuisine) : près du feu de camp du village, d'un four, d'un four à pain ou d'une forge.
- Le guide a une nouvelle étape : « Mange un repas cuit » (avant la première nuit).

## Histoire principale : L'Éveil du Royaume
Une longue histoire originale en **16 actes (84 étapes, 5 ou 6 par acte)** et **23 personnages**, dans l'esprit des récits de réincarnation où l'on bâtit une nation de monstres. Tu es mort dans un autre monde (une ville de verre, un soir de pluie, des phares...) et tu renais ici. Seul **Orvane**, un ancien esprit enchaîné dans un cristal près du village, t'entend : vous faites un **Pacte**. De pacte en pacte, ton petit village devient une nation où tous les peuples vivent ensemble.
- **I — Une autre vie** : Orvane, et **Glou** le petit slime affamé ; 2 obélisques ; premières compétences uniques.
- **II — Les gobelins et le loup** : **Grik** l'ancien, **Pip** le jeune chasseur ; une meute à chasser... et son chef, **Ulric** le seigneur loup, qui chassait par faim. Pacte des gobelins (ils viennent au village, ou restent alliés dans leurs bois), 2 maisons.
- **III — L'érudite et la fée** : **Maëlle** l'érudite elfe, 5 obélisques, **Liora** la fée gourmande de pain, qui révèle que le Cœur a été brisé *de l'intérieur*.
- **IV — La dernière lame oni** : **Kaede**, son clan détruit ; la bête du donjon... puis **Ren**, son frère, possédé par un cristal de Brume (duel). Bûcher funéraire ; Kaede te rejoint ou part sur les routes.
- **V — Le serment des nains** : **Kaïa** la harpie messagère, **Borin** le forgeron, les araignées de la mine, la reine **Brunhild** (on trouve un cristal noir... et un nom : l'Ordre de l'Aube Pure). Borin t'apprend le **mithril**.
- **VI — Les routes de Lysandre** : **Lysandre** la marchande (5 perles), **Zzar** la reine de la Ruche et ses scorpions, un marché.
- **VII — La Horde affamée** : camp d'entraînement, siège de la Horde, **Gorvak** le fils du chef (accueillir ou éloigner son peuple), le cristal noir de l'Ordre.
- **VIII — Nourrir un peuple** : 15 bottes de blé, 10 habitants, **Pip évolue en hobgobelin** grâce au Pacte, le festin des peuples, **Sylve** la dryade.
- **IX — La couronne d'Hauterive** : **Aldéric** le chevalier, sa bête, le roi **Edmond** et le traité (3 lingots d'or).
- **X — Le Grand Inquisiteur** : **Morvain** veut « purifier » les éclats ; Orvane se méfie ; **Lysandre avoue t'avoir espionné pour lui**.
- **XI — La trahison** : la Croisade de l'Aube Pure attaque le village, **Maëlle est enlevée** ; Kaïa suit les ravisseurs ; **Séléné**, reine vampire, propose une alliance.
- **XII — Le Parjure** : les templiers morts-vivants, **duel contre Morvain**, Maëlle libérée... et la vérité : **le Seigneur de la Brume, Caël, était le premier Éveillé**, un réincarné comme toi, fiancé de Séléné — et **Orvane était son ami**, celui qui a brisé le Cœur pour l'arrêter.
- **XIII — Le conseil des pactes** : salle du trône, conseil de tous les peuples, Edmond demande pardon, **Vharok** le dernier dragonide et la bête du nid.
- **XIV — Les dragons et l'ange** : l'héritage des dragons, tous les éclats, un temple, **Aurèle** le Séraphin veut détruire le Cœur : **duel-épreuve**.
- **XV — Le Cœur d'Aube** : le Cœur reformé, **Orvane libéré**, une armée de 15 habitants, **forger une pièce légendaire**, la veille de la bataille avec Séléné.
- **XVI — L'Éveil** : les Veilleurs du Sanctuaire, le **Seigneur de la Brume**, puis **l'âme de Caël** (la libérer ou la porter en toi), la fondation de ta nation (tu choisis son nom : il remplace le rang du royaume) et la grande fête.
- **Récompenses** : à chaque pacte, une **compétence unique** (branche Pacte de l'arbre de talents) et souvent une **arme ou pièce d'équipement unique** : Croc de la Meute, Lame des Cornes-Rouges, Marteau de Borin, Cape des Routes, Hache de la Horde, Bouclier d'Hauterive, Sceptre du Parjure, Lame d'Aube, **Couronne des Pactes** (légendaire), plus des ressources ultra-rares.
- **Dialogues** avec portrait du personnage qui parle (E ou Espace pour la suite), et choix qui changent la suite (qui rejoint le village, qui part, quels objets on reçoit). Un **« ! »** au-dessus de la personne à qui parler.
- **Étapes variées** : parler, apporter des objets, éveiller des obélisques, chasser une meute autour d'un camp, vaincre le boss d'un donjon, repousser un siège, duel contre un boss de l'histoire, construire une pièce, réunir des habitants, forger du légendaire.
- **Suivi** : l'objectif en cours en haut à droite (avec avancement, distance et direction), une **étoile dorée** sur la mini-carte et la carte (M) ; le **journal (O)** récapitule les 16 actes, les éclats et les 23 personnages (où ils sont). Grands titres à chaque acte.
- Tout est sauvegardé (étape, choix, éclats, meute, personnages). Les données sont dans `scripts/story/story_data.gd` (`STEPS`, `NPCS`, `RAIDS`, `DUELS`), les dialogues dans `scripts/story/story_dialogs.gd`, le déroulement dans `scripts/story/story.gd`. Une sauvegarde de l'ancienne histoire recommence la nouvelle au premier acte (les éclats sont gardés).

## Compétences uniques de l'histoire (branche Pacte)
- Dans l'arbre de talents (**T**), l'onglet **✦ Pacte** montre les **15 compétences uniques** que seule l'histoire donne (sans points, jamais oubliées) : Voix d'Outre-Monde (+XP, +butin), Estomac sans fond (absorbe la force des vaincus), Hurlement de la Meute (terreur), Œil des Fées (critiques), Ruée écarlate (ruée de feu), Peau d'acier, Carapace de la Ruche (barrière qui renvoie les coups), Lien d'évolution, Pacte des Racines (soin de groupe), Brume inversée (drain de vie), Souffle du dragon, Ailes du Séraphin (survit à un coup mortel), Chaînes brisées (tourbillon), **Éveil** (ultime : pluie de lumière) et **Roi des Pactes** (gros bonus à tout).
- Tant qu'elles ne sont pas découvertes, elles s'affichent en « ??? ». Les actives se rangent dans les emplacements 1-4 comme les autres talents.

## Évolutions par le Pacte
Une fois le Pacte conclu avec Orvane (acte I de l'histoire), les liens font **évoluer** ceux qui les partagent.
- **Nommer un habitant** : dans sa fiche (E près de lui), zone « ✦ Pacte : nommer pour évoluer » ; écris le nom que tu veux lui donner et clique « Nommer ». Deux évolutions par habitant :
  - 1re : niveau 3 et 50 pièces d'or ; 2e : niveau 8, 150 pièces d'or et 1 larme d'esprit ;
  - chaînes d'évolution : gobelin → **hobgobelin** → chef hobgobelin ; ogre → **oni** → grand oni ; homme-lézard → guerrier → **dragonide** ; fée → grande fée → **fée céleste** (ange) ; mort-vivant → spectre → **vampire** ; dryade → **esprit sylvestre** ; orc → orc noble → seigneur orc ; slime → slime éveillé → slime royal ; lycan, harpie, insecte, homme-bête, démon... (les autres races deviennent « nommées » puis « éveillées ») ;
  - à chaque évolution : nouvelle race ou nouveau titre, **+3 niveaux**, force ×1,25 puis ×1,6, un peu plus grand, et une gerbe de lumière.
- **Familiers** : un monstre affaibli (moins de 30 % de vie, pas un boss) affiche « [E] Pacte » : appuie sur E pour l'apprivoiser. Il reçoit un nom, te suit partout et **combat à tes côtés** (3 familiers au plus, liste dans le panneau du royaume, U).
  - Chaque victoire près de toi le fait progresser : +1 niveau toutes les 4 victoires, **1re évolution à 12 victoires, 2e à 35** (loup → Loup des tempêtes → Seigneur-loup, sanglier → Sanglier de guerre → Roi sanglier, slime → Slime géant → Slime royal, gobelin → Hobgobelin → Chef hobgobelin, ogre → Oni → Grand oni...), plus grand et bien plus fort.
  - K.O., il revient auprès de toi au bout de 40 secondes ; trop loin, il te rejoint. Les familiers sont sauvegardés.
- **Évolution du héros** : l'histoire principale fait évoluer ton âme trois fois (fin des actes IV, XII et XVI) : titre selon ta race (homme-bête éveillé → Seigneur-bête → **Roi des Bêtes** ; humain éveillé → Héros → Saint ; slime éveillé → Slime primordial → Slime divin...), vie, attaque, magie, défense et régénération en hausse, un peu plus grand, puis une aura lumineuse. Le titre s'affiche à côté de ton nom.
- Les règles sont dans `scripts/kingdom/evolution.gd` (habitants et héros) et `scripts/world/familiars.gd` (familiers).

## Équipement légendaire et ressources ultra-rares
- Nouvelle rareté **Légendaire** (orange) et nouvel onglet **Légendaire** dans l'artisanat.
- **Ressources ultra-rares** : **mithril brut** (boss 70 %, pioche de fer sur la roche ou les filons : très rare), **écailles de dragon** (Seigneur Ignarok, salamandres, coffres des îles), **larmes d'esprit** (fées, esprits, dryades), **sang de démon** (démons), **fragments de Brume** (morts-vivants, démons, boss de l'histoire), **cristaux d'aube** et **orichalque** (les plus rares : boss finaux, trésors des îles, bosses très rarement). Un message doré annonce chaque trouvaille.
- **Forge légendaire** : lingots de mithril (four) → épée, casque, armure, gantelets et jambières de mithril (enclume) ; **Lance draconique** et **Armure draconique** (écailles + sang de démon) ; **Bâton des Larmes** et **Cape de Brume** (à l'autel) ; et l'arme ultime, la **Lame de l'Éveil** (orichalque + cristaux d'aube + mithril, attaque 46).
- Les tables de butin rare sont dans `scripts/items/rare_drops.gd`, les modèles dans `tools/voxel_equipment_generator.py`.

## Agriculture
- **Houe** (Artisanat → Outils : 2 bois, 2 cailloux) : choisis-la avec C et appuie sur V pour **labourer** l'herbe ou la terre devant toi (sillons bruns).
- **Semer** : choisis des graines avec C et appuie sur V devant de la terre labourée. Avec une houe dans le sac, V laboure l'herbe et sème d'un coup. Une case fantôme verte montre où.
- **Graines** : les hautes herbes donnent des graines de blé (près d'une fois sur deux), les buissons parfois des carottes et des pommes de terre (elles se replantent). On peut aussi battre 1 blé pour 2 graines.
- **Cultures** : blé (5 min), carottes (4 min), pommes de terre (6 min), en 4 stades (semé, pousse, en herbe, mûr). Elles poussent **1,5 fois plus vite près de l'eau** (sillons plus foncés) et moitié moins vite la nuit.
- **Récolter** : frappe une culture mûre (épis dorés, carottes sorties de terre) : blé et graines, carottes, pommes de terre. Creuser (G) une culture pas mûre l'arrache et rend la graine.
- **Cuisine** (près du feu) : pain (3 blé), pomme de terre cuite, soupe de légumes (2 carottes et 2 pommes de terre : le repas le plus nourrissant).
- **Fermiers** : dès 4 cases labourées, le poste **Champs** apparaît (E près d'un habitant → Poste de travail), 1 fermier pour 8 cases. Pendant les heures de travail, il récolte les cultures mûres (tout va dans la **réserve du village**), ressème aussitôt et sème les cases vides avec les graines que tu lui confies (royaume **U** → « Confier mes graines aux fermiers »). Il garde une partie des récoltes comme semence.
- Un petit champ de blé est déjà semé au village au début de la partie. Le panneau du royaume résume les champs (cases, cultures, mûres, fermiers, graines). Tout est sauvegardé. Le guide a un 4e chapitre « Les champs ».
- Réglages dans `scripts/world/farming.gd` (liste `CROPS` : durée, récolte, valeur pour la réserve) ; objets dans `data/items/` (champ « Culture » d'un objet = ce qu'il fait pousser) ; modèles des cultures créés par `tools/voxel_props_generator.py` (`crop_<culture>_<stade>.glb`).

## Montures, barques et îles
- **Chevaux sauvages** dans les prés (prairie surtout, forêt, montagnes). Prends des **carottes** en main (C) : le cheval te suit. **E** près de lui : il mange une carotte ; au bout de **3**, il est apprivoisé et porte une selle.
- **À cheval** : E pour monter, E pour descendre. On va **1,9 fois plus vite** ; le cheval ne va pas dans l'eau. Il attend là où tu l'as laissé.
- **Barque** : établi, 12 planches et 4 fibres (Outils). Choisis-la (C) et **V face à l'eau** pour la mettre à l'eau. **E** pour monter (depuis la berge ou en nageant) : elle glisse sur les lacs et les mers, plus vite qu'à la nage, sans perdre son souffle. **E près d'une berge** pour débarquer. Elle reste là où tu la laisses.
- **Îles au trésor** : au large, en pleine mer, de petites îles (sable et herbe, arbres de la région) ; sur chacune, un **coffre** (perles, or, parfois un lingot d'or ou un équipement rare). Il faut une barque (ou de bons poumons) pour les atteindre.
- Chevaux apprivoisés, barques et coffres ouverts sont sauvegardés. Réglages : `scripts/world/horse.gd`, `scripts/world/mounts.gd` ; les îles sont créées avec le monde (`ISLAND_GRID`, `ISLAND_CHANCE` dans `scenes/world/world_generator.gd`).

## Saisons
- Une année = **4 saisons de 4 jours** : printemps, été, automne, hiver. La saison et le jour s'affichent sous l'horloge ; le royaume (U) donne la prochaine fête.
- **Couleurs du monde** : herbe fraîche au printemps, plus dorée en été, feuillages orange et rouges et herbe rousse en automne, **neige au sol et sur les arbres** l'hiver (pas dans le désert ni au volcan). Les couleurs glissent doucement d'une saison à l'autre.
- **Météo** : plus de pluie au printemps, beau temps et orages en été, brouillard et pluie en automne ; l'hiver, la pluie tombe en **neige** partout (sauf contrées chaudes), et il fait froid (cape ou armure !).
- **Cultures** : elles poussent plus vite au printemps (×1,25) et **pas du tout l'hiver** (elles attendent le printemps).
- **Fêtes** (2e jour de chaque saison) : fête des semailles, du solstice, des moissons, des lumières. Lanternes et fanions autour du feu de camp, **cadeaux** de saison près du feu (semences, poisson grillé, pain et gâteau, lanternes et manteau de laine...), **feux d'artifice** le soir, et des habitants plus heureux (+12) toute la journée.
- Réglages : `scripts/world/seasons.gd` (durée, couleurs, météo, cultures, fêtes et cadeaux).

## Météo
- Le temps change toutes les quelques heures : **beau temps, nuageux, pluie, orage, brouillard**. Chaque jour a un temps dominant, **annoncé la veille** : sous l'horloge, « Pluie · demain : beau temps ».
- **Climat des régions** : le désert est surtout ensoleillé (et sans orage), le marais souvent dans le brouillard... Ce qui tombe dépend de la région où tu es : **pluie**, **neige** (toundra, montagnes), **vent ou tempête de sable** (désert), **pluie de cendres** (volcan).
- **Effets** : ciel plus sombre et lumière grise, gouttes, flocons, sable ou cendres, brouillard, bruit de la pluie ou du vent.
- **Champs** : la pluie les arrose (ils poussent 1,5 fois plus vite, comme près de l'eau). **Sécheresse** après 3 jours sans pluie : les champs loin de l'eau poussent moins vite.
- **Habitants** : sous la pluie, ils passent la soirée à l'abri (taverne, maisons, dortoir, temple... ou dans leur cabane) au lieu de se détendre dehors ; pendant un orage, ceux qui travaillent dehors (bâtisseurs, fermiers) rentrent aussi. Rester trempé les rend un peu moins heureux.
- **Orage** : éclairs et tonnerre, des monstres rôdent même en plein jour (et 2 de plus la nuit) ; ils fuient quand l'orage passe. La foudre frappe parfois un arbre isolé (du bois à ramasser).
- **Froid** (neige) : sans cape ni armure de torse, et loin d'un feu ou d'une torche, tu as froid au bout de 20 s : tu avances moins vite et tu as faim plus vite.
- Réglages : `scripts/world/weather.gd` (durées, effets) et, pour chaque région (`data/regions/*.tres`, groupe **Météo**) : chances de chaque temps et ce qui tombe.

## Élevage
- **Poules, moutons et vaches** vivent à l'état sauvage dans les prés (prairie, forêt, montagnes, toundra...) ; quelques poules picorent près du village au début.
- **Attirer** : prends leur nourriture en main avec C (**graines de blé** pour les poules, **blé** pour les moutons et les vaches) : les bêtes proches te suivent (♥).
- **Enclos** : fabrique une **mangeoire** (établi : 2 bois, 2 fibres) et pose-la ; mène les bêtes jusqu'à elle : elles s'y installent et restent autour (5 m). Les **barrières** (2 bois → 3, Mobilier) ferment l'enclos : les bêtes ne passent pas au travers.
- **Produits** : nourries par la réserve du village, les poules pondent des **œufs**, les moutons donnent de la **laine**, les vaches du **lait**. Ils tombent près des bêtes (3 au plus) ; avec un **fermier à la grange**, ils sont ramassés tout seuls (œufs et lait dans la réserve, laine dans ton sac). Réserve vide : les bêtes ont faim et ne produisent plus.
- **Petits** : chaque matin, une espèce qui a au moins un couple dans l'enclos a un petit (s'il y a assez de nourriture en réserve), qui grandit en un jour. 6 bêtes au plus par espèce.
- **Recettes** : omelette (2 œufs), fromage (2 laits), gâteau (2 blés, 1 lait, 2 œufs) près du feu ; **manteau de laine** (4 laines, 1 cuir, établi) : une armure de torse qui tient chaud dans la neige.
- Le royaume (U) résume l'élevage ; le guide a un 6e chapitre « L'élevage ». Les bêtes de l'enclos sont sauvegardées. Réglages : `scripts/world/farm_animal.gd` (`SPECIES` : nourriture, produit, fréquence, consommation) et `scripts/kingdom/livestock.gd` (bêtes sauvages par région, petits).

## Nage, grottes sous-marines et pêche
- **Nager** : le héros entre dans l'eau. Là où elle est profonde, il nage, la tête hors de l'eau (plus lentement). **G** (gâchette droite) pour plonger, **Espace** (A) pour remonter ; sans rien toucher, il reste à sa profondeur. On ressort sur une berge basse. Les mers et les grands lacs sont plus profonds au large (jusqu'à 6 m).
- **Souffle** : sous l'eau, une jauge « Souffle » apparaît (15 s) et l'écran se teinte de bleu ; à zéro, on se noie petit à petit. On reprend son souffle à la surface.
- **Grottes sous-marines** : au fond des eaux profondes, des rochers, des cristaux bleus et une colonne de bulles marquent l'entrée d'une grotte. Plonge jusqu'à elle et appuie sur **E** : une grotte inondée (salles et galeries, algues, cristaux) avec des **coffres engloutis** (perles, or, parfois un lingot d'or ou une pièce d'équipement rare) et des **poches d'air** pour respirer. E devant l'anneau de sortie : on remonte au-dessus de l'entrée. Les coffres ouverts sont sauvegardés.
- **Pêche** : fabrique une **canne à pêche** (3 bois, 2 fibres, Outils), choisis-la avec C et appuie sur **V face à l'eau** pour lancer. Quand ça mord (« ! »), V ; puis V quand le curseur est dans la **zone verte** (deux essais). Les gros poissons ont une zone plus petite et un curseur plus rapide. La pluie les fait mordre plus vite.
- **Poissons** selon la région et la profondeur : gardon, truite, carpe, brochet, anguille, saumon, omble, poisson-scorpion (désert), poisson de lave (volcan), poisson-lune (bois enchanté) ; en eau profonde, parfois une **perle** (et parfois une vieille botte...). Se mangent crus, ou en **poisson grillé** près du feu ; les rares se vendent cher au marchand.
- Le guide a un 7e chapitre « L'eau ». Réglages : `scripts/world/fishing.gd` (liste `FISH`), `scripts/dungeon/underwater_caves.gd`, et dans `scenes/player/player.gd` : `BREATH_MAX`, `SWIM_SPEED`.

## Commerce
- Un **marchand ambulant** arrive au village avec sa charrette tous les **3 jours** (le premier le jour 2), à 8 h, et repart le lendemain matin. Son arrivée est annoncée (cor) ; « Marchand au village » s'affiche sous l'horloge, et le royaume (**U**) dit quand il repasse.
- **E près de lui** : sa boutique. À gauche ce qu'il vend (graines, nourriture, matériaux, outils, meubles et quelques pièces d'équipement), à droite ce que tu peux lui vendre, avec ta bourse en pièces d'or. Boutons « ×5 » et « Tout ».
- Son **stock change à chaque visite** : il vient d'une zone du monde qui décide de sa **spécialité** (catégorie mieux fournie) et de la qualité de l'équipement (plus rare s'il vient d'une zone difficile).
- **Prix** : chaque objet a une valeur (matières premières fixes, objets fabriqués = ingrédients + 30 %, équipement selon ses bonus et sa rareté). Le marchand vend au double et rachète à la valeur ; **vendre beaucoup du même objet fait baisser son prix** (jusqu'à 40 %) pendant sa visite. Les objets de moins d'une demi-pièce (planches...) ne se vendent pas.
- **Marché** (pièce fermée, 2 étals et un comptoir, 9 cases) : le marchand vient **tous les 2 jours**, vend 15 % moins cher et rachète 20 % plus cher. Un habitant posté au marché y gagne de l'or. Le guide a un 5e chapitre « Le commerce ».
- Tout est sauvegardé (même le marchand présent et son stock). Réglages dans `scripts/kingdom/trade.gd` (`GOODS` : ce qu'il peut vendre, `VALUES` : valeur des matières premières, fréquence des visites, multiplicateurs de prix) ; la boutique est `scenes/ui/shop_dialog.gd`.

## Besoins des habitants
- **Réserve de nourriture du village** : la boulangerie (pain) et la grange (viande) la remplissent, et tu y déposes la nourriture de ton sac (panneau du royaume, **U**). Chaque habitant y prend un repas quand il a faim (sa faim se vide en 20 minutes). Au début : 5 repas.
- **Lits** : 2 par maison (pièce fermée, porte, un lit et un coffre), 6 par dortoir (4 lits et un coffre), et 2 par cabane du village encore debout. Un habitant sans lit est moins heureux.
- **Bonheur** (0 à 100 %) : nourriture et lit (nourri et logé = « Content »), plus le confort des pièces (taverne +10, temple +10, marché +5, bibliothèque +5, salle du trône +5), le rang du royaume et la sécurité (raid repoussé : +10 pendant 10 min ; raid perdu : -15).
  - Heureux (70 % et plus) : travaille 25 % plus vite, et des voyageurs viennent s'installer (un toutes les 3 min au plus, s'il reste de la place).
  - Mécontent : 20 % plus lent ; malheureux : 40 % plus lent, et s'il le reste 4 minutes, il quitte le village (on est prévenu à 2 minutes).
- **Panneau du royaume** (U, ou menu pause → Royaume) : habitants, lits, réserve, bonheur moyen, liste des habitants avec leur humeur et ce qui leur manque, conseils. L'étiquette de chaque habitant montre aussi son humeur, et la ligne du royaume en haut à gauche résume tout.
- Le guide a un 3e chapitre, « Le village » : remplir la réserve, un lit pour chaque habitant, un village heureux.
- Code : `scripts/kingdom/village_needs.gd`, `scenes/ui/kingdom_panel.gd`.

## Vie quotidienne des habitants
- **Emploi du temps** (selon l'horloge du jeu) : travail 6 h - 12 h et 13 h - 18 h ; **repas** 12 h - 13 h (à la taverne, sinon en cercle autour du feu de camp) ; **détente** 18 h - 21 h (taverne, temple, marché, bibliothèque, ou la place du village) ; **sommeil** 21 h - 6 h.
- **Sommeil** : chacun a sa place (panneau du royaume) : un lit dans une maison ou un dortoir (il s'y allonge), une place dans une cabane du village (il rentre à l'intérieur), ou par terre près du feu s'il n'a pas de lit. Dormir dans un vrai lit rend plus heureux (+15 au lieu de +10).
- **Gardes** (poste au camp d'entraînement) : la nuit, ils font leur ronde autour du village au lieu de dormir.
- **Bulles** au-dessus des têtes : « Zzz » (dort), « ♨ » (mange), « ♪ ♫ … ! » (se détend). L'étiquette et le panneau du royaume disent aussi ce que fait chacun et où il dort.
- La nuit et pendant les repas, les ateliers ne produisent pas et les chantiers s'arrêtent. Un habitant menacé se réveille pour se défendre ou fuir.

## Quêtes des habitants
- De temps en temps (environ toutes les 75 s), un habitant a quelque chose à te demander : un **« ! »** doré flotte au-dessus de sa tête. **E** près de lui : il explique sa demande et la récompense ; **Accepter**, **Plus tard**, ou ouvrir son équipement.
- **5 sortes de quêtes** : **apporter** des objets (planches, bûches, cailloux, nourriture, lingots...), **chasser** une bête marquée « ★ Cible de quête » apparue loin du village, **explorer** en éveillant l'obélisque d'une zone, **défendre** le village en vainquant des créatures de la nuit, **construire** une pièce qui manque (taverne, temple, maison...).
- **Marques** : « ! » quête proposée, « … » quête en cours, « ? » c'est fait, reviens le voir. Au plus **4 quêtes en cours** et 3 propositions à la fois.
- **Suivi à l'écran** (en haut à droite) : chaque quête en cours et son avancement (objets dans le sac, distance et direction de la cible, créatures vaincues...). Le panneau du royaume (**U**) a aussi une section **Quêtes**.
- **Récompenses** : pièces d'or (selon la difficulté), expérience, et l'habitant est bien plus heureux pendant un moment. Après **3 quêtes réussies** pour le même habitant, il devient ton **ami** (« · Ami » sur son étiquette, meilleur moral) et t'offre un **cadeau rare** (arme, armure ou outil en fer, cape).
- Une quête peut être abandonnée (E près de l'habitant). Si l'habitant quitte le village, sa quête disparaît. Les quêtes et l'amitié sont sauvegardées. Le code est dans `scripts/kingdom/quests.gd` (listes `FETCH`, `BUILD`, `RARE_GIFTS` à modifier facilement) et `scenes/ui/quest_dialog.gd`.

## Sons et musique
- **Bruitages** : coups d'épée et impacts (plus forts pour un coup critique), garde, parade, roulade, dégâts reçus, monstre vaincu, défaite du héros, pas (herbe, pierre, bois, sable), coupe du bois, coups de pioche, blocs cassés et posés, creusage, objets ramassés, niveau gagné, talent appris, sorts, cri du boss en 2e phase, cor du raid, tombée de la nuit, lever du jour, sommeil, artisanat, porte, boutons et fenêtres. Les bruits du monde sont en 3D (plus faibles de loin).
- **Ambiances** : oiseaux et vent le jour, grillons la nuit, crépitement du feu de camp en s'approchant.
- **Musiques** (en boucle, avec fondus) : écran titre, jour, nuit (et donjons), combat (boss tout proche ou raid en cours).
- **Options** : volume général, musique et bruitages séparés.
- Tous les sons sont fabriqués par programme (`tools/audio_generator.py`, synthèse en Python pur) dans `assets/audio/sfx/` et `assets/audio/music/`. Pour mettre un vrai son, remplace le fichier en gardant son nom (un `.ogg` du même nom est pris en priorité). Le code est dans `scripts/audio/sound.gd` (autoload `Sound` : `Sound.play("hit", position)`).

## Jour et nuit
- Un jour dure 10 minutes (6 h → 20 h) et une nuit 4 minutes (20 h → 6 h). L'heure et le jour s'affichent sous la mini-carte ; le ciel, le soleil et la lune changent avec l'heure.
- **La nuit**, des monstres de la région apparaissent dans le noir, à 15-24 m du héros, et marchent vers lui : un peu plus chaque nuit (4 la première, jusqu'à 8). Ils n'apparaissent pas près d'une lumière (torche, lanterne posée, feu de camp du village) ni dans une pièce fermée. Au lever du jour, ils fuient.
- **Dormir** : E près d'un lit, la nuit, s'il n'y a pas de monstre à moins de 12 m. On se réveille le matin avec toute sa vie.
- L'heure et le jour sont sauvegardés. Réglages dans `scripts/world/day_cycle.gd`.

## Guide des premiers pas
Un panneau à gauche de l'écran guide le début de partie : couper 3 arbres, casser 2 rochers, fabriquer un outil, fabriquer des planches, construire un abri (pièce fermée avec une porte et un lit), poser une torche, survivre à la première nuit. Puis viennent les chapitres « L'âge du fer », « Le village », « Les champs » (houe, semer, récolter, nommer un fermier) et « Le commerce » (vendre, acheter, construire un marché). Chaque objectif atteint est annoncé ; l'avancement est sauvegardé et le panneau disparaît à la fin (`scenes/ui/guide_panel.gd`).

## Équipement et artisanat
- Les personnages sont **nus** au départ (modèles `models/base/`) ; l'équipement s'affiche par-dessus et suit les mouvements du corps.
- 7 emplacements : tête, torse, bras, jambes, arme, bouclier, dos. Une arme à deux mains retire le bouclier.
- **Ramasser** : marcher sur un objet au sol (anneau coloré = rareté). S'il reste un emplacement vide, l'objet est équipé tout de suite, sinon il va dans le sac.
- **Habitants** : ils commencent avec une partie de la tenue d'un métier (garde, mage, guerrier...), vont chercher les armes et armures meilleures que les leurs qui traînent près d'eux et reposent l'ancienne au sol. Touche E près d'un habitant pour l'équiper avec le contenu de ton sac.
- **Artisanat** (fenêtre I) : le bois, la pierre, le cuir et la fibre se ramassent dans la nature ; le minerai de fer se trouve sur la roche et se fond en lingots à l'**établi** du village. Les objets en fer demandent d'être près de l'établi.

## Combat (temps réel, façon Zelda)
Commandes (clavier-souris / manette) :
- **Attaque** : clic gauche, J / X. Trois appuis = combo (le 3e coup est un coup final qui fait une onde de choc). Chaque arme a ses coups : épée (taillades), lance (estocs et balayage), arme lourde (lents, puissants), bâton (sorts, le 3e en éventail), mains nues (poings et uppercut).
- **Attaque chargée** : maintenir l'attaque (l'arme brille, puis devient dorée), relâcher = attaque tournoyante.
- **Roulade** : Espace / A. Invulnérable. Attaquer juste après = estoc en avant.
- **Esquive parfaite** : rouler au dernier moment avant un coup → ralenti bleuté + images fantômes ; attaquer pendant le ralenti = **riposte** (on se jette sur l'ennemi pour une rafale de coups).
- **Garde** : clic droit, K / LB. Le bouclier bloque tout (sans bouclier, la moitié des dégâts passe). Lever la garde juste avant l'impact = **parade** : l'ennemi est étourdi, et attaquer juste après = **contre** dévastateur.
- **Viser** : clic molette, L / LT. Verrouille la cible (réticule, caméra et personnage tournés vers elle) ; appuyer encore passe à la cible suivante.

Règles :
- Dégâts = attaque × 40 / (40 + défense), ±15 %. Un ennemi étourdi prend 50 % de dégâts en plus.
- **Équilibre** : chaque monstre a une jauge d'équilibre ; quand elle est vide, il est étourdi (étoiles au-dessus de la tête). Les monstres légers sont interrompus par chaque coup, les gros (orc, loup alpha) encaissent.
- Les monstres **annoncent** chaque attaque : pose de préparation, clignotement de leur couleur et « ! ». Pas plus de 2 monstres attaquent la même cible à la fois, les autres tournent autour.
- Effets : traînée de cubes derrière l'arme, gerbes de voxels à l'impact, arrêt sur image, tremblements de caméra, ralentis.
- Les animations sont décrites par des poses clés dans `scripts/combat/move_library.gd` (une pose = rotation de chaque os) : on peut les modifier ou en ajouter.
- Les monstres vivent en camps et lâchent du butin ; les habitants armés défendent le village (K.O. 20 s à 0 PV) ; le joueur se réveille au village sans rien perdre.

## Graphismes (3D voxel)
- 1 case du monde = 1 mètre. Le sol est fait de colonnes de blocs en terrasses, avec le même grain que les personnages (`assets/environment/voxel_grain.png`).
- Personnages : `assets/characters/models/base/<race>_base.glb` (versions nues, `_v2`, `_v3` = autres palettes) ; les habitants tirent une palette au hasard. Les modèles avec métier (`models/<race>_<métier>.glb`) restent disponibles mais ne sont plus utilisés.
- Équipement : `assets/equipment/<race>_equipment.glb` contient les 22 pièces taillées aux mesures de chaque race ; `materials.glb` contient les matériaux posés au sol.
- Animation : `scripts/voxel_character.gd` balance bras et jambes en marchant, fait respirer au repos et gère la roulade.
- Décors : `assets/environment/models/*.glb` (chênes, sapins, buissons, rochers, fleurs, cabane, feu de camp, tonneau, caisse).
- Outils (Python 3, sans dépendance) dans `tools/` :
  - `voxel_character_generator.py` : régénère ou crée des personnages (voir `PROMPT_NOUVELLE_RACE.md`).
  - `voxel_props_generator.py` : régénère les décors (`python voxel_props_generator.py`).
  - `voxel_creature_generator.py` : régénère les créatures (loup, loup alpha, sanglier) dans `assets/characters/creatures/`.
  - `voxel_equipment_generator.py` : régénère les équipements de toutes les races (`python voxel_equipment_generator.py`). Pour ajouter une pièce : écris sa fonction, ajoute-la à `ITEMS`, relance le script, puis crée son fichier dans `data/items/` avec le même `id`.

## Construction du royaume (façon Going Medieval)
Touche **B** (croix bas à la manette) : mode construction. Le héros reste sur place et une **caméra libre** survole le village : ZQSD/flèches pour la déplacer (Maj : plus vite), molette pour zoomer, clic molette + glisser ou A/E (Q/E en QWERTY) pour tourner. B ou Échap pour revenir au héros (on y revient aussi tout seul si le héros est attaqué).
- On trace des **plans** : ils apparaissent en fantômes bleus, et les **habitants libres** (sans poste de travail ni expédition) viennent les construire eux-mêmes, du bas vers le haut, avec les matériaux de ton sac. Un plan sans matériaux devient rouge et attend. Clic droit : effacer le plan visé. Case « Construction instantanée » pour tout réaliser tout de suite.
- **Niveau** (Page ↑ / Page ↓, Ctrl + molette, gâchettes) : la hauteur où l'on travaille. Les murs partent de ce niveau, les sols sont posés juste dessous (leur dessus est au niveau), les toits se posent au niveau du haut des murs. « Couper au-dessus » (C) cache ce qui dépasse pour voir l'intérieur.
- **Catégories** (1-7, ou LB/RB) :
  1. **Terrain** : Récolter (zone : arbres, rochers, buissons → bois, pierre, fibres, minerais), Aplanir (zone : sol mis au niveau choisi), Creuser, Remblayer (±50 cm).
  2. **Murs** : Pièce (glisser un rectangle : les 4 murs) ou Mur droit ; hauteur de 1 à 6 (`[` `]`).
  3. **Sols** : plancher sur une zone.
  4. **Toits** : à deux pans (avec débord et pignons fermés) ou plat.
  5. **Portes et fenêtres** : clic sur un mur pour y percer une porte (dans l'axe du mur) ou une fenêtre.
  6. **Mobilier** : tous les meubles, avec les pièces auxquelles ils servent (R : tourner).
  7. **Démolir** : zone à démonter à partir du niveau choisi (les blocs et meubles reviennent dans le sac), ou Annuler les plans d'une zone. Les décors du village de départ se démolissent aussi : cabanes (planches, rondins, chaume), tonneaux, caisses, établi et râtelier (rendus comme meubles à reposer). On ne peut pas construire à travers un de ces décors : il faut d'abord le démolir.
- **Matériau** : choisi sous les outils (V pour passer au suivant) ; le nombre que tu possèdes est affiché (rouge : aucun).
- **Blocs** (1 m, ou dalles de 50 cm) : planches, rondins, chaume, terre, sable → pierre brute → briques, tuiles, verre → pierre polie, ardoise → marbre, marbre noir → marbre doré. Plus le matériau est rare, plus il faut un atelier pour le fabriquer (table de tailleur, four, meule, enclume).
- **Pièces** : une zone fermée par des murs (au moins 2 m de haut) avec une **porte** devient un lieu dès que son **mobilier** est posé : enclume + foyer de forge + établi = Forge, four à pain + pétrin + table = Boulangerie, 2 mannequins + râtelier = Camp d'entraînement, lit + coffre = Maison... En mode construction, les pièces incomplètes affichent ce qu'il leur manque. Taille et forme libres.
- **Âges de l'empire** : le matériau des murs fixe l'âge d'une pièce. Deux pièces reconnues en pierre font passer à l'Âge de la Pierre, puis Pierre taillée, Pierre polie, Marbre et Or.
- **Rangs** : Campement, Hameau, Village, Bourg, Ville, Cité, Capitale d'empire (nombre de pièces reconnues + âge).
- **Habitants** : **E** près d'un habitant > Poste de travail. Les étoiles indiquent son affinité (race et talents). Il va à son poste par la porte, travaille près des meubles et produit (lingots, pain, briques, planches...) directement dans ton sac. Certaines pièces donnent aussi un bonus au héros (attaque, défense, magie, régénération, expérience).
- Les meubles d'artisan servent aussi d'ateliers pour toi : approche-toi d'un four, d'une enclume, d'une meule... pour débloquer leurs recettes.
- Modèles : `tools/voxel_blocks_generator.py` (textures des blocs), `tools/voxel_furniture_generator.py` (31 meubles), `tools/build_database.py` (objets, recettes et types de pièces).

## Monde ouvert
- Un monde de 640 × 640 m (réglable : nœud **World** > **World Size**) découpé en 25 zones d'environ 128 m (**Zone Size**), chacune avec un nom et un type de région tiré selon le climat (nord froid, sud chaud), l'humidité et l'éloignement du village. Les frontières sont fondues sur une dizaine de mètres (**Region Blend**).
- Le terrain est calculé et affiché par morceaux de 16 m autour du héros (**View Distance**) : seuls les morceaux proches existent en 3D, avec leurs camps de monstres et leurs objets au sol. Un objet ramassé ne revient pas.
- Plus on s'éloigne du village, plus les monstres sont forts : chaque zone a sa fourchette de niveaux (« Loup · Nv 3 ») et des camps d'élite (loup alpha, ogre des cimes, seigneur squelette, dryade corrompue, seigneur démon...).
- Nouveaux monstres : slimes (bleu, acide, de magma), araignée géante, loup de givre, ours des neiges, scorpion géant, salamandre de feu, homme-lézard, harpie, ogre, esprit follet, fée sauvage, dryade corrompue, démons, seigneur squelette.
- **Obélisques** : un par zone. Passe à côté pour l'activer, puis voyage vers n'importe quel obélisque activé depuis la carte. Celui du village est actif dès le départ.
- **Carte** (M) : se dévoile là où tu passes, avec les noms et niveaux des zones découvertes, les obélisques, les entrées de donjon (vertes une fois vaincues) et ton royaume. Molette ou gâchettes : zoom. **Mini-carte** en haut à droite, avec le nom de la zone.
- Un bandeau annonce chaque nouvelle zone (nom, région, niveaux) ; la découverte d'une zone donne de l'expérience.
- Les feuillages et les murs entre la caméra et le héros deviennent transparents.
- Modèles : `tools/voxel_region_props.py` (cactus, sapins enneigés, arbres morts, champignons géants, cerisiers, roseaux, cristaux, roches volcaniques, obélisque, porte de donjon), `tools/voxel_creature_generator.py` (créatures), `tools/regions_database.py` (monstres et régions).

## Donjons et boss
- Chaque zone (sauf celle du village) a une entrée de donjon. **E** devant l'entrée : on descend dans un donjon généré sous la surface, toujours le même pour une partie donnée : une dizaine de salles reliées par des couloirs, bâties avec les blocs de la région (réglables dans `data/regions/*.tres` > groupe **Donjon** : sol, murs, piliers, couleur des torches et de l'ambiance).
- Les salles sont gardées par les monstres de la région, un peu plus forts qu'à la surface, dont un monstre d'élite. Des coffres contiennent des matériaux, de l'or et parfois un équipement rare. Un portail près de l'entrée permet de remonter.
- Au fond, la salle du boss se ferme derrière toi. Chaque région a son boss, avec ses pouvoirs (**Boss Powers**) toujours annoncés à l'avance :
  - **onde** : un disque rouge se remplit autour du boss, puis une onde de choc frappe tout ce qui est dedans (roule hors du cercle ou esquive au bon moment) ;
  - **pluie** : des projectiles tombent sur toi et autour de toi (chaque point d'impact est marqué au sol) ;
  - **invocation** : il appelle des monstres de sa région ;
  - **charge** : il fonce sur toi.
- Sous la moitié de sa vie, le boss **enrage** : il frappe plus vite, lance ses pouvoirs plus souvent et en enchaîne parfois deux. Sa barre de vie s'affiche en bas de l'écran.
- Les 8 boss : Grondebois le Roi Sanglier (prairie), Tissombre la Reine Araignée (forêt), le Slime Primordial (marais), Ankhar le Scorpion Empereur (désert), Brisemonts Roi des Ogres (montagnes), Givrecroc l'Ours Ancien (toundra), Sylvaëlle la Dryade Mère (bois enchanté), Ignarok Seigneur des Cendres (terres de cendres).
- Boss vaincu : trésor (or, lingots, équipements rares), portail de sortie, beaucoup d'expérience, et ton héros **absorbe l'âme du boss** : un bonus permanent propre à chaque boss (**Boss Soul**, par exemple « Prédation du Slime Primordial : +2,5 vie/s »). L'entrée du donjon devient verte sur la carte (« Vaincu »).
- Si tu tombes dans un donjon, tu te réveilles au village comme d'habitude. On ne peut pas construire dans un donjon.

## Recrutement, compagnons et raids
- **Voyageurs** : des campements de voyageurs sont dispersés dans le monde (réglage **Traveler Density** des régions). Leurs races dépendent de la région (**Recruit Races** : nains et ogres en montagne, fées et esprits au bois enchanté, démons et onis dans les cendres...). Chacun a un niveau, un métier où il excelle et un second talent.
- **E** près d'un voyageur : il se présente et dit ce qu'il demande pour rejoindre ton village (des matériaux selon son métier, et de l'or pour les plus expérimentés). Il faut aussi de la place : la population maximale vaut 8 + les lits de tes maisons et dortoirs. Une fois recruté, il part pour ton village où tu peux lui donner un poste.
- **Prisonniers** : chaque donjon retient un prisonnier (dans une petite cage) qui te rejoint sans rien demander.
- **Compagnons d'expédition** : dans la fiche d'un habitant (E près de lui), coche « Compagnon d'expédition » (2 au plus). Il te suit partout (voyage par obélisque, donjons, réveil au village), défend le héros et progresse avec toi (son niveau suit le tien). Donne-lui de bonnes armes et armures ! Points verts sur la mini-carte.
- **Raids** : de temps en temps (premier raid après 8 minutes, puis toutes les 10 à 14 minutes, réglable dans le nœud **Menaces**), une bande de pillards attaque le village. Le raid est annoncé 45 secondes à l'avance avec sa direction. La bande dépend de ton niveau (gobelins, horde d'orcs, clan des ogres, légion des cendres) et grossit avec le rang de ton royaume.
- Les pillards contournent le décor, s'en prennent aux habitants et au héros, et **cassent les murs construits** qui leur barrent la route : une palissade les retarde. Les **gardes** (habitants au camp d'entraînement) défendent tout le village avec un bonus d'attaque. Points rouges sur la mini-carte.
- Tous les pillards vaincus : butin au feu de camp (or, lingots, cuir, bois) et expérience. Sinon, au bout de 3 min 30, ils repartent en volant un quart de trois de tes piles de ressources. Pas de raid pendant que tu es dans un donjon.

## Sauvegarde, menus et options
- **3 emplacements de sauvegarde** et une **sauvegarde automatique** toutes les 5 minutes (désactivable). Menu pause > Sauvegarder ; écran titre > Continuer (la plus récente) ou Charger. Chaque emplacement affiche le héros, son niveau, le rang du royaume, la zone, le temps de jeu et la date.
- Ce qui est sauvegardé : le héros (apparence, classe, métier, compétence, niveau, expérience, vie, sac, équipement, âmes de boss), le monde (graine, terrassement, décors récoltés, carte dévoilée, zones découvertes, obélisques activés, donjons vaincus, objets ramassés, voyageurs recrutés), toutes les constructions (blocs et meubles : les pièces sont reconnues à nouveau), les habitants (race, nom, talents, niveau, équipement, poste de travail, compagnons) et le temps avant le prochain raid. Sauvegarder dans un donjon te fera reprendre devant son entrée.
- Les fichiers sont dans le dossier utilisateur de Godot (`user://saves/partie_1.json`... ; sous Windows : `%APPDATA%\Godot\app_userdata\L'Éveil du Royaume\saves`).
- **Options** (écran titre ou pause, enregistrées dans `user://options.cfg`) : difficulté, distance de la caméra, volume, plein écran, rappel du menu des commandes à l'écran, sauvegarde automatique.
- **Difficulté** : Facile (monstres −25 % de vie et −30 % de dégâts, raids 40 % plus espacés), Normal, Difficile (monstres +35 % de vie et de dégâts, raids 25 % plus fréquents). Les valeurs sont dans `scripts/save/save_game.gd` (ENEMY_HP, ENEMY_DMG, RAID_DELAY).
- **Équilibrage** : à niveau égal avec l'équipement de sa tranche de niveau, un monstre normal tombe en 3 à 7 coups et le héros encaisse 12 à 25 coups ; un boss demande 35 à 75 coups et le héros tombe en 7 à 9 de ses coups (ils sont tous annoncés : esquive-les !).

## Feuille de route
Le jeu a deux piliers : un **RPG d'action en monde ouvert** vu de dessus (héros, exploration libre, donjons, boss, combat en temps réel à la Zelda) et la **construction d'un royaume** (des huttes jusqu'à une capitale d'empire, population de n'importe quelles races, habitants dirigés un par un). Inspiration : l'univers de « Moi, quand je me réincarne en Slime », avec des noms originaux.

Choix de conception :
- Création du héros libre : on choisit la race, la classe et le métier ; les compétences uniques évoluent.
- Construction : libre, bloc par bloc comme Minecraft (terrassement, murs, toits) ; une pièce fermée devient un lieu selon son mobilier ; âges selon les matériaux et rangs (campement → capitale d'empire).
- Habitants : dirigés un par un, avec un métier et un poste selon leurs affinités.
- Mort du héros : réveil à la ville, sans perte d'inventaire.
- Commandes : manette et clavier-souris.

Étapes :
1. Combat à la Zelda : verrouillage de cible, combos, attaque chargée, esquive parfaite, parade et contre, animations et effets. **(fait)**
2. Héros : création et personnalisation, classes, métiers, niveaux **(fait)**  ; 151 compétences uniques qui évoluent **(fait)**.
3. Construction du royaume : terrassement, blocs et matériaux par âge, pièces reconnues par leur mobilier, rangs, postes des habitants et production. **(fait)**
4. Monde ouvert : 8 régions et 25 zones nommées, monde chargé par morceaux, niveaux des monstres, carte, mini-carte, obélisques de voyage rapide. **(fait)**
5. Donjons et boss : un donjon généré par zone, 8 boss à pouvoirs annoncés et seconde phase, trésors, âmes de boss. **(fait)**
6. Recrutement dans le monde, compagnons en expédition, menaces sur la ville : voyageurs et prisonniers à recruter, 2 compagnons, raids de pillards qui assiègent le village. **(fait)**
7. Sauvegarde, menus, équilibrage : écran titre, menu pause, 3 emplacements + sauvegarde automatique, options, 3 niveaux de difficulté, réglage des boss. **(fait)**

Toutes les étapes de la feuille de route sont terminées. Pistes pour la suite : commerce entre villages, plus de régions et de boss, arbres de talents pour les habitants.

Ajouts depuis : caméra libre à 360°, saut et double saut, construction à la Going Medieval (plans bâtis par les habitants), **arbre de talents du héros** (27 talents, 15 nouvelles attaques et nouveaux sorts).
