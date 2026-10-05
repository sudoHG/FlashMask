# Flash Mask

[![Release](https://img.shields.io/github/v/release/sudoHG/FlashMask?style=flat-square&label=release)](https://github.com/sudoHG/FlashMask/releases/latest) [![Stars](https://img.shields.io/github/stars/sudoHG/FlashMask?style=flat-square&label=stars)](https://github.com/sudoHG/FlashMask/stargazers) [![License](https://img.shields.io/badge/license-Apache--2.0-blue?style=flat-square)](LICENSE) [![macOS](https://img.shields.io/badge/macOS-13%2B-black?style=flat-square)](https://apps.apple.com/fr/app/flash-mask/id6803817818?mt=12) [![Universal](https://img.shields.io/badge/Universal-arm64%20%2B%20x86__64-black?style=flat-square)](https://apps.apple.com/fr/app/flash-mask/id6803817818?mt=12) [![README views](https://hits.sh/github.com/sudoHG/FlashMask.svg?style=flat-square&label=README%20views)](https://hits.sh/github.com/sudoHG/FlashMask/)

[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-Hant.md) | [日本語](README.ja.md) | [Deutsch](README.de.md) | Français | [Español](README.es.md)

**Des masques d'image rapides pour indiquer à l'IA exactement où modifier.**

<a href="https://apps.apple.com/fr/app/flash-mask/id6803817818?mt=12"><img src="https://tools.applemediaservices.com/api/badges/download-on-the-mac-app-store/black/fr-fr?size=250x83" alt="Télécharger dans le Mac App Store" height="54"></a>

> « Pas ça — celui d'à côté. » Combien de fois avez-vous dû dire cela à l'IA ?  
> Vous voulez modifier un simple détail, et le modèle régénère l'image entière. Jusqu'à présent, corriger cela signifiait ouvrir un éditeur d'image lourd pour des sélections et des exports fastidieux.  
> Flash Mask transforme tout ce processus en quelques secondes : déposez une image, délimitez la zone à modifier et copiez des coordonnées JSON structurées directement dans votre IA ou votre agent afin qu'il connaisse l'emplacement exact de la modification. Lorsque vous avez besoin d'une précision au pixel près, exportez un masque noir et blanc 1:1 en un clic.

![Flash Mask sur macOS : délimiter une région d'image et copier les coordonnées JSON pour un agent IA](assets/app-screenshot.png)

---

## Présentation

Flash Mask est une application compagnon macOS native et légère conçue pour l'édition d'images par IA et les flux de travail visuels. Lors de la collaboration avec des modèles d'IA ou des agents de programmation, les prompts textuels seuls échouent souvent à spécifier des limites exactes, entraînant des modifications involontaires sur l'ensemble de l'image ou des retouches au mauvais endroit.

Sur macOS, Flash Mask génère du JSON 1.1 avec une instruction pour l'ensemble de l'image et des notes facultatives pour chaque région. L'application web du site reste en JSON 1.0.

### Application Mac

- Collez une capture d'écran directement depuis le presse-papiers.
- Ajoutez une instruction pour l'ensemble de l'image et des notes facultatives pour les régions individuelles.
- Utilisez l'interface en sept langues : anglais, chinois simplifié, chinois traditionnel, japonais, allemand, français et espagnol.
- Utilisez une fenêtre de réglages dédiée pour changer de langue, vérifier les mises à jour et ouvrir le site web, l'aide, le code source sur GitHub ou la page d'assistance.

Au lieu de lutter avec des outils lasso, des calques de remplissage et des exports manuels dans des éditeurs d'images complexes, Flash Mask convertit vos sélections en coordonnées prêtes pour vos agents en quelques secondes :

- **Coordonnées JSON structurées par défaut** : copiez en un clic du JSON standardisé contenant les coordonnées en pixels, les coordonnées normalisées, les dimensions de l'image source, les chemins de fichiers absolus locaux et des instructions d'édition facultatives (prompts). Collez-les directement dans votre chat IA ou votre flux de travail d'agent.
- **Masque PNG noir et blanc 1:1 à la demande** : pour les modèles d'inpainting et les pipelines traditionnels nécessitant des masques au niveau du pixel, exportez un masque PNG net correspondant aux dimensions de l'image d'origine (sélection en blanc pur, arrière-plan en noir pur, sans contour progressif ni anticrénelage).
- **100 % local, hors ligne et privé** : le décodage d'image, le calcul des coordonnées et le rendu du masque s'exécutent entièrement sur votre Mac. Aucune image, aucun chemin de fichier, aucune coordonnée ni aucun prompt n'est jamais téléversé. Aucun compte, aucune connexion, aucune publicité et aucun SDK de suivi.
- **Ciblage spatial dédié — sans verrouillage IA intégré** : Flash Mask se concentre sur la communication claire de *l'endroit à modifier* et de *ce qu'il faut changer*. La génération et l'édition réelles de l'image sont gérées par votre outil d'IA ou agent préféré — sans verrouillage propriétaire ni dépendance au cloud.

## Cas d'utilisation

- **Art de personnages et retouches de générations d'IA** : délimitez les mains, les traits du visage, les vêtements ou les accessoires pour guider un inpainting ciblé tout en préservant le reste de l'image.
- **Nettoyage de photos et suppression d'objets** : encadrez rapidement les passants en arrière-plan, les éléments indésirables, les filigranes ou les imperfections pour que les agents d'édition d'image les suppriment et effectuent un inpainting propre.
- **Modifications d'affiches et de supports marketing** : marquez les dispositions de texte spécifiques, les sujets de produits ou les éléments graphiques à remplacer dans les affiches, bannières et ressources e-commerce.
- **Signalement de bugs d'interface pour les agents de programmation** : identifiez précisément les bugs visuels dans les captures d'écran d'interface — comme du texte tronqué, des contrôles qui se chevauchent ou des défauts d'alignement dans le simulateur iOS, les applications macOS, Canvas, WebGL, les cartes, les graphiques ou les interfaces de jeux — et transmettez directement les coordonnées exactes et les instructions de correction à votre agent de programmation.

## Démarrage rapide

1. **Ouvrir une image** : glissez-déposez une image PNG, JPEG/JPG ou WebP dans la fenêtre, cliquez sur **Ouvrir une image** ou collez une capture d'écran depuis le presse-papiers. Déplacez, zoomez et basculez entre les vues **Ajuster** et **Taille réelle** (pixels 1:1).
2. **Délimiter et affiner les régions** :
   - Cliquez et glissez sur l'image pour tracer une zone à main levée ; relâchez le bouton de la souris pour l'ajouter. Dessinez plusieurs régions distinctes si nécessaire (automatiquement fusionnées en une union).
   - Cliquez sur n'importe quelle région existante pour l'ajuster : faites glisser l'ensemble de la sélection pour la repositionner, ou déplacez, ajoutez et supprimez des sommets de polygone individuels.
   - Facultatif : saisissez une instruction pour l'ensemble de l'image dans le champ **« Que doit faire votre agent ? »**, puis sélectionnez une région pour lui ajouter une note.
3. **Copier le JSON ou exporter le masque** :
   - Cliquez sur **Copier le JSON** : copie les données structurées — y compris le chemin de fichier local, les dimensions de l'image, les coordonnées de polygone et le prompt d'édition — dans votre presse-papiers pour les coller directement dans votre IA ou agent.
   - Cliquez sur **Exporter le masque PNG** : ouvre la boîte de dialogue d'enregistrement de macOS pour exporter un masque PNG net en noir et blanc correspondant aux dimensions de l'image source. Le masque marque les zones sélectionnées ; les notes sont incluses dans le JSON.

## Format des données de coordonnées JSON

Flash Mask génère du JSON versionné et auto-descriptif avec un double système de coordonnées — coordonnées absolues en pixels et coordonnées normalisées `[0.0, 1.0]` (origine en haut à gauche, X croissant vers la droite, Y croissant vers le bas). L'application Mac utilise le format JSON 1.1 ; l'application web du site utilise le format JSON 1.0 :

```json
{
  "mask_spec_version": "1.1",
  "instruction": "This JSON identifies areas the user selected in the source image. Each polygon marks one selected area; multiple polygons form a combined selection; the first and last points are connected automatically. The top-level `prompt`, if present, applies to the whole image. Each region's `prompt`, if present, applies only to that region. Interpret these texts in the context of the current conversation. The combined geometry marks range only; it does not assign a processing order among regions.",
  "source_image": {
    "file_name": "example.jpg",
    "width": 1920,
    "height": 1080,
    "file_path": "/Users/username/Pictures/example.jpg"
  },
  "coordinate_system": {
    "origin": "top-left",
    "x_direction": "right",
    "y_direction": "down"
  },
  "prompt": "Keep the building",
  "regions": [
    {
      "id": 1,
      "shape": "polygon",
      "points_px": [[96, 108], [480, 108], [480, 432], [96, 432]],
      "points_normalized": [[0.05, 0.1], [0.25, 0.1], [0.25, 0.4], [0.05, 0.4]],
      "prompt": "Remove stray lines"
    },
    {
      "id": 3,
      "shape": "polygon",
      "points_px": [[600, 108], [900, 108], [900, 432], [600, 432]],
      "points_normalized": [[0.3125, 0.1], [0.46875, 0.1], [0.46875, 0.4], [0.3125, 0.4]],
      "prompt": "Use a light gray background"
    }
  ]
}
```

### Référence des champs

- `mask_spec_version` : version de la spécification. L'application Mac émet actuellement `"1.1"` ; l'application web du site reste sur `"1.0"`.
- `instruction` : guide auto-descriptif intégré qui indique aux modèles d'IA ou agents en aval comment interpréter les polygones et l'intention de l'utilisateur.
- `source_image` : nom du fichier source, dimensions en pixels (`width`, `height`) et chemin de fichier absolu local sur Mac (`file_path` est spécifique à l'application macOS afin que les agents locaux puissent accéder directement au fichier).
- `coordinate_system` : définition du système de coordonnées (fixée avec l'origine en haut à gauche, X croissant vers la droite, Y croissant vers le bas).
- `prompt` : facultatif. Dans le JSON 1.1 pour Mac, cette instruction s'applique à l'ensemble de l'image.
- `regions` : liste des régions marquées. Chaque région comprend des coordonnées entières en pixels (`points_px` sous la forme `[x, y]`) et des coordonnées normalisées sans dimension (`points_normalized` sous la forme `[x/width, y/height]`). Le format JSON 1.1 pour Mac peut inclure un `prompt` facultatif pour une région spécifique ; les identifiants de région restent stables lorsqu'une autre région est supprimée. Les sommets de début et de fin se ferment automatiquement, et plusieurs régions forment une union combinée.

Les consommateurs stricts de JSON 1.0 doivent mettre à jour leur validateur avant d'accepter le JSON 1.1. Flash Mask ne supprime pas silencieusement les notes de région.

## Fonctionnalités

- **Large prise en charge de formats** : importez des images PNG, JPEG/JPG et WebP.
- **Sélection multi-régions** : dessinez plusieurs sélections irrégulières sur une seule image ; les sélections se combinent automatiquement en un masque unifié lors de l'exportation.
- **Édition interactive des sommets** : déplacez des sélections entières pour les repositionner, ou ajoutez, déplacez et supprimez précisément des sommets de polygone.
- **Navigation fluide sur le canevas** : faites défiler et zoomez de manière fluide, avec des basculements rapides pour les vues **Ajuster** et **Taille réelle** (pixels 1:1).
- **Notes d'image et de région** : associez une instruction facultative à l'ensemble de l'image et ajoutez des notes aux régions individuelles dans l'application Mac.
- **Double système de coordonnées** : génère à la fois des coordonnées absolues en pixels et des coordonnées normalisées indépendantes de la résolution pour prendre en charge les différents schémas d'agents et de modèles.
- **Fidélité à la résolution d'origine** : les masques PNG en noir et blanc correspondent aux dimensions de l'image source en 1:1, avec un rendu aux sélections en blanc pur, arrière-plans en noir pur et bords nets sans contour progressif.
- **Chemins de fichiers locaux directs** : l'application macOS produit des chemins de fichiers absolus vérifiés en JSON afin que les scripts d'automatisation et agents locaux puissent localiser les fichiers instantanément.
- **Sept langues d'interface** : anglais, chinois simplifié, chinois traditionnel, japonais, allemand, français et espagnol. L'application suit la langue de votre système par défaut ; changez à tout moment depuis le menu des langues de la barre supérieure ou dans les Réglages sans perdre votre image actuelle, vos régions ou vos notes.
- **Confidentialité et fonctionnement hors ligne d'abord** : fonctionne à 100 % localement sans nécessiter de compte, avec zéro publicité et aucun SDK de suivi ou d'analyse.

## Obtenir Flash Mask

- **Mac App Store** : obtenez l'application officielle précompilée sur le [Mac App Store](https://apps.apple.com/fr/app/flash-mask/id6803817818?mt=12). Un achat unique avec accès à vie — sans abonnement ni achat intégré.
- **Site officiel** : visitez [flashmask.net](https://flashmask.net/) pour les mises à jour et les détails sur le produit.
- **Versions sources** : téléchargez les archives du code source depuis les [GitHub Releases](https://github.com/sudoHG/FlashMask/releases). *(Remarque : les versions binaires officielles sont distribuées exclusivement via le Mac App Store ; GitHub Releases ne fournit pas de binaires précompilés).*

## Périmètre open source

Ce dépôt fournit l'intégralité du code open source pour le client macOS de Flash Mask, comprenant :
- Le conteneur hôte natif macOS AppKit / WKWebView et le projet Xcode (`macos/`)
- Le cœur de l'éditeur HTML / JavaScript intégré (`index.html`)
- L'analyse du protocole de contrat de coordonnées, le nettoyage des sommets de sélection et la logique de génération de masque (`src/`)
- Les schémas de validation des contrats de coordonnées JSON Flash Mask 1.0 et 1.1 (`schemas/`)
- La suite de tests unitaires et de validation automatisée de contrats (`tests/`)

*Remarque : ce dépôt contient l'application macOS autonome et son cœur d'édition. Il n'inclut pas les scripts de déploiement web autonomes ni les services back-end commerciaux (tels que les pages d'atterrissage marketing, les systèmes de quotas/publicités, les analyses ou l'infrastructure hébergée). Sous la licence Apache-2.0, le module d'édition principal et les contrats de données partagés peuvent être librement portés et adaptés.*

## Contribuer

Consultez le [guide de contribution](贡献指南.md) pour les vérifications locales, la couverture CI et les détails sur les pull requests.

## Compiler l'application Mac depuis les sources

### Prérequis

- Un Mac avec une installation complète de **Xcode** ; la version de macOS hôte doit être prise en charge par cette version de Xcode
- L'application cible **macOS 13.0 ou version ultérieure** et se compile sous forme de binaire universel (`arm64` + `x86_64`)
- Compilation en Swift, AppKit et WebKit purs — zéro dépendance de paquet Swift externe

### Commande de compilation

Exécutez la commande suivante depuis la racine du dépôt :

```sh
xcodebuild \
  -project 'macos/Flash Mask.xcodeproj' \
  -scheme 'Flash Mask' \
  -configuration Release \
  -derivedDataPath '.derivedData/local' \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  build
```

**Emplacement de sortie de la compilation** : `.derivedData/local/Build/Products/Release/Flash Mask.app`

Cette commande crée une version locale non signée, compilant le conteneur natif et regroupant `index.html` et les ressources de l'application dans une application autonome. La configuration Release cible macOS 13.0 et compile les tranches d'architecture `arm64` et `x86_64`. La version officielle pour l'App Store est produite via le flux distinct d'archivage et de distribution de Xcode, et non par cette commande de compilation locale.

### Script de compilation en une seule commande

Vous pouvez également utiliser le script `build.sh` inclus (exécutez `./build.sh --help` pour plus de détails) :

```sh
./build.sh
./build.sh --version 1.3.1 --build-number 9 --dmg
```

Le script utilise par défaut la version `1.3` et le build `8` ; `--version` et `--build-number` permettent de remplacer ces valeurs. Il vérifie la version de l'application compilée, la version minimale de macOS et les deux tranches d'architecture. `--dmg` empaquette cette application non signée pour des tests locaux ; le fichier DMG obtenu ne convient pas à une distribution Gatekeeper.

Pour une distribution en dehors du Mac App Store, signez l'application avec votre propre identité **Developer ID Application** et un horodatage sécurisé, vérifiez sa signature de code, soumettez-la pour notarisation, puis agrafez et validez le ticket accepté. Ensuite, empaquetez cette application exacte avec :

```sh
./build.sh --package-app "/path/to/stapled/Flash Mask.app"
```

`--package-app` vérifie la signature Developer ID, l'horodatage sécurisé, le ticket de notarisation, le prérequis macOS 13.0 minimum et les deux tranches d'architecture, puis crée un fichier DMG versionné sans réexécuter `xcodebuild` ni signer à nouveau. Le DMG lui-même reste non signé ; la signature, la notarisation et l'agrafage de ce conteneur externe sont des étapes distinctes pour la distribution directe. Cet utilitaire ne signe pas, ne notarise pas, n'archive pas et ne produit pas de build officiel pour l'App Store. Les versions dérivées doivent utiliser leurs propres Bundle ID, nom d'application et éléments de marque.

## Exécution des tests principaux

L'exécution de la suite de tests du protocole et de la logique principale nécessite **Node.js 22** ou version ultérieure. (*Node.js est utilisé exclusivement pour tester les contrats et les algorithmes ; la compilation de l'application macOS elle-même ne nécessite pas Node.js*).

```sh
npm ci --ignore-scripts
npm test
```

La suite de tests couvre :
- La validation des schémas du contrat de coordonnées JSON pour les cibles macOS et Web
- Les contraintes de champs spécifiques aux plateformes et les règles d'omission
- Les calculs de géométrie des polygones et la simplification des sommets du lasso (lissage et suppression des redondances)
- La précision de la rastérisation en pixels du masque PNG 1:1 en noir et blanc
- Les limites de performance et les garde-fous sur le nombre de sommets
- Les ressources de localisation : clés identiques, espaces réservés et ressources de bundle appariées dans les sept langues

Sur macOS, `npm test` compile et exécute également les tests Swift natifs (ressources de localisation et positionnement de la fenêtre des Réglages), qui ouvrent brièvement des fenêtres de test. Exécutez les tests d'interface native séparément avec `node --test tests/mac-localization-ui.js`. L'intégration continue (CI) exécute les tests principaux sous Linux ainsi que les tests natifs et d'interface sur Apple Silicon macOS 15, Intel et macOS 14 ; consultez le [guide de contribution](贡献指南.md).

## Structure du répertoire

| Chemin | Description |
|---|---|
| `index.html` | Interface de l'éditeur intégré, interactions avec le canevas et machine à états de l'interface utilisateur |
| `src/` | Analyse du contrat de coordonnées, rastérisation du masque et algorithmes de nettoyage des sommets de sélection |
| `src/localizations/` | Texte de l'interface pour les sept langues, un fichier JSON par langue |
| `scripts/` | Script au moment de la compilation qui valide et regroupe les ressources de localisation appariées |
| `schemas/` | Définitions officielles JSON Schema pour les contrats de coordonnées Flash Mask 1.0 et 1.1 |
| `macos/` | Conteneur hôte natif AppKit / WKWebView, accès aux fichiers avec portée de sécurité et projet Xcode |
| `tests/` | Tests unitaires, suites de validation de contrats et jeux d'essai |

## Licence et mentions

Le code source original de Flash Mask est sous licence [Apache License 2.0](LICENSE). Conformément aux termes de la licence, vous pouvez librement utiliser, modifier et distribuer ce logiciel, y compris dans des œuvres dérivées commerciales et propriétaires.

- Les mentions de droit d'auteur et d'attribution sont documentées dans [NOTICE](NOTICE).
- Les composants et dépendances tiers sont répertoriés dans [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
- Les éléments de marque — y compris le nom « Flash Mask », les logos et les icônes de l'application — sont protégés par des [conditions relatives aux éléments de marque](BRAND_ASSETS.md) distinctes et sont exclus de la concession de licence Apache-2.0.
- **Propriété des données de l'utilisateur** : toutes les données de coordonnées JSON, images et masques PNG générés avec Flash Mask appartiennent entièrement à l'utilisateur et ne sont pas soumis à la licence Apache-2.0.
