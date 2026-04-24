#!/bin/bash

# ════════════════════════════════════════════════════════════════
#  ERP FINCAS - Instalación Automatizada
# ════════════════════════════════════════════════════════════════

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║      ERP FINCAS - Script de Instalación v1.0.0            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# ── Variables ────────────────────────────────────────────────────
DB_NAME="erp_fincas"
DB_USER="erp_user"
DB_PASS=""
BASE_DOMAIN=""

# ── Comprobar requisitos ─────────────────────────────────────────
echo "► Comprobando requisitos..."

if ! command -v php &> /dev/null; then
    echo "✗ PHP no encontrado. Instala PHP 8.1 o superior."
    exit 1
fi

PHP_VERSION=$(php -r 'echo PHP_VERSION;')
echo "✓ PHP $PHP_VERSION encontrado"

if ! command -v mysql &> /dev/null; then
    echo "✗ MySQL/MariaDB no encontrado."
    exit 1
fi
echo "✓ MySQL/MariaDB encontrado"

# ── Solicitar datos ──────────────────────────────────────────────
echo ""
echo "► Configuración de la instalación"
echo ""

read -p "Dominio base (ej: nanoserver.es): " BASE_DOMAIN
read -p "Contraseña para el usuario de BD '$DB_USER': " -s DB_PASS
echo ""

if [ -z "$BASE_DOMAIN" ] || [ -z "$DB_PASS" ]; then
    echo "✗ Faltan datos obligatorios"
    exit 1
fi

# ── Crear base de datos ──────────────────────────────────────────
echo ""
echo "► Creando base de datos..."

mysql -u root -p <<EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

echo "✓ Base de datos creada"

# ── Importar schema ──────────────────────────────────────────────
echo "► Importando schema SQL..."
mysql -u $DB_USER -p$DB_PASS $DB_NAME < install/schema.sql
echo "✓ Schema importado"

# ── Generar .env ─────────────────────────────────────────────────
echo "► Generando archivo .env..."

ENCRYPTION_KEY=$(php -r "echo bin2hex(random_bytes(16));")

cat > .env <<EOF
APP_ENV=production
APP_DEBUG=false
BASE_DOMAIN=$BASE_DOMAIN

DB_HOST=localhost
DB_PORT=3306
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASS=$DB_PASS

MAIL_HOST=smtp.$BASE_DOMAIN
MAIL_PORT=587
MAIL_USERNAME=noreply@$BASE_DOMAIN
MAIL_PASSWORD=CONFIGURA_ESTO
MAIL_FROM=noreply@$BASE_DOMAIN

ENCRYPTION_KEY=$ENCRYPTION_KEY
EOF

echo "✓ Archivo .env generado"

# ── Permisos ─────────────────────────────────────────────────────
echo "► Configurando permisos..."

mkdir -p uploads/{logos,docs,avatars} logs cache
chmod -R 775 uploads logs cache
chown -R www-data:www-data uploads logs cache 2>/dev/null || true

echo "✓ Permisos configurados"

# ── Finalizar ────────────────────────────────────────────────────
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              ✓ Instalación completada                     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Próximos pasos:"
echo "  1. Configura tu servidor web (Apache/Nginx)"
echo "  2. Accede a https://admin.$BASE_DOMAIN"
echo "  3. Usuario inicial: admin@nanoserver.es"
echo "  4. Cambia la contraseña inicial desde el panel"
echo ""
echo "Documentación completa en README.md"
echo ""
