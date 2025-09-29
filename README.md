# NFCR - NFC Card Reader

Une application Android Flutter pour scanner, enregistrer et réutiliser des cartes NFC.

## Fonctionnalités

- 📱 **Scan de cartes NFC** : Scannez vos cartes NFC (cartes de transport, badges d'accès, etc.)
- 💾 **Stockage local** : Enregistrez vos cartes dans une base de données SQLite locale
- 🏷️ **Noms personnalisés** : Donnez des noms personnalisés à vos cartes pour les identifier facilement
- 🔍 **Recherche** : Recherchez vos cartes par nom ou UID
- 📋 **Détails complets** : Visualisez toutes les informations techniques de vos cartes
- ♻️ **Réutilisation** : Simulez l'utilisation de vos cartes enregistrées
- ✏️ **Édition** : Modifiez le nom de vos cartes à tout moment

## Technologies supportées

L'application supporte les technologies NFC suivantes :

- NFC-A (ISO 14443-A)
- NFC-B (ISO 14443-B)
- NFC-F (FeliCa)
- NFC-V (ISO 15693)
- ISO-DEP (ISO 14443-4)
- MIFARE Classic
- MIFARE Ultralight
- NDEF (NFC Data Exchange Format)

## Prérequis

- Appareil Android avec support NFC
- NFC activé dans les paramètres
- Android 6.0+ (API niveau 23+)

## Installation

1. Clonez le projet
2. Installez les dépendances :
   ```bash
   flutter pub get
   ```
3. Compilez et installez l'application :
   ```bash
   flutter run
   ```

## Utilisation

### 1. Scanner une nouvelle carte

- Appuyez sur le bouton "+" en bas à droite
- Appuyez sur "Commencer le scan"
- Approchez votre carte NFC du téléphone
- Donnez un nom à votre carte
- Sauvegardez

### 2. Voir vos cartes

- La liste de vos cartes s'affiche sur l'écran principal
- Utilisez la barre de recherche pour filtrer par nom ou UID
- Tirez vers le bas pour actualiser la liste

### 3. Gérer une carte

- Appuyez sur une carte pour voir ses détails
- Modifiez le nom en appuyant sur l'icône de modification
- Utilisez "Utiliser cette carte" pour simuler son utilisation
- Supprimez une carte via le menu contextuel (⋮)

### 4. Rechercher

- Utilisez la barre de recherche en haut de l'écran principal
- Recherchez par nom de carte ou par UID
- La liste se filtre automatiquement

## Structure du projet

```
lib/
├── main.dart                 # Point d'entrée de l'application
├── models/
│   └── nfc_card.dart        # Modèle de données pour les cartes NFC
├── services/
│   ├── database_service.dart # Service de base de données SQLite
│   └── nfc_service.dart     # Service de gestion NFC
└── screens/
    ├── home_screen.dart     # Écran principal avec liste des cartes
    ├── scan_screen.dart     # Écran de scan de nouvelles cartes
    └── card_detail_screen.dart # Écran de détails/édition des cartes
```

## Dépendances

- `nfc_manager`: Gestion des fonctionnalités NFC
- `sqflite`: Base de données SQLite locale
- `path`: Gestion des chemins de fichiers

## Permissions

L'application nécessite les permissions suivantes dans `AndroidManifest.xml` :

- `android.permission.NFC` : Accès aux fonctionnalités NFC
- `android.hardware.nfc` : Fonctionnalité NFC requise

## Notes importantes

- L'émulation HCE (Host Card Emulation) n'est pas disponible sur tous les appareils
- Certaines cartes peuvent avoir des protections qui empêchent la lecture complète des données
- Les données sensibles ne sont jamais transmises - tout reste local sur l'appareil
- L'application fonctionne uniquement sur Android (le NFC n'est pas disponible sur iOS)

## Développement

### Commandes utiles

```bash
# Analyser le code
flutter analyze

# Exécuter les tests
flutter test

# Compiler pour Android
flutter build apk

# Installer sur un appareil connecté
flutter install
```

### Structure de la base de données

Table `nfc_cards`:

- `id`: INTEGER PRIMARY KEY AUTOINCREMENT
- `name`: TEXT NOT NULL (nom personnalisé)
- `uid`: TEXT NOT NULL UNIQUE (identifiant unique de la carte)
- `technology`: TEXT NOT NULL (technologie NFC)
- `data`: TEXT (données brutes de la carte, format JSON)
- `createdAt`: TEXT NOT NULL (date de création)
- `lastUsed`: TEXT (date de dernière utilisation)

## Licence

Ce projet est sous licence MIT.
