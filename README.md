# Boutik Faso

Boutik Faso est une application de gestion destinée aux commerçants. Elle permet de gérer les produits et le stock, d’enregistrer les ventes payées immédiatement ou à crédit, de suivre les clients et leurs remboursements, et de consulter les dépenses et les indicateurs de la boutique.

L’application n’est pas une boutique en ligne : elle ne propose ni commande en ligne, ni panier destiné aux acheteurs, ni livraison. Les ventes sont enregistrées par le commerçant depuis la caisse.

L’interface Flutter est conçue pour mobile et ordinateur.

## Fonctionnalités de l’application actuelle

- Tableau de bord avec activité du jour, ventes, dettes et alertes de stock.
- Catalogue des produits, catégories, recherche et photo de produit.
- Suivi du stock : entrées, sorties, pertes et seuils d’alerte.
- Caisse, panier, validation de vente et reçu.
- Ventes payées en espèces ou mobile money, et ventes à crédit rattachées à un client.
- Fiches clients, soldes dus, historique et remboursements partiels.
- Saisie et suivi des dépenses.
- Affichage adapté aux écrans mobiles et desktop.

## Stack technique prévu

### Application Flutter

| Technologie | Rôle prévu |
|---|---|
| Flutter et Dart | Application mobile et desktop |
| GetX | Navigation, état d’écran et injection des contrôleurs |
| Drift / SQLite | Données locales persistantes et fonctionnement hors ligne |
| Dio | Appels HTTP vers l’API, authentification, erreurs et téléversement de photos |

### Backend et base de données

| Technologie | Rôle prévu |
|---|---|
| Python et FastAPI | API REST versionnée |
| Pydantic | Validation et schémas des requêtes/réponses |
| SQLAlchemy 2 | Accès aux données et transactions métier |
| Alembic | Migrations du schéma PostgreSQL |
| PostgreSQL | Base de données centrale |

### Sécurité et infrastructure

- JWT pour les jetons d’accès ; OAuth2 pour le flux d’autorisation retenu. Pour une connexion OAuth native, prévoir Authorization Code avec PKCE.
- Argon2id pour le hachage des mots de passe.
- Permissions par utilisateur et par boutique, vérifiées côté serveur à chaque requête.
- Docker et Docker Compose pour les environnements reproductibles.
- VPS Ubuntu, Nginx et HTTPS pour l’hébergement.
- Sauvegardes automatisées de PostgreSQL et procédure de restauration vérifiée.
- Pytest, tests API et tests de synchronisation pour valider les opérations métier et le mode hors ligne.

Le stack backend et local décrit ici est la cible prévue ; il n’est pas encore intégré à l’application.

## État actuel et limites

Le projet est actuellement un prototype Flutter/GetX sans API ni base de données. Les données métier sont conservées en mémoire pendant la session. Les espaces de commerçants peuvent être créés et sélectionnés localement, mais ils ne sont pas des comptes authentifiés et leurs données ne sont ni sécurisées entre utilisateurs ni conservées après fermeture de l’application.

Drift/SQLite, Dio, FastAPI, PostgreSQL, l’authentification, la synchronisation et les sauvegardes restent à implémenter. Les photos de produits sont actuellement référencées par un chemin local ; leur téléversement et leur stockage durable restent à faire.

## Architecture Flutter

L’application suit une organisation **Feature-First**. Chaque domaine regroupe ses écrans, contrôleurs, modèles et bindings.

```text
lib/
├── app.dart
├── main.dart
├── core/
│   ├── navigation/       # Shell responsive, navigation et sélection d’espace local
│   ├── routes/           # Routes GetX
│   ├── theme/            # Thème et palette
│   ├── widgets/          # Composants communs
│   └── workspace/        # Espaces commerçants temporaires actuels
└── modules/
    ├── home/             # Tableau de bord
    ├── products/         # Catalogue, catégories et photo produit
    ├── stock/            # Mouvements et alertes
    ├── cashier/          # Caisse et panier
    ├── sales/            # Validation, ventes et reçus
    ├── clients/          # Clients, dettes et remboursements
    ├── expenses/         # Dépenses
    └── shared/           # Écrans provisoires
```

Quand l’intégration des données commencera, les contrôleurs GetX devront utiliser des dépôts par domaine. Ces dépôts coordonneront Drift/SQLite et Dio ; les règles d’autorisation et la validation définitive des ventes resteront côté serveur.

## Prérequis

- Flutter et Dart compatibles avec la contrainte du SDK définie dans `pubspec.yaml`.
- Pour lancer sur Linux desktop : outils de compilation Flutter desktop et bibliothèques de développement GTK requis par Flutter.

## Démarrer l’application

À la racine du projet :

```sh
flutter pub get
flutter run
```

Pour lancer explicitement la version Linux desktop :

```sh
flutter run -d linux
```

## Vérification et tests

```sh
flutter analyze
flutter test
```

Les tests du backend seront ajoutés dans son propre projet Python lorsque l’API sera créée :

```sh
pytest
```

## Principes métier

- Toutes les données doivent être isolées par boutique côté serveur.
- Une vente à crédit doit être rattachée à un client.
- Une vente validée doit mettre à jour le stock et, si nécessaire, le solde dû dans une seule transaction.
- Un remboursement ne peut pas dépasser le solde restant.
- Les ventes, remboursements et mouvements de stock doivent conserver un historique auditable.
- Les montants sont exprimés en francs CFA (FCFA).
