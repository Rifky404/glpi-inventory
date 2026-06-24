#!/bin/bash
# ─────────────────────────────────────────
# GLPI Docker Setup Script
# Ubuntu 26.04 (Resolute)
# ─────────────────────────────────────────

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()    { echo -e "${GREEN}[✓]${NC} $1"; }
warn()   { echo -e "${YELLOW}[!]${NC} $1"; }
error()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }

echo ""
echo "╔══════════════════════════════════════╗"
echo "║   GLPI + MariaDB 10.11 Docker Setup  ║"
echo "╚══════════════════════════════════════╝"
echo ""

# ── 1. Cek Docker ──────────────────────────
if ! command -v docker &>/dev/null; then
    warn "Docker belum terinstall. Menginstall..."
    apt-get update -qq
    apt-get install -y docker.io docker-compose-v2
    systemctl enable --now docker
    log "Docker terinstall"
else
    log "Docker sudah ada: $(docker --version)"
fi

if ! command -v docker compose &>/dev/null 2>&1; then
    warn "docker compose plugin belum ada. Menginstall..."
    apt-get install -y docker-compose-v2
fi

# ── 2. Cek file .env ───────────────────────
if [ ! -f ".env" ]; then
    warn "File .env tidak ada. Menyalin dari .env.example..."
    if [ -f ".env.example" ]; then
        cp .env.example .env
        warn "Edit file .env sebelum lanjut!"
        exit 0
    else
        error "File .env tidak ditemukan!"
    fi
fi

log "File .env ditemukan"

# ── 3. Jalankan container ──────────────────
log "Menarik image Docker..."
docker compose pull

log "Menjalankan container..."
docker compose up -d --build

# ── 4. Tunggu MariaDB siap ─────────────────
log "Menunggu MariaDB siap..."
attempt=0
max_attempts=30
until docker compose exec mariadb healthcheck.sh --connect --innodb_initialized &>/dev/null; do
    attempt=$((attempt+1))
    if [ $attempt -ge $max_attempts ]; then
        error "MariaDB tidak siap setelah ${max_attempts} percobaan"
    fi
    echo -n "."
    sleep 2
done
echo ""
log "MariaDB siap!"

# ── 5. Info akses ──────────────────────────
GLPI_PORT=$(grep GLPI_PORT .env | cut -d'=' -f2)
SERVER_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║          GLPI Berhasil Dijalankan!       ║"
echo "╠══════════════════════════════════════════╣"
echo "║  URL: http://${SERVER_IP}:${GLPI_PORT}              "
echo "║                                          ║"
echo "║  Setup DB di installer GLPI:             ║"
echo "║  • Host    : mariadb                     ║"
echo "║  • DB      : (lihat .env MYSQL_DATABASE) ║"
echo "║  • User    : (lihat .env MYSQL_USER)     ║"
echo "║  • Password: (lihat .env MYSQL_PASSWORD) ║"
echo "║                                          ║"
echo "║  Login default GLPI:                     ║"
echo "║  • User: glpi   | Pass: glpi             ║"
echo "║  • User: tech   | Pass: tech             ║"
echo "╚══════════════════════════════════════════╝"
echo ""