# ============================================
# Makefile MinIO - selys.app
# ============================================

.PHONY: help setup init-alias license deploy down restart logs status buckets nginx-setup nginx-remove ssl clean

# Chargement des variables d'environnement
include .env
export

# Couleurs
GREEN  := \033[0;32m
YELLOW := \033[1;33m
CYAN   := \033[0;36m
RED    := \033[0;31m
NC     := \033[0m

DOMAIN_API     := $(API_DOMAIN)
DOMAIN_CONSOLE := $(CONSOLE_DOMAIN)
CONTAINER_NAME := aistor-server
ALIAS_NAME := selysafrica
LICENSE_PATH := $$HOME/aistro/minio/minio.license/minio.license
NGINX_AVAILABLE_DIR := /etc/nginx/sites-available
NGINX_ENABLED_DIR   := /etc/nginx/sites-enabled


help: ## Affiche cette aide
	@echo ""
	@echo -e "$(CYAN)╔════════════════════════════════════════════════════════════╗$(NC)"
	@echo -e "$(CYAN)║           MinIO AIstro - Commandes disponibles             ║$(NC)"
	@echo -e "$(CYAN)╚════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(CYAN)%-18s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""


setup: ## Installe le client mc (MinIO Client)
	@echo -e "$(YELLOW)📦 Téléchargement et installation de mc...$(NC)"
	curl --progress-bar -L https://dl.min.io/aistor/mc/release/linux-amd64/mc -o /tmp/mc
	chmod +x /tmp/mc
	sudo mv /tmp/mc /usr/local/bin/mc
	@echo -e "$(GREEN)✅ mc installé :$(NC)"
	mc --version
 
deploy: ## Lance le conteneur MinIO AIstro
	@echo -e "$(YELLOW)🚀 Démarrage de MinIO AIstro...$(NC)"
	docker run -dt \
		-p $(MINIO_API_PORT):9000 \
		-p $(MINIO_CONSOLE_PORT):9001 \
		-e MINIO_ROOT_USER=$(MINIO_ROOT_USER)
		-e MINIO_ROOT_PASSWORD=$(MINIO_ROOT_PASSWORD)
		-v $$HOME/aistro/minio/data:/mnt/data/aistro \
		-v $(LICENSE_PATH):/minio.license \
		-v $$HOME/aistro/minio/certs:/etc/aistro/minio/certs \
		--name "$(CONTAINER_NAME)" \
		--restart unless-stopped \
		quay.io/minio/aistor/minio:latest \
		minio server /mnt/data/aistro \
			--license /minio.license \
			--console-address ":9011"
	@echo -e "$(GREEN)✅ MinIO démarré !$(NC)"
	@echo -e "$(GREEN)   • API     → http://localhost:$(MINIO_API_PORT)$(NC)"
	@echo -e "$(GREEN)   • Console → http://localhost:$(MINIO_CONSOLE_PORT)$(NC)"


init-alias:
	@echo -e "$(YELLOW)📄 Init Alias...$(NC)"
	mc alias set $(ALIAS_NAME) http://localhost:$(MINIO_API_PORT) $(MINIO_ROOT_USER) $(MINIO_ROOT_PASSWORD)

license:
	@echo -e "$(YELLOW)📄 Copie du fichier de licence...$(NC)"
	@mkdir -p $$HOME/aistro/minio/minio.license
	@cp minio.license $$HOME/aistro/minio/minio.license/minio.license
	@echo -e "$(GREEN)✅ Licence copiée vers $$HOME/aistro/minio/minio.license/minio.license$(NC)"
	@echo -e "$(GREEN)✅ Enregistremet de la licence$(NC)"
	mc license register $(ALIAS_NAME) --license $(LICENSE_PATH)
	@echo -e "$(GREEN)✅ License activée$(NC)"


down: ## Arrête et supprime le conteneur MinIO
	@echo -e "$(YELLOW)🛑 Arrêt de MinIO...$(NC)"
	docker stop $(CONTAINER_NAME) 2>/dev/null || true
	docker rm   $(CONTAINER_NAME) 2>/dev/null || true
	@echo -e "$(GREEN)✅ Conteneur arrêté et supprimé.$(NC)"


restart: ## Redémarre le conteneur MinIO
	@echo -e "$(YELLOW)🔄 Redémarrage de MinIO...$(NC)"
	docker restart $(CONTAINER_NAME)
	@echo -e "$(GREEN)✅ MinIO redémarré.$(NC)"


logs: ## Affiche les logs du conteneur MinIO
	docker logs -f $(CONTAINER_NAME)


status: ## Affiche l'état du conteneur MinIO
	@docker ps --filter "name=$(CONTAINER_NAME)" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"


buckets: ## Crée les buckets public et private
	@echo -e "$(YELLOW)📦 Création des buckets...$(NC)"
	@bash scripts/setup-buckets.sh


nginx-setup: ## Installe les configs Nginx (nécessite sudo)
	@echo -e "$(YELLOW)🌐 Installation des configs Nginx...$(NC)"
	@sudo cp nginx/s3.v2.selys.app.conf    $(NGINX_AVAILABLE_DIR)/$(DOMAIN_API)
	@sudo cp nginx/minio.v2.selys.app.conf $(NGINX_AVAILABLE_DIR)/$(DOMAIN_CONSOLE)
	@sudo ln -sf $(NGINX_AVAILABLE_DIR)/$(DOMAIN_API)     $(NGINX_ENABLED_DIR)/$(DOMAIN_API)     2>/dev/null || true
	@sudo ln -sf $(NGINX_AVAILABLE_DIR)/$(DOMAIN_CONSOLE) $(NGINX_ENABLED_DIR)/$(DOMAIN_CONSOLE) 2>/dev/null || true
	@sudo nginx -t && sudo systemctl reload nginx
	@echo -e "$(GREEN)✅ Nginx configuré !$(NC)"


nginx-remove: ## Supprime les configs Nginx
	@echo -e "$(YELLOW)🗑️  Suppression des configs Nginx...$(NC)"
	@sudo rm -f $(NGINX_ENABLED_DIR)/$(DOMAIN_API)
	@sudo rm -f $(NGINX_ENABLED_DIR)/$(DOMAIN_CONSOLE)
	@sudo rm -f $(NGINX_AVAILABLE_DIR)/$(DOMAIN_API)
	@sudo rm -f $(NGINX_AVAILABLE_DIR)/$(DOMAIN_CONSOLE)
	@sudo systemctl reload nginx
	@echo -e "$(GREEN)✅ Configs Nginx supprimées !$(NC)"


ssl: ## Génère les certificats SSL avec Certbot
	@echo -e "$(YELLOW)🔒 Génération des certificats SSL...$(NC)"
	@sudo certbot --nginx -d $(API_DOMAIN) -d $(CONSOLE_DOMAIN) --non-interactive --agree-tos --email $(LETSENCRYPT_EMAIL)
	@echo -e "$(GREEN)✅ Certificats SSL générés !$(NC)"


clean: ## Supprime le conteneur, les données et les volumes MinIO
	@echo -e "$(RED)🗑️  Suppression complète...$(NC)"
	docker stop $(CONTAINER_NAME) 2>/dev/null || true
	docker rm   $(CONTAINER_NAME) 2>/dev/null || true
	@echo -e "$(GREEN)✅ Nettoyage terminé !$(NC)"
