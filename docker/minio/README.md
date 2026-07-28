# 🪣 MinIO - selys.app

Déploiement de MinIO avec Docker, Nginx reverse proxy et Certbot SSL sur VPS.

## 📁 Structure

```
minio/
├── docker-compose.yml          # Configuration Docker
├── .env                        # Variables d'environnement
├── Makefile                    # Commandes de gestion
├── README.md                   # Ce fichier
├── data/                       # Données MinIO (persistantes)
├── certs/                      # Certificats SSL
├── nginx/
│   ├── s3.selys.app.conf       # Config Nginx API S3
│   └── minio.selys.app.conf    # Config Nginx Console
└── scripts/
    └── setup-buckets.sh        # Création des buckets
```

## 🚀 Déploiement rapide

### 1. Copier sur le VPS

```bash
scp -r minio/ user@votre-vps:/opt/
ssh user@votre-vps
cd /opt/minio
```

### 2. Configurer les variables

```bash
nano .env
```
Modifiez au minimum :
- `MINIO_ROOT_PASSWORD` — mot de passe admin
- `LETSENCRYPT_EMAIL` — email pour Let's Encrypt

### 3. Lancer le déploiement complet

```bash
make setup
```

Cette commande fait :
1. Installation des configs Nginx
2. Démarrage de MinIO
3. Création des buckets `public` et `private`

### 4. Générer les certificats SSL

```bash
make ssl
```

### 5. Activer HTTPS dans Nginx

```bash
make update-ssl-nginx
```

## 📋 Commandes disponibles

| Commande | Description |
|----------|-------------|
| `make help` | Affiche l'aide |
| `make build` | Build les images Docker |
| `make up` | Démarre MinIO |
| `make down` | Arrête MinIO |
| `make restart` | Redémarre MinIO |
| `make logs` | Affiche les logs |
| `make status` | Statut des conteneurs |
| `make setup` | Déploiement complet (Nginx + MinIO + buckets) |
| `make buckets` | Crée les buckets public/private |
| `make nginx-setup` | Installe les configs Nginx |
| `make nginx-remove` | Supprime les configs Nginx |
| `make ssl` | Génère les certificats SSL |
| `make certbot-renew` | Renouvelle les certificats |
| `make update-ssl-nginx` | Active HTTPS dans Nginx |
| `make clean` | Supprime tout (conteneurs + données) |
| `make prune` | Nettoie les images Docker |

## 🔗 Accès

| Service | URL | Port interne |
|---------|-----|-------------|
| API S3 | `https://s3.selys.app` | `9001` (hôte) → `9000` (conteneur) |
| Console | `https://minio.selys.app` | `9002` (hôte) → `9001` (conteneur) |

## 📦 Buckets par défaut

| Bucket | Accès | Description |
|--------|-------|-------------|
| `public` | Lecture publique | Fichiers accessibles sans authentification |
| `private` | Restreint | Fichiers nécessitant une authentification |

## 🔐 Sécurité

- Changez impérativement `MINIO_ROOT_PASSWORD` dans `.env`
- Les certificats SSL sont gérés par Certbot / Let's Encrypt
- Le bucket `private` refuse tout accès anonyme
- Le bucket `public` autorise uniquement la lecture (`s3:GetObject`)

## 🔄 Renouvellement SSL

Certbot installe un cron automatique. Pour forcer le renouvellement :

```bash
make certbot-renew
```

## 🛠️ Dépannage

### MinIO ne démarre pas
```bash
make logs
```

### Problème de permissions
```bash
sudo chown -R $USER:$USER data/ certs/
```

### Redémarrage complet
```bash
make clean
make setup
make ssl
make update-ssl-nginx
```
