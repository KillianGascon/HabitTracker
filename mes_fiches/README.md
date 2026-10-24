# Mes fiches

Appli Android (Flutter) de suivi d’habitudes façon fiches bristol : tâches à faire
X fois par jour, par semaine ou par mois, grilles de suivi façon contributions GitHub.
Reproduit le design de `../Appli de suivi d'habitudes/design_handoff_appli_habitudes`.

## Base de données

Le schéma est géré par l’API : voir [`../api/migrations`](../api/migrations), appliqué
automatiquement au démarrage de l’API.

> ⚠️ Transition en cours : l’appli se connecte encore **directement** à PostgreSQL (écran
> ci-dessous) ; elle passera par l’API (`../api`). Cette connexion directe n’est pas compatible
> avec le nouveau schéma.

Dans l’appli : onglet **Suivi** → icône base de données en haut à droite → hôte, port, base,
utilisateur, mot de passe → « Tester et enregistrer ».

Le téléphone doit pouvoir joindre le serveur (même Wi-Fi, ou VPN type NetBird/Tailscale), et
PostgreSQL doit écouter sur le réseau :

- `postgresql.conf` : `listen_addresses = '*'`
- `pg_hba.conf` : `host  mes_fiches  postgres  192.168.1.0/24  scram-sha-256` (adapter le réseau)
- pare-feu Windows : autoriser le port 5432 en entrant.

### Synchronisation

L’état complet est toujours gardé sur le téléphone (`shared_preferences`, clé `mes-fiches:v1`) :
l’appli marche sans réseau.

- Chaque changement est enregistré en local puis envoyé à la base.
- Si l’envoi échoue, l’état local est marqué « en attente » et **remplace** le contenu de la base
  à la prochaine connexion réussie (retour au premier plan, ou « Synchroniser maintenant »).
- Sinon, au démarrage et au retour au premier plan, **la base fait foi** (les modifications faites
  directement en SQL sont récupérées). Exception : base vide + données locales → envoi du local.

## Build

```bash
flutter pub get
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```

Installer : `flutter install` (téléphone branché en USB, débogage USB activé) ou copier l’APK
sur le téléphone.

Derrière un antivirus qui inspecte le HTTPS (Norton Web Shield…), Gradle échoue avec
`PKIX path building failed`. Le correctif est propre à la machine et vit hors du dépôt, dans
`~/.gradle/gradle.properties` : un truststore Java (certificats standards + racine de l’antivirus)
via `systemProp.javax.net.ssl.trustStore=…`.

## Code

| Fichier | Rôle |
|---|---|
| `lib/logic.dart` | dates locales, périodes, séries, niveaux de grille |
| `lib/store.dart` | état de l’appli + synchro |
| `lib/storage/` | stockage local, accès PostgreSQL |
| `lib/screens/` | Aujourd’hui, Suivi, feuilles Créer/Modifier, Modifier le jour, Base de données |
| `lib/widgets/` | fiche bristol, boutons, segments, grille, icônes Phosphor |
| `lib/theme.dart` | tokens clair / sombre |
