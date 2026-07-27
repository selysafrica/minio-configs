SHELL := /bin/bash
NAMESPACE := minio
DOMAIN_API := minio.selys.app
DOMAIN_CONSOLE := s3.selys.app
NGINX_CONF_DIR := /etc/nginx/sites-available
NGINX_ENABLED_DIR := /etc/nginx/sites-enabled
K8S_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

-include $(K8S_DIR)/.env

.PHONY: help build deploy up down restart status logs init-buckets \
        nginx nginx-reload ssl certbot clean secret

help: ## Afficher l'aide
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ──────────────────────────────────────────────
# Kubernetes
# ──────────────────────────────────────────────

secret: ## Créer le secret K8s depuis .env
	@if [ ! -f $(K8S_DIR)/.env ]; then \
		echo "ERREUR: Fichier .env manquant. Copiez .env.example vers .env"; \
		exit 1; \
	fi
	@kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@kubectl create secret generic minio-credentials \
		--namespace=$(NAMESPACE) \
		--from-literal=MINIO_ROOT_USER=$(MINIO_ROOT_USER) \
		--from-literal=MINIO_ROOT_PASSWORD=$(MINIO_ROOT_PASSWORD) \
		--dry-run=client -o yaml | kubectl apply -f -
	@echo "Secret minio-credentials créé/mis à jour."

build: secret ## Appliquer les manifests K8s (namespace, pv, pvc, deployment, services)
	kubectl apply -f $(K8S_DIR)/namespace.yaml
	kubectl apply -f $(K8S_DIR)/pv.yaml
	kubectl apply -f $(K8S_DIR)/pvc.yaml
	kubectl apply -f $(K8S_DIR)/deployment.yaml
	kubectl apply -f $(K8S_DIR)/service.yaml

deploy: build nginx ## Déployer MinIO + configurer Nginx
	@echo "Attente du pod MinIO..."
	kubectl wait --namespace=$(NAMESPACE) --for=condition=ready pod -l app=minio --timeout=120s
	@echo "MinIO déployé avec succès."

up: deploy init-buckets ## Déployer tout (K8s + Nginx + Buckets)
	@echo ""
	@echo "═══════════════════════════════════════════════"
	@echo " MinIO déployé avec succès!"
	@echo " API S3:    https://$(DOMAIN_API)"
	@echo " Console:   https://$(DOMAIN_CONSOLE)"
	@echo "═══════════════════════════════════════════════"
	@echo ""
	@echo "Exécutez 'make ssl' pour activer HTTPS."

down: ## Supprimer le déploiement MinIO (conserve les données)
	kubectl delete -f $(K8S_DIR)/service.yaml --ignore-not-found
	kubectl delete -f $(K8S_DIR)/deployment.yaml --ignore-not-found
	@echo "Déploiement MinIO supprimé. Les données sont conservées dans le PV."

restart: ## Redémarrer le pod MinIO
	kubectl rollout restart deployment/minio -n $(NAMESPACE)
	kubectl wait --namespace=$(NAMESPACE) --for=condition=ready pod -l app=minio --timeout=120s
	@echo "MinIO redémarré."

status: ## Afficher le statut du déploiement
	@echo "=== Namespace ==="
	@kubectl get namespace $(NAMESPACE) 2>/dev/null || echo "Namespace $(NAMESPACE) non trouvé"
	@echo ""
	@echo "=== Pods ==="
	@kubectl get pods -n $(NAMESPACE) -o wide 2>/dev/null || true
	@echo ""
	@echo "=== Services ==="
	@kubectl get svc -n $(NAMESPACE) 2>/dev/null || true
	@echo ""
	@echo "=== PVC ==="
	@kubectl get pvc -n $(NAMESPACE) 2>/dev/null || true

logs: ## Afficher les logs MinIO
	kubectl logs -n $(NAMESPACE) -l app=minio --tail=100 -f

# ──────────────────────────────────────────────
# Buckets
# ──────────────────────────────────────────────

init-buckets: ## Créer les buckets par défaut (public + private)
	@chmod +x $(K8S_DIR)/scripts/init-buckets.sh
	@$(K8S_DIR)/scripts/init-buckets.sh

# ──────────────────────────────────────────────
# Nginx
# ──────────────────────────────────────────────

nginx: ## Installer la config Nginx pour MinIO
	sudo cp $(K8S_DIR)/nginx/minio.conf $(NGINX_CONF_DIR)/$(DOMAIN_API)
	sudo ln -sf $(NGINX_CONF_DIR)/$(DOMAIN_API) $(NGINX_ENABLED_DIR)/$(DOMAIN_API)
	sudo nginx -t
	sudo systemctl reload nginx
	@echo "Configuration Nginx installée et rechargée."

nginx-reload: ## Recharger Nginx
	sudo nginx -t && sudo systemctl reload nginx

# ──────────────────────────────────────────────
# SSL / Certbot
# ──────────────────────────────────────────────

ssl: certbot ## Alias pour certbot

certbot: ## Obtenir les certificats SSL via Certbot
	sudo certbot --nginx -d $(DOMAIN_API) -d $(DOMAIN_CONSOLE) --non-interactive --agree-tos --redirect
	@echo "Certificats SSL installés pour $(DOMAIN_API) et $(DOMAIN_CONSOLE)."

certbot-renew: ## Renouveler les certificats SSL
	sudo certbot renew --dry-run
	@echo "Test de renouvellement terminé."

# ──────────────────────────────────────────────
# Nettoyage
# ──────────────────────────────────────────────

clean: ## Supprimer tout le déploiement (deployment, services, pvc)
	@echo "ATTENTION: Ceci va supprimer le déploiement MinIO."
	@read -p "Les données seront conservées dans /data/minio. Continuer ? [y/N] " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		kubectl delete -f $(K8S_DIR)/service.yaml --ignore-not-found; \
		kubectl delete -f $(K8S_DIR)/deployment.yaml --ignore-not-found; \
		kubectl delete -f $(K8S_DIR)/pvc.yaml --ignore-not-found; \
		kubectl delete secret minio-credentials -n $(NAMESPACE) --ignore-not-found; \
		echo "Déploiement nettoyé. PV et données conservés."; \
	else \
		echo "Annulé."; \
	fi

clean-all: ## Supprimer TOUT (y compris PV, namespace et données)
	@echo "ATTENTION: Ceci va TOUT supprimer, y compris les données!"
	@read -p "Êtes-vous sûr ? [y/N] " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		kubectl delete namespace $(NAMESPACE) --ignore-not-found; \
		kubectl delete pv minio-pv --ignore-not-found; \
		sudo rm -f $(NGINX_ENABLED_DIR)/minio.conf; \
		sudo rm -f $(NGINX_CONF_DIR)/minio.conf; \
		sudo systemctl reload nginx 2>/dev/null || true; \
		echo "Tout a été supprimé."; \
	else \
		echo "Annulé."; \
	fi
