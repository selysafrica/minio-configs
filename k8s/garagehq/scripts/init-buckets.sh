#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if [ -f "${PROJECT_DIR}/.env" ]; then
  export $(grep -v '^#' "${PROJECT_DIR}/.env" | xargs)
fi

ADMIN_TOKEN="${GARAGE_ADMIN_TOKEN}"
ADMIN_URL="http://127.0.0.1:3331"
PRIVATE_BUCKET="${PRIVATE_BUCKET:-private}"
PUBLIC_BUCKET="${PUBLIC_BUCKET:-public}"

GARAGE_POD=$(kubectl get pods -n garagehq -l app=garagehq -o jsonpath='{.items[0].metadata.name}')

if [ -z "$GARAGE_POD" ]; then
  echo "ERREUR: Aucun pod GarageHQ trouvé dans le namespace 'garagehq'"
  exit 1
fi

echo "==> Pod GarageHQ détecté: ${GARAGE_POD}"

echo "==> Attente du démarrage de GarageHQ..."
until kubectl exec -n garagehq "${GARAGE_POD}" -- garage status 2>/dev/null; do
  echo "    GarageHQ pas encore prêt, nouvelle tentative dans 3s..."
  sleep 3
done
echo "==> GarageHQ est prêt."

echo "==> Configuration du layout..."
NODE_ID=$(kubectl exec -n garagehq "${GARAGE_POD}" -- garage status 2>/dev/null | grep -oP '^[a-f0-9]+' | head -1)

if [ -n "$NODE_ID" ]; then
  kubectl exec -n garagehq "${GARAGE_POD}" -- garage layout assign -z dc1 -c 10GB "${NODE_ID}" 2>/dev/null || true
  kubectl exec -n garagehq "${GARAGE_POD}" -- garage layout apply --version 1 2>/dev/null || echo "    Layout déjà appliqué ou version suivante requise."
else
  echo "    ATTENTION: Impossible de récupérer le Node ID. Configurez le layout manuellement."
fi

echo ""
echo "==> Création du bucket privé: ${PRIVATE_BUCKET}"
kubectl exec -n garagehq "${GARAGE_POD}" -- garage bucket create "${PRIVATE_BUCKET}" 2>/dev/null || echo "    Bucket '${PRIVATE_BUCKET}' existe déjà."

echo "==> Création du bucket public: ${PUBLIC_BUCKET}"
kubectl exec -n garagehq "${GARAGE_POD}" -- garage bucket create "${PUBLIC_BUCKET}" 2>/dev/null || echo "    Bucket '${PUBLIC_BUCKET}' existe déjà."

echo "==> Configuration de l'accès public en lecture pour '${PUBLIC_BUCKET}'..."
kubectl exec -n garagehq "${GARAGE_POD}" -- garage bucket website --allow "${PUBLIC_BUCKET}" 2>/dev/null || true
kubectl exec -n garagehq "${GARAGE_POD}" -- garage bucket allow --read --owner "${PUBLIC_BUCKET}" --key "${GARAGE_API_KEY_NAME:-selys-key}" 2>/dev/null || true

echo ""
echo "==> Création de la clé API..."
kubectl exec -n garagehq "${GARAGE_POD}" -- garage key create "${GARAGE_API_KEY_NAME:-selys-key}" 2>/dev/null || echo "    Clé '${GARAGE_API_KEY_NAME:-selys-key}' existe déjà."

echo "==> Attribution des permissions sur les buckets..."
kubectl exec -n garagehq "${GARAGE_POD}" -- garage bucket allow \
  --read --write --owner "${PRIVATE_BUCKET}" \
  --key "${GARAGE_API_KEY_NAME:-selys-key}" 2>/dev/null || true

kubectl exec -n garagehq "${GARAGE_POD}" -- garage bucket allow \
  --read --write --owner "${PUBLIC_BUCKET}" \
  --key "${GARAGE_API_KEY_NAME:-selys-key}" 2>/dev/null || true

echo ""
echo "==> Résultat:"
kubectl exec -n garagehq "${GARAGE_POD}" -- garage bucket list
echo ""
kubectl exec -n garagehq "${GARAGE_POD}" -- garage key info "${GARAGE_API_KEY_NAME:-selys-key}" 2>/dev/null || true

echo ""
echo "==> Buckets configurés avec succès."
echo "    - ${PRIVATE_BUCKET} (privé)"
echo "    - ${PUBLIC_BUCKET} (public - website activé)"
