# ============================================
# Makefile MinIO - selys.app
# ============================================

.PHONY: help build up down restart logs status ssl certbot clean setup buckets

# Chargement des variables d'environnement
include .env
export

# Couleurs
GREEN := \033[0;32m
YELLOW := \033[1;33m
CYAN := \033[0;36m
NC := \033[0m

help: ## Affiche cette aide
	@echo ""
	@echo -e "$(CYAN)╔════════════════════════════════════════════════════════════╗$(NC)"
	@echo -e "$(CYAN)║           MinIO - Commandes disponibles                   ║$(NC)"
	@echo -e "$(CYAN)╚════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(CYAN)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""

build: ## Build les images Docker
	@echo -e "$(YELLOW)🔨 Build des images...$(NC)"
	docker-compose build

up: ## Démarre MinIO en arrière-plan
	@echo -e "$(GREEN)🚀 Démarrage de MinIO...$(NC)"
	docker-compose up -d
	@echo -e "$(GREEN)✅ MinIO démarré !$(NC)"
	@echo -e "$(CYAN)   API S3    : http://localhost:$(MINIO_API_PORT)$(NC)"
	@echo -e "$(CYAN)   Console   : http://localhost:$(MINIO_CONSOLE_PORT)$(NC)"

down: ## Arrête MinIO
	@echo -e "$(YELLOW)🛑 Arrêt de MinIO...$(NC)"
	docker-compose down

restart: down up ## Redémarre MinIO

logs: ## Affiche les logs en temps réel
	@echo -e "$(CYAN)📋 Logs MinIO (Ctrl+C pour quitter)...$(NC)"
	docker-compose logs -f

status: ## Affiche le statut des conteneurs
	@echo -e "$(CYAN)📊 Statut des conteneurs :$(NC)"
	docker-compose ps

setup: ## Configure Nginx + démarre MinIO + crée les buckets
	@echo -e "$(YELLOW)🔧 Configuration complète...$(NC)"
	$(MAKE) nginx-setup
	$(MAKE) up
	@echo -e "$(YELLOW)⏳ Attente du démarrage complet...$(NC)"
	@sleep 5
	$(MAKE) buckets
	@echo -e "$(GREEN)✅ Setup terminé !$(NC)"

buckets: ## Crée les buckets public et private
	@echo -e "$(YELLOW)📦 Création des buckets...$(NC)"
	@bash scripts/setup-buckets.sh

nginx-setup: ## Installe les configs Nginx (nécessite sudo)
	@echo -e "$(YELLOW)🌐 Installation des configs Nginx...$(NC)"
	@sudo cp nginx/s3.selys.app.conf /etc/nginx/sites-available/s3.selys.app
	@sudo cp nginx/minio.selys.app.conf /etc/nginx/sites-available/minio.selys.app
	@sudo ln -sf /etc/nginx/sites-available/s3.selys.app /etc/nginx/sites-enabled/s3.selys.app 2>/dev/null || true
	@sudo ln -sf /etc/nginx/sites-available/minio.selys.app /etc/nginx/sites-enabled/minio.selys.app 2>/dev/null || true
	@sudo nginx -t && sudo systemctl reload nginx
	@echo -e "$(GREEN)✅ Nginx configuré !$(NC)"

nginx-remove: ## Supprime les configs Nginx
	@echo -e "$(YELLOW)🗑️  Suppression des configs Nginx...$(NC)"
	@sudo rm -f /etc/nginx/sites-enabled/s3.selys.app
	@sudo rm -f /etc/nginx/sites-enabled/minio.selys.app
	@sudo rm -f /etc/nginx/sites-available/s3.selys.app
	@sudo rm -f /etc/nginx/sites-available/minio.selys.app
	@sudo systemctl reload nginx
	@echo -e "$(GREEN)✅ Configs Nginx supprimées !$(NC)"

ssl: ## Génère les certificats SSL avec Certbot
	@echo -e "$(YELLOW)🔒 Génération des certificats SSL...$(NC)"
	@sudo certbot --nginx -d $(API_DOMAIN) -d $(CONSOLE_DOMAIN) --non-interactive --agree-tos --email $(LETSENCRYPT_EMAIL)
	@echo -e "$(GREEN)✅ Certificats SSL générés !$(NC)"

certbot-renew: ## Renouvelle les certificats SSL
	@echo -e "$(YELLOW)🔄 Renouvellement des certificats...$(NC)"
	@sudo certbot renew
	@echo -e "$(GREEN)✅ Certificats renouvelés !$(NC)"

update-ssl-nginx: ## Met à jour les configs Nginx pour HTTPS après certbot
	@echo -e "$(YELLOW)📝 Mise à jour des configs Nginx pour HTTPS...$(NC)"
	@sudo sed -i 's/# listen 443/listen 443/g' /etc/nginx/sites-available/s3.selys.app
	@sudo sed -i 's/# listen 443/listen 443/g' /etc/nginx/sites-available/minio.selys.app
	@sudo sed -i 's/# ssl_certificate/ssl_certificate/g' /etc/nginx/sites-available/s3.selys.app
	@sudo sed -i 's/# ssl_certificate/ssl_certificate/g' /etc/nginx/sites-available/minio.selys.app
	@sudo sed -i 's/# server {/server {/g' /etc/nginx/sites-available/s3.selys.app
	@sudo sed -i 's/# server {/server {/g' /etc/nginx/sites-available/minio.selys.app
	@sudo sed -i 's/#     listen 443/    listen 443/g' /etc/nginx/sites-available/s3.selys.app
	@sudo sed -i 's/#     listen 443/    listen 443/g' /etc/nginx/sites-available/minio.selys.app
	@sudo sed -i 's/#     ssl_certificate/    ssl_certificate/g' /etc/nginx/sites-available/s3.selys.app
	@sudo sed -i 's/#     ssl_certificate/    ssl_certificate/g' /etc/nginx/sites-available/minio.selys.app
	@sudo sed -i 's/#     location/    location/g' /etc/nginx/sites-available/s3.selys.app
	@sudo sed -i 's/#     location/    location/g' /etc/nginx/sites-available/minio.selys.app
	@sudo sed -i 's/#         proxy_pass/        proxy_pass/g' /etc/nginx/sites-available/s3.selys.app
	@sudo sed -i 's/#         proxy_pass/        proxy_pass/g' /etc/nginx/sites-available/minio.selys.app
	@sudo sed -i 's/#         proxy_set_header/        proxy_set_header/g' /etc/nginx/sites-available/s3.selys.app
	@sudo sed -i 's/#         proxy_set_header/        proxy_set_header/g' /etc/nginx/sites-available/minio.selys.app
	@sudo sed -i 's/#         proxy_connect/        proxy_connect/g' /etc/nginx/sites-available/s3.selys.app
	@sudo sed -i 's/#         proxy_connect/        proxy_connect/g' /etc/nginx/sites-available/minio.selys.app
	@sudo sed -i 's/#         proxy_http/        proxy_http/g' /etc/nginx/sites-available/s3.selys.app
	@sudo sed -i 's/#         proxy_http/        proxy_http/g' /etc/nginx/sites-available/minio.selys.app
	@sudo sed -i 's/#         chunked_transfer/        chunked_transfer/g' /etc/nginx/sites-available/s3.selys.app
	@sudo sed -i 's/#         chunked_transfer/        chunked_transfer/g' /etc/nginx/sites-available/minio.selys.app
	@sudo sed -i 's/#         proxy_set_header Upgrade/        proxy_set_header Upgrade/g' /etc/nginx/sites-available/minio.selys.app
	@sudo sed -i 's/#         proxy_set_header Connection/        proxy_set_header Connection/g' /etc/nginx/sites-available/minio.selys.app
	@sudo sed -i 's/#     }/    }/g' /etc/nginx/sites-available/s3.selys.app
	@sudo sed -i 's/#     }/    }/g' /etc/nginx/sites-available/minio.selys.app
	@sudo sed -i 's/# }/}/g' /etc/nginx/sites-available/s3.selys.app
	@sudo sed -i 's/# }/}/g' /etc/nginx/sites-available/minio.selys.app
	@sudo sed -i 's/# return 301/return 301/g' /etc/nginx/sites-available/s3.selys.app
	@sudo sed -i 's/# return 301/return 301/g' /etc/nginx/sites-available/minio.selys.app
	@sudo nginx -t && sudo systemctl reload nginx
	@echo -e "$(GREEN)✅ Configs Nginx mises à jour pour HTTPS !$(NC)"

clean: ## Supprime tout (conteneurs, volumes, données)
	@echo -e "$(RED)🗑️  Suppression complète...$(NC)"
	@docker-compose down -v --remove-orphans
	@docker rmi minio/minio:latest 2>/dev/null || true
	@echo -e "$(GREEN)✅ Nettoyage terminé !$(NC)"

prune: ## Nettoie les images Docker inutilisées
	@echo -e "$(YELLOW)🧹 Nettoyage des images Docker...$(NC)"
	@docker system prune -f
