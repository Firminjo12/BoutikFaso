# Backend Boutik Faso

API Python destinée à la gestion interne des boutiques : produits, stock, ventes, clients, crédits, remboursements et dépenses. Ce service ne gère pas de commandes en ligne.

## Stack

- FastAPI et Pydantic pour l’API REST et la validation.
- SQLAlchemy 2 et Alembic pour l’accès à PostgreSQL et les migrations.
- PostgreSQL comme base centrale.
- PyJWT et `pwdlib[argon2]` comme briques de sécurité.
- Docker Compose pour lancer l’API, qui se connecte à une instance PostgreSQL déjà disponible.

L’application FastAPI expose les routes de santé, d’authentification, de boutiques,
de catalogue, de stock, de ventes, de clients, de crédits, de dépenses, de rapports et de synchronisation hors ligne.

## Démarrage local avec Docker

```sh
cd backend
cp .env.example .env
# Pour Docker, DATABASE_URL doit pointer vers une adresse accessible depuis le conteneur.
docker compose up --build
```

L’API écoute sur `http://127.0.0.1:8000`. Sa documentation interactive est disponible sur `http://127.0.0.1:8000/docs`.

- `GET /api/v1/health/live` confirme que le processus API répond.
- `GET /api/v1/health/ready` vérifie aussi la connexion à PostgreSQL.

Les secrets présents dans `.env.example` sont réservés au développement local. Remplacer toutes les valeurs avant tout déploiement.
Compose ne contient aucun service PostgreSQL et ne crée aucun volume de base de données.
La configuration accepte soit `DATABASE_URL`, soit `DB_HOST`, `DB_PORT`, `DB_NAME`,
`DB_USER` et `DB_PASSWORD` dans `.env`.

## Comptes et boutiques

- `POST /api/v1/auth/register` crée le compte et sa première boutique (mot de passe d’au moins 12 caractères).
- `POST /api/v1/auth/login` accepte les champs OAuth2 `username` (e-mail ou téléphone) et `password` en formulaire.
- `POST /api/v1/auth/refresh` renouvelle et fait tourner les jetons.
- `POST /api/v1/auth/logout` révoque la session courante.
- `GET /api/v1/me` et `GET /api/v1/me/merchants` retournent le compte et ses boutiques accessibles.
- `POST /api/v1/merchants` crée une boutique supplémentaire pour le compte connecté.
- `POST /api/v1/merchants/{id}/switch` sélectionne une boutique et renvoie une nouvelle paire de jetons.

Les routes protégées attendent `Authorization: Bearer <access_token>`. Les jetons d’accès
durent 15 minutes et sont vérifiés contre la session en base à chaque requête ; les
jetons de renouvellement sont enregistrés sous forme de hash SHA-256 et
peuvent être révoqués. Les requêtes métier doivent utiliser `require_active_merchant`
et vérifier le rôle demandé pour isoler chaque boutique côté serveur.

## Catalogue et stock

Les routes catalogue sont sous `/api/v1/merchants/{merchant_id}`. Elles permettent
de gérer les catégories et les produits, de rechercher/filtrer le catalogue, et
d’archiver les fiches sans supprimer l’historique. L’import CSV accepte jusqu’à 500
produits et les colonnes `name`, `sale_price` (obligatoires), puis `category`, `sku`,
`purchase_price`, `stock_alert_threshold` et `initial_quantity` (optionnelles).
Un stock initial crée un mouvement d’entrée au lieu d’écrire une quantité directement.

Les photos acceptent JPEG, PNG et WebP jusqu’à 5 Mo. Le contenu est décodé et vérifié,
puis stocké dans le volume privé `product-images`. Leur lecture exige une session et
l’accès à la boutique concernée. Le chemin est configurable avec `PRODUCT_IMAGES_DIR`.

`GET /api/v1/merchants/{id}/stock/summary` et `/stock/movements` exposent le résumé et
l’historique. Les mouvements manuels acceptés sont `entry`, `exit` et `loss` ; une
sortie ou une perte est refusée si le stock disponible est insuffisant. La quantité
disponible est calculée depuis le journal des mouvements.

## Clients, caisse et crédits

`/api/v1/merchants/{merchant_id}/clients` gère la liste, la recherche, la fiche,
l’archivage et le solde de crédit calculé du client. Les ventes sont créées avec
`POST /api/v1/merchants/{merchant_id}/sales` ; les prix et totaux sont calculés par
le serveur à partir du catalogue. Chaque demande doit envoyer un en-tête
`Idempotency-Key` unique. Les lignes de vente, la vente, les sorties de stock et
l’éventuelle dette client sont validées dans une seule transaction.

Le champ `paid_amount` permet d’enregistrer un paiement partiel immédiat ; le reste
est inscrit au crédit et exige un client. Sans ce champ, les modes espèces/mobile
sont considérés comme réglés en totalité, tandis que `credit` crée une vente entièrement
à crédit. Les reçus sont lisibles via `/sales/{id}/receipt`.

`GET /credits` et `/clients/{id}/credit-ledger` affichent les soldes et écritures.
`POST /clients/{id}/repayments` enregistre un remboursement partiel ou total. Cette
route exige aussi `Idempotency-Key` ; `X-Device-ID` distingue les appareils pour les
reprises après coupure réseau.

## Dépenses, tableau de bord et rapports

Les dépenses sont isolées par boutique sous `/api/v1/merchants/{merchant_id}/expenses` :
`GET` liste et filtre, `POST` crée (propriétaire ou gestionnaire), `PATCH/{expense_id}`
modifie et `DELETE/{expense_id}` annule sans effacer l’historique. `GET /categories`
retourne les catégories encore utilisées. Les filtres de période acceptent `today`,
`week`, `month`, ou `start_date=YYYY-MM-DD&end_date=YYYY-MM-DD`; les dates sont
interprétées dans le fuseau de la boutique et les deux bornes sont inclusives.

- `GET /api/v1/merchants/{id}/dashboard?period=today` fournit les indicateurs et les
  produits les plus vendus.
- `GET /api/v1/merchants/{id}/reports/summary`, `/sales`, `/profit`, `/expenses` et
  `/stock` fournissent les rapports filtrables.
- `GET /api/v1/merchants/{id}/reports/export?report=sales|profit|expenses|stock`
  renvoie un CSV UTF-8 avec BOM.

Les définitions sont les suivantes : ventes nettes = total des ventes terminées après
remises ; encaissé = paiements immédiats des ventes + remboursements de crédits ;
crédit créé/remboursé = écritures correspondantes du journal ; crédit restant = solde
du journal à la fin de la période ; bénéfice brut estimé = montant des lignes vendues
moins leur coût d’achat historique et la remise de vente ; résultat estimé = bénéfice
brut estimé moins dépenses non annulées. Ce résultat est une estimation de gestion,
pas un bénéfice comptable certifié. Les périodes utilisent le fuseau IANA de la boutique.

## Stockage local et synchronisation hors ligne (Étape 5)

L'API de synchronisation permet aux appareils mobiles et caisses de fonctionner sans
réseau, d'empiler leurs opérations localement et de les envoyer au serveur dès le
retour de la connexion :

- `POST /api/v1/merchants/{merchant_id}/sync/push` (et `/api/v1/sync/push`) :
  Accepte un lot d'opérations hors ligne (`sale.create`, `credit.repayment`,
  `expense.create`, `client.create`, `client.update`, `product.create`, `product.update`,
  `category.create`, `stock.movement`).
  - Chaque opération dispose d'un identifiant `operation_id`, d'une clé d'idempotence
    `idempotency_key` et de son horodatage local `occurred_at`.
  - **Idempotence stricte** : si une opération a déjà été traitée pour le couple
    `(device_id, idempotency_key)`, le serveur renvoie le résultat mis en cache avec le
    statut `duplicate` sans dupliquer l'opération ni le stock.
  - **Tolérance aux erreurs partielles** : chaque opération s'exécute dans un point de
    sauvegarde (savepoint) dédié. Un rejet ou un conflit sur une opération n'annule pas
    les autres opérations valides du lot, permettant au client de vider sa file locale
    des opérations confirmées tout en conservant les brouillons en erreur.
  - **Détection des conflits** : pour les mises à jour de fiches (`client.update`,
    `product.update`), le champ optionnel `client_updated_at` vérifie que la fiche n'a
    pas été modifiée de manière concurrente sur le serveur. En cas de conflit, le statut
    `conflict` est renvoyé avec les métadonnées actuelles du serveur.
  - **Préservation des événements métiers** : les ventes et remboursements sont enregistrés
    avec leurs lignes, déductions de stock et écritures de crédit de manière atomique.

- `GET /api/v1/merchants/{merchant_id}/sync/pull?cursor=...&limit=...` (et `/api/v1/sync/pull`) :
  Synchronisation descendante incrémentale. Fournit toutes les créations et mises à jour
  (catégories, produits avec stock calculé, clients avec solde de crédit, ventes,
  remboursements, dépenses et mouvements de stock) survenues depuis la valeur du
  `cursor` ISO 8601. Renvoie `next_cursor` pour le prochain appel et `has_more`.

- `GET /api/v1/merchants/{merchant_id}/sync/status` (et `/api/v1/sync/status`) :
  Retourne l'état de synchronisation de la boutique, le dernier horodatage de synchronisation,
  le nombre total d'opérations et le nombre d'opérations associées à l'appareil (`device_id`
  ou en-tête `X-Device-ID`).

L’étape 1 ajoute `audit_logs`. Comme le reste du schéma existe déjà, appliquer seulement
la migration additive (elle ne recrée pas les autres tables) :

```sh
alembic upgrade head
```

Cette opération est à lancer explicitement contre la base existante ; elle n’a pas été
exécutée par l’initialisation du backend.

## Sauvegarde PostgreSQL

Le script `scripts/backup_postgres.sh` crée un fichier `pg_dump` protégé par les
permissions du compte local (mode `0600`) dans `backend/backups/`. Il lit les paramètres
`DB_*` de `.env` et ne modifie pas la base. Il peut être planifié par cron après avoir
vérifié manuellement qu’une sauvegarde peut être restaurée.

```sh
./scripts/backup_postgres.sh
```

Des exemples de service et minuteur systemd quotidien sont dans `ops/systemd/`. Avant
de les installer sur un VPS, remplacer le chemin et l’utilisateur dans le service,
puis vérifier la restauration d’une sauvegarde.

## Modèles et migrations

Les modèles SQLAlchemy sont dans `app/models/entities.py`. Le schéma SQL initial est
documenté dans `sql/schema.sql`. La révision Alembic de l’étape 1 ajoute seulement
`audit_logs` aux tables existantes ; elle n’est pas exécutée automatiquement.

## Démarrage Python sans Docker

Python 3.12 ou plus récent et un PostgreSQL accessible sont requis. Le projet ne crée
ni ne démarre la base ; il se connecte uniquement à l’adresse fournie dans `.env`.

```sh
cd backend
cp .env.example .env
python -m venv .venv
source .venv/bin/activate
python -m pip install -e '.[dev]'
uvicorn app.main:app --reload
```

## Structure

```text
backend/
├── app/
│   ├── api/v1/endpoints/  # Routes HTTP versionnées
│   ├── core/              # Configuration et sécurité
│   ├── db/                # Base SQLAlchemy et sessions
│   ├── models/            # Modèles ORM
│   └── main.py            # Création de l’application FastAPI
├── Dockerfile
├── alembic.ini
├── docker-compose.yml
├── migrations/            # Révisions Alembic
└── pyproject.toml
```

Les routes métier utilisent les dépendances d’authentification et de sélection de
boutique afin de vérifier l’appartenance à la boutique pour chaque requête. Les sessions
SQLAlchemy sont limitées à une requête.
