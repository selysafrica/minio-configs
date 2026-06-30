#!/bin/bash
set -e

if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

MINIO_URL="http://127.0.0.1:9002"
PRIVATE_BUCKET="${PRIVATE_BUCKET:-private}"
PUBLIC_BUCKET="${PUBLIC_BUCKET:-public}"

echo "==> Attente du démarrage de MinIO..."
until curl -sf "${MINIO_URL}/minio/health/live" > /dev/null; do
  sleep 2
done
echo "==> MinIO est prêt."

PUBLIC_POLICY=$(sed "s/PUBLIC_BUCKET_NAME/${PUBLIC_BUCKET}/g" policies/public-read.json)

echo "==> Configuration des buckets..."
docker run --rm --network host \
  -e MC_HOST_local="${MINIO_URL%/}" \
  -e MINIO_USER="${MINIO_ROOT_USER}" \
  -e MINIO_PASS="${MINIO_ROOT_PASSWORD}" \
  -e PRIVATE_BUCKET="${PRIVATE_BUCKET}" \
  -e PUBLIC_BUCKET="${PUBLIC_BUCKET}" \
  -e PUBLIC_POLICY="${PUBLIC_POLICY}" \
  --entrypoint sh quay.io/minio/mc -c "
    mc alias set local http://127.0.0.1:9002 \${MINIO_USER} \${MINIO_PASS}

    echo '-- Bucket privé : '\${PRIVATE_BUCKET}
    mc mb --ignore-existing local/\${PRIVATE_BUCKET}
    mc anonymous set none local/\${PRIVATE_BUCKET}

    echo '-- Bucket public : '\${PUBLIC_BUCKET}
    mc mb --ignore-existing local/\${PUBLIC_BUCKET}
    echo \"\${PUBLIC_POLICY}\" > /tmp/public-read.json
    mc anonymous set-json /tmp/public-read.json local/\${PUBLIC_BUCKET}

    echo '-- Buckets créés :'
    mc ls local
  "

echo "==> Buckets configurés avec succès."
