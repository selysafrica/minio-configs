#!/bin/bash
# ============================================
# Script de création des buckets MinIO
# ============================================

set -e

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Chargement des variables d'environnement
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

MINIO_USER=${MINIO_ROOT_USER:-minioadmin}
MINIO_PASS=${MINIO_ROOT_PASSWORD:-minioadmin}
API_URL="http://localhost:9011"

echo -e "${YELLOW}⏳ Attente du démarrage de MinIO...${NC}"

# Attendre que MinIO soit prêt
for i in {1..30}; do
    if curl -s -o /dev/null -w "%{http_code}" "${API_URL}/minio/health/live" | grep -q "200"; then
        echo -e "${GREEN}✅ MinIO est prêt !${NC}"
        break
    fi
    echo -n "."
    sleep 2
    if [ $i -eq 30 ]; then
        echo -e "${RED}❌ MinIO n'a pas démarré à temps${NC}"
        exit 1
    fi
done

echo -e "${YELLOW}🔧 Configuration de l'alias mc...${NC}"
mc alias set local ${API_URL} ${MINIO_USER} ${MINIO_PASS} --insecure 2>/dev/null || true

# Création du bucket "public"
echo -e "${YELLOW}📦 Création du bucket 'public'...${NC}"
mc mb local/public --ignore-existing 2>/dev/null || true

# Politique de bucket public (lecture seule)
echo -e "${YELLOW}🔓 Application de la politique publique sur 'public'...${NC}"
cat > /tmp/public-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {"AWS": ["*"]},
            "Action": ["s3:GetObject"],
            "Resource": ["arn:aws:s3:::public/*"]
        }
    ]
}
EOF
mc anonymous set-json /tmp/public-policy.json local/public 2>/dev/null || true

# Création du bucket "private"
echo -e "${YELLOW}📦 Création du bucket 'private'...${NC}"
mc mb local/private --ignore-existing 2>/dev/null || true

# Politique de bucket privé (aucun accès public)
echo -e "${YELLOW}🔒 Application de la politique privée sur 'private'...${NC}"
mc anonymous set none local/private 2>/dev/null || true

# Nettoyage
rm -f /tmp/public-policy.json

echo ""
echo -e "${GREEN}✅ Buckets configurés avec succès !${NC}"
echo -e "${GREEN}   • public  → accès en lecture publique${NC}"
echo -e "${GREEN}   • private → accès restreint (authentification requise)${NC}"
