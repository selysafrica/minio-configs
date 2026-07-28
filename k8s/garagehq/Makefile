SHELL := /bin/bash
NAMESPACE := garagehq
DOMAIN_API := garage.selys.app
DOMAIN_CONSOLE := console.garage.selys.app
NGINX_CONF_DIR := /etc/nginx/sites-available
NGINX_ENABLED_DIR := /etc/nginx/sites-enabled
K8S_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

-include $(K8S_DIR)/.env

.PHONY: help build deploy up down restart status logs init-buckets \
        nginx nginx-reload ssl certbot clean secret generate-secrets

help: ## Afficher l'aide
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ──────────────────────────────────────────────
# Génération
# ──────────────────────────────────────────────

generate-secrets: ## Générer les secrets aléatoires dans .env
	@if [ -f $(K8S_DIR)/.env ]; then \
		echo "Le fichier .env existe déjà. Supprimez-le d'abord si vous voulez régénérer."; \
		exit 1; \
	fi
	@RPC=$$(openssl rand -hex 32) && \
	ADMIN=$$(openssl rand -base64 32) && \
	METRICS=$$(openssl rand -base64 32) && \
	cp $(K8S_DIR)/.env.example $(K8S_DIR)/.env && \
	sed -i "s|changeme_rpc_secret_hex_32_bytes|$$RPC|" $(K8S_DIR)/.env && \
	sed -i "s|changeme_admin_token|$$ADMIN|" $(K8S_DIR)/.env && \
	sed -i "s|changeme_metrics_token|$$METRICS|" $(K8S_DIR)/.env && \
	echo "Secrets générés dans .env"

# ──────────────────────────────────────────────
# Kubernetes
# ──────────────────────────────────────────────

secret: ## Créer les secrets K8s depuis .env
	@if [ ! -f $(K8S_DIR)/.env ]; then \
		echo "ERREUR: Fichier .env manquant. Exécutez 'make generate-secrets' ou copiez .env.example vers .env"; \
		exit 1; \
	fi
	@kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@kubectl create secret generic garagehq-secrets \
		--namespace=$(NAMESPACE) \
		--from-literal=rpc_secret=$(GARAGE_RPC_SECRET) \
		--from-literal=admin_token=$(GARAGE_ADMIN_TOKEN) \
		--from-literal=metrics_token=$(GARAGE_METRICS_TOKEN) \
		--dry-run=client -o yaml | kubectl apply -f -
	@echo "Secret garagehq-secrets créé/mis à jour."

build: secret ## Appliquer les manifests K8s (namespace, pv, pvc, configmap, deployment, services)
	kubectl apply -f $(K8S_DIR)/namespace.yaml
	kubectl apply -f $(K8S_DIR)/pv.yaml
	kubectl apply -f $(K8S_DIR)/pvc.yaml
	kubectl apply -f $(K8S_DIR)/configmap.yaml
	kubectl apply -f $(K8S_DIR)/deployment.yaml
	kubectl apply -f $(K8S_DIR)/service.yaml

deploy: build nginx ## Déployer GarageHQ + configurer Nginx
	@echo "Attente du pod GarageHQ..."
	kubectl wait --namespace=$(NAMESPACE) --for=condition=ready pod -l app=garagehq --timeout=120s
	@echo "GarageHQ déployé avec succès."

up: deploy init-buckets ## Déployer tout (K8s + Nginx + Buckets)
	@echo ""
	@echo "═══════════════════════════════════════════════"
	@echo " GarageHQ déployé avec succès!"
	@echo " API S3:    http://$(DOMAIN_API)"
	@echo " Admin:     http://$(DOMAIN_CONSOLE)"
	@echo "═══════════════════════════════════════════════"
	@echo ""
	@echo "Exécutez 'make ssl' pour activer HTTPS."

down: ## Supprimer le déploiement GarageHQ (conserve les données)
	kubectl delete -f $(K8S_DIR)/service.yaml --ignore-not-found
	kubectl delete -f $(K8S_DIR)/deployment.yaml --ignore-not-found
	@echo "Déploiement GarageHQ supprimé. Les données sont conservées dans le PV."

restart: ## Redémarrer le pod GarageHQ
	kubectl rollout restart deployment/garagehq -n $(NAMESPACE)
	kubectl wait --namespace=$(NAMESPACE) --for=condition=ready pod -l app=garagehq --timeout=120s
	@echo "GarageHQ redémarré."

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

logs: ## Afficher les logs GarageHQ
	kubectl logs -n $(NAMESPACE) -l app=garagehq --tail=100 -f

garage-status: ## Afficher le statut du cluster Garage
	@GARAGE_POD=$$(kubectl get pods -n $(NAMESPACE) -l app=garagehq -o jsonpath='{.items[0].metadata.name}'); \
	kubectl exec -n $(NAMESPACE) "$$GARAGE_POD" -- /garage status

garage-key-list: ## Lister les clés API
	@GARAGE_POD=$$(kubectl get pods -n $(NAMESPACE) -l app=garagehq -o jsonpath='{.items[0].metadata.name}'); \
	kubectl exec -n $(NAMESPACE) "$$GARAGE_POD" -- /garage key list

garage-bucket-list: ## Lister les buckets
	@GARAGE_POD=$$(kubectl get pods -n $(NAMESPACE) -l app=garagehq -o jsonpath='{.items[0].metadata.name}'); \
	kubectl exec -n $(NAMESPACE) "$$GARAGE_POD" -- /garage bucket list

# ──────────────────────────────────────────────
# Buckets
# ──────────────────────────────────────────────

init-buckets: ## Créer les buckets par défaut (public + private)
	@chmod +x $(K8S_DIR)/scripts/init-buckets.sh
	@$(K8S_DIR)/scripts/init-buckets.sh

# ──────────────────────────────────────────────
# Nginx
# ──────────────────────────────────────────────

nginx: ## Installer la config Nginx pour GarageHQ
	sudo cp $(K8S_DIR)/nginx/garagehq.conf $(NGINX_CONF_DIR)/$(DOMAIN_API)
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
	@echo "ATTENTION: Ceci va supprimer le déploiement GarageHQ."
	@read -p "Les données seront conservées dans /data/garagehq. Continuer ? [y/N] " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		kubectl delete -f $(K8S_DIR)/service.yaml --ignore-not-found; \
		kubectl delete -f $(K8S_DIR)/deployment.yaml --ignore-not-found; \
		kubectl delete -f $(K8S_DIR)/pvc.yaml --ignore-not-found; \
		kubectl delete -f $(K8S_DIR)/configmap.yaml --ignore-not-found; \
		kubectl delete secret garagehq-secrets -n $(NAMESPACE) --ignore-not-found; \
		echo "Déploiement nettoyé. PV et données conservés."; \
	else \
		echo "Annulé."; \
	fi

clean-all: ## Supprimer TOUT (y compris PV, namespace et données)
	@echo "ATTENTION: Ceci va TOUT supprimer, y compris les données!"
	@read -p "Êtes-vous sûr ? [y/N] " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		kubectl delete namespace $(NAMESPACE) --ignore-not-found; \
		kubectl delete pv garagehq-meta-pv garagehq-data-pv --ignore-not-found; \
		sudo rm -f $(NGINX_ENABLED_DIR)/$(DOMAIN_API); \
		sudo rm -f $(NGINX_CONF_DIR)/$(DOMAIN_API); \
		sudo systemctl reload nginx 2>/dev/null || true; \
		echo "Tout a été supprimé."; \
	else \
		echo "Annulé."; \
	fi
