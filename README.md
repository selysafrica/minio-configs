# minio-configs

Configuration de déploiement MinIO sur VPS avec Docker, Nginx et SSL.

## Prérequis

- Docker + Docker Compose
- Nginx
- MakeFile
- Certbot (`apt install certbot python3-certbot-nginx`)
- Deux sous-domaines DNS pointant vers le VPS :
  - un pour la **console web** (ex: `minio.exemple.com`)
  - un pour l'**API S3** (ex: `s3.exemple.com`)

---

## Installation

### 1. Cloner le repo

```bash
git clone <url-du-repo> minio-configs
cd minio-configs
```

### 2. Configurer les variables d'environnement

```bash
cp .env.example .env
nano .env
```

| Variable | Description | Exemple |
|---|---|---|
| `MINIO_ROOT_USER` | Nom d'utilisateur admin | `minioadmin` |
| `MINIO_ROOT_PASSWORD` | Mot de passe admin (min. 8 caractères) | `motdepasse123` |
| `MINIO_SERVER_URL` | URL publique de l'API S3 | `https://s3.exemple.com` |
| `MINIO_BROWSER_REDIRECT_URL` | URL publique de la console web | `https://minio.exemple.com` |
| `PRIVATE_BUCKET` | Nom du bucket privé | `private` |
| `PUBLIC_BUCKET` | Nom du bucket public | `public` |

### 3. Adapter la configuration Nginx

Ouvrez `nginx/minio.conf` et remplacez les `server_name` par vos domaines :

```nginx
# Console web
server_name minio.exemple.com;   # ← votre domaine console

# API S3
server_name s3.exemple.com;      # ← votre domaine API
```

### 4. Déploiement complet

```bash
make setup
```

Cette commande enchaîne automatiquement :

1. Création du dossier `data/`
2. Installation de la config Nginx
3. Génération des certificats SSL via Certbot
4. Démarrage des conteneurs Docker
5. Création et configuration des buckets

> Pour spécifier l'email Certbot : `make setup CERTBOT_EMAIL=you@exemple.com`

---

## Commandes disponibles

```bash
make setup      # Installation complète (première fois)
make deploy     # Démarrer MinIO
make stop       # Arrêter MinIO
make restart    # Redémarrer MinIO
make logs       # Afficher les logs en temps réel
make status     # État des conteneurs
make buckets    # (Re)créer et configurer les buckets
make ssl        # (Re)générer les certificats SSL
make clean      # Supprimer toutes les données (DESTRUCTIF)
```

---

## Architecture

```
                    Internet
                       │
          ┌────────────┴────────────┐
          │                         │
   minio.exemple.com          s3.exemple.com
      (Console Web)              (API S3)
          │                         │
          └────────────┬────────────┘
                 Nginx + SSL (443)
                       │
          ┌────────────┴────────────┐
          │                         │
       :9001                     :9002
     (Console)                  (API S3)
          └────────────┬────────────┘
                  MinIO (Docker)
```

---

## Buckets

| Bucket | Accès lecture | Accès écriture | Usage recommandé |
|---|---|---|---|
| `private` | Authentification requise | Authentification requise | Données sensibles, fichiers internes |
| `public` | **Libre (URL directe)** | Authentification requise | Assets statiques, images, fichiers publics |

### Accéder à un fichier public

```
https://s3.exemple.com/<PUBLIC_BUCKET>/<nom-du-fichier>
```

### Console d'administration

```
https://minio.exemple.com
```

---

## Mise à jour

```bash
git pull
make restart
```

Si des modifications locales bloquent le `git pull` :

```bash
# Mettre de côté les fichiers modifiés localement
git stash -- scripts/init-buckets.sh

git pull

# Récupérer les modifications locales
git stash pop

make buckets
```

> Le fichier `.env` n'est jamais écrasé par `git pull` car il est dans `.gitignore`.
