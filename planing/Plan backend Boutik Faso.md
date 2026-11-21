# Plan backend — Boutik Faso

## 1. Objectif et périmètre

Connecter les écrans Flutter existants à un service backend afin que plusieurs commerçants puissent gérer leurs boutiques avec des données séparées, accessibles depuis leurs appareils autorisés.

Le backend sert à la gestion interne : catalogue, stock, ventes, ventes à crédit, remboursements, dépenses et rapports. **Il ne gère ni catalogue public, ni panier client en ligne, ni commande en ligne, ni livraison.**

Le plan prend en compte les écrans visibles dans le code et les maquettes : tableau de bord, caisse/panier, confirmation et reçu, produits/catégories, stock/mouvements, clients, dettes/remboursements, dépenses, rapports, paramètres et synchronisation/hors ligne.

## 2. Principes de conception

- **Un commerçant = un espace de données isolé.** Chaque donnée métier porte l’identifiant du commerçant. Le serveur déduit l’accès depuis la session authentifiée et vérifie l’appartenance à cet espace à chaque requête.
- **Un utilisateur peut être membre d’un ou plusieurs espaces.** Il sélectionne la boutique active après connexion. Cela permet plus tard à un propriétaire d’inviter un caissier ou un gestionnaire sans mélanger leurs données.
- **Le serveur est la source de vérité synchronisée.** L’application garde un stockage local pour fonctionner sans réseau et envoie ses opérations en attente au retour de la connexion.
- **Les opérations financières et de stock sont traçables.** Ventes, paiements, remboursements et mouvements de stock sont enregistrés comme opérations datées ; une correction passe par une annulation ou une opération compensatrice plutôt que par l’effacement silencieux de l’historique.
- **Le backend ne réalise pas de vente en ligne.** Une vente est créée par le commerçant depuis la caisse de l’application.

## 3. Architecture cible proposée

```text
Application Flutter / GetX
        │ HTTPS — API REST versionnée
        ▼
API backend ── authentification et autorisations par commerçant
        │
        ├── Base relationnelle : comptes, produits, ventes, dettes, stock, dépenses
        ├── Stockage de fichiers : photos des produits et logo de boutique
        └── Journal de synchronisation : opérations hors ligne et reprises idempotentes
```

Choix recommandés à valider avant le démarrage : API REST, base relationnelle compatible transactions, stockage objet privé pour les images et jetons d’accès de courte durée renouvelables. Le fournisseur précis pourra être choisi selon l’hébergement, le budget et les besoins de maintenance ; ce plan ne dépend pas d’un fournisseur particulier.

## 4. Modèle de données métier

Toutes les tables métier ci-dessous sont rattachées à `merchant_id` et indexées en conséquence.

| Entité | Données principales | Utilisée par |
|---|---|---|
| `users` | identité et coordonnées de connexion | Connexion, paramètres |
| `merchants` | nom, téléphone, adresse, devise, fuseau horaire | Boutique, reçus, espace actif |
| `merchant_memberships` | utilisateur, commerçant, rôle, statut | Séparation des données, équipe |
| `products` | nom, catégorie, SKU, prix d’achat/vente, seuil, état | Catalogue, caisse, stock, rapports |
| `product_images` | chemin privé, type, taille, ordre | Formulaire produit, catalogue, caisse |
| `categories` | nom et statut | Catalogue, filtres de caisse |
| `stock_movements` | produit, type, quantité, date, auteur, note, référence | Stock, ventes, historique |
| `clients` | nom, téléphone, adresse et indicateurs calculés | Clients, dettes, caisse |
| `sales` | numéro, date, totaux, mode de paiement, statut, auteur | Caisse, reçu, dashboard, rapports |
| `sale_lines` | produit, libellé figé, quantité, prix et coût au moment de la vente | Reçu, historique, marge |
| `credit_ledger_entries` | client, vente ou remboursement, montant signé, date, mode, auteur | Dettes, fiche client, remboursements |
| `expenses` | libellé, catégorie, montant, date, note, auteur | Dépenses, dashboard, rapports |
| `sync_operations` | identifiant client unique, type, résultat, horodatage | Mode hors ligne, reprise après erreur |

Les prix et montants utilisent des entiers en FCFA. La ligne de vente conserve le nom du produit, le prix de vente et le prix d’achat au moment de l’opération afin que les reçus et les marges historiques ne changent pas lorsque la fiche produit est modifiée.

## 5. Règles métier à faire appliquer par le serveur

### Produits et stock

- Le SKU est unique dans un espace commerçant lorsqu’il est renseigné.
- Un mouvement d’entrée, de sortie ou de perte doit référencer un produit du même commerçant et avoir une quantité positive.
- Une sortie ne peut pas créer un stock négatif, sauf décision produit explicite ultérieure.
- La suppression d’un produit ayant un historique de vente ou de mouvement est remplacée par son archivage.
- Les photos sont privées à l’espace commerçant ; l’API fournit un accès contrôlé ou une URL signée à durée limitée.

### Ventes et paiements à crédit

- La validation d’une vente, ses lignes, la sortie de stock et, le cas échéant, l’écriture de dette sont enregistrées dans une seule transaction serveur.
- Une vente à crédit exige un client. Le compte client est débité du reste dû ; un paiement immédiat n’augmente pas la dette.
- Un remboursement ne peut pas dépasser le solde dû au moment de sa validation.
- Les remboursements partiels créent des écritures distinctes et datées ; le solde restant est calculé à partir du journal de crédit.
- Une clé d’idempotence empêche qu’un double appui ou une nouvelle tentative réseau crée deux ventes ou deux remboursements.
- Les corrections financières utilisent des écritures d’annulation/rectification conservant l’audit.

### Accès et rôles

Rôles initiaux proposés :

- **Propriétaire** : gère la boutique, ses membres et toutes les opérations.
- **Gestionnaire** : gère catalogue, stock, ventes, clients et dépenses.
- **Caissier** : enregistre les ventes et consulte les produits/clients nécessaires à la caisse.
- **Gestionnaire de stock** : gère le catalogue et les mouvements de stock.

Les rôles peuvent être simplifiés au lancement si l’interface actuelle ne prévoit pas encore la gestion d’équipe. L’isolation entre commerçants reste obligatoire quel que soit le rôle.

## 6. API à prévoir par groupe d’écrans

Toutes les routes sont sous `/api/v1`. Les exemples ci-dessous sont indicatifs et nécessitent une session authentifiée.

| Écran / module | Routes principales |
|---|---|
| Connexion / sélection de boutique | `POST /auth/register`, `POST /auth/login`, `POST /auth/refresh`, `POST /auth/logout`, `GET /me/merchants`, `POST /merchants`, `POST /merchants/{id}/switch` |
| Tableau de bord | `GET /merchants/{id}/dashboard?period=today`, `GET /merchants/{id}/reports/summary` |
| Produits / catégories | `GET, POST /merchants/{id}/products`, `GET, PATCH, DELETE /merchants/{id}/products/{productId}`, routes CRUD `/categories`, `POST /products/{productId}/images` |
| Caisse / panier | `GET /products?query=&category=&available=true`, `POST /sales/preview`, `POST /sales` |
| Vente / reçu | `GET /sales/{saleId}`, `GET /sales/{saleId}/receipt`, `POST /sales/{saleId}/void` avec autorisation renforcée |
| Stock | `GET /stock/summary`, `GET /stock/movements`, `POST /stock/movements`, `GET /products/{productId}/stock` |
| Clients | `GET, POST /clients`, `GET, PATCH /clients/{clientId}`, `GET /clients/{clientId}/transactions` |
| Dettes / remboursements | `GET /credits?status=open`, `GET /clients/{clientId}/credit-ledger`, `POST /clients/{clientId}/repayments` |
| Dépenses | `GET, POST /expenses`, `PATCH, DELETE /expenses/{expenseId}` selon règles d’audit |
| Rapports | `GET /reports/sales`, `GET /reports/profit`, `GET /reports/stock`, filtres de dates et export |
| Paramètres | `GET, PATCH /merchants/{id}`, routes membres/invitations, préférences et sauvegarde |
| Hors ligne / synchronisation | `POST /sync/push`, `GET /sync/pull?cursor=...`, `GET /sync/status` |

Les routes de lecture acceptent pagination, tri et filtres. Les réponses d’erreur ont un format commun : code métier stable, message lisible et détails de validation exploitables par Flutter.

## 7. Plan de réalisation par étapes

### Étape 0 — Décisions produit et contrat de données

- Confirmer si un compte peut gérer plusieurs boutiques et si le commerçant peut avoir des employés.
- Fixer les rôles du premier lancement, les règles de suppression/annulation et le format de reçu.
- Documenter les modèles de requête/réponse, codes d’erreur, pagination et conventions de dates.
- Définir les données de démonstration actuelles et leur migration ou leur retrait.

**Livrable :** contrat d’API versionné et règles métier approuvées.

### Étape 1 — Fondations backend et séparation des commerçants

- Créer les comptes, connexions, renouvellement et révocation de sessions.
- Créer boutique, appartenance et sélection de boutique active.
- Imposer l’autorisation au niveau serveur et ajouter des journaux d’audit.
- Ajouter migrations de base, sauvegardes et environnements de développement/préproduction.

**Écrans raccordés :** connexion et paramètres/profil commerçant (à construire, absents des pages actuelles).

### Étape 2 — Catalogue et stock

- Implémenter catégories, produits, recherche, filtres, archivage et import initial.
- Ajouter téléversement sécurisé des photos.
- Implémenter mouvements d’entrée/sortie/perte et calcul cohérent du stock.
- Remplacer les données en mémoire des écrans Produits et Stock par les appels API.

**Critère de sortie :** deux comptes commerçants ne peuvent ni voir ni modifier les produits ou mouvements de l’autre.

### Étape 3 — Clients, caisse et ventes à crédit

- Implémenter clients et historique d’activité.
- Valider une vente atomiquement avec ses lignes et mouvements de stock.
- Appliquer les règles de paiement espèces/mobile/crédit et produire le numéro de reçu.
- Implémenter grand livre des crédits, remboursements partiels et solde restant.
- Raccorder Caisse, Panier, Confirmation, Reçu, Clients et Dettes.

**Critère de sortie :** vente répétée après une coupure ne crée pas de doublon ; le crédit et le stock restent cohérents.

### Étape 4 — Dépenses, dashboard et rapports

- Raccorder les dépenses avec catégories et périodes.
- Construire les agrégats du tableau de bord côté serveur, avec périodes et fuseau horaire explicites.
- Définir précisément chiffre d’affaires, bénéfice estimatif, dettes et remboursements.
- Raccorder les filtres et exports des rapports.

**Critère de sortie :** les totaux affichés correspondent aux ventes, mouvements, remboursements et dépenses stockés.

### Étape 5 — Stockage local et synchronisation hors ligne

- Remplacer les profils temporaires en mémoire par une base locale persistante par appareil.
- Enregistrer chaque opération hors ligne dans une file avec UUID et clé d’idempotence.
- Synchroniser envoi/réception avec curseur de reprise, indicateur d’état et réessais limités.
- Définir les conflits : les ventes et remboursements sont des événements à conserver ; les éditions concurrentes de fiches sont signalées ou résolues selon une règle explicite.
- Gérer les erreurs partielles sans perdre le brouillon ou la file locale.

**Écrans raccordés :** Paramètres et Synchronisation/Hors ligne des maquettes.

### Étape 6 — Préproduction et lancement

- Vérifier l’isolation entre commerçants et les permissions par rôle.
- Vérifier les scénarios de vente, dette, remboursement, stock négatif et doublon réseau.
- Tester restauration des sauvegardes, migrations et reprise après indisponibilité réseau.
- Mettre en place supervision, alertes, journaux sans données sensibles et procédure d’assistance.
- Déployer d’abord en préproduction avec comptes pilotes, puis activer progressivement la production.

## 8. Adaptations nécessaires dans l’application Flutter

- Introduire une couche `ApiClient` et des dépôts par domaine (`ProductsRepository`, `SalesRepository`, etc.) au lieu d’accéder directement aux listes GetX.
- Garder les contrôleurs GetX responsables de l’état d’écran, pas des règles de sécurité ni de la validation finale des ventes.
- Ajouter les états chargement, erreur, hors ligne, synchronisation en attente et reprise.
- Ajouter connexion, récupération de session, création/sélection de boutique et éventuellement invitation d’employés.
- Remplacer les profils temporaires ajoutés localement : ils ne constituent ni des comptes ni une frontière de sécurité serveur.
- Garder l’image locale dans le cache pendant le mode hors ligne, puis téléverser et remplacer le chemin local par une référence serveur.

## 9. Dépendances et risques

- La synchronisation hors ligne dépend du contrat API, des identifiants stables et des clés d’idempotence ; elle vient après les opérations en ligne.
- Les ventes et remboursements doivent être transactionnels afin d’éviter les écarts entre stock, reçu et dette.
- L’isolation des données doit être contrôlée côté serveur à chaque requête, même si Flutter masque déjà les autres boutiques.
- Les photos requièrent limites de taille/type, contrôle du contenu et stockage privé.
- Les statistiques dépendent de définitions comptables explicites ; elles ne doivent pas être présentées comme un bénéfice comptable certifié.
- Le choix de l’hébergement, du pays/région, du budget et de la politique de conservation doit précéder la mise en production.

## 10. Ordre recommandé pour le premier MVP connecté

1. Authentification et espace commerçant, avec isolation serveur.
2. Catalogue, catégories, photo et stock.
3. Caisse, vente, reçu et déduction du stock.
4. Clients, ventes à crédit et remboursements.
5. Dépenses et tableau de bord.
6. Rapports, rôles d’équipe et synchronisation hors ligne complète.

Ce séquencement permet de valider d’abord l’isolation multi-commerçant et le parcours de gestion de vente avant d’investir dans les rapports et la synchronisation avancée.
