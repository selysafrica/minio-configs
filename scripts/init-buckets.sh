#!/bin/bash
set -e

# Charger les variables d'environnement
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

MINIO_ALIAS="local"
MINIO_URL="http://127.0.0.1:9002"
PRIVATE_BUCKET="${PRIVATE_BUCKET:-private}"
PUBLIC_BUCKET="${PUBLIC_BUCKET:-public}"

echo "==> Attente du démarrage de MinIO..."
until curl -sf "${MINIO_URL}/minio/health/live" > /dev/null; do
  sleep 2
done
echo "==> MinIO est prêt."

echo "==> Configuration du client mc..."
docker run --rm --network host \
  quay.io/minio/mc \
  alias set "${MINIO_ALIAS}" "${MINIO_URL}" "${MINIO_ROOT_USER}" "${MINIO_ROOT_PASSWORD}"

echo "==> Création du bucket privé : ${PRIVATE_BUCKET}"
docker run --rm --network host \
  quay.io/minio/mc \
  mb --ignore-existing "${MINIO_ALIAS}/${PRIVATE_BUCKET}"

docker run --rm --network host \
  quay.io/minio/mc \
  anonymous set none "${MINIO_ALIAS}/${PRIVATE_BUCKET}"

echo "==> Bucket privé configuré (aucun accès public)."

echo "==> Création du bucket public : ${PUBLIC_BUCKET}"
docker run --rm --network host \
  quay.io/minio/mc \
  mb --ignore-existing "${MINIO_ALIAS}/${PUBLIC_BUCKET}"

# Appliquer la policy de lecture publique
POLICY_FILE="/tmp/public-read.json"
POLICY_CONTENT=$(sed "s/PUBLIC_BUCKET_NAME/${PUBLIC_BUCKET}/g" policies/public-read.json)

docker run --rm --network host \
  -e POLICY="${POLICY_CONTENT}" \
  quay.io/minio/mc \
  sh -c "echo \"\$POLICY\" > ${POLICY_FILE} && mc anonymous set-json ${POLICY_FILE} ${MINIO_ALIAS}/${PUBLIC_BUCKET}"

echo "==> Bucket public configuré (lecture publique activée)."

echo ""
echo "Buckets configurés :"
docker run --rm --network host \
  quay.io/minio/mc \
  ls "${MINIO_ALIAS}"
