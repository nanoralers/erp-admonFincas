#!/bin/bash
# ════════════════════════════════════════════════════════════════════
#  ERP FINCAS — Script de verificación completa del sistema
#  Uso: bash verificar.sh
# ════════════════════════════════════════════════════════════════════

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

ok()   { echo -e "  ${GREEN}✓${NC}  $1"; }
fail() { echo -e "  ${RED}✗${NC}  $1"; ERRORS=$((ERRORS+1)); }
warn() { echo -e "  ${YELLOW}⚠${NC}  $1"; }
hdr()  { echo -e "\n${BOLD}${CYAN}▸ $1${NC}"; }

ERRORS=0
PROJECT_DIR="/home/nano/www/erp-fincas"

echo -e "\n${BOLD}  ERP FINCAS — Verificación del sistema${NC}"
echo "  ─────────────────────────────────────────────"

# ── PHP ───────────────────────────────────────────────────────────
hdr "PHP"
PHP_VER=$(php -r 'echo PHP_VERSION;' 2>/dev/null)
[[ -n "$PHP_VER" ]] && ok "PHP $PHP_VER" || fail "PHP no encontrado"
for ext in pdo pdo_mysql mbstring json openssl; do
    php -m 2>/dev/null | grep -q "^$ext$" && ok "ext-$ext" || fail "Falta ext-$ext"
done

# ── Archivos del proyecto ────────────────────────────────────────
hdr "Archivos del proyecto"
REQUIRED_FILES=(
    "$PROJECT_DIR/index.php"
    "$PROJECT_DIR/config/config.php"
    "$PROJECT_DIR/.env"
    "$PROJECT_DIR/core/Database.php"
    "$PROJECT_DIR/core/Auth.php"
    "$PROJECT_DIR/core/SubdomainResolver.php"
    "$PROJECT_DIR/core/Router.php"
    "$PROJECT_DIR/core/helpers.php"
    "$PROJECT_DIR/public/index.php"
    "$PROJECT_DIR/public/.htaccess"
    "$PROJECT_DIR/public/css/app.css"
    "$PROJECT_DIR/public/js/app.js"
    "$PROJECT_DIR/install/schema.sql"
)
for f in "${REQUIRED_FILES[@]}"; do
    [[ -f "$f" ]] && ok "${f/$PROJECT_DIR\//}" || fail "FALTA: ${f/$PROJECT_DIR\//}"
done

# ── Permisos ──────────────────────────────────────────────────────
hdr "Permisos"
for dir in uploads cache; do
    [[ -w "$PROJECT_DIR/$dir" ]] \
        && ok "$dir/ es escribible" \
        || fail "$dir/ NO es escribible"
done
[[ -f "$PROJECT_DIR/.env" ]] && {
    PERM=$(stat -c %a "$PROJECT_DIR/.env")
    [[ "$PERM" -le 640 ]] && ok ".env protegido ($PERM)" || warn ".env tiene permisos $PERM (recomendado: 640)"
}

# ── Base de datos ─────────────────────────────────────────────────
hdr "Base de datos"
if [[ -f "$PROJECT_DIR/.env" ]]; then
    DB_HOST=$(grep "^DB_HOST=" "$PROJECT_DIR/.env" | cut -d= -f2-)
    DB_NAME=$(grep "^DB_NAME=" "$PROJECT_DIR/.env" | cut -d= -f2-)
    DB_USER=$(grep "^DB_USER=" "$PROJECT_DIR/.env" | cut -d= -f2-)
    DB_PASS=$(grep "^DB_PASS=" "$PROJECT_DIR/.env" | cut -d= -f2-)

    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" \
        -e "SELECT 1;" &>/dev/null \
        && ok "Conexión a DB '$DB_NAME'" \
        || fail "No se puede conectar a la DB"

    TABLES=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" \
        -e "SHOW TABLES;" 2>/dev/null | wc -l)
    [[ $TABLES -ge 20 ]] \
        && ok "$TABLES tablas en la BD" \
        || fail "Solo $TABLES tablas (esperadas ≥20) — ¿se importó el schema?"
else
    warn "Sin .env — no se verifica la DB"
fi

# ── Apache ────────────────────────────────────────────────────────
hdr "Apache"
apache2ctl -M 2>/dev/null | grep -q "rewrite_module"  && ok "mod_rewrite activo" || fail "mod_rewrite inactivo"
apache2ctl -M 2>/dev/null | grep -q "headers_module"  && ok "mod_headers activo" || fail "mod_headers inactivo"
apache2ctl -M 2>/dev/null | grep -q "ssl_module"      && ok "mod_ssl activo"     || fail "mod_ssl inactivo"
apache2ctl configtest 2>&1 | grep -q "Syntax OK"      && ok "Sintaxis Apache OK"  || fail "Error de sintaxis Apache"
[[ -f "/etc/apache2/sites-enabled/nanoserver_es.conf" ]] \
    && ok "VirtualHost nanoserver_es.conf activo" \
    || fail "VirtualHost nanoserver_es.conf no está habilitado"

# ── SSL ───────────────────────────────────────────────────────────
hdr "Certificados SSL"
for CERT_NAME in "nanoserver.es" "nanoserver.es-wildcard"; do
    CERT_PATH="/etc/letsencrypt/live/$CERT_NAME/fullchain.pem"
    if [[ -f "$CERT_PATH" ]]; then
        EXPIRY=$(openssl x509 -enddate -noout -in "$CERT_PATH" 2>/dev/null | cut -d= -f2)
        DAYS=$(( ( $(date -d "$EXPIRY" +%s) - $(date +%s) ) / 86400 ))
        [[ $DAYS -gt 30 ]] \
            && ok "$CERT_NAME — válido $DAYS días más ($EXPIRY)" \
            || warn "$CERT_NAME — EXPIRA EN $DAYS DÍAS ($EXPIRY)"
    else
        [[ "$CERT_NAME" == "nanoserver.es-wildcard" ]] \
            && fail "Certificado wildcard NO encontrado — ejecuta ssl-wildcard.sh" \
            || warn "Certificado $CERT_NAME no encontrado"
    fi
done

# ── DNS ───────────────────────────────────────────────────────────
hdr "DNS"
MY_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null)
for HOST in "nanoserver.es" "www.nanoserver.es" "admin.nanoserver.es" "demo.nanoserver.es"; do
    RESOLVED=$(dig +short "$HOST" 2>/dev/null | tail -1)
    if [[ "$RESOLVED" == "$MY_IP" ]]; then
        ok "$HOST → $RESOLVED"
    elif [[ -n "$RESOLVED" ]]; then
        warn "$HOST → $RESOLVED (¿es tu IP? La tuya es $MY_IP)"
    else
        fail "$HOST no resuelve"
    fi
done

# ── Conectividad HTTPS ────────────────────────────────────────────
hdr "Conectividad HTTPS"
for URL in "https://nanoserver.es" "https://admin.nanoserver.es"; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$URL" 2>/dev/null)
    case $HTTP_CODE in
        200|301|302) ok "$URL → HTTP $HTTP_CODE" ;;
        000) fail "$URL — Sin respuesta (¿Apache corriendo?)" ;;
        *)   warn "$URL → HTTP $HTTP_CODE" ;;
    esac
done

# ── Resumen ───────────────────────────────────────────────────────
echo ""
echo "  ─────────────────────────────────────────────"
if [[ $ERRORS -eq 0 ]]; then
    echo -e "  ${GREEN}${BOLD}✓  Todo correcto — Sistema listo para usar${NC}"
else
    echo -e "  ${RED}${BOLD}✗  $ERRORS error(es) encontrado(s) — Revisa los puntos marcados${NC}"
fi
echo ""
