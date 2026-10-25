# Handoff : Appli de suivi d'habitudes — direction « Fiche bristol »

## Overview
Application mobile (français) de suivi d'habitudes ménagères/organisationnelles, inspirée des fiches papier bristol : tâches à faire **par jour**, **par semaine** et **par mois**, avec un objectif en nombre de fois (ex. « 3 fois par jour »). Écrans : Aujourd'hui, Suivi (grilles type contributions GitHub), feuille Créer/Modifier une habitude, feuille « Modifier un jour », état vide. Mode clair et mode sombre.

## About the Design Files
Les fichiers de ce dossier sont des **références de design en HTML** — des prototypes montrant l'apparence et le comportement attendus, **pas du code de production à copier**. La tâche est de **recréer ces écrans dans l'environnement cible** (React Native, SwiftUI, Flutter, etc.) avec ses patterns et bibliothèques. S'il n'existe pas encore de codebase, choisir le framework le plus adapté (recommandation : React Native + Expo, ou SwiftUI si iOS uniquement).

- `Appli Bristol.dc.html` : planche de tous les écrans (7 états × clair/sombre). Ouvrir dans un navigateur.
- `AppBristol.dc.html` : le prototype complet et fonctionnel (une instance = l'appli entière). La logique (`class Component`) en bas du fichier est la **référence de comportement** : modèle de données, calcul des séries, niveaux de la grille.
- `_ds/…/styles.css` : tokens du design system Nocturne (police, ramps de couleurs).

## Fidelity
**Haute fidélité.** Couleurs, typographie, espacements et interactions sont finaux. Reproduire au plus près.

## Cadre général
- Écran de référence : **360 × 760 pt** (barre de statut 44 pt, barre d'onglets en bas ~80 pt avec safe area 22 pt).
- Police : **Inter** (400 / 500 / 600). Titres en 500, jamais plus gras.
- Zones tactiles **≥ 44 pt** partout.
- Icônes : **Phosphor** (Regular) — calendar-check, squares-four, plus-circle, plus, minus, check, pencil-simple.
- Emojis comme icônes d'habitude ; 🔥 pour la série.
- Le **vert est réservé à la progression** (segments remplis, état atteint, cases de grille). Le **rouge** ne sert qu'à la ligne bristol (et au bouton Supprimer). L'accent violet sert aux actions et à l'onglet actif.

## Screens / Views

### 1. Aujourd'hui
Padding de contenu : 8 pt haut, 18 pt côtés, 28 pt bas ; sections espacées de 22 pt.
- **En-tête** : surtitre date (« MARDI 21 OCTOBRE ») 12 pt, uppercase, letter-spacing .08em, couleur `muted`. Titre 30 pt / 500 : « Aujourd'hui », « Hier » ou nom du jour. Si un jour passé est sélectionné : lien « Revenir à aujourd'hui » 13 pt couleur `accent`, aligné à droite.
- **Bande de 7 jours** : grille 7 colonnes égales, gap 5 pt, hauteur 64 pt. Chaque jour : abréviation (11 pt, opacité .7), numéro (17 pt / 500, chiffres tabulaires), pastille 6 pt (pleine `green` si toutes les habitudes quotidiennes de ce jour sont atteintes, sinon anneau 1 pt `muted`). Jour sélectionné = mini-fiche : fond `card`, contour 1 pt `rule`, rayon 6, **ligne rouge 1 pt** horizontale à 14 pt du haut. Les autres : fond transparent.
- **Groupes** « Chaque jour », « Chaque semaine », « Chaque mois » (un groupe vide est masqué) : titre 16 pt / 500 à gauche, compteur « 2/3 » 14 pt / 500 à droite (habitudes atteintes / total ; couleur `muted`, ou `done-ink-bg` quand tout est atteint). Cartes espacées de 10 pt.
- **Carte habitude (fiche bristol)** :
  - Fond `card` (ou `done-bg` si atteint), rayon 4, ombre `0 0 0 1px rule, 0 2px 6px rgba(0,0,0,.08)` (contour `green` si atteint). Réglure en fond : lignes horizontales 1 pt couleur `ruled` tous les 24 pt à partir de 51 pt.
  - Ligne de titre : padding 12/14/10, emoji 22 pt, nom 17 pt / 500 `card-ink` (une ligne, ellipsis), **bordure basse 1 pt `red` bord à bord** de la carte. Si atteint : pastille 26 pt `green` avec coche à droite.
  - Corps : à gauche, « 3 fois par jour » + « 🔥 5 j » (13 pt `card-muted`, gap 12) puis barre de **segments** (un par fois requise, hauteur 8, rayon 2, gap 4 ; remplis `green`, vides `seg`). À droite, boutons **−** et **+** 44×44, rayon 6 ; − contour `rule` (opacité .35 si compteur à 0), + contour `card-ink`.
  - Unités de série : `j`, `sem.`, `mois`. Pas de série → rien affiché.
- Pied : « Touchez une fiche pour cocher une fois · appui long pour la modifier » 12 pt `muted`, centré.

### 2. Suivi
- En-tête : surtitre « 16 DERNIÈRES SEMAINES », titre « Suivi » 30 pt.
- **Carte globale** (même style de fiche) : titre « Toutes les habitudes » + « Touchez un jour » (12 pt) ; ligne rouge. Ligne des mois (10 pt, « juil. », « août »… sur la semaine contenant le 1er). Grille : colonne de libellés 20 pt (« lun », « mer », « ven », 9 pt) + **16 colonnes (semaines, lundi en haut) × 7 lignes**, cases carrées fluides (`aspect-ratio:1`), gap 3, rayon 3. Légende « Moins ▢▢▢▢▢ Plus » alignée à droite.
- **Une carte par habitude**, regroupées par fréquence (titre de groupe 16 pt) : ligne de titre cliquable (emoji, nom, fréquence 12 pt, icône crayon) → ouvre Modifier ; ligne rouge. 3 colonnes de stats : libellé 11 pt `card-muted` (« Série en cours », « Meilleure série », « Total »), valeur 19 pt / 500. Puis grille 16×7 sans libellés, rayon 2.
- Jours futurs : case transparente avec anneau intérieur 1 pt `seg`, non cliquable.
- Toucher une case passée → feuille **Modifier un jour** ; la case sélectionnée a un anneau 2 pt `card-ink`.
- Vide : texte « Rien à suivre pour l'instant… » + bouton « Créer une habitude ».

### 3. Feuille « Modifier un jour »
Feuille du bas : fond `card`, rayon haut 14, padding 8/18/28, poignée 36×4 `rule`, voile `rgba(10,11,18,.45)`, hauteur max 84 %. En-tête : « Modifier le jour » (12 pt) + date complète 19 pt / 500, bouton « Terminé » (contour `card-accent`, 40 pt) ; ligne rouge. Une ligne par habitude (min 56 pt, séparateur `ruled`) : emoji, nom 15 pt / 500, sous-titre 12 pt (« 2/3 ce jour-là », « Objectif atteint · 3/3 » en `done-ink`, ou fréquence pour hebdo/mensuel), − / valeur 17 pt / +. Toucher le voile ferme.

### 4. Feuille Créer / Modifier une habitude
Même feuille (hauteur max 92 %), sections espacées de 18 pt. Titre « Nouvelle habitude » / « Modifier l'habitude » 20 pt + « Annuler » ; ligne rouge.
- **Nom** : libellé 12 pt, champ 48 pt, contour `rule`, rayon 6, texte 17 pt ; focus → contour `card-accent`. Placeholder « Ex. Arroser les plantes ».
- **Icône** : grille 8 × 2 de boutons 40 pt (🍽️ 🛏️ ✨ 🧺 🧹 🛒 🧾 🛌 💊 💧 🪴 🐕 📚 🏃 🗑️ 📞) ; sélection = fond `seg` + anneau 1,5 pt `card-accent`.
- **Fréquence** : contrôle segmenté 3 options 44 pt (« Par jour », « Par semaine », « Par mois »), sélection = anneau intérieur + texte `card-accent`.
- **Nombre de fois** : stepper − (48 pt) / valeur 28 pt + phrase « 3 fois par jour » 13 pt / + (48 pt). Min 1, max 12 (jour), 14 (semaine), 31 (mois). Aperçu des segments en dessous.
- **Actions** : « Créer l'habitude » / « Enregistrer » 50 pt, contour `card-accent` (opacité .45 et inactif si nom vide). En modification : « Supprimer cette habitude » texte `red` ; 1er appui → « Confirmer la suppression » avec contour `red` ; 2e appui supprime.

### 5. État vide (Aujourd'hui sans habitude)
En-tête normal, pas de bande de jours. Grande fiche (marge haute 28) : titre « Votre première fiche » 20 pt + ligne rouge ; texte 15 pt, interligne 28 pt sur réglure : « La table est vide. Notez ce que vous voulez faire chaque jour, chaque semaine ou chaque mois, comme sur vos fiches papier. » Boutons 50 pt : « Créer ma première habitude » (contour `card-accent`) et « Charger des exemples » + sous-titre « vaisselle, lessive, factures… » (contour `rule`).

### Barre d'onglets
3 onglets égaux, 52 pt + safe area : Aujourd'hui, Suivi, Nouvelle (ouvre la feuille Créer). Icône 24 pt + libellé 11 pt / 500. Actif `accent`, inactif `muted`. Fond `tab-bg`, filet haut 1 pt `rule`.

## Interactions & Behavior
- **Toucher une carte** = +1 (sans dépasser l'objectif de la période). **+** idem ; **−** retire 1 (sur le jour sélectionné ; pour hebdo/mensuel, s'il n'y a rien ce jour-là, retire sur le dernier jour de la période qui en a).
- **Appui long (≈520 ms)** sur une carte → feuille Modifier ; le tap qui suit est ignoré.
- Objectif atteint → fond `done-bg`, contour `green`, coche, segments verts. Transition fond 200 ms. Pressé : `scale(.99)`.
- Sélection d'un jour dans la bande → toutes les cartes affichent ce jour (hebdo/mensuel : total de la période qui contient ce jour).
- Feuilles : montent du bas (prévoir ~250 ms ease-out), fermeture au voile, à « Annuler »/« Terminé ».
- Feedback haptique léger recommandé au +1 et à l'objectif atteint.

## State Management
```
habits: { id, e (emoji), name, per: 'jour'|'semaine'|'mois', goal: number }[]
counts: Record<dateISO, Record<habitId, number>>   // compteur par jour
ui: screen ('today'|'suivi'), selectedDay, sheet (null|'form'|'day'), draft, confirmDelete
```
- Progression d'une habitude pour un jour J = `jour` : counts[J] ; `semaine` : somme sur la semaine ISO (lundi→dimanche) de J ; `mois` : somme sur le mois civil.
- **Série en cours** : nombre de périodes consécutives atteintes en remontant depuis la période actuelle (la période actuelle non encore atteinte ne casse pas la série). **Meilleure série** : plus longue suite. **Total** : somme de tous les compteurs.
- **Niveau de case (0–4)** — global : `round(4 × Σ min(count, goal) / Σ goal)` sur les habitudes quotidiennes. Par habitude quotidienne : 0 si rien, sinon `min(4, round(1 + 3 × count/goal))`. Hebdo/mensuelle : 4 le jour où c'est fait, 1 les autres jours d'une période atteinte, sinon 0.
- Persistance locale (AsyncStorage / SQLite / SwiftData). « Charger des exemples » crée les 8 habitudes ci-dessous sans historique.

Exemples : Faire la vaisselle 🍽️ 3/jour · Faire le lit 🛏️ 1/jour · Ranger 10 minutes ✨ 1/jour · Lancer une lessive 🧺 2/semaine · Passer l'aspirateur 🧹 1/semaine · Faire les courses 🛒 1/semaine · Payer les factures 🧾 1/mois · Changer les draps 🛌 2/mois.

## Design Tokens
| Token | Clair | Sombre |
|---|---|---|
| bg | #eef0f6 | #161826 |
| ink | #1f2130 | #e9e9ed |
| muted | #5f6375 | #9397ab |
| card (fiche) | #fdfdfb | #e4e3dc (les fiches restent claires) |
| card-ink | #1f2130 | #1f2130 |
| card-muted | #5f6375 | #595d6c |
| card-accent | #796cbf | #5d5294 |
| rule | #d9dce8 | #b2b6ca |
| seg (vide) | #e4e7f5 | #cfd3e5 |
| ruled (réglure) | oklch(0.85 0.05 240 / .45) | oklch(0.75 0.05 240 / .4) |
| red (ligne bristol) | oklch(0.6 0.19 25) ≈ #d9433f | oklch(0.58 0.19 25) |
| green | oklch(0.62 0.15 150) ≈ #3a9a5b | oklch(0.6 0.15 150) |
| green-deep (niveau 4) | oklch(0.42 0.11 150) ≈ #1f5f36 | idem |
| done-bg | oklch(0.96 0.035 150) | oklch(0.89 0.06 150) |
| done-ink (sur fiche) | oklch(0.42 0.1 150) | oklch(0.4 0.1 150) |
| done-ink-bg (sur fond) | oklch(0.42 0.1 150) | oklch(0.8 0.12 150) |
| accent | #796cbf | #9184d9 |
| tab-bg | #fdfdfb | #1d1f2c |

Niveaux de grille : 0 `seg` · 1 mélange 35 % green/seg · 2 mélange 70 % · 3 `green` · 4 `green-deep` (mélanges en OKLCH).

Rayons : 2–4 (cases, fiches), 6 (boutons, champs), 14 (haut des feuilles). Espacements : 4, 5, 8, 10, 12, 14, 18, 22, 28. Typo : 30 (titre écran), 20 (titre feuille), 19 (stats), 17 (nom habitude, chiffres), 16 (groupe), 15, 13, 12, 11, 10, 9.

## Assets
Aucune image. Emojis système. Icônes Phosphor (phosphoricons.com, MIT). Police Inter (Google Fonts, OFL).

## Files
- `Appli Bristol.dc.html` — planche de tous les écrans
- `AppBristol.dc.html` — prototype + logique de référence
- `support.js`, `_ds/…` — nécessaires pour ouvrir les fichiers HTML localement
