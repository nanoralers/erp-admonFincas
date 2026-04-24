#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════
#  PASO 08 — Despliegue del ERP Fincas
# ════════════════════════════════════════════════════════════════════════════

set -euo pipefail
G='\033[0;32m'; C='\033[0;36m'; Y='\033[1;33m'; R='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${G}    ✓${NC} $1"; }
info() { echo -e "${C}    ▸ $1${NC}"; }
warn() { echo -e "${Y}    ⚠${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ERP_SRC="$SCRIPT_DIR/../02-proyecto-erp"
PROJECT_DIR="/home/nano/www/erp-fincas"
CREDS_FILE="/root/.erp-fincas-db-credentials"

# ── Copiar archivos del proyecto ──────────────────────────────────────────────
info "Copiando archivos ERP → $PROJECT_DIR..."
rsync -a --exclude='.gitkeep' --exclude='.env' "$ERP_SRC/" "$PROJECT_DIR/" 2>/dev/null \
    || cp -r "$ERP_SRC"/. "$PROJECT_DIR/"
ok "Archivos copiados"

# ── Generar .env ──────────────────────────────────────────────────────────────
info "Generando .env..."

if [[ -f "$PROJECT_DIR/.env" ]]; then
    cp "$PROJECT_DIR/.env" "$PROJECT_DIR/.env.bak.$(date +%Y%m%d%H%M%S)"
    warn ".env existente respaldado"
fi

# Leer credenciales del paso 04
DB_PASS=""
[[ -f "$CREDS_FILE" ]] && DB_PASS=$(grep "^DB_PASS=" "$CREDS_FILE" | cut -d= -f2-)
if [[ -z "$DB_PASS" ]]; then
    read -p "    Contraseña del usuario erp_user: " -s DB_PASS; echo
fi

ENC_KEY=$(php -r "echo bin2hex(random_bytes(16));" 2>/dev/null \
    || openssl rand -hex 16)

cat > "$PROJECT_DIR/.env" <<ENV
# ERP Fincas — Producción · Debian 13 Trixie
# Generado: $(date)

APP_ENV=production
APP_DEBUG=false
BASE_DOMAIN=nanoserver.es

DB_HOST=localhost
DB_PORT=3306
DB_NAME=erp_fincas
DB_USER=erp_user
DB_PASS=${DB_PASS}

# Configura con tus credenciales reales de correo IONOS
MAIL_HOST=smtp.ionos.es
MAIL_PORT=587
MAIL_USERNAME=noreply@nanoserver.es
MAIL_PASSWORD=CONFIGURAR_PASSWORD_CORREO_IONOS_AQUI
MAIL_FROM=noreply@nanoserver.es
MAIL_FROM_NAME=ERP Fincas

ENCRYPTION_KEY=${ENC_KEY}
ENV

chmod 640 "$PROJECT_DIR/.env"
chown nano:www-data "$PROJECT_DIR/.env"
ok ".env generado (clave de cifrado aleatoria)"

# ── Permisos finales ──────────────────────────────────────────────────────────
info "Aplicando permisos..."
chown -R nano:www-data "$PROJECT_DIR"
find "$PROJECT_DIR" -type d -exec chmod 755 {} \;
find "$PROJECT_DIR" -type f -exec chmod 644 {} \; 2>/dev/null || true
chmod 640 "$PROJECT_DIR/.env"
chmod -R 775 "$PROJECT_DIR/uploads" "$PROJECT_DIR/cache" "$PROJECT_DIR/logs"
chmod -R 775 /home/nano/www/logs/
find "$PROJECT_DIR/install" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

# ACL para www-data si está disponible
if command -v setfacl &>/dev/null; then
    setfacl -R -m u:www-data:rX   "$PROJECT_DIR"
    setfacl -R -m u:www-data:rwX  "$PROJECT_DIR/uploads"
    setfacl -R -m u:www-data:rwX  "$PROJECT_DIR/cache"
    setfacl -R -m u:www-data:rwX  "$PROJECT_DIR/logs"
    ok "ACL configurado para www-data"
fi

ok "Permisos aplicados"

# ── Recargar servicios ────────────────────────────────────────────────────────
info "Recargando servicios..."
systemctl reload apache2  2>/dev/null && ok "Apache recargado"  || warn "Apache no pudo recargar"
systemctl reload mariadb  2>/dev/null && ok "MariaDB recargado" || true
systemctl reload fail2ban 2>/dev/null && ok "Fail2Ban recargado"|| true

# ── Test básico HTTP ──────────────────────────────────────────────────────────
sleep 1
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
    -H "Host: nanoserver.es" http://127.0.0.1/ 2>/dev/null || echo "000")
case "$HTTP_CODE" in
    200|301|302) ok "HTTP responde (código $HTTP_CODE)" ;;
    000) warn "Sin respuesta HTTP — ¿Apache está corriendo?" ;;
    *) warn "HTTP código $HTTP_CODE — revisar configuración" ;;
esac

echo ""
ok "PASO 08 completado"
echo ""
echo "    ERP desplegado en: $PROJECT_DIR"
echo "    Configuración:     $PROJECT_DIR/.env"
