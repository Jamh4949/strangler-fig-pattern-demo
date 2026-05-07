#!/usr/bin/env bash

set -euo pipefail

WORKDIR=$(pwd)

echo "=================================================="
echo "🔨 RECOMPILANDO QUARKUS OWNER SERVICE"
echo "=================================================="

cd "$WORKDIR/quarkus-owner-service"

# Detect JAVA_HOME si no está definido
if [ -z "${JAVA_HOME:-}" ] && command -v java >/dev/null 2>&1; then
  JAVA_HOME=$(cd "$(dirname "$(command -v java)")/.." && pwd)
  export JAVA_HOME
  echo "✓ JAVA_HOME detectado: $JAVA_HOME"
fi

# Compilar con el mvnw normalizado para Git Bash
TMP_MAVENW=".mvnw.gitbash"
tr -d '\r' < ./mvnw > "$TMP_MAVENW"
bash "$TMP_MAVENW" clean package -DskipTests || { rm -f "$TMP_MAVENW"; exit 1; }
rm -f "$TMP_MAVENW"

echo "✓ Build completado"

cd "$WORKDIR"

echo ""
echo "=================================================="
echo "🐳 RECONSTRUYENDO IMAGEN DOCKER (sin caché)"
echo "=================================================="

docker-compose build --no-cache quarkus-owner-service

echo ""
echo "=================================================="
echo "🚀 LEVANTANDO CONTENEDOR NUEVO"
echo "=================================================="

docker-compose up -d --no-deps --force-recreate quarkus-owner-service

echo "✓ Contenedor iniciado"

echo ""
echo "=================================================="
echo "♻️  REINICIANDO KAFKA STREAMS (sincronización)"
echo "=================================================="

docker-compose restart kstreams-table-joiner

echo ""
echo "=================================================="
echo "✅ DEPLOYMENT COMPLETADO"
echo "=================================================="
echo ""
echo "🌐 Accede a:"
echo "   - http://localhost/petclinic/owners.html (vía NGINX read_write)"
echo "   - http://localhost:8080/owners/ (directo a Quarkus)"
echo ""
echo "📋 Deberías ver:"
echo "   ✓ Navbar moderno con logo Q"
echo "   ✓ Cards elegantes con glassmorphism"
echo "   ✓ Colores azul cian y púrpura"
echo "   ✓ Badge 'MODERNIZADO - QUARKUS SERVICE'"
echo ""
echo "⏱️  Espera 10 segundos antes de recargar la página"
echo "=================================================="