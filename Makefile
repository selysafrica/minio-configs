NGINX_CONF_SRC  = nginx/minio.conf
NGINX_CONF_DEST = /etc/nginx/sites-available/minio.conf
NGINX_ENABLED   = /etc/nginx/sites-enabled/minio.conf
CERTBOT_EMAIL   ?= karimadio40@gmail.com

.PHONY: all setup deploy stop restart logs status nginx-setup ssl buckets clean

all: deploy

# Première installation complète sur un nouveau VPS
setup: _check-env _create-data-dir nginx-setup ssl deploy buckets
	@echo "==> MinIO déployé et accessible."

# Démarrer les conteneurs
deploy: _check-env
	docker compose up -d
	@echo "==> Conteneurs démarrés."

# Arrêter les conteneurs
stop:
	docker compose down

# Redémarrer
restart:
	docker compose restart

# Voir les logs en temps réel
logs:
	docker compose logs -f

# État des conteneurs
status:
	docker compose ps

# Installer la config Nginx et activer le site
nginx-setup:
	@echo "==> Installation de la configuration Nginx..."
	sudo cp $(NGINX_CONF_SRC) $(NGINX_CONF_DEST)
	sudo ln -sf $(NGINX_CONF_DEST) $(NGINX_ENABLED)
	sudo nginx -t
	sudo systemctl reload nginx
	@echo "==> Nginx configuré."

# Générer les certificats SSL via Certbot
ssl:
	@echo "==> Génération des certificats SSL..."
	sudo certbot --nginx \
		-d minio.selys.app \
		-d s3.selys.app \
		--non-interactive \
		--agree-tos \
		--email $(CERTBOT_EMAIL)
	sudo systemctl reload nginx
	@echo "==> SSL activé."

# Créer et configurer les buckets privé et public
buckets: _check-env
	@echo "==> Configuration des buckets..."
	chmod +x scripts/init-buckets.sh
	bash scripts/init-buckets.sh

# Supprimer les données MinIO (DESTRUCTIF)
clean:
	@echo "ATTENTION : ceci supprime toutes les données MinIO."
	@read -p "Confirmer ? [y/N] " ans && [ "$$ans" = "y" ]
	docker compose down -v
	sudo rm -rf ./data

# --- cibles internes ---

_check-env:
	@test -f .env || (echo "ERREUR : fichier .env manquant. Copiez .env.example vers .env et remplissez-le." && exit 1)

_create-data-dir:
	mkdir -p data
