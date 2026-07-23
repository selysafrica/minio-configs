#!/bin/bash
set -e

if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

MINIO_API_URL="http://127.0.0.1:9055"
PRIVATE_BUCKET="${PRIVATE_BUCKET:-private}"
PUBLIC_BUCKET="${PUBLIC_BUCKET:-public}"

echo "==> Attente du démarrage de MinIO..."
until curl -sf "${MINIO_API_URL}/minio/health/live" > /dev/null; do
  sleep 2
done
echo "==> MinIO est prêt."

PUBLIC_POLICY=$(sed "s/PUBLIC_BUCKET_NAME/${PUBLIC_BUCKET}/g" policies/public-read.json)

echo "==> Configuration des buckets (privé: ${PRIVATE_BUCKET}, public: ${PUBLIC_BUCKET})..."

docker run --rm --network host \
  --entrypoint sh quay.io/minio/mc -c "
    mc alias set minio ${MINIO_API_URL} ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD} --api S3v4

    echo '-- Bucket privé : ${PRIVATE_BUCKET}'
    mc mb --ignore-existing minio/${PRIVATE_BUCKET}
    mc anonymous set none minio/${PRIVATE_BUCKET}

    echo '-- Bucket public : ${PUBLIC_BUCKET}'
    mc mb --ignore-existing minio/${PUBLIC_BUCKET}
    printf '%s' '${PUBLIC_POLICY}' > /tmp/public-read.json
    mc anonymous set-json /tmp/public-read.json minio/${PUBLIC_BUCKET}

    echo '-- Résultat :'
    mc ls minio
  "

echo "==> Buckets configurés avec succès."
