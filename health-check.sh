#!/bin/bash
# health-check.sh
# Script para validar que el MiniSOC está completamente funcional

set -e

echo "=========================================="
echo "🏥 MiniSOC - Health Check"
echo "=========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Contadores
CHECKS_PASSED=0
CHECKS_FAILED=0

# Función para check
check() {
    local name=$1
    local command=$2
    
    echo -n "🔍 $name ... "
    
    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        ((CHECKS_PASSED++))
    else
        echo -e "${RED}✗${NC}"
        ((CHECKS_FAILED++))
    fi
}

# Función para check con info
check_info() {
    local name=$1
    local command=$2
    
    echo -n "ℹ️  $name: "
    eval "$command"
}

# ========================================
# CHEQUEOS BÁSICOS
# ========================================
echo -e "\n${BLUE}═══ Chequeos del Sistema ═══${NC}"
check "Docker instalado" "docker --version"
check "Docker Compose instalado" "docker-compose --version"
check "Docker daemon corriendo" "docker ps > /dev/null"

# ========================================
# CHEQUEOS DE CONFIGURACIÓN
# ========================================
echo -e "\n${BLUE}═══ Chequeos de Configuración ═══${NC}"

if [ -f ".env" ]; then
    check ".env existe" "[ -f .env ]"
else
    echo -e "${YELLOW}⚠️  Archivo .env no encontrado - creando...${NC}"
    touch .env
fi

if [ -f "docker-compose.yml" ]; then
    check "docker-compose.yml válido" "docker-compose config > /dev/null"
else
    echo -e "${RED}✗ docker-compose.yml no encontrado${NC}"
    ((CHECKS_FAILED++))
fi

check "Estructura de directorios" "[ -d logstash/conf.d ] && [ -d filebeat ]"

# ========================================
# CHEQUEOS DE SERVICIOS
# ========================================
echo -e "\n${BLUE}═══ Chequeos de Servicios Docker ═══${NC}"

# Ver si los containers existen
if docker ps -a | grep -q minisoc-elasticsearch; then
    check "Container Elasticsearch existe" "docker ps -a | grep minisoc-elasticsearch"
    check "Elasticsearch corriendo" "docker ps | grep minisoc-elasticsearch | grep -q Up"
else
    echo -e "${YELLOW}⚠️  Containers no encontrados - asegúrate de haber ejecutado docker-compose up${NC}"
fi

if docker ps -a | grep -q minisoc-kibana; then
    check "Container Kibana existe" "docker ps -a | grep minisoc-kibana"
    check "Kibana corriendo" "docker ps | grep minisoc-kibana | grep -q Up"
fi

if docker ps -a | grep -q minisoc-logstash; then
    check "Container Logstash existe" "docker ps -a | grep minisoc-logstash"
    check "Logstash corriendo" "docker ps | grep minisoc-logstash | grep -q Up"
fi

# ========================================
# CHEQUEOS DE CONECTIVIDAD
# ========================================
echo -e "\n${BLUE}═══ Chequeos de Conectividad ═══${NC}"

check "Elasticsearch accesible (puerto 9200)" "curl -s http://localhost:9200 | grep -q version"
check "Kibana accesible (puerto 5601)" "curl -s http://localhost:5601/api/status"
check "Logstash operacional" "curl -s http://localhost:9600/ | grep -q logstash_version"

# ========================================
# CHEQUEOS DE DATOS
# ========================================
echo -e "\n${BLUE}═══ Chequeos de Datos en Elasticsearch ═══${NC}"

echo -n "📊 Índices creados: "
INDICES=$(curl -s http://localhost:9200/_cat/indices?h=index | wc -l)
if [ $INDICES -gt 0 ]; then
    echo -e "${GREEN}$INDICES encontrados${NC}"
    ((CHECKS_PASSED++))
    echo -e "${YELLOW}Índices:${NC}"
    curl -s http://localhost:9200/_cat/indices?h=index,store.size,docs.count | sed 's/^/   /'
else
    echo -e "${YELLOW}Ninguno (normal si es primera ejecución)${NC}"
fi

echo -n "💾 Estado del cluster: "
HEALTH=$(curl -s http://localhost:9200/_cluster/health | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
if [ "$HEALTH" = "green" ]; then
    echo -e "${GREEN}$HEALTH${NC}"
    ((CHECKS_PASSED++))
elif [ "$HEALTH" = "yellow" ]; then
    echo -e "${YELLOW}$HEALTH (normal en single-node)${NC}"
    ((CHECKS_PASSED++))
else
    echo -e "${RED}$HEALTH${NC}"
    ((CHECKS_FAILED++))
fi

# ========================================
# CHEQUEOS DE MEMORIA
# ========================================
echo -e "\n${BLUE}═══ Información de Recursos ═══${NC}"

echo -e "${YELLOW}Memoria del sistema:${NC}"
free -h | sed 's/^/  /'

echo -e "\n${YELLOW}Memoria de Docker:${NC}"
docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}" 2>/dev/null | sed 's/^/  /'

echo -e "\n${YELLOW}Espacio en disco:${NC}"
df -h | grep -E '/$|var|minisoc' | sed 's/^/  /'

# ========================================
# RESUMEN
# ========================================
echo ""
echo "=========================================="
echo "📊 RESUMEN"
echo "=========================================="
echo -e "${GREEN}✓ Pasados: $CHECKS_PASSED${NC}"
echo -e "${RED}✗ Fallidos: $CHECKS_FAILED${NC}"

if [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✅ Todas las verificaciones pasaron!${NC}"
    echo -e "\n${BLUE}Acceder a:${NC}"
    echo "  🖥️  Kibana:       http://localhost:5601"
    echo "  📡 Elasticsearch: http://localhost:9200"
    echo "  🔌 Logstash:      http://localhost:9600"
    exit 0
else
    echo -e "\n${RED}⚠️  Algunas verificaciones fallaron${NC}"
    echo -e "\n${YELLOW}Troubleshooting:${NC}"
    echo "  1. Verificar logs: docker-compose logs -f"
    echo "  2. Reiniciar stack: docker-compose restart"
    echo "  3. Ver memoria disponible: free -h"
    exit 1
fi