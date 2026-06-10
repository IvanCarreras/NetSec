#!/usr/bin/env bash
# ============================================================
#  install-docker.sh — Instala Docker Engine en Ubuntu Server
#  Uso: chmod +x install-docker.sh && ./install-docker.sh
# ============================================================

set -euo pipefail

GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[*]${NC} $1"; }
success() { echo -e "${GREEN}[+]${NC} $1"; }

echo ""
echo -e "${CYAN}[*] Instalando Docker Engine en Ubuntu Server...${NC}"
echo ""

# Limpiar instalaciones previas
info "Limpiando paquetes conflictivos..."
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
  sudo apt-get remove -y "$pkg" 2>/dev/null || true
done

# Dependencias
info "Instalando dependencias..."
sudo apt-get update -qq
sudo apt-get install -y -qq \
  ca-certificates curl gnupg lsb-release openssl

# Repositorio oficial de Docker
info "Añadiendo repositorio oficial de Docker..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instalar Docker
info "Instalando Docker Engine + Compose plugin..."
sudo apt-get update -qq
sudo apt-get install -y -qq \
  docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

# Añadir usuario al grupo docker (sin sudo)
info "Añadiendo $USER al grupo docker..."
sudo usermod -aG docker "$USER"

# Arrancar y habilitar servicio
sudo systemctl enable --now docker

success "Docker instalado correctamente"
echo ""
echo -e "${GREEN}  Versión:${NC} $(docker --version)"
echo -e "${GREEN}  Compose:${NC} $(docker compose version)"
echo ""
echo -e "${CYAN}[!] IMPORTANTE: Cierra la sesión SSH y vuelve a entrar${NC}"
echo -e "${CYAN}    para que el grupo 'docker' surta efecto sin sudo.${NC}"
echo ""
