#!/usr/bin/env bash
# ============================================================
#  setup.sh — Script de arranque del Homelab Fase 1
#  Pensado para Ubuntu Server (sin GUI)
#  Uso: chmod +x setup.sh && ./setup.sh
# ============================================================

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[*]${NC} $1"; }
success() { echo -e "${GREEN}[+]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[-]${NC} $1"; exit 1; }

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     HOMELAB CYBERSECURITY — FASE 1 SETUP         ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# ──────────────────────────────────────────────────────
#  COMPROBACIONES PREVIAS
# ──────────────────────────────────────────────────────
info "Comprobando requisitos..."

command -v docker  >/dev/null 2>&1 || error "Docker no está instalado. Ejecuta: install-docker.sh"
command -v openssl >/dev/null 2>&1 || error "openssl no encontrado: sudo apt install openssl"

docker compose version >/dev/null 2>&1 || \
  command -v docker-compose >/dev/null 2>&1 || \
  error "docker compose plugin no encontrado"

success "Requisitos OK"

# ──────────────────────────────────────────────────────
#  DETECTAR IP DE LA MÁQUINA (para mostrar al final)
# ──────────────────────────────────────────────────────
SERVER_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1); exit}')
SERVER_IP=${SERVER_IP:-"<IP_DEL_SERVIDOR>"}

# ──────────────────────────────────────────────────────
#  CERTIFICADO SSL SELF-SIGNED
# ──────────────────────────────────────────────────────
info "Generando certificado SSL self-signed..."

mkdir -p nginx/ssl

openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout nginx/ssl/homelab.key \
  -out    nginx/ssl/homelab.crt \
  -subj   "/C=ES/ST=Baleares/L=Palma/O=Homelab/CN=${SERVER_IP}" \
  -addext "subjectAltName=IP:${SERVER_IP},IP:127.0.0.1,DNS:localhost" \
  2>/dev/null

success "Certificado generado → nginx/ssl/ (CN=${SERVER_IP})"

# ──────────────────────────────────────────────────────
#  PULL DE IMÁGENES
# ──────────────────────────────────────────────────────
info "Descargando imágenes Docker..."

docker pull nginx:1.25-alpine
docker pull ghcr.io/digininja/dvwa:latest
docker pull mysql:8.0
docker pull bkimminich/juice-shop:latest
docker pull portainer/portainer-ce:latest

success "Imágenes descargadas"

# ──────────────────────────────────────────────────────
#  LEVANTAR EL LAB
# ──────────────────────────────────────────────────────
info "Levantando contenedores..."

COMPOSE_CMD="docker compose"
command -v docker-compose >/dev/null 2>&1 && COMPOSE_CMD="docker-compose"

$COMPOSE_CMD up -d

# ──────────────────────────────────────────────────────
#  ESPERAR A QUE DVWA ESTÉ HEALTHY
# ──────────────────────────────────────────────────────
info "Esperando a que DVWA esté listo (puede tardar ~60s)..."

TIMEOUT=120; ELAPSED=0
until docker inspect --format='{{.State.Health.Status}}' dvwa 2>/dev/null | grep -q "healthy"; do
  [ "$ELAPSED" -ge "$TIMEOUT" ] && { warn "Timeout. DVWA puede tardar un poco más."; break; }
  sleep 5; ELAPSED=$((ELAPSED+5)); echo -n "."
done
echo ""

# ──────────────────────────────────────────────────────
#  RESUMEN FINAL
# ──────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            LAB FASE 1 — LISTO  ✓                                 ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${NC}  Desde Windows / red local:                                       ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}                                                                   ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  DVWA        → ${CYAN}https://${SERVER_IP}${NC}                          ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  Juice Shop  → ${CYAN}https://${SERVER_IP}:8443${NC}                     ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  Portainer   → ${CYAN}http://${SERVER_IP}:9000${NC}                      ${GREEN}║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${NC}  DVWA login  → admin / password                                   ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  (Primera vez: Setup → Reset Database en el menú de DVWA)         ${GREEN}║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${NC}  El certificado SSL es self-signed → acepta la excepción            ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  en el navegador (Avanzado → Continuar)                            ${GREEN}║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${NC}  Ver logs en tiempo real:                                          ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  ${CYAN}docker exec nginx-rp tail -f /var/log/nginx/dvwa_access.log${NC}    ${GREEN}║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""
