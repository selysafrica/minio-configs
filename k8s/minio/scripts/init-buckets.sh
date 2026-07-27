#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if [ -f "${PROJECT_DIR}/.env" ]; then
  export $(grep -v '^#' "${PROJECT_DIR}/.env" | xargs)
fi

MINIO_HOST="${MINIO_ROOT_USER:-minioadmin}"
MINIO_PASS="${MINIO_ROOT_PASSWORD:-changeme123}"
MINIO_API_URL="https://s3.selys.app"
PRIVATE_BUCKET="${PRIVATE_BUCKET:-private}"
PUBLIC_BUCKET="${PUBLIC_BUCKET:-public}"

echo "==> Attente du démarrage de MinIO..."
until curl -sf "${MINIO_API_URL}/minio/health/live" -k > /dev/null 2>&1; do
  echo "    MinIO pas encore prêt, nouvelle tentative dans 3s..."
  sleep 3
done
echo "==> MinIO est prêt."

MINIO_POD=$(kubectl get pods -n minio -l app=minio -o jsonpath='{.items[0].metadata.name}')

if [ -z "$MINIO_POD" ]; then
  echo "ERREUR: Aucun pod MinIO trouvé dans le namespace 'minio'"
  exit 1
fi

echo "==> Pod MinIO détecté: ${MINIO_POD}"

PUBLIC_POLICY=$(sed "s/PUBLIC_BUCKET_NAME/${PUBLIC_BUCKET}/g" "${PROJECT_DIR}/policies/public-read.json")

echo "==> Configuration des buckets..."

kubectl exec -n minio "${MINIO_POD}" -- sh -c "
  mc alias set local http://localhost:9000 '${MINIO_HOST}' '${MINIO_PASS}' --api S3v4

  echo '-- Création du bucket privé: ${PRIVATE_BUCKET}'
  mc mb --ignore-existing local/${PRIVATE_BUCKET}
  mc anonymous set none local/${PRIVATE_BUCKET}

  echo '-- Création du bucket public: ${PUBLIC_BUCKET}'
  mc mb --ignore-existing local/${PUBLIC_BUCKET}
  printf '%s' '${PUBLIC_POLICY}' > /tmp/public-read.json
  mc anonymous set-json /tmp/public-read.json local/${PUBLIC_BUCKET}

  echo '-- Liste des buckets:'
  mc ls local
"

echo "==> Buckets configurés avec succès."
echo "    - ${PRIVATE_BUCKET} (privé)"
echo "    - ${PUBLIC_BUCKET} (public en lecture)"
