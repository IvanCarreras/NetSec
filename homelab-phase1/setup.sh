#!/usr/bin/env bash
# ============================================================
#  setup.sh — Script de arranque del Homelab Fase 1
#  Uso: chmod +x setup.sh && ./setup.sh
# ============================================================

set -euo pipefail

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

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

command -v docker      >/dev/null 2>&1 || error "Docker no está instalado"
command -v docker-compose >/dev/null 2>&1 || \
  docker compose version >/dev/null 2>&1 || \
  error "docker-compose no está instalado"

command -v openssl >/dev/null 2>&1 || error "openssl no está instalado"

success "Docker y OpenSSL encontrados"

# ──────────────────────────────────────────────────────
#  GENERAR CERTIFICADO SSL SELF-SIGNED
# ──────────────────────────────────────────────────────
info "Generando certificado SSL self-signed..."

mkdir -p nginx/ssl

openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout nginx/ssl/homelab.key \
  -out    nginx/ssl/homelab.crt \
  -subj   "/C=ES/ST=Baleares/L=Palma/O=Homelab/CN=homelab.local" \
  -addext "subjectAltName=DNS:homelab.local,DNS:dvwa.homelab.local,DNS:juice.homelab.local,IP:127.0.0.1" \
  2>/dev/null

success "Certificado generado en nginx/ssl/"

# ──────────────────────────────────────────────────────
#  HOSTS FILE (opcional, para nombres de dominio locales)
# ──────────────────────────────────────────────────────
info "Comprobando /etc/hosts..."

add_host() {
  local entry="127.0.0.1 $1"
  if ! grep -qF "$1" /etc/hosts 2>/dev/null; then
    warn "Añadiendo '$entry' a /etc/hosts (requiere sudo)"
    echo "$entry" | sudo tee -a /etc/hosts > /dev/null && \
      success "Añadido: $entry" || \
      warn "No se pudo añadir. Hazlo manualmente: echo '$entry' | sudo tee -a /etc/hosts"
  else
    success "Ya existe en /etc/hosts: $1"
  fi
}

add_host "dvwa.homelab.local"
add_host "juice.homelab.local"

# ──────────────────────────────────────────────────────
#  PULL DE IMÁGENES (por adelantado para ver el progreso)
# ──────────────────────────────────────────────────────
info "Descargando imágenes Docker (esto puede tardar unos minutos)..."

docker pull nginx:1.25-alpine
docker pull ghcr.io/digininja/dvwa:latest
docker pull mysql:8.0
docker pull bkimminich/juice-shop:latest
docker pull kalilinux/kali-rolling:latest
docker pull portainer/portainer-ce:latest

success "Imágenes descargadas"

# ──────────────────────────────────────────────────────
#  LEVANTAR EL LAB
# ──────────────────────────────────────────────────────
info "Levantando contenedores..."

# Soporte para docker-compose v1 y v2
if command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD="docker-compose"
else
  COMPOSE_CMD="docker compose"
fi

$COMPOSE_CMD up -d --build

# ──────────────────────────────────────────────────────
#  ESPERAR A QUE DVWA ESTÉ HEALTHY
# ──────────────────────────────────────────────────────
info "Esperando a que DVWA esté listo (puede tardar ~60s)..."

TIMEOUT=120
ELAPSED=0
until docker inspect --format='{{.State.Health.Status}}' dvwa 2>/dev/null | grep -q "healthy"; do
  if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
    warn "DVWA tardó más de ${TIMEOUT}s. Puede que aún esté iniciando."
    break
  fi
  sleep 5
  ELAPSED=$((ELAPSED+5))
  echo -n "."
done
echo ""

# ──────────────────────────────────────────────────────
#  RESUMEN FINAL
# ──────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                  LAB FASE 1 — LISTO                          ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${NC}  DVWA          → ${CYAN}https://dvwa.homelab.local${NC}  (o :443)      ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  Juice Shop    → ${CYAN}https://juice.homelab.local:8443${NC}           ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  Portainer     → ${CYAN}http://localhost:9000${NC}                      ${GREEN}║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${NC}  DVWA login    → admin / password                            ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  (Primera vez: Setup/Reset DB en el menú de DVWA)            ${GREEN}║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${NC}  Atacar desde Kali:                                           ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  ${CYAN}docker exec -it kali-attacker bash${NC}                          ${GREEN}║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${NC}  Ver logs Nginx en tiempo real:                               ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  ${CYAN}docker exec nginx-rp tail -f /var/log/nginx/access.log${NC}      ${GREEN}║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
