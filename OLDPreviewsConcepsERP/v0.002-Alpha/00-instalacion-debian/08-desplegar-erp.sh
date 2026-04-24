#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════
#  PASO 08 — Despliegue final del ERP Fincas
# ════════════════════════════════════════════════════════════════════════════

set -euo pipefail
G='\033[0;32m'; C='\033[0;36m'; Y='\033[1;33m'; R='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${G}    ✓${NC} $1"; }
info() { echo -e "${C}    ▸ $1${NC}"; }
warn() { echo -e "${Y}    ⚠ $1${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ERP_SRC="$SCRIPT_DIR/../02-proyecto-erp"
PROJECT_DIR="/home/nano/www/erp-fincas"
CREDS_FILE="/root/.erp-fincas-db-credentials"

# ── Copiar archivos del proyecto ──────────────────────────────────────────────
info "Copiando archivos del ERP a $PROJECT_DIR..."
rsync -a --exclude='.gitkeep' "$ERP_SRC/" "$PROJECT_DIR/"
ok "Archivos copiados"

# ── Crear .env ────────────────────────────────────────────────────────────────
info "Generando archivo .env..."

if [[ -f "$PROJECT_DIR/.env" ]]; then
    warn ".env ya existe — haciendo backup y regenerando"
    cp "$PROJECT_DIR/.env" "$PROJECT_DIR/.env.bak.$(date +%Y%m%d%H%M%S)"
fi

# Leer credenciales guardadas en paso 04
DB_PASS=""
if [[ -f "$CREDS_FILE" ]]; then
    DB_PASS=$(grep "^DB_PASS=" "$CREDS_FILE" | cut -d= -f2-)
fi

if [[ -z "$DB_PASS" ]]; then
    read -p "    Contraseña del usuario erp_user en MariaDB: " -s DB_PASS
    echo ""
fi

# Generar clave de cifrado aleatoria
ENCRYPTION_KEY=$(php -r "echo bin2hex(random_bytes(16));" 2>/dev/null \
    || openssl rand -hex 16)

cat > "$PROJECT_DIR/.env" <<ENV
# ERP Fincas — Configuración de producción
# Generado: $(date)

# ── Aplicación ────────────────────────────────────────────────
APP_ENV=production
APP_DEBUG=false
BASE_DOMAIN=nanoserver.es

# ── Base de datos ─────────────────────────────────────────────
DB_HOST=localhost
DB_PORT=3306
DB_NAME=erp_fincas
DB_USER=erp_user
DB_PASS=${DB_PASS}

# ── Email SMTP ────────────────────────────────────────────────
# Configurar con tus credenciales reales de correo IONOS
MAIL_HOST=smtp.ionos.es
MAIL_PORT=587
MAIL_USERNAME=noreply@nanoserver.es
MAIL_PASSWORD=CONFIGURA_PASSWORD_CORREO_AQUI
MAIL_FROM=noreply@nanoserver.es
MAIL_FROM_NAME=ERP Fincas

# ── Seguridad ─────────────────────────────────────────────────
ENCRYPTION_KEY=${ENCRYPTION_KEY}
ENV

chmod 640 "$PROJECT_DIR/.env"
chown nano:www-data "$PROJECT_DIR/.env"
ok ".env generado con clave de cifrado aleatoria"

# ── Permisos finales ──────────────────────────────────────────────────────────
info "Aplicando permisos finales..."
chown -R nano:www-data "$PROJECT_DIR"
find "$PROJECT_DIR" -type d -exec chmod 755 {} \;
find "$PROJECT_DIR" -type f -exec chmod 644 {} \;

# Directorios que Apache/PHP necesita escribir
chmod -R 775 "$PROJECT_DIR/uploads"
chmod -R 775 "$PROJECT_DIR/cache"
chmod -R 775 "$PROJECT_DIR/logs"
chmod -R 775 /home/nano/www/logs

# Scripts ejecutables
find "$PROJECT_DIR/install" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

# .env solo legible por dueño y grupo
chmod 640 "$PROJECT_DIR/.env"

# Traversal para Apache
chmod o+x /home/nano
chmod o+x /home/nano/www
ok "Permisos aplicados"

# ── Verificar que Apache puede leer el proyecto ───────────────────────────────
info "Verificando acceso de Apache al proyecto..."
if sudo -u www-data test -r "$PROJECT_DIR/public/index.php" 2>/dev/null; then
    ok "www-data puede leer el proyecto"
else
    warn "www-data no puede leer el proyecto — verificar permisos"
    # Intentar corrección con ACL
    if command -v setfacl &>/dev/null; then
        setfacl -R -m u:www-data:rX "$PROJECT_DIR" 2>/dev/null || true
        setfacl -R -m u:www-data:rwX "$PROJECT_DIR/uploads" 2>/dev/null || true
        setfacl -R -m u:www-data:rwX "$PROJECT_DIR/cache" 2>/dev/null || true
        ok "ACL aplicado para www-data"
    fi
fi

# ── Recarga final de servicios ────────────────────────────────────────────────
info "Recargando servicios..."
systemctl reload apache2  2>/dev/null && ok "Apache recargado"  || warn "Apache no pudo recargar"
systemctl reload mariadb  2>/dev/null && ok "MariaDB recargado" || true
systemctl reload fail2ban 2>/dev/null && ok "Fail2Ban recargado"|| true

# ── Limpieza de credenciales temporales ──────────────────────────────────────
if [[ -f "$CREDS_FILE" ]]; then
    echo ""
    warn "Recuerda borrar el archivo de credenciales temporales:"
    echo -e "    ${R}rm -f $CREDS_FILE${NC}"
    echo ""
fi

# ── Prueba de acceso ──────────────────────────────────────────────────────────
info "Prueba de acceso HTTP local..."
sleep 1
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
    -H "Host: nanoserver.es" http://127.0.0.1/ 2>/dev/null || echo "000")

case "$HTTP_CODE" in
    200|301|302) ok "HTTP responde correctamente (código $HTTP_CODE)" ;;
    000) warn "Sin respuesta HTTP — ¿Apache está corriendo?" ;;
    *)   warn "HTTP código $HTTP_CODE — revisar configuración" ;;
esac

echo ""
ok "PASO 08 completado — ERP desplegado"
echo ""
echo "    Proyecto: $PROJECT_DIR"
echo "    Config:   $PROJECT_DIR/.env"
echo ""
echo "    ─────────────────────────────────────────────────"
echo "    FALTA: obtener certificado SSL wildcard real"
echo "    sudo bash 03-scripts-despliegue/ssl-wildcard.sh"
echo "    ─────────────────────────────────────────────────"
