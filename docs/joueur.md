# L'Éveil du Royaume — guide du joueur

Tout ce qu'on peut faire dans le jeu : touches, histoire, construction, combat, royaume. (Voir aussi le [README](../README.md) et la [documentation développeur](dev.md).)

## Ouvrir le projet
Godot 4.7 > Importer > `project.godot`, puis F5 pour lancer. Le jeu commence par l'écran titre (`scenes/ui/title_screen.tscn`) : Continuer, Nouvelle partie (création du héros), Charger, Options, Quitter. `scenes/main.tscn` se lance aussi seul (F6) avec un héros par défaut.

## Commandes (clavier et souris)
Le jeu se joue au **clavier et à la souris** (la manette marche aussi, avec ses boutons habituels). Toutes les touches sont dans le jeu : **Échap → Commandes**. Le 1er onglet, **Plan du clavier**, dessine le clavier (dans ta disposition, AZERTY ou QWERTY) et la souris. Chaque touche utilisée y a la couleur de sa famille : vert pour se déplacer, rouge pour combattre, or pour agir dans le monde, bleu pour les menus. Les autres onglets donnent la liste complète : Se déplacer, Combattre, Récolter et bâtir, Menus, Construction, et Personnaliser pour changer n'importe quelle touche. **F1** affiche un aide-mémoire compact à l'écran.

L'idée du plan : la main gauche reste sur ZQSD et tout ce qui sert en combat est autour. Les menus sont à droite du clavier, sous leur initiale.

**Souris**
- Clic gauche : frapper (maintenir : attaque chargée), récolter, casser un bloc.
- Clic droit : garde et parade. **Avec un objet en main, le clic droit le pose** (bloc, meuble, graine, houe, canne à pêche, barque...), comme dans Minecraft. Maintenu, il pose les blocs en continu.
- Molette : zoom de la caméra. **Avec un objet en main, elle change d'objet** (Ctrl + molette : zoom).
- Clic molette : viser la cible la plus proche ; maintenu : tourner la caméra (vue de dessus).
- Boutons de côté : roulade (avant) et potion (arrière).

**Main gauche (autour de ZQSD)**
| Touche (AZERTY) | Action |
|---|---|
| Z Q S D | se déplacer, dans le sens de la caméra |
| Espace | sauter (dans l'eau : remonter) |
| Maj | roulade (invulnérable un instant) |
| A | compétence unique |
| F | **agir** : parler, recruter, quête, fiche d'un habitant, atelier, coffre, barrière, monter, dormir |
| R | boire une potion |
| Tab | viser la cible la plus proche (encore : la suivante) ; aussi clic molette |
| G | creuser (maintenir) ; dans l'eau : plonger |
| X | manger |
| C | **prendre / ranger l'objet en main** (reprend le dernier objet tenu) |
| V | poser (comme le clic droit) |
| 1 … 0 | compétences de la barre du bas |
| Ctrl + 1 … 0 | prendre l'objet d'une case de la barre de construction |
| Alt (maintenu) | libérer la souris pour cliquer à l'écran |

**Menus (sous leur initiale)**
| Touche | Menu |
|---|---|
| **E** (ou I) | **équipement** : sac, équipement, artisanat sur soi |
| B | bâtir : mode construction |
| M | carte du monde et voyage rapide |
| J (ou O) | journal (histoire, quêtes) |
| T | talents et compétences |
| U | royaume (habitants, carte, production, expéditions) |
| N | nations : diplomatie |
| P | familiers (ordre suivant) |
| H | hauts faits : succès et bestiaire |
| F1 | aide-mémoire des touches · F3 : métiers · F5 : changer de vue |
| Entrée | terminal de commandes (/aide) · Échap : pause, ou fermer la fenêtre ouverte |

La touche d'un menu le referme aussi.

**Ce qui aide à s'y retrouver**
- **Invite à l'écran** : près de quelque chose d'utilisable, une plaque au-dessus des barres dit ce que fait E (« [E] Parler à Magnus », « [E] Ouvrir le coffre », « [E] Dormir jusqu'au matin », « [E] Descendre »...).
- **Tous les textes du jeu suivent tes touches** : guide, astuces, messages, descriptions d'objets, étiquettes des habitants, barres du bas. Ils écrivent `{action}` dans le code (`KeyBindings.fmt`), qui devient la touche choisie, dans la disposition du clavier. Si tu changes une touche, tout le jeu l'affiche.
- La barre de construction rappelle ce que fait le clic droit avec l'objet tenu (« Clic droit : poser », « pêcher »...), ainsi que la molette et C.
- Changements par rapport à avant : potion Z → R, manger H → X, journal O → J, diplomatie Y → N, succès F1 → H, aide-mémoire F2 → F1. C / X ne servent plus à faire défiler les objets : c'est la molette. J / K / L ne doublent plus la souris. Échap ne range plus l'objet en main (c'est C). Touches de test depuis l'éditeur : F9 (nouveau monde), F10 (race suivante).
- Test : `tests/run_tests.sh keys` (plan du clavier, onglets, pas de touche en double, personnalisation et conflits, clic droit qui pose, molette, C, invite à l'écran).

## Création du héros
- **Race** : 22 races, chacune avec ses caractéristiques (vie, force, agilité, magie, vitesse) dans `data/races/*.tres`. L'agilité accélère les coups.
- **Apparence** : style propre à la race (coiffure, cornes, espèce de l'homme-bête, élément de l'esprit, type d'ange...), barbe (humain ; longue et tressée pour le nain), couleurs de peau, de cheveux (ou plumes, fourrure, feuillage) et d'yeux (pastilles de la race ou couleur libre), taille et carrure.
- **Classe** (`data/classes/`, 13 classes) : Guerrier, Paladin, Barbare, Rôdeur, Assassin, Mage, Moine, Nécromancien, Druide, Chevalier, Barde, Clerc, Cryomancien. Donne l'équipement de départ, des bonus, le gain de caractéristiques à chaque niveau et un talent offert dans l'arbre (ex. Nécromancien : Soif, Druide et Chevalier : Enraciné, Cryomancien : Sang-froid, Clerc : Foi, Moine et Barde : Étincelle).
- **Métier** (`data/jobs/`, 14 métiers) : Forgeron, Chasseur, Bûcheron, Mineur, Herboriste, Marchand, Tisserand, Pêcheur, Alchimiste, Cuisinier, Fermier, Joaillier, Enchanteur, Architecte. Donne des objets de départ (sauf départ à mains nues), un avantage (vie, défense, magie, vitesse, régénération, butin...) et deux métiers d'artisanat qui commencent au niveau 10 (`Crafts.JOB_START`).
- **Niveaux** : les monstres vaincus donnent de l'expérience ; chaque niveau augmente la vie, l'attaque, la défense et la magie selon la classe (barre bleue sous la vie).
- Les modèles du héros sont dans `assets/characters/hero/` (outil `tools/voxel_hero_generator.py`) : la peau, les cheveux et les yeux y sont peints avec des couleurs repères, remplacées en jeu par les couleurs choisies (`VoxelCharacter.set_colors`).

## Compétences uniques
- **151 compétences** réparties en 26 catégories (Péchés, Vertus, Sagesse, Feu, Eau, Glace, Vent, Foudre, Terre, Lumière, Ténèbres, Poison, Sang, Espace, Temps, Son, Métal, Nature, Cristal, Martiale, Bête, Survie, Ombre, Esprit, Chaos, Commandement). On en choisit une à la création (onglet « Compétence », avec filtre, recherche et tirage au hasard).
- Chaque compétence **évolue** et change de nom : Rang I (compétence unique) au niveau 1, Rang II (supérieure) au niveau 6, Rang III (ultime) au niveau 12. Ex. : Vorace → Dévoreur → Seigneur de la Faim ; Éclair → Foudre vivante → Dieu du Tonnerre.
- **Passif** permanent (attaque, magie, vie, critiques, vol de vie, brûlure, étourdissement, ralentissement, absorption de force sur les ennemis vaincus, survie à un coup mortel, parade et esquive facilitées...), renforcé à chaque rang.
- **Actif** (Q / RB), avec recharge (compteur en bas de l'écran) : explosion, salve de projectiles, ruée, météores, tourbillon, souffle, drain de vie, zones de poison ou de gel, aura, barrière, soin (aussi des habitants), terreur, exécution, téléportation...
- Les compétences sont décrites dans `tools/skills_database.py` (qui génère `data/skills/*.tres`) : pour en ajouter une, écris une ligne `S(...)` et relance le script. Leur fonctionnement est dans `scripts/hero/hero_skill.gd`.

## Arbre de compétences et niveaux (jusqu'au niveau 1000)
- **Niveaux 1 à 1000.** Jusqu'au niveau 100, l'expérience demandée reste celle d'avant (40 au niveau 1, +35 par niveau). Ensuite, il faut 10 de plus à chaque niveau (12 505 au niveau 1000), et chaque ennemi rapporte de plus en plus d'expérience (jusqu'à 4 fois plus au niveau 1000).
- **Niveau de puissance** : les statistiques de base du héros (et des ennemis qui s'adaptent à lui : sièges, armées, tournois, bandits, raids...) suivent le niveau jusqu'à 100, puis montent 4 fois moins vite (325 au niveau 1000). Au-delà, c'est l'arbre qui fait la différence.
- **Points** : 2 par niveau jusqu'au niveau 50, puis 1, et 1 par âme de boss, soit environ 1 050 points au niveau 1000. Le talent de départ de ta classe est offert.
- **L'arbre (touche T)** : une grande étoile de **377 nœuds** à huit branches qui partent du centre dans toutes les directions. Les branches voisines sont reliées par des **ponts**.

  | Branche | Contenu |
  |---|---|
  | Lame | épées, charges |
  | Feu | brasiers, météores |
  | Foudre | éclairs, orages |
  | Givre | prisons de glace |
  | Lumière | soins, jugements |
  | Terre | séismes, ronces |
  | Sang | drains, rage |
  | Ombre | poisons, assassinats |

  Tout l'arbre est ouvert dès le début. Un nœud s'apprend avec ses points, son niveau (de 1 au centre jusqu'à 990 au bout), et un nœud voisin plus près du centre déjà appris.
- **Types de nœuds** :
  - petits ronds : **runes** (petits bonus de la branche) ;
  - grands ronds : **talents** (gros bonus) ;
  - carrés : **compétences actives**.
- **89 compétences actives**, de 5 raretés :

  | Rareté | Nombre | Coût | Dégâts | Zone | Recharge |
  |---|---|---|---|---|---|
  | Commune | 16 | 1 point | ×1,4 à 2 | — | — |
  | Rare | 24 | 2 points | — | — | — |
  | Épique | 16 | 3 points | — | — | — |
  | Légendaire | 24 | 5 points | ×4 à 6 | jusqu'à 16 m | — |
  | **Mystique** | 9 | 12 points | ×10 à 12 | 18 à 20 m | une minute |

  Les **mystiques** se trouvent au bout de chaque branche, à partir du niveau 700. À leur lancement :
  - le temps ralentit et une colonne de lumière monte du héros ;
  - l'écran s'illumine et des ondes de choc se succèdent ;
  - puis s'abattent par exemple des épées géantes (Mille Soleils d'Acier), dix-huit météores (Apocalypse), quarante éclairs (Colère du Ciel), l'hiver de la fin du monde (Fimbulvetr), une aube qui soigne tout (Aube Éternelle), des pics de roche (Fureur de Gaïa), la lune pourpre qui draine la vie (Nuit Pourpre) ou des lames d'ombre (Nuit sans fin).
- **Cataclysme** (tout au bout de la branche Terre, **niveau 990**, 30 points) : une seconde de silence, puis tout explose à 26 mètres à la ronde.
  - Les dégâts sont colossaux et les ennemis sont projetés.
  - Le sol se creuse en un **cratère géant** au fond de roche brûlée, entouré d'un grand bourrelet de terre.
  - Arbres, rochers et constructions du monde volent en éclats. Les constructions du joueur sont épargnées.
- **Barre de compétences**, façon MMORPG, en bas de l'écran : **10 emplacements**, touches 1 à 9 et 0 (configurables dans les options). Chaque case montre la rareté et la recharge de sa compétence.
  - Pour placer une compétence apprise, choisis son emplacement dans la fenêtre de l'arbre, ou appuie sur la touche voulue pendant qu'elle est sélectionnée.
  - À la manette : croix droite pour choisir, R3 pour lancer.
- **Dans la fenêtre de l'arbre** :
  - glisser (ou stick droit) pour se déplacer, molette (ou gâchettes) pour zoomer, flèches (ou croix) pour passer d'un nœud à l'autre ;
  - « Centrer », « Tout oublier » (rend tous les points) ;
  - l'onglet **✦ Pacte** contient les compétences uniques de l'histoire.
- **Terminal** : `/niveau 990` puis `/competences` pour tout apprendre jusqu'à ton niveau et essayer le Cataclysme.
- **Anciennes sauvegardes** : les talents déjà appris restent appris, et les 4 anciens emplacements passent dans la nouvelle barre.
- **Pour les modifs** :
  - le contenu est dans `scripts/hero/talent_tree.gd` (`CONTENT` : chaque branche, compétence par compétence ; `SHAPE` : la forme d'une branche) ;
  - les effets sont dans `scripts/hero/hero_skill.gd` (`storm` pour les frappes venues du ciel, `crater` pour le Cataclysme, `_mythic_intro` pour la mise en scène des mystiques).
- Test : `tests/test_skills.gd`.

## Début de partie et récolte (façon Minecraft)
- **On commence à mains nues, comme dans Minecraft** : ni arme, ni armure, ni ressources, ni meubles au campement, ni champ semé. **Le héros arrive seul au monde** : ni feu de camp, ni habitants. On fabrique son propre **feu de camp** (3 bois + 3 cailloux : il éclaire et sert à cuisiner), et les premiers habitants sont des voyageurs attirés dès qu'on a bâti un abri (on les recrute en leur parlant). Tout se trouve et se débloque : du bois en frappant un arbre à mains nues, un établi (4 bois), des outils en bois puis en pierre, une arme en bois à l'établi... (`GameState.bare_start` ; les tests gardent l'ancien départ avec `GG_CLASSIC_START=1`.)
- Tout le reste se récolte. Chaque coup d'arme frappe aussi le décor devant le héros ; il se brise après quelques coups et lâche des ressources à ramasser en marchant dessus :
  - arbre (5 coups) : 3 à 5 bois, parfois de la fibre ; rocher (6 coups) : 2 à 4 cailloux, parfois du minerai de fer, du marbre ou de l'or ; buisson (2 coups) : fibre ; herbes et fleurs (1 coup) : fibre ;
  - décors du village : cabane (14 coups : planches, rondins, chaume), tonneau, caisse, établi, râtelier.
  - Une hache coupe les arbres deux fois plus vite, un marteau de guerre casse les rochers deux fois plus vite, et un coup chargé compte double.
- **Creuser** (G / gâchette droite) : chaque coup de pelle abaisse le sol de 50 cm devant soi et donne 1 bloc de terre (sable sur la plage, cailloux dans la roche, parfois du minerai).
- Ensuite on fabrique (inventaire, I) : bois → planches, rondins, portes, torches ; fibre → chaume ; cailloux → blocs de pierre...
- **Outils** (inventaire → Artisanat → Outils) : hache et pioche en bois (3 bois), en pierre (2 bois + 3 cailloux, près d'un établi), en fer (voir « L'âge du fer »). Il suffit de les avoir dans son sac, le meilleur est utilisé tout seul : ×2 en bois, ×3 en pierre, ×4 en fer. Le héros le sort et le tient en main quand il récolte (la hache pour un arbre, un buisson ou un décor du village, la pioche pour un rocher ou pour creuser), puis reprend son arme 3 secondes après, ou tout de suite si un ennemi approche. Sans pioche, un rocher ne donne que des cailloux (pas de minerai) et on ne peut pas creuser la roche.
- Les réglages sont dans `scripts/world/harvest.gd` (points de vie des décors, butin, outils).

## Prise en main : tutoriel, menus et gestion simplifiés
- **Tutoriel naturel** : le guide (à gauche) commence par un chapitre **LES BASES** où l'on apprend en faisant : marcher, regarder autour de soi (et F5), sauter, ouvrir son sac. Chaque étape se valide toute seule dès qu'on l'a faite. Viennent ensuite les **PREMIERS PAS** à mains nues : du bois, un établi, des cailloux, des outils, une arme, des planches, un abri, une torche, un repas, la première nuit. Les conseils montrent **les touches réglées par le joueur** (ZQSD sur un clavier AZERTY, la touche changée dans Commandes...). Au total, 51 étapes en 12 chapitres.
- **Astuces au bon moment** : la première fois qu'on tient un bloc en main, que le soleil se couche, qu'on ouvre la construction, qu'on a faim, ou quand le village grandit (panneau du royaume).
- **Menus qui se ferment toujours** : le mode construction a un bouton **✕ Quitter (B / Échap)** bien visible ; Échap avec un bloc en main le range (mains nues) au lieu d'ouvrir le menu.
- **Plans prêts (construction, touche 8, catégorie par défaut)** : un clic sur le sol trace **une pièce complète** (murs, sol, porte, toit à deux pans et les meubles qu'il faut) pour chacun des 21 types de pièces : maison, dortoir, entrepôt, taverne, forge, marché, temple... L'aperçu dit combien de blocs il faut et quels meubles sont encore à fabriquer. Les habitants libres bâtissent avec les matériaux choisis dans Murs, Sols et Toits.
- **Panneau du royaume (U)** : un cadre **« À faire maintenant »** en haut donne les 3 actions les plus utiles (habitants sans lit, réserve vide, habitants sans poste, champs, élevage, marché, taverne, temple, prochain rang), avec un bouton **Construire ▸** qui ouvre directement le bon plan prêt.

### Finitions de la caméra et du départ en solo
- **3e personne** : la caméra ne traverse plus le relief, les blocs posés ni les murs des donjons ; coincée contre un mur, elle revient derrière la tête du héros (qui s'efface s'il la touche presque). **Aide à la visée** : un coup, une flèche ou un sort part vers l'ennemi le plus proche du viseur (moins de 10°).
- **1re personne** : le bras du héros (couleur de sa peau, ou de son armure) et son arme sont visibles, se balancent quand il marche et partent quand il frappe.
- **Barre de construction** : dans le sac, la fiche d'un bloc, d'un meuble ou de graines propose « Barre de construction : 1 … 0 » pour le ranger dans la case voulue (les deux objets s'échangent si la case est prise). À la manette : LB + croix gauche/droite parcourt la barre.
- **Seul au début** : pas de raid tant que tu n'as aucun habitant ; la première nuit ne fait sortir que 2 monstres ; il n'y a plus de zone sûre invisible au point d'arrivée : ce sont tes torches et ton feu de camp qui protègent.

### Rythme du départ en solo (mesuré par `tests/test_rythme.gd`)
- Seul, **c'est le héros qui bâtit ses plans** : il suffit de se tenir à côté (4,5 m), avec les matériaux dans le sac ; un plan à la fois, du bas vers le haut. Quand il y a des habitants libres, ils bâtissent aussi.
- Les armes **en bois, en os et en pierre** ont une poignée en fibres (et non en cuir) : on peut s'armer avant de pouvoir chasser.
- Temps d'action mesuré (sans compter la recherche des ressources ni les menus ; un vrai joueur met environ 2 à 3 fois plus) : établi 0,3 min, outils et épée en bois 1 min, feu de camp 1,1 min, maison complète (58 planches, 42 chaume, porte, lit, coffre) 4,7 min, premier habitant au plus tard 3 min après.

### Vue rapprochée plus légère, retours en jeu et glisser-déposer
- **Performances en 3e et 1re personne** (mesure : appels de dessin au village, de dessus 3 666, en 3e personne 8 251 avant) : en vue rapprochée, la caméra ne dessine plus au-delà de la zone chargée (≈ 80 m au lieu de 250 m) et une **brume de distance** efface le monde avant sa limite (au lieu d'un bord net) ; les ombres ne sont calculées qu'à 28 m (elles coûtaient plus de 40 % des appels de dessin) et les petits décors s'arrêtent à 40 m. 3e personne : 8 251 → 6 239 appels de dessin (−24 %). La vue de dessus garde ses réglages. Le brouillard de la météo se superpose à cette brume.
- **Retours en jeu** : le feu de camp fabriqué est le vrai feu animé (flammes qui dansent, lumière qui vacille, crépitement qu'on entend en s'approchant) ; quand le héros bâtit ses plans, on le voit donner des coups d'outil, avec des éclats et un petit bruit ; en 1re personne, le bras bouge aussi quand on pose un bloc.
- **Glisser-déposer** : dans le sac, la rangée « Barre de construction » accepte un objet glissé depuis le sac (les deux objets s'échangent si la case est prise) ; clic droit sur une case : la vider.

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
- **Manger** : X choisit tout seul le plat le plus nourrissant qui ne gaspille pas (ou clic sur la nourriture dans le sac).
- **Nourriture** : baies (buissons, 8), viande crue (sangliers, loups, ours, 10), viande cuite (32, +15 vie), pain (boulangerie du village, 26, +8 vie), ragoût (viande + 3 baies, 55, +40 vie).
- **Cuisine** (inventaire → Artisanat → Cuisine) : près du feu de camp du village, d'un four, d'un four à pain ou d'une forge.
- Le guide a une nouvelle étape : « Mange un repas cuit » (avant la première nuit).

## Histoire principale : L'Éveil du Royaume
Une longue histoire originale en **16 actes (88 étapes, 5 à 7 par acte)** et **23 personnages**, dans l'esprit des récits de réincarnation où l'on bâtit une nation de monstres. Tu es mort dans un autre monde (une ville de verre, un soir de pluie, des phares...) et tu renais ici. Seul **Orvane**, un ancien esprit enchaîné dans un cristal près du village, t'entend : vous faites un **Pacte**. De pacte en pacte, ton petit village devient une nation où tous les peuples vivent ensemble.
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
- **Suivi** : l'objectif en cours en haut à droite (avec avancement, distance et direction), une **étoile dorée** sur la mini-carte et la carte (M) ; le **journal (J)** récapitule les 16 actes, les éclats et les 23 personnages (où ils sont). Grands titres à chaque acte.
- Tout est sauvegardé (étape, choix, éclats, meute, personnages). Les données sont dans `scripts/story/story_data.gd` (`STEPS`, `NPCS`, `RAIDS`, `DUELS`), les dialogues dans `scripts/story/story_dialogs.gd`, le déroulement dans `scripts/story/story.gd`. Une sauvegarde de l'ancienne histoire recommence la nouvelle au premier acte (les éclats sont gardés).

## Quêtes secondaires des personnages
- **44 quêtes** : deux pour chacun des 20 personnages de l'histoire encore présents (Orvane, Glou, Grik, Pip, Ulric, Maëlle, Liora, Kaede, Kaïa, Borin, Brunhild, Lysandre, Zzar, Gorvak, Sylve, Aldéric, Edmond, Séléné, Vharok, Aurèle).
- La **première** s'ouvre après leur arc dans l'histoire, la **seconde** après la fin de l'histoire (fin de partie : récompenses plus rares, orichalque, cristaux d'aube, armes uniques).
- Un **« ! »** au-dessus d'un personnage : il a une quête à proposer (E pour lui parler, « J'accepte » ou « Plus tard ») ; un **« ? »** : l'objectif est rempli, va lui faire ton rapport.
- Objectifs variés : apporter des objets (ragoûts, gâteaux, lingots de mithril, marbre...), chasser des monstres (loups de Brume, fées sauvages, templiers morts-vivants, démons...), vaincre des grandes bêtes, construire des pièces, éveiller tous les obélisques, apprivoiser des familiers, faire évoluer des habitants, forger une arme légendaire, atteindre un niveau.
- Le **journal (J)** liste les quêtes en cours avec leur avancement. Tout est sauvegardé. Les quêtes sont dans `scripts/story/side_quest_data.gd` (une entrée par quête), le moteur dans `scripts/story/side_quests.gd`.

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
  - K.O., il revient auprès de toi au bout de 40 secondes ; trop loin ou bloqué derrière un obstacle, il te rejoint. Les familiers sont sauvegardés.
  - **Ordres (touche P)** : « Suivez-moi ! », « Attendez ici ! » (ils gardent l'endroit), « Attaquez ma cible ! » (la cible verrouillée, sinon la plus proche).
  - **Monture** : E près d'un loup, sanglier, ours, araignée ou scorpion familier pour le monter (×1,6 de vitesse, ×1,8 et ×2 une fois évolué) ; E pour descendre.
  - **Équipe et village** : 3 familiers te suivent, jusqu'à 8 en tout ; les autres vivent autour du feu de camp et **défendent le village**. Dans le panneau du royaume (U) : « Au village » / « Avec moi » et « Libérer ».
  - **Modèles d'évolution** : les créatures (loups, sanglier, ours, slimes, araignée, scorpion, salamandre) ont 2 modèles d'évolution (cornes, marques lumineuses, épines de cristal, anneau au sol) ; les familiers humanoïdes (gobelin, orc, ogre...) prennent les modèles d'évolution de leur race.
- **Évolution du héros** : l'histoire principale fait évoluer ton âme trois fois (fin des actes IV, XII et XVI) : titre selon ta race (homme-bête éveillé → Seigneur-bête → **Roi des Bêtes** ; humain éveillé → Héros → Saint ; slime éveillé → Slime primordial → Slime divin...), vie, attaque, magie, défense et régénération en hausse, un peu plus grand, puis une aura lumineuse. Le titre s'affiche à côté de ton nom.
- **Modèles 3D des évolutions** : chaque race (sauf l'humain) a **3 modèles d'évolution** — 21 races × 3 paliers, en 3 couleurs pour les habitants et dans tous les styles pour le héros (384 modèles). Les changements sont légers mais reconnaissables : petites cornes et peinture de guerre puis couronne d'os (gobelin), cornes courbes et runes rouges (orc), yeux et marques de jade puis couronne d'or (elfe), ailes de chauve-souris et couronne d'épines (vampire), couronne de gel puis d'or (slime), bois de cerf fleuris (dryade), flammes d'âme (mort-vivant), auréoles et cristaux (ange, esprit)... et au 3e palier un **anneau de lumière au sol**.
  - Le corps garde exactement le squelette et les proportions de sa race : **tous les équipements s'y portent** comme avant (armures, casques, armes, capes).
  - Un habitant garde sa variante de couleur en évoluant ; s'il change de race (gobelin → hobgobelin), il prend le modèle de la nouvelle race, puis ses évolutions. Le héros prend le modèle de son évolution (1 à 3) avec ses propres couleurs.
  - Générés par `tools/voxel_evolution_generator.py` (une fonction `evo_<race>` par race, paliers cumulatifs) : fichiers `models/base/<race>_base[_v2|_v3]_evoN.glb` et `hero/<race>_s<style>_evoN.glb`.
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
- Tous les sons sont fabriqués par programme (`tools/audio_generator.py`, synthèse en Python pur) dans `assets/audio/sfx/` et `assets/audio/music/`. Pour mettre un vrai son, remplace le fichier en gardant son nom (un `.ogg` du même nom est pris en priorité). Chaque musique a deux variantes (`<nom>_2`, `<nom>_3` : nouvelles mélodies sur la même grille, puis un passage plus calme) que le jeu enchaîne avec le thème dans un ordre au hasard. Le code est dans `scripts/audio/sound.gd` (autoload `Sound` : `Sound.play("hit", position)`).
- Bruitages des systèmes récents : leviers, piques des pièges, mur secret qui coulisse, potions, sertissage des gemmes, gravure des runes, succès, cloches des événements, tambours de guerre (sièges, invasions, déclarations de guerre), fanfares (tournoi, annexion, victoire de siège), sceau des traités.

- **Une musique par région** (`tools/audio_generator.py`, générée comme les autres) : flûte et harpe pour la forêt profonde, cloches et battements sourds pour les marais, oud et percussions à main dans le désert, cors pour les montagnes, carillons glacés dans la toundra, célesta pour le bois enchanté, tambours de guerre pour les terres de cendres, marimba et maracas dans la jungle. Près du village, on garde le thème « de chez soi » ; la nuit, le thème nocturne.
- **Donjons et grottes** : un thème souterrain inquiétant. **Boss** : un thème de combat à part, plus lourd que celui des raids.
## Jour et nuit
- Un jour dure 10 minutes (6 h → 20 h) et une nuit 4 minutes (20 h → 6 h). L'heure et le jour s'affichent sous la mini-carte ; le ciel, le soleil et la lune changent avec l'heure.
- **La nuit**, des monstres de la région apparaissent dans le noir, à 15-24 m du héros, et marchent vers lui : un peu plus chaque nuit (4 la première, jusqu'à 8). Ils n'apparaissent pas près d'une lumière (torche, lanterne posée, feu de camp du village) ni dans une pièce fermée. Au lever du jour, ils fuient.
- **Dormir** : E près d'un lit, la nuit, s'il n'y a pas de monstre à moins de 12 m. On se réveille le matin avec toute sa vie.
- L'heure et le jour sont sauvegardés. Réglages dans `scripts/world/day_cycle.gd`.

## Guide des premiers pas
Un panneau à gauche de l'écran guide le début de partie : couper 3 arbres, casser 2 rochers, fabriquer un outil, fabriquer des planches, construire un abri (pièce fermée avec une porte et un lit), poser une torche, survivre à la première nuit. Puis viennent les chapitres « L'âge du fer », « Le village », « Les champs » (houe, semer, récolter, nommer un fermier) et « Le commerce » (vendre, acheter, construire un marché), « L'élevage », « L'eau », « L'aventure » (vaincre un boss de donjon, renforcer un objet à la forge, boire une potion, ouvrir les succès) et « Les voisins » (diplomatie, présent, traité, métier avancé, événement du monde). Des **astuces** s'affichent aussi la première fois qu'une situation se présente (première gemme, rune ou potion, donjon piégé, énigme des leviers, guerre, épidémie, premier succès). Chaque objectif atteint est annoncé ; l'avancement est sauvegardé et le panneau disparaît à la fin (`scenes/ui/guide_panel.gd`).

## Équipement et artisanat
- Les personnages sont **nus** au départ (modèles `models/base/`) ; l'équipement s'affiche par-dessus et suit les mouvements du corps.
- 7 emplacements : tête, torse, bras, jambes, arme, bouclier, dos. Une arme à deux mains retire le bouclier.
- **Ramasser** : marcher sur un objet au sol (anneau coloré = rareté). S'il reste un emplacement vide, l'objet est équipé tout de suite, sinon il va dans le sac.
- **Habitants** : ils commencent avec une partie de la tenue d'un métier (garde, mage, guerrier...), vont chercher les armes et armures meilleures que les leurs qui traînent près d'eux et reposent l'ancienne au sol. Touche E près d'un habitant pour l'équiper avec le contenu de ton sac.
- **Artisanat** (fenêtre I) : le bois, la pierre, le cuir et la fibre se ramassent dans la nature ; le minerai de fer se trouve sur la roche et se fond en lingots à l'**établi** du village. Les objets en fer demandent d'être près de l'établi.

### Arsenal : 884 armes à forger
- Onglet **Armurerie** de l'artisanat (fenêtre I) : **17 types** d'armes × **13 matériaux** × **4 designs** = **884 armes**, chacune avec son modèle 3D en blocs et ses statistiques.
- Types : épée, espadon, sabre, katana, rapière, dague, hache, hache de bataille, marteau de guerre, masse d'armes, morgenstern, lance, hallebarde, faux, bâton, sceptre, arc. Chacun a 4 designs (ex. Épée, Épée large, Épée dentelée, Épée royale ; Espadon, Claymore, Flamberge, Espadon du héraut...) : **équilibré**, **lourd** (+15 % de dégâts, plus lent), **vif** (plus rapide, critiques) ou **orné** (magie, dégâts critiques ; un lingot d'or en plus).
- Matériaux, du plus simple au plus rare : bois, os, pierre (à l'établi), cuivre, bronze, fer, acier, argent, or (la magie), obsidienne, mithril, orichalque, écailles de dragon (à l'enclume). Chaque matériau demande un niveau de **Forgeron d'armes** (1 à 90).
- Nouvelles ressources : minerais de cuivre, d'étain et d'argent, charbon (dans les rochers et les filons), os (squelettes, bêtes), obsidienne (filons d'or), poussière arcanique (tous les monstres, les boss, en réduisant des objets), pierre d'âme (boss, failles, titans). Au four : lingots de cuivre, de bronze (cuivre + étain), d'acier (fer + charbon), d'argent ; charbon de bois.
- Les armes de l'arsenal servent aussi de base au butin de niveau (failles, titans, paliers du monde).

### Forge : raffiner (+15), sertir, enchanter
- Onglet **Forge**, près d'une **enclume** : **raffiner** de +1 à **+15** : +10 % des caractéristiques et +1 point par niveau. Le niveau de Forgeron (armes) ou d'Armurier (armures) fixe le raffinage maximum : +5 au niveau 1, +15 au niveau 100.
- Coût : +1 à +3 lingots de fer et or ; +4 à +6 lingots d'or, mithril brut et or ; +7 à +9 lingots de mithril, larme d'esprit et or ; +10 un orichalque ; +11 à +15 de plus en plus d'orichalque, du mithril, une larme d'esprit et beaucoup d'or.
- **Gemmes** : 1 emplacement, 2 à +4, 3 à +8 (Rubis, Saphir, Émeraude, Topaze, Améthyste, Diamant). **Runes** gravées par les enchanteurs.
- Onglet **Enchantement**, près d'un **autel** : **26 enchantements** du rang I au rang V — Tranchant, Embrasement, Givre, Vampirisme, Précision, Brutalité, Célérité, Exécution, Tonnerre, Arcanes, Furie, Moisson d'âmes, Sagesse, Fortune (armes) ; Protection, Vitalité, Épines, Régénération, Esquive, Vivacité, Stabilité, Absorption, Dernier rempart (armures) ; Concentration, Parade et **Éveil** (attaque, magie et vie).
  - **Emplacements** : 1, +1 tous les 5 niveaux de raffinage, +1 si l'objet est épique ou mieux (jusqu'à 5).
  - **Rang maximum** selon le raffinage de l'objet (I jusqu'à +3, II dès +4, III dès +7, IV dès +11, V dès +14) et le niveau d'**Enchanteur** (II au niveau 15, III à 35, IV à 60, V à 85).
  - Coût : poussière arcanique et or, larmes d'esprit dès le rang III, **pierre d'âme** au rang V. On peut retirer un enchantement (rend de la poussière) ou **réduire un objet en poussière**.
  - **Rareté qui monte** : une arme ordinaire raffinée et enchantée devient rare, épique, **légendaire** (+10, ou 14 rangs d'enchantement), et même **mystique** (+15 avec 20 rangs : 4 enchantements au rang V).
- Les bonus de tout l'équipement porté sont plafonnés (ex. 40 % de critiques, 15 % de vol de vie, +60 % d'attaque). Un objet amélioré se sauvegarde avec ses gemmes, sa rune et ses enchantements.

### Métiers : 12 artisanats du niveau 1 au niveau 100 (F3)
- Comme dans Dofus, on **ne choisit pas** son métier : on le **pratique**. 12 métiers : Forgeron d'armes, Armurier, Enchanteur, Joaillier, Mineur, Bûcheron, Alchimiste, Cuisinier, Pêcheur, Fermier, Tailleur, Bâtisseur. Le métier choisi à la création du héros donne deux métiers au niveau 10.
- On progresse en faisant : forger, raffiner, enchanter, sertir, miner, abattre, fondre, cuisiner, préparer des potions, pêcher, récolter, coudre, fabriquer des blocs et des meubles. Une action trop facile pour son niveau rapporte moins.
- Courbe douce : environ 27 000 points d'expérience pour le niveau 100 (quelques centaines d'actions par métier).
- Bonus : matériaux plus nobles et raffinage plus poussé (Forgeron, Armurier), **chef-d'œuvre** (l'arme ou l'armure sort déjà raffinée, jusqu'à 45 %), rangs d'enchantement (Enchanteur), récolte double (Mineur, Bûcheron, Fermier, Pêcheur), double fabrication (Alchimiste, Cuisinier, Tailleur), blocs en plus (Bâtisseur).
- Onglet **Métiers** de l'artisanat, ou touche **F3**. Commande `/metier <métier|tous> <niveau>`.

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

## Introduction
- Chaque nouvelle partie (après la création du héros) s'ouvre sur une courte cinématique : la légende du Cœur d'Aube écrite en calligraphie sur fond noir, puis la caméra survole le cristal d'Orvane (« un cristal murmure ton nom »), glisse jusqu'au héros au village, et le titre « L'Éveil du Royaume — Acte I » apparaît entre deux bandes de cinéma. Musique du titre, interface cachée pendant la scène.
- Espace, E, Échap ou un clic la passent. On peut la revoir depuis le journal (O → « Revoir l'introduction »).

## Rendu : ombrages, vent et eau
- **Sol** : ombrage des coins au pied des talus et des murs, talus plus sombres vers leur pied (d'autant plus qu'ils sont hauts), légères nuances d'une case à l'autre et par taches, sol mouillé au bord de l'eau.
- **Arbres et buissons** : les feuillages ondulent au vent (davantage en haut des arbres), chaque arbre a sa nuance, le dessous des couronnes est plus sombre et les feuilles laissent passer un peu de lumière.
- **Blocs** : un léger biseau au bord de chaque face et une nuance propre à chaque bloc, pour bien lire les constructions.
- **Eau** : petites vagues animées (reflets qui bougent), effet Fresnel (on voit au travers de haut, elle reflète le ciel en rasant), écume sur les crêtes et scintillement du soleil.
- **Image** : tons « filmiques », halo autour des lumières (torches, lave, feu), brume de distance qui prend la couleur du ciel (bleutée le jour, dorée au crépuscule, sombre la nuit). Le halo et la brume sont coupés en qualité graphique basse.

## Interface : bois sombre, dorures et parchemin
- **Polices** (libres, licence OFL, dans `assets/ui/fonts/`) : **Almendra** pour les titres (une calligraphie de manuscrit médiéval, faite pour les jeux de fantasy) et **Alegreya Sans** pour le texte (humaniste et très lisible, même petite ; chiffres alignés pour les statistiques).
- **Thème commun** à toute l'interface (`scripts/ui/ui_theme.gd`, chargé au démarrage) : cadres en bois sombre aux coins dorés sertis d'un rubis, boutons en planche avec fermoirs de fer (dorés au survol), onglets, ascenseurs dorés, barres, champs de saisie, infobulles, listes déroulantes. Les titres des panneaux sont posés sur un **ruban rouge** à queues d'aronde, les sections séparées par un filet doré.
- **Textures** en pixels, assorties aux modèles voxel : `tools/ui_texture_generator.py` (Pillow) dessine les cadres, le parchemin, les boutons, les cases d'inventaire et 17 petites icônes (cœur, épée, bouclier, magie, nourriture, or, couronne, crâne, parchemin, maison, habitants, étoile, lune, soleil, gemme, livre, boussole) dans `assets/ui/`.
- **Navigation** : les panneaux s'ouvrent en fondu avec un léger zoom, les pages changent en fondu, les boutons réagissent au survol ; un panneau trop grand pour l'écran est réduit au lieu d'être coupé. Tout se joue aussi à la manette (focus doré).
- **HUD** : plaque du héros encadrée (cœur, étoile d'expérience, épi de blé), jauges serties d'or, attaque / défense / magie en icônes, couronne devant le royaume ; noms de régions et grands messages en calligraphie.
- **Bestiaire illustré** : chaque créature et chaque boss a son **portrait** (rendu de son modèle 3D, vue de trois quarts : `assets/ui/portraits/`, régénérés par `tools/render_portraits.gd`). Les créatures jamais vaincues apparaissent en silhouette avec un « ? ». Un clic sur une carte ouvre sa **fiche sur parchemin** : grand portrait, vie / attaque / défense / victoires, régions, butin, ressources rares, notes du naturaliste et un conseil de combat. Les 9 seigneurs des donjons ont leur section.
- **Succès** : cartes par catégorie avec icône, barre de progression et points.
- Dialogues de l'histoire : portrait du personnage dans un médaillon doré ; inventaire, création du héros, carte du monde, journal, royaume, pause et écran titre suivent le même style.
- **Portraits des personnages** : les 25 personnages de l'histoire (en buste) et les 21 races ont leur portrait (`npc_<id>.png`, `race_<race>.png`, même outil). Le **journal** (J) a un onglet « Personnages » : la galerie de ceux qu'on a rencontrés (silhouettes pour les autres), avec leur titre et où ils en sont. Les portraits apparaissent aussi au recrutement, dans les quêtes et dans la liste des habitants du royaume. Les personnages de l'histoire gardent toujours la même apparence que leur portrait.
- **Blasons** : chaque nation a son écu (hache de la Horde de Karg, feuille de Sylvaë, soleil des Sables, flocon du Givre, flamme des Cendres) dans le panneau de diplomatie.
- **Guide** : une icône par chapitre (boussole, épée, maison, blé, or, habitants, gemme, crâne, bouclier).
- **Inventaire** : la fiche de l'objet survolé montre sa grande image dans une case, son nom aux couleurs de sa rareté, ses effets et sa description.
- **Carte du monde** sur un vieux parchemin (« Terra incognita » tant qu'on n'a pas exploré), dans un cadre doré, avec une rose des vents.
- **Sons d'interface** : un parchemin qu'on déroule à l'ouverture d'un panneau et qu'on roule à la fermeture, une page tournée pour changer d'onglet, un « toc » de bois pour les boutons, un tic très doux au survol.

## Un monde fait de blocs
- **Pas de constructions toutes faites** : le campement de départ n'a que le feu et des meubles posés comme ceux du joueur (établi, râtelier, tonneaux, coffre), qu'on peut casser et ramasser. Les habitants dorment à la belle étoile tant qu'on ne leur a pas bâti de maison.
- **Les constructions du monde sont faites des mêmes blocs que celles du joueur** (comme les villages de Minecraft), et **tout se casse bloc par bloc** en rendant ses blocs :
  - des **maisons abandonnées** et des **ruines** dans chaque région, avec les matériaux du lieu : planches et chaume dans les prairies, rondins en forêt, tuiles et pierre polie au bois enchanté, grès dans le désert, pierre et ardoise en montagne et dans la toundra, marbre noir dans les terres de cendres, et sur pilotis dans les marais et la jungle ;
  - l'**arche de pierre** de chaque entrée de donjon (avec un voile de ténèbres dans l'ouverture) et les **piliers** autour des obélisques.
- Ces constructions ne comptent pas comme pièces du royaume. Ce qui a été cassé le reste après une sauvegarde.
- Les blocs ne sont dessinés qu'autour du héros (environ 150 m), quelques morceaux par image : les grandes constructions apparaissent sans à-coup.

## Catalogue de construction façon Minecraft (493 blocs) et panoplies
- **493 blocs de construction** (dont 46 dalles, 33 escaliers et 12 pentes posables dans 4 sens, 12 murets, 9 barrières et 9 portillons), textures dessinées par le jeu, dans l'onglet **Construction** de l'artisanat, rangés par famille :
  - **Pierres** : 12 pierres (pierre, granite, diorite, andésite, basalte, calcaire, grès, grès rouge, schiste, obsidienne, quartz, prismarine) en pavés, polie, briques, petites briques, sculptée et briques fissurées, plus les pavés moussus (table du tailleur de pierre) ;
  - **Bois** : 9 essences (chêne, bouleau, sapin, acajou, ébène, cerisier, acacia, saule, palmier) en planches, rondins, bois écorcé et parquet. Chaque région a ses arbres : bouleau des prairies et toundras, sapin des forêts et montagnes, acajou et palmier de la jungle, cerisier du bois enchanté, acacia du désert, saule et ébène des marais...
  - **16 couleurs** de laine, de béton, de terre cuite, de terre cuite émaillée et de verre teinté, grâce à **16 teintures** (os : blanc, charbon : noir, baies : rouge, blé : jaune, fibres : vert, lazurite : bleu, et les mélanges : orange, rose, cyan, violet, magenta...) ;
  - **Métaux et gemmes** : blocs de fer, d'or, de cuivre, de bronze, d'acier, d'argent, de mithril, d'orichalque, de charbon, d'os, de diamant, d'émeraude, de rubis, de saphir, d'améthyste, de topaze, de lazurite ;
  - **Nature** : gravier, argile, neige, glace, mousse, motte d'herbe, terre battue, foin, feuillage, citrouille, melon, bibliothèque, pierre lumineuse, lanterne marine, champignons ;
  - **Dalles** (demi-blocs) de toutes les pierres et de tous les bois.
- Ressources : les rochers donnent la pierre de leur région (granite, diorite, andésite, basalte, calcaire, quartz, prismarine) et parfois de la lazurite ; en creusant, du gravier et de l'argile (surtout dans le sable).
- Le mode construction (B) propose les blocs de base et tous ceux que le héros possède. Fabriquer des blocs fait monter le métier de **Bâtisseur**.
- **92 pièces d'armure en panoplies** (onglet **Armures**) : casque, heaume à cornes, plastron, gantelets, jambières et bouclier en cuivre, bronze, os, acier, argent, or, obsidienne, mithril, orichalque et écailles de dragon (Armurier, niveau du matériau), et l'armure de cuir teinte en 8 couleurs (Tailleur). Les modèles prennent la couleur du matériau.

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
- Un monde immense de 1 536 × 1 536 m (plus de 2 km², réglable : nœud **World** > **World Size**) découpé en 144 zones d'environ 128 m (**Zone Size**), chacune avec un nom et un type de région tiré selon le climat (nord froid, sud chaud), l'humidité et l'éloignement du village. Les frontières sont fondues sur une dizaine de mètres (**Region Blend**).
- Le terrain est calculé et affiché par morceaux de 16 m autour du héros (**View Distance**) : seuls les morceaux proches existent en 3D, avec leurs camps de monstres et leurs objets au sol. Un objet ramassé ne revient pas.
- Plus on s'éloigne du village, plus les monstres sont forts : chaque zone a sa fourchette de niveaux (« Loup · Nv 3 ») et des camps d'élite (loup alpha, ogre des cimes, seigneur squelette, dryade corrompue, seigneur démon...).
- Nouveaux monstres : slimes (bleu, acide, de magma), araignée géante, loup de givre, ours des neiges, scorpion géant, salamandre de feu, homme-lézard, harpie, ogre, esprit follet, fée sauvage, dryade corrompue, démons, seigneur squelette.
- **Jungle d'émeraude** (régions chaudes et humides, niveaux 11 à 16) : palmiers, arbres géants à lianes, fougères, roches moussues et pluies fréquentes. Panthères d'ombre (on peut les monter une fois apprivoisées), grenouilles venimeuses, serpents géants, et le Serpent royal en camp d'élite. Au fond de son donjon-temple : **Xochitl, le Serpent à Plumes** (+3 attaque, +1,5 vie/s, +5 % d'expérience). Poissons : gardons, carpes, anguilles.
- **Obélisques** : un par zone. Passe à côté pour l'activer, puis voyage vers n'importe quel obélisque activé depuis la carte. Celui du village est actif dès le départ.
- **Carte** (M) : se dévoile là où tu passes, avec les noms et niveaux des zones découvertes, les obélisques, les entrées de donjon (vertes une fois vaincues) et ton royaume. Molette ou gâchettes : zoom. **Mini-carte** en haut à droite, avec le nom de la zone.
- Un bandeau annonce chaque nouvelle zone (nom, région, niveaux) ; la découverte d'une zone donne de l'expérience.
- Les arbres poussent en quinconce, toujours à au moins 2 m l'un de l'autre : on circule entre les troncs même au cœur des forêts profondes, qui ont aussi leurs clairières.
- Les feuillages et les murs entre la caméra et le héros deviennent transparents.
- Modèles : `tools/voxel_region_props.py` (cactus, sapins enneigés, arbres morts, champignons géants, cerisiers, roseaux, cristaux, roches volcaniques, obélisque, porte de donjon), `tools/voxel_creature_generator.py` (créatures), `tools/regions_database.py` (monstres et régions).

## Un monde immense à explorer
- **Hautes montagnes** : dans les montagnes, la toundra et les volcans, des crêtes montent jusqu'à 35 m au-dessus du sol, en falaises étagées. Chaque zone porte un nom composé (« Pics de Sombreval », « Brasiers de Loupmont »...).
- **Grottes dans les montagnes** : au pied des falaises, des entrées sombres mènent à trois niveaux de cavernes naturelles, de plus en plus profondes. Les murs cachent du fer, puis de l'or et des cristaux, et du mithril tout au fond. À la pioche, on creuse où l'on veut : chaque bloc cassé ouvre un passage et révèle la roche derrière (on peut creuser sans fin). Monstres et coffres à chaque niveau, sortie et descente balisées. Ce qui a été creusé est sauvegardé.
- **Châteaux forts** : une douzaine dans le monde, en blocs comme le reste. Certains sont **abandonnés** : murs écroulés, squelettes et seigneur squelette qui hantent la cour, trésor au donjon. Les autres sont **habités** : une garnison et un seigneur à qui parler.
- **Épaves** : des navires échoués sur les plages, avec un coffre dans la cale (or, perles, gemmes). Un coffre ouvert le reste, même après rechargement.

## Les capitales des nations
Les cinq nations voisines (voir Diplomatie) ont chacune une capitale bâtie dans une de leurs régions, loin du village. Elles sont faites des mêmes blocs que les constructions du joueur (des milliers chacune : on peut les casser, et ce qui est cassé est sauvegardé), à l'échelle de vraies villes de 110 à 140 m de large, et s'inspirent des cités du Seigneur des Anneaux :
- **Hrodgard** (Jarls du Givre), façon Edoras : une colline en paliers ceinte d'une palissade de rondins pointus, trois anneaux de maisons longues au toit de chaume, et le grand hall au toit doré au sommet. 380 habitants.
- **Lothëlia** (Cour de Sylvaë), façon Fondcombe : des terrasses de marbre blanc reliées par une longue rampe, des demeures claires aux toits de tuiles et la maison du seigneur sur la plus haute terrasse. 420 habitants.
- **Qasr-Ammar** (Sultanat des Sables) : de hauts remparts de grès percés de quatre portes, des rues en damier bordées de maisons à toit plat, un grand bazar d'une douzaine d'étals et le palais au dôme doré. 900 habitants.
- **Gor-Karath** (Horde de Karg), façon Isengard : une enceinte noire hérissée de pointes autour d'une tour noire de 40 m à quatre cornes, avec des huttes et des forges. 650 habitants.
- **Minas Cendrys** (Principauté des Cendres), façon Minas Tirith : sept cercles étagés de 4 m chacun, un rempart blanc par cercle avec sa porte alternativement d'un côté puis de l'autre, des rampes entre les niveaux et la tour blanche de la citadelle tout en haut (près de 50 m). On monte à pied de la grande porte jusqu'à la citadelle. 1 200 habitants.

Dans les rues :
- À l'approche, la ville s'anime : une quarantaine de citadins des peuples de la nation flânent dans les rues, des gardes tiennent chaque porte et le souverain attend devant son palais (Jarl, Dame, Sultan, Chef de guerre, Prince). Ils disparaissent quand on s'éloigne, ce qui garde le jeu fluide. Un bandeau annonce la ville, sa population et ses marchands.
- **E** près d'un habitant : il parle (chaque ville a ses répliques).
- **Marchands** : 4 à 13 étals par ville, chacun avec son métier (forgeron, épicier, herboriste, joaillier, maçon, charpentier, tisserand). **E** ouvre sa boutique : on achète son stock et on lui vend tout ce qui a de la valeur. Les prix varient de 20 % selon les relations avec sa nation, et un marchand refuse de commercer en temps de guerre. Le stock acheté ne revient pas tant que la partie tourne.

## L'histoire dans le vrai monde
L'histoire passe maintenant par les capitales, les châteaux, les grottes et les épaves du monde immense (sur un ancien petit monde sans ces lieux, les personnages campent comme avant) :
- **Borin** et la reine **Brunhild** campent à l'entrée d'une grotte au pied des monts de **Hrodgard** ; les araignées en sortent.
- **Liora** vit à **Lothëlia**, près du palais ; **Lysandre** tient boutique au grand bazar de **Qasr-Ammar**.
- Le roi **Edmond** tient sa cour dans un **château habité** lointain ; le repaire de **Morvain** est un **château abandonné** gardé par ses templiers morts-vivants (Maëlle y est enchaînée) ; **Séléné** attend dans une **grotte** toute proche.
- Le **Sanctuaire de l'Éveil** s'ouvre aux portes de **Minas Cendrys**.
- Quatre nouvelles étapes de **visite** : présenter le marteau de Borin au **Jarl de Hrodgard** (+15 de relations, or et fer), demander asile pour la Horde à **Gor-Karath** (refus : −10), consulter les **archives de Lothëlia** (la vérité sur l'Inquisition, +10), puis approcher des sept cercles de **Minas Cendrys**. Il suffit d'entrer dans les murs de la ville ; le suivi indique la distance et la direction.
- Le journal nomme les vrais lieux (« Borin campe à l'entrée d'une grotte, au pied des monts de Hrodgard »), et les perles se trouvent aussi dans les cales des épaves.
- **Quêtes secondaires d'exploration** : Borin (2 coffres au fond des grottes), Lysandre (les coffres de 3 épaves), Aldéric (les trésors de 2 châteaux abandonnés), Séléné (3 coffres de grottes).
- Les sauvegardes retiennent l'étape par son nom : une partie en cours reprend à la même étape, et les nouvelles étapes déjà dépassées sont sautées.
- Test : `tests/test_story_places.gd`.

## Donjons et boss
- Chaque zone (sauf celle du village) a une entrée de donjon. **E** devant l'entrée : on descend dans un donjon généré sous la surface, toujours le même pour une partie donnée : une dizaine de salles reliées par des couloirs, bâties avec les blocs de la région (réglables dans `data/regions/*.tres` > groupe **Donjon** : sol, murs, piliers, couleur des torches et de l'ambiance).
- Les salles sont gardées par les monstres de la région, un peu plus forts qu'à la surface, dont un monstre d'élite. Des coffres contiennent des matériaux, de l'or et parfois un équipement rare. Un portail près de l'entrée permet de remonter.
- Au fond, la salle du boss se ferme derrière toi. Chaque région a son boss, avec ses pouvoirs (**Boss Powers**) toujours annoncés à l'avance :
  - **onde** : un disque rouge se remplit autour du boss, puis une onde de choc frappe tout ce qui est dedans (roule hors du cercle ou esquive au bon moment) ;
  - **pluie** : des projectiles tombent sur toi et autour de toi (chaque point d'impact est marqué au sol) ;
  - **invocation** : il appelle des monstres de sa région ;
  - **charge** : il fonce sur toi.
- Sous la moitié de sa vie, le boss **enrage** : il frappe plus vite, lance ses pouvoirs plus souvent et en enchaîne parfois deux. Sa barre de vie s'affiche en bas de l'écran.
- Les 9 boss : Grondebois le Roi Sanglier (prairie), Tissombre la Reine Araignée (forêt), le Slime Primordial (marais), Ankhar le Scorpion Empereur (désert), Brisemonts Roi des Ogres (montagnes), Givrecroc l'Ours Ancien (toundra), Sylvaëlle la Dryade Mère (bois enchanté), Xochitl le Serpent à Plumes (jungle d'émeraude), Ignarok Seigneur des Cendres (terres de cendres).
- Boss vaincu : trésor (or, lingots, équipements rares), portail de sortie, beaucoup d'expérience, et ton héros **absorbe l'âme du boss** : un bonus permanent propre à chaque boss (**Boss Soul**, par exemple « Prédation du Slime Primordial : +2,5 vie/s »). L'entrée du donjon devient verte sur la carte (« Vaincu »).
- Si tu tombes dans un donjon, tu te réveilles au village comme d'habitude. On ne peut pas construire dans un donjon.

- **Pièges à piques** dans les couloirs : le sol rougit, puis les piques jaillissent (le héros, les habitants et les monstres y perdent de la vie).
- **Le Gardien** : un monstre d'élite plus grand et bien plus résistant garde une salle du milieu (gemme, or, parfois du mithril).
- **Salle secrète** (la plupart des donjons) : un mur fissuré cache un trésor. Une stèle grave l'ordre de trois leviers (◆ ● ▲ ★) ; dans le bon ordre, le mur s'ouvre ; sinon les leviers se remettent en place et blessent le héros. Deux coffres : gemme, or, lingots, mithril, parfois une larme d'esprit.

### Fin de jeu : la Brume
- Quand l'histoire est finie (ou que tous les donjons sont vaincus), **la Brume s'éveille** : les donjons déjà vaincus affichent « Brume : palier N » à leur entrée.
- 10 paliers par donjon, à franchir l'un après l'autre : monstres « brumeux » (+4 niveaux par palier), boss « Écho de Brume », lumière violette. Dès le palier 4, le boss a les 4 pouvoirs.
- Aux paliers 3, 6, 9 et 10 : un **Seigneur de Brume** légendaire (plus grand, plus fort). Son âme donne +3 attaque et +2 défense, une fois par palier de Seigneur (4 âmes au plus).
- Trésors : fragments de Brume, gemmes, larmes d'esprit, orichalque et, sur les Seigneurs, parfois une pièce d'équipement légendaire (Lame de l'Éveil, Lance draconique...).
- Le journal (J) indique le palier le plus haut et le nombre de Seigneurs vaincus. Les paliers sont sauvegardés.

### Fin de partie : paliers du monde, failles et titans
Pour les héros de haut niveau (jusqu'au niveau 1000), le **Portail des Failles** (anneaux violets, près du village ; E) ouvre un panneau :
- **Paliers du monde** (Normal, Difficile, Expert, Maître, puis Tourment I à VII), débloqués aux niveaux 60, 120, 200, 300... 950. Chaque palier donne **+30 niveaux** à tous les monstres du monde, **+50 % d'expérience**, et les monstres laissent tomber du **butin de niveau** (3 % + 0,6 % par palier).
- **Failles** : une arène de cristal hors du monde. Trois vagues de monstres, puis le **Gardien de la Faille**. Les rangs sont **sans limite** (monstres de niveau 10 + 5 × rang) ; vaincre le gardien ouvre le rang suivant et fait tomber 2 objets ou plus (le premier au moins Rare). E au centre de l'arène pour sortir ; mourir dans une faille ramène au village.
- **Titans** : tous les deux ou trois jours (à partir du niveau 30), un titan géant s'éveille quelque part entre 220 et 480 m du village (Ursok, Ignarok, Gromm, Sylvara, Kar'Zeth, Azgaroth). Il est marqué sur la carte (☠), se réveille quand on approche, frappe très fort et a une énorme réserve de vie. Son trésor : 3 objets, dont un **légendaire ou mystique**.

### Butin de niveau (raretés jusqu'à Mystique)
- Les failles, les titans et les monstres des paliers élevés font tomber des pièces d'équipement **générées** : une arme, une armure ou un bijou ordinaire, avec un **niveau d'objet** (celui du monstre, jusqu'à 1000) et une **rareté** : commune, peu commune (« solide »), rare (« de maître »), épique (« de la Faille »), légendaire (« des Titans ») et **mystique** (✦ « de l'Éveil », en rose).
- Les statistiques grandissent avec le niveau d'objet et la rareté (×3 pour un mystique), et chaque rareté ajoute un bonus tiré au sort (0 à 5) : attaque, magie, vie en %, critique, dégâts critiques, vol de vie, recharge, vitesse, régénération, armure, vitesse d'attaque. Les bonus sont affichés dans l'infobulle.
- Ces objets sont sauvegardés par leur identifiant (« base#niveau.rareté.graine ») et ne s'améliorent pas à la forge.

## Recrutement, compagnons et raids
- **Voyageurs** : des campements de voyageurs sont dispersés dans le monde (réglage **Traveler Density** des régions). Leurs races dépendent de la région (**Recruit Races** : nains et ogres en montagne, fées et esprits au bois enchanté, démons et onis dans les cendres...). Chacun a un niveau, un métier où il excelle et un second talent.
- **E** près d'un voyageur : il se présente et dit ce qu'il demande pour rejoindre ton village (des matériaux selon son métier, et de l'or pour les plus expérimentés). Il faut aussi de la place : la population maximale vaut 8 + les lits de tes maisons et dortoirs. Une fois recruté, il part pour ton village où tu peux lui donner un poste.
- **Prisonniers** : chaque donjon retient un prisonnier (dans une petite cage) qui te rejoint sans rien demander.
- **Compagnons d'expédition** : dans la fiche d'un habitant (E près de lui), coche « Compagnon d'expédition » (2 au plus, 3 quand le royaume est une Ville, 4 en Capitale d'empire). Il te suit partout (voyage par obélisque, donjons, réveil au village), défend le héros et progresse avec toi (son niveau suit le tien). Donne-lui de bonnes armes et armures ! Points verts sur la mini-carte.
- **Raids** : de temps en temps (premier raid après 8 minutes, puis toutes les 10 à 14 minutes, réglable dans le nœud **Menaces**), une bande de pillards attaque le village. Le raid est annoncé 45 secondes à l'avance avec sa direction. La bande dépend de ton niveau (gobelins, horde d'orcs, clan des ogres, légion des cendres) et grossit avec le rang de ton royaume.
- Les pillards contournent le décor, s'en prennent aux habitants et au héros, et **cassent les murs construits** qui leur barrent la route : une palissade les retarde. Les **gardes** (habitants au camp d'entraînement) défendent tout le village avec un bonus d'attaque. Points rouges sur la mini-carte.
- Tous les pillards vaincus : butin au feu de camp (or, lingots, cuir, bois) et expérience. Sinon, au bout de 3 min 30, ils repartent en volant un quart de trois de tes piles de ressources. Pas de raid pendant que tu es dans un donjon.

## Compétences de classe et savoir-faire des métiers
- **3 compétences par classe** (39 en tout, `TalentTree.CLASS_SKILLS`), offertes sans point aux niveaux **1, 6 et 15**. Elles se rangent dans la barre en partant de la droite (touches **0**, **9**, **8**) et se retrouvent dans l'arbre (T), onglet **Classe et Pacte**. Quelques exemples :
  - Guerrier : Coup de bouclier, Cri de guerre, Tourbillon d'acier ; Barbare : Rage, Bond fracassant, Séisme ;
  - Paladin : Lumière sacrée, Bouclier divin, Jugement ; Clerc : Prière de soin, Bénédiction, Marteau céleste ;
  - Mage : Projectiles arcaniques, Arc électrique, Pluie de météores ; Cryomancien : Éclats de glace, Prison de glace, Blizzard ;
  - Nécromancien : **Lever les morts** (des squelettes alliés combattent 30 s), Drain de vie, Terreur ;
  - Druide : Ronces, Régénération, Colère de la terre ; Barde : Chant de bravoure (renforce et soigne les alliés), Dissonance, Crescendo ;
  - Rôdeur : Salve, Piège à ronces, Pluie de flèches ; Assassin : Pas de l'ombre, Instinct du tueur, Exécution ;
  - Moine : Paume foudroyante, Méditation, Cent poings ; Chevalier : Charge, Rempart, Percée.
- **Les habitants combattent selon leur classe** (`Villager.CLASS_ROLE`), en plus de leurs coups : clercs, paladins et druides soignent l'allié le plus blessé (héros compris), le barde soigne tout le groupe, mages, cryomanciens (ralentit) et rôdeurs tirent de loin, le nécromancien draine la vie, chevaliers et guerriers sonnent d'un coup de bouclier, le moine repousse, le barbare entre en rage, l'assassin passe dans le dos de sa cible.
- **Savoir-faire du métier du héros** (`Crafts.JOB_SPECIALTY`, affiché à la création) : Cuisinier (repas +40 %), Joaillier (gemmes en cassant la roche), Fermier (récoltes plus généreuses), Pêcheur (poissons qui mordent plus vite), Herboriste (plus de baies), Bûcheron et Mineur (bois et pierre en plus), Alchimiste (potions de soin +50 %).
- Test : `tests/test_class_skills.gd`.

## Carte du royaume, fiches et événements d'expédition
- **Carte du royaume** (U → onglet *Carte*, `scenes/ui/kingdom_map.gd`) : le village vu du ciel, voir la section suivante.
- **Fiche d'un habitant (E)** : carte d'identité (classe en couleur, niveau, humeur en jauge), interrupteur Compagnon, et les postes de travail en cartes à cliquer (couleur de la pièce, places prises, ★ talent ; poste actuel en vert, postes complets grisés).
- **Boutique** : ta bourse en tuile, chaque objet dans une carte avec son icône et son prix en pastille dorée.
- **Quêtes** : la quête sur parchemin avec une icône par type (livraison, chasse, exploration, défense, construction), l'objet demandé en icône (et ce que tu as) ou le portrait du monstre à chasser, la progression en jauge, la récompense en icônes, l'amitié en jauge.
- **Événements d'expédition** (70 % des expéditions, à mi-parcours) : grotte inconnue, voyageur blessé, bête sauvage, tempête, carte au trésor — deux choix chacun dans le panneau des expéditions (risque contre butin, temps en plus...). Sans réponse, le choix prudent est pris au retour. Le voyageur sauvé attend ensuite au feu de camp et rejoint le village sans rien demander. Au retour d'une expédition réussie, 10 % de chances d'une **trouvaille rare** (diamant, rubis, saphir, cristal d'aube, perle, orichalque). Événements et choix sauvegardés.

## Panneaux de gestion repensés
- **Composants communs** (`MenuKit`) : tuiles de chiffres (icône, grande valeur, jauge), jauges (et jauge centrée pour les relations), pastilles colorées (classe, métier, état), cartes, en-têtes de section à icône, barre d'onglets, cartes de conseil avec bouton d'action, icônes d'objets avec leur nombre, petits portraits, messages de liste vide.
- **Royaume (U)** en 5 onglets : *Vue d'ensemble* (habitants, lits, nourriture et bonheur en tuiles avec jauges, progression vers le rang suivant, dépôt de nourriture, 3 conseils « À faire maintenant » avec bouton Construire), *Habitants* (une carte par habitant : portrait, race, niveau, classe et poste en pastilles, humeur en jauge, lit), *Production* (ateliers avec leurs postes occupés, champs et graines en icônes, saison, élevage, commerce), *Familiers* (cartes avec portrait et boutons) et *Quêtes*. En bas : Expéditions, Diplomatie, Bannière.
- **Expéditions** : les 7 missions en cartes cliquables (durée, difficulté en étoiles), la fiche de la mission sur parchemin (classes et métiers conseillés, butin en icônes), l'équipe en 4 places avec portraits, soigneur et protecteur cochés, grande jauge de chance de réussite ; les habitants disponibles sont des cartes à cliquer (✦ : classe conseillée). Les expéditions en route et le dernier retour s'affichent en pastilles.
- **Diplomatie (N)** : or, alliances et guerres en tuiles, une fiche par nation (blason, attitude, jauge de relation centrée, traités signés en pastilles, goût et demande en icônes) ; seules les actions possibles sont des boutons, les traités pas encore accessibles sont des pastilles verrouillées (la raison en info-bulle), la déclaration de guerre est à part.
- **Recrutement** : classe en couleur, caractéristiques en icônes, sa phrase sur parchemin, talents en pastilles, ce qu'il demande en icônes (et ce que tu as), population en jauge. **Portail des Failles** : sections à icône.
- Test : `tests/test_panels.gd` (une capture par écran).

## Spécialisations, expéditions, combat plus net
- **Coups sans élan** (comme dans Minecraft) : frapper ne fait plus avancer le héros tout seul (`Player.lunge_velocity` renvoie zéro) ; on peut marcher en frappant, plus lentement, et seuls les coups reçus font reculer. La roulade et les compétences de charge restent des déplacements voulus.
- **Spécialisations au niveau 30** (`TalentTree.CLASS_SPECS`, 26 voies) : chaque classe choisit une voie parmi deux dans l'arbre (T, onglet Classe et Pacte), sans point. La voie donne un titre (affiché à la place de la classe), un bonus permanent et une compétence ultime rangée dans la barre. « Tout oublier » permet de changer de voie. Ex. : Guerrier → Champion ou Seigneur de guerre, Mage → Archimage ou Pyromancien, Nécromancien → Liche ou Seigneur des os (4 squelettes), Rôdeur → Tireur d'élite ou Maître des bêtes (3 loups), Barde → Ménestrel ou Chantelame, Clerc → Prêtre lumineux ou Inquisiteur...
- **Expéditions des habitants** (panneau du royaume U → Expéditions, `scripts/kingdom/expeditions.gd`) : 7 missions (cueillette, pêche, chasse, mine, escorte de caravane, exploration de ruines, nettoyage d'un repaire), 1 à 4 habitants par expédition, 1 expédition à la fois au Campement, 2 dès le Village, 3 en Ville.
  - La chance de réussite (affichée avant de partir) dépend du niveau, de la classe conseillée et du talent pour les métiers de la mission ; un soigneur et un protecteur dans le groupe aident (indispensables pour le repaire).
  - Pendant la mission, les habitants quittent le village (ils ne travaillent pas, les monstres ne les voient pas) ; au retour : butin dans le sac, bonheur et parfois un niveau ; en cas d'échec, un peu de butin, des blessés et du mécontentement. Expéditions en cours et derniers retours sauvegardés.
- **Équilibrage des 13 classes** (`tools/class_balance.gd`) : attaque sur 60 s contre un groupe et survie (vie, défense, soins, barrières, invocations) estimées du niveau 1 à 100 ; les classes sont ramenées entre ~80 et ~120 % de la médiane (avant : de 54 à 180 %). Assassin, Barde, Mage, Clerc et Rôdeur renforcés, Druide et Nécromancien (squelettes 20 s) adoucis.
- Test : `tests/test_expeditions.gd`.

## Classes et métiers des habitants
- Chaque habitant, voyageur, prisonnier ou citadin a une **classe de combat** (les 13 classes du héros, `Villager.CLASS_IDS`), le plus souvent liée à son métier (un garde est guerrier, chevalier, paladin ou barbare ; un mage est mage, cryomancien ou nécromancien ; un chasseur est rôdeur...). Elle donne ses bonus (vie, attaque, défense, magie) et sa **tenue de départ** : les voyageurs et les premiers habitants portent l'équipement de leur classe.
- La classe s'affiche sur l'étiquette des voyageurs, dans la fiche de recrutement, dans la fiche de l'habitant et dans le panneau du royaume ; elle est sauvegardée.
- **5 nouveaux métiers d'habitants**, avec leur pièce :
  - **Pavillon de chasse** (râtelier, billot, table) : 2 chasseurs rapportent cuir, viande et crocs ;
  - **Cabane de pêche** (tonneau, étal, barrière) : 2 pêcheurs ramènent truites, carpes, gardons, saumons ;
  - **Carrière** (meule, râtelier, coffre) : 2 mineurs extraient pierre, fer, pierre brute et un peu d'or ;
  - **Cuisine** (four à pain, chaudron, table) : 2 cuisiniers préparent soupes, ragoûts, omelettes et viande cuite ;
  - **Joaillerie** (établi, bougeoir, coffre) : 1 joaillier taille des gemmes (améthyste, topaze, émeraude, perles) et de l'or.
- En progressant (voir Artisans), ils produisent aussi des prises rares, du cuivre et de l'étain, des gâteaux ou des rubis et diamants. Nouvelles affinités : nains mineurs et joailliers, orcs et lycans chasseurs, hommes-lézards et harpies pêcheurs, humains et slimes cuisiniers, gobelins joailliers. Les voyageurs de ces métiers demandent leurs propres matériaux pour te rejoindre.
- Test : `tests/test_classes.gd`.

## Métiers avancés
- **Laboratoire d'alchimie** (chaudron, table, tonneau) : 2 alchimistes préparent des potions. **Z** : boire une potion (soin si le héros est blessé, sinon une potion de renfort : force +25 % d'attaque, garde +8 défense, célérité +20 % de vitesse, 90 s). La potion de soin se fabrique aussi au chaudron (8 baies) et soigne les malades d'une épidémie.
- **Sanctuaire des runes** (autel, 2 bougeoirs, bibliothèque) : 2 enchanteurs gravent des runes (force, garde, vie, célérité). À l'enclume (onglet Forge), une rune se grave sur une arme ou une armure (une par objet, remplaçable). Héros : +5 % de magie.
- **Ménagerie** (mangeoire, auge, 2 barrières) : 2 dresseurs entraînent les familiers qui vivent au village (une victoire par minute et par dresseur), les familiers K.O. reviennent 2 fois plus vite, et on peut en avoir 2 de plus.
- **Bureau d'architecte** (pupitre, table, bibliothèque) : 2 architectes taillent des blocs de construction (pierre polie, planches, tuiles, verre, briques).
- Nouvelles affinités : les nains et les humains font de bons architectes, les elfes, fées, dryades et vampires de bons alchimistes, les démons, esprits et anges de bons enchanteurs, les lycans, hommes-bêtes et gobelins de bons dresseurs.

## Événements du monde
- Tous les 3 ou 4 jours (à partir du jour 3), un événement frappe le royaume, annoncé par un bandeau et suivi en haut de l'écran et dans le journal (J) :
  - **Pluie d'étoiles** : 4 éclats lumineux tombent autour du village (mithril, cristal d'aube, gemmes, parfois de l'orichalque).
  - **Invasion de la Brume** : une horde brumeuse attaque le village ; repoussée, elle laisse fragments de Brume, gemme et or.
  - **Grand tournoi** : trois champions t'attendent près du feu de camp, l'un après l'autre. Victoire : or, gemme, lingots et +1 attaque.
  - **Fête du royaume** : habitants plus heureux (+15) et visite du marchand.
  - **Épidémie** : des habitants tombent malades (-20 bonheur) ; soigne-les dans le panneau du royaume (U), une soupe de légumes ou une potion de soin chacun.
- Un événement dure jusqu'à la fin du lendemain, ou jusqu'à ce qu'il soit réglé.

## Succès et bestiaire (touche H)
- **116 succès** en 11 catégories : combat (victoires, 25 de chaque monstre), boss (les 9 boss), héros (niveaux, évolution, or), royaume (habitants, rangs), histoire (16 actes, quêtes des personnages), familiers, forge (renforcement, gemmes, runes), Brume, diplomatie (traités, capitulation, provinces), événements du monde, exploration (salles secrètes, Gardiens, obélisques, bestiaire complet).
- Chaque succès rapporte des points. **Titres** (affichés à côté du nom du héros) : Aventurier (50 points), Héros du royaume (150), Légende vivante (300), Mythe éternel (500), et des titres de succès (Tueur de boss, Empereur, Maître de la Brume, Dompteur, Cartographe, Naturaliste...). **Auras** (lumière et étincelles autour du héros) bleue, dorée et violette à 150, 300 et 500 points. Titre et aura se choisissent dans le panneau.
- **Bestiaire illustré** : les 27 monstres du monde et les 9 seigneurs des donjons, chacun avec son portrait (silhouette tant qu'il n'est pas vaincu) et sa fiche sur parchemin : victoires, vie, attaque, défense, régions, butin, ressources rares (avec leurs chances), notes du naturaliste et conseil de combat.
- Panneau : touche F1, ou « Succès et bestiaire » dans le menu pause. Tout est sauvegardé.

## Bannière et trophées
- Panneau du royaume (U) → **Bannière et trophées** : choisis le **nom du royaume** (affiché partout à la place du rang), ses **deux couleurs** (pourpre, azur, sinople, or, argent, sable, orangé, violet) et son **emblème** (couronne, étoile, épées, soleil, lune, fleur, tour, croix, cavalier, flocon).
- Quatre **étendards** aux couleurs du royaume flottent autour du village ; on peut en poser d'autres (Artisanat → Mobilier → Étendard : 3 bois et 2 laines, près d'un établi). Ils changent dès qu'on modifie la bannière.
- **L'allée des trophées** : chaque boss de donjon vaincu laisse une statue de pierre (sur un piédestal, avec son nom) autour du feu de camp.

## Diplomatie (touche N)
- Cinq nations voisines : **Horde de Karg** (orcs), **Cour de Sylvaë** (fées et dryades), **Sultanat des Sables** (hommes-lézards), **Jarls du Givre** (clans du nord), **Principauté des Cendres** (démons). Chacune a une relation de -100 à +100 et un caractère vers lequel elle revient peu à peu.
- **Présents** (50 or, ou ce que la nation aime, une fois par jour) et **demandes** remplies (de l'or en échange) font monter la relation.
- **Traités** : paix (relation 0 : elle ne te déclarera jamais la guerre), commerce (20 : une caravane tous les 3 jours et de meilleurs prix chez le marchand), alliance (60, avec paix et commerce : un présent rare tous les 5 jours et un pillard de moins par raid).
- **Guerre** : une nation hostile (-40 ou moins, sans paix) peut te la déclarer, ou tu la déclares toi-même (les autres nations n'aiment pas ça). Ses armées attaquent alors le village. Repousse-en 3 : elle capitule, signe la paix et paie un tribut. On peut aussi acheter la paix.
- Panneau : touche Y, ou bouton « Diplomatie » du panneau du royaume (U).
- **Conquête** : en guerre, à partir du niveau 6, le bouton « Assiéger la capitale » emmène le héros (et ses compagnons) **devant la grande porte de la vraie capitale**. Les habitants se barricadent, trois vagues de soldats sortent par la porte, puis le souverain (Gor, Chef de guerre de Karg ; Dame Lothaël ; le Sultan Ssarak-Ammar ; le Jarl Hrothgar ; Azhar, Prince des Cendres) attend devant son palais : il faut traverser la ville pour l'affronter (à Minas Cendrys, monter les sept cercles). S'éloigner de la ville lève le siège. Sur un monde sans capitale, le siège se joue dans une place forte souterraine, comme avant.
- En guerre, des **soldats hostiles gardent les portes** de la capitale ennemie, et ses marchands refusent de commercer.
- Souverain vaincu : la nation devient une **province**. Sa capitale arbore **ta bannière** (couleurs et emblème du royaume) aux portes et devant le palais, un **gouverneur** la dirige, ses marchands te font -25 % (et rachètent 25 % plus cher), et le **trésor de la capitale** attend devant le palais. La province donne aussi +2 attaque et +2 défense au héros, des impôts tous les 2 jours et un colon de sa race tous les 5 jours. Avec 3 provinces, ton royaume devient un **Empire**.

## Villes vivantes, routes et hameaux
- **Maisons meublées** : autour du héros, les maisons des capitales ont leurs lits, tables, chaises, tonneaux, coffres et lanternes (seules les plus proches sont meublées, pour garder le jeu fluide).
- **Le jour et la nuit** : la nuit, le marché ferme, les rues se vident (une dizaine de passants), des torches s'allument le long des rues et des lanternes dans les maisons.
- **Une taverne par ville** (« Le Sanglier d'or », « Le Dragon assoupi »...) : **E** auprès de l'aubergiste, le jour un repas chaud (5 or : faim rassasiée, un peu de vie), la nuit une chambre (12 or : on dort jusqu'au matin, repu).
- **Quêtes des citadins** : dans chaque ville, deux citadins ont une demande (« ! ») : apporter ce que leur nation recherche, ou abattre des monstres autour de la ville. « ? » : c'est fait, la récompense (or, expérience, amitié avec la nation) t'attend. Une nouvelle demande le lendemain.
- **Marchands** : leur stock est sauvegardé (ce qu'on a acheté ne revient pas) et se renouvelle chaque semaine.
- **Routes pavées** : des routes relient ton village aux cinq capitales (plus de 2 km en tout). Elles évitent les pentes trop raides, sont lissées pour qu'on y marche partout et franchissent les rivières sur des ponts de planches.
- **Hameaux** au bord des routes : quelques maisons en blocs autour d'une place, des villageois, un **colporteur** (épicier, herboriste ou charpentier) et un **chef** qui a souvent une quête. Ils apparaissent sur la carte et la mini-carte.
- **Rencontres sur les routes** : on croise des **caravanes** (un marchand et ses gardes : E pour commercer), des **patrouilles** de la nation voisine, ou on tombe dans une **embuscade de bandits** (des bandits et leur chef, plus fréquente la nuit).
- La **mini-carte** montre aussi les capitales (leur nom et leur enceinte), les châteaux, les hameaux et les épaves.

## Explorer : voilier, cités englouties, griffon, souterrains des capitales
- **Voilier** (établi : 30 planches, 8 rondins, 12 laines, 4 lingots de fer) : choisis-le (C) et appuie sur V face à l'eau. Il file **deux fois plus vite** que la barque, sa voile se gonfle quand il avance et il tangue sur les vagues. E pour monter, E près d'une berge pour débarquer.
- **Cités englouties** : cinq ruines au fond de la mer (Ys la Noyée, Thalassor, Atlantée...), un dallage de marbre, des colonnes brisées qui affleurent et un temple au centre. Une bouée et son nom flottent à la surface. Plonge (Creuser) jusqu'au **trésor englouti** : or, perles, gemmes, parfois de l'orichalque ou un cristal d'aube. Elles sont sur la carte ; `/tp cité engloutie`.
- **Griffon** (fin de partie) : Vharok t'offre le **sifflet du griffon** avec l'héritage des dragons (les parties qui ont déjà passé cette étape le reçoivent automatiquement). Choisis le sifflet (C), puis V : le griffon se pose devant toi. **E** pour monter ; en vol, **Saut** pour monter, **Creuser** pour descendre, et 1,6 fois plus vite qu'à pied en vol. **E** pour se poser (pas sur l'eau). Il t'attend là où tu l'as laissé, même après une sauvegarde.
- **Souterrains des capitales** : un escalier sous une arche de pierre, près du palais de chaque capitale. On y trouve les Catacombes des Jarls, les Cryptes de Lothëlia, les Égouts de Qasr-Ammar, les Fosses de Gor-Karath et les Catacombes de Minas Cendrys. Trois niveaux de salles et de couloirs de briques (on peut creuser les murs) :
  - les cryptes sont peuplées de squelettes et d'esprits, les égouts de slimes, d'araignées et de bandits ;
  - les coffres sont plus riches (lingots d'or, orichalque au fond) ;
  - au troisième niveau, un **gardien** (Gardien des tombeaux, Roi des égouts) veille.
  - `/tp catacombes` mène à l'entrée la plus proche.
- Test : `tests/test_explore.gd`.

## Un monde qui vit sans toi
Les cinq nations vivent leur vie (voir `scripts/world/world_politics.gd`) :
- **Guerres entre nations** : de temps en temps, une nation en attaque une autre. Son **armée marche sur les routes pavées** d'une capitale à l'autre, bannière en tête ; quand le héros passe à moins de 140 m, ses soldats apparaissent sur la route. En chemin, elle prend les **hameaux** de l'ennemi, qui **changent de camp** (nouvelle bannière sur la carte et dans le hameau, nouveaux habitants). Devant la capitale ennemie, elle est repoussée ou pille les faubourgs (la ville paie tribut). Si tu es toi-même en guerre contre cette nation, ses soldats t'attaquent, et mettre l'armée en déroute rapporte or, expérience et l'estime de ses ennemis.
- **Économie** : chaque capitale a ses réserves d'armes, de vivres, de bijoux et de matériaux. La guerre vide les arsenaux et les greniers, les caravanes de capitale en capitale les remplissent, et les bandits en pillent parfois. Les **prix des marchands suivent** : jusqu'à +50 % en pénurie, −35 % en abondance ; le marchand l'annonce (« pénurie d'armes (+36 %) »).
- **Événements de saison**, dans une capitale en paix avec toi :
  - **Printemps — Foire** : les marchands de la ville baissent leurs prix (−20 %) et rachètent plus cher.
  - **Été — Grand tournoi** : une lice devant la grande porte, trois champions de la nation à vaincre (250 or, une gemme, +10 de relations).
  - **Automne — Foire des moissons** : les vivres sont bon marché partout.
  - **Hiver — Invasion des morts** : les morts-vivants sortent d'un château abandonné et marchent sur le hameau le plus proche. Arrête-les avant qu'ils ne le ravagent (sinon, ses habitants fuient trois jours).
- Les **nouvelles du monde** s'affichent à l'écran, et les dernières en bas du panneau de la diplomatie (N). La **carte** montre les armées en marche (et leur chemin), la bannière des hameaux, les hameaux ravagés et l'événement en cours.
- Terminal : `/monde` (guerres, armées, prix, nouvelles), `/guerre karg givre`, `/evenement tournoi`.
- Tout est sauvegardé (guerres, armées, réserves, hameaux, événement, nouvelles). Test : `tests/test_world_life.gd`.

## Terminal de commandes (Entrée ou /)
- Le texte du terminal **défile** : molette de la souris, ou Page ↑ / Page ↓ depuis la ligne de commande. Une longue réponse (/aide, /competences...) garde le terminal ouvert, au début de la réponse ; Échap le ferme.
Comme dans Minecraft, **Entrée** (ou **/**) ouvre une ligne de commande en bas à gauche. Le jeu continue pendant qu'on écrit ; la ligne se ferme après chaque commande et les réponses restent affichées quelques secondes. **Échap** referme, **↑ / ↓** rappellent les commandes précédentes, **Tab** complète le nom d'une commande. Les accents sont facultatifs.

| Commande | Effet |
|---|---|
| `/aide` | la liste des commandes |
| `/carte` | dévoile toute la carte (en une dizaine de secondes, sans figer le jeu) : zones, capitales, châteaux, épaves, grottes |
| `/lieux` | les capitales et les châteaux, avec leurs coordonnées |
| `/tp <x> <z>` | téléporte à des coordonnées |
| `/tp <lieu>` | téléporte devant une capitale (`/tp minas`, `/tp hrodgard`...), dans une zone par son nom, ou au plus proche : `village`, `château` (`château abandonné`, `château habité`), `épave`, `grotte`, `donjon` |
| `/pos` | ta position et ta zone |
| `/donner <objet> [nombre]` | un objet par son identifiant ou son nom (`/donner épée en fer`, `/donner mithril 20`) |
| `/or <nombre>` | des pièces d'or |
| `/soin` | vie et faim au maximum |
| `/dieu` | invincible (encore une fois pour arrêter) |
| `/vitesse <x>` | vitesse de marche multipliée (1 = normale, jusqu'à 10) |
| `/niveau <n>` | monte jusqu'au niveau n |
| `/heure <0-24>`, `/meteo <clair, nuageux, pluie, orage, brouillard>` | l'heure et le temps |
| `/obelisques` | active tous les obélisques (voyage rapide partout depuis la carte) |
| `/tuer` | terrasse les monstres à moins de 30 m |
| `/vol` | voler au-dessus du monde, à travers tout (Saut : monter, Creuser : descendre) ; encore une fois pour atterrir |
| `/kit` | un équipement complet en mithril, des outils, des potions, à manger et des blocs |
| `/invoquer <monstre> [nombre]` | fait apparaître des monstres devant toi (`/invoquer loup 3`, `/invoquer chef des bandits`) |
| `/graine` | la graine du monde |
| `/metier <métier|tous> <niveau>` | met un métier (ou tous) à ce niveau |
| `/palier <0-10>` | change le palier du monde (monte le héros au niveau requis si besoin) |
| `/faille <rang>` | ouvre les failles jusqu'à ce rang et y entre |
| `/titan` | éveille un titan devant toi |
| `/butin <niveau> [rareté 0-5]` | crée un objet de butin (5 : mystique) |

La carte montre maintenant les **capitales** (avec leur enceinte et leur population), les **châteaux** (gris : abandonnés), les **épaves** et, en zoomant, les **entrées de grottes**. Sur le monde immense, les noms des zones apparaissent en zoomant.

## Accessibilité et langues
- **Options → Langue** : français (par défaut) ou anglais. Les menus, boutons et listes se traduisent tout seuls ; le reste du texte du jeu passera progressivement par `I18n.t("texte")` (voir `scripts/ui/i18n.gd` : pour une autre langue, ajoute un dictionnaire dans `LANGS`).
- **Options → Filtre pour daltoniens** : protanopie, deutéranopie ou tritanopie (corrige les couleurs de toute l'image, interface comprise).
- **Options → Mouvement réduit** : presque plus de secousses de caméra, pas d'arrêt sur image, ralentis adoucis et plus courts.
- **Taille de l'interface** de 80 % à 130 %.
- **Menus débloqués au fil de la partie** (départ à mains nues, option désactivable) : les talents (T) s'ouvrent au niveau 2, le royaume (U) dès qu'on a un abri ou un habitant. Un message annonce chaque nouveau menu.
- **Tutoriel en deux temps** : 14 étapes de base (LES BASES et PREMIERS PAS), puis des **défis** facultatifs (fer, village, champs, commerce...).
- Test : `tests/run_tests.sh access unlocks`.

## Défense du camp et bête rôdeuse
- Les raids suivent la taille du royaume. Ce qu'on bâtit les affaiblit : **1 point de défense** par 10 murets, barrières ou portillons autour du camp (6 au plus), par 8 tours ou remparts de pierre (colonnes de 3 blocs ou plus, 6 au plus), par 6 torches ou lanternes (3 au plus), et **2 points par garde** (caserne, 10 au plus). **3 points = 1 pillard en moins**, 3 secondes d'alerte de plus par point, et des gardes plus forts. Le panneau du royaume (U) conseille de renforcer le camp quand la menace dépasse deux fois la défense. Code : `scripts/kingdom/camp_defense.gd`.
- Nouvel événement du royaume, **Bête rôdeuse** : un grand monstre apparaît à 60-90 m du camp. Le bandeau en haut de l'écran donne sa distance et sa direction. L'abattre rapporte de l'or, du cuir, de la viande et de l'expérience ; au bout de deux jours, elle disparaît. Pousse le héros à quitter le village.
- Test : `tests/run_tests.sh defense`.

## Défis des donjons
- Un donjon vaincu peut être refait en **défi** (étiquette de l'entrée : « Défi N »). Le boss et ses gardiens gagnent 2 niveaux par défi, et des **modificateurs** s'ajoutent : rapides, robustes, enragés, explosifs, nombreux (1 dès le défi 1, 2 dès le 4, 3 dès le 8 ; toujours les mêmes pour un donjon et un défi donnés).
- Chaque modificateur ajoute un objet rare au coffre du boss ; le défi ajoute de l'or et de l'expérience. Le défi monte à chaque victoire (12 au plus, sauvegardé).
- Les paliers de la Brume ont aussi des modificateurs (1 dès le palier 2, 2 dès le palier 4).
- Test : `tests/run_tests.sh challenge`.

## Trappes et fenêtres
- **Trappes** (une par bois) : fermées, on marche dessus ; ouvertes avec **E**, on passe. **Vitres** (verre et 16 teintes) : fines, elles se raccordent entre elles et aux murs pleins. Dans le sac : Construction → Trappes et fenêtres. Test : `tests/run_tests.sh panes`.

## Difficulté
- En plus de la vie, des dégâts et de la fréquence des raids, la difficulté règle l'**agressivité** : Facile = attaques 25 % plus espacées et monstres 8 % plus lents ; Difficile = attaques 20 % plus rapprochées et monstres 8 % plus rapides.

## Sauvegarde, menus et options
- **Démarrage** : l'écran titre utilise un petit monde de décor (il s'affiche en quelques secondes).
- **Écran de chargement**, façon Minecraft : fond de blocs de terre, étape en cours (« Fondation de Hrodgard... », « Tracé des routes... », « Châteaux, ruines et épaves... »), barre de progression verte avec son pourcentage et une astuce. Le monde se calcule dans un autre fil (`WorldGenerator.generate_data`) : l'écran reste vivant du début à la fin, plus d'écran noir ni figé (test `tests/test_boot.gd` : l'écran se redessine des centaines de fois et la barre avance par étapes).
- Les parties d'avant le monde immense se rechargent dans leur monde d'origine (640 × 640 m), village et constructions compris ; une nouvelle partie crée le monde immense.
- **3 emplacements de sauvegarde** et une **sauvegarde automatique** toutes les 5 minutes (désactivable). Menu pause > Sauvegarder ; écran titre > Continuer (la plus récente) ou Charger. Chaque emplacement affiche le héros, son niveau, le rang du royaume, la zone, le temps de jeu et la date.
- Ce qui est sauvegardé : le héros (apparence, classe, métier, compétence, niveau, expérience, vie, sac, équipement, âmes de boss), le monde (graine, terrassement, décors récoltés, carte dévoilée, zones découvertes, obélisques activés, donjons vaincus, objets ramassés, voyageurs recrutés), toutes les constructions (blocs et meubles : les pièces sont reconnues à nouveau), les habitants (race, nom, talents, niveau, équipement, poste de travail, compagnons) et le temps avant le prochain raid. Sauvegarder dans un donjon te fera reprendre devant son entrée.
- Les fichiers sont dans le dossier utilisateur de Godot (`user://saves/partie_1.json`... ; sous Windows : `%APPDATA%\Godot\app_userdata\L'Éveil du Royaume\saves`).
- **Options** (écran titre ou pause, enregistrées dans `user://options.cfg`) : difficulté, distance de la caméra, volume, plein écran, rappel du menu des commandes à l'écran, sauvegarde automatique.
- **Difficulté** : Facile (monstres −25 % de vie et −30 % de dégâts, raids 40 % plus espacés), Normal, Difficile (monstres +35 % de vie et de dégâts, raids 25 % plus fréquents). Les valeurs sont dans `scripts/save/save_game.gd` (ENEMY_HP, ENEMY_DMG, RAID_DELAY).
- **Équilibrage** : à niveau égal avec l'équipement de sa tranche de niveau, un monstre normal tombe en 3 à 7 coups et le héros encaisse 12 à 25 coups ; un boss demande 35 à 75 coups et le héros tombe en 7 à 9 de ses coups (ils sont tous annoncés : esquive-les !).

## Confort et options
- **Touches configurables** : menu pause → Commandes → onglet **Personnaliser** : clique sur une touche puis appuie sur la nouvelle (Échap : annuler). Les conflits sont signalés ; « Touches par défaut » remet tout comme au départ. La souris et la manette gardent leurs boutons. Les touches choisies sont gardées dans `user://options.cfg` et s'affichent partout (onglets des commandes, aide-mémoire).
- **Aide-mémoire** (F1) : un petit cadre à gauche de l'écran avec les touches principales.
- **Qualité graphique** (Options) : basse, moyenne ou haute (ombres, distance d'affichage du monde, petite végétation au loin). **Images par seconde** : à afficher en haut à gauche.
- Les **sauvegardes des anciennes versions** se chargent toujours : ce qui n'existait pas encore (diplomatie, succès, bannière...) démarre avec ses valeurs par défaut (test `tests/test_compat.gd` avec une vraie sauvegarde d'une version d'avant la forge).

## Carte du royaume détaillée
U → onglet *Carte* (`scenes/ui/kingdom_map.gd`, `kingdom_panel.gd::_page_map`).
- **Le vrai terrain** : chaque case dans la couleur de son sol et de sa région (herbe, sable, roche, eau, place, terre, champs), avec un **relief ombré** (pentes éclairées depuis le nord-ouest, hauteurs plus claires).
- **Décor** : arbres (chênes, sapins) avec leur ombre, buissons, rochers, fleurs, **filons de fer et d'or**.
- **Constructions** : le bloc du dessus de chaque colonne dans la couleur de sa texture, avec une ombre portée ; au zoom, l'icône de chaque meuble.
- **Pièces** : contour net, nom et postes occupés (ex. *Forge 1/2*) dans une étiquette ; les pièces à finir en gris avec « ? ». **Clic sur une pièce** : panneau de détails à droite (effet, ouvriers avec portraits, places libres, production, lits ; pour une pièce à finir, la pièce qu'elle est presque et les **meubles manquants en icônes**). Sans sélection, le panneau liste toutes tes pièces (clic = centrer dessus).
- **Plans** en hachures dorées, **feu de camp** lumineux, **habitants** (couleur de leur classe, anneau vert au travail, prénom au zoom ; clic = fiche), **héros** en flèche dorée.
- **Navigation** : molette (zoom vers le curseur), glisser pour se déplacer, boutons − / + / ⌖ (recadrer sur le village). **Rose des vents**, **échelle en mètres**, légende et info-bulle de survol pour tout (meuble, arbre, filon, eau, champ, plan...).
- Test : `tests/run_tests.sh panels` (captures `pn_02_carte.png` et `pn_03_carte_zoom.png`).

## Effets spéciaux des attaques et des compétences
Chaque attaque est reconnaissable à sa forme, à sa couleur et à sa façon d'exploser. Plus une compétence est rare, plus son effet est grand, lumineux et détaillé (`HeroSkill.grade()` : 0 pour une commune, 4 pour une mystique ; la compétence unique de l'histoire suit son rang).

**Moteur** (`scripts/combat/voxel_burst.gd`, `scripts/combat/skill_fx.gd`, shaders `fx_glow_add` / `fx_glow_mix`) :
- **Particules** :
  - palettes de couleurs : un éclat clair, la couleur, une teinte sombre ;
  - **éclat lumineux** : la couleur dépasse 1 et brille avec le halo de l'image ;
  - **étincelles étirées** dans le sens de leur course, **fumée** qui gonfle ;
  - modes cône, disque, colonne, coquille et **implosion en spirale**.
- **Garde-fou** : un budget de cubes à l'écran allège les gerbes quand il y en a trop.
- Nouveaux effets :
  - **explosion** en couches : éclair, boule de feu, étincelles, onde au sol, fumée, débris, brûlure ;
  - **éclair** zigzag avec ramifications, qui crépite ;
  - **entaille** en croissant ; **cercle de runes** tournant ; **étoile d'impact** ;
  - **lumière** qui éclaire le décor (au plus 6 à la fois) ;
  - **traînées** derrière les projectiles et les météores ;
  - **filets de lumière** d'un point à un personnage (vol de vie, soins).

**Attaques de base** :
- **Traînée de l'arme** : un **ruban de lumière** de la garde à la pointe, dans la couleur de la rareté de l'arme, d'où s'échappent des étincelles.
- **Entaille** lumineuse à chaque coup du héros et des boss : inclinée en alternance dans le combo, un cercle complet pour le tourbillon, plus large pour les coups lourds.
- **Impact** à chaque coup reçu : éclat et étincelles dans le sens du coup. Les **critiques** et les gros coups ajoutent une **étoile de lumière**, une onde et une lumière.
- **Coups bloqués et parades** : gerbes d'étincelles. Une parade est dorée, avec étoile, anneau et lumière.
- **Onde au sol** des coups lourds : poussière, fumée, anneau.
- Les tirs de **bâton** ont un halo, une traînée et un éclat à l'impact ; les **flèches**, une fine traînée.

**Compétences** :
- **Geste de lancement** : cercle de runes sous le héros et gerbe à ses mains. Dès légendaire, une colonne de lumière et un éclair d'écran.
- Chaque genre a sa signature :

  | Compétence | Effet |
  |---|---|
  | Nova | explosion d'énergie, éclairs qui courent au sol jusqu'au bord |
  | Météores | runes au point d'impact, boule de feu à traînée de flammes et de fumée, explosion et brûlure |
  | Éclair en chaîne | vrais éclairs ramifiés d'ennemi en ennemi |
  | Souffle | jet de flammes en trois couches |
  | Tourbillon | aspiration en spirale puis explosion |
  | Exécution | tranche en croix (et explosion si elle achève) |
  | Ruée et transfert | trait de lumière sur le trajet |
  | Soin | runes et colonne de lumières |
  | Vol de vie | filets de lumière des ennemis vers le héros |
  | Étourdissement | étoiles qui tournent au-dessus des sonnés |
  | Zones | bulles, flocons ou flammes tant qu'elles durent |
  | Invocation | la tombe s'ouvre |
  | Effroi | vague d'ombre |

- **Ultimes mystiques** : le temps ralentit, l'énergie est aspirée vers le héros, un immense cercle de runes s'ouvre, une couronne de huit colonnes de lumière s'élève, puis la frappe tombe.
  - La foudre tombe en vrais éclairs ; les lames sont de vraies épées géantes (garde, poignée, pommeau).
  - Chaque impact est une explosion complète.
- **Cataclysme** : tout le décor est aspiré en silence, puis une couronne de douze explosions s'éloigne du centre avant que le cratère se creuse.

Test : `tests/run_tests.sh effects` lance une vitrine de 14 effets et vérifie que tout se nettoie (plus aucun cube ni lumière) :
- coup d'épée, tourbillon, critique ;
- nova commune et légendaire, éclair en chaîne, souffle, comète, tempête de lames, soin, exécution, salve ;
- la mystique « Mille Soleils d'Acier » et le Cataclysme.

Les captures sont `fx_XX_*.png`.

## Visée à la souris (comme dans Minecraft)
C'est la souris qui décide **où l'on frappe, ce que l'on récolte ou casse, et où l'on pose un bloc**, plus la direction du héros (`scripts/combat/aim.gd`, `Player._update_aim`).
- **3e et 1re personne** : le **viseur** au centre de l'écran.
- **Vue de dessus** : le **curseur** de la souris ; il suffit de cliquer sur un ennemi pour le frapper.

**Le rayon de visée** part de la caméra, à chaque image :
- Il s'arrête sur la première chose touchée : un ennemi, un bloc ou un meuble posé, un arbre, un rocher, un buisson, un filon, une plante, un décor du village, une culture mûre, ou le sol.
- Il avance case par case le long du rayon et teste ce qui s'y trouve. Le sol en marches est compté à sa vraie hauteur, ainsi que les demi-blocs et les escaliers.

**Ce qui en dépend** :
- **Frapper, lancer un sort, tirer** : le héros se tourne vers le point visé, ou vers l'ennemi visé. Ce n'est plus le héros qui choisit sa cible.
- **Récolter, casser** :
  - Seul ce qui est sous le viseur est touché, à moins de 3,2 m.
  - Un viseur dans le vide ne casse rien, même s'il y a un arbre juste à côté.
  - La pelle (G) creuse la case du sol visée.
- **Poser** (clic droit) :
  - Contre la face visée d'un bloc ; sur le sol visé, ou à côté si c'est le flanc d'une marche ; ou sur le dessus d'un meuble.
  - Jusqu'à 5,5 m, jamais dans le corps du héros.
  - Le cube fantôme (vert : possible, rouge : impossible) montre exactement où.
  - Graines et houe : la case de sol visée.
- **Repères à l'écran** :
  - Le viseur devient rouge sur un ennemi à portée, doré sur ce qui se récolte ou se casse.
  - Un **contour** entoure le bloc, l'arbre ou le décor visé.

**À la manette, ou tant que la souris n'a pas bougé**, le héros frappe et pose devant lui comme avant.

Test : `tests/run_tests.sh aim`. Il vérifie :
- en 1re personne : le bloc visé et sa face, la pose contre cette face au clic droit, l'arbre visé récolté, rien de touché en visant le ciel, et le héros qui se tourne vers un ennemi visé sur le côté ;
- en vue de dessus : le curseur posé sur un ennemi qui le vise.

## Interface épurée : on voit le monde
L'interface prenait trop de place : la double barre du bas occupait **30 % de la hauteur de l'écran** et restait affichée par-dessus les menus. Elle est maintenant **compacte et discrète**.
- **Tout est plus petit** : le jeu est conçu pour 1280×720 (et non plus 960×540, agrandi). Toute l'interface s'affiche aux trois quarts de son ancienne taille, à résolution égale.
- **Option « Taille de l'interface »** (Options) : de 80 % à 130 %, pour plus de monde ou plus de lisibilité. C'est `content_scale_factor` de la fenêtre.
- **Barre du bas compacte** : une seule rangée de cases plus petites (sorts 1 … 0 et compétence unique), sans étiquettes. Elle fait **5 % de la hauteur de l'écran**. Le nom de la compétence unique s'affiche au survol.
- **La rangée de construction** n'apparaît qu'**avec un objet en main** (`C`, Ctrl + chiffre ou la molette), ou un court instant après avoir ramassé quelque chose.
- **Sous les menus, plus rien d'autre** : barres, mini-carte, guide, horloge, quêtes suivies, aide et invites s'effacent dès qu'un menu s'ouvre (carte, journal, inventaire, royaume, talents, succès, boutique, dialogues...), y compris quand le menu met le jeu en pause.
  - Tout ce qui s'affiche en jeu est rangé dans un seul conteneur (`Hud._chrome`).
  - Le héros émet `ui_changed` quand un menu s'ouvre ou se ferme.
- Test : `tests/run_tests.sh hud`. Il mesure la barre du bas et vérifie que rien ne reste affiché sous la carte, le journal, l'inventaire, le royaume et les talents. Captures : `hud_XX_*.png`.

## Finitions de prise en main (session de jeu automatique)

Une partie jouée toute seule (`tests/test_session.gd`) : le héros marche en 3e personne, combat deux squelettes
au viseur, lance une compétence, pose des blocs, ouvre son sac puis passe la nuit près du feu ; une capture à
chaque moment (`se_*.png`) sert à repérer les défauts visuels. Ce qu'elle a fait corriger :

- **Grands titres qui se chevauchaient** : le titre de l'acte (« Acte I — Une autre vie ») et celui de la région
  s'affichaient l'un sur l'autre au début. Les grands titres (région, acte, raid, événement, boss) passent
  désormais **l'un après l'autre**.
- **Contour du bloc visé plus épais** : de vraies arêtes sombres (et non des lignes d'un pixel), visibles de jour
  comme de nuit.
- **Aide à la visée** en 3e et 1re personne : un ennemi à portée, à moins de 4° du viseur, est accroché (on ne
  rate plus un monstre de peu).
- **Option « Viser à la souris »** (Options) : décochée, on retrouve l'ancien mode où le héros frappe et pose
  **devant lui**.
- **Guide replié** : le conseil détaillé d'un objectif reste 12 s, puis le guide se réduit à une ligne (titre et
  objectif) ; il revient un moment de temps en temps, ou avec la touche d'aide-mémoire.
- **Rappel des touches** (en haut à droite) : il s'efface après les 3 premières minutes de jeu.

## Sons du combat

Tous les bruitages sont générés par `tools/audio_generator.py` (synthèse, sans fichier extérieur).

- **Chaque arme a son impact** : lame (« tchac » métallique), masse et marteau (coup sourd), lance et dague
  (« tock » sec), poings (« pof » mat), bâton et projectiles magiques (claquement d'énergie). Les gros coups et
  les critiques ajoutent un grondement.
- **Chaque cible a sa matière** : les squelettes claquent comme des os, les gelées et grenouilles font
  « splotch », les dryades sonnent le bois creux, les esprits et fées un souffle cristallin, les orcs, scorpions
  et chevaliers un « clang » d'armure, les démons et créatures de magma la pierre. Un habitant ou le héros en
  armure de métal sonne aussi le métal.
- **Chaque compétence a le son de son genre** : feu (flamme qui s'embrase), glace (cristaux qui tintent),
  foudre (claquement électrique), lumière et soins (accord de cloches), ombre (souffle grave qui aspire),
  nature (bruissement), arcane (scintillement), technique d'arme (grand souffle). Le genre se déduit de l'effet
  de la compétence, sinon de sa couleur.
- **Les ultimes** (talents légendaires et mystiques) rassemblent leur énergie dans une montée de plus en plus
  aiguë, puis éclatent dans une déflagration : sous-grave, souffle et débris qui retombent (plus forte encore
  pour une mystique).

## Combat vivant

- **Zones rouges au sol** avant les grands coups : une bande devant un monstre qui va charger (sangliers,
  loups, ours...), un disque autour d'un monstre qui balaie, un disque devant les grands monstres. Elle se
  remplit pendant la préparation du coup : quand elle est pleine, ça frappe. On a le temps de rouler hors de
  la zone.
- **Les monstres réagissent** au coup qui vient :
  - les **agiles** (loups, panthères, harpies, gobelins, bandits, araignées, fées, serpents...) **esquivent**
    d'un bond de côté, dans un nuage de poussière ;
  - les **armés et cuirassés** (squelettes, orcs, ogres, démons, chefs bandits...) **lèvent leur garde** : les
    coups normaux sont bloqués, mais une **attaque chargée brise la garde** et les étourdit un instant.

  Plus le monstre a de niveaux, plus il le fait souvent (de 12 % à 40 % des coups), jamais deux fois de
  suite.
- **Boss en trois phases** :
  - **Enragé**, à la moitié de sa vie : rugissement, temps ralenti, onde qui repousse le héros ; il devient
    plus rapide et enchaîne ses pouvoirs.
  - **Fureur**, au quart de sa vie : sol brûlé, braises violettes autour de lui, pouvoirs deux fois plus
    fréquents, et un nouveau pouvoir, les **lames en croix**. Quatre bandes rouges partent de lui (en + ou
    en X), puis des lames d'énergie les parcourent : il faut se placer entre elles.

  Pendant chaque changement de phase, il est intouchable un court instant. La barre de vie du boss indique
  sa phase (ENRAGÉ, FUREUR) et change de couleur.
- Les grands titres attendent maintenant que le précédent se soit effacé, même quand le jeu rame.

## Lumières : nuit, flammes et grottes sombres

- **Torches et feux qui vivent** : la lumière d'une torche, d'un brasero ou d'une lanterne **vacille** comme
  une vraie flamme (`FlickerLight`). Elle éclaire plus loin (8 m) : la nuit, on voit nettement les cercles
  de lumière autour du campement.
- **Grottes vraiment sombres** : sous terre, les ténèbres avalent tout au-delà de quelques mètres, et la
  lumière ambiante est bien plus faible. On avance à la lueur de sa **lanterne**, qui vacille elle aussi.
  Les lumières des grottes sortent maintenant de **grappes de cristaux ou de champignons luisants**, bien
  visibles et qui palpitent doucement. Les donjons sont un peu plus sombres aussi.
- **Créatures de la nuit** : la nuit, et sous terre, les monstres proches ont **les yeux qui luisent** de leur
  couleur, et un léger halo autour d'eux. On les repère dans l'obscurité. Au lever du jour, ça s'éteint
  (sauf pour les monstres sortis avec la nuit).
- Les panneaux des grottes (« Sortie », « Descendre »...) s'effacent quand on est collé contre eux.

## Animations du héros

- **Chaque classe incante à sa manière** quand elle lance une compétence :
  - mage, cryomancien et nécromancien lèvent les mains au ciel puis les projettent en avant ;
  - guerrier, barbare et chevalier brandissent leur arme vers le ciel puis l'abattent en fléchissant les
    jambes ;
  - clerc, paladin et barde ouvrent les bras vers le ciel, le regard levé ;
  - le rôdeur tend un bras et tire la corde jusqu'à la joue ;
  - l'assassin s'accroupit, bras croisés, puis écarte ses lames d'un geste sec ;
  - le druide pose les mains vers la terre puis les remonte lentement ;
  - le moine se met en garde basse puis projette ses deux paumes.

  Les compétences de déplacement (ruée, clignement...) gardent leur propre mouvement.
- **Roulade** : le héros se met en boule (bras et jambes repliés) pendant le tour complet.
- **Saut** : le corps s'étire à l'envol et s'écrase à la réception, puis revient en souplesse ; un petit
  nuage de poussière se soulève à l'atterrissage.
- **Récolte** : quand on vise un arbre, un rocher, un bloc ou une culture (sans ennemi tout près), le héros
  lève son outil au-dessus de l'épaule et l'abat, comme un bûcheron ou un mineur, au lieu de donner un coup
  d'épée.

## Chasse et caméra de construction

- **On peut attaquer les animaux** (poules, moutons, vaches), sauvages ou de l'enclos :
  - le viseur les accroche (il devient rouge) ;
  - frappé, l'animal a mal, recule et **s'enfuit** quelques secondes ;
  - abattu, il laisse **de la viande crue** (à cuire au feu de camp), plus **de la laine** pour un mouton,
    **du cuir** pour une vache ou **des graines** pour une poule.

  Poule : 4 PV, mouton : 10, vache : 14 (moitié moins pour un petit).
- **Caméra de construction qui descend jusqu'au sol** : en mode construction, **Maj + molette** (ou **T** pour
  monter, **G** pour descendre) incline la caméra de la vue du dessus jusqu'au **ras du sol**. On voit ainsi
  si une base touche bien le sol ou si elle flotte. La caméra ne passe jamais sous le terrain. Clic molette
  + glisser fait aussi monter ou descendre la caméra, désormais jusqu'au sol.

## Artisanat par ateliers

L'ancien menu unique (13 onglets, plus de 1 400 recettes mélangées) est remplacé par des ateliers.

- **Sur soi (I) : l'essentiel.** Outils en bois, établi, feu de camp, torches, portes, planches, armures de
  cuir... De quoi démarrer, sans rien chercher.
- **Chaque atelier a son menu** : **F devant le meuble** l'ouvre (l'invite « Utiliser : Enclume » s'affiche).
  - **Établi** : outils de pierre, meubles, armes en bois, en os et en pierre, bateaux.
  - **Enclume** : armes et armures de métal, outils en fer, **Forge** (renforcement, gemmes, runes).
  - **Four** et **foyer de forge** : lingots, verre, terre cuite... et ils cuisent aussi les repas.
  - **Table du tailleur** : blocs de pierre taillée, dalles, escaliers, murets.
  - **Feu de camp** (et le feu du village) : la cuisine.
  - **Chaudron** : potions.
  - **Autel** : **Enchantement** et objets légendaires.

  Chaque menu ne montre que ce que ce meuble sait faire.
- **Carnet de découvertes** : une recette n'apparaît qu'une fois qu'on a eu en main tous ses ingrédients. En
  ramassant un nouveau matériau, un message annonce ce qu'il permet de fabriquer (« 3 nouvelles recettes :
  ... »). Les menus indiquent combien de recettes restent inconnues. L'onglet **Carnet** (sur soi) liste toutes
  les recettes connues, de tous les ateliers, avec une recherche.
- **Chercher à partir de son sac** :
  - **clic droit sur un objet du sac** : tout ce qu'on peut fabriquer avec, et à quel atelier ;
  - **clic sur un ingrédient** d'une recette : **comment l'obtenir** (quel atelier le fabrique, ce qu'on récolte
    pour l'avoir, quels monstres le lâchent, si le marchand le vend...).
- **Épingler (📌)** un objet : sa **liste de courses** s'affiche à l'écran, sous le guide (« Lingot de fer 1/2 ·
  Bois 2/2 »). Quand tout est réuni, elle dit où aller (« Prêt : enclume, 23 m au nord »). Trois objets au plus.
- **Construction : une forme, puis une matière** : on choisit Blocs, Dalles, Escaliers, Murets, Barrières,
  Portillons ou Toits en pente, puis la matière (granite, chêne, laine, béton...) dans une grille d'icônes, puis le
  bloc. Fini les centaines de lignes à faire défiler.

Les anciennes sauvegardes gardent toutes leurs recettes connues.

## Mondes (comme dans Minecraft)

- **Jouer (mondes)** sur l'écran titre ouvre la **liste des mondes**, jusqu'à **100 mondes**, du plus récent au
  plus ancien. Chaque monde montre son nom, le héros, son niveau, le temps de jeu, la date et ses options.
  Un clic sélectionne un monde, un deuxième clic le lance.
- **Créer un monde** : nom, **graine** (vide = au hasard ; un mot ou un nombre redonne toujours le même monde),
  difficulté, et les options :
  - **commandes autorisées** (triches : /vol, /kit, /donner... ; désactivées par défaut) ;
  - **raids** sur le village ;
  - **monstres la nuit** ;
  - **faim**.
- **Modifier** change le nom et les options d'un monde existant. **Supprimer** demande une confirmation
  (deuxième clic), puis efface le monde pour toujours.
- Le monde en cours se sauvegarde **à sa place** : « Sauvegarder » dans le menu pause, et la sauvegarde
  automatique toutes les 5 minutes. « Changer de monde » ouvre la liste. **Continuer** reprend le monde joué
  le plus récemment.
- Les anciennes sauvegardes apparaissent comme des mondes (« Monde 1 », « Sauvegarde automatique »...), avec
  les commandes autorisées.
- **Bug corrigé : le jeu s'arrêtait juste après une sauvegarde depuis le menu pause.** Une erreur de script
  dans le message de confirmation faisait arrêter le jeu (lancé depuis l'éditeur). La sauvegarde, elle, était
  bien écrite.

## Touche F pour interagir, et creuser la terre

- **F** sert maintenant à **toutes les interactions** : ateliers (établi, four, enclume...), coffres de
  rangement, portes, montures, entrées de grottes, et **parler aux habitants et aux PNJ**. Les invites à
  l'écran disent « F : ... ».
- **Verrouiller un ennemi** passe sur **Tab** (le clic molette verrouille toujours aussi).
- **Creuser** : vise le sol (le contour s'affiche) et **clic gauche**, comme pour un bloc. La terre vient
  d'abord (à mains nues ou à la pelle), et tombe en blocs de terre ou de sable à ramasser.
- Vers **2 m** de profondeur, on atteint la **roche** : il faut une **pioche**. Plus bas, la roche donne parfois
  du **minerai de fer** et du **charbon**.
- Vers **5 m**, la pioche **perce la voûte d'une galerie souterraine** : le héros descend dans une grotte à
  explorer (monstres, minerais, coffres), avec une sortie vers la surface.
- La touche G (creuser sous ses pieds) marche toujours.

## E pour l'équipement, F pour agir

- **E** (ou I) ouvre et ferme l'**équipement** (sac, équipement, artisanat sur soi) : c'est sa seule fonction.
- **F** ne sert qu'à **agir** sur ce qui est devant soi (atelier, coffre, habitant, PNJ, porte, monture...). Sans
  rien à portée, F ne fait rien : il n'ouvre plus le sac.
- **Viser / verrouiller un ennemi** : **Tab** (ou clic molette), comme dans beaucoup de jeux de rôle.
- Toutes les touches restent modifiables dans Commandes → Personnaliser.

## Le sac : trier, 999 par case, défilement corrigé

- **Trier** : en haut du sac, cinq boutons : **Arrivée** (l'ordre où on a ramassé), **Type** (équipement, outils,
  potions, nourriture, graines, blocs, meubles, matériaux), **Nom**, **Nombre** (les plus grosses piles d'abord),
  **Rareté**. Le choix est gardé ; les objets ramassés se rangent tout seuls à leur place.
- **999 par case** : tout ce qui s'empile (bois, pierre, blocs, nourriture, potions...) monte jusqu'à **999** dans
  une même case (avant : 20, 50 ou 99 selon l'objet). Armes, armures et outils ne s'empilent pas. Les anciennes
  sauvegardes regroupent leurs piles au chargement.
- **Bug corrigé : le sac remontait tout seul** quand on descendait dedans et qu'un objet arrivait, qu'on en
  équipait un ou qu'on fabriquait quelque chose. La liste (et celle des recettes) reste maintenant où on l'a
  laissée ; elle ne repart en haut que si on change d'onglet ou de tri.
## Creuser sous le niveau de la mer : plus d'eau sous les terres

- Avant, un seul grand plan d'eau couvrait tout le monde au niveau de la mer (avec un fond marin 2 m plus bas) :
  dès qu'on creusait plus bas que la mer sur la terre ferme, le trou se remplissait d'eau à l'écran et le
  fond marin masquait le fond du trou.
- Maintenant, un **masque de l'eau** (une case = un pixel) dit où sont les vrais lacs et la mer : le plan d'eau,
  le fond marin et le sol mouillé ne s'affichent plus qu'au-dessus des cases d'eau. On peut creuser aussi bas
  qu'on veut sous les terres : le trou reste **sec**, comme dans Minecraft. Les lacs, la mer et le large
  autour de l'île gardent leur eau.
- Le masque suit les changements du terrain (un lac comblé devient sec, un trou creusé reste sec).

## Grille d'artisanat façon Minecraft

- **Sur soi : une grille 2×2** (dans le sac, colonne Artisanat). **À un atelier** (établi, enclume, meule, four,
  table du tailleur, autel...) : **une grille 3×3** (F devant le meuble).
- **Poser des objets** : glisser une pile du sac dans une case (Ctrl : un seul objet), ou **Maj+clic** sur un objet
  du sac (la pile va dans la grille). Glisser une case sur une autre échange leur contenu ; la glisser sur le sac
  la range. **Clic droit** sur une case : en retirer un ; **Maj+clic** : tout retirer.
- **Le résultat** apparaît à droite de la flèche. **Clic** : fabriquer une fois. **Maj+clic : tout fabriquer** :
  4 bûches dans une case → **16 planches** d'un coup.
- **Le livre de recettes** (la liste en dessous) : **Placer** pose la recette dans la grille avec les objets du
  sac ; **Maj+Placer** en met de quoi la fabriquer le plus de fois possible. Grille vide : la dernière recette
  posée s'y dessine en transparence.
- Les recettes se reconnaissent au **nombre de cases qu'occupe chaque objet** (pas à leur place exacte : avec des
  centaines de recettes, ce serait illisible). Les grosses recettes (plus d'objets que de cases) demandent
  plusieurs objets par case : le chiffre est affiché. Quand plusieurs recettes ont les mêmes ingrédients
  (bois → planches, dalles, rondins...), **◀ ▶** à côté du résultat change de recette.
- Fermer le sac (ou changer d'atelier) **rend au sac** tout ce qui est dans la grille ; la sauvegarde le compte
  avec le sac.

## Drapeau du royaume : fonder son camp où on veut (RPG et gestion, dans l'ordre qu'on veut)

- Au début d'une partie, le héros arrive seul avec le **drapeau du royaume** dans le sac. Rien n'est imposé :
  on peut d'abord **explorer, suivre l'histoire et se battre** (le côté RPG / hack and slash), et fonder son
  royaume plus tard, ou tout de suite.
- **Planter le drapeau** : le prendre en main ({hand_toggle}, ou glisser dans la barre) puis **clic droit** au sol.
  Là où il est planté, c'est **le centre du camp** : les habitants recrutés s'y installent, les pillards y
  viennent, le marchand, les quêtes du village, les fêtes, les trophées, les animaux, la carte du royaume et le
  repère de la mini-carte s'y rattachent.
- **Le déplacer** : frapper le drapeau le reprend (il revient directement dans le sac, on ne peut pas le perdre),
  puis on le replante ailleurs. Drapeau arraché : **plus de camp, plus de raids** ; les habitants restent au
  dernier endroit en attendant. Un drapeau perdu se refait sur soi (2 bois, 2 fibres) ; un seul peut être planté
  à la fois.
- **Tant qu'aucun drapeau n'est planté : aucun raid.** Les raids de l'histoire, nécessaires pour avancer, tombent
  alors sur le héros là où il se trouve.
- **Recruter** un habitant demande un camp (« Plante d'abord le drapeau du royaume »).
- **L'histoire n'oblige plus à gérer** : chaque étape de gestion (« Construis 2 maisons », « Construis une forge »,
  « Rassemble 10 habitants »...) peut aussi se franchir **en aventurier**, en vainquant des monstres (12 + 4 par
  acte, depuis le début de l'étape). Le suivi à l'écran affiche les deux voies.
- Les deux moitiés s'aident : un royaume développé donne équipement, potions, bonus des pièces, artisans,
  expéditions ; l'aventure donne des niveaux, du butin et des ressources rares pour tenir face aux raids.
- Anciennes sauvegardes : le drapeau est planté automatiquement près de l'ancien village. Départ classique (avec
  campement) : le drapeau est déjà planté au campement.

## Raids selon la taille du royaume, et zone du camp

- **La force des raids vient du royaume, plus du niveau du héros.** La **menace du royaume** (affichée dans le
  panneau du royaume, onglet des habitants) vaut 1 + la moitié des habitants + 3 par rang (Campement → Capitale)
  + 2 par âge + 3 par province conquise. Elle choisit la bande de pillards (gobelins, orcs, ogres, légion des
  cendres) et leur niveau ; leur nombre dépend du rang et des habitants.
- Résultat : **l'aventure rend les raids plus faciles** (un héros de haut niveau balaie les pillards d'un petit
  camp), et **un grand royaume attire des bandes redoutables** qu'il faut des gardes et un héros solide pour
  repousser. Les raids de l'histoire, eux, suivent toujours le niveau du héros.
- **Zone du camp** : autour du drapeau, un cercle de **bornes à fanion** aux couleurs du royaume marque la zone.
  Son rayon grandit avec le rang : 16 m (Campement), 20, 26, 32, 40, 50, jusqu'à 62 m (Capitale d'empire) ; un
  message l'annonce quand elle s'étend. Elle apparaît aussi sur la carte du monde et la mini-carte (cercle doré).
- Pendant un raid, les gardes défendent toute la zone, et les pillards arrivent toujours de l'extérieur.

## Le camp et l'aventure s'aident

- **Guide** : une étape « Plante le drapeau du royaume » ouvre le chapitre du village. Sous chaque conseil, un
  bouton **« Passer cette étape »** (Alt pour libérer la souris) : le guide ne bloque jamais, on peut partir à
  l'aventure d'abord et fonder son village plus tard.
- **Retour au camp** :
  - sur la **carte du monde** ({world_map}), cliquer sur le camp (le carré doré) y ramène, comme un obélisque ;
  - la **pierre de rappel** (établi → Outils : 6 cailloux, 2 fibres → 2 pierres) : un clic dans le sac ramène au
    drapeau **d'où que l'on soit, même du fond d'un donjon, d'une grotte ou d'une faille**. Elle se brise.
- **Zone du camp = refuge** : aucun monstre n'y apparaît la nuit, et le héros y récupère **+3 PV/s** (un message
  le rappelle en entrant, au plus une fois par minute).
- **Faveurs du royaume (royaume → héros)**, selon le rang du royaume (panneau du royaume, vue d'ensemble) :
  - Hameau : chaque matin, 2 pains ;
  - Village : chaque matin, une potion de soin ;
  - Bourg : chaque matin, une pierre de rappel ;
  - Ville : attaque et défense du héros +2 par rang ;
  - Cité : chaque matin, 40 pièces d'or par rang ;
  - Capitale d'empire : expérience +10 %.
- **Trophées (héros → royaume)** : chaque région dont le héros a vaincu le boss (sa statue se dresse au camp)
  rend les habitants plus fiers (**bonheur +3** par trophée, jusqu'à +20) et fait venir les **voyageurs plus
  souvent** (−12 % d'attente par trophée, jusqu'à deux fois plus vite).
- Les voyageurs n'arrivent qu'auprès d'un camp (drapeau planté).
- **Passer le tutoriel** : à la création d'un monde, la case **« Tutoriel »** (cochée par défaut) peut être
  décochée : pas de guide des premiers pas. En jeu, sous le conseil du guide, **« Passer tout le tutoriel »**
  (deux clics pour confirmer) le fait disparaître pour de bon. L'intro animée se passe toujours avec Espace ou
  Échap.
