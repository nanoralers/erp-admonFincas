#!/bin/bash
# ════════════════════════════════════════════════════════════════════
#  ERP FINCAS — Script de despliegue completo en el servidor
#  Ejecutar como root en el servidor nanoserver.es
#  Uso: sudo bash deploy.sh
# ════════════════════════════════════════════════════════════════════

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

ok()   { echo -e "${GREEN}  ✓ $1${NC}"; }
info() { echo -e "${CYAN}  ► $1${NC}"; }
warn() { echo -e "${YELLOW}  ⚠ $1${NC}"; }
fail() { echo -e "${RED}  ✗ $1${NC}"; exit 1; }
hdr()  { echo -e "\n${BOLD}${BLUE}══ $1 ══${NC}"; }

echo -e "${BOLD}"
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║      ERP FINCAS — Despliegue automático          ║"
echo "  ║      nanoserver.es · Versión 1.0.0               ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo -e "${NC}"

[[ $EUID -ne 0 ]] && fail "Ejecuta como root: sudo bash deploy.sh"

PROJECT_DIR="/home/nano/www/erp-fincas"
WEB_USER="www-data"
OWNER="nano"
DB_NAME="erp_fincas"
DB_USER="erp_user"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ERP_SRC="$SCRIPT_DIR/../02-proyecto-erp"
APACHE_CONF="$SCRIPT_DIR/../01-servidor-apache/nanoserver_es.conf"

# ── PASO 1: Requisitos ───────────────────────────────────────────────
hdr "PASO 1 — Verificar requisitos"

PHP_VER=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || echo "0")
[[ $(echo "$PHP_VER >= 8.1" | bc -l 2>/dev/null || php -r "echo version_compare('$PHP_VER','8.1','>=') ? 1 : 0;") -eq 1 ]] \
    || fail "Necesitas PHP 8.1+. Tienes $PHP_VER"
ok "PHP $PHP_VER"

for ext in pdo pdo_mysql mbstring json; do
    php -m | grep -q "^$ext$" || fail "Extensión PHP faltante: $ext"
    ok "ext-$ext"
done

command -v mysql    &>/dev/null || fail "MySQL/MariaDB no encontrado"
command -v apache2ctl &>/dev/null || fail "Apache2 no encontrado"
ok "MySQL y Apache2 disponibles"

# ── PASO 2: Desplegar archivos ───────────────────────────────────────
hdr "PASO 2 — Desplegar archivos"

mkdir -p "$PROJECT_DIR"
cp -r "$ERP_SRC/." "$PROJECT_DIR/"
mkdir -p "$PROJECT_DIR/uploads/"{logos,docs,avatars}
mkdir -p "$PROJECT_DIR/cache"
mkdir -p /home/nano/www/logs
ok "Archivos copiados en $PROJECT_DIR"

chown -R "$OWNER:$WEB_USER" "$PROJECT_DIR"
find "$PROJECT_DIR" -type d -exec chmod 755 {} \;
find "$PROJECT_DIR" -type f -exec chmod 644 {} \;
chmod -R 775 "$PROJECT_DIR/uploads" "$PROJECT_DIR/cache"
chmod 775 /home/nano/www/logs
chmod +x "$PROJECT_DIR/install/install.sh"
ok "Permisos aplicados"

# ── PASO 3: Archivo .env ─────────────────────────────────────────────
hdr "PASO 3 — Archivo .env"

if [[ -f "$PROJECT_DIR/.env" ]]; then
    warn ".env ya existe — no se sobreescribe"
else
    ENCRYPTION_KEY=$(php -r "echo bin2hex(random_bytes(16));")
    cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
    read -p "  Contraseña para DB user '$DB_USER': " -s DB_PASS; echo
    read -p "  Password SMTP (noreply@nanoserver.es): " -s MAIL_PASS; echo
    sed -i "s|DB_PASS=.*|DB_PASS=$DB_PASS|"               "$PROJECT_DIR/.env"
    sed -i "s|MAIL_PASSWORD=.*|MAIL_PASSWORD=$MAIL_PASS|" "$PROJECT_DIR/.env"
    sed -i "s|ENCRYPTION_KEY=.*|ENCRYPTION_KEY=$ENCRYPTION_KEY|" "$PROJECT_DIR/.env"
    chmod 640 "$PROJECT_DIR/.env"
    chown "$OWNER:$WEB_USER" "$PROJECT_DIR/.env"
    ok ".env generado con clave de cifrado aleatoria"
fi

DB_PASS_FILE=$(grep "^DB_PASS=" "$PROJECT_DIR/.env" | cut -d= -f2-)

# ── PASO 4: Base de datos ────────────────────────────────────────────
hdr "PASO 4 — Base de datos"

info "Creando DB y usuario (necesitas la contraseña de root de MySQL)..."
mysql -u root -p <<MYSQLEOF
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS_FILE';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
MYSQLEOF
ok "Base de datos '$DB_NAME' lista"

info "Importando schema..."
mysql -u "$DB_USER" -p"$DB_PASS_FILE" "$DB_NAME" \
    < "$PROJECT_DIR/install/schema.sql"
ok "Schema importado ($(mysql -u "$DB_USER" -p"$DB_PASS_FILE" "$DB_NAME" -e "SHOW TABLES;" 2>/dev/null | wc -l) tablas)"

# ── PASO 5: Apache ───────────────────────────────────────────────────
hdr "PASO 5 — Configurar Apache"

a2enmod rewrite headers expires deflate ssl 2>/dev/null | grep -v "already enabled" || true
ok "Módulos Apache activados"

cp "$APACHE_CONF" /etc/apache2/sites-available/nanoserver_es.conf
a2ensite nanoserver_es.conf 2>/dev/null || true
ok "VirtualHost instalado"

if apache2ctl configtest 2>&1 | grep -q "Syntax OK"; then
    systemctl reload apache2
    ok "Apache recargado correctamente"
else
    warn "Error de sintaxis — revisa: sudo apache2ctl configtest"
fi

# ── PASO 6: Resumen ──────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}"
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║         ✓  Despliegue completado                 ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  Siguiente: obtener certificado SSL wildcard"
echo -e "  ${CYAN}sudo bash 03-scripts-despliegue/ssl-wildcard.sh${NC}"
echo ""
