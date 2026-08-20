# ============================================
# Makefile MinIO AIstro - codihub.ci (cPanel / Apache)
# ============================================

.PHONY: help setup init-alias license deploy down restart logs status buckets apache-setup apache-remove apache-modules ssl clean

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
ALIAS_NAME := codihub
LICENSE_DIR  := $$HOME/aistro/minio
LICENSE_PATH := $$HOME/aistro/minio/minio.license

# cPanel Apache include directory
CPANEL_INCLUDES := /etc/apache2/conf.d/includes


help: ## Affiche cette aide
	@echo ""
	@echo -e "$(CYAN)╔════════════════════════════════════════════════════════════╗$(NC)"
	@echo -e "$(CYAN)║      MinIO AIstro (cPanel) - Commandes disponibles        ║$(NC)"
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
		-e MINIO_ROOT_USER=$(MINIO_ROOT_USER) \
		-e MINIO_ROOT_PASSWORD=$(MINIO_ROOT_PASSWORD) \
# 		-e MINIO_BROWSER_REDIRECT_URL=$(MINIO_BROWSER_REDIRECT_URL) \
# 		-e MINIO_DOMAIN=$(MINIO_DOMAIN) \
# 		-e MINIO_SERVER_URL=$(MINIO_SERVER_URL) \
		-v $$HOME/aistro/minio/data:/mnt/data/aistro \
		-v $(LICENSE_PATH):/minio.license \
		-v $$HOME/aistro/minio/certs:/etc/aistro/minio/certs \
		--name "$(CONTAINER_NAME)" \
		--restart unless-stopped \
		quay.io/minio/aistor/minio:latest \
		minio server /mnt/data/aistro \
			--license /minio.license \
			--console-address ":9001"
	@echo -e "$(GREEN)✅ MinIO démarré !$(NC)"
	@echo -e "$(GREEN)   • API     → http://localhost:$(MINIO_API_PORT)$(NC)"
	@echo -e "$(GREEN)   • Console → http://localhost:$(MINIO_CONSOLE_PORT)$(NC)"


init-alias: ## Configure l'alias mc
	@echo -e "$(YELLOW)📄 Init Alias...$(NC)"
	mc alias set $(ALIAS_NAME) http://localhost:$(MINIO_API_PORT) $(MINIO_ROOT_USER) $(MINIO_ROOT_PASSWORD)

license: ## Copie et enregistre la licence MinIO
	@echo -e "$(YELLOW)📄 Copie du fichier de licence...$(NC)"
	@mkdir -p $(LICENSE_DIR)
	@test ! -d $(LICENSE_PATH) || (echo -e "$(RED)⚠️  $(LICENSE_PATH) est un dossier, suppression...$(NC)" && rm -rf $(LICENSE_PATH))
	@cp minio.license $(LICENSE_PATH)
	@echo -e "$(GREEN)✅ Licence copiée vers $(LICENSE_PATH)$(NC)"
	@echo -e "$(GREEN)✅ Enregistrement de la licence$(NC)"
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


apache-modules: ## Active les modules Apache nécessaires (proxy, rewrite, headers)
	@echo -e "$(YELLOW)🔧 Activation des modules Apache...$(NC)"
	@sudo a2enmod proxy proxy_http proxy_wstunnel rewrite headers ssl 2>/dev/null || true
	@echo -e "$(GREEN)✅ Modules Apache activés.$(NC)"


apache-setup: apache-modules ## Installe les configs Apache pour cPanel
	@echo -e "$(YELLOW)🌐 Installation des configs Apache...$(NC)"
	@sudo mkdir -p $(CPANEL_INCLUDES)
	@sudo cp apache/s3.codihub.ci.conf $(CPANEL_INCLUDES)/s3.codihub.ci.conf
	@sudo cp apache/minio.codihub.ci.conf $(CPANEL_INCLUDES)/minio.codihub.ci.conf
	@sudo /scripts/rebuildhttpdconf 2>/dev/null || true
	@sudo apachectl configtest && sudo apachectl graceful
	@echo -e "$(GREEN)✅ Apache configuré !$(NC)"
	@echo -e "$(CYAN)   API S3    : http://$(DOMAIN_API)$(NC)"
	@echo -e "$(CYAN)   Console   : http://$(DOMAIN_CONSOLE)$(NC)"


apache-remove: ## Supprime les configs Apache
	@echo -e "$(YELLOW)🗑️  Suppression des configs Apache...$(NC)"
	@sudo rm -f $(CPANEL_INCLUDES)/s3.codihub.ci.conf
	@sudo rm -f $(CPANEL_INCLUDES)/minio.codihub.ci.conf
	@sudo /scripts/rebuildhttpdconf 2>/dev/null || true
	@sudo apachectl graceful
	@echo -e "$(GREEN)✅ Configs Apache supprimées !$(NC)"


ssl: ## Lance AutoSSL cPanel pour les domaines MinIO
	@echo -e "$(YELLOW)🔒 Lancement d'AutoSSL pour $(DOMAIN_API) et $(DOMAIN_CONSOLE)...$(NC)"
	@sudo /usr/local/cpanel/bin/autossl_check --all
	@echo -e "$(GREEN)✅ AutoSSL lancé ! Les certificats seront générés sous quelques minutes.$(NC)"
	@echo -e "$(CYAN)   Vérifiez le statut dans : WHM > SSL/TLS > Manage AutoSSL$(NC)"


clean: ## Supprime le conteneur, les données et les volumes MinIO
	@echo -e "$(RED)🗑️  Suppression complète...$(NC)"
	docker stop $(CONTAINER_NAME) 2>/dev/null || true
	docker rm   $(CONTAINER_NAME) 2>/dev/null || true
	@echo -e "$(GREEN)✅ Nettoyage terminé !$(NC)"
