# Récap – App de suivi d’habitudes « Mes fiches »

## Objectif

Une app mobile-first en français pour suivre des habitudes récurrentes (tâches à faire X fois par jour, par semaine ou par mois), inspirée de Hello Habit, avec un suivi visuel façon contributions GitHub.

## Modèle de données

```ts
type Period = "day" | "week" | "month";

interface Habit {
  id: string;        // ex. "h1729500000000"
  name: string;      // ex. "Faire la vaisselle"
  emoji: string;     // ex. "🍽️"
  period: Period;
  target: number;    // nombre de fois par période, 1 à 50
  created: string;   // date de création "YYYY-MM-DD"
}

interface State {
  habits: Habit[];
  logs: Record<string, Record<string, number>>; // logs[habitId]["YYYY-MM-DD"] = nombre de fois ce jour-là
}
```

Les dates sont des clés locales `YYYY-MM-DD` (pas d’UTC). Un compteur à 0 est supprimé du log.

## Règles métier

- **Période** : `day` = le jour même ; `week` = du lundi au dimanche ; `month` = du 1er au dernier jour du mois.
- **Compteur de période** : somme des logs de l’habitude sur la période qui contient la date sélectionnée.
- **Habitude faite** : compteur de période ≥ `target`.
- **Série en cours** : nombre de périodes réussies d’affilée en remontant depuis la période actuelle. Si la période actuelle n’est pas encore faite, on part de la précédente (la série n’est pas cassée tant que la période n’est pas finie).
- **Meilleure série** : plus longue suite de périodes réussies depuis la date de création.
- **Total** : somme de tous les logs de l’habitude.
- On peut cocher ou décocher n’importe quel jour passé, jamais un jour futur.

### Intensité des grilles (niveaux 0 à 4)

- **Par habitude, jour** : si `period = day`, niveau = `ceil(min(compteur / target, 1) × 4)` ; sinon niveau = `min(4, compteur × 2)`. 0 si rien.
- **Globale, jour** : moyenne des `min(compteur / target, 1)` des habitudes quotidiennes, + 0,25 par habitude hebdo ou mensuelle cochée ce jour-là, plafonné à 1, puis converti en niveau 1 à 4 (0 si rien).

## Écrans

### Aujourd’hui
- Bande de 7 jours (lundi → dimanche de la semaine du jour sélectionné), flèches semaine précédente / suivante, jours futurs désactivés, indicateur de niveau global sous chaque jour.
- Lien « Revenir à aujourd’hui » quand un autre jour est sélectionné.
- Habitudes groupées en « Chaque jour », « Chaque semaine », « Chaque mois », avec le compte des habitudes faites par groupe.
- Carte d’habitude : emoji, nom, fréquence (« 3 fois par jour »), série (🔥 5 j / sem. / mois), barre en segments (un par fois à faire, barre continue au-delà de 12), compteur `2/3`, boutons − et +, bouton modifier.
- Toucher la carte = +1. Quand l’objectif vient d’être atteint : état « fait » (fond vert, coche) et toast « Fait ! Série de N ».
- Bouton « Nouvelle habitude » en bas.

### Suivi
- Grille globale façon GitHub : colonnes = semaines, lignes = lundi → dimanche, nombre de semaines adapté à la largeur (14 à 30), repères de mois, légende « Moins → Plus ».
- Stats globales : jours actifs sur 30 jours, total de coches.
- Une carte par habitude : grille, série en cours, meilleure série, total, bouton modifier.
- Toucher une case sélectionne ce jour et bascule sur l’écran Aujourd’hui.

### Créer / modifier (feuille modale)
- Nom (obligatoire), grille d’emojis, fréquence (jour / semaine / mois), stepper pour le nombre de fois.
- Enregistrer, Annuler, et Supprimer en mode modification avec confirmation (supprime aussi l’historique).
- Échap ou clic hors de la feuille = fermer.

### États vides
- Aucune habitude : bouton « Ajouter une habitude » et bouton « Charger des exemples ».
- Exemples : Faire la vaisselle 🍽️ 3/jour, Faire le lit 🛏️ 1/jour, Lancer une lessive 🧺 2/semaine, Passer l’aspirateur 🧹 1/semaine, Payer les factures 🧾 1/mois.

## Persistance

- Tout l’état est sauvegardé à chaque modification (localStorage au minimum, clé `mes-fiches:v1`).
- Prévoir une couche de stockage isolée pour pouvoir brancher plus tard une synchro (compte, base distante) sans toucher au reste.
- À la reprise de l’app (retour au premier plan), recalculer la date du jour et réafficher.

## Contraintes

- Interface et textes en français, apostrophes typographiques (’).
- Mobile-first, responsive, grandes zones tactiles, safe areas iPhone.
- Mode clair et sombre (suivre le système).
- Accessibilité : focus clavier visible, cartes activables au clavier (Entrée / Espace), labels ARIA sur les boutons icônes, animations désactivées si `prefers-reduced-motion`.
- Design : cartes façon fiches bristol (blanches, ligne rouge sous le titre), vert réservé à la progression.

## Pistes pour la suite

- Rappels / notifications.
- Réorganiser les habitudes par glisser-déposer.
- Export / import des données (JSON).
- PWA installable sur le téléphone.