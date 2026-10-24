# Mes fiches

Appli Android (Flutter) de suivi d’habitudes façon fiches bristol : tâches à faire
X fois par jour, par semaine ou par mois, grilles de suivi façon contributions GitHub.
Reproduit le design de `../Appli de suivi d'habitudes/design_handoff_appli_habitudes`.

## Synchronisation (API)

L’appli parle uniquement à l’API (`../api`), jamais directement à PostgreSQL.

Dans l’appli : onglet **Suivi** → icône en haut à droite → adresse de l’API, nom du téléphone,
code d’association (`PAIRING_CODE` du serveur) et, en production, Client ID / Secret du jeton
de service Cloudflare Access → « Associer ce téléphone ».

- L’état complet reste sur le téléphone (`shared_preferences`) : l’appli marche sans réseau.
- Chaque changement est noté « à envoyer » ; la synchro (1,5 s après un changement, au
  démarrage, au retour au premier plan, ou « Synchroniser maintenant ») envoie ces changements
  puis récupère ceux faits ailleurs depuis la dernière révision reçue.
- Conflit sur une même habitude ou un même jour : la dernière écriture gagne. Un changement
  local pas encore envoyé n’est jamais écrasé par la synchro entrante.
- À l’association, toutes les données locales sont envoyées et fusionnées avec celles du serveur.
- Le jeton du téléphone et le secret Cloudflare sont dans le coffre Android
  (`flutter_secure_storage`), jamais dans les préférences.

En dev : API lancée sur le PC (`cd ../api && npm run db:start && npm run dev`), adresse
`http://10.0.2.2:3000` depuis l’émulateur. Le HTTP non chiffré n’est autorisé que dans les
builds **debug** (`flutter run`) ; la release exige HTTPS.

## Tests

```bash
flutter test                       # logique métier
# + synchro de bout en bout entre deux téléphones simulés, contre l’API de dev :
API_TEST_URL=http://localhost:3000 API_TEST_PAIRING_CODE=<PAIRING_CODE> flutter test
```

Chaque lancement de bout en bout associe deux appareils : l’API limite les associations à 5
par 15 minutes (redémarrer l’API de dev remet le compteur à zéro).

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
| `lib/store.dart` | état de l’appli + synchro (changements en attente, fusion) |
| `lib/sync.dart` | format des changements échangés avec l’API |
| `lib/storage/` | stockage local, client de l’API, coffre à secrets |
| `lib/screens/` | Aujourd’hui, Suivi, feuilles Créer/Modifier, Modifier le jour, Synchronisation |
| `lib/widgets/` | fiche bristol, boutons, segments, grille, icônes Phosphor |
| `lib/theme.dart` | tokens clair / sombre |
