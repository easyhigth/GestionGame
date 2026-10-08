# L'Éveil du Royaume — documentation développeur

Ce qu'on peut modifier sans code, les outils, les optimisations, les tests et la feuille de route. (Voir aussi le [README](../README.md) et le [guide du joueur](joueur.md).)

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

## Graphismes (3D voxel)
- 1 case du monde = 1 mètre ; un humain mesure 2 cases (voir « Échelle » plus bas). Le sol est fait de colonnes de blocs en terrasses d'un demi-cube, avec le même grain que les personnages (`assets/environment/voxel_grain.png`).
- Personnages : `assets/characters/models/base/<race>_base.glb` (versions nues, `_v2`, `_v3` = autres palettes) ; les habitants tirent une palette au hasard. Les modèles avec métier (`models/<race>_<métier>.glb`) restent disponibles mais ne sont plus utilisés.
- Équipement : `assets/equipment/<race>_equipment.glb` contient les 22 pièces taillées aux mesures de chaque race ; `materials.glb` contient les matériaux posés au sol.
- Animation : `scripts/voxel_character.gd` balance bras et jambes en marchant, fait respirer au repos et gère la roulade.
- Décors : `assets/environment/models/*.glb` (chênes, sapins, buissons, rochers, fleurs, cabane, feu de camp, tonneau, caisse).
- Outils (Python 3, sans dépendance) dans `tools/` :
  - `voxel_character_generator.py` : régénère ou crée des personnages (voir `PROMPT_NOUVELLE_RACE.md`).
  - `voxel_props_generator.py` : régénère les décors (`python voxel_props_generator.py`).
  - `voxel_creature_generator.py` : régénère les créatures (loup, loup alpha, sanglier) dans `assets/characters/creatures/`.
  - `voxel_equipment_generator.py` : régénère les équipements de toutes les races (`python voxel_equipment_generator.py`). Pour ajouter une pièce : écris sa fonction, ajoute-la à `ITEMS`, relance le script, puis crée son fichier dans `data/items/` avec le même `id`.

## Limites connues et optimisations
Audit fait sur tout le jeu (profilage des scripts, du moteur, des nœuds et des appels de dessin). Outil : `tools/profile_systems.gd` (temps de chaque script par image, nœuds par type, objets au sol).

**Optimisé**
- **Interface (HUD)** : l'horloge, la météo et la couleur du jour étaient recalculées et réappliquées à chaque image (la météo cherchait la région du village à chaque fois) : 4 fois par seconde suffisent. Coût du HUD : 1,3 ms → 0,26 ms par image. Temps total des scripts au village : 3,1 ms → 2,0 ms.
- **Mini-carte** : redessinée seulement quand le héros bouge ou tourne (et 5 fois par seconde pour les pillards et compagnons), avec la liste des lieux proches mise en cache au lieu de parcourir tous les châteaux, hameaux, épaves et villes du monde à chaque dessin.
- **Objets au sol** : les tas identiques tout proches se regroupent ; les objets tombés disparaissent au bout de 10 minutes (30 pour les rares et mieux), comme dans Minecraft ; loin du héros (30 m), un objet « dort » (ni détection de collision ni animation). Les objets semés par le monde ne disparaissent pas.
- **Icônes** : chaque icône gardait pour toujours sa petite scène 3D de rendu (des centaines avec l'arsenal et les blocs) ; elle est maintenant copiée dans une texture ordinaire puis la scène est libérée.
- **Blocs** : toutes les textures de blocs sont réunies dans un seul tableau de textures. Un morceau de construction n'a plus qu'un maillage opaque et un maillage de verre, au lieu d'un maillage par texture (vitrine de tous les blocs : 35 maillages pour 26 morceaux, contre plusieurs centaines avant).
- **Objets sans modèle** : la pièce d'or, le lingot d'or, l'or brut, le marbre brut, la barque, le voilier et le sifflet du griffon avaient une icône vide ; ils ont maintenant un modèle.

**Limites levées**
- **Blocs lumineux** : la pierre lumineuse et la lanterne marine brillent et éclairent vraiment (quelques lumières par morceau au plus, qui s'estompent au loin).
- **Arcs** : ils tiraient des sorts ; ils tirent maintenant de vraies flèches (bois, pointe, empennage), plus rapides, qui comptent sur l'attaque.
- **Escaliers** : 33 escaliers (pierres polies et en briques, tous les bois), posés dans le sens du regard, qu'on monte sans sauter (deux demi-marches). 316 blocs de construction en tout.
- **Failles** : elles étaient toutes pareilles. 5 thèmes d'arène (cristal, lave, glace, sylvestre, abysses), 3 dispositions (couronne de piliers, croix de murets, quatre gros piliers), une taille qui varie, et des **modificateurs** à la Diablo dès le rang 3 (Rapides, Robustes, Enragés, Explosifs, Nombreux ; 2 dès le rang 10, 3 dès le rang 25), chacun ajoutant un objet au trésor du gardien. Le panneau du portail montre le thème et les modificateurs du rang choisi.

**Deuxième passe**
- **Physique** : mesure fiable (médiane sur 300 pas). Les monstres loin du héros (plus de 45 m, au calme) ne se calculent plus qu'un pas de physique sur 4, les habitants à plus de 60 m un sur 3 (le temps est cumulé : rien n'est ralenti). Physique au village : ~4,5-5,5 ms → 3,4 ms par pas ; les monstres ne coûtent presque plus rien.
- **Plafonds qui grandissent avec la progression** :
  - familiers qui te suivent : 3, 4 au niveau 100, 5 au niveau 300 ;
  - compagnons d'expédition : 2, 3 quand le royaume devient une Ville, 4 en Capitale d'empire ;
  - quêtes en cours : 4, +1 par rang du royaume à partir du Village (7 au plus) ;
  - bêtes par espèce : 6, +2 par mangeoire ou auge en plus de la première (12 au plus).
- **Murets et barrières** : 12 murets (un par pierre) et 9 barrières (une par bois) qui se raccordent tout seuls aux murets, barrières et murs voisins ; ils bloquent le passage comme un bloc. 337 blocs de construction en tout.
- **Panoplies** : chaque matériau a ses ornements en blocs, placés d'après la pièce (donc à la taille de chaque race) : rivets (cuivre, acier), cimier et gemme rouge (bronze, or), pointes d'os, cristaux d'obsidienne lumineux, gemmes d'argent, runes de mithril, flammes d'orichalque, cornes et écailles draconiques. Les boucliers prennent entièrement la couleur du matériau (l'emblème doré reste).

**Grande passe**
- **Équilibrage du niveau 1 au niveau 1000** (`tools/balance_sim.gd`) : la simulation compare à chaque niveau une arme forgée (meilleur matériau maîtrisé, raffinée, enchantée) au butin épique et mythique et aux monstres. Le butin de niveau suit maintenant une courbe en `0,03 × niveau^0,95` (au lieu de `niveau / 12`, qui rendait le butin bien plus fort que la forge) : un objet épique vaut à peu près une arme forgée, un mythique la dépasse.
- **Prix** : les ressources rares (mithril, orichalque, écailles, larmes, gemmes, pierres d'âme, nouveaux minerais, pierres et bois) avaient la valeur par défaut (1 pièce) ; elles ont maintenant un vrai prix. Le butin de niveau vaut selon son niveau et sa rareté, les enchantements ajoutent à la valeur. Le marchand vend les nouveaux matériaux et des armes de l'arsenal.
- **Artisanat plus pratique** : barre de **recherche** (sans accents) sur des centaines de recettes, case **« Fabricable »**, onglet **★ Favoris** (sauvegardé), et dans la fiche d'un objet la **comparaison** avec l'objet porté (attaque, défense, magie).
- **Habitants artisans** : ils montent eux aussi de niveau 1 à 100 en travaillant. Le **forgeron** du village fabrique des armes de l'arsenal (du meilleur matériau qu'il maîtrise, parfois déjà raffinées) et prend des **commandes** (bouton « Commander » dans l'Armurerie : ingrédients + or), l'**enchanteur** produit de la poussière arcanique et parfois une pierre d'âme, le maçon, le bûcheron, le tisserand et le verrier produisent minerais, pierres, essences de bois, teintures et verre teinté. Tout cela vient **en plus** de la production habituelle de l'atelier.
- **Guide** : deux nouveaux chapitres, **L'ARTISAN** (arme de l'arsenal, métier au niveau 10, enchantement, bloc du catalogue) et **LA FIN DE PARTIE** (palier du monde, faille, titan), et 4 astuces (poussière arcanique, premier niveau de métier, failles, recherche). 45 étapes en 11 chapitres.
- **Portillons** : 9 portes de barrière (une par bois) qui se raccordent aux barrières et s'ouvrent ou se ferment avec **E** ; ouvertes, on passe.
- **Toits en pente** : 12 pentes (tuiles, ardoise, chaume, planches, pierre polie, cuivre, terre cuite, sapin, ébène, quartz, obsidienne...) posées dans le sens du regard ; on y monte comme sur un escalier.
- **Silhouettes d'armures** : en plus des ornements, chaque matériau change la forme des pièces : épaulières de plus en plus massives (aucune pour le cuivre, légères pour le bronze, l'os et l'argent, larges pour l'acier, l'or, l'obsidienne et le mithril, énormes pour l'orichalque et le dragon), tassettes sur le plastron, visière sur les casques (acier, obsidienne, mithril, dragon), genouillères sur les jambières.

**Limites qui restent (choix ou coût)**
- Le moteur garde un coût de base (~1,4 ms de physique) et les habitants proches du héros se calculent à chaque pas.
- Les armures gardent la base des modèles en fer et en cuir (la silhouette change par des pièces ajoutées, pas par un modèle entièrement nouveau).
- Formes de blocs : plein, dalle, escalier, pente, muret, barrière, portillon, trappe et vitre (les portes de maison sont des meubles).
- Plafonds volontaires : raffinage +15, enchantements rang V, 5 emplacements d'enchantement, 8 familiers en tout (10 avec la ménagerie).

## Tests automatiques
- Le dossier `tests/` contient plus de 90 tests de jeu (histoire, interface, sauvegarde, donjons, siège, forge, diplomatie, événements, métiers, guide, équilibrage...). Chacun lance une vraie partie, joue un scénario et vérifie le résultat (« OK » / « ÉCHEC »).
- Tout lancer : `GODOT=/chemin/vers/godot tests/run_tests.sh` (ou seulement quelques-uns : `tests/run_tests.sh save story`). Il faut l'éditeur Godot 4.7 ; sans écran, `xvfb-run` est utilisé automatiquement. Importer le projet une première fois : `godot --headless --editor --quit --path .`.
- Le monde des tests est toujours le même (graine 4242, ou `TEST_SEED=...`). Les captures d'écran vont dans `tests/captures/`, les journaux dans `tests/logs/` (ignorés par git).
- Un test réussi affiche `RÉSULTAT : tout est bon` sans erreur de script ; le lanceur fait le résumé et renvoie un code d'erreur si un test échoue.
- **GitHub** lance automatiquement tous les tests à chaque pull request et à chaque envoi sur `main` (`.github/workflows/tests.yml`, réparti sur 4 machines). Le résultat apparaît sur la PR ; journaux et captures sont téléchargeables dans l'onglet « Actions ».

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

## Organisation du code
- `scenes/player/player.gd` reste le plus gros script (entrées, combat, caméra, nage). Ses sous-systèmes s'en détachent peu à peu dans `scripts/hero/` : la faim, la nourriture et les potions sont dans `player_needs.gd` (`PlayerNeeds`), le joueur garde l'état et des méthodes qui délèguent. Prochains candidats : la visée à la souris, la nage, la caméra.
- Autoloads (`project.godot`) : `Items`, `TimeFX`, `Access` (daltonisme, mouvement réduit), `I18n` (langues), `GameState`, `Sound`, `SaveGame`, `UiStyle`, `LabelLod`, `Unlocks` (menus progressifs).
- Dans les tests, ne pas citer de nom de classe du jeu au niveau du script (les autoloads ne sont pas encore là à la compilation) : charger avec `load()` dans `_process`, ou passer par `root.get_node("Items")`.

## Échelle
- 1 case = 1 m. Les personnages voxel (modèle humain : 1,806 m) sont agrandis par `VoxelCharacter.WORLD_SCALE` (2 / 1,806) : un humain mesure 2 cubes. Pour placer quelque chose au-dessus d'une tête, multiplier par `visual.height_scale()` (taille choisie × échelle du monde) plutôt que par `visual.scale.y`.
- Corps : `BuildGrid.BODY_HEIGHT` = 1,85 m (passe sous un plafond à 2 cubes) ; capsules de collision de 1,8 m (habitants, héros) et 1,55 m (monstres).
- Grands meubles : `BuildGrid.LONG_FURNITURE` (le lit : 2 cases). `footprint()` donne les cases, `furniture_touching()` les meubles qui couvrent une case (y compris leurs pieds), `furniture_center()` le milieu. Une ancienne sauvegarde repose ses lits avec `force` (jamais perdus).
- Relief : `step_height` = 0,5 m (demi-cube), `terrace_size` = 0,14 ; la roche monte deux fois plus vite, toujours par demi-cubes. Le relief d'ensemble est le même qu'avec les anciennes marches de 25 cm.
- Test : `tests/run_tests.sh scale`.
