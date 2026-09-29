# Jeu de gestion

## Ouvrir le projet
Godot 4.7 > Importer > `project.godot`, puis F5 pour lancer.

## Commandes
- ZQSD ou flèches : se déplacer
- Espace : roulade (esquive : invulnérable pendant la roulade)
- Clic gauche / J (maintenu) : frapper avec son arme, ou lancer un sort avec un bâton de mage
- I (ou Tab) : inventaire, équipement et artisanat
- E près d'un habitant : ouvrir son équipement pour lui donner des armes et armures
- R : changer de race (pour tester les 22 races)
- N : nouveau monde

## Ce que tu peux modifier sans code
- `data/races/*.tres` : les 22 races (nom, description, stats, modèle 3D nu du joueur, modèles des habitants, équipements de la race). Duplique un fichier pour créer une race.
- `data/items/*.tres` : les 28 objets (matériaux, armes, boucliers, casques, armures, brassards, jambières, capes) : nom, description, emplacement, rareté, bonus d'attaque / défense / magie / vitesse.
- `data/enemies/*.tres` : les 6 monstres (loup, loup alpha, sanglier, gobelin pillard, squelette, orc brutal) : modèle, équipement porté, vie, attaque, défense, vitesse, distance de repérage, portée et durée de leurs coups, butin et chances de le lâcher.
- `data/recipes/*.tres` : les 23 recettes d'artisanat (objet fabriqué, ingrédients et quantités, établi obligatoire ou non).
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

## Feuille de route
Le jeu a deux piliers : un **RPG d'action en monde ouvert** vu de dessus (héros, exploration libre, donjons, boss, combat en temps réel à la Zelda) et la **construction d'un royaume** (des huttes jusqu'à une capitale d'empire, population de n'importe quelles races, habitants dirigés un par un). Inspiration : l'univers de « Moi, quand je me réincarne en Slime », avec des noms originaux.

Choix de conception :
- Création du héros libre : on choisit la race, la classe et le métier ; les compétences uniques évoluent.
- Construction : placement libre sur une grille, paliers de progression (campement, village, bourg, ville, cité, capitale).
- Habitants : dirigés un par un, avec un métier et un poste selon leurs affinités.
- Mort du héros : réveil à la ville, sans perte d'inventaire.
- Commandes : manette et clavier-souris.

Étapes :
1. Combat à la Zelda : verrouillage de cible, combos, attaque chargée, esquive parfaite, parade et contre, animations et effets. **(fait)**
2. Héros : création, classes, métiers, compétences uniques qui évoluent, niveaux. **(prochaine étape)**
3. Construction du royaume : bâtiments sur grille, paliers, métiers et postes des habitants.
4. Monde ouvert : régions, monde plus grand chargé par morceaux, carte.
5. Donjons et boss.
6. Recrutement dans le monde, compagnons en expédition, menaces sur la ville.
7. Sauvegarde, menus, équilibrage.
