#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if [ -f "${PROJECT_DIR}/.env" ]; then
  export $(grep -v '^#' "${PROJECT_DIR}/.env" | xargs)
fi

PRIVATE_BUCKET="${PRIVATE_BUCKET:-private}"
PUBLIC_BUCKET="${PUBLIC_BUCKET:-public}"
KEY_NAME="${GARAGE_API_KEY_NAME:-selys-key}"

GARAGE_POD=$(kubectl get pods -n garagehq -l app=garagehq -o jsonpath='{.items[0].metadata.name}')

if [ -z "$GARAGE_POD" ]; then
  echo "ERREUR: Aucun pod GarageHQ trouvé dans le namespace 'garagehq'"
  exit 1
fi

echo "==> Pod GarageHQ détecté: ${GARAGE_POD}"

EXEC="kubectl exec -n garagehq ${GARAGE_POD} --"

echo "==> Attente du démarrage de GarageHQ..."
until $EXEC /garage status 2>/dev/null; do
  echo "    GarageHQ pas encore prêt, nouvelle tentative dans 3s..."
  sleep 3
done
echo "==> GarageHQ est prêt."

echo "==> Configuration du layout..."
NODE_ID=$($EXEC /garage status 2>/dev/null | grep -oP '^[a-f0-9]+' | head -1)

if [ -n "$NODE_ID" ]; then
  $EXEC /garage layout assign -z dc1 -c 20GB "${NODE_ID}" 2>/dev/null || true
  $EXEC /garage layout apply --version 1 2>/dev/null || echo "    Layout déjà appliqué ou version suivante requise."
else
  echo "    ATTENTION: Impossible de récupérer le Node ID."
fi

echo ""
echo "==> Création de la clé API: ${KEY_NAME}"
$EXEC /garage key create "${KEY_NAME}" 2>/dev/null || echo "    Clé '${KEY_NAME}' existe déjà."

echo ""
echo "==> Création du bucket privé: ${PRIVATE_BUCKET}"
$EXEC /garage bucket create "${PRIVATE_BUCKET}" 2>/dev/null || echo "    Bucket '${PRIVATE_BUCKET}' existe déjà."

echo "==> Création du bucket public: ${PUBLIC_BUCKET}"
$EXEC /garage bucket create "${PUBLIC_BUCKET}" 2>/dev/null || echo "    Bucket '${PUBLIC_BUCKET}' existe déjà."

echo "==> Attribution des permissions..."
$EXEC /garage bucket allow --read --write --owner "${PRIVATE_BUCKET}" --key "${KEY_NAME}" 2>/dev/null || true
$EXEC /garage bucket allow --read --write --owner "${PUBLIC_BUCKET}" --key "${KEY_NAME}" 2>/dev/null || true

echo "==> Activation du mode website pour '${PUBLIC_BUCKET}'..."
$EXEC /garage bucket website --allow "${PUBLIC_BUCKET}" 2>/dev/null || true

echo ""
echo "==> Résultat:"
$EXEC /garage bucket list
echo ""
$EXEC /garage key info "${KEY_NAME}" 2>/dev/null || true

echo ""
echo "==> Buckets configurés avec succès."
echo "    - ${PRIVATE_BUCKET} (privé)"
echo "    - ${PUBLIC_BUCKET} (public - website activé)"
