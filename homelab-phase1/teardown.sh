#!/usr/bin/env bash
# ============================================================
#  teardown.sh — Para el lab y limpia los recursos
#  Uso: ./teardown.sh           → para contenedores
#       ./teardown.sh --purge   → borra también volúmenes y redes
# ============================================================

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[*]${NC} $1"; }
success() { echo -e "${GREEN}[+]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }

COMPOSE_CMD="docker compose"
command -v docker-compose >/dev/null 2>&1 && COMPOSE_CMD="docker-compose"

if [[ "${1:-}" == "--purge" ]]; then
    warn "Modo PURGE: se borrarán contenedores, volúmenes y redes"
    read -rp "¿Continuar? (s/N): " confirm
    [[ "$confirm" == "s" || "$confirm" == "S" ]] || { echo "Cancelado"; exit 0; }
    $COMPOSE_CMD down -v --remove-orphans
    success "Lab eliminado completamente (incluidos volúmenes)"
else
    info "Parando contenedores..."
    $COMPOSE_CMD down --remove-orphans
    success "Contenedores parados. Los volúmenes se conservan."
    info "Para borrar todo: ./teardown.sh --purge"
fi
